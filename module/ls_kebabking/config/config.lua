-- ls_kebabking — Configuration générale.
--
-- Ressource autonome : aucune dépendance vers ls_burgershot ou ls_aldentes.

KKConfig = {}

KKConfig.Debug = false

-- ── Identité de l'entreprise ─────────────────────────────────────────────
KKConfig.Job      = 'kebabking'
KKConfig.JobLabel = "Kebab King"
KKConfig.Prefix   = 'ls_kebabking'

KKConfig.MinGrade = 0

-- ── Service ──────────────────────────────────────────────────────────────
-- Pas de zone physique : la prise/fin de service se fait depuis le tableau
-- de bord du MDT (tablette), voir module/ls_kebabking/config_mdt.lua et
-- client/main.lua (LSLegacy.MDT.DutyToggles côté externe).

-- ── Blip ─────────────────────────────────────────────────────────────────
KKConfig.Blip = {
    enabled = true,
    coords  = vec3(256.40, -817.48, 30.19), -- calé sur la caisse (entrée) ; à ajuster avec /kk_coords si besoin
    sprite  = 439,
    color   = 5, -- jaune
    scale   = 0.8,
    label   = "Kebab King",
}

-- ── Sécurité serveur ─────────────────────────────────────────────────────
KKConfig.Security = {
    maxDistance    = 4.0,
    rateWindow     = 15000,
    rateMaxActions = 30,
    craftCooldown  = 350,
}

-- ── Logs ─────────────────────────────────────────────────────────────────
KKConfig.Logs = {
    console = true,
    -- set lslegacy_ls_kebabking_webhook "https://discord.com/api/webhooks/..."
    convar  = 'lslegacy_ls_kebabking_webhook',
}

-- ── Animations réutilisables ─────────────────────────────────────────────
KKConfig.Anims = {
    cut = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer',
        -- Bone 60309 (PH_R_Hand), comme grill/fry/sauce/drink ci-dessous : le
        -- couteau utilisait 28422 (bone squelette), d'où un placement en main
        -- incorrect contrairement aux autres props de cette table.
        flag = 49, prop = { model = 'prop_knife', bone = 60309, pos = vec3(0.10, 0.02, 0.01), rot = vec3(-90.0, 0.0, 0.0) },
    },
    spit = {
        dict = 'amb@prop_human_bbq@male@base', clip = 'base',
        flag = 49, prop = { model = 'prop_knife', bone = 60309, pos = vec3(0.10, 0.02, 0.01), rot = vec3(-90.0, 0.0, 0.0) },
    },
    grill = {
        dict = 'amb@prop_human_bbq@male@base', clip = 'base',
        flag = 49, prop = { model = 'prop_cs_bbq_tongs', bone = 28422, pos = vec3(0.10, 0.02, 0.01), rot = vec3(-90.0, 0.0, 0.0) },
    },
    fry = {
        dict = 'anim@heists@box_carry@', clip = 'idle',
        flag = 49, prop = { model = 'prop_food_bs_chips', bone = 60309, pos = vec3(0.12, 0.02, -0.02), rot = vec3(-70.0, 0.0, 0.0) },
    },
    sauce = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer',
        flag = 49, prop = { model = 'prop_cs_bowl_01b', bone = 60309, pos = vec3(0.10, 0.02, -0.02), rot = vec3(-70.0, 0.0, 0.0) },
    },
    assemble = {
        dict = 'anim@amb@business@bgen@bgen_no_work@', clip = 'sit_phone_phoneputdown_idle_nowork',
        flag = 49, prop = nil,
    },
    drink = {
        dict = 'anim@am_hold_up@male', clip = 'shoplift_high',
        flag = 49, prop = { model = 'prop_food_bs_juice01', bone = 60309, pos = vec3(0.0, 0.0, -0.03), rot = vec3(0.0, 0.0, 0.0) },
    },
}

-- ── Stations ─────────────────────────────────────────────────────────────
-- Coordonnées relevées en jeu (/kk_coords) dans tstudio_kebabking. La station
-- "Boissons" n'a pas encore été relevée (voir note dans le README) : sa
-- position reste un placeholder à recalibrer.
KKConfig.Stations = {
    prep = {
        label = "Préparation des légumes", icon = 'fa-solid fa-carrot', type = 'craft',
        coords = vec3(254.123, -817.390, 30.30), size = vec3(2.2, 1.0, 1.4), rotation = 155.9, distance = 2.0,
    },
    spit = {
        -- Station de découpe : là où la broche montée (item kebab_spit) est
        -- posée et utilisée. Point relevé par l'utilisateur lui-même.
        label = "Broche à kebab", icon = 'fa-solid fa-fire', type = 'craft',
        coords = vec3(255.771423, -815.261536, 31.00), size = vec3(1.4, 1.2, 2.0), rotation = 343.0, distance = 2.0,
    },
    spit_build = {
        -- Station de montage : où spit_mount fabrique l'item kebab_spit,
        -- ensuite transporté jusqu'à 'spit' pour y être découpé.
        -- Rotation non fournie par l'utilisateur : à recalibrer si besoin.
        label = "Montage de la broche", icon = 'fa-solid fa-screwdriver-wrench', type = 'craft',
        coords = vec3(254.73, -810.20, 30.90), size = vec3(1.4, 1.2, 1.4), rotation = 343.0, distance = 2.0,
    },
    grill = {
        label = "Grill / plaque", icon = 'fa-solid fa-fire-burner', type = 'craft',
        coords = vec3(251.58, -809.37, 30.19), size = vec3(1.8, 1.0, 1.4), rotation = 343.0, distance = 2.0,
    },
    fryer = {
        label = "Friteuse", icon = 'fa-solid fa-bacon', type = 'craft',
        coords = vec3(257.12, -815.21, 30.33), size = vec3(1.4, 1.0, 1.4), rotation = 161.6, distance = 2.0,
    },
    sauces = {
        -- Même comptoir que la préparation des légumes (confirmé en jeu).
        label = "Préparation des sauces", icon = 'fa-solid fa-jar', type = 'craft',
        coords = vec3(254.123, -817.390, 30.30), size = vec3(2.2, 1.0, 1.4), rotation = 155.9, distance = 2.0,
    },
    assembly = {
        label = "Assemblage", icon = 'fa-solid fa-bread-slice', type = 'craft',
        coords = vec3(251.841766, -816.435181, 30.30), size = vec3(2.4, 1.0, 1.4), rotation = 164.4, distance = 2.0,
    },
    assembly2 = {
        -- Deuxième poste d'assemblage : même offre que 'assembly' (voir
        -- sharesRecipesWith, résolu dans shared/utils.lua/KK.RecipeStationId),
        -- juste un second emplacement physique.
        label = "Assemblage", icon = 'fa-solid fa-bread-slice', type = 'craft',
        coords = vec3(250.180222, -816.0131842, 30.30), size = vec3(2.4, 1.0, 1.4), rotation = 164.4, distance = 2.0,
        sharesRecipesWith = 'assembly',
    },
    water = {
        label = "Point d'eau", icon = 'fa-solid fa-faucet-drip', type = 'craft',
        coords = vec3(256.549438, -813.929688, 30.35), size = vec3(1.0, 1.0, 1.6),
        rotation = 153.0708770752, distance = 2.0,
    },
}

-- ── Stockages ────────────────────────────────────────────────────────────
-- Frigo, congélateur et stock boissons partagent la même chambre froide
-- (un seul point relevé pour les trois) : les zones se superposent, ox_target
-- propose alors les trois interactions au même endroit.
KKConfig.Storages = {
    reserve = {
        enabled = true, label = "Réserve", icon = 'fa-solid fa-boxes-stacked',
        coords = vec3(256.11, -811.00, 29.50), size = vec3(1.8, 1.6, 2.0), rotation = 345.8, distance = 2.0,
        maxWeight = 400, cold = nil, minGrade = 0,
    },
    fridge = {
        enabled = true, label = "Frigo", icon = 'fa-solid fa-snowflake',
        coords = vec3(250.15, -811.77, 30.19), size = vec3(1.4, 1.2, 2.0), rotation = 73.7, distance = 2.0,
        maxWeight = 250, cold = 'pro', minGrade = 0,
    },
    freezer = {
        enabled = true, label = "Congélateur", icon = 'fa-solid fa-icicles',
        coords = vec3(250.15, -811.77, 30.19), size = vec3(1.4, 1.2, 2.0), rotation = 73.7, distance = 2.0,
        maxWeight = 250, cold = 'pro', minGrade = 0,
    },
    drinks = {
        enabled = true, label = "Stock boissons", icon = 'fa-solid fa-bottle-water',
        coords = vec3(250.15, -811.77, 30.19), size = vec3(1.4, 1.2, 2.0), rotation = 73.7, distance = 2.0,
        maxWeight = 200, cold = 'pro', minGrade = 0,
    },
}

-- ── Plateaux ─────────────────────────────────────────────────────────────
-- Un seul plateau, position relevée en jeu.
KKConfig.Trays = {
    enabled          = true,
    maxWeight        = 15,
    customersCanTake = true,
    customersCanPut  = false,
    distance         = 2.0,
    size             = vec3(0.8, 0.8, 0.6),
    rotation         = 160.0,
    list = {
        { id = 1, label = "Plateau Kebab King #1", coords = vec3(257.393402, -817.028564, 30.30) },
    },
}

-- ── Caisse ───────────────────────────────────────────────────────────────
KKConfig.Cash = {
    enabled        = true,
    label          = "Caisse",
    icon           = 'fa-solid fa-cash-register',
    coords         = vec3(256.259338, -818.096680, 30.30),
    size           = vec3(1.2, 1.0, 1.4),
    rotation       = 158.7,
    distance       = 2.0,
    maxAmount      = 2000,
    clientDistance = 5.0,
    safeToCompany  = true,
    safeMinGrade   = 3,
}

-- ── Sauces proposées à l'assemblage ──────────────────────────────────────
-- Une recette d'assemblage porte `options.sauce` ; le joueur choisit sa
-- sauce au moment du montage, elle est consommée en plus des ingrédients
-- et son nom est repris dans le libellé du produit fini.
KKConfig.SauceChoices = {
    'sauce_white',
    'sauce_samurai',
    'sauce_algerian',
    'sauce_harissa',
    'sauce_bbq',
    'sauce_mayo',
    'sauce_ketchup',
}

-- ── Pots de sauce ──────────────────────────────────────────────────────
-- Chaque pot est un item unique (voir config/items.lua, `unique = true`)
-- fabriqué avec `KKConfig.PotUses` utilisations. Chaque utilisation
-- (server/pots.lua, via LSLegacy.RegisterUsableItem) dispense une sauce et
-- décrémente le compteur propre à CETTE instance de pot.
KKConfig.PotUses = 20

KKConfig.Pots = {
    pot_ketchup  = { sauce = 'sauce_ketchup' },
    pot_mayo     = { sauce = 'sauce_mayo' },
    pot_bbq      = { sauce = 'sauce_bbq' },
    pot_harissa  = { sauce = 'sauce_harissa' },
    pot_white    = { sauce = 'sauce_white' },
    pot_samurai  = { sauce = 'sauce_samurai' },
    pot_algerian = { sauce = 'sauce_algerian' },
    pot_cheese   = { sauce = 'cheese_sauce' },
}
