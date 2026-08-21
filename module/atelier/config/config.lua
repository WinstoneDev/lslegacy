Config.Atelier = {}

Config.Atelier.NotifyEvent = 'brutal_notify:SendAlert'

-- Distances / cooldowns génériques (repris du module mecanicien existant)
Config.Atelier.Actions = {
    interactionRange = 3.0,
    installRange      = 2.5,
    cooldowns = {
        diagnose = 3000,
        repair   = 5000,
        tow      = 5000,
    },
}

-- Durée de vie d'une réservation de pièces (ms) avant libération automatique
-- si l'intervention n'a pas été validée (déconnexion, crash, abandon).
Config.Atelier.PartReservationTimeoutMs = 120000

-- Durée de vie d'un verrou de composant (ms). Un mécano ne peut verrouiller
-- qu'un seul composant à la fois ; le verrou expire de lui-même en cas de
-- déconnexion pour ne jamais bloquer un composant indéfiniment.
Config.Atelier.ComponentLockTimeoutMs = 180000

-- Minijeu de réparation (repris du module mecanicien existant)
Config.Atelier.Minigame = {
    rounds        = 3,
    roundDuration = 1600,
    zoneSize      = 0.15,
    requiredHits  = 2,
}

-- Seuils de diagnostic (GTA : EngineHealth/BodyHealth vont de 0 à 1000)
Config.Atelier.Thresholds = {
    EngineDamaged = 700,
    BodyDamaged   = 700,
}

Config.Atelier.PartHandBone   = 'SKEL_R_Hand'
Config.Atelier.PartHandOffset = vector3(0.0, 0.0, 0.0)
Config.Atelier.PartHandRot    = vector3(0.0, 0.0, 0.0)
