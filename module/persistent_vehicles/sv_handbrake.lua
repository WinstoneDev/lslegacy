-- Relaie le son de serrage/desserrage aux joueurs dans un rayon de 50m autour du véhicule.
LSLegacy.RegisterServerEvent("handbrake:broadcastSound", function(netId, isEngage)
    local _source = source

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return end

    local vehPos  = GetEntityCoords(entity)
    local players = GetPlayers()

    for _, pid in ipairs(players) do
        local playerId = tonumber(pid)
        -- Exclure l'émetteur : il joue déjà le son localement via PlaySoundFrontend
        if playerId ~= _source then
            local playerPed = GetPlayerPed(playerId)
            if DoesEntityExist(playerPed) then
                local playerPos = GetEntityCoords(playerPed)
                if #(vehPos - playerPos) <= 50.0 then
                    LSLegacy.SendEventToClient("handbrake:playSound", playerId, netId, isEngage)
                end
            end
        end
    end
end)
