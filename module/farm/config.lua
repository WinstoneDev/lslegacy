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
        rawItem       = 'bois',
        nodeCooldown  = 30000,
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
        -- Calibré pour ~750$/h (référence salaire serveur). Ratio 1 bois → 2 planches, débit estimé ~400 planches/h → prix ≈ 1.9$. À ajuster après test réel en jeu.
        processedItems = {
            { item = 'planche', weight = 1, price = 2, shopItem = 'planche', buyPrice = 3 },
        },
    },
    mineur = {
        label         = 'Mineur',
        tool          = 'pioche',
        rawItem       = 'minerai', -- seul item consommé par la fonderie (traitement → tous les minerai_XXX)
        -- Tirage pondéré à chaque coup de pioche. Seuls `minerai`/`tas_pierre` viennent directement des rochers — les minerai_XXX viennent uniquement de la fonte à la fonderie (voir `processedItems`).
        gatherYields = {
            { item = 'minerai',    weight = 1 },
            { item = 'tas_pierre', weight = 1 },
        },
        -- Items bruts revendables sans passer par la fonderie. `shopItem`/`buyPrice` alimentent aussi une boutique publique achetable par n'importe quel joueur (pattern repris de module/ltd/server/stock.lua).
        directSellItems = {
            -- Prix ×7 (2026-07-20) : structure à 3 lieux éloignés (mine→fonderie→vente) bien plus coûteuse en temps que le bûcheron, compensée pour viser les mêmes ~750$/h.
            { item = 'tas_pierre', price = 7, shopItem = 'pierre', buyPrice = 14 },
            { item = 'sac_pierre', price = 420, shopItem = 'sac_pierre', buyPrice = 700 }, -- 20 × prix de la pierre (neutre, gain de poids uniquement)
        },
        nodeCooldown  = 35000,
        blipSprite    = 620,
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
        tool    = nil, -- n'importe quelle arme équipée suffit pour tuer l'animal
        -- Carcasse différente par espèce. `rawItem` = item rendu au dépeçage manuel, `model` identifie l'espèce côté serveur.
        -- `peauItem`/`peauPrice` (braconnage, illégal) : prélevable via un bouton ox_target à part, couteau en main (voir `poaching` plus bas) — seuls coyote et cougar en ont.
        -- Plusieurs modèles d'oiseaux partagent la même carcasse (`carcasse_oiseau`).
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
            -- Oiseaux : pas de zone fixe, `ambient` fait apparaître l'espèce autour du joueur avec un filtre de biome (`requiresWater`/`ruralOnly`). Voir `Config.Farm.HuntSpawn.ambient*`.
            { model = 'a_c_crow',        rawItem = 'carcasse_oiseau',   label = 'Oiseau',
              ambient = { maxNearby = 3 } }, -- partout, comme en vanilla
            { model = 'a_c_pigeon',      rawItem = 'carcasse_oiseau',   label = 'Oiseau',
              ambient = { maxNearby = 3 } }, -- partout, comme en vanilla
            { model = 'a_c_seagull',     rawItem = 'carcasse_oiseau',   label = 'Oiseau',
              ambient = { maxNearby = 2, requiresWater = true } }, -- littoral uniquement
            { model = 'a_c_chickenhawk', rawItem = 'carcasse_oiseau',   label = 'Oiseau',
              ambient = { maxNearby = 2, ruralOnly = true } }, -- montagne/campagne, hors ville dense
            { model = 'a_c_hen',         rawItem = 'carcasse_oiseau',   label = 'Oiseau',
              ambient = { maxNearby = 2, ruralOnly = true } }, -- ferme, hors ville dense
        },
        instantGather = true, -- récupération instantanée, pas de minijeu ni d'animation
        -- `processing.coords` sert juste à placer le PNJ/blip ; le boucher transforme lui-même à la vente, pas de bouton "Traiter" séparé (voir `multiSellItems`).
        processing = {
            coords = vector3(-42.59, -1474.73, 31.93), -- boucherie
        },
        processingNpc = {
            model   = 'a_m_m_hillbilly_01', -- à ajuster si un autre modèle convient mieux
            heading = 0.0, -- orientation approximative, à ajuster en jeu
        },
        -- Vente directe : chaque carcasse est découpée en quantités fixes selon l'espèce (garanti, pas aléatoire), alimente aussi la boutique publique (`shopItem`).
        multiSellItems = {
            {
                rawItem = 'carcasse_cerf',
                outputs = {
                    { item = 'steak_gibier',    amount = 5, price = 6, shopItem = 'steak_gibier',    buyPrice = 10 },
                    { item = 'graisse_animale', amount = 5, price = 2, shopItem = 'graisse_animale', buyPrice = 4 },
                    { item = 'tripes',          amount = 1, price = 3, shopItem = 'tripes',          buyPrice = 5 },
                },
            },
            {
                rawItem = 'carcasse_porc',
                outputs = {
                    { item = 'steak_gibier',    amount = 5, price = 6, shopItem = 'steak_gibier',    buyPrice = 10 },
                    { item = 'graisse_animale', amount = 4, price = 2, shopItem = 'graisse_animale', buyPrice = 4 },
                    { item = 'tripes',          amount = 1, price = 3, shopItem = 'tripes',          buyPrice = 5 },
                    { item = 'sang',            amount = 1, price = 1, shopItem = 'sang',            buyPrice = 2 },
                },
            },
            {
                rawItem = 'carcasse_lapin',
                outputs = {
                    { item = 'steak_gibier',    amount = 2, price = 6, shopItem = 'steak_gibier',    buyPrice = 10 },
                    { item = 'graisse_animale', amount = 1, price = 2, shopItem = 'graisse_animale', buyPrice = 4 },
                    { item = 'abats',           amount = 1, price = 3, shopItem = 'abats',           buyPrice = 5 },
                },
            },
            {
                rawItem = 'carcasse_sanglier',
                outputs = {
                    { item = 'steak_gibier',    amount = 8, price = 6, shopItem = 'steak_gibier',    buyPrice = 10 },
                    { item = 'graisse_animale', amount = 8, price = 2, shopItem = 'graisse_animale', buyPrice = 4 },
                    { item = 'tripes',          amount = 1, price = 3, shopItem = 'tripes',          buyPrice = 5 },
                },
            },
            -- Ni coyote ni cougar ici : sans `rawItem` leur carcasse n'est jamais revendable, seule leur peau se monnaie au receleur.
            {
                rawItem = 'carcasse_oiseau',
                outputs = {
                    { item = 'steak_gibier', amount = 2, price = 6, shopItem = 'steak_gibier', buyPrice = 10 },
                },
            },
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

-- Animaux ambiants du jeu trop rares pour certaines espèces (porc, oiseaux) : on peuple nous-mêmes des zones dédiées via `spawnZones` sur chaque entrée de `species`.
-- count = nombre max entretenu dans la zone, compté sur TOUS les joueurs à proximité (pas de sur-spawn si plusieurs chasseurs se croisent).
Config.Farm.HuntSpawn = {
    checkInterval = 15000, -- ms entre deux passes de peuplement des zones
    triggerRadius = 150.0, -- distance joueur → zone en dessous de laquelle elle est peuplée

    -- Oiseaux (`ambient` sur une espèce) : pas de zone fixe, peuplement autour du joueur avec filtre de biome (`requiresWater`/`ruralOnly`).
    ambientNearbyRadius = 120.0, -- rayon dans lequel on compte les individus déjà présents (vs `ambient.maxNearby`)
    ambientSpawnMin     = 40.0,  -- distance minimum au joueur pour l'apparition (jamais sous ses yeux)
    ambientSpawnMax     = 90.0,  -- distance maximum au joueur pour l'apparition (reste dans le champ de vision/streaming)
}

Config.Farm.NodeBlipScale       = 0.55
Config.Farm.ProcessingBlipScale = 0.85
