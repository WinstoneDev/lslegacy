--  MDT — Département GENDARMERIE NATIONALE
--
--  Ce fichier déclare Config.MDT.Departments.gendarmerie :
--    • jobs        : les métiers LSLegacy rattachés à ce département
--    • tabs        : onglets MDT activés pour ce département
--    • services    : organisation en subdivisions / unités
--    • grades      : 9 grades, chacun débloque permissions / véhicules
--
--  IMPORTANT — Permissions CUMULATIVES :
--  Chaque grade ne liste dans `grants` que les permissions QU'IL AJOUTE.
--  shared/permissions.lua cumule tous les `grants` des grades de 0 jusqu'au
--  grade du joueur. Un Commandant possède donc tout ce qui précède.
--
--  BASE JUDICIAIRE COMMUNE — La gendarmerie partage avec la police le
--  casier, les amendes, les avis de recherche, les gardes à vue, les
--  dossiers, le registre des armes, le code juridique et l'historique des
--  interventions (Config.MDT.DataGroups). Chaque pièce reste estampillée
--  au pôle qui l'a rédigée grâce au champ `short` ci-dessous.

Config.MDT = Config.MDT or {}
Config.MDT.Departments = Config.MDT.Departments or {}

Config.MDT.Departments.gendarmerie = {
    label = 'Gendarmerie Nationale',
    short = 'Gendarmerie',
    color = '#0e3b2e', -- vert gendarmerie

    jobs = { 'gendarmerie' },

    -- Mêmes onglets que la police : les deux pôles font le même métier sur
    -- la même base. L'ordre d'affichage vient du registre Config.MDT.Tabs.
    tabs = { 'dashboard', 'citizens', 'vehicles', 'weapons', 'int_reports', 'dossiers', 'warrants', 'custody', 'investigation', 'laws', 'interventions', 'effectifs', 'trainings', 'organisation' },

    -- SUBDIVISIONS (4 pôles)
    services = {
        {
            id = 'departementale',
            label = 'Gendarmerie Départementale',
            units = {
                { id = 'brigade_territoriale', label = 'Brigade Territoriale', description = "Unité de base — accueil du public, premières interventions." },
                { id = 'cob',                  label = 'Communauté de Brigades', description = 'Mutualisation de plusieurs brigades sur un secteur.' },
                { id = 'psig',                 label = 'PSIG',                 description = "Peloton de surveillance et d'intervention — nuit, flagrants délits." },
                { id = 'psig_sabre',           label = 'PSIG Sabre',           description = 'Primo-intervention sur tuerie de masse.' },
            },
        },
        {
            id = 'appui',
            label = "Unités d'Appui",
            units = {
                { id = 'edsr',       label = 'EDSR',              description = 'Escadron départemental de sécurité routière.' },
                { id = 'bmo',        label = 'Brigade Motorisée', description = 'Surveillance des axes, escortes, interceptions.' },
                { id = 'brigade_rapide', label = 'BRI Motocycliste', description = 'Interventions rapides en deux-roues.' },
                { id = 'cynophile',  label = 'Brigade Cynophile', description = 'Équipes cynotechniques (pistage, stupéfiants, explosifs).' },
                { id = 'nautique',   label = 'Brigade Nautique',  description = 'Surveillance du littoral et des plans d\'eau.' },
                { id = 'fag',        label = 'Forces Aériennes',  description = 'Hélicoptère de la gendarmerie, observation et secours.' },
                { id = 'pghm',       label = 'PGHM',              description = 'Peloton de gendarmerie de haute montagne — secours en terrain difficile.' },
                { id = 'garde_rep',  label = 'Garde Républicaine', description = 'Honneurs, escortes officielles, brigade montée.' },
            },
        },
        {
            id = 'intervention',
            label = "Unités d'Intervention",
            units = {
                { id = 'gign',  label = 'GIGN',  description = 'Groupe d\'intervention — forcené, prise d\'otages, terrorisme.' },
                { id = 'agign', label = 'AGIGN', description = 'Antenne GIGN — intervention spécialisée en région.' },
            },
        },
        {
            id = 'judiciaire',
            label = 'Pôle Judiciaire',
            units = {
                { id = 'brigade_recherches', label = 'Brigade de Recherches', description = 'Enquêtes judiciaires de proximité.' },
                { id = 'section_recherches', label = 'Section de Recherches', description = 'Affaires complexes et criminalité organisée.' },
                { id = 'ircgn',              label = 'IRCGN',                description = 'Institut de recherche criminelle — police technique et scientifique.' },
                { id = 'renseignement_gn',   label = 'Renseignement',        description = 'Recueil et exploitation du renseignement territorial.' },
            },
        },
    },

    -- CODES DE FORMATION PROPRES À LA GENDARMERIE
    -- Sans cette liste, le cœur MDT retomberait sur Config.MDT.TrainingCodes,
    -- qui décrit le cursus police. Les deux codes marqués ci-dessous
    -- débloquent des permissions (voir Config.MDT.SkillUnlocks).
    trainingCodes = {
        { code = 'GA001', name = 'Formation initiale du gendarme' },
        { code = 'GA004', name = 'Habilitation bâton télescopique' },
        { code = 'GA007', name = 'Habilitation aérosol lacrymogène' },
        { code = 'GA012', name = 'Intervention professionnelle' },
        { code = 'GB003', name = 'Tireur qualifié — arme de poing' },
        { code = 'GB006', name = 'Habilitation HK G36' },
        { code = 'GB009', name = 'Habilitation fusil à pompe' },
        { code = 'GB014', name = 'Tireur de précision' },
        { code = 'GB021', name = 'Habilitation LBD' },
        { code = 'GB030', name = 'Tir en situation dégradée' },
        { code = 'GC002', name = 'Recyclage tir annuel' },
        { code = 'GC005', name = 'Recyclage bâton' },
        { code = 'GC008', name = 'Recyclage LBD' },
        { code = 'GD003', name = 'Conduite tout-terrain' },
        { code = 'GD007', name = "Conduite en situation d'urgence" },
        { code = 'GD011', name = 'Motocycliste — EDSR' },
        { code = 'GE002', name = 'Contrôle routier et dépistage' },
        { code = 'GE006', name = 'Constatation d\'accident corporel' },
        { code = 'GF004', name = 'Secourisme au combat' },
        { code = 'GG001', name = 'Officier de police judiciaire' },
        { code = 'GG005', name = 'Audition et procédure' },
        { code = 'GG012', name = 'Lutte contre les stupéfiants' },
        { code = 'GT037', name = 'Technicien en identification criminelle' }, -- → Enquête
        { code = 'GZ001', name = 'Formation de formateur' },                  -- → création de formation
        { code = 'GH010', name = 'Maintien de l\'ordre' },
        { code = 'GH015', name = 'Escortes sensibles' },
        { code = 'GH021', name = 'Risque NRBC' },
        { code = 'GK004', name = 'Intervention en milieu montagneux' },
        { code = 'GK009', name = 'Plongeur de la gendarmerie' },
        { code = 'GK014', name = 'Équipier cynophile' },
    },

    -- GRADES (0 → 8)
    -- Progression alignée sur celle de la police : à grade équivalent, un
    -- gendarme et un policier disposent des mêmes droits sur la base
    -- commune. C'est ce qui rend le partage lisible côté procédure.
    grades = {
        [0] = {
            label = 'Gendarme Adjoint Volontaire',
            grants = { 'view_citizens', 'view_vehicles', 'view_reports', 'view_warrants', 'view_weapons', 'view_laws', 'view_trainings', 'view_callouts' },
            vehicles = { 'Véhicules de patrouille de base' },
            units = { 'brigade_territoriale' },
            responsibilities = "Patrouille encadrée, assistance, accueil du public.",
        },
        [1] = {
            label = 'Élève Gendarme',
            grants = { 'create_fine', 'create_report' },
            vehicles = { 'Véhicules de patrouille' },
            units = { 'brigade_territoriale' },
            responsibilities = "Patrouille, verbalisation, premières constatations.",
        },
        [2] = {
            label = 'Gendarme',
            grants = { 'manage_records', 'manage_custody', 'manage_weapons' },
            vehicles = { 'Véhicules de patrouille', 'Véhicules banalisés' },
            units = { 'brigade_territoriale', 'cob', 'psig', 'bmo', 'cynophile' },
            responsibilities = "Interventions autonomes, gardes à vue, tenue du casier.",
        },
        [3] = {
            label = 'Maréchal des Logis-Chef',
            grants = { 'manage_warrants' },
            vehicles = { 'Véhicules de patrouille', 'Véhicules banalisés', 'Véhicules rapides' },
            units = { 'psig', 'psig_sabre', 'edsr', 'bmo', 'cynophile', 'nautique' },
            responsibilities = "Chef de patrouille, supervision, avis de recherche.",
        },
        [4] = {
            label = 'Adjudant',
            grants = {}, -- l'accès Enquête est débloqué par la compétence GT037
            vehicles = { 'Véhicules banalisés', 'Véhicules rapides' },
            units = { 'psig_sabre', 'edsr', 'fag', 'pghm', 'brigade_recherches' },
            responsibilities = "Encadrement d'unité, coordination des appuis.",
        },
        [5] = {
            label = 'Adjudant-Chef',
            grants = { 'manage_laws' },
            vehicles = { 'Véhicules banalisés', 'Véhicules rapides', 'Véhicules spécialisés' },
            units = { 'edsr', 'fag', 'pghm', 'garde_rep', 'brigade_recherches', 'renseignement_gn', 'ircgn' },
            responsibilities = "Sous-officier supérieur — conduite d'opérations, gestion des preuves.",
        },
        [6] = {
            label = 'Lieutenant',
            grants = { 'delete_records' },
            vehicles = { 'Tous véhicules opérationnels' },
            units = { 'section_recherches', 'renseignement_gn', 'ircgn', 'agign' },
            responsibilities = "Officier — commandement de peloton, supervision judiciaire.",
        },
        [7] = {
            label = 'Capitaine',
            grants = { 'manage_personnel', 'manage_trainings', 'delete_custody' },
            vehicles = { 'Tous véhicules opérationnels' },
            units = { 'gign', 'agign', 'section_recherches' },
            responsibilities = "Commandant de compagnie, gestion du personnel.",
        },
        [8] = {
            label = 'Commandant',
            grants = { 'admin_mdt' },
            vehicles = { 'Tous véhicules' },
            units = { 'gign', 'agign' },
            responsibilities = "Commandement de groupement, administration complète du MDT.",
        },
    },
}

-- Déblocages de permissions par compétence (équivalents gendarmerie)
-- Le registre Config.MDT.SkillUnlocks est global et indexé par code : on y
-- ajoute les codes gendarmerie qui correspondent aux codes police CS037
-- (police technique et scientifique) et CZ001 (formateur).
Config.MDT.SkillUnlocks = Config.MDT.SkillUnlocks or {}
Config.MDT.SkillUnlocks.GT037 = { 'view_evidence', 'manage_evidence' } -- TIC → onglet Enquête
Config.MDT.SkillUnlocks.GZ001 = { 'manage_trainings' }                  -- formateur

-- Compétences à recycler (durée de validité en jours)
-- Même registre global que la police, indexé par code : au-delà du délai,
-- la compétence passe « À recycler » dans la fiche de l'agent.
Config.MDT.SkillRecycleDays = Config.MDT.SkillRecycleDays or {}
Config.MDT.SkillRecycleDays.GC002 = 30  -- recyclage tir annuel
Config.MDT.SkillRecycleDays.GC005 = 90  -- recyclage bâton
Config.MDT.SkillRecycleDays.GC008 = 90  -- recyclage LBD
Config.MDT.SkillRecycleDays.GB006 = 30  -- habilitation HK G36
Config.MDT.SkillRecycleDays.GB009 = 30  -- habilitation fusil à pompe
Config.MDT.SkillRecycleDays.GB021 = 90  -- habilitation LBD
