-- Suit qui occupe quelle place, pour éviter deux joueurs sur la même place d'un banc/canapé multi-places. Port de server/server.lua de mnr_sitanywhere.
-- Clé de suivi : netId pour les objets dynamiques réseautés, sinon "static:hash:x:y:z" pour les props YMAP statiques (non résolvables côté serveur).
local occupied = {} -- [seatKey] = { [seatIndex] = source }

LSLegacy.Security.RegisterRateLimit('sit:serverOccupy', 100)
LSLegacy.Security.RegisterRateLimit('sit:serverGetFree', 100)
LSLegacy.Callbacks.RegisterServer('sit:serverOccupy', function(source, cb, seatKey, seatIndex)
    occupied[seatKey] = occupied[seatKey] or {}
    if occupied[seatKey][seatIndex] then return cb(false) end

    occupied[seatKey][seatIndex] = source
    cb(true)
end)

LSLegacy.Callbacks.RegisterServer('sit:serverGetFree', function(source, cb, seatKey, hash)
    local model = Sit.Models[hash]
    if not model then return cb(false) end

    occupied[seatKey] = occupied[seatKey] or {}
    for i = 1, model.maxSeats do
        if not occupied[seatKey][i] then return cb(i) end
    end
    cb(false)
end)

RegisterNetEvent('sit:serverFree', function(seatKey)
    local src = source
    if not occupied[seatKey] then return end

    for seatIndex, occupant in pairs(occupied[seatKey]) do
        if occupant == src then
            occupied[seatKey][seatIndex] = nil
        end
    end

    if not next(occupied[seatKey]) then
        occupied[seatKey] = nil
        TriggerClientEvent('sit:clientUnregister', src, seatKey)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for seatKey, seats in pairs(occupied) do
        for seatIndex, occupant in pairs(seats) do
            if occupant == src then
                seats[seatIndex] = nil
            end
        end
        if not next(seats) then
            occupied[seatKey] = nil
        end
    end
end)
