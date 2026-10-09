-- Activités de récolte indépendantes (pas de job/grade requis) : récolte → traitement → revente

Config.Farm = {}

-- Notification (même système que les autres métiers)

-- Minijeu générique (barre + appui touche, identique à Mécanicien), réutilisé pour la récolte et le traitement.
Config.Farm.Minigame = {
    rounds        = 3,
    roundDuration = 1600, -- ms par aller-retour de la barre
    zoneSize      = 0.15, -- largeur de la zone de réussite (0-1)
    requiredHits  = 2,    -- sur `rounds`
}

-- Activités
-- tool          : item requis en inventaire pour récolter (nil = aucun outil requis)
-- rawItem       : item brut obtenu à la récolte
-- processedItem : item transformé obtenu au traitement (c'est lui qui se revend)
-- nodes         : points de récolte fixes { coords = vector3(...) }
-- nodeCooldown  : ms avant qu'un même nœud soit à nouveau récoltable
-- processing    : { coords, inputPerUnit, outputPerUnit } — station de traitement
-- sellPrice     : prix unitaire ($ par processedItem) au point de revente
-- blipSprite/blipColor : utilisés pour les blips des nœuds ET de la station (voir plus bas)
-- dirty/illegal/policeAlertChance : réservé à la culture illégale (à réintroduire plus tard)
Config.Farm.Activities = {
    bucheron = {
        label         = 'Bûcheron',
        tool          = 'weapon_hatchet',
        metier        = 'bucheron',
        rawItem       = 'bois',
        -- Pas de cooldown temporel : un joueur ne peut pas récolter deux fois de suite sur le même nœud (`noRepeatNode`).
        noRepeatNode  = true,
        blipSprite    = 836, -- confirmé en jeu
        blipColor     = 2,
        -- Points fixes choisis en jeu via /farmpos. Envoie d'autres lignes
        -- pour en ajouter d'autres.
        nodes = {
            { coords = vector3(-597.82, 5472.95, 56.45) },
            { coords = vector3(-618.64, 5487.91, 51.49) },
            { coords = vector3(-590.74, 5494.12, 54.14) },
            { coords = vector3(-536.69, 5490.04, 65.02) },
        },
        -- Présent = récolte par animation en boucle (`loopDuration`) puis `yieldAmount` bois d'un coup, au lieu du minijeu barre/touche.
        -- TODO : vérifier en jeu que `clip` correspond bien à un coup de hache ; dict/clip non testés ici.
        gatherAnim = {
            dict         = 'melee@large_wpn@streamed_core',
            clip         = 'ground_attack_on_spot',
            loopDuration = 10000, -- durée totale de la récolte (ms)
            yieldAmount  = 2,     -- bois obtenus à la fin de la boucle
            -- Pas de `prop` : weapon_hatchet est une vraie arme GTA, déjà
            -- affichée correctement en main quand équipée. Un prop manuel
            -- ici créait un second modèle flottant à côté (offset non testé).
        },
        processing = {
            coords       = vector3(-503.46, 5269.66, 80.60), -- scierie
            inputPerUnit = 1, -- bois consommé
            outputPerUnit = 2, -- planches produites
        },
        sellPoint = vector3(2685.49, 3515.33, 53.29), -- point de revente séparé de la scierie (partagé avec le mineur)
        -- Bois brut vendable directement, prix volontairement bas (< 4$, l'équivalent via la scierie) pour que la transformation reste toujours plus rentable.
        directSellItems = {
            { item = 'bois', price = 1, shopItem = 'bois', buyPrice = 2 },
        },
        -- Calibré pour ~750$/h (référence salaire serveur). Ratio 1 bois → 2 planches, débit estimé ~400 planches/h. Vente uniquement par lot de 2 planches = 5$ (2.5$/unité), pas de vente à l'unité.
        processedItems = {
            { item = 'planche', weight = 1, lotSize = 2, lotPrice = 5, shopItem = 'planche', buyPrice = 3 },
        },
    },
    mineur = {
        label         = 'Mineur',
        tool          = 'pioche',
        metier        = 'mineur',
        rawItem       = 'minerai', -- seul item consommé par la fonderie (traitement → tous les minerai_XXX)
        -- Tirage pondéré à chaque coup de pioche. Seuls `minerai`/`tas_pierre` viennent directement des rochers — les minerai_XXX viennent uniquement de la fonte à la fonderie (voir `processedItems`).
        gatherYields = {
            { item = 'minerai',    weight = 1 },
            { item = 'tas_pierre', weight = 1 },
        },
        -- Items bruts revendables sans passer par la fonderie. `shopItem`/`buyPrice` alimentent aussi une boutique publique achetable par n'importe quel joueur (pattern repris de module/ltd/server/stock.lua).
        directSellItems = {
            { item = 'tas_pierre', price = 3, shopItem = 'pierre' },
        },
        -- Sac de pierre : achat uniquement, jamais vendu par le mineur. Consomme 20 unités du stock
        -- `pierre` (alimenté par les ventes de tas_pierre ci-dessus) au lieu d'avoir son propre stock —
        -- `publicShop = true` l'expose dans la boutique minéraux générique (voir shopStockResult, client).
        craftRecipes = {
            { publicShop = true, inputs = { { item = 'pierre', amount = 20 } }, output = { item = 'sac_pierre', amount = 1, buyPrice = 80 } },
        },
        -- Pas de cooldown temporel : un joueur ne peut pas miner deux fois de suite sur le même nœud (`noRepeatNode`).
        noRepeatNode  = true,
        blipSprite    = 566,
        blipColor     = 47,
        nodes = {
            { coords = vector3(2980.10, 2826.24, 46.13) },
            { coords = vector3(2914.06, 2801.88, 44.34) },
            { coords = vector3(2910.40, 2783.16, 45.78) },
            { coords = vector3(2934.33, 2743.86, 44.01) },
            { coords = vector3(2979.24, 2748.66, 43.20) },
            { coords = vector3(2987.24, 2751.86, 43.35) },
            { coords = vector3(3001.00, 2754.54, 44.16) },
            { coords = vector3(3004.43, 2763.77, 43.64) },
            { coords = vector3(3004.87, 2783.13, 44.65) },
            { coords = vector3(2984.99, 2818.59, 45.88) },
            { coords = vector3(2970.30, 2845.77, 46.53) },
            { coords = vector3(2953.54, 2852.97, 49.26) },
        },
        -- Pas de vraie arme "pioche" dans GTA V, donc prop manuel attaché en main. Anim/os/position repris tel quel de jim-mining-esx (Mycroft-Studios/jim-mining-esx/client.lua), déjà testé avec prop_tool_pickaxe.
        gatherAnim = {
            dict         = 'amb@world_human_hammering@male@base',
            clip         = 'base',
            loopDuration = 10000,
            yieldAmount  = 1, -- 1 seule unité par coup (minerai OU tas_pierre, jamais les deux)
            prop         = 'prop_tool_pickaxe',
            bone         = 57005,
            offset       = vector3(0.09, -0.53, -0.22),
            rotation     = vector3(252.0, 180.0, 0.0),
        },
        -- Anim de traitement (fonderie), geste de versage repris de module/pompe/config.lua (issue de ox_fuel). Pas de prop, juste le geste.
        processAnim = {
            dict = 'timetable@gardener@filling_can',
            clip = 'gar_ig_5_filling_can',
        },
        processing = {
            coords       = vector3(1108.40, -2007.23, 30.93), -- fonderie
            inputPerUnit = 5, -- minerai consommé
            outputPerUnit = 1, -- métal produit (tiré aléatoirement ci-dessous)
        },
        -- Vente regroupée avec le bûcheron (assignée en fin de fichier, Config.Farm.Activities n'existe pas encore ici). Fonte pondérée par rareté ; diamant = trouvaille rare (1/1000), exclu de la boutique. Prix ×7 (2026-07-20), voir directSellItems ci-dessus.
        processedItems = {
            { item = 'minerai_fer',      weight = 40,  price = 28,   shopItem = 'fer',      buyPrice = 49 },
            { item = 'minerai_cuivre',   weight = 20,  price = 42,   shopItem = 'cuivre',   buyPrice = 70 },
            { item = 'minerai_argile',   weight = 10,  price = 14,   shopItem = 'argile',   buyPrice = 28 },
            { item = 'minerai_charbon',  weight = 8,   price = 21,   shopItem = 'charbon',  buyPrice = 42 },
            { item = 'minerai_plomb',    weight = 7,   price = 28,   shopItem = 'plomb',    buyPrice = 49 },
            { item = 'minerai_zinc',     weight = 6,   price = 35,   shopItem = 'zinc',     buyPrice = 63 },
            { item = 'minerai_soufre',   weight = 3,   price = 42,   shopItem = 'soufre',   buyPrice = 77 },
            { item = 'minerai_salpetre', weight = 3,   price = 42,   shopItem = 'salpetre', buyPrice = 77 },
            { item = 'minerai_carbone',  weight = 2,   price = 56,   shopItem = 'carbone',  buyPrice = 98 },
            { item = 'minerai_or',       weight = 1,   price = 280,  shopItem = 'or',       buyPrice = 476 },
            { item = 'diamant',          weight = 0.1, price = 2100 },
        },
    },
    agriculteur = {
        label         = 'Agriculteur',
        tool          = nil,
        rawItem       = 'legume',
        processedItem = 'panier_legumes',
        nodeCooldown  = 30000,
        blipSprite    = 566,
        blipColor     = 2,
        nodes = {
            { coords = vector3(2438.0, 4974.0, 46.0) },
            { coords = vector3(2460.0, 5000.0, 46.5) },
            { coords = vector3(2410.0, 4950.0, 45.5) },
        },
        processing = {
            coords       = vector3(2445.0, 4990.0, 46.0), -- coopérative
            inputPerUnit = 5, -- légumes consommés
            outputPerUnit = 1, -- paniers produits
        },
        sellPrice = 35,
    },
    chasseur = {
        label   = 'Chasseur',
        endPnj = 'le garde-chasse',
        tool    = nil, -- n'importe quelle arme équipée suffit pour tuer l'animal
        metier  = 'chasseur',
        -- Carcasse différente par espèce. `rawItem` = item rendu au dépeçage manuel, `model` identifie l'espèce côté serveur.
        -- `peauItem`/`peauPrice` (braconnage, illégal) : prélevable via un bouton ox_target à part, couteau en main (voir `poaching` plus bas) — seuls coyote et cougar en ont.
        species = {
            { model = 'a_c_deer',        rawItem = 'carcasse_cerf',     label = 'Cerf',
              spawnZones = {
                  { coords = vector3(-1687.72, 4598.36, 48.93), radius = 50.0, count = 5 },
                  { coords = vector3(-1583.32, 4664.71, 46.09), radius = 30.0, count = 2 },
                  { coords = vector3(-1508.21, 4430.46, 14.17), radius = 40.0, count = 2 },
              },
            },
            { model = 'a_c_pig',         rawItem = 'carcasse_porc',     label = 'Porc',
              spawnZones = {
                  { coords = vector3(437.53, 6506.31, 28.61), radius = 15.0, count = 8 },
              },
            },
            { model = 'a_c_boar',        rawItem = 'carcasse_sanglier', label = 'Sanglier',
              spawnZones = {
                  { coords = vector3(-673.15, 5863.98, 16.92), radius = 70.0, count = 10 },
              },
            },
            -- Coyote : pas de `rawItem`, seule sa peau a de la valeur — sans `rawItem`, l'option dépeçage n'apparaît pas, il ne reste que "Prélever la peau".
            { model = 'a_c_coyote',      label = 'Coyote',
              peauItem = 'peau_coyote', peauPrice = 20,
              spawnZones = {
                  { coords = vector3(2048.33, 2821.23, 50.37), radius = 150.0, count = 12 },
              },
            },
            -- Cougar (a_c_mtlion) : comme le coyote, exclusivement braconnable. Population ambiante vanilla, pas de zone dédiée nécessaire.
            { model = 'a_c_mtlion',      label = 'Cougar',
              peauItem = 'peau_cougar', peauPrice = 80,
            },
            { model = 'a_c_rabbit_01',   rawItem = 'carcasse_lapin',    label = 'Lapin',
              spawnZones = {
                  { coords = vector3(-1728.22, 4699.62, 33.21), radius = 30.0, count = 10 },
                  { coords = vector3(-1687.72, 4598.36, 48.93), radius = 50.0, count = 15 },
                  { coords = vector3(-1458.43, 4569.94, 42.21), radius = 50.0, count = 10 },
              },
            },
        },
        instantGather = true, -- récupération instantanée, pas de minijeu ni d'animation
        -- `processing.coords` sert juste à placer le PNJ/blip ; le boucher transforme lui-même à la vente, pas de bouton "Traiter" séparé (voir `multiSellItems`).
        processing = {
            coords = vector3(-42.59, -1474.73, 31.93), -- boucherie
        },
        processingNpc = {
            model   = 's_m_m_strvend_01', -- Michael Freeman
            heading = 0.0, -- orientation approximative, à ajuster en jeu
        },
        -- Vente directe : chaque carcasse est découpée en quantités fixes selon l'espèce (garanti, pas aléatoire).
        -- `shopItem` reste nécessaire pour alimenter le stock caché du boucher (consommé par `craftRecipes`
        -- ci-dessous), mais AUCUN `buyPrice` ici : viande/graisse_animale/tripes/abats/sang ne sont jamais
        -- achetables directement, même par un event forgé (`farm:buyShopItem` exige un `ShopBuyPrices` non nil,
        -- lui-même construit uniquement à partir des entrées qui portent un `buyPrice` — voir server/main.lua).
        multiSellItems = {
            {
                rawItem = 'carcasse_cerf',
                outputs = {
                    { item = 'viande',          amount = 5, price = 6, shopItem = 'viande' },
                    { item = 'graisse_animale', amount = 5, price = 2, shopItem = 'graisse_animale' },
                },
            },
            {
                rawItem = 'carcasse_porc',
                outputs = {
                    { item = 'viande',          amount = 5, price = 6, shopItem = 'viande' },
                    { item = 'graisse_animale', amount = 4, price = 2, shopItem = 'graisse_animale' },
                },
            },
            {
                rawItem = 'carcasse_lapin',
                outputs = {
                    { item = 'viande',          amount = 2, price = 6, shopItem = 'viande' },
                    { item = 'graisse_animale', amount = 1, price = 2, shopItem = 'graisse_animale' },
                    { item = 'abats',           amount = 1, price = 3, shopItem = 'abats' },
                },
            },
            {
                rawItem = 'carcasse_sanglier',
                outputs = {
                    { item = 'viande',          amount = 8, price = 6, shopItem = 'viande' },
                    { item = 'graisse_animale', amount = 8, price = 2, shopItem = 'graisse_animale' },
                },
            },
            -- Ni coyote ni cougar ici : sans `rawItem` leur carcasse n'est jamais revendable, seule leur peau se monnaie au receleur.
        },
        -- Ingrédients bruts des trois restaurants (kebabking/burgershot/aldentes), directement achetables à la boutique du boucher (pas d'action "transformer" séparée) :
        -- l'achat consomme lui-même viande/graisse_animale/abats en stock (alimenté par `multiSellItems` ci-dessus), au prorata du lot demandé — voir `farm:buyShopItem`.
        -- `output.amount` = taille du lot (les ingrédients de `inputs` sont pour UN lot) ; achat arrondi au lot supérieur. ×5 pour les produits "prêts à cuisiner", ×1 pour les morceaux nobles/déchets (viande de veau, croquettes).
        craftRecipes = {
            { inputs = { { item = 'viande', amount = 3 }, { item = 'graisse_animale', amount = 1 } }, output = { item = 'patty_raw', amount = 5, buyPrice = 15 } }, -- Steak haché cru (fusionné kebabking/burgershot)
            { inputs = { { item = 'viande', amount = 3 }, { item = 'graisse_animale', amount = 2 } }, output = { item = 'guanciale',        amount = 5, buyPrice = 18 } }, -- Guanciale (aldentes)
            { inputs = { { item = 'viande', amount = 4 }, { item = 'graisse_animale', amount = 1 } }, output = { item = 'kebab_meat_raw',    amount = 1, buyPrice = 35 } }, -- Viande de veau crue (kebabking)
            { inputs = { { item = 'abats', amount = 2 }, { item = 'graisse_animale', amount = 1 } }, output = { item = 'croquette_animale', amount = 1, buyPrice = 18 } }, -- Croquettes animales
            { inputs = { { item = 'viande', amount = 3 } },                                           output = { item = 'bacon_raw',         amount = 5, buyPrice = 15 } }, -- Bacon cru (burgershot)
            { inputs = { { item = 'viande', amount = 3 }, { item = 'graisse_animale', amount = 1 } }, output = { item = 'ground_beef',       amount = 5, buyPrice = 15 } }, -- Viande hachée (aldentes)
            { inputs = { { item = 'viande', amount = 4 } },                                           output = { item = 'ham',               amount = 5, buyPrice = 15 } }, -- Jambon (aldentes)
            { inputs = { { item = 'viande', amount = 3 }, { item = 'graisse_animale', amount = 2 } }, output = { item = 'pepperoni',         amount = 5, buyPrice = 18 } }, -- Pepperoni (aldentes)
            { inputs = { { item = 'viande', amount = 3 } },                                           output = { item = 'chicken_raw',        amount = 5, buyPrice = 15 } }, -- Filet de poulet cru (burgershot)
            { inputs = { { item = 'viande', amount = 3 } },                                           output = { item = 'nugget_raw',         amount = 5, buyPrice = 16 } }, -- Nuggets crus (burgershot) ; coût du sel/épices intégré au buyPrice, non trackés en ShopStock
        },

        -- Braconnage (illégal) : bouton à part, couteau en main, cadavre non retiré. Risque d'alerte police à chaque prélèvement. Peau vendable uniquement au receleur, jamais dans la boutique publique.
        poaching = {
            tool              = 'weapon_knife',
            policeAlertChance = 0.15,
            fenceCoords = vector3(220.46, 112.29, 93.48),
            fenceNpc    = { model = 'g_m_y_strpunk_02', heading = 252.28 }, -- modèle discret par défaut, à ajuster si besoin
        },
    },
    -- Culture illégale (weed/coke) à réintroduire plus tard : server/main.lua gère déjà `dirty`/`illegal`/`policeAlertChance` génériquement, il suffira d'ajouter une entrée avec son propre circuit de revente.
}

-- Vente du mineur regroupée avec celle du bûcheron (Sandy Shores).
Config.Farm.Activities.mineur.sellPoint = Config.Farm.Activities.bucheron.sellPoint

-- Compacte 20 pierres en 1 sac, plus léger à transporter, vendable au même prix cumulé (pas d'exploit économique, juste du confort).
Config.Farm.StoneBagStation = {
    coords      = Config.Farm.Activities.bucheron.sellPoint,
    inputItem   = 'pierre',
    inputAmount = 20,
    outputItem  = 'sac_pierre',
}

Config.Farm.ShopBuyPoint = vector3(2747.25, 3472.97, 55.67) -- séparé du point de vente mineur

Config.Farm.ZoneSize     = vector3(1.2, 1.2, 2.0)
Config.Farm.ZoneDistance = 2.0

-- Animaux ambiants du jeu trop rares pour certaines espèces (porc) : on peuple nous-mêmes des zones dédiées via `spawnZones` sur chaque entrée de `species`.
-- count = nombre max entretenu dans la zone, compté sur TOUS les joueurs à proximité (pas de sur-spawn si plusieurs chasseurs se croisent).
Config.Farm.HuntSpawn = {
    checkInterval = 15000, -- ms entre deux passes de peuplement des zones
    triggerRadius = 150.0, -- distance joueur → zone en dessous de laquelle elle est peuplée
}

-- Mineur : pioche délivrée par un PNJ. La première est gratuite ; rendre la pioche restaure le droit gratuit,
-- sinon chaque nouvelle pioche coûte `price`. Seule la pioche émise (numéro unique) permet de miner.
Config.Farm.Pickaxe = {
    item     = 'pioche',
    price    = 100,
    model    = 's_m_y_construct_01',
    name     = 'John Marston',
    coords   = vector3(2834.373535, 2790.540771, 57.789795),
    heading  = 164.4094543457,
}

-- Garde-chasse : prêt d'un fusil de précision contre caution, munitions à l'unité par boîte.
-- Un seul garde affiché à la fois, alterné sur l'heure en jeu (Judy le jour, Ryan la nuit,
-- cf. LSLegacy.Weather.GetTime() côté serveur). Zone autorisée = spawnZones des espèces avec
-- `rawItem` (coyote exclu). `blips` : sprite/couleur à confirmer en jeu.
Config.Farm.GunLoan = {
    weapon       = 'weapon_sniperrifle',
    ammoItem     = 'ammo_338',
    ammoBoxCount = 10,
    ammoBoxPrice = 50,
    deposit      = 500,
    graceSec     = 300,
    reminderSec  = 60,
    dayStart     = 7,
    dayEnd       = 19,
    coords       = vector3(-1490.756104, 4980.685547, 63.350220),
    heading      = 79.370079040527,
    rangers = {
        { model = 's_f_y_ranger_01', name = 'Sarah Connor' },
        { model = 's_m_y_ranger_01', name = 'John Dunbar' },
    },
    blips = {
        Cerf     = { sprite = 463, color = 25, scale = 0.7, label = 'Zone de chasse — Cerf' },
        Porc     = { sprite = 463, color = 17, scale = 0.7, label = 'Zone de chasse — Porc' },
        Sanglier = { sprite = 463, color = 47, scale = 0.7, label = 'Zone de chasse — Sanglier' },
        Lapin    = { sprite = 463, color = 2,  scale = 0.7, label = 'Zone de chasse — Lapin' },
    },
}

Config.Farm.NodeBlipScale       = 0.55
Config.Farm.ProcessingBlipScale = 0.85

-- Hache du bûcheron : même fonctionnement que la pioche (premier exemplaire gratuit, rendu = droit restauré).
Config.Farm.Hatchet = {
    item     = 'weapon_hatchet',
    price    = 100,
    model    = 's_m_m_cntrybar_01',
    name     = 'Paul Bunyan',
    coords   = vector3(-572.241760, 5326.153809, 70.208008),
    heading  = 70.866142272949,
}

-- Marchands ouverts à tous, visibles par tous les joueurs.
Config.Farm.Marchands = {
    boucher = {
        blipCoords = { Config.Farm.Activities.chasseur.processing.coords },
        blip = { sprite = 52, color = 1, scale = 0.6, label = 'Boucher' },
    },
    poissonnier = {
        pnj = { model = 's_m_m_linecook', name = 'Arnold Patterson', coords = vector3(1301.630737, 4320.158203, 38.227051), heading = 317.48031616211 },
        blip = { sprite = 52, color = 3, scale = 0.6, label = 'Poissonnier' },
    },
}

-- Agence d'intérim : le joueur choisit un métier, seuls les points de ce métier lui sont visibles et accessibles.
Config.Farm.Agency = {
    model   = 'a_f_y_business_02',
    name    = 'Kelly Chambers',
    coords  = vector3(416.571442, -1086.540649, 30.054932),
    heading = 130.39370727539,
    blip    = { sprite = 480, color = 5, scale = 0.7, label = 'Agence d\'intérim' },
}

-- `pnj` : PNJ de métier à faire apparaître (les autres PNJ de métier existent déjà ailleurs).
-- `blipCoords` : PNJ de métier, visibles par tous les joueurs sans blip tant que le métier n'est pas choisi.
-- Les points de récolte/traitement/vente et zones de chasse sont rattachés via `metier` dans Config.Farm.Activities.
Config.Farm.Metiers = {
    chasseur = {
        label = 'Chasseur',
        blipCoords = { Config.Farm.GunLoan.coords },
        blip = { sprite = 480, color = 1, scale = 0.6, label = 'Chasseur — Garde-chasse / Boucher' },
    },
    mineur = {
        label = 'Mineur',
        endPnj = 'John Marston',
        blipCoords = { Config.Farm.Pickaxe.coords },
        blip = { sprite = 480, color = 47, scale = 0.6, label = 'Mineur — Pioche' },
    },
    bucheron = {
        label = 'Bûcheron',
        endPnj = 'Paul Bunyan',
        blipCoords = { Config.Farm.Hatchet.coords },
        blip = { sprite = 480, color = 2, scale = 0.6, label = 'Bûcheron — Paul Bunyan' },
    },
    ['chauffeur_citerne'] = {
        label = 'Chauffeur-Citerne',
        endPnj = 'Frank Martin',
        blipCoords = { Config.Interim.Ped.coords },
        blip = { sprite = 318, color = 5, scale = 0.8, label = 'Intérim — Essence' },
    },
    pecheur = {
        label = 'Pêcheur',
        endPnj = 'Hank Hill',
        pnj = { model = 'a_m_m_hillbilly_01', name = 'Hank Hill', coords = vector3(3820.760498, 4454.399902, 3.297485), heading = 28.34645652771 },
        blipCoords = { vector3(3820.760498, 4454.399902, 3.297485) },
        blip = { sprite = 480, color = 3, scale = 0.6, label = 'Pêcheur — Hank Hill' },
    },
    ['transporteur_avicole'] = {
        label = 'Transporteur Avicole',
        endPnj = 'Earl Hickey',
        blipCoords = { Config.Avicole.Ped.coords },
        blip = { sprite = 480, color = 25, scale = 0.6, label = 'Transporteur Avicole — Earl Hickey' },
    },
    ['preparateur_avicole'] = {
        label = 'Préparateur Avicole',
        endPnj = 'Cluck Norris / Ginger Fields',
        blipCoords = { Config.Avicole.Usine.coords },
        blip = { sprite = 480, color = 2, scale = 0.6, label = 'Préparateur Avicole — Usine du Nord' },
    },
}
