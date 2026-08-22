LSLegacy.Security.RegisterRateLimit('creatorperso:setBucket', 20)
LSLegacy.Security.RegisterRateLimit('saveskin', 20)
LSLegacy.Security.RegisterRateLimit('creatorperso:setIdentity', 20)

-- ─── Bucket routing (isolement du joueur pendant la création) ──────────────
-- Le client ne choisit plus le bucket lui-même (un client modifié pourrait
-- sinon demander le bucket d'un autre joueur en cours de création). Le
-- serveur dérive un bucket unique à partir du server id, qui ne peut pas
-- entrer en collision avec celui d'un autre joueur connecté.
LSLegacy.Events.Register("creatorperso:setBucket", function(enter)
    local _src = source
    SetPlayerRoutingBucket(_src, enter and (10000 + _src) or 0)
end)

-- ─── Sauvegarde fiable (retry jusqu'à confirmation en BDD) ──────────────────
-- Écrit `column` puis relit la ligne pour vérifier que la valeur a bien été
-- persistée ; retente sinon. Évite qu'un personnage reste avec un skin ou un
-- characterInfos par défaut/périmé si l'écriture initiale échoue/se perd.
local function SaveWithRetry(column, boutiqueId, jsonValue, maxAttempts, delayMs)
    maxAttempts = maxAttempts or 10
    delayMs = delayMs or 500

    for attempt = 1, maxAttempts do
        MySQL.Async.execute('UPDATE players SET ' .. column .. ' = @value WHERE `boutique-id` = @id', {
            ['@id']    = boutiqueId,
            ['@value'] = jsonValue,
        })

        local dbValue, received = nil, false
        MySQL.Async.fetchAll('SELECT ' .. column .. ' FROM players WHERE `boutique-id` = @id', { ['@id'] = boutiqueId }, function(result)
            dbValue  = result and result[1] and result[1][column]
            received = true
        end)
        while not received do Wait(0) end

        if dbValue == jsonValue then
            return true, attempt
        end

        Config.Development.Print(('SaveWithRetry(%s): tentative %d/%d échouée pour boutique-id %s'):format(column, attempt, maxAttempts, tostring(boutiqueId)))
        Wait(delayMs)
    end

    return false, maxAttempts
end

LSLegacy.Events.Register('saveskin', function(skin)
    local _src = source
    local player = LSLegacy.Players.Get(_src)

    if not player then
        Config.Development.Print("Joueur non trouvé: " .. _src)
        return
    end

    local saved, attempts = SaveWithRetry('skin', player["boutique-id"], json.encode(skin))

    if saved then
        player.skin = skin
        Config.Development.Print("Skin sauvegardé pour le joueur: " .. _src .. " (tentative " .. attempts .. ")")
    else
        Config.Development.Print("ÉCHEC sauvegarde skin après " .. attempts .. " tentatives pour le joueur: " .. _src)
    end

    -- Le client attend cet ack avant d'envoyer creatorperso:setIdentity : sans lui,
    -- creatorperso:setIdentity peut relire le skin en BDD avant que l'UPDATE ci-dessus
    -- soit committé (les deux handlers tournent en coroutines concurrentes),
    -- et écraser le skin fraîchement créé avec une valeur périmée.
    LSLegacy.Events.SendToClient('creatorperso:skinSaved', _src, saved)
end)

-- ─── Identité ────────────────────────────────────────────────────────────────
-- Rejette toute valeur contenant des caractères dangereux pour du HTML/JS
-- (ces champs sont réaffichés tels quels dans d'autres modules NUI : MDT,
-- police, gendarmerie, banque...), et borne strictement les longueurs et
-- plages numériques.
local FORBIDDEN_CHARS_PATTERN = "[<>&\"'`]"

local function IsSafeText(str, maxLength)
    if type(str) ~= "string" then return false end
    if #str == 0 or #str > maxLength then return false end
    if string.find(str, FORBIDDEN_CHARS_PATTERN) then return false end
    -- Rejette les caractères de contrôle (hors espace).
    if string.find(str, "%c") then return false end
    return true
end

-- ─── Tenue de base offerte à la création ────────────────────────────────────
-- Données récupérées depuis les inventaires existants des personnages
-- (slot homme / slot femme) pour que la tenue offerte corresponde à celle
-- déjà utilisée en jeu comme "Tenue de base".
local StarterOutfits = {
    M = { arms = {14, 0}, pants = {15, 3}, torso = {7, 2}, shoes = {5, 2}, tshirt = {199, 0} },
    F = { torso = {114, 0}, shoes = {6, 2}, arms = {2, 0}, pants = {8, 0} },
}

local function IsValidDateOfBirth(dob)
    if type(dob) ~= "string" then return false end
    local d, m, y = string.match(dob, "^(%d%d)/(%d%d)/(%d%d%d%d)$")
    if not d then return false end
    d, m, y = tonumber(d), tonumber(m), tonumber(y)
    if m < 1 or m > 12 or d < 1 or d > 31 then return false end
    local currentYear = tonumber(os.date("%Y"))
    if y < 1900 or y > currentYear then return false end
    return true
end

LSLegacy.Events.Register("creatorperso:setIdentity", function(lastName, firstName, dateOfBirth, sex, height, birthPlace)
    local _src = source
    local player = LSLegacy.Players.Get(_src)

    if not player then
        Config.Development.Print("Joueur non trouvé: " .. _src)
        return
    end

    height = tonumber(height)

    if not IsSafeText(lastName, 50) or not IsSafeText(firstName, 50) then
        LSLegacy.Events.SendToClient('notify', _src, "Erreur", "Nom ou prénom invalide", "error")
        LSLegacy.Events.SendToClient('creatorperso:identityResult', _src, false)
        return
    end

    if not IsValidDateOfBirth(dateOfBirth) then
        LSLegacy.Events.SendToClient('notify', _src, "Erreur", "Date de naissance invalide", "error")
        LSLegacy.Events.SendToClient('creatorperso:identityResult', _src, false)
        return
    end

    if sex ~= "M" and sex ~= "F" then
        LSLegacy.Events.SendToClient('notify', _src, "Erreur", "Sexe invalide", "error")
        LSLegacy.Events.SendToClient('creatorperso:identityResult', _src, false)
        return
    end

    if not height or height < 140 or height > 220 then
        LSLegacy.Events.SendToClient('notify', _src, "Erreur", "Taille invalide", "error")
        LSLegacy.Events.SendToClient('creatorperso:identityResult', _src, false)
        return
    end

    if not IsSafeText(birthPlace, 100) then
        LSLegacy.Events.SendToClient('notify', _src, "Erreur", "Lieu de naissance invalide", "error")
        LSLegacy.Events.SendToClient('creatorperso:identityResult', _src, false)
        return
    end

    local infos = {
        NDF = lastName,
        Prenom = firstName,
        DDN = dateOfBirth,
        Sexe = sex,
        Taille = math.floor(height),
        LDN = birthPlace
    }

    local saved, attempts = SaveWithRetry('characterInfos', player["boutique-id"], json.encode(infos))

    if not saved then
        Config.Development.Print("ÉCHEC sauvegarde identité après " .. attempts .. " tentatives pour le joueur: " .. _src)
        LSLegacy.Events.SendToClient('notify', _src, "Erreur", "Impossible d'enregistrer l'identité, réessayez.", "error")
        LSLegacy.Events.SendToClient('creatorperso:identityResult', _src, false)
        return
    end

    player.characterInfos = infos

    -- ── Tenue de base (inventaire + skin) ──────────────────────────────────
    -- Donne la tenue adaptée au sexe choisi dans l'inventaire (slot tenue),
    -- et fusionne ses valeurs de vêtements dans le skin persistant pour que
    -- le ped l'affiche réellement (au lieu des vêtements par défaut du
    -- créateur de personnage).
    local outfitData = StarterOutfits[sex]
    local appliedOutfit = nil

    if outfitData then
        LSLegacy.Inventory.AddItemInInventory(player, 'outfit', 1, 'Tenue de base', nil, outfitData)

        -- Relit le skin depuis la BDD (déjà sauvegardé par 'saveskin' juste
        -- avant cet event) plutôt que de se fier à player.skin en mémoire,
        -- qui n'est pas mis à jour par le handler 'saveskin'.
        local dbSkin, skinReceived = nil, false
        MySQL.Async.fetchAll('SELECT skin FROM players WHERE `boutique-id` = @id', { ['@id'] = player["boutique-id"] }, function(result)
            dbSkin = result and result[1] and result[1].skin
            skinReceived = true
        end)
        while not skinReceived do Wait(0) end

        local skin = (dbSkin and dbSkin ~= '' and json.decode(dbSkin)) or {}
        for slot, vals in pairs(outfitData) do
            skin[slot .. '_1'] = vals[1]
            skin[slot .. '_2'] = vals[2]
        end

        local skinSaved = SaveWithRetry('skin', player["boutique-id"], json.encode(skin))
        if skinSaved then
            player.skin = skin
            appliedOutfit = outfitData
        else
            Config.Development.Print("ÉCHEC application tenue de base pour le joueur: " .. _src)
        end
    end

    Config.Development.Print("Identité définie pour le joueur: " .. _src .. " - " .. firstName .. " " .. lastName .. " (tentative " .. attempts .. ")")
    LSLegacy.Events.SendToClient('creatorperso:identityResult', _src, true, appliedOutfit)
end)
