-- ─── Résolution des slots ────────────────────────────────────────────────
-- Événements non passés par LSLegacy.Events.Register (RegisterNetEvent
-- brut + TriggerServerEvent côté client) : comme pour `registerPlayer`, le
-- système de jetons anti-triche n'existe pas encore à ce stade de la
-- connexion (LSLegacy.GeneratorTokenConnecting n'a pas encore tourné).

local function GetPlayerIdentifierMC(source)
    for _, v in pairs(GetPlayerIdentifiers(source)) do
        if string.find(v, "license:") then
            return v
        end
    end
    return nil
end

local function GetMaxSlots(identifier)
    if not Config.Multichar.Enabled then return 1 end

    for _, id in ipairs(Config.Multichar.AdminIdentifiers) do
        if id == identifier then
            return Config.Multichar.SlotsAdmin
        end
    end

    -- Tout superadmin (Config.StaffGroups[4]) bénéficie des slots admin,
    -- indépendamment du personnage utilisé pour se connecter.
    local isSuperAdmin = MySQL.Sync.fetchScalar(
        'SELECT 1 FROM players WHERE identifier = @identifier AND `group` = @group LIMIT 1',
        { ['@identifier'] = identifier, ['@group'] = Config.StaffGroups[4] }
    )
    if isSuperAdmin then
        return Config.Multichar.SlotsAdmin
    end

    return Config.Multichar.SlotsDefault
end

-- Construit la liste enrichie des personnages d'un compte (utilisée par
-- requestSlots ET deleteCharacter, pour ne pas dupliquer le SELECT/mapping).
-- Inclut skin/job/argent/coords : nécessaire à la scène "appartement" (ped +
-- tooltip NUI), en plus des champs déjà utilisés par l'ancienne liste NUI.
local function FetchCharacters(identifier, cb)
    MySQL.Async.fetchAll('SELECT `boutique-id`, slot, characterInfos, skin, job, job_grade, money, coords FROM players WHERE identifier = @identifier ORDER BY slot ASC', {
        ['@identifier'] = identifier
    }, function(rows)
        rows = rows or {}

        local characters = {}
        for _, row in ipairs(rows) do
            local infos = {}
            local ok, decoded = pcall(json.decode, row.characterInfos)
            if ok and type(decoded) == 'table' then infos = decoded end

            local skin = {}
            local okSkin, decodedSkin = pcall(json.decode, row.skin)
            if okSkin and type(decodedSkin) == 'table' then skin = decodedSkin end

            local money = { cash = 0 }
            local okMoney, decodedMoney = pcall(json.decode, row.money)
            if okMoney and type(decodedMoney) == 'table' then money = decodedMoney end

            local coords = nil
            local okCoords, decodedCoords = pcall(json.decode, row.coords)
            if okCoords and type(decodedCoords) == 'table' then coords = decodedCoords end

            local characterId = row["boutique-id"]
            local bankBalance = nil
            if LSLegacy.Bank and LSLegacy.Bank.GetCompteCourant then
                local ok2, courant = pcall(LSLegacy.Bank.GetCompteCourant, characterId)
                if ok2 and courant then bankBalance = courant.amountMoney end
            end

            -- Libellé job/grade résolu ici via le vrai registre LSLegacy.Jobs
            -- (server/player/jobs.lua) plutôt que côté client, qui n'y a pas
            -- accès et ne connaît que Config.MDT.Departments (institutions
            -- seulement, pas les jobs civils). 'unemployed' est un job comme
            -- un autre dans ce registre (label "Chômeur") -> même lookup.
            local job = (row.job and row.job ~= '') and row.job or 'unemployed'
            local jobLabel
            if LSLegacy.Jobs and LSLegacy.Jobs.DoesJobExist(job) then
                jobLabel = LSLegacy.Jobs.GetJobLabel(job)
                if LSLegacy.Jobs.DoesJobGradeExist(job, row.job_grade) then
                    jobLabel = jobLabel .. " - " .. LSLegacy.Jobs.GetJobGradeLabel(job, row.job_grade)
                end
            else
                jobLabel = job
            end

            characters[#characters + 1] = {
                id = characterId,
                slot = row.slot,
                firstname = infos.Prenom or "?",
                lastname = infos.NDF or "?",
                skin = skin,
                jobLabel = jobLabel,
                cash = money.cash or 0,
                bankBalance = bankBalance,
                coords = coords,
            }
        end

        cb(characters)
    end)
end

RegisterNetEvent('multichar:requestSlots')
AddEventHandler('multichar:requestSlots', function()
    local source = source
    Config.Development.Print("[multichar] requestSlots reçu de " .. source)

    if LSLegacy.Players.Get(source) then
        Config.Development.Print("Player " .. source .. " already registered")
        DropPlayer(source, "Player " .. source .. " already registered ╭∩╮（︶_︶）╭∩╮")
        return
    end

    local identifier = GetPlayerIdentifierMC(source)
    if not identifier then
        Config.Development.Print("[multichar] " .. source .. ": AUCUN identifier license trouvé, kick")
        DropPlayer(source, "Identifiant introuvable ╭∩╮（︶_︶）╭∩╮")
        return
    end

    local maxSlots = GetMaxSlots(identifier)
    Config.Development.Print("[multichar] " .. source .. ": identifier=" .. identifier .. " maxSlots=" .. maxSlots .. ", requête SELECT...")

    FetchCharacters(identifier, function(characters)
        Config.Development.Print("[multichar] " .. source .. ": SELECT terminé, " .. #characters .. " ligne(s)")
        Config.Development.Print("[multichar] " .. source .. ": envoi multichar:init")
        TriggerClientEvent('multichar:init', source, characters, maxSlots)
    end)
end)

-- ─── Bucket routing (isolement pendant l'appartement de sélection) ─────────
-- Même contrainte que registerPlayer/requestSlots : le système de jetons
-- n'existe pas encore à ce stade, donc RegisterNetEvent brut (comme
-- module/creatorperso, mais offset distinct pour ne jamais collisionner avec
-- son propre bucket). Le serveur dérive le bucket du server id : un client
-- modifié ne peut pas demander le bucket d'un autre joueur.
RegisterNetEvent('multichar:setApartmentBucket')
AddEventHandler('multichar:setApartmentBucket', function(enter)
    local source = source
    if LSLegacy.Players.Get(source) then return end
    SetPlayerRoutingBucket(source, enter and (Config.Multichar.Apartment.BucketOffset + source) or 0)
end)

-- ─── Suppression d'un personnage ───────────────────────────────────────────
RegisterNetEvent('multichar:deleteCharacter')
AddEventHandler('multichar:deleteCharacter', function(characterId)
    local source = source

    if LSLegacy.Players.Get(source) then
        -- La suppression ne se fait que depuis l'écran de sélection, avant
        -- tout chargement de personnage.
        return
    end

    local identifier = GetPlayerIdentifierMC(source)
    characterId = tonumber(characterId)
    if not identifier or not characterId then return end

    -- Suppression en cascade des données propres à ce personnage (Lot 1 —
    -- tables "agent de service" à un seul rôle identifier). Volontairement
    -- PAS de cascade pour interim_stations / police_blood_traces /
    -- police_crime_scenes : ces tables deviennent per-personnage mais
    -- restent en base (preuves/scènes), voir module/pedoffline pour le
    -- même principe déjà appliqué aux peds endormis.
    local CASCADE_TABLES = {
        'police_officers', 'pompiers_agents', 'mecanicien_agents', 'atelier_agents',
        'ltd_agents', 'samu_agents', 'gendarmerie_officers',
        'police_radio_channels', 'emotes_favorites',
        -- Lot 2 : tables où ce personnage est le SUJET (citoyen/patient).
        -- La suppression cible toujours `character_id` (le sujet), jamais
        -- `officer_character_id` : supprimer le personnage d'un OFFICIER ne
        -- doit pas effacer le casier d'un citoyen tiers qu'il a arrêté.
        'police_custody', 'police_prison', 'mdt_custody',
        'mdt_criminal_records', 'mdt_fines', 'mdt_warrants',
        'mdt_med_records', 'bankaccounts',
        -- Lot 3 : véhicules
        'owned_vehicles', 'concessionnaire_occasions', 'fourriere',
        -- Lot 4 : fiche agent MDT
        'mdt_agent_meta', 'mdt_agent_career', 'mdt_agent_assignments',
        'mdt_agent_commendations', 'mdt_agent_skills', 'mdt_weapon_persons',
        'mdt_training_signups',
        -- Audit post-Lot 4 : journal médical/prescriptions, même traitement
        -- que mdt_med_records (déjà en cascade) dont elles sont les tables
        -- sœurs. mdt_evidence et mdt_med_calls restent volontairement HORS
        -- cascade (Groupe B, comme police_dna/fingerprints/callout_agents) :
        -- une preuve ou un historique d'appel ne doit pas disparaître avec
        -- le personnage qui y est lié.
        'mdt_med_entries', 'mdt_med_treatments',
    }
    for _, tbl in ipairs(CASCADE_TABLES) do
        MySQL.Async.execute('DELETE FROM `' .. tbl .. '` WHERE character_id = @id', {
            ['@id'] = characterId
        })
    end

    MySQL.Async.execute('DELETE FROM players WHERE `boutique-id` = @id AND identifier = @identifier', {
        ['@id'] = characterId,
        ['@identifier'] = identifier
    }, function(rowsChanged)
        if not rowsChanged or rowsChanged == 0 then
            Config.Development.Print("Tentative de suppression d'un personnage invalide par " .. source)
        end

        local maxSlots = GetMaxSlots(identifier)
        FetchCharacters(identifier, function(characters)
            TriggerClientEvent('multichar:deleted', source, characters, maxSlots)
        end)
    end)
end)

-- ─── Retour à la sélection de personnage (commande admin) ─────────────────
-- Sauvegarde le personnage en cours et renvoie le joueur à l'écran de
-- sélection multicharacter, sans déconnexion. Réservé aux comptes listés
-- dans Config.Multichar.AdminIdentifiers (mêmes comptes qui ont accès à
-- plusieurs slots) — pas au grade en jeu, qui est propre à chaque personnage.
local function SaveAndReleaseCharacter(source)
    local player = LSLegacy.Players.Get(source)
    if not player then return end

    local ped = GetPlayerPed(source)
    local coords = player.coords
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        coords = GetEntityCoords(ped)
    end

    MySQL.Async.execute('UPDATE players SET coords = @coords, skin = @skin, inventory = @inventory, money = @money, health = @health, status = @status, skills = @skills, job = @job, job_grade = @job_grade, faction = @faction, faction_grade = @faction_grade WHERE `boutique-id` = @id', {
        ['@coords'] = json.encode(coords),
        ['@id'] = player["boutique-id"],
        ['@skin'] = json.encode(player.skin),
        ['@inventory'] = json.encode(player.inventory),
        ['@money'] = json.encode({cash = player.cash, dirty = player.dirty}),
        ['@health'] = ped and ped ~= 0 and DoesEntityExist(ped) and GetEntityHealth(ped) or player.health,
        ['@status'] = json.encode(player.status),
        ['@skills'] = json.encode(player.skills or {}),
        ['@job'] = player.job,
        ['@job_grade'] = player.job_grade,
        ['@faction'] = player.faction,
        ['@faction_grade'] = player.faction_grade
    })

    -- Le joueur reste connecté (seul le personnage change), donc `playerDropped`
    -- ne se déclenche jamais : sans cet appel explicite, module/pedoffline ne
    -- mettrait jamais "au lit" le personnage laissé derrière.
    if LSLegacy.PedOffline and LSLegacy.PedOffline.PutToSleep then
        LSLegacy.PedOffline.PutToSleep(source)
    end

    LSLegacy.Players.Remove(source)

    -- LSLegacy.GeneratorTokenConnecting (appelée par `registerPlayer`) ne
    -- s'exécute qu'une fois par valeur de `addTokenClient[source]` : sans ce
    -- reset, le deuxième passage par `registerPlayer` (après la sélection)
    -- serait pris pour une tentative d'injection et le joueur serait kické
    -- ("Injector detected"). On efface aussi les jetons actuels : ils seront
    -- régénérés et renvoyés au client par GeneratorTokenConnecting.
    LSLegacy.addTokenClient[source] = nil
    LSLegacy.Token[source] = nil
end

-- Exporté pour que module/adminmenu (bouton du menu admin) puisse déclencher
-- exactement le même comportement que la commande, sans dupliquer la logique.
LSLegacy.Multichar = LSLegacy.Multichar or {}

function LSLegacy.Multichar.ReturnToSelection(source)
    local identifier = GetPlayerIdentifierMC(source)
    if not identifier or GetMaxSlots(identifier) <= 1 then
        LSLegacy.Events.SendToClient('notify', source, "LSLegacy", "Vous n'avez pas accès au multicharacter.", "error")
        return
    end

    if not LSLegacy.Players.Get(source) then return end

    SaveAndReleaseCharacter(source)
    TriggerClientEvent('multichar:forceReselect', source)
end

RegisterCommand('multichar', function(source)
    if source == 0 then return end
    LSLegacy.Multichar.ReturnToSelection(source)
end, false)

TriggerClientEvent('chat:addSuggestion', -1, '/multichar', "Revenir à la sélection de personnage (réservé aux comptes multicharacter)")

-- Bouton du menu admin (module/adminmenu/client/main.lua) : passe par le système
-- de jetons sécurisé, puisqu'il n'est utilisable qu'une fois le personnage
-- déjà chargé (contrairement à /multichar, utilisable dès la connexion).
LSLegacy.Events.Register('admin:multichar:returnToSelection', function()
    local source = source
    LSLegacy.Multichar.ReturnToSelection(source)
end)
