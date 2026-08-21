-- ════════════════════════════════════════════════════════════════════════════
-- FREIN À MAIN MANUEL — Côté serveur
-- Rôle : relayer le son de serrage/desserrage aux joueurs proches du véhicule
-- ════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- handbrake:broadcastSound
--   Reçoit la demande du conducteur, puis envoie "handbrake:playSound"
--   à chaque joueur dans un rayon de 50 mètres autour du véhicule.
--
-- NetworkGetEntityFromNetworkId(netId)
--   → convertit le network ID en entité serveur
--
-- GetEntityCoords(entity)
--   → position monde de l'entité (vector3)
--
-- GetPlayers()
--   → table des source IDs de tous les joueurs connectés
--
-- GetPlayerPed(playerId)
--   → ped serveur du joueur (pour obtenir sa position)
--
-- #(v1 - v2)
--   → distance euclidienne entre deux vector3 (sucre syntaxique Lua FiveM)
--
-- LSLegacy.SendEventToClient(event, target, ...)
--   → TriggerClientEvent interne avec log Debug
-- ─────────────────────────────────────────────────────────────────────────────
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
                -- Rayon de diffusion sonore : 50 mètres
                if #(vehPos - playerPos) <= 50.0 then
                    LSLegacy.SendEventToClient("handbrake:playSound", playerId, netId, isEngage)
                end
            end
        end
    end
end)
