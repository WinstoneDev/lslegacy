-- Suit qui occupe quelle place, pour éviter deux joueurs sur la même place d'un banc/canapé multi-places. Port de server/server.lua de mnr_sitanywhere.
local occupied = {} -- [entity] = { [seatIndex] = source }

lib.callback.register('sit:server:occupy', function(source, netId, seatIndex)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return false end

    occupied[entity] = occupied[entity] or {}
    if occupied[entity][seatIndex] then return false end

    occupied[entity][seatIndex] = source
    return true
end)

lib.callback.register('sit:server:getFree', function(source, netId, hash)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return false end

    local model = Sit.Models[hash]
    if not model then return false end

    occupied[entity] = occupied[entity] or {}
    for i = 1, model.maxSeats do
        if not occupied[entity][i] then return i end
    end
    return false
end)

RegisterNetEvent('sit:server:free', function(netId)
    local src = source
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) or not occupied[entity] then return end

    for seatIndex, occupant in pairs(occupied[entity]) do
        if occupant == src then
            occupied[entity][seatIndex] = nil
        end
    end

    if not next(occupied[entity]) then
        occupied[entity] = nil
        TriggerClientEvent('sit:client:unregister', src, netId)
    end
end)
