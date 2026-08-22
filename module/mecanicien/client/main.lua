--  MODULE MÉCANICIEN — Client principal
--  Gestion : prise/fin de service, tenue, garage, dépôt pièces, blips
--  Interactions : ox_target (zones) + ox_lib (menus)

Mecanicien = Mecanicien or {}
Mecanicien.OnDuty    = false
Mecanicien.Grade     = 0
Mecanicien.InUniform = false
Mecanicien.HeldPart  = nil   -- nom de l'item actuellement porté en main (ou nil)
Mecanicien.HeldProp  = nil   -- entité du prop attaché

local function Notify(msg, type)
    TriggerEvent('notify', 'Mécanicien', msg, type or 'info', 5000)
end

-- Utilitaires

local function IsMecanicien()
    return LSLegacy.PlayerData.job == Config.Mecanicien.Job
end

local function GetGrade()
    return tonumber(LSLegacy.PlayerData.job_grade) or 0
end

local function GetFullName()
    local ci = LSLegacy.PlayerData.characterInfos
    if ci then
        return (ci.Prenom or '') .. ' ' .. (ci.NDF or '')
    end
    return 'Mécanicien'
end

-- Blips

local function CreateBlips()
    for _, b in ipairs(Config.Mecanicien.Blips or {}) do
        local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
        SetBlipSprite(blip, b.sprite)
        SetBlipColour(blip, b.color)
        SetBlipScale(blip, b.scale)
        SetBlipAsShortRange(blip, b.short)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(b.label)
        EndTextCommandSetBlipName(blip)
    end
end

-- Prise de service

local function GoOnDuty()
    if Mecanicien.OnDuty then Notify(Lang.Mecanicien.already_on_duty, 'error') return end
    Mecanicien.OnDuty = true
    Mecanicien.Grade  = GetGrade()

    LSLegacy.Events.SendToServer('mecanicien:onDuty')
    Notify(Lang.Mecanicien.duty_on, 'success')
    --TriggerEvent('mecanicien:dutyChanged', true)
end

local function GoOffDuty()
    if not Mecanicien.OnDuty then Notify(Lang.Mecanicien.already_off_duty, 'error') return end
    if Mecanicien.InUniform then
        Notify('Changez de tenue au vestiaire avant de quitter le service.', 'error')
        return
    end
    Mecanicien.OnDuty = false

    LSLegacy.Events.SendToServer('mecanicien:offDuty')
    Notify(Lang.Mecanicien.duty_off, 'info')
    --TriggerEvent('mecanicien:dutyChanged', false)
end

local function ToggleDuty()
    if not IsMecanicien() then Notify(Lang.Mecanicien.not_mecanicien, 'error') return end
    if Mecanicien.OnDuty then
        GoOffDuty()
    else
        GoOnDuty()
    end
end

-- Tenue

local function ApplyOutfit(outfit)
    local ped    = PlayerPedId()
    local isMale = GetEntityModel(ped) == GetHashKey('mp_m_freemode_01')
    local t      = isMale and outfit.male or outfit.female
    SetPedComponentVariation(ped, 3, t.torso_1,  t.torso_2,  2)
    SetPedComponentVariation(ped, 4, t.pants_1,  t.pants_2,  2)
    SetPedComponentVariation(ped, 6, t.shoes_1,  t.shoes_2,  2)
    SetPedComponentVariation(ped, 8, t.tshirt_1, t.tshirt_2, 2)
    SetPedPropIndex(ped, 0, t.helmet_1, t.helmet_2, false)
end

local function OpenClothingMenu()
    if not Mecanicien.OnDuty then Notify(Lang.Mecanicien.not_mecanicien, 'error') return end

    local options = {
        {
            title = 'Tenue civile',
            description = 'Restaurer la tenue personnelle',
            icon = 'fa-solid fa-shirt',
            onSelect = function()
                TriggerEvent('skinchanger:loadSkin', LSLegacy.PlayerData.skin)
                Mecanicien.InUniform = false
                Notify('Tenue civile restaurée.', 'success')
            end,
        },
    }

    for _, outfit in ipairs(Config.Mecanicien.Outfits) do
        local available = Mecanicien.Grade >= outfit.grade
        options[#options + 1] = {
            title = outfit.label,
            description = available and ('Grade ' .. outfit.grade .. '+') or ('Grade ' .. outfit.grade .. '+ requis'),
            icon = 'fa-solid fa-shirt',
            disabled = not available,
            onSelect = function()
                ApplyOutfit(outfit)
                Mecanicien.InUniform = true
                Notify('Tenue appliquée : ' .. outfit.label, 'success')
            end,
        }
    end

    lib.registerContext({ id = 'mecanicien_clothing', title = 'Mécanicien — Vestiaire', options = options })
    lib.showContext('mecanicien_clothing')
end

-- Garage

local function OpenGarageMenu()
    if not Mecanicien.OnDuty then Notify(Lang.Mecanicien.not_mecanicien, 'error') return end

    local options = {}
    for category, vehicles in pairs(Config.Mecanicien.Vehicles) do
        for _, veh in ipairs(vehicles) do
            local available = Mecanicien.Grade >= veh.grade
            options[#options + 1] = {
                title = veh.label,
                description = available and string.upper(veh.model) or ('Grade ' .. veh.grade .. '+ requis'),
                icon = 'fa-solid fa-truck-pickup',
                disabled = not available,
                onSelect = function()
                    LSLegacy.Events.SendToServer('mecanicien:spawnVehicle', {
                        model    = veh.model,
                        category = category,
                        grade    = veh.grade,
                    })
                    Notify(Lang.Mecanicien.vehicle_spawned, 'success')
                end,
            }
        end
    end

    lib.registerContext({ id = 'mecanicien_garage', title = 'Mécanicien — Garage', options = options })
    lib.showContext('mecanicien_garage')
end

-- Dépôt de pièces

local function AttachHeldPart(itemName)
    local part = Config.Mecanicien.Parts[itemName]
    if not part or not part.carried then return end

    -- Détache l'ancien prop si présent
    if Mecanicien.HeldProp and DoesEntityExist(Mecanicien.HeldProp) then
        DeleteEntity(Mecanicien.HeldProp)
    end

    local ped  = PlayerPedId()
    local hash = GetHashKey(part.prop)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(100); t = t + 1 end
    if not HasModelLoaded(hash) then return end

    local prop = CreateObject(hash, GetEntityCoords(ped), true, true, true)
    local bone = GetEntityBoneIndexByName(ped, Config.Mecanicien.PartHandBone)
    local off  = Config.Mecanicien.PartHandOffset
    local rot  = Config.Mecanicien.PartHandRot
    AttachEntityToEntity(prop, ped, bone, off.x, off.y, off.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)

    Mecanicien.HeldPart = itemName
    Mecanicien.HeldProp = prop
end

local function DropHeldPart(silent)
    if Mecanicien.HeldProp and DoesEntityExist(Mecanicien.HeldProp) then
        DeleteEntity(Mecanicien.HeldProp)
    end
    Mecanicien.HeldPart = nil
    Mecanicien.HeldProp = nil
    if not silent then Notify(Lang.Mecanicien.drop_part, 'info') end
end

RegisterCommand('mecanicien_drop_part', function()
    if not Mecanicien.HeldPart then return end
    DropHeldPart()
end, false)

RegisterKeyMapping('mecanicien_drop_part', 'Lâcher la pièce portée (Mécanicien)', 'keyboard', 'G')

local function OpenPartsDepot()
    if not Mecanicien.OnDuty then Notify(Lang.Mecanicien.not_mecanicien, 'error') return end
    if Mecanicien.HeldPart then Notify(Lang.Mecanicien.depot_already_holding, 'error') return end

    LSLegacy.Events.SendToServer('mecanicien:requestStock')
end

LSLegacy.Events.Register('mecanicien:stockResult', function(stock)
    stock = stock or {}
    local options = {}

    for itemName, part in pairs(Config.Mecanicien.Parts) do
        local qty       = stock[itemName] or 0
        local available = qty > 0
        options[#options + 1] = {
            title = part.label .. (available and (' (x' .. qty .. ')') or ' — Rupture de stock'),
            description = available and Lang.Mecanicien.depot_buy or Lang.Mecanicien.depot_out_of_stock,
            icon = part.carried and 'fa-solid fa-hand-holding' or 'fa-solid fa-circle-dot',
            disabled = not available,
            onSelect = function()
                LSLegacy.Events.SendToServer('mecanicien:buyPart', { item = itemName })
            end,
        }
    end

    if Mecanicien.Grade >= 3 then
        options[#options + 1] = {
            title = 'Remplir le stock à la main',
            description = "Chef d'Atelier — après achat chez le grossiste",
            icon = 'fa-solid fa-truck-ramp-box',
            onSelect = function()
                local fillOptions = {}
                for itemName, part in pairs(Config.Mecanicien.Parts) do
                    fillOptions[#fillOptions + 1] = {
                        title = part.label .. ' (x' .. (stock[itemName] or 0) .. ')',
                        description = 'Ajouter une quantité au stock',
                        icon = 'fa-solid fa-box-open',
                        onSelect = function()
                            local qtyStr = LSLegacy.KeyboardInput('Quantité à ajouter au stock', 4)
                            local qty    = tonumber(qtyStr)
                            if not qty or qty <= 0 then return end
                            LSLegacy.Events.SendToServer('mecanicien:restockDepot', { item = itemName, amount = math.floor(qty) })
                        end,
                    }
                end
                lib.registerContext({ id = 'mecanicien_depot_fill', title = 'Remplir le stock', menu = 'mecanicien_depot', options = fillOptions })
                lib.showContext('mecanicien_depot_fill')
            end,
        }
    end

    lib.registerContext({ id = 'mecanicien_depot', title = Lang.Mecanicien.depot_title, options = options })
    lib.showContext('mecanicien_depot')
end)

LSLegacy.Events.Register('mecanicien:restockResult', function(data)
    if not data then return end
    if data.success then
        local part = data.item and Config.Mecanicien.Parts[data.item]
        Notify(string.format('%s ajouté(s) au stock : %s.', tostring(data.amount), part and part.label or data.item), 'success')
    end
end)

LSLegacy.Events.Register('mecanicien:partBought', function(data)
    if not data then return end
    Notify(string.format(Lang.Mecanicien.depot_part_bought, data.label), 'success')
    local part = Config.Mecanicien.Parts[data.item]
    if part and part.carried then
        AttachHeldPart(data.item)
    end
end)

-- Zones ox_target (Benny's)

exports.ox_target:addBoxZone({
    coords   = Config.Mecanicien.Headquarters,
    size     = vector3(2.0, 2.0, 2.0),
    rotation = Config.Mecanicien.HeadquartersHeading,
    debug    = false,
    options  = {
        {
            name = 'mecanicien_duty',
            icon = 'fa-solid fa-right-from-bracket',
            label = 'Prise / Fin de service',
            distance = 2.5,
            canInteract = function() return IsMecanicien() end,
            onSelect = ToggleDuty,
        },
    },
})

exports.ox_target:addBoxZone({
    coords   = Config.Mecanicien.ClothingCoords,
    size     = vector3(1.5, 1.5, 2.0),
    rotation = Config.Mecanicien.HeadquartersHeading,
    debug    = false,
    options  = {
        {
            name = 'mecanicien_clothing',
            icon = 'fa-solid fa-shirt',
            label = 'Vestiaire',
            distance = 2.0,
            canInteract = function() return IsMecanicien() end,
            onSelect = OpenClothingMenu,
        },
    },
})

exports.ox_target:addBoxZone({
    coords   = Config.Mecanicien.GarageCoords,
    size     = vector3(2.0, 2.0, 2.0),
    rotation = Config.Mecanicien.HeadquartersHeading,
    debug    = false,
    options  = {
        {
            name = 'mecanicien_garage',
            icon = 'fa-solid fa-truck-pickup',
            label = 'Garage',
            distance = 2.0,
            canInteract = function() return IsMecanicien() end,
            onSelect = OpenGarageMenu,
        },
    },
})

exports.ox_target:addBoxZone({
    coords   = Config.Mecanicien.PartsDepotCoords,
    size     = vector3(1.5, 1.5, 2.0),
    rotation = Config.Mecanicien.HeadquartersHeading,
    debug    = false,
    options  = {
        {
            name = 'mecanicien_depot',
            icon = 'fa-solid fa-boxes-stacked',
            label = 'Dépôt de pièces',
            distance = 2.0,
            canInteract = function() return IsMecanicien() end,
            onSelect = OpenPartsDepot,
        },
    },
})

-- Events serveur → client

LSLegacy.Events.Register('mecanicien:spawnVehicleClient', function(data)
    if not data or not data.model then return end
    local coords  = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    local hash    = GetHashKey(data.model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do
        Wait(100)
        t = t + 1
    end
    if not HasModelLoaded(hash) then
        Notify('Modèle introuvable : ' .. data.model, 'error')
        return
    end
    local spawnX = coords.x + math.sin(math.rad(-heading)) * 5.0
    local spawnY = coords.y + math.cos(math.rad(-heading)) * 5.0
    local veh = CreateVehicle(hash, spawnX, spawnY, coords.z, heading, true, false)
    SetVehicleNumberPlateText(veh, 'MECANO')
    SetPedIntoVehicle(PlayerPedId(), veh, -1)
    SetModelAsNoLongerNeeded(hash)
end)

-- Minijeu maison (barre + appui touche) — partagé actions/parts

local function DrawMinigameBar(pos, zoneStart, zoneEnd)
    DrawRect(0.5, 0.85, 0.3, 0.03, 30, 30, 30, 180)
    DrawRect(0.5 - 0.15 + zoneStart * 0.3, 0.85, (zoneEnd - zoneStart) * 0.3, 0.03, 50, 200, 50, 180)
    DrawRect(0.5 - 0.15 + pos * 0.3, 0.85, 0.004, 0.05, 255, 255, 255, 230)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName('~b~[E]~w~ Valider au bon moment')
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- RunMinigame
-- @param onComplete function appelé avec (hits, rounds, success)
function Mecanicien.RunMinigame(onComplete)
    local cfg          = Config.Mecanicien.Minigame
    local hits          = 0

    for _ = 1, cfg.rounds do
        local zoneStart = math.random(20, 70) / 100.0
        local zoneEnd   = math.min(1.0, zoneStart + cfg.zoneSize)
        local startTime = GetGameTimer()
        local done      = false
        local roundHit  = false
        local lastPos   = 0.0

        while not done do
            Wait(0)
            local elapsed = (GetGameTimer() - startTime) % cfg.roundDuration
            local t       = elapsed / cfg.roundDuration
            lastPos       = t < 0.5 and (t * 2) or (2 - t * 2)

            DrawMinigameBar(lastPos, zoneStart, zoneEnd)

            if IsControlJustReleased(0, 38) then -- E
                roundHit = lastPos >= zoneStart and lastPos <= zoneEnd
                done     = true
            end

            if (GetGameTimer() - startTime) > (cfg.roundDuration * 2) then
                done = true
            end
        end

        if roundHit then hits = hits + 1 end
        Wait(150)
    end

    local success = hits >= cfg.requiredHits
    onComplete(hits, cfg.rounds, success)
end

-- Init

Citizen.CreateThread(function()
    Wait(2000)
    if not IsMecanicien() then return end
    CreateBlips()
end)

-- Exporter l'état pour les autres sous-modules
function Mecanicien.IsOnDuty() return Mecanicien.OnDuty end
function Mecanicien.GetGrade() return Mecanicien.Grade end
function Mecanicien.GetName() return GetFullName() end
function Mecanicien.GetHeldPart() return Mecanicien.HeldPart end
function Mecanicien.ClearHeldPart() DropHeldPart(true) end
