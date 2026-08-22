--  MODULE SAMU — Serveur principal
--  Création tables SQL, gestion prise de service, spawn véhicule
--  SÉCURITÉ : toutes les actions revalident job/grade depuis ServerPlayers

local rateLimits = {
    ['samu:onDuty'] = 10, ['samu:offDuty'] = 10, ['samu:spawnVehicle'] = 15,
    ['samu:restock'] = 15, ['samu:revive'] = 15,
    ['samu:hi:open'] = 15, ['samu:hi:useItem'] = 20, ['samu:hi:poll'] = 40, ['samu:hi:damage'] = 40,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local SamuAgents = {}   -- { [source] = { onDuty, grade, name } }

-- Helpers sécurité

local function GetPlayer(src)
    return LSLegacy.Players.Get(src)
end

local function IsSamuAgent(src)
    local p = GetPlayer(src)
    return p and p.job == Config.SAMU.Job
end

local function GetGrade(src)
    local p = GetPlayer(src)
    return p and (tonumber(p.job_grade) or 0) or 0
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
    TriggerClientEvent(Config.SAMU.NotifyEvent, src, 'SAMU', msg, 5000, t or 'info')
end

-- Création des tables SQL

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS samu_agents (
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

LSLegacy.RegisterServerEvent('samu:onDuty', function()
    local src = source
    if not IsSamuAgent(src) then return end

    local grade  = GetGrade(src)
    local ident  = GetIdentifier(src)
    local charId = GetCharacterId(src)
    local name   = GetName(src)

    SamuAgents[src] = { onDuty = true, grade = grade, name = name }

    -- ON DUPLICATE KEY UPDATE se déclenche sur UNIQUE(character_id), pas sur
    -- identifier (partageable entre personnages du même compte) — sans ça,
    -- une nouvelle ligne était créée à chaque prise de service.
    MySQL.Async.execute(
        'INSERT INTO samu_agents (identifier, character_id, name, on_duty, duty_since, last_seen) ' ..
        'VALUES (@id, @charId, @name, 1, NOW(), NOW()) ' ..
        'ON DUPLICATE KEY UPDATE identifier=@id, name=@name, on_duty=1, duty_since=NOW(), last_seen=NOW()',
        { ['@id'] = ident, ['@charId'] = charId, ['@name'] = name }
    )
end)

LSLegacy.RegisterServerEvent('samu:offDuty', function()
    local src = source
    if not SamuAgents[src] then return end

    local charId = GetCharacterId(src)
    MySQL.Async.execute(
        'UPDATE samu_agents SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
        { ['@id'] = charId }
    )
    SamuAgents[src] = nil
end)

-- RESYNCHRONISATION DE L'ÉTAT DE SERVICE
-- Le client remet SAMU.OnDuty à false à chaque rechargement de script
-- (restart de ressource, relog), alors que SamuAgents survit côté serveur.
-- Les cibles ox_target du SAMU ne dépendant que du flag client, elles
-- disparaissaient alors en silence bien que le MDT affiche l'agent en
-- service. Le client redemande donc son état au démarrage.
LSLegacy.RegisterServerEvent('samu:requestDutyState', function()
    local src = source

    if IsSamuOnDuty(src) then
        TriggerClientEvent('samu:setDutyState', src, true)
        return
    end

    -- Un restart de ressource vide SamuAgents sans passer par playerDropped :
    -- la prise de service reste alors inscrite en base (on_duty=1) alors que
    -- le serveur n'en sait plus rien, et l'agent se retrouvait silencieusement
    -- hors service. On la restaure donc depuis la BDD — fiable, puisque toute
    -- vraie déconnexion y remet on_duty=0.
    local charId = GetCharacterId(src)
    if not IsSamuAgent(src) or not charId then
        TriggerClientEvent('samu:setDutyState', src, false)
        return
    end

    MySQL.Async.fetchAll(
        'SELECT on_duty FROM samu_agents WHERE character_id=@id LIMIT 1',
        { ['@id'] = charId },
        function(rows)
            local onDuty = (rows and rows[1] and tonumber(rows[1].on_duty) == 1) or false
            if onDuty then
                SamuAgents[src] = { onDuty = true, grade = GetGrade(src), name = GetName(src) }
            end
            TriggerClientEvent('samu:setDutyState', src, onDuty)
        end
    )
end)

-- SPAWN VÉHICULE

LSLegacy.RegisterServerEvent('samu:spawnVehicle', function(data)
    local src = source
    if not IsSamuAgent(src) or not SamuAgents[src] then return end
    if not data or not data.model then return end

    local grade    = GetGrade(src)
    local minGrade = data.grade or 0
    if grade < minGrade then
        Notify(src, 'Votre grade est insuffisant pour ce véhicule.', 'error')
        return
    end

    TriggerClientEvent('samu:spawnVehicleClient', src, { model = data.model })
end)

-- APPEL PATIENT (relayé depuis LSLegacy:injury:callEMS)

AddEventHandler('samu:patientCall', function(data)
    if not data then return end
    for src, agent in pairs(SamuAgents) do
        if agent.onDuty then
            TriggerClientEvent('samu:patientCallReceived', src, { coords = data.coords })
        end
    end
end)

-- AGENTS EN SERVICE — récupération pour d'autres modules

function GetSamuAgents() return SamuAgents end

function IsSamuOnDuty(src)
    return SamuAgents[src] ~= nil and SamuAgents[src].onDuty == true
end

-- Nettoyage à la déconnexion
AddEventHandler('playerDropped', function()
    local src = source
    if SamuAgents[src] then
        local charId = GetCharacterId(src)
        MySQL.Async.execute(
            'UPDATE samu_agents SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
            { ['@id'] = charId }
        )
        SamuAgents[src] = nil
    end
end)
