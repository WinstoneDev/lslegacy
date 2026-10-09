--  MODULE EMS — Serveur principal
--  Création tables SQL, gestion prise de service, spawn véhicule
--  SÉCURITÉ : toutes les actions revalident job/grade depuis ServerPlayers

local rateLimits = {
    ['ems:onDuty'] = 10, ['ems:offDuty'] = 10,
    ['ems:restock'] = 15, ['ems:revive'] = 15, ['ems:reviveStartPose'] = 15,
    ['ems:hiOpen'] = 15, ['ems:hiUseItem'] = 20, ['ems:hiPoll'] = 40, ['ems:hiDamage'] = 40,
    ['ems:requestDutyState'] = 50,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local EmsAgents = {}   -- { [source] = { onDuty, grade, name } }

-- Helpers sécurité

local function GetPlayer(src)
    return LSLegacy.Players.Get(src)
end

local function IsEmsAgent(src)
    local p = GetPlayer(src)
    return LSLegacy.Jobs.Is(p, Config.EMS.Job)
end

local function GetGrade(src)
    local p = GetPlayer(src)
    return p and (tonumber(LSLegacy.Jobs.GetGrade(p)) or 0) or 0
end

local function GetName(src)
    local p = GetPlayer(src)
    if p and p.characterInfos then
        return (p.characterInfos.Prenom or '') .. ' ' .. (p.characterInfos.NDF or '')
    end
    return GetPlayerName(src) or 'Secouriste'
end

local function GetIdentifier(src)
    local p = GetPlayer(src)
    return p and p.identifier or nil
end

-- Clé "personnage" (players.id) : identifier seul ne suffit plus depuis le
-- multicharacter, plusieurs personnages d'un même compte partagent le
-- même identifier.
local function GetCharacterId(src)
    local p = GetPlayer(src)
    return p and p["boutique-id"] or nil
end

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Emergency Medical Services', msg, t or 'info', 5000)
end

-- Création des tables SQL

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS ems_agents (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        identifier    VARCHAR(60)  NOT NULL,
        character_id  INT          DEFAULT NULL,
        name          VARCHAR(100) NOT NULL DEFAULT '',
        on_duty       TINYINT(1)   NOT NULL DEFAULT 0,
        duty_since    DATETIME     DEFAULT NULL,
        last_seen     DATETIME     DEFAULT NULL,
        KEY idx_sa_identifier (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- PRISE DE SERVICE

LSLegacy.Events.Register('ems:onDuty', function()
    local src = source
    if not IsEmsAgent(src) then return end

    local grade  = GetGrade(src)
    local ident  = GetIdentifier(src)
    local charId = GetCharacterId(src)
    local name   = GetName(src)

    EmsAgents[src] = { onDuty = true, grade = grade, name = name }

    -- ON DUPLICATE KEY UPDATE se déclenche sur UNIQUE(character_id), pas sur
    -- identifier (partageable entre personnages du même compte) — sans ça,
    -- une nouvelle ligne était créée à chaque prise de service.
    MySQL.Async.execute(
        'INSERT INTO ems_agents (identifier, character_id, name, on_duty, duty_since, last_seen) ' ..
        'VALUES (@id, @charId, @name, 1, NOW(), NOW()) ' ..
        'ON DUPLICATE KEY UPDATE identifier=@id, name=@name, on_duty=1, duty_since=NOW(), last_seen=NOW()',
        { ['@id'] = ident, ['@charId'] = charId, ['@name'] = name }
    )
end)

LSLegacy.Events.Register('ems:offDuty', function()
    local src = source
    if not EmsAgents[src] then return end

    local charId = GetCharacterId(src)
    MySQL.Async.execute(
        'UPDATE ems_agents SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
        { ['@id'] = charId }
    )
    EmsAgents[src] = nil
end)

-- RESYNCHRONISATION DE L'ÉTAT DE SERVICE
-- Le client remet EMS.OnDuty à false à chaque rechargement de script
-- (restart de ressource, relog), alors que EmsAgents survit côté serveur.
-- Les cibles ox_target de l'EMS ne dépendant que du flag client, elles
-- disparaissaient alors en silence bien que le MDT affiche l'agent en
-- service. Le client redemande donc son état au démarrage.
LSLegacy.Events.Register('ems:requestDutyState', function()
    local src = source

    if IsEmsOnDuty(src) then
        TriggerClientEvent('ems:setDutyState', src, true)
        return
    end

    -- Un restart de ressource vide EmsAgents sans passer par playerDropped :
    -- la prise de service reste alors inscrite en base (on_duty=1) alors que
    -- le serveur n'en sait plus rien, et l'agent se retrouvait silencieusement
    -- hors service. On la restaure donc depuis la BDD — fiable, puisque toute
    -- vraie déconnexion y remet on_duty=0.
    local charId = GetCharacterId(src)
    if not IsEmsAgent(src) or not charId then
        TriggerClientEvent('ems:setDutyState', src, false)
        return
    end

    MySQL.Async.fetchAll(
        'SELECT on_duty FROM ems_agents WHERE character_id=@id LIMIT 1',
        { ['@id'] = charId },
        function(rows)
            local onDuty = (rows and rows[1] and tonumber(rows[1].on_duty) == 1) or false
            if onDuty then
                EmsAgents[src] = { onDuty = true, grade = GetGrade(src), name = GetName(src) }
            end
            TriggerClientEvent('ems:setDutyState', src, onDuty)
        end
    )
end)

-- APPEL PATIENT (relayé depuis lslegacy:injuryCallEMS)

AddEventHandler('ems:patientCall', function(data)
    if not data then return end
    for src, agent in pairs(EmsAgents) do
        if agent.onDuty then
            TriggerClientEvent('ems:patientCallReceived', src, { coords = data.coords })
        end
    end
end)

-- AGENTS EN SERVICE — récupération pour d'autres modules

function GetEmsAgents() return EmsAgents end

function IsEmsOnDuty(src)
    return EmsAgents[src] ~= nil and EmsAgents[src].onDuty == true
end

-- Nettoyage à la déconnexion
AddEventHandler('playerDropped', function()
    local src = source
    if EmsAgents[src] then
        local charId = GetCharacterId(src)
        MySQL.Async.execute(
            'UPDATE ems_agents SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
            { ['@id'] = charId }
        )
        EmsAgents[src] = nil
    end
end)
