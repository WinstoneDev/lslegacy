-- Empêche l'apparition de véhicules/pnj ambiants dans un rayon de Config.Interim.StationNoSpawnRadius autour de chaque station, actif en permanence (points fixes du monde).

local CFG = Config.Interim
local RADIUS = CFG.StationNoSpawnRadius or 10.0
-- Marge avant la zone stricte, pour éviter qu'un véhicule/pnj termine sa course de spawn pile dans la zone.
local DETECT_RADIUS = RADIUS + 20.0
local CLEAR_INTERVAL_MS = 2000

-- Ne touche jamais aux entités des joueurs ni aux entités "mission" (camion/remorque de l'intérimaire, pnj de job, etc.).
local function ClearAmbientVehiclesAround(coords, radius)
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and not IsEntityAMissionEntity(vehicle)
            and #(GetEntityCoords(vehicle) - coords) <= radius
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

local function ClearAmbientPedsAround(coords, radius)
    for _, ped in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsEntityAMissionEntity(ped)
            and #(GetEntityCoords(ped) - coords) <= radius
        then
            SetEntityAsMissionEntity(ped, true, true)
            DeletePed(ped)
        end
    end
end

local function NearestStationDist(coords)
    local nearest = nil
    for _, s in ipairs(CFG.Stations) do
        local d = #(coords - s.coords)
        if not nearest or d < nearest then nearest = d end
    end
    return nearest
end

CreateThread(function()
    local lastClear = 0
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        local nearest = NearestStationDist(coords)

        if nearest and nearest <= DETECT_RADIUS then
            -- Coupe la génération ambiante tant qu'on est proche d'une station.
            SetPedDensityMultiplierThisFrame(0.0)
            SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
            SetVehicleDensityMultiplierThisFrame(0.0)
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.0)

            local now = GetGameTimer()
            if now - lastClear >= CLEAR_INTERVAL_MS then
                lastClear = now
                for _, s in ipairs(CFG.Stations) do
                    if #(coords - s.coords) <= DETECT_RADIUS then
                        ClearAmbientVehiclesAround(s.coords, RADIUS)
                        ClearAmbientPedsAround(s.coords, RADIUS)
                    end
                end
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)
