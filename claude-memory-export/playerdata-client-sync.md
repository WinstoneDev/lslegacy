---
name: playerdata-client-sync
description: "LSLegacy.PlayerData côté client est un miroir en lecture de l'état serveur — seul le skin y est écrit par le client ; ReceiveUpdateServerPlayer merge via whitelist ClientWritableFields."
metadata: 
  node_type: memory
  type: project
  originSessionId: a4bbf07b-0490-4bc5-b97c-888aacc5d1b8
  modified: 2026-08-21T15:26:16.493Z
---

Dans `server-data/resources/lslegacy`, `LSLegacy.PlayerData` côté client (`client/player/player.lua`) n'est modifié localement que pour le champ `skin` (poll `skinchanger:getSkin` toutes les 10s). Tous les autres champs (`inventory`, `weight`, `job`, `cash`, `status`, `skills`, etc.) sont un simple miroir en lecture de ce que le serveur pousse — jamais écrits côté client.

**Why:** `server/player/player.lua` faisait autrefois `LSLegacy.ServerPlayers[source] = data` (remplacement complet) dans `ReceiveUpdateServerPlayer`, ce qui écrasait toute mutation serveur (argent, job, inventaire...) survenue entre deux pushs client — un vrai risque de désync/perte de données. Corrigé en 2026-08-21 par une whitelist `ClientWritableFields` (actuellement `{'skin'}`) que le handler merge champ par champ au lieu de remplacer tout l'objet.

Autre correction liée dans `module/creatorPerso` : l'event `saveskin` envoie désormais un ack `creatorPerso:skinSaved` que le client attend avant d'envoyer `SetIdentity`, pour éviter que `SetIdentity` relise un skin périmé en BDD (course entre deux handlers serveur asynchrones).

**How to apply:** si un futur module modifie un autre champ de `LSLegacy.PlayerData` côté client (au-delà du skin), il doit être ajouté à `ClientWritableFields` dans `server/player/player.lua` — ne jamais revenir à un remplacement complet de `LSLegacy.ServerPlayers[source]` sur réception de `ReceiveUpdateServerPlayer`. Voir aussi [[creatorperso-intro-cutscene]] pour le contexte du module creatorPerso.
