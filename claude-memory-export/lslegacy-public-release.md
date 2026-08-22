---
name: lslegacy-public-release
description: "LS Legacy (server-data/resources/lslegacy) was made public on GitHub by Winstone; security fixes, license, README, and git history reset done 2026-08-21 — comment cleanup left partial."
metadata: 
  node_type: memory
  type: project
  originSessionId: 79a9fcff-2023-4829-b243-607f87cc9a62
  modified: 2026-08-21T16:52:32.116Z
---

Le framework LS Legacy (`/opt/gamepanel/servers/8/base/server-data/resources/lslegacy`, repo GitHub `WinstoneDev/lslegacy`) a été rendu public par Winstone (Bastien MAGAN) le 2026-08-21, dans une optique de projet communautaire.

**Ce qui a été fait ce jour-là :**
- 5 webhooks Discord + 1 clé API imgbb trouvés codés en dur dans le code (déjà exposés publiquement au moment de la découverte) → remplacés par `GetConvar('lslegacy_webhook_*', '')` / `lslegacy_imgbb_key` / `lslegacy_anticheat_password`, à définir dans `server.cfg` (non versionné). Fichiers concernés : `shared/sv_config.lua`, `module/adminmenu/sv_admin.lua`, `module/mdt/config.lua`, `server/boutique.lua`, `server/anticheat.lua`.
- L'utilisateur a supprimé le repo GitHub existant avant que la rotation des webhooks soit confirmée — **il faut vérifier que Winstone a bien régénéré ces webhooks/clé côté Discord/imgbb**, sinon ils restent valides même si retirés du code public.
- `.claude/` et `.DS_Store` supprimés du repo, `.gitignore` créé (couvre aussi `module/police/sceneanchors.json` et `module/police/spawnfails.json`, des caches runtime générés par le système de callouts police, pas des fichiers source).
- Historique git entièrement réinitialisé (un seul commit propre) plutôt que réécrit, car le repo distant venait d'être supprimé — l'ancien `.git` (142 commits, avec les secrets en clair dans l'historique) a été sauvegardé à côté : `server-data/resources/lslegacy_git_backup_20260821_162320/`.
- `LICENSE.md` créé : CC BY-NC 4.0 adaptée code, attribution obligatoire à Winstone, usage commercial interdit sans accord.
- `README.md` complet créé (installation, convars requis, tableau des modules, dépendances externes, crédits tiers).

**Nettoyage des commentaires "façon IA" — TERMINÉ (2026-08-21, session suivante).**
Objectif : réduire la verbosité des commentaires Lua (bannières décoratives, paragraphes explicatifs) pour que le code ne trahisse pas une écriture assistée par IA, tout en gardant les crédits/URLs, les avertissements non-évidents et les annotations LuaCATS (`---@param` etc.). Repris là où la première session s'était arrêtée (voir [[background-agent-spend-limit]]) : tous les modules restants (`atelier`, `emotes`, `farm`, `garage`, `identity`, `interim`, `keyhanger`, `ltd`, `needs`, `persistent_vehicles`, `pompe`, `sit`, `weather`, `wildlife`) ainsi que le socle `client/`, `server/`, `inventory/` ont été passés en revue et nettoyés via agents en arrière-plan (cette fois sans sous-agents imbriqués, un agent = un lot de fichiers, tous ont réussi). Vérifications post-nettoyage effectuées : recherche de fragments de commentaires tronqués (aucun trouvé), `luac -p` sur tous les fichiers modifiés (propre, hormis les littéraux backtick/`+=` CitizenFX pré-existants, non liés au nettoyage). Un commit git a suivi le premier (`8c74a28`).

**Mise à jour du SQL faite en parallèle :** `winframe_database.sql` ne contient que le socle et pointe vers des fichiers par module (pattern déjà existant). Ajout de `module/atelier/sql/atelier.sql` et `module/emotes/sql/emotes.sql` (n'existaient pas), complété `module/mdt/sql/mdt.sql` avec 7 tables manquantes + corrigé une colonne (`character_id`) qui avait dérivé sur `mdt_training_signups`. Pas d'audit colonne par colonne exhaustif des tables déjà documentées ailleurs (`bank_*`, `police_*`, etc.) — seulement les écarts détectés (tables absentes du code vs SQL).

**`DEVELOPMENT.md` créé** à la racine : architecture du framework, API `LSLegacy.*` (events sécurisés par jetons, callbacks client/serveur, DataStore générique, résolution joueur/personnage), comment ajouter un nouveau module.
