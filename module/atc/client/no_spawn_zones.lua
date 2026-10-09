-- Empêche l'apparition d'avions ambiants (trafic vanilla, générateurs ymap) dans les zones
-- listées par Config.ATC.NoSpawnZones (ex : hangars hors LSIA), actif en permanence.

local ZONES = Config.ATC.NoSpawnZones or {}
if #ZONES == 0 then return end

local DETECT_MARGIN = 20.0
local CLEAR_INTERVAL_MS = 2000
local VEHICLE_CLASS_PLANES = 16

local function ClearAmbientPlanesAround(coords, radius)
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and not IsEntityAMissionEntity(vehicle)
            and GetVehicleClass(vehicle) == VEHICLE_CLASS_PLANES
            and LSLegacy.Validate.Distance(GetEntityCoords(vehicle), coords, radius)
        then
            local hasPlayer = false
            for i = -1, GetVehicleMaxNumberOfPassengers(vehicle) do
                local occupant = GetPedInVehicleSeat(vehicle, i)
                if occupant ~= 0 and IsPedAPlayer(occupant) then
                    hasPlayer = true
                    break
                end
            end
            if not hasPlayer then
                SetEntityAsMissionEntity(vehicle, true, true)
                DeleteVehicle(vehicle)
            end
        end
    end
end

local function IsNearAnyZone(coords)
    for _, z in ipairs(ZONES) do
        if LSLegacy.Validate.Distance(coords, z.coords, z.radius + DETECT_MARGIN) then
            return true
        end
    end
    return false
end

CreateThread(function()
    local lastClear = 0
    while true do
        local coords = GetEntityCoords(PlayerPedId())

        if IsNearAnyZone(coords) then
            SetVehicleDensityMultiplierThisFrame(0.0)
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.0)

            local now = GetGameTimer()
            if now - lastClear >= CLEAR_INTERVAL_MS then
                lastClear = now
                for _, z in ipairs(ZONES) do
                    if LSLegacy.Validate.Distance(coords, z.coords, z.radius + DETECT_MARGIN) then
                        ClearAmbientPlanesAround(z.coords, z.radius)
                    end
                end
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)
