-- ls_aldentes — Items propres à Aldente's.
--
-- Poussés dans le registre du framework au démarrage
-- (exports['lslegacy']:registerItems), retirés si la ressource s'arrête.
-- Le nom technique est aussi le nom de l'image : images/<nom>.png
-- Plus aucun item n'est préfixé : les trois restos partagent le même
-- registre Config.Items depuis leur fusion dans lslegacy, chaque item n'est
-- défini que dans UN SEUL des trois items.lua, les deux autres se contentant
-- d'y faire référence dans leurs recettes.

ALDConfig.Items = {
    -- ── Épicerie / réserve ───────────────────────────────────────────────
    -- flour/cream/herbs : voir ls_kebabking/config/items.lua (item partagé).
    egg              = { label = "Œuf",                 weight = 0.06, category = 'ingredient', props = 'prop_egg_01' },
    butter           = { label = "Beurre",              weight = 0.12, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    sugar            = { label = "Sucre",               weight = 0.15, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    vanilla          = { label = "Vanille",             weight = 0.03, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    olive_oil        = { label = "Huile d'olive",       weight = 0.25, category = 'ingredient', props = 'prop_ld_flow_bottle' },

    spaghetti_raw   = { label = "Spaghetti crus",   weight = 0.20, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    penne_raw       = { label = "Penne crus",       weight = 0.20, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    tagliatelle_raw = { label = "Tagliatelles crues", weight = 0.20, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    lasagne_raw     = { label = "Feuilles de lasagne crues", weight = 0.22, category = 'ingredient', props = 'prop_cs_bowl_01b' },

    garlic           = { label = "Ail",                 weight = 0.05, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    -- basil retiré : remplacé par 'herbs' (grossiste) dans prep_basil
    spinach          = { label = "Épinards",            weight = 0.12, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    mushroom         = { label = "Champignons",         weight = 0.12, category = 'ingredient', props = 'prop_veg_crop_03_pump' },

    parmesan_block   = { label = "Meule de parmesan",   weight = 0.40, category = 'ingredient', props = 'prop_cs_burger_01' },
    mozzarella       = { label = "Mozzarella",          weight = 0.15, category = 'ingredient', props = 'prop_cs_burger_01' },
    gorgonzola       = { label = "Gorgonzola",          weight = 0.15, category = 'ingredient', props = 'prop_cs_burger_01' },
    goat_cheese      = { label = "Chèvre",              weight = 0.14, category = 'ingredient', props = 'prop_cs_burger_01' },
    ricotta          = { label = "Ricotta",             weight = 0.16, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    mascarpone       = { label = "Mascarpone",          weight = 0.18, category = 'ingredient', props = 'prop_cs_bowl_01b' },

    guanciale        = { label = "Guanciale",           weight = 0.18, category = 'ingredient', props = 'prop_cs_steak' },
    ground_beef      = { label = "Viande hachée",       weight = 0.25, category = 'ingredient', props = 'prop_cs_steak' },
    ham              = { label = "Jambon",              weight = 0.15, category = 'ingredient', props = 'prop_cs_steak' },
    pepperoni        = { label = "Pepperoni",           weight = 0.14, category = 'ingredient', props = 'prop_cs_steak' },

    pot_empty        = { label = "Casserole vide",      weight = 0.80, category = 'ingredient', props = 'prop_cs_pot_01' },
    pot_water        = { label = "Casserole d'eau",     weight = 1.60, category = 'ingredient', props = 'prop_cs_pot_01' },

    ladyfingers      = { label = "Biscuits à la cuillère", weight = 0.12, category = 'ingredient', props = 'prop_choc_ego' },
    cannoli_shell    = { label = "Tube à cannoli",      weight = 0.08, category = 'ingredient', props = 'prop_choc_ego' },
    coffee_beans     = { label = "Café en grains",      weight = 0.20, category = 'ingredient', props = 'prop_cs_bowl_01b' },

    glass            = { label = "Verre vide",          weight = 0.02, category = 'ingredient', props = 'prop_wine_glass' },

    -- ── Produits préparés ────────────────────────────────────────────────
    onion_chopped    = { label = "Oignon émincé",     weight = 0.09, category = 'prepared', props = 'prop_cs_bowl_01b' },
    garlic_chopped   = { label = "Ail haché",         weight = 0.04, category = 'prepared', props = 'prop_cs_bowl_01b' },
    basil_chopped    = { label = "Basilic ciselé",    weight = 0.03, category = 'prepared', props = 'prop_cs_bowl_01b' },
    tomato_diced     = { label = "Tomates concassées",weight = 0.11, category = 'prepared', props = 'prop_cs_bowl_01b' },
    guanciale_diced  = { label = "Guanciale taillé",  weight = 0.16, category = 'prepared', props = 'prop_cs_bowl_01b' },
    parmesan         = { label = "Parmesan râpé",     weight = 0.06, category = 'prepared', props = 'prop_cs_bowl_01b' },
    pizza_dough      = { label = "Pâton à pizza",     weight = 0.25, category = 'prepared', props = 'prop_cs_burger_01' },
    pizza_base       = { label = "Pâte à pizza étalée",weight = 0.24, category = 'prepared', props = 'prop_pizza_box_01' },
    beef_cooked      = { label = "Viande hachée revenue", weight = 0.22, category = 'prepared', props = 'prop_cs_steak' },
    spinach_cooked   = { label = "Épinards fondus",   weight = 0.10, category = 'prepared', props = 'prop_cs_bowl_01b' },
    bechamel         = { label = "Béchamel",          weight = 0.20, category = 'prepared', props = 'prop_cs_bowl_01b' },

    -- ── Pâtes cuites ─────────────────────────────────────────────────────
    spaghetti_cooked   = { label = "Spaghetti cuits",     weight = 0.24, category = 'cooked', props = 'prop_cs_bowl_01b' },
    penne_cooked       = { label = "Penne cuits",         weight = 0.24, category = 'cooked', props = 'prop_cs_bowl_01b' },
    tagliatelle_cooked = { label = "Tagliatelles cuites", weight = 0.24, category = 'cooked', props = 'prop_cs_bowl_01b' },
    lasagne_cooked     = { label = "Feuilles de lasagne cuites", weight = 0.26, category = 'cooked', props = 'prop_cs_bowl_01b' },

    -- ── Sauces ───────────────────────────────────────────────────────────
    tomato_sauce     = { label = "Sauce tomate",      weight = 0.20, category = 'sauce', props = 'prop_cs_bowl_01b' },
    sauce_bolognese  = { label = "Sauce bolognaise",  weight = 0.24, category = 'sauce', props = 'prop_cs_bowl_01b' },
    sauce_carbonara  = { label = "Sauce carbonara",   weight = 0.22, category = 'sauce', props = 'prop_cs_bowl_01b' },
    sauce_pesto      = { label = "Pesto",             weight = 0.18, category = 'sauce', props = 'prop_cs_bowl_01b' },
    sauce_alfredo    = { label = "Sauce Alfredo",     weight = 0.22, category = 'sauce', props = 'prop_cs_bowl_01b' },

    -- ── Crus prêts à enfourner ───────────────────────────────────────────
    pizza_margherita_raw      = { label = "Margherita crue",       weight = 0.45, category = 'raw', props = 'prop_pizza_box_01' },
    pizza_regina_raw          = { label = "Regina crue",           weight = 0.50, category = 'raw', props = 'prop_pizza_box_01' },
    pizza_pepperoni_raw       = { label = "Pepperoni crue",        weight = 0.50, category = 'raw', props = 'prop_pizza_box_01' },
    pizza_quattro_formaggi_raw= { label = "Quattro Formaggi crue", weight = 0.52, category = 'raw', props = 'prop_pizza_box_01' },
    calzone_raw               = { label = "Calzone cru",           weight = 0.50, category = 'raw', props = 'prop_pizza_box_01' },
    lasagne_bolognese_raw     = { label = "Lasagnes bolognaise crues", weight = 0.60, category = 'raw', props = 'prop_cs_bowl_01b' },
    lasagne_chep_raw          = { label = "Lasagne chèvre-épinard crue", weight = 0.58, category = 'raw', props = 'prop_cs_bowl_01b' },

    -- ── Plats ────────────────────────────────────────────────────────────
    spaghetti_carbonara = { label = "Spaghetti Carbonara", weight = 0.45, category = 'meal', props = 'prop_cs_bowl_01b',
                            perishable = true, needs = { hunger = 90, anim = 'eating', portion = 28 } },
    spaghetti_bolognese = { label = "Spaghetti Bolognaise", weight = 0.46, category = 'meal', props = 'prop_cs_bowl_01b',
                            perishable = true, needs = { hunger = 90, anim = 'eating', portion = 28 } },
    penne_pesto         = { label = "Penne au Pesto",      weight = 0.42, category = 'meal', props = 'prop_cs_bowl_01b',
                            perishable = true, needs = { hunger = 90, anim = 'eating', portion = 26 } },
    tagliatelle_alfredo = { label = "Tagliatelles Alfredo", weight = 0.44, category = 'meal', props = 'prop_cs_bowl_01b',
                            perishable = true, needs = { hunger = 90, anim = 'eating', portion = 26 } },
    lasagne_bolognese   = { label = "Lasagnes Bolognaise", weight = 0.55, category = 'meal', props = 'prop_cs_bowl_01b',
                            perishable = true, needs = { hunger = 90, anim = 'eating', portion = 32 } },
    lasagne_chep        = { label = "Lasagne chèvre-épinard", weight = 0.53, category = 'meal', props = 'prop_cs_bowl_01b',
                            perishable = true, needs = { hunger = 90, anim = 'eating', portion = 32 } },

    pizza_margherita       = { label = "Pizza Margherita",       weight = 0.42, category = 'meal', props = 'prop_pizza_box_01',
                               perishable = true, needs = { hunger = 90, anim = 'eating', portion = 30 } },
    pizza_regina           = { label = "Pizza Regina",           weight = 0.46, category = 'meal', props = 'prop_pizza_box_01',
                               perishable = true, needs = { hunger = 90, anim = 'eating', portion = 30 } },
    pizza_pepperoni        = { label = "Pizza Pepperoni",        weight = 0.46, category = 'meal', props = 'prop_pizza_box_01',
                               perishable = true, needs = { hunger = 90, anim = 'eating', portion = 30 } },
    pizza_quattro_formaggi = { label = "Pizza Quattro Formaggi", weight = 0.48, category = 'meal', props = 'prop_pizza_box_01',
                               perishable = true, needs = { hunger = 90, anim = 'eating', portion = 30 } },
    calzone                = { label = "Calzone",                weight = 0.46, category = 'meal', props = 'prop_pizza_box_01',
                               perishable = true, needs = { hunger = 90, anim = 'eating', portion = 30 } },

    -- ── Desserts ─────────────────────────────────────────────────────────
    tiramisu    = { label = "Tiramisu",    weight = 0.26, category = 'dessert', props = 'prop_cs_bowl_01b',
                    perishable = true, needs = { hunger = 20, anim = 'eating', portion = 20 } },
    panna_cotta = { label = "Panna Cotta", weight = 0.24, category = 'dessert', props = 'prop_cs_bowl_01b',
                    perishable = true, needs = { hunger = 20, anim = 'eating', portion = 20 } },
    cannoli     = { label = "Cannoli",     weight = 0.16, category = 'dessert', props = 'prop_choc_ego',
                    perishable = true, needs = { hunger = 20, anim = 'eating', portion = 16 } },

    -- ── Boissons ─────────────────────────────────────────────────────────
    -- water/cola/sprunk/otang : voir ls_burgershot/config/items.lua (item
    -- partagé, sans préfixe — les recettes ci-dessous y font juste référence).
    coffee = { label = "Café",    weight = 0.20, category = 'drink', props = 'p_ing_coffeecup_01',
               needs = { thirst = 70, stamina = 25, anim = 'drinking', portion = 12 } },
}
