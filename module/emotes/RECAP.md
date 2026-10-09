# Module Émotes — Récapitulatif

Adaptation en RageUI de [rpemotes-reborn](https://github.com/alberttheprince/rpemotes-reborn) pour la base **lslegacy**, entièrement en français, sans contenu adulte.

## Touche d'ouverture

**F3** ouvre le menu. Le menu se referme tout seul quand on quitte le dernier sous-menu (structure plate : Principal → Catégorie → Liste, sans sous-menu par lettre).

## Catégories du menu

| Catégorie | Contenu | Nombre |
|---|---|---|
| Favoris | Vos émotes favorites (toutes catégories confondues) | dynamique |
| Émotes | Gestes et réactions | 657 |
| Danses | 119 |
| Objets | Émotes avec accessoire (certaines avec effet de particules) | 615 |
| Émotes animaux | Nécessite un modèle chien/chat/coyote compatible | 116 |
| Styles de marche | Persistant (KVP) | 137 |
| Expressions | Humeur/visage, persistant (KVP) | 38 |
| Émotes à deux | Synchronisées avec le joueur le plus proche (3m) | 94 |

**Filtrage appliqué sur tout le catalogue d'origine** : suppression de tout contenu à caractère adulte (marqué `AdultAnimation` par le repo + mots-clés supplémentaires vérifiés manuellement), suppression des doublons avec les touches déjà existantes (`point`, `handsup`, `handsup2` → B/U/X).

## Contrôles

| Touche | Action |
|---|---|
| **F3** | Ouvrir/fermer le menu émotes |
| **F4** | Ajouter/retirer des favoris l'émote survolée dans le menu |
| **X** | Annule l'animation en cours (émote solo ou à deux). Si aucune animation n'est active, accroupit normalement. Supprime aussi l'accessoire attaché s'il y en a un. |
| **Y / L** | Accepter / refuser une émote à deux proposée par un autre joueur (10s pour répondre) |
| **J** | Jumelles |
| **H** | Caméra news |
| **G** | Éditer le texte de la caméra news (titre/sous-titre/message) |
| `/e id_emote` | Joue directement une émote par son identifiant (cherche dans émotes, danses, objets, animaux, marches, expressions, à deux) |
| `/idlecamon` / `/idlecamoff` | Active/désactive la caméra idle du jeu (persistant) |

## Favoris — sauvegardés par personnage

Les favoris sont stockés en base (table `emotes_favorites`, créée automatiquement au démarrage) indexés par `players.id` (l'identifiant du **personnage**, pas du compte). Chaque personnage d'un même compte multichar a donc ses propres favoris, sans partage entre eux. Rechargés automatiquement à chaque connexion ou changement de personnage.

## Émotes synchronisées à deux

- Détection automatique du joueur le plus proche (max 3m)
- Le joueur ciblé a 10 secondes pour accepter (**Y**) ou refuser (**L**)
- Positionnement automatique (attache sur un os du partenaire, ou décalage devant lui selon l'émote)
- Annulation automatique si un des deux joueurs monte en véhicule, meurt, ou se déconnecte

## Effets de particules partagés (PTFX)

Certaines émotes (fumée, feux d'artifice, etc.) diffusent un effet de particules visible par **tous les joueurs à proximité**, pas seulement vous — via un statebag répliqué (`lslegacy_emotes_ptfx`), sans passer par un événement serveur dédié.

## Jumelles & Caméra news

Portage simplifié des modules d'origine (caméra scriptée + scaleforms **vanilla** du jeu — `BINOCULARS` et `breaking_news` — aucun asset ni fichier NUI supplémentaire nécessaire) :
- **Jumelles (J)** : vue zoomable (molette), avec le prop `prop_binoc_01` dans les mains.
- **Caméra news (H)** : bandeau d'actualité éditable (**T**) via le clavier virtuel du jeu (titre défilant, sous-titre, message).

## Assets custom (stream)

Le dossier `stream/` (77 Mo, à la racine de la ressource) contient les animations et props personnalisés utilisés par certaines émotes/danses/objets non-vanilla, repris tels quels du repository officiel. Déclarés dans `fxmanifest.lua` via `data_file 'DLC_ITYP_REQUEST'` pour les props custom.

## Fichiers du module

```
module/emotes/
├── client/
│   ├── main.lua           -- moteur principal : menu RageUI, favoris, /e, sync 2 joueurs, PTFX
│   ├── idlecam.lua        -- /idlecamon /idlecamoff
│   ├── binoculars.lua     -- touche J
│   └── newscam.lua        -- touche H / T
├── server/
│   └── main.lua           -- relais serveur (sync 2 joueurs + favoris en BDD)
└── data/
    ├── emotes_emotes.lua
    ├── emotes_dances.lua
    ├── emotes_props.lua
    ├── emotes_animals.lua
    ├── emotes_walks.lua
    ├── emotes_expressions.lua
    └── emotes_shared.lua

stream/                        -- assets custom (racine de la ressource)
emotes_conditionalanims.meta   -- racine de la ressource
```

## Conventions du projet respectées

- Tous les événements réseau passent par `LSLegacy.Events.Register` / `LSLegacy.Events.Register` / `LSLegacy.Events.SendToServer` (pas de `RegisterNetEvent`/`TriggerServerEvent` bruts)
- Rate limits ajoutés dans `LSLegacy.RateLimit` (`server/function.lua`) pour les 5 événements serveur du module
- Toutes les touches sont enregistrées via `RegisterKeyMapping`/`Keys.Register` (rebindables par le joueur dans les paramètres FiveM)

## Limites connues

- La traduction anglais → français du catalogue (1391 émotes + marches/expressions/partagées) est faite par substitution automatique (dictionnaire + règles), pas relue une par une. La grande majorité est claire, certaines tournures restent approximatives.
- Les émotes animaux ne fonctionnent que si le joueur est déjà sur un modèle compatible (aucun système "devenir animal" n'existe sur cette base) — sinon un message d'erreur s'affiche.
- Jumelles/caméra news n'ont pas la bascule vision nocturne/thermique de la version d'origine (non demandée, retirée pour rester simple).
- La touche **G** (édition du texte de la caméra news) est aussi utilisée par le module Mécanicien (lâcher la pièce portée). Les deux commandes restent bindées dessus par défaut ; à rebinder dans les paramètres FiveM si besoin.
