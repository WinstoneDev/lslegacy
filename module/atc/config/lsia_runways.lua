-- Pistes LSIA. Un QFU = un sens d'utilisation d'une piste physique.
-- `threshold` : seuil (début de piste dans ce sens), `heading` : cap GTA (0 = nord, sens anti-horaire),
-- `bearing` : cap compas réel (0 = nord, sens horaire) = (360 - heading) % 360.
-- Longueurs mesurées entre seuils : 12R/30L 679 m, 12L/30R 674 m, 03/21 549 m. Écartement des parallèles : 168 m.

Config = Config or {}
Config.ATC = Config.ATC or {}

-- Piste physique -> ses deux QFU. `category` : trafic autorisé.
Config.ATC.Runways = {
    ['12R/30L'] = { qfus = { '12R', '30L' }, width = 45.0, category = 'commercial' },
    ['12L/30R'] = { qfus = { '12L', '30R' }, width = 45.0, category = 'commercial' },
    ['03/21']   = { qfus = { '03', '21' },   width = 30.0, category = 'business' },
}

-- `role` : usage préférentiel dans la configuration en service.
--   landing  = atterrissages (commercial)
--   takeoff  = décollages (commercial) ; les hélicoptères y translatent puis décollent
--   mixed    = décollage et atterrissage (aviation d'affaires)
Config.ATC.Qfu = {
    ['12R'] = { runway = '12R/30L', threshold = vector3(-1625.327515, -2976.633057, 13.929688), heading = 240.94488525391, bearing = 120, role = 'landing', opposite = '30L' },
    ['30L'] = { runway = '12R/30L', threshold = vector3(-1036.918701, -3315.230713, 13.929688), heading = 62.362205505371,  bearing = 300, role = 'landing', opposite = '12R' },
    ['12L'] = { runway = '12L/30R', threshold = vector3(-1543.516479, -2829.428467, 13.946533), heading = 240.94488525391, bearing = 120, role = 'takeoff', opposite = '30R' },
    ['30R'] = { runway = '12L/30R', threshold = vector3(-960.065918, -3166.061523, 13.929688),  heading = 62.362205505371,  bearing = 300, role = 'takeoff', opposite = '12L' },
    ['03']  = { runway = '03/21',   threshold = vector3(-1643.973633, -2743.331787, 13.963379), heading = 331.65353393555, bearing = 30,  role = 'mixed',   opposite = '21' },
    ['21']  = { runway = '03/21',   threshold = vector3(-1369.054932, -2267.604492, 13.963379), heading = 147.40158081055, bearing = 210, role = 'mixed',   opposite = '03' },
}

-- Nœud d'alignement (graphe) par QFU : cible des itinéraires de départ.
Config.ATC.Qfu['12L'].lineupNode = 'RWY_12L_END'
Config.ATC.Qfu['30R'].lineupNode = 'RWY_30R_END'
Config.ATC.Qfu['12R'].lineupNode = 'RWY_12R_END'
Config.ATC.Qfu['30L'].lineupNode = 'RWY_30L_END'
Config.ATC.Qfu['03'].lineupNode  = 'RWY_03_END'
Config.ATC.Qfu['21'].lineupNode  = 'HP_A21_21'

-- Configurations en service : le contrôleur en choisit une selon le vent du METAR.
-- Une config = un sens pour le doublet commercial + un sens pour la piste affaires.
Config.ATC.RunwayConfigs = {
    -- Vent de secteur est/sud-est (≈ 090-150) : atterrissage 12R, décollage 12L, affaires 03 ou 21 selon composante.
    { id = 'EAST_03',  landing = '12R', takeoff = '12L', business = '03', helicopters = '12L' },
    { id = 'EAST_21',  landing = '12R', takeoff = '12L', business = '21', helicopters = '12L' },
    -- Vent de secteur ouest/nord-ouest (≈ 270-330) : atterrissage 30L, décollage 30R.
    { id = 'WEST_03',  landing = '30L', takeoff = '30R', business = '03', helicopters = '30R' },
    { id = 'WEST_21',  landing = '30L', takeoff = '30R', business = '21', helicopters = '30R' },
}

-- Vent : tiré autour des axes de piste pour que l'aéroport reste "face au vent".
-- Chaque entrée = direction moyenne (compas) + dispersion ; le poids règle la fréquence.
Config.ATC.WindSectors = {
    { mean = 120, spread = 40, weight = 5 }, -- config EAST
    { mean = 300, spread = 40, weight = 5 }, -- config WEST
    { mean = 30,  spread = 25, weight = 1 }, -- vent dans l'axe 03 (rare)
    { mean = 210, spread = 25, weight = 1 }, -- vent dans l'axe 21 (rare)
}
