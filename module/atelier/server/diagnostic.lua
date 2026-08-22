-- Lecture seule : recale puis renvoie l'état complet du véhicule, ne répare rien.

LSLegacy.Events.Register('atelier:requestDiagnostic', function(data)
    local src = source
    local ok = LSLegacy.Atelier.CanAct(src, 'diagnostic')
    if not ok then return end
    if not data or not data.vehNet then return end

    local entity = NetworkGetEntityFromNetworkId(data.vehNet)
    if not DoesEntityExist(entity) then return end

    -- La plaque est TOUJOURS lue depuis l'entité serveur, jamais depuis le client.
    local plate = GetVehicleNumberPlateText(entity):upper()

    local snapshot = LSLegacy.Atelier.BuildGTASnapshot(entity)
    LSLegacy.Atelier.ReconcileVehicleState(plate, snapshot)

    LSLegacy.Atelier.GetVehicleState(plate, function(state)
        LSLegacy.Events.SendToClient('atelier:diagnosticResult', src, {
            plate      = plate,
            components = state.components,
        })
    end)
end)
