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
    tabs = { 'dashboard', 'citizens', 'vehicles', 'weapons', 'int_reports', 'dossiers', 'warrants', 'custody', 'investigation', 'laws', 'interventions', 'effectifs', 'trainings', 'organisation', 'garage', 'entreprise', 'boutique_tenue' },

    -- La police garde son vocabulaire historique pour l'onglet générique
    -- boutique_tenue (Config.MDT.Tabs) : affiché "UNIPOL" plutôt que
    -- "Boutique tenues" pour ce département uniquement.
    tabLabels = { boutique_tenue = 'UNIPOL' },

    -- BOUTIQUE TENUES — commande de tenues livrées au casier ci-dessous,
    -- débitées sur le compte entreprise police. Catalogue provisoire (mêmes
    -- emplacements que ClothShop, sans aperçu) en attendant un vrai jeu de
    -- tenues police (cf. discussion du 2026-09-09).
    boutique = {
        DeliveryCoords  = vector3(-401.459351, -376.509888, 25.084229),
        DeliveryHeading = 85.039367675781,
        DeliveryProp    = 'xm3_prop_xm3_product_box_01',
        -- Scène cosmétique jouée pour tous les joueurs à proximité quand une
        -- commande passe en statut "prête" (boxville4 qui vient déposer le
        -- colis) — sans lien avec la remise en inventaire (toujours faite à
        -- l'interaction ox_target ci-dessus).
        DeliveryVanCoords  = vector3(-346.140656, -346.918671, 30.189697),
        DeliveryVanHeading = 235.27558898926,
        -- Point d'arrivée du livreur à pied (distinct de DeliveryCoords
        -- ci-dessus, qui reste la zone de retrait ox_target) : arrêt juste
        -- avant le mur pour éviter qu'il ne s'y encastre en marchant.
        DeliveryPedCoords  = vector3(-376.338470, -351.283508, 31.638794),
        DeliveryPedHeading = 79.370079040527,
        -- Passage obligé (porte d'entrée du commissariat) entre le van et le
        -- point de dépose : évite que le PNJ ne traverse les murs en ligne
        -- droite. Emprunté à l'aller comme au retour.
        DeliveryDoorCoords  = vector3(-365.432953, -355.529663, 31.571411),
        DeliveryDoorHeading = 76.535438537598,
        ItemPrice      = 30,
        DeliveryDelay  = 3 * 60, -- secondes avant que le colis soit disponible
        -- Temps estimé pour que le livreur arrive physiquement à la boîte aux
        -- lettres (trajet camion + marche) : la scène se déclenche cette durée
        -- AVANT la fin de DeliveryDelay, pour que le PNJ ait fini sa livraison
        -- exactement quand le colis devient disponible au retrait.
        SceneArrivalDelay = 25, -- secondes
        MaxPendingPerAgent = 3, -- commandes non retirées (en_attente/pret) max par agent
        MaxItemsPerOrder = 15, -- articles max dans le panier d'une même commande
    },

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
            grants = { 'manage_laws', 'recruit_personnel' }, -- manage_evidence débloqué par la compétence CS037
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
