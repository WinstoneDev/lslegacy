local CurrentVehicle = nil
local viewOnlyMode   = false
function SetFieldValueFromNameEncode(stringName, data)
	SetResourceKvp(stringName, json.encode(data))
end
function GetFieldValueFromName(stringName)
	local data = GetResourceKvpString(stringName)
	if not data then return {} end
	local ok, decoded = pcall(json.decode, data)
	return (ok and type(decoded) == 'table') and decoded or {}
end
-- Raccourcis d'inventaire (items/armes assignés aux touches numériques),
-- rechargés par personnage plus bas (getCharacterKvpSuffix) une fois
-- LSLegacy.PlayerData disponible — voir le handler InitPlayer.
local FastWeapons = {}
local currentMenu = 'items'
local ItemVetement = {
    ['tshirt'] = {15, 0},
    ['torso'] = {15, 0},
    ['arms'] = {15, 0},
    ['pants'] = {14, 0},
    ['shoes'] = {34, 0},
    ['helmet'] = {-1, 0},
    ['glasses'] = {0, 0},
    ['chain'] = {0, 0},
    ['bags'] = {0, 0},
    ['ears'] = {0, 0},
    ['watches'] = {0, 0},
    ['bracelet'] = {0, 0},
    ['mask'] = {0, 0},
    ['decals'] = {0, 0},
    ['bproof'] = {0, 0}
}

-- Valeurs par défaut "à poil" selon le genre
local DefaultClothesMale = {
    ['tshirt']   = {15, 0},
    ['torso']    = {15, 0},
    ['arms']     = {15, 0},
    ['pants']    = {14, 0},
    ['shoes']    = {118, 0},
    ['helmet']   = {-1,  0},
    ['glasses']  = {-1,  0},
    ['chain']    = {-1,  0},
    ['bags']     = {0,  0},
    ['ears']     = {-1,  0},
    ['watches']  = {-1,  0},
    ['bracelet'] = {-1,  0},
    ['mask']     = {0,  0},
    ['decals']   = {-1,  0},
    ['bproof']   = {-1,  0},
}

local DefaultClothesFemale = {
    ['tshirt']   = {14, 0},
    ['torso']    = {15, 0},
    ['arms']     = {15, 0},
    ['pants']    = {15, 0},
    ['shoes']    = {119, 0},
    ['helmet']   = {-1,  0},
    ['glasses']  = {-1,  0},
    ['chain']    = {-1,  0},
    ['bags']     = {0,  0},
    ['ears']     = {-1,  0},
    ['watches']  = {-1,  0},
    ['bracelet'] = {-1,  0},
    ['mask']     = {0,  0},
    ['decals']   = {-1,  0},
    ['bproof']   = {-1,  0},
}

function getDefaultClothes()
    local isFemale = GetEntityModel(PlayerPedId()) == GetHashKey("mp_f_freemode_01")
    return isFemale and DefaultClothesFemale or DefaultClothesMale
end

-- Mapping nom vêtement → composant GTA V (component ou prop)
local ClothingComponentIds = {
    ['mask']     = {type='component', id=1},
    ['arms']     = {type='component', id=3},
    ['pants']    = {type='component', id=4},
    ['bags']     = {type='component', id=5},
    ['shoes']    = {type='component', id=6},
    ['chain']    = {type='component', id=7},
    ['tshirt']   = {type='component', id=8},
    ['decals']   = {type='component', id=10},
    ['torso']    = {type='component', id=11},
    ['bproof']   = {type='component', id=9},
    ['helmet']   = {type='prop',      id=0},
    ['glasses']  = {type='prop',      id=1},
    ['ears']     = {type='prop',      id=2},
    ['watches']  = {type='prop',      id=6},
    ['bracelet'] = {type='prop',      id=7},
}

function isValidClothingVariation(name, drawable, texture)
    local ped = PlayerPedId()
    local info = ClothingComponentIds[name]
    if not info then return true end
    local maxDrawables, maxTextures
    if info.type == 'component' then
        maxDrawables = GetNumberOfPedDrawableVariations(ped, info.id)
        if drawable < 0 or drawable >= maxDrawables then return false end
        maxTextures = GetNumberOfPedTextureVariations(ped, info.id, drawable)
    else
        maxDrawables = GetNumberOfPedPropDrawableVariations(ped, info.id)
        if drawable < 0 or drawable >= maxDrawables then return false end
        maxTextures = GetNumberOfPedPropTextureVariations(ped, info.id, drawable)
    end
    return texture >= 0 and texture < maxTextures
end

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

            local liveAmmo = GetAmmoInPedWeapon(playerPed, GetHashKey(currentWeapon))
            for k, v in pairs(LSLegacy.PlayerData.inventory) do
                if v.name == currentWeapon then
                    v.data.ammo = liveAmmo
                end
            end
            local fastEntry = SearchInFastWeapons(currentWeapon)
            if fastEntry and FastWeapons[fastEntry.slot] and FastWeapons[fastEntry.slot].ammo ~= liveAmmo then
                FastWeapons[fastEntry.slot].ammo = liveAmmo
                if isInInventory then
                    SendNUIMessage({action = "updateFastAmmo", slot = fastEntry.slot, ammo = liveAmmo})
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
                        LSLegacy.Events.SendToServer('removeAmmo', Config.AmmoForWeapon[currentWeapon], ammoNeeded, currentWeapon)
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

LSLegacy.Events.Register('setAmmo', function(name, count, forWeapon)
    -- `forWeapon` transmis par le serveur = l'arme réellement rechargée.
    -- Repli sur la recherche inverse (ambiguë dès que plusieurs armes
    -- partagent la même munition) uniquement si absent, pour compatibilité.
    local weaponName = forWeapon or ReverseSearchConfigAmmo(name)
    AddAmmoToPed(PlayerPedId(), GetHashKey(weaponName), count)
    Citizen.SetTimeout(100, function()
        local newAmmo = GetAmmoInPedWeapon(PlayerPedId(), GetHashKey(weaponName))
        LSLegacy.Events.SendToServer('updateWeaponAmmo', weaponName, newAmmo)
    end)
end)

local lastInventoryToggle = 0
Keys.Register('TAB', 'TAB', 'Ouverture inventaire', function()
    if GetGameTimer() - lastInventoryToggle < 600 then return end
    if LSLegacy.IsCuffed then return end
    lastInventoryToggle = GetGameTimer()

    -- Bloquer l'inventaire si le joueur pilote un véhicule armé
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(veh, -1) == ped and DoesVehicleHaveWeapons(veh) then
            return
        end
    end

    if not isInInventory then
        openInventory()
    elseif isInInventory then
        if viewOnlyMode then
            closeViewInventory()
        else
            closeInventory()
        end
    end
end)

-- local lastInventoryToggle = 0

-- RegisterCommand('test', function()
--     if GetGameTimer() - lastInventoryToggle < 600 then return end
--     lastInventoryToggle = GetGameTimer()
--     if not isInInventory then
--         openInventory()
--     elseif isInInventory then
--         closeInventory()
--     end
-- end)

local lastTrunkToggle = 0
Keys.Register('K', 'K', 'Ouvrir le coffre du véhicule', function()
    if isInInventory then return end
    if GetGameTimer() - lastTrunkToggle < 600 then return end
    lastTrunkToggle = GetGameTimer()
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

Keys.Register('1', '1', 'Slot 1', function()
    useitem(1)
end)

Keys.Register('2', '2', 'Slot 2', function()
    useitem(2)
end)

Keys.Register('3', '3', 'Slot 3', function()
    useitem(3)
end)

Keys.Register('4', '4', 'Slot 4', function()
    useitem(4)
end)

Keys.Register('5', '5', 'Slot 5', function()
    useitem(5)
end)


local previewPed=nil

local FaceFeatureMap={
    nose_1=0,nose_2=1,nose_3=2,nose_4=3,nose_5=4,nose_6=5,
    eyebrows_5=6,eyebrows_6=7,
    cheeks_1=8,cheeks_2=9,cheeks_3=10,
    eye_squint=11,lip_thickness=12,
    jaw_1=13,jaw_2=14,
    chin_1=15,chin_2=16,chin_3=17,chin_4=18,
    neck_thickness=19
}

local OverlayMap={
    blemishes_1={id=0,opa="blemishes_2"},
    beard_1={id=1,opa="beard_2",c1="beard_3",c2="beard_4",colorType=1},
    eyebrows_1={id=2,opa="eyebrows_2",c1="eyebrows_3",c2="eyebrows_4",colorType=1},
    age_1={id=3,opa="age_2"},
    makeup_1={id=4,opa="makeup_2",c1="makeup_3",c2="makeup_4",colorType=2},
    blush_1={id=5,opa="blush_2",c1="blush_3",colorType=2},
    complexion_1={id=6,opa="complexion_2"},
    sun_1={id=7,opa="sun_2"},
    lipstick_1={id=8,opa="lipstick_2",c1="lipstick_3",c2="lipstick_4",colorType=2},
    moles_1={id=9,opa="moles_2"},
    chest_1={id=10,opa="chest_2",c1="chest_3",colorType=1},
    bodyb_1={id=11,opa="bodyb_2"}
}

local ClothesMap={
    mask_1={cid=1,tex="mask_2"},
    arms_1={cid=3,tex="arms_2"},
    pants_1={cid=4,tex="pants_2"},
    bags_1={cid=5,tex="bags_2"},
    shoes_1={cid=6,tex="shoes_2"},
    chain_1={cid=7,tex="chain_2"},
    tshirt_1={cid=8,tex="tshirt_2"},
    bproof_1={cid=9,tex="bproof_2"},
    decals_1={cid=10,tex="decals_2"},
    torso_1={cid=11,tex="torso_2"}
}

local PropMap={
    helmet_1={pid=0,tex="helmet_2"},
    glasses_1={pid=1,tex="glasses_2"},
    ears_1={pid=2,tex="ears_2"},
    watches_1={pid=6,tex="watches_2"},
    bracelets_1={pid=7,tex="bracelets_2"}
}

local function clamp(v,min,max)
    if v<min then return min end
    if v>max then return max end
    return v
end

local function applyHeadBlend(ped,skin)
    SetPedHeadBlendData(
        ped,
        skin.mom or 0,
        skin.dad or 0,
        0,
        skin.mom or 0,
        skin.dad or 0,
        0,
        clamp((skin.face_md_weight or 50)/100,0.0,1.0),
        clamp((skin.skin_md_weight or 50)/100,0.0,1.0),
        0.0,
        false
    )
end

local function applyFaceFeatures(ped,skin)
    for name,id in pairs(FaceFeatureMap) do
        if skin[name]~=nil then
            SetPedFaceFeature(ped,id,clamp(skin[name]/10,-1.0,1.0))
        end
    end
end

local function applyOverlays(ped,skin)
    for field,data in pairs(OverlayMap) do
        if skin[field]~=nil then
            local drawable=skin[field]
            if drawable<0 then drawable=255 end

            SetPedHeadOverlay(
                ped,
                data.id,
                drawable,
                clamp((skin[data.opa] or 0)/10,0.0,1.0)
            )

            if data.colorType then
                SetPedHeadOverlayColor(
                    ped,
                    data.id,
                    data.colorType,
                    skin[data.c1] or 0,
                    skin[data.c2] or 0
                )
            end
        end
    end
end

local function applyHair(ped,skin)
    SetPedComponentVariation(
        ped,
        2,
        skin.hair_1 or 0,
        skin.hair_2 or 0,
        0
    )

    SetPedHairColor(
        ped,
        skin.hair_color_1 or 0,
        skin.hair_color_2 or 0
    )
end

local function applyEyeColor(ped,skin)
    if skin.eye_color~=nil then
        SetPedEyeColor(
            ped,
            clamp(skin.eye_color,0,31)
        )
    end
end

local function applyClothes(ped,skin)
    for name,data in pairs(ClothesMap) do
        if skin[name]~=nil then
            SetPedComponentVariation(
                ped,
                data.cid,
                skin[name],
                skin[data.tex] or 0,
                0
            )
        end
    end
end

local function applyProps(ped,skin)
    for name,data in pairs(PropMap) do
        if skin[name]~=nil then
            if skin[name]==-1 then
                ClearPedProp(ped,data.pid)
            else
                SetPedPropIndex(
                    ped,
                    data.pid,
                    skin[name],
                    skin[data.tex] or 0,
                    true
                )
            end
        end
    end
end

local function applySkin(ped,skin)
    SetPedDefaultComponentVariation(ped)
    applyHeadBlend(ped,skin)
    applyHair(ped,skin)
    applyEyeColor(ped,skin)
    applyOverlays(ped,skin)
    applyFaceFeatures(ped,skin)
    applyClothes(ped,skin)
    applyProps(ped,skin)
end

local function createPedScreen(skin)
    local model=skin.sex==0 and `mp_m_freemode_01` or `mp_f_freemode_01`

    RequestModel(model)

    while not HasModelLoaded(model) do
        Wait(0)
    end

    local playerPed=PlayerPedId()
    local coords=GetEntityCoords(playerPed)
    local heading=GetEntityHeading(playerPed)

    SetFrontendActive(true)

    ActivateFrontendMenu(
        GetHashKey("FE_MENU_VERSION_EMPTY_NO_BACKGROUND"),
        false,
        -1
    )

    Wait(100)

    SetMouseCursorVisible(false)

    previewPed=CreatePed(
        4,
        model,
        coords.x,
        coords.y,
        coords.z-100.0,
        heading,
        false,
        false
    )

    SetModelAsNoLongerNeeded(model)

    SetEntityAsMissionEntity(previewPed,true,true)
    FreezeEntityPosition(previewPed,true)
    SetEntityInvincible(previewPed,true)
    SetEntityCollision(previewPed,false,false)
    SetEntityVisible(previewPed,false,false)
    NetworkSetEntityInvisibleToNetwork(previewPed,true)

    applySkin(previewPed,skin)

    GivePedToPauseMenu(previewPed,1)

    SetPauseMenuPedLighting(true)
    SetPauseMenuPedSleepState(true)

    ReplaceHudColourWithRgba(
        117,
        0,
        0,
        0,
        0
    )
end

local function deletePedScreen()
    if DoesEntityExist(previewPed) then
        SetEntityAsMissionEntity(previewPed,true,true)
        DeleteEntity(previewPed)
        previewPed=nil
    end

    SetFrontendActive(false)

    ReplaceHudColourWithRgba(
        117,
        0,
        0,
        0,
        190
    )
end

local function refreshPedScreen()
    if not DoesEntityExist(previewPed) then return end

    TriggerEvent("skinchanger:getSkin",function(skin)
        deletePedScreen()
        Wait(100)
        createPedScreen(skin)
    end)
end

RegisterCommand("p1",function()
    TriggerEvent("skinchanger:getSkin",function(skin)
        createPedScreen(skin)
    end)
end)

RegisterCommand("p2",function()
    deletePedScreen()
end)

RegisterCommand("p3",function()
    refreshPedScreen()
end)

CreateThread(function()

    while DoesEntityExist(previewPed) do

        print(
            "PREVIEW:",
            previewPed,
            "EXISTS:",
            DoesEntityExist(previewPed),
            "VISIBLE:",
            IsEntityVisible(previewPed),
            "MODEL:",
            GetEntityModel(previewPed)
        )

        Wait(100)
    end

    print("!!! PREVIEW PED DELETED !!!")

end)

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

-- Les vêtements équipés / la tenue active sont mis en cache localement (KVP,
-- stocké sur la machine du joueur — le serveur n'y a pas accès). Sans les
-- faire dépendre de l'identifier + du slot du personnage chargé, tous les
-- personnages d'un même compte (et même les comptes différents utilisés sur
-- le même PC) partageraient exactement le même cache.
local EquippedClothSlots = {}

local function getCharacterKvpSuffix()
    local identifier = LSLegacy.PlayerData and LSLegacy.PlayerData.identifier
    if not identifier then return nil end
    local slot = LSLegacy.PlayerData.slot or 1
    return '_' .. identifier:gsub('[^%w]', '_') .. '_' .. tostring(slot)
end

local function equippedSlotsKey()
    local suffix = getCharacterKvpSuffix()
    return suffix and ('LSLegacy_EquippedSlots' .. suffix) or nil
end

local function equippedOutfitKey()
    local suffix = getCharacterKvpSuffix()
    return suffix and ('LSLegacy_EquippedOutfit' .. suffix) or nil
end

local function loadEquippedSlots()
    local key = equippedSlotsKey()
    local saved = key and GetResourceKvpString(key)
    EquippedClothSlots = (saved and json.decode(saved)) or {}
end

function getEquippedSlots()
    return EquippedClothSlots
end

local function saveEquippedSlots()
    local key = equippedSlotsKey()
    if key then SetResourceKvp(key, json.encode(EquippedClothSlots)) end
end

local function getEquippedOutfit()
    local key = equippedOutfitKey()
    local saved = key and GetResourceKvpString(key)
    return (saved and json.decode(saved)) or nil
end

-- Raccourcis d'inventaire (FastWeapons, déclaré en haut du fichier) : même
-- traitement par personnage que les vêtements équipés ci-dessus.
local function fastWeaponsKey()
    local suffix = getCharacterKvpSuffix()
    return suffix and ('LSLegacy_FastWeapons' .. suffix) or nil
end

local function loadFastWeapons()
    local key = fastWeaponsKey()
    FastWeapons = (key and GetFieldValueFromName(key)) or {}
end

local function saveFastWeapons()
    local key = fastWeaponsKey()
    if key then SetFieldValueFromNameEncode(key, FastWeapons) end
end

-- Rechargé à chaque InitPlayer : à la connexion initiale, mais aussi après
-- un changement de personnage en cours de session (module/multichar,
-- "Retour à la sélection"), qui redéclenche InitPlayer pour le nouveau
-- personnage choisi.
LSLegacy.Events.AddHandler('lslegacy:initPlayer', function()
    loadEquippedSlots()
    loadFastWeapons()
end)

function openInventory()
    isInInventory = true
    ExecuteCommand('p1')
    currentMenu = 'items'
    loadPlayerInventory(currentMenu)
    SendNUIMessage({action = "display", type = "normal"})
    SendNUIMessage({action = "setWeightText", text = ""})
    SendNUIMessage({action = "setEquippedSlots", slots = getEquippedSlots()})
    SendNUIMessage({action = "setEquippedOutfit", outfit = getEquippedOutfit()})
    SetNuiFocus(true, true)
    SetKeepInputMode(true)
    DisableControlInventory()
    DisplayRadar(false)
    LSLegacy.Status.Displayed = false
end

function closeInventory()
    isInInventory = false
    viewOnlyMode  = false
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

    if CurrentContainer ~= nil then
        TriggerEvent('inventory:containerClosed', CurrentContainer.name)
        CurrentContainer = nil
    end
end

-- Inventaire lecture seule (admin)

function openViewInventory(inventory, characterInfos, cash, dirty)
    viewOnlyMode = true
    local playerName = (characterInfos and characterInfos.Prenom and characterInfos.NDF)
        and (characterInfos.Prenom .. ' ' .. characterInfos.NDF) or 'Joueur'

    local items = {}
    for _, item in ipairs(inventory or {}) do
        table.insert(items, {
            label    = item.label,
            name     = item.name,
            count    = item.count,
            uniqueId = item.uniqueId,
            data     = item.data,
            type     = 'item_standard',
            ammo     = item.data and item.data.ammo or nil,
            usable   = false,
        })
    end
    -- Injecter l'argent comme items (même pattern que loadPlayerInventory)
    if cash and cash > 0 then
        table.insert(items, { label = 'Argent', name = 'money', count = cash, type = 'item_cash', usable = false })
    end
    if dirty and dirty > 0 then
        table.insert(items, { label = 'money', name = 'money', count = dirty, type = 'item_dirty', usable = false })
    end

    isInInventory = true
    SendNUIMessage({action = "display", type = "normal"})
    SendNUIMessage({
        action        = "setItems",
        itemList      = items,
        fastItems     = {},
        text          = "Inventaire de " .. playerName .. " (lecture seule)",
        crMenu        = 'items',
        equippedSlots = {},
        equippedOutfit = nil,
    })
    SetNuiFocus(true, true)
    SetKeepInputMode(true)
    DisableControlInventory()
    DisplayRadar(false)
    LSLegacy.Status.Displayed = false
end

function closeViewInventory()
    viewOnlyMode  = false
    isInInventory = false
    SendNUIMessage({action = "hide"})
    SetNuiFocus(false, false)
    SetKeepInputMode(false)
    DisplayRadar(true)
    LSLegacy.Status.Displayed = true
    TriggerEvent('admin:inventoryViewClosed')
end

AddEventHandler('inventory:viewExternal', function(inv, ci, cash, dirty)
    openViewInventory(inv, ci, cash, dirty)
end)

function unloadWeapon(name, count)
    if Config.AmmoForWeapon[name] then
        LSLegacy.Events.SendToServer('giveItem', Config.AmmoForWeapon[name], count)
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

-- Prépare le transfert d'une arme : synchro ammo, déséquipement, retrait du ped et du fast slot
function prepareWeaponTransfer(itemName, itemData)
    if not string.match(itemName, "weapon_") then return end
    local weaponHash = GetHashKey(itemName)
    local playerPed = PlayerPedId()
    if HasPedGotWeapon(playerPed, weaponHash, false) then
        if itemData then
            itemData.ammo = GetAmmoInPedWeapon(playerPed, weaponHash)
        end
        if currentWeapon == itemName then
            GiveWeaponToPed(playerPed, "weapon_unarmed", 0, false, true)
            currentWeapon = nil
        end
        RemoveWeaponFromPed(playerPed, weaponHash)
    end
    local fastEntry = SearchInFastWeapons(itemName)
    if fastEntry then
        FastWeapons[fastEntry.slot] = nil
        saveFastWeapons()
    end
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
        return LSLegacy.Utils.Math.Round(weight, 1) .. 'KG'
    else
        return LSLegacy.Utils.Math.Round(weight*1000, 1) .. 'G'
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
                    LSLegacy.Events.SendToServer('useItem', FastWeapons[num].name)
                else
                    LSLegacy.Events.SendToServer('useItem', FastWeapons[num].name, FastWeapons[num].data, FastWeapons[num].uniqueId)
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
                slot = k,
                ammo = v.ammo
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
            table.insert(items, {
                label = v.label,
                name = v.name,
                count = v.count,
                uniqueId = v.uniqueId,
                data = v.data,
                type = "item_standard",
                ammo = v.data and v.data.ammo or nil,
                usable = true
            })
        end
        SendNUIMessage({ action = "setItems", itemList = items, fastItems = fastItems, text = textweight, crMenu = result, equippedSlots = EquippedClothSlots, equippedOutfit = getEquippedOutfit()})
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
        SendNUIMessage({ action = "setItems", itemList = items, fastItems = fastItems, text = textweight, crMenu = result, equippedSlots = EquippedClothSlots, equippedOutfit = getEquippedOutfit()})
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
        SendNUIMessage({ action = "setItems", itemList = items, fastItems = fastItems, text = textweight, crMenu = result, equippedSlots = EquippedClothSlots, equippedOutfit = getEquippedOutfit()})
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
    if viewOnlyMode then
        closeViewInventory()
    else
        closeInventory()
    end
    SetKeepInputMode(false)
end)

RegisterNUICallback("GetNearPlayers", function(data, cb)
    if viewOnlyMode then cb("ok") return end
    closeInventory()
    local target = GetNearbyPlayer(3.0)
    if target then
        local transferData = data.item.data
        prepareWeaponTransfer(data.item.name, transferData)
        LSLegacy.Events.SendToServer('transfer', {
            name = data.item.name,
            count = data.number,
            label = data.item.label,
            target = GetPlayerServerId(target),
            uniqueId = data.item.uniqueId,
            data = transferData,
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
    if viewOnlyMode then cb("ok") return end
    if data.item.type == "item_standard" then
        closeInventory()
        local result = KeyboardInput(data.item.label, 30)
        if result ~= nil then
            local count = tonumber(data.number)
            if result ~= data.item.label and tonumber(count) and count ~= nil then
                LSLegacy.Events.SendToServer("renameItem", data.item.name, data.item.label, result, count, data.item.uniqueId)
            else
                LSLegacy.ShowNotification(nil, "Impossible l'item a déjà ce label.", 'error')
            end
        end
    end 
end)

RegisterNUICallback("SwapItemPosition", function(data, cb)
    if viewOnlyMode then cb("ok") return end
    if data.itemA and data.itemB then
        LSLegacy.Events.SendToServer('swapItemPosition', data.itemA, data.itemB)
    end
    cb("ok")
end)

RegisterNUICallback("UnloadWeapon", function(data, cb)
    if viewOnlyMode then cb("ok") return end
    if currentMenu == "weapons" or currentMenu == "items" then
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
            local fastEntry = SearchInFastWeapons(data.item.name)
            if fastEntry then
                FastWeapons[fastEntry.slot].ammo = 0
                saveFastWeapons()
            end
            LSLegacy.Events.SendToServer('updateWeaponAmmo', data.item.name, 0)
            cb('ok')
        end
    end
end)

RegisterNUICallback("UseItem", function(data, cb)
    if viewOnlyMode then cb("ok") return end
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
                        skins['bproof'] = {skin.bproof_1, skin.bproof_2}
                    end)

                    if skins[data.item.name][1] ~= data.item.data[1] or skins[data.item.name][2] ~= data.item.data[2] then
                        LSLegacy.Events.TriggerLocal('skinchanger:change', data.item.name..'_1', data.item.data[1])
                        LSLegacy.Events.TriggerLocal('skinchanger:change', data.item.name..'_2', data.item.data[2])
                        ExecuteCommand('p3')
                        loadPlayerInventory('clothes', CurrentVehicle)
                    else
                        LSLegacy.Events.TriggerLocal('skinchanger:change', data.item.name..'_1', clothes[1])
                        LSLegacy.Events.TriggerLocal('skinchanger:change', data.item.name..'_2', clothes[2])
                        ExecuteCommand('p3')
                        loadPlayerInventory('clothes', CurrentVehicle)
                    end
                else
                    LSLegacy.Events.SendToServer('useItem', data.item.name, data.item.data, data.item.uniqueId)
                end
            else
                LSLegacy.Events.SendToServer('useItem', data.item.name)
            end
        end
    end
    if (currentMenu == 'weapons' or currentMenu == 'items') and not ItemVetement[data.item.name] then
        closeInventory()
    end
    cb("ok")
end)

RegisterNUICallback("EquipClothing", function(data, cb)
    if viewOnlyMode then cb("ok") return end
    local clothes = ItemVetement[data.item.name]
    if clothes and next(data.item.data) ~= nil then
        local drawable = data.item.data[1]
        local texture  = data.item.data[2]
        if isValidClothingVariation(data.item.name, drawable, texture) then
            LSLegacy.Events.TriggerLocal('skinchanger:change', data.item.name..'_1', drawable)
            LSLegacy.Events.TriggerLocal('skinchanger:change', data.item.name..'_2', texture)
        else
            local def = getDefaultClothes()
            LSLegacy.Events.TriggerLocal('skinchanger:change', data.item.name..'_1', def[data.item.name][1])
            LSLegacy.Events.TriggerLocal('skinchanger:change', data.item.name..'_2', def[data.item.name][2])
            LSLegacy.ShowNotification(nil, "Ce vêtement n'est pas compatible avec ton modèle.", 'error')
        end
        EquippedClothSlots[data.item.name] = { name = data.item.name, uniqueId = data.item.uniqueId }
        saveEquippedSlots()
        ExecuteCommand('p3')
    end
    cb("ok")
end)

RegisterNUICallback("UnequipClothing", function(data, cb)
    if viewOnlyMode then cb("ok") return end
    local def = getDefaultClothes()
    local clothes = def[data.item.name]
    if clothes then
        LSLegacy.Events.TriggerLocal('skinchanger:change', data.item.name..'_1', clothes[1])
        LSLegacy.Events.TriggerLocal('skinchanger:change', data.item.name..'_2', clothes[2])
        if data.item.name == 'tshirt' or data.item.name == 'torso' then
            LSLegacy.Events.TriggerLocal('skinchanger:change', 'arms_1', def['arms'][1])
            LSLegacy.Events.TriggerLocal('skinchanger:change', 'arms_2', def['arms'][2])
        end
        EquippedClothSlots[data.item.name] = nil
        saveEquippedSlots()
        ExecuteCommand('p3')
    end
    cb("ok")
end)


RegisterNUICallback("EquipOutfit", function(data, cb)
    if viewOnlyMode then cb("ok") return end
    local outfit = data.outfit
    if not outfit or not outfit.data then cb("ok") return end

    local clothingData = outfit.data

    for slot, vals in pairs(clothingData) do
        local drawable = 0
        local texture  = 0
        if type(vals) == 'table' then
            drawable = vals[1] or vals.drawable or 0
            texture  = vals[2] or vals.texture  or 0
        end
        if isValidClothingVariation(slot, drawable, texture) then
            LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_1', drawable)
            LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_2', texture)
        end
    end

    EquippedClothSlots = {}
    saveEquippedSlots()

    local outfitKey = equippedOutfitKey()
    if outfitKey then
        SetResourceKvp(outfitKey, json.encode({
            name     = outfit.label,
            uniqueId = outfit.uniqueId,
            data     = clothingData
        }))
    end

    ExecuteCommand('p3')
    cb("ok")
end)

RegisterNUICallback("UnequipOutfit", function(data, cb)
    if viewOnlyMode then cb("ok") return end
    local def = getDefaultClothes()
    for slot, values in pairs(def) do
        LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_1', values[1])
        LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_2', values[2])
    end

    local outfitKey = equippedOutfitKey()
    if outfitKey then DeleteResourceKvp(outfitKey) end

    ExecuteCommand('p3')
    cb("ok")
end)

RegisterNUICallback("SaveOutfitFromInventory", function(data, cb)
    if viewOnlyMode then cb("ok") return end
    local newSlots = data.newSlots or {}
    local def = getDefaultClothes()

    for slot, vals in pairs(newSlots) do
        local drawable = type(vals) == 'table' and (vals[1] or 0) or 0
        local texture  = type(vals) == 'table' and (vals[2] or 0) or 0
        if isValidClothingVariation(slot, drawable, texture) then
            LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_1', drawable)
            LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_2', texture)
        end
    end

    for slot, _ in pairs(data.removedSlots or {}) do
        if def[slot] then
            LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_1', def[slot][1])
            LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_2', def[slot][2])
        end
    end

    local currentOutfit = getEquippedOutfit()
    if currentOutfit and tostring(currentOutfit.uniqueId) == tostring(data.outfitUniqueId) then
        local outfitKey = equippedOutfitKey()
        if outfitKey then
            SetResourceKvp(outfitKey, json.encode({
                name     = data.outfitLabel or currentOutfit.name,
                uniqueId = data.outfitUniqueId,
                data     = newSlots
            }))
        end
    end

    LSLegacy.Events.SendToServer('inventory:updateOutfitFromInventory', {
        outfitUniqueId = data.outfitUniqueId,
        outfitLabel    = data.outfitLabel,
        newSlots       = newSlots,
        consumedItems  = data.consumedItems or {},
        removedSlots   = data.removedSlots  or {}
    })

    ExecuteCommand('p3')

    -- Recharger l'inventaire pour refléter les items créés/supprimés côté serveur
    Wait(400)
    loadPlayerInventory(currentMenu)

    cb("ok")
end)

RegisterNUICallback("OutfitEditApplyDefault", function(data, cb)
    if viewOnlyMode then cb("ok") return end
    local def = getDefaultClothes()
    local slot = data.slotType
    if slot and def[slot] then
        LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_1', def[slot][1])
        LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_2', def[slot][2])
        ExecuteCommand('p3')
    end
    cb("ok")
end)

RegisterNUICallback("OutfitEditApplySlot", function(data, cb)
    if viewOnlyMode then cb("ok") return end
    local slot     = data.slotType
    local drawable = tonumber(data.drawable) or 0
    local texture  = tonumber(data.texture)  or 0
    if slot and isValidClothingVariation(slot, drawable, texture) then
        LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_1', drawable)
        LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_2', texture)
        ExecuteCommand('p3')
    end
    cb("ok")
end)

RegisterNUICallback("DropItem", function(data, cb)
    if viewOnlyMode then cb("ok") return end
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        LSLegacy.ShowNotification(nil, "Vous ne pouvez pas jeter d'objets dans un véhicule.", 'error')
        return cb("ok")
    end
    if data.item.type == "item_standard" then
        local pPed = PlayerPedId()
        local pCoords = GetEntityCoords(pPed)
        local pHeading = GetEntityHeading(pPed)

        if tonumber(data.number) then
            prepareWeaponTransfer(data.item.name, data.item.data)
            LSLegacy.Events.SendToServer('addItemPickup', data.item.name, data.item.type, data.item.label, data.number, {x = pCoords.x, y = pCoords.y, z = pCoords.z, w = pHeading}, data.item.uniqueId, data.item.data)
            TaskPlayAnim(PlayerPedId(), "random@domestic", "pickup_low" , 8.0, -8.0, 1780, 35, 0.0, false, false, false)
        end
    elseif data.item.type ~= 'item_standard' then
        local pPed = PlayerPedId()
        local pCoords = GetEntityCoords(pPed)
        local pHeading = GetEntityHeading(pPed)
        
        if tonumber(data.number) then
            LSLegacy.Events.SendToServer('addItemPickup', data.item.type, nil, data.item.label, tonumber(data.number), {x = pCoords.x, y = pCoords.y, z = pCoords.z, w = pHeading})
            TaskPlayAnim(PlayerPedId(), "random@domestic", "pickup_low" , 8.0, -8.0, 1780, 35, 0.0, false, false, false)
        end
    end

    Wait(250)
    loadPlayerInventory(currentMenu)
    cb("ok")
end)

RegisterNUICallback("PutIntoFast", function(data, cb)
    if viewOnlyMode then cb("ok") return end
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
            ammo = data.item.data and data.item.data.ammo --- a changer pour eviter d'avoir full balles
        }
        saveFastWeapons()
        loadPlayerInventory(currentMenu, CurrentVehicle)
    end
    cb("ok")
end)

RegisterNUICallback("TakeFromFast", function(data, cb)
    if viewOnlyMode then cb("ok") return end
    if currentMenu == 'items' or currentMenu == 'weapons' then
        FastWeapons[data.item.slot] = nil
        saveFastWeapons()
        loadPlayerInventory(currentMenu, CurrentVehicle)
    end
	cb("ok")
end)

RegisterNUICallback("lslegacy:putIntoTrunk", function(data, cb)
    if viewOnlyMode then cb("ok") return end
    if CurrentContainer then
        prepareWeaponTransfer(data.item.name, data.item.data)
        LSLegacy.Events.SendToServer('lslegacy:putIntoTrunk', {
            name     = data.item.name,
            count    = data.number,
            label    = data.item.label,
            uniqueId = data.item.uniqueId,
            data     = data.item.data,
            type     = data.item.type
        }, CurrentContainer.name)
        Wait(120)
        loadContainerInventory()
        cb("ok")
        return
    end
    if BagOrTrunk(CurrentVehicle) == 'trunk' then
        datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(CurrentVehicle))
        Wait(250)
        prepareWeaponTransfer(data.item.name, data.item.data)
        LSLegacy.Events.SendToServer('lslegacy:putIntoTrunk', {
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
        prepareWeaponTransfer(data.item.name, data.item.data)
        LSLegacy.Events.SendToServer('lslegacy:putIntoTrunk', {
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

RegisterNUICallback("lslegacy:takeFromTrunk", function(data, cb)
    if viewOnlyMode then cb("ok") return end
    if CurrentContainer then
        LSLegacy.Events.SendToServer('lslegacy:takeFromTrunk', {
            name     = data.item.name,
            count    = data.number,
            label    = data.item.label,
            uniqueId = data.item.uniqueId,
            data     = data.item.data,
            type     = data.item.type
        }, CurrentContainer.name)
        Wait(120)
        loadContainerInventory()
        cb("ok")
        return
    end
    if BagOrTrunk(CurrentVehicle) == 'trunk' then
        datastore = LSLegacy.DataStore.GetTrunk(GetVehicleNumberPlateText(CurrentVehicle))
        Wait(250)
        LSLegacy.Events.SendToServer('lslegacy:takeFromTrunk', {
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
        LSLegacy.Events.SendToServer('lslegacy:takeFromTrunk', {
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

-- Conteneur générique (stash / porte-clés / ...) : réutilise l'UI "coffre" et le système
-- DataStore, piloté par un nom de DataStore au lieu d'un véhicule, via l'event
-- 'inventory:openContainer'. Accès gardé côté serveur par LSLegacy.DataStoreGuard.

CurrentContainer = nil  -- { name, label, maxWeight }

local function buildSelfItemsList()
    local list, fast = {}, {}
    if json.encode(FastWeapons) ~= "[]" then
        for k, v in pairs(FastWeapons) do
            table.insert(fast, {
                label = v.label, name = v.name, count = v.count, uniqueId = v.uniqueId,
                data = v.data, type = v.type, usable = false, slot = k, ammo = v.ammo,
            })
        end
    end
    local cash  = LSLegacy.PlayerData.cash or 0
    local dirty = LSLegacy.PlayerData.dirty or 0
    if cash > 0 then  table.insert(list, { label = 'Argent', name = 'money', count = cash, type = 'item_cash', usable = false }) end
    if dirty > 0 then table.insert(list, { label = 'Argent sale', name = 'money', count = dirty, type = 'item_dirty', usable = false }) end
    for _, v in pairs(LSLegacy.PlayerData.inventory or {}) do
        table.insert(list, {
            label = v.label, name = v.name, count = v.count, uniqueId = v.uniqueId,
            data = v.data, type = 'item_standard', ammo = v.data and v.data.ammo or nil, usable = true,
        })
    end
    return list, fast
end

-- (Re)charge l'affichage joueur + conteneur (appelée après chaque Put/Take).
function loadContainerInventory()
    if not CurrentContainer then return end
    local ds = LSLegacy.DataStores[CurrentContainer.name]
    if not ds then return end
    datastore   = ds   -- réutilisé par les callbacks Put/Take
    currentMenu = 'items'

    local selfList, fast = buildSelfItemsList()
    local weight = GramsOrKg(LSLegacy.PlayerData.weight or 0)
    SendNUIMessage({
        action        = "setItems",
        itemList      = selfList,
        fastItems     = fast,
        text          = weight .. " / " .. Config.Informations["MaxWeight"] .. 'KG',
        crMenu        = 'items',
        equippedSlots = getEquippedSlots(),
        equippedOutfit = getEquippedOutfit(),
    })

    local inv = (type(ds.inventory) == 'table') and ds.inventory or {}
    local contList = {}
    for _, v in pairs(inv) do
        table.insert(contList, {
            label = v.label, name = v.name, count = v.count, uniqueId = v.uniqueId,
            data = v.data, type = 'item_standard', ammo = v.data and v.data.ammo or nil, usable = false,
        })
    end
    SendNUIMessage({ action = "setSecondInventoryItems", itemList = contList })

    local cw = GramsOrKg(LSLegacy.DataStore.GetInventoryWeight(inv) or 0)
    SendNUIMessage({
        action = "setInfoText",
        text   = (CurrentContainer.label or "Conteneur") .. " : " .. cw .. " / " .. (CurrentContainer.maxWeight or 0) .. "KG",
    })
end

function openContainerInventory(name, label, maxWeight)
    -- Attend que le DataStore soit présent côté client (synchro serveur)
    local timeout = GetGameTimer() + 2000
    while not LSLegacy.DataStores[name] and GetGameTimer() < timeout do Wait(50) end
    if not LSLegacy.DataStores[name] then
        LSLegacy.ShowNotification(nil, "Conteneur indisponible.", 'error')
        return
    end
    CurrentContainer = { name = name, label = label, maxWeight = maxWeight or LSLegacy.DataStores[name].maxWeight or 0 }
    CurrentVehicle   = nil
    isInInventory    = true
    ExecuteCommand('p1')
    SendNUIMessage({ action = "display", type = "trunk" })
    SendNUIMessage({ action = "setWeightText", text = "" })
    loadContainerInventory()
    SetNuiFocus(true, true)
    SetKeepInputMode(true)
    DisableControlInventory()
    DisplayRadar(false)
    LSLegacy.Status.Displayed = false
end

AddEventHandler('inventory:openContainer', function(name, label, maxWeight)
    if isInInventory then return end
    openContainerInventory(name, label, maxWeight)
end)