-- Relais serveur : ne fait que valider la distance et relayer l'événement, toute la logique d'animation est côté client.
-- Favoris stockés par personnage (players.`boutique-id`), pas par compte, pour ne pas les partager entre personnages.

local rateLimits = {
    ['lslegacy_emotes:requestShared'] = 20, ['lslegacy_emotes:confirmShared'] = 20,
    ['lslegacy_emotes:cancelShared'] = 30, ['lslegacy_emotes:getFavorites'] = 10,
    ['lslegacy_emotes:toggleFavorite'] = 30,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS `emotes_favorites` (
        `character_id` INT(11) NOT NULL,
        `emote_key` VARCHAR(80) NOT NULL,
        PRIMARY KEY (`character_id`, `emote_key`)
    )
]])

local function getCharacterId(src)
    local player = LSLegacy.Players.Get(src)
    return player and player["boutique-id"] or nil
end

LSLegacy.Events.Register('lslegacy_emotes:getFavorites', function()
    local src = source
    local characterId = getCharacterId(src)
    if not characterId then return end

    MySQL.Async.fetchAll('SELECT emote_key FROM emotes_favorites WHERE character_id = @id', {
        ['@id'] = characterId,
    }, function(rows)
        local keys = {}
        for _, row in ipairs(rows) do
            keys[#keys + 1] = row.emote_key
        end
        TriggerClientEvent('lslegacy_emotes:clientSetFavorites', src, keys)
    end)
end)

LSLegacy.Events.Register('lslegacy_emotes:toggleFavorite', function(emoteKey)
    local src = source
    local characterId = getCharacterId(src)
    if not characterId or type(emoteKey) ~= 'string' or #emoteKey == 0 or #emoteKey > 80 then return end

    MySQL.Async.fetchAll('SELECT 1 FROM emotes_favorites WHERE character_id = @id AND emote_key = @key', {
        ['@id'] = characterId,
        ['@key'] = emoteKey,
    }, function(rows)
        if rows[1] then
            MySQL.Async.execute('DELETE FROM emotes_favorites WHERE character_id = @id AND emote_key = @key', {
                ['@id'] = characterId,
                ['@key'] = emoteKey,
            })
        else
            MySQL.Async.execute('INSERT INTO emotes_favorites (character_id, emote_key) VALUES (@id, @key)', {
                ['@id'] = characterId,
                ['@key'] = emoteKey,
            })
        end
    end)
end)

local MAX_DISTANCE = 3.0

local function playerDistance(a, b)
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if pedA == 0 or pedB == 0 then return 999.0 end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB))
end

LSLegacy.Events.Register('lslegacy_emotes:requestShared', function(targetServerId, emoteId)
    local src = source
    local target = tonumber(targetServerId)
    if not target or GetPlayerName(target) == nil then return end
    if playerDistance(src, target) > MAX_DISTANCE then return end

    TriggerClientEvent('lslegacy_emotes:clientRequestShared', target, emoteId, src)
end)

LSLegacy.Events.Register('lslegacy_emotes:confirmShared', function(requesterServerId, emoteId, targetEmoteId)
    local src = source
    local requester = tonumber(requesterServerId)
    if not requester or GetPlayerName(requester) == nil then return end
    if playerDistance(src, requester) > MAX_DISTANCE then return end

    TriggerClientEvent('lslegacy_emotes:clientPlayShared', requester, emoteId, src)
    TriggerClientEvent('lslegacy_emotes:clientPlaySharedTarget', src, targetEmoteId, requester)
end)

LSLegacy.Events.Register('lslegacy_emotes:cancelShared', function(otherServerId)
    local src = source
    local target = tonumber(otherServerId)
    if not target or GetPlayerName(target) == nil then return end
    TriggerClientEvent('lslegacy_emotes:clientCancelShared', target, src)
end)
