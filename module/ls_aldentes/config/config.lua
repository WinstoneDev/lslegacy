-- ls_aldentes — Configuration générale.
--
-- Ressource autonome : aucune dépendance vers ls_burgershot ou ls_kebabking.
-- Toutes les coordonnées, durées, stations, stockages et plateaux sont ici
-- ou dans les deux autres fichiers de config/.

ALDConfig = {}

ALDConfig.Debug = false

-- ── Identité de l'entreprise ─────────────────────────────────────────────
ALDConfig.Job      = 'aldentes'
ALDConfig.JobLabel = "Aldente's"
ALDConfig.Prefix   = 'ls_aldentes'

ALDConfig.MinGrade = 0

-- ── Service ──────────────────────────────────────────────────────────────
ALDConfig.Duty = {
    required = true,
    coords   = vec3(-1197.60, -1408.20, 5.40),
    size     = vec3(1.2, 1.2, 2.0),
    rotation = 125.0,
    label    = "Pointeuse",
    icon     = 'fa-solid fa-clock',
    distance = 2.0,
}

-- ── Blip ─────────────────────────────────────────────────────────────────
ALDConfig.Blip = {
    enabled = true,
    coords  = vec3(-1191.30, -1402.90, 4.50),
    sprite  = 267,
    color   = 5,
    scale   = 0.7,
    label   = "Aldente's",
}

-- ── Sécurité serveur ─────────────────────────────────────────────────────
ALDConfig.Security = {
    maxDistance    = 4.0,
    rateWindow     = 15000,
    rateMaxActions = 30,
    craftCooldown  = 350,
}

-- ── Logs ─────────────────────────────────────────────────────────────────
ALDConfig.Logs = {
    console = true,
    -- set lslegacy_ls_aldentes_webhook "https://discord.com/api/webhooks/..."
    convar  = 'lslegacy_ls_aldentes_webhook',
}

-- ── Animations réutilisables ─────────────────────────────────────────────
ALDConfig.Anims = {
    cut = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer',
        -- Bone 60309 (PH_R_Hand), comme boil/sauce ci-dessous : le couteau
        -- utilisait 28422 (bone squelette), d'où un placement en main incorrect.
        flag = 49, prop = { model = 'prop_knife', bone = 60309, pos = vec3(0.10, 0.02, 0.01), rot = vec3(-90.0, 0.0, 0.0) },
    },
    water = {
        dict = 'amb@world_human_bum_wash@male@low@base', clip = 'base',
        flag = 49, prop = { model = 'prop_wateringcan', bone = 28422, pos = vec3(0.10, 0.02, 0.0), rot = vec3(-80.0, 0.0, 0.0) },
    },
    boil = {
        dict = 'amb@prop_human_bbq@male@base', clip = 'base',
        flag = 49, prop = { model = 'prop_cs_pot_01', bone = 60309, pos = vec3(0.12, 0.02, -0.02), rot = vec3(-70.0, 0.0, 0.0) },
    },
    stove = {
        dict = 'amb@prop_human_bbq@male@base', clip = 'base',
        flag = 49, prop = { model = 'prop_cs_bbq_tongs', bone = 28422, pos = vec3(0.10, 0.02, 0.01), rot = vec3(-90.0, 0.0, 0.0) },
    },
    sauce = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer',
        flag = 49, prop = { model = 'prop_cs_bowl_01b', bone = 60309, pos = vec3(0.10, 0.02, -0.02), rot = vec3(-70.0, 0.0, 0.0) },
    },
    knead = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer',
        flag = 49, prop = nil,
    },
    oven = {
        dict = 'anim@heists@box_carry@', clip = 'idle',
        flag = 49, prop = { model = 'prop_pizza_box_01', bone = 60309, pos = vec3(0.14, 0.03, -0.02), rot = vec3(-75.0, 0.0, 0.0) },
    },
    plating = {
        dict = 'anim@amb@business@bgen@bgen_no_work@', clip = 'sit_phone_phoneputdown_idle_nowork',
        flag = 49, prop = nil,
    },
    dessert = {
        dict = 'amb@prop_human_bum_bin@base', clip = 'base',
        flag = 49, prop = nil,
    },
    drink = {
        dict = 'anim@am_hold_up@male', clip = 'shoplift_high',
        flag = 49, prop = { model = 'prop_wine_glass', bone = 60309, pos = vec3(0.0, 0.0, -0.03), rot = vec3(0.0, 0.0, 0.0) },
    },
}

-- ── Stations ─────────────────────────────────────────────────────────────
ALDConfig.Stations = {
    sink = {
        label = "Point d'eau", icon = 'fa-solid fa-faucet', type = 'craft',
        coords = vec3(-1194.60, -1409.80, 5.40), size = vec3(1.4, 1.0, 1.4), rotation = 125.0, distance = 2.0,
    },
    prep = {
        label = "Plan de préparation", icon = 'fa-solid fa-kitchen-set', type = 'craft',
        coords = vec3(-1193.20, -1408.40, 5.40), size = vec3(2.4, 1.0, 1.4), rotation = 125.0, distance = 2.0,
    },
    pasta = {
        label = "Cuisson des pâtes", icon = 'fa-solid fa-bowl-food', type = 'craft',
        coords = vec3(-1191.80, -1410.20, 5.40), size = vec3(1.6, 1.0, 1.4), rotation = 125.0, distance = 2.0,
    },
    stove = {
        label = "Plaques de cuisson", icon = 'fa-solid fa-fire-burner', type = 'craft',
        coords = vec3(-1190.40, -1408.80, 5.40), size = vec3(1.8, 1.0, 1.4), rotation = 125.0, distance = 2.0,
    },
    sauces = {
        label = "Préparation des sauces", icon = 'fa-solid fa-jar', type = 'craft',
        coords = vec3(-1189.00, -1410.60, 5.40), size = vec3(1.8, 1.0, 1.4), rotation = 125.0, distance = 2.0,
    },
    pizza = {
        label = "Plan à pizza", icon = 'fa-solid fa-pizza-slice', type = 'craft',
        coords = vec3(-1187.60, -1409.20, 5.40), size = vec3(2.0, 1.0, 1.4), rotation = 125.0, distance = 2.0,
    },
    oven = {
        label = "Four à pizza", icon = 'fa-solid fa-fire', type = 'craft',
        coords = vec3(-1186.20, -1411.00, 5.40), size = vec3(1.8, 1.2, 2.0), rotation = 125.0, distance = 2.0,
    },
    plating = {
        label = "Dressage", icon = 'fa-solid fa-utensils', type = 'craft',
        coords = vec3(-1189.80, -1405.60, 5.40), size = vec3(2.2, 1.0, 1.4), rotation = 125.0, distance = 2.0,
    },
    desserts = {
        label = "Desserts", icon = 'fa-solid fa-ice-cream', type = 'craft',
        coords = vec3(-1188.20, -1404.20, 5.40), size = vec3(1.6, 1.0, 1.4), rotation = 125.0, distance = 2.0,
    },
    drinks = {
        label = "Bar / boissons", icon = 'fa-solid fa-mug-hot', type = 'craft',
        coords = vec3(-1186.60, -1405.80, 5.40), size = vec3(1.8, 1.0, 1.6), rotation = 125.0, distance = 2.0,
    },
}

-- ── Stockages ────────────────────────────────────────────────────────────
ALDConfig.Storages = {
    reserve = {
        enabled = true, label = "Réserve", icon = 'fa-solid fa-boxes-stacked',
        coords = vec3(-1197.20, -1412.40, 5.40), size = vec3(1.8, 1.6, 2.0), rotation = 125.0, distance = 2.0,
        maxWeight = 500, cold = nil, minGrade = 0,
    },
    fridge = {
        enabled = true, label = "Frigo", icon = 'fa-solid fa-snowflake',
        coords = vec3(-1195.60, -1411.00, 5.40), size = vec3(1.4, 1.2, 2.0), rotation = 125.0, distance = 2.0,
        maxWeight = 300, cold = 'pro', minGrade = 0,
    },
    freezer = {
        enabled = true, label = "Congélateur", icon = 'fa-solid fa-icicles',
        coords = vec3(-1196.40, -1413.60, 5.40), size = vec3(1.4, 1.2, 2.0), rotation = 125.0, distance = 2.0,
        maxWeight = 250, cold = 'pro', minGrade = 0,
    },
    cellar = {
        enabled = true, label = "Cave à boissons", icon = 'fa-solid fa-bottle-water',
        coords = vec3(-1185.20, -1404.40, 5.40), size = vec3(1.4, 1.2, 2.0), rotation = 125.0, distance = 2.0,
        maxWeight = 250, cold = 'pro', minGrade = 0,
    },
}

-- ── Plateaux ─────────────────────────────────────────────────────────────
ALDConfig.Trays = {
    enabled          = true,
    maxWeight        = 20,
    customersCanTake = true,
    customersCanPut  = false,
    distance         = 2.0,
    size             = vec3(0.9, 0.9, 0.6),
    rotation         = 125.0,
    list = {
        { id = 1, label = "Plateau Aldente's #1", coords = vec3(-1192.60, -1403.40, 5.36) },
        { id = 2, label = "Plateau Aldente's #2", coords = vec3(-1193.30, -1402.60, 5.36) },
        { id = 3, label = "Plateau Aldente's #3", coords = vec3(-1194.00, -1401.80, 5.36) },
        { id = 4, label = "Plateau Aldente's #4", coords = vec3(-1194.70, -1401.00, 5.36) },
    },
}

-- ── Caisse ───────────────────────────────────────────────────────────────
ALDConfig.Cash = {
    enabled        = true,
    label          = "Caisse",
    icon           = 'fa-solid fa-cash-register',
    coords         = vec3(-1195.60, -1400.20, 5.40),
    size           = vec3(1.2, 1.0, 1.4),
    rotation       = 125.0,
    distance       = 2.0,
    maxAmount      = 3000,
    clientDistance = 5.0,
    safeToCompany  = true,
    safeMinGrade   = 2,
}
