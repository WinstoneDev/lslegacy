local CFG = Config.Population

CreateThread(function()
    while true do
        SetPedDensityMultiplierThisFrame(CFG.PedDensity)
        SetScenarioPedDensityMultiplierThisFrame(CFG.PedDensity, CFG.PedDensity)
        SetVehicleDensityMultiplierThisFrame(CFG.VehicleDensity)
        SetRandomVehicleDensityMultiplierThisFrame(CFG.VehicleDensity)
        SetParkedVehicleDensityMultiplierThisFrame(CFG.ParkedVehicleDensity)
        Wait(0)
    end
end)

if CFG.LockAmbientVehicles then
    CreateThread(function()
        while true do
            for _, vehicle in ipairs(GetGamePool('CVehicle')) do
                if DoesEntityExist(vehicle) and not IsEntityAMissionEntity(vehicle)
                    and GetVehicleDoorLockStatus(vehicle) < 2
                then
                    local driver = GetPedInVehicleSeat(vehicle, -1)
                    if driver == 0 or not IsPedAPlayer(driver) then
                        SetVehicleDoorsLocked(vehicle, 2)
                        SetVehicleDoorsLockedForAllPlayers(vehicle, true)
                    end
                end
            end
            Wait(1000)
        end
    end)
end
