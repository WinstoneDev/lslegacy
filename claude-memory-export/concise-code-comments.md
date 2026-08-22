---
name: concise-code-comments
description: "Always keep code comments concise — no verbose explanatory paragraphs or decorative banners, even outside cleanup tasks."
metadata:
  type: feedback
---

Quand j'écris des commentaires dans du code (n'importe quel langage, pas seulement Lua), ils
doivent être concis.

**Pourquoi :** après le nettoyage du framework [[lslegacy-public-release]] (bannières
décoratives, paragraphes explicatifs verbeux typiques d'un assistant IA), l'utilisateur a
explicitement demandé que ce style ne revienne jamais, y compris en dehors d'une tâche de
nettoyage dédiée.

**Comment l'appliquer :** par défaut, pas de commentaire du tout (le code doit se lire tout
seul). Quand un commentaire est justifié — contrainte non évidente, workaround, avertissement
d'ordre/effet de bord, signification d'une valeur de config, crédit/URL d'origine — une ligne
courte suffit. Jamais de bannières décoratives (`-- ===`, `-- ───`, etc.), jamais de paragraphes
multi-lignes qui reformulent ce que le code fait déjà, jamais de blocs "explicatifs" qui
ressemblent à de la documentation générée automatiquement.

Rappel donné une seconde fois pendant le refactor [[lslegacy-refactor-progress]] (lot 6) :
plusieurs commentaires ajoutés sur 3-4 lignes pour expliquer des fix de sécurité (guard
DataStore, event réseau) ont dû être condensés à une seule ligne. Règle stricte : même pour
justifier un correctif de sécurité non trivial, une seule ligne — ne jamais développer le
raisonnement dans le commentaire (ça va dans le message de commit ou la mémoire projet, pas dans
le code).
