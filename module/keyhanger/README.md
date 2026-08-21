# Utility Keyhanger — Porte-clés mural (module LSLegacy)

Système de **porte-clés muraux physiques et interactifs**. Les clés de véhicules
sont des objets d'inventaire que l'on **accroche** sur un support mural (visible
en direct par tous les joueurs) et que l'on **récupère** — exactement comme on
ouvre le **coffre d'un véhicule**, via l'inventaire et le système **DataStore**
du framework.

> Maisons, appartements, garages, entreprises, factions, postes de police,
> ateliers… chaque porte-clés est un point de stockage et de partage des clés.

---

## ✨ Fonctionnalités

- **Clé de véhicule** = item d'inventaire (`vehicle_key`) porteur de la plaque/modèle.
  - L'utiliser **verrouille/déverrouille** le véhicule correspondant (phares + klaxon).
- **Support mural** posable n'importe où via un **mode placement** (aperçu temps réel,
  accroche au mur par raycast, rotation/hauteur/profondeur réglables).
- **Stockage façon coffre** : on ouvre le support et on glisse les clés
  dans/depuis l'inventaire (réutilise l'UI coffre + les DataStore, **pas de menu**).
- **Props visibles en direct** : chaque clé accrochée apparaît physiquement sur le
  support, synchronisée pour tous les joueurs à proximité.
- **Contrôle d'accès** : `personnel`, `métier`, `faction`, `partagé` (liste de
  personnes), `public`. Gardé **côté serveur**.
- **Partage** : le propriétaire autorise une personne proche à utiliser le support.
- **Persistance BDD** : supports (table `keyhanger_boards`) + contenu (table
  `datastore`, comme les coffres).

---

## 📦 Installation

Le module est intégré au framework `lslegacy`. Fichiers déclarés dans `fxmanifest.lua` :

```lua
-- shared_scripts
'module/keyhanger/config.lua',
'module/keyhanger/languages/fr.lua',
-- client_scripts
'module/keyhanger/client/main.lua',
'module/keyhanger/client/placement.lua',
-- server_scripts
'module/keyhanger/server/main.lua',
```

L'item `vehicle_key` est ajouté dans `shared/config.lua` (`Config.Items` +
`Config.InsertItems`) et son image est `inventory/html/img/items/vehicle_key.png`.

La table SQL `keyhanger_boards` est **créée automatiquement** au démarrage
(voir aussi `keyhanger.sql` pour un import manuel). Aucune autre table à créer :
le contenu utilise la table `datastore` existante.

**Dépendances** : `ox_target`, `oxmysql` (déjà présents), `RageUI` (déjà présent).

---

## 🎮 Utilisation

### Joueur
- **Viser le support** (ox_target) → *Ouvrir le porte-clés* : ouvre le stockage,
  glisser les clés dans/hors comme un coffre.
- **Utiliser une clé** depuis l'inventaire : verrouille/déverrouille le véhicule.

### Propriétaire / staff
- **Viser le support** → *Gérer le porte-clés* (renommer, partager, voir/retirer
  les partages, décrocher le support).

### Admin
- `/porteclefs` : ouvre le **mode placement** (choix du support + accès, puis aperçu).
  - Souris : viser un mur · Molette : rotation · `SHIFT`+molette : hauteur ·
    `ALT`+molette : profondeur · `Entrée`/clic : valider · `Échap` : annuler.
- `/creercle` : crée une **clé** pour le véhicule le plus proche (test/concession).

> Groupes requis configurables dans `config.lua` (`C.Placement.group`,
> `C.Key.createCommand.group`). Par défaut `3` = admin.

---

## 🔧 Configuration (`config.lua`)

| Section        | Rôle |
|----------------|------|
| `C.Key`        | Distance d'usage de la clé, klaxon, commande de création. |
| `C.Placement`  | Commande, raycast, pas de rotation/hauteur/profondeur. |
| `C.Render`     | Distance d'apparition des props + LOD des clés. |
| `C.Storage`    | Capacité (KG) du support, intervalle de resync, clés uniquement. |
| `C.Boards`     | Modèles de supports + disposition de slots. |
| `C.KeyProps`   | Pool de props de clés (variété visuelle). |
| `C.SlotLayouts`| Position de chaque clé relative au support (réglable). |
| `C.AccessTypes`| Types d'accès disponibles. |

**Réglage des positions de clés** : passez `C.Debug = true`, le support trace un
contour ; ajustez les offsets `x` (latéral) / `y` (profondeur) / `z` (vertical)
dans `C.SlotLayouts`.

---

## 🧩 Exports serveur

```lua
-- Donner une clé de véhicule à un joueur (concession, garage, récompense…)
exports['lslegacy']:giveVehicleKey(source, plate, vehModel, display, label)

-- Installer un porte-clés par script (retourne l'id, ou nil)
exports['lslegacy']:createBoard({
    coords    = vector3(x, y, z),
    heading   = 0.0,
    board     = 'board_wood',      -- clé de C.Boards
    label     = 'Garage Benny',
    ownerType = 'job',             -- personal|job|faction|shared|public
    ownerId   = 'mechanic',        -- identifier / nom job / nom faction
})
```

---

## 🛠️ Intégration technique (réutilisable)

Pour permettre l'ouverture façon coffre, un **chemin « conteneur générique »** a
été ajouté à l'inventaire (utile aussi pour de futurs stashs) :

- Client : `TriggerEvent('inventory:openContainer', dataStoreName, label, maxWeight)`
  ouvre n'importe quel DataStore comme un coffre.
- Serveur : `LSLegacy.DataStoreGuard(source, name, action, item)` — garde
  d'accès générique pour les DataStores. Le keyhanger l'étend pour
  n'autoriser que les ayants droit et uniquement les clés.
- Serveur : event `lslegacy:containerUpdated(name)` émis après chaque dépôt/retrait.

---

## 🎨 Props

Par défaut le module utilise des **props natifs GTA V vérifiés** (aucun stream
requis) : supports `prop_cork_board`, `prop_muster_wboard_01`,
`prop_muster_wboard_02` ; clés `prop_cs_keys_01`, `prop_cuff_keys_01`.

Pour un **modèle custom** (planche de porte-clés dédiée, trousseaux sur mesure),
voir [`stream/README_PROPS.md`](stream/README_PROPS.md).
