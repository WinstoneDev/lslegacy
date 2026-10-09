--  MDT — BOUTIQUE TENUES (client, générique multi-jobs)
--  Généralisation d'UNIPOL (ex module/police/client/vetipol.lua) : pont NUI
--  de l'onglet MDT « Boutique tenues » + un point de retrait ox_target par
--  département ayant déclaré Config.MDT.Departments.<dep>.boutique.

-- ── Pont requête/réponse (lectures) ──────────────────────────────
local pending, counter = {}, 0

LSLegacy.Events.Register('mdtboutique:queryResult', function(payload)
    if type(payload) ~= 'table' then return end
    local cb = pending[payload.reqId]
    if cb then pending[payload.reqId] = nil; cb(payload.result) end
end)

local function Query(action, data, cb)
    counter = counter + 1
    local reqId = counter
    pending[reqId] = cb
    LSLegacy.Events.SendToServer('mdtboutique:query', { reqId = reqId, action = action, data = data or {} })
    Citizen.SetTimeout(15000, function()
        if pending[reqId] then pending[reqId] = nil; cb(false) end
    end)
end

for _, name in ipairs({ 'getCatalogue', 'getHistory', 'getPresets' }) do
    RegisterNUICallback('mdtboutique:' .. name, function(data, cb)
        Query(name, type(data) == 'table' and data or {}, function(res) cb(res == nil and false or res) end)
    end)
end

-- ── Écritures ─────────────────────────────────────────────────────
RegisterNUICallback('mdtboutique:order', function(data, cb)
    LSLegacy.Events.SendToServer('mdtboutique:order', data)
    cb(true)
end)

RegisterNUICallback('mdtboutique:cancel', function(data, cb)
    LSLegacy.Events.SendToServer('mdtboutique:cancel', { batchId = data.batchId })
    cb(true)
end)

RegisterNUICallback('mdtboutique:presetSave', function(data, cb)
    LSLegacy.Events.SendToServer('mdtboutique:presetSave', { name = data.name, items = data.items })
    cb(true)
end)

RegisterNUICallback('mdtboutique:presetDelete', function(data, cb)
    LSLegacy.Events.SendToServer('mdtboutique:presetDelete', { presetId = data.presetId })
    cb(true)
end)

-- ── Scène cosmétique de livraison (camion + livreur) ─────────────
-- Jouée en local par chaque client à portée quand une commande passe en
-- statut "prête" (event diffusé par le serveur, coordonnées incluses dans le
-- payload). N'a aucun effet sur la BDD/l'inventaire : la remise du colis
-- reste l'interaction ox_target ci-dessous, indépendante. Départements sans
-- DeliveryVanCoords configuré (donc sans scène) n'émettent jamais cet event.

local sceneRunning = false
local UPS_MODELS = { `s_m_m_ups_01`, `s_m_m_ups_02` }
local BOX_ANIM_DICT = 'anim@heists@box_carry@'
local BOX_ANIM_CLIP = 'idle'
local BOX_PROP_MODEL = `hei_prop_heist_box`
local BOX_PROP_BONE = 60309
local BOX_PLACEMENT = { 0.025, 0.08, 0.255, -145.0, 290.0, 0.0 }

local function RequestModelAsync(model)
    if not IsModelValid(model) then return false end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    return HasModelLoaded(model)
end

local function HeadingForward(heading)
    local rad = heading * math.pi / 180.0
    return vector3(-math.sin(rad), math.cos(rad), 0.0)
end

local function WaitUntil(fn, timeoutMs, stepMs)
    local timeout = GetGameTimer() + timeoutMs
    while not fn() and GetGameTimer() < timeout do Wait(stepMs or 200) end
end

local function PlayDeliveryScene(data)
    if sceneRunning or type(data) ~= 'table' or not data.deliveryVanCoords then return end
    local target = data.deliveryVanCoords
    local heading = data.deliveryVanHeading or 0.0
    local pedStop = data.deliveryPedCoords or target
    local pedHeading = data.deliveryPedHeading or heading
    local doorStop = data.deliveryDoorCoords
    if #(GetEntityCoords(PlayerPedId()) - target) > 100.0 then return end

    sceneRunning = true
    Citizen.CreateThread(function()
        local vanModel = `boxville4`
        local pedModel = UPS_MODELS[math.random(#UPS_MODELS)]
        if not RequestModelAsync(vanModel) or not RequestModelAsync(pedModel) then
            sceneRunning = false
            return
        end

        local forward = HeadingForward(heading)
        local spawnCoords = target - forward * 30.0

        local van = CreateVehicle(vanModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, false, false)
        SetVehicleOnGroundProperly(van)
        local driver = CreatePedInsideVehicle(van, 4, pedModel, -1, true, false)
        SetBlockingOfNonTemporaryEvents(driver, true)
        SetPedFleeAttributes(driver, 0, false)
        SetPedCanBeTargetted(driver, false)

        -- Style de conduite 786603 = respecte feux/priorités et reste sur la
        -- route ; il était passé en 4ème position (stopRange) et non en
        -- 3ème (driveMode) : le van grillait donc les feux sans en tenir compte.
        TaskVehicleDriveToCoordLongrange(driver, van, target.x, target.y, target.z, 8.0, 786603, 4.0)
        WaitUntil(function() return not DoesEntityExist(van) or #(GetEntityCoords(van) - target) <= 4.0 end, 20000)

        if DoesEntityExist(van) then
            SetVehicleHandbrake(van, true)
            SetEntityHeading(van, heading)
            TaskLeaveVehicle(driver, van, 0)
            WaitUntil(function() return not IsPedInVehicle(driver, van, false) end, 5000, 100)

            RequestAnimDict(BOX_ANIM_DICT)
            WaitUntil(function() return HasAnimDictLoaded(BOX_ANIM_DICT) end, 2000, 0)
            RequestModelAsync(BOX_PROP_MODEL)

            local box = CreateObject(BOX_PROP_MODEL, pedStop.x, pedStop.y, pedStop.z, true, true, false)
            AttachEntityToEntity(box, driver, GetPedBoneIndex(driver, BOX_PROP_BONE),
                BOX_PLACEMENT[1], BOX_PLACEMENT[2], BOX_PLACEMENT[3],
                BOX_PLACEMENT[4], BOX_PLACEMENT[5], BOX_PLACEMENT[6], true, true, false, true, 1, true)
            TaskPlayAnim(driver, BOX_ANIM_DICT, BOX_ANIM_CLIP, 8.0, -8.0, -1, 49, 0, false, false, false)

            -- Passage obligé par la porte du commissariat, à l'aller comme
            -- au retour, pour éviter que le PNJ ne traverse les murs.
            if doorStop then
                TaskGoStraightToCoord(driver, doorStop.x, doorStop.y, doorStop.z, 1.0, 8000, 0.0, 0.0)
                WaitUntil(function() return #(GetEntityCoords(driver) - doorStop) <= 1.5 end, 10000)
            end

            -- Point d'arrêt à pied avancé (avant le mur) plutôt que le point
            -- de retrait ox_target lui-même, qui le faisait s'encastrer dedans.
            TaskGoStraightToCoord(driver, pedStop.x, pedStop.y, pedStop.z, 1.0, 8000, pedHeading, 0.0)
            WaitUntil(function() return #(GetEntityCoords(driver) - pedStop) <= 1.0 end, 10000)
            SetEntityHeading(driver, pedHeading)

            Wait(1000)
            ClearPedTasks(driver)
            TaskPlayAnim(driver, BOX_ANIM_DICT, BOX_ANIM_CLIP, 8.0, -8.0, 1500, 0, 0, false, false, false)
            Wait(1500) -- dépose (purement cosmétique, la remise en inventaire reste indépendante)

            ClearPedTasks(driver)
            if DoesEntityExist(box) then
                DetachEntity(box, true, false)
                DeleteEntity(box)
            end

            if doorStop then
                TaskGoStraightToCoord(driver, doorStop.x, doorStop.y, doorStop.z, 2.0, 8000, 0.0, 0.0)
                WaitUntil(function() return #(GetEntityCoords(driver) - doorStop) <= 1.5 end, 10000)
            end

            TaskGoStraightToCoord(driver, spawnCoords.x, spawnCoords.y, spawnCoords.z, 2.0, 8000, 0.0, 0.0)
            WaitUntil(function() return #(GetEntityCoords(driver) - spawnCoords) <= 2.5 end, 10000)

            TaskEnterVehicle(driver, van, 8000, -1, 1.0, 1, nil)
            WaitUntil(function() return IsPedInVehicle(driver, van, false) end, 8000, 100)

            local departCoords = target + forward * 60.0
            TaskVehicleDriveToCoordLongrange(driver, van, departCoords.x, departCoords.y, departCoords.z, 15.0, 786603, 4.0)
            Wait(8000)
        end

        if DoesEntityExist(van) then DeleteEntity(van) end
        if DoesEntityExist(driver) then DeleteEntity(driver) end
        sceneRunning = false
    end)
end

LSLegacy.Events.Register('boutique:deliveryScene', PlayDeliveryScene)

-- ── Colis posé au point de retrait (visuel, un seul par département) ──
-- Apparaît quand une commande passe "prête" (voir server/boutique.lua),
-- disparaît au retrait ox_target ci-dessous ou à l'annulation.
local DeliveryProps = {}

LSLegacy.Events.Register('boutique:deliveryPropSpawn', function(data)
    if type(data) ~= 'table' or not data.department or not data.coords or not data.model then return end
    if DeliveryProps[data.department] and DoesEntityExist(DeliveryProps[data.department]) then return end
    local model = GetHashKey(data.model)
    if not RequestModelAsync(model) then return end
    local c = data.coords
    local obj = CreateObject(model, c.x, c.y, c.z, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    if data.heading then SetEntityHeading(obj, data.heading) end
    FreezeEntityPosition(obj, true)
    DeliveryProps[data.department] = obj
end)

LSLegacy.Events.Register('boutique:deliveryPropDespawn', function(data)
    if type(data) ~= 'table' or not data.department then return end
    local obj = DeliveryProps[data.department]
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    DeliveryProps[data.department] = nil
end)

-- ── Retrait au point dédié — une zone par département ayant une boutique ──
CreateThread(function()
    for depName, dep in pairs(Config.MDT.Departments or {}) do
        local C = dep.boutique
        if C and C.DeliveryCoords then
            local jobs = dep.jobs or {}
            local function IsMember()
                for _, j in ipairs(jobs) do if LSLegacy.PlayerData.job == j then return true end end
                return false
            end
            exports.ox_target:addBoxZone({
                coords   = C.DeliveryCoords,
                size     = vector3(2.0, 2.0, 2.0),
                rotation = C.DeliveryHeading,
                debug    = false,
                drawSprite = true,
                options  = {
                    {
                        name = 'boutique_pickup_' .. depName,
                        icon = 'fa-solid fa-box-open',
                        label = 'Retirer mon colis',
                        distance = 2.0,
                        canInteract = IsMember,
                        onSelect = function() LSLegacy.Events.SendToServer('boutique:pickup') end,
                    },
                },
            })
        end
    end
end)
