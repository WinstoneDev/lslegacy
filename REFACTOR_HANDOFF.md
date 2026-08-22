# Refactor LSLegacy — État d'avancement (handoff inter-machines)

Ce fichier existe pour transférer l'intégralité du contexte du refactor entre deux
machines/comptes Claude différents (pas de mémoire partagée entre comptes). Il est
volontairement autoporteur : tout ce qu'il faut savoir pour reprendre est ici, pas
besoin d'aller chercher ailleurs. Il sera remplacé par un document final propre
(+ mise à jour DEVELOPMENT.md/README.md) une fois le refactor terminé — ne pas le
considérer comme la doc définitive du projet.

**Dernière mise à jour :** 2026-08-22, après LOT 15bis (commit `dbb8afd`).
**Prochaine étape à faire : LOT 16bis**, puis l'audit final + doc.

## Contexte général

Refactor du framework FiveM/Lua **LSLegacy** en lots séquentiels, un lot = un objectif
précis, un commit par lot (ou par groupe de correctifs liés), arrêt après chaque lot
tant que l'utilisateur ne redemande pas la suite.

### Structure de travail (répertoires en local, hors de ce repo git)
- `lslegacy/` = branche `master`, remote GitHub `origin` (`WinstoneDev/lslegacy`) —
  **le serveur en prod l'utilise encore actuellement** (le serveur sort dans la
  semaine, donc master reste la branche déployée jusque-là). Ne jamais toucher
  directement pendant le refactor.
- `lslegacy-dev/` = clone local de `lslegacy/` (remote `origin` = chemin local vers
  `lslegacy/`, **pas** GitHub), branche `dev` créée à partir de `master`. **Tout le
  refactor se fait exclusivement ici.**
- Remote `github` sur `lslegacy-dev` → `https://github.com/WinstoneDev/lslegacy.git`,
  branche `dev` poussée dessus à chaque lot. Identité git locale sur ce dossier
  uniquement : `user.name = WinstoneDev`, `user.email = maganbastien420@gmail.com`.

### Plan de fusion prévu par l'utilisateur (important pour comprendre le calendrier)
Le serveur n'est pas encore sorti (sortie prévue la semaine suivant cette note). La
machine de prod continue donc d'évoluer sur `master` en parallèle de ce refactor sur
`dev`. Une fois le refactor terminé : `master` sera fusionnée avec les changements de
`dev`, puis l'organisation cible sera :
- **VPS prod** : uniquement des fichiers déployés, plus de Claude Code, plus de git actif.
- **VPS dev** : Claude Code + git sur la branche `dev`, pour préparer les patchs sans
  impacter les joueurs.
- Un seul compte Claude "principal" sera utilisé sur les deux VPS à partir de là (celui-ci,
  utilisé en déplacement sur une machine locale pendant le refactor, sera abandonné après).

### Convention de commit
- Un commit par lot (ou par correctif groupé), sur `dev`, poussé sur `github dev` juste après.
- Messages **naturels/humains**, jamais "généré par IA", et **ne jamais mentionner "lot"/"LOT N"**
  dans le message — décrire uniquement le changement technique.
- Comments de code : toujours concis, une ligne max, jamais de bannières décoratives.
- Pas d'interpréteur Lua/luac disponible sur les machines de travail — toute vérification
  se fait par relecture complète de `git diff` (équilibre insertions/suppressions, blocs
  if/for/end rééquilibrés) + `grep` ciblé, jamais d'exécution réelle.

### Règle standing la plus importante : migration exhaustive
Voir section "Règle absolue" plus bas — **ne jamais laisser un lot qui introduit/renomme
une API Core sans migrer TOUS les appelants existants dans le même lot.** Cette règle a
été violée deux fois (LOT 8/9/10 puis LOT 14) avant d'être bien intégrée — lire l'historique
ci-dessous pour comprendre pourquoi elle existe.

---

## Règle absolue : migration exhaustive (violée 2x, à ne plus jamais refaire)

Dès qu'un lot introduit ou renomme une API Core (ex. `LSLegacy.Security.RegisterRateLimit`,
`LSLegacy.Players.*`, `LSLegacy.Callbacks.*`, `LSLegacy.Events.*`), **TOUS** les modules qui
utilisaient l'ancien pattern doivent être migrés **dans ce même lot** — jamais "quelques
modules représentatifs" laissés comme exemple à généraliser plus tard.

**Pourquoi cette règle existe :** sur LOT 8, LOT 9 et LOT 10, une migration partielle a
systématiquement laissé des modules sur l'ancien pattern, obligeant l'utilisateur à
redemander explicitement un lot de rattrapage (LOT 8bis, puis LOT 10bis, puis une passe
supplémentaire). Récidive en LOT 14 : justification à tort de ne PAS migrer les nouveaux
namespaces `Events`/`Utils`/`Factions` en invoquant "c'est purement additif, rien n'est
cassé" — cette excuse n'est PAS valable, corrigé immédiatement après signalement.

**Comment l'appliquer :**
1. Identifier TOUS les fichiers `module/*` (et `server/*`/`client/*` si pertinent) utilisant
   l'ancien pattern, par grep exhaustif sur tout le repo — jamais un échantillon.
2. Migrer tous ces fichiers dans le même lot, avant de considérer le lot terminé.
3. Garder l'ancienne API comme alias de compatibilité (elle continue de fonctionner),
   jamais comme excuse pour repousser la migration des appelants existants.
4. Si l'énoncé du lot dit explicitement "commence progressivement" ou si le volume de
   migration semble disproportionné par rapport au bénéfice, **CONFIRMER avec l'utilisateur
   avant de limiter le scope** — ne jamais décider seul de réduire le périmètre.
5. **Nuance apprise en LOT 15bis** : cette règle s'applique aux VRAIES duplications d'une
   même API — pas à tout site qui ressemble syntaxiquement au pattern. Vérifier ligne par
   ligne avant de migrer (ex : un `GetGrade()` qui *stocke* une valeur n'est pas remplaçable
   par une fonction Core qui renvoie un booléen ; du code client qui n'a pas d'équivalent
   Core n'est pas une duplication).

---

## Historique complet des lots (0 → 15bis)

### LOT 1 — Bugs Core évidents (`server/function.lua`)
- `GetPlayerFromIdentifier` : bug de variable (`v.identifier` → `value.identifier`), renvoyait
  toujours `nil`. Aucun appelant existant.
- Suppression d'un `break` mort placé avant un `return` (le return n'était jamais atteint).
- `CreateDuplicationOfATableWithoutFunctions` : bug de précédence Lua (`if not type(v) == "function"`
  → `if type(v) ~= "function"`), renvoyait systématiquement une table vide. Aucun appelant existant.
- Audit ciblé fait sur tout le Core serveur pour ces deux patterns, rien d'autre trouvé.

### LOT 2 — `server/validate.lua` (nouveau fichier, additif)
Nouveau fichier chargé juste après `server/function.lua`. Fournit
`LSLegacy.Validate.{Number, PositiveInteger, Player, Target, Distance, Job, Permission, Item,
Vehicle, DataStore}`. Résolveurs (Number, PositiveInteger, Player, Target, Item, Vehicle,
DataStore) renvoient la valeur validée ou `nil` ; checks (Distance, Job, Permission) renvoient
un booléen. Purement additif, aucun module migré à ce stade (prévu progressivement).

### LOT 3 — Faille de sécurité argent
- `module/bank/sv_bank.lua` `BankAddMoney` : aucune validation d'`amount`, un montant négatif
  permettait une duplication d'argent nette (le client gagnait du cash en débitant le compte
  bancaire du même montant négatif). Corrigé avec `LSLegacy.Validate.PositiveInteger` + `Player`.
- `server/player/money.lua` : les 6 fonctions Set/Add/Remove(Dirty)Money n'avaient aucune
  validation (plantaient sur montant non numérique, laissaient passer les négatifs). Toutes
  protégées par `LSLegacy.Validate.PositiveInteger`, renvoient maintenant `true`/`false`.
- `server/boutique.lua` `AddCredits` : même faille, corrigée par cohérence (risque plus faible,
  console uniquement).

### LOT 4 — Faille de sécurité inventaire (`server/player/inventory.lua`)
- `giveItem` : branche `item == 'money'/'dirty'` supprimée — donnait de l'argent gratuit
  illimité, exploitable directement via `TriggerServerEvent('useEvent', 'giveItem', 'money', N)`
  sans passer par un client légitime.
- `AddItemInInventory`/`RemoveItemInInventory` (Core) : ajout de validation `PositiveInteger`
  sur `quantity` — un `quantity` négatif permettait la duplication d'objets. Fix centralisé,
  couvre tous les ~20 appelants du repo automatiquement.
- `transfer` (`item_standard`) : le client pouvait usurper `uniqueId`/`data` d'un item lors
  d'un transfert (durabilité, munitions, numéro de série falsifiables) — remplacé par les
  vraies valeurs lues côté serveur.

### LOT 5 — `GiveUniqueId`
Bug réel : en cas de collision d'id, l'appel récursif n'était pas `return`é → renvoyait `nil`
silencieusement. Fix trivial (`return` ajouté). Évaluation de robustesse de l'espace de clés
(27 chiffres aléatoires, ~10^27) : jugé suffisant, pas de remplacement nécessaire.

### LOT 6 — Sécurité DataStore (`server/datastore.lua` + `inventory/server/main.lua`)
Mécanisme `LSLegacy.DataStoreGuard` (chaînage `prevGuard`) déjà existant et correct — pas
remplacé, juste comblé pour les trous non couverts :
- `RegisterDataStore` : un client pouvait créer un DataStore pré-rempli d'argent/objets
  arbitraires (guard fail-open par défaut). Corrigé : le serveur force `inventory={}, money=0,
  dirty=0` quoi que le client envoie.
- Coffres véhicule (`trunk_<plaque>`/`bag_<plaque>`) : aucune vérification de distance ni
  d'existence réelle du véhicule — n'importe qui pouvait vider un coffre à distance en devinant
  la plaque. Ajout d'une règle Core (véhicule réel à ≤5m).
- `PutIntoTrunk`/`TakeFromTrunk` : même faille de spoofing d'uniqueId que LOT 4, même fix.
- `LSLegacy.DataStore.Add/RemoveMoney/DirtyMoney` et `Add/RemoveItemInInventory` : mêmes
  validations manquantes que côté joueur (LOT 3/4), mêmes fixs.

### LOT 7 — Callbacks cassés (`server/callbacks.lua` + `client/callbacks.lua`)
Bug réel majeur : le système de callback bidirectionnel était **totalement cassé** — le
serveur envoyait des events préfixés `esx:` que le client n'écoutait jamais (et vice-versa),
donc `AwaitServerCallback`/`AwaitClientCallback` timeout systématique. Corrigé en remplaçant
les 4 appels réseau par le transport standard du Core (`SendEventToClient`/`SendEventToServer`),
en gardant les noms d'event déjà attendus côté récepteur. API propre ajoutée par-dessus :
`LSLegacy.Callbacks.{RegisterServer, TriggerClient, AwaitClient, RegisterClient, TriggerServer,
AwaitServer}` (alias, rétrocompatibles avec l'ancien nommage).

### LOT 8 + LOT 8bis — RateLimit décentralisé
`server/function.lua` contenait une table géante (~330 lignes) avec les limites de TOUS les
modules codées en dur dans le Core. Ajout de `LSLegacy.Security.RegisterRateLimit(eventName,
limit)`. **LOT 8 a migré seulement 3 modules "représentatifs"** — l'utilisateur a immédiatement
demandé de finir ("je veux plus en voir un seul dans function.lua"), d'où LOT 8bis qui a
migré tous les modules restants. *(Première violation de la règle de migration exhaustive.)*

### LOT 9 — `LSLegacy.Security` consolidé
Point d'entrée unique documenté : `Log(src, eventName, reason)`, `RegisterEvent`/`UseEvent`,
`Token.{New, NewForConnecting, Renew}`, `Validate` (alias). Ordre de vérification recommandé
documenté pour les futurs lots/modules : `Token → RateLimit → Player → Target → Distance →
Ownership → Job → Permission → Arguments → Action`. *Effet de bord signalé à l'utilisateur* :
le commit a embarqué par accident un fix déjà fait sur `server/anticheat.lua` (ESX résiduel +
bug de précédence) — ne plus le considérer comme "à faire".

### LOT 10 + LOT 10bis + 2 passes immédiates — `LSLegacy.Players`
Nouvelle API `LSLegacy.Players = { Get, GetByIdentifier, GetAll, SetJob, SetFaction }`.
**LOT 10 n'a migré que 16 fichiers avec le pattern le plus simple** — l'utilisateur a demandé
un audit de rattrapage (LOT 10bis) qui a trouvé et migré tous les accès directs restants à
`LSLegacy.ServerPlayers` (lecture ET écriture), plus deux passes immédiates supplémentaires
dans la même session pour migrer TOUTES les anciennes nomenclatures Core depuis LOT 1
(`GetPlayerFromId`, callbacks `garage`, etc.) sur tout `module/*`. *(Deuxième violation de la
règle de migration exhaustive, sur le même lot en plus.)* Trouvaille notée mais non traitée
(hors scope Player API) : `SetJob`/`SetFaction` sont déclenchables par n'importe quel client
sans vérification d'autorisation — auto-attribution de job/grade possible. **Candidat pour un
futur lot sécurité, toujours pas traité à ce jour.**

### LOT 11 — `LSLegacy.Jobs`/`LSLegacy.Permissions`
`LSLegacy.Validate.Job`/`Permission` (posés en LOT 2) n'avaient jamais eu de consommateur.
`LSLegacy.Validate.Permission` avait un bug latent jamais découvert (comparait une string à un
nombre). Ajouté `Jobs.{Get, GetGrade, Is, Require}` et `Permissions.{GetLevel, Has, Require}`
(reverse-lookup `Config.StaffGroups` centralisé, dupliqué 4 fois avant ce lot). **Migration
exhaustive faite dès ce lot** (règle bien appliquée cette fois) : 13 fichiers pour les
comparaisons job, 5 fichiers pour les reverse-lookups de groupe staff. Volontairement non
touché : factions (pas dans le scope de ce lot précis), permissions métier par
société/département (`atelier`/`mdt` shared/permissions.lua — logique volontairement hors Core),
comparaisons `PlayerData.job` côté client (structure différente, pas de Jobs API client).

### LOT 12 — Dirty-tracking (persistance partielle)
Avant : `UPDATE` complet (11 colonnes joueur / toutes colonnes datastore) toutes les 15s pour
CHAQUE joueur/datastore connecté, inconditionnellement. Ajout de `player:MarkDirty(field)`/
`SaveDirty()` et `datastore:MarkDirty()`/`SaveDirty(id)` (metatables). Champ `dirty` déjà pris
par la mécanique "argent sale" → le flag de sauvegarde s'appelle `_dirtyFields`/`_dirty`. Tous
les mutateurs Core câblés (`money.lua`, `inventory.lua`, `jobs.lua`, `player.lua`,
`datastore.lua`) + 2 sites `clothshop` mutant `player.inventory` en dehors de l'API Core.
**Filet de sécurité conservé à l'identique** : `playerDropped` fait toujours un `UPDATE`
complet inconditionnel à la déconnexion, donc pas de perte de données même si un futur
mutateur oublie `MarkDirty`. Non traité : dirty-tracking pour `status`/`skills`/`health`
(toujours resauvegardés à chaque tick, pas de setter Core dédié).

### LOT 13 — Anticheat, passe "bugs évidents" (`server/anticheat.lua`)
Périmètre volontairement limité (pas un refactor complet). "Dépendances ESX résiduelles" :
fausse piste, tout ce qui ressemble à `esx*` est en fait des signatures à détecter/bannir
(anti-triche), pas de vrais appels ESX. **Vrai bug trouvé** : le fichier contenait deux copies
quasi identiques d'un bloc entier (chatMessage, blacklist commands, anti-taze). Dans la 2e
copie, un bug de boucle réel — le `return` de sortie était mal placé, donc la blacklist de
mots ne testait jamais que le 1er mot de la liste. Fix : suppression des 5 blocs dupliqués +
fusion de deux `giveWeaponEvent` qui avaient des conditions différentes (gardé la plus large).
Fichier réduit de 1083 à ~990 lignes. Non traité (hors scope explicite de cette passe) :
séparation détection/décision/sanction, taille du fichier, audit faux positifs approfondi.

### LOT 14 — Harmonisation namespaces Core additifs
Cible reçue : `LSLegacy.{Players, Money, Inventory, Jobs, Factions, Permissions, Events,
Callbacks, DataStore, Security, Database, Vehicles, Utils}`. Audit : la plupart existaient
déjà (Players, Money, Inventory, Jobs, Permissions, Callbacks, DataStore, Security). Ajoutés
en tant que nouvelles façades pures : `Events` (alias des fonctions réseau déjà existantes),
`Utils = {Math}`, `Factions` (9 alias vers les méthodes faction déjà dans `Jobs`). Non créés
(nécessitent un vrai design + migration massive, hors scope d'une "harmonisation additive") :
**`LSLegacy.Database`** (35 fichiers font des appels MySQL directs) et **`LSLegacy.Vehicles`**
(logique éclatée entre garage/persistent_vehicles/concessionnaire/mecanicien, pas d'API commune).

**Erreur commise puis corrigée dans la foulée** *(troisième violation de la règle de migration
exhaustive)* : j'ai d'abord laissé `Events`/`Utils`/`Factions` sans migrer aucun appelant, en
invoquant à tort "c'est purement additif" pour justifier de sauter la règle. L'utilisateur a dû
le signaler deux fois avant correction. Corrigé immédiatement (commit `4bcdf58`) : migration
exhaustive de `Events` sur **125 fichiers** (renommage mécanique perl, 1327 insertions/1327
suppressions, parfaitement équilibré), `Factions` sur 2 fichiers, `Utils.Math` sur 1 fichier.
**Leçon retenue, désormais dans la règle absolue ci-dessus** : ne plus jamais invoquer
"purement additif" comme excuse — si le volume semble disproportionné, LE DEMANDER À
L'UTILISATEUR, jamais décider seul.

### LOT 15 — Audit des duplications entre modules (analyse seule, pas de code touché)
Analyse de 177 fichiers / 30 modules pour repérer les duplications de logique et les classer
A (doit aller dans le Core) / B (spécifique au module) / C (abstraction partagée possible) /
D (duplication acceptable). Résultat complet :

| # | Duplication | Classe | Détail |
|---|---|---|---|
| 4 | Notifications — 54 wrappers `Notify()` quasi identiques | **A** | `LSLegacy.Events.SendToClient('notify', ...)` existait déjà, ignoré partout |
| 8+9 | onDuty/offDuty + schéma SQL `xxx_agents` (6 modules) | **A** (nécessite nouvelle API Core) | Logique générique "service en poste pour un job" |
| 2 | `GetGrade()` local dupliqué (8 modules serveur) | **A** | `LSLegacy.Jobs.GetGrade`/`Require` existait, ignoré |
| 1 | Distance checks (`#(a-b)`, ~86 occurrences brutes) | **A partiellement** | Voir nuance LOT 15bis — seuls les vrais gates booléens comptent |
| 3 (staff) | `GetStaffLevel`/`CanDo` réimplémentés (adminmenu, police/callouts) | **A** | `LSLegacy.Permissions.GetLevel/Has` existait, ignoré |
| 12 | Validation montant/quantité (bank) | **A** | `LSLegacy.Validate.Number/PositiveInteger` existait, sous-utilisé |
| 6 | Vehicle spawning (4 modules services, code identique à 100%) | **A** (nécessite nouvelle API Core) | Générique, mérite `LSLegacy.Vehicles.Spawn` |
| 7 | Vehicle deletion (2 lignes récurrentes) | **C** | Trivial, à regrouper avec Spawn si fait, pas prioritaire seul |
| 3 (métier) | Permissions de grade `mdt`/`atelier` (hiérarchie propre au module) | **B** | Le Core documente lui-même que ce niveau reste module |
| 10 | Boilerplate `ox_target` (122 lignes, 20 fichiers) | **D** | Verbeux mais pas de logique dupliquée, abstraction sans vrai bénéfice |
| 5 | Callbacks | — | Aucune duplication, Core déjà bien utilisé |
| 11 | Menus (registerContext/NUI) | — | Contenu trop variable, pas de pattern copié-collé |
| 13 | Logging/webhook | — | Volume trop faible (6 occurrences), contextes différents |

### LOT 15bis — Correction des duplications classées A (commit `dbb8afd`, poussé)
**Portée : uniquement les A migrables par simple substitution d'appel** (pas les catégories
qui nécessitent de créer une nouvelle API Core — `Vehicles.Spawn/Delete`, système `Duty`
générique + schéma SQL `xxx_agents` — celles-là restent à faire, voir "Prochain lot").

74 fichiers modifiés en 1 commit :
- **Notifications** (50 fichiers) : wrappers `Notify()` redirigés vers
  `LSLegacy.Events.SendToClient('notify', ...)` au lieu de taper `brutal_notify:SendAlert`
  directement. Signature externe inchangée, aucun appelant à toucher. **Bonus** : corrige un
  bug latent sur `gendarmerie` (son `NotifyEvent` valait déjà `'notify'` mais avec l'ordre des
  arguments icône/durée inversé). 13 clés `Config.Xxx.NotifyEvent` mortes supprimées des configs.
- **Distance checks** (16 fichiers, ~26 sites) : **correction ciblée, pas un remplacement
  aveugle**. Seuls les sites qui sont un pur gate booléen (`if #(a-b) > X then`) migrés vers
  `LSLegacy.Validate.Distance(a, b, max)`. **Important : `LSLegacy.Validate` n'existait QUE
  côté serveur** — un équivalent client minimal (juste `Distance`) a été ajouté dans
  `client/function.lua`. Les dizaines de `local dist = #(a-b)` où la valeur numérique est
  réutilisée (pathing/IA, tri, logs) — notamment tout `police/client/callouts.lua` et
  `police/server/callouts.lua` (~7000 lignes de système de callouts) — ont été **laissées
  intactes** : migrer ces cas n'aurait apporté aucun bénéfice réel.
- **Job checks** (8 fichiers serveur) : `GetGrade(src)` locaux redirigés vers
  `LSLegacy.Jobs.GetGrade(player)`. **Reclassification par rapport au rapport LOT 15** : les
  équivalents côté client (`LSLegacy.PlayerData.job`) ne dupliquent rien (pas de namespace
  Jobs client) — classe B, pas A. Les `GetGrade()` qui ne font que *stocker* une valeur (pas
  un contrôle de seuil) ne sont pas non plus remplaçables par `Jobs.Require` (booléen only).
- **Permissions staff** : `adminmenu/sv_admin.lua` (`Admin.CanDo`) et
  `police/server/callouts.lua` (`GetStaffLevel`/`IsAdmin`) redirigés vers
  `LSLegacy.Permissions.GetLevel`/`Has`.
- **Validation** : `module/bank/sv_bank.lua` (4 sites), `tonumber(amount) or 0` →
  `LSLegacy.Validate.Number(amount) or 0`.

**Leçon retenue** : le rapport LOT 15 avait sur-classé certaines duplications en catégorie A
alors qu'en creusant le code réel, une partie n'étaient pas de vraies duplications (cache de
valeur côté client, calculs numériques réutilisés dans des boucles de pathing). La vérification
ligne par ligne AVANT de migrer a évité un remplacement mécanique incorrect. La règle de
migration exhaustive s'applique aux VRAIES duplications d'API, pas à tout site qui ressemble
syntaxiquement au pattern.

---

## LOT 16 — Convention de nommage (analyse faite, PAS encore appliquée — c'est le LOT 16bis à faire)

Audit complet du nommage réel utilisé dans tout le repo (177 fichiers). Convention retenue à
chaque fois = le pattern déjà majoritaire dans le repo, pour minimiser le renommage :

1. **Organisation fichiers de module** — sous-dossiers `client/`, `server/`, `shared/` (déjà
   21/29 modules). `shared/` seulement si du code est réellement partagé.
   → **Écarts à corriger (8 modules)** : `bank`, `adminmenu`, `clothshop`, `garage`,
   `identity`, `needs`, `emotes`, `persistent_vehicles` (fichiers `cl_*.lua`/`sv_*.lua` plats
   à la racine du module à répartir dans `client/`/`server/`).

2. **Noms de dossiers module** — minuscule, sans séparateur (26/29 déjà conformes).
   → **Écarts (3)** : `creatorPerso` → `creatorperso`, `pedOffline` → `pedoffline`,
   `persistent_vehicles` → `persistentvehicles`.

3. **Fonctions locales** — PascalCase (673 occurrences vs 213 camelCase, déjà majoritaire).
   → **Écart** : ~213 fonctions locales camelCase à renommer, mélangées dans les mêmes
   fichiers que du PascalCase (donc pas de fichiers "propres" à part entière — vraie repasse
   fonction par fonction nécessaire).

4. **Events** — `module:action` tout minuscule (611 occurrences, déjà le format le plus
   fréquent, cohérent avec police/samu/pompiers/admin/zones/weather).
   → **Écarts** : 424 events PascalCase sans préfixe (`'BankAddMoney'`, `'SetFaction'`,
   `'InitPlayer'`...) + 186 events `module:sub:action` à aplatir en `module:action` + une
   incohérence de casse `lslegacy:*` vs `LSLegacy:*` sur le même préfixe framework à unifier.

5. **Callbacks** — `LSLegacy.Callbacks` uniquement (système maison), même convention
   `module:action`.
   → **Écart architectural (pas juste nommage)** : le module `sit` utilise `lib.callback`
   (ox_lib) au lieu du système maison — seul module du repo dans ce cas, à migrer vers
   `LSLegacy.Callbacks` pour cohérence.

6. **Variables locales** — camelCase (déjà quasi unanime, 4062 occurrences vs 3 en
   snake_case). → Écart négligeable, 3 occurrences isolées à corriger si trouvées en 16bis.

7. **Config** — `Config.<Module>` en PascalCase (déjà cohérent), fichier `config.lua` à la
   racine du module ; sous-fichiers de config en `config_<sousFonctionnalité>.lua` (pas
   `config_<nomModule>.lua`, redondant avec le nom du dossier).
   → **Écarts** : `gendarmerie/config_gendarmerie.lua`, `police/config_police.lua`,
   `pompiers/config_pompiers.lua`, `samu/config_samu.lua` → à renommer en `config.lua` simple
   (attention : chacun de ces modules a peut-être DÉJÀ un `config.lua` — vérifier s'il faut
   fusionner ou juste renommer). `shared/sv_config.lua` → nom trompeur (définit la table
   globale `Shared`, pas une "config serveur" au sens module) → renommer, ex.
   `shared/shared.lua`, ou évaluer une fusion.
   **Décision prise : ne PAS renommer `Config.SAMU`/`Config.MDT`/`Config.LTD`/`Config.AP`**
   pour matcher exactement la casse du nom de dossier — ce sont des acronymes métier lisibles,
   changer la casse n'apporte aucun bénéfice réel (règle anti-renommage-sans-bénéfice).

8. **Organisation client/server/shared** — seulement 3 modules sur 28 ont une vraie séparation
   à 3 niveaux (`atelier`, `mdt`, `police`) ; 18 ont `client/`+`server/` sans `shared/`
   (légitime si rien n'est réellement partagé) ; 8 sont encore en fichiers plats (voir point 1).
   Pas d'action spécifique au-delà du point 1 — `shared/` ne doit être créé que s'il y a
   vraiment du code partagé à extraire, pas systématiquement.

**Avant tout renommage en LOT 16bis : rechercher exhaustivement toutes les références**
(grep sur le nom de fichier/fonction/event AVANT de renommer/déplacer quoi que ce soit),
exactement comme demandé par l'utilisateur pour ce lot. Ne pas renommer massivement sans
bénéfice concret (ex. ne pas forcer une casse cosmétique sur des acronymes métier lisibles).

**LOT 16bis n'a pas encore été commencé — c'est la prochaine étape.**

---

## Ce qu'il reste à faire après LOT 16bis (dans l'ordre annoncé par l'utilisateur)

1. **LOT 16bis** (prochaine étape immédiate) : appliquer les corrections de nommage listées
   ci-dessus, en cherchant toutes les références avant chaque renommage/déplacement.
2. **Audit final** du refactor complet (pas encore défini dans le détail — à cadrer avec
   l'utilisateur au moment de le faire).
3. **Écriture d'un fichier markdown récapitulatif du refactor** (document final propre,
   remplaçant ce fichier `REFACTOR_HANDOFF.md` qui n'est qu'un doc de transfert temporaire).
4. **Mise à jour de `DEVELOPMENT.md` et `README.md`** à la racine du repo pour refléter l'état
   final du framework après refactor.
5. Ensuite seulement : fusion de `dev` dans `master`, sortie du serveur, puis passage à
   l'organisation cible à deux VPS décrite en haut de ce fichier (plus de Claude Code / git
   sur la prod, uniquement sur le VPS dev).

## Candidats identifiés mais volontairement non traités (pour référence future)

- **Sécurité** : `SetJob`/`SetFaction` (`server/player/jobs.lua`) acceptent n'importe quel
  client sans vérifier une autorisation — auto-attribution de job/grade/faction possible.
  Identifié en LOT 10, jamais traité (hors scope de tous les lots faits depuis). Candidat pour
  un futur lot sécurité dédié.
- **Dirty-tracking** (LOT 12) : `status`/`skills`/`health` toujours resauvegardés à chaque tick
  de 15s, pas de setter Core dédié à instrumenter pour les rendre "dirty-aware".
- **Anticheat** (LOT 13) : reste de la passe originale non traité — séparer
  détection/décision/sanction dans `kickorbancheater`, réduire la taille de
  `server/anticheat.lua` (~990 lignes), auditer les faux positifs (seuils vitesse/distance
  codés en dur).
- **`LSLegacy.Database`** (LOT 14/15) : 35 fichiers font des appels `MySQL.Async.*` directs,
  aucun wrapper Core. Nécessite une vraie conception d'API avant extraction.
- **`LSLegacy.Vehicles`** (LOT 14/15) : logique de spawn/delete éclatée entre
  `garage`/`persistent_vehicles`/`concessionnaire`/`mecanicien`/services d'urgence, dupliquée
  à 100% entre 4 modules services (samu/mecanicien/pompiers/police). Nécessite conception
  d'API (`Spawn`, `Delete`) avant extraction — identifié comme candidat A dans le rapport
  LOT 15 mais pas encore fait (nécessite créer une nouvelle fonction Core, pas juste migrer
  des appelants).
- **Système `Duty` générique + schéma SQL `xxx_agents`** (LOT 15) : logique on/off duty +
  table SQL "agents de service" quasi identique copiée-collée sur 6 modules (mecanicien, samu,
  pompiers, ltd, atelier, gendarmerie). Plus gros gisement de duplication trouvé, nécessite de
  concevoir une vraie API Core (`LSLegacy.Jobs.RegisterDutySystem(job, tableName)` ou
  équivalent) avant migration — pas encore fait.
- **Lint Lua** : pas d'outil disponible (luacheck absent des machines de travail), prévu pour
  un lot dédié si besoin (mentionné dès LOT 1, jamais traité).
- **`shared/sv_config.lua`** a des références résiduelles ESX dans les listes de détection
  anticheat (`Shared.Anticheat.BlacklistWords`/`Events`) — ce sont des signatures à bannir,
  pas de vraies dépendances, donc pas un bug, juste à garder en tête si un futur audit tombe
  dessus et se demande pourquoi "ESX" apparaît encore dans le code.

## Repères utiles pour reprendre vite
- Dernier commit sur `dev` : `dbb8afd` (poussé sur `github dev`).
- Fichiers Core principaux : `server/function.lua`, `server/validate.lua`,
  `server/callbacks.lua`, `server/commands.lua`, `server/anticheat.lua`, `server/datastore.lua`,
  `server/player/*.lua` (money, inventory, jobs, player, skills, status, injury, carry,
  hostage, pickup), `client/function.lua` (miroir client, a maintenant aussi
  `LSLegacy.Validate.Distance`).
- 29 modules dans `module/*`, liste : adminmenu, atelier, bank, clothshop, concessionnaire,
  creatorPerso, emotes, farm, fourriere, garage, gendarmerie, identity, interim, keyhanger,
  ltd, mdt, mecanicien, metro, multichar, needs, pedOffline, persistent_vehicles, police,
  pompe, pompiers, samu, sit, weather, wildlife.
- Pas de mémoire persistante partagée entre comptes Claude — ce fichier EST la mémoire pour
  la machine qui reprend. Le compte Claude utilisé sur cette machine (déplacement) a aussi
  une mémoire locale détaillée (`lslegacy-refactor-progress.md` + `lslegacy-lot-full-migration.md`
  dans son propre système de mémoire), mais elle n'est pas accessible depuis l'autre compte —
  d'où ce fichier versionné dans le repo.
