-- ═══════════════════════════════════════════════════════════════════
--  MODULE MÉTRO — Client principal
--  Le moteur du jeu spawn/pilote/arrête lui-même les rames natives sur
--  la piste métro (SetRandomTrains + SetTrainTrackSpawnFrequency,
--  approche adaptée de XNL-FiveM-Trains-U3). On ne gère ici que les
--  blips de station et les bornes de ticket (props + ox_target).
-- ═══════════════════════════════════════════════════════════════════

local machines = {}   -- [stationId] = entity
local metroEnabled = true -- basculé par /metrotoggle (staff), voir metro:setEnabled

local function dbg(...) if Config.Metro.Debug then print('[metro]', ...) end end

local function Notify(msg, type)
    TriggerEvent(Config.Metro.NotifyEvent, 'Métro', msg, 5000, type or 'info')
end

-- ── Piste de métro ──────────────────────────────────────────────────
-- client/player/spawn.lua coupe la piste 3 et SetRandomTrains à chaque
-- respawn : on les réactive donc nous-mêmes après chaque spawn, sinon
-- aucune rame ambiante ne peut apparaître.

local function EnsureTrack()
    if not metroEnabled then return end
    SwitchTrainTrack(Config.Metro.TrackId, true)
    SetTrainTrackSpawnFrequency(Config.Metro.TrackId, Config.Metro.SpawnFrequency)
    SetRandomTrains(true)
    SetTrainsForceDoorsOpen(false)
    dbg('piste', Config.Metro.TrackId, 'réactivée, spawn ambiant activé')
end

AddEventHandler('playerSpawned', function()
    Wait(2000)
    EnsureTrack()
end)

CreateThread(EnsureTrack)

-- ── Blips ───────────────────────────────────────────────────────────

local function CreateBlips()
    for _, s in ipairs(Config.Metro.Stations) do
        local blip = AddBlipForCoord(s.coords.x, s.coords.y, s.coords.z)
        SetBlipSprite(blip, Config.Metro.BlipSprite)
        SetBlipColour(blip, Config.Metro.BlipColor)
        SetBlipScale(blip, Config.Metro.BlipScale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Métro — ' .. s.label)
        EndTextCommandSetBlipName(blip)
    end
    dbg(#Config.Metro.Stations, 'blips de station créés')
end

CreateThread(CreateBlips)

-- ── Bornes de tickets (props + ox_target) ───────────────────────────

local function loadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

-- Le script ne fait QUE spawn le prop — le ticket acheté n'est associé à
-- aucune station (voir le ciblage ox_target global plus bas, qui réagit
-- au modèle et pas à une entité précise : ça inclut aussi bien nos props
-- que les `prop_train_ticket_02` déjà placés nativement par le jeu).

local function spawnMachine(station)
    local m = station.ticketMachine
    local hash = loadModel(Config.Metro.TicketMachineModel)
    if not hash then
        dbg('ERREUR : modèle', Config.Metro.TicketMachineModel, 'non chargé, borne', station.id, 'annulée')
        return
    end
    local z = m.coords.z + Config.Metro.TicketMachineZOffset
    local obj = CreateObjectNoOffset(hash, m.coords.x, m.coords.y, z, false, false, false)
    SetEntityHeading(obj, m.heading)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    SetModelAsNoLongerNeeded(hash)
    machines[station.id] = obj
    dbg('borne spawnée pour', station.id, '- entité', obj)
end

local function despawnMachine(stationId)
    local obj = machines[stationId]
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    machines[stationId] = nil
    dbg('borne despawnée pour', stationId)
end

CreateThread(function()
    while true do
        if not metroEnabled then
            for id in pairs(machines) do despawnMachine(id) end
        else
            local pc = GetEntityCoords(PlayerPedId())
            for _, s in ipairs(Config.Metro.Stations) do
                if s.ticketMachine then
                    local dist = #(pc - s.ticketMachine.coords)
                    if dist <= Config.Metro.PropRenderDistance then
                        if not machines[s.id] then spawnMachine(s) end
                    elseif machines[s.id] then
                        despawnMachine(s.id)
                    end
                end
            end
        end
        Wait(1000)
    end
end)

-- Ciblage global sur le modèle : réagit sur toute borne de ce modèle,
-- que ce soit une des nôtres ou une instance déjà placée nativement par
-- le jeu. Le ticket acheté n'est associé à aucune station en particulier.
exports.ox_target:addModel(Config.Metro.TicketMachineModel, {
    {
        name = 'metro_ticket',
        icon = 'fa-solid fa-ticket',
        label = string.format(Lang.Metro.buy_ticket, Config.Metro.Price),
        distance = Config.Metro.ZoneDistance,
        onSelect = function()
            if not metroEnabled then
                Notify(Lang.Metro.metro_disabled, 'error')
                return
            end
            dbg('achat ticket demandé')
            -- L'heure in-game n'existe que côté client : on la transmet
            -- pour le label du ticket.
            LSLegacy.Events.SendToServer('metro:buyTicket', GetClockHours(), GetClockMinutes())
        end,
    },
})

-- ── Debug : localiser toutes les rames sur la carte ─────────────────
-- Les rames étant spawnées par le moteur (ambiant), on n'a aucune
-- référence à leur entité : on les retrouve en scannant le pool véhicule
-- par modèle. Chaque wagon d'une même rame partage ce modèle, donc on
-- déduplique via GetTrainCarriageEngine (renvoie la tête pour n'importe
-- quel wagon de la même rame) pour n'avoir qu'un blip par rame réelle.

local trainBlipsEnabled = false
local trainBlips = {} -- [entité tête] = blip

local function RefreshTrainBlips()
    local metrotrainHash = GetHashKey('metrotrain')
    local pool = GetGamePool('CVehicle')
    local newBlips = {}

    for _, veh in ipairs(pool) do
        if DoesEntityExist(veh) and GetEntityModel(veh) == metrotrainHash then
            local ok, engine = pcall(GetTrainCarriageEngine, veh)
            local key = (ok and engine and engine ~= 0 and DoesEntityExist(engine)) and engine or veh

            if not newBlips[key] then
                local blip = trainBlips[key]
                if not blip or not DoesBlipExist(blip) then
                    blip = AddBlipForEntity(key)
                    SetBlipSprite(blip, 404)
                    SetBlipColour(blip, 1)
                    SetBlipScale(blip, 0.9)
                    BeginTextCommandSetBlipName('STRING')
                    AddTextComponentString('DEBUG Rame métro')
                    EndTextCommandSetBlipName(blip)
                end
                newBlips[key] = blip
            end
        end
    end

    for key, blip in pairs(trainBlips) do
        if not newBlips[key] and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    trainBlips = newBlips
end

CreateThread(function()
    while true do
        if trainBlipsEnabled then
            RefreshTrainBlips()
            Wait(2000)
        else
            Wait(1000)
        end
    end
end)

LSLegacy.Events.Register('metro:toggleTrainBlips', function()
    trainBlipsEnabled = not trainBlipsEnabled
    dbg('blips de debug rames', trainBlipsEnabled and 'ACTIVÉS' or 'DÉSACTIVÉS')
    if not trainBlipsEnabled then
        for key, blip in pairs(trainBlips) do
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
        trainBlips = {}
    end
    Notify('Blips de debug des rames ' .. (trainBlipsEnabled and 'activés.' or 'désactivés.'), 'success')
end)

-- ── Retours serveur ─────────────────────────────────────────────────

LSLegacy.Events.Register('metro:setEnabled', function(enabled)
    metroEnabled = enabled
    dbg('métro', enabled and 'ACTIVÉ' or 'DÉSACTIVÉ', 'par le staff')
    if not enabled then
        SetRandomTrains(false)
    else
        EnsureTrack()
    end
end)

LSLegacy.Events.Register('metro:ticketBought', function()
    dbg('ticket acheté avec succès')
    Notify(Lang.Metro.ticket_bought, 'success')
end)

LSLegacy.Events.Register('metro:ticketFailed', function(reason)
    dbg('achat ticket refusé :', tostring(reason))
    Notify(reason or Lang.Metro.ticket_failed, 'error')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(machines) do despawnMachine(id) end
end)
