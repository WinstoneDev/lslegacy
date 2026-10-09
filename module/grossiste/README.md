# module/grossiste

Grossiste d'ingrédients bruts, ouvert à **n'importe quel joueur**. Deux PNJ
distincts (voir `config/config.lua`) :

- **Seller** — le joueur ACHÈTE au grossiste.
- **Buyer** — le joueur VEND au grossiste.

Stock **illimité** des deux côtés, prix **fixes** définis dans
`config/catalog.lua` (grille de départ, à ajuster après test en jeu).

## Paiement

- **Achat** : paiement personnel (espèces/carte, via le TPE partagé du module
  `bank`) ou compte entreprise (si le job du joueur possède un coffre
  enregistré dans `GRConfig.CompanySafes`).
- **Vente** : si le joueur a un job dans `GRConfig.CompanySafes`, la recette
  est **automatiquement** déposée sur le coffre de son entreprise, libellée
  « Vente grossiste ». Sinon, versée en espèces.

## Catalogue

`config/catalog.lua` liste chaque item avec un habillage RP (`pack`,
`packCount` — ex. "Sac de Farine" donne 20 Farine) mais des prix **unitaires**
(`buyUnit`/`sellUnit`) : l'achat se fait par lot, la revente accepte
n'importe quelle quantité détenue.

Les pots de sauce Kebab King (`pot_ketchup`, etc.) sont vendus avec
**10 utilisations** (`potUses`) au lieu des 20 obtenues en les fabriquant à
la station Sauces — un dépannage plus cher à l'usage, jamais gratuit.

## Exclusions volontaires

Poulet cru, steak haché cru (`patty_raw`), jambon, viande de veau crue
(`kebab_meat_raw`) et graisse animale ne sont **pas** vendus ici : ils sont
déjà fournis par la chasse (`module/farm`, activité Chasseur), à stock
limité. Les vendre en illimité au grossiste rendrait la chasse inutile.
Même raisonnement pour le bois (déjà vendu par le Bûcheron).

## En réserve pour plus tard

- Boîte de thé / sachet de thé, tabac à rouler, cigarettes, cigares,
  papier à rouler, chips, cacahuètes, tickets de loto/à gratter : à
  rattacher à la LTD existante, pas encore implémentés ici.
- Fruits exotiques, alcools, poissons, houblon/orge/canne à sucre/agave,
  coton/pavot/aloe vera, cuir/tissu : items créés sans recette, en attente
  de futurs métiers (brasserie, pêche, menuiserie/maroquinerie...).

## Café moulu — retiré

`coffee_ground` et son doublon retail (`paquet_cafe`) ont été retirés du
grossiste (2026-09-07) : aucune recette resto ne consommait `coffee_ground`,
Aldente's utilise `coffee_beans` (Café en Grains, toujours au catalogue).

## Coordonnées

Les coordonnées des deux PNJ et du blip (`config/config.lua`) sont des
**placeholders jamais calibrés en jeu** — à ajuster une fois l'emplacement
réel choisi.
