-- ls_burgershot — Recettes.
--
-- Le client n'envoie JAMAIS l'item ni la quantité à produire : il envoie
-- seulement un `recipeId` et un `stationId`. Le serveur relit la recette
-- ici, revérifie la station, la distance, le job, le service, les
-- ingrédients, puis retire et donne lui-même.
--
-- Champs :
--   label       : nom affiché dans le menu
--   station     : station où la recette est disponible (clé de BSConfig.Stations)
--   ingredients : { { item = ..., count = ... }, ... }
--   results     : { { item = ..., count = ... }, ... }
--   duration    : durée de la progressbar en ms (imposée aussi côté serveur)
--   anim        : clé de BSConfig.Anims
--   minGrade    : grade minimum (facultatif)

BSConfig.Recipes = {
    -- ── Préparation ──────────────────────────────────────────────────────
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
    prep_bacon = {
        label = "Trancher le bacon", station = 'prep', anim = 'cut', duration = 4500,
        ingredients = { { item = 'bacon_raw', count = 1 } },
        results     = { { item = 'bacon_strips', count = 2 } },
    },
    prep_potato = {
        label = "Tailler des morceaux de patate", station = 'prep', anim = 'cut', duration = 5000,
        ingredients = { { item = 'potato', count = 1 } },
        results     = { { item = 'potato_chunks', count = 10 } },
    },

    -- ── Grill ────────────────────────────────────────────────────────────
    grill_patty = {
        label = "Griller un steak", station = 'grill', anim = 'grill', duration = 7000,
        ingredients = { { item = 'patty_raw', count = 1 } },
        results     = { { item = 'patty_cooked', count = 1 } },
    },
    grill_chicken = {
        label = "Griller un filet de poulet", station = 'grill', anim = 'grill', duration = 8000,
        ingredients = { { item = 'chicken_raw', count = 1 } },
        results     = { { item = 'chicken_cooked', count = 1 } },
    },
    grill_bacon = {
        label = "Griller du bacon", station = 'grill', anim = 'grill', duration = 6000,
        ingredients = { { item = 'bacon_strips', count = 1 } },
        results     = { { item = 'bacon_cooked', count = 1 } },
    },

    -- ── Friteuse ─────────────────────────────────────────────────────────
    fry_potatoes = {
        label = "Cuire des potatoes", station = 'fryer', anim = 'fry', duration = 9000,
        ingredients = { { item = 'potato_chunks', count = 10 } },
        results     = { { item = 'potatoes', count = 1 } },
    },
    fry_onion_rings = {
        label = "Cuire des onion rings", station = 'fryer', anim = 'fry', duration = 6500,
        ingredients = { { item = 'onion_slice', count = 1 } },
        results     = { { item = 'onion_rings', count = 1 } },
    },
    fry_nuggets = {
        label = "Cuire des nuggets", station = 'fryer', anim = 'fry', duration = 6500,
        ingredients = { { item = 'nugget_raw', count = 5 } },
        results     = { { item = 'nuggets', count = 1 } },
    },

    prep_sauce_burger = {
        label = "Préparer la sauce burger", station = 'prep', anim = 'cut', duration = 4000,
        ingredients = {
            { item = 'sauce_mayo', count = 5 }, { item = 'sauce_ketchup', count = 3 },
            { item = 'pickle', count = 3 }, { item = 'onion', count = 1 }, { item = 'spices', count = 1 },
        },
        results = { { item = 'sauce_burger', count = 5 } },
    },

    -- ── Assemblage ───────────────────────────────────────────────────────
    burger_hamburger = {
        label = "Hamburger", station = 'assembly', anim = 'assemble', duration = 5000,
        ingredients = {
            { item = 'bun', count = 1 }, { item = 'patty_cooked', count = 1 },
            { item = 'salad_cut', count = 1 }, { item = 'tomato_slice', count = 1 },
            { item = 'sauce_burger', count = 1 },
        },
        results = { { item = 'hamburger', count = 1 } },
    },
    burger_cheeseburger = {
        label = "Cheeseburger", station = 'assembly', anim = 'assemble', duration = 5000,
        ingredients = {
            { item = 'bun', count = 1 }, { item = 'patty_cooked', count = 1 },
            { item = 'cheese', count = 1 }, { item = 'salad_cut', count = 1 },
            { item = 'sauce_burger', count = 1 },
        },
        results = { { item = 'cheeseburger', count = 1 } },
    },
    burger_double_cheese = {
        label = "Double Cheese", station = 'assembly', anim = 'assemble', duration = 6500,
        ingredients = {
            { item = 'bun', count = 1 }, { item = 'patty_cooked', count = 2 },
            { item = 'cheese', count = 2 }, { item = 'onion_slice', count = 1 },
            { item = 'sauce_burger', count = 1 },
        },
        results = { { item = 'double_cheese', count = 1 } },
    },
    burger_bacon = {
        label = "Bacon Burger", station = 'assembly', anim = 'assemble', duration = 6000,
        ingredients = {
            { item = 'bun', count = 1 }, { item = 'patty_cooked', count = 1 },
            { item = 'bacon_cooked', count = 2 }, { item = 'cheese', count = 1 },
            { item = 'sauce_burger', count = 1 },
        },
        results = { { item = 'bacon_burger', count = 1 } },
    },
    burger_chicken = {
        label = "Chicken Burger", station = 'assembly', anim = 'assemble', duration = 6000,
        ingredients = {
            { item = 'bun', count = 1 }, { item = 'chicken_cooked', count = 1 },
            { item = 'salad_cut', count = 1 }, { item = 'tomato_slice', count = 1 },
            { item = 'sauce_burger', count = 1 },
        },
        results = { { item = 'chicken_burger', count = 1 } },
    },

    -- ── Desserts ─────────────────────────────────────────────────────────
    dessert_sundae = {
        label = "Sundae", station = 'assembly', anim = 'dessert', duration = 4000,
        ingredients = {
            { item = 'cup', count = 1 }, { item = 'ice_cream', count = 1 },
            { item = 'syrup_choco', count = 1 },
        },
        results = { { item = 'sundae', count = 1 } },
    },
    dessert_cookie = {
        label = "Cookie", station = 'assembly', anim = 'dessert', duration = 4500,
        ingredients = { { item = 'cookie_dough', count = 1 } },
        results     = { { item = 'cookie', count = 5 } },
    },
}
