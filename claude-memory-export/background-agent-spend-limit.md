---
name: background-agent-spend-limit
description: "Launching many parallel background agents can hit the account's monthly spend limit mid-task, silently killing all of them at once — verify survivors before assuming a batch finished."
metadata:
  type: feedback
---

Le 2026-08-21, 5 agents en arrière-plan ont été lancés en parallèle (un survey + 4 nettoyages de
code sur le projet [[lslegacy-public-release]]), et l'un d'eux a lui-même spawné 4 sous-agents
supplémentaires. Peu après, tous les agents encore actifs ont échoué en même temps avec l'erreur
"You've hit your monthly spend limit".

**Pourquoi c'est important :** une rafale d'agents en parallèle (surtout avec des sous-agents
imbriqués) peut consommer le budget du compte beaucoup plus vite que prévu, et l'échec touche
tous les agents en vol simultanément, laissant potentiellement un travail par lots à moitié fait
(ex. certains fichiers d'un même module nettoyés, d'autres non, sans qu'aucune erreur locale ne
le signale avant coup).

**Comment appliquer :** après une vague d'agents parallèles sur une tâche de modification de
fichiers, toujours vérifier via `git status`/diff (ou équivalent) l'étendue réelle des
changements plutôt que de faire confiance au rapport de fin de tâche — un agent tué en plein
travail ne renvoie pas de rapport final fiable. Si l'utilisateur signale avoir atteint la limite,
arrêter d'en relancer d'autres et terminer le travail restant soi-même ou le documenter
clairement comme incomplet plutôt que de retenter la même rafale.
