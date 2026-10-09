-- Aéronefs IA vanilla. `category` doit correspondre à une catégorie de stand ; `military` = trafic militaire (stands business). Pas de fret : taxiways trop étroits.
-- Vitesses en km/h, taux de montée/descente en m/s. rotateSpeed adapté à l'échelle GTA (pistes de 670 m).
-- `livery` : index GetVehicleLivery -> compagnie lore (à calibrer in-game, voir commande de debug).

Config = Config or {}
Config.ATC = Config.ATC or {}

Config.ATC.Aircraft = {
    jet        = { label = 'Boeing 747',    icao = 'B744', category = 'commercial', wake = 'H', taxiSpeed = 25, rotateSpeed = 165, climbRate = 12, approachSpeed = 270, touchdownSpeed = 250, cruiseAlt = 1500 },
    miljet     = { label = 'Miljet',        icao = 'MLJT', category = 'business',   wake = 'M', military = true, taxiSpeed = 25, rotateSpeed = 150, climbRate = 15, approachSpeed = 240, touchdownSpeed = 220, cruiseAlt = 1200 },
    velum      = { label = 'TBM 800',       icao = 'TBM8', category = 'business',   wake = 'L', military = true, taxiSpeed = 20, rotateSpeed = 110, climbRate = 8,  approachSpeed = 160, touchdownSpeed = 140, cruiseAlt = 900 },
    luxor      = { label = 'Luxor',         icao = 'LUXR', category = 'business',   wake = 'M', taxiSpeed = 20, rotateSpeed = 140, climbRate = 15, approachSpeed = 230, touchdownSpeed = 210, cruiseAlt = 1200 },
    luxor2     = { label = 'Luxor Deluxe',  icao = 'LUXD', category = 'business',   wake = 'M', taxiSpeed = 20, rotateSpeed = 140, climbRate = 15, approachSpeed = 230, touchdownSpeed = 210, cruiseAlt = 1200 },
    nimbus     = { label = 'Nimbus',        icao = 'NMBS', category = 'business',   wake = 'M', taxiSpeed = 20, rotateSpeed = 140, climbRate = 15, approachSpeed = 220, touchdownSpeed = 200, cruiseAlt = 1200 },
    shamal     = { label = 'Shamal',        icao = 'SHML', category = 'business',   wake = 'M', taxiSpeed = 20, rotateSpeed = 135, climbRate = 14, approachSpeed = 210, touchdownSpeed = 190, cruiseAlt = 1200 },

    -- Hélicoptères : décollage/atterrissage vertical direct au stand H1-H3, pas de roulage taxiway
    -- (rotateSpeed très bas = envol quasi immédiat, touchdownSpeed bas = roulis d'atterrissage court).
    supervolito  = { label = 'SuperVolito',        icao = 'EC45', category = 'heli', wake = 'L', heli = true, taxiSpeed = 15, rotateSpeed = 8, touchdownSpeed = 20, hoverAlt = 6, climbRate = 6, approachSpeed = 120, cruiseAlt = 600 },
    supervolito2 = { label = 'SuperVolito Carbon', icao = 'EC45', category = 'heli', wake = 'L', heli = true, taxiSpeed = 15, rotateSpeed = 8, touchdownSpeed = 20, hoverAlt = 6, climbRate = 6, approachSpeed = 120, cruiseAlt = 600 },
    swift        = { label = 'Swift',              icao = 'A109', category = 'heli', wake = 'L', heli = true, taxiSpeed = 15, rotateSpeed = 8, touchdownSpeed = 20, hoverAlt = 6, climbRate = 7, approachSpeed = 130, cruiseAlt = 600 },
    swift2       = { label = 'Swift Deluxe',       icao = 'A109', category = 'heli', wake = 'L', heli = true, taxiSpeed = 15, rotateSpeed = 8, touchdownSpeed = 20, hoverAlt = 6, climbRate = 7, approachSpeed = 130, cruiseAlt = 600 },
    volatus      = { label = 'Volatus',            icao = 'H160', category = 'heli', wake = 'L', heli = true, taxiSpeed = 15, rotateSpeed = 8, touchdownSpeed = 20, hoverAlt = 6, climbRate = 7, approachSpeed = 140, cruiseAlt = 600 },
}

-- Compagnies lore : indicatif radio + préfixe callsign. `liveries` = { modèle = { index livrée, ... } }, à calibrer.
Config.ATC.Airlines = {
    { code = 'FLY', name = 'FlyUS',           radio = 'FlyUS',   liveries = { jet = {} } },
    { code = 'ADS', name = 'Adios Airlines',  radio = 'Adios',   liveries = { jet = {} } },
    { code = 'AHR', name = 'Air Herler',      radio = 'Herler',  liveries = { jet = {} } },
    { code = 'CAI', name = 'Caipira Airways', radio = 'Caipira', liveries = { jet = {} } },
}
