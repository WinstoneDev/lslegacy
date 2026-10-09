-- Lecture seule : recale puis renvoie l'état complet du véhicule, ne répare rien.

LSLegacy.Events.Register('atelier:requestDiagnostic', function(data)
    local src = source
    local ok = LSLegacy.Atelier.CanAct(src, 'diagnostic')
    if not ok then
        LSLegacy.Atelier.Notify(src, Lang.Atelier.not_on_duty, 'error')
        return
    end
    if not data or not data.vehNet then return end

    local entity = NetworkGetEntityFromNetworkId(data.vehNet)
    if not DoesEntityExist(entity) then
        LSLegacy.Atelier.Notify(src, "Véhicule introuvable.", 'error')
        return
    end

    -- La plaque est TOUJOURS lue depuis l'entité serveur, jamais depuis le client.
    local plate = GetVehicleNumberPlateText(entity):upper()

    local snapshot = LSLegacy.Atelier.BuildGTASnapshot(
        entity,
        type(data.tyres) == 'table' and data.tyres or nil,
        type(data.doorsBroken) == 'table' and data.doorsBroken or nil,
        type(data.deformation) == 'table' and data.deformation or nil
    )
    LSLegacy.Atelier.ReconcileVehicleState(plate, snapshot)

    LSLegacy.Atelier.GetVehicleState(plate, function(state)
        LSLegacy.Events.SendToClient('atelier:diagnosticResult', src, {
            plate      = plate,
            components = state.components,
        })
    end)
end)
