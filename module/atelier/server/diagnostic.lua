--  MODULE ATELIER — Diagnostic (serveur)
--  Lecture seule : ne répare rien, ne fait que recaler puis renvoyer
--  l'état complet du véhicule (mécanique + pneus + carrosserie).

LSLegacy.RegisterServerEvent('atelier:requestDiagnostic', function(data)
    local src = source
    local ok = LSLegacy.Atelier.CanAct(src, 'diagnostic')
    if not ok then return end
    if not data or not data.vehNet then return end

    local entity = NetworkGetEntityFromNetworkId(data.vehNet)
    if not DoesEntityExist(entity) then return end

    -- La plaque est TOUJOURS lue depuis l'entité serveur, jamais depuis
    -- le client : c'est elle qui indexe atelier_vehicles.
    local plate = GetVehicleNumberPlateText(entity):upper()

    local snapshot = LSLegacy.Atelier.BuildGTASnapshot(entity)
    LSLegacy.Atelier.ReconcileVehicleState(plate, snapshot)

    LSLegacy.Atelier.GetVehicleState(plate, function(state)
        LSLegacy.SendEventToClient('atelier:diagnosticResult', src, {
            plate      = plate,
            components = state.components,
        })
    end)
end)
