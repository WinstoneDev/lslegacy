--  MDT — Département POLICE (premier métier implémenté)
--  Inspiré de l'organisation de la Police Nationale française.
--
--  Ce fichier déclare Config.MDT.Departments.police :
--    • jobs        : les métiers LSLegacy rattachés à ce département
--    • tabs        : onglets MDT activés pour ce département
--    • services    : hiérarchie des services / unités (affichage + extension)
--    • grades      : 9 grades, chacun débloque permissions / véhicules / unités
--
--  IMPORTANT — Permissions CUMULATIVES :
--  Chaque grade ne liste dans `grants` que les permissions QU'IL AJOUTE.
--  shared/permissions.lua cumule tous les `grants` des grades de 0 jusqu'au
--  grade du joueur. Un Commissaire possède donc tout ce qui précède.

Config.MDT = Config.MDT or {}
Config.MDT.Departments = Config.MDT.Departments or {}

Config.MDT.Departments.police = {
    label = 'Police Nationale',
    -- Estampille d'origine portée par chaque pièce du dossier commun aux
    -- forces de l'ordre (voir Config.MDT.DataGroups).
    short = 'Police',
    color = '#1b3a6b', -- bleu nuit Police Nationale

    -- Métiers LSLegacy (LSLegacy.AvailableJobs) rattachés à ce département
    jobs = { 'police' },

    -- Onglets activés pour ce département (ids depuis Config.MDT.Tabs)
    tabs = { 'dashboard', 'citizens', 'vehicles', 'weapons', 'int_reports', 'dossiers', 'warrants', 'custody', 'investigation', 'laws', 'interventions', 'effectifs', 'trainings', 'organisation' },

    -- SERVICES DE POLICE (4 pôles)
    -- Données structurées : affichage dans l'onglet Organisation + base
    -- pour de futurs systèmes (affectation d'unité, garages dédiés…).
    services = {
        {
            id = 'securite_quotidienne',
            label = 'Sécurité Quotidienne',
            units = {
                { id = 'police_secours', label = 'Police Secours',  description = 'Service de base, premières interventions.' },
                { id = 'bac',            label = 'BAC',             description = 'Brigade anti-criminalité — banalisé, discrétion, interventions.' },
                { id = 'bac_97n',        label = 'BAC 97N',         description = 'Interventions à risque.' },
            },
        },
        {
            id = 'appui_operationnel',
            label = "Unités d'Appui Opérationnel",
            units = {
                { id = 'moto',        label = 'Brigade Motocycliste', description = 'Escorte, circulation, interventions rapides.' },
                { id = 'csi',         label = 'CSI',                  description = 'Compagnie de sécurisation et d\'intervention.' },
                { id = 'bravm',       label = 'BRAV-M',               description = 'Brigade de répression de l\'action violente motorisée — maintien de l\'ordre.' },
                { id = 'crs',         label = 'CRS',                  description = 'Compagnies républicaines de sécurité — manifestations.' },
                { id = 'k9',          label = 'K9',                   description = 'Brigade cynophile (chien policier).' },
                { id = 'aero',        label = 'Aéronautique',         description = 'Hélicoptère / drone.' },
                { id = 'equestre',    label = 'Équestre',             description = 'Brigade montée.' },
                { id = 'fluviale',    label = 'Fluviale',             description = 'Brigade fluviale.' },
                { id = 'sdlp',        label = 'SDLP',                 description = 'Service de la protection — protection des personnalités.' },
            },
        },
        {
            id = 'specialisees',
            label = 'Unités Spécialisées',
            units = {
                { id = 'raid', label = 'RAID', description = 'Interventions extrêmes.' },
                { id = 'bri',  label = 'BRI',  description = 'Brigade de recherche et d\'intervention — arrestations haut risque.' },
            },
        },
        {
            id = 'judiciaire',
            label = 'Pôle Judiciaire',
            units = {
                { id = 'renseignement', label = 'Renseignement',                 description = 'Collecte et analyse du renseignement.' },
                { id = 'stups',         label = 'Stupéfiants',                   description = 'Lutte contre les trafics de stupéfiants.' },
                { id = 'pts',           label = 'Police Technique et Scientifique', description = 'PTS — relevés et analyse des preuves.' },
            },
        },
    },

    -- GRADES (0 → 8)
    -- `grants` = permissions AJOUTÉES par ce grade (cumulatives).
    -- `vehicles` / `units` = accès débloqués (informatif / futurs systèmes).
    -- `responsibilities` = description du rôle.
    grades = {
        [0] = {
            label = 'Policier Adjoint',
            grants = { 'view_citizens', 'view_vehicles', 'view_reports', 'view_warrants', 'view_weapons', 'view_laws', 'view_trainings', 'view_callouts' },
            vehicles = { 'Véhicules de patrouille de base' },
            units = { 'police_secours' },
            responsibilities = "Patrouille encadrée, assistance, rédaction de mains courantes.",
        },
        [1] = {
            label = 'Gardien de la Paix Stagiaire',
            grants = { 'create_fine', 'create_report' },
            vehicles = { 'Véhicules de patrouille' },
            units = { 'police_secours' },
            responsibilities = "Patrouille, verbalisation, premières interventions.",
        },
        [2] = {
            label = 'Gardien de la Paix',
            grants = { 'manage_records', 'manage_custody', 'manage_weapons' },
            vehicles = { 'Véhicules de patrouille', 'Véhicules banalisés' },
            units = { 'police_secours', 'bac', 'moto', 'k9' },
            responsibilities = "Interventions autonomes, gestion des gardes à vue, casier.",
        },
        [3] = {
            label = 'Brigadier Chef',
            grants = { 'manage_warrants' },
            vehicles = { 'Véhicules de patrouille', 'Véhicules banalisés', 'Véhicules rapides' },
            units = { 'bac', 'bac_97n', 'csi', 'moto', 'k9', 'equestre', 'fluviale' },
            responsibilities = "Chef d'équipe, supervision de patrouille, avis de recherche.",
        },
        [4] = {
            label = 'Major',
            grants = {}, -- l'accès Enquête (view_evidence) est désormais débloqué par la compétence CS037
            vehicles = { 'Véhicules banalisés', 'Véhicules rapides' },
            units = { 'bac_97n', 'csi', 'bravm', 'crs', 'aero' },
            responsibilities = "Encadrement, coordination d'unités d'appui, accès enquêtes.",
        },
        [5] = {
            label = 'Lieutenant',
            grants = { 'manage_laws' }, -- manage_evidence débloqué par la compétence CS037
            vehicles = { 'Véhicules banalisés', 'Véhicules rapides', 'Véhicules spécialisés' },
            units = { 'csi', 'bravm', 'crs', 'aero', 'sdlp', 'renseignement', 'stups', 'pts' },
            responsibilities = "Officier — direction d'opérations, gestion des preuves.",
        },
        [6] = {
            label = 'Capitaine',
            grants = { 'delete_records' },
            vehicles = { 'Tous véhicules opérationnels' },
            units = { 'bri', 'renseignement', 'stups', 'pts', 'sdlp' },
            responsibilities = "Commandement d'unité, supervision judiciaire.",
        },
        [7] = {
            label = 'Commandant',
            grants = { 'manage_personnel', 'manage_trainings', 'delete_custody' },
            vehicles = { 'Tous véhicules opérationnels' },
            units = { 'raid', 'bri' },
            responsibilities = "Commandement supérieur, gestion du personnel.",
        },
        [8] = {
            label = 'Commissaire',
            grants = { 'admin_mdt' },
            vehicles = { 'Tous véhicules' },
            units = { 'raid', 'bri' },
            responsibilities = "Direction du service, administration complète du MDT.",
        },
    },
}
