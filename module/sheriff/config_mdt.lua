--  MDT — Département BLAINE COUNTY SHERIFF'S OFFICE
--
--  Ce fichier déclare Config.MDT.Departments.sheriff :
--    • jobs        : les métiers LSLegacy rattachés à ce département
--    • tabs        : onglets MDT activés pour ce département
--    • services    : organisation en divisions / unités
--    • grades      : 9 grades, chacun débloque permissions / véhicules
--
--  IMPORTANT — Permissions CUMULATIVES :
--  Chaque grade ne liste dans `grants` que les permissions QU'IL AJOUTE.
--  shared/permissions.lua cumule tous les `grants` des grades de 0 jusqu'au
--  grade du joueur. Un Undersheriff possède donc tout ce qui précède.
--
--  BASE JUDICIAIRE COMMUNE — Le shérif partage avec la police le casier,
--  les amendes, les avis de recherche, les gardes à vue, les dossiers, le
--  registre des armes, le code juridique et l'historique des interventions
--  (Config.MDT.DataGroups). Chaque pièce reste estampillée au pôle qui l'a
--  rédigée grâce au champ `short` ci-dessous.

Config.MDT = Config.MDT or {}
Config.MDT.Departments = Config.MDT.Departments or {}

Config.MDT.Departments.sheriff = {
    label = "Blaine County Sheriff's Office",
    short = 'BCSO',
    color = '#7a5c2e', -- tan/marron, uniforme shérif

    jobs = { 'sheriff' },

    -- Mêmes onglets que la police : les deux pôles font le même métier sur
    -- la même base. L'ordre d'affichage vient du registre Config.MDT.Tabs.
    tabs = { 'dashboard', 'citizens', 'vehicles', 'weapons', 'int_reports', 'dossiers', 'warrants', 'custody', 'investigation', 'laws', 'interventions', 'effectifs', 'trainings', 'organisation', 'garage', 'entreprise', 'boutique_tenue' },

    -- BOUTIQUE TENUES — point de retrait non précisé (aucun vestiaire
    -- n'existait pour ce département) : coordonnées placeholder (0,0,0) à
    -- ajuster une fois l'emplacement du dépôt shérif défini.
    boutique = {
        DeliveryCoords = vector3(0.0, 0.0, 0.0),
        ItemPrice      = 30,
        DeliveryDelay  = 3 * 60,
        MaxPendingPerAgent = 3,
        MaxItemsPerOrder = 15,
    },

    -- DIVISIONS (4 pôles)
    services = {
        {
            id = 'patrol_division',
            label = 'Patrol Division',
            units = {
                { id = 'patrol',         label = 'Patrol Deputies',      description = 'Base unit — public reception, first response.' },
                { id = 'substation',     label = 'Substation',           description = 'Pooled coverage across several patrol sectors.' },
                { id = 'special_patrol', label = 'Special Patrol Unit',  description = 'Night proactive patrol — surveillance, felony stops.' },
                { id = 'rapid_response', label = 'Rapid Response Team',  description = 'First responders to active-shooter and mass-casualty events.' },
            },
        },
        {
            id = 'support_division',
            label = 'Support Units',
            units = {
                { id = 'traffic',      label = 'Traffic Unit',              description = 'Highway safety enforcement, DUI patrol.' },
                { id = 'motors',       label = 'Motor Unit',                 description = 'Motorcycle patrol — corridor surveillance, escorts, interceptions.' },
                { id = 'motor_response', label = 'Motor Response Team',      description = 'Rapid two-wheel response.' },
                { id = 'k9',           label = 'K9 Unit',                    description = 'Canine teams (tracking, narcotics, explosives).' },
                { id = 'marine',       label = 'Marine Unit',                description = 'Coastline and waterway patrol.' },
                { id = 'air_support',  label = 'Air Support Unit',           description = "Sheriff's helicopter — observation and rescue." },
                { id = 'sar',          label = 'Search and Rescue Unit',     description = 'Rescue operations in difficult terrain.' },
                { id = 'honor_guard',  label = 'Honor Guard',                description = 'Ceremonial honors, official escorts, mounted unit.' },
            },
        },
        {
            id = 'tactical_division',
            label = 'Tactical Division',
            units = {
                { id = 'swat',          label = 'SWAT',                description = 'Special Weapons and Tactics — barricaded suspects, hostage rescue, terrorism.' },
                { id = 'regional_swat', label = 'Regional SWAT Team',  description = 'Regional tactical support element.' },
            },
        },
        {
            id = 'investigations_division',
            label = 'Investigations Division',
            units = {
                { id = 'detectives',   label = 'Detective Bureau',           description = 'Local criminal investigations.' },
                { id = 'major_crimes', label = 'Major Crimes Unit',          description = 'Complex cases and organized crime.' },
                { id = 'forensics',    label = 'Forensic Services Unit',     description = 'Crime scene and forensic analysis.' },
                { id = 'intel',        label = 'Intelligence Unit',          description = 'Collection and analysis of criminal intelligence.' },
            },
        },
    },

    -- CODES DE FORMATION PROPRES AU SHÉRIF
    -- Sans cette liste, le cœur MDT retomberait sur Config.MDT.TrainingCodes,
    -- qui décrit le cursus police. Les deux codes marqués ci-dessous
    -- débloquent des permissions (voir Config.MDT.SkillUnlocks).
    trainingCodes = {
        { code = 'SA001', name = 'Basic Deputy Training' },
        { code = 'SA004', name = 'Baton Certification' },
        { code = 'SA007', name = 'OC Spray Certification' },
        { code = 'SA012', name = 'Professional Intervention' },
        { code = 'SB003', name = 'Qualified Shooter — Handgun' },
        { code = 'SB006', name = 'Patrol Rifle Certification' },
        { code = 'SB009', name = 'Shotgun Certification' },
        { code = 'SB014', name = 'Precision Marksman' },
        { code = 'SB021', name = 'Less-Lethal (Beanbag) Certification' },
        { code = 'SB030', name = 'Stress Shooting' },
        { code = 'SC002', name = 'Annual Firearms Requalification' },
        { code = 'SC005', name = 'Baton Recertification' },
        { code = 'SC008', name = 'Less-Lethal Recertification' },
        { code = 'SD003', name = 'Off-Road Driving' },
        { code = 'SD007', name = 'Emergency Vehicle Operations' },
        { code = 'SD011', name = 'Motor Unit Certification' },
        { code = 'SE002', name = 'Traffic Stops & DUI Detection' },
        { code = 'SE006', name = 'Traffic Collision Investigation' },
        { code = 'SF004', name = 'Tactical Combat Casualty Care' },
        { code = 'SG001', name = 'Criminal Investigator Certification' },
        { code = 'SG005', name = 'Interview & Interrogation' },
        { code = 'SG012', name = 'Narcotics Enforcement' },
        { code = 'ST037', name = 'Crime Scene Technician' }, -- → Forensics
        { code = 'SZ001', name = 'Field Training Officer' },  -- → création de formation
        { code = 'SH010', name = 'Crowd Control / Riot Response' },
        { code = 'SH015', name = 'VIP / Dignitary Protection' },
        { code = 'SH021', name = 'HazMat / WMD Response' },
        { code = 'SK004', name = 'Mountain Rescue Operations' },
        { code = 'SK009', name = 'Dive Team Certification' },
        { code = 'SK014', name = 'K9 Handler Certification' },
    },

    -- GRADES (0 → 11)
    -- Progression alignée sur celle de la police à grade équivalent (mêmes
    -- permissions sur la base commune), avec des échelons supplémentaires
    -- propres à la hiérarchie réelle d'un Sheriff's Office (Deputy II,
    -- Commander, Sheriff élu en tête de chaîne).
    grades = {
        [0] = {
            label = 'Explorer',
            grants = { 'view_citizens', 'view_vehicles', 'view_reports', 'view_warrants', 'view_weapons', 'view_laws', 'view_trainings', 'view_callouts' },
            vehicles = { 'Basic Patrol Vehicles' },
            units = { 'patrol' },
            responsibilities = 'Supervised ride-along, public assistance, front desk.',
        },
        [1] = {
            label = 'Deputy Trainee',
            grants = { 'create_fine', 'create_report' },
            vehicles = { 'Patrol Vehicles' },
            units = { 'patrol' },
            responsibilities = 'Patrol, citations, initial reports.',
        },
        [2] = {
            label = 'Deputy Sheriff I',
            grants = { 'manage_records', 'manage_custody', 'manage_weapons' },
            vehicles = { 'Patrol Vehicles', 'Unmarked Vehicles' },
            units = { 'patrol', 'substation', 'special_patrol', 'motors', 'k9' },
            responsibilities = 'Independent patrol, bookings, records upkeep.',
        },
        [3] = {
            label = 'Deputy Sheriff II',
            grants = {}, -- promotion à l'ancienneté, pas de nouvelle permission
            vehicles = { 'Patrol Vehicles', 'Unmarked Vehicles' },
            units = { 'patrol', 'substation', 'special_patrol', 'motors', 'k9' },
            responsibilities = 'Senior deputy — field training of junior deputies.',
        },
        [4] = {
            label = 'Corporal',
            grants = { 'manage_warrants' },
            vehicles = { 'Patrol Vehicles', 'Unmarked Vehicles', 'Pursuit Vehicles' },
            units = { 'special_patrol', 'rapid_response', 'traffic', 'motors', 'k9', 'marine' },
            responsibilities = 'Patrol lead, oversight, warrants.',
        },
        [5] = {
            label = 'Sergeant',
            grants = {}, -- l'accès Investigations est débloqué par la compétence ST037
            vehicles = { 'Unmarked Vehicles', 'Pursuit Vehicles' },
            units = { 'rapid_response', 'traffic', 'air_support', 'sar', 'detectives' },
            responsibilities = 'Unit supervision, coordination of support elements.',
        },
        [6] = {
            label = 'Staff Sergeant',
            grants = { 'manage_laws' },
            vehicles = { 'Unmarked Vehicles', 'Pursuit Vehicles', 'Specialized Vehicles' },
            units = { 'traffic', 'air_support', 'sar', 'honor_guard', 'detectives', 'intel', 'forensics' },
            responsibilities = 'Senior NCO — operations command, evidence management.',
        },
        [7] = {
            label = 'Lieutenant',
            grants = { 'delete_records' },
            vehicles = { 'All Operational Vehicles' },
            units = { 'major_crimes', 'intel', 'forensics', 'regional_swat' },
            responsibilities = 'Watch commander, judicial oversight.',
        },
        [8] = {
            label = 'Captain',
            grants = { 'manage_personnel', 'manage_trainings', 'delete_custody' },
            vehicles = { 'All Operational Vehicles' },
            units = { 'swat', 'regional_swat', 'major_crimes' },
            responsibilities = 'Company commander, personnel management.',
        },
        [9] = {
            label = 'Commander',
            grants = {}, -- rang structurel, aucune permission supplémentaire
            vehicles = { 'All Operational Vehicles' },
            units = { 'swat', 'regional_swat', 'major_crimes' },
            responsibilities = 'Division commander, oversight of multiple units.',
        },
        [10] = {
            label = 'Undersheriff',
            grants = { 'admin_mdt' },
            vehicles = { 'All Vehicles' },
            units = { 'swat', 'regional_swat' },
            responsibilities = 'Department command, full MDT administration.',
        },
        [11] = {
            label = 'Sheriff',
            grants = {}, -- déjà tout, via le cumul des grades précédents
            vehicles = { 'All Vehicles' },
            units = { 'swat', 'regional_swat' },
            responsibilities = "Elected head of the department, ultimate authority.",
        },
    },
}

-- Déblocages de permissions par compétence (équivalents shérif)
-- Le registre Config.MDT.SkillUnlocks est global et indexé par code : on y
-- ajoute les codes shérif qui correspondent aux codes police CS037
-- (police technique et scientifique) et CZ001 (formateur).
Config.MDT.SkillUnlocks = Config.MDT.SkillUnlocks or {}
Config.MDT.SkillUnlocks.ST037 = { 'view_evidence', 'manage_evidence' } -- Crime Scene Technician → onglet Investigations
Config.MDT.SkillUnlocks.SZ001 = { 'manage_trainings' }                  -- Field Training Officer

-- Compétences à recycler (durée de validité en jours)
-- Même registre global que la police, indexé par code : au-delà du délai,
-- la compétence passe « À recycler » dans la fiche de l'agent.
Config.MDT.SkillRecycleDays = Config.MDT.SkillRecycleDays or {}
Config.MDT.SkillRecycleDays.SC002 = 30  -- recyclage tir annuel
Config.MDT.SkillRecycleDays.SC005 = 90  -- recyclage bâton
Config.MDT.SkillRecycleDays.SC008 = 90  -- recyclage less-lethal
Config.MDT.SkillRecycleDays.SB006 = 30  -- habilitation carabine
Config.MDT.SkillRecycleDays.SB009 = 30  -- habilitation fusil à pompe
Config.MDT.SkillRecycleDays.SB021 = 90  -- habilitation less-lethal
