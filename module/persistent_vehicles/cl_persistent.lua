local lastVeh = nil

-- Enregistrement de l'event côté client
LSLegacy.RegisterClientEvent("ap:vehicleSpawned", function(data)
    local netId = data.netId
    local plate = data.plate
    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
        if data.extras then
            for i=0,20 do
                if data.extras[i] ~= nil then
                    SetVehicleExtra(entity, i, data.extras[i] and 0 or 1)
                end
            end
        end
        SetVehicleEngineHealth(entity, data.engineHealth)
        SetVehiclePetrolTankHealth(entity, data.tankHealth)
        SetVehicleFuelLevel(entity, tonumber(data.fuel))
        if data.tuning then
            for i = 0, 49 do
                if data.tuning[i] ~= nil then
                    SetVehicleMod(entity, i, data.tuning[i], false)
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

-- Thread principal pour toucher / quitter le véhicule
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

    -- Récupère tous les véhicules proches
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

    -- Notification
    print("[ClearVehicles] Véhicules supprimés :", deletedCount)
end, false)

local function updateVehicleStatus(veh)
    if veh == 0 then return end

    local plate = GetVehicleNumberPlateText(veh)

    -- Mods / tuning
    local tuningV = {}
    for i = 0, 49 do
        tuningV[i] = GetVehicleMod(veh, i)
    end

    local colorPrimary, colorSecondary = GetVehicleColours(veh)
    local pearlColor, wheelColor = GetVehicleExtraColours(veh)

    -- Extras
    local extras = {}
    for i = 0, 20 do
        if DoesExtraExist(veh, i) then
            extras[i] = IsVehicleExtraTurnedOn(veh, i)
        end
    end

    -- Statut complet
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

        extras = extras,
    }

    LSLegacy.SendEventToServer("ap:updateVehicleStatus", plate, status)
end

-- Thread principal pour update fuel/dirt
CreateThread(function()
    Wait(5000)
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            updateVehicleStatus(veh)
        end
        Wait(Config.AP.UpdateIntervalMs) 
    end
end)
