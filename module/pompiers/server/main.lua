--  MODULE SAPEURS-POMPIERS — Serveur principal
--  Création tables SQL, gestion prise de service, spawn véhicule
--  SÉCURITÉ : toutes les actions revalident job/grade depuis ServerPlayers

LSLegacy.Security.RegisterRateLimit('pompiers:onDuty', 10)
LSLegacy.Security.RegisterRateLimit('pompiers:offDuty', 10)
LSLegacy.Security.RegisterRateLimit('pompiers:spawnVehicle', 15)
LSLegacy.Security.RegisterRateLimit('pompiers:rescue', 15)

local PompiersAgents = {}   -- { [source] = { onDuty, grade, name } }

-- Helpers sécurité

local function GetPlayer(src)
    return LSLegacy.Players.Get(src)
end

local function IsPompier(src)
    local p = GetPlayer(src)
    return LSLegacy.Jobs.Is(p, Config.Pompiers.Job)
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
    return GetPlayerName(src) or 'Sapeur-Pompier'
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
    LSLegacy.Events.SendToClient('notify', src, 'Sapeurs-Pompiers', msg, t or 'info', 5000)
end

-- Création des tables SQL

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS pompiers_agents (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        identifier    VARCHAR(60)  NOT NULL,
        character_id  INT          DEFAULT NULL,
        name          VARCHAR(100) NOT NULL DEFAULT '',
        on_duty       TINYINT(1)   NOT NULL DEFAULT 0,
        duty_since    DATETIME     DEFAULT NULL,
        last_seen     DATETIME     DEFAULT NULL,
        KEY idx_pa_identifier (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- PRISE DE SERVICE

LSLegacy.Events.Register('pompiers:onDuty', function()
    local src = source
    if not IsPompier(src) then return end

    local grade  = GetGrade(src)
    local ident  = GetIdentifier(src)
    local charId = GetCharacterId(src)
    local name   = GetName(src)

    PompiersAgents[src] = { onDuty = true, grade = grade, name = name }

    -- ON DUPLICATE KEY UPDATE se déclenche sur UNIQUE(character_id), pas sur
    -- identifier (partageable entre personnages du même compte depuis le
    -- multicharacter) — sans ça, une nouvelle ligne était créée à chaque
    -- prise de service.
    MySQL.Async.execute(
        'INSERT INTO pompiers_agents (identifier, character_id, name, on_duty, duty_since, last_seen) ' ..
        'VALUES (@id, @charId, @name, 1, NOW(), NOW()) ' ..
        'ON DUPLICATE KEY UPDATE identifier=@id, name=@name, on_duty=1, duty_since=NOW(), last_seen=NOW()',
        { ['@id'] = ident, ['@charId'] = charId, ['@name'] = name }
    )
end)

LSLegacy.Events.Register('pompiers:offDuty', function()
    local src = source
    if not PompiersAgents[src] then return end

    local charId = GetCharacterId(src)
    MySQL.Async.execute(
        'UPDATE pompiers_agents SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
        { ['@id'] = charId }
    )
    PompiersAgents[src] = nil
end)

-- SPAWN VÉHICULE

LSLegacy.Events.Register('pompiers:spawnVehicle', function(data)
    local src = source
    if not IsPompier(src) or not PompiersAgents[src] then return end
    if not data or not data.model then return end

    local grade    = GetGrade(src)
    local minGrade = data.grade or 0
    if grade < minGrade then
        Notify(src, 'Votre grade est insuffisant pour ce véhicule.', 'error')
        return
    end

    TriggerClientEvent('pompiers:spawnVehicleClient', src, { model = data.model })
end)

-- AGENTS EN SERVICE — récupération pour d'autres modules

function GetPompiersAgents() return PompiersAgents end

function IsPompierOnDuty(src)
    return PompiersAgents[src] ~= nil and PompiersAgents[src].onDuty == true
end

-- Nettoyage à la déconnexion
AddEventHandler('playerDropped', function()
    local src = source
    if PompiersAgents[src] then
        local charId = GetCharacterId(src)
        MySQL.Async.execute(
            'UPDATE pompiers_agents SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
            { ['@id'] = charId }
        )
        PompiersAgents[src] = nil
    end
end)
