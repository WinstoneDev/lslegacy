---
name: playerdata-client-sync
description: "LSLegacy.PlayerData côté client est un miroir en lecture de l'état serveur — seul le skin y est écrit par le client ; ReceiveUpdateServerPlayer merge via whitelist ClientWritableFields."
metadata:
  type: project
---

Dans `server-data/resources/lslegacy`, `LSLegacy.PlayerData` côté client
(`client/player/player.lua`) n'est modifié localement que pour le champ `skin` (poll
`skinchanger:getSkin` toutes les 10s). Tous les autres champs (`inventory`, `weight`, `job`,
`cash`, `status`, `skills`, etc.) sont un simple miroir en lecture de ce que le serveur pousse —
jamais écrits côté client.

**Why:** `server/player/player.lua` faisait autrefois `LSLegacy.ServerPlayers[source] = data`
(remplacement complet) dans `ReceiveUpdateServerPlayer`, ce qui écrasait toute mutation serveur
(argent, job, inventaire...) survenue entre deux pushs client — un vrai risque de
désync/perte de données. Corrigé en 2026-08-21 par une whitelist `ClientWritableFields`
(actuellement `{'skin'}`) que le handler merge champ par champ au lieu de remplacer tout l'objet.

Autre correction liée dans `module/creatorperso` : l'event `saveskin` envoie désormais un ack
`creatorperso:skinSaved` que le client attend avant d'envoyer `creatorperso:setIdentity`, pour
éviter que ce dernier relise un skin périmé en BDD (course entre deux handlers serveur
asynchrones).

**How to apply:** si un futur module modifie un autre champ de `LSLegacy.PlayerData` côté client
(au-delà du skin), il doit être ajouté à `ClientWritableFields` dans `server/player/player.lua`
— ne jamais revenir à un remplacement complet de `LSLegacy.ServerPlayers[source]` sur réception
de `lslegacy:receiveUpdateServerPlayer`. Voir aussi [[creatorperso-intro-cutscene]] pour le
contexte du module creatorperso.
