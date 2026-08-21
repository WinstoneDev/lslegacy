--  MODULE SAPEURS-POMPIERS — Configuration principale
--  Framework : LSLegacy (custom)

Config.Pompiers = {}

-- Job rattaché au module
Config.Pompiers.Job = 'pompiers'

-- Coordonnées de la Caserne de Davis (Los Santos)
Config.Pompiers.Headquarters       = vector3(1193.79, -1464.31, 34.78)
Config.Pompiers.HeadquartersHeading = 0.0

-- Zone d'habillage (vestiaire)
Config.Pompiers.ClothingCoords = vector3(1196.6, -1469.3, 34.78)

-- Point de sortie véhicule
Config.Pompiers.GarageCoords = vector3(1188.0, -1460.3, 34.78)

-- Blips carte
Config.Pompiers.Blips = {
    {
        coords  = Config.Pompiers.Headquarters,
        sprite  = 436,
        color   = 1,
        scale   = 0.9,
        label   = 'Caserne de Davis',
        short   = true,
    },
}

-- Tenues disponibles au vestiaire
Config.Pompiers.Outfits = {
    {
        label  = 'Tenue Sapeur-Pompier',
        grade  = 0,
        male   = {
            tshirt_1 = 21, tshirt_2 = 0,
            torso_1  = 14, torso_2  = 1,
            pants_1  = 20, pants_2  = 0,
            shoes_1  = 25, shoes_2  = 0,
            helmet_1 = -1, helmet_2 = -1,
            chain_1  = -1, chain_2  = -1,
            ears_1   = -1, ears_2   = -1,
        },
        female = {
            tshirt_1 = 21, tshirt_2 = 0,
            torso_1  = 13, torso_2  = 1,
            pants_1  = 28, pants_2  = 0,
            shoes_1  = 28, shoes_2  = 0,
            helmet_1 = -1, helmet_2 = -1,
            chain_1  = -1, chain_2  = -1,
            ears_1   = -1, ears_2   = -1,
        },
    },
}

-- Compatibilité interne (utilisé par ApplyUniform)
Config.Pompiers.Uniforms = {
    male   = Config.Pompiers.Outfits[1].male,
    female = Config.Pompiers.Outfits[1].female,
}

-- Véhicules par grade
Config.Pompiers.Vehicles = {
    fire = {
        { model = 'firetruk', label = 'Camion de Pompiers', grade = 0 },
    },
    rescue = {
        { model = 'lguard', label = 'Véhicule de Sauvetage Côtier', grade = 2 },
    },
}

-- Actions de secours
Config.Pompiers.Actions = {
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
Config.Pompiers.NotifyEvent = 'brutal_notify:SendAlert'
