---
name: samu-diagnostic-samudebug
description: "La commande /samudebug (job SAMU, resource lslegacy) est un outil permanent voulu par l'utilisateur, à ne pas retirer"
metadata:
  type: project
---

`/samudebug` (dans `module/samu/client/actions.lua`) imprime l'état de service de l'agent SAMU
et l'état réel du patient visé (santé, statebag `injury`, `IsEntityDead`, `IsPedRagdoll`,
`IsPedAPlayer`).

Créée le 2026-08-21 comme diagnostic temporaire, **l'utilisateur a demandé de la conserver**
après la campagne de correctifs (« laisse le »). Ne pas la retirer au titre du nettoyage.

**Why:** elle a été proposée puis effectivement supprimée une fois les tests passés ;
l'utilisateur a dû demander sa restauration. Sans cette note, le même nettoyage se reproduirait.

**How to apply:** la maintenir en état si `canInteract` ou l'état KO/coma évoluent (elle lit
`Config.SAMU.Actions.downedHealthThreshold` et le statebag `injury` publié par
`client/player/injury.lua`).

Contexte utile : ox_target masque une option aussi bien quand `canInteract` renvoie false que
quand elle **lève une erreur** — aucun retour visuel dans les deux cas, d'où l'intérêt de cette
commande.
