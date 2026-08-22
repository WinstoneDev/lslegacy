---
name: nui-pointer-events-camera-controls
description: Molette/clic-glisser caméra dans une UI NUI transparente ne marche pas si le conteneur racine est en pointer-events:none
metadata:
  type: project
---

Dans les UIs NUI transparentes (creatorperso, clothshop), le conteneur racine doit être en
`pointer-events: auto` (pas `none`) pour que la molette et le clic-glisser (contrôle caméra
style "caméra de sécurité") atteignent le JS, même au-dessus des zones transparentes qui
laissent voir le personnage.

**Why:** `creatorperso` (creator-container) utilisait déjà `pointer-events: auto` avec ce
commentaire explicite. `clothshop` avait `.shop { pointer-events: none }` à la racine — les
événements clavier (flèches) passaient (non affectés par pointer-events), mais molette/mousedown
souris étaient bloqués avant d'atteindre les handlers jQuery, même si les panneaux enfants
(header, sidebar, cart) étaient en `pointer-events: all`. Le focus NUI (`SetNuiFocus(true,true)`)
capture de toute façon tout l'input tant que le panneau est ouvert, donc passer la racine en
`auto` est sans risque de casser le clic-à-travers vers le jeu.

**How to apply:** Si un futur ajout de contrôle caméra (molette/drag) sur une UI NUI transparente
de ce projet ne réagit pas à la souris alors que les clics sur boutons/clavier fonctionnent,
vérifier en premier le `pointer-events` du conteneur racine de cette UI (souvent `none` par
défaut pour laisser voir le jeu derrière). Voir aussi [[creatorperso-intro-cutscene]] pour
d'autres subtilités NUI de creatorperso.
