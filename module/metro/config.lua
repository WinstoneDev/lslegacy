-- Approche adaptée de XNL-FiveM-Trains-U3 (github.com/VenomXNL) : pas de
-- rame pilotée par CreateMissionTrain (limitée à 1 wagon sans crasher),
-- on laisse le moteur du jeu spawner les rames ambiantes natives (2
-- wagons metrotrain) via SetRandomTrains + SetTrainTrackSpawnFrequency.
-- On perd le contrôle fin (spawn à la demande, arrêt scripté) en échange.

Config.Metro = {}

-- Tarif du ticket (débité via le payment menu)
Config.Metro.Price = 2


-- Piste 3 = métro. Ne pas toucher à la piste 0 (fret).
-- client/player/spawn.lua désactive cette piste et SetRandomTrains à
-- chaque respawn : le module la réactive donc lui-même.
Config.Metro.TrackId = 3
Config.Metro.SpawnFrequency = 30000 -- ms — ne pas descendre trop bas (cf. avertissement upstream)

Config.Metro.TicketMachineModel   = 'prop_train_ticket_02'
-- Coordonnées relevées à hauteur du joueur : on redescend le prop au sol.
Config.Metro.TicketMachineZOffset = -1.0
Config.Metro.PropRenderDistance   = 50.0
Config.Metro.ZoneDistance         = 2.0

Config.Metro.BlipSprite = 79
Config.Metro.BlipColor  = 3
Config.Metro.BlipScale  = 0.8

Config.Metro.Debug = true

-- Stations, uniquement pour les blips + les bornes de tickets : le
-- moteur gère seul le trajet et les arrêts natifs.
Config.Metro.Stations = {
    {
        id = 'lsia_terminals', label = 'LSIA Terminals',
        coords = vector3(-1083.217529, -2715.230713, -7.419067),
    },
    {
        id = 'lsia_parking', label = 'LSIA Parking',
        coords = vector3(-883.450562, -2319.415283, -11.749512),
    },
    {
        id = 'puerto_del_sol', label = 'Puerto del Sol',
        coords = vector3(-538.945068, -1278.962646, 27.325317),
        ticketMachine = {
            coords = vector3(-532.760437, -1265.169189, 26.887207),
            heading = 335.90551757812,
        },
    },
    {
        id = 'strawberry', label = 'Strawberry',
        coords = vector3(271.173615, -1204.193359, 38.901123),
        ticketMachine = {
            coords = vector3(274.589020, -1204.232910, 38.884277),
            heading = 265.039367675781,
        },
    },
    -- Pillbox North — FERMÉE, aucun arrêt voyageurs.
    {
        id = 'burton', label = 'Burton',
        coords = vector3(-294.619781, -312.778015, 10.054199),
    },
    {
        id = 'portola', label = 'Portola',
        coords = vector3(-831.468140, -146.821976, 19.945068),
    },
    {
        id = 'del_perro', label = 'Del Perro',
        coords = vector3(-1342.813232, -479.868134, 15.041748),
    },
    {
        id = 'little_seoul', label = 'Little Seoul',
        coords = vector3(-483.270325, -673.173645, 11.806641),
    },
    {
        id = 'pillbox_south', label = 'Pillbox South',
        coords = vector3(-214.681320, -1037.208740, 30.560425),
        ticketMachine = {
            coords = vector3(-219.929672, -1055.960449, 30.139160),
            heading = 168.6614074707,
        },
    },
    {
        id = 'davis', label = 'Davis',
        coords = vector3(111.850548, -1722.804443, 30.526733),
        ticketMachine = {
            coords = vector3(132.052750, -1741.687866, 30.105469),
            heading = 228.188972473145,
        },
    },
}
