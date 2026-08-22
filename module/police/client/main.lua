--  MODULE POLICE NATIONALE — Client principal
--  Gestion : prise/fin de service, tenue, armurerie, garage, blips
--  Interactions : ox_target (zones) + ox_lib (menus)

Police = Police or {}
Police.OnDuty    = false
Police.Service   = nil
Police.Unit      = nil
Police.Grade     = 0
Police.InUniform = false

local function Notify(msg, type)
    TriggerEvent('notify', 'Police Nationale', msg, type or 'info', Config.Police.NotifyDuration or 30000)
end

-- Utilitaires

local function IsPolice()
    return LSLegacy.PlayerData.job == Config.Police.Job
end

local function GetGrade()
    return tonumber(LSLegacy.PlayerData.job_grade) or 0
end

local function GetGradeLabel()
    local dep = Config.MDT and Config.MDT.Departments and Config.MDT.Departments.police
    if not dep then return 'Agent' end
    local g = dep.grades[GetGrade()]
    return g and g.label or 'Agent'
end

local function GetFullName()
    local ci = LSLegacy.PlayerData.characterInfos
    if ci then
        return (ci.Prenom or '') .. ' ' .. (ci.NDF or '')
    end
    return 'Agent'
end

-- Blips

local function CreateBlips()
    for _, b in ipairs(Config.Police.Blips or {}) do
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

-- Armurerie

local function GiveWeapons(grade)
    -- Cherche les armes du grade le plus proche (descend par paliers)
    local weapons = nil
    for g = grade, 0, -1 do
        if Config.Police.Weapons[g] then
            weapons = Config.Police.Weapons[g]
            break
        end
    end
    if not weapons then return end
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    for _, w in ipairs(weapons) do
        GiveWeaponToPed(ped, GetHashKey(w.weapon), w.ammo, false, false)
    end
end

-- Prise de service

local function GoOnDuty()
    if Police.OnDuty then Notify(Lang.Police.already_on_duty, 'error') return end
    Police.OnDuty  = true
    Police.Service = nil
    Police.Unit    = nil
    Police.Grade   = GetGrade()

    GiveWeapons(Police.Grade)

    LSLegacy.Events.SendToServer('police:onDuty', { service = nil, unit = nil })
    Notify(Lang.Police.duty_on, 'success')
    TriggerEvent('police:dutyChanged', true)
end

local function GoOffDuty()
    if not Police.OnDuty then Notify(Lang.Police.already_off_duty, 'error') return end
    if Police.InUniform then
        Notify('Changez de tenue au vestiaire avant de quitter le service.', 'error')
        return
    end
    Police.OnDuty  = false
    Police.Service = nil
    Police.Unit    = nil

    RemoveAllPedWeapons(PlayerPedId(), true)
    LSLegacy.Events.SendToServer('police:offDuty')
    Notify(Lang.Police.duty_off, 'info')
    TriggerEvent('police:dutyChanged', false)
end

-- Menu prise de service

local function ToggleDuty()
    if not IsPolice() then Notify(Lang.Police.not_police, 'error') return end
    if Police.OnDuty then
        GoOffDuty()
    else
        GoOnDuty()
    end
end

-- Tenue (ox_lib context)

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
    if not Police.OnDuty then Notify(Lang.Police.not_police, 'error') return end

    local options = {
        {
            title = 'Tenue civile',
            description = 'Restaurer la tenue personnelle',
            icon = 'fa-solid fa-shirt',
            onSelect = function()
                TriggerEvent('skinchanger:loadSkin', LSLegacy.PlayerData.skin)
                Police.InUniform = false
                Notify('Tenue civile restaurée.', 'success')
            end,
        },
    }

    for _, outfit in ipairs(Config.Police.Outfits) do
        local available = Police.Grade >= outfit.grade
        options[#options + 1] = {
            title = outfit.label,
            description = available and ('Grade ' .. outfit.grade .. '+') or ('Grade ' .. outfit.grade .. '+ requis'),
            icon = 'fa-solid fa-user-tie',
            disabled = not available,
            onSelect = function()
                ApplyOutfit(outfit)
                Police.InUniform = true
                Notify('Tenue appliquée : ' .. outfit.label, 'success')
            end,
        }
    end

    lib.registerContext({ id = 'police_clothing', title = 'Police Nationale — Vestiaire', options = options })
    lib.showContext('police_clothing')
end

-- Garage (ox_lib context)

local function OpenGarageMenu()
    if not IsPolice() or not Police.OnDuty then
        Notify(Lang.Police.not_police, 'error')
        return
    end

    local options = {}
    for category, vehicles in pairs(Config.Police.Vehicles) do
        for _, veh in ipairs(vehicles) do
            local available = Police.Grade >= veh.grade
            options[#options + 1] = {
                title = veh.label,
                description = available and string.upper(veh.model) or ('Grade ' .. veh.grade .. '+ requis'),
                icon = 'fa-solid fa-car',
                disabled = not available,
                onSelect = function()
                    LSLegacy.Events.SendToServer('police:spawnVehicle', {
                        model    = veh.model,
                        category = category,
                        grade    = veh.grade,
                    })
                    Notify(Lang.Police.vehicle_spawned, 'success')
                end,
            }
        end
    end

    lib.registerContext({ id = 'police_garage', title = 'Police Nationale — Garage', options = options })
    lib.showContext('police_garage')
end

-- Zones ox_target (Commissariat)

exports.ox_target:addBoxZone({
    coords   = Config.Police.Headquarters,
    size     = vector3(3.0, 3.0, 3.0),
    rotation = Config.Police.HeadquartersHeading,
    debug    = false,
    drawSprite = true,
    options  = {
        {
            name = 'police_duty',
            icon = 'fa-solid fa-right-from-bracket',
            label = 'Prise / Fin de service',
            distance = 2.5,
            canInteract = function() return IsPolice() end,
            onSelect = ToggleDuty,
        },
    },
})

exports.ox_target:addBoxZone({
    coords   = Config.Police.ArmoryCoords,
    size     = vector3(3.0, 3.0, 3.0),
    rotation = Config.Police.HeadquartersHeading,
    debug    = false,
    drawSprite = true,
    options  = {
        {
            name = 'police_armory',
            icon = 'fa-solid fa-gun',
            label = 'Armurerie',
            distance = 2.0,
            canInteract = function() return IsPolice() end,
            onSelect = function()
                if not Police.OnDuty then Notify(Lang.Police.not_police, 'error') return end
                GiveWeapons(Police.Grade)
                Notify('Armurerie rechargée.', 'success')
            end,
        },
    },
})

exports.ox_target:addBoxZone({
    coords   = Config.Police.ClothingCoords,
    size     = vector3(3.0, 3.0, 3.0),
    rotation = Config.Police.HeadquartersHeading,
    debug    = false,
    drawSprite = true,
    options  = {
        {
            name = 'police_clothing',
            icon = 'fa-solid fa-shirt',
            label = 'Vestiaire',
            distance = 2.0,
            canInteract = function() return IsPolice() end,
            onSelect = OpenClothingMenu,
        },
    },
})

LSLegacy.Events.AddHandler('police:openGarageMenu', OpenGarageMenu)

-- Events serveur → client

LSLegacy.Events.Register('police:spawnVehicleClient', function(data)
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
    SetVehicleNumberPlateText(veh, 'POLICE')
    SetPedIntoVehicle(PlayerPedId(), veh, -1)
    SetModelAsNoLongerNeeded(hash)
end)

-- Init

Citizen.CreateThread(function()
    Wait(2000)
    if not IsPolice() then return end
    CreateBlips()
end)

-- Exporter l'état pour les autres sous-modules
function Police.IsOnDuty() return Police.OnDuty end
function Police.GetService() return Police.Service end
function Police.GetUnit() return Police.Unit end
function Police.GetGrade() return Police.Grade end
function Police.GetName() return GetFullName() end
function Police.ToggleDuty() ToggleDuty() end

-- Prise de service depuis le tableau de bord du MDT. On s'enregistre dans
-- le registre du cœur MDT plutôt que de lui faire connaître ce module :
-- la borne du commissariat et le MDT appellent exactement la même bascule.
LSLegacy.MDT = LSLegacy.MDT or {}
LSLegacy.MDT.DutyToggles = LSLegacy.MDT.DutyToggles or {}
LSLegacy.MDT.DutyToggles['police'] = {
    toggle   = ToggleDuty,
    isOnDuty = function() return Police.OnDuty end,
}
