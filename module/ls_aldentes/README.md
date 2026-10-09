# ls_aldentes

Restaurant italien **Aldente's** pour le framework **LSLegacy** (job
`aldentes`). C'est volontairement **le plus poussé des trois** en cuisine :
eau → casserole → pâtes cuites → sauce préparée → dressage, et
pizza/lasagnes montées crues puis enfournées. Il est impossible de
fabriquer un plat directement à partir de pâtes crues.

Ressource **totalement autonome** : elle ne dépend d'aucune autre ressource
restaurant (`ls_burgershot`, `ls_kebabking`). Si l'une d'elles est arrêtée,
`ls_aldentes` continue de fonctionner normalement, et inversement.

## Dépendances

- `lslegacy` (framework — jobs, service, inventaire, argent, facturation)
- `ox_lib`
- `ox_target`

## Installation

1. Placer le dossier `ls_aldentes/` dans `resources/`.
2. Ajouter `ensure ls_aldentes` dans `server.cfg` (après `ensure lslegacy`,
   `ensure ox_lib` et `ensure ox_target`).
3. Les images d'items ont déjà été copiées dans
   `lslegacy/inventory/html/img/items/` au moment de la création de cette
   ressource. Si vous modifiez une image dans `images/`, recopiez-la
   manuellement au même endroit (voir la note dans `fxmanifest.lua`).
4. **Recalibrer les coordonnées.** Les positions dans `config/config.lua`
   ont été estimées à partir du MLO `tstudio_aldentes` sans accès à une
   session de jeu en direct. Avec `ALDConfig.Debug = true` :
   - `/coords` en regardant un point précis copie
     `coords = vec3(...), rotation = ...` dans le presse-papier ;
   - `/stations` liste toutes les stations/stockages configurés en
     console et affiche votre job/grade/service détectés ;
   - des marqueurs au sol s'affichent à proximité de chaque point configuré.
   Recopiez les valeurs ajustées dans `config/config.lua`, puis repassez
   `ALDConfig.Debug` à `false`.

## Architecture

```
ls_aldentes/
├── config/
│   ├── config.lua   -- job, coordonnées, stations, stockages, plateaux, caisse, animations
│   ├── items.lua    -- items du restaurant (poussés dans le registre LSLegacy)
│   └── recipes.lua  -- recettes (ingrédients -> résultats, station, durée, anim)
├── shared/utils.lua
├── client/ (main, craft, storage, cash, target)
├── server/ (main, craft, storage, cash)
├── images/            -- icônes PNG 512x512 transparentes (une par item)
└── fxmanifest.lua
```

Même organisation interne que `ls_burgershot` et `ls_kebabking` (choix
assumé — un peu de code similaire entre les trois plutôt qu'une
abstraction commune qui risquerait de mélanger les jobs), mais aucune
dépendance fonctionnelle entre elles.

## La cuisine Aldente's, en détail

```
Point d'eau            -> remplir une casserole
Plan de préparation     -> émincer légumes, râper parmesan, pétrir la pâte à pizza
Cuisson des pâtes       -> spaghetti/penne/tagliatelles/lasagnes CRUS -> CUITS (via casserole d'eau)
Plaques de cuisson       -> revenir la viande, faire tomber les épinards, béchamel
Préparation des sauces   -> tomate, bolognaise, carbonara, pesto, Alfredo
Plan à pizza             -> étaler un pâton, garnir à cru (Margherita, Regina, Pepperoni, 4 Formaggi, Calzone)
Four à pizza             -> cuit les pizzas ET les lasagnes montées à cru
Dressage                 -> assemble pâtes cuites + sauce + parmesan, ou monte les lasagnes avant cuisson
Desserts                 -> Tiramisu, Panna Cotta, Cannoli
Bar / boissons           -> eau, cola, Sprunk, O'tang, café
```

Aucune recette de plat de pâtes n'accepte des pâtes crues en ingrédient :
la station « Cuisson des pâtes » est un passage obligé. De même, une pizza
ou une lasagne ne peut pas être servie directement — elle doit d'abord être
montée crue puis passer par le four.

## Sécurité

Identique au principe des deux autres restaurants (voir `server/craft.lua`) :
le client envoie uniquement `stationId` + `recipeId`, jamais l'item produit.
Le serveur revérifie fréquence, arguments, cohérence recette/station, job
`aldentes` + grade, service actif, distance réelle, cadence de fabrication,
puis exécute une transaction atomique (ingrédients retirés + résultat donné
en un seul appel, avec vérification du poids).

Les stockages et plateaux sont des `DataStore` LSLegacy préfixés
`ls_aldentes_` : la garde d'accès n'autorise que ce préfixe, avec
vérification job/service/distance à chaque dépôt ou retrait — ni Burger
Shot ni Kebab King ne peuvent y accéder, et Aldente's ne peut pas toucher à
leurs stocks.

## Péremption des aliments

Gérée par `module/foodapi` du framework :

- Frigo/congélateur **professionnel** (`cold = 'pro'`) : péremption figée.
- Sorti du frigo pro : **5 heures** avant péremption.
- Frigo **domestique** (logement joueur) : péremption ~9,6× plus lente
  (équivalent 48h), sans jamais repartir de zéro si le plat a déjà entamé
  son délai de 5h. Le temps restant s'affiche au survol dans l'inventaire.

## Prise de service

Zone ox_target « Pointeuse » (`ALDConfig.Duty`). Sans job `aldentes` + service
actif, toute interaction avec une station, un stockage ou la caisse est
refusée côté serveur.

## Facturation

Réutilise le menu de paiement du module `bank` de LSLegacy via
`module/foodapi` (espèces ou carte). Le règlement alimente le coffre de
l'entreprise, accessible aux employés gradés (`ALDConfig.Cash.safeMinGrade`).

## Items créés

Convention : plus aucun item n'est préfixé. Les trois restos partagent le
même registre `Config.Items` depuis leur fusion dans `lslegacy` (voir plus
haut) — chaque item n'est défini que dans UN SEUL des trois `items.lua`
(marqué « partagé » ci-dessous quand ce n'est pas celui-ci : `egg`/`garlic`/
`sugar` sont définis ici, `tomato`/`onion`/`milk`/les sodas chez
`ls_burgershot`, `cream`/`herbs`/`flour` chez `ls_kebabking`), les autres se
contentant d'y faire référence dans leurs recettes.

### Ingrédients

| Item | Libellé | Image |
|---|---|---|
| `egg` | Œuf (partagé) | `images/egg.png` |
| `butter` | Beurre | `images/butter.png` |
| `milk` | Lait (partagé — voir `ls_burgershot`) | `images/milk.png` |
| `cream` | Crème fraîche (partagé — voir `ls_kebabking`) | `images/cream.png` |
| `sugar` | Sucre (partagé) | `images/sugar.png` |
| `vanilla` | Vanille | `images/vanilla.png` |
| `olive_oil` | Huile d'olive | `images/olive_oil.png` |
| `herbs` | Herbes italiennes (partagé — voir `ls_kebabking`) | `images/herbs.png` |
| `flour` | Farine (partagé — voir `ls_kebabking`) | `images/flour.png` |
| `spaghetti_raw` | Spaghetti crus | `images/spaghetti_raw.png` |
| `penne_raw` | Penne crus | `images/penne_raw.png` |
| `tagliatelle_raw` | Tagliatelles crues | `images/tagliatelle_raw.png` |
| `lasagne_raw` | Feuilles de lasagne crues | `images/lasagne_raw.png` |
| `tomato` | Tomate (partagé — voir `ls_burgershot`) | `images/tomato.png` |
| `onion` | Oignon (partagé — voir `ls_burgershot`) | `images/onion.png` |
| `garlic` | Ail (sans préfixe, partagé) | `images/garlic.png` |
| `basil` | Basilic | `images/basil.png` |
| `spinach` | Épinards | `images/spinach.png` |
| `mushroom` | Champignons | `images/mushroom.png` |
| `parmesan_block` | Meule de parmesan | `images/parmesan_block.png` |
| `mozzarella` | Mozzarella | `images/mozzarella.png` |
| `gorgonzola` | Gorgonzola | `images/gorgonzola.png` |
| `goat_cheese` | Chèvre | `images/goat_cheese.png` |
| `ricotta` | Ricotta | `images/ricotta.png` |
| `mascarpone` | Mascarpone | `images/mascarpone.png` |
| `guanciale` | Guanciale | `images/guanciale.png` |
| `ground_beef` | Viande hachée | `images/ground_beef.png` |
| `ham` | Jambon | `images/ham.png` |
| `pepperoni` | Pepperoni | `images/pepperoni.png` |
| `pot_empty` | Casserole vide | `images/pot_empty.png` |
| `pot_water` | Casserole d'eau | `images/pot_water.png` |
| `ladyfingers` | Biscuits à la cuillère | `images/ladyfingers.png` |
| `cannoli_shell` | Tube à cannoli | `images/cannoli_shell.png` |
| `coffee_beans` | Café en grains | `images/coffee_beans.png` |
| `glass` | Verre vide | `images/glass.png` |
| `syrup_cola` | Sirop cola (sans préfixe, partagé — voir `ls_burgershot`) | `images/syrup_cola.png` |
| `syrup_sprunk` | Sirop Sprunk (sans préfixe, partagé — voir `ls_burgershot`) | `images/syrup_sprunk.png` |
| `syrup_otang` | Sirop O'tang (sans préfixe, partagé — voir `ls_burgershot`) | `images/syrup_otang.png` |

### Produits préparés

| Item | Libellé | Image |
|---|---|---|
| `onion_chopped` | Oignon émincé | `images/onion_chopped.png` |
| `garlic_chopped` | Ail haché | `images/garlic_chopped.png` |
| `basil_chopped` | Basilic ciselé | `images/basil_chopped.png` |
| `tomato_diced` | Tomates concassées | `images/tomato_diced.png` |
| `guanciale_diced` | Guanciale taillé | `images/guanciale_diced.png` |
| `parmesan` | Parmesan râpé | `images/parmesan.png` |
| `pizza_dough` | Pâton à pizza | `images/pizza_dough.png` |
| `pizza_base` | Pâte à pizza étalée | `images/pizza_base.png` |
| `beef_cooked` | Viande hachée revenue | `images/beef_cooked.png` |
| `spinach_cooked` | Épinards fondus | `images/spinach_cooked.png` |
| `bechamel` | Béchamel | `images/bechamel.png` |

### Cuissons

| Item | Libellé | Image |
|---|---|---|
| `spaghetti_cooked` | Spaghetti cuits | `images/spaghetti_cooked.png` |
| `penne_cooked` | Penne cuits | `images/penne_cooked.png` |
| `tagliatelle_cooked` | Tagliatelles cuites | `images/tagliatelle_cooked.png` |
| `lasagne_cooked` | Feuilles de lasagne cuites | `images/lasagne_cooked.png` |

### Sauces

| Item | Libellé | Image |
|---|---|---|
| `tomato_sauce` | Sauce tomate | `images/tomato_sauce.png` |
| `sauce_bolognese` | Sauce bolognaise | `images/sauce_bolognese.png` |
| `sauce_carbonara` | Sauce carbonara | `images/sauce_carbonara.png` |
| `sauce_pesto` | Pesto | `images/sauce_pesto.png` |
| `sauce_alfredo` | Sauce Alfredo | `images/sauce_alfredo.png` |

### Crus (avant cuisson au four)

| Item | Libellé | Image |
|---|---|---|
| `pizza_margherita_raw` | Margherita crue | `images/pizza_margherita_raw.png` |
| `pizza_regina_raw` | Regina crue | `images/pizza_regina_raw.png` |
| `pizza_pepperoni_raw` | Pepperoni crue | `images/pizza_pepperoni_raw.png` |
| `pizza_quattro_formaggi_raw` | Quattro Formaggi crue | `images/pizza_quattro_formaggi_raw.png` |
| `calzone_raw` | Calzone cru | `images/calzone_raw.png` |
| `lasagne_bolognese_raw` | Lasagnes bolognaise crues | `images/lasagne_bolognese_raw.png` |
| `lasagne_chep_raw` | Lasagne chèvre-épinard crue | `images/lasagne_chep_raw.png` |

### Plats

| Item | Libellé | Image |
|---|---|---|
| `spaghetti_carbonara` | Spaghetti Carbonara | `images/spaghetti_carbonara.png` |
| `spaghetti_bolognese` | Spaghetti Bolognaise | `images/spaghetti_bolognese.png` |
| `penne_pesto` | Penne au Pesto | `images/penne_pesto.png` |
| `tagliatelle_alfredo` | Tagliatelles Alfredo | `images/tagliatelle_alfredo.png` |
| `lasagne_bolognese` | Lasagnes Bolognaise | `images/lasagne_bolognese.png` |
| `lasagne_chep` | Lasagne chèvre-épinard | `images/lasagne_chep.png` |
| `pizza_margherita` | Pizza Margherita | `images/pizza_margherita.png` |
| `pizza_regina` | Pizza Regina | `images/pizza_regina.png` |
| `pizza_pepperoni` | Pizza Pepperoni | `images/pizza_pepperoni.png` |
| `pizza_quattro_formaggi` | Pizza Quattro Formaggi | `images/pizza_quattro_formaggi.png` |
| `calzone` | Calzone | `images/calzone.png` |

### Boissons

| Item | Libellé | Image |
|---|---|---|
| `water` | Eau (sans préfixe, partagé — voir `ls_burgershot`) | `images/water.png` |
| `cola` | Cola (sans préfixe, partagé — voir `ls_burgershot`) | `images/cola.png` |
| `sprunk` | Sprunk (sans préfixe, partagé — voir `ls_burgershot`) | `images/sprunk.png` |
| `otang` | O'tang (sans préfixe, partagé — voir `ls_burgershot`) | `images/otang.png` |
| `coffee` | Café | `images/coffee.png` |

### Desserts

| Item | Libellé | Image |
|---|---|---|
| `tiramisu` | Tiramisu | `images/tiramisu.png` |
| `panna_cotta` | Panna Cotta | `images/panna_cotta.png` |
| `cannoli` | Cannoli | `images/cannoli.png` |
