-- Module ATC (contrôle aérien LSIA) : position unique SOL+LOC, un seul contrôleur.
-- Les données géographiques sont dans lsia_*.lua ; ici uniquement les réglages généraux.

Config = Config or {}
Config.ATC = {
    Enabled = true,

    Job = 'atc',
    -- Grade minimum pour prendre la position (0 = Stagiaire).
    MinGrade = 0,

    -- Code OACI fictif utilisé dans les strips/METAR.
    Icao = 'LSIA',

    -- Poste de la tour : caméra du contrôleur (vue radar). TAB bascule vers camExterior/headingExterior
    -- (fenêtre de la tour donnant sur le tarmac) puis masque tout le NUI pour voir dehors sans obstruction.
    Tower = {
        cam = vector3(-1299.665894, -2631.019775, 81.817627),
        heading = 150.23622131348,
        camExterior = vector3(-1290.329712, -2634.514404, 94.876221),
        headingExterior = 164.4094543457,
        fov = 50.0,
        -- Rotation caméra : clic gauche maintenu + souris. Sensibilité volontairement faible.
        mouseSensitivity = 0.08,
        pitchMin = -60.0,
        pitchMax = 15.0,
    },

    -- Marqueur d'entrée en tour : [E] dans le cercle -> caméra tour + interface.
    Entry = {
        coords = vector3(-984.408813, -2640.896729, 13.946533),
        heading = 331.65353393555,
        marker = { type = 1, size = vector3(1.5, 1.5, 0.5), color = { r = 40, g = 120, b = 255, a = 140 } },
        -- Distance d'interaction (m) autour du centre du marqueur.
        radius = 1.5,
        drawDistance = 25.0,
    },

    -- Rayon (m) autour de la tour où les avions IA existent réellement.
    -- Au-delà : spawn des arrivées / despawn des départs.
    SimulationRadius = 10000.0,

    -- Rayon (m) autour de la tour où les props de servitude vanilla sont masqués.
    PropHideRadius = 8000.0,

    -- Météo : METAR régénéré à cet intervalle réel (minutes) depuis la météo LS
    -- (module weather / codem-dynamicweather). Le vent est tiré pour rester
    -- cohérent avec l'orientation des pistes.
    Metar = {
        IntervalMinutes = 30,
        -- Zone codem-dynamicweather utilisée pour LSIA (cf. Config.Weather.Zones).
        WeatherAreaId = 4,
    },

    -- Horloge des strips : heure GTA in-game.
    UseGameTime = true,

    -- Spawn automatique dynamique (en plus du spawn manuel), activable via la NUI (curseur).
    -- Intervalle moyen 90s avec dispersion -> ~10 mouvements / 15 min quand actif.
    DynamicSpawn = {
        AverageIntervalSeconds = 90,
        JitterSeconds = 45,
        MaxConcurrent = 8,
    },

    -- Espacement entre arrivées consécutives sur une même piste : chaque arrivée déjà en approche/
    -- finale/atterrissage décale la suivante de cette distance (m) le long de l'axe, pour éviter deux
    -- avions superposés au point d'entrée à 10 NM. Au-delà de MaxQueue, la piste refuse une arrivée de plus.
    ArrivalSpacing = 9260.0, -- 5 NM
    MaxArrivalsPerRunway = 3,

    -- Langue radio : anglais, phraséologie ENAC.
    RadioLanguage = 'en',

    -- Outil de relevé (/atcsurvey, staff niveau 2) : fichier de sortie relatif à la ressource.
    Survey = {
        File = 'module/atc/data/survey.json',
        MaxPoints = 3000,
        DrawDistance = 200.0,
        Types = {
            { id = 'taxiway',      label = 'Nœud de taxiway' },
            { id = 'holding',      label = "Point d'attente" },
            { id = 'exit',         label = 'Sortie / entrée de piste' },
            { id = 'intersection', label = 'Intersection' },
            { id = 'stand',        label = 'Stand' },
            { id = 'route',        label = 'Point de trajectoire (air)' },
            { id = 'free',         label = 'Point libre' },
        },
    },

    -- Modèles d'aéronefs vanilla que le jeu ne doit plus faire apparaître
    -- (population ambiante + générateurs de véhicules des ymaps). Nos propres
    -- spawns scriptés ne sont pas concernés par la suppression.
    SuppressedAmbientModels = {
        'jet', 'cargoplane', 'luxor', 'luxor2', 'miljet', 'nimbus', 'shamal', 'velum', 'velum2',
        'titan', 'mammatus', 'dodo', 'duster', 'cuban800', 'vestra', 'besra', 'lazer', 'hydra',
        'supervolito', 'supervolito2', 'swift', 'swift2', 'volatus', 'maverick', 'frogger', 'buzzard2',
    },

    -- Zones ponctuelles où le spawn d'avions ambiants/vanilla est bloqué (hangars,
    -- pistes isolées hors LSIA) — indépendant de PropHideRadius/SuppressedAmbientModels
    -- (props.lua désactivé) : balayage actif par no_spawn_zones.lua.
    NoSpawnZones = {
        { label = 'Hangar (McKenzie Field)', coords = vector3(-2128.496582, 3265.542969, 35.177246), radius = 100.0 },
    },

    -- Props de servitude aéroport vanilla masqués dans PropHideRadius (ymap = model hide,
    -- objets dynamiques = suppression par balayage périodique).
    HiddenProps = {
        'prop_air_bagloader', 'prop_air_bagloader2', 'prop_air_bagloader2_cr',
        'prop_air_trailer_1a', 'prop_air_trailer_1b', 'prop_air_trailer_1c',
        'prop_air_trailer_2a', 'prop_air_trailer_2b',
        'prop_air_trailer_3a', 'prop_air_trailer_3b',
        'prop_air_trailer_4a', 'prop_air_trailer_4b', 'prop_air_trailer_4c',
        'prop_air_cargo_01a', 'prop_air_cargo_01b', 'prop_air_cargo_01c',
        'prop_air_cargo_02b', 'prop_air_cargo_03a',
        'prop_air_cargo_04a', 'prop_air_cargo_04b', 'prop_air_cargo_04c',
        'prop_air_cargoloader_01',
        'prop_air_stair_01', 'prop_air_stair_02', 'prop_air_stair_03',
        'prop_air_stair_04a_cr', 'prop_air_stair_04b', 'prop_air_stair_04b_cr',
        'prop_air_towbar_01', 'prop_air_towbar_02', 'prop_air_towbar_03',
        'prop_air_generator_03', 'sf_prop_air_compressor_01a', 'imp_prop_air_compressor_01a',
        'prop_air_fireexting', 'prop_air_gasbogey_01', 'prop_air_propeller01',
        'prop_air_watertank3', 'prop_air_woodsteps', 'prop_air_luggtrolley',
        'prop_air_chock_01', 'prop_air_chock_03', 'prop_air_chock_04',
        'prop_air_fueltrail1', 'prop_air_fueltrail2', 'prop_tanktrailer_01a',
        'prop_air_blastfence_02', 'prop_aircon_m_03',
    },
}
