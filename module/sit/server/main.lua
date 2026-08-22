-- Suit qui occupe quelle place, pour éviter deux joueurs sur la même place d'un banc/canapé multi-places. Port de server/server.lua de mnr_sitanywhere.
local occupied = {} -- [entity] = { [seatIndex] = source }

LSLegacy.Callbacks.RegisterServer('sit:server:occupy', function(source, cb, netId, seatIndex)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return cb(false) end

    occupied[entity] = occupied[entity] or {}
    if occupied[entity][seatIndex] then return cb(false) end

    occupied[entity][seatIndex] = source
    cb(true)
end)

LSLegacy.Callbacks.RegisterServer('sit:server:getFree', function(source, cb, netId, hash)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return cb(false) end

    local model = Sit.Models[hash]
    if not model then return cb(false) end

    occupied[entity] = occupied[entity] or {}
    for i = 1, model.maxSeats do
        if not occupied[entity][i] then return cb(i) end
    end
    cb(false)
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
