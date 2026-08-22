-- Pompe publique sans job : interaction sur un prop (ox_target) qui tire sur le stock réel de la station la plus proche (interim_stations, alimentée par le job intérimaire).

Config = Config or {}
Config.Pompe = {

    PricePerLiter = 1.8, -- $ / L, identique dans toutes les stations

    -- Durée d'un plein COMPLET (0 -> 100 % du réservoir), en ms. Un plein
    -- partiel est proportionnel (ex : remplir la moitié du réservoir prend
    -- moitié moins de temps) — voir client/main.lua.
    FillDuration = 30000,

    -- Props de pompe à essence vanilla sur lesquels l'interaction ox_target
    -- est attachée (n'importe quelle instance présente sur la map, pas
    -- besoin de coordonnées).
    PumpModels = {
        'prop_gas_pump_1a',
        'prop_gas_pump_1b',
        'prop_gas_pump_1c',
        'prop_gas_pump_1d',
        'prop_gas_pump_old2',
        'prop_gas_pump_old3',
        'prop_vintage_pump',
    },

    -- Anim + prop du pistolet à essence, repris tels quels du script public
    -- ox_fuel (overextended/ox_fuel, client/fuel.lua) — un vrai geste de
    -- ravitaillement, contrairement au jerrican utilisé pour le job intérimaire.
    Anim = {
        dict = 'timetable@gardener@filling_can',
        clip = 'gar_ig_5_filling_can',
        prop = 'prop_cs_fuel_nozle',
        bone = 18905,
        offset = { x = 0.1, y = 0.02, z = 0.02 },
        rotation = { x = 90.0, y = 40.0, z = 170.0 },
        rotOrder = 1,
    },

    VehicleMaxDistance = 3.0,  -- distance max au dernier véhicule utilisé (pattern ox_fuel) pour autoriser le plein
    StationSearchRadius = 60.0, -- rayon d'association pompe -> station (Config.Interim.Stations) la plus proche

    Actions = {
        interactionRange = 5.0,
    },
}
