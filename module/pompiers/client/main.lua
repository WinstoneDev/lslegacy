--  MODULE SAPEURS-POMPIERS — Client principal
--  Gestion : prise/fin de service, tenue, garage, blips
--  Interactions : ox_target (zones) + ox_lib (menus)

Pompiers = Pompiers or {}
Pompiers.OnDuty    = false
Pompiers.Grade     = 0
Pompiers.InUniform = false

local function Notify(msg, type)
    TriggerEvent('notify', 'Sapeurs-Pompiers', msg, type or 'info', 5000)
end

-- Utilitaires

local function IsPompier()
    return LSLegacy.PlayerData.job == Config.Pompiers.Job
end

local function GetGrade()
    return tonumber(LSLegacy.PlayerData.job_grade) or 0
end

local function GetFullName()
    local ci = LSLegacy.PlayerData.characterInfos
    if ci then
        return (ci.Prenom or '') .. ' ' .. (ci.NDF or '')
    end
    return 'Sapeur-Pompier'
end

-- Blips

local function CreateBlips()
    for _, b in ipairs(Config.Pompiers.Blips or {}) do
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
    if Pompiers.OnDuty then Notify(Lang.Pompiers.already_on_duty, 'error') return end
    Pompiers.OnDuty = true
    Pompiers.Grade  = GetGrade()

    LSLegacy.Events.SendToServer('pompiers:onDuty')
    Notify(Lang.Pompiers.duty_on, 'success')
    TriggerEvent('pompiers:dutyChanged', true)
end

local function GoOffDuty()
    if not Pompiers.OnDuty then Notify(Lang.Pompiers.already_off_duty, 'error') return end
    if Pompiers.InUniform then
        Notify('Changez de tenue au vestiaire avant de quitter le service.', 'error')
        return
    end
    Pompiers.OnDuty = false

    LSLegacy.Events.SendToServer('pompiers:offDuty')
    Notify(Lang.Pompiers.duty_off, 'info')
    TriggerEvent('pompiers:dutyChanged', false)
end

local function ToggleDuty()
    if not IsPompier() then Notify(Lang.Pompiers.not_pompier, 'error') return end
    if Pompiers.OnDuty then
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
    if not Pompiers.OnDuty then Notify(Lang.Pompiers.not_pompier, 'error') return end

    local options = {
        {
            title = 'Tenue civile',
            description = 'Restaurer la tenue personnelle',
            icon = 'fa-solid fa-shirt',
            onSelect = function()
                TriggerEvent('skinchanger:loadSkin', LSLegacy.PlayerData.skin)
                Pompiers.InUniform = false
                Notify('Tenue civile restaurée.', 'success')
            end,
        },
    }

    for _, outfit in ipairs(Config.Pompiers.Outfits) do
        local available = Pompiers.Grade >= outfit.grade
        options[#options + 1] = {
            title = outfit.label,
            description = available and ('Grade ' .. outfit.grade .. '+') or ('Grade ' .. outfit.grade .. '+ requis'),
            icon = 'fa-solid fa-fire-extinguisher',
            disabled = not available,
            onSelect = function()
                ApplyOutfit(outfit)
                Pompiers.InUniform = true
                Notify('Tenue appliquée : ' .. outfit.label, 'success')
            end,
        }
    end

    lib.registerContext({ id = 'pompiers_clothing', title = 'Sapeurs-Pompiers — Vestiaire', options = options })
    lib.showContext('pompiers_clothing')
end

-- Garage

local function OpenGarageMenu()
    if not Pompiers.OnDuty then Notify(Lang.Pompiers.not_pompier, 'error') return end

    local options = {}
    for category, vehicles in pairs(Config.Pompiers.Vehicles) do
        for _, veh in ipairs(vehicles) do
            local available = Pompiers.Grade >= veh.grade
            options[#options + 1] = {
                title = veh.label,
                description = available and string.upper(veh.model) or ('Grade ' .. veh.grade .. '+ requis'),
                icon = 'fa-solid fa-truck-pickup',
                disabled = not available,
                onSelect = function()
                    LSLegacy.Events.SendToServer('pompiers:spawnVehicle', {
                        model    = veh.model,
                        category = category,
                        grade    = veh.grade,
                    })
                    Notify(Lang.Pompiers.vehicle_spawned, 'success')
                end,
            }
        end
    end

    lib.registerContext({ id = 'pompiers_garage', title = 'Sapeurs-Pompiers — Garage', options = options })
    lib.showContext('pompiers_garage')
end

-- Zones ox_target (Caserne de Davis)

exports.ox_target:addBoxZone({
    coords   = Config.Pompiers.Headquarters,
    size     = vector3(3.0, 3.0, 3.0),
    rotation = Config.Pompiers.HeadquartersHeading,
    debug    = false,
    drawSprite = true,
    options  = {
        {
            name = 'pompiers_duty',
            icon = 'fa-solid fa-right-from-bracket',
            label = 'Prise / Fin de service',
            distance = 2.5,
            canInteract = function() return IsPompier() end,
            onSelect = ToggleDuty,
        },
    },
})

exports.ox_target:addBoxZone({
    coords   = Config.Pompiers.ClothingCoords,
    size     = vector3(3.0, 3.0, 3.0),
    rotation = Config.Pompiers.HeadquartersHeading,
    debug    = false,
    drawSprite = true,
    options  = {
        {
            name = 'pompiers_clothing',
            icon = 'fa-solid fa-shirt',
            label = 'Vestiaire',
            distance = 2.0,
            canInteract = function() return IsPompier() end,
            onSelect = OpenClothingMenu,
        },
    },
})

exports.ox_target:addBoxZone({
    coords   = Config.Pompiers.GarageCoords,
    size     = vector3(3.0, 3.0, 3.0),
    rotation = Config.Pompiers.HeadquartersHeading,
    debug    = false,
    drawSprite = true,
    options  = {
        {
            name = 'pompiers_garage',
            icon = 'fa-solid fa-truck-pickup',
            label = 'Garage',
            distance = 2.0,
            canInteract = function() return IsPompier() end,
            onSelect = OpenGarageMenu,
        },
    },
})

-- Events serveur → client

LSLegacy.Events.Register('pompiers:spawnVehicleClient', function(data)
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
    SetVehicleNumberPlateText(veh, 'POMPIER')
    SetPedIntoVehicle(PlayerPedId(), veh, -1)
    SetModelAsNoLongerNeeded(hash)
end)

-- Init

Citizen.CreateThread(function()
    Wait(2000)
    if not IsPompier() then return end
    CreateBlips()
end)

-- Exporter l'état pour les autres sous-modules
function Pompiers.IsOnDuty() return Pompiers.OnDuty end
function Pompiers.GetGrade() return Pompiers.Grade end
function Pompiers.GetName() return GetFullName() end
