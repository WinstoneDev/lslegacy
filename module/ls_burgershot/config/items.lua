-- ls_burgershot — Items propres au Burger Shot.
--
-- Ils sont poussés dans le registre du framework au démarrage
-- (exports['lslegacy']:registerItems), et retirés si la ressource s'arrête.
--
-- Champs :
--   label      : nom affiché dans l'inventaire
--   weight     : poids en kg
--   props      : modèle GTA tenu en main lors de la consommation (module/needs)
--   category   : purement informatif (README / tri)
--   needs      : rend l'item consommable { hunger, thirst, stamina, anim, portion }
--   perishable : soumis à la péremption (5h hors chambre froide)
--
-- Le nom technique de l'item est aussi le nom de son image :
--   images/<nom>.png -> lslegacy/inventory/html/img/items/<nom>.png
-- Plus aucun item n'est préfixé : les trois restos partagent le même
-- registre Config.Items depuis leur fusion dans lslegacy, chaque item n'est
-- défini que dans UN SEUL des trois items.lua, les deux autres se contentant
-- d'y faire référence dans leurs recettes.

BSConfig.Items = {
    -- ── Ingrédients bruts ────────────────────────────────────────────────
    bun             = { label = "Pain à burger",      weight = 0.08, category = 'ingredient', props = 'prop_cs_burger_01' },
    patty_raw       = { label = "Steak haché cru",    weight = 0.15, category = 'ingredient', props = 'prop_cs_steak' },
    chicken_raw     = { label = "Filet de poulet cru",weight = 0.15, category = 'ingredient', props = 'prop_cs_steak' },
    bacon_raw       = { label = "Bacon cru",          weight = 0.10, category = 'ingredient', props = 'prop_cs_steak' },
    salad           = { label = "Salade",             weight = 0.12, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    tomato          = { label = "Tomate",             weight = 0.10, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    onion           = { label = "Oignon",             weight = 0.10, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    pickle          = { label = "Cornichons",         weight = 0.05, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    potato          = { label = "Pomme de terre",     weight = 0.20, category = 'ingredient', props = 'prop_veg_crop_03_pump' },
    nugget_raw      = { label = "Nuggets crus",       weight = 0.12, category = 'ingredient', props = 'prop_cs_steak' },
    sauce_burger    = { label = "Sauce burger",       weight = 0.04, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    cup             = { label = "Gobelet vide",       weight = 0.02, category = 'ingredient', props = 'prop_food_bs_juice01' },
    milk            = { label = "Lait",               weight = 0.30, category = 'ingredient', props = 'prop_ld_flow_bottle' },
    ice_cream       = { label = "Sundae",              weight = 0.20, category = 'ingredient', props = 'prop_cs_bowl_01b' },
    cookie_dough    = { label = "Pâte à cookie",      weight = 0.12, category = 'ingredient', props = 'prop_cs_burger_01' },

    -- ── Produits préparés (station Préparation) ──────────────────────────
    -- salad_cut/tomato_slice/onion_slice : voir ls_kebabking/config/items.lua
    -- (item partagé, sans préfixe — les recettes ci-dessous y font référence).
    -- potato_chunks est un item À PART de potato_cut (kebab king, coupe en
    -- frites) : Burger Shot en fait des potatoes, pas des frites.
    bacon_strips    = { label = "Bacon tranché",      weight = 0.09, category = 'prepared', props = 'prop_cs_steak' },
    potato_chunks   = { label = "Morceaux de patate", weight = 0.06, category = 'prepared', props = 'prop_food_bs_chips' },

    -- ── Cuissons (Grill / Friteuse) ──────────────────────────────────────
    -- fries est défini dans ls_kebabking/config/items.lua : Burger Shot ne
    -- fait plus de frites, seulement des potatoes (voir ci-dessous).
    patty_cooked    = { label = "Steak grillé",       weight = 0.13, category = 'cooked', props = 'prop_cs_steak' },
    chicken_cooked  = { label = "Poulet grillé",      weight = 0.13, category = 'cooked', props = 'prop_cs_steak' },
    bacon_cooked    = { label = "Bacon grillé",       weight = 0.07, category = 'cooked', props = 'prop_cs_steak' },
    potatoes        = { label = "Potatoes",           weight = 0.16, category = 'side',   props = 'prop_food_bs_chips',
                        perishable = true, needs = { hunger = 20, anim = 'eating', portion = 20 } },
    onion_rings     = { label = "Onion rings",        weight = 0.14, category = 'side',   props = 'prop_food_bs_chips',
                        perishable = true, needs = { hunger = 20, anim = 'eating', portion = 20 } },
    nuggets         = { label = "Nuggets",            weight = 0.14, category = 'side',   props = 'prop_food_bs_chips',
                        perishable = true, needs = { hunger = 20, anim = 'eating', portion = 20 } },

    -- ── Plats (Assemblage) ───────────────────────────────────────────────
    hamburger       = { label = "Hamburger",          weight = 0.28, category = 'meal', props = 'prop_cs_burger_01',
                        perishable = true, needs = { hunger = 90, anim = 'eating', portion = 25 } },
    cheeseburger    = { label = "Cheeseburger",       weight = 0.30, category = 'meal', props = 'prop_cs_burger_01',
                        perishable = true, needs = { hunger = 90, anim = 'eating', portion = 25 } },
    double_cheese   = { label = "Double Cheese",      weight = 0.42, category = 'meal', props = 'prop_cs_burger_01',
                        perishable = true, needs = { hunger = 90, anim = 'eating', portion = 30 } },
    bacon_burger    = { label = "Bacon Burger",       weight = 0.36, category = 'meal', props = 'prop_cs_burger_01',
                        perishable = true, needs = { hunger = 90, anim = 'eating', portion = 28 } },
    chicken_burger  = { label = "Chicken Burger",     weight = 0.34, category = 'meal', props = 'prop_cs_burger_01',
                        perishable = true, needs = { hunger = 90, anim = 'eating', portion = 28 } },

    -- ── Boissons ─────────────────────────────────────────────────────────
    -- Achetées puis revendues telles quelles (comme ls_kebabking) : aucune
    -- station ni recette de boisson dans ce restaurant.
    cola         = { label = "Cola",            weight = 0.33, category = 'drink', props = 'prop_food_bs_juice01',
                     needs = { thirst = 70, stamina = 10, anim = 'drinking', portion = 20 } },
    sprunk       = { label = "Sprunk",          weight = 0.33, category = 'drink', props = 'prop_food_bs_juice01',
                     needs = { thirst = 70, stamina = 10, anim = 'drinking', portion = 20 } },
    water        = { label = "Eau",             weight = 0.33, category = 'drink', props = 'prop_food_bs_juice01',
                     needs = { thirst = 70, anim = 'drinking', portion = 20 } },
    otang        = { label = "O'tang",          weight = 0.33, category = 'drink', props = 'prop_food_bs_juice01',
                     needs = { thirst = 70, stamina = 5, anim = 'drinking', portion = 20 } },
    milkshake_vanilla    = { label = "Milkshake vanille",  weight = 0.36, category = 'drink', props = 'prop_food_bs_juice01',
                             perishable = true, needs = { thirst = 50, hunger = 20, anim = 'drinking', portion = 20 } },
    milkshake_chocolate  = { label = "Milkshake chocolat", weight = 0.36, category = 'drink', props = 'prop_food_bs_juice01',
                             perishable = true, needs = { thirst = 50, hunger = 20, anim = 'drinking', portion = 20 } },
    milkshake_strawberry = { label = "Milkshake fraise",   weight = 0.36, category = 'drink', props = 'prop_food_bs_juice01',
                             perishable = true, needs = { thirst = 50, hunger = 20, anim = 'drinking', portion = 20 } },

    -- ── Desserts ─────────────────────────────────────────────────────────
    sundae    = { label = "Sundae",             weight = 0.25, category = 'dessert', props = 'prop_cs_bowl_01b',
                  perishable = true, needs = { hunger = 20, thirst = 10, anim = 'eating', portion = 20 } },
    cookie    = { label = "Cookie",             weight = 0.10, category = 'dessert', props = 'prop_choc_ego',
                  perishable = true, needs = { hunger = 20, anim = 'eating', portion = 15 } },
}
