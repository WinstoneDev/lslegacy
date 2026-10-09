-- Job libre : chaque joueur a sa propre instance (camion + remorque + citerne), suivie via Interim.Sessions[src].
-- Les stations essence sont persistées en BDD (interim_stations), seedées à 50 % au premier démarrage, jamais écrasées ensuite.

local rateLimits = {
    ['interim:startDuty'] = 10, ['interim:endDuty'] = 10, ['interim:rigSpawned'] = 15,
    ['interim:trailerAttached'] = 15, ['interim:trailerDetached'] = 15,
    ['interim:requestFillTank'] = 20, ['interim:stationFillComplete'] = 15,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local CFG = Config.Interim

Interim = Interim or {}
Interim.Sessions = Interim.Sessions or {}
Interim.StationCache = Interim.StationCache or {}

-- Niveau des stations en litres réels (fuel_liters), plafonné à Economy.stationCapacity ; seedé à 50 % de ce plafond au premier démarrage.
local seedLiters = math.floor(CFG.Economy.stationCapacity / 2)

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS interim_stations (
        id                          VARCHAR(32)  NOT NULL,
        label                       VARCHAR(60)  NOT NULL DEFAULT '',
        fuel_liters                 INT          NOT NULL DEFAULT 0,
        last_filled_at              TIMESTAMP    NULL     DEFAULT NULL,
        last_filled_by              VARCHAR(60)  NULL     DEFAULT NULL,
        last_filled_by_character_id INT          NULL     DEFAULT NULL,
        PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {}, function()
    MySQL.Async.execute('ALTER TABLE interim_stations ADD COLUMN IF NOT EXISTS fuel_liters INT NOT NULL DEFAULT 0', {})
    MySQL.Async.execute('ALTER TABLE interim_stations DROP COLUMN IF EXISTS fuel_pct', {})

    for _, s in ipairs(CFG.Stations) do
        MySQL.Async.execute(
            'INSERT IGNORE INTO interim_stations (id, label, fuel_liters) VALUES (@id, @label, @liters)',
            { ['@id'] = s.id, ['@label'] = s.label, ['@liters'] = seedLiters }
        )
    end

    MySQL.Async.fetchAll('SELECT id, fuel_liters, UNIX_TIMESTAMP(last_filled_at) AS last_filled_epoch FROM interim_stations', {}, function(rows)
        for _, row in ipairs(rows or {}) do
            Interim.StationCache[row.id] = {
                liters = math.floor(tonumber(row.fuel_liters) or 0),
                lastFilledAt = tonumber(row.last_filled_epoch),
            }
        end
    end)
end)

local function GetPlayer(src) return LSLegacy.Players.Get(src) end

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Intérimaire', msg, t or 'info', 5000)
end

local function FindStation(id)
    for _, s in ipairs(CFG.Stations) do
        if s.id == id then return s end
    end
    return nil
end

local function BuildState(session)
    return {
        onDuty      = true,
        attached    = session.attached,
        trailerFuel = session.trailerFuel,
        capacity    = CFG.Economy.trailerCapacity,
    }
end

-- Supprime une entité networkée depuis son netId, plus fiable qu'un scan client par plaque puisqu'on garde déjà les netId en mémoire.
local function DeleteNetEntity(netId)
    if not netId then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

local function DeleteRig(session)
    DeleteNetEntity(session.truckNetId)
    DeleteNetEntity(session.trailerNetId)
end

LSLegacy.Events.Register('interim:startDuty', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    if Interim.Sessions[src] then
        return Notify(src, 'Vous êtes déjà en service.', 'error')
    end
    if not FarmMetier.CanStart(player, 'chauffeur_citerne') then
        return Notify(src, FarmMetier.Refusal(player, 'chauffeur_citerne') or 'Vous êtes déjà en service.', 'error')
    end

    Interim.Sessions[src] = { attached = false, trailerFuel = 0, truckNetId = nil, trailerNetId = nil }
    FarmMetier.StartService(src)

    -- TODO: appliquer la tenue intérimaire une fois créée sur le serveur.

    LSLegacy.Events.SendToClient('interim:spawnRig', src, {
        truckModel     = CFG.Truck.model,
        truckCoords    = { x = CFG.Truck.coords.x, y = CFG.Truck.coords.y, z = CFG.Truck.coords.z },
        truckHeading   = CFG.Truck.coords.w,
        trailerModel   = CFG.Trailer.model,
        trailerCoords  = { x = CFG.Trailer.coords.x, y = CFG.Trailer.coords.y, z = CFG.Trailer.coords.z },
        trailerHeading = CFG.Trailer.coords.w,
    })
    Notify(src, 'Vous avez pris votre service.', 'success')
end)

LSLegacy.Events.Register('interim:endDuty', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    local session = Interim.Sessions[src]
    if not session then return Notify(src, "Vous n'êtes pas en service.", 'error') end

    DeleteRig(session)
    Interim.Sessions[src] = nil
    LSLegacy.Events.SendToClient('interim:despawnRig', src, {})
    Notify(src, 'Fin de service.', 'info')
end)

LSLegacy.Events.Register('interim:rigSpawned', function(data)
    local src = source
    if not GetPlayer(src) then return end
    local session = Interim.Sessions[src]
    if not session or type(data) ~= 'table' then return end
    session.truckNetId   = tonumber(data.truckNetId)
    session.trailerNetId = tonumber(data.trailerNetId)
end)

LSLegacy.Events.Register('interim:trailerAttached', function()
    local src = source
    if not GetPlayer(src) then return end
    local session = Interim.Sessions[src]
    if not session then return end
    if not session.truckNetId or not session.trailerNetId then return end
    if session.attached then return end

    session.attached = true
    LSLegacy.Events.SendToClient('interim:syncState', src, BuildState(session))
    Notify(src, 'Remorque attachée. Direction le point de remplissage.', 'success')
end)

-- Détache détectée côté client : coupe l'accès citerne/stations tant que non rattachée. Le message utilisateur est déjà affiché côté client, on se contente de resynchroniser l'état ici.
LSLegacy.Events.Register('interim:trailerDetached', function()
    local src = source
    if not GetPlayer(src) then return end
    local session = Interim.Sessions[src]
    if not session or not session.attached then return end

    session.attached = false
    LSLegacy.Events.SendToClient('interim:syncState', src, BuildState(session))
end)

LSLegacy.Events.Register('interim:requestFillTank', function()
    local src = source
    if not GetPlayer(src) then return end
    local session = Interim.Sessions[src]
    if not session or not session.attached then
        return Notify(src, 'Vous devez être en service et attelé.', 'error')
    end
    if session.trailerFuel >= CFG.Economy.trailerCapacity then
        return Notify(src, 'Citerne déjà pleine.', 'error')
    end

    session.trailerFuel = CFG.Economy.trailerCapacity
    LSLegacy.Events.SendToClient('interim:syncState', src, BuildState(session))
    Notify(src, 'Citerne remplie.', 'success')
end)

-- Déclenché par les zones ci-dessous (canInteractFunc + interactFunc), qui envoient l'anim au client ; la station n'est débitée/créditée qu'une fois l'anim terminée côté client.
LSLegacy.Events.Register('interim:stationFillComplete', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player or type(data) ~= 'table' then return end
    local session = Interim.Sessions[src]
    if not session or not session.attached then return end

    local station = FindStation(data.stationId)
    if not station then return end
    local cache = Interim.StationCache[station.id]
    if not cache then return end

    -- Station toujours vide à l'arrivée (pas de niveau réel suivi) : le plein consomme
    -- systématiquement stationCapacity litres, payé à prix fixe (voir config.lua).
    local delivered = CFG.Economy.stationCapacity
    if session.trailerFuel < delivered then return end
    if cache.lastFilledAt and (os.time() - cache.lastFilledAt) < CFG.Economy.stationCooldownSec then return end

    local pay = CFG.Economy.pricePerStation

    MySQL.Async.execute(
        'UPDATE interim_stations SET fuel_liters=@liters, last_filled_at=NOW(), last_filled_by=@id, last_filled_by_character_id=@charId WHERE id=@sid',
        { ['@id'] = player.identifier, ['@charId'] = player["boutique-id"], ['@sid'] = station.id, ['@liters'] = delivered },
        function()
            cache.liters = delivered
            cache.lastFilledAt = os.time()
            session.trailerFuel = session.trailerFuel - delivered
            -- source doit être ré-assigné explicitement : ce callback tourne hors
            -- du contexte synchrone de l'event, LSLegacy.Bank.PaySalary en dépend
            -- (AddTransaction/UpdateAccount capturent `source` pour le refresh NUI).
            source = src
            LSLegacy.Bank.PaySalary(player, pay, 'Salaire - Ravitaillement station-service')
            LSLegacy.Events.SendToClient('interim:syncState', src, BuildState(session))
            Notify(src, ('%s ravitaillée (+%d $).'):format(station.label, pay), 'success')
        end
    )
end)

for _, s in ipairs(CFG.Stations) do
    LSLegacy.RegisterZone(
        'interim_station_' .. s.id,
        s.coords,
        function(src)
            local player = GetPlayer(src)
            local session = Interim.Sessions[src]
            if not player or not session or not session.attached then return end

            local cache = Interim.StationCache[s.id]
            if not cache then return end

            if cache.lastFilledAt and (os.time() - cache.lastFilledAt) < CFG.Economy.stationCooldownSec then
                local mins = math.ceil((CFG.Economy.stationCooldownSec - (os.time() - cache.lastFilledAt)) / 60)
                return Notify(src, ('%s vient d\'être ravitaillée (%d min restantes).'):format(s.label, mins), 'error')
            end
            if session.trailerFuel < CFG.Economy.stationCapacity then
                return Notify(src, 'Pas assez de carburant dans la citerne — repassez au point de remplissage.', 'error')
            end

            local duration = math.random(CFG.StationFillDuration.min, CFG.StationFillDuration.max)
            LSLegacy.Events.SendToClient('interim:playStationFillAnim', src, {
                stationId = s.id,
                label = s.label,
                duration = duration,
            })
        end,
        20.0,
        true, {
            markerType = 1,
            markerColor = { r = 255, g = 180, b = 0, a = 180 },
            markerScale = 5.0,
        },
        false, nil,
        true, {
            drawNotificationDistance = CFG.Actions.interactionRange,
            notificationMessage = ('Appuyez sur ~INPUT_CONTEXT~ pour remplir %s'):format(s.label),
        },
        false, nil,
        function(src)
            local session = Interim.Sessions[src]
            return session ~= nil and session.attached == true
        end,
        function(src)
            local cache = Interim.StationCache[s.id]
            if not cache then return {} end

            local cooldownLeft = cache.lastFilledAt and math.max(0, CFG.Economy.stationCooldownSec - (os.time() - cache.lastFilledAt)) or 0
            if cooldownLeft > 0 then
                return {
                    notificationMessage = ('%s : pleine, ravitaillable dans %d min'):format(s.label, math.ceil(cooldownLeft / 60)),
                    markerColor = { r = 0, g = 180, b = 0, a = 180 },
                }
            end
            return {
                notificationMessage = ('Appuyez sur ~INPUT_CONTEXT~ pour remplir %s (+%d $)'):format(s.label, CFG.Economy.pricePerStation),
                markerColor = { r = 255, g = 180, b = 0, a = 180 },
            }
        end
    )
end

AddEventHandler('playerDropped', function()
    local src = source
    local session = Interim.Sessions[src]
    if session then DeleteRig(session) end
    Interim.Sessions[src] = nil
end)
