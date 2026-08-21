Config.Wildlife = {}

-- Modèles de peds animaux à supprimer dès qu'ils apparaissent (pas de native pour empêcher leur spawn à la source, détection + suppression après coup).
-- ATTENTION : ne jamais lister ici une espèce présente dans Config.Farm.Activities.chasseur.species, elle serait supprimée avant d'être chassable (cas vécu avec le cougar a_c_mtlion).
-- Liste vide = le scan ne tourne pas du tout.
Config.Wildlife.SuppressedModels = {}

Config.Wildlife.ScanInterval = 2000 -- ms
