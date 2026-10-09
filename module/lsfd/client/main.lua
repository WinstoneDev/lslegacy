--  MODULE LSFD — Client principal
--  Gestion : prise/fin de service, tenue, blips
--  Interactions : ox_target (zones) + ox_lib (menus)

LSFD = LSFD or {}
LSFD.OnDuty    = false
LSFD.Grade     = 0

local function Notify(msg, type)
    TriggerEvent('notify', 'LSFD', msg, type or 'info', 5000)
end

-- Utilitaires

local function IsLSFD()
    return LSLegacy.PlayerData.job == Config.LSFD.Job
end

local function GetGrade()
    return tonumber(LSLegacy.PlayerData.job_grade) or 0
end

local function GetFullName()
    local ci = LSLegacy.PlayerData.characterInfos
    if ci then
        return (ci.Prenom or '') .. ' ' .. (ci.NDF or '')
    end
    return 'Agent LSFD'
end

-- Blips

local function CreateBlips()
    for _, b in ipairs(Config.LSFD.Blips or {}) do
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
    if LSFD.OnDuty then Notify(Lang.LSFD.already_on_duty, 'error') return end
    LSFD.OnDuty = true
    LSFD.Grade  = GetGrade()

    LSLegacy.Events.SendToServer('lsfd:onDuty')
    Notify(Lang.LSFD.duty_on, 'success')
    TriggerEvent('lsfd:dutyChanged', true)
end

local function GoOffDuty()
    if not LSFD.OnDuty then Notify(Lang.LSFD.already_off_duty, 'error') return end
    LSFD.OnDuty = false

    LSLegacy.Events.SendToServer('lsfd:offDuty')
    Notify(Lang.LSFD.duty_off, 'info')
    TriggerEvent('lsfd:dutyChanged', false)
end

local function ToggleDuty()
    if not IsLSFD() then Notify(Lang.LSFD.not_lsfd, 'error') return end
    if LSFD.OnDuty then
        GoOffDuty()
    else
        GoOnDuty()
    end
end

-- Zones ox_target (Caserne de Davis)

exports.ox_target:addBoxZone({
    coords   = Config.LSFD.Headquarters,
    size     = vector3(3.0, 3.0, 3.0),
    rotation = Config.LSFD.HeadquartersHeading,
    debug    = false,
    drawSprite = true,
    options  = {
        {
            name = 'lsfd_duty',
            icon = 'fa-solid fa-right-from-bracket',
            label = 'Prise / Fin de service',
            distance = 2.5,
            canInteract = function() return IsLSFD() end,
            onSelect = ToggleDuty,
        },
    },
})

-- Events serveur → client


-- Init

Citizen.CreateThread(function()
    Wait(2000)
    if not IsLSFD() then return end
    CreateBlips()
end)

-- Exporter l'état pour les autres sous-modules
function LSFD.IsOnDuty() return LSFD.OnDuty end
function LSFD.GetGrade() return LSFD.Grade end
function LSFD.GetName() return GetFullName() end
