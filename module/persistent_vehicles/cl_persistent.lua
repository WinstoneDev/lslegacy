local lastVeh = nil

LSLegacy.RegisterClientEvent("ap:vehicleSpawned", function(data)
    local netId = data.netId
    local plate = data.plate
    local entity = NetworkGetEntityFromNetworkId(netId)
    Wait(1000)
    if DoesEntityExist(entity) then
        local status = data.status
        if status then
            for k, v in pairs(status.windows) do
                if v ~= nil then
                    if v.broken then
                        SmashVehicleWindow(entity, v.id)
                        while IsVehicleWindowIntact(entity, v.id) do
                            SmashVehicleWindow(entity, v.id)
                            Wait(100)
                        end
                    end
                end
            end
            if status.doorsBroken then
                for doorIndex, isBroken in pairs(status.doorsBroken) do
                    if isBroken then
                        SetVehicleDoorBroken(entity, tonumber(doorIndex), true)
                    end
                end
            end
            if status.tyreData then
                local tyreData = status.tyreData
                
                if tyreData.driftEnabled ~= nil then
                    SetDriftTyresEnabled(entity, tyreData.driftEnabled)
                end
                if tyreData.canBurst ~= nil then
                    SetVehicleTyresCanBurst(entity, tyreData.canBurst)
                end
                if tyreData.smokeColor then
                    SetVehicleTyreSmokeColor(entity, tyreData.smokeColor.r, tyreData.smokeColor.g, tyreData.smokeColor.b)
                end

                if tyreData.wheels then
                    for wheelId, wheelData in pairs(tyreData.wheels) do
                        local id = tonumber(wheelId)
                        if tyreData.canBurst and wheelData.health == 0.0 then
                            SetVehicleTyreBurst(entity, id, true, 1000.0)
                        end
                        SetTyreHealth(entity, id, wheelData.health)
                        SetTyreWearMultiplier(entity, id, wheelData.wear)
                    end
                end
            end
        end
        if data.extras then
            for k, v in pairs(data.extras) do
                print(k, v)
               -- if v == true then
                    --SetVehicleExtra(entity, k, 0)
                print(IsVehicleExtraTurnedOn(entity, k))
                --elseif v == false then
                   -- SetVehicleExtra(entity, k, 1)
                    --print(IsVehicleExtraTurnedOn(entity, k))
               -- end
            end
        end
        SetVehicleEngineHealth(entity, data.engineHealth)
        SetVehiclePetrolTankHealth(entity, data.tankHealth)
        SetVehicleFuelLevel(entity, tonumber(data.fuel))
        if data.tuning then
            for k, v in pairs(data.tuning) do
                if v ~= nil then
                    SetVehicleMod(entity, k, v, false)
                end
            end
            if data.tuning.colorPrimary and data.tuning.colorSecondary then
                SetVehicleColours(entity, data.tuning.colorPrimary, data.tuning.colorSecondary)
            end
            if data.tuning.pearlColor and data.tuning.wheelColor then
                SetVehicleExtraColours(entity, data.tuning.pearlColor, data.tuning.wheelColor)
            end
            if data.tuning.wheelType then
                SetVehicleWheelType(entity, data.tuning.wheelType)
            end
            if data.tuning.windowTint then
                SetVehicleWindowTint(entity, data.tuning.windowTint)
            end
        end
        print("[AP] Véhicule spawné :", plate)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 and veh ~= lastVeh then
            lastVeh = veh
        elseif veh == 0 and lastVeh ~= nil then
            LSLegacy.SendEventToServer("ap:updateVehicle", VehToNet(lastVeh))
            lastVeh = nil
        end
        Wait(Config.AP.UpdateIntervalMs)
    end
end)

RegisterCommand("clearvehicles", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local radius = 500.0

    local vehicles = GetGamePool("CVehicle")
    local deletedCount = 0

    for _, veh in ipairs(vehicles) do
        if DoesEntityExist(veh) then
            local vehCoords = GetEntityCoords(veh)
            if #(coords - vehCoords) <= radius then
                DeleteEntity(veh)
                deletedCount = deletedCount + 1
            end
        end
    end

    print("[ClearVehicles] Véhicules supprimés :", deletedCount)
end, false)


local function updateVehicleStatus(veh)
    if veh == 0 then return end

    local plate = GetVehicleNumberPlateText(veh)

    local tuningV = {}
    for i = 0, 49 do
        tuningV[i] = GetVehicleMod(veh, i)
    end

    local colorPrimary, colorSecondary = GetVehicleColours(veh)
    local pearlColor, wheelColor = GetVehicleExtraColours(veh)

    local extras = {}
    for i = 0, 20 do
        if DoesExtraExist(veh, i) then
            if IsVehicleExtraTurnedOn(veh, i) == 1 then
                extras[i] = true
            elseif IsVehicleExtraTurnedOn(veh, i) == false then
                extras[i] = false
            end
        end
    end

    local windows = {}
    for i = 0, 7 do
        table.insert(windows, {id = i, broken = not IsVehicleWindowIntact(veh, i)})
    end

    local r, g, b = GetVehicleTyreSmokeColor(veh)
    local tyreData = {
        canBurst = GetVehicleTyresCanBurst(veh),
        driftEnabled = GetDriftTyresEnabled(veh),
        smokeColor = { r = r, g = g, b = b },
        
        wheels = {}
    }

    for i = 0, 7 do
        tyreData.wheels[i] = {
            health = GetTyreHealth(veh, i),
            wear = GetTyreWearMultiplier(veh, i)
        }
    end

    local doorsBroken = {}
    for i = 0, 7 do 
        if IsVehicleDoorDamaged(veh, i) then
            doorsBroken[i] = true
        else
            doorsBroken[i] = false
        end
    end

    local status = {
        fuel = GetVehicleFuelLevel(veh),
        tuning = {
            mods = tuningV,
            colorPrimary = colorPrimary,
            colorSecondary = colorSecondary,
            pearlColor = pearlColor,
            wheelColor = wheelColor,
            wheelType = GetVehicleWheelType(veh),
            windowTint = GetVehicleWindowTint(veh)
        },
        windows = windows,
        extras = extras,
        tyreData = tyreData,
        doorsBroken = doorsBroken
    }

    LSLegacy.SendEventToServer("ap:updateVehicleStatus", plate, status)
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            updateVehicleStatus(veh)
        end
        Wait(Config.AP.UpdateIntervalMs) 
    end
end)
