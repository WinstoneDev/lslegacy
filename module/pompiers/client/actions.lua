--  MODULE SAPEURS-POMPIERS — Actions de secours (client)
--  Toutes les actions touchant un joueur sont validées côté SERVEUR.
--  L'extinction est un effet purement visuel (StopFireInRange).
--  Ciblage : ox_target (ALT sur un joueur)

local Actions   = {}
local cooldowns = {}

local function Notify(msg, type)
    TriggerEvent(Config.Pompiers.NotifyEvent, 'Sapeurs-Pompiers', msg, 5000, type or 'info')
end

-- Anti-abus cooldown

local function HasCooldown(action)
    if not cooldowns[action] then return false end
    return (GetGameTimer() - cooldowns[action]) < (Config.Pompiers.Actions.cooldowns[action] or 3000)
end

local function SetCooldown(action)
    cooldowns[action] = GetGameTimer()
end

-- Conversion ped ciblé → id serveur

local function GetServerIdFromPed(ped)
    local playerIndex = NetworkGetPlayerIndexFromPed(ped)
    if not playerIndex then return nil end
    return GetPlayerServerId(playerIndex)
end

-- Jouer une animation avec durée

local function PlayAnim(dict, anim, duration, flag)
    flag = flag or 49
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do
        Wait(100); t = t + 1
    end
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, duration, flag, 0, false, false, false)
    Wait(duration)
    ClearPedTasks(PlayerPedId())
end

--  ACTION : ÉTEINDRE UN INCENDIE (touche F8 — pas de cible nécessaire)

Actions.Extinguish = function()
    if not Pompiers.IsOnDuty() then Notify(Lang.Pompiers.not_pompier, 'error') return end
    if HasCooldown('extinguish') then Notify(Lang.Pompiers.action_cooldown, 'error') return end

    SetCooldown('extinguish')
    Notify(Lang.Pompiers.extinguish_start, 'info')

    PlayAnim('amb@world_human_gardener_plant@male@base', 'base',
        Config.Pompiers.Actions.extinguishDuration, 49)

    local coords = GetEntityCoords(PlayerPedId())
    StopFireInRange(coords.x, coords.y, coords.z, Config.Pompiers.Actions.extinguishRadius)

    Notify(Lang.Pompiers.extinguish_done, 'success')
end

RegisterCommand('pompiers_extinguish', function()
    Actions.Extinguish()
end, false)

RegisterKeyMapping('pompiers_extinguish', 'Éteindre un incendie (Sapeurs-Pompiers)', 'keyboard', 'F8')

--  ACTION : DÉSINCARCÉRATION / SECOURS

local function Rescue(targetSrc)
    if not LSLegacy.MDT.HasPermission('pompiers', Pompiers.GetGrade(), 'rescue_victim') then
        Notify(Lang.Pompiers.grade_required, 'error')
        return
    end
    if HasCooldown('rescue') then Notify(Lang.Pompiers.action_cooldown, 'error') return end

    SetCooldown('rescue')
    Notify(Lang.Pompiers.rescue_start, 'info')

    PlayAnim('mini@repair', 'fixing_a_ped', Config.Pompiers.Actions.rescueDuration, 49)

    LSLegacy.Events.SendToServer('pompiers:rescue', { target = targetSrc })
end

-- Résultats serveur

LSLegacy.Events.Register('pompiers:rescueResult', function(data)
    if not data then return end
    if data.success then
        Notify(Lang.Pompiers.rescue_done, 'success')
    end
end)

LSLegacy.Events.Register('pompiers:rescuedByFiremen', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 4160)
    end
    Notify(Lang.Pompiers.rescued_by, 'success')
end)

--  CIBLAGE OX_TARGET — Touche ALT sur un joueur

exports.ox_target:addGlobalPlayer({
    {
        name = 'pompiers_rescue',
        icon = 'fa-solid fa-truck-medical',
        label = Lang.Pompiers.action_rescue,
        distance = 2.0,
        canInteract = function(entity)
            return Pompiers.IsOnDuty() and entity ~= PlayerPedId()
        end,
        onSelect = function(data)
            local targetSrc = GetServerIdFromPed(data.entity)
            if not targetSrc then return end
            Rescue(targetSrc)
        end,
    },
})
