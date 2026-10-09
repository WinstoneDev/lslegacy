-- ═══════════════════════════════════════════════════════════════════
--  LOCATION DE VÉHICULES — Configuration
--  Agence PNJ ouverte à tous — Framework : LSLegacy (custom)
-- ═══════════════════════════════════════════════════════════════════

Config.Location = {}

Config.Location.Agency = {
    Ped = {
        model   = 'a_m_y_business_01',
        coords  = vector3(-809.551636, -2415.072510, 14.738403),
        heading = 300.47244262695,
    },
    Blip = {
        coords = vector3(-809.551636, -2415.072510, 14.738403),
        sprite = 225,
        color  = 5,
        scale  = 0.8,
        label  = 'Location de véhicules',
        short  = true,
    },
    -- Distance max à l'agence pour pouvoir rendre un véhicule loué.
    ReturnRadius = 20.0,
}

-- Point de livraison du véhicule loué. Si l'emplacement est déjà occupé
-- (véhicule garé dessus), on retombe sur un point décalé en X pour éviter
-- un spawn imbriqué (véhicules fusionnés, portière bloquée, etc.).
Config.Location.Spawn = {
    coords    = vector4(-817.859314, -2406.250488, 14.569946, 300.47244262695),
    altOffsetX = -6.0,
}

-- Catalogue : model = spawn name GTA, pricePerHour = prix en $/heure.
Config.Location.Vehicles = {
    { model = 'faggio', label = 'Pegassi Faggio', pricePerHour = 30 },
    { model = 'panto',  label = 'Benefactor Panto', pricePerHour = 50 },
}

-- Durée max louable en une fois (heures).
Config.Location.MaxHours = 48

-- Moyens de paiement autorisés à l'agence.
Config.Location.Payment = {
    cash = true,
    bank = true,
}

-- Comportement à l'expiration du contrat pendant que le véhicule roule :
-- la vitesse max diminue progressivement jusqu'à 0 sur cette durée (ms).
Config.Location.Decay = {
    decayDurationMs = 15000,
}
