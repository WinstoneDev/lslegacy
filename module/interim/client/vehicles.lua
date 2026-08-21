-- ════════════════════════════════════════════════════════════════════
--  INTÉRIMAIRE — Camion + remorque (spawn à coordonnées fixes, attache)
--  Pas de persistance (véhicules d'outil de job, comme mecanicien/samu) :
--  spawn/despawn simples, aucune ligne persistent_vehicles.
-- ════════════════════════════════════════════════════════════════════

local CFG = Config.Interim
Interim = Interim or {}

local truckEntity, trailerEntity = nil, nil

local function Notify(msg, t)
    TriggerEvent(CFG.NotifyEvent, 'Intérimaire', msg, 5000, t or 'info')
end

-- Exposée pour refuel.lua : la "citerne jaune" à laquelle le personnage doit
-- se rendre pour remplir le camion est l'entité remorque elle-même (elle
-- suit le joueur, sa position n'est donc pas fixe comme celle de la zone
-- d'interaction pos4).
function Interim.GetTrailerEntity()
    return trailerEntity
end

local function VehicleHasPlayerOccupant(vehicle)
    for i = -1, GetVehicleMaxNumberOfPassengers(vehicle) do
        local ped = GetPedInVehicleSeat(vehicle, i)
        if ped ~= 0 and IsPedAPlayer(ped) then return true end
    end
    return false
end

-- Supprime les véhicules PNJ (trafic ambiant/parkés) qui traînent sur les
-- points de spawn fixes du camion/remorque, sans toucher aux véhicules
-- occupés par un joueur.
local function ClearVehiclesAround(coords, radius)
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and not VehicleHasPlayerOccupant(vehicle)
            and #(GetEntityCoords(vehicle) - coords) <= radius
        then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end
end

local function SpawnVehicleAt(modelName, coords, heading)
    local hash = GetHashKey(modelName)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then
        Notify('Modèle introuvable : ' .. tostring(modelName), 'error')
        return nil
    end

    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, heading or 0.0, true, false)
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)

    local ct = 0
    while not NetworkHasControlOfEntity(veh) and ct < 30 do
        NetworkRequestControlOfEntity(veh)
        Wait(10); ct = ct + 1
    end
    SetModelAsNoLongerNeeded(hash)
    return veh
end

-- ── Spawn du rig à la prise de service ───────────────────────────────
LSLegacy.RegisterClientEvent('interim:spawnRig', function(data)
    if not data then return end
    Interim.OnDuty = true

    ClearVehiclesAround(vector3(data.truckCoords.x, data.truckCoords.y, data.truckCoords.z), 6.0)
    ClearVehiclesAround(vector3(data.trailerCoords.x, data.trailerCoords.y, data.trailerCoords.z), 6.0)

    truckEntity   = SpawnVehicleAt(data.truckModel, data.truckCoords, data.truckHeading)
    trailerEntity = SpawnVehicleAt(data.trailerModel, data.trailerCoords, data.trailerHeading)

    if not truckEntity or not trailerEntity then
        Notify('Erreur de spawn du camion/remorque.', 'error')
        return
    end

    local truckNetId   = NetworkGetNetworkIdFromEntity(truckEntity)
    local trailerNetId = NetworkGetNetworkIdFromEntity(trailerEntity)
    LSLegacy.SendEventToServer('interim:rigSpawned', { truckNetId = truckNetId, trailerNetId = trailerNetId })

    Notify('Camion et remorque disponibles dans le parking en face.', 'success')
end)

-- ── Despawn à la fin de service ──────────────────────────────────────
LSLegacy.RegisterClientEvent('interim:despawnRig', function()
    Interim.OnDuty      = false
    Interim.Attached    = false
    Interim.TrailerFuel = 0
    if Interim.ShowTankPoint then Interim.ShowTankPoint(false) end
    if Interim.ShowStationBlips and not Interim.DevForceStationBlips then Interim.ShowStationBlips(false) end

    if truckEntity and DoesEntityExist(truckEntity) then
        SetEntityAsMissionEntity(truckEntity, true, true)
        DeleteVehicle(truckEntity)
    end
    if trailerEntity and DoesEntityExist(trailerEntity) then
        SetEntityAsMissionEntity(trailerEntity, true, true)
        DeleteVehicle(trailerEntity)
    end
    truckEntity, trailerEntity = nil, nil
end)

-- ── Détection automatique de l'attache/détache (native GTA : le camion
--    s'attache seul à la remorque en reculant dessus, aucune interaction
--    requise ; il peut aussi se détacher tout seul en cas de choc/mauvaise
--    conduite, d'où la surveillance dans les deux sens) ──────────────────
CreateThread(function()
    while true do
        Wait(500)
        if Interim.OnDuty and truckEntity and DoesEntityExist(truckEntity) then
            local nowAttached = IsVehicleAttachedToTrailer(truckEntity)
            if not Interim.Attached and nowAttached then
                Interim.Attached = true
                LSLegacy.SendEventToServer('interim:trailerAttached')
                Notify('Remorque attachée.', 'success')
            elseif Interim.Attached and not nowAttached then
                Interim.Attached = false
                LSLegacy.SendEventToServer('interim:trailerDetached')
                Notify('Remorque détachée, veuillez vous rendre à la raffinerie pour recommencer ou essayer de la rattacher.', 'error')
            end
        end
    end
end)
