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
