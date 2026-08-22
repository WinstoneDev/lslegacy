# Prompt à coller à Claude sur l'autre machine

Copie-colle tout ce qui suit dans une nouvelle conversation Claude Code, dans le dossier
`lslegacy-dev` (après avoir fait `git pull` pour récupérer ce fichier, `REFACTOR_HANDOFF.md`
et le dossier `claude-memory-export/`).

---

Tu reprends un refactor en cours du framework FiveM/Lua LSLegacy, commencé sur une autre
machine avec un autre compte Claude (pas de mémoire partagée entre les deux comptes — c'est
pour ça que tout est transféré par fichiers dans ce repo).

Avant toute chose :

1. Lis entièrement `REFACTOR_HANDOFF.md` à la racine du repo — il contient tout l'historique
   détaillé des lots déjà faits (LOT 0 à LOT 15bis), la règle absolue de migration exhaustive
   (violée 3 fois avant d'être bien comprise, ne la reproduis pas), l'audit complet des
   duplications entre modules (LOT 15) et l'audit de convention de nommage (LOT 16, pas encore
   appliqué).

2. Lis chaque fichier du dossier `claude-memory-export/` — ce sont mes mémoires persistantes
   exportées telles quelles (format frontmatter + contenu). Certaines ne concernent pas le
   refactor mais le projet LSLegacy en général (bugs UI, comportements voulus par l'utilisateur
   à ne pas "corriger" par erreur) :
   - `lslegacy-refactor-progress.md` — le détail complet lot par lot (source de
     `REFACTOR_HANDOFF.md`, à lire si tu veux le niveau de détail maximal sur un lot précis).
   - `lslegacy-lot-full-migration.md` — la règle de migration exhaustive.
   - `lslegacy-public-release.md` — contexte sur le passage en public du repo, secrets rotés,
     licence, nettoyage des commentaires déjà fait.
   - `concise-code-comments.md` — convention de commentaires (une ligne max, jamais de
     bannières décoratives), s'applique à tout le code que tu écriras.
   - `background-agent-spend-limit.md` — un lancement massif d'agents en parallèle peut tous
     les faire échouer d'un coup en silence ; vérifier `git status` plutôt que de faire
     confiance à un rapport de fin de tâche après une vague d'agents.
   - `creatorperso-intro-cutscene.md`, `nui-pointer-events-camera-controls.md`,
     `playerdata-client-sync.md`, `samu-diagnostic-samudebug.md` — comportements/bugs
     spécifiques à certains modules, volontaires ou déjà corrigés, à ne pas retoucher par
     erreur si tu tombes dessus pendant le refactor.

   **Recrée ces mémoires dans ton propre système de mémoire persistante** (le dossier memory
   de ce compte Claude) avec le même contenu, pour ne pas avoir à relire ces fichiers à chaque
   session future — utilise le format déjà présent (frontmatter `name`/`description`/`metadata`)
   et mets à jour ton `MEMORY.md` en conséquence.

3. Une fois le contexte chargé, la prochaine étape à faire est le **LOT 16bis** : appliquer
   les corrections de convention de nommage listées dans la section "LOT 16" de
   `REFACTOR_HANDOFF.md` (fichiers plats `cl_`/`sv_` à réorganiser en `client/`/`server/` pour
   8 modules, casse de 3 noms de dossiers, ~213 fonctions camelCase → PascalCase, events à
   uniformiser en `module:action` minuscule, migration du module `sit` de `lib.callback` vers
   `LSLegacy.Callbacks`, fichiers de config redondants à renommer). **Avant chaque
   renommage/déplacement, rechercher exhaustivement toutes les références** (grep sur tout le
   repo — module/, server/, client/, inventory/, et le manifest `fxmanifest.lua` qui liste
   explicitement chaque chemin de fichier chargé). Un seul commit par correctif logique, message
   naturel sans mention de "lot", push sur `github dev` à la fin. Arrête-toi après ce lot et
   attends la suite de l'utilisateur.

4. Travaille exclusivement dans `lslegacy-dev` (branche `dev`) — jamais dans `lslegacy`
   (branche `master`, qui est encore la branche utilisée par le serveur en prod jusqu'à sa
   sortie). Voir `REFACTOR_HANDOFF.md` pour le détail complet de cette séparation et le plan de
   fusion prévu après la sortie du serveur.

Si un point du handoff est ambigu ou si le repo a visiblement évolué depuis (fichiers déplacés,
lot déjà fait autrement), vérifie l'état réel du code plutôt que de faire confiance aveuglément
au document — il décrit l'état à un instant T, pas une garantie absolue.
