local lastVeh = nil

LSLegacy.RegisterClientEvent("ap:vehicleSpawned", function(data)
    local netId = data.netId
    local plate = data.plate
    local entity = NetworkGetEntityFromNetworkId(netId)
    Wait(1000)
    if DoesEntityExist(entity) then
        local status = data.status
        if status then
                if status.visualDamage then
                    if status.visualDamage.bumpers then
                        if status.visualDamage.bumpers.front == 1 then
                            SetVehicleDamage(entity, 0.0, 2.0, 0.5, 500.0, 100.0, true) -- impact avant
                        end
                        if status.visualDamage.bumpers.rear == 1 then
                            SetVehicleDamage(entity, 0.0, -2.0, 0.5, 500.0, 100.0, true) -- impact arrière
                        end
                    end

                    if status.visualDamage.doors then
                        for doorIndex, d in pairs(status.visualDamage.doors) do
                            local index = tonumber(doorIndex)
                            if index and GetIsDoorValid(entity, index) then
                                if d.damaged then
                                    SetVehicleDoorBroken(entity, index, true)
                                elseif d.angle and d.angle > 0.1 then
                                    SetVehicleDoorOpen(entity, index, false, true)
                                else
                                    SetVehicleDoorShut(entity, index, false)
                                end
                            end
                        end
                    end

                    if status.visualDamage and status.visualDamage.deformation then
                        for _, deform in pairs(status.visualDamage.deformation) do
                            if deform and deform.damage then
                                local dmg = deform.damage * 1000.0
                                SetVehicleDamage(entity, deform.x, deform.y, deform.z, dmg, 100.0, true)
                            end
                        end
                    end
                end
            if data.extras then
                for i = 0, 20 do
                    if DoesExtraExist(entity, i) then
                        LSLegacy.SetVehicleExtra_PreserveDamage(entity, i, false)
                    end
                end
                for k, v in pairs(data.extras) do
                    if DoesExtraExist(entity, v.id) then
                        if v.state then
                            LSLegacy.SetVehicleExtra_PreserveDamage(entity, v.id, true)
                        else
                            LSLegacy.SetVehicleExtra_PreserveDamage(entity, v.id, false)
                        end
                    end
                end
            end
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
                    local index = tonumber(doorIndex)
                    if index and isBroken and GetIsDoorValid(entity, index) then
                        SetVehicleDoorBroken(entity, index, true)
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

LSLegacy.RegisterClientEvent("ap:findAndDeleteVehicle", function()
    local ped = PlayerPedId()
    local vehicleToDelete = nil

    if IsPedInAnyVehicle(ped, false) then
        vehicleToDelete = GetVehiclePedIsIn(ped, false)
    else
        local coords = GetEntityCoords(ped)
        local closestVehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 3.0, 0, 70)
        
        if closestVehicle ~= 0 and DoesEntityExist(closestVehicle) then
            vehicleToDelete = closestVehicle
        end
    end

    if vehicleToDelete then
        local netId = VehToNet(vehicleToDelete)
        local plate = GetVehicleNumberPlateText(vehicleToDelete)

        if NetworkDoesEntityExistWithNetworkId(netId) then
            LSLegacy.SendEventToServer("ap:requestVehicleDeletion", netId, plate)
        else
            DeleteEntity(vehicleToDelete)
            LSLegacy.SendEventToServer("ap:requestVehicleDeletion", 0, plate)
        end
    else
        LSLegacy.ShowNotification('Erreur', 'Aucun véhicule trouvé à proximité.', 'error')
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
                extras[i] = {id = i, state = true}
            elseif IsVehicleExtraTurnedOn(veh, i) == false then
                extras[i] = {id = i, state = false}
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

    local bumpers = {
        front = IsVehicleBumperBrokenOff(veh, true),
        rear = IsVehicleBumperBrokenOff(veh, false)
    }

    local doors = {}
    for i = 0, 7 do
        if GetIsDoorValid(veh, i) then
            doors[i] = {
                damaged = IsVehicleDoorDamaged(veh, i),
                angle = GetVehicleDoorAngleRatio(veh, i)
            }
        end
    end

    local offsets = {
        {x=0.0, y=2.0, z=0.5},   -- avant
        {x=0.0, y=-2.0, z=0.5},  -- arrière
        {x=0.0, y=0.0, z=1.2},   -- toit
        {x=-1.0, y=0.0, z=0.5},  -- gauche
        {x=1.0, y=0.0, z=0.5}    -- droite
    }

    local deformation = {}
    for _, offset in ipairs(offsets) do
        local deform = GetVehicleDeformationAtPos(veh, vector3(offset.x, offset.y, offset.z))
        local intensity = #(deform)*5
        if intensity > 0.01 then 
            table.insert(deformation, {
                x = offset.x,
                y = offset.y,
                z = offset.z,
                damage = intensity
            })
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


    status.visualDamage = {
        bumpers = bumpers,
        doors = doors,
        deformation = deformation
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

Citizen.CreateThread(function()
    while true do
        local waitTime = 5000
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == playerPed then

            if GetIsVehicleEngineRunning(vehicle) and GetEntitySpeed(vehicle) > 0.5 then
                local vehicleClass = GetVehicleClass(vehicle)
                local baseLossRate = Config.FuelConsumption.LossRateByClass[vehicleClass]

                local maxGear = GetVehicleHighGear(vehicle)
                local isElectric = (maxGear <= 1)

                if baseLossRate then
                    local currentSpeedKmh = GetEntitySpeed(vehicle) * 3.6
                    local speedMultiplier = math.max(0.5, currentSpeedKmh / 150.0)
                    if isElectric then
                        speedMultiplier = speedMultiplier * 0.8
                    end
                    local totalLoss = baseLossRate * speedMultiplier
                    local currentFuel = GetVehicleFuelLevel(vehicle)
                    local newFuel = currentFuel - totalLoss

                    if newFuel < 0 then
                        newFuel = 0
                    end

                    SetVehicleFuelLevel(vehicle, newFuel)

                    if newFuel <= 0 and GetIsVehicleEngineRunning(vehicle) then
                        SetVehicleEngineOn(vehicle, false, true, true)
                        LSLegacy.ShowNotification(nil, "Votre véhicule n'a plus d'essence !", 'error')
                    end
                end
            end
        end
        
        Wait(waitTime)
    end
end)