--  MODULE GARAGE — Client runtime
--  Entrée/sortie d'instance, rangement, sortie de véhicule, véhicules figés
--  (statebag garageVeh), ox_target sur les véhicules garés, serrurier.
local C = Config.Garage
Garage = Garage or {}
Garage.list = {}
Garage.byId = {}
Garage.inInstance = nil
Garage.vehicles = {}   -- [entity] = statebag garageVeh
local blips = {}
local nearest, nearestDist = nil, 999.0
local busyUntil = 0

local function Notify(msg, t) TriggerEvent('notify', 'Garage', msg, t or 'info', 5000) end

local function HelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function MyCharId() return LSLegacy.PlayerData and LSLegacy.PlayerData['boutique-id'] end

local function Trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

function Garage.ModelLabel(hash)
    local name = GetDisplayNameFromVehicleModel(hash + 0)
    if name and name ~= '' and name ~= 'CARNOTFOUND' then
        local lbl = GetLabelText(name)
        if lbl and lbl ~= '' and lbl ~= 'NULL' then return lbl end
        return name
    end
    return 'Véhicule'
end

function Garage.VehicleType(veh)
    local class = GetVehicleClass(veh)
    return C.ClassToType[class] or 'car', class
end

local function SlotDef(id)
    for _, s in ipairs(C.SlotTypes) do if s.id == id then return s end end
    return C.SlotTypes[1]
end

-- Vérification locale (confort) : le serveur reste l'autorité
function Garage.CanAccessLocal(g)
    local pd = LSLegacy.PlayerData or {}
    if g.owner_type == 'public' then return true end
    if g.owner_type == 'job' then return pd.job == g.owner_id end
    if g.owner_type == 'faction' then return pd.faction == g.owner_id end
    if g.owner_type == 'personal' then
        for _, it in pairs(pd.inventory or {}) do
            if it.name == C.KeyItem and it.data and tonumber(it.data.garage) == g.id then return true end
        end
    end
    return false
end

-- ── Sync + blips ───────────────────────────────────────────────────
local function RebuildBlips()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
    for _, g in ipairs(Garage.list) do
        if g.blip and Garage.CanAccessLocal(g) then
            local b = AddBlipForCoord(g.entrance.x, g.entrance.y, g.entrance.z)
            SetBlipSprite(b, C.Blip.sprite)
            SetBlipColour(b, C.Blip.colors[g.owner_type] or 0)
            SetBlipScale(b, C.Blip.scale)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName('Garage - ' .. g.name)
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
end

LSLegacy.Events.Register('garage:sync', function(list)
    Garage.list = list or {}
    Garage.byId = {}
    for _, g in ipairs(Garage.list) do Garage.byId[g.id] = g end
    RebuildBlips()
    if Garage.OnSync then Garage.OnSync() end
end)

-- Rechange de job/faction, ou clé de garage reçue (prêt, admin...) : ces trois
-- cas passent tous par le miroir PlayerData, donc un rafraîchissement immédiat
-- des blips ici couvre tout sans event dédié par cas.
LSLegacy.Events.Register('lslegacy:updatePlayer', function()
    RebuildBlips()
end)

CreateThread(function()
    while not (LSLegacy.PlayerData and LSLegacy.PlayerData.job) do Wait(500) end
    Wait(1000)
    LSLegacy.Events.SendToServer('garage:requestSync')
    -- Filet de sécurité si un rafraîchissement ciblé a été manqué
    while true do
        Wait(30000)
        RebuildBlips()
    end
end)

local function IsDriver(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    return veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped, veh
end

-- Point d'entrée à utiliser pour ce garage : le marker "poids lourd" (s'il
-- est défini) remplace le marker de base uniquement quand on conduit
-- effectivement un poids lourd — sinon on garde l'entrée standard (piéton,
-- ou véhicule léger).
local function EntranceFor(g, heavy)
    return (heavy and g.heavy_entrance) or g.entrance
end

-- ── Boucle de proximité ────────────────────────────────────────────
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local driving, veh = IsDriver(ped)
        local heavy = driving and Garage.VehicleType(veh) == 'heavy'
        local best, bestD = nil, C.DrawDistance
        if not Garage.inInstance then
            for _, g in ipairs(Garage.list) do
                local ep = EntranceFor(g, heavy)
                local d = #(pos - vector3(ep.x, ep.y, ep.z))
                if d < bestD then best, bestD = g, d end
            end
        end
        nearest, nearestDist = best, bestD
        Wait(500)
    end
end)

-- Choix de place puis rangement
local function StoreFlow(g)
    local ped = PlayerPedId()
    local driving, veh = IsDriver(ped)
    if not driving then return Notify('Vous devez être au volant.', 'error') end
    if Garage.vehicles[veh] then return Notify('Ce véhicule est déjà garé.', 'error') end
    local vtype = Garage.VehicleType(veh)
    LSLegacy.Callbacks.TriggerServer('garage:getSlots', function(slots)
        if not slots then return Notify("Vous n'avez pas accès à ce garage.", 'error') end
        local options = {}
        local free = 0
        for i, s in ipairs(slots) do
            local ok = not s.plate and SlotDef(s.type).accepts[vtype]
            if ok then free = free + 1 end
            options[#options + 1] = {
                title = ('Place %d - %s'):format(i, SlotDef(s.type).label),
                description = s.plate and ('Occupée : ' .. Garage.ModelLabel(s.model or 0) .. ' [' .. Trim(s.plate) .. ']') or (ok and 'Libre' or 'Libre (type incompatible)'),
                icon = s.plate and 'fa-solid fa-lock' or 'fa-solid fa-square-parking',
                disabled = not ok,
                onSelect = function() Garage.DoStore(g, veh, i) end,
            }
        end
        if free == 0 then return Notify('Aucune place libre adaptée à ce véhicule.', 'error') end
        table.insert(options, 1, {
            title = 'Première place libre', icon = 'fa-solid fa-bolt',
            onSelect = function() Garage.DoStore(g, veh, nil) end,
        })
        lib.registerContext({ id = 'garage_store', title = g.name .. ' - Choisir une place', options = options })
        lib.showContext('garage_store')
    end, g.id)
end

function Garage.DoStore(g, veh, slot)
    local ped = PlayerPedId()
    if not DoesEntityExist(veh) then return end
    local _, class = Garage.VehicleType(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    -- rapport d'état frais (mods, néons, dégâts visuels, pneus) avant le snapshot serveur
    if LSLegacy.AP and LSLegacy.AP.ReportVehicleStatus then
        pcall(LSLegacy.AP.ReportVehicleStatus, veh)
        Wait(400)
    end
    SetVehicleEngineOn(veh, false, true, true)
    TaskLeaveVehicle(ped, veh, 0)
    local t = GetGameTimer() + 5000
    while IsPedInAnyVehicle(ped, false) and GetGameTimer() < t do Wait(100) end
    Wait(300)
    busyUntil = GetGameTimer() + 3000
    LSLegacy.Events.SendToServer('garage:store', { garage = g.id, netId = netId, slot = slot, class = class })
end

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        if Garage.inInstance then
            local g = Garage.byId[Garage.inInstance]
            if g and g.interior_exit then
                sleep = 0
                local e = g.interior_exit
                local d = #(GetEntityCoords(ped) - vector3(e.x, e.y, e.z))
                if d < 20.0 then
                    DrawMarker(C.Marker.type, e.x, e.y, e.z - 0.9, 0, 0, 0, 0, 0, 0, 1.5, 1.5, 0.5, 255, 80, 80, 120, false, true, 2, false, nil, nil, false)
                    if d < 2.0 and not IsPedInAnyVehicle(ped, false) then
                        HelpText('Appuyez sur ~INPUT_CONTEXT~ pour sortir du garage')
                        if IsControlJustReleased(0, 38) and GetGameTimer() > busyUntil then
                            busyUntil = GetGameTimer() + 2000
                            LSLegacy.Events.SendToServer('garage:leave')
                        end
                    end
                end
            end
        elseif nearest and Garage.CanAccessLocal(nearest) then
            sleep = 0
            local g = nearest
            local driving, veh = IsDriver(ped)
            local heavy = driving and Garage.VehicleType(veh) == 'heavy'
            local e = EntranceFor(g, heavy)
            local m = C.Marker
            DrawMarker(m.type, e.x, e.y, e.z - 0.9, 0, 0, 0, 0, 0, 0, m.size.x, m.size.y, m.size.z, m.color.r, m.color.g, m.color.b, m.color.a, false, true, 2, false, nil, nil, false)
            if nearestDist < C.EntranceRadius then
                if driving then
                    HelpText(('Appuyez sur ~INPUT_CONTEXT~ pour ranger le véhicule (%s)'):format(g.name))
                    if IsControlJustReleased(0, 38) and GetGameTimer() > busyUntil then
                        busyUntil = GetGameTimer() + 1500
                        StoreFlow(g)
                    end
                elseif g.type == 'interior' and not IsPedInAnyVehicle(ped, false) then
                    HelpText(('Appuyez sur ~INPUT_CONTEXT~ pour entrer dans le garage (%s)'):format(g.name))
                    if IsControlJustReleased(0, 38) and GetGameTimer() > busyUntil then
                        busyUntil = GetGameTimer() + 2000
                        LSLegacy.Events.SendToServer('garage:enter', g.id)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ── Téléportations ─────────────────────────────────────────────────
local function FadeTeleport(coords, heading, cb)
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    if heading then SetEntityHeading(ped, heading + 0.0) end
    Wait(600)
    if cb then cb() end
    DoScreenFadeIn(600)
end

-- Charge un intérieur IPL (bob74) et l'épingle en mémoire. Renvoie false si
-- aucun intérieur n'existe aux coordonnées (IPL non chargé / coords fausses).
function Garage.LoadInterior(id)
    local def = id and C.InteriorDef(id)
    if not def then return true end
    if def.load then
        local ok, err = pcall(def.load)
        if not ok then print('[garage] chargement IPL ' .. id .. ' : ' .. tostring(err)) end
    end
    local interior = GetInteriorAtCoords(def.coords.x, def.coords.y, def.coords.z)
    if interior == 0 then return false end
    PinInteriorInMemory(interior)
    local t = GetGameTimer() + 3000
    while not IsInteriorReady(interior) and GetGameTimer() < t do Wait(0) end
    return true
end

local visualsTimer = nil
function Garage.ScheduleVisuals()
    local stamp = GetGameTimer()
    visualsTimer = stamp
    SetTimeout(800, function()
        if visualsTimer == stamp and Garage.inInstance then
            LSLegacy.Events.SendToServer('garage:requestVisuals')
        end
    end)
end

LSLegacy.Events.Register('garage:enterInstance', function(data)
    if not data or not data.spawn then return end
    Garage.inInstance = data.garage
    Garage.LoadInterior(data.interior)
    FadeTeleport(data.spawn, data.spawn.h)
    Wait(1500)
    Garage.ScheduleVisuals()
end)

LSLegacy.Events.Register('garage:leftInstance', function(data)
    Garage.inInstance = nil
    if data and data.coords then FadeTeleport(data.coords, data.coords.h) end
end)

LSLegacy.Events.Register('garage:warpInto', function(data)
    Garage.inInstance = nil
    if not data or not data.netId then return end
    -- sans coords : le joueur est déjà à la sortie (garage:leftInstance), pas de fondu
    local ped = PlayerPedId()
    if data.coords then
        DoScreenFadeOut(400)
        while not IsScreenFadedOut() do Wait(10) end
        SetEntityCoords(ped, data.coords.x, data.coords.y, data.coords.z, false, false, false, false)
    end
    local t = GetGameTimer() + 6000
    local veh = 0
    while GetGameTimer() < t do
        veh = NetworkGetEntityFromNetworkId(data.netId)
        if veh ~= 0 and DoesEntityExist(veh) then break end
        Wait(100)
    end
    if veh ~= 0 and DoesEntityExist(veh) then
        NetworkRequestControlOfEntity(veh)
        SetVehicleDoorsLocked(veh, 1)
        TaskWarpPedIntoVehicle(ped, veh, -1)
    end
    Wait(300)
    DoScreenFadeIn(600)
end)

LSLegacy.Events.Register('garage:released', function(data)
    if not data or not data.netId then return end
    local veh = NetworkGetEntityFromNetworkId(data.netId)
    if veh == 0 or not DoesEntityExist(veh) then return end
    local ped = PlayerPedId()
    SetVehicleDoorsLocked(veh, 1)
    if data.warp then
        -- Le véhicule vient d'être téléporté au marker poids lourd, potentiellement
        -- loin du joueur : on le tp directement dedans plutôt qu'un TaskEnterVehicle
        -- (pathfind) qui échouerait ou prendrait trop de temps.
        DoScreenFadeOut(400)
        while not IsScreenFadedOut() do Wait(10) end
        if data.coords then
            SetEntityCoords(ped, data.coords.x, data.coords.y, data.coords.z, false, false, false, false)
        end
        NetworkRequestControlOfEntity(veh)
        TaskWarpPedIntoVehicle(ped, veh, -1)
        Wait(300)
        DoScreenFadeIn(600)
    else
        TaskEnterVehicle(ped, veh, 10000, -1, 1.0, 1, 0)
    end
end)

-- ── Véhicules garés : statebag garageVeh ───────────────────────────
AddStateBagChangeHandler('garageVeh', nil, function(bagName, _, value)
    local ent = GetEntityFromStateBagName(bagName)
    if not ent or ent == 0 then return end
    local t = 0
    while not DoesEntityExist(ent) and t < 50 do Wait(100); t = t + 1 end
    if not DoesEntityExist(ent) then return end
    if value then
        Garage.vehicles[ent] = value
        FreezeEntityPosition(ent, true)
        SetVehicleDoorsLocked(ent, 2)
        SetEntityInvincible(ent, true)
        SetVehicleEngineOn(ent, false, true, true)
        -- l'entité vient d'être streamée : demander le rejeu tuning/dégâts maintenant
        -- (et non sur un délai deviné), regroupé si plusieurs véhicules arrivent ensemble
        if value.mode == 'interior' and Garage.inInstance then Garage.ScheduleVisuals() end
    else
        Garage.vehicles[ent] = nil
        FreezeEntityPosition(ent, false)
        SetEntityInvincible(ent, false)
        SetVehicleDoorsLocked(ent, 1)
    end
end)

-- Entités streamées avant l'arrivée du bag / nettoyage des handles morts
CreateThread(function()
    while true do
        for ent in pairs(Garage.vehicles) do
            if not DoesEntityExist(ent) then Garage.vehicles[ent] = nil end
        end
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if not Garage.vehicles[veh] then
                local st = Entity(veh).state.garageVeh
                if st then
                    Garage.vehicles[veh] = st
                    FreezeEntityPosition(veh, true)
                    SetVehicleDoorsLocked(veh, 2)
                    SetEntityInvincible(veh, true)
                end
            end
        end
        Wait(2000)
    end
end)

function Garage.RequestTakeout(veh)
    local st = Garage.vehicles[veh]
    if not st or GetGameTimer() < busyUntil then return end
    busyUntil = GetGameTimer() + 3000
    LSLegacy.Events.SendToServer('garage:takeout', { garage = st.garage, plate = st.plate })
end

-- Tenter d'entrer dans un véhicule garé = demande de sortie
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsTryingToEnter(ped)
        if veh ~= 0 and Garage.vehicles[veh] then
            ClearPedTasksImmediately(ped)
            Garage.RequestTakeout(veh)
        end
        Wait(150)
    end
end)

local function MoveFlow(veh)
    local st = Garage.vehicles[veh]
    if not st then return end
    LSLegacy.Callbacks.TriggerServer('garage:getSlots', function(slots)
        if not slots then return end
        local from = slots[st.slot]
        local options = {}
        for i, s in ipairs(slots) do
            if i ~= st.slot and not s.plate and SlotDef(s.type).id == SlotDef(from and from.type or 'car').id then
                options[#options + 1] = {
                    title = ('Place %d - %s'):format(i, SlotDef(s.type).label), icon = 'fa-solid fa-square-parking',
                    onSelect = function() LSLegacy.Events.SendToServer('garage:moveSlot', { garage = st.garage, plate = st.plate, slot = i }) end,
                }
            end
        end
        if #options == 0 then return Notify('Aucune autre place libre du même type.', 'error') end
        lib.registerContext({ id = 'garage_move', title = 'Changer de place', options = options })
        lib.showContext('garage_move')
    end, st.garage)
end

-- Fiche/options ox_target flottantes au-dessus du véhicule : réservées aux
-- joueurs ayant accès au garage où il est rangé (sinon un joueur sans accès
-- voit quand même la fiche et les actions d'un véhicule qui ne le concerne pas).
local function CanAccessVehicle(entity)
    local st = Garage.vehicles[entity]
    local g = st and Garage.byId[st.garage]
    return g ~= nil and Garage.CanAccessLocal(g)
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'garage_takeout', icon = 'fa-solid fa-car-side', label = 'Sortir du garage', distance = 3.0,
        canInteract = function(entity) return CanAccessVehicle(entity) end,
        onSelect = function(d) Garage.RequestTakeout(d.entity) end,
    },
    {
        name = 'garage_inspect', icon = 'fa-solid fa-magnifying-glass', label = 'Inspecter', distance = 3.0,
        canInteract = function(entity) return CanAccessVehicle(entity) end,
        onSelect = function(d) if Garage.Showroom then Garage.Showroom(d.entity) end end,
    },
    {
        name = 'garage_move', icon = 'fa-solid fa-arrows-left-right', label = 'Changer de place', distance = 3.0,
        canInteract = function(entity) return CanAccessVehicle(entity) end,
        onSelect = function(d) MoveFlow(d.entity) end,
    },
})

-- ── Serrurier ──────────────────────────────────────────────────────
LSLegacy.Events.Register('garage:locksmithList', function(rows, price)
    if not rows or #rows == 0 then return Notify("Aucun véhicule n'est à votre nom.", 'error') end
    local options = {}
    for _, r in ipairs(rows) do
        options[#options + 1] = {
            title = Garage.ModelLabel(r.model or 0) .. ' [' .. Trim(r.plate) .. ']',
            description = ('Double de clé : %d$'):format(price or 0), icon = 'fa-solid fa-key',
            onSelect = function() LSLegacy.Events.SendToServer('garage:locksmithDuplicate', r.plate) end,
        }
    end
    lib.registerContext({ id = 'garage_locksmith', title = 'Serrurier - Double de clé', options = options })
    lib.showContext('garage_locksmith')
end)

CreateThread(function()
    local L = C.Locksmith
    if not L.enabled then return end
    local hash = GetHashKey(L.ped)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(50); t = t + 1 end
    if not HasModelLoaded(hash) then return end
    local ped = CreatePed(4, hash, L.coords.x, L.coords.y, L.coords.z, L.heading, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(hash)
    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'garage_locksmith', icon = 'fa-solid fa-key', label = 'Faire un double de clé', distance = 2.5,
            onSelect = function() LSLegacy.Events.SendToServer('garage:locksmithList') end,
        },
    })
    if L.blip and L.blip.enabled then
        local b = AddBlipForCoord(L.coords.x, L.coords.y, L.coords.z)
        SetBlipSprite(b, L.blip.sprite)
        SetBlipColour(b, L.blip.color)
        SetBlipScale(b, L.blip.scale)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(L.blip.label)
        EndTextCommandSetBlipName(b)
    end
end)

-- ── Pont MDT (onglet Garage) ───────────────────────────────────────
local pending, counter = {}, 0
LSLegacy.Events.Register('mdtgarage:queryResult', function(payload)
    if type(payload) ~= 'table' then return end
    local cb = pending[payload.reqId]
    if cb then pending[payload.reqId] = nil; cb(payload.result) end
end)
RegisterNUICallback('mdtgarage:getLogs', function(data, cb)
    counter = counter + 1
    local reqId = counter
    pending[reqId] = function(res)
        -- le serveur ne connaît que le hash du modèle (GetDisplayNameFromVehicleModel
        -- est un natif client) : on résout le nom lisible ici avant de le renvoyer au NUI
        if type(res) == 'table' and type(res.vehicles) == 'table' then
            for _, v in ipairs(res.vehicles) do
                if v.model then v.model = Garage.ModelLabel(tonumber(v.model) or 0) end
            end
        end
        cb(res == nil and false or res)
    end
    LSLegacy.Events.SendToServer('mdtgarage:query', { reqId = reqId, action = 'getLogs', data = {} })
    Citizen.SetTimeout(15000, function()
        if pending[reqId] then pending[reqId] = nil; cb(false) end
    end)
end)
