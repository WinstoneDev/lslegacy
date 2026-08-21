-- Carrosserie : pièce portée en main, touche E — cf. client/inventory.lua qui émet 'atelier:requestInstallPart'.

local cooldowns = {}

local function Notify(msg, type)
    TriggerEvent(Config.Atelier.NotifyEvent, 'Atelier', msg, 5000, type or 'info')
end

local function HasCooldown(action)
    if not cooldowns[action] then return false end
    return (GetGameTimer() - cooldowns[action]) < (Config.Atelier.Actions.cooldowns[action] or 3000)
end

local function SetCooldown(action)
    cooldowns[action] = GetGameTimer()
end

local function PlayAnim(dict, anim, duration, flag)
    flag = flag or 49
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do Wait(100); t = t + 1 end
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, duration, flag, 0, false, false, false)
    Wait(duration)
    ClearPedTasks(PlayerPedId())
end

-- Minijeu (barre + appui touche)

local function DrawMinigameBar(pos, zoneStart, zoneEnd)
    DrawRect(0.5, 0.85, 0.3, 0.03, 30, 30, 30, 180)
    DrawRect(0.5 - 0.15 + zoneStart * 0.3, 0.85, (zoneEnd - zoneStart) * 0.3, 0.03, 50, 200, 50, 180)
    DrawRect(0.5 - 0.15 + pos * 0.3, 0.85, 0.004, 0.05, 255, 255, 255, 230)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName('~b~[E]~w~ Valider au bon moment')
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- @param onComplete function appelé avec (hits, rounds, success)
local function RunMinigame(onComplete)
    local cfg  = Config.Atelier.Minigame
    local hits = 0

    for _ = 1, cfg.rounds do
        local zoneStart = math.random(20, 70) / 100.0
        local zoneEnd   = math.min(1.0, zoneStart + cfg.zoneSize)
        local startTime = GetGameTimer()
        local done      = false
        local roundHit  = false
        local lastPos    = 0.0

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

    onComplete(hits, cfg.rounds, hits >= cfg.requiredHits)
end

local function CanRepair()
    return Atelier.IsOnDuty() and LSLegacy.Atelier.HasPermission(Atelier.GetCompanyId(), Atelier.GetGrade(), 'repair_mechanical')
end

local function StartRepair(veh, componentId)
    if HasCooldown('repair') then Notify(Lang.Atelier.action_cooldown, 'error') return end
    SetCooldown('repair')
    Notify(Lang.Atelier.repair_start, 'info')
    PlayAnim('mini@repair', 'fixing_a_ped', 3000, 49)

    RunMinigame(function(hits, rounds, success)
        if not success then
            Notify(Lang.Atelier.repair_failed, 'error')
            return
        end
        LSLegacy.SendEventToServer('atelier:repairComponent', {
            vehNet      = NetworkGetNetworkIdFromEntity(veh),
            componentId = componentId,
        })
    end)
end

LSLegacy.RegisterClientEvent('atelier:repairResult', function(data)
    if not data then return end
    Notify(data.success and Lang.Atelier.repair_done or Lang.Atelier.repair_failed, data.success and 'success' or 'error')
end)

-- Pose d'une pièce portée en main (carrosserie), déclenché par client/inventory.lua sur la touche E.

local MULTI_TARGET_PARTS = {
    piece_portiere = { { id = 'portiere_avg', label = 'Avant gauche' }, { id = 'portiere_avd', label = 'Avant droite' },
                        { id = 'portiere_arg', label = 'Arrière gauche' }, { id = 'portiere_ard', label = 'Arrière droite' } },
    piece_aile     = { { id = 'aile_avg', label = 'Avant gauche' }, { id = 'aile_avd', label = 'Avant droite' } },
}

local installing = false

local function DoInstall(veh, componentId)
    if installing then return end
    installing = true
    Notify(Lang.Atelier.repair_start, 'info')
    PlayAnim('mini@repair', 'fixing_a_ped', 3000, 49)

    RunMinigame(function(hits, rounds, success)
        installing = false
        if not success then
            Notify(Lang.Atelier.repair_failed, 'error')
            return
        end
        LSLegacy.SendEventToServer('atelier:repairComponent', {
            vehNet      = NetworkGetNetworkIdFromEntity(veh),
            componentId = componentId,
        })
    end)
end

AddEventHandler('atelier:requestInstallPart', function(veh, itemName)
    local targets = MULTI_TARGET_PARTS[itemName]
    if targets then
        local options = {}
        for _, target in ipairs(targets) do
            options[#options + 1] = {
                title = target.label,
                onSelect = function() DoInstall(veh, target.id) end,
            }
        end
        lib.registerContext({ id = 'atelier_install_target', title = 'Où poser la pièce ?', options = options })
        lib.showContext('atelier_install_target')
        return
    end

    local part = Config.Atelier.Parts[itemName]
    if part and part.repairs and part.repairs[1] then
        DoInstall(veh, part.repairs[1])
    end
end)

-- Ciblage ox_target — mécanique & pneus (touche ALT)

local MECHANICAL_LABELS = {
    moteur       = 'Réparer le moteur',
    freins       = 'Réparer les freins',
    transmission = 'Réparer la transmission',
    suspension   = 'Réparer la suspension',
    embrayage    = "Réparer l'embrayage",
    radiateur    = 'Réparer le radiateur',
}

local mechanicalOptions = {}
for componentId, label in pairs(MECHANICAL_LABELS) do
    mechanicalOptions[#mechanicalOptions + 1] = {
        name = 'atelier_repair_' .. componentId,
        icon = 'fa-solid fa-screwdriver-wrench',
        label = label,
        distance = 3.0,
        canInteract = CanRepair,
        onSelect = function(data) StartRepair(data.entity, componentId) end,
    }
end

local TYRE_COMPONENT_BY_WHEEL = {}
for id, def in pairs(LSLegacy.Atelier.Components.tyres) do
    TYRE_COMPONENT_BY_WHEEL[def.wheelIndex] = id
end

mechanicalOptions[#mechanicalOptions + 1] = {
    name = 'atelier_change_tyre', icon = 'fa-solid fa-circle-dot', label = 'Changer un pneu',
    distance = 3.0, canInteract = CanRepair,
    onSelect = function(data)
        local veh = data.entity
        local burstWheel = nil
        for wheelIndex in pairs(TYRE_COMPONENT_BY_WHEEL) do
            if IsVehicleTyreBurst(veh, wheelIndex, false) then burstWheel = wheelIndex break end
        end
        if not burstWheel then Notify('Aucun pneu à changer.', 'warning') return end
        StartRepair(veh, TYRE_COMPONENT_BY_WHEEL[burstWheel])
    end,
}

exports.ox_target:addGlobalVehicle(mechanicalOptions)
