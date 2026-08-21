-- codem-dynamicweather n'expose que des overrides temporaires (pas de forecast persistant) : ce module simule la météo lui-même, tirage pondéré par zone (voir config.lua) poussé via setAreaWeather à intervalle aléatoire indépendant par zone.
-- L'horloge in-game est calculée et diffusée par le serveur (Config.HandleTime = false côté codem-dynamicweather) ; les clients l'appliquent avec NetworkOverrideClockTime/SetClockDate (natives client only). La date diffusée est toujours la vraie date de la machine, pour garder la saison cohérente.
-- Météo (/weathercycle on|off) et horloge (freeze admin) sont deux flags indépendants.

local CFG = Config.Weather
local WEATHER_RESOURCE = 'codem-dynamicweather'
local MINUTES_PER_DAY = 1440

local weatherEnabled = CFG.Enabled
local timeFrozen = false
local lastWeather = {} -- [areaId] = weather
local totalMinutes -- horloge : minutes depuis minuit (0-1439)

local function RandomFloat(min, max)
    return min + math.random() * (max - min)
end

local function Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- Interpolation été/hiver sur la vraie date IRL (cosinus, pic ~21 juin = jour 172) → 1.0 = plein été, -1.0 = plein hiver.
local function SeasonFactor()
    local dayOfYear = tonumber(os.date('*t').yday) or 172
    return math.cos((2 * math.pi * (dayOfYear - 172)) / 365)
end

-- Cycle jour/nuit sur l'heure in-game. Pic de chaleur ~15h, creux ~3h (cosinus) → 1.0 = 15h, -1.0 = 3h.
local function DiurnalFactor()
    local hour = totalMinutes and (totalMinutes / 60) or 12
    return math.cos((2 * math.pi * (hour - 15)) / 24)
end

-- Température ambiante de la zone, avant le delta propre à la météo qui sera tirée.
local function AmbientTemperature(zone)
    local season = SeasonFactor()
    local seasonAvg = (zone.summerAvgTemp + zone.winterAvgTemp) / 2
        + (zone.summerAvgTemp - zone.winterAvgTemp) / 2 * season

    local diurnal = zone.diurnalAmplitude * DiurnalFactor()
    local jitter = RandomFloat(-CFG.TempJitter, CFG.TempJitter)

    return seasonAvg + diurnal + jitter
end

-- Tirage pondéré parmi les entrées éligibles (bornes minAmbient/maxAmbient respectées), en évitant si possible la dernière météo de la zone.
local function PickWeather(areaId, zone, ambient)
    local eligible = {}
    local totalWeight = 0
    for _, entry in ipairs(zone.pool) do
        local aboveMin = not entry.minAmbient or ambient >= entry.minAmbient
        local belowMax = not entry.maxAmbient or ambient <= entry.maxAmbient
        if aboveMin and belowMax then
            eligible[#eligible + 1] = entry
            totalWeight = totalWeight + entry.weight
        end
    end

    if #eligible == 0 then
        -- Rien d'éligible (config trop stricte) : repli neutre plutôt que planter.
        return { weather = 'CLEAR', tempOffsetMin = 0, tempOffsetMax = 0 }
    end

    local previous = lastWeather[areaId]
    local pickPool = eligible
    if CFG.AvoidRepeat and previous and #eligible > 1 then
        local withoutPrevious, weightWithoutPrevious = {}, 0
        for _, entry in ipairs(eligible) do
            if entry.weather ~= previous then
                withoutPrevious[#withoutPrevious + 1] = entry
                weightWithoutPrevious = weightWithoutPrevious + entry.weight
            end
        end
        if #withoutPrevious > 0 then
            pickPool = withoutPrevious
            totalWeight = weightWithoutPrevious
        end
    end

    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, entry in ipairs(pickPool) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry
        end
    end
    return pickPool[#pickPool]
end

local function ApplyAreaWeather(areaId, zone)
    local ambient = AmbientTemperature(zone)
    local entry = PickWeather(areaId, zone, ambient)
    local temperature = Clamp(
        math.floor(ambient + RandomFloat(entry.tempOffsetMin, entry.tempOffsetMax) + 0.5),
        CFG.TempHardMin, CFG.TempHardMax
    )

    local ok = exports[WEATHER_RESOURCE]:setAreaWeather(areaId, entry.weather, temperature)
    if ok then
        lastWeather[areaId] = entry.weather
        Config.Development.Print(('[weather] %s -> %s (%d°C, ambiant %.1f°C)'):format(zone.name, entry.weather, temperature, ambient))
    else
        Config.Development.Print(('[weather] échec setAreaWeather pour %s (id=%s)'):format(zone.name, areaId))
    end

    return ok
end

-- Juste après "started", codem-dynamicweather peut encore être en train de
-- charger ses données (lecture SQL/JSON asynchrone) : un premier appel peut
-- donc échouer même si la ressource est démarrée. On retente quelques fois
-- avant d'abandonner pour de bon.
local function ApplyAreaWeatherRetrying(areaId, zone, maxAttempts, delayMs)
    for attempt = 1, maxAttempts do
        if ApplyAreaWeather(areaId, zone) then return true end
        if attempt < maxAttempts then Wait(delayMs) end
    end
    Config.Development.Print(('[weather] abandon pour %s après %d tentatives'):format(zone.name, maxAttempts))
    return false
end

local function RandomIntervalMs()
    return math.random(CFG.MinIntervalMinutes, CFG.MaxIntervalMinutes) * 60000
end

-- Chaque zone tourne sur son propre thread/délai ; il "saute" son tour tant que weatherEnabled est false, pour reprendre instantanément au /weathercycle on.
local function StartAreaCycle(areaId, zone)
    CreateThread(function()
        while true do
            Wait(RandomIntervalMs())
            if weatherEnabled then
                ApplyAreaWeather(areaId, zone)
            end
        end
    end)
end

-- Heures (in-game) de lever/coucher de soleil pour la saison du jour, + durée du jour en heures. Pivot 12h.
local function SunriseSunset()
    local dayLengthHours = Clamp(12 + CFG.DaylightAmplitudeHours * SeasonFactor(), 6, 18)
    local sunrise = 12 - dayLengthHours / 2
    local sunset = 12 + dayLengthHours / 2
    return sunrise, sunset, dayLengthHours
end

-- Vitesse courante de l'horloge (ms réels par minute in-game) pour la phase (jour ou nuit) dans laquelle tombe `minutes`.
local function MsPerGameMinute(minutes)
    local sunrise, sunset, dayLengthHours = SunriseSunset()
    local sunriseMin, sunsetMin = sunrise * 60, sunset * 60
    local dayLengthMin = dayLengthHours * 60
    local nightLengthMin = MINUTES_PER_DAY - dayLengthMin

    local isDay = minutes >= sunriseMin and minutes < sunsetMin
    if isDay then
        return (CFG.RealSecondsDayPhase * 1000) / dayLengthMin
    else
        return (CFG.RealSecondsNightPhase * 1000) / nightLengthMin
    end
end

-- SetClockTime/SetClockDate sont CLIENT ONLY : on diffuse l'heure. `receiver` = -1 pour tout le monde, ou un seul joueur (sync à la connexion).
local function BroadcastClock(receiver)
    local hour = math.floor(totalMinutes / 60)
    local minute = math.floor(totalMinutes % 60)
    local d = os.date('*t')
    LSLegacy.SendEventToClient('weather:syncClock', receiver, hour, minute, d.day, d.month, d.year)
end

local function ReadInitialTotalMinutes()
    local ok, time = pcall(function() return exports[WEATHER_RESOURCE]:getTime() end)
    if ok and type(time) == 'table' and type(time.hour) == 'number' then
        return (time.hour * 60 + (tonumber(time.minute) or 0)) % MINUTES_PER_DAY
    end
    return 8 * 60 -- repli : 8h00
end

-- API partagée (menu admin, etc.)
LSLegacy.Weather = LSLegacy.Weather or {}

-- Recale l'heure ET le point de départ de la boucle : le cycle jour/nuit n'est jamais interrompu par un set manuel, seulement recalé dessus.
function LSLegacy.Weather.SetTime(hour, minute)
    hour = math.floor(Clamp(tonumber(hour) or 0, 0, 23))
    minute = math.floor(Clamp(tonumber(minute) or 0, 0, 59))
    totalMinutes = hour * 60 + minute
    BroadcastClock(-1)
    return true
end

function LSLegacy.Weather.GetTime()
    if not totalMinutes then return nil end
    return math.floor(totalMinutes / 60), math.floor(totalMinutes % 60)
end

-- Gèle/dégèle l'horloge sans toucher au cycle météo (flag indépendant) ; la boucle continue de repousser l'heure pour compenser la dérive du moteur, sans plus avancer totalMinutes tant que c'est gelé.
function LSLegacy.Weather.SetTimeFrozen(state)
    timeFrozen = state and true or false
    return timeFrozen
end

function LSLegacy.Weather.IsTimeFrozen()
    return timeFrozen
end

LSLegacy.RegisterServerEvent('weather:requestClockSync', function()
    local src = source
    if not totalMinutes then return end
    BroadcastClock(src)
end)

local function StartClock()
    CreateThread(function()
        totalMinutes = ReadInitialTotalMinutes()
        BroadcastClock(-1)
        Config.Development.Print(('[weather] horloge dynamique démarrée à %02dh%02d'):format(math.floor(totalMinutes / 60), math.floor(totalMinutes % 60)))

        while true do
            Wait(CFG.TimeTickMs)
            -- Continuer à repousser l'heure même gelée, sinon elle dérive à la vitesse par défaut du jeu.
            if not timeFrozen then
                local msPerGameMinute = MsPerGameMinute(totalMinutes)
                local gameMinutesElapsed = CFG.TimeTickMs / msPerGameMinute
                totalMinutes = (totalMinutes + gameMinutesElapsed) % MINUTES_PER_DAY
            end
            BroadcastClock(-1)
        end
    end)
end

CreateThread(function()
    while GetResourceState(WEATHER_RESOURCE) ~= 'started' do
        Wait(1000)
    end

    -- Premier tirage immédiat pour chaque zone au démarrage, avec retries (les données de codem-dynamicweather peuvent finir de charger juste après).
    for areaId, zone in ipairs(CFG.Zones) do
        ApplyAreaWeatherRetrying(areaId, zone, 10, 3000)
        StartAreaCycle(areaId, zone)
    end
    StartClock()

    Config.Development.Print(('[weather] cycle dynamique démarré sur %d zones'):format(#CFG.Zones))
end)

local function Reply(player, msg, type)
    if player then
        LSLegacy.SendEventToClient('notify', player.source, 'Météo', msg, type or 'info')
    else
        Config.Development.Print('[weather] ' .. msg)
    end
end

LSLegacy.RegisterCommand('weathercycle', CFG.CommandGroup, function(player, args, showError, rawCommand)
    local sub = args and args.action

    if sub == 'off' then
        weatherEnabled = false
        exports[WEATHER_RESOURCE]:clearWeatherOverride()
        exports[WEATHER_RESOURCE]:setGlobalWeather('CLEAR')
        return Reply(player, 'Cycle météo dynamique désactivé (météo forcée au beau temps).')
    elseif sub == 'on' then
        weatherEnabled = true
        for areaId, zone in ipairs(CFG.Zones) do
            ApplyAreaWeather(areaId, zone)
        end
        return Reply(player, 'Cycle météo dynamique réactivé.')
    end

    Reply(player, 'Les 4 zones ont été rafraîchies.', 'success')
end, {
    help = "Force un rafraîchissement météo des 4 zones, ou active/désactive le cycle météo (on/off) — n'affecte pas l'horloge, voir le menu admin pour ça",
    validate = false,
    arguments = { { name = 'action', help = 'on | off (optionnel)', type = 'string' } },
}, true)
