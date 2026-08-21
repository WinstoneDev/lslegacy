-- ═══════════════════════════════════════════════════════════════════
--  MODULE FARM — Configuration principale
--  Activités de récolte indépendantes (pas de job/grade requis)
--  Circuit complet : récolte → traitement → revente
-- ═══════════════════════════════════════════════════════════════════

Config.Farm = {}

-- ── Notification (même système que les autres métiers) ────────────────
Config.Farm.NotifyEvent = 'brutal_notify:SendAlert'

-- ── Minijeu générique (barre + appui touche, identique à Mécanicien) ──
-- Réutilisé pour la récolte ET le traitement.
Config.Farm.Minigame = {
    rounds        = 3,
    roundDuration = 1600, -- ms par aller-retour de la barre
    zoneSize      = 0.15, -- largeur de la zone de réussite (0-1)
    requiredHits  = 2,    -- sur `rounds`
}

-- ── Activités ─────────────────────────────────────────────────────────
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
        -- Présent = la récolte se fait par une animation de coup de hache en
        -- boucle pendant `loopDuration` ms, puis `yieldAmount` bois d'un coup
        -- à la fin — au lieu du minijeu barre/touche.
        -- TODO : vérifier en jeu que `clip` correspond bien à un mouvement
        -- de coup de hache ; ajuster sinon (dict/clip GTA V non testés ici).
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
        -- Bois brut vendable directement (sans passer par la scierie), en plus
        -- de la planche transformée — alimente aussi la boutique publique.
        -- Prix volontairement bas (< 4$, l'équivalent par bois obtenu via la
        -- scierie : 1 bois → 2 planches à 2$ = 4$) pour que la transformation
        -- reste toujours plus rentable que la vente brute.
        directSellItems = {
            { item = 'bois', price = 1, shopItem = 'bois', buyPrice = 2 },
        },
        -- Calibré pour ~750$/h (référence salaire serveur, cf. rééquilibrage
        -- véhicules). Ratio 1 bois → 2 planches (rendement matière ×10 par
        -- rapport à l'ancien 5→1) : débit estimé ~400 planches/h en jeu actif
        -- (4.5s de récolte + 4.5s de traitement/trajet amorti par planche,
        -- contre 27s avant) → prix baissé en conséquence (750/400 ≈ 1.9$).
        -- À ajuster après test réel en jeu, l'estimation reste approximative.
        processedItems = {
            { item = 'planche', weight = 1, price = 2, shopItem = 'planche', buyPrice = 3 },
        },
    },
    mineur = {
        label         = 'Mineur',
        tool          = 'pioche',
        rawItem       = 'minerai', -- seul item consommé par la fonderie (traitement → tous les minerai_XXX)
        -- À chaque coup de pioche, tirage pondéré parmi cette liste (5 unités
        -- de l'item tiré, cf. gatherAnim.yieldAmount). Seuls `minerai` et
        -- `tas_pierre` se trouvent directement sur les rochers — tous les
        -- minerai_XXX (métaux ET charbon/soufre/etc.) viennent uniquement de
        -- la fonte du `minerai` à la fonderie (voir `processedItems`).
        gatherYields = {
            { item = 'minerai',    weight = 1 },
            { item = 'tas_pierre', weight = 1 },
        },
        -- Items bruts revendables directement (pas de passage par la
        -- fonderie), au même point de vente que les métaux.
        -- `shopItem`/`buyPrice` : en plus du cash immédiat au vendeur, alimente
        -- le stock d'une boutique publique (`shopItem`, sans le préfixe
        -- minerai_/tas_) que N'IMPORTE QUEL joueur peut ensuite acheter au
        -- même endroit — pattern stock inspiré de module/ltd/server/stock.lua.
        directSellItems = {
            -- Prix ×7 (2026-07-20) suite au vrai temps de trajet mesuré en jeu
            -- (mine→fonderie 3min39, + fonderie→vente comparable) : structure
            -- à 3 lieux éloignés bien plus coûteuse en temps que le bûcheron,
            -- compensée par des prix plus élevés pour viser les mêmes ~750$/h.
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
        -- Pas de vraie arme "pioche" dans GTA V (contrairement à la hachette),
        -- donc prop manuel attaché en main pendant l'animation.
        -- Set anim/os/position repris tel quel d'un script de minage public
        -- (jim-mining-esx, Mycroft-Studios/jim-mining-esx/client.lua) qui
        -- utilise exactement prop_tool_pickaxe — cohérent et déjà testé,
        -- plutôt que des morceaux dépareillés devinés à l'aveugle.
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
        -- Anim du minijeu de TRAITEMENT (fonderie) — geste de versage, distinct
        -- du coup de pioche de la récolte. Reprise de module/pompe/config.lua
        -- (elle-même issue tel quel du script public ox_fuel, donc validée en
        -- jeu) : arrosoir/versage. Pas de prop ici (le pistolet à essence de
        -- pompe ne correspond pas à une fonderie), juste le geste.
        processAnim = {
            dict = 'timetable@gardener@filling_can',
            clip = 'gar_ig_5_filling_can',
        },
        processing = {
            coords       = vector3(1108.40, -2007.23, 30.93), -- fonderie
            inputPerUnit = 5, -- minerai consommé
            outputPerUnit = 1, -- métal produit (tiré aléatoirement ci-dessous)
        },
        -- Vente regroupée avec le bûcheron au même endroit (Sandy Shores) —
        -- assignée après coup, cf. fin du fichier (Config.Farm.Activities
        -- n'existe pas encore pendant la construction de cette table).
        -- Fonte du minerai en résultat aléatoire (pondéré par rareté) : tous
        -- les minerai_XXX (métaux ET charbon/soufre/salpêtre/plomb/zinc/acier/
        -- argile) sortent d'ici, jamais du loot direct sur les rochers.
        -- Diamant : trouvaille très rare (1 chance sur 1000), belle somme
        -- d'un coup pour casser la routine.
        -- `shopItem`/`buyPrice` : la vente alimente aussi le stock boutique
        -- (sans le préfixe minerai_) achetable par n'importe quel joueur.
        -- Diamant exclu (déjà un item "final", pas de forme boutique séparée).
        -- Prix ×7 (2026-07-20), voir commentaire directSellItems ci-dessus.
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
        -- Une carcasse différente PAR ESPÈCE — la boucherie ne découpe pas
        -- la même chose selon l'animal tué (un cerf donne bien plus qu'un
        -- lapin). `rawItem` = l'item rendu au joueur au dépeçage manuel [E]
        -- sur le cadavre, `model` sert au ciblage ox_target et à identifier
        -- l'espèce tuée côté serveur (jamais décidé par le client).
        -- `peauItem`/`peauPrice` (braconnage, illégal) : prélevable via un
        -- bouton ox_target à PART ("Prélever la peau", ne retire pas le
        -- cadavre), affiché uniquement couteau (`poaching.tool`) en main —
        -- voir le bloc `poaching` plus bas. Uniquement présent sur coyote et
        -- cougar (seules espèces braconnables demandées) ; les autres n'ont
        -- pas de peau exploitable.
        -- Plusieurs modèles d'oiseaux partagent la même carcasse/sortie
        -- (`carcasse_oiseau`) — aucune raison de les distinguer en boutique.
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
            -- Coyote : pas de `rawItem` — sa viande ne se récupère pas, seule
            -- sa peau a de la valeur (braconnage). Sans `rawItem`, l'option
            -- "Dépecer"/"Ramasser le cadavre" n'apparaît pas du tout sur
            -- l'espèce, il ne reste que "Prélever la peau".
            { model = 'a_c_coyote',      label = 'Coyote',
              peauItem = 'peau_coyote', peauPrice = 20,
              spawnZones = {
                  { coords = vector3(2048.33, 2821.23, 50.37), radius = 150.0, count = 12 },
              },
            },
            -- Cougar (`a_c_mtlion` = mountain lion) : comme le coyote, pas de
            -- `rawItem` — EXCLUSIVEMENT pour le braconnage, sa carcasse ne se
            -- récupère pas, seule sa peau a de la valeur, au receleur.
            -- Fait partie de la population ambiante vanilla (montagnes/Grand
            -- Senora) — pas de zone dédiée nécessaire, une peut être ajoutée
            -- en plus si besoin de plus de densité.
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
            -- Oiseaux : pas de zone fixe, `ambient = true` fait apparaître
            -- l'espèce autour du joueur où qu'il soit sur la carte — avec
            -- un filtre de biome simple (`requiresWater`/`ruralOnly`) pour
            -- rester logique (pas de mouette en plein désert, pas de poule
            -- en pleine ville). Voir `Config.Farm.HuntSpawn.ambient*`.
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
        -- Récupération instantanée à l'interaction : pas de minijeu ni
        -- d'animation, juste "il interagit, il récupère".
        instantGather = true,
        -- `processing.coords` sert uniquement à placer le PNJ/blip ici — le
        -- boucher fait la transformation lui-même à la vente, pas de bouton
        -- "Traiter" séparé pour le joueur (voir `multiSellItems`).
        processing = {
            coords = vector3(-42.59, -1474.73, 31.93), -- boucherie
        },
        -- PNJ boucher — l'option "Vendre" s'attache à lui (ox_target:
        -- addLocalEntity) au lieu d'une zone au sol.
        processingNpc = {
            model   = 'a_m_m_hillbilly_01', -- à ajuster si un autre modèle convient mieux
            heading = 0.0, -- orientation approximative, à ajuster en jeu
        },
        -- Vente directe des carcasses : le boucher (le serveur) découpe
        -- CHAQUE carcasse vendue en quantités fixes selon l'espèce (garanti,
        -- pas aléatoire) — et alimente la boutique publique avec (`shopItem`),
        -- sans que le joueur ne voie jamais ces items dans son propre
        -- inventaire. Barème donné par le joueur, un item = un `amount` fixe
        -- par carcasse (les items sans `amount` explicite sont garantis x1).
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
            -- Ni coyote ni cougar ici : sans `rawItem`, leur carcasse n'est
            -- jamais récupérable ni revendable — seule leur peau se monnaie,
            -- au receleur.
            {
                rawItem = 'carcasse_oiseau',
                outputs = {
                    { item = 'steak_gibier', amount = 2, price = 6, shopItem = 'steak_gibier', buyPrice = 10 },
                },
            },
        },
        -- Braconnage (illégal) : bouton ox_target à part ("Prélever la
        -- peau", `farm:requestPoach`), affiché seulement si le joueur a
        -- `tool` en MAIN et que l'espèce ciblée a un `peauItem` — le cadavre
        -- n'est pas retiré, le dépeçage/ramassage normal reste possible en
        -- plus. Chaque prélèvement a un risque d'alerte police. La peau ne
        -- passe jamais par la boutique publique (`multiSellItems`),
        -- uniquement par le receleur (`fenceNpc`/`fenceCoords`, à placer).
        poaching = {
            tool              = 'weapon_knife',
            policeAlertChance = 0.15,
            fenceCoords = vector3(220.46, 112.29, 93.48),
            fenceNpc    = { model = 'g_m_y_strpunk_02', heading = 252.28 }, -- modèle discret par défaut, à ajuster si besoin
        },
    },
    -- Culture illégale (weed/coke) : à réintroduire plus tard.
    -- Le serveur (server/main.lua) gère déjà `dirty`/`illegal`/`policeAlertChance`
    -- de façon générique, il suffira d'ajouter une entrée ici avec son propre
    -- circuit de revente (recel plutôt que point de vente légal).
}

-- Vente du mineur regroupée avec celle du bûcheron, au même endroit (Sandy
-- Shores) — assigné ici, après construction complète de Config.Farm.Activities.
Config.Farm.Activities.mineur.sellPoint = Config.Farm.Activities.bucheron.sellPoint

-- ── Station de compactage "sac de pierre" ──────────────────────────────
-- Au même endroit que le point de vente du bois (bûcheron) : compacte
-- 20 pierres (item du mineur) en 1 sac de pierres, plus léger à transporter
-- et vendable au même prix cumulé (pas d'exploit économique, juste du confort).
Config.Farm.StoneBagStation = {
    coords      = Config.Farm.Activities.bucheron.sellPoint,
    inputItem   = 'pierre',
    inputAmount = 20,
    outputItem  = 'sac_pierre',
}

-- ── Point d'achat de la boutique minéraux (séparé du point de vente mineur) ──
Config.Farm.ShopBuyPoint = vector3(2747.25, 3472.97, 55.67)

-- ── Zones ox_target ───────────────────────────────────────────────────
Config.Farm.ZoneSize     = vector3(1.2, 1.2, 2.0)
Config.Farm.ZoneDistance = 2.0

-- ── Zones de spawn (chasseur) ───────────────────────────────────────────
-- Les animaux ambiants du jeu sont trop rares/aléatoires pour certaines
-- espèces (porc, oiseaux) — on peuple nous-mêmes des zones dédiées, une
-- espèce par zone. `spawnZones` se définit directement sur chaque entrée
-- de `species` (voir `chasseur.species` ci-dessus) :
--   spawnZones = { { coords = vector3(...), radius = 60.0, count = 3 }, ... }
-- radius : rayon (m) où les individus apparaissent autour de `coords`.
-- count  : nombre d'individus vivants maximum entretenu dans cette zone
--          (compté sur TOUS les joueurs à proximité, pas par joueur — pas
--          de sur-spawn si plusieurs chasseurs se retrouvent au même endroit).
Config.Farm.HuntSpawn = {
    checkInterval = 15000, -- ms entre deux passes de peuplement des zones
    triggerRadius = 150.0, -- distance joueur → zone en dessous de laquelle elle est peuplée

    -- ── Oiseaux (`ambient = {...}` sur une espèce, voir `chasseur.species`) ──
    -- Pas de zone fixe : on peuple autour du joueur où qu'il soit, avec un
    -- filtre de biome simple par espèce (`requiresWater`/`ruralOnly`).
    ambientNearbyRadius = 120.0, -- rayon dans lequel on compte les individus déjà présents (vs `ambient.maxNearby`)
    ambientSpawnMin     = 40.0,  -- distance minimum au joueur pour l'apparition (jamais sous ses yeux)
    ambientSpawnMax     = 90.0,  -- distance maximum au joueur pour l'apparition (reste dans le champ de vision/streaming)
}

-- ── Blips carte ─────────────────────────────────────────────────────────
-- Générés dynamiquement par client/main.lua : un petit blip par nœud de
-- récolte + un blip plus visible sur la station de traitement/revente,
-- avec le sprite/couleur défini par activité ci-dessus.
Config.Farm.NodeBlipScale       = 0.55
Config.Farm.ProcessingBlipScale = 0.85
