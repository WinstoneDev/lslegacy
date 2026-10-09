--  MODULE EMS — Client principal
--  Gestion : prise/fin de service, tenue, blips
--  Interactions : ox_target (zones + ciblage joueur) + ox_lib (menus)

EMS = EMS or {}
EMS.OnDuty    = false
EMS.Grade     = 0

local function Notify(msg, type)
    TriggerEvent('notify', 'Emergency Medical Services', msg, type or 'info', 5000)
end

-- Utilitaires

local function IsEms()
    return LSLegacy.PlayerData.job == Config.EMS.Job
end

local function GetGrade()
    return tonumber(LSLegacy.PlayerData.job_grade) or 0
end

local function GetFullName()
    local ci = LSLegacy.PlayerData.characterInfos
    if ci then
        return (ci.Prenom or '') .. ' ' .. (ci.NDF or '')
    end
    return 'Secouriste'
end

-- Blips

local function CreateBlips()
    for _, b in ipairs(Config.EMS.Blips or {}) do
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
    if EMS.OnDuty then Notify(Lang.EMS.already_on_duty, 'error') return end
    EMS.OnDuty = true
    EMS.Grade  = GetGrade()

    LSLegacy.Events.SendToServer('ems:onDuty')
    Notify(Lang.EMS.duty_on, 'success')
    TriggerEvent('ems:dutyChanged', true)
end

local function GoOffDuty()
    if not EMS.OnDuty then Notify(Lang.EMS.already_off_duty, 'error') return end
    EMS.OnDuty = false

    LSLegacy.Events.SendToServer('ems:offDuty')
    Notify(Lang.EMS.duty_off, 'info')
    TriggerEvent('ems:dutyChanged', false)
end

local function ToggleDuty()
    if not IsEms() then Notify(Lang.EMS.not_ems, 'error') return end
    if EMS.OnDuty then
        GoOffDuty()
    else
        GoOnDuty()
    end
end

-- Réassort trousse de soins

local function RequestRestock()
    if not EMS.OnDuty then Notify(Lang.EMS.not_ems, 'error') return end
    LSLegacy.Events.SendToServer('ems:restock')
end

-- Zones ox_target (Centre Médical)
-- Prise/fin de service désormais uniquement via le dashboard MDT
-- (mdtmed:toggleDuty → EMS.ToggleDuty()), pas de zone physique dédiée.

exports.ox_target:addBoxZone({
    coords   = Config.EMS.RestockCoords,
    size     = vector3(3.0, 3.0, 3.0),
    rotation = Config.EMS.RestockHeading,
    debug    = false,
    drawSprite = true,
    options  = {
        {
            name = 'ems_restock',
            icon = 'fa-solid fa-box-medical',
            label = 'Réassort trousse de soins',
            distance = 2.0,
            canInteract = function() return IsEms() end,
            onSelect = RequestRestock,
        },
    },
})

-- Events serveur → client


-- Notification d'appel patient (détresse vitale) reçue du serveur
LSLegacy.Events.Register('ems:patientCallReceived', function(data)
    if not data or not data.coords then return end
    Notify(Lang.EMS.patient_call_received, 'error')
    SetNewWaypoint(data.coords.x, data.coords.y)
end)

-- Init

-- Le serveur répond à `ems:requestDutyState` (et peut pousser l'état à tout
-- moment) : c'est lui qui fait autorité sur la prise de service, le flag
-- client n'en est qu'un cache — remis à false à chaque rechargement de script.
LSLegacy.Events.Register('ems:setDutyState', function(state)
    local onDuty = state == true
    if onDuty == EMS.OnDuty then return end
    EMS.OnDuty = onDuty
    if onDuty then EMS.Grade = GetGrade() end
    TriggerEvent('ems:dutyChanged', onDuty)
end)

Citizen.CreateThread(function()
    -- Attendre que les données du personnage soient réellement chargées :
    -- un simple Wait(2000) laissait IsEms() renvoyer false quand le
    -- chargement traînait, et l'état de service ne s'initialisait
    -- alors jamais.
    local timeout = GetGameTimer() + 60000
    while not (LSLegacy.PlayerData and LSLegacy.PlayerData.job) and GetGameTimer() < timeout do
        Wait(500)
    end

    -- Blip de l'hôpital visible pour tous les joueurs (pas seulement le job EMS)
    CreateBlips()
    if not IsEms() then return end
    -- Récupérer l'état de service réel (cf. ems:setDutyState ci-dessus)
    LSLegacy.Events.SendToServer('ems:requestDutyState')
end)

-- Exporter l'état pour les autres sous-modules
function EMS.IsOnDuty() return EMS.OnDuty end
function EMS.GetGrade() return EMS.Grade end
function EMS.GetName() return GetFullName() end

-- Bascule de service, exposée pour le bouton du dashboard du MDT médical
-- (client/mdt_medical.lua). On expose la fonction existante plutôt que d'en
-- réécrire une : elle porte déjà la vérification du métier, les
-- notifications et l'event `ems:dutyChanged` dont dépendent les autres
-- sous-modules.
function EMS.ToggleDuty() ToggleDuty() end
