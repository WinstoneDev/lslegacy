-- module/grossiste — Catalogue achat/vente.
--
-- Prix fixes, grille de départ à ajuster après test en jeu. `item` peut
-- pointer un item déjà défini par un autre module (kebab king, burger shot,
-- items partagés...) ou un item introduit ici (config/items.lua).
--
-- `label` est répété ici volontairement : le client n'a jamais chargé le
-- registre d'items du module propriétaire (ex. Burger Shot pour `tomato`),
-- donc pas moyen d'aller chercher son libellé dynamiquement côté NUI/menu.
--
-- pack/packCount : juste l'habillage RP du bouton d'achat ("Sac de Farine"
-- donne 20 Farine d'un coup) — buyUnit/sellUnit restent des prix UNITAIRES,
-- pour que la revente accepte n'importe quelle quantité détenue.
--
-- potUses : marque un pot de sauce Kebab King (voir ls_kebabking) — acheté
-- avec ce nombre d'utilisations au lieu des 20 obtenues en le fabriquant.

GRConfig.Catalog = {
    -- ── Boulangerie / crèmerie (hors viandes couvertes par la chasse) ────
    { item = 'bun',    label = "Buns",    category = "Boulangerie", pack = "Paquet de buns",    packCount = 30, buyUnit = 1, sellUnit = 0.5 },
    { item = 'cheese', label = "Fromage", category = "Crèmerie",    pack = "Brique de fromage",  packCount = 10, buyUnit = 2, sellUnit = 1 },

    -- ── Fruits & légumes ─────────────────────────────────────────────────
    { item = 'pickle',         label = "Cornichons",     category = "Fruits & légumes", pack = "Bocal de Cornichon",     packCount = 20, buyUnit = 1,   sellUnit = 0.5 },
    { item = 'raspberry',      label = "Framboise",      category = "Fruits & légumes", pack = "Paquet de Framboise",    packCount = 15, buyUnit = 2,   sellUnit = 1 },
    { item = 'cucumber',       label = "Concombre",      category = "Fruits & légumes", pack = "Cagette de Concombre",   packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'bell_pepper',    label = "Poivron",        category = "Fruits & légumes", pack = "Sachet de Poivron",      packCount = 5,  buyUnit = 2,   sellUnit = 1 },
    { item = 'harissa_pepper', label = "Piments",        category = "Fruits & légumes", pack = "Sachet de Piment",       packCount = 5,  buyUnit = 2,   sellUnit = 1 },
    { item = 'broccoli',       label = "Brocolis",       category = "Fruits & légumes", pack = "Cagette de Brocolis",    packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'orange',         label = "Orange",         category = "Fruits & légumes", pack = "Cagette d'Orange",       packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'avocado',        label = "Avocat",         category = "Fruits & légumes", pack = "Sachet d'Avocat",        packCount = 2,  buyUnit = 4,   sellUnit = 2 },
    { item = 'carrot',         label = "Carotte",        category = "Fruits & légumes", pack = "Cagette de Carotte",     packCount = 20, buyUnit = 1,   sellUnit = 0.5 },
    { item = 'corn',           label = "Maïs",           category = "Fruits & légumes", pack = "Cagette de Maïs",        packCount = 5,  buyUnit = 2,   sellUnit = 1 },
    { item = 'tomato',         label = "Tomate",         category = "Fruits & légumes", pack = "Cagette de Tomates",     packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'rice',           label = "Sachet de riz",  category = "Fruits & légumes", pack = "Paquet de Riz",          packCount = 5,  buyUnit = 2,   sellUnit = 1 },
    { item = 'onion',          label = "Oignon",         category = "Fruits & légumes", pack = "Sachet d'Oignon",        packCount = 5,  buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'garlic',         label = "Ail",            category = "Fruits & légumes", pack = "Sachet d'ail",           packCount = 5,  buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'kiwi',           label = "Kiwi",           category = "Fruits & légumes", pack = "Sachet de Kiwi",         packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'coconut',        label = "Noix de Coco",   category = "Fruits & légumes", pack = "Sachet de Noix de Coco", packCount = 2,  buyUnit = 4,   sellUnit = 2 },
    { item = 'pineapple',      label = "Ananas",         category = "Fruits & légumes", pack = "Cagette d'ananas",       packCount = 5,  buyUnit = 3,   sellUnit = 1.5 },
    { item = 'apple',          label = "Pommes",         category = "Fruits & légumes", pack = "Cagette de Pomme",       packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'pear',           label = "Poire",          category = "Fruits & légumes", pack = "Sachet de Poire",        packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'potato',         label = "Pomme de terre", category = "Fruits & légumes", pack = "Sac de Pomme de terre",  packCount = 20, buyUnit = 1,   sellUnit = 0.5 },
    { item = 'salad',          label = "Salade",         category = "Fruits & légumes", pack = "Cagette de Salade",      packCount = 5,  buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'cabbage',        label = "Choux",          category = "Fruits & légumes", pack = "Cagette de Choux",       packCount = 5,  buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'mango',          label = "Mangue",         category = "Fruits & légumes", pack = "Cagette de Mangue",      packCount = 10, buyUnit = 2,   sellUnit = 1 },
    { item = 'lemon',          label = "Citron J/V",     category = "Fruits & légumes", pack = "Cagette de Citron J/V",  packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'mushroom',       label = "Champignon",     category = "Fruits & légumes", pack = "Sac de Champignon",      packCount = 20, buyUnit = 1,   sellUnit = 0.5 },
    { item = 'noodles_dry',    label = "Nouilles déshydratées", category = "Fruits & légumes", pack = "Carton de Nouille", packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },

    -- ── Boucherie (hors viandes couvertes par la chasse) ─────────────────
    { item = 'potato_cut', label = "Frites crues", category = "Boucherie", pack = "Paquet de Frite surgelé", packCount = 10, buyUnit = 1, sellUnit = 0.5 },
    { item = 'sausage',    label = "Saucisses",    category = "Boucherie", pack = "Paquet de Saucisses",     packCount = 6,  buyUnit = 3, sellUnit = 1.5 },
    { item = 'merguez',    label = "Merguez",      category = "Boucherie", pack = "Paquet de Merguez",       packCount = 6,  buyUnit = 3, sellUnit = 1.5 },

    -- ── Brasserie / distillerie (en réserve) ─────────────────────────────
    { item = 'hops',      label = "Houblon",       category = "Brasserie", pack = "Sachet de Houblon",        packCount = 20, buyUnit = 1, sellUnit = 0.5 },
    { item = 'barley',    label = "Orge",          category = "Brasserie", pack = "Sac d'Orge",               packCount = 20, buyUnit = 1, sellUnit = 0.5 },
    { item = 'sugarcane', label = "Canne à Sucre", category = "Brasserie", pack = "Cagette de Canne à Sucre", packCount = 5,  buyUnit = 2, sellUnit = 1 },
    { item = 'agave',     label = "Agave",         category = "Brasserie", pack = "Cagette d'Agave",          packCount = 5,  buyUnit = 2, sellUnit = 1 },
    { item = 'yeast',     label = "Levure",        category = "Brasserie", pack = "Paquet de Levure",         packCount = 20, buyUnit = 1, sellUnit = 0.5 },

    -- ── Cave (alcools, produits finis) ────────────────────────────────────
    { item = 'grape_juice', label = "Jus de Raisin",             category = "Cave", pack = "Pack de Jus de Raisin",            packCount = 6, buyUnit = 3,  sellUnit = 1.5 },
    { item = 'wine_red',    label = "Bouteille de Vin Rouge",    category = "Cave", pack = "Carton de Bouteille de Vin Rouge", packCount = 6, buyUnit = 25, sellUnit = 12 },
    { item = 'wine_white',  label = "Bouteille de Vin Blanc",    category = "Cave", pack = "Carton de Bouteille de Vin Blanc", packCount = 6, buyUnit = 25, sellUnit = 12 },
    { item = 'champagne',   label = "Bouteille de Champagne",    category = "Cave", pack = "Carton de Bouteille de Champagne", packCount = 6, buyUnit = 40, sellUnit = 20 },
    { item = 'beer_blonde', label = "Bouteille de Bière Blonde", category = "Cave", pack = "Carton de Bière Blonde",           packCount = 6, buyUnit = 15, sellUnit = 7 },
    { item = 'beer_brown',  label = "Bouteille de Bière Brune",  category = "Cave", pack = "Carton de Bière Brune",            packCount = 6, buyUnit = 15, sellUnit = 7 },
    { item = 'beer_red',    label = "Bouteille de Bière Rousse", category = "Cave", pack = "Carton de Bière Rousse",           packCount = 6, buyUnit = 15, sellUnit = 7 },
    { item = 'whisky',      label = "Bouteille de Whisky",       category = "Cave", pack = "Carton de Whisky",                 packCount = 6, buyUnit = 35, sellUnit = 17 },
    { item = 'vodka',       label = "Bouteille de Vodka",        category = "Cave", pack = "Carton de Vodka",                  packCount = 6, buyUnit = 30, sellUnit = 15 },
    { item = 'cognac',      label = "Bouteille de Cognac",       category = "Cave", pack = "Carton de Cognac",                 packCount = 6, buyUnit = 40, sellUnit = 20 },
    { item = 'moonshine',   label = "Bouteille d'Eau de Vie",    category = "Cave", pack = "Carton d'Eau de Vie",              packCount = 6, buyUnit = 35, sellUnit = 17 },
    { item = 'cider',       label = "Bouteille de Cidre",        category = "Cave", pack = "Carton de Cidre",                  packCount = 6, buyUnit = 18, sellUnit = 9 },
    { item = 'calvados',    label = "Bouteille de Calvados",     category = "Cave", pack = "Carton de Calvados",               packCount = 6, buyUnit = 35, sellUnit = 17 },
    { item = 'rum',         label = "Bouteille de Rhum",         category = "Cave", pack = "Carton de Rhum",                   packCount = 6, buyUnit = 35, sellUnit = 17 },
    { item = 'tequila',     label = "Bouteille de Tequila",      category = "Cave", pack = "Carton de Tequila",                packCount = 6, buyUnit = 35, sellUnit = 17 },

    -- ── Épicerie ──────────────────────────────────────────────────────────
    { item = 'flour',    label = "Farine",  category = "Épicerie", pack = "Sac de Farine",      packCount = 20, buyUnit = 1,   sellUnit = 0.5 },
    { item = 'wheat',    label = "Blé",     category = "Épicerie", pack = "Sachet de Blé",      packCount = 20, buyUnit = 1,   sellUnit = 0.5 },
    { item = 'sugar',    label = "Sucre",   category = "Épicerie", pack = "Paquet de Sucre",    packCount = 10, buyUnit = 1,   sellUnit = 0.5 },
    { item = 'salt',     label = "Sel",     category = "Épicerie", pack = "Paquet de Sel",      packCount = 20, buyUnit = 0.5, sellUnit = 0.25 },
    { item = 'butter',   label = "Beurre",  category = "Épicerie", pack = "Paquet de Beurre",   packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'chocolate', label = "Chocolat", category = "Épicerie", pack = "Paquet de Chocolat", packCount = 10, buyUnit = 2, sellUnit = 1 },
    { item = 'praline',  label = "Praline", category = "Épicerie", pack = "Paquet de Praline",  packCount = 10, buyUnit = 2,   sellUnit = 1 },
    { item = 'almond',   label = "Amande",  category = "Épicerie", pack = "Paquet d'Amande",    packCount = 10, buyUnit = 2,   sellUnit = 1 },
    { item = 'spices',   label = "Épices",  category = "Épicerie", pack = "Paquet d'Épices",    packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'honey',    label = "Miel",    category = "Épicerie", pack = "Pot de Miel",        packCount = 10, buyUnit = 2,   sellUnit = 1 },
    { item = 'milk',     label = "Lait",    category = "Épicerie", pack = "Pack de Lait",       packCount = 6,  buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'egg',      label = "Œuf",     category = "Épicerie", pack = "Boite a oeuf",       packCount = 12, buyUnit = 1,   sellUnit = 0.5 },
    -- Ces 4 comblent le trou d'approvisionnement Kebab King (vinaigre, huile
    -- d'olive, crème, yaourt) — retail à ouvrir un par un, voir GRConfig.Unpacks.
    { item = 'bouteille_vinaigre',    label = "Bouteille de Vinaigre",     category = "Épicerie", pack = "Carton de Vinaigre",      packCount = 6,  buyUnit = 3,   sellUnit = 1.5 },
    { item = 'bouteille_huile_olive', label = "Bouteille d'Huile d'Olive", category = "Épicerie", pack = "Carton d'Huile d'Olive",  packCount = 6,  buyUnit = 3,   sellUnit = 1.5 },
    { item = 'pot_creme_fraiche',     label = "Pot de Crème Fraîche",      category = "Épicerie", pack = "Carton de Crème Fraîche", packCount = 6,  buyUnit = 3,   sellUnit = 1.5 },
    { item = 'pack_yaourt',           label = "Pack de Yaourt",            category = "Épicerie", pack = "Carton de Yaourt",        packCount = 6,  buyUnit = 2,   sellUnit = 1 },
    { item = 'herbs',                 label = "Herbes de cuisine",         category = "Épicerie", pack = "Sac d'Herbes",            packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'chickpea',              label = "Pois chiche",               category = "Épicerie", pack = "Sac de Pois Chiche",      packCount = 20, buyUnit = 1,   sellUnit = 0.5 },
    -- Glace vanille (burgershot) : carton -> boîtes -> glace vanille (voir GRConfig.Unpacks).
    { item = 'boite_glace_vanille', label = "Boîte de Glace Vanille", category = "Épicerie", pack = "Carton de glace vanille", packCount = 5, buyUnit = 4, sellUnit = 2 },
    -- Pâte à cookies (burgershot) : carton -> pots -> pâte à cookies.
    { item = 'pot_pate_cookie', label = "Pot de Pâte à Cookies", category = "Épicerie", pack = "Carton de pot de pâte à cookies", packCount = 5, buyUnit = 2.5, sellUnit = 1.25 },
    -- Pâte à viennoiserie / chausson (burgershot) : carton -> pots -> pâte à viennoiserie.
    { item = 'pot_pate_viennoiserie', label = "Pot de Pâte à Viennoiserie", category = "Épicerie", pack = "Carton de pot de pâte à viennoiserie", packCount = 5, buyUnit = 2.5, sellUnit = 1.25 },

    -- ── Crèmerie / pâtes Aldente's ────────────────────────────────────────
    { item = 'sachet_epinard',    label = "Sachet d'Épinard",     category = "Épicerie", pack = "Carton d'épinards",          packCount = 6,  buyUnit = 2,   sellUnit = 1 },
    { item = 'parmesan',          label = "Parmesan râpé",        category = "Épicerie", pack = "Meule de Parmesan",          packCount = 20, buyUnit = 1,   sellUnit = 0.5 },
    { item = 'sachet_mozzarella', label = "Sachet de Mozzarella", category = "Épicerie", pack = "Carton de mozzarella",       packCount = 6,  buyUnit = 2,   sellUnit = 1 },
    { item = 'gorgonzola',        label = "Gorgonzola",           category = "Épicerie", pack = "Bloc de gorgonzola",         packCount = 10, buyUnit = 2,   sellUnit = 1 },
    { item = 'goat_cheese',       label = "Chèvre",               category = "Épicerie", pack = "Rouleau de chèvre",          packCount = 10, buyUnit = 2,   sellUnit = 1 },
    { item = 'pot_mascarpone',    label = "Pot de Mascarpone",    category = "Épicerie", pack = "Carton de mascarpone",       packCount = 6,  buyUnit = 3,   sellUnit = 1.5 },
    { item = 'pot_ricotta',       label = "Pot de Ricotta",       category = "Épicerie", pack = "Carton de ricotta",          packCount = 6,  buyUnit = 2.5, sellUnit = 1.25 },
    { item = 'paquet_spaghetti',  label = "Paquet de Spaghetti",  category = "Épicerie", pack = "Carton de spaghetti",        packCount = 6,  buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'paquet_penne',            label = "Paquet de Penne",             category = "Épicerie", pack = "Carton de penne",             packCount = 6, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'paquet_tagliatelle',      label = "Paquet de Tagliatelle",       category = "Épicerie", pack = "Carton de tagliatelle",       packCount = 6, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'paquet_feuille_lasagne',  label = "Paquet de Feuille de Lasagne", category = "Épicerie", pack = "Carton de feuille de lasagne", packCount = 4, buyUnit = 2, sellUnit = 1 },
    { item = 'boite_vanille',           label = "Boîte de Vanille",         category = "Épicerie", pack = "Carton de boite de vanille",     packCount = 4, buyUnit = 2,   sellUnit = 1 },
    { item = 'paquet_biscuit_cuillere', label = "Paquet de Biscuit Cuillère", category = "Épicerie", pack = "Carton de biscuit cuillère", packCount = 6, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'paquet_cafe_grains',      label = "Paquet de Café en Grains", category = "Épicerie", pack = "Carton de sac de café en grains", packCount = 4, buyUnit = 2, sellUnit = 1 },
    { item = 'paquet_tube_cannoli',     label = "Paquet de Tube à Cannoli", category = "Épicerie", pack = "Carton de tube à cannoli", packCount = 4, buyUnit = 2, sellUnit = 1 },

    -- ── Poissonnerie (en réserve) ─────────────────────────────────────────
    { item = 'salmon_fillet', label = "Filet de Saumon", category = "Poissonnerie", pack = "Paquet de Filet de Saumon", packCount = 5, buyUnit = 6, sellUnit = 3 },
    { item = 'tuna_fillet',   label = "Filet de Thon",   category = "Poissonnerie", pack = "Paquet de Filet de Thon",   packCount = 5, buyUnit = 6, sellUnit = 3 },
    { item = 'cod_fillet',    label = "Filet de Colin",  category = "Poissonnerie", pack = "Paquet de Filet de Colin",  packCount = 5, buyUnit = 5, sellUnit = 2.5 },
    { item = 'perch_fillet',  label = "Filet de Perche", category = "Poissonnerie", pack = "Paquet de Filet de Perche", packCount = 5, buyUnit = 5, sellUnit = 2.5 },

    -- ── Matériaux (en réserve) ────────────────────────────────────────────
    { item = 'cotton',      label = "Coton",       category = "Matériaux", pack = "Sachet de Coton",      packCount = 10, buyUnit = 2, sellUnit = 1 },
    { item = 'poppy',       label = "Pavot",       category = "Matériaux", pack = "Cagette de Pavot",     packCount = 10, buyUnit = 2, sellUnit = 1 },
    { item = 'aloe_vera',   label = "Aloe Vera",   category = "Matériaux", pack = "Cagette d'Aloe Vera",  packCount = 10, buyUnit = 2, sellUnit = 1 },
    { item = 'fabric',      label = "Tissus",      category = "Matériaux", pack = "Rouleau de Tissus",    packCount = 10, buyUnit = 3, sellUnit = 1.5 },
    { item = 'leather',     label = "Cuir",        category = "Matériaux", pack = "Rouleau de Cuir",      packCount = 10, buyUnit = 3, sellUnit = 1.5 },
    { item = 'tobacco_raw', label = "Tabac",       category = "Matériaux", pack = "Carton de Tabac Brut", packCount = 20, buyUnit = 1, sellUnit = 0.5 },

    -- ── Boissons diverses ─────────────────────────────────────────────────
    { item = 'water',           label = "Eau",           category = "Boissons", pack = "Pack D'Eau",          packCount = 6,  buyUnit = 1,   sellUnit = 0.5 },
    { item = 'sparkling_water', label = "Eau Gazeuse",   category = "Boissons", pack = "Pack D'Eau Gazeuse",  packCount = 6,  buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'coconut_milk',    label = "Lait de Coco",  category = "Boissons", pack = "Pack de Lait de Coco", packCount = 6, buyUnit = 2,   sellUnit = 1 },
    { item = 'crushed_ice',     label = "Glace Pilée",   category = "Boissons", pack = "Sac de Glace Pilée",  packCount = 10, buyUnit = 0.5, sellUnit = 0.25 },
    { item = 'syrup_cola',   label = "Sirop Cola",   category = "Boissons", pack = "Pack de Sirop Cola",   packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'syrup_sprunk', label = "Sirop Sprunk", category = "Boissons", pack = "Pack de Sirop Sprunk", packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'syrup_otang',  label = "Sirop O'tang", category = "Boissons", pack = "Pack de Sirop O'tang", packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'syrup_straw',  label = "Sirop Fraise",   category = "Boissons", pack = "Pack de Sirop Fraise",   packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },
    { item = 'syrup_choco',  label = "Sirop Chocolat", category = "Boissons", pack = "Pack de Sirop Chocolat", packCount = 10, buyUnit = 1.5, sellUnit = 0.75 },

    -- ── Pots de sauce Kebab King (achetés à 10 utilisations, 20 en craft) ──
    { item = 'pot_ketchup',  label = "Pot de Ketchup",          category = "Sauces", pack = "Pot de Ketchup",          packCount = 1, buyUnit = 60, sellUnit = 30, potUses = 10 },
    { item = 'pot_harissa',  label = "Pot de Harissa",          category = "Sauces", pack = "Pot de Harissa",          packCount = 1, buyUnit = 60, sellUnit = 30, potUses = 10 },
    { item = 'pot_bbq',      label = "Pot de Sauce Barbecue",   category = "Sauces", pack = "Pot de Barbecue",         packCount = 1, buyUnit = 60, sellUnit = 30, potUses = 10 },
    { item = 'pot_mayo',     label = "Pot de Mayonnaise",       category = "Sauces", pack = "Pot de Mayonnaise",       packCount = 1, buyUnit = 60, sellUnit = 30, potUses = 10 },
    { item = 'pot_white',    label = "Pot de Sauce Blanche",    category = "Sauces", pack = "Pot de Sauce Blanche",    packCount = 1, buyUnit = 65, sellUnit = 32, potUses = 10 },
    { item = 'pot_samurai',  label = "Pot de Sauce Samouraï",   category = "Sauces", pack = "Pot de Sauce Samouraï",   packCount = 1, buyUnit = 65, sellUnit = 32, potUses = 10 },
    { item = 'pot_algerian', label = "Pot de Sauce Algérienne", category = "Sauces", pack = "Pot de Sauce Algérienne", packCount = 1, buyUnit = 65, sellUnit = 32, potUses = 10 },
    { item = 'pot_cheese',   label = "Pot de Sauce Fromagère",  category = "Sauces", pack = "Pot de Sauce Fromagère",  packCount = 1, buyUnit = 65, sellUnit = 32, potUses = 10 },
}

-- Index rapide item -> entrée catalogue.
GRConfig.CatalogByItem = {}
for _, entry in ipairs(GRConfig.Catalog) do
    GRConfig.CatalogByItem[entry.item] = entry
end

-- ── Déballage (usable item -> N unités d'un ingrédient de base) ──────────
-- Un seul handler générique les enregistre tous (voir server/main.lua).
-- `label` : libellé de l'ingrédient de base obtenu, pour le message de
-- confirmation (même raison que `label` sur GRConfig.Catalog ci-dessus).
GRConfig.Unpacks = {
    bouteille_vinaigre    = { item = 'vinegar',        count = 10, label = "Vinaigre" },
    bouteille_huile_olive = { item = 'olive_oil',      count = 10, label = "Huile d'Olive" },
    pot_creme_fraiche     = { item = 'cream',          count = 10, label = "Crème" },
    pack_yaourt           = { item = 'yogurt',         count = 10, label = "Yaourt" },
    sachet_epinard          = { item = 'spinach',      count = 10, label = "Épinards" },
    sachet_mozzarella       = { item = 'mozzarella',   count = 10, label = "Mozzarella" },
    pot_mascarpone          = { item = 'mascarpone',   count = 8,  label = "Mascarpone" },
    pot_ricotta             = { item = 'ricotta',      count = 8,  label = "Ricotta" },
    paquet_spaghetti        = { item = 'spaghetti_raw', count = 10, label = "Spaghetti crus" },
    paquet_penne            = { item = 'penne_raw',       count = 10, label = "Penne crus" },
    paquet_tagliatelle      = { item = 'tagliatelle_raw', count = 10, label = "Tagliatelles crues" },
    paquet_feuille_lasagne  = { item = 'lasagne_raw',     count = 10, label = "Feuilles de lasagne crues" },
    boite_vanille           = { item = 'vanilla',      count = 10, label = "Vanille" },
    paquet_biscuit_cuillere = { item = 'ladyfingers',  count = 10, label = "Biscuits à la cuillère" },
    paquet_cafe_grains      = { item = 'coffee_beans', count = 10, label = "Café en grains" },
    paquet_tube_cannoli     = { item = 'cannoli_shell', count = 10, label = "Tube à cannoli" },
    boite_glace_vanille    = { item = 'ice_cream',    count = 10, label = "Glace vanille" },
    pot_pate_cookie        = { item = 'cookie_dough', count = 1,  label = "Pâte à Cookies" },
    pot_pate_viennoiserie  = { item = 'dough_pie',    count = 5,  label = "Pâte à Viennoiserie" },
}
