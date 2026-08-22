--  MDT — Département SAPEURS-POMPIERS
--
--  Ce fichier déclare Config.MDT.Departments.pompiers :
--    • jobs        : les métiers LSLegacy rattachés à ce département
--    • tabs        : onglets MDT activés pour ce département
--    • services    : hiérarchie des services / unités (affichage)
--    • grades      : 5 grades, chacun débloque permissions / véhicules
--
--  IMPORTANT — Permissions CUMULATIVES :
--  Chaque grade ne liste dans `grants` que les permissions QU'IL AJOUTE.
--  shared/permissions.lua cumule tous les `grants` des grades de 0 jusqu'au
--  grade du joueur.

Config.MDT = Config.MDT or {}
Config.MDT.Departments = Config.MDT.Departments or {}

Config.MDT.Departments.pompiers = {
    label = 'Sapeurs-Pompiers',
    color = '#a93226', -- rouge pompier

    jobs = { 'pompiers' },

    tabs = { 'citizens', 'organisation' },

    services = {
        {
            id = 'secours_incendie',
            label = "Secours et Lutte contre l'Incendie",
            units = {
                { id = 'incendie', label = 'Lutte Incendie', description = 'Extinction et sécurisation des feux.' },
                { id = 'sauvetage', label = 'Sauvetage / Désincarcération', description = 'Extraction de victimes, accidents de la route.' },
            },
        },
    },

    -- GRADES (0 → 4)
    grades = {
        [0] = {
            label = 'Sapeur Stagiaire',
            grants = { 'view_citizens', 'extinguish_fire' },
            vehicles = { 'Camion de Pompiers' },
            units = { 'incendie' },
            responsibilities = "Extinction encadrée, manœuvres de base.",
        },
        [1] = {
            label = 'Sapeur',
            grants = { 'rescue_victim' },
            vehicles = { 'Camion de Pompiers' },
            units = { 'incendie' },
            responsibilities = "Extinction autonome, premières désincarcérations.",
        },
        [2] = {
            label = 'Caporal',
            grants = {},
            vehicles = { 'Camion de Pompiers', 'Véhicule de Sauvetage Côtier' },
            units = { 'incendie', 'sauvetage' },
            responsibilities = "Intervention autonome, sauvetage côtier.",
        },
        [3] = {
            label = 'Sergent',
            grants = { 'advanced_rescue' },
            vehicles = { 'Camion de Pompiers', 'Véhicule de Sauvetage Côtier' },
            units = { 'incendie', 'sauvetage' },
            responsibilities = "Désincarcérations complexes, encadrement d'équipe.",
        },
        [4] = {
            label = 'Capitaine — Chef de Centre',
            grants = { 'manage_service' },
            vehicles = { 'Camion de Pompiers', 'Véhicule de Sauvetage Côtier' },
            units = { 'incendie', 'sauvetage' },
            responsibilities = "Coordination du centre, gestion des effectifs.",
        },
    },
}
