-- Job libre : camion-citerne pour ravitailler les stations essence. Portée v1 : le niveau des stations n'est pas encore consommé par les véhicules joueurs.

Config = Config or {}
Config.Interim = {
    -- Event de notification (framework)
    NotifyEvent = 'brutal_notify:SendAlert',

    -- PNJ chantier (prise/fin de service) — pos 2
    Ped = {
        model   = 's_m_y_construct_01',
        coords  = vector3(136.720886, -2472.751709, 5.993408),
        heading = 238.11,
    },

    -- Camion-citerne — pos 1
    Truck = {
        model   = 'phantom',
        coords  = vector4(190.061539, -2508.712158, 5.993408, 85.039367675781)
    },

    -- Remorque-citerne essence — pos 3
    Trailer = {
        model   = 'tanker',
        coords  = vector4(202.087921, -2497.424072, 8.857910, 175.74803161621),
    },

    -- Point de remplissage de la citerne du camion — pos 4
    TankPoint = {
        coords  = vector4(1432.628540, -2295.600098, 66.804443, 263.6220703125),
        blip    = { sprite = 361, color = 5, scale = 0.8, label = 'Citerne essence' },
        -- Même anim que la station (weapon@w_sp_jerrycan/fire) mais SANS le
        -- prop jerrican en main : joué sur place, là où le joueur a cliqué.
        anim = {
            dict = 'weapon@w_sp_jerrycan',
            clip = 'fire',
        },
    },

    -- Animation + prop "pistolet à essence". Aucune anim dédiée n'existe dans
    -- le repo : on part de l'asset vanilla le plus proche thématiquement
    -- (tenir/distribuer un liquide) — À VALIDER VISUELLEMENT, remplacer si le
    -- rendu ne convient pas.
    Anim = {
        dict = 'weapon@w_sp_jerrycan',
        clip = 'fire',
        prop = 'prop_jerrycan_01a',
        boneName = 'SKEL_R_Hand',
        offset = { x = 0.13, y = 0.06, z = 0.03 },
        rotation = { x = 0.0, y = 0.0, z = 0.0 },
        duration = 4000, -- ms — valeur de repli, non utilisée directement (durées aléatoires ci-dessous)
    },

    -- Remplissage de la citerne (pos4) : durée aléatoire entre les deux
    -- bornes, en ms, pour éviter un plein instantané.
    TankFillDuration = {
        min = 60000,
        max = 90000,
    },

    -- Remplissage d'une station essence : durée aléatoire entre les deux
    -- bornes, en ms.
    StationFillDuration = {
        min = 45000,
        max = 60000,
    },

    -- Stations essence à ravitailler. Liste de DÉPART volontairement courte
    -- (coordonnées vanilla GTA V dont je suis raisonnablement sûr) —
    -- À VÉRIFIER/ÉTENDRE EN JEU avant d'ajouter les ~17 stations du monde.
    Stations = {
        { id = 'grapeseed',  label = 'Grapeseed',   coords = vector3(1699.292358, 4944.369141, 42.287964),  heading = 113 },
        { id = 'freeway',     label = 'Freeway',      coords = vector3(2654.940674, 3277.028564, 55.228516),  heading = 334  },
        { id = 'la_mesa',       label = 'La Mesa',        coords = vector3(808.786804, -1043.142822, 26.550171), heading = 2.83   },
        { id = 'strawberry',         label = 'Strawberry',          coords = vector3(282.171417, -1247.182373, 29.195557), heading = 269 },
        { id = 'little_seoul',      label = 'Little Seoul',       coords = vector3(-727.832947, -914.861511, 19.001465), heading = 0.0  },
        { id = 'davis', label = 'Davis Avenue', coords = vector3(180.342865, -1546.813232, 29.14502), heading = 0.0 },
        { id = 'paleto_market', label = 'Paleto Market', coords = vector3(200.980225, 6617.841797, 31.67248), heading = 0.0 },
        { id = 'mont_chiliad', label = 'Mont Chiliad', coords = vector3(1686.290161, 6438.487793, 32.380249), heading = 0.0 },
        { id = 'sandy_shores', label = 'Sandy Shores', coords = vector3(2008.720825, 3793.964844, 32.177979), heading = 0.0 },
        { id = 'harmony_cafe', label = 'Harmony Cafe', coords = vector3(1056.527466, 2656.523193, 39.541382), heading = 0.0 },
        { id = 'harmony_garage', label = 'Harmony Garage', coords = vector3(1207.265991, 2640.118652, 37.805908), heading = 0.0 },
        { id = 'vinewood', label = 'Vinewood', coords = vector3(648.250549, 277.885712, 103.132568), heading = 0.0 },
        { id = 'mirror_park', label = 'Mirror Park', coords = vector3(1153.318726, -340.272522, 67.697388), heading = 0.0 },
        { id = 'murrieta_heights', label = 'Murrieta Heights', coords = vector3(1200.092285, -1383.191162, 35.210938), heading = 0.0 },
        { id = 'grove_street', label = 'Groove Street', coords = vector3(-67.345055, -1748.874756, 29.448364), heading = 0.0 },
        { id = 'la_puerta', label = 'La Puerta', coords = vector3(-356.795593, -1497.652710, 30.172852), heading = 0.0 },
        { id = 'little_seoul_2', label = 'Little Seoul 2', coords = vector3(-512.571411, -1216.641724, 18.445435), heading = 0.0 },
        { id = 'davis_2', label = 'Davis Avenue 2', coords = vector3(180.342865, -1546.813232, 29.14502), heading = 0.0 },
        { id = 'morringwood', label = 'Morringwood', coords = vector3(-1414.654907, -281.670319, 46.298218), heading = 0.0 },
        { id = 'pacific_bluffs', label = 'Pacific Bluffs', coords = vector3(-2062.786865, -304.997803, 13.137695), heading = 0.0 },
        { id = 'monts_tataviam', label = 'Monts Tataviam', coords = vector3(2567.287842, 363.62, 108.45), heading = 0.0 },
        { id = 'richman_glen', label = 'Richman Glen', coords = vector3(-1820.400024, 773.182434, 136.697388), heading = 0.0 },
        { id = 'lago_zancudo', label = 'Lago Zancudo', coords = vector3(-2543.749512, 2346.355957, 33.05419), heading = 0.0 },
        { id = 'harmony', label = 'Harmony', coords = vector3(244.905502, 2598.342773, 45.118652), heading = 0.0 },
        { id = 'Route 68', label = 'Route 68', coords = vector3(65.010986, 2784.276855, 57.874023), heading = 0.0 },
        { id = 'sandy_shores_airport', label = 'Sandy Shores Airport', coords = vector3(1765.714233, 3340.404297, 41.17578), heading = 0.0 },
        { id = 'paleto_bay', label = 'Paleto Bay', coords = vector3(-99.336266, 6399.178223, 31.436646), heading = 0.0 },
    },

    -- Économie — cible ~400 $/h (voir plan, à recalibrer après test en jeu
    -- réel des nouvelles durées de remplissage). Litres réels : la citerne
    -- transfère exactement ce qu'il faut à la station pour atteindre son
    -- plafond (stationCapacity - niveau actuel), plafonné par ce qu'il reste
    -- dans la citerne.
    Economy = {
        trailerCapacity    = 15000, -- litres, capacité max de la citerne du camion
        stationCapacity    = 5000, -- litres, capacité max d'une station
        pricePerStation    = 90,  -- paiement par station amenée à sa capacité max
        stationCooldownSec = 120,  
    },

    Actions = {
        interactionRange = 4.0,
    },

    -- Rayon (mètres) autour de chaque station essence référencée dans lequel
    -- le spawn de véhicules/pnj ambiants est bloqué (trafic ambiant, pnj de
    -- scénario) — évite qu'une voiture ou un pnj apparaisse sur la zone
    -- d'interaction et gêne le remplissage.
    StationNoSpawnRadius = 10.0,
}
