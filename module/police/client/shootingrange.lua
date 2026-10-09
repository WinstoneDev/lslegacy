--  MODULE POLICE NATIONALE — Stand de tir (client)
--  Côté formateur : ox_target + menus ox_lib (agent → difficulté → nombre
--  de cibles → confirmation). Côté testé : exécution du test (cibles
--  fixes ou surgissantes selon le stand), sans jamais afficher de score.

local function IsPolice()
    return LSLegacy.PlayerData.job == Config.Police.Job
end

local function Notify(msg, t)
    TriggerEvent('notify', 'Stand de tir', msg, t or 'info', 6000)
end

local function RequestModelAsync(model)
    if not IsModelValid(model) then return false end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    return HasModelLoaded(model)
end

-- ── Outil dev : relever une position de cible ─────────────────────
-- Réutilise le mode placement du module Obstacles (viser à la souris,
-- molette = rotation, clic gauche = valider). La position est affichée
-- dans la console F8 au format vector3, prête à coller dans
-- Config.Police.ShootingRange.Stands. Le prop posé n'est pas conservé
-- (uniquement pour visualiser où il tombe avant de relever la coord).
RegisterCommand('rangetarget', function()
    if type(Obstacles) ~= 'table' or not Obstacles.RunPlacement then
        return Notify("Outil de placement (module Obstacles) indisponible.", 'error')
    end
    Obstacles.RunPlacement(Config.Police.ShootingRange.TargetProp, nil, function(entity, coords, rotation)
        print(('[stand de tir] Cible : vector3(%.6f, %.6f, %.6f) -- heading %.2f'):format(coords.x, coords.y, coords.z, rotation.z))
        Notify('Position relevée (voir console F8).', 'success')
        DeleteEntity(entity)
    end, function() end)
end, false)

-- ════════════════════════════════════════════════════════════════
-- CÔTÉ FORMATEUR — sélection puis lancement du test
-- ════════════════════════════════════════════════════════════════

local pendingNearby, nearbyCounter = {}, 0

LSLegacy.Events.Register('range:nearbyResult', function(payload)
    if type(payload) ~= 'table' then return end
    local cb = pendingNearby[payload.reqId]
    if cb then pendingNearby[payload.reqId] = nil; cb(payload.result) end
end)

local function GetNearby(cb)
    nearbyCounter = nearbyCounter + 1
    local reqId = nearbyCounter
    pendingNearby[reqId] = cb
    LSLegacy.Events.SendToServer('range:getNearby', { reqId = reqId })
    Citizen.SetTimeout(5000, function()
        if pendingNearby[reqId] then pendingNearby[reqId] = nil; cb(false) end
    end)
end

local function OpenConfirmMenu(stand, targetSrc, targetName, diff, count)
    lib.registerContext({
        id = 'range_confirm_menu',
        title = 'Confirmer le test',
        menu = 'range_count_menu',
        options = {
            { title = ('%s'):format(targetName), description = ('%s — %d cibles'):format(diff.label, count), disabled = true },
            {
                title = 'Commencer',
                icon = 'fa-solid fa-play',
                onSelect = function()
                    LSLegacy.Events.SendToServer('range:startTest', {
                        standId = stand.id, targetSrc = targetSrc, difficultyId = diff.id, targetCount = count,
                    })
                end,
            },
            { title = 'Annuler', icon = 'fa-solid fa-xmark' },
        },
    })
    lib.showContext('range_confirm_menu')
end

local function OpenCountMenu(stand, targetSrc, targetName, diff)
    local options = {}
    for _, n in ipairs(Config.Police.ShootingRange.TargetCounts) do
        options[#options + 1] = {
            title = n .. ' cibles',
            onSelect = function() OpenConfirmMenu(stand, targetSrc, targetName, diff, n) end,
        }
    end
    lib.registerContext({ id = 'range_count_menu', title = 'Nombre de cibles', menu = 'range_diff_menu', options = options })
    lib.showContext('range_count_menu')
end

local function OpenDifficultyMenu(stand, targetSrc, targetName)
    local options = {}
    for _, d in ipairs(Config.Police.ShootingRange.Difficulties) do
        options[#options + 1] = {
            title = d.label,
            description = ('%.1fs par cible'):format(d.interval),
            onSelect = function() OpenCountMenu(stand, targetSrc, targetName, d) end,
        }
    end
    lib.registerContext({ id = 'range_diff_menu', title = 'Difficulté', menu = 'range_player_menu', options = options })
    lib.showContext('range_diff_menu')
end

local function OpenPlayerMenu(stand)
    GetNearby(function(list)
        list = list or {}
        if #list == 0 then return Notify('Aucun joueur à proximité.', 'error') end
        local options = {}
        for _, p in ipairs(list) do
            options[#options + 1] = {
                title = p.name,
                icon = 'fa-solid fa-user',
                iconColor = p.isPolice and '#3b82f6' or '#d1d5db',
                onSelect = function() OpenDifficultyMenu(stand, p.src, p.name) end,
            }
        end
        lib.registerContext({ id = 'range_player_menu', title = 'Choisir un agent', options = options })
        lib.showContext('range_player_menu')
    end)
end

for _, stand in ipairs(Config.Police.ShootingRange.Stands) do
    exports.ox_target:addBoxZone({
        coords     = stand.coords,
        size       = vector3(2.0, 2.0, 2.0),
        debug      = false,
        drawSprite = true,
        options    = {
            {
                name        = 'police_range_' .. stand.id,
                icon        = 'fa-solid fa-crosshairs',
                label       = 'Stand de tir',
                distance    = 2.0,
                canInteract = function() return IsPolice() end,
                onSelect    = function() OpenPlayerMenu(stand) end,
            },
        },
    })
end

-- ════════════════════════════════════════════════════════════════
-- CÔTÉ TESTÉ — déroulement du test (jamais de score affiché ici)
-- ════════════════════════════════════════════════════════════════

local testRunning = false
local activeTarget = nil
local hitFlag = false

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    if not activeTarget or not DoesEntityExist(activeTarget) then return end
    if args[1] == activeTarget then hitFlag = true end
end)

-- Une cible active pendant au plus `interval` secondes, ou jusqu'à ce
-- qu'elle soit touchée (on ne raccourcit/rallonge jamais au-delà de ça).
local function RunOneTarget(obj, coords, interval)
    SetEntityCanBeDamaged(obj, true)
    hitFlag = false
    activeTarget = obj
    local endTime = GetGameTimer() + interval * 1000
    while GetGameTimer() < endTime and not hitFlag do
        DrawMarker(2, coords.x, coords.y, coords.z + 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.25, 0.25, 255, 40, 40, 200, false, true, 2, false, nil, nil, false)
        Wait(0)
    end
    activeTarget = nil
    return hitFlag
end

LSLegacy.Events.Register('range:runTest', function(payload)
    if type(payload) ~= 'table' or testRunning then return end
    testRunning = true

    Citizen.CreateThread(function()
        Notify("Le formateur lance un exercice de tir. C'est parti.", 'info')

        if not RequestModelAsync(payload.targetProp) then
            testRunning = false
            LSLegacy.Events.SendToServer('range:finishTest', { sessionId = payload.sessionId, hits = 0 })
            return
        end

        local fixedObjects = {}
        if payload.standType == 'fixed' then
            -- Toutes les cibles sont posées d'un coup et restent visibles ;
            -- une seule compte à la fois (cf. RunOneTarget).
            for i, pos in ipairs(payload.targets) do
                local obj = CreateObject(payload.targetProp, pos.x, pos.y, pos.z, false, false, false)
                PlaceObjectOnGroundProperly(obj)
                FreezeEntityPosition(obj, true)
                fixedObjects[i] = obj
            end
        end

        local hits = 0
        for i, pos in ipairs(payload.targets) do
            local obj = fixedObjects[i]
            if payload.standType == 'surging' then
                obj = CreateObject(payload.targetProp, pos.x, pos.y, pos.z, false, false, false)
                PlaceObjectOnGroundProperly(obj)
                FreezeEntityPosition(obj, true)
            end

            local hit = RunOneTarget(obj, pos, payload.interval)
            if hit then
                hits = hits + 1
                -- Même mécanisme que le tir réel (client/player/skills.lua) —
                -- uniquement si le testé est policier.
                if IsPolice() then LSLegacy.Events.SendToServer('lslegacy:skillsAddXP', 'tir') end
            end

            if payload.standType == 'surging' and DoesEntityExist(obj) then
                DeleteEntity(obj)
            end
        end

        for _, obj in ipairs(fixedObjects) do
            if DoesEntityExist(obj) then DeleteEntity(obj) end
        end

        LSLegacy.Events.SendToServer('range:finishTest', { sessionId = payload.sessionId, hits = hits })
        testRunning = false
    end)
end)
