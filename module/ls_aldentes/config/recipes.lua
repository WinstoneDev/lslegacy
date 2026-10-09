-- ls_aldentes — Recettes.
--
-- La cuisine d'Aldente's est volontairement la plus poussée des trois :
-- eau -> casserole -> pâtes cuites -> sauce préparée -> dressage, et
-- pizza/lasagnes montées crues puis enfournées. Il est impossible de
-- fabriquer un plat directement depuis des pâtes crues.
--
-- Le client n'envoie que stationId + recipeId ; le serveur relit tout ici.

ALDConfig.Recipes = {
    -- ── Point d'eau ──────────────────────────────────────────────────────
    water_fill_pot = {
        label = "Remplir une casserole", station = 'sink', anim = 'water', duration = 3500,
        ingredients = { { item = 'pot_empty', count = 1 } },
        results     = { { item = 'pot_water', count = 1 } },
    },

    -- ── Plan de préparation ──────────────────────────────────────────────
    prep_onion = {
        label = "Émincer un oignon", station = 'prep', anim = 'cut', duration = 4000,
        ingredients = { { item = 'onion', count = 1 } },
        results     = { { item = 'onion_chopped', count = 2 } },
    },
    prep_garlic = {
        label = "Hacher de l'ail", station = 'prep', anim = 'cut', duration = 3500,
        ingredients = { { item = 'garlic', count = 1 } },
        results     = { { item = 'garlic_chopped', count = 2 } },
    },
    prep_basil = {
        -- basilic remplacé par les herbes de cuisine génériques (voir grossiste, item 'herbs')
        label = "Ciseler des herbes de cuisine", station = 'prep', anim = 'cut', duration = 3500,
        ingredients = { { item = 'herbs', count = 1 } },
        results     = { { item = 'basil_chopped', count = 2 } },
    },
    prep_tomato = {
        label = "Concasser des tomates", station = 'prep', anim = 'cut', duration = 4500,
        ingredients = { { item = 'tomato', count = 2 } },
        results     = { { item = 'tomato_diced', count = 2 } },
    },
    prep_guanciale = {
        label = "Tailler le guanciale", station = 'prep', anim = 'cut', duration = 4500,
        ingredients = { { item = 'guanciale', count = 1 } },
        results     = { { item = 'guanciale_diced', count = 2 } },
    },
    prep_parmesan = {
        label = "Râper du parmesan", station = 'prep', anim = 'cut', duration = 4000,
        ingredients = { { item = 'parmesan_block', count = 1 } },
        results     = { { item = 'parmesan', count = 4 } },
    },
    prep_pizza_dough = {
        label = "Pétrir la pâte à pizza", station = 'prep', anim = 'knead', duration = 8000,
        ingredients = { { item = 'flour', count = 1 }, { item = 'olive_oil', count = 1 } },
        results     = { { item = 'pizza_dough', count = 3 } },
    },

    -- ── Cuisson des pâtes (toujours via une casserole d'eau) ─────────────
    pasta_spaghetti = {
        label = "Cuire des spaghetti", station = 'pasta', anim = 'boil', duration = 9000,
        ingredients = { { item = 'pot_water', count = 1 }, { item = 'spaghetti_raw', count = 1 } },
        results     = { { item = 'spaghetti_cooked', count = 1 }, { item = 'pot_empty', count = 1 } },
    },
    pasta_penne = {
        label = "Cuire des penne", station = 'pasta', anim = 'boil', duration = 9000,
        ingredients = { { item = 'pot_water', count = 1 }, { item = 'penne_raw', count = 1 } },
        results     = { { item = 'penne_cooked', count = 1 }, { item = 'pot_empty', count = 1 } },
    },
    pasta_tagliatelle = {
        label = "Cuire des tagliatelles", station = 'pasta', anim = 'boil', duration = 9000,
        ingredients = { { item = 'pot_water', count = 1 }, { item = 'tagliatelle_raw', count = 1 } },
        results     = { { item = 'tagliatelle_cooked', count = 1 }, { item = 'pot_empty', count = 1 } },
    },
    pasta_lasagne = {
        label = "Précuire des feuilles de lasagne", station = 'pasta', anim = 'boil', duration = 9000,
        ingredients = { { item = 'pot_water', count = 1 }, { item = 'lasagne_raw', count = 1 } },
        results     = { { item = 'lasagne_cooked', count = 1 }, { item = 'pot_empty', count = 1 } },
    },

    -- ── Plaques de cuisson ───────────────────────────────────────────────
    stove_beef = {
        label = "Faire revenir la viande hachée", station = 'stove', anim = 'stove', duration = 8000,
        ingredients = { { item = 'ground_beef', count = 1 }, { item = 'onion_chopped', count = 1 } },
        results     = { { item = 'beef_cooked', count = 1 } },
    },
    stove_spinach = {
        label = "Faire tomber les épinards", station = 'stove', anim = 'stove', duration = 6000,
        ingredients = { { item = 'spinach', count = 1 }, { item = 'butter', count = 1 } },
        results     = { { item = 'spinach_cooked', count = 2 } },
    },
    stove_bechamel = {
        label = "Monter une béchamel", station = 'stove', anim = 'stove', duration = 7000,
        ingredients = { { item = 'milk', count = 1 }, { item = 'flour', count = 1 }, { item = 'butter', count = 1 } },
        results     = { { item = 'bechamel', count = 2 } },
    },

    -- ── Préparation des sauces ───────────────────────────────────────────
    sauce_tomato = {
        label = "Sauce tomate", station = 'sauces', anim = 'sauce', duration = 8000,
        ingredients = {
            { item = 'tomato_diced', count = 2 }, { item = 'garlic_chopped', count = 1 },
            { item = 'olive_oil', count = 1 },
        },
        results = { { item = 'tomato_sauce', count = 2 } },
    },
    sauce_bolognese = {
        label = "Sauce bolognaise", station = 'sauces', anim = 'sauce', duration = 10000,
        ingredients = {
            { item = 'beef_cooked', count = 1 }, { item = 'tomato_sauce', count = 1 },
            { item = 'onion_chopped', count = 1 }, { item = 'herbs', count = 1 },
        },
        results = { { item = 'sauce_bolognese', count = 2 } },
    },
    sauce_carbonara = {
        label = "Sauce carbonara", station = 'sauces', anim = 'sauce', duration = 8000,
        ingredients = {
            { item = 'egg', count = 2 }, { item = 'guanciale_diced', count = 1 },
            { item = 'parmesan', count = 1 },
        },
        results = { { item = 'sauce_carbonara', count = 1 } },
    },
    sauce_pesto = {
        label = "Pesto", station = 'sauces', anim = 'sauce', duration = 7000,
        ingredients = {
            { item = 'basil_chopped', count = 2 }, { item = 'olive_oil', count = 1 },
            { item = 'parmesan', count = 1 },
        },
        results = { { item = 'sauce_pesto', count = 2 } },
    },
    sauce_alfredo = {
        label = "Sauce Alfredo", station = 'sauces', anim = 'sauce', duration = 7000,
        ingredients = {
            { item = 'cream', count = 1 }, { item = 'butter', count = 1 },
            { item = 'parmesan', count = 1 },
        },
        results = { { item = 'sauce_alfredo', count = 2 } },
    },

    -- ── Dressage (plats de pâtes) ────────────────────────────────────────
    plate_carbonara = {
        label = "Spaghetti Carbonara", station = 'plating', anim = 'plating', duration = 5000,
        ingredients = {
            { item = 'spaghetti_cooked', count = 1 }, { item = 'sauce_carbonara', count = 1 },
            { item = 'parmesan', count = 1 },
        },
        results = { { item = 'spaghetti_carbonara', count = 1 } },
    },
    plate_bolognese = {
        label = "Spaghetti Bolognaise", station = 'plating', anim = 'plating', duration = 5000,
        ingredients = {
            { item = 'spaghetti_cooked', count = 1 }, { item = 'sauce_bolognese', count = 1 },
            { item = 'parmesan', count = 1 },
        },
        results = { { item = 'spaghetti_bolognese', count = 1 } },
    },
    plate_penne_pesto = {
        label = "Penne au Pesto", station = 'plating', anim = 'plating', duration = 5000,
        ingredients = {
            { item = 'penne_cooked', count = 1 }, { item = 'sauce_pesto', count = 1 },
            { item = 'parmesan', count = 1 },
        },
        results = { { item = 'penne_pesto', count = 1 } },
    },
    plate_tagliatelle_alfredo = {
        label = "Tagliatelles Alfredo", station = 'plating', anim = 'plating', duration = 5000,
        ingredients = {
            { item = 'tagliatelle_cooked', count = 1 }, { item = 'sauce_alfredo', count = 1 },
            { item = 'parmesan', count = 1 },
        },
        results = { { item = 'tagliatelle_alfredo', count = 1 } },
    },
    plate_lasagne_bolognese = {
        label = "Monter des lasagnes bolognaise", station = 'plating', anim = 'plating', duration = 8000,
        ingredients = {
            { item = 'lasagne_cooked', count = 1 }, { item = 'sauce_bolognese', count = 2 },
            { item = 'bechamel', count = 1 }, { item = 'parmesan', count = 1 },
        },
        results = { { item = 'lasagne_bolognese_raw', count = 1 } },
    },
    plate_lasagne_chep = {
        label = "Monter une lasagne chèvre-épinard", station = 'plating', anim = 'plating', duration = 8000,
        ingredients = {
            { item = 'lasagne_cooked', count = 1 }, { item = 'goat_cheese', count = 1 },
            { item = 'spinach_cooked', count = 1 }, { item = 'parmesan', count = 1 },
        },
        results = { { item = 'lasagne_chep_raw', count = 1 } },
    },

    -- ── Plan à pizza (montage à cru) ─────────────────────────────────────
    pizza_base = {
        label = "Étaler un pâton", station = 'pizza', anim = 'knead', duration = 5000,
        ingredients = { { item = 'pizza_dough', count = 1 } },
        results     = { { item = 'pizza_base', count = 1 } },
    },
    pizza_margherita_raw = {
        label = "Margherita (à cru)", station = 'pizza', anim = 'plating', duration = 5000,
        ingredients = {
            { item = 'pizza_base', count = 1 }, { item = 'tomato_sauce', count = 1 },
            { item = 'mozzarella', count = 1 },
        },
        results = { { item = 'pizza_margherita_raw', count = 1 } },
    },
    pizza_regina_raw = {
        label = "Regina (à cru)", station = 'pizza', anim = 'plating', duration = 6000,
        ingredients = {
            { item = 'pizza_base', count = 1 }, { item = 'tomato_sauce', count = 1 },
            { item = 'mozzarella', count = 1 }, { item = 'ham', count = 1 },
            { item = 'mushroom', count = 1 },
        },
        results = { { item = 'pizza_regina_raw', count = 1 } },
    },
    pizza_pepperoni_raw = {
        label = "Pepperoni (à cru)", station = 'pizza', anim = 'plating', duration = 6000,
        ingredients = {
            { item = 'pizza_base', count = 1 }, { item = 'tomato_sauce', count = 1 },
            { item = 'mozzarella', count = 1 }, { item = 'pepperoni', count = 1 },
        },
        results = { { item = 'pizza_pepperoni_raw', count = 1 } },
    },
    pizza_quattro_formaggi_raw = {
        label = "Quattro Formaggi (à cru)", station = 'pizza', anim = 'plating', duration = 6500,
        ingredients = {
            { item = 'pizza_base', count = 1 }, { item = 'mozzarella', count = 1 },
            { item = 'gorgonzola', count = 1 }, { item = 'goat_cheese', count = 1 },
            { item = 'parmesan', count = 1 },
        },
        results = { { item = 'pizza_quattro_formaggi_raw', count = 1 } },
    },
    pizza_calzone_raw = {
        label = "Calzone (à cru)", station = 'pizza', anim = 'plating', duration = 6500,
        ingredients = {
            { item = 'pizza_base', count = 1 }, { item = 'tomato_sauce', count = 1 },
            { item = 'mozzarella', count = 1 }, { item = 'ham', count = 1 },
            { item = 'egg', count = 1 },
        },
        results = { { item = 'calzone_raw', count = 1 } },
    },

    -- ── Four ─────────────────────────────────────────────────────────────
    oven_margherita = {
        label = "Enfourner une Margherita", station = 'oven', anim = 'oven', duration = 8000,
        ingredients = { { item = 'pizza_margherita_raw', count = 1 } },
        results     = { { item = 'pizza_margherita', count = 1 } },
    },
    oven_regina = {
        label = "Enfourner une Regina", station = 'oven', anim = 'oven', duration = 8000,
        ingredients = { { item = 'pizza_regina_raw', count = 1 } },
        results     = { { item = 'pizza_regina', count = 1 } },
    },
    oven_pepperoni = {
        label = "Enfourner une Pepperoni", station = 'oven', anim = 'oven', duration = 8000,
        ingredients = { { item = 'pizza_pepperoni_raw', count = 1 } },
        results     = { { item = 'pizza_pepperoni', count = 1 } },
    },
    oven_quattro_formaggi = {
        label = "Enfourner une Quattro Formaggi", station = 'oven', anim = 'oven', duration = 8000,
        ingredients = { { item = 'pizza_quattro_formaggi_raw', count = 1 } },
        results     = { { item = 'pizza_quattro_formaggi', count = 1 } },
    },
    oven_calzone = {
        label = "Enfourner un Calzone", station = 'oven', anim = 'oven', duration = 8500,
        ingredients = { { item = 'calzone_raw', count = 1 } },
        results     = { { item = 'calzone', count = 1 } },
    },
    oven_lasagne_bolognese = {
        label = "Enfourner des lasagnes bolognaise", station = 'oven', anim = 'oven', duration = 12000,
        ingredients = { { item = 'lasagne_bolognese_raw', count = 1 } },
        results     = { { item = 'lasagne_bolognese', count = 1 } },
    },
    oven_lasagne_chep = {
        label = "Enfourner une lasagne chèvre-épinard", station = 'oven', anim = 'oven', duration = 12000,
        ingredients = { { item = 'lasagne_chep_raw', count = 1 } },
        results     = { { item = 'lasagne_chep', count = 1 } },
    },

    -- ── Desserts ─────────────────────────────────────────────────────────
    dessert_tiramisu = {
        label = "Tiramisu", station = 'desserts', anim = 'dessert', duration = 9000,
        ingredients = {
            { item = 'mascarpone', count = 1 }, { item = 'egg', count = 1 },
            { item = 'sugar', count = 1 }, { item = 'ladyfingers', count = 1 },
            { item = 'coffee_beans', count = 1 },
        },
        results = { { item = 'tiramisu', count = 2 } },
    },
    dessert_panna_cotta = {
        label = "Panna Cotta", station = 'desserts', anim = 'dessert', duration = 7000,
        ingredients = {
            { item = 'cream', count = 1 }, { item = 'sugar', count = 1 },
            { item = 'vanilla', count = 1 },
        },
        results = { { item = 'panna_cotta', count = 2 } },
    },
    dessert_cannoli = {
        label = "Cannoli", station = 'desserts', anim = 'dessert', duration = 6000,
        ingredients = {
            { item = 'cannoli_shell', count = 1 }, { item = 'ricotta', count = 1 },
            { item = 'sugar', count = 1 },
        },
        results = { { item = 'cannoli', count = 2 } },
    },

    -- ── Bar ──────────────────────────────────────────────────────────────
    drink_water = {
        label = "Eau", station = 'drinks', anim = 'drink', duration = 2500,
        ingredients = { { item = 'glass', count = 1 } },
        results     = { { item = 'water', count = 1 } },
    },
    drink_cola = {
        label = "Cola", station = 'drinks', anim = 'drink', duration = 3000,
        ingredients = { { item = 'glass', count = 1 }, { item = 'syrup_cola', count = 1 } },
        results     = { { item = 'cola', count = 1 } },
    },
    drink_sprunk = {
        label = "Sprunk", station = 'drinks', anim = 'drink', duration = 3000,
        ingredients = { { item = 'glass', count = 1 }, { item = 'syrup_sprunk', count = 1 } },
        results     = { { item = 'sprunk', count = 1 } },
    },
    drink_otang = {
        label = "O'tang", station = 'drinks', anim = 'drink', duration = 3000,
        ingredients = { { item = 'glass', count = 1 }, { item = 'syrup_otang', count = 1 } },
        results     = { { item = 'otang', count = 1 } },
    },
    drink_coffee = {
        label = "Café", station = 'drinks', anim = 'drink', duration = 4000,
        ingredients = { { item = 'coffee_beans', count = 1 } },
        results     = { { item = 'coffee', count = 1 } },
    },
}
