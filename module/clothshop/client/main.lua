-- ════════════════════════════════════════════════
--  LSLegacy – ClothShop Client  (NUI version)
-- ════════════════════════════════════════════════

local shopState = {
    isOpen   = false,
    shopType = '',
    shopName = '',
    coords   = nil,
    lastSkin = nil,
    maxVals  = nil,
    pendingCart = nil,
}

-- ── Prop index map (for ClearPedProp on drawable -1) ─
local PROP_MAP = { helmet = 0, glasses = 1, ears = 2, watches = 6, bracelet = 7 }

-- 'bracelet' (singulier, nom d'item) vs 'bracelets_1/2' (champs skinchanger, pluriel)
local SKIN_FIELD_ALIAS = { bracelet = 'bracelets' }
local function SkinField(name) return SKIN_FIELD_ALIAS[name] or name end

-- ── Component index map (for texture variation queries) ─
local COMP_MAP = { tshirt = 8, torso = 11, arms = 3, pants = 4, shoes = 6, chain = 7, bags = 5, decals = 10, mask = 1, bproof = 9 }

-- ── Camera state ──────────────────────────────────
local shopCam        = nil
local shopCamPreset  = 'full'
local shopPedHeading = 180.0  -- ped faces +Y (Nord), caméra placée côté -Y
local pedBaseCoords  = nil

local CAM_PRESETS = {
    full  = { dist = 4.5,  height = 1.4,  lookH = 0.9,  fov = 50.0 },
    head  = { dist = 0.85, height = 0.72, lookH = 0.65, fov = 30.0 },
    torso = { dist = 1.3,  height = 0.2,  lookH = 0.15, fov = 35.0 },
    legs  = { dist = 1.4,  height = -0.4, lookH = -0.3, fov = 35.0 },
    feet  = { dist = 1.0,  height = -0.7, lookH = -0.85, fov = 28.0 },
}

-- Zoom molette / regard souris (clic gauche maintenu) : n'affectent jamais
-- les valeurs de base du preset actif, seulement des offsets bornés,
-- remis à zéro à chaque changement de preset / ouverture / fermeture.
local MIN_ZOOM_OFFSET   = -1.5
local MAX_ZOOM_OFFSET   = 2.5
local MIN_PITCH_OFFSET  = -15.0
local MAX_PITCH_OFFSET  = 15.0
local shopZoomOffset    = 0.0
local shopPitchOffset   = 0.0

-- ── Helpers ───────────────────────────────────────
local function GetPlayerClothingItems()
    local items = {}
    if LSLegacy.PlayerData and LSLegacy.PlayerData.inventory then
        for _, v in pairs(LSLegacy.PlayerData.inventory) do
            local clothTypes = {
                tshirt=true, torso=true, arms=true, pants=true, shoes=true,
                helmet=true, glasses=true, chain=true, bags=true, ears=true,
                watches=true, bracelet=true, mask=true, decals=true, bproof=true
            }
            if clothTypes[v.name] then
                table.insert(items, {
                    name     = v.name,
                    label    = v.label,
                    count    = v.count,
                    uniqueId = v.uniqueId,
                    data     = v.data,
                })
            end
        end
    end
    return items
end

local function GetPlayerOutfitItems()
    local items = {}
    if LSLegacy.PlayerData and LSLegacy.PlayerData.inventory then
        for _, v in pairs(LSLegacy.PlayerData.inventory) do
            if v.name == 'outfit' then
                table.insert(items, {
                    name     = v.name,
                    label    = v.label,
                    count    = v.count,
                    uniqueId = v.uniqueId,
                    data     = v.data,
                })
            end
        end
    end
    return items
end

local function StripPedClothes()
    local def = getDefaultClothes()
    if def then
        for slot, values in pairs(def) do
            LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_1', values[1] or 0)
            LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_2', values[2] or 0)
        end
    else
        local ped = PlayerPedId()
        for component = 0, 11 do
            SetPedComponentVariation(ped, component, 0, 0, 2)
        end
        for prop = 0, 9 do
            ClearPedProp(ped, prop)
        end
    end
end

-- ── Camera functions ──────────────────────────────
local function ApplyShopCamera()
    if not shopCam or not pedBaseCoords then return end
    local p = CAM_PRESETS[shopCamPreset] or CAM_PRESETS.full
    local dist = math.max(0.3, p.dist + shopZoomOffset)
    -- heading 180 = ped faces +Y → caméra côté -Y pour voir le visage
    local camX = pedBaseCoords.x
    local camY = pedBaseCoords.y - dist
    local camZ = pedBaseCoords.z + p.height
    local lookZ = pedBaseCoords.z + p.lookH
    SetCamCoord(shopCam, camX, camY, camZ)
    PointCamAtCoord(shopCam, pedBaseCoords.x, pedBaseCoords.y, lookZ)
    if shopPitchOffset ~= 0.0 then
        local rot = GetCamRot(shopCam, 2)
        SetCamRot(shopCam, rot.x + shopPitchOffset, rot.y, rot.z, 2)
    end
    SetCamFov(shopCam, p.fov)
end

-- Molette : ajuste la distance caméra (zoom) sans changer le preset actif.
local function AdjustShopZoom(delta)
    if not delta or delta == 0 then return end
    shopZoomOffset = math.max(MIN_ZOOM_OFFSET, math.min(MAX_ZOOM_OFFSET, shopZoomOffset + delta))
    ApplyShopCamera()
end

-- Clic gauche maintenu + déplacement souris : la caméra ne se déplace pas,
-- seul son angle change (dx tourne le personnage, dy incline la caméra).
local function AdjustShopLook(dx, dy)
    if dx and dx ~= 0 then
        shopPedHeading = (shopPedHeading + dx) % 360.0
        SetEntityHeading(PlayerPedId(), shopPedHeading)
    end
    if dy and dy ~= 0 then
        shopPitchOffset = math.max(MIN_PITCH_OFFSET, math.min(MAX_PITCH_OFFSET, shopPitchOffset + dy))
        ApplyShopCamera()
    end
end

local function CreateShopCamera()
    local ped = PlayerPedId()
    pedBaseCoords = GetEntityCoords(ped)
    shopPedHeading  = 180.0
    shopCamPreset   = 'full'
    shopZoomOffset  = 0.0
    shopPitchOffset = 0.0

    FreezeEntityPosition(ped, true)
    SetEntityHeading(ped, shopPedHeading)

    shopCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    ApplyShopCamera()
    SetCamActive(shopCam, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function DestroyShopCamera()
    -- Snap to full preset so blend back to gameplay cam starts from a sane position
    -- (avoids jarring transition when closing from head/feet presets)
    shopCamPreset   = 'full'
    shopZoomOffset  = 0.0
    shopPitchOffset = 0.0
    ApplyShopCamera()

    FreezeEntityPosition(PlayerPedId(), false)
    if shopCam then SetCamActive(shopCam, false) end
    RenderScriptCams(false, true, 300, true, true)

    Citizen.CreateThread(function()
        Wait(400)
        if shopCam then
            DestroyCam(shopCam, false)
            shopCam = nil
        end
        pedBaseCoords   = nil
        shopCamPreset   = 'full'
        shopPedHeading  = 180.0
        shopZoomOffset  = 0.0
        shopPitchOffset = 0.0
    end)
end

-- ── Open Clothshop NUI ────────────────────────────
function OpenClothShopNUI(header, type, coords)
    if shopState.isOpen then return end
    shopState.isOpen   = true
    shopState.shopType = type
    shopState.shopName = header
    shopState.coords   = coords

    Citizen.CreateThread(function()
        -- Capture skin BEFORE any preview changes can happen
        LSLegacy.Events.TriggerLocal('skinchanger:getSkin', function(skin)
            shopState.lastSkin = skin
        end)
        Wait(100)  -- let the callback fire (getSkin may be async)

        local maxVals = {}
        LSLegacy.Events.TriggerLocal('skinchanger:getData', function(components, max)
            maxVals = max or {}
            shopState.maxVals = maxVals
        end)
        Wait(50)

        local clothingItems = GetPlayerClothingItems()
        local outfitItems   = GetPlayerOutfitItems()

        SetNuiFocus(true, true)
        DisableClothShopControls()
        CreateShopCamera()

        Wait(100)
        SendNUIMessage({
            action          = 'clothshop:open',
            shopName        = header,
            shopType        = type,
            maxVals         = maxVals,
            playerInventory = clothingItems,
            outfitItems     = outfitItems,
        })
    end)
end

function DisableClothShopControls()
    Citizen.CreateThread(function()
        while shopState.isOpen do
            DisableControlAction(0, 24, true)   -- attack
            DisableControlAction(0, 69, true)   -- select weapon (Tab)
            DisableControlAction(0, 70, true)   -- next weapon
            DisableControlAction(0, 140, true)  -- melee
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            Wait(0)
        end
    end)
end

function CloseClothShopNUI()
    if not shopState.isOpen then return end
    shopState.isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'clothshop:hide' })
    DestroyShopCamera()
    -- Revert previewed clothes: fire after camera blend starts to avoid conflicts
    local savedSkin = shopState.lastSkin
    shopState.lastSkin = nil
    Citizen.CreateThread(function()
        Wait(200)
        if savedSkin then
            TriggerEvent('skinchanger:loadSkin', savedSkin)
        end
    end)
    LSLegacy.Status.Displayed = true
end

-- ── NUI Callbacks ─────────────────────────────────

RegisterNUICallback('clothshop:close', function(data, cb)
    CloseClothShopNUI()
    cb('ok')
end)

RegisterNUICallback('clothshop:preview', function(data, cb)
    local maxTex = 0
    if data.name and data.drawable ~= nil and data.texture ~= nil then
        if data.drawable == -1 then
            local propIdx = PROP_MAP[data.name]
            if propIdx ~= nil then
                ClearPedProp(PlayerPedId(), propIdx)
            end
        else
            LSLegacy.Events.TriggerLocal('skinchanger:change', data.name..'_1', data.drawable)
            LSLegacy.Events.TriggerLocal('skinchanger:change', data.name..'_2', data.texture)
            local ped    = PlayerPedId()
            local compId = COMP_MAP[data.name]
            local propId = PROP_MAP[data.name]
            if compId ~= nil then
                maxTex = math.max(0, GetNumberOfPedTextureVariations(ped, compId, data.drawable) - 1)
            elseif propId ~= nil then
                maxTex = math.max(0, GetNumberOfPedPropTextureVariations(ped, propId, data.drawable) - 1)
            end
        end
    end
    cb({ maxTex = maxTex })
end)

RegisterNUICallback('clothshop:revertSlot', function(data, cb)
    local slot = data.slot
    if not slot or not shopState.lastSkin then cb('ok') return end

    local propId = PROP_MAP[slot]
    if propId ~= nil then
        local field = SkinField(slot)
        local origDraw = shopState.lastSkin[field..'_1']
        if not origDraw or origDraw <= 0 then
            ClearPedProp(PlayerPedId(), propId)
        else
            LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_1', origDraw)
            LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_2', shopState.lastSkin[field..'_2'] or 0)
        end
    else
        LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_1', shopState.lastSkin[slot..'_1'] or 0)
        LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_2', shopState.lastSkin[slot..'_2'] or 0)
    end
    cb('ok')
end)

RegisterNUICallback('clothshop:camera', function(data, cb)
    if data.action == 'rotate' then
        shopPedHeading = (shopPedHeading + (data.dir or 1) * 30.0) % 360.0
        SetEntityHeading(PlayerPedId(), shopPedHeading)
    elseif data.action == 'preset' then
        shopCamPreset   = data.preset or 'full'
        shopZoomOffset  = 0.0
        shopPitchOffset = 0.0
        ApplyShopCamera()
    elseif data.action == 'zoom' then
        AdjustShopZoom(tonumber(data.delta) or 0)
    elseif data.action == 'look' then
        AdjustShopLook(tonumber(data.dx) or 0, tonumber(data.dy) or 0)
    end
    cb('ok')
end)

RegisterNUICallback('clothshop:checkout', function(data, cb)
    if not data.items or #data.items == 0 then cb('ok') return end

    shopState.pendingCart = data.items

    -- JS a déjà caché l'UI, on retire juste le focus NUI
    SetNuiFocus(false, false)

    local names = {}
    for _, item in ipairs(data.items) do
        table.insert(names, item.label)
    end
    local message = 'Achat: ' .. table.concat(names, ', ')

    LSLegacy.Events.SendToServer('attemptToPayMenu', message, data.total)

    paymentMenu.actions = {
        onSucess = function()
            Citizen.CreateThread(function()
                for _, item in ipairs(shopState.pendingCart) do
                    LSLegacy.Events.SendToServer('clothshop:addClothesInInventory', item.name, item.label, {item.drawable, item.texture})
                    Wait(100)
                end
                shopState.pendingCart = nil
                CloseClothShopNUI()
            end)
        end,
        onFailed = function()
            shopState.pendingCart = nil
            SetNuiFocus(true, true)
            SendNUIMessage({ action = 'clothshop:cartFailed' })
        end
    }
    cb('ok')
end)

RegisterNUICallback('clothshop:createOutfit', function(data, cb)
    CloseClothShopNUI()

    Citizen.CreateThread(function()
        Wait(150)
        StripPedClothes()
    end)

    LSLegacy.Events.SendToServer('clothshop:createOutfit', data.name, data.items, data.itemIds)
    cb('ok')
end)

RegisterNUICallback('clothshop:splitOutfit', function(data, cb)
    LSLegacy.Events.SendToServer('clothshop:splitOutfit', data.outfit)
    cb('ok')
end)

RegisterNUICallback('clothshop:modifyOutfit', function(data, cb)
    LSLegacy.Events.SendToServer('clothshop:modifyOutfit', data)
    CloseClothShopNUI()
    cb('ok')
end)

-- ── Server confirmation events ────────────────────

LSLegacy.Events.Register('clothshop:outfitCreated', function()
    Wait(300)
    local clothingItems = GetPlayerClothingItems()
    local outfitItems   = GetPlayerOutfitItems()
    SendNUIMessage({
        action          = 'clothshop:outfitCreated',
        playerInventory = clothingItems,
        outfitItems     = outfitItems,
    })
end)

LSLegacy.Events.Register('clothshop:outfitSplit', function()
    Wait(300)
    local clothingItems = GetPlayerClothingItems()
    local outfitItems   = GetPlayerOutfitItems()
    SendNUIMessage({
        action          = 'clothshop:outfitSplit',
        playerInventory = clothingItems,
        outfitItems     = outfitItems,
    })
end)

LSLegacy.Events.Register('clothshop:outfitModified', function()
    -- Shop déjà fermé, rien à faire
end)

-- ── Zone trigger ──────────────────────────────────

LSLegacy.Events.Register('openClothMenu', function(header, type, coords)
    OpenClothShopNUI(header, type, coords)
    LSLegacy.Status.Displayed = false
end)
