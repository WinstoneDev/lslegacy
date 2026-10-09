-- ls_kebabking — Items propres au Kebab King.
--
-- Poussés dans le registre du framework au démarrage
-- (exports['lslegacy']:registerItems), retirés si la ressource s'arrête.
-- Le nom technique est aussi le nom de l'image : images/<nom>.png
-- Plus aucun item n'est préfixé : les trois restos partagent le même
-- registre Config.Items depuis leur fusion dans lslegacy, chaque item n'est
-- défini que dans UN SEUL des trois items.lua, les deux autres se contentant
-- d'y faire référence dans leurs recettes.

KKConfig.Items = {
    -- ── Ingrédients bruts ────────────────────────────────────────────────
    -- patty_raw/patty_cooked (steak haché) : voir ls_burgershot/config/items.lua
    -- (item partagé — fusionné avec l'ancien ground_steak_raw/cooked, doublon).
    kebab_meat_raw   = { label = "Viande de veau crue",      weight = 0.30, category = 'ingredient', props = 'prop_cs_steak' },
    chickpea         = { label = "Pois chiches",             weight = 0.15, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    cheese           = { label = "Fromage",                  weight = 0.12, category = 'ingredient', props = 'prop_cs_burger_01' },
    -- olive_oil : voir ls_aldentes/config/items.lua (fusionné avec l'ancien
    -- oil générique, doublon — même principe que patty_raw/ground_steak_raw).
    yogurt           = { label = "Yaourt",                   weight = 0.18, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    spices           = { label = "Épices",                   weight = 0.04, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    herbs            = { label = "Herbes fraîches",          weight = 0.03, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    harissa_pepper   = { label = "Piments",                  weight = 0.06, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    flour            = { label = "Farine",                   weight = 0.20, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    salt             = { label = "Sel",                      weight = 0.05, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    wheat            = { label = "Blé",                      weight = 0.20, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    vinegar          = { label = "Vinaigre",                 weight = 0.15, category = 'ingredient', props = 'prop_ld_flow_bottle' },
    honey            = { label = "Miel",                     weight = 0.15, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    cream            = { label = "Crème",                    weight = 0.20, category = 'ingredient', props = 'prop_ld_flow_bottle' },
    water_glass      = { label = "Verre d'eau",              weight = 0.25, category = 'ingredient', props = 'prop_food_bs_juice01' },
    -- Pas de sirops : les sodas (eau/cola/sprunk/o'tang) sont des produits
    -- finis, sans aucune recette ni mécanisme d'acquisition en jeu.

    -- ── Produits préparés ────────────────────────────────────────────────
    bread_pita    = { label = "Pain pita",           weight = 0.12, category = 'prepared', props = 'prop_cs_burger_01' },
    tortilla      = { label = "Tortilla",            weight = 0.10, category = 'prepared', props = 'prop_taco_01' },
    salad_cut     = { label = "Feuille de salade",   weight = 0.05, category = 'prepared', props = 'prop_cs_bowl_01b' },
    tomato_slice  = { label = "Tranche de tomate",   weight = 0.05, category = 'prepared', props = 'prop_cs_bowl_01b' },
    onion_slice   = { label = "Tranche d'oignon",    weight = 0.04, category = 'prepared', props = 'prop_cs_bowl_01b' },
    potato_cut    = { label = "Frites crues",        weight = 0.06, category = 'prepared', props = 'prop_food_bs_chips' },
    falafel_mix   = { label = "Pâte à falafel",      weight = 0.14, category = 'prepared', props = 'prop_cs_bowl_01b' },
    -- Montée à la station 'spit_build' (spit_mount), transportée jusqu'à la
    -- station 'spit' pour y être découpée (spit_cut, 10 utilisations) — même
    -- mécanisme que les pots de sauce (unique + data.uses).
    kebab_spit    = { label = "Broche montée",       weight = 3.0,  category = 'prepared', props = 'prop_cs_steak', unique = true },

    -- ── Cuissons ─────────────────────────────────────────────────────────
    kebab_meat_cooked   = { label = "Viande de veau cuite",     weight = 0.16, category = 'cooked', props = 'prop_cs_steak' },
    falafel_cooked      = { label = "Boulettes de falafel",     weight = 0.12, category = 'side', props = 'prop_food_bs_chips',
                                perishable = true, needs = { hunger = 20, anim = 'eating', portion = 18 } },
    bulgur              = { label = "Boulgour",         weight = 0.20, category = 'side',   props = 'prop_cs_bowl_01b',
                                perishable = true, needs = { hunger = 20, anim = 'eating', portion = 22 } },
    -- Burger Shot ne fait plus de frites (remplacées par les potatoes,
    -- voir ls_burgershot/config/items.lua) : fries reste défini ici, seul
    -- restaurant qui le fabrique encore (fry_fries).
    fries               = { label = "Frites",           weight = 0.16, category = 'side',   props = 'prop_food_bs_chips',
                                perishable = true, needs = { hunger = 20, anim = 'eating', portion = 20 } },

    -- ── Pots de sauce (20 utilisations, 1 sauce dispensée par usage) ───────
    pot_ketchup  = { label = "Pot de ketchup",         weight = 1.5, category = 'sauce_pot', props = 'prop_cs_bowl_01b', unique = true },
    pot_mayo     = { label = "Pot de mayonnaise",      weight = 1.5, category = 'sauce_pot', props = 'prop_cs_bowl_01b', unique = true },
    pot_bbq      = { label = "Pot de sauce barbecue",  weight = 1.5, category = 'sauce_pot', props = 'prop_cs_bowl_01b', unique = true },
    pot_harissa  = { label = "Pot de harissa",         weight = 1.5, category = 'sauce_pot', props = 'prop_cs_bowl_01b', unique = true },
    pot_white    = { label = "Pot de sauce blanche",   weight = 1.5, category = 'sauce_pot', props = 'prop_cs_bowl_01b', unique = true },
    pot_samurai  = { label = "Pot de sauce samouraï",  weight = 1.5, category = 'sauce_pot', props = 'prop_cs_bowl_01b', unique = true },
    pot_algerian = { label = "Pot de sauce algérienne",weight = 1.5, category = 'sauce_pot', props = 'prop_cs_bowl_01b', unique = true },
    pot_cheese   = { label = "Pot de sauce fromagère", weight = 1.5, category = 'sauce_pot', props = 'prop_cs_bowl_01b', unique = true },

    -- ── Sauces dispensées ────────────────────────────────────────────────
    sauce_mayo      = { label = "Mayonnaise",      weight = 0.06, category = 'sauce', props = 'prop_cs_bowl_01b' },
    sauce_ketchup   = { label = "Ketchup",         weight = 0.06, category = 'sauce', props = 'prop_cs_bowl_01b' },
    sauce_white     = { label = "Sauce blanche",   weight = 0.06, category = 'sauce', props = 'prop_cs_bowl_01b' },
    sauce_samurai   = { label = "Sauce samouraï",  weight = 0.06, category = 'sauce', props = 'prop_cs_bowl_01b' },
    sauce_algerian  = { label = "Sauce algérienne",weight = 0.06, category = 'sauce', props = 'prop_cs_bowl_01b' },
    sauce_harissa   = { label = "Harissa",         weight = 0.06, category = 'sauce', props = 'prop_cs_bowl_01b' },
    sauce_bbq       = { label = "Sauce barbecue",  weight = 0.06, category = 'sauce', props = 'prop_cs_bowl_01b' },
    cheese_sauce    = { label = "Sauce fromagère", weight = 0.10, category = 'sauce', props = 'prop_cs_bowl_01b' },

    -- ── Plats ────────────────────────────────────────────────────────────
    kebab            = { label = "Kebab classique",  weight = 0.45, category = 'meal', props = 'prop_cs_burger_01',
                            perishable = true, needs = { hunger = 90, anim = 'eating', portion = 28 } },
    kebab_galette    = { label = "Galette kebab",    weight = 0.42, category = 'meal', props = 'prop_taco_01',
                            perishable = true, needs = { hunger = 90, anim = 'eating', portion = 27 } },
    tacos_1meat      = { label = "Tacos une viande", weight = 0.48, category = 'meal', props = 'prop_taco_01',
                            perishable = true, needs = { hunger = 90, anim = 'eating', portion = 30 } },
    tacos_2meat      = { label = "Tacos deux viandes", weight = 0.58, category = 'meal', props = 'prop_taco_01',
                            perishable = true, needs = { hunger = 90, anim = 'eating', portion = 34 } },
    kebab_plate      = { label = "Assiette Kebab",   weight = 0.50, category = 'meal', props = 'prop_cs_bowl_01b',
                            perishable = true, needs = { hunger = 85, anim = 'eating', portion = 30 } },
    falafel_sandwich = { label = "Sandwich falafel", weight = 0.40, category = 'meal', props = 'prop_cs_burger_01',
                            perishable = true, needs = { hunger = 80, anim = 'eating', portion = 26 } },
    americain        = { label = "L'Americain",      weight = 0.55, category = 'meal', props = 'prop_cs_burger_01',
                            perishable = true, needs = { hunger = 90, anim = 'eating', portion = 32 } },
}
