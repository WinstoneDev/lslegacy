--  MODULE SAMU — Configuration principale
--  Framework : LSLegacy (custom)

Config.SAMU = {}

-- Job rattaché au module
Config.SAMU.Job = 'samu'

-- Coordonnées du Centre Médical de Los Santos
-- Même bâtiment que Config.Injury.RespawnCoords (cohérence RP).
Config.SAMU.Headquarters       = vector3(-829.173645, -1218.131836, 6.920166)

-- Zone d'habillage (vestiaire)
Config.SAMU.ClothingCoords  = vector3(-807.296692, -1224.553833, 11.301147)
Config.SAMU.ClothingHeading = 221.10237121582

-- Point de sortie véhicule
Config.SAMU.GarageCoords   = vector3(-858.514282, -1221.362671, 6.195557)
Config.SAMU.GarageHeading  = 323.14959716797

-- Blip flottant du garage (rouge = véhicule à ranger, vert = à pied)
Config.SAMU.GarageBlipCoords = vector3(-859.252747, -1223.010986, 6.212402)

-- Blips carte
Config.SAMU.Blips = {
    {
        coords  = Config.SAMU.Headquarters,
        sprite  = 61,
        color   = 3,
        scale   = 0.8,
        label   = 'Hôpital de Los Santos',
        short   = true,
    },
}

-- Tenues disponibles au vestiaire
Config.SAMU.Outfits = {
    {
        label  = 'Tenue Ambulancier',
        grade  = 0,
        male   = {
            tshirt_1 = 15, tshirt_2 = 0,
            torso_1  = 56, torso_2  = 0,
            pants_1  = 21, pants_2  = 0,
            shoes_1  = 25, shoes_2  = 0,
            helmet_1 = -1, helmet_2 = -1,
            chain_1  = -1, chain_2  = -1,
            ears_1   = -1, ears_2   = -1,
        },
        female = {
            tshirt_1 = 15, tshirt_2 = 0,
            torso_1  = 49, torso_2  = 0,
            pants_1  = 30, pants_2  = 0,
            shoes_1  = 28, shoes_2  = 0,
            helmet_1 = -1, helmet_2 = -1,
            chain_1  = -1, chain_2  = -1,
            ears_1   = -1, ears_2   = -1,
        },
    },
}

-- Compatibilité interne (utilisé par ApplyUniform)
Config.SAMU.Uniforms = {
    male   = Config.SAMU.Outfits[1].male,
    female = Config.SAMU.Outfits[1].female,
}

-- Véhicules par grade
Config.SAMU.Vehicles = {
    ambulance = {
        { model = 'ambulance',   label = 'Ambulance', grade = 0 },
        { model = 'sandbulance', label = 'Sandstorm Ambulance', grade = 0 },
    },
    air = {
        { model = 'polmav', label = 'Hélicoptère médical (SMUR)', grade = 3 },
    },
}

-- Actions de soins
Config.SAMU.Actions = {
    -- Durée des actions en millisecondes
    healDuration          = 4000,
    reviveDuration         = 6000,
    reviveGroundDuration    = 2500, -- délai au sol après réanimation, avant de se relever
    monitorAttachDuration   = 2500, -- Health Inspection : branchement du moniteur cardiaque
    interactionRange    = 3.0,

    -- Santé GTA au-dessous de laquelle un joueur est considéré "à terre"
    -- (KO ou coma) et donc réanimable. Le coma plafonne la vie à 101 et le
    -- KO à 105 (cf. client/player/injury.lua) : 105 couvre les deux états.
    -- Sert à n'afficher "Réanimer" que sur un patient réellement inconscient.
    downedHealthThreshold = 105,

    -- Soin : points de vie GTA rendus (100-200)
    healAmount           = 40,

    -- Réanimation : santé restaurée après sortie de KO/coma (100=mort, 200=plein → 125=25%)
    reviveHealth          = 125,

    -- Anti-abus : cooldown entre deux actions identiques (ms)
    cooldowns = {
        heal   = 5000,
        revive = 8000,
        bag    = 3000,
    },
}

-- Health Inspection — mannequin par membre, blessures & trousse
Config.SAMU.HealthInspection = {}

-- 6 zones du mannequin (têtes/torse/bras/jambes, gauche+droite séparés)
Config.SAMU.HealthInspection.BodyPartLabels = {
    head  = 'Tête',
    body  = 'Torse',
    arm_l = 'Bras Gauche',
    arm_r = 'Bras Droit',
    leg_l = 'Jambe Gauche',
    leg_r = 'Jambe Droite',
}

-- 7 types de blessures (compteurs, panneau "Blessures Totales")
Config.SAMU.HealthInspection.InjuryLabels = {
    blunt      = 'Traumatisme',
    broken     = 'Fracture',
    bruising   = 'Contusion',
    burns      = 'Brûlure',
    gunshot    = 'Blessure par balle',
    laceration = 'Lacération',
    taser      = 'Fléchette de Taser',
}

-- Catégorie de dégâts (LSLegacy:injury, calculée serveur) → type de blessure infligé.
-- Étend le système existant (unarmed/melee/vehicle/explosion/firearm/generic)
-- avec une seule catégorie nouvelle : taser.
Config.SAMU.HealthInspection.CategoryToInjury = {
    unarmed   = 'bruising',
    melee     = 'laceration',
    vehicle   = 'blunt',
    explosion = 'burns',
    firearm   = 'gunshot',
    taser     = 'taser',
    generic   = 'broken',
}

-- Items de la trousse : soin (points de vie GTA rendus au membre traité,
-- plafonné à 100) et types de blessures qu'ils traitent (décrémente le
-- compteur correspondant sur le membre ciblé s'il y en a). `medbag` est
-- volontairement absent : ce n'est pas un item soignant, il n'apparaît donc
-- jamais dans la grille de la trousse.
Config.SAMU.HealthInspection.Items = {
    bandage    = { label = 'Bandage',                heal = 15, treats = { 'laceration', 'bruising' } },
    suture     = { label = 'Suture',                 heal = 20, treats = { 'laceration' } },
    forceps    = { label = 'Forceps',                heal = 20, treats = { 'gunshot' } },
    pliers     = { label = 'Pince',                  heal = 15, treats = { 'taser' } },
    splint     = { label = 'Attelle',                heal = 20, treats = { 'broken' } },
    trauma_kit = { label = 'Kit de Traumatologie',    heal = 35, treats = { 'gunshot', 'blunt' } },
    burn_cream = { label = 'Crème pour Brûlures',     heal = 15, treats = { 'burns' } },
    ice_pack   = { label = 'Poche de Glace',          heal = 10, treats = { 'bruising', 'blunt' } },
    med_kit    = { label = 'Kit de Premiers Secours', heal = 25, treats = { 'blunt', 'broken', 'bruising', 'burns', 'gunshot', 'laceration', 'taser' } },
}

-- Réassort gratuit de la trousse (Centre Médical)
Config.SAMU.RestockCoords  = vector3(-446.0, -344.5, 34.5)
Config.SAMU.RestockHeading = 70.0
Config.SAMU.RestockCooldown = 600 -- secondes entre deux réassorts (10 min)
Config.SAMU.RestockItems = {
    bandage    = 5,
    med_kit    = 1,
    forceps    = 2,
    pliers     = 2,
    suture     = 3,
    splint     = 2,
    burn_cream = 3,
    ice_pack   = 3,
    trauma_kit = 1,
    medbag     = 1,
}

-- Notification (même système que les autres métiers)
Config.SAMU.NotifyEvent = 'brutal_notify:SendAlert'
