-- Création tables SQL, gestion prise de service (par magasin). Toutes les actions revalident job/grade depuis ServerPlayers.

local rateLimits = {
    ['ltd:onDuty'] = 10, ['ltd:offDuty'] = 10, ['ltd:requestShelfStock'] = 20,
    ['ltd:requestReserveStock'] = 20, ['ltd:sellItem'] = 20, ['ltd:restockShelf'] = 15,
    ['ltd:fillReserve'] = 15, ['ltd:triggerAlarm'] = 10, ['ltd:stealItem'] = 15,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local LtdAgents = {}   -- { [source] = { onDuty, grade, storeId } }

local function GetPlayer(src)
    return LSLegacy.Players.Get(src)
end

local function IsEmployee(src)
    local p = GetPlayer(src)
    return LSLegacy.Jobs.Is(p, Config.LTD.Job)
end

local function GetGrade(src)
    local p = GetPlayer(src)
    return p and (tonumber(LSLegacy.Jobs.GetGrade(p)) or 0) or 0
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

local function IsValidStore(storeId)
    for _, s in ipairs(Config.LTD.Stores) do
        if s.id == storeId then return true end
    end
    return false
end

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS ltd_agents (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        identifier    VARCHAR(60)  NOT NULL,
        character_id  INT          DEFAULT NULL,
        store_id      VARCHAR(60)  DEFAULT NULL,
        on_duty       TINYINT(1)   NOT NULL DEFAULT 0,
        duty_since    DATETIME     DEFAULT NULL,
        last_seen     DATETIME     DEFAULT NULL,
        KEY idx_la_identifier (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

LSLegacy.Events.Register('ltd:onDuty', function(data)
    local src = source
    if not IsEmployee(src) then return end
    if not data or not IsValidStore(data.storeId) then return end

    LtdAgents[src] = { onDuty = true, grade = GetGrade(src), storeId = data.storeId }

    -- ON DUPLICATE KEY UPDATE se déclenche sur UNIQUE(character_id), pas sur
    -- identifier (partageable entre personnages du même compte) — sans ça,
    -- une nouvelle ligne était créée à chaque prise de service.
    MySQL.Async.execute(
        'INSERT INTO ltd_agents (identifier, character_id, store_id, on_duty, duty_since, last_seen) VALUES (@id, @charId, @store, 1, NOW(), NOW()) ' ..
        'ON DUPLICATE KEY UPDATE identifier=@id, store_id=@store, on_duty=1, duty_since=NOW(), last_seen=NOW()',
        { ['@id'] = GetIdentifier(src), ['@charId'] = GetCharacterId(src), ['@store'] = data.storeId }
    )
end)

LSLegacy.Events.Register('ltd:offDuty', function()
    local src = source
    if not LtdAgents[src] then return end

    MySQL.Async.execute(
        'UPDATE ltd_agents SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
        { ['@id'] = GetCharacterId(src) }
    )
    LtdAgents[src] = nil
end)

function GetLtdAgents() return LtdAgents end

function IsLtdOnDuty(src)
    return LtdAgents[src] ~= nil and LtdAgents[src].onDuty == true
end

---@param src number
---@param storeId string
---@return boolean
function IsLtdOnDutyAt(src, storeId)
    return LtdAgents[src] ~= nil and LtdAgents[src].onDuty == true and LtdAgents[src].storeId == storeId
end

-- Agents en service sur un magasin précis.
---@param storeId string
function GetLtdAgentsAt(storeId)
    local result = {}
    for src, agent in pairs(LtdAgents) do
        if agent.onDuty and agent.storeId == storeId then
            result[src] = agent
        end
    end
    return result
end

AddEventHandler('playerDropped', function()
    local src = source
    if LtdAgents[src] then
        MySQL.Async.execute(
            'UPDATE ltd_agents SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
            { ['@id'] = GetCharacterId(src) }
        )
        LtdAgents[src] = nil
    end
end)
