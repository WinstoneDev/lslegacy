local HostageWeaponHashes = {}
for _, name in ipairs(Config.HostageWeapons) do
    HostageWeaponHashes[#HostageWeaponHashes + 1] = GetHashKey(name)
end

local Hostage = {
    inProgress = false,
    type       = '', -- 'agressor' | 'hostage'
    targetSrc  = -1,
    aggressor  = { dict = 'anim@gangops@hostage@', anim = 'perp_idle',   flag = 49 },
    hostage    = { dict = 'anim@gangops@hostage@', anim = 'victim_idle', flag = 49, attach = vector3(-0.24, 0.11, 0.0) },
}

local canTakeHostage = false
local foundWeapon    = nil

LSLegacy.IsHostageTaker = false
LSLegacy.IsHostage      = false

local function Notify(msg, type)
    LSLegacy.ShowNotification('Otage', msg, type or 'info')
end

local function drawNativeText(str)
    SetTextEntry_2('STRING')
    AddTextComponentString(str)
    EndTextCommandPrint(1000, 1)
end

local function ensureAnimDict(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do Wait(0) end
    end
    return dict
end

-- TaskPlayAnim avec une durée de -1 ne rend jamais la main : l'animation ne
-- boucle pas, mais la tâche reste active indéfiniment et fige le ped sur la
-- dernière frame. On la relâche nous-même après le temps qu'il faut pour la
-- jouer une fois.
local function playReactionOnce(entity, dict, anim, flag, holdMs)
    ensureAnimDict(dict)
    TaskPlayAnim(entity, dict, anim, 8.0, -8.0, -1, flag or 0, 0, false, false, false)

    CreateThread(function()
        Wait(holdMs or 1000)
        if DoesEntityExist(entity) then
            ClearPedTasksImmediately(entity)
        end
    end)
end

local function GetServerIdFromPed(ped)
    local playerIndex = NetworkGetPlayerIndexFromPed(ped)
    if not playerIndex then return nil end
    return GetPlayerServerId(playerIndex)
end

-- Exige l'arme EN MAIN (pas juste possédée dans l'inventaire) pour que le
-- bouton ox_target apparaisse, et pour que l'animation de prise d'otage
-- garde la même arme que celle déjà dégainée (SetCurrentPedWeapon devient
-- un no-op puisque foundWeapon == l'arme déjà équipée).
local function UpdateCanTakeHostage()
    canTakeHostage = false
    foundWeapon    = nil
    local ped = PlayerPedId()
    local currentWeapon = GetSelectedPedWeapon(ped)

    for i = 1, #HostageWeaponHashes do
        if HostageWeaponHashes[i] == currentWeapon and GetAmmoInPedWeapon(ped, currentWeapon) > 0 then
            canTakeHostage = true
            foundWeapon    = currentWeapon
            break
        end
    end
end

-- ── Déclenchement (commande ou ox_target) ────────────────────────────

function callTakeHostage(targetPed)
    ClearPedSecondaryTask(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)

    UpdateCanTakeHostage()

    if not canTakeHostage then
        Notify("Vous avez besoin d'un pistolet avec des munitions pour prendre en otage quelqu'un.", 'error')
        return
    end

    if Hostage.inProgress then return end

    if LSLegacy.IsCuffed or LSLegacy.IsHostage or LSLegacy.IsBeingCarried or LSLegacy.IsCarrying then
        Notify('Impossible dans cet état.', 'error')
        return
    end

    local targetSrc

    if targetPed then
        if not DoesEntityExist(targetPed) or targetPed == PlayerPedId() then return end
        if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(targetPed)) > Config.Hostage.range then
            Notify('Trop loin.', 'error')
            return
        end
        targetSrc = GetServerIdFromPed(targetPed)
    else
        local closest = LSLegacy.GetClosestPlayer(true, Config.Hostage.range)
        targetSrc = closest and GetServerIdFromPed(closest)
    end

    if not targetSrc then
        Notify("Personne à proximité à prendre en otage.", 'error')
        return
    end

    SetCurrentPedWeapon(PlayerPedId(), foundWeapon, true)
    Hostage.inProgress = true
    Hostage.targetSrc  = targetSrc
    Hostage.type       = 'agressor'
    LSLegacy.IsHostageTaker = true
    ensureAnimDict(Hostage.aggressor.dict)

    LSLegacy.Events.SendToServer('lslegacy_hostage:sync', targetSrc)
end

RegisterCommand('otage', function()
    callTakeHostage(nil)
end, false)

LSLegacy.Events.Register('lslegacy_hostage:client:syncTarget', function(aggressorSrc)
    local aggressorPed = GetPlayerPed(GetPlayerFromServerId(aggressorSrc))
    if aggressorPed == 0 then return end

    Hostage.inProgress = true
    Hostage.targetSrc  = aggressorSrc
    Hostage.type       = 'hostage'
    LSLegacy.IsHostage = true

    ensureAnimDict(Hostage.hostage.dict)
    AttachEntityToEntity(PlayerPedId(), aggressorPed, 0,
        Hostage.hostage.attach.x, Hostage.hostage.attach.y, Hostage.hostage.attach.z,
        0.5, 0.5, 0.0, false, false, false, false, 2, false)
end)

LSLegacy.Events.Register('lslegacy_hostage:client:release', function()
    Hostage.inProgress = false
    Hostage.type       = ''
    LSLegacy.IsHostageTaker, LSLegacy.IsHostage = false, false

    DetachEntity(PlayerPedId(), true, false)
    playReactionOnce(PlayerPedId(), 'reaction@shove', 'shoved_back', 0, 1000)
end)

LSLegacy.Events.Register('lslegacy_hostage:client:kill', function()
    Hostage.inProgress = false
    Hostage.type       = ''
    LSLegacy.IsHostageTaker, LSLegacy.IsHostage = false, false

    DetachEntity(PlayerPedId(), true, false)
    -- Pas d'animation de mort forcée ici : elle empêcherait le ragdoll
    -- naturel de s'exécuter, et le système K.O./coma du framework
    -- (client/player/injury.lua) détecte déjà le passage sous 100 PV pour
    -- déclencher automatiquement la mise au sol/coma en conséquence.
    ClearPedTasksImmediately(PlayerPedId())
    SetEntityHealth(PlayerPedId(), 0)
end)

LSLegacy.Events.Register('lslegacy_hostage:client:stop', function()
    Hostage.inProgress = false
    Hostage.type       = ''
    LSLegacy.IsHostageTaker, LSLegacy.IsHostage = false, false

    ClearPedSecondaryTask(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
end)

CreateThread(function()
    while true do
        local sleep = 1000

        if Hostage.type == 'agressor' then
            if not IsEntityPlayingAnim(PlayerPedId(), Hostage.aggressor.dict, Hostage.aggressor.anim, 3) then
                TaskPlayAnim(PlayerPedId(), Hostage.aggressor.dict, Hostage.aggressor.anim, 8.0, -8.0, 100000,
                    Hostage.aggressor.flag, 0, false, false, false)
            end
        elseif Hostage.type == 'hostage' then
            if not IsEntityPlayingAnim(PlayerPedId(), Hostage.hostage.dict, Hostage.hostage.anim, 3) then
                TaskPlayAnim(PlayerPedId(), Hostage.hostage.dict, Hostage.hostage.anim, 8.0, -8.0, 100000,
                    Hostage.hostage.flag, 0, false, false, false)
            end
        end

        if Hostage.type ~= '' then sleep = 0 end

        UpdateCanTakeHostage()

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(Hostage.type == '' and 1000 or 0)

        if Hostage.type == 'agressor' then
            DisableControlAction(0, 24, true) -- Attaque
            DisableControlAction(0, 25, true) -- Viser
            DisableControlAction(0, 47, true) -- Roue armes
            DisableControlAction(0, 58, true) -- Arme 2
            DisableControlAction(0, 21, true) -- Sprint
            DisablePlayerFiring(PlayerPedId(), true)
            drawNativeText('Appuyez sur [G] pour relâcher, [H] pour tuer')

            if IsEntityDead(PlayerPedId()) then
                Hostage.type = ''
                Hostage.inProgress = false
                LSLegacy.IsHostageTaker = false
                playReactionOnce(PlayerPedId(), 'reaction@shove', 'shove_var_a', 168, 1000)
                LSLegacy.Events.SendToServer('lslegacy_hostage:release', Hostage.targetSrc)
            end

            if IsDisabledControlJustPressed(0, 47) then -- relâcher
                Hostage.type = ''
                Hostage.inProgress = false
                LSLegacy.IsHostageTaker = false
                playReactionOnce(PlayerPedId(), 'reaction@shove', 'shove_var_a', 168, 1000)
                LSLegacy.Events.SendToServer('lslegacy_hostage:release', Hostage.targetSrc)
            elseif IsDisabledControlJustPressed(0, 74) then -- tuer
                Hostage.type = ''
                Hostage.inProgress = false
                LSLegacy.IsHostageTaker = false
                playReactionOnce(PlayerPedId(), 'anim@gangops@hostage@', 'perp_fail', 168, 1500)
                LSLegacy.Events.SendToServer('lslegacy_hostage:kill', Hostage.targetSrc)
                LSLegacy.Events.SendToServer('lslegacy_hostage:stop', Hostage.targetSrc)
                Wait(100)
                SetPedShootsAtCoord(PlayerPedId(), 0.0, 0.0, 0.0, 0)
            end
        elseif Hostage.type == 'hostage' then
            DisableControlAction(0, 21, true)  -- Sprint
            DisableControlAction(0, 24, true)  -- Attaque
            DisableControlAction(0, 25, true)  -- Viser
            DisableControlAction(0, 47, true)  -- Roue armes
            DisableControlAction(0, 58, true)  -- Arme 2
            DisableControlAction(0, 263, true) -- Corps à corps
            DisableControlAction(0, 264, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 143, true)
            DisableControlAction(0, 75, true)  -- Sortir du véhicule
            DisableControlAction(27, 75, true)
            DisableControlAction(0, 22, true)  -- Sauter
            DisableControlAction(0, 32, true)  -- Déplacement
            DisableControlAction(0, 268, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 269, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 270, true)
            DisableControlAction(0, 35, true)
            DisableControlAction(0, 271, true)
        end
    end
end)

exports.ox_target:addGlobalPlayer({
    {
        icon = 'fa-solid fa-gun',
        label = 'Prendre en otage',
        name = 'lslegacy_hostage',
        onSelect = function(data) callTakeHostage(data.entity) end,
        canInteract = function(entity, distance)
            return distance < Config.Hostage.range
                and canTakeHostage
                and not LSLegacy.IsCuffed
                and not LSLegacy.IsHostage
                and not LSLegacy.IsBeingCarried
                and not LSLegacy.IsCarrying
                and not IsEntityDead(entity)
        end,
    },
})
