# Développer sur LS Legacy

Ce document explique l'architecture interne de LS Legacy et l'API du socle (`LSLegacy.*`), pour quiconque veut modifier le framework ou ajouter un module. Pour l'installation et la liste des modules, voir le [README](README.md).

## Sommaire

- [Structure générale](#structure-générale)
- [Le socle `LSLegacy`](#le-socle-lslegacy)
- [Convention de nommage](#convention-de-nommage)
- [Events sécurisés (système de jetons)](#events-sécurisés-système-de-jetons)
- [Callbacks client ↔ serveur](#callbacks-client--serveur)
- [Validation des entrées](#validation-des-entrées)
- [DataStore (inventaires génériques)](#datastore-inventaires-génériques)
- [Argent et inventaire joueur](#argent-et-inventaire-joueur)
- [Joueurs et personnages](#joueurs-et-personnages)
- [Persistance partielle (dirty-tracking)](#persistance-partielle-dirty-tracking)
- [Ajouter un module](#ajouter-un-module)
- [Base de données](#base-de-données)
- [Anticheat et rate-limiting](#anticheat-et-rate-limiting)
- [Sécurité — limites connues](#sécurité--limites-connues)

## Structure générale

```
client/          logique commune à tous les joueurs (spawn, statuts, inventaire, etc.)
server/          logique serveur miroir de client/
shared/          config globale + fonctions utilisables des deux côtés
inventory/       système d'inventaire NUI générique
module/<nom>/    un module = une fonctionnalité indépendante (job, commerce, système...)
dependencies/    bibliothèques tierces embarquées (RageUI)
```

Chaque module suit en général cette forme (adaptée selon ses besoins) :

```
module/<nom>/
  config.lua              -- réglages exposés au propriétaire du serveur (shared)
  client/main.lua          -- logique client
  server/main.lua          -- logique serveur (permissions, BDD, events)
  shared/permissions.lua   -- si le module a un système de grades
  languages/fr.lua          -- libellés affichés
  html/                     -- interface NUI (si le module en a une)
  sql/<nom>.sql             -- schéma de référence (optionnel, la table s'auto-crée)
```

Rien n'est chargé « par convention » : chaque fichier doit être ajouté explicitement dans `client_scripts`, `shared_scripts` ou `server_scripts` du `fxmanifest.lua` racine. Un module désactivé (ex. `module/mecanicien`) reste simplement absent de ces listes — pas besoin de le supprimer du disque pour le désactiver.

## Le socle `LSLegacy`

Tout le framework s'organise autour d'une table globale `LSLegacy`, exposée aux deux bouts (`client/function.lua` côté client, `server/function.lua` côté serveur). Une ressource externe peut y accéder via `exports['lslegacy']:getSharedObject()`.

Fonctions utilitaires notables : `LSLegacy.Utils.Math.Round` (alias `LSLegacy.Math.Round`), `LSLegacy.ConverToBoolean/ConverToNumber`, `LSLegacy.GetClosestPlayer/GetClosestVehicle` (client), `LSLegacy.StringSplit`, `LSLegacy.GenerateNumeroDeSerie`. `LSLegacy.Factions` expose les mêmes opérations que `LSLegacy.Jobs` mais pour les factions (`GetAvailableFactions`, `GetFactionLabel`, `SetFaction`, etc.) — les deux systèmes partagent la même mécanique de grade.

## Convention de nommage

- **Events et callbacks** : `module:action` tout en minuscule, sans troisième segment (ex.
  `bank:addMoney`, `keyhanger:syncAll`) — le module owner de l'event fait autorité pour son
  préfixe, qui ne correspond pas toujours au nom du dossier (ex. le module `adminmenu` préfixe
  ses events `admin:`, pas `adminmenu:`). Exception assumée : les sous-espaces qui structurent
  vraiment un domaine volumineux (`police:callouts:*`, `police:inv:*`) restent à 3 segments —
  ne pas les aplatir mécaniquement.
- **Fonctions locales** (`local function ...`) : PascalCase.
- **Variables locales** : camelCase.
- **Dossiers de module** : minuscule, sans séparateur (`persistentvehicles`, pas
  `persistent_vehicles`).

## Events sécurisés (système de jetons)

LS Legacy n'utilise pas `RegisterNetEvent`/`TriggerServerEvent` directement pour les events venant du client : tout passe par un système de jetons à usage unique, pour empêcher un client modifié de rejouer ou de forger un event serveur. La façade `LSLegacy.Events` est le point d'entrée recommandé (alias vers les fonctions historiques ci-dessous, utilisée partout dans le framework).

**Déclarer un event serveur :**
```lua
LSLegacy.Events.Register('module:action', function(arg1, arg2)
    local _source = source
    -- ...
end)
```

**Le déclencher depuis le client :**
```lua
LSLegacy.Events.SendToServer('module:action', arg1, arg2)
```

En coulisses : à la connexion, le serveur génère un jeton aléatoire par event enregistré (`LSLegacy.GeneratorTokenConnecting`) et les envoie au client par lots (`addTokenEvent`, pour rester sous la limite de taille d'un event réseau). `SendToServer` consomme le jeton courant de l'event visé et déclenche `useEvent` ; le serveur vérifie le jeton dans `LSLegacy.Token[source][eventName]`, le retire, en génère un nouveau, puis exécute le handler. Un jeton invalide/rejoué = `DropPlayer` immédiat (« Injector detected »).

Si vous ajoutez un nouvel event serveur déclenchable par le client, pensez à lui donner une limite avec `LSLegacy.Security.RegisterRateLimit('module:action', limite)` en tête de votre fichier — un event sans entrée n'est pas limité en fréquence.

**Events serveur → client**, plus simples, pas de jeton (le client fait confiance au serveur) :
```lua
-- serveur
LSLegacy.Events.SendToClient('module:action', targetSource, data)

-- client
LSLegacy.Events.Register('module:action', function(data)
    -- ...
end)
```

## Callbacks client ↔ serveur

Pour un aller-retour avec réponse (façon RPC), plutôt que deux events à la main, via `LSLegacy.Callbacks` :

```lua
-- serveur : déclarer un callback
LSLegacy.Callbacks.RegisterServer('module:action', function(player, cb, arg1)
    cb(true, "résultat")
end)

-- client : l'appeler en bloquant (Citizen.Await, timeout fixe 15s)
local ok, result = LSLegacy.Callbacks.AwaitServer('module:action', arg1)
```

Le sens inverse existe aussi : côté serveur, `LSLegacy.Callbacks.TriggerClient(player, eventName, callback, ...)` (asynchrone) et `LSLegacy.Callbacks.AwaitClient(player, eventName, ...)` (bloquant, timeout 15s) appellent un callback déclaré côté client avec `LSLegacy.Callbacks.RegisterClient(eventName, callback)`. Les callbacks client→serveur passent par les events sécurisés `triggerServerCallback`/`clientCallback` déjà présents dans `LSLegacy.RateLimit`.

## Validation des entrées

`LSLegacy.Validate` (`server/validate.lua`, chargé juste après `server/function.lua`) centralise la validation des données envoyées par le client dans un handler serveur — **un jeton valide prouve seulement que l'event vient d'un client légitime, jamais que les valeurs qu'il contient sont sensées** (montant négatif, cible hors de portée, item inexistant...). Deux familles de fonctions :

```lua
-- « Résolveurs » : renvoient la valeur validée, ou nil si invalide
LSLegacy.Validate.Number(value)             -- rejette aussi NaN/inf, pas juste les non-nombres
LSLegacy.Validate.PositiveInteger(value, allowZero)
LSLegacy.Validate.Player(source)            -- renvoie l'objet joueur, ou nil s'il n'existe pas
LSLegacy.Validate.Target(source, targetSource)
LSLegacy.Validate.Item(itemName)
LSLegacy.Validate.Vehicle(entity)
LSLegacy.Validate.DataStore(name)

-- « Checks » : renvoient un booléen
LSLegacy.Validate.Distance(coordsA, coordsB, maxDistance)  -- existe aussi côté client (géométrie pure)
LSLegacy.Validate.Job(player, job[, minGrade])
LSLegacy.Validate.Permission(player, minGroupLevel)
```

Ordre de vérification recommandé pour tout event serveur qui exécute une action métier
(documenté dans `server/function.lua` au-dessus de `LSLegacy.Security`) : **Token → RateLimit →
Player → Target → Distance → Ownership → Job → Permission → Arguments → Action**. Chaque étage
protège contre une catégorie d'abus différente ; sauter un étage pour « gagner du temps » est la
source la plus fréquente de failles de sécurité dans ce framework (voir les lots 3/4/6 de
l'historique du refactor — dupe d'argent/d'objets, spoofing d'items via des events client mal
validés).

## DataStore (inventaires génériques)

`LSLegacy.DataStore` (`server/datastore.lua`) est le système générique derrière tous les inventaires secondaires (coffres, stock d'entreprise, porte-clés...) — l'inventaire du personnage lui-même passe par `inventory/`.

```lua
LSLegacy.DataStore.RegisterDataStore(name, data)   -- crée/charge un datastore
LSLegacy.DataStore.GetDataStore(name)
LSLegacy.DataStore.AddItemInInventory(datastore, item, quantity, label, uniqueId, data)
LSLegacy.DataStore.RemoveItemInInventory(datastore, item, quantity, label)
LSLegacy.DataStore.CanStoreItem(datastore, item, quantity)  -- vérifie le poids max
```

Un datastore est identifié par un `name` (ex. `keyhanger_12`, `atelier_stock_benny`). Un module qui veut restreindre l'accès à ses propres datastores implémente `LSLegacy.DataStoreGuard(src, name, action, item)` en chaînant l'implémentation précédente — voir `module/keyhanger/server/main.lua` pour un exemple de ce pattern (préfixe de nom + vérification de permission avant d'autoriser dépôt/retrait). Toutes les fonctions `Add/Remove(Money|DirtyMoney|ItemInInventory)` valident déjà leurs paramètres en interne (`LSLegacy.Validate.PositiveInteger`) — inutile de revalider avant d'appeler.

## Argent et inventaire joueur

`LSLegacy.Money` (`server/player/money.lua`) et `LSLegacy.Inventory` (`server/player/inventory.lua`) sont les seuls points d'entrée pour modifier l'argent/l'inventaire d'un joueur — ne jamais muter `player.cash`/`player.inventory` directement, ce qui court-circuiterait la validation **et** le dirty-tracking (voir plus bas).

```lua
LSLegacy.Money.SetPlayerMoney(player, amount)      -- + Add/Remove, idem pour *DirtyMoney (argent sale)
LSLegacy.Inventory.AddItemInInventory(player, item, quantity, label, uniqueId, data)
LSLegacy.Inventory.RemoveItemInInventory(player, item, quantity, label)
```

Toutes renvoient `true`/`false` et rejettent silencieusement une quantité négative, nulle (sauf `allowZero`) ou non numérique — c'est le point qui a comblé une faille de dupe d'argent/objets tôt dans le refactor (un event `BankAddMoney` sans validation permettait de créditer un montant négatif pour gagner du cash net). Un nouvel event serveur qui touche à l'argent ou à l'inventaire doit passer par ces fonctions, jamais par un accès direct.

## Joueurs et personnages

`LSLegacy.ServerPlayers[source]` est la table vivante des joueurs connectés (source réseau → données du personnage actif), mais l'accès direct est déprécié au profit de la façade `LSLegacy.Players` :

- `LSLegacy.Players.Get(source)` — le joueur connecté à cette source réseau
- `LSLegacy.Players.GetByIdentifier(identifier)` — recherche par identifiant (license/steam)
- `LSLegacy.Players.GetAll()` — snapshot de tous les joueurs connectés
- `LSLegacy.Players.SetJob(source, job, grade)` / `SetFaction(source, faction, grade)`
- `LSLegacy.ResolveCharacterId(identifier, cb)` / `ResolveCharacterIdSync(identifier)` — résout un `identifier` vers le `character_id` (personnage en ligne en priorité, sinon repli en base sur le slot 1)

Pour les vérifications job/grade et permissions staff, préférer `LSLegacy.Jobs.Is(player, job[, minGrade])` / `LSLegacy.Jobs.Require(...)` et `LSLegacy.Permissions.GetLevel(player)` / `Has(player, minLevel)` à une comparaison manuelle de `player.job`/`player.group`.

Un personnage est identifié par sa clé `boutique-id` en base (colonne `players.boutique-id`), pas seulement par l'`identifier` du compte : un même compte peut avoir plusieurs personnages (`module/multichar`).

⚠️ Concernant la synchronisation des données joueur : seul `skin` est écrit depuis le client vers le serveur. Le handler de `lslegacy:receiveUpdateServerPlayer` merge les champs reçus via une liste blanche (`ClientWritableFields` dans `server/player/player.lua`) — ne jamais la transformer en remplacement complet de la table joueur (un client modifié pourrait alors écraser n'importe quel champ, y compris l'argent ou les permissions). Si un futur module a besoin d'écrire un autre champ depuis le client, l'ajouter à cette liste plutôt que de contourner le merge.

## Persistance partielle (dirty-tracking)

Le joueur et chaque datastore ne sont resauvegardés en base que si quelque chose a réellement
changé, plutôt qu'un `UPDATE` complet inconditionnel toutes les 15s. Tout mutateur Core marque
déjà les champs qu'il touche (`money.lua`, `inventory.lua`, `jobs.lua`, `ReceiveUpdateServerPlayer`
pour `skin`) ; si vous ajoutez une nouvelle façon de muter un champ persistant en dehors de ces
fonctions Core, appelez `MarkDirty` vous-même :

```lua
player:MarkDirty('money')          -- côté joueur (server/player/player.lua)
player:SaveDirty()                 -- forcer une sauvegarde immédiate plutôt qu'attendre le tick

datastore:MarkDirty()              -- côté datastore (server/datastore.lua), un seul flag booléen
datastore:SaveDirty(datastoreId)
```

Le flag de sauvegarde s'appelle `_dirtyFields`/`_dirty` (pas `dirty`, déjà pris par la mécanique
« argent sale »). **Filet de sécurité** : `playerDropped` fait toujours un `UPDATE` complet
inconditionnel à la déconnexion propre, donc oublier un `MarkDirty` ne perd des données qu'en cas
de crash serveur entre deux mutations — pas en usage normal. `status`/`skills`/`health` n'ont pas
encore de setter Core dédié et sont toujours resauvegardés à chaque tick de 15s (candidat pour un
futur lot, pas un bug).

## Ajouter un module

1. Créer `module/<nom>/` avec au minimum `config.lua` (réglages) et `server/main.lua` et/ou `client/main.lua`.
2. Si le module a une échelle de permissions (grades), suivre le pattern de `module/atelier/shared/permissions.lua` ou `module/mdt/shared/permissions.lua` : une table de grades avec des `grants` cumulatifs, vérifiée aussi bien côté client (affichage) que côté serveur (autorité réelle — jamais faire confiance à un `job`/`grade` envoyé par le client).
3. Déclarer les fichiers dans `fxmanifest.lua` racine, dans l'ordre : `shared_scripts` (config) → `client_scripts` → `server_scripts`.
4. Si le module a besoin de tables, les créer via `MySQL.Async.execute('CREATE TABLE IF NOT EXISTS ... ', {})` au démarrage (voir n'importe quel `server/main.lua` existant) — la table se crée toute seule au premier lancement, pas besoin de migration manuelle. Documenter le schéma dans un `module/<nom>/sql/<nom>.sql` de référence si le module a plusieurs tables (voir `module/atelier/sql/atelier.sql` pour un exemple).
5. Ajouter une limite pour chaque event serveur déclenchable par le client via `LSLegacy.Security.RegisterRateLimit('module:action', limite)`, en tête de votre `server/main.lua`.
6. Si le module expose un webhook Discord ou une clé API, la lire via `GetConvar('lslegacy_<nom>', '')` — **ne jamais coder une clé ou une URL de webhook en dur dans le code**, elles doivent être définies dans `server.cfg`, qui n'est jamais versionné.
7. Valider systématiquement les arguments d'un handler d'event serveur avec `LSLegacy.Validate.*` (montants, cibles, distance) avant d'agir dessus, et passer par `LSLegacy.Money`/`LSLegacy.Inventory` pour toute modification d'argent/objets — voir [Validation des entrées](#validation-des-entrées) et [Argent et inventaire joueur](#argent-et-inventaire-joueur).

## Base de données

`winframe_database.sql` (racine) documente le socle. Chaque module aux tables non triviales a son propre fichier de référence sous `module/<nom>/sql/`. Ces fichiers sont indicatifs : le code source (`CREATE TABLE IF NOT EXISTS`) fait foi en cas d'écart, puisque c'est lui qui crée réellement les tables au démarrage.

## Anticheat et rate-limiting

`LSLegacy.RateLimit` (`server/function.lua`, alimentée par `LSLegacy.Security.RegisterRateLimit` — voir ci-dessus) plafonne le nombre de déclenchements autorisés par joueur pour chaque event sécurisé, sur une fenêtre glissante de 15s (`LSLegacy.PlayersLimit`, remise à zéro périodiquement). Dépasser la limite déclenche un `DropPlayer` immédiat. `shared/shared.lua` et `server/anticheat.lua` couvrent les protections plus générales (détection d'entités suspectes, contrôle de la triche côté client, etc.) — voir les commentaires de `Shared.Anticheat` pour la liste des options activables.

`Shared.Anticheat.WhitelistedEvents` (`shared/shared.lua`) liste tous les events client légitimes enregistrés via le système sécurisé : si vous ajoutez ou renommez un event `LSLegacy.Events.Register` côté **client**, pensez à mettre à jour cette liste, sinon l'anticheat le traitera comme suspect. `Shared.Anticheat.Events` est une liste distincte de signatures à bannir (noms d'events d'autres frameworks/mods de triche, ex. `esx_*`, `QBCore:*`) — ne jamais y ajouter un event légitime de ce framework, et ne jamais s'inquiéter d'y voir apparaître des noms « ESX »/« QBCore » : ce sont des signatures de détection, pas de vraies dépendances.

`LSLegacy.Security` (`server/function.lua` + `server/validate.lua`) est le point d'entrée unique pour la sécurité réseau, au-delà du rate-limiting :

```lua
LSLegacy.Security.RegisterRateLimit('module:action', limite)
LSLegacy.Security.Log(source, eventName, reason)   -- log centralisé (utilisé aussi par les drops internes)
LSLegacy.Security.Token.New / NewForConnecting / Renew
LSLegacy.Security.Validate                          -- alias de LSLegacy.Validate
```

## Sécurité — limites connues

Ces points sont documentés ici pour que personne ne les redécouvre par accident en pensant que
c'est un comportement voulu :

- **`SetJob`/`SetFaction`** (côté serveur, `lslegacy:setJob`/`lslegacy:setFaction` dans
  `server/player/jobs.lua`) sont protégés par jeton et rate-limit, mais **pas par une vérification
  d'autorisation** — un jeton valide prouve qu'un client légitime a déclenché l'event, pas qu'il a
  le droit de changer son propre job. En l'état, n'importe quel joueur peut s'auto-attribuer
  n'importe quel job/grade/faction en rejouant l'event avec les bons arguments. Personne n'a
  encore ajouté le check d'autorisation manquant (candidat pour un futur lot sécurité dédié) — ne
  pas supposer que ce chemin est sûr sous prétexte qu'il est protégé par jeton.
- Un jeton valide et une limite de fréquence respectée **ne prouvent jamais qu'une action métier
  est autorisée** — voir l'ordre de vérification recommandé dans la section
  [Validation des entrées](#validation-des-entrées). C'est l'erreur qui a permis les failles de
  duplication d'argent/objets trouvées tôt dans le refactor de ce framework.
- Ne jamais faire confiance à un `job`/`grade`/`money`/`inventory` envoyé par le client : toujours
  relire la valeur autoritative côté serveur (`LSLegacy.Players.Get(source)`) avant d'agir dessus.
