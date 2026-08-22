LSLegacy = {}
LSLegacy.RegisteredClientEvents = {}
LSLegacy.Token = nil
LSLegacy.Math = {}

LSLegacy.TriggerLocalEvent = function(name, ...)
    if not name then return end
    TriggerEvent(name, ...)
    Config.Development.Print("Successfully triggered event " .. name)
end

LSLegacy.RegisterClientEvent = function(name, execute)
    if not name then return end
    if not LSLegacy.RegisteredClientEvents[name] then
        RegisterNetEvent(name)
        AddEventHandler(name, function(...)
           local getResource = GetInvokingResource()

            if Config.ResourcesClientEvent[getResource] then
                execute(...)
            elseif getResource == nil then
                execute(...)
            else
               LSLegacy.SendEventToServer("DropInjectorDetected")
            end
        end)
        Config.Development.Print("Successfully registered event " .. name)
        LSLegacy.RegisteredClientEvents[name] = execute
    else
        return Config.Development.Print("Event " .. name .. " already registered")
    end
end

-- Les jetons arrivent par lots a la connexion, puis un par un lors du
-- renouvellement. `merge` distingue les deux : sans lui, chaque lot
-- ecrasait le precedent et il ne restait que le dernier.
--
-- Chaque event a desormais une FILE de jetons valides (et non plus une
-- valeur unique) : ca permet d'avoir plusieurs jetons en attente pour le
-- meme event quand le serveur en declenche coup sur coup plusieurs
-- (ex: farm:animalSpawned pour deux animaux). Sans ca, le second appel
-- repartait avec le meme jeton que le premier (pas encore renouvele cote
-- client) et se faisait rejeter par le serveur comme "Injector detected".
LSLegacy.RegisterClientEvent("addTokenEvent", function(data, merge)
    if not data then return end
    if not merge or type(LSLegacy.Token) ~= "table" then
        LSLegacy.Token = {}
    end
    for k, v in pairs(data) do
        LSLegacy.Token[k] = LSLegacy.Token[k] or {}
        for _, tok in ipairs(v) do
            table.insert(LSLegacy.Token[k], tok)
        end
    end
end)

LSLegacy.AddEventHandler = function(name, execute)
    if not name then return end
    if not execute then return end
    AddEventHandler(name, function(...)
        execute(...)
    end)
    Config.Development.Print("Successfully added event " .. name)
end

LSLegacy.SendEventToServer = function(eventName, ...)
    if type(LSLegacy.Token) == "table" and type(LSLegacy.Token[eventName]) == "table" and #LSLegacy.Token[eventName] > 0 then
        local token = table.remove(LSLegacy.Token[eventName], 1)
        TriggerServerEvent('useEvent', eventName, token, ...)
        return
    end

    -- Jeton pas encore arrive.
    --
    -- Le serveur renouvelle le jeton APRES chaque utilisation et le
    -- repousse de facon asynchrone ; il arrive aussi par lots a la
    -- connexion. Un event tire pendant ce court intervalle etait
    -- purement et simplement PERDU, avec un faux « Injector detected »
    -- en console. On patiente le temps que le jeton arrive.
    --
    -- Fenêtre volontairement large (15s) : LSLegacy.GeneratorTokenConnecting
    -- (serveur) attend déjà 1500ms en dur avant de générer les jetons, et ce
    -- délai peut grimper sous charge (plusieurs connexions simultanées,
    -- latence DB) ou avec l'écran de sélection multicharacter qui ajoute un
    -- aller-retour réseau avant que `registerPlayer` ne déclenche la
    -- génération. Une fenêtre trop courte perdait l'event pour de bon, sans
    -- aucune erreur visible (chargement infini).
    local args = table.pack(...)
    CreateThread(function()
        for _ = 1, 300 do
            Wait(50)
            if type(LSLegacy.Token) == "table" and type(LSLegacy.Token[eventName]) == "table" and #LSLegacy.Token[eventName] > 0 then
                local token = table.remove(LSLegacy.Token[eventName], 1)
                TriggerServerEvent('useEvent', eventName,
                    token, table.unpack(args, 1, args.n))
                return
            end
        end
        Config.Development.Print("Injector detected " .. eventName)
    end)
end

LSLegacy.KeyboardInput = function(textEntry, maxLength)
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

LSLegacy.DrawText3D = function(x, y, z, text, distance, v3)
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

LSLegacy.AddBlip = function(blipName, blipSprite, blipColor, blipScale, coords)
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

LSLegacy.DrawMarker = function(markerType, coords, r, g, b, a, scale)
    if not markerType then return end
    if not coords then return end
    if not r then return end
    if not g then return end
    if not b then return end
    if not a then return end

    local scaleX, scaleY, scaleZ = 0.7, 0.7, 0.7

    if type(scale) == "table" then
        scaleX = scale.x or scaleX
        scaleY = scale.y or scaleY
        scaleZ = scale.z or scaleZ
    elseif type(scale) == "number" then
        scaleX, scaleY, scaleZ = scale, scale, scale
    end

    DrawMarker(markerType, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, scaleX, scaleY, scaleZ, r, g, b, a, false, false, false, false)
end

LSLegacy.SetCoords = function(coords)
    if not coords then return end
    if LSLegacy.Anticheat then LSLegacy.Anticheat.AllowTeleport() end
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z)
end

LSLegacy.ShowNotification = function(title, message, icon, time)
    time = time or 5000
    TriggerEvent('brutal_notify:SendAlert', title, message, time, icon or 'info')
end

LSLegacy.GetClosestPlayer = function(player, distance)
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

LSLegacy.GetClosestVehicle = function(coords, distance)
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

LSLegacy.RequestAnimDict = function(animDict, cb)
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

LSLegacy.RegisterClientEvent('notify', function(title, message, icon, time)
    time = time or 5000
    TriggerEvent('brutal_notify:SendAlert', title, message, time, icon)
end)

LSLegacy.Math.Round = function(value, numDecimalPlaces)
    if numDecimalPlaces then
        local power = 10^numDecimalPlaces
        return math.floor((value * power) + 0.5) / (power)
    else
        return math.floor(value + 0.5)
    end
end

LSLegacy.DisplayInteract = function(text, init)
    SetTextComponentFormat("jamyfafi")
    AddTextComponentString(text)
    DisplayHelpTextFromStringLabel(0, 0, init, -1)
end

LSLegacy.SpawnPed = function(hash, coords, anim)
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

LSLegacy.ConverToBoolean = function(number)
    if number == 0 then
        return false
    elseif number == 1 then
        return true
    end
end

LSLegacy.ConverToNumber = function(boolean)
    if boolean == false then
        return 0
    elseif boolean == true then
        return 1
    end
end

LSLegacy.RegroupNumbers = function(number)
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

LSLegacy.SetVehicleExtra_PreserveDamage = function(vehicle, extraId, state)
    if not DoesEntityExist(vehicle) then return end
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local fuelLevel = GetVehicleFuelLevel(vehicle)

    local brokenWindows = {}
    for i = 0, 8 do 
        if not IsVehicleWindowIntact(vehicle, i) then
            brokenWindows[i] = true
        end
    end

    local burstTires = {}
    for i = 0, 5 do
        if IsVehicleTyreBurst(vehicle, i, false) then
            burstTires[i] = true
        end
    end

    local extraState = state and 0 or 1
    SetVehicleExtra(vehicle, extraId, extraState)
    Citizen.Wait(0)
    SetVehicleBodyHealth(vehicle, bodyHealth)
    SetVehicleEngineHealth(vehicle, engineHealth)
    SetVehicleFuelLevel(vehicle, fuelLevel)

    for windowIndex, _ in pairs(brokenWindows) do
        SmashVehicleWindow(vehicle, windowIndex)
    end

    for tireIndex, _ in pairs(burstTires) do
        SetVehicleTyreBurst(vehicle, tireIndex, true, 1000.0)
    end
end

-- Exports client

-- Indique si LSLegacy a fini d'initialiser le personnage du joueur
exports('isLoaded', function()
    return LSLegacy.PlayerData ~= nil and LSLegacy.PlayerData.identifier ~= nil
end)

-- Retourne les données du joueur local
exports('getPlayerData', function()
    return LSLegacy.PlayerData
end)

-- Retourne l'objet LSLegacy complet (pour ressources externes : police, mdt, …)
exports('getSharedObject', function()
    return LSLegacy
end)

-- Retourne RageUI (pour ressources externes qui utilisent les menus)
exports('getRageUI', function()
    return RageUI
end)

---LSLegacy.Events — API réseau côté client, regroupe les fonctions déjà en place sur LSLegacy.*.
LSLegacy.Events = {
    Register = LSLegacy.RegisterClientEvent,
    TriggerLocal = LSLegacy.TriggerLocalEvent,
    SendToServer = LSLegacy.SendEventToServer,
    AddHandler = LSLegacy.AddEventHandler,
}

---LSLegacy.Utils — utilitaires génériques (regroupe LSLegacy.Math pour l'instant).
LSLegacy.Utils = {
    Math = LSLegacy.Math,
}

---LSLegacy.Validate.Distance — équivalent client de server/validate.lua (pure géométrie, sans notion d'autorité serveur).
---@type function
---@param coordsA vector3
---@param coordsB vector3
---@param maxDistance number
---@return boolean
LSLegacy.Validate = LSLegacy.Validate or {}
LSLegacy.Validate.Distance = function(coordsA, coordsB, maxDistance)
    if coordsA == nil or coordsB == nil or maxDistance == nil then return false end
    return #(coordsA - coordsB) <= maxDistance
end