--  MODULE POLICE NATIONALE — Serveur principal
--  Création tables SQL, gestion prise de service, spawn véhicule
--  SÉCURITÉ : toutes les actions revalident job/grade depuis ServerPlayers

local rateLimits = {
    ['police:onDuty'] = 10, ['police:offDuty'] = 10, ['police:openLocker'] = 20,
    ['police:openEvidenceLocker'] = 20,
    ['police:armory:open'] = 20, ['police:armory:personalAction'] = 20,
    ['police:armory:collectiveAction'] = 20, ['police:armory:attachAccessory'] = 20,
    ['police:cuff'] = 20, ['police:cuffStart'] = 20, ['police:search'] = 15,
    ['police:palpation'] = 20, ['police:idCheck'] = 20, ['police:licenseCheck'] = 20,
    ['police:escort'] = 20, ['police:putInVehicle'] = 20, ['police:getOutVehicle'] = 20,
    ['police:seizeItem'] = 15, ['police:custody'] = 10, ['police:prison'] = 10,
    ['police:inv:collectFingerprints'] = 15, ['police:inv:collectDNA'] = 15,
    ['police:inv:collectBlood'] = 15, ['police:inv:createScene'] = 10,
    ['police:inv:compareFingerprints'] = 20, ['police:inv:compareDNA'] = 20,
    ['police:radio:join'] = 20, ['police:radio:leave'] = 20,
    ['police:mission:accept'] = 10, ['police:mission:resolve'] = 10,
    ['mdtco:query'] = 40,
    ['police:callouts:accept'] = 10, ['police:callouts:reposition'] = 40,
    -- L'inscription (police:callouts:register) passe désormais par
    -- mdtco:query, déjà limité (ligne au-dessus).
    ['police:callouts:corpseVisible'] = 20, ['police:callouts:reportStreet'] = 15,
    ['police:callouts:refuse'] = 10, ['police:callouts:leave'] = 15,
    ['police:callouts:requestBackup'] = 10, ['police:callouts:acceptBackup'] = 15,
    ['police:callouts:setStatus'] = 30, ['police:callouts:suspectStunned'] = 20,
    ['police:callouts:suspectCuffed'] = 20, ['police:callouts:suspectIdentify'] = 20,
    ['police:callouts:moveAlong'] = 20, ['police:callouts:victimStatement'] = 15,
    ['police:callouts:interrogate'] = 15, ['police:callouts:suspectSearched'] = 20,
    ['police:callouts:suspectDropWeapon'] = 20, ['police:callouts:pickupWeapon'] = 20,
    ['police:callouts:suspectDead'] = 15, ['police:callouts:suspectCombat'] = 30,
    ['police:callouts:suspectSurrender'] = 20, ['police:callouts:suspectEscaped'] = 15,
    ['police:callouts:suspectDelivered'] = 15, ['police:callouts:ambulanceLoaded'] = 15,
    ['police:callouts:objectiveDone'] = 20, ['police:callouts:firstAid'] = 15,
    ['police:callouts:askRadioOff'] = 15, ['police:callouts:radioOff'] = 15,
    ['police:callouts:dismissBystander'] = 15, ['police:callouts:reportHour'] = 10,
    ['police:callouts:askAdmin'] = 10, ['police:callouts:command'] = 15,
    ['police:callouts:spawnFail'] = 10, ['police:callouts:reportSpawn'] = 15,
    ['police:callouts:reportLocation'] = 30, ['police:callouts:reportMismatch'] = 15,
    ['police:callouts:anchorSurvey'] = 10, ['police:callouts:anchorHere'] = 10,
    ['police:callouts:anchorUndo'] = 10, ['police:callouts:adminAction'] = 10,
    ['police:callouts:breathalyzer'] = 15,
    ['police:callouts:autopsy'] = 15, ['police:callouts:familyNotified'] = 15,
    ['police:callouts:examinePoint'] = 20, ['police:callouts:offerPayOff'] = 10,
    ['police:callouts:suspectDropStash'] = 15, ['police:callouts:pickupStash'] = 15,
    ['police:callouts:suspectKillHit'] = 30,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local PoliceOfficers = {}   -- { [source] = { onDuty, service, unit, grade } }

-- Helpers partagés (globaux — utilisés par actions/prison/investigation)

function GetPlayer(src)
    return LSLegacy.Players.Get(src)
end

local function IsPoliceOfficer(src)
    local p = GetPlayer(src)
    return LSLegacy.Jobs.Is(p, Config.Police.Job)
end

function IsPolice(src) return IsPoliceOfficer(src) end

-- Unité RAID/BRI : jamais prise du client. PoliceOfficers[src].unit n'est
-- résolu qu'à la prise de service (police:onDuty) et reste donc périmé si
-- le joueur change d'affectation dans le MDT sans repasser hors-service —
-- on revalide toujours contre mdt_agent_assignments en direct.
function CheckRaidOrBriUnit(src, cb)
    local charId = GetCharacterId(src)
    if not charId then return cb(false) end
    MySQL.Async.fetchScalar(
        "SELECT code FROM mdt_agent_assignments WHERE character_id=@id AND end_date='' ORDER BY id DESC LIMIT 1",
        { ['@id'] = charId },
        function(unitCode)
            cb(unitCode == 'raid' or unitCode == 'bri')
        end
    )
end

-- Grade 8 = Commissaire : accès total à l'armurerie chef de poste / RAID,
-- sans tenir compte des formations ni de l'unité (voir Config.Police.Armory).
function IsCommissaire(src)
    return GetGrade(src) >= 8
end

-- Casier personnel du vestiaire : un DataStore par identifiant, accès réservé au propriétaire
local prevDataStoreGuard = LSLegacy.DataStoreGuard
LSLegacy.DataStoreGuard = function(src, name, action, item)
    if type(name) == "string" and name:sub(1, 14) == "police_locker_" then
        local player = GetPlayer(src)
        if not player then return false end
        return name == 'police_locker_' .. player.identifier
    end
    -- Coffre à preuves : partagé par tous les policiers (pas de restriction par identifiant).
    if name == "police_evidence_locker" then
        return IsPoliceOfficer(src)
    end
    if prevDataStoreGuard then return prevDataStoreGuard(src, name, action, item) end
    return true
end

LSLegacy.Events.Register('police:openEvidenceLocker', function()
    local src = source
    if not IsPoliceOfficer(src) then return end
    local name = 'police_evidence_locker'
    if not LSLegacy.DataStores[name] then
        LSLegacy.DataStore.RegisterDataStore(name, {
            inventory = {}, name = name, type = 'trunk',
            money = 0, dirty = 0, maxWeight = Config.Police.EvidenceLocker.maxWeight,
        })
    end
    LSLegacy.Events.SendToClient('lslegacy:updateDatastore', src, LSLegacy.DataStores)
    LSLegacy.Events.SendToClient('inventory:openContainer', src, name, 'Coffre à preuves', Config.Police.EvidenceLocker.maxWeight)
end)

LSLegacy.Events.Register('police:openLocker', function()
    local src = source
    local player = GetPlayer(src)
    if not player or not IsPoliceOfficer(src) then return end
    local name = 'police_locker_' .. player.identifier
    if not LSLegacy.DataStores[name] then
        LSLegacy.DataStore.RegisterDataStore(name, {
            inventory = {}, name = name, type = 'trunk',
            money = 0, dirty = 0, maxWeight = Config.Police.Locker.maxWeight,
        })
    end
    LSLegacy.Events.SendToClient('lslegacy:updateDatastore', src, LSLegacy.DataStores)
    LSLegacy.Events.SendToClient('inventory:openContainer', src, name, 'Casier personnel', Config.Police.Locker.maxWeight)
end)

function GetGrade(src)
    local p = GetPlayer(src)
    return p and (tonumber(p.job_grade) or 0) or 0
end

-- Les permissions se résolvent dans le département RÉEL du joueur : un
-- adjoint du shérif engagé sur une mission conjointe doit être évalué sur la grille
-- de la shérif, pas sur celle de la police.
function HasPermission(src, perm)
    local dep = (type(GetMdtDepartment) == 'function' and GetMdtDepartment(src)) or 'police'
    return LSLegacy.MDT.HasPermission(dep, GetGrade(src), perm)
end

function GetName(src)
    local p = GetPlayer(src)
    if p and p.characterInfos then
        return (p.characterInfos.Prenom or '') .. ' ' .. (p.characterInfos.NDF or '')
    end
    return GetPlayerName(src) or 'Agent'
end

function GetIdentifier(src)
    local p = GetPlayer(src)
    return p and p.identifier or nil
end

function GetIdent(src) return GetIdentifier(src) end

-- Clé "personnage" (players.id) : identifier seul ne suffit plus depuis le
-- multicharacter, plusieurs personnages d'un même compte partagent le
-- même identifier.
function GetCharacterId(src)
    local p = GetPlayer(src)
    return p and p["boutique-id"] or nil
end

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Police Nationale', msg, t or 'info', Config.Police.NotifyDuration or 30000)
end

function LogDiscord(title, description, color)
    local webhook = Config.MDT.Webhook
    if not webhook or webhook == '' then return end
    PerformHttpRequest(webhook, function() end, 'POST',
        json.encode({
            username = 'Police Nationale',
            embeds   = {{
                title       = title,
                description = description,
                color       = color or 3447003,
                footer      = { text = os.date('%d/%m/%Y %H:%M:%S') },
            }}
        }),
        { ['Content-Type'] = 'application/json' }
    )
end

-- Création des tables SQL

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS police_officers (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        identifier    VARCHAR(60)  NOT NULL,
        character_id  INT          DEFAULT NULL,
        name          VARCHAR(100) NOT NULL DEFAULT '',
        service       VARCHAR(60)  DEFAULT NULL,
        unit          VARCHAR(60)  DEFAULT NULL,
        on_duty       TINYINT(1)   NOT NULL DEFAULT 0,
        duty_since    DATETIME     DEFAULT NULL,
        last_seen     DATETIME     DEFAULT NULL,
        KEY idx_po_identifier (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- police_cuffed : table historique jamais utilisée par le code (le
-- menottage/démenottage est purement en mémoire via statebag, cf.
-- module/police/server/actions.lua) — supprimée par la migration Lot 2
-- (module/multichar/sql/lot2_character_scoping.sql), plus recréée ici.

-- Bodycam supprimée : on retire les anciennes tables (peut être enlevé après un démarrage).
MySQL.Async.execute("DROP TABLE IF EXISTS police_bodycam_logs", {})
MySQL.Async.execute("DROP TABLE IF EXISTS police_bodycam_sessions", {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS police_stats (
        id             INT AUTO_INCREMENT PRIMARY KEY,
        identifier     VARCHAR(60)  NOT NULL,
        character_id   INT          DEFAULT NULL,
        name           VARCHAR(100) NOT NULL DEFAULT '',
        custody_count  INT          NOT NULL DEFAULT 0,
        prison_count   INT          NOT NULL DEFAULT 0,
        fines_count    INT          NOT NULL DEFAULT 0,
        fines_amount   INT          NOT NULL DEFAULT 0,
        searches_count INT          NOT NULL DEFAULT 0,
        evidence_count INT          NOT NULL DEFAULT 0,
        duty_seconds   INT          NOT NULL DEFAULT 0,
        UNIQUE KEY uq_stats_character (character_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- Colonnes autorisées en écriture (whitelist : le nom de colonne est
-- interpolé dans la requête, jamais fourni par le client).
local StatColumns = {
    custody_count = true, prison_count = true, fines_count = true, fines_amount = true,
    searches_count = true, evidence_count = true, duty_seconds = true,
}

-- Incrémente une statistique d'agent (police ET shérif, ces derniers
-- partageant les mêmes actions de terrain). Crée la ligne au besoin.
function IncrementPoliceStat(ident, charId, name, column, amount)
    if not StatColumns[column] or not ident then return end
    amount = amount or 1
    MySQL.Async.execute(
        'INSERT INTO police_stats (identifier, character_id, name, ' .. column .. ') ' ..
        'VALUES (@id, @charId, @name, @amt) ' ..
        'ON DUPLICATE KEY UPDATE ' .. column .. ' = ' .. column .. ' + @amt, name = @name',
        { ['@id'] = ident, ['@charId'] = charId, ['@name'] = name, ['@amt'] = amount }
    )
end

-- Récupération des stats (soi-même, ou un autre agent avec manage_personnel)
LSLegacy.Security.RegisterRateLimit('police:getStats', 10)

LSLegacy.Events.Register('police:getStats', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end

    local targetSrc = tonumber(data and data.target) or src
    if targetSrc ~= src and not HasPermission(src, 'manage_personnel') then
        Notify(src, Lang.Police.grade_required, 'error')
        return
    end

    local tp = GetPlayer(targetSrc)
    if not tp then return end
    local charId = tp["boutique-id"]

    MySQL.Async.fetchAll(
        'SELECT * FROM police_stats WHERE character_id=@id LIMIT 1',
        { ['@id'] = charId },
        function(rows)
            local row = rows and rows[1]
            TriggerClientEvent('police:statsResult', src, {
                name          = GetName(targetSrc),
                custodyCount  = row and row.custody_count or 0,
                prisonCount   = row and row.prison_count or 0,
                finesCount    = row and row.fines_count or 0,
                finesAmount   = row and row.fines_amount or 0,
                searchesCount = row and row.searches_count or 0,
                evidenceCount = row and row.evidence_count or 0,
                dutySeconds   = row and row.duty_seconds or 0,
            })
        end
    )
end)

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS police_radio_channels (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        source_id     INT         NOT NULL,
        identifier    VARCHAR(60) NOT NULL,
        character_id  INT         DEFAULT NULL,
        channel_id    INT         NOT NULL,
        joined_at     DATETIME    DEFAULT CURRENT_TIMESTAMP,
        KEY idx_prc_source (source_id),
        KEY idx_prc_channel (channel_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- PRISE DE SERVICE

LSLegacy.Events.Register('police:onDuty', function(data)
    local src = source
    if not IsPoliceOfficer(src) then return end
    if not data then return end

    local grade  = GetGrade(src)
    local ident  = GetIdentifier(src)
    local charId = GetCharacterId(src)
    local name   = GetName(src)

    -- L'unité n'est jamais prise du client : elle vient de l'affectation
    -- active gérée par la hiérarchie dans le MDT (fiche agent), à défaut
    -- Police Secours (unité de base, cf. grades 0-1).
    MySQL.Async.fetchScalar(
        "SELECT code FROM mdt_agent_assignments WHERE character_id=@id AND end_date='' ORDER BY id DESC LIMIT 1",
        { ['@id'] = charId },
        function(unitCode)
            local unit = unitCode or 'police_secours'

            PoliceOfficers[src] = {
                onDuty    = true,
                service   = data.service,
                unit      = unit,
                grade     = grade,
                name      = name,
                dutyStart = os.time(),
            }

            -- Statebag autoritaire (lisible par toute ressource : ex. fourrière)
            Player(src).state:set('policeOnDuty', true, true)

            -- ON DUPLICATE KEY UPDATE se déclenche sur UNIQUE(character_id), pas sur
            -- identifier (qui peut être partagé par plusieurs personnages du même
            -- compte depuis le multicharacter) — sans ça, une nouvelle ligne était
            -- créée à chaque prise de service.
            MySQL.Async.execute(
                'INSERT INTO police_officers (identifier, character_id, name, service, unit, on_duty, duty_since, last_seen) ' ..
                'VALUES (@id, @charId, @name, @service, @unit, 1, NOW(), NOW()) ' ..
                'ON DUPLICATE KEY UPDATE identifier=@id, name=@name, service=@service, unit=@unit, on_duty=1, duty_since=NOW(), last_seen=NOW()',
                { ['@id'] = ident, ['@charId'] = charId, ['@name'] = name,
                  ['@service'] = data.service, ['@unit'] = unit }
            )

            TriggerClientEvent('police:onDutyResult', src, { unit = unit })

            LogDiscord('Prise de service',
                '**' .. name .. '** (' .. LSLegacy.MDT.GetGradeLabel('police', grade) .. ')' ..
                ' — Service : ' .. (data.service or '?') .. ' / Unité : ' .. unit, 3066993)
        end
    )
end)

LSLegacy.Events.Register('police:offDuty', function()
    local src   = source
    if not PoliceOfficers[src] then return end

    local charId = GetCharacterId(src)
    MySQL.Async.execute(
        'UPDATE police_officers SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
        { ['@id'] = charId }
    )

    local name = PoliceOfficers[src].name
    local dutyStart = PoliceOfficers[src].dutyStart
    if dutyStart then
        IncrementPoliceStat(GetIdentifier(src), charId, name, 'duty_seconds', os.time() - dutyStart)
    end
    PoliceOfficers[src] = nil
    Player(src).state:set('policeOnDuty', false, true)

    -- Déconnecter de la radio
    TriggerEvent('police:radio:leaveAll', src)

    -- Sortir du groupe d'intervention (missions PNJ)
    TriggerEvent('police:callouts:officerOffDuty', src)

    LogDiscord('Fin de service', '**' .. name .. '** a terminé son service.', 15158332)
end)

-- OFFICIERS EN SERVICE — récupération pour d'autres modules

function GetPoliceOfficers() return PoliceOfficers end

function IsOfficerOnDuty(src)
    return PoliceOfficers[src] ~= nil and PoliceOfficers[src].onDuty == true
end

-- Nettoyage à la déconnexion
AddEventHandler('playerDropped', function()
    local src = source
    if PoliceOfficers[src] then
        local charId = GetCharacterId(src)
        MySQL.Async.execute(
            'UPDATE police_officers SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
            { ['@id'] = charId }
        )
        local dutyStart = PoliceOfficers[src].dutyStart
        if dutyStart then
            IncrementPoliceStat(GetIdentifier(src), charId, PoliceOfficers[src].name, 'duty_seconds', os.time() - dutyStart)
        end
        PoliceOfficers[src] = nil
    end
end)
