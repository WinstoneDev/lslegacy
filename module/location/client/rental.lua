-- ═══════════════════════════════════════════════════════════════════
--  LOCATION DE VÉHICULES — Livraison, retour, expiration du contrat
--  location_expires (statebag, epoch secondes) posé à la livraison.
--  À expiration : moteur déjà tournant -> décroissance de vitesse
--  jusqu'à 0 ; moteur éteint -> prochain démarrage coupé après coup.
-- ═══════════════════════════════════════════════════════════════════

local CFG = Config.Location
local Notify = Location.Notify

local function IsSpotFree(coords)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and #(GetEntityCoords(veh) - coords) < 3.0 then
            return false
        end
    end
    return true
end

local function ResolveSpawnCoords()
    local base = CFG.Spawn.coords
    if IsSpotFree(vector3(base.x, base.y, base.z)) then
        return base.x, base.y, base.z, base.w
    end
    return base.x + CFG.Spawn.altOffsetX, base.y, base.z, base.w
end

-- [netId] = 'decaying' | 'cutting' | 'dead'
local vehicleStates = {}
local warnedVehicles = {}
-- [netId] = GetGameTimer() deadline (os.time n'existe pas côté client)
local vehicleDeadlines = {}

local function ReturnOptionsFor(vehicle)
    return {
        {
            name = 'location_return',
            icon = 'fa-solid fa-key',
            label = 'Rendre le véhicule',
            distance = 3.0,
            canInteract = function()
                local agency = CFG.Agency.Ped.coords
                return #(GetEntityCoords(PlayerPedId()) - agency) <= CFG.Agency.ReturnRadius
            end,
            onSelect = function()
                LSLegacy.Events.SendToServer('location:returnVehicle', {
                    netId = NetworkGetNetworkIdFromEntity(vehicle),
                    plate = GetVehicleNumberPlateText(vehicle),
                })
            end,
        },
    }
end

local function DecayToStop(vehicle, netId)
    vehicleStates[netId] = 'decaying'
    Citizen.CreateThread(function()
        local duration   = CFG.Decay.decayDurationMs
        local start      = GetGameTimer()
        local startSpeed = math.max(GetEntitySpeed(vehicle), 5.0)
        while DoesEntityExist(vehicle) and vehicleStates[netId] == 'decaying' do
            local t = (GetGameTimer() - start) / duration
            if t >= 1.0 then
                SetEntityMaxSpeed(vehicle, 0.05)
                break
            end
            SetEntityMaxSpeed(vehicle, startSpeed * (1.0 - t))
            Wait(200)
        end
        if DoesEntityExist(vehicle) then
            SetVehicleEngineOn(vehicle, false, true, true)
        end
        vehicleStates[netId] = 'dead'
    end)
end

local function CutAfterStart(vehicle, netId)
    vehicleStates[netId] = 'cutting'
    Citizen.CreateThread(function()
        while DoesEntityExist(vehicle) and not GetIsVehicleEngineRunning(vehicle) and vehicleStates[netId] == 'cutting' do
            Wait(200)
        end
        if DoesEntityExist(vehicle) and vehicleStates[netId] == 'cutting' then
            Wait(1200)
            if DoesEntityExist(vehicle) then
                SetVehicleEngineOn(vehicle, false, true, true)
                Notify('Contrat de location expiré : le moteur ne peut plus démarrer.', 'error')
            end
        end
        if vehicleStates[netId] == 'cutting' then vehicleStates[netId] = 'dead' end
    end)
end

Citizen.CreateThread(function()
    while true do
        Wait(400)
        local vehicle = cache and cache.vehicle
        if vehicle and DoesEntityExist(vehicle) then
            local netId = NetworkGetNetworkIdFromEntity(vehicle)
            local deadline = vehicleDeadlines[netId]
            if not deadline and Entity(vehicle).state.location_expires then
                local hours = Entity(vehicle).state.location_hours
                deadline = GetGameTimer() + (hours or 1) * 3600000
                vehicleDeadlines[netId] = deadline
            end
            if deadline then
                local state = vehicleStates[netId]

                if state == 'dead' then
                    if GetIsVehicleEngineRunning(vehicle) then
                        SetVehicleEngineOn(vehicle, false, true, true)
                    end
                elseif GetGameTimer() >= deadline then
                    if not warnedVehicles[netId] then
                        warnedVehicles[netId] = true
                        Notify("Le temps imparti pour ce contrat de location est dépassé.", 'error')
                    end
                    if GetIsVehicleEngineRunning(vehicle) then
                        if state ~= 'decaying' then DecayToStop(vehicle, netId) end
                    elseif state ~= 'cutting' then
                        CutAfterStart(vehicle, netId)
                    end
                end
            end
        end
    end
end)

LSLegacy.Events.Register('location:deliverVehicle', function(data)
    local x, y, z, h = ResolveSpawnCoords()
    local hash = GetHashKey(data.model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then return end

    local vehicle = CreateVehicle(hash, x, y, z, h, true, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleNumberPlateText(vehicle, data.plate)
    SetVehicleFuelLevel(vehicle, 100.0)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleDoorsLocked(vehicle, 1)

    Entity(vehicle).state:set('location_expires', data.expiresAt, true)
    Entity(vehicle).state:set('location_hours', data.hours, true)
    vehicleDeadlines[NetworkGetNetworkIdFromEntity(vehicle)] = GetGameTimer() + data.hours * 3600000

    exports.ox_target:addLocalEntity(vehicle, ReturnOptionsFor(vehicle))

    Notify(('Véhicule loué pour %d heure(s). Ramenez-le à l\'agence avant expiration.'):format(data.hours), 'success')
end)

LSLegacy.Events.Register('location:returnAuthorized', function(netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    vehicleStates[netId] = nil
    warnedVehicles[netId] = nil
    vehicleDeadlines[netId] = nil
    if vehicle and DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
    end
    Notify('Véhicule rendu à l\'agence.', 'success')
end)

local RENT_FAIL_REASONS = {
    invalid_vehicle = 'Véhicule invalide.',
    invalid_hours   = 'Durée invalide.',
    already_rented  = 'Vous avez déjà un véhicule en location, rendez-le avant d\'en louer un autre.',
    payment_failed  = 'Paiement refusé.',
    purchase_failed = 'Impossible de générer une plaque, réessayez.',
}

LSLegacy.Events.Register('location:rentResult', function(data)
    if data and data.success then return end
    Notify(RENT_FAIL_REASONS[data and data.reason] or 'Location impossible.', 'error')
end)
