-- Pilote la météo des 4 zones presets de codem-dynamicweather via ses exports serveur (doit être `ensure`d avant lslegacy).
-- Température calculée (pas piochée dans une plage fixe) : base saisonnière (vraie date IRL) + delta jour/nuit (heure in-game) + bruit + delta de la météo tirée. minAmbient/maxAmbient bornent l'éligibilité d'une météo à la température ambiante (ex : pas de neige à Sandy Shores en été).

Config = Config or {}
Config.Weather = {
    Enabled = true,

    -- Intervalle réel (minutes) entre deux changements de météo, par zone.
    -- Chaque zone tire son propre délai dans cette plage pour ne pas
    -- changer toutes en même temps.
    MinIntervalMinutes = 15,
    MaxIntervalMinutes = 30,

    -- Une zone ne retire jamais la même météo deux fois de suite.
    AvoidRepeat = true,

    -- Bruit aléatoire (°C) ajouté/retiré à la température ambiante calculée.
    TempJitter = 1.5,

    -- Bornes physiques absolues, quoi qu'il arrive (°C).
    TempHardMin = -25,
    TempHardMax = 45,

    -- Niveau de commande requis (LSLegacy.RegisterCommand) pour forcer
    -- un rafraîchissement manuel des 4 zones.
    CommandGroup = 2,

    -- Horloge in-game pilotée par ce module (Config.HandleTime = false côté codem-dynamicweather) : durée réelle FIXE du jour/nuit, seules les heures de lever/coucher bougent avec la saison.
    RealSecondsDayPhase = 3 * 3600,   -- durée réelle du jour in-game (lever -> coucher)
    RealSecondsNightPhase = 1 * 3600, -- durée réelle de la nuit in-game (coucher -> lever)

    -- Amplitude été/hiver de la durée du jour in-game (heures), pivot 12h ; ~2.2h ≈ latitude de Los Santos (été ≈14h de soleil, hiver ≈9h45).
    DaylightAmplitudeHours = 2.2,

    -- Fréquence réelle (ms) à laquelle l'horloge in-game est recalculée
    -- et poussée via setTime. Plus bas = plus fluide, plus haut = moins
    -- d'appels réseau/natives.
    TimeTickMs = 2000,

    -- Zones — clé = id de config/Cities.lua (codem-dynamicweather).
    -- summerAvgTemp / winterAvgTemp : moyenne au pic de l'été / de l'hiver.
    -- diurnalAmplitude : écart (°C) entre le pic de l'après-midi (~15h)
    -- et le creux avant l'aube (~3h) — plus fort dans un désert qu'en
    -- ville côtière.
    -- pool : météos plausibles pour cette zone, avec :
    --   weight              poids de tirage
    --   tempOffsetMin/Max   delta (°C) appliqué à la température ambiante
    --   minAmbient/maxAmbient (optionnels) plage de température ambiante
    --                       (avant delta météo) où l'entrée est éligible
    Zones = {
        [1] = { -- Paleto Bay — forêt de montagne, nord de la carte, le plus froid
            name = 'Paleto Bay',
            summerAvgTemp = 22,
            winterAvgTemp = 2,
            diurnalAmplitude = 7,
            pool = {
                { weather = 'EXTRASUNNY', weight = 4,  tempOffsetMin = 2,  tempOffsetMax = 5 },
                { weather = 'CLEAR',      weight = 16, tempOffsetMin = 0,  tempOffsetMax = 2 },
                { weather = 'NEUTRAL',    weight = 10, tempOffsetMin = -1, tempOffsetMax = 1 },
                { weather = 'CLOUDS',     weight = 16, tempOffsetMin = -2, tempOffsetMax = 0 },
                { weather = 'OVERCAST',   weight = 16, tempOffsetMin = -3, tempOffsetMax = -1 },
                { weather = 'FOGGY',      weight = 10, tempOffsetMin = -3, tempOffsetMax = -1 },
                { weather = 'CLEARING',   weight = 6,  tempOffsetMin = -1, tempOffsetMax = 1 },
                { weather = 'RAIN',       weight = 10, tempOffsetMin = -4, tempOffsetMax = -1, maxAmbient = 18 },
                { weather = 'THUNDER',    weight = 3,  tempOffsetMin = -5, tempOffsetMax = -2, maxAmbient = 20 },
                { weather = 'SNOWLIGHT',  weight = 10, tempOffsetMin = -3, tempOffsetMax = 0,  maxAmbient = 4 },
                { weather = 'SNOW',       weight = 8,  tempOffsetMin = -4, tempOffsetMax = -1, maxAmbient = 1 },
                { weather = 'BLIZZARD',   weight = 2,  tempOffsetMin = -6, tempOffsetMax = -3, maxAmbient = -3 },
            },
        },
        [2] = { -- Sandy Shores — désert, plein soleil et gros écart jour/nuit
            name = 'Sandy Shores',
            summerAvgTemp = 34,
            winterAvgTemp = 14,
            diurnalAmplitude = 9,
            pool = {
                { weather = 'EXTRASUNNY', weight = 34, tempOffsetMin = 1,  tempOffsetMax = 4 },
                { weather = 'CLEAR',      weight = 28, tempOffsetMin = 0,  tempOffsetMax = 2 },
                { weather = 'NEUTRAL',    weight = 8,  tempOffsetMin = -1, tempOffsetMax = 1 },
                { weather = 'CLOUDS',     weight = 6,  tempOffsetMin = -2, tempOffsetMax = 0 },
                { weather = 'FOGGY',      weight = 3,  tempOffsetMin = -2, tempOffsetMax = 0,  maxAmbient = 20 }, -- brume matinale fraîche
                { weather = 'CLEARING',   weight = 5,  tempOffsetMin = -1, tempOffsetMax = 1 },
                { weather = 'SMOG',       weight = 2,  tempOffsetMin = 0,  tempOffsetMax = 2 },
                { weather = 'THUNDER',    weight = 3,  tempOffsetMin = -5, tempOffsetMax = -2, maxAmbient = 32 }, -- orage de désert, rare
                { weather = 'RAIN',       weight = 2,  tempOffsetMin = -5, tempOffsetMax = -2, maxAmbient = 28 }, -- très rare
            },
        },
        [3] = { -- Great Chaparral — collines/forêt tempérée, entre désert et montagne
            name = 'Great Chaparral',
            summerAvgTemp = 27,
            winterAvgTemp = 8,
            diurnalAmplitude = 6,
            pool = {
                { weather = 'EXTRASUNNY', weight = 10, tempOffsetMin = 2,  tempOffsetMax = 4 },
                { weather = 'CLEAR',      weight = 22, tempOffsetMin = 0,  tempOffsetMax = 2 },
                { weather = 'NEUTRAL',    weight = 12, tempOffsetMin = -1, tempOffsetMax = 1 },
                { weather = 'CLOUDS',     weight = 16, tempOffsetMin = -2, tempOffsetMax = 0 },
                { weather = 'OVERCAST',   weight = 12, tempOffsetMin = -3, tempOffsetMax = -1 },
                { weather = 'FOGGY',      weight = 6,  tempOffsetMin = -2, tempOffsetMax = 0 },
                { weather = 'CLEARING',   weight = 6,  tempOffsetMin = -1, tempOffsetMax = 1 },
                { weather = 'RAIN',       weight = 10, tempOffsetMin = -3, tempOffsetMax = -1, maxAmbient = 22 },
                { weather = 'THUNDER',    weight = 4,  tempOffsetMin = -4, tempOffsetMax = -1, maxAmbient = 24 },
                { weather = 'SNOWLIGHT',  weight = 5,  tempOffsetMin = -2, tempOffsetMax = 0,  maxAmbient = 3 },
                { weather = 'SNOW',       weight = 3,  tempOffsetMin = -3, tempOffsetMax = 0,  maxAmbient = 0 },
            },
        },
        [4] = { -- Los Santos — ville côtière méditerranéenne, doux toute l'année
            name = 'Los Santos',
            summerAvgTemp = 27,
            winterAvgTemp = 16,
            diurnalAmplitude = 4, -- la mer amortit l'écart jour/nuit
            pool = {
                { weather = 'EXTRASUNNY', weight = 20, tempOffsetMin = 1,  tempOffsetMax = 3 },
                { weather = 'CLEAR',      weight = 26, tempOffsetMin = 0,  tempOffsetMax = 2 },
                { weather = 'NEUTRAL',    weight = 12, tempOffsetMin = -1, tempOffsetMax = 1 },
                { weather = 'CLOUDS',     weight = 14, tempOffsetMin = -1, tempOffsetMax = 0 },
                { weather = 'OVERCAST',   weight = 6,  tempOffsetMin = -2, tempOffsetMax = 0 },
                { weather = 'FOGGY',      weight = 8,  tempOffsetMin = -2, tempOffsetMax = 0 }, -- brume marine matinale
                { weather = 'CLEARING',   weight = 6,  tempOffsetMin = -1, tempOffsetMax = 1 },
                { weather = 'SMOG',       weight = 4,  tempOffsetMin = 0,  tempOffsetMax = 2 }, -- pollution urbaine
                { weather = 'RAIN',       weight = 5,  tempOffsetMin = -3, tempOffsetMax = -1, maxAmbient = 24 },
                { weather = 'THUNDER',    weight = 1,  tempOffsetMin = -4, tempOffsetMax = -1, maxAmbient = 26 },
            },
        },
    },
}
