--  MODULE GENDARMERIE NATIONALE — Client principal
--  Gestion : prise/fin de service, blips, borne de caserne.
--  La prise de service est également accessible depuis le tableau de
--  bord du MDT : les deux chemins appellent la même bascule.

Gendarmerie = Gendarmerie or {}
Gendarmerie.OnDuty = false
Gendarmerie.Grade  = 0

local function Notify(msg, type)
    TriggerEvent(Config.Gendarmerie.NotifyEvent, 'Gendarmerie Nationale', msg,
        Config.Gendarmerie.NotifyDuration or 30000, type or 'info')
end

-- Utilitaires

local function IsGendarme()
    return LSLegacy.PlayerData and LSLegacy.PlayerData.job == Config.Gendarmerie.Job
end

local function GetGrade()
    return tonumber(LSLegacy.PlayerData.job_grade) or 0
end

local function GetFullName()
    local ci = LSLegacy.PlayerData and LSLegacy.PlayerData.characterInfos
    if ci then
        return (ci.Prenom or '') .. ' ' .. (ci.NDF or '')
    end
    return 'Gendarme'
end

-- Blips

local function CreateBlips()
    for _, b in ipairs(Config.Gendarmerie.Blips or {}) do
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
    if Gendarmerie.OnDuty then Notify(Lang.Gendarmerie.already_on_duty, 'error') return end
    Gendarmerie.OnDuty = true
    Gendarmerie.Grade  = GetGrade()

    LSLegacy.Events.SendToServer('gendarmerie:onDuty')
    Notify(Lang.Gendarmerie.duty_on, 'success')
    TriggerEvent('gendarmerie:dutyChanged', true)
end

local function GoOffDuty()
    if not Gendarmerie.OnDuty then Notify(Lang.Gendarmerie.already_off_duty, 'error') return end
    Gendarmerie.OnDuty = false

    LSLegacy.Events.SendToServer('gendarmerie:offDuty')
    Notify(Lang.Gendarmerie.duty_off, 'info')
    TriggerEvent('gendarmerie:dutyChanged', false)
end

local function ToggleDuty()
    if not IsGendarme() then Notify(Lang.Gendarmerie.not_gendarme, 'error') return end
    if Gendarmerie.OnDuty then GoOffDuty() else GoOnDuty() end
end

-- Borne de service à la caserne

if Config.Gendarmerie.DutyZone then
    exports.ox_target:addBoxZone({
        coords   = Config.Gendarmerie.Headquarters,
        size     = vector3(3.0, 3.0, 3.0),
        rotation = Config.Gendarmerie.HeadquartersHeading,
        debug    = false,
        drawSprite = true,
        options  = {
            {
                name = 'gendarmerie_duty',
                icon = 'fa-solid fa-right-from-bracket',
                label = Lang.Gendarmerie.take_duty,
                distance = 2.5,
                canInteract = function() return IsGendarme() end,
                onSelect = ToggleDuty,
            },
        },
    })
end

-- Init

Citizen.CreateThread(function()
    Wait(2000)
    if not IsGendarme() then return end
    CreateBlips()
end)

-- État exposé aux autres sous-modules

function Gendarmerie.IsOnDuty() return Gendarmerie.OnDuty end
function Gendarmerie.GetGrade() return Gendarmerie.Grade end
function Gendarmerie.GetName() return GetFullName() end
function Gendarmerie.ToggleDuty() ToggleDuty() end

-- Enregistrement dans le registre du cœur MDT : le bouton « prise de
-- service » du tableau de bord y trouve la bascule du département sans
-- que le MDT ait à connaître ce module.
LSLegacy.MDT = LSLegacy.MDT or {}
LSLegacy.MDT.DutyToggles = LSLegacy.MDT.DutyToggles or {}
LSLegacy.MDT.DutyToggles['gendarmerie'] = {
    toggle   = ToggleDuty,
    isOnDuty = function() return Gendarmerie.OnDuty end,
}
