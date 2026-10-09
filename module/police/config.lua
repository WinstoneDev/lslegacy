--  MODULE POLICE NATIONALE — Configuration principale
--  Framework : LSLegacy (custom)
--  Auteur    : Bastien MAGAN

Config.Police = {}

-- Job rattaché au module
Config.Police.Job = 'police'

-- Coordonnées du commissariat principal
Config.Police.Headquarters = vector3(441.6, -981.8, 30.7)
Config.Police.HeadquartersHeading = 90.0

-- Position du blip visible sur la map pour le nouveau commissariat (distincte
-- de Headquarters ci-dessus tant que les autres points du nouveau bâtiment
-- — prise de service, armurerie, vestiaire — n'ont pas été communiqués).
Config.Police.BlipCoords = vector3(-362.4848, -356.5504, 31.5752)

-- Armurerie (spawn armes en prise de service)
Config.Police.ArmoryCoords = vector3(453.9, -989.1, 30.7)

-- PNJ armurier (nouveau commissariat) : donne les armes du grade, comme la
-- zone ArmoryCoords ci-dessus (ancien commissariat vanilla, conservée).
Config.Police.ArmorerNpc = {
    models  = {'ig_mp_agent14', 's_m_m_ciasec_01'},
    coords  = vector3(-422.3479, -382.1095, 25.0988),
    heading = 348.4145,
}

-- PNJ chef de poste (nouveau commissariat). Fonctionnalité à définir —
-- interaction placeholder en attendant les instructions précises.
Config.Police.StationChiefNpc = {
    models  = {'s_m_y_cop_01', 's_f_y_cop_01'},
    coords  = vector3(-403.318665, -379.160431, 25.084229),
    heading = 354.33071899414,
}

-- PNJ armurier RAID (salle RAID/BRI). Décoratif pour l'instant.
Config.Police.RaidArmorerNpc = {
    models  = {'s_m_y_armymech_01'},
    coords  = vector3(-360.7942, -374.5643, 20.2261),
    heading = 83.3556,
}

-- PNJ cafétéria (nouveau commissariat). Décoratif pour l'instant.
Config.Police.CafeteriaNpc = {
    models  = {'s_m_y_chef_01', 's_m_y_waiter_01'},
    coords  = vector3(-374.2719, -349.3803, 43.5975),
    heading = 174.2999,
}

-- Pôle Judiciaire — postes d'analyse des preuves (nouveau commissariat).
-- Coordonnées réservées, sans interaction pour l'instant : la mécanique
-- d'analyse dépend des items preuve, pas encore créés.
Config.Police.EvidenceAnalysisStations = {
    { coords = vector3(-401.5780, -329.2868, 53.2555), heading = 151.5797 },
    { coords = vector3(-402.1458, -332.4690, 53.2555), heading = 6.0186 },
    { coords = vector3(-394.4782, -334.8891, 53.2555), heading = 256.3378 },
}

-- Coffre à preuves : stockage partagé par tous les policiers (pas personnel,
-- contrairement aux casiers), pour déposer les preuves collectées en intervention.
Config.Police.EvidenceLocker = {
    coords    = vector3(-407.4478, -333.8618, 53.2554),
    heading   = 72.9549,
    maxWeight = 50,
}

-- Armurerie — 3 PNJ (module/police/client/armory.lua + server/armory.lua) :
--   • Armurier      : accessoires seuls, libre d'accès, posés directement sur
--     une arme de l'inventaire (Config.WeaponComponents en shared/config.lua).
--   • Chef de poste : équipement personnel (unique par agent, état en BDD)
--     + armes collectives à stock limité, formation MDT requise au retrait.
--   • Armurier RAID : mêmes mécanismes (accessoires Mk2, personnel identique,
--     collectif RAID), accès réservé aux unités RAID/BRI (CheckRaidOrBriUnit),
--     revalidé en direct sur le MDT à chaque action, et débloqué sans condition
--     pour un Commissaire (grade 8, IsCommissaire).
Config.Police.Armory = {
    Accessories = {
        standard = {
            'component_at_pi_flsh', 'component_at_ar_flsh',
            'component_at_scope_macro_02', 'component_at_scope_medium',
            'component_at_ar_afgrip',
        },
        raid = {
            'component_at_pi_flsh', 'component_at_ar_flsh',
            'component_at_scope_macro_02', 'component_at_scope_medium_mk2',
            'component_at_ar_afgrip_02',
        },
    },

    -- Libre sauf le Tonfa (formation requise au premier retrait).
    PersonalItems = {
        { item = 'weapon_combatpistol', label = 'SIG Sauer personnel' },
        { item = 'weapon_flashlight',   label = 'Lampe torche' },
        { item = 'weapon_nightstick',   label = 'Tonfa', training = 'BZ003' },
    },

    -- Stocks partagés dissociés par PNJ (pool = 'chef' / 'raid').
    CollectiveStock = 5,
    -- `stock` optionnel par entrée : surcharge CollectiveStock ci-dessus.
    Collective = {
        police = {
            { item = 'weapon_pumpshotgun',    label = 'Remington 870',  training = 'CA041' },
            { item = 'weapon_specialcarbine', label = 'HK G36C',        training = 'CA066' },
            { item = 'weapon_smg',            label = 'HK UMP9',       training = 'CA070' },
            { item = 'weapon_stungun',        label = 'PIE',            training = 'CA096' },
            { item = 'weapon_lbd',            label = 'LBD 40',         training = 'CA037' },
            { item = 'weapon_lgcougar',       label = 'Lanceur Cougar', training = 'CA072' },
            { item = 'weapon_bzgas',          label = 'Grenade Lacrymogene', stock = 10 },
            { item = 'weapon_smokegrenade',   label = 'Grenade fumigène',    stock = 10 },
            { item = 'weapon_gazeuse',        label = 'Gazeuse lacrymogène', stock = 10 },
            { item = 'ammo_training',         label = "Munition d'entrainement", training = 'CZ001', minGrade = 5, stock = 50 },
            { item = 'med_kit',               label = 'Kit de Premiers Secours', training = 'CB014', stock = 10 },
        },
        raid = {
            { item = 'weapon_combatshotgun',      label = 'Benelli M4',          training = 'CA005' },
            { item = 'weapon_specialcarbine_mk2', label = 'HK G36C Mk II',       training = 'CA066' },
            { item = 'weapon_smg',                label = 'HK UMP9',            training = 'CA070' },
            { item = 'weapon_stungun',            label = 'PIE',                 training = 'CA096' },
            { item = 'weapon_heavysniper',        label = 'Sako TRG 42',         training = 'CA027' },
            { item = 'weapon_bzgas',              label = 'Grenade Lacrymogene', stock = 10 },
            { item = 'weapon_smokegrenade',       label = 'Grenade fumigène',    stock = 10 },
            { item = 'weapon_gazeuse',            label = 'Gazeuse lacrymogène', stock = 10 },
            { item = 'ammo_training',             label = "Munition d'entrainement", training = 'CZ001', minGrade = 5, stock = 50 },
            { item = 'med_kit',                   label = 'Kit de Premiers Secours', training = 'CB014', stock = 10 },
        },
    },
}

-- Casier personnel (coffre inventaire) — plus de vestiaire physique : les
-- tenues s'obtiennent via l'onglet MDT « Boutique tenues » (Config.MDT.Departments.police.boutique).
Config.Police.LockerCoords = vector3(447.3, -992.4, 30.7)

Config.Police.Locker = {
    maxWeight = 30,
}

-- Salles de casiers dédiées (accès restreint) — même casier personnel, juste
-- une zone d'accès différente selon le sexe du personnage ou l'unité RAID/BRI.
Config.Police.LockerRooms = {
    { coords = vector3(415.1864, -360.8205, 25.0988),   heading = 347.8129, restrict = 'female' },
    { coords = vector3(-396.0625, -366.1849, 25.0988),  heading = 252.3298, restrict = 'male' },
    { coords = vector3(-356.3961, -390.1560, 20.2261),  heading = 354.0395, restrict = 'raidbri' },
}

-- Cellule de garde à vue principale
Config.Police.CustodyCoords = vector3(461.6, -997.9, 25.8)
Config.Police.CustodyHeading = 270.0

-- Prison (Bolingbroke)
Config.Police.PrisonCoords = vector3(1849.4, 2595.6, 45.7)
Config.Police.PrisonHeading = 270.0

-- Blips carte
Config.Police.Blips = {
    {
        coords  = Config.Police.BlipCoords,
        sprite  = 60,
        color   = 3,
        scale   = 0.9,
        label   = 'Commissariat Central',
        short   = true,
    },
}

-- STAND DE TIR — accès réservé aux formateurs (compétence CZ001) et au
-- Commissaire (grade 8). Le formateur positionne lui-même le stagiaire
-- avant de lancer le test ; le déroulement (type de cibles fixe/surgissante)
-- dépend du stand utilisé, pas d'un choix dans le menu.
Config.Police.ShootingRange = {
    InstructorSkillCode = 'CZ001',
    InstructorMinGrade  = 8, -- Commissaire : accès même sans la compétence
    PointsPerHit = 5,
    TargetProp = 'prop_range_target_01',
    Difficulties = {
        { id = 'facile',      label = 'Facile',      interval = 2.0 },
        { id = 'normal',      label = 'Normal',      interval = 1.5 },
        { id = 'dur',         label = 'Dur',         interval = 1.0 },
        { id = 'tres_dur',    label = 'Très dur',    interval = 0.5 },
        { id = 'impossible',  label = 'Impossible',  interval = 0.3 },
    },
    TargetCounts = { 10, 12, 14, 16, 18, 20 },
    -- Un stand = un point d'interaction ox_target + un jeu de positions de
    -- cibles (au moins 20, pour couvrir le plus grand nombre choisissable).
    -- type = 'fixed' (props déjà en place, une seule "active" à la fois) ou
    -- 'surging' (la cible apparaît puis se rétracte). À compléter avec les
    -- coordonnées réelles du/des stand(s).
    Stands = {
        -- {
        --     id = 'stand_1',
        --     type = 'fixed', -- ou 'surging'
        --     coords = vector3(0.0, 0.0, 0.0),
        --     targets = {
        --         vector3(0.0, 0.0, 0.0), -- jusqu'à 20 positions
        --     },
        -- },
    },
}

-- Véhicules par grade
Config.Police.Vehicles = {
    -- Patrouille standard (grade 0+)
    patrol = {
        { model = 'police',   label = 'Police Patrouille',  grade = 0 },
        { model = 'police2',  label = 'Police Croiseur',    grade = 0 },
        { model = 'police3',  label = 'Police Rancher',     grade = 1 },
    },
    -- Banalisés (grade 2+)
    unmarked = {
        { model = 'police4',  label = 'Véhicule Banalisé',  grade = 2 },
        { model = 'fbi',      label = 'SUV Banalisé',       grade = 2 },
    },
    -- Rapides (grade 3+)
    fast = {
        { model = 'fbi2',     label = 'SUV Rapide',         grade = 3 },
        { model = 'riot',     label = 'Fourgon Riot',       grade = 3 },
    },
    -- Motos (grade 3+, unité moto uniquement)
    moto = {
        { model = 'policeb',  label = 'Moto Police',        grade = 3 },
    },
    -- Aéronautique (grade 4+, unité aero uniquement)
    air = {
        { model = 'polmav',   label = 'Hélicoptère Police', grade = 4 },
        { model = 'buzzard2', label = 'Drone RPAS',         grade = 4 },
    },
    -- Nautique (grade 3+, unité fluviale uniquement)
    water = {
        { model = 'predator', label = 'Hors-bord Police',   grade = 3 },
    },
    -- Spécialisés RAID/BRI (grade 7+)
    special = {
        { model = 'insurgent3', label = 'MRAP RAID',        grade = 7 },
    },
}

-- Armes distribuées selon grade
Config.Police.Weapons = {
    [0] = {  -- Policier Adjoint
        { weapon = 'WEAPON_PISTOL',      ammo = 60,  label = 'Pistolet réglementaire' },
        { weapon = 'WEAPON_NIGHTSTICK',  ammo = 0,   label = 'Matraque' },
    },
    [1] = {  -- Gardien de la Paix Stagiaire
        { weapon = 'WEAPON_PISTOL',      ammo = 90,  label = 'Pistolet réglementaire' },
        { weapon = 'WEAPON_NIGHTSTICK',  ammo = 0,   label = 'Matraque' },
        { weapon = 'WEAPON_STUNGUN',     ammo = 5,   label = 'Taser' },
    },
    [2] = {  -- Gardien de la Paix
        { weapon = 'WEAPON_PISTOL',      ammo = 120, label = 'Pistolet réglementaire' },
        { weapon = 'WEAPON_PUMPSHOTGUN', ammo = 20,  label = 'Fusil à pompe' },
        { weapon = 'WEAPON_NIGHTSTICK',  ammo = 0,   label = 'Matraque' },
        { weapon = 'WEAPON_STUNGUN',     ammo = 5,   label = 'Taser' },
    },
    [3] = {  -- Brigadier Chef
        { weapon = 'WEAPON_PISTOL',      ammo = 120, label = 'Pistolet réglementaire' },
        { weapon = 'WEAPON_CARBINERIFLE',ammo = 60,  label = 'Carabine' },
        { weapon = 'WEAPON_PUMPSHOTGUN', ammo = 20,  label = 'Fusil à pompe' },
        { weapon = 'WEAPON_NIGHTSTICK',  ammo = 0,   label = 'Matraque' },
        { weapon = 'WEAPON_STUNGUN',     ammo = 5,   label = 'Taser' },
    },
    [7] = {  -- Commandant (RAID/BRI)
        { weapon = 'WEAPON_PISTOL',       ammo = 120, label = 'Pistolet réglementaire' },
        { weapon = 'WEAPON_CARBINERIFLE', ammo = 120, label = 'Carabine' },
        { weapon = 'WEAPON_SMG',          ammo = 90,  label = 'Pistolet mitrailleur' },
        { weapon = 'WEAPON_SNIPERRIFLE',  ammo = 30,  label = 'Fusil de précision' },
        { weapon = 'WEAPON_NIGHTSTICK',   ammo = 0,   label = 'Matraque' },
        { weapon = 'WEAPON_STUNGUN',      ammo = 5,   label = 'Taser' },
    },
}

-- Radio — canaux par service
Config.Police.RadioChannels = {
    { id = 1, freq = '156.800', label = 'Canal Général',         color = '#3498db', icon = '📡' },
    { id = 2, freq = '157.050', label = 'Police Secours',        color = '#2ecc71', icon = '🚓' },
    { id = 3, freq = '157.325', label = 'BAC / BAC 97N',         color = '#e74c3c', icon = '⚡' },
    { id = 4, freq = '158.100', label = 'BRAV-M / CRS',          color = '#f39c12', icon = '🛡️' },
    { id = 5, freq = '158.450', label = 'Brigade Moto',          color = '#9b59b6', icon = '🏍️' },
    { id = 6, freq = '159.225', label = 'K9 / Équestre',         color = '#1abc9c', icon = '🐕' },
    { id = 7, freq = '160.000', label = 'Aéronautique',          color = '#34495e', icon = '🚁' },
    { id = 8, freq = '160.575', label = 'Fluviale',              color = '#2980b9', icon = '⚓' },
    { id = 9, freq = '161.350', label = 'RAID / BRI',            color = '#c0392b', icon = '🎯' },
    { id = 10, freq = '162.000', label = 'Pôle Judiciaire',      color = '#8e44ad', icon = '🔬' },
    { id = 11, freq = '162.675', label = 'Commandement',         color = '#d35400', icon = '⭐' },
}

-- Actions policières — paramètres
Config.Police.Actions = {
    -- Durée des actions en millisecondes
    cuffDuration        = 3500,
    searchDuration      = 5000,
    palpationDuration   = 3000,
    idCheckDuration     = 2500,
    licenseCheckDuration= 2000,
    seizeItemDuration   = 3000,
    escortAttachRange   = 2.0,
    interactionRange    = 1.0,

    -- Anti-abus : cooldown entre deux actions identiques (ms)
    cooldowns = {
        cuff         = 3000,
        search       = 8000,
        palpation    = 5000,
        id_check     = 4000,
        escort       = 2000,
    },

    -- Préfixes d'items saisissables lors d'une fouille complète.
    -- Ajouter ici les futurs préfixes (ex: 'drug_', 'illegal_').
    seizablePrefixes = {
        'weapon_',
    },
}

-- Notifications (clé de l'event de notif du framework)

-- Durée d'affichage de TOUTES les notifications « Police Nationale »,
-- en millisecondes. Les messages du service sont souvent longs
-- (consignes du central, bilan d'intervention, motifs de refus) et
-- s'affichent en pleine conduite : il faut le temps de les lire.
Config.Police.NotifyDuration = 30000
