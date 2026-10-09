-- Transporteur Avicole : docks -> usine du Nord (décharge + recharge) -> grossiste -> docks.
-- Job libre, intégré à l'agence d'intérim (voir Config.Farm.Metiers.transporteur_avicole).

Config = Config or {}
Config.Avicole = {
    Ped = {
        model   = 's_m_y_dockwork_01', -- Earl Hickey
        coords  = vector3(1196.465942, -3255.191162, 7.088623),
        heading = 0.0, -- à ajuster en jeu
    },

    Truck = {
        model  = 'benson2',
        coords = vector4(1200.131836, -3236.795654, 6.246094, 0.0), -- heading à ajuster en jeu
    },

    -- PNJ de l'usine : Robert le jour, Roberta la nuit (rotation sur l'heure en jeu, cf. LSLegacy.Weather.GetTime()).
    Usine = {
        coords   = vector3(-69.652748, 6267.771484, 31.150146),
        heading  = 36.850395202637,
        day      = { model = 's_m_y_factory_01', name = 'Cluck Norris' },
        night    = { model = 's_f_y_factory_01', name = 'Ginger Fields' },
        dayStart = 7,
        dayEnd   = 19,
    },

    Grossiste = {
        model   = 'cs_janet',
        name    = 'Janet Vance',
        coords  = vector3(2684.241699, 3515.683594, 53.290894),
        heading = 70.866142272949,
    },

    ActionDuration = 60000, -- 1 min, pour décharger (usine), charger (usine) et décharger (grossiste)
    Payment        = 250,   -- $ par livraison complète

    -- Délai de suppression du camion après un "Non" à une nouvelle livraison,
    -- une fois que le joueur s'est suffisamment éloigné.
    DespawnDistance = 20.0,
    DespawnTimeout  = 60000,

    -- Préparateur Avicole : métier intérim à part, sur le PNJ de l'usine
    -- (Cluck Norris / Ginger Fields, déjà spawné pour le transporteur).
    -- Boucle : point 1 (plumer) -> point 2 (découper) -> point 1, sans item consommé.
    Prep = {
        Point1 = vector3(-84.593407, 6231.125488, 31.082764), -- plumer
        Point2 = vector3(-99.494507, 6210.883301, 31.015381), -- découper
        ActionDuration = 10000, -- 10s par étape

        -- Gain par boucle complète (point1 + point2). 'boosted' s'applique si
        -- un Transporteur Avicole est en service au même moment (notif
        -- cosmétique "la chaîne tourne à plein régime", pas d'effet mécanique
        -- sur le transport). badCut s'applique dans les deux cas.
        Payment = {
            normal       = { { amount = 7, weight = 80 }, { amount = 6, weight = 10 }, { amount = 8, weight = 10 } },
            boosted      = { { amount = 7, weight = 60 }, { amount = 8, weight = 40 } },
            badCutChance = 0.05,
            badCutAmount = 3,
        },
    },
}
