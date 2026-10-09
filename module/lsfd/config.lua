--  MODULE LSFD — Configuration principale
--  Framework : LSLegacy (custom)

Config.LSFD = {}

-- Job rattaché au module
Config.LSFD.Job = 'lsfd'

-- Coordonnées de la Caserne de Davis (Los Santos)
Config.LSFD.Headquarters       = vector3(1193.79, -1464.31, 34.78)
Config.LSFD.HeadquartersHeading = 0.0

-- Point de sortie véhicule

-- Blips carte
Config.LSFD.Blips = {
    {
        coords  = Config.LSFD.Headquarters,
        sprite  = 436,
        color   = 1,
        scale   = 0.9,
        label   = 'Caserne de Davis',
        short   = true,
    },
}

-- Véhicules par grade

-- Actions de secours
Config.LSFD.Actions = {
    -- Durée des actions en millisecondes
    extinguishDuration  = 4000,
    rescueDuration       = 6000,
    interactionRange    = 2.0,
    extinguishRadius     = 8.0,

    -- Désincarcération : santé restaurée après extraction (100=mort, 200=plein → 125=25%)
    rescueHealth          = 125,
    -- Soin léger si la victime n'est pas en KO/coma
    rescueHealAmount      = 30,

    -- Anti-abus : cooldown entre deux actions identiques (ms)
    cooldowns = {
        extinguish = 4000,
        rescue     = 8000,
    },
}

-- Notification (même système que les autres métiers)
