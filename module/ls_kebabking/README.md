# ls_kebabking

Restaurant **Kebab King** pour le framework **LSLegacy** (job `kebabking`).

Ressource **totalement autonome** : elle ne dépend d'aucune autre ressource
restaurant (`ls_burgershot`, `ls_aldentes`). Si l'une d'elles est arrêtée,
`ls_kebabking` continue de fonctionner normalement, et inversement.

## Dépendances

- `lslegacy` (framework — jobs, service, inventaire, argent, facturation)
- `ox_lib`
- `ox_target`

## Installation

1. Placer le dossier `ls_kebabking/` dans `resources/`.
2. Ajouter `ensure ls_kebabking` dans `server.cfg` (après `ensure lslegacy`,
   `ensure ox_lib` et `ensure ox_target`).
3. Les images d'items ont déjà été copiées dans
   `lslegacy/inventory/html/img/items/` au moment de la création de cette
   ressource. Si vous modifiez une image dans `images/`, recopiez-la
   manuellement au même endroit (voir la note dans `fxmanifest.lua`).
4. **Recalibrer les coordonnées restantes si besoin.** La plupart des points
   ont été relevés en jeu dans `tstudio_kebabking`. Avec `KKConfig.Debug = true` :
   - `/coords` en regardant un point précis copie
     `coords = vec3(...), rotation = ...` dans le presse-papier ;
   - `/stations` liste toutes les stations/stockages configurés en
     console et affiche votre job/grade/service détectés ;
   - des marqueurs au sol s'affichent à proximité de chaque point configuré.
   Recopiez les valeurs ajustées dans `config/config.lua`, puis repassez
   `KKConfig.Debug` à `false`.

## Architecture

```
ls_kebabking/
├── config/
│   ├── config.lua   -- job, coordonnées, stations, stockages, plateaux, caisse, animations,
│   │                    KKConfig.SauceChoices (liste blanche des sauces au choix)
│   ├── items.lua    -- items du restaurant (poussés dans le registre LSLegacy)
│   └── recipes.lua  -- recettes, avec `options.sauce` pour les recettes à choix de sauce
├── shared/utils.lua
├── client/ (main, craft, storage, cash, target)
├── server/ (main, craft, storage, cash)
├── images/            -- icônes PNG 512x512 transparentes (une par item)
└── fxmanifest.lua
```

## Broche à kebab

Trois temps sur deux stations : on monte la broche (item transportable
`kebab_spit`, comme un pot de sauce) à la station **Montage de la broche**
(`spit_build`) ; on la pose sur le tournebroche à la station **Broche à
kebab** (`spit_place`) — l'item quitte alors l'inventaire et devient un état
partagé de la station (`KK.Spit` dans `server/main.lua`) ; n'importe quel
employé en service peut ensuite venir la couper (`spit_cut`, répétable),
pas seulement celui qui l'a posée.

```
kebab_meat_raw x20 + spices x5  --(spit_mount, 20s, à spit_build)-->  item kebab_spit (10 utilisations)
kebab_spit                      --(spit_place, 4s, à spit)-->        broche posée (état partagé, 10 utilisations)
broche posée                    --(spit_cut, 3s, répétable, à spit)--> kebab_meat_cooked x2 à chaque fois
```

Une fois les 10 utilisations épuisées, la broche redevient vide : il faut en
monter et en poser une nouvelle. Impossible de poser une broche tant qu'une
autre est déjà en place.

## Pots de sauce

Les 8 sauces (`sauce_ketchup`, `sauce_mayo`, `sauce_bbq`, `sauce_harissa`,
`sauce_white`, `sauce_samurai`, `sauce_algerian`, `sauce_cheese`) ne
produisent plus des doses individuelles : elles fabriquent un **pot**
(`KKConfig.Pots`, ex. `pot_ketchup`), un item unique (`unique = true`
dans `config/items.lua`) qui embarque `KKConfig.PotUses` (20) utilisations
dans son propre `data.uses`.

- `server/craft.lua` clone `{ uses = ... }` dans une nouvelle table à
  chaque fabrication, jamais la table de la recette elle-même — sinon tous
  les pots issus de la même recette partageraient le même compteur.
- `server/pots.lua` enregistre chaque pot via
  `LSLegacy.RegisterUsableItem` : le bouton « Utiliser » de l'inventaire
  relit l'instance authoritative côté serveur (jamais le `data` envoyé par
  le client), dispense 1 sauce (`Core:craftTransaction`), décrémente
  `data.uses` et met à jour le libellé (`Pot de ketchup (12 utilisations)`),
  puis retire le pot une fois à 0.
- Certaines recettes de pot consomment des sauces déjà dispensées d'un
  autre pot (ex. la sauce blanche a besoin de 5 `sauce_mayo`) : il faut
  donc garder un pot de mayonnaise ouvert avant de préparer la sauce
  blanche, samouraï ou algérienne.

## Choix de la sauce à l'assemblage

Seules certaines recettes de montage (`Kebab classique`, `Galette kebab`,
`Chicken kebab`, `Tacos` 1 et 2 viandes) portent un champ
`options.sauce = { count = 1 }` — l'Assiette Kebab, le Sandwich falafel et
L'Americain n'en ont pas. Côté client, un second menu ox_lib
(`KK.OpenSauceMenu`) propose les sauces de `KKConfig.SauceChoices` avant de
lancer la fabrication. Le choix envoyé au serveur (`{ sauce = 'sauce_...' }`)
est **revalidé contre cette même liste blanche** dans
`server/craft.lua` (`ValidateSauce`) — un client modifié ne peut donc pas
injecter un nom d'item arbitraire à la place d'une sauce. La sauce choisie
est consommée comme un ingrédient normal, et son nom est ajouté au libellé
du plat fini.

## Boissons — achetées, pas préparées

Les sodas (`water`, `cola`, `sprunk`, `otang` — sans préfixe, partagés avec
`ls_burgershot`) ne se préparent pas et n'ont aucune recette dans
`KKConfig.Recipes` : elles sont achetées puis revendues telles quelles. Le
restaurant n'a donc aucune station ni recette de boisson — seul le
stockage `KKConfig.Storages.drinks` (« Stock boissons ») existe, pour
gérer le réapprovisionnement/la revente.

## Sécurité

Identique au principe des deux autres restaurants : le client envoie
uniquement `stationId` + `recipeId` (+ le choix de sauce le cas échéant),
jamais l'item produit. Le serveur revérifie fréquence, arguments, cohérence
recette/station, validité du choix de sauce, job `kebabking` + grade,
service actif, distance réelle, cadence de fabrication, puis exécute une
transaction atomique (ingrédients + sauce retirés, résultat donné en un seul
appel, avec vérification du poids).

Les stockages et plateaux sont des `DataStore` LSLegacy préfixés
`ls_kebabking_` : la garde d'accès n'autorise que ce préfixe, avec
vérification job/service/distance à chaque dépôt ou retrait — ni Burger
Shot ni Aldente's ne peuvent y accéder, et Kebab King ne peut pas toucher à
leurs stocks.

## Péremption des aliments

Gérée par `module/foodapi` du framework :

- Frigo/congélateur **professionnel** (`cold = 'pro'`) : péremption figée.
- Sorti du frigo pro : **5 heures** avant péremption.
- Frigo **domestique** (logement joueur) : péremption ~9,6× plus lente
  (équivalent 48h), sans jamais repartir de zéro. Le temps restant s'affiche
  au survol dans l'inventaire.

## Prise de service (MDT)

Pas de pointeuse physique : la prise/fin de service se fait depuis le
tableau de bord du **MDT** (tablette `tablette_mdt`, comme Red's Tunershop),
onglet **Tableau de bord**. Un employé `kebabking` y trouve aussi les
onglets **Effectifs** (qui est en service) et **Organisation** (grades,
pôles Cuisine/Salle/Gestion) — déclarés dans
`lslegacy/module/ls_kebabking/config_mdt.lua`.

Câblage technique (voir `client/main.lua` et `server/main.lua`) :

- Le job `kebabking` et sa grille de grades (0 Stagiaire → 4 Gérant) sont
  enregistrés dans le Core au démarrage via `Core:registerJob(...)`
  (`module/foodapi`) — sans ça, le job n'existerait pour aucune fonction du
  framework (`/setjob`, sélecteur de job de l'adminmenu, etc.).
- Le bouton « Prise de service » du MDT appelle `LSLegacy.MDT.DutyToggles`
  pour les jobs internes au Core (police, atelier…) ; comme `ls_kebabking`
  est une ressource séparée, il expose plutôt deux exports (`toggleDuty`,
  `isOnDuty`) et s'enregistre par son NOM de ressource via
  `exports['lslegacy']:registerClientDuty('kebabking')` — jamais de
  fonction Lua passée directement entre ressources.
- Côté serveur, la présence dans l'onglet **Effectifs** passe par le même
  principe : `Core:registerDutyChecker('kebabking')` + export `isOnDuty(src)`.

Sans job `kebabking` + service actif (MDT), toute interaction avec une
station, un stockage ou la caisse est refusée côté serveur.

## Facturation

Réutilise le menu de paiement du module `bank` de LSLegacy via
`module/foodapi` (espèces ou carte). Le règlement alimente le coffre de
l'entreprise, accessible aux employés gradés (`KKConfig.Cash.safeMinGrade`).

## Items créés

Convention : plus aucun item n'est préfixé. Depuis la fusion des trois
restos dans `lslegacy` (voir plus haut), ils partagent le même registre
`Config.Items` — chaque item n'est défini que dans UN SEUL des trois
`items.lua` (marqué « partagé » ci-dessous quand ce n'est pas celui-ci), les
autres se contentant d'y faire référence dans leurs recettes sans le
redéclarer.

### Ingrédients

| Item | Libellé | Image |
|---|---|---|
| `kebab_meat_raw` | Viande de veau crue | `images/kebab_meat_raw.png` |
| `ground_steak_raw` | Steak haché cru | `images/ground_steak_raw.png` |
| `chickpea` | Pois chiches (sans préfixe, voir note ci-dessus) | `images/chickpea.png` |
| `salad` | Salade (sans préfixe, partagé — voir `ls_burgershot`) | `images/salad.png` |
| `tomato` | Tomate (sans préfixe, partagé — voir `ls_burgershot`) | `images/tomato.png` |
| `onion` | Oignon (sans préfixe, partagé — voir `ls_burgershot`) | `images/onion.png` |
| `potato` | Pomme de terre (sans préfixe, partagé — voir `ls_burgershot`) | `images/potato.png` |
| `cheese` | Fromage (partagé — utilisé aussi par `ls_burgershot`) | `images/cheese.png` |
| `milk` | Lait (partagé — voir `ls_burgershot`) | `images/milk.png` |
| `yogurt` | Yaourt | `images/yogurt.png` |
| `egg` | Œuf (partagé — voir `ls_aldentes`) | `images/egg.png` |
| `oil` | Huile | `images/oil.png` |
| `spices` | Épices | `images/spices.png` |
| `herbs` | Herbes fraîches (partagé — utilisé aussi par `ls_aldentes`) | `images/herbs.png` |
| `harissa_pepper` | Piments | `images/harissa_pepper.png` |
| `sugar` | Sucre (partagé — voir `ls_aldentes`) | `images/sugar.png` |
| `cup` | Gobelet vide (partagé — sert à l'Ayran) | `images/cup.png` |
| `flour` | Farine (partagé — utilisé aussi par `ls_aldentes`) | `images/flour.png` |
| `salt` | Sel | `images/salt.png` |
| `wheat` | Blé | `images/wheat.png` |
| `vinegar` | Vinaigre | `images/vinegar.png` |
| `honey` | Miel | `images/honey.png` |
| `garlic` | Ail (partagé — voir `ls_aldentes`) | `images/garlic.png` |
| `cream` | Crème (partagé — utilisé aussi par `ls_aldentes`) | `images/cream.png` |
| `water_glass` | Verre d'eau (station **Point d'eau**, gratuit) | `images/water_glass.png` |

### Produits préparés

| Item | Libellé | Image |
|---|---|---|
| `bread_pita` | Pain pita (fabriqué) | `images/bread_pita.png` |
| `tortilla` | Tortilla (fabriquée) | `images/tortilla.png` |
| `salad_cut` | Feuille de salade (partagé — utilisé aussi par `ls_burgershot`) | `images/salad_cut.png` |
| `tomato_slice` | Tranche de tomate (partagé — voir `ls_burgershot`) | `images/tomato_slice.png` |
| `onion_slice` | Tranche d'oignon (partagé — voir `ls_burgershot`) | `images/onion_slice.png` |
| `potato_cut` | Frites crues (partagé — voir `ls_burgershot`) | `images/potato_cut.png` |
| `falafel_mix` | Pâte à falafel, crue (sans préfixe, voir note ci-dessus) | `images/falafel_mix.png` |

### Cuissons

| Item | Libellé | Image |
|---|---|---|
| `kebab_meat_cooked` | Viande de veau cuite | `images/kebab_meat_cooked.png` |
| `ground_steak_cooked` | Steak haché cuit | `images/ground_steak_cooked.png` |
| `kebab_spit` | Broche montée (unique, 10 utilisations) | `images/kebab_spit.png` |

### Accompagnements

| Item | Libellé | Image |
|---|---|---|
| `bulgur` | Boulgour | `images/bulgur.png` |
| `falafel_cooked` | Boulettes de falafel frites (sans préfixe, voir note ci-dessus) | `images/falafel_cooked.png` |

### Pots de sauce (20 utilisations, item unique)

| Item | Libellé | Image |
|---|---|---|
| `pot_ketchup` | Pot de ketchup | `images/pot_ketchup.png` |
| `pot_mayo` | Pot de mayonnaise | `images/pot_mayo.png` |
| `pot_bbq` | Pot de sauce barbecue | `images/pot_bbq.png` |
| `pot_harissa` | Pot de harissa | `images/pot_harissa.png` |
| `pot_white` | Pot de sauce blanche | `images/pot_white.png` |
| `pot_samurai` | Pot de sauce samouraï | `images/pot_samurai.png` |
| `pot_algerian` | Pot de sauce algérienne | `images/pot_algerian.png` |
| `pot_cheese` | Pot de sauce fromagère | `images/pot_cheese.png` |

### Sauces (dispensées par un pot)

| Item | Libellé | Image |
|---|---|---|
| `sauce_mayo` | Mayonnaise | `images/sauce_mayo.png` |
| `sauce_ketchup` | Ketchup | `images/sauce_ketchup.png` |
| `sauce_white` | Sauce blanche | `images/sauce_white.png` |
| `sauce_samurai` | Sauce samouraï | `images/sauce_samurai.png` |
| `sauce_algerian` | Sauce algérienne | `images/sauce_algerian.png` |
| `sauce_harissa` | Harissa | `images/sauce_harissa.png` |
| `sauce_bbq` | Sauce barbecue | `images/sauce_bbq.png` |
| `cheese_sauce` | Sauce fromagère | `images/cheese_sauce.png` |

### Plats

| Item | Libellé | Image |
|---|---|---|
| `kebab` | Kebab classique | `images/kebab.png` |
| `kebab_galette` | Galette kebab | `images/kebab_galette.png` |
| `chicken_kebab` | Chicken kebab | `images/chicken_kebab.png` |
| `tacos_1meat` | Tacos une viande | `images/tacos_1meat.png` |
| `tacos_2meat` | Tacos deux viandes | `images/tacos_2meat.png` |
| `kebab_plate` | Assiette Kebab | `images/kebab_plate.png` |
| `falafel_sandwich` | Sandwich falafel | `images/falafel_sandwich.png` |
| `americain` | L'Americain | `images/americain.png` |

### Boissons

Eau/Cola/Sprunk/O'tang sont **achetées puis revendues telles quelles** —
aucune station ni recette de boisson dans ce restaurant.

| Item | Libellé | Image |
|---|---|---|
| `water` | Eau (achetée, sans préfixe, partagé — voir `ls_burgershot`) | `images/water.png` |
| `cola` | Cola (achetée, sans préfixe, partagé — voir `ls_burgershot`) | `images/cola.png` |
| `sprunk` | Sprunk (achetée, sans préfixe, partagé — voir `ls_burgershot`) | `images/sprunk.png` |
| `otang` | O'tang (achetée, sans préfixe, partagé — voir `ls_burgershot`) | `images/otang.png` |
