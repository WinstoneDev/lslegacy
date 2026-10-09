-- Gestionnaire de vols : registre, machine à états (autorité), clairances, commandes de test.
-- Le client contrôleur possède les entités et exécute le mouvement ; il rapporte les changements d'état.

local C = Config.ATC
local flights = {}
local nextId = 1
local controller = nil            -- source du joueur en tour (v1 : un seul)
local runwayConfig = C.RunwayConfigs[1].id
local wind = { dir = 120, speedKt = 8 }
local dynamicSpawnOn = false
local metarText = ''

-- Seed dédiée (au lieu de compter sur celle par défaut du runtime, potentiellement corrélée entre
-- ressources démarrées à la même seconde) pour un tirage de vent réellement varié dès le premier METAR.
math.randomseed(os.time() + GetGameTimer())

LSLegacy.Security.RegisterRateLimit('atc:flight:spawned', 30)
LSLegacy.Security.RegisterRateLimit('atc:flight:state', 200)
LSLegacy.Security.RegisterRateLimit('atc:clearance', 60)
LSLegacy.Security.RegisterRateLimit('atc:tower:enter', 10)
LSLegacy.Security.RegisterRateLimit('atc:tower:leave', 10)
LSLegacy.Security.RegisterRateLimit('atc:nui:spawnDeparture', 10)
LSLegacy.Security.RegisterRateLimit('atc:nui:spawnArrival', 10)
LSLegacy.Security.RegisterRateLimit('atc:nui:delete', 10)
LSLegacy.Security.RegisterRateLimit('atc:nui:setRunwayConfig', 10)
LSLegacy.Security.RegisterRateLimit('atc:nui:setDynamicSpawn', 20)

local function IsStaff(src)
    local p = LSLegacy.Players.Get(src)
    return p and LSLegacy.Permissions.Has(p, 2)
end

-- Contrôleur : job ATC avec le grade minimum requis (jamais de confiance client).
local function IsController(src)
    local p = LSLegacy.Players.Get(src)
    return p and p.job == C.Job and (tonumber(p.job_grade) or 0) >= C.MinGrade
end

local function Reply(src, msg)
    LSLegacy.Events.SendToClient('notify', src, 'ATC', msg, 'info')
end

local function StandById(id)
    for _, s in ipairs(C.Stands) do if s.id == id then return s end end
end

-- Stands trop proches pour être occupés en même temps (Config.ATC.StandExclusions).
local function ExcludedBy(standId)
    local out = {}
    for _, pair in ipairs(C.StandExclusions) do
        if pair[1] == standId then out[#out + 1] = pair[2] end
        if pair[2] == standId then out[#out + 1] = pair[1] end
    end
    return out
end

local function IsStandFree(standId, exceptFlightId)
    for _, f in pairs(flights) do
        if f.id ~= exceptFlightId and f.stand == standId and f.state ~= ATC.State.DESPAWN then return false end
    end
    for _, other in ipairs(ExcludedBy(standId)) do
        for _, f in pairs(flights) do
            if f.id ~= exceptFlightId and f.stand == other and f.state ~= ATC.State.DESPAWN then return false end
        end
    end
    return true
end

local function Callsign(model)
    local ac = C.Aircraft[model]
    if model == 'jet' then
        local a = C.Airlines[math.random(#C.Airlines)]
        return a.code .. tostring(math.random(100, 999)), a
    end
    if ac and ac.military then return 'ARMY' .. tostring(math.random(10, 99)), nil end
    return 'N' .. tostring(math.random(100, 999)) .. string.char(math.random(65, 90)) .. string.char(math.random(65, 90)), nil
end

local function Broadcast(flight)
    if controller then LSLegacy.Events.SendToClient('atc:flight:update', controller, flight) end
end

-- ── Météo / METAR ────────────────────────────────────────────────
-- Vent simulé tiré autour des axes de piste (Config.ATC.WindSectors), utilisé à la fois pour
-- le texte METAR et pour choisir automatiquement la configuration de pistes en service.
local function WeightedSector()
    local total = 0
    for _, s in ipairs(C.WindSectors) do total = total + s.weight end
    local r = math.random() * total
    for _, s in ipairs(C.WindSectors) do
        r = r - s.weight
        if r <= 0 then return s end
    end
    return C.WindSectors[1]
end

local function GenerateWind()
    local s = WeightedSector()
    wind.dir = (s.mean + math.random(-s.spread, s.spread) + 360) % 360
    wind.speedKt = math.random(3, 18)
end

-- Meilleure config vent de face : doublet commercial (12/30) et piste affaires (03/21)
-- choisis indépendamment via leur cap compas ('bearing'), puis recombinés en id de config.
local function BestRunwayConfig()
    local commercial = math.cos(math.rad(wind.dir - 120)) >= math.cos(math.rad(wind.dir - 300)) and 'EAST' or 'WEST'
    local business = math.cos(math.rad(wind.dir - 30)) >= math.cos(math.rad(wind.dir - 210)) and '03' or '21'
    return commercial .. '_' .. business
end

-- Traduction du type météo GTA (module weather) en groupe METAR (visibilité/nébulosité/phénomène)
-- + biais de pression (QHN), pour que le METAR ne soit pas toujours "CAVOK Q1013".
local WEATHER_METAR = {
    CLEAR      = { cloud = 'CAVOK', qnhBias = 3 },
    EXTRASUNNY = { cloud = 'CAVOK', qnhBias = 4 },
    NEUTRAL    = { cloud = 'CAVOK', qnhBias = 1 },
    CLEARING   = { visKm = 10, phen = nil,   cloud = 'FEW020', qnhBias = 1 },
    CLOUDS     = { visKm = 10, phen = nil,   cloud = 'SCT025', qnhBias = 0 },
    OVERCAST   = { visKm = 8,  phen = nil,   cloud = 'BKN012', qnhBias = -2 },
    FOGGY      = { visKm = 3,  phen = 'BR',  cloud = 'BKN005', qnhBias = -1 },
    SMOG       = { visKm = 5,  phen = 'HZ',  cloud = 'FEW030', qnhBias = 0 },
    RAIN       = { visKm = 5,  phen = 'RA',  cloud = 'OVC008', qnhBias = -6 },
    THUNDER    = { visKm = 3,  phen = 'TSRA', cloud = 'OVC006', qnhBias = -10 },
    SNOWLIGHT  = { visKm = 4,  phen = '-SN', cloud = 'OVC010', qnhBias = -4 },
    SNOW       = { visKm = 2,  phen = 'SN',  cloud = 'OVC008', qnhBias = -6 },
    BLIZZARD   = { visKm = 1,  phen = '+SN', cloud = 'OVC003', qnhBias = -8 },
}

local function BuildMetar()
    -- Heure : celle du module weather (horloge in-game), repli sur l'heure réelle si indisponible.
    local hh, mm
    if C.UseGameTime and LSLegacy.Weather then hh, mm = LSLegacy.Weather.GetTime() end
    if not hh then hh, mm = tonumber(os.date('!%H')), tonumber(os.date('!%M')) end
    -- Température alignée sur le module weather (codem-dynamicweather) ; repli 22°C si jamais appliquée (démarrage).
    local temp = (LSLegacy.Weather and LSLegacy.Weather.GetTemperature(C.Metar.WeatherAreaId)) or 22
    local dew = temp - 8
    local wtype = LSLegacy.Weather and LSLegacy.Weather.GetWeatherType(C.Metar.WeatherAreaId)
    local wm = WEATHER_METAR[wtype] or WEATHER_METAR.CLEAR
    local qnh = 1013 + wm.qnhBias + math.random(-2, 2)
    local body
    if wm.cloud == 'CAVOK' then
        body = 'CAVOK'
    else
        local parts = { ('%04d'):format(math.floor(wm.visKm * 1000)) }
        if wm.phen then parts[#parts + 1] = wm.phen end
        parts[#parts + 1] = wm.cloud
        body = table.concat(parts, ' ')
    end
    metarText = ('%s %02d%02dZ %03d%02dKT %s %02d/%02d Q%04d NOSIG'):format(
        C.Icao, hh, mm, math.floor(wind.dir), wind.speedKt, body, temp, dew, qnh)
end

local function RefreshMetar()
    GenerateWind()
    BuildMetar()
    runwayConfig = BestRunwayConfig()
    if controller then
        LSLegacy.Events.SendToClient('atc:metar:update', controller, metarText, ATC.RunwayConfig(runwayConfig))
    end
end

-- Numéro de créneau de 30 min de jeu (8h00, 8h30, 9h00...) : le METAR se régénère exactement à chaque
-- passage de créneau (calculé et diffusé côté serveur, seule autorité de l'horloge -> pas de désync
-- client). Repli sur un intervalle réel fixe si l'horloge de jeu (module weather) est indisponible.
local function GameMetarSlot()
    if C.UseGameTime and LSLegacy.Weather then
        local hh, mm = LSLegacy.Weather.GetTime()
        if hh then return hh * 2 + (mm >= 30 and 1 or 0) end
    end
    return nil
end

CreateThread(function()
    RefreshMetar()
    local lastSlot = GameMetarSlot()
    local lastReal = os.time()
    while true do
        Wait(5000)
        local slot = GameMetarSlot()
        if slot ~= nil then
            if slot ~= lastSlot then
                lastSlot = slot
                RefreshMetar()
            end
        elseif os.time() - lastReal >= C.Metar.IntervalMinutes * 60 then
            lastReal = os.time()
            RefreshMetar()
        end
    end
end)

-- Création d'un départ au stand (v1 : commande). Le client crée l'entité et renvoie le netId.
local function SpawnDeparture(src, standId, model)
    local stand = StandById(standId)
    if not stand then return Reply(src, 'Stand inconnu : ' .. tostring(standId)) end
    model = model or (stand.category == 'business' and 'luxor' or stand.category == 'heli' and 'swift' or 'jet')
    local ac = C.Aircraft[model]
    if not ac then return Reply(src, 'Modèle inconnu : ' .. tostring(model)) end
    if ac.category ~= stand.category then return Reply(src, ('%s incompatible avec le stand %s (%s)'):format(model, standId, stand.category)) end
    if not IsStandFree(standId) then return Reply(src, 'Stand occupé ou indisponible (proximité) : ' .. standId) end
    local cs, airline = Callsign(model)
    local f = {
        id = nextId, callsign = cs, model = model, type = ac.icao, airline = airline and airline.name or nil,
        kind = 'DEP', stand = standId, category = ac.category, origin = C.Icao, destination = 'LSXX',
        state = ATC.State.PARKED, node = 'STAND_' .. standId, netId = nil, owner = src,
        runway = ATC.RunwayConfig(runwayConfig)[ac.heli and 'helicopters' or (ac.category == 'business' and 'business' or 'takeoff')],
        created = os.time(),
    }
    nextId = nextId + 1
    flights[f.id] = f
    controller = src
    LSLegacy.Events.SendToClient('atc:flight:spawn', src, f, stand)
    Reply(src, ('Vol #%d %s (%s) créé au stand %s, piste %s'):format(f.id, f.callsign, model, standId, f.runway))
end

-- Nombre d'arrivées déjà en approche/finale/atterrissage sur cette piste : sert à espacer la nouvelle
-- arrivée le long de l'axe (pas de contrôle radar réel, donc pas de superposition à 10 NM).
local function ArrivalsQueued(runway)
    local n = 0
    for _, f in pairs(flights) do
        if f.kind == 'ARR' and f.runway == runway and (f.state == ATC.State.APPROACH or f.state == ATC.State.FINAL or f.state == ATC.State.LANDING) then
            n = n + 1
        end
    end
    return n
end

-- Création d'une arrivée en approche classique, 10 NM dans l'axe du seuil en service.
local function SpawnArrival(src, model)
    model = model or 'jet'
    local ac = C.Aircraft[model]
    if not ac then return Reply(src, 'Modèle inconnu : ' .. tostring(model)) end
    local cs, airline = Callsign(model)
    local cfg = ATC.RunwayConfig(runwayConfig)
    local runway = cfg[ac.heli and 'helicopters' or (ac.category == 'business' and 'business' or 'landing')]
    local queue = ArrivalsQueued(runway)
    if queue >= C.MaxArrivalsPerRunway then
        return Reply(src, ('Piste %s : trop de trafic en approche, patientez'):format(runway))
    end
    local f = {
        id = nextId, callsign = cs, model = model, type = ac.icao, airline = airline and airline.name or nil,
        kind = 'ARR', origin = 'LSXX', destination = C.Icao, category = ac.category,
        state = ATC.State.APPROACH, node = nil, netId = nil, owner = src,
        runway = runway, created = os.time(),
    }
    nextId = nextId + 1
    flights[f.id] = f
    controller = src
    LSLegacy.Events.SendToClient('atc:flight:spawnArrival', src, f, queue)
    Reply(src, ('Vol #%d %s (%s) en approche, piste %s'):format(f.id, f.callsign, model, f.runway))
end

-- ── Spawn automatique dynamique ──────────────────────────────────
-- En plus du spawn manuel : tire un départ ou une arrivée à intervalle aléatoire (moyenne/dispersion
-- dans Config.ATC.DynamicSpawn) tant qu'un contrôleur est en poste et sous la limite de trafic simultané.
local function RandomFreeStand(category)
    local candidates = {}
    for _, s in ipairs(C.Stands) do
        if s.category == category and IsStandFree(s.id) then candidates[#candidates + 1] = s.id end
    end
    if #candidates == 0 then return nil end
    return candidates[math.random(#candidates)]
end

local function RandomModel(category)
    local list = {}
    for model, ac in pairs(C.Aircraft) do
        if ac.category == category then list[#list + 1] = model end
    end
    if #list == 0 then return nil end
    return list[math.random(#list)]
end

local DYN_CATEGORIES = { 'commercial', 'commercial', 'business', 'heli' } -- pondération : commercial favorisé

local function DynamicSpawnTick()
    if not dynamicSpawnOn or not controller then return end
    local count = 0
    for _ in pairs(flights) do count = count + 1 end
    if count >= C.DynamicSpawn.MaxConcurrent then return end
    local cat = DYN_CATEGORIES[math.random(#DYN_CATEGORIES)]
    if math.random() < 0.5 then
        local standId = RandomFreeStand(cat)
        local model = standId and RandomModel(cat)
        if standId and model then SpawnDeparture(controller, standId, model) end
    else
        local model = RandomModel(cat)
        if model then SpawnArrival(controller, model) end
    end
end

CreateThread(function()
    while true do
        local d = C.DynamicSpawn
        Wait((d.AverageIntervalSeconds + math.random(-d.JitterSeconds, d.JitterSeconds)) * 1000)
        DynamicSpawnTick()
    end
end)

LSLegacy.Events.Register('atc:nui:setDynamicSpawn', function(enabled)
    local src = source
    if not (IsStaff(src) or IsController(src)) then return end
    dynamicSpawnOn = enabled and true or false
    Reply(src, 'Spawn automatique ' .. (dynamicSpawnOn and 'activé' or 'désactivé'))
end)

LSLegacy.Events.Register('atc:flight:spawned', function(id, netId)
    local f = flights[id]
    if not f or f.owner ~= source then return end
    f.netId = netId
    Broadcast(f)
end)

LSLegacy.Events.Register('atc:flight:state', function(id, state, node)
    local f = flights[id]
    if not f or f.owner ~= source or not ATC.State[state] then return end
    f.state = state
    if node then f.node = node end
    if state == ATC.State.DESPAWN then
        Broadcast(f)
        flights[id] = nil
        return
    end
    Broadcast(f)
end)

-- Clairance : validée ici, exécutée par le client propriétaire.
local function Clear(src, id, clearance, arg)
    local f = flights[id]
    if not f then return Reply(src, 'Vol inconnu #' .. tostring(id)) end
    clearance = string.upper(clearance or '')
    if clearance == 'LINEUP' then clearance = 'LINE_UP' end
    if not ATC.Clearance[clearance] then return Reply(src, 'Clairance inconnue : ' .. clearance) end
    local allowed = ATC.Allowed[f.state]
    if not allowed or not allowed[clearance] then
        return Reply(src, ('%s : %s impossible en état %s'):format(f.callsign, clearance, f.state))
    end
    -- Décollage direct depuis PARKED : réservé aux hélicoptères (décollage vertical, pas de roulage).
    if clearance == 'TAKEOFF' and f.state == ATC.State.PARKED then
        local ac = C.Aircraft[f.model]
        if not (ac and ac.heli) then return Reply(src, f.callsign .. ' : pushback/taxi requis avant décollage') end
    end
    -- Sans cible fournie (NUI, départs) le client applique un défaut sensé (point de ligne up
    -- de la piste en service) ; une cible fournie doit exister dans le graphe (NUI d'arrivée : stand).
    if clearance == 'TAXI' and arg and not ATC.Graph.Node(arg) then
        return Reply(src, 'Nœud cible inconnu : ' .. tostring(arg))
    end
    -- Mémorise le stand assigné pour une arrivée (jamais fixé au spawn, contrairement à un départ)
    -- afin que la NUI puisse l'exclure des stands libres tant que l'avion l'occupe.
    if clearance == 'TAXI' and arg then
        local standId = arg:match('^STAND_(.+)$')
        if standId then
            if not IsStandFree(standId, f.id) then
                return Reply(src, 'Stand occupé ou indisponible (proximité) : ' .. standId)
            end
            f.stand = standId
        end
    end
    f.clearance = clearance
    f.clearanceArg = arg
    LSLegacy.Events.SendToClient('atc:flight:order', f.owner, id, clearance, arg)
end

LSLegacy.Events.Register('atc:clearance', function(id, clearance, arg)
    local src = source
    if not (IsStaff(src) or IsController(src)) then return end
    Clear(src, tonumber(id), clearance, arg)
end)

-- Choix manuel de la config piste par le contrôleur (remplace l'auto-METAR jusqu'au prochain cycle).
LSLegacy.Events.Register('atc:nui:setRunwayConfig', function(id)
    local src = source
    if not (IsStaff(src) or IsController(src)) then return end
    if not ATC.RunwayConfig(id) or ATC.RunwayConfig(id).id ~= id then return Reply(src, 'Config piste inconnue : ' .. tostring(id)) end
    runwayConfig = id
    if controller then
        LSLegacy.Events.SendToClient('atc:metar:update', controller, metarText, ATC.RunwayConfig(runwayConfig))
    end
end)

-- ── Tour : entrée/sortie (poste NUI) ────────────────────────────────
LSLegacy.Events.Register('atc:tower:enter', function()
    local src = source
    if not IsController(src) then return Reply(src, 'Poste ATC réservé au service (grade insuffisant).') end
    controller = src
    RefreshMetar() -- resynchronise sur la météo actuelle (WeatherAreaId) à chaque prise de poste, sans attendre le créneau de 30 min
    local list = {}
    for _, f in pairs(flights) do list[#list + 1] = f end
    LSLegacy.Events.SendToClient('atc:tower:state', src, list, metarText, ATC.RunwayConfig(runwayConfig), dynamicSpawnOn)
end)

LSLegacy.Events.Register('atc:tower:leave', function()
    if controller == source then controller = nil end
end)

-- ── Commandes NUI (radar/strips) ────────────────────────────────────
LSLegacy.Events.Register('atc:nui:spawnDeparture', function(standId, model)
    local src = source
    if IsController(src) or IsStaff(src) then SpawnDeparture(src, standId, model) end
end)

LSLegacy.Events.Register('atc:nui:spawnArrival', function(model)
    local src = source
    if IsController(src) or IsStaff(src) then SpawnArrival(src, model) end
end)

LSLegacy.Events.Register('atc:nui:delete', function(id)
    local src = source
    if not (IsController(src) or IsStaff(src)) then return end
    local f = flights[tonumber(id)]
    if not f then return end
    LSLegacy.Events.SendToClient('atc:flight:delete', f.owner, f.id)
    flights[f.id] = nil
    if controller then LSLegacy.Events.SendToClient('atc:flight:removed', controller, f.id) end
end)

-- ── Commandes de test (avant NUI) ────────────────────────────────
-- Le dispatcher Core ne transmet que les arguments déclarés (par nom, type 'any' = optionnel).
LSLegacy.RegisterCommand('atcspawn', 2, function(xPlayer, args)
    SpawnDeparture(xPlayer.source, args.stand, args.modele)
end, { help = 'ATC : créer un départ au stand', validate = false, arguments = {
    { name = 'stand', help = 'C1..C10, B1..B5, H1..H3', type = 'any' },
    { name = 'modele', help = 'jet, luxor, shamal... (optionnel)', type = 'any' },
} }, false)

LSLegacy.RegisterCommand('atcarr', 2, function(xPlayer, args)
    SpawnArrival(xPlayer.source, args.modele)
end, { help = 'ATC : créer une arrivée en approche (10 NM)', validate = false, arguments = {
    { name = 'modele', help = 'jet, luxor, shamal... (optionnel)', type = 'any' },
} }, false)

LSLegacy.RegisterCommand('atcclr', 2, function(xPlayer, args)
    Clear(xPlayer.source, tonumber(args.id), args.clairance, args.cible)
end, { help = 'ATC : clairance', validate = false, arguments = {
    { name = 'id', help = 'numéro du vol', type = 'any' },
    { name = 'clairance', help = 'pushback | taxi | cross | lineup | takeoff', type = 'any' },
    { name = 'cible', help = 'nœud cible pour taxi (ex : HP_D3_12L)', type = 'any' },
} }, false)

LSLegacy.RegisterCommand('atclist', 2, function(xPlayer)
    local n = 0
    for _, f in pairs(flights) do
        n = n + 1
        Reply(xPlayer.source, ('#%d %s %s %s état %s nœud %s piste %s'):format(f.id, f.callsign, f.model, f.kind, f.state, tostring(f.node), tostring(f.runway)))
    end
    if n == 0 then Reply(xPlayer.source, 'Aucun vol') end
end, { help = 'ATC : lister les vols', validate = false }, false)

LSLegacy.RegisterCommand('atcdel', 2, function(xPlayer, args)
    local id = tonumber(args.id)
    local f = id and flights[id]
    if not f then return Reply(xPlayer.source, 'Vol inconnu') end
    LSLegacy.Events.SendToClient('atc:flight:delete', f.owner, id)
    flights[id] = nil
    if controller then LSLegacy.Events.SendToClient('atc:flight:removed', controller, id) end
    Reply(xPlayer.source, ('Vol #%d supprimé'):format(id))
end, { help = 'ATC : supprimer un vol', validate = false, arguments = {
    { name = 'id', help = 'numéro du vol', type = 'any' },
} }, false)

LSLegacy.RegisterCommand('atcrwy', 2, function(xPlayer, args)
    local cfg = ATC.RunwayConfig(args.config)
    if not args.config or cfg.id ~= args.config then return Reply(xPlayer.source, 'Configs : EAST_03, EAST_21, WEST_03, WEST_21') end
    runwayConfig = cfg.id
    Reply(xPlayer.source, ('Pistes en service : atterrissage %s, décollage %s, affaires %s'):format(cfg.landing, cfg.takeoff, cfg.business))
end, { help = 'ATC : configuration de pistes en service', validate = false, arguments = {
    { name = 'config', help = 'EAST_03 | EAST_21 | WEST_03 | WEST_21', type = 'any' },
} }, false)

AddEventHandler('playerDropped', function()
    local src = source
    for id, f in pairs(flights) do
        if f.owner == src then flights[id] = nil end
    end
    if controller == src then controller = nil end -- déjà couvert, laissé explicite (tour + vols)
end)
