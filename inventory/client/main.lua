local CurrentVehicle = nil

RegisterCommand('p1', function()
   createPedScreen()
end)

RegisterCommand('p2', function()
   deletePedScreen()
end)

RegisterCommand('p3', function()
   refreshPedScreen()
end)

function createPedScreen()
   CreateThread(function()
       heading = GetEntityHeading(PlayerPedId())
       SetFrontendActive(true)
       ActivateFrontendMenu(GetHashKey("FE_MENU_VERSION_EMPTY_NO_BACKGROUND"), true, -1)
       Citizen.Wait(100)
       N_0x98215325a695e78a(false)

       PlayerPedPreview = ClonePed(PlayerPedId(), heading, false, false)
       local PosPedPreview = GetEntityCoords(PlayerPedPreview)
       SetEntityCoords(PlayerPedPreview, PosPedPreview.x, PosPedPreview.y, PosPedPreview.z - 100)
       FreezeEntityPosition(PlayerPedPreview, true)
       SetEntityVisible(PlayerPedPreview, false, false)
       NetworkSetEntityInvisibleToNetwork(PlayerPedPreview, false)
       Wait(200)
       SetPedAsNoLongerNeeded(PlayerPedPreview)
       GivePedToPauseMenu(PlayerPedPreview, 1)
       SetPauseMenuPedLighting(true)
       SetPauseMenuPedSleepState(true)
       ReplaceHudColourWithRgba(117, 0, 0, 0, 0)
       previewPed = PlayerPedPreview
   end)
end

function deletePedScreen()
   if DoesEntityExist(previewPed) then
       DeleteEntity(previewPed)
       SetFrontendActive(false)
       ReplaceHudColourWithRgba(117, 0, 0, 0, 190)
       previewPed = nil
   end
end

function refreshPedScreen()
   if DoesEntityExist(previewPed) then
       deletePedScreen()
       Wait(200)
       createPedScreen()
   end
end

function SetFieldValueFromNameEncode(stringName, data)
	SetResourceKvp(stringName, json.encode(data))
end

function GetFieldValueFromName(stringName)
	local data = GetResourceKvpString(stringName)
	return json.decode(data) or {}
end

local FastWeapons = GetFieldValueFromName('MadeInFrance')
local currentMenu = 'items'
local ItemVetement = {
    ['tshirt'] = {15, 0},
    ['pants'] = {14, 0},
    ['shoes'] = {34, 0},
    ['helmet'] ={-1, 0},
    ['glasses'] = {-1, 0},
    ['chain'] = {-1, 0},
    ['bags'] = {-1, 0},
    ['helmet'] = {-1, 0},
    ['glasses'] = {-1, 0},
    ['ears'] = {-1, 0}
}

function DisableControlInventory()
    Citizen.CreateThread(function()
        while isInInventory do
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 69, true)
            DisableControlAction(0, 70, true)
            DisableControlAction(0, 92, true)
            DisableControlAction(0, 114, true)
            DisableControlAction(0, 121, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            DisableControlAction(0, 331, true)
            DisableControlAction(0, 157, true)
            DisableControlAction(0, 158, true)
            DisableControlAction(0, 160, true)
            Wait(0)
        end
    end)
end

function openInventory()
    isInInventory = true
    ExecuteCommand('p1')
    currentMenu = 'items'
    loadPlayerInventory(currentMenu)
    SendNUIMessage({action = "display", type = "normal"})
    SendNUIMessage({action = "setWeightText", text = ""})
    SetNuiFocus(true, true)
    SetKeepInputMode(true)
    DisableControlInventory()
    DisplayRadar(false)
end

function closeInventory()
    isInInventory = false
    ExecuteCommand('p2')
    SendNUIMessage({action = "hide"})
    SetNuiFocus(false, false)
    SetKeepInputMode(false)
    DisplayRadar(true)
    CurrentVehicle = nil
end

RegisterNUICallback('escape', function(data, cb)
    closeInventory()
    SetKeepInputMode(false)
end)

RegisterNUICallback("NUIFocusOff",function()
    closeInventory()
    SetKeepInputMode(false)
end)

RegisterNUICallback("GetNearPlayers", function(data, cb)
    local target = GetNearbyPlayer(3.0)
    if target then
        closeInventory()
        if data.item.type == "item_standard" then
            MadeInFrance.SendEventToServer('transfer', {
                name = data.item.name,
                count = data.number,
                label = data.item.label,
                target = GetPlayerServerId(target),
                uniqueId = data.item.uniqueId,
                data = data.item.data
            })
            MadeInFrance.RequestAnimDict("mp_common", function()
                TaskPlayAnim(PlayerPedId(), "mp_common", "givetake2_a", 2.0, -2.0, 2500, 49, 0, false, false, false)
            end)
        end
        Wait(250)
        loadPlayerInventory(currentMenu)
    end
    cb("ok")
end)

RegisterNUICallback("OngletInventory", function(data, cb)
    if currentMenu ~= data.type then 
        currentMenu = data.type
        loadPlayerInventory(data.type)
    end
end)

function KeyboardInput(textEntry, maxLength)
    AddTextEntry("Message", textEntry)
    DisplayOnscreenKeyboard(1, "Message", '', '', '', '', '', maxLength)
    blockinput = true

    while UpdateOnscreenKeyboard() ~= 1 and UpdateOnscreenKeyboard() ~= 2 do
        Citizen.Wait(0)
    end

    if UpdateOnscreenKeyboard() ~= 2 then
        local result = GetOnscreenKeyboardResult()
        Citizen.Wait(500)
        blockinput = false
        return result
    else
        Citizen.Wait(500)
        blockinput = false
        return nil
    end
end

RegisterNUICallback("RenameItem", function(data, cb)
    if data.item.type == "item_standard" then
        closeInventory()
        local result = KeyboardInput(data.item.label, 30)
        if result ~= nil then
            local count = tonumber(data.number)
            if result ~= data.item.label and tonumber(count) and count ~= nil then
                MadeInFrance.SendEventToServer("renameItem", data.item.name, data.item.label, result, count, data.item.uniqueId)
            else
                MadeInFrance.ShowNotification(nil, "Impossible l'item a déjà ce label.", 'error')
            end
        end
    end 
end)

function useWeapon(name, label)
    if currentWeapon == name then
        GiveWeaponToPed(PlayerPedId(), "weapon_unarmed", 0, false, true)
        currentWeapon = nil
    else
        currentWeapon = name
        GiveWeaponToPed(PlayerPedId(), name, 0, false, true)
        local originalLabel = Config.Items[name].label
        if originalLabel ~= nil and label == originalLabel then
            MadeInFrance.ShowNotification(nil, "Vous avez équipé votre "..label..".", 'info')
        else
            MadeInFrance.ShowNotification(nil, "Vous avez équipé votre "..originalLabel.." '"..label.."'.", 'info')
        end
    end
end

RegisterNUICallback("UseItem", function(data, cb)
    if data.item.type == "item_standard" then
        if string.match(data.item.name, "weapon_") then
            useWeapon(data.item.name, data.item.label)
        else
            if data.item.data ~= nil then
                local clothes = ItemVetement[data.item.name]
                if clothes then
                    TriggerEvent('skinchanger:getSkin', function(skin)
                        skins = {}
                        skins["tshirt"] = {skin.tshirt_1, skin.tshirt_2}
                        skins["pants"] = {skin.pants_1, skin.pants_2}
                        skins["shoes"] = {skin.shoes_1, skin.shoes_2}
                        skins["helmet"] = {skin.helmet_1, skin.helmet_2}
                        skins["glasses"] = {skin.glasses_1, skin.glasses_2}
                        skins["chain"] = {skin.chain_1, skin.chain_2}
                        skins["bags"] = {skin.bags_1, skin.bags_2}
                        skins['helmet'] = {skin.helmet_1, skin.helmet_2}
                        skins['glasses'] = {skin.glasses_1, skin.glasses_2}
                    end)

                    if skins[data.item.name][1] ~= data.item.data[1] or skins[data.item.name][2] ~= data.item.data[2] then
                        MadeInFrance.TriggerLocalEvent('skinchanger:change', data.item.name..'_1', data.item.data[1])
                        MadeInFrance.TriggerLocalEvent('skinchanger:change', data.item.name..'_2', data.item.data[2])
                        ExecuteCommand('p3')
                    else
                        MadeInFrance.TriggerLocalEvent('skinchanger:change', data.item.name..'_1', clothes[1])
                        MadeInFrance.TriggerLocalEvent('skinchanger:change', data.item.name..'_2', clothes[2])
                        ExecuteCommand('p3')
                    end
                else
                    MadeInFrance.SendEventToServer('useItem', data.item.name, data.item.data)
                end
            else
                MadeInFrance.SendEventToServer('useItem', data.item.name)
            end
        end
    end

    Wait(150)
    loadPlayerInventory(currentMenu)
    cb("ok")
end)

RegisterNUICallback("DropItem", function(data, cb)
    if data.item.type == "item_standard" then
        local pPed = PlayerPedId()
        local pCoords = GetEntityCoords(pPed)
        local pHeading = GetEntityHeading(pPed)
        
        if tonumber(data.number) then
            MadeInFrance.SendEventToServer('addItemPickup', data.item.name, data.item.type, data.item.label, data.number, {x = pCoords.x, y = pCoords.y, z = pCoords.z, w = pHeading}, data.item.uniqueId, data.item.data)
            TaskPlayAnim(PlayerPedId(), "random@domestic", "pickup_low" , 8.0, -8.0, 1780, 35, 0.0, false, false, false)
        end
    elseif data.item.type ~= 'item_standard' then
        local pPed = PlayerPedId()
        local pCoords = GetEntityCoords(pPed)
        local pHeading = GetEntityHeading(pPed)
        
        if tonumber(data.number) then
            MadeInFrance.SendEventToServer('addItemPickup', data.item.type, nil, data.item.label, tonumber(data.number), {x = pCoords.x, y = pCoords.y, z = pCoords.z, w = pHeading})
            TaskPlayAnim(PlayerPedId(), "random@domestic", "pickup_low" , 8.0, -8.0, 1780, 35, 0.0, false, false, false)
        end
    end

    Wait(250)
    loadPlayerInventory(currentMenu)
    cb("ok")
end)

function GramsOrKg(weight)
    if weight >= 1 then
        return MadeInFrance.Math.Round(weight, 1) .. 'KG'
    else
        return MadeInFrance.Math.Round(weight*1000, 1) .. 'G'
    end
end

function loadPlayerInventory(result, vehicle)
    items = {}
    fastItems = {}
    weight = GramsOrKg(MadeInFrance.PlayerData.weight or 0)
    textweight = weight.. " / "..Config.Informations["MaxWeight"]..'KG'
    inventory = MadeInFrance.PlayerData.inventory
    cash = MadeInFrance.PlayerData.cash
    dirty = MadeInFrance.PlayerData.dirty

    if json.encode(FastWeapons) ~= "[]" then
        for k, v in pairs(FastWeapons) do
            table.insert(fastItems, {
                label = v.label,
                name = v.name,
                count = v.count,
                uniqueId = v.uniqueId,
                data = v.data,
                type = v.type,
                usable = false,
                slot = k
            })
        end
    end
    Wait(50)
    if result == 'items' then 
        if cash > 0 then
            table.insert(items, {
                label = 'Argent',
                name = 'money',
                count = cash,
                type = "item_cash",
                usable = false
            })
        end
        if dirty > 0 then
            table.insert(items, {
                label = 'Argent',
                name = 'money',
                count = dirty,
                type = "item_dirty",
                usable = false
            })
        end
        for k, v in pairs(inventory) do
            if not ItemVetement[v.name] then
                table.insert(items, {
                    label = v.label,
                    name = v.name,
                    count = v.count,
                    uniqueId = v.uniqueId,
                    data = v.data,
                    type = "item_standard",
                    usable = true
                })
            end
        end
        SendNUIMessage({ action = "setItems", itemList = items, fastItems = fastItems, text = textweight, crMenu = result})
    elseif result == 'clothes' then 
        for k, v in pairs(inventory) do
            if ItemVetement[v.name] then
                table.insert(items, {
                    label = v.label,
                    name = v.name,
                    count = v.count,
                    uniqueId = v.uniqueId,
                    data = v.data,
                    type = "item_standard",
                    usable = true
                })
            end
        end
        SendNUIMessage({ action = "setItems", itemList = items, fastItems = fastItems, text = textweight, crMenu = result})
    elseif result == 'vehicle' then
        local datastore = MadeInFrance.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
        if not datastore then
            MadeInFrance.DataStore.RegisterTrunk(vehicle)
            while MadeInFrance.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle)) == nil do
                Wait(100)
            end
            datastore = MadeInFrance.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
            inventory = datastore.inventory
            trunkWeight = GramsOrKg(MadeInFrance.DataStore.GetInventoryWeight(inventory) or 0)
            trunkMaxWeight = 50

            weightText = trunkWeight.. " / "..trunkMaxWeight..'KG'

            SendNUIMessage({
                action = "setSecondInventoryItems",
                itemList = inventory,
                fastItems = fastItems
            })

            local plate = GetVehicleNumberPlateText(vehicle)
            SendNUIMessage({
                action = "setInfoText",
                text = "Poids coffre : " .. weightText .. " Plaque : " .. plate
            })
            Wait(100)
            loadPlayerInventory('items')
        else
            datastore = MadeInFrance.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
            inventory = datastore.inventory
            trunkWeight = MadeInFrance.DataStore.GetInventoryWeight(inventory)
            trunkMaxWeight = 50
            
            weightText = string.format("%.1f / %d KG", trunkWeight, trunkMaxWeight)

            SendNUIMessage({
                action = "setSecondInventoryItems",
                itemList = inventory,
                fastItems = fastItems
            })

            local plate = GetVehicleNumberPlateText(vehicle)
            SendNUIMessage({
                action = "setInfoText",
                text = "Poids coffre : " .. weightText .. " Plaque : " .. plate
            })
            Wait(100)
            loadPlayerInventory('items')
        end
    end
end

RegisterNUICallback("PutIntoFast", function(data, cb)
    if currentMenu == 'items' then
        if data.slot ~= nil then
            FastWeapons[data.slot] = nil
        end
        FastWeapons[data.slot] = {
            label = data.item.label,
            name = data.item.name,
            type = data.item.type,
            count = data.item.count,
            uniqueId = data.item.uniqueId,
            data = data.item.data
        }
        SetFieldValueFromNameEncode('MadeInFrance', FastWeapons)
        loadPlayerInventory(currentMenu)
    end
    cb("ok")
end)

RegisterNUICallback("TakeFromFast", function(data, cb)
    if currentMenu == 'items' then
        FastWeapons[data.item.slot] = nil
        SetFieldValueFromNameEncode('MadeInFrance', FastWeapons)
        loadPlayerInventory(currentMenu)
    end
	cb("ok")
end)

RegisterNUICallback("PutIntoTrunk", function(data, cb)
    if currentMenu == 'vehicle' then
        local datastore = MadeInFrance.DataStore.GetTrunk(GetVehicleNumberPlateText(CurrentVehicle))
        Wait(100)
        MadeInFrance.SendEventToServer('PutIntoTrunk', {
            name = data.item.name,
            count = data.number,
            label = data.item.label,
            uniqueId = data.item.uniqueId,
            data = data.item.data
        }, datastore.name)
        Wait(250)
        loadPlayerInventory(currentMenu, CurrentVehicle)
    end
	cb("ok")
end)

RegisterNUICallback("TakeFromTrunk", function(data, cb)
    if currentMenu == 'vehicle' then
        local datastore = MadeInFrance.DataStore.GetTrunk(GetVehicleNumberPlateText(CurrentVehicle))
        Wait(100)
        MadeInFrance.SendEventToServer('TakeFromTrunk', {
            name = data.item.name,
            count = data.number,
            label = data.item.label,
            uniqueId = data.item.uniqueId,
            data = data.item.data
        }, datastore.name)
        Wait(250)
        loadPlayerInventory(currentMenu, CurrentVehicle)
    end
    cb("ok")
end)

Keys.Register('TAB', 'TAB', 'Ouverture inventaire', function()
    if not isInInventory then
        openInventory()
    elseif isInInventory then 
        closeInventory()
    end
end)

Keys.Register('1', '1', 'Slot d\'arme 1', function()
    useitem(1)
end)

Keys.Register('2', '2', 'Slot d\'arme 2', function()
    useitem(2)
end)

Keys.Register('3', '3', 'Slot d\'arme 3', function()
    useitem(3)
end)

function useitem(num)
    if not isInInventory then
        if FastWeapons[num] ~= nil then
            if string.match(FastWeapons[num].name, "weapon_") then
                useWeapon(FastWeapons[num].name, FastWeapons[num].label)
            else
                if FastWeapons[num].data == nil then
                    MadeInFrance.SendEventToServer('useItem', FastWeapons[num].name)
                else
                    MadeInFrance.SendEventToServer('useItem', FastWeapons[num].name, FastWeapons[num].data)
                end
            end
        end
    end
end

function SetKeepInputMode(bool)
    local threadCreated = false
    local controlDisabled = {1, 2, 3, 4, 5, 6, 18, 24, 25, 37, 69, 70, 111, 117, 118, 182, 199, 200, 257}

    if SetNuiFocusKeepInput then
        SetNuiFocusKeepInput(bool)
    end

    value = bool

    if not threadCreated and bool then
        threadCreated = true

        Citizen.CreateThread(function()
            while value do
                Wait(0)

                for _,v in pairs(controlDisabled) do
                    DisableControlAction(0, v, true)
                end
            end

            threadCreated = false
        end)
    end
end

function openTrunkInventory(vehicle)
    isInInventory = true
    currentMenu = 'vehicle'
    loadPlayerInventory(currentMenu, vehicle)
    SendNUIMessage({action = "display", type = "trunk"})
    SendNUIMessage({action = "setWeightText", text = ""})
    SetNuiFocus(true, true)
    SetKeepInputMode(true)
    DisableControlInventory()
    DisplayRadar(false)
    ExecuteCommand('p1')
end

Keys.Register('K', 'K', 'Ouvrir le coffre du véhicule', function()
    if isInInventory then return end
    local ped = PlayerPedId()
    local vehicle = MadeInFrance.GetClosestVehicle(GetEntityCoords(ped), 3.0)
    if vehicle ~= 0 then
        openTrunkInventory(vehicle)
        CurrentVehicle = vehicle
    else
        MadeInFrance.ShowNotification(nil, "Aucun véhicule à proximité.", 'error')
    end
end)