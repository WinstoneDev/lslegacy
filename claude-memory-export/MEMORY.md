# Memory Index

- [Refactor LSLegacy par lots (détail)](lslegacy-refactor-progress.md) — historique lot par lot LOT 0-16bis ; dernier lot fait = LOT 16bis (convention de nommage), commit 201427b.
- [Migration exhaustive par lot](lslegacy-lot-full-migration.md) — chaque lot Core doit migrer TOUS les appelants existants (y compris whitelist anticheat/rate-limit), jamais un échantillon.
- [Pièges d'architecture LSLegacy](lslegacy-architecture-gotchas.md) — seul le fxmanifest.lua racine est vivant ; Shared.Anticheat.WhitelistedEvents doit rester synchronisée avec les events client.
- [LS Legacy passé public](lslegacy-public-release.md) — secrets rotés en convars, licence CC BY-NC, historique git réinitialisé, nettoyage commentaires terminé.
- [Commentaires de code concis](concise-code-comments.md) — toujours courts, jamais de bannières décoratives, s'applique à tout code écrit.
- [Limite de dépenses agents parallèles](background-agent-spend-limit.md) — une rafale d'agents en arrière-plan peut tous échouer d'un coup, vérifier git status plutôt que le rapport de fin.
- [Cutscene intro creatorperso](creatorperso-intro-cutscene.md) — les 7 PNJ passagers crashent le jeu (build b3407), SKIP_PASSENGERS volontairement désactivé.
- [Sync PlayerData client/serveur](playerdata-client-sync.md) — seul skin est écrit côté client ; lslegacy:receiveUpdateServerPlayer merge via whitelist, ne jamais remplacer entièrement.
- [Pointer-events caméra NUI](nui-pointer-events-camera-controls.md) — molette/drag caméra bloqués si le conteneur racine NUI est en pointer-events:none.
- [/samudebug est permanent](samu-diagnostic-samudebug.md) — commande de diagnostic du job SAMU à conserver, pas à nettoyer.
