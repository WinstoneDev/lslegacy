-- ═══════════════════════════════════════════════════════════════════
--  MODULE WILDLIFE — Suppression d'espèces animales du spawn ambiant
-- ═══════════════════════════════════════════════════════════════════

Config.Wildlife = {}

-- Modèles de peds animaux à supprimer dès qu'ils apparaissent (population
-- ambiante du jeu — pas de native pour empêcher leur spawn à la source,
-- on les détecte et supprime après coup).
--
-- ATTENTION : ne jamais lister ici une espèce présente dans
-- `Config.Farm.Activities.chasseur.species` — elle serait supprimée avant
-- même d'être chassable. C'est ce qui faisait « disparaître » le cougar
-- (`a_c_mtlion`) dès qu'on le regardait, alors qu'il est braconnable.
--
-- Liste vide = le scan ne tourne pas du tout (voir client/main.lua).
Config.Wildlife.SuppressedModels = {}

Config.Wildlife.ScanInterval = 2000 -- ms
