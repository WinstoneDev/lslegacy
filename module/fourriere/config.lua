-- Ressource autonome : le global Config du framework n'existe pas dans cet état Lua, on le crée.
Config = Config or {}
Config.Fourriere = {
    -- Job autorisé à mettre un véhicule en fourrière (ox_target sur le véhicule)
    Job = 'police',

    -- Département MDT associé (pour le statut « Fourrière » du véhicule)
    Department = 'police',

    -- Réservé aux policiers EN SERVICE (statebag policeOnDuty posé par la police)
    RequireOnDuty = true,

    -- Taxe / durée par défaut (fallback si un motif n'en définit pas)
    BaseFee = 300,
    BaseDuration = 30,   -- minutes

    -- Motif personnalisé : la police saisit librement motif + tarif + durée.
    AllowCustom = true,
    MaxFee = 50000,        -- borne serveur du tarif personnalisé
    MaxDuration = 10080,   -- borne serveur de la durée (minutes) = 7 jours

    -- PNJ de la fourrière (récupération) — AJUSTER à ton mapping
    Ped = { model = 's_m_m_security_01', coords = vector3(409.38,  -1623.32, 29.27), heading = 228.0 },

    -- Point de réapparition du véhicule récupéré — AJUSTER
    Spawn = { x = 403.147247, y = -1632.342896, z = 29.279907, h = 60.0 },

    -- Blip carte
    Blip = { enabled = true, sprite = 68, color = 5, scale = 0.8, label = 'Fourrière' },

    -- Motifs : chacun définit sa TAXE ($) et sa DURÉE d'immobilisation (minutes).
    -- Le véhicule n'est récupérable qu'une fois la durée écoulée.
    Reasons = {
        { label = 'Stationnement gênant', fee = 150, duration = 15   },
        { label = 'Véhicule abandonné',   fee = 200, duration = 30   },
        { label = 'Infraction routière',  fee = 300, duration = 60   },
        { label = "Défaut d'assurance",   fee = 400, duration = 120  },
        { label = 'Saisie judiciaire',    fee = 750, duration = 1440 }, -- 24 h
        { label = 'Autre',                fee = 300, duration = 30   },
    },
}

-- Dépanneuse NPC : convoi qui vient accrocher le véhicule visé avant sa mise
-- en fourrière effective (la fourrière elle-même n'est appliquée qu'à son
-- arrivée à Config.Fourriere.Ped.coords).
Config.Towtruck = {
    Enabled = true,
    Debug   = true,

    -- Les deux modèles supportent nativement le crochet (ATTACH_VEHICLE_TO_TOW_TRUCK) ;
    -- à départager en jeu.
    Model  = 'towtruck2',
    Driver = 's_m_y_construct_01',

    MaxConcurrent = 5,     -- convois simultanés, tous véhicules confondus

    SpawnDist     = 110.0,
    ArriveDist    = 6.0,   -- rayon d'arrêt à la fourrière
    StagingDist   = 12.0,  -- point d'approche, devant le véhicule
    -- Distance de SÉCURITÉ à laquelle la marche arrière s'arrête — pas la
    -- distance de contact réelle : la native d'accroche replace ensuite le
    -- véhicule au bon point, inutile (et dangereux) de coller les pare-chocs.
    ReachDist     = 5.5,
    -- Rayon d'arrivée de la conduite AVANT le recalage exact au point de
    -- mise en ligne — doit rester petit : un grand écart ici force un
    -- téléport de correction long, qui fait « disparaître » le véhicule
    -- et peut éjecter le chauffeur.
    FinalApproach = 6.0,

    DriveSpeed   = 24.0,
    DriveStyle   = 786469,
    ReverseSpeed = 2.5,
    -- En-deçà de cette distance du véhicule à accrocher, la dépanneuse
    -- ralentit à ApproachSlowSpeed — l'arrivée au point de mise en ligne
    -- se fait alors en douceur, sans risquer de heurter le décor.
    ApproachSlowDist  = 15.0,
    ApproachSlowSpeed = 8.0,

    StuckDelay      = 4000,
    StuckSwerve     = 2,
    StuckReposition = true,

    ApproachTimeout = 45000,  -- délai max pour rejoindre le véhicule à accrocher
    ReverseTimeout  = 15000,  -- délai max pour la marche arrière d'accroche
    HookDelay       = 4000,   -- mime de l'accroche par le conducteur
    TravelTimeout   = 60000,  -- délai max pour le trajet retour vers la fourrière
    Cleanup         = 45,     -- s avant nettoyage forcé du convoi

    Hazards = true,   -- feux de détresse pendant la manœuvre d'accroche

    -- Point d'arrivée de la dépanneuse à la fourrière (emplacement de dépose,
    -- distinct du PNJ de récupération).
    Delivery = { x = 417.454956, y = -1618.312134, z = 29.279907, h = 232.44094848633 },
}
