-- ls_burgershot — Configuration générale.
--
-- Cette ressource est volontairement autonome : elle ne dépend d'aucune
-- autre ressource restaurant. Tout ce qui est réglable (coordonnées,
-- durées, stations, stockages, plateaux, animations) est ici ou dans les
-- deux autres fichiers de config/.

BSConfig = {}

-- Journalise en console les refus d'interaction, affiche les zones ox_target
-- et débloque les commandes de calibrage des coordonnées (voir README).
BSConfig.Debug = false

-- ── Identité de l'entreprise ─────────────────────────────────────────────
BSConfig.Job      = 'burgershot'
BSConfig.JobLabel = "Burger Shot"
BSConfig.Prefix   = 'ls_burgershot'   -- préfixe des events, DataStores et logs

-- Grade minimum requis pour les actions courantes. Chaque station et chaque
-- recette peut redéfinir le sien (clé `minGrade`).
BSConfig.MinGrade = 0

-- ── Service ──────────────────────────────────────────────────────────────
-- Prise/fin de service gérée uniquement via le MDT (tablette) : plus de
-- pointeuse physique, voir module/ls_burgershot/client/main.lua.
BSConfig.Duty = {
    -- Il faut être en service pour utiliser les installations professionnelles.
    required = true,
}

-- ── Blip ─────────────────────────────────────────────────────────────────
BSConfig.Blip = {
    enabled = true,
    coords  = vec3(-1193.20, -894.70, 13.98),
    sprite  = 106,
    color   = 47,
    scale   = 0.7,
    label   = "Burger Shot",
}

-- ── Sécurité serveur ─────────────────────────────────────────────────────
BSConfig.Security = {
    -- Distance max autorisée entre le joueur et la station, vérifiée côté serveur.
    maxDistance    = 4.0,
    -- Fenêtre glissante de limitation par joueur (anti-spam d'events).
    rateWindow     = 15000,
    rateMaxActions = 30,
    -- Délai minimum entre deux fabrications d'un même joueur (ms). Sert de
    -- filet : le serveur exige aussi la durée de la recette.
    craftCooldown  = 350,
}

-- ── Logs ─────────────────────────────────────────────────────────────────
BSConfig.Logs = {
    console = true,
    -- Webhook Discord facultatif : jamais en dur ici, il se lit dans server.cfg
    --   set lslegacy_ls_burgershot_webhook "https://discord.com/api/webhooks/..."
    convar  = 'lslegacy_ls_burgershot_webhook',
}

-- ── Animations réutilisables ─────────────────────────────────────────────
-- Modifiable librement : chaque station/recette référence une clé de cette table.
BSConfig.Anims = {
    cut = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer',
        -- Bone 60309 (PH_R_Hand), comme fry/drink ci-dessous : le couteau
        -- utilisait 28422 (bone squelette), d'où un placement en main incorrect.
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
    assemble = {
        dict = 'anim@amb@business@bgen@bgen_no_work@', clip = 'sit_phone_phoneputdown_idle_nowork',
        flag = 49, prop = nil,
    },
    dessert = {
        dict = 'amb@prop_human_bum_bin@base', clip = 'base',
        flag = 49, prop = nil,
    },
}

-- ── Stations ─────────────────────────────────────────────────────────────
-- type = 'craft'   : ouvre le menu des recettes rattachées à cette station
--        'storage' : ouvre un stockage (voir BSConfig.Storages)
--        'tray'    : ouvre un plateau (voir BSConfig.Trays)
--        'cash'    : caisse
-- Coordonnées à relever en jeu (/bs_coords) : les anciennes valeurs étaient
-- des placeholders inventés, jamais calibrés — effacées dans l'attente des
-- vraies positions, fournies une par une.
BSConfig.Stations = {
    prep = {
        label = "Plan de préparation", icon = 'fa-solid fa-kitchen-set', type = 'craft',
        coords = vec3(-1199.881348, -896.400024, 14.009669), size = vec3(2.2, 1.0, 1.4), rotation = 209.76377868652, distance = 2.0,
    },
    grill = {
        label = "Grill", icon = 'fa-solid fa-fire-burner', type = 'craft',
        coords = vec3(-1196.927490, -897.956055, 14.009669), size = vec3(2.0, 1.0, 1.4), rotation = 121.88976287842, distance = 2.0,
    },
    fryer = {
        label = "Friteuse", icon = 'fa-solid fa-bacon', type = 'craft',
        coords = vec3(-1198.232910, -898.404419, 14.009669), size = vec3(1.4, 1.0, 1.4), rotation = 308.97637939453, distance = 2.0,
    },
    assembly = {
        label = "Assemblage", icon = 'fa-solid fa-burger', type = 'craft',
        coords = vec3(-1194.420776, -897.277100, 14.009669), size = vec3(2.2, 1.0, 1.4), rotation = 0.0, distance = 2.0,
    },
    -- Deuxième et troisième points d'assemblage : même offre que 'assembly'
    -- (sharesRecipesWith, voir BS.RecipeStationId dans shared/utils.lua).
    assembly2 = {
        label = "Assemblage", icon = 'fa-solid fa-burger', type = 'craft',
        coords = vec3(-1194.759521, -896.745667, 14.014064), size = vec3(2.2, 1.0, 1.4), rotation = 0.0, distance = 2.0,
        sharesRecipesWith = 'assembly',
    },
    assembly3 = {
        label = "Assemblage", icon = 'fa-solid fa-burger', type = 'craft',
        coords = vec3(-1195.203491, -896.091980, 14.014064), size = vec3(2.2, 1.0, 1.4), rotation = 0.0, distance = 2.0,
        sharesRecipesWith = 'assembly',
    },
}

-- ── Stockages ────────────────────────────────────────────────────────────
-- `cold` : mode de conservation appliqué aux aliments déposés ici.
--          'pro' = péremption figée (frigo/congélateur professionnel)
--          nil   = stockage sec, la péremption continue de courir
-- Un seul et même point pour les 4 : les zones se superposent, ox_target
-- propose alors les quatre interactions au même endroit (même principe que
-- ls_kebabking). Les DataStores restent séparés (noms différents) malgré
-- le point physique commun.
BSConfig.Storages = {
    reserve = {
        enabled = true, label = "Réserve", icon = 'fa-solid fa-boxes-stacked',
        coords = vec3(-1202.624146, -890.610962, 13.980225), size = vec3(1.6, 1.6, 2.0), rotation = 119.05511474609, distance = 2.0,
        maxWeight = 400, cold = nil, minGrade = 0,
    },
    fridge = {
        enabled = true, label = "Frigo", icon = 'fa-solid fa-snowflake',
        coords = vec3(-1202.624146, -890.610962, 13.980225), size = vec3(1.4, 1.2, 2.0), rotation = 119.05511474609, distance = 2.0,
        maxWeight = 250, cold = 'pro', minGrade = 0,
    },
    freezer = {
        enabled = true, label = "Congélateur", icon = 'fa-solid fa-icicles',
        coords = vec3(-1202.624146, -890.610962, 13.980225), size = vec3(1.4, 1.2, 2.0), rotation = 119.05511474609, distance = 2.0,
        maxWeight = 250, cold = 'pro', minGrade = 0,
    },
    drinks = {
        enabled = true, label = "Stock boissons", icon = 'fa-solid fa-bottle-water',
        coords = vec3(-1202.624146, -890.610962, 13.980225), size = vec3(1.4, 1.2, 2.0), rotation = 119.05511474609, distance = 2.0,
        maxWeight = 200, cold = 'pro', minGrade = 0,
    },
}

-- ── Plateaux ─────────────────────────────────────────────────────────────
-- Stockage tampon entre l'équipe et les clients : l'employé y dépose la
-- commande, le client vient la chercher.
-- TODO positions à relever (/bs_coords) : anciennes valeurs (placeholders
-- inventés) effacées.
BSConfig.Trays = {
    enabled          = true,
    maxWeight        = 15,
    customersCanTake = true,    -- un client peut récupérer ce qui est posé
    customersCanPut  = false,   -- mais ne peut rien y déposer
    distance         = 2.0,
    size             = vec3(0.8, 0.8, 0.6),
    rotation         = 0.0,
    list = {
        { id = 1, label = "Plateau Burger Shot #1", coords = vec3(-1194.397461, -892.790344, 13.988970) },
        { id = 2, label = "Plateau Burger Shot #2", coords = vec3(-1192.342651, -893.933044, 13.984575) },
        { id = 3, label = "Plateau Burger Shot #3", coords = vec3(-1191.630371, -894.910645, 14.066117) },
        { id = 4, label = "Plateau Burger Shot #4", coords = vec3(-1190.354858, -896.825806, 13.988970) },
    },
}

-- ── Caisse ───────────────────────────────────────────────────────────────
-- Coordonnées à relever en jeu (/bs_coords) : placeholder inventé effacé.
BSConfig.Cash = {
    enabled   = true,
    label     = "Caisse",
    icon      = 'fa-solid fa-cash-register',
    coords    = vec3(-1191.984619, -894.479492, 14.103716),
    size      = vec3(1.2, 1.0, 1.4),
    rotation  = 0.0,
    distance  = 2.0,
    -- Montant maximum d'une facture (garde-fou serveur).
    maxAmount = 2500,
    -- Distance max entre l'employé et le client facturé.
    clientDistance = 5.0,
    -- Le règlement encaissé alimente le coffre de l'entreprise.
    safeToCompany  = true,
    -- Grade minimum pour ouvrir le coffre de l'entreprise.
    safeMinGrade   = 2,
}
