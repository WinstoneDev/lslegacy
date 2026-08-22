--  MODULE POLICE NATIONALE — Configuration principale
--  Framework : LSLegacy (custom)
--  Auteur    : Bastien MAGAN

Config.Police = {}

-- Job rattaché au module
Config.Police.Job = 'police'

-- Coordonnées du commissariat principal
Config.Police.Headquarters = vector3(441.6, -981.8, 30.7)
Config.Police.HeadquartersHeading = 90.0

-- Armurerie (spawn armes en prise de service)
Config.Police.ArmoryCoords = vector3(453.9, -989.1, 30.7)

-- Zone d'habillage (vestiaire)
Config.Police.ClothingCoords = vector3(447.3, -992.4, 30.7)

-- Cellule de garde à vue principale
Config.Police.CustodyCoords = vector3(461.6, -997.9, 25.8)
Config.Police.CustodyHeading = 270.0

-- Prison (Bolingbroke)
Config.Police.PrisonCoords = vector3(1849.4, 2595.6, 45.7)
Config.Police.PrisonHeading = 270.0

-- Blips carte
Config.Police.Blips = {
    {
        coords  = Config.Police.Headquarters,
        sprite  = 60,
        color   = 3,
        scale   = 0.9,
        label   = 'Commissariat Central',
        short   = true,
    },
}

-- Tenues disponibles au vestiaire
-- Chaque tenue nécessite un grade minimum.
-- Ajouter autant d'entrées que nécessaire.
Config.Police.Outfits = {
    {
        label  = 'Uniforme standard',
        grade  = 0,
        male   = {
            tshirt_1 = 58, tshirt_2 = 0,
            torso_1  = 55, torso_2  = 0,
            pants_1  = 24, pants_2  = 0,
            shoes_1  = 24, shoes_2  = 0,
            helmet_1 = -1, helmet_2 = -1,
            chain_1  = -1, chain_2  = -1,
            ears_1   = -1, ears_2   = -1,
        },
        female = {
            tshirt_1 = 58, tshirt_2 = 0,
            torso_1  = 48, torso_2  = 0,
            pants_1  = 34, pants_2  = 0,
            shoes_1  = 27, shoes_2  = 0,
            helmet_1 = -1, helmet_2 = -1,
            chain_1  = -1, chain_2  = -1,
            ears_1   = -1, ears_2   = -1,
        },
    },
    -- Exemple : tenue BAC (grade 2+)
    -- {
    --     label  = 'Tenue BAC',
    --     grade  = 2,
    --     male   = { tshirt_1 = 0, tshirt_2 = 0, torso_1 = 0, torso_2 = 0,
    --                pants_1 = 0, pants_2 = 0, shoes_1 = 0, shoes_2 = 0,
    --                helmet_1 = -1, helmet_2 = -1, chain_1 = -1, chain_2 = -1,
    --                ears_1 = -1, ears_2 = -1 },
    --     female = { ... },
    -- },
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
