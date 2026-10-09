Config.Atelier = {}


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

-- Pose "portage à deux mains, paumes vers le ciel" (même anim/bone/placement
-- que l'emote "Boîte" déjà calibrée dans module/emotes/data/emotes_props.lua)
-- plutôt qu'un simple attach à la main : sinon la pièce tenue reste figée,
-- flotte contre le buste sans pose de portage, quelle que soit sa taille.
Config.Atelier.PartHandAnimDict  = 'anim@heists@box_carry@'
Config.Atelier.PartHandAnimClip  = 'idle'
Config.Atelier.PartHandBone      = 'SKEL_R_Hand'
Config.Atelier.PartHandOffset    = vector3(0.025, 0.08, 0.255)
Config.Atelier.PartHandRot       = vector3(-145.0, 290.0, 0.0)

-- Usure des pièces mécaniques non observables nativement (freins, transmission,
-- suspension, embrayage, radiateur) : dégradée uniquement par la conduite réelle
-- (moteur allumé, joueur au volant), jamais par le simple écoulement du temps
-- calendaire — cf. client/interventions.lua (rapport) et server/vehicles.lua
-- (application). ~2.5%/h vise une visite chez le mécano toutes les ~40h de
-- conduite effective par pièce (à ajuster selon le rythme de jeu constaté).
Config.Atelier.Wear = {
    componentsPerHour     = 2.5,
    reportIntervalSeconds = 300,
}
