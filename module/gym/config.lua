-- Salle de sport : machines communes (force/endurance), déclinées en salle
-- privée (commissariat, gratuite, réservée police) et salle publique
-- (abonnement payant). Dict/clip vérifiés dans module/emotes/data (gym*,
-- pushup, chinup) ou repris de amb@world_human_jog_standing (confirmé
-- existant côté emotes pour le tapis de course).

Config = Config or {}
Config.Gym = {

    RepDuration   = 10000, -- ms par répétition d'animation
    InteractRange = 2.0,

    -- Gain d'XP : réutilise lslegacy:skillsAddXP tel quel (cooldown 45s /
    -- cap 25 par session déjà gérés côté serveur, aucune modif du système).

    -- flag = 1 (REPEAT uniquement) sur toutes les anims dict/clip : le flag
    -- par défaut d'ox_lib (49 = REPEAT + UPPERBODY + ENABLE_PLAYER_CONTROL)
    -- ne joue que le haut du corps et laisse le joueur marcher pendant
    -- l'anim — on veut le corps entier, joueur figé sur place (disable.move).
    MachineTypes = {
        tapis = {
            label = 'Tapis de course', skill = 'endurance',
            anim = { dict = 'amb@world_human_jog_standing@male@idle_a', clip = 'idle_a', flag = 1 },
        },
        traction = {
            label = 'Traction', skill = 'force',
            -- Anim brute plutôt que le scénario PROP_HUMAN_MUSCLE_CHIN_UPS :
            -- ce dernier fait "voler" le ped (le système de scénario le
            -- replace/élève automatiquement pour caler sur un vrai prop de
            -- barre de traction, absent ici). TaskPlayAnim joue le clip tel
            -- quel, sans ce recalage.
            anim = { dict = 'amb@prop_human_muscle_chin_ups@male@base', clip = 'base', flag = 1 },
        },
        biceps = {
            label = 'Biceps', skill = 'force',
            anim = { dict = 'amb@world_human_muscle_free_weights@male@barbell@base', clip = 'base', flag = 1 },
            prop = { model = 'prop_curl_bar_01', bone = 28422, offset = vector3(0.0, 0.0, 0.0), rotation = vector3(0.0, 0.0, 0.0) },
        },
        abdo = {
            label = 'Abdominaux', skill = 'endurance',
            anim = { dict = 'mouse@situp', clip = 'situp_clip', flag = 1 },
        },
        crunch = {
            label = 'Crunch', skill = 'endurance',
            anim = { dict = 'mouse@byc_crunch', clip = 'byc_crunch_clip', flag = 1 },
        },
        jumping_jack = {
            label = 'Jumping Jack', skill = 'endurance',
            anim = { dict = 'mouse@jump_jack', clip = 'jump_jack_clip', flag = 1 },
        },
        squat = {
            label = 'Squats', skill = 'endurance',
            anim = { dict = 'mouse@air_squat', clip = 'air_squat_clip', flag = 1 },
        },
        gainage = {
            label = 'Gainage', skill = 'endurance',
            anim = { dict = 'frabi@femalepose@solo@firstsport', clip = 'fem_pose_sport_004', flag = 1 },
        },
        pompe = {
            label = 'Pompes', skill = 'force',
            anim = { dict = 'amb@world_human_push_ups@male@idle_a', clip = 'idle_d', flag = 1 },
        },
    },

    -- ── Salle privée (commissariat) : gratuite, réservée forces de l'ordre ──
    Police = {
        Job      = Config.Police.Job,
        Machines = {
            { type = 'tapis', coords = vector3(-391.424164, -326.162628, 42.203613), heading = 342.99212646484 },
            { type = 'tapis', coords = vector3(-390.276917, -327.032959, 42.203613), heading = 337.32284545898 },
            { type = 'tapis', coords = vector3(-386.465942, -329.657135, 42.203613), heading = 340.15747070312 },
            { type = 'tapis', coords = vector3(-385.384613, -330.632965, 42.203613), heading = 337.32284545898 },
            { type = 'tapis', coords = vector3(-384.250549, -331.424164, 42.203613), heading = 340.15747070312 },
            { type = 'tapis', coords = vector3(-382.272522, -332.729675, 42.220459), heading = 340.15747070312 },

            { type = 'traction', coords = vector3(-393.824158, -337.239563, 43.585327), heading = 255.11810302734 },

            { type = 'biceps', coords = vector3(-379.437378, -337.767029, 43.585327), heading = 249.44882202148 },
            { type = 'biceps', coords = vector3(-380.782410, -341.367035, 43.585327), heading = 249.44882202148 },

            { type = 'abdo', coords = vector3(-388.048340, -335.142853, 43.585327), heading = 164.4094543457 },

            { type = 'crunch', coords = vector3(-384.659332, -339.969238, 43.585327), heading = 342.99212646484 },

            { type = 'jumping_jack', coords = vector3(-388.074738, -339.204407, 43.585327), heading = 337.32284545898 },

            { type = 'squat', coords = vector3(-381.507690, -337.305481, 43.585327), heading = 249.44882202148 },
            { type = 'squat', coords = vector3(-382.654938, -340.865936, 43.585327), heading = 252.28346252441 },

            { type = 'gainage', coords = vector3(-385.542847, -333.323090, 42.068848), heading = 65.19685363769 },

            { type = 'pompe', coords = vector3(-391.938477, -333.771423, 43.585327), heading = 155.90551757812 },
        },
    },

    -- ── Salle publique : abonnement payant ──────────────────────────────
    Public = {
        Npc = {
            model   = 'u_m_y_babyd',
            coords  = vector3(-1195.160400, -1577.446167, 4.594849),
            heading = 113.38582611084,
        },
        Subscription = {
            Price       = 200,
            DurationDays = 7,
        },
        Machines = {
            { type = 'traction', coords = vector3(-1200.013184, -1571.182373, 4.594849), heading = 215.43307495117 },
            { type = 'traction', coords = vector3(-1204.760498, -1564.351685, 4.594849), heading = 34.015747070312 },

            { type = 'abdo', coords = vector3(-1201.226318, -1566.540649, 4.999268), heading = 36.850395202637 },
            { type = 'abdo', coords = vector3(-1203.349487, -1567.859375, 4.999268), heading = 31.181102752686 },
            { type = 'abdo', coords = vector3(-1198.984619, -1565.076904, 5.016113), heading = 303.30709838867 },

            { type = 'crunch', coords = vector3(-1201.226318, -1566.540649, 4.999268), heading = 36.850395202637 },
            { type = 'crunch', coords = vector3(-1203.349487, -1567.859375, 4.999268), heading = 31.181102752686 },
            { type = 'crunch', coords = vector3(-1198.984619, -1565.076904, 5.016113), heading = 303.30709838867 },

            { type = 'jumping_jack', coords = vector3(-1200.290161, -1577.024170, 4.594849), heading = 31.181102752686 },
            { type = 'jumping_jack', coords = vector3(-1197.731812, -1571.208740, 4.611694), heading = 28.34645652771 },

            { type = 'squat', coords = vector3(-1199.353882, -1563.362671, 4.611694), heading = 124.72441101074 },
            { type = 'squat', coords = vector3(-1204.325317, -1557.072510, 4.611694), heading = 167.24409484863 },

            { type = 'gainage', coords = vector3(-1193.578003, -1570.575806, 4.611694), heading = 34.015747070312 },

            { type = 'pompe', coords = vector3(-1200.857178, -1570.193359, 4.594849), heading = 303.30709838867 },

            { type = 'biceps', coords = vector3(-1210.694458, -1561.252808, 4.594849), heading = 255.11810302734 },
            { type = 'biceps', coords = vector3(-1202.940674, -1565.221924, 4.594849), heading = 215.43307495117 },
            { type = 'biceps', coords = vector3(-1196.874756, -1573.107666, 4.611694), heading = 31.181102752686 },
            { type = 'biceps', coords = vector3(-1198.945068, -1574.637329, 4.594849), heading = 31.181102752686 },
        },
    },

    -- ── Vestiaires (salle publique) ───────────────────────────────────────
    -- Casier personnel unique par joueur (même DataStore quel que soit le
    -- casier utilisé) : on peut déposer dans l'un et récupérer dans un autre.
    -- Marqué au sol par un rond de couleur (DrawMarker type 1).
    Lockers = {
        maxWeight = 30,
        Rooms = {
            {
                restrict    = 'male',
                markerColor = { r = 30, g = 120, b = 255, a = 150 },
                Coords = {
                    { coords = vector3(-413.7457, -334.6371, 43.5975), heading = 339.9254 },
                    { coords = vector3(-412.8343, -332.2164, 43.5975), heading = 164.4645 },
                    { coords = vector3(-404.7665, -331.2190, 43.5975), heading = 243.8716 },
                },
            },
            {
                restrict    = 'female',
                markerColor = { r = 255, g = 60, b = 180, a = 150 },
                Coords = {
                    { coords = vector3(-407.7296, -318.1234, 43.5975), heading = 168.1104 },
                    { coords = vector3(-408.5624, -320.5006, 43.5975), heading = 339.5122 },
                    { coords = vector3(-402.6317, -326.0583, 43.5975), heading = 250.7603 },
                },
            },
        },
    },
}
