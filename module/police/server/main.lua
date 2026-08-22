--  MODULE POLICE NATIONALE — Serveur principal
--  Création tables SQL, gestion prise de service, spawn véhicule
--  SÉCURITÉ : toutes les actions revalident job/grade depuis ServerPlayers

local rateLimits = {
    ['police:onDuty'] = 10, ['police:offDuty'] = 10, ['police:spawnVehicle'] = 15,
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
    ['police:callouts:askCrews'] = 15, ['police:callouts:register'] = 10,
    ['police:callouts:accept'] = 10, ['police:callouts:reposition'] = 40,
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
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local PoliceOfficers = {}   -- { [source] = { onDuty, service, unit, grade } }

-- Helpers partagés (globaux — utilisés par actions/prison/investigation)

function GetPlayer(src)
    return LSLegacy.GetPlayerFromId(src)
end

local function IsPoliceOfficer(src)
    local p = GetPlayer(src)
    return p and p.job == Config.Police.Job
end

function IsPolice(src) return IsPoliceOfficer(src) end

function GetGrade(src)
    local p = GetPlayer(src)
    return p and (tonumber(p.job_grade) or 0) or 0
end

-- Les permissions se résolvent dans le département RÉEL du joueur : un
-- gendarme engagé sur une mission conjointe doit être évalué sur la grille
-- de la gendarmerie, pas sur celle de la police.
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
    TriggerClientEvent(Config.Police.NotifyEvent, src, 'Police Nationale', msg,
        Config.Police.NotifyDuration or 30000, t or 'info')
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

LSLegacy.RegisterServerEvent('police:onDuty', function(data)
    local src = source
    if not IsPoliceOfficer(src) then return end
    if not data then return end

    local grade  = GetGrade(src)
    local ident  = GetIdentifier(src)
    local charId = GetCharacterId(src)
    local name   = GetName(src)

    PoliceOfficers[src] = {
        onDuty   = true,
        service  = data.service,
        unit     = data.unit,
        grade    = grade,
        name     = name,
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
          ['@service'] = data.service, ['@unit'] = data.unit }
    )

    LogDiscord('Prise de service',
        '**' .. name .. '** (' .. LSLegacy.MDT.GetGradeLabel('police', grade) .. ')' ..
        ' — Service : ' .. (data.service or '?') .. ' / Unité : ' .. (data.unit or '?'), 3066993)
end)

LSLegacy.RegisterServerEvent('police:offDuty', function()
    local src   = source
    if not PoliceOfficers[src] then return end

    local charId = GetCharacterId(src)
    MySQL.Async.execute(
        'UPDATE police_officers SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
        { ['@id'] = charId }
    )

    local name = PoliceOfficers[src].name
    PoliceOfficers[src] = nil
    Player(src).state:set('policeOnDuty', false, true)

    -- Déconnecter de la radio
    TriggerEvent('police:radio:leaveAll', src)

    -- Sortir du groupe d'intervention (missions PNJ)
    TriggerEvent('police:callouts:officerOffDuty', src)

    LogDiscord('Fin de service', '**' .. name .. '** a terminé son service.', 15158332)
end)

-- SPAWN VÉHICULE

LSLegacy.RegisterServerEvent('police:spawnVehicle', function(data)
    local src   = source
    if not IsPoliceOfficer(src) or not PoliceOfficers[src] then return end
    if not data or not data.model then return end

    local grade    = GetGrade(src)
    local minGrade = data.grade or 0
    if grade < minGrade then
        Notify(src, 'Votre grade est insuffisant pour ce véhicule.', 'error')
        return
    end

    TriggerClientEvent('police:spawnVehicleClient', src, { model = data.model })
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
        PoliceOfficers[src] = nil
    end
end)
