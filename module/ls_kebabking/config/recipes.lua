-- ls_kebabking — Recettes.
--
-- Le client n'envoie que stationId + recipeId (+ éventuellement le choix de
-- sauce, validé contre la liste blanche de la recette). Tout le reste est
-- relu ici côté serveur.
--
-- Champ supplémentaire par rapport aux deux autres restaurants :
--   options.sauce = { choices = { item, ... }, count = n }
-- Le joueur choisit sa sauce pendant l'assemblage ; elle est consommée en
-- plus des ingrédients et son nom est ajouté au libellé du plat.
--
-- Un résultat peut aussi porter `data = { uses = n }` (pots de sauce) :
-- server/craft.lua clone cette table à chaque fabrication (jamais la table
-- de la recette elle-même) pour que chaque pot ait son propre compteur.

KKConfig.Recipes = {
    -- ── Point d'eau ──────────────────────────────────────────────────────
    fill_water_glass = {
        label = "Remplir un verre d'eau", station = 'water', anim = 'drink', duration = 2000,
        ingredients = {},
        results     = { { item = 'water_glass', count = 1 } },
    },

    -- ── Préparation des légumes et des pains ────────────────────────────
    prep_salad = {
        label = "Émincer de la salade", station = 'prep', anim = 'cut', duration = 4000,
        ingredients = { { item = 'salad', count = 1 } },
        results     = { { item = 'salad_cut', count = 5 } },
    },
    prep_tomato = {
        label = "Couper des tomates", station = 'prep', anim = 'cut', duration = 4000,
        ingredients = { { item = 'tomato', count = 1 } },
        results     = { { item = 'tomato_slice', count = 6 } },
    },
    prep_onion = {
        label = "Émincer des oignons", station = 'prep', anim = 'cut', duration = 4000,
        ingredients = { { item = 'onion', count = 1 } },
        results     = { { item = 'onion_slice', count = 8 } },
    },
    prep_potato = {
        label = "Tailler des frites", station = 'prep', anim = 'cut', duration = 5000,
        ingredients = { { item = 'potato', count = 1 } },
        results     = { { item = 'potato_cut', count = 10 } },
    },
    prep_pita = {
        label = "Pain pita", station = 'prep', anim = 'cut', duration = 9000,
        ingredients = {
            { item = 'water_glass', count = 2 }, { item = 'flour', count = 3 },
            { item = 'salt', count = 1 },
        },
        results = { { item = 'bread_pita', count = 5 } },
    },
    prep_tortilla = {
        label = "Tortilla", station = 'prep', anim = 'cut', duration = 9000,
        ingredients = {
            { item = 'flour', count = 3 }, { item = 'salt', count = 1 },
            { item = 'milk', count = 1 },
        },
        results = { { item = 'tortilla', count = 5 } },
    },
    prep_falafel_mix = {
        -- Le falafel est une boulette de pois chiches (végétarien), pas de
        -- viande : pâte crue préparée ici, frite ensuite (voir fry_falafel).
        label = "Pâte à falafel", station = 'prep', anim = 'cut', duration = 7000,
        ingredients = {
            { item = 'chickpea', count = 8 }, { item = 'herbs', count = 2 },
            { item = 'spices', count = 2 },
        },
        results = { { item = 'falafel_mix', count = 5 } },
    },

    -- ── Broche ───────────────────────────────────────────────────────────
    -- Trois temps sur deux stations : on monte la broche à 'spit_build'
    -- (item transportable kebab_spit, comme un pot de sauce) ; on la POSE
    -- sur le tournebroche à 'spit' (spit_place — retire l'item de
    -- l'inventaire, la broche devient un état partagé de la station) ;
    -- n'importe quel employé EN SERVICE peut ensuite venir la couper
    -- (spit_cut, répétable) sans rien avoir sur lui. Les trois sont des cas
    -- spéciaux (voir server/craft.lua, KK.Spit) : ni l'un ni l'autre ne suit
    -- exactement la transaction ingrédients->résultats générique.
    spit_mount = {
        label = "Monter la broche (10 utilisations)", station = 'spit_build', anim = 'spit', duration = 20000,
        ingredients = { { item = 'kebab_meat_raw', count = 20 }, { item = 'spices', count = 5 } },
        results     = { { item = 'kebab_spit', count = 1, data = { uses = 10 } } },
    },
    spit_place = {
        label = "Poser la broche sur le tournebroche", station = 'spit', anim = 'spit', duration = 4000,
        ingredients = { { item = 'kebab_spit', count = 1 } },
        results     = {},
    },
    spit_cut = {
        label = "Couper de la viande", station = 'spit', anim = 'spit', duration = 3000,
        ingredients = {},
        results     = { { item = 'kebab_meat_cooked', count = 2 } },
    },

    -- ── Grill / plaque ───────────────────────────────────────────────────
    grill_patty = {
        label = "Griller un steak haché", station = 'grill', anim = 'grill', duration = 6000,
        ingredients = { { item = 'patty_raw', count = 1 } },
        results     = { { item = 'patty_cooked', count = 1 } },
    },
    grill_bulgur = {
        label = "Cuire du boulgour", station = 'grill', anim = 'grill', duration = 7000,
        ingredients = { { item = 'water_glass', count = 5 }, { item = 'wheat', count = 2 } },
        results     = { { item = 'bulgur', count = 5 } },
    },

    -- ── Friteuse ─────────────────────────────────────────────────────────
    fry_fries = {
        label = "Cuire des frites", station = 'fryer', anim = 'fry', duration = 9000,
        ingredients = { { item = 'potato_cut', count = 10 } },
        results     = { { item = 'fries', count = 1 } },
    },
    fry_falafel = {
        label = "Frire des boulettes de falafel", station = 'fryer', anim = 'fry', duration = 8000,
        ingredients = { { item = 'falafel_mix', count = 1 } },
        results     = { { item = 'falafel_cooked', count = 1 } },
    },

    -- ── Préparation des pots de sauce (20 utilisations chacun) ──────────
    sauce_ketchup = {
        label = "Pot de ketchup", station = 'sauces', anim = 'sauce', duration = 5000,
        ingredients = {
            { item = 'tomato', count = 10 }, { item = 'sugar', count = 2 },
            { item = 'vinegar', count = 1 }, { item = 'salt', count = 1 },
        },
        results = { { item = 'pot_ketchup', count = 1, data = { uses = KKConfig.PotUses } } },
    },
    sauce_mayo = {
        label = "Pot de mayonnaise", station = 'sauces', anim = 'sauce', duration = 5000,
        ingredients = {
            { item = 'egg', count = 3 }, { item = 'olive_oil', count = 5 },
            { item = 'vinegar', count = 1 }, { item = 'salt', count = 1 },
        },
        results = { { item = 'pot_mayo', count = 1, data = { uses = KKConfig.PotUses } } },
    },
    sauce_bbq = {
        label = "Pot de sauce barbecue", station = 'sauces', anim = 'sauce', duration = 6000,
        ingredients = {
            { item = 'sauce_ketchup', count = 5 }, { item = 'honey', count = 2 },
            { item = 'vinegar', count = 1 }, { item = 'spices', count = 2 },
        },
        results = { { item = 'pot_bbq', count = 1, data = { uses = KKConfig.PotUses } } },
    },
    sauce_harissa = {
        label = "Pot de harissa", station = 'sauces', anim = 'sauce', duration = 6000,
        ingredients = {
            { item = 'harissa_pepper', count = 5 }, { item = 'tomato', count = 2 },
            { item = 'garlic', count = 2 }, { item = 'olive_oil', count = 2 },
            { item = 'spices', count = 1 },
        },
        results = { { item = 'pot_harissa', count = 1, data = { uses = KKConfig.PotUses } } },
    },
    sauce_white = {
        label = "Pot de sauce blanche", station = 'sauces', anim = 'sauce', duration = 6000,
        ingredients = {
            { item = 'sauce_mayo', count = 5 }, { item = 'yogurt', count = 5 },
            { item = 'garlic', count = 2 }, { item = 'herbs', count = 1 },
        },
        results = { { item = 'pot_white', count = 1, data = { uses = KKConfig.PotUses } } },
    },
    sauce_samurai = {
        label = "Pot de sauce samouraï", station = 'sauces', anim = 'sauce', duration = 6000,
        ingredients = {
            { item = 'sauce_mayo', count = 5 }, { item = 'sauce_harissa', count = 3 },
            { item = 'harissa_pepper', count = 1 },
        },
        results = { { item = 'pot_samurai', count = 1, data = { uses = KKConfig.PotUses } } },
    },
    sauce_algerian = {
        label = "Pot de sauce algérienne", station = 'sauces', anim = 'sauce', duration = 6000,
        ingredients = {
            { item = 'sauce_mayo', count = 5 }, { item = 'tomato', count = 2 },
            { item = 'onion', count = 2 }, { item = 'harissa_pepper', count = 2 },
            { item = 'spices', count = 1 },
        },
        results = { { item = 'pot_algerian', count = 1, data = { uses = KKConfig.PotUses } } },
    },
    sauce_cheese = {
        label = "Pot de sauce fromagère", station = 'sauces', anim = 'sauce', duration = 6000,
        ingredients = {
            { item = 'cheese', count = 5 }, { item = 'cream', count = 3 },
            { item = 'milk', count = 2 }, { item = 'salt', count = 1 },
        },
        results = { { item = 'pot_cheese', count = 1, data = { uses = KKConfig.PotUses } } },
    },

    -- ── Assemblage (avec choix de sauce le cas échéant) ──────────────────
    build_kebab = {
        label = "Kebab classique", station = 'assembly', anim = 'assemble', duration = 6000,
        ingredients = {
            { item = 'bread_pita', count = 1 }, { item = 'kebab_meat_cooked', count = 2 },
            { item = 'salad_cut', count = 1 }, { item = 'tomato_slice', count = 2 },
            { item = 'onion_slice', count = 2 },
        },
        options = { sauce = { count = 1 } },
        results = { { item = 'kebab', count = 1 } },
    },
    build_kebab_galette = {
        label = "Galette kebab", station = 'assembly', anim = 'assemble', duration = 6000,
        ingredients = {
            { item = 'tortilla', count = 1 }, { item = 'kebab_meat_cooked', count = 2 },
            { item = 'salad_cut', count = 1 }, { item = 'tomato_slice', count = 2 },
            { item = 'onion_slice', count = 2 },
        },
        options = { sauce = { count = 1 } },
        results = { { item = 'kebab_galette', count = 1 } },
    },
    build_tacos_1meat = {
        label = "Tacos une viande", station = 'assembly', anim = 'assemble', duration = 7000,
        ingredients = {
            { item = 'tortilla', count = 1 }, { item = 'kebab_meat_cooked', count = 2 },
            { item = 'cheese', count = 1 }, { item = 'fries', count = 1 },
        },
        options = { sauce = { count = 1 } },
        results = { { item = 'tacos_1meat', count = 1 } },
    },
    build_kebab_plate = {
        label = "Assiette Kebab", station = 'assembly', anim = 'assemble', duration = 6000,
        ingredients = {
            { item = 'kebab_meat_cooked', count = 2 }, { item = 'salad_cut', count = 1 },
            { item = 'tomato_slice', count = 2 }, { item = 'onion_slice', count = 2 },
            { item = 'bulgur', count = 1 },
        },
        results = { { item = 'kebab_plate', count = 1 } },
    },
    build_falafel_sandwich = {
        label = "Sandwich falafel", station = 'assembly', anim = 'assemble', duration = 6000,
        ingredients = {
            { item = 'bread_pita', count = 1 }, { item = 'falafel_cooked', count = 2 },
            { item = 'salad_cut', count = 1 }, { item = 'tomato_slice', count = 2 },
            { item = 'onion_slice', count = 2 },
        },
        results = { { item = 'falafel_sandwich', count = 1 } },
    },
    build_americain = {
        label = "L'Americain", station = 'assembly', anim = 'assemble', duration = 7000,
        ingredients = {
            { item = 'bread_pita', count = 1 }, { item = 'patty_cooked', count = 2 },
            { item = 'salad_cut', count = 1 }, { item = 'tomato_slice', count = 2 },
            { item = 'onion_slice', count = 2 }, { item = 'fries', count = 1 },
            { item = 'cheese', count = 2 },
        },
        results = { { item = 'americain', count = 1 } },
    },
}
