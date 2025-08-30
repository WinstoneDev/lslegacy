local CurrentVehicle = nil
function SetFieldValueFromNameEncode(stringName, data)
	SetResourceKvp(stringName, json.encode(data))
end
function GetFieldValueFromName(stringName)
	local data = GetResourceKvpString(stringName)
	return json.decode(data) or {}
end
local FastWeapons = GetFieldValueFromName('LSLegacy')
local currentMenu = 'items'
local ItemVetement = {
    ['tshirt'] = {15, 0},
    ['torso'] = {-1, 0},
    ['arms'] = {-1, 0},
    ['pants'] = {14, 0},
    ['shoes'] = {34, 0},
    ['helmet'] = {-1, 0},
    ['glasses'] = {-1, 0},
    ['chain'] = {-1, 0},
    ['bags'] = {-1, 0},
    ['ears'] = {-1, 0},
    ['watches'] = {-1, 0},
    ['bracelet'] = {-1, 0},
    ['mask'] = {-1, 0},
    ['decals'] = {-1, 0}
}

Citizen.CreateThread(function()
    while true do
        local waitTime = 1000
        local playerPed = PlayerPedId()

        if currentWeapon then
            waitTime = 0
            if IsPedArmed(playerPed, 6) then
                DisableControlAction(1, 140, true)
                DisableControlAction(1, 141, true)
                DisableControlAction(1, 142, true)
            end

            for k, v in pairs(LSLegacy.PlayerData.inventory) do
                if v.name == currentWeapon then
                    v.data.ammo = GetAmmoInPedWeapon(playerPed, GetHashKey(currentWeapon))
                end
            end

            if GetAmmoInPedWeapon(playerPed, GetHashKey(currentWeapon)) == 0 then
                 GiveWeaponToPed(playerPed, currentWeapon, 0, false, true)
            end

            if IsControlJustPressed(0, 45) then
                local maxAmmo = GetWeaponClipSize(GetHashKey(currentWeapon))
                local currentAmmo = GetAmmoInPedWeapon(playerPed, GetHashKey(currentWeapon))
                local ammoNeeded = maxAmmo - currentAmmo

                if ammoNeeded > 0 then
                    if Config.AmmoForWeapon[currentWeapon] then
                        LSLegacy.SendEventToServer('removeAmmo', Config.AmmoForWeapon[currentWeapon], ammoNeeded)
                    end
                end
            end
        end
        Wait(waitTime)
    end
end)

function ReverseSearchConfigAmmo(ammo)
    for k, v in pairs(Config.AmmoForWeapon) do
        if v == ammo then
            return k
        end
    end
    return nil
end

LSLegacy.RegisterClientEvent('setAmmo', function(name, count)
    AddAmmoToPed(PlayerPedId(), GetHashKey(ReverseSearchConfigAmmo(name)), count)
end)

Keys.Register('TAB', 'TAB', 'Ouverture inventaire', function()
    if not isInInventory then
        openInventory()
    elseif isInInventory then 
        closeInventory()
    end
end)

Keys.Register('K', 'K', 'Ouvrir le coffre du véhicule', function()
    if isInInventory then return end
    local ped = PlayerPedId()
    local vehicle = 0

    if IsPedInAnyVehicle(ped, false) then
        vehicle = GetVehiclePedIsIn(ped, false)
        CurrentVehicle = vehicle
        openTrunkInventory(vehicle)
    else
        vehicle = LSLegacy.GetClosestVehicle(GetEntityCoords(ped), 3.0)
        if vehicle ~= 0 then
            if IsPlayerFacingTrunk(ped, vehicle) then
                CurrentVehicle = vehicle
                SetVehicleDoorOpen(vehicle, 5, false, false)
                PlayTrunkAnim(ped, "open")
                openTrunkInventory(vehicle)
            else
                LSLegacy.ShowNotification(nil, "Vous devez être derrière le coffre.", 'error')
            end
        else
            LSLegacy.ShowNotification(nil, "Aucun véhicule à proximité.", 'error')
        end
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
    heading = GetEntityHeading(PlayerPedId())
    SetFrontendActive(true)
    ActivateFrontendMenu(GetHashKey("FE_MENU_VERSION_EMPTY_NO_BACKGROUND"), true, -1)
    Wait(100)
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

            if CurrentVehicle ~= nil then
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true) 
                DisableControlAction(0, 59, true) 
                DisableControlAction(0, 60, true)
            end

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
    LSLegacy.Status.Displayed = false
end

function closeInventory()
    isInInventory = false
    ExecuteCommand('p2')
    SendNUIMessage({action = "hide"})
    SetNuiFocus(false, false)
    SetKeepInputMode(false)
    DisplayRadar(true)
    LSLegacy.Status.Displayed = true

    if CurrentVehicle ~= nil then
        if not IsPedInAnyVehicle(PlayerPedId(), false) then
            SetVehicleDoorShut(CurrentVehicle, 5, false) 
            PlayTrunkAnim(PlayerPedId(), "close")
        end
        CurrentVehicle = nil
    end
end

function unloadWeapon(name, count)
    if Config.AmmoForWeapon[name] then
        LSLegacy.SendEventToServer('giveItem', Config.AmmoForWeapon[name], count)
    end
end

function SearchInFastWeapons(name)
    for k, v in pairs(FastWeapons) do
        if v.name == name then
            return v
        end
    end
    return nil
end

function useWeapon(name, label, ammo)
    if currentWeapon == name then
        if SearchInFastWeapons(name) then
            FastWeapons[SearchInFastWeapons(name).slot].ammo = GetAmmoInPedWeapon(PlayerPedId(), GetHashKey(currentWeapon))
        end
        GiveWeaponToPed(PlayerPedId(), "weapon_unarmed", 0, false, true)
        currentWeapon = nil
    else
        currentWeapon = name
        GiveWeaponToPed(PlayerPedId(), name, 0, false, true)
        SetPedAmmo(PlayerPedId(), name, ammo)
        local originalLabel = Config.Items[name].label
        if originalLabel ~= nil and label == originalLabel then
            LSLegacy.ShowNotification(nil, "Vous avez équipé votre "..label..".", 'info')
        else
            LSLegacy.ShowNotification(nil, "Vous avez équipé votre "..originalLabel.." '"..label.."'.", 'info')
        end
    end
end

function GramsOrKg(weight)
    if weight >= 1 then
        return LSLegacy.Math.Round(weight, 1) .. 'KG'
    else
        return LSLegacy.Math.Round(weight*1000, 1) .. 'G'
    end
end

function BagOrTrunk(vehicle)
    if IsPedInVehicle(PlayerPedId(), vehicle, false) == 1 then
        return 'bag'
    else
        return 'trunk'
    end
end


function useitem(num)
    if not isInInventory then
        if FastWeapons[num] ~= nil then
            if string.match(FastWeapons[num].name, "weapon_") then
                useWeapon(FastWeapons[num].name, FastWeapons[num].label, FastWeapons[num].ammo)
            else
                if FastWeapons[num].data == nil then
                    LSLegacy.SendEventToServer('useItem', FastWeapons[num].name)
                else
                    LSLegacy.SendEventToServer('useItem', FastWeapons[num].name, FastWeapons[num].data, FastWeapons[num].uniqueId)
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

function IsPlayerFacingTrunk(ped, vehicle)
    local playerCoords = GetEntityCoords(ped)
    local trunkCoords = GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, "boot"))
    local dist = #(playerCoords - trunkCoords)

    if dist < 2.0 then
        local vehicleHeading = GetEntityHeading(vehicle)
        local pedHeading = GetHeadingFromVector_2d((trunkCoords.x - playerCoords.x), (trunkCoords.y - playerCoords.y))
        local angle = math.abs(vehicleHeading - pedHeading)
        if angle > 180 then angle = 360 - angle end
        return angle < 60.0
    end
    return false
end

function PlayTrunkAnim(ped, anim)
    RequestAnimDict("anim@heists@keycard@") 
    while not HasAnimDictLoaded("anim@heists@keycard@") do
        Wait(10)
    end
    RequestAnimDict("anim@gangops@morgue@table@") 
    while not HasAnimDictLoaded("anim@gangops@morgue@table@") do
        Wait(10)
    end
    if anim == "open" then
        TaskPlayAnim(ped, "anim@gangops@morgue@table@", "player_search", 3.0, -1, -1, 49, 0, false, false, false)
    elseif anim == "close" then
        TaskPlayAnim(ped, "anim@heists@keycard@", "exit", 3.0, -1, 2000, 49, 0, false, false, false)
    end
end

function openTrunkInventory(vehicle)
    isInInventory = true
    currentMenu = 'items'
    SendNUIMessage({action = "display", type = "trunk"})
    SendNUIMessage({action = "setWeightText", text = ""})
    loadPlayerInventory(currentMenu, vehicle)
    SetNuiFocus(true, true)
    SetKeepInputMode(true)
    DisableControlInventory()
    DisplayRadar(false)
    LSLegacy.Status.Displayed = false
end

function KeyboardInput(textEntry, maxLength)
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

function loadPlayerInventory(result, vehicle)
    items = {}
    fastItems = {}
    weight = GramsOrKg(LSLegacy.PlayerData.weight or 0)
    textweight = weight.. " / "..Config.Informations["MaxWeight"]..'KG'
    inventory = LSLegacy.PlayerData.inventory
    cash = LSLegacy.PlayerData.cash
    dirty = LSLegacy.PlayerData.dirty

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
                label = 'Argent sale',
                name = 'money',
                count = dirty,
                type = "item_dirty",
                usable = false
            })
        end
        for k, v in pairs(inventory) do
            if not ItemVetement[v.name] and not string.match(v.name, "weapon_") then
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
        if vehicle then
            if BagOrTrunk(CurrentVehicle) == 'trunk' then
                datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                Wait(250)
                if datastore == nil then
                    LSLegacy.DataStore.RegisterTrunk(vehicle)
                    datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                    while datastore == nil do
                        datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                        Wait(100)
                    end
                    cash = datastore.money or 0
                    dirty = datastore.dirty or 0
                    inventory = datastore.inventory
                    items = {}
                    for k, v in pairs(inventory) do
                        table.insert(items, {
                            label = v.label,
                            name = v.name,
                            count = v.count,
                            uniqueId = v.uniqueId,
                            data = v.data,
                            ammo = v.data and v.data.ammo or nil,
                            type = "item_standard",
                            usable = false
                        })
                    end
                    trunkWeight = GramsOrKg(LSLegacy.DataStore.GetInventoryWeight(items) or 0)
                    vehicleClass = GetVehicleClass(vehicle)
                    trunkMaxWeight = Config.VehicleTrunks[vehicleClass] or 50
                    weightText = trunkWeight.. " / "..trunkMaxWeight..'KG'
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
                            label = 'Argent sale',
                            name = 'money',
                            count = dirty,
                            type = "item_dirty",
                            usable = false
                        })
                    end

                    SendNUIMessage({
                        action = "setSecondInventoryItems",
                        itemList = items
                    })

                    local plate = GetVehicleNumberPlateText(vehicle)
                    SendNUIMessage({
                        action = "setInfoText",
                        text = "Poids coffre : " .. weightText .. " Plaque : " .. plate
                    })
                    
                else
                    datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                    while datastore == nil do
                        datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                        Wait(100)
                    end
                    cash = datastore.money or 0
                    dirty = datastore.dirty or 0
                    inventory = datastore.inventory
                    items = {}
                    for k, v in pairs(inventory) do
                        table.insert(items, {
                            label = v.label,
                            name = v.name,
                            count = v.count,
                            uniqueId = v.uniqueId,
                            data = v.data,
                            type = "item_standard",
                            ammo = v.data and v.data.ammo or nil,
                            usable = false
                        })
                    end
                    trunkWeight = GramsOrKg(LSLegacy.DataStore.GetInventoryWeight(items) or 0)
                    vehicleClass = GetVehicleClass(vehicle)
                    trunkMaxWeight = Config.VehicleTrunks[vehicleClass] or 50
                    weightText = trunkWeight.. " / "..trunkMaxWeight..'KG'
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
                            label = 'Argent sale',
                            name = 'money',
                            count = dirty,
                            type = "item_dirty",
                            usable = false
                        })
                    end

                    SendNUIMessage({
                        action = "setSecondInventoryItems",
                        itemList = items,
                        fastItems = fastItems
                    })

                    local plate = GetVehicleNumberPlateText(vehicle)
                    SendNUIMessage({
                        action = "setInfoText",
                        text = "Poids coffre : " .. weightText .. " Plaque : " .. plate
                    })
                end
            elseif BagOrTrunk(CurrentVehicle) == 'bag' then
                datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                Wait(250)
                if datastore == nil then
                    LSLegacy.DataStore.RegisterBAG(vehicle)
                    datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                    while datastore == nil do
                        datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                        Wait(100)
                    end
                    cash = datastore.money or 0
                    dirty = datastore.dirty or 0
                    inventory = datastore.inventory
                    items = {}
                    for k, v in pairs(inventory) do
                        table.insert(items, {
                            label = v.label,
                            name = v.name,
                            count = v.count,
                            uniqueId = v.uniqueId,
                            data = v.data,
                            type = "item_standard",
                            ammo = v.data and v.data.ammo or nil,
                            usable = false
                        })
                    end
                    trunkWeight = GramsOrKg(LSLegacy.DataStore.GetInventoryWeight(items) or 0)
                    vehicleClass = GetVehicleClass(vehicle)
                    trunkMaxWeight = Config.VehicleGloveboxes[vehicleClass] or 50
                    weightText = trunkWeight.. " / "..trunkMaxWeight..'KG'
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
                            label = 'Argent sale',
                            name = 'money',
                            count = dirty,
                            type = "item_dirty",
                            usable = false
                        })
                    end
                    SendNUIMessage({
                        action = "setSecondInventoryItems",
                        itemList = items,
                        fastItems = fastItems
                    })

                    local plate = GetVehicleNumberPlateText(vehicle)
                    SendNUIMessage({
                        action = "setInfoText",
                        text = "Poids coffre : " .. weightText .. " Plaque : " .. plate
                    })
                    
                    
                else
                    datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                    while datastore == nil do
                        datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                        Wait(100)
                    end
                    cash = datastore.money or 0
                    dirty = datastore.dirty or 0
                    inventory = datastore.inventory
                    items = {}
                    for k, v in pairs(inventory) do
                        table.insert(items, {
                            label = v.label,
                            name = v.name,
                            count = v.count,
                            uniqueId = v.uniqueId,
                            data = v.data,
                            type = "item_standard",
                            ammo = v.data and v.data.ammo or nil,
                            usable = false
                        })
                    end
                    trunkWeight = GramsOrKg(LSLegacy.DataStore.GetInventoryWeight(items) or 0)
                    vehicleClass = GetVehicleClass(vehicle)
                    trunkMaxWeight = Config.VehicleGloveboxes[vehicleClass] or 50
                    weightText = trunkWeight.. " / "..trunkMaxWeight..'KG'
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
                            label = 'Argent sale',
                            name = 'money',
                            count = dirty,
                            type = "item_dirty",
                            usable = false
                        })
                    end

                    SendNUIMessage({
                        action = "setSecondInventoryItems",
                        itemList = items,
                        fastItems = fastItems
                    })

                    local plate = GetVehicleNumberPlateText(vehicle)
                    SendNUIMessage({
                        action = "setInfoText",
                        text = "Poids coffre : " .. weightText .. " Plaque : " .. plate
                    })
                    
                    
                end
            end
        end
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
        if vehicle then
            if BagOrTrunk(CurrentVehicle) == 'trunk' then
                datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                Wait(250)
                if datastore == nil then
                    LSLegacy.DataStore.RegisterTrunk(vehicle)
                    datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                    while datastore == nil do
                        datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                        Wait(100)
                    end
                    cash = datastore.money or 0
                    dirty = datastore.dirty or 0
                    inventory = datastore.inventory
                    items = {}
                    for k, v in pairs(inventory) do
                        table.insert(items, {
                            label = v.label,
                            name = v.name,
                            count = v.count,
                            uniqueId = v.uniqueId,
                            data = v.data,
                            type = "item_standard",
                            ammo = v.data and v.data.ammo or nil,
                            usable = false
                        })
                    end
                    trunkWeight = GramsOrKg(LSLegacy.DataStore.GetInventoryWeight(items) or 0)
                    vehicleClass = GetVehicleClass(vehicle)
                    trunkMaxWeight = Config.VehicleTrunks[vehicleClass] or 50
                    weightText = trunkWeight.. " / "..trunkMaxWeight..'KG'
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
                            label = 'Argent sale',
                            name = 'money',
                            count = dirty,
                            type = "item_dirty",
                            usable = false
                        })
                    end

                    SendNUIMessage({
                        action = "setSecondInventoryItems",
                        itemList = items
                    })

                    local plate = GetVehicleNumberPlateText(vehicle)
                    SendNUIMessage({
                        action = "setInfoText",
                        text = "Poids coffre : " .. weightText .. " Plaque : " .. plate
                    })
                else
                    datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                    while datastore == nil do
                        datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                        Wait(100)
                    end
                    cash = datastore.money or 0
                    dirty = datastore.dirty or 0
                    inventory = datastore.inventory
                    items = {}
                    for k, v in pairs(inventory) do
                        table.insert(items, {
                            label = v.label,
                            name = v.name,
                            count = v.count,
                            uniqueId = v.uniqueId,
                            data = v.data,
                            type = "item_standard",
                            ammo = v.data and v.data.ammo or nil,
                            usable = false
                        })
                    end
                    trunkWeight = GramsOrKg(LSLegacy.DataStore.GetInventoryWeight(items) or 0)
                    vehicleClass = GetVehicleClass(vehicle)
                    trunkMaxWeight = Config.VehicleTrunks[vehicleClass] or 50
                    weightText = trunkWeight.. " / "..trunkMaxWeight..'KG'
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
                            label = 'Argent sale',
                            name = 'money',
                            count = dirty,
                            type = "item_dirty",
                            usable = false
                        })
                    end

                    SendNUIMessage({
                        action = "setSecondInventoryItems",
                        itemList = items,
                        fastItems = fastItems
                    })

                    local plate = GetVehicleNumberPlateText(vehicle)
                    SendNUIMessage({
                        action = "setInfoText",
                        text = "Poids coffre : " .. weightText .. " Plaque : " .. plate
                    })
                end
            elseif BagOrTrunk(CurrentVehicle) == 'bag' then
                datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                Wait(250)
                if datastore == nil then
                    LSLegacy.DataStore.RegisterBAG(vehicle)
                    datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                    while datastore == nil do
                        datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                        Wait(100)
                    end
                    cash = datastore.money or 0
                    dirty = datastore.dirty or 0
                    inventory = datastore.inventory
                    items = {}
                    for k, v in pairs(inventory) do
                        table.insert(items, {
                            label = v.label,
                            name = v.name,
                            count = v.count,
                            uniqueId = v.uniqueId,
                            data = v.data,
                            type = "item_standard",
                            ammo = v.data and v.data.ammo or nil,
                            usable = false
                        })
                    end
                    trunkWeight = GramsOrKg(LSLegacy.DataStore.GetInventoryWeight(items) or 0)
                    vehicleClass = GetVehicleClass(vehicle)
                    trunkMaxWeight = Config.VehicleGloveboxes[vehicleClass] or 50
                    weightText = trunkWeight.. " / "..trunkMaxWeight..'KG'
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
                            label = 'Argent sale',
                            name = 'money',
                            count = dirty,
                            type = "item_dirty",
                            usable = false
                        })
                    end
                    SendNUIMessage({
                        action = "setSecondInventoryItems",
                        itemList = items,
                        fastItems = fastItems
                    })

                    local plate = GetVehicleNumberPlateText(vehicle)
                    SendNUIMessage({
                        action = "setInfoText",
                        text = "Poids coffre : " .. weightText .. " Plaque : " .. plate
                    })
                else
                    datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                    while datastore == nil do
                        datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                        Wait(100)
                    end
                    cash = datastore.money or 0
                    dirty = datastore.dirty or 0
                    inventory = datastore.inventory
                    items = {}
                    for k, v in pairs(inventory) do
                        table.insert(items, {
                            label = v.label,
                            name = v.name,
                            count = v.count,
                            uniqueId = v.uniqueId,
                            data = v.data,
                            type = "item_standard",
                            ammo = v.data and v.data.ammo or nil,
                            usable = false
                        })
                    end
                    trunkWeight = GramsOrKg(LSLegacy.DataStore.GetInventoryWeight(items) or 0)
                    vehicleClass = GetVehicleClass(vehicle)
                    trunkMaxWeight = Config.VehicleGloveboxes[vehicleClass] or 50
                    weightText = trunkWeight.. " / "..trunkMaxWeight..'KG'
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
                            label = 'Argent sale',
                            name = 'money',
                            count = dirty,
                            type = "item_dirty",
                            usable = false
                        })
                    end

                    SendNUIMessage({
                        action = "setSecondInventoryItems",
                        itemList = items,
                        fastItems = fastItems
                    })

                    local plate = GetVehicleNumberPlateText(vehicle)
                    SendNUIMessage({
                        action = "setInfoText",
                        text = "Poids coffre : " .. weightText .. " Plaque : " .. plate
                    })
                end
            end
        end
    elseif result == 'weapons' then
        for k, v in pairs(inventory) do
            if string.match(v.name, "weapon_") then
                table.insert(items, {
                    label = v.label,
                    name = v.name,
                    count = v.count,
                    uniqueId = v.uniqueId,
                    data = v.data,
                    type = "item_standard",
                    usable = true,
                    ammo = v.data and v.data.ammo or nil
                })
            end
        end
        SendNUIMessage({ action = "setItems", itemList = items, fastItems = fastItems, text = textweight, crMenu = result})
        if vehicle then
            if BagOrTrunk(CurrentVehicle) == 'trunk' then
                datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                Wait(250)
                if datastore == nil then
                    LSLegacy.DataStore.RegisterTrunk(vehicle)
                    datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                    while datastore == nil do
                        datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                        Wait(100)
                    end
                    cash = datastore.money or 0
                    dirty = datastore.dirty or 0
                    inventory = datastore.inventory
                    items = {}
                    for k, v in pairs(inventory) do
                        table.insert(items, {
                            label = v.label,
                            name = v.name,
                            count = v.count,
                            uniqueId = v.uniqueId,
                            data = v.data,
                            type = "item_standard",
                            ammo = v.data and v.data.ammo or nil,
                            usable = false
                        })
                    end
                    trunkWeight = GramsOrKg(LSLegacy.DataStore.GetInventoryWeight(items) or 0)
                    vehicleClass = GetVehicleClass(vehicle)
                    trunkMaxWeight = Config.VehicleTrunks[vehicleClass] or 50
                    weightText = trunkWeight.. " / "..trunkMaxWeight..'KG'
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
                            label = 'Argent sale',
                            name = 'money',
                            count = dirty,
                            type = "item_dirty",
                            usable = false
                        })
                    end

                    SendNUIMessage({
                        action = "setSecondInventoryItems",
                        itemList = items
                    })

                    local plate = GetVehicleNumberPlateText(vehicle)
                    SendNUIMessage({
                        action = "setInfoText",
                        text = "Poids coffre : " .. weightText .. " Plaque : " .. plate
                    }) 
                else
                    datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                    while datastore == nil do
                        datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(vehicle))
                        Wait(100)
                    end
                    cash = datastore.money or 0
                    dirty = datastore.dirty or 0
                    inventory = datastore.inventory
                    items = {}
                    for k, v in pairs(inventory) do
                        table.insert(items, {
                            label = v.label,
                            name = v.name,
                            count = v.count,
                            uniqueId = v.uniqueId,
                            data = v.data,
                            type = "item_standard",
                            ammo = v.data and v.data.ammo or nil,
                            usable = false
                        })
                    end
                    trunkWeight = GramsOrKg(LSLegacy.DataStore.GetInventoryWeight(items) or 0)
                    vehicleClass = GetVehicleClass(vehicle)
                    trunkMaxWeight = Config.VehicleTrunks[vehicleClass] or 50
                    weightText = trunkWeight.. " / "..trunkMaxWeight..'KG'
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
                            label = 'Argent sale',
                            name = 'money',
                            count = dirty,
                            type = "item_dirty",
                            usable = false
                        })
                    end

                    SendNUIMessage({
                        action = "setSecondInventoryItems",
                        itemList = items,
                        fastItems = fastItems
                    })

                    local plate = GetVehicleNumberPlateText(vehicle)
                    SendNUIMessage({
                        action = "setInfoText",
                        text = "Poids coffre : " .. weightText .. " Plaque : " .. plate
                    })
                end
            elseif BagOrTrunk(CurrentVehicle) == 'bag' then
                datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                Wait(250)
                if datastore == nil then
                    LSLegacy.DataStore.RegisterBAG(vehicle)
                    datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                    while datastore == nil do
                        datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                        Wait(100)
                    end
                    cash = datastore.money or 0
                    dirty = datastore.dirty or 0
                    inventory = datastore.inventory
                    items = {}
                    for k, v in pairs(inventory) do
                        table.insert(items, {
                            label = v.label,
                            name = v.name,
                            count = v.count,
                            uniqueId = v.uniqueId,
                            data = v.data,
                            type = "item_standard",
                            ammo = v.data and v.data.ammo or nil,
                            usable = false
                        })
                    end
                    trunkWeight = GramsOrKg(LSLegacy.DataStore.GetInventoryWeight(items) or 0)
                    vehicleClass = GetVehicleClass(vehicle)
                    trunkMaxWeight = Config.VehicleGloveboxes[vehicleClass] or 50
                    weightText = trunkWeight.. " / "..trunkMaxWeight..'KG'
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
                            label = 'Argent sale',
                            name = 'money',
                            count = dirty,
                            type = "item_dirty",
                            usable = false
                        })
                    end
                    SendNUIMessage({
                        action = "setSecondInventoryItems",
                        itemList = items,
                        fastItems = fastItems
                    })

                    local plate = GetVehicleNumberPlateText(vehicle)
                    SendNUIMessage({
                        action = "setInfoText",
                        text = "Poids coffre : " .. weightText .. " Plaque : " .. plate
                    })
                else
                    datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                    while datastore == nil do
                        datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(vehicle))
                        Wait(100)
                    end
                    cash = datastore.money or 0
                    dirty = datastore.dirty or 0
                    inventory = datastore.inventory
                    items = {}
                    for k, v in pairs(inventory) do
                        table.insert(items, {
                            label = v.label,
                            name = v.name,
                            count = v.count,
                            uniqueId = v.uniqueId,
                            data = v.data,
                            type = "item_standard",
                            ammo = v.data and v.data.ammo or nil,
                            usable = false
                        })
                    end
                    trunkWeight = GramsOrKg(LSLegacy.DataStore.GetInventoryWeight(items) or 0)
                    vehicleClass = GetVehicleClass(vehicle)
                    trunkMaxWeight = Config.VehicleGloveboxes[vehicleClass] or 50
                    weightText = trunkWeight.. " / "..trunkMaxWeight..'KG'
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
                            label = 'Argent sale',
                            name = 'money',
                            count = dirty,
                            type = "item_dirty",
                            usable = false
                        })
                    end

                    SendNUIMessage({
                        action = "setSecondInventoryItems",
                        itemList = items,
                        fastItems = fastItems
                    })

                    local plate = GetVehicleNumberPlateText(vehicle)
                    SendNUIMessage({
                        action = "setInfoText",
                        text = "Poids coffre : " .. weightText .. " Plaque : " .. plate
                    })
                end
            end
        end
    end
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
        LSLegacy.SendEventToServer('transfer', {
            name = data.item.name,
            count = data.number,
            label = data.item.label,
            target = GetPlayerServerId(target),
            uniqueId = data.item.uniqueId,
            data = data.item.data,
            type = data.item.type
        })
        LSLegacy.RequestAnimDict("mp_common", function()
            TaskPlayAnim(PlayerPedId(), "mp_common", "givetake2_a", 2.0, -2.0, 2500, 49, 0, false, false, false)
        end)
        Wait(250)
        loadPlayerInventory(currentMenu)
    end
    cb("ok")
end)

RegisterNUICallback("OngletInventory", function(data, cb)
    if currentMenu ~= data.type then 
        currentMenu = data.type
        loadPlayerInventory(currentMenu, CurrentVehicle)
    end
end)

RegisterNUICallback("RenameItem", function(data, cb)
    if data.item.type == "item_standard" then
        closeInventory()
        local result = KeyboardInput(data.item.label, 30)
        if result ~= nil then
            local count = tonumber(data.number)
            if result ~= data.item.label and tonumber(count) and count ~= nil then
                LSLegacy.SendEventToServer("renameItem", data.item.name, data.item.label, result, count, data.item.uniqueId)
            else
                LSLegacy.ShowNotification(nil, "Impossible l'item a déjà ce label.", 'error')
            end
        end
    end 
end)

RegisterNUICallback("UnloadWeapon", function(data, cb)
    if currentMenu == "weapons" then
        if data.item.ammo > 0 then
            closeInventory()
            unloadWeapon(data.item.name, data.item.ammo)
            if currentWeapon ~= nil then
                GiveWeaponToPed(PlayerPedId(), "weapon_unarmed", 0, false, true)
                currentWeapon = nil
            end
            Wait(500)
            for i, v in pairs(LSLegacy.PlayerData.inventory) do
                if v.name == data.item.name then
                    v.data.ammo = 0
                    break
                end
            end
            cb('ok')
        end
    end
end)

RegisterNUICallback("UseItem", function(data, cb)
    if data.item.type == "item_standard" then
        if string.match(data.item.name, "weapon_") then
            useWeapon(data.item.name, data.item.label, data.item.ammo)
        else
            if data.item.data ~= nil then
                local clothes = ItemVetement[data.item.name]
                if clothes then
                    TriggerEvent('skinchanger:getSkin', function(skin)
                        skins = {}
                        skins['tshirt'] = {skin.tshirt_1, skin.tshirt_2}
                        skins['torso'] = {skin.torso_1, skin.torso_2}
                        skins['arms'] = {skin.arms_1, skin.torso_2}
                        skins['pants'] = {skin.pants_1, skin.pants_2}
                        skins['shoes'] = {skin.shoes_1, skin.shoes_2}
                        skins['helmet'] = {skin.helmet_1, skin.helmet_2}
                        skins['glasses'] = {skin.glasses_1, skin.glasses_2}
                        skins['chain'] = {skin.chain_1, skin.chain_2}
                        skins['bags'] = {skin.bags_1, skin.bags_2}
                        skins['ears'] = {skin.ears_1, skin.ears_2}
                        skins['watches'] = {skin.watches_1, skin.watches_2}
                        skins['bracelet'] = {skin.bracelets_1, skin.bracelets_2}
                        skins['mask'] = {skin.mask_1, skin.mask_2}
                        skins['decals'] = {skin.decals_1, skin.decals_2}
                    end)

                    if skins[data.item.name][1] ~= data.item.data[1] or skins[data.item.name][2] ~= data.item.data[2] then
                        LSLegacy.TriggerLocalEvent('skinchanger:change', data.item.name..'_1', data.item.data[1])
                        LSLegacy.TriggerLocalEvent('skinchanger:change', data.item.name..'_2', data.item.data[2])
                        ExecuteCommand('p3')
                        loadPlayerInventory('clothes', CurrentVehicle)
                    else
                        LSLegacy.TriggerLocalEvent('skinchanger:change', data.item.name..'_1', clothes[1])
                        LSLegacy.TriggerLocalEvent('skinchanger:change', data.item.name..'_2', clothes[2])
                        ExecuteCommand('p3')
                        loadPlayerInventory('clothes', CurrentVehicle)
                    end
                else
                    LSLegacy.SendEventToServer('useItem', data.item.name, data.item.data, data.item.uniqueId)
                end
            else
                LSLegacy.SendEventToServer('useItem', data.item.name)
            end
        end
    end
    if currentMenu == 'weapons' or currentMenu == 'items' then
        closeInventory()
    end
    cb("ok")
end)

RegisterNUICallback("DropItem", function(data, cb)
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        LSLegacy.ShowNotification(nil, "Vous ne pouvez pas jeter d'objets dans un véhicule.", 'error')
        return cb("ok")
    end
    if data.item.type == "item_standard" then
        local pPed = PlayerPedId()
        local pCoords = GetEntityCoords(pPed)
        local pHeading = GetEntityHeading(pPed)
        
        if tonumber(data.number) then
            LSLegacy.SendEventToServer('addItemPickup', data.item.name, data.item.type, data.item.label, data.number, {x = pCoords.x, y = pCoords.y, z = pCoords.z, w = pHeading}, data.item.uniqueId, data.item.data)
            TaskPlayAnim(PlayerPedId(), "random@domestic", "pickup_low" , 8.0, -8.0, 1780, 35, 0.0, false, false, false)
        end
    elseif data.item.type ~= 'item_standard' then
        local pPed = PlayerPedId()
        local pCoords = GetEntityCoords(pPed)
        local pHeading = GetEntityHeading(pPed)
        
        if tonumber(data.number) then
            LSLegacy.SendEventToServer('addItemPickup', data.item.type, nil, data.item.label, tonumber(data.number), {x = pCoords.x, y = pCoords.y, z = pCoords.z, w = pHeading})
            TaskPlayAnim(PlayerPedId(), "random@domestic", "pickup_low" , 8.0, -8.0, 1780, 35, 0.0, false, false, false)
        end
    end

    Wait(250)
    loadPlayerInventory(currentMenu)
    cb("ok")
end)

RegisterNUICallback("PutIntoFast", function(data, cb)
    if currentMenu == 'items' or currentMenu == 'weapons' then
        if data.slot ~= nil then
            FastWeapons[data.slot] = nil
        end
        FastWeapons[data.slot] = {
            slot = data.slot,
            label = data.item.label,
            name = data.item.name,
            type = data.item.type,
            count = data.item.count,
            uniqueId = data.item.uniqueId,
            data = data.item.data,
            ammo = data.item.data.ammo --- a changer pour eviter d'avoir full balles
        }
        SetFieldValueFromNameEncode('LSLegacy', FastWeapons)
        loadPlayerInventory(currentMenu, CurrentVehicle)
    end
    cb("ok")
end)

RegisterNUICallback("TakeFromFast", function(data, cb)
    if currentMenu == 'items' or currentMenu == 'weapons' then
        FastWeapons[data.item.slot] = nil
        SetFieldValueFromNameEncode('LSLegacy', FastWeapons)
        loadPlayerInventory(currentMenu, CurrentVehicle)
    end
	cb("ok")
end)

RegisterNUICallback("PutIntoTrunk", function(data, cb)
    if BagOrTrunk(CurrentVehicle) == 'trunk' then
        datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(CurrentVehicle))
        Wait(250)
        LSLegacy.SendEventToServer('PutIntoTrunk', {
            name = data.item.name,
            count = data.number,
            label = data.item.label,
            uniqueId = data.item.uniqueId,
            data = data.item.data,
            type = data.item.type
        }, datastore.name)
        Wait(100)
        loadPlayerInventory(currentMenu, CurrentVehicle)
    elseif BagOrTrunk(CurrentVehicle) == 'bag' then
        datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(CurrentVehicle))
        Wait(250)
        LSLegacy.SendEventToServer('PutIntoTrunk', {
            name = data.item.name,
            count = data.number,
            label = data.item.label,
            uniqueId = data.item.uniqueId,
            data = data.item.data,
            type = data.item.type
        }, datastore.name)
        Wait(100)
        loadPlayerInventory(currentMenu, CurrentVehicle)
    end
	cb("ok")
end)

RegisterNUICallback("TakeFromTrunk", function(data, cb)
    if BagOrTrunk(CurrentVehicle) == 'trunk' then
        datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(CurrentVehicle))
        Wait(250)
        LSLegacy.SendEventToServer('TakeFromTrunk', {
            name = data.item.name,
            count = data.number,
            label = data.item.label,
            uniqueId = data.item.uniqueId,
            data = data.item.data,
            type = data.item.type
        }, datastore.name)
        Wait(100)
        loadPlayerInventory(currentMenu, CurrentVehicle)
    elseif BagOrTrunk(CurrentVehicle) == 'bag' then
        datastore = LSLegacy.DataStore.GetBAG(GetVehicleNumberPlateText(CurrentVehicle))
        Wait(250)
        LSLegacy.SendEventToServer('TakeFromTrunk', {
            name = data.item.name,
            count = data.number,
            label = data.item.label,
            uniqueId = data.item.uniqueId,
            data = data.item.data,
            type = data.item.type
        }, datastore.name)
        Wait(100)
        loadPlayerInventory(currentMenu, CurrentVehicle)
    end
    cb("ok")
end)