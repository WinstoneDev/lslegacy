--  MODULE MÉCANICIEN — Configuration principale
--  Framework : LSLegacy (custom)

Config.Mecanicien = {}

-- Job rattaché au module
Config.Mecanicien.Job = 'mecanicien'

-- Coordonnées — Benny's Original Motor Works (La Mesa)
Config.Mecanicien.Headquarters       = vector3(-202.95, -1307.71, 31.29)
Config.Mecanicien.HeadquartersHeading = 30.0

-- Zone d'habillage (vestiaire)
Config.Mecanicien.ClothingCoords = vector3(-207.5, -1311.0, 31.29)

-- Point de sortie véhicule (dépanneuses)
Config.Mecanicien.GarageCoords = vector3(-195.0, -1303.0, 31.29)

-- Dépôt de pièces détachées
Config.Mecanicien.PartsDepotCoords = vector3(-199.0, -1315.0, 31.29)

-- Blips carte
Config.Mecanicien.Blips = {
    {
        coords  = Config.Mecanicien.Headquarters,
        sprite  = 446,
        color   = 5,
        scale   = 0.9,
        label   = "Benny's Original Motor Works",
        short   = true,
    },
}

-- Tenues disponibles au vestiaire
Config.Mecanicien.Outfits = {
    {
        label  = 'Bleu de travail',
        grade  = 0,
        male   = {
            tshirt_1 = 13, tshirt_2 = 0,
            torso_1  = 12, torso_2  = 0,
            pants_1  = 4,  pants_2  = 0,
            shoes_1  = 6,  shoes_2  = 0,
            helmet_1 = -1, helmet_2 = -1,
            chain_1  = -1, chain_2  = -1,
            ears_1   = -1, ears_2   = -1,
        },
        female = {
            tshirt_1 = 13, tshirt_2 = 0,
            torso_1  = 11, torso_2  = 0,
            pants_1  = 8,  pants_2  = 0,
            shoes_1  = 4,  shoes_2  = 0,
            helmet_1 = -1, helmet_2 = -1,
            chain_1  = -1, chain_2  = -1,
            ears_1   = -1, ears_2   = -1,
        },
    },
}

-- Compatibilité interne (utilisé par ApplyUniform)
Config.Mecanicien.Uniforms = {
    male   = Config.Mecanicien.Outfits[1].male,
    female = Config.Mecanicien.Outfits[1].female,
}

-- Véhicules par grade (dépanneuses)
Config.Mecanicien.Vehicles = {
    tow = {
        { model = 'towtruck',  label = 'Dépanneuse légère', grade = 0 },
        { model = 'towtruck2', label = 'Dépanneuse plateau', grade = 2 },
        { model = 'flatbed',   label = 'Camion plateau',     grade = 3 },
    },
}

-- Pièces détachées
-- IMPORTANT : `prop` doit pointer vers un modèle custom streamé par une
-- resource séparée (capot/pare-choc/portière n'existent pas en modèles
-- détachés natifs dans GTA V). Remplacer les valeurs ci-dessous par les
-- noms de vos modèles une fois la resource de props ajoutée au serveur.
-- En attendant, un prop générique de caisse à outils est utilisé en repli.
Config.Mecanicien.Parts = {
    -- Pièces "portées en main" (prop attaché + pose via touche E)
    piece_capot = {
        label    = 'Capot',
        price    = 150,
        carried  = true,
        prop     = 'prop_tool_boxv1',   -- TODO: remplacer par le modèle custom du capot
        repairs  = 'body',
    },
    piece_pare_choc_avant = {
        label    = 'Pare-choc avant',
        price    = 120,
        carried  = true,
        prop     = 'prop_tool_boxv1',   -- TODO: remplacer par le modèle custom du pare-choc avant
        repairs  = 'body',
    },
    piece_pare_choc_arriere = {
        label    = 'Pare-choc arrière',
        price    = 120,
        carried  = true,
        prop     = 'prop_tool_boxv1',   -- TODO: remplacer par le modèle custom du pare-choc arrière
        repairs  = 'body',
    },
    piece_portiere = {
        label    = 'Portière',
        price    = 200,
        carried  = true,
        prop     = 'prop_tool_boxv1',   -- TODO: remplacer par le modèle custom de la portière
        repairs  = 'body',
    },
    -- Pièce consommée directement depuis l'inventaire (pas portée en main)
    piece_pneu = {
        label    = 'Pneu',
        price    = 80,
        carried  = false,
        repairs  = 'tyre',
    },
}

-- Offset du prop par rapport à la main droite du mécanicien
Config.Mecanicien.PartHandBone   = 'SKEL_R_Hand'
Config.Mecanicien.PartHandOffset = vector3(0.0, 0.0, 0.0)
Config.Mecanicien.PartHandRot    = vector3(0.0, 0.0, 0.0)

-- Seuils de diagnostic
Config.Mecanicien.Thresholds = {
    -- GTA : EngineHealth/BodyHealth vont de 0 (détruit) à 1000 (parfait)
    EngineDamaged = 700,
    BodyDamaged   = 700,
}

-- Tarifs main d'œuvre (facturés au client, sans pièce)
Config.Mecanicien.LaborPrices = {
    engine = 250,
    tyre   = 60,   -- en plus du prix de la pièce
    body   = 100,  -- en plus du prix de la pièce
    tuning = {
        color      = 300,
        wheels     = 400,
        performance= 1500,
    },
}

-- Minijeu de réparation (maison, barre + appui touche)
Config.Mecanicien.Minigame = {
    rounds       = 3,
    roundDuration = 1600, -- ms par aller-retour de la barre
    zoneSize      = 0.15, -- largeur de la zone de réussite (0-1)
    requiredHits  = 2,     -- sur `rounds`
}

-- Tuning (LS Customs simplifié)
Config.Mecanicien.Tuning = {
    colors = {
        { label = 'Noir',         id = 0  },
        { label = 'Blanc',        id = 111 },
        { label = 'Rouge',        id = 27 },
        { label = 'Bleu',         id = 64 },
        { label = 'Gris',         id = 1  },
        { label = 'Jaune',        id = 88 },
    },
    wheelTypes = {
        { label = 'Sport',  id = 1 },
        { label = 'Muscle', id = 2 },
        { label = 'Lowrider', id = 3 },
        { label = 'SUV',     id = 4 },
        { label = 'Tuner',   id = 6 },
    },
}

-- Actions / cooldowns
Config.Mecanicien.Actions = {
    interactionRange = 3.0,
    installRange      = 2.5,
    cooldowns = {
        diagnose = 3000,
        repair   = 5000,
        tow      = 5000,
    },
}

-- Notification (même système que les autres métiers)
