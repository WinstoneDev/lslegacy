-- Transporteur Avicole : PNJ Earl Hickey (docks), camion, PNJ usine (jour/nuit), PNJ grossiste.

local CFG = Config.Avicole

Avicole = Avicole or {}
Avicole.OnDuty     = false
Avicole.Delivered  = false
Avicole.PrepOnDuty = false
local truckEntity = nil
local usinePed, usineModel = nil, nil

local function Notify(msg, t)
    TriggerEvent('notify', 'Transporteur Avicole', msg, t or 'info', 5000)
end

local function VehicleHasPlayerOccupant(vehicle)
    for i = -1, GetVehicleMaxNumberOfPassengers(vehicle) do
        local ped = GetPedInVehicleSeat(vehicle, i)
        if ped ~= 0 and IsPedAPlayer(ped) then return true end
    end
    return false
end

local function ClearVehiclesAround(coords, radius)
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and not VehicleHasPlayerOccupant(vehicle)
            and LSLegacy.Validate.Distance(GetEntityCoords(vehicle), coords, radius)
        then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end
end

local function SpawnVehicleAt(modelName, coords, heading)
    local hash = GetHashKey(modelName)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then
        Notify('Modèle introuvable : ' .. tostring(modelName), 'error')
        return nil
    end

    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, heading or 0.0, true, false)
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)

    local ct = 0
    while not NetworkHasControlOfEntity(veh) and ct < 30 do
        NetworkRequestControlOfEntity(veh)
        Wait(10); ct = ct + 1
    end
    SetModelAsNoLongerNeeded(hash)
    return veh
end

local function SpawnStaticPed(coords, model, heading, options)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then return nil end

    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, heading or 0.0, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(hash)
    exports.ox_target:addLocalEntity(ped, options)
    return ped
end

-- ── Earl Hickey (docks) ────────────────────────────────────────────────
CreateThread(function()
    Wait(1000)
    SpawnStaticPed(CFG.Ped.coords, CFG.Ped.model, CFG.Ped.heading, {
        {
            name = 'avicole_start',
            icon = 'fa-solid fa-truck',
            label = 'Prendre le service (Transporteur Avicole)',
            distance = 2.5,
            canInteract = function() return not Avicole.OnDuty end,
            onSelect = function() LSLegacy.Events.SendToServer('avicole:startDuty') end,
        },
        {
            name = 'avicole_end',
            icon = 'fa-solid fa-coins',
            label = 'Terminer la livraison',
            distance = 2.5,
            canInteract = function() return Avicole.OnDuty and Avicole.Delivered end,
            onSelect = function() LSLegacy.Events.SendToServer('avicole:endDelivery') end,
        },
    })
end)

-- ── PNJ de l'usine (Robert le jour, Roberta la nuit) ─────────────────────
local function SpawnUsinePed(model)
    if usinePed and DoesEntityExist(usinePed) then
        exports.ox_target:removeLocalEntity(usinePed)
        DeleteEntity(usinePed)
    end
    usineModel = model
    usinePed = SpawnStaticPed(CFG.Usine.coords, model, CFG.Usine.heading, {
        {
            name = 'avicole_usine_talk',
            icon = 'fa-solid fa-comments',
            label = 'Parler',
            distance = 2.5,
            canInteract = function() return true end,
            onSelect = function() LSLegacy.Events.SendToServer('avicole:talkUsinePed') end,
        },
        {
            name = 'avicole_prep_start',
            icon = 'fa-solid fa-user-check',
            label = 'Commencer le travail (Préparateur Avicole)',
            distance = 2.5,
            canInteract = function() return not Avicole.PrepOnDuty end,
            onSelect = function()
                Avicole.PrepOnDuty = true
                LSLegacy.Events.SendToServer('avicole:prep:startDuty')
            end,
        },
        {
            name = 'avicole_prep_stop',
            icon = 'fa-solid fa-user-slash',
            label = 'Terminer le travail',
            distance = 2.5,
            canInteract = function() return Avicole.PrepOnDuty end,
            onSelect = function()
                Avicole.PrepOnDuty = false
                LSLegacy.Events.SendToServer('avicole:prep:stopDuty')
                LSLegacy.Events.SendToServer('farm:metier:endService', { metier = 'preparateur_avicole' })
            end,
        },
    })
end

LSLegacy.Events.Register('avicole:usineState', function(data)
    if not data or data.model == usineModel then return end
    SpawnUsinePed(data.model)
end)

-- Spawne le PNJ de l'usine dès le début (nécessaire pour le métier Préparateur Avicole,
-- indépendamment d'une livraison de camion en cours).
CreateThread(function()
    Wait(1500)
    LSLegacy.Events.SendToServer('avicole:requestUsineState')
end)

-- ── Préparateur Avicole : boucle point1 (plumer) -> point2 (découper) ────
local PREP = CFG.Prep

exports.ox_target:addBoxZone({
    coords = PREP.Point1, size = vec3(2.0, 2.0, 2.0), rotation = 0.0, debug = false,
    options = {
        {
            name = 'avicole_prep_point1',
            icon = 'fa-solid fa-feather',
            label = 'Déplumer le poulet',
            distance = 2.5,
            canInteract = function() return Avicole.PrepOnDuty end,
            onSelect = function() LSLegacy.Events.SendToServer('avicole:prep:requestAction', 1) end,
        },
    },
})

exports.ox_target:addBoxZone({
    coords = PREP.Point2, size = vec3(2.0, 2.0, 2.0), rotation = 0.0, debug = false,
    options = {
        {
            name = 'avicole_prep_point2',
            icon = 'fa-solid fa-knife',
            label = 'Découper le poulet',
            distance = 2.5,
            canInteract = function() return Avicole.PrepOnDuty end,
            onSelect = function() LSLegacy.Events.SendToServer('avicole:prep:requestAction', 2) end,
        },
    },
})

LSLegacy.Events.Register('avicole:prep:playAction', function(data)
    if not data then return end
    local ok = lib.progressBar({
        duration = data.duration,
        label = data.label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
    if ok then
        LSLegacy.Events.SendToServer('avicole:prep:completeAction', data.point)
    end
end)

-- ── PNJ du grossiste (Janet, fixe) ────────────────────────────────────────
CreateThread(function()
    Wait(1000)
    SpawnStaticPed(CFG.Grossiste.coords, CFG.Grossiste.model, CFG.Grossiste.heading, {
        {
            name = 'avicole_grossiste_talk',
            icon = 'fa-solid fa-comments',
            label = 'Parler',
            distance = 2.5,
            canInteract = function() return true end,
            onSelect = function() LSLegacy.Events.SendToServer('avicole:talkGrossistePed') end,
        },
        {
            name = 'grossiste_sell',
            icon = 'fa-solid fa-hand-holding-dollar',
            label = 'Vendre au grossiste',
            distance = 2.5,
            canInteract = function() return true end,
            onSelect = function() TriggerEvent('grossiste:openSellMenu') end,
        },
    })
end)

-- ── Camion : prise de service, ox_target, actions ─────────────────────
LSLegacy.Events.Register('avicole:spawnTruck', function(data)
    if not data then return end
    Avicole.OnDuty    = true
    Avicole.Delivered = false

    ClearVehiclesAround(vector3(data.coords.x, data.coords.y, data.coords.z), 6.0)
    truckEntity = SpawnVehicleAt(data.model, data.coords, data.heading)
    if not truckEntity then
        Avicole.OnDuty = false
        return Notify('Erreur de spawn du camion.', 'error')
    end

    exports.ox_target:addLocalEntity(truckEntity, {
        {
            name = 'avicole_truck_unload_raw',
            icon = 'fa-solid fa-truck-ramp-box',
            label = 'Décharger la cargaison',
            distance = 2.5,
            canInteract = function() return true end,
            onSelect = function() LSLegacy.Events.SendToServer('avicole:requestUnloadRaw') end,
        },
        {
            name = 'avicole_truck_load',
            icon = 'fa-solid fa-dolly',
            label = 'Charger le camion',
            distance = 2.5,
            canInteract = function() return true end,
            onSelect = function() LSLegacy.Events.SendToServer('avicole:requestLoadPrepared') end,
        },
        {
            name = 'avicole_truck_unload_grossiste',
            icon = 'fa-solid fa-truck-ramp-box',
            label = 'Décharger chez le grossiste',
            distance = 2.5,
            canInteract = function() return true end,
            onSelect = function() LSLegacy.Events.SendToServer('avicole:requestUnloadGrossiste') end,
        },
    })

    local netId = NetworkGetNetworkIdFromEntity(truckEntity)
    LSLegacy.Events.SendToServer('avicole:rigSpawned', { truckNetId = netId })
end)

LSLegacy.Events.Register('avicole:playAction', function(data)
    if not data then return end
    local ok = lib.progressBar({
        duration = data.duration,
        label = data.label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
    if ok then
        if data.complete == 'unload_grossiste' then Avicole.Delivered = true end
        LSLegacy.Events.SendToServer('avicole:completeAction', { complete = data.complete })
    end
end)

LSLegacy.Events.Register('avicole:askContinue', function()
    Avicole.Delivered = false
    local alert = lib.alertDialog({
        header = 'Earl Hickey',
        content = 'Voulez-vous effectuer une nouvelle livraison ?',
        centered = true,
        cancel = true,
        labels = { confirm = 'Oui', cancel = 'Non' },
    })
    if alert == 'confirm' then
        LSLegacy.Events.SendToServer('avicole:continue')
    else
        LSLegacy.Events.SendToServer('avicole:stopService')
        LSLegacy.Events.SendToServer('farm:metier:endService', { metier = 'transporteur_avicole' })
    end
end)

LSLegacy.Events.Register('avicole:despawnRig', function()
    Avicole.OnDuty    = false
    Avicole.Delivered = false
    local veh = truckEntity
    if not veh or not DoesEntityExist(veh) then return end

    CreateThread(function()
        local waited = 0
        while waited < CFG.DespawnTimeout do
            if not VehicleHasPlayerOccupant(veh)
                and not LSLegacy.Validate.Distance(GetEntityCoords(PlayerPedId()), GetEntityCoords(veh), CFG.DespawnDistance)
            then
                break
            end
            Wait(1000)
            waited = waited + 1000
        end
        if DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
        end
        if truckEntity == veh then truckEntity = nil end
    end)
end)

-- Rafraîchit le PNJ de l'usine toutes les 5 min pour suivre la rotation jour/nuit
-- (toujours actif : utile pour le transporteur comme pour le préparateur avicole).
CreateThread(function()
    while true do
        Wait(300000)
        LSLegacy.Events.SendToServer('avicole:requestUsineState')
    end
end)
