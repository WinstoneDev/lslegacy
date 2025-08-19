MadeInFrance = {}
MadeInFrance.RegisteredClientEvents = {}
MadeInFrance.Token = nil
MadeInFrance.Math = {}

MadeInFrance.TriggerLocalEvent = function(name, ...)
    if not name then return end
    TriggerEvent(name, ...)
    Config.Development.Print("Successfully triggered event " .. name)
end

MadeInFrance.RegisterClientEvent = function(name, execute)
    if not name then return end
    if not MadeInFrance.RegisteredClientEvents[name] then
        RegisterNetEvent(name)
        AddEventHandler(name, function(...)
           local getResource = GetInvokingResource()

            if Config.ResourcesClientEvent[getResource] then
                execute(...)
            elseif getResource == nil then
                execute(...)
            else
               MadeInFrance.SendEventToServer("DropInjectorDetected")
            end
        end)
        Config.Development.Print("Successfully registered event " .. name)
        MadeInFrance.RegisteredClientEvents[name] = execute
    else
        return Config.Development.Print("Event " .. name .. " already registered")
    end
end

MadeInFrance.RegisterClientEvent("addTokenEvent", function(data)
    MadeInFrance.Token = data
end)

MadeInFrance.AddEventHandler = function(name, execute)
    if not name then return end
    if not execute then return end
    AddEventHandler(name, function(...)
        execute(...)
    end)
    Config.Development.Print("Successfully added event " .. name)
end

MadeInFrance.SendEventToServer = function(eventName, ...)
    if MadeInFrance.Token[eventName] then
        token = MadeInFrance.Token[eventName]
        TriggerServerEvent('useEvent', eventName, token, ...)
    else
        Config.Development.Print("Injector detected " .. eventName)
    end
end

MadeInFrance.KeyboardInput = function(textEntry, maxLength)
    AddTextEntry("Message", textEntry)
    DisplayOnscreenKeyboard(1, "Message", '', '', '', '', '', maxLength)
    blockinput = true

    while UpdateOnscreenKeyboard() ~= 1 and UpdateOnscreenKeyboard() ~= 2 do
        Wait(0)
    end

    if UpdateOnscreenKeyboard() ~= 2 then
        local result = GetOnscreenKeyboardResult()
        Wait(500)
        blockinput = false
        return result
    else
        Wait(500)
        blockinput = false
        return nil
    end
end

MadeInFrance.DrawText3D = function(x, y, z, text, distance, v3)
    local dist = distance or 7
    local aze, zea, aez = table.unpack(GetGameplayCamCoords())
    local plyCoords = GetEntityCoords(PlayerPedId())
    distance = GetDistanceBetweenCoords(aze, zea, aez, x, y, z, 1)
    local Text3D = GetDistanceBetweenCoords((plyCoords), x, y, z, 1) - 1.65
    local scale, fov = ((1 / distance) * (dist * .7)) * (1 / GetGameplayCamFov()) * 100, 255;
    if Text3D < dist then
        fov = math.floor(255 * ((dist - Text3D) / dist))
    elseif Text3D >= dist then
        fov = 0
    end
    fov = v3 or fov
    SetTextFont(0)
    SetTextScale(.0 * scale, .1 * scale)
    SetTextColour(255, 255, 255, math.max(0, math.min(255, fov)))
    SetTextCentre(1)
    SetDrawOrigin(x, y, z, 0)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

MadeInFrance.AddBlip = function(blipName, blipSprite, blipColor, blipScale, coords)
    if not blipName then return end
    if not blipSprite then return end
    if not blipColor then return end
    if not coords then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipSprite)
    SetBlipScale(blip, blipScale)
    SetBlipColour(blip, blipColor)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(blipName)
    EndTextCommandSetBlipName(blip)
end

MadeInFrance.DrawMarker = function(markerType, coords, r, g, b, a)
    if not markerType then return end
    if not coords then return end
    if not r then return end
    if not g then return end
    if not b then return end
    if not a then return end
    DrawMarker(markerType, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 0.7, 0.7, 0.7, r, g, b, a, false, false, false, false)
end

MadeInFrance.SetCoords = function(coords)
    if not coords then return end
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
end

MadeInFrance.ShowNotification = function(title, message, icon, time)
    time = time or 5000
    TriggerEvent('brutal_notify:SendAlert', title, message, time, icon)
end

MadeInFrance.GetClosestPlayer = function(player, distance)
    if not player then return end
    if not distance then return end
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPlayer, closestDistance = nil, distance or -1
    for _, player in ipairs(GetActivePlayers()) do
        local target = GetPlayerPed(player)
        if target ~= playerPed then
            local targetCoords = GetEntityCoords(target)
            local distance = #(playerCoords - targetCoords)
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = target
                closestDistance = distance
            end
        end
    end
    return closestPlayer
end

MadeInFrance.GetClosestVehicle = function(coords, distance)
    if not coords then return end
    if not distance then return end
    local closestVehicle, closestDistance = nil, distance or -1
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        local vehicleCoords = GetEntityCoords(vehicle)
        local dist = #(coords - vehicleCoords)
        if closestDistance == -1 or closestDistance > dist then
            closestVehicle = vehicle
            closestDistance = dist
        end
    end
    return closestVehicle
end

MadeInFrance.RequestAnimDict = function(animDict, cb)
	if not HasAnimDictLoaded(animDict) then
		RequestAnimDict(animDict)
		while not HasAnimDictLoaded(animDict) do
			Wait(0)
		end
	end

	if cb ~= nil then
		cb()
	end
end

MadeInFrance.RegisterClientEvent('notify', function(title, message, icon, time)
    time = time or 5000
    TriggerEvent('brutal_notify:SendAlert', title, message, time, icon)
end)

MadeInFrance.Math.Round = function(value, numDecimalPlaces)
    if numDecimalPlaces then
        local power = 10^numDecimalPlaces
        return math.floor((value * power) + 0.5) / (power)
    else
        return math.floor(value + 0.5)
    end
end

MadeInFrance.DisplayInteract = function(text, init)
    SetTextComponentFormat("jamyfafi")
    AddTextComponentString(text)
    DisplayHelpTextFromStringLabel(0, 0, init, -1)
end

MadeInFrance.SpawnPed = function(hash, coords, anim)
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(5)
    end
    local ped = CreatePed(4, hash, coords, false, false)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedHearingRange(ped, 0.0)
    SetPedSeeingRange(ped, 0.0)
    SetEntityInvincible(ped, true)
    SetPedAlertness(ped, 0.0)
    FreezeEntityPosition(ped, true) 
    SetPedFleeAttributes(ped, 0, 0)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCombatAttributes(ped, 46, true)
    SetPedFleeAttributes(ped, 0, 0)
    if anim ~= nil then
        TaskStartScenarioInPlace(ped, anim, 0, 0)
    end
    return ped
end

MadeInFrance.ConverToBoolean = function(number)
    if number == 0 then
        return false
    elseif number == 1 then
        return true
    end
end

MadeInFrance.ConverToNumber = function(boolean)
    if boolean == false then
        return 0
    elseif boolean == true then
        return 1
    end
end

MadeInFrance.RegroupNumbers = function(number)
    local number = tostring(number)
    local length = string.len(number)
    local result = ""
    local i = 1
    while i <= length do
        result = result .. string.sub(number, i, i + 3) .. " "
        i = i + 4
    end
    return result
end