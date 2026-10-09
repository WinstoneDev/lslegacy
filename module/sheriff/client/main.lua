--  MODULE BLAINE COUNTY SHERIFF'S OFFICE — Client principal
--  Gestion : prise/fin de service, blips, borne de station.
--  La prise de service est également accessible depuis le tableau de
--  bord du MDT : les deux chemins appellent la même bascule.

Sheriff = Sheriff or {}
Sheriff.OnDuty = false
Sheriff.Grade  = 0
Sheriff.Unit   = nil

local function Notify(msg, type)
    TriggerEvent('notify', "Blaine County Sheriff's Office", msg, type or 'info', Config.Sheriff.NotifyDuration or 30000)
end

-- Utilitaires

local function IsSheriff()
    return LSLegacy.PlayerData and LSLegacy.PlayerData.job == Config.Sheriff.Job
end

local function GetGrade()
    return tonumber(LSLegacy.PlayerData.job_grade) or 0
end

local function GetFullName()
    local ci = LSLegacy.PlayerData and LSLegacy.PlayerData.characterInfos
    if ci then
        return (ci.Prenom or '') .. ' ' .. (ci.NDF or '')
    end
    return 'Deputy'
end

-- Blips

local function CreateBlips()
    for _, b in ipairs(Config.Sheriff.Blips or {}) do
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
    if Sheriff.OnDuty then Notify(Lang.Sheriff.already_on_duty, 'error') return end
    Sheriff.OnDuty = true
    Sheriff.Grade  = GetGrade()

    LSLegacy.Events.SendToServer('sheriff:onDuty')
    Notify(Lang.Sheriff.duty_on, 'success')
    TriggerEvent('sheriff:dutyChanged', true)
end

-- L'unité réelle (affectation active gérée par la hiérarchie) est résolue
-- côté serveur ; on la reçoit ici pour affichage.
LSLegacy.Events.Register('sheriff:onDutyResult', function(data)
    if not data then return end
    Sheriff.Unit = data.unit
end)

local function GoOffDuty()
    if not Sheriff.OnDuty then Notify(Lang.Sheriff.already_off_duty, 'error') return end
    Sheriff.OnDuty = false

    LSLegacy.Events.SendToServer('sheriff:offDuty')
    Notify(Lang.Sheriff.duty_off, 'info')
    TriggerEvent('sheriff:dutyChanged', false)
end

local function ToggleDuty()
    if not IsSheriff() then Notify(Lang.Sheriff.not_sheriff, 'error') return end
    if Sheriff.OnDuty then GoOffDuty() else GoOnDuty() end
end

-- Borne de service à la station

if Config.Sheriff.DutyZone then
    exports.ox_target:addBoxZone({
        coords   = Config.Sheriff.Headquarters,
        size     = vector3(3.0, 3.0, 3.0),
        rotation = Config.Sheriff.HeadquartersHeading,
        debug    = false,
        drawSprite = true,
        options  = {
            {
                name = 'sheriff_duty',
                icon = 'fa-solid fa-right-from-bracket',
                label = Lang.Sheriff.take_duty,
                distance = 2.5,
                canInteract = function() return IsSheriff() end,
                onSelect = ToggleDuty,
            },
        },
    })
end

-- Init

Citizen.CreateThread(function()
    Wait(2000)
    if not IsSheriff() then return end
    CreateBlips()
end)

-- État exposé aux autres sous-modules

function Sheriff.IsOnDuty() return Sheriff.OnDuty end
function Sheriff.GetGrade() return Sheriff.Grade end
function Sheriff.GetName() return GetFullName() end
function Sheriff.ToggleDuty() ToggleDuty() end

-- Enregistrement dans le registre du cœur MDT : le bouton « prise de
-- service » du tableau de bord y trouve la bascule du département sans
-- que le MDT ait à connaître ce module.
LSLegacy.MDT = LSLegacy.MDT or {}
LSLegacy.MDT.DutyToggles = LSLegacy.MDT.DutyToggles or {}
LSLegacy.MDT.DutyToggles['sheriff'] = {
    toggle   = ToggleDuty,
    isOnDuty = function() return Sheriff.OnDuty end,
}
