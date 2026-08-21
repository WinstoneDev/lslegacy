# Développer sur LS Legacy

Ce document explique l'architecture interne de LS Legacy et l'API du socle (`LSLegacy.*`), pour quiconque veut modifier le framework ou ajouter un module. Pour l'installation et la liste des modules, voir le [README](README.md).

## Sommaire

- [Structure générale](#structure-générale)
- [Le socle `LSLegacy`](#le-socle-lslegacy)
- [Events sécurisés (système de jetons)](#events-sécurisés-système-de-jetons)
- [Callbacks client ↔ serveur](#callbacks-client--serveur)
- [DataStore (inventaires génériques)](#datastore-inventaires-génériques)
- [Joueurs et personnages](#joueurs-et-personnages)
- [Ajouter un module](#ajouter-un-module)
- [Base de données](#base-de-données)
- [Anticheat et rate-limiting](#anticheat-et-rate-limiting)

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

Fonctions utilitaires notables : `LSLegacy.Math.Round`, `LSLegacy.ConverToBoolean/ConverToNumber`, `LSLegacy.GetClosestPlayer/GetClosestVehicle` (client), `LSLegacy.StringSplit`, `LSLegacy.GenerateNumeroDeSerie`.

## Events sécurisés (système de jetons)

LS Legacy n'utilise pas `RegisterNetEvent`/`TriggerServerEvent` directement pour les events venant du client : tout passe par un système de jetons à usage unique, pour empêcher un client modifié de rejouer ou de forger un event serveur.

**Déclarer un event serveur :**
```lua
LSLegacy.RegisterServerEvent('monEvent', function(arg1, arg2)
    local _source = source
    -- ...
end)
```

**Le déclencher depuis le client :**
```lua
LSLegacy.SendEventToServer('monEvent', arg1, arg2)
```

En coulisses : à la connexion, le serveur génère un jeton aléatoire par event enregistré (`LSLegacy.GeneratorTokenConnecting`) et les envoie au client par lots (`addTokenEvent`, pour rester sous la limite de taille d'un event réseau). `SendEventToServer` consomme le jeton courant de l'event visé et déclenche `useEvent` ; le serveur vérifie le jeton dans `LSLegacy.Token[source][eventName]`, le retire, en génère un nouveau, puis exécute le handler. Un jeton invalide/rejoué = `DropPlayer` immédiat (« Injector detected »).

Si vous ajoutez un nouvel event serveur déclenchable par le client, pensez à lui donner une limite dans `LSLegacy.RateLimit` (`server/function.lua`) — un event sans entrée n'est pas limité en fréquence.

**Events serveur → client**, plus simples, pas de jeton (le client fait confiance au serveur) :
```lua
-- serveur
LSLegacy.SendEventToClient('monEventClient', targetSource, data)

-- client
LSLegacy.RegisterClientEvent('monEventClient', function(data)
    -- ...
end)
```

## Callbacks client ↔ serveur

Pour un aller-retour avec réponse (façon RPC), plutôt que deux events à la main :

```lua
-- serveur : déclarer un callback
LSLegacy.RegisterServerCallback('monCallback', function(player, cb, arg1)
    cb(true, "résultat")
end)

-- client : l'appeler
LSLegacy.TriggerServerCallback('monCallback', function(ok, result)
    -- ...
end, arg1)

-- ou en bloquant (Citizen.Await) :
local ok, result = LSLegacy.AwaitServerCallback('monCallback', arg1)
```

Le sens inverse existe aussi : côté serveur, `LSLegacy.TriggerClientCallback(player, eventName, callback, ...)` (asynchrone) et `LSLegacy.AwaitClientCallback(player, eventName, ...)` (bloquant, timeout 15s) appellent un callback déclaré côté client avec `LSLegacy.RegisterClientCallback(eventName, callback)`. Les callbacks client→serveur passent par les events sécurisés `triggerServerCallback`/`clientCallback` déjà présents dans `LSLegacy.RateLimit`.

## DataStore (inventaires génériques)

`LSLegacy.DataStore` (`server/datastore.lua`) est le système générique derrière tous les inventaires secondaires (coffres, stock d'entreprise, porte-clés...) — l'inventaire du personnage lui-même passe par `inventory/`.

```lua
LSLegacy.DataStore.RegisterDataStore(name, data)   -- crée/charge un datastore
LSLegacy.DataStore.GetDataStore(name)
LSLegacy.DataStore.AddItemInInventory(datastore, item, quantity, label, uniqueId, data)
LSLegacy.DataStore.RemoveItemInInventory(datastore, item, quantity, label)
LSLegacy.DataStore.CanStoreItem(datastore, item, quantity)  -- vérifie le poids max
```

Un datastore est identifié par un `name` (ex. `keyhanger_12`, `atelier_stock_benny`). Un module qui veut restreindre l'accès à ses propres datastores implémente `LSLegacy.DataStoreGuard(src, name, action, item)` en chaînant l'implémentation précédente — voir `module/keyhanger/server/main.lua` pour un exemple de ce pattern (préfixe de nom + vérification de permission avant d'autoriser dépôt/retrait).

## Joueurs et personnages

`LSLegacy.ServerPlayers[source]` est la table vivante des joueurs connectés (source réseau → données du personnage actif). Fonctions utiles :

- `LSLegacy.GetPlayerFromId(source)` — le joueur connecté à cette source réseau
- `LSLegacy.GetPlayerFromIdentifier(identifier)` — recherche par identifiant (license/steam)
- `LSLegacy.ResolveCharacterId(identifier, cb)` / `ResolveCharacterIdSync(identifier)` — résout un `identifier` vers le `character_id` (personnage en ligne en priorité, sinon repli en base sur le slot 1)

Un personnage est identifié par sa clé `boutique-id` en base (colonne `players.boutique-id`), pas seulement par l'`identifier` du compte : un même compte peut avoir plusieurs personnages (`module/multichar`).

⚠️ Concernant la synchronisation des données joueur : seul `skin` est écrit depuis le client vers le serveur. `ReceiveUpdateServerPlayer` merge les champs reçus via une liste blanche — ne jamais la transformer en remplacement complet de la table joueur (un client modifié pourrait alors écraser n'importe quel champ, y compris l'argent ou les permissions).

## Ajouter un module

1. Créer `module/<nom>/` avec au minimum `config.lua` (réglages) et `server/main.lua` et/ou `client/main.lua`.
2. Si le module a une échelle de permissions (grades), suivre le pattern de `module/atelier/shared/permissions.lua` ou `module/mdt/shared/permissions.lua` : une table de grades avec des `grants` cumulatifs, vérifiée aussi bien côté client (affichage) que côté serveur (autorité réelle — jamais faire confiance à un `job`/`grade` envoyé par le client).
3. Déclarer les fichiers dans `fxmanifest.lua` racine, dans l'ordre : `shared_scripts` (config) → `client_scripts` → `server_scripts`.
4. Si le module a besoin de tables, les créer via `MySQL.Async.execute('CREATE TABLE IF NOT EXISTS ... ', {})` au démarrage (voir n'importe quel `server/main.lua` existant) — la table se crée toute seule au premier lancement, pas besoin de migration manuelle. Documenter le schéma dans un `module/<nom>/sql/<nom>.sql` de référence si le module a plusieurs tables (voir `module/atelier/sql/atelier.sql` pour un exemple).
5. Ajouter les events serveur déclenchables par le client dans `LSLegacy.RateLimit` (`server/function.lua`).
6. Si le module expose un webhook Discord ou une clé API, la lire via `GetConvar('lslegacy_<nom>', '')` — **ne jamais coder une clé ou une URL de webhook en dur dans le code**, elles doivent être définies dans `server.cfg`, qui n'est jamais versionné.

## Base de données

`winframe_database.sql` (racine) documente le socle. Chaque module aux tables non triviales a son propre fichier de référence sous `module/<nom>/sql/`. Ces fichiers sont indicatifs : le code source (`CREATE TABLE IF NOT EXISTS`) fait foi en cas d'écart, puisque c'est lui qui crée réellement les tables au démarrage.

## Anticheat et rate-limiting

`LSLegacy.RateLimit` (`server/function.lua`) plafonne le nombre de déclenchements autorisés par joueur pour chaque event sécurisé, sur une fenêtre glissante de 15s (`LSLegacy.PlayersLimit`, remise à zéro périodiquement). Dépasser la limite déclenche un `DropPlayer` immédiat. `shared/sv_config.lua` et `server/anticheat.lua` couvrent les protections plus générales (détection d'entités suspectes, contrôle de la triche côté client, etc.) — voir les commentaires de `Shared.Anticheat` pour la liste des options activables.
