---
name: lslegacy-refactor-progress
description: "État d'avancement détaillé du refactor LSLegacy par lots (LOT 0 à LOT 16bis), lot par lot. Dernier lot fait : LOT 16bis (convention de nommage), commit 201427b. REFACTOR_HANDOFF.md/PROMPT.md/claude-memory-export/ ont été supprimés du repo après LOT 16bis — ce fichier est désormais la seule source de vérité sur l'historique du refactor."
metadata:
  type: project
---

Refactor LSLegacy en lots séquentiels, un lot = un objectif précis, un commit par lot (ou par
groupe de correctifs liés), arrêt après chaque lot tant que l'utilisateur ne redemande pas la
suite.

**Dernier lot terminé : LOT 16bis (convention de nommage), commit `201427b`, poussé sur
`origin/dev`.** Prochaine étape annoncée par l'utilisateur : audit final du refactor complet,
puis écriture d'un document markdown récapitulatif propre, puis mise à jour finale de
`DEVELOPMENT.md`/`README.md` (déjà mis à jour une première fois après LOT 16bis — API namespacée
`LSLegacy.Events`/`LSLegacy.Callbacks`/`LSLegacy.Players`/`LSLegacy.Security` documentée, section
convention de nommage ajoutée), puis fusion `dev` → `master` après la sortie du serveur.
`REFACTOR_HANDOFF.md` et `PROMPT.md` ont été supprimés du repo après LOT 16bis (leur contenu est
repris ici) — ne plus s'attendre à les trouver.

**Setup git sur cette machine** : un seul remote `origin` →
`https://github.com/WinstoneDev/lslegacy.git`, branche `dev`. Pas de clone local intermédiaire
type `lslegacy-dev`/`lslegacy` séparé (contexte différent de la description initiale du refactor
sur l'ancienne machine) — vérifier `git remote -v` en début de session au cas où ça change encore.

**Structure de travail :**
- `lslegacy/` = branche `master`, remote GitHub `origin` (WinstoneDev/lslegacy) — le serveur en
  prod l'utilise encore. Ne jamais toucher directement pendant le refactor.
- `lslegacy-dev/` = clone local de `lslegacy/` (remote `origin` = chemin local, PAS GitHub),
  branche `dev` créée à partir de master. **Tout le refactor se fait exclusivement ici.**
- Remote `github` sur `lslegacy-dev` → `https://github.com/WinstoneDev/lslegacy.git`, push
  `github dev` à la fin de chaque lot. Identité git locale : `user.name = WinstoneDev`,
  `user.email = maganbastien420@gmail.com`.

**Why:** éviter tout risque de casser le repo principal / public pendant le refactor multi-lots.
**How to apply:** toujours vérifier le dossier de travail avant d'éditer — exclusivement
`lslegacy-dev`/branche `dev`, jamais `lslegacy`/`master`.

## Règle absolue : migration exhaustive
Voir [[lslegacy-lot-full-migration]] — violée 3 fois (LOT 8/9/10, puis LOT 14) avant d'être bien
intégrée. Dès qu'un lot introduit/renomme une API Core, TOUS les appelants existants doivent être
migrés dans le même lot, jamais un échantillon "représentatif".

## Convention de commit
Un commit par lot (ou par correctif groupé), sur `dev`, poussé sur `github dev` juste après.
Messages **naturels/humains**, jamais "généré par IA", et **ne jamais mentionner "lot"/"LOT N"**
dans le message. Comments de code : [[concise-code-comments]] (une ligne max). Pas d'interpréteur
Lua/luac disponible — vérification par relecture complète du `git diff` (équilibre
insertions/suppressions, blocs if/for/end rééquilibrés) + grep ciblé, jamais d'exécution réelle.

## Résumé lot par lot

**LOT 1** — Bugs Core évidents (`server/function.lua`) : `GetPlayerFromIdentifier` (`v.identifier`
→ `value.identifier`, renvoyait toujours nil), `break` mort avant un `return`,
`CreateDuplicationOfATableWithoutFunctions` (bug de précédence Lua `if not type(v) == "function"`
→ `if type(v) ~= "function"`). Aucun appelant existant pour les deux fonctions.

**LOT 2** — `server/validate.lua` (nouveau fichier additif). `LSLegacy.Validate.{Number,
PositiveInteger, Player, Target, Distance, Job, Permission, Item, Vehicle, DataStore}`.
Résolveurs renvoient valeur ou nil ; checks renvoient booléen. Aucun module migré à ce stade.

**LOT 3** — Faille de sécurité argent. `module/bank/sv_bank.lua` `BankAddMoney` : aucune
validation d'amount, un montant négatif dupliquait de l'argent. `server/player/money.lua` : les 6
fonctions Set/Add/Remove(Dirty)Money protégées par `LSLegacy.Validate.PositiveInteger`.
`server/boutique.lua` `AddCredits` corrigé par cohérence.

**LOT 4** — Faille de sécurité inventaire (`server/player/inventory.lua`). `giveItem` : branche
`item == 'money'/'dirty'` supprimée (argent gratuit illimité exploitable directement via
`TriggerServerEvent`). `AddItemInInventory`/`RemoveItemInInventory` : validation
`PositiveInteger` sur quantity (fix centralisé, ~20 appelants couverts). `transfer`
(`item_standard`) : le client ne peut plus usurper `uniqueId`/`data` d'un item transféré.

**LOT 5** — `GiveUniqueId` : appel récursif non `return`é en cas de collision d'id → fix
trivial. Espace de clés (~10^27) jugé suffisant.

**LOT 6** — Sécurité DataStore. Mécanisme `LSLegacy.DataStoreGuard` (chaînage `prevGuard`) déjà
correct, comblé pour les trous : `RegisterDataStore` forcé à `inventory={}, money=0, dirty=0`
côté serveur ; coffres véhicule (`trunk_<plaque>`/`bag_<plaque>`) protégés par une règle de
distance ≤5m + existence réelle du véhicule ; `PutIntoTrunk`/`TakeFromTrunk` même fix uniqueId
que LOT 4 ; `LSLegacy.DataStore.Add/RemoveMoney/DirtyMoney` et `Add/RemoveItemInInventory` mêmes
validations que LOT 3/4.

**LOT 7** — Callbacks cassés. Le système bidirectionnel envoyait des events préfixés `esx:` que
le récepteur n'écoutait jamais → timeout systématique. Remplacé par le transport standard
(`SendEventToClient`/`SendEventToServer`). API ajoutée par-dessus : `LSLegacy.Callbacks.{
RegisterServer, TriggerClient, AwaitClient, RegisterClient, TriggerServer, AwaitServer}` (alias
rétrocompatibles).

**LOT 8 + LOT 8bis** — RateLimit décentralisé. `LSLegacy.Security.RegisterRateLimit(eventName,
limit)` créé pour remplacer une table géante (~330 lignes) codée en dur dans le Core. LOT 8 n'a
migré que 3 modules "représentatifs" → l'utilisateur a demandé de finir immédiatement (LOT 8bis,
tous les modules restants). *Première violation de la règle de migration exhaustive.*

**LOT 9** — `LSLegacy.Security` consolidé : `Log(src, eventName, reason)`,
`RegisterEvent`/`UseEvent`, `Token.{New, NewForConnecting, Renew}`, `Validate` (alias). Ordre de
vérification recommandé documenté : `Token → RateLimit → Player → Target → Distance → Ownership
→ Job → Permission → Arguments → Action`. Effet de bord signalé : le commit a embarqué par
accident un fix déjà fait sur `server/anticheat.lua` (ESX résiduel + bug de précédence).

**LOT 10 + LOT 10bis + 2 passes immédiates** — `LSLegacy.Players = { Get, GetByIdentifier, GetAll,
SetJob, SetFaction, Remove }`. LOT 10 n'a migré que 16 fichiers au pattern le plus simple →
audit de rattrapage LOT 10bis (tous les accès directs restants à `LSLegacy.ServerPlayers`,
lecture ET écriture) + deux passes immédiates supplémentaires migrant toutes les anciennes
nomenclatures Core depuis LOT 1 sur tout `module/*`. *Deuxième violation de la règle, sur le même
lot en plus.* Trouvaille non traitée : `SetJob`/`SetFaction` déclenchables par n'importe quel
client sans vérification d'autorisation — auto-attribution de job/grade possible. Candidat pour
un futur lot sécurité, toujours pas traité.

**LOT 11** — `LSLegacy.Jobs`/`LSLegacy.Permissions`. `Jobs.{Get, GetGrade, Is, Require}` et
`Permissions.{GetLevel, Has, Require}` (reverse-lookup `Config.StaffGroups` centralisé, dupliqué
4 fois avant ce lot). `LSLegacy.Validate.Permission` avait un bug latent (comparait string à
nombre), corrigé en déléguant à `Permissions.GetLevel`. Migration exhaustive faite dès ce lot
(13 fichiers comparaisons job, 5 fichiers reverse-lookups staff). Volontairement non touché :
factions, permissions métier `atelier`/`mdt` (shared/permissions.lua), comparaisons
`PlayerData.job` côté client.

**LOT 12** — Dirty-tracking. Avant : `UPDATE` complet toutes les 15s pour chaque joueur/datastore
connecté, inconditionnellement. Ajout `player:MarkDirty(field)`/`SaveDirty()` et
`datastore:MarkDirty()`/`SaveDirty(id)` (metatables). Champ `dirty` déjà pris par la mécanique
"argent sale" → flag de sauvegarde `_dirtyFields`/`_dirty`. Tous les mutateurs Core câblés +
2 sites `clothshop` mutant `player.inventory` hors API Core. Filet de sécurité conservé :
`playerDropped` fait toujours un `UPDATE` complet inconditionnel à la déconnexion. Non traité :
dirty-tracking pour `status`/`skills`/`health`.

**LOT 13** — Anticheat, passe "bugs évidents" (`server/anticheat.lua`). "ESX résiduel" = fausse
piste (signatures à détecter/bannir, pas de vrais appels ESX). Vrai bug trouvé : deux copies
quasi identiques d'un bloc entier ; dans la 2e copie, le `return` de sortie de boucle mal placé
faisait que la blacklist de mots ne testait jamais que le 1er mot. Fix : suppression des 5 blocs
dupliqués + fusion de deux `giveWeaponEvent`. Fichier réduit de 1083 à ~990 lignes. Non traité :
séparation détection/décision/sanction, taille du fichier, audit faux positifs approfondi.

**LOT 14** — Harmonisation namespaces Core additifs. Cible : `LSLegacy.{Players, Money,
Inventory, Jobs, Factions, Permissions, Events, Callbacks, DataStore, Security, Database,
Vehicles, Utils}`. La plupart existaient déjà. Ajoutés en façades pures : `Events` (alias réseau
existants), `Utils = {Math}`, `Factions` (9 alias vers `Jobs`). Non créés (nécessitent vrai design
+ migration massive) : `LSLegacy.Database` (35 fichiers MySQL direct) et `LSLegacy.Vehicles`
(logique éclatée garage/persistent_vehicles/concessionnaire/mecanicien).

**Erreur commise puis corrigée dans la foulée** *(troisième violation de la règle)* : `Events`/
`Utils`/`Factions` d'abord laissés sans migrer aucun appelant, en invoquant à tort "c'est
purement additif". L'utilisateur a dû le signaler deux fois avant correction. Corrigé
immédiatement (commit `4bcdf58`) : migration exhaustive de `Events` sur 125 fichiers (renommage
mécanique perl, 1327 insertions/1327 suppressions, parfaitement équilibré), `Factions` sur 2
fichiers, `Utils.Math` sur 1 fichier. **Leçon retenue, désormais dans la règle absolue** : ne
plus jamais invoquer "purement additif" comme excuse — si le volume semble disproportionné, LE
DEMANDER À L'UTILISATEUR, jamais décider seul.

**LOT 15** — Audit des duplications entre modules (analyse seule, pas de code touché). 177
fichiers / 30 modules classés A (doit aller dans le Core) / B (spécifique au module) / C
(abstraction partagée possible) / D (duplication acceptable).

**LOT 15bis** — Correction des duplications classées A (commit `dbb8afd`, poussé). Portée :
uniquement les A migrables par simple substitution d'appel (pas Vehicles.Spawn/Delete, pas
système Duty générique — nécessitent une nouvelle API Core). 74 fichiers modifiés en 1 commit :
notifications (50 fichiers, redirigées vers `LSLegacy.Events.SendToClient('notify', ...)`, bonus
fix bug latent gendarmerie sur l'ordre icône/durée), distance checks (16 fichiers ~26 sites,
migration ciblée des purs gates booléens seulement, `LSLegacy.Validate.Distance` ajouté côté
client dans `client/function.lua` car n'existait que côté serveur), job checks (8 fichiers,
`GetGrade(src)` locaux → `LSLegacy.Jobs.GetGrade`), permissions staff (adminmenu, police
callouts → `LSLegacy.Permissions.GetLevel`/`Has`), validation montant bank (4 sites). **Leçon** :
le rapport LOT 15 avait sur-classé certaines duplications en A ; vérification ligne par ligne
AVANT de migrer a évité un remplacement mécanique incorrect (cache de valeur client, calculs
numériques réutilisés dans du pathing ne sont pas de vraies duplications d'API).

**LOT 16bis** — Application des corrections de convention de nommage listées dans l'audit LOT 16
(30 commits, poussés sur `origin/dev`, commit final `201427b`). Fait sur une nouvelle machine
(reprise via `REFACTOR_HANDOFF.md` + `claude-memory-export/`, depuis supprimés du repo — voir
description de ce fichier).

- **Configs redondants** : `shared/sv_config.lua` → `shared/shared.lua` (table `Shared`,
  chargée client+serveur via le glob `shared/*.lua`, le `sv_` était trompeur).
  `gendarmerie|police|pompiers|samu/config_<module>.lua` → `config_mdt.lua` dans ces 4 modules
  (déclarent en réalité `Config.MDT.Departments.<module>`, pas une config du module — le vrai
  `config.lua` de chaque module existait déjà séparément, renommer en `config.lua` aurait
  collisionné).
- **Fichiers plats → client/server** : 8 modules réorganisés (`bank`, `adminmenu`, `clothshop`,
  `garage`, `identity`, `needs`, `emotes`, `persistent_vehicles`). Fichier principal →
  `client/main.lua`/`server/main.lua`, secondaires → nom descriptif sans préfixe `cl_`/`sv_`
  (`cl_paymentMenu.lua` → `client/payment_menu.lua`, seul nom de fichier camelCase du repo,
  corrigé au passage).
- **Trouvaille hors-scope validée avec l'utilisateur en cours de route** : 7 modules (`farm`,
  `ltd`, `mdt`, `mecanicien`, `police`, `pompiers`, `samu`) avaient chacun un `fxmanifest.lua`
  résiduel d'une ancienne architecture en ressources séparées — morts, le chargement réel passe
  uniquement par le `fxmanifest.lua` racine (ressource monolithique). Supprimés après
  confirmation utilisateur (l'utilisateur a interrompu la session en cours pour signaler que
  "les modules ne doivent pas du tout avoir de fxmanifest.lua" après m'avoir vu éditer ces
  fichiers par erreur — bon réflexe : j'avais traité ces manifests comme vivants sans vérifier
  s'ils étaient réellement chargés). Voir [[lslegacy-architecture-gotchas]].
- **Casse des dossiers** : `creatorPerso` → `creatorperso`, `pedOffline` → `pedoffline`,
  `persistent_vehicles` → `persistentvehicles`. Rename impossible en une seule étape `git mv`
  sous Windows (filesystem insensible à la casse) — passer par un nom temporaire intermédiaire
  (`git mv X X_tmp && git mv X_tmp x`). La table SQL `persistent_vehicles` (schéma, requêtes)
  volontairement **pas** renommée — namespace différent du nom de dossier, migrer un schéma SQL
  en prod n'apporte aucun bénéfice ici.
- **Callback `sit`** : migré de `lib.callback` (ox_lib) vers `LSLegacy.Callbacks`
  (`RegisterServer`/`AwaitServer`). Nuance : timeout fixe 15s côté maison contre timeout par
  appel côté ox_lib (`false`/`200ms`), sans conséquence en usage normal.
- **Events** (le plus gros morceau) : casse `LSLegacy:*` → `lslegacy:*` (skills/injury/status) ;
  events PascalCase sans préfixe → `module:action` (Core → `lslegacy:xxx`, `bank` 17 events dont
  un bug de casse latent corrigé `BankwithdrawMoney` → `bank:withdrawMoney`, `adminmenu` →
  préfixe `admin:` déjà établi ailleurs dans ce module **pas** `adminmenu:`, `clothshop`,
  `creatorperso`) ; events `module:sub:action` aplatis en `module:action` (segment intermédiaire
  fusionné en camelCase dans l'action — `admin:multichar:returnToSelection`, `keyhanger:*:*`,
  `lslegacy_carry|hostage|emotes:client:*`, `lslegacy:injury|skills|status|client:*`, `samu:hi:*`,
  `pedOffline:*:*`, callbacks `sit:server:*`). **Chaque event client-registered renommé doit être
  resynchronisé dans `Shared.Anticheat.WhitelistedEvents`** (`shared/shared.lua`) sous peine de
  faux positif anticheat — fait systématiquement à chaque commit d'event, et revérifié
  exhaustivement à la fin (voir [[lslegacy-architecture-gotchas]]). RateLimit tables
  (`RegisterRateLimit`) également resynchronisées à chaque fois.
  **Exclusions volontaires actées avec l'utilisateur** : `police:callouts:*`/`police:inv:*`/
  `police:radio:*` (~110 events, système ~7000 lignes où le segment intermédiaire structure un
  vrai sous-domaine, pas un excès accidentel — risque élevé pour bénéfice cosmétique faible) ;
  `lslegacy:phone:playerReady`/`updateBalance` (probable contrat avec une resource téléphone
  externe non présente dans ce repo, ex. `winframe-phone`). **Trouvaille de sécurité** :
  `chat:server:ServerPSA` dans `server/anticheat.lua` n'est **pas** un event à nous — signature
  de détection anti-triche (comme les autres entrées de `Shared.Anticheat.Events`), repéré grâce
  au filtre par fonction d'enregistrement (raw `RegisterNetEvent`, pas `LSLegacy.Events.*`) —
  ne jamais le renommer/toucher.
- **213 fonctions locales camelCase → PascalCase** : nombre qui correspondait exactement à
  l'audit LOT 16. Toutes des `local function`, donc portée fichier (pas de recherche
  cross-fichier nécessaire, contrairement aux events). Renommage mécanique par script
  (déclaration + tout appel direct `nom(`), avec vérification préalable par fonction que le
  nombre d'occurrences du mot nu correspond au nombre d'appels — les ~22 écarts inspectés un par
  un pour distinguer vraies références indirectes à renommer (`onReset = resetWalk` → `=
  ResetWalk`, `exports('x', name)` où seule la référence change pas le nom d'export public,
  `AddHandler('evt', name)`) des collisions purement textuelles à laisser (chaînes d'event, clés
  de table `{ result = res }`, texte de log). 10 commits, un par module/zone.
- **4 variables snake_case → camelCase** : `time_val`, `board_model`, `overlay_model`, l'alias
  local `ox_target` dans `keyhanger` (seul fichier du repo à aliaser `ox_target` en variable
  locale au lieu de l'appeler inline comme partout ailleurs).
- Pas d'interpréteur Lua disponible — vérification systématique par `git diff --stat` (équilibre
  strict insertions/suppressions à chaque commit mécanique) + relecture ciblée des cas
  particuliers avant chaque renommage, jamais de remplacement aveugle sans grep préalable.

`DEVELOPMENT.md` mis à jour en deux passes après LOT 16bis : d'abord les exemples de code
remplacés par l'API namespacée moderne (`LSLegacy.Events.*`/`LSLegacy.Callbacks.*`/
`LSLegacy.Players.*`/`LSLegacy.Security.RegisterRateLimit`) et section "Convention de nommage"
ajoutée ; puis, sur demande explicite de l'utilisateur de couvrir "TOUT ce qui a été fait depuis
le 3ème commit" (donc tout le refactor, pas juste LOT 16bis), ajout de sections entières
manquantes : Validation des entrées (`LSLegacy.Validate`, ordre de vérification Token→...→Action),
Argent et inventaire (`LSLegacy.Money`/`LSLegacy.Inventory`), Persistance partielle
(dirty-tracking, `MarkDirty`/`SaveDirty`), `LSLegacy.Security` complet (Log/Token), et une section
"Sécurité — limites connues" documentant explicitement la faille `SetJob`/`SetFaction` non
autorisée (LOT 10, jamais corrigée) pour que personne ne la redécouvre par accident.

## Candidats identifiés mais volontairement non traités (état à LOT 16bis)
- Sécurité `SetJob`/`SetFaction` sans vérification d'autorisation (depuis LOT 10) — toujours pas
  traité, seul le NOM des events a changé en LOT 16bis (`lslegacy:setJob`/`lslegacy:setFaction`),
  la faille elle-même est intacte. Documentée explicitement dans `DEVELOPMENT.md` depuis.
- Dirty-tracking `status`/`skills`/`health` (depuis LOT 12).
- Anticheat : séparation détection/décision/sanction, taille du fichier, faux positifs (LOT 13).
- `LSLegacy.Database` (35 fichiers MySQL direct) et `LSLegacy.Vehicles` (logique éclatée) — LOT
  14/15, nécessitent une vraie conception d'API.
- Système `Duty` générique + schéma SQL `xxx_agents` (6 modules dupliqués à 100%) — LOT 15, plus
  gros gisement de duplication trouvé, pas encore fait.
- Lint Lua : pas d'outil disponible (luacheck absent), prévu pour un lot dédié si besoin.
- `police:callouts:*`/`police:inv:*`/`police:radio:*` et `lslegacy:phone:*` : exclus
  volontairement de l'uniformisation des events en LOT 16bis (voir détail ci-dessus) — à
  reconsidérer seulement si un vrai besoin se présente, pas par principe de cohérence.

## Points à surveiller
- Pas d'outil de lint Lua disponible (luacheck absent).
- Le repo lslegacy (master) a eu un passage en public récent — voir [[lslegacy-public-release]] —
  prudence sur tout ce qui touche secrets/config avant de commit/push.
