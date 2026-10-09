# ls_burgershot

Restaurant **Burger Shot** pour le framework **LSLegacy** (job `burgershot`).

Ressource **totalement autonome** : elle ne dépend d'aucune autre ressource
restaurant (`ls_aldentes`, `ls_kebabking`). Si l'une d'elles est arrêtée,
`ls_burgershot` continue de fonctionner normalement, et inversement.

## Dépendances

- `lslegacy` (framework — jobs, service, inventaire, argent, facturation)
- `ox_lib`
- `ox_target`

## Installation

1. Placer le dossier `ls_burgershot/` dans `resources/`.
2. Ajouter `ensure ls_burgershot` dans `server.cfg` (après `ensure lslegacy`,
   `ensure ox_lib` et `ensure ox_target`).
3. Les images d'items ont déjà été copiées dans
   `lslegacy/inventory/html/img/items/` au moment de la création de cette
   ressource. Si vous modifiez une image dans `images/`, recopiez-la
   manuellement au même endroit (voir la note dans `fxmanifest.lua`).
4. **Recalibrer les coordonnées.** Les positions dans `config/config.lua`
   ont été estimées à partir du MLO `tstudio_burgershot` sans accès à une
   session de jeu en direct — elles sont donc plausibles mais pas garanties
   pixel-perfect. Avec `BSConfig.Debug = true` :
   - `/coords` en regardant un point précis copie
     `coords = vec3(...), rotation = ...` dans le presse-papier ;
   - `/stations` liste toutes les stations/stockages configurés en
     console et affiche votre job/grade/service détectés ;
   - des marqueurs au sol s'affichent à proximité de chaque point configuré.
   Recopiez les valeurs ajustées dans `config/config.lua`, puis repassez
   `BSConfig.Debug` à `false`.

## Architecture

```
ls_burgershot/
├── config/
│   ├── config.lua   -- job, coordonnées, stations, stockages, plateaux, caisse, animations
│   ├── items.lua    -- items du restaurant (poussés dans le registre LSLegacy)
│   └── recipes.lua  -- recettes (ingrédients -> résultats, station, durée, anim)
├── shared/
│   └── utils.lua    -- lecture de configuration (recettes, stations, plateaux)
├── client/
│   ├── main.lua      -- état local, service, blip, animations, debug
│   ├── craft.lua      -- menus de fabrication (ox_lib)
│   ├── storage.lua    -- ouverture des stockages/plateaux
│   ├── cash.lua        -- menu caisse (facturation, coffre)
│   └── target.lua      -- toutes les zones ox_target
├── server/
│   ├── main.lua      -- registre d'items, sécurité, service, logs
│   ├── craft.lua      -- validation + fabrication (transaction atomique)
│   ├── storage.lua    -- DataStores (garde d'accès stricte au job)
│   └── cash.lua        -- facturation via le module bank de LSLegacy
├── images/            -- icônes PNG 512x512 transparentes (une par item)
└── fxmanifest.lua
```

## Sécurité

Le client n'envoie jamais l'item produit ni sa quantité : uniquement un
`stationId` et un `recipeId` (voir `server/craft.lua`). Le serveur relit la
recette dans `config/recipes.lua` et vérifie, dans l'ordre :

1. Fréquence (anti-spam d'events, fenêtre glissante de 15 s)
2. Type des arguments reçus
3. Existence de la recette et cohérence recette ↔ station
4. Job `burgershot` + grade minimum requis
5. Service (duty) actif
6. Distance réelle jusqu'à la station (recalculée côté serveur)
7. Cadence (au moins 85 % de la durée de la recette entre deux fabrications)
8. Ingrédients disponibles + poids restant (transaction atomique côté
   framework, retire et donne en une seule fois)

Les stockages (réserve, frigo, congélateur, boissons) et les plateaux sont
des `DataStore` LSLegacy dont le nom est préfixé `ls_burgershot_` : la garde
d'accès (`LSLegacy.DataStoreGuard`, étendue via `module/foodapi`) refuse tout
accès dont le nom ne correspond pas à ce préfixe, et revérifie job/service/
distance à chaque dépôt ou retrait. Aucun autre job ne peut donc lire ou
modifier ces stocks, et `ls_burgershot` ne peut pas toucher à ceux d'un autre
restaurant.

## Péremption des aliments

Gérée par le module `foodapi` du framework (`lslegacy/module/foodapi/`) :

- Un plat en frigo/congélateur **professionnel** (`cold = 'pro'` dans
  `BSConfig.Storages`) ne se périme jamais.
- Sorti du frigo pro, un plat a **5 heures** avant péremption.
- Dans un frigo **domestique** (logement joueur), la péremption est
  **~9,6× plus lente** (budget équivalent à 48h), et ne repart jamais de
  zéro : le temps déjà écoulé hors du frigo reste décompté.
- Le temps restant s'affiche au survol de l'item dans l'inventaire.

## Prise de service

Uniquement via le tableau de bord du MDT (tablette, module/mdt) — plus de
pointeuse physique. Sans job `burgershot` +
service actif, toute interaction avec une station, un stockage ou la caisse
est refusée avec le message « Vous devez être en service pour utiliser cet
équipement. » — vérifié côté serveur, pas seulement côté client.

## Facturation

Réutilise le menu de paiement du module `bank` de LSLegacy (espèces ou
carte, plafond sans-contact, code PIN) via `module/foodapi`. Aucun système
d'argent n'est recréé. Le règlement encaissé alimente le coffre de
l'entreprise (`BSConfig.Cash.safeToCompany`), accessible aux employés gradés
(`BSConfig.Cash.safeMinGrade`).

## Items créés

Convention : plus aucun item n'est préfixé. Les trois restos partagent le
même registre `Config.Items` depuis leur fusion dans `lslegacy` (voir plus
haut) — chaque item n'est défini que dans UN SEUL des trois `items.lua`
(marqué « partagé » ci-dessous quand ce n'est pas celui-ci), les deux autres
se contentant d'y faire référence dans leurs recettes sans le redéclarer.

### Ingrédients

| Item | Libellé | Image |
|---|---|---|
| `bun` | Pain à burger | `images/bun.png` |
| `patty_raw` | Steak haché cru | `images/patty_raw.png` |
| `chicken_raw` | Filet de poulet cru | `images/chicken_raw.png` |
| `bacon_raw` | Bacon cru | `images/bacon_raw.png` |
| `cheese` | Fromage (partagé — voir `ls_kebabking`) | `images/cheese.png` |
| `salad` | Salade | `images/salad.png` |
| `tomato` | Tomate | `images/tomato.png` |
| `onion` | Oignon | `images/onion.png` |
| `pickle` | Cornichons | `images/pickle.png` |
| `potato` | Pomme de terre | `images/potato.png` |
| `nugget_raw` | Nuggets crus | `images/nugget_raw.png` |
| `sauce_burger` | Sauce burger | `images/sauce_burger.png` |
| `syrup_cola` | Sirop cola | `images/syrup_cola.png` |
| `syrup_sprunk` | Sirop Sprunk | `images/syrup_sprunk.png` |
| `syrup_otang` | Sirop O'tang | `images/syrup_otang.png` |
| `cup` | Gobelet vide | `images/cup.png` |
| `milk` | Lait | `images/milk.png` |
| `ice_cream` | Glace vanille | `images/ice_cream.png` |
| `syrup_choco` | Sirop chocolat | `images/syrup_choco.png` |
| `syrup_straw` | Sirop fraise | `images/syrup_straw.png` |
| `apple` | Pommes | `images/apple.png` |
| `cookie_dough` | Pâte à cookie | `images/cookie_dough.png` |

### Produits préparés

`salad_cut`/`tomato_slice`/`onion_slice` sont partagés, définis dans
`ls_kebabking/config/items.lua`. `potato_chunks` est propre à Burger Shot —
à ne pas confondre avec `potato_cut` (frites crues) qui reste propre à
Kebab King, coupe différente du même légume.

| Item | Libellé | Image |
|---|---|---|
| `bacon_strips` | Bacon tranché | `images/bacon_strips.png` |
| `potato_chunks` | Morceaux de patate | `images/potato_chunks.png` |

### Cuissons

| Item | Libellé | Image |
|---|---|---|
| `patty_cooked` | Steak grillé | `images/patty_cooked.png` |
| `chicken_cooked` | Poulet grillé | `images/chicken_cooked.png` |
| `bacon_cooked` | Bacon grillé | `images/bacon_cooked.png` |

### Accompagnements

`fries` (Frites) n'est plus fabriqué par Burger Shot : il est resté défini
dans `ls_kebabking/config/items.lua`, seul restaurant qui le produit encore.

| Item | Libellé | Image |
|---|---|---|
| `potatoes` | Potatoes | `images/potatoes.png` |
| `onion_rings` | Onion rings | `images/onion_rings.png` |
| `nuggets` | Nuggets | `images/nuggets.png` |

### Plats

| Item | Libellé | Image |
|---|---|---|
| `hamburger` | Hamburger | `images/hamburger.png` |
| `cheeseburger` | Cheeseburger | `images/cheeseburger.png` |
| `double_cheese` | Double Cheese | `images/double_cheese.png` |
| `bacon_burger` | Bacon Burger | `images/bacon_burger.png` |
| `chicken_burger` | Chicken Burger | `images/chicken_burger.png` |

### Boissons

| Item | Libellé | Image |
|---|---|---|
| `cola` | Cola (sans préfixe, partagé) | `images/cola.png` |
| `sprunk` | Sprunk (sans préfixe, partagé) | `images/sprunk.png` |
| `water` | Eau (sans préfixe, partagé) | `images/water.png` |
| `otang` | O'tang (sans préfixe, partagé) | `images/otang.png` |
| `milkshake_vanilla` | Milkshake vanille | `images/milkshake_vanilla.png` |
| `milkshake_chocolate` | Milkshake chocolat | `images/milkshake_chocolate.png` |
| `milkshake_strawberry` | Milkshake fraise | `images/milkshake_strawberry.png` |

### Desserts

| Item | Libellé | Image |
|---|---|---|
| `sundae` | Sundae | `images/sundae.png` |
| `cookie` | Cookie | `images/cookie.png` |
