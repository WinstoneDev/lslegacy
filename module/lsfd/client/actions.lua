--  MODULE LSFD — Actions de secours (client)
--  Toutes les actions touchant un joueur sont validées côté SERVEUR.
--  L'extinction est un effet purement visuel (StopFireInRange).
--  Ciblage : ox_target (ALT sur un joueur)

local Actions   = {}
local cooldowns = {}

local function Notify(msg, type)
    TriggerEvent('notify', 'LSFD', msg, type or 'info', 5000)
end

-- Anti-abus cooldown

local function HasCooldown(action)
    if not cooldowns[action] then return false end
    return (GetGameTimer() - cooldowns[action]) < (Config.LSFD.Actions.cooldowns[action] or 3000)
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
    if not LSFD.IsOnDuty() then Notify(Lang.LSFD.not_lsfd, 'error') return end
    if HasCooldown('extinguish') then Notify(Lang.LSFD.action_cooldown, 'error') return end

    SetCooldown('extinguish')
    Notify(Lang.LSFD.extinguish_start, 'info')

    PlayAnim('amb@world_human_gardener_plant@male@base', 'base',
        Config.LSFD.Actions.extinguishDuration, 49)

    local coords = GetEntityCoords(PlayerPedId())
    StopFireInRange(coords.x, coords.y, coords.z, Config.LSFD.Actions.extinguishRadius)

    Notify(Lang.LSFD.extinguish_done, 'success')
end

RegisterCommand('lsfd_extinguish', function()
    Actions.Extinguish()
end, false)

RegisterKeyMapping('lsfd_extinguish', 'Éteindre un incendie (LSFD)', 'keyboard', 'F8')

--  ACTION : DÉSINCARCÉRATION / SECOURS

local function Rescue(targetSrc)
    if not LSLegacy.MDT.HasPermission('lsfd', LSFD.GetGrade(), 'rescue_victim') then
        Notify(Lang.LSFD.grade_required, 'error')
        return
    end
    if HasCooldown('rescue') then Notify(Lang.LSFD.action_cooldown, 'error') return end

    SetCooldown('rescue')
    Notify(Lang.LSFD.rescue_start, 'info')

    PlayAnim('mini@repair', 'fixing_a_ped', Config.LSFD.Actions.rescueDuration, 49)

    LSLegacy.Events.SendToServer('lsfd:rescue', { target = targetSrc })
end

-- Résultats serveur

LSLegacy.Events.Register('lsfd:rescueResult', function(data)
    if not data then return end
    if data.success then
        Notify(Lang.LSFD.rescue_done, 'success')
    end
end)

LSLegacy.Events.Register('lsfd:rescuedByFiremen', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 4160)
    end
    Notify(Lang.LSFD.rescued_by, 'success')
end)

--  CIBLAGE OX_TARGET — Touche ALT sur un joueur

exports.ox_target:addGlobalPlayer({
    {
        name = 'lsfd_rescue',
        icon = 'fa-solid fa-truck-medical',
        label = Lang.LSFD.action_rescue,
        distance = 2.0,
        canInteract = function(entity)
            return LSFD.IsOnDuty() and entity ~= PlayerPedId()
        end,
        onSelect = function(data)
            local targetSrc = GetServerIdFromPed(data.entity)
            if not targetSrc then return end
            Rescue(targetSrc)
        end,
    },
})
