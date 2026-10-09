-- module/grossiste — Items introduits par le grossiste (aucun autre module
-- ne les définit encore). Poussés dans le registre partagé au démarrage,
-- comme les 3 restaurants (exports['lslegacy']:registerItems).
--
-- Pas de recette pour l'instant : en réserve pour de futurs métiers
-- (brasserie, pêche, menuiserie/maroquinerie...).
--
-- Volontairement absents : poulet cru, steak haché cru, jambon, viande de
-- veau crue et graisse animale — déjà fournis par la chasse (module farm,
-- stock limité) ; les vendre ici à stock illimité rendrait la chasse inutile.

GRConfig.Items = {
    -- ── Fruits & légumes ─────────────────────────────────────────────────
    raspberry   = { label = "Framboise",  weight = 0.03, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    cucumber    = { label = "Concombre",  weight = 0.15, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    bell_pepper = { label = "Poivron",    weight = 0.10, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    broccoli    = { label = "Brocolis",   weight = 0.15, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    orange      = { label = "Orange",     weight = 0.12, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    avocado     = { label = "Avocat",     weight = 0.10, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    carrot      = { label = "Carotte",    weight = 0.08, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    corn        = { label = "Maïs",       weight = 0.15, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    kiwi        = { label = "Kiwi",       weight = 0.06, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    coconut     = { label = "Noix de Coco", weight = 0.40, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    pineapple   = { label = "Ananas",     weight = 0.50, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    pear        = { label = "Poire",      weight = 0.12, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    cabbage     = { label = "Choux",      weight = 0.30, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    mango       = { label = "Mangue",     weight = 0.20, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    lemon       = { label = "Citron J/V", weight = 0.06, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    rice        = { label = "Sachet de riz", weight = 0.20, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    noodles_dry = { label = "Nouilles déshydratées", weight = 0.20, category = 'ingredient', props = 'prop_cs_bowl_01b' },

    -- ── Brasserie / distillerie (précurseurs, en réserve) ────────────────
    hops      = { label = "Houblon",         weight = 0.10, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    barley    = { label = "Orge",            weight = 0.15, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    sugarcane = { label = "Canne à Sucre",   weight = 0.20, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    agave     = { label = "Agave",           weight = 0.25, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    yeast     = { label = "Levure",          weight = 0.04, category = 'ingredient', props = 'prop_cs_bowl_01b' },

    -- ── Alcools (produits finis) ─────────────────────────────────────────
    grape_juice = { label = "Jus de Raisin", weight = 0.30, category = 'drink', props = 'prop_food_bs_juice01' },
    wine_red    = { label = "Bouteille de Vin Rouge",  weight = 0.75, category = 'drink', props = 'prop_wine_bottle' },
    wine_white  = { label = "Bouteille de Vin Blanc",  weight = 0.75, category = 'drink', props = 'prop_wine_bottle' },
    champagne   = { label = "Bouteille de Champagne",  weight = 0.80, category = 'drink', props = 'prop_wine_bottle' },
    beer_blonde = { label = "Bouteille de Bière Blonde", weight = 0.50, category = 'drink', props = 'prop_beer_bottle' },
    beer_brown  = { label = "Bouteille de Bière Brune",  weight = 0.50, category = 'drink', props = 'prop_beer_bottle' },
    beer_red    = { label = "Bouteille de Bière Rousse", weight = 0.50, category = 'drink', props = 'prop_beer_bottle' },
    whisky      = { label = "Bouteille de Whisky",   weight = 0.70, category = 'drink', props = 'prop_amb_whisky_btl' },
    vodka       = { label = "Bouteille de Vodka",    weight = 0.70, category = 'drink', props = 'prop_amb_whisky_btl' },
    cognac      = { label = "Bouteille de Cognac",   weight = 0.70, category = 'drink', props = 'prop_amb_whisky_btl' },
    moonshine   = { label = "Bouteille d'Eau de Vie", weight = 0.70, category = 'drink', props = 'prop_amb_whisky_btl' },
    cider       = { label = "Bouteille de Cidre",    weight = 0.70, category = 'drink', props = 'prop_wine_bottle' },
    calvados    = { label = "Bouteille de Calvados", weight = 0.70, category = 'drink', props = 'prop_amb_whisky_btl' },
    rum         = { label = "Bouteille de Rhum",     weight = 0.70, category = 'drink', props = 'prop_amb_whisky_btl' },
    tequila     = { label = "Bouteille de Tequila",  weight = 0.70, category = 'drink', props = 'prop_amb_whisky_btl' },

    -- ── Épicerie diverse ──────────────────────────────────────────────────
    chocolate         = { label = "Chocolat",         weight = 0.10, category = 'ingredient', props = 'prop_choc_ego' },
    praline           = { label = "Praline",          weight = 0.10, category = 'ingredient', props = 'prop_choc_ego' },
    almond            = { label = "Amande",           weight = 0.08, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    sausage           = { label = "Saucisses",        weight = 0.12, category = 'ingredient', props = 'prop_cs_steak' },
    merguez           = { label = "Merguez",          weight = 0.12, category = 'ingredient', props = 'prop_cs_steak' },

    -- ── Retail (comble l'approvisionnement de Kebab King) ────────────────
    -- Chaque bouteille/pot/pack est un usable (voir server/main.lua,
    -- GRConfig.Unpacks) qui s'ouvre en 10 unités de l'ingrédient de base
    -- déjà utilisé dans les recettes (vinegar/olive_oil/cream/yogurt).
    bouteille_vinaigre    = { label = "Bouteille de Vinaigre",     weight = 0.60, category = 'ingredient', props = 'prop_ld_flow_bottle' },
    bouteille_huile_olive = { label = "Bouteille d'Huile d'Olive", weight = 0.60, category = 'ingredient', props = 'prop_ld_flow_bottle' },
    pot_creme_fraiche     = { label = "Pot de Crème Fraîche",      weight = 0.50, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    pack_yaourt           = { label = "Pack de Yaourt",            weight = 0.60, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    pot_pate_cookie       = { label = "Pot de Pâte à Cookies",     weight = 0.35, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    pot_pate_viennoiserie = { label = "Pot de Pâte à Viennoiserie", weight = 0.40, category = 'ingredient', props = 'prop_cs_bowl_01b' },

    -- ── Retail (comble l'approvisionnement d'Aldente's) ──────────────────
    sachet_epinard          = { label = "Sachet d'Épinard",         weight = 0.25, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    sachet_mozzarella       = { label = "Sachet de Mozzarella",     weight = 0.30, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    pot_mascarpone          = { label = "Pot de Mascarpone",        weight = 0.40, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    pot_ricotta             = { label = "Pot de Ricotta",           weight = 0.40, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    paquet_spaghetti        = { label = "Paquet de Spaghetti",      weight = 0.40, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    paquet_penne            = { label = "Paquet de Penne",          weight = 0.40, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    paquet_tagliatelle      = { label = "Paquet de Tagliatelle",    weight = 0.40, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    paquet_feuille_lasagne  = { label = "Paquet de Feuille de Lasagne", weight = 0.44, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    boite_vanille           = { label = "Boîte de Vanille",         weight = 0.10, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    paquet_biscuit_cuillere = { label = "Paquet de Biscuit Cuillère", weight = 0.20, category = 'ingredient', props = 'prop_choc_ego' },
    paquet_cafe_grains      = { label = "Paquet de Café en Grains", weight = 0.30, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    paquet_tube_cannoli     = { label = "Paquet de Tube à Cannoli", weight = 0.15, category = 'ingredient', props = 'prop_choc_ego' },

    -- ── Matériaux ────────────────────────────────────────────────────────
    cotton      = { label = "Coton",       weight = 0.08, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    poppy       = { label = "Pavot",       weight = 0.08, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    aloe_vera   = { label = "Aloe Vera",   weight = 0.15, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    fabric      = { label = "Tissus",      weight = 0.20, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    leather     = { label = "Cuir",        weight = 0.25, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    tobacco_raw = { label = "Tabac",       weight = 0.05, category = 'ingredient', props = 'prop_cs_bowl_01b' },

    -- ── Poissonnerie ─────────────────────────────────────────────────────
    salmon_fillet = { label = "Filet de Saumon", weight = 0.20, category = 'ingredient', props = 'prop_cs_steak' },
    tuna_fillet   = { label = "Filet de Thon",   weight = 0.20, category = 'ingredient', props = 'prop_cs_steak' },
    cod_fillet    = { label = "Filet de Colin",  weight = 0.18, category = 'ingredient', props = 'prop_cs_steak' },
    perch_fillet  = { label = "Filet de Perche", weight = 0.16, category = 'ingredient', props = 'prop_cs_steak' },

    -- ── Boissons diverses ────────────────────────────────────────────────
    sparkling_water = { label = "Eau Gazeuse",   weight = 0.33, category = 'drink', props = 'prop_food_bs_juice01' },
    coconut_milk    = { label = "Lait de Coco",  weight = 0.30, category = 'ingredient', props = 'prop_ld_flow_bottle' },
    crushed_ice     = { label = "Glace Pilée",   weight = 0.10, category = 'ingredient', props = 'prop_cs_bowl_01b' },
}
