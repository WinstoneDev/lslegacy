-- Deux magasins indépendants (stock, employés en service, alarme) : Grove Street (Strawberry) et Grapeseed, même enseigne/job mais aucune donnée partagée. Coordonnées approximatives, à ajuster si besoin.

Config.LTD = {}

-- Job rattaché au module
Config.LTD.Job = 'ltd'

-- Magasins
-- Chaque magasin a son propre stock, ses propres employés en service et
-- sa propre alarme. `id` doit être unique et stable (utilisé en BDD).
Config.LTD.Stores = {
    {
        id      = 'groove',
        label   = 'LTD Grove Street',
        headquarters        = vector3(-48.5, -1757.3, 29.4),
        headquartersHeading = 240.0,
        clothingCoords       = vector3(-44.7, -1754.0, 29.4),
        registerCoords         = vector3(-47.0, -1751.9, 29.4),
        storageCoords             = vector3(-51.8, -1755.0, 29.4),
        shelfCoords                 = vector3(-46.0, -1755.5, 29.4),
        blipSprite = 59,
        blipColor  = 5,
    },
    {
        id      = 'grapeseed',
        label   = 'LTD Grapeseed',
        headquarters        = vector3(2540.4, 4671.8, 38.4),
        headquartersHeading = 130.0,
        clothingCoords       = vector3(2544.0, 4668.5, 38.4),
        registerCoords         = vector3(2538.0, 4674.0, 38.4),
        storageCoords             = vector3(2535.0, 4669.0, 38.4),
        shelfCoords                 = vector3(2541.5, 4669.5, 38.4),
        blipSprite = 59,
        blipColor  = 5,
    },
}

-- Tenues disponibles au vestiaire (communes aux deux magasins)
Config.LTD.Outfits = {
    {
        label  = 'Tablier LTD',
        grade  = 0,
        male   = {
            tshirt_1 = 30, tshirt_2 = 0,
            torso_1  = 14, torso_2  = 3,
            pants_1  = 4,  pants_2  = 0,
            shoes_1  = 6,  shoes_2  = 0,
            helmet_1 = -1, helmet_2 = -1,
            chain_1  = -1, chain_2  = -1,
            ears_1   = -1, ears_2   = -1,
        },
        female = {
            tshirt_1 = 30, tshirt_2 = 0,
            torso_1  = 13, torso_2  = 3,
            pants_1  = 8,  pants_2  = 0,
            shoes_1  = 4,  shoes_2  = 0,
            helmet_1 = -1, helmet_2 = -1,
            chain_1  = -1, chain_2  = -1,
            ears_1   = -1, ears_2   = -1,
        },
    },
}

-- Compatibilité interne (utilisé par ApplyUniform)
Config.LTD.Uniforms = {
    male   = Config.LTD.Outfits[1].male,
    female = Config.LTD.Outfits[1].female,
}

-- Articles vendus en caisse (catalogue commun aux deux magasins)
-- `item` doit exister dans Config.Items (shared/config.lua).
-- Le STOCK, lui, est totalement indépendant par magasin (voir server/stock.lua).
Config.LTD.Items = {
    { item = 'food_bread',  label = 'Pain',          price = 8  },
    { item = 'food_burger', label = 'Hamburger',     price = 15 },
    { item = 'food_water',  label = "Bouteille d'eau", price = 5 },
    { item = 'food_sprunk', label = 'Sprunk',         price = 6  },
    { item = 'cigarettes',  label = 'Cigarettes',      price = 12 },
}

-- Quantité de réassort par passage rayon → caisse
Config.LTD.RestockAmount = 5

-- Stock de départ si jamais initialisé
Config.LTD.DefaultReserveStock = 0
Config.LTD.DefaultShelfStock   = 10

-- Vol à l'étalage
Config.LTD.Theft = {
    cooldown      = 120,  -- secondes entre deux vols sur LE MÊME magasin
    alertRadiusPD = true, -- notifie les policiers en service avec waypoint
}

-- Actions / cooldowns
Config.LTD.Actions = {
    interactionRange = 2.5,
    cooldowns = {
        sell    = 1500,
        restock = 3000,
        theft   = 5000,
        alarm   = 30000,
    },
}

-- Notification (même système que les autres métiers)
Config.LTD.NotifyEvent = 'brutal_notify:SendAlert'
