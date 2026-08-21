--  MODULE POLICE NATIONALE — Appels 17 / Missions PNJ

Config              = Config              or {}
Config.Police       = Config.Police       or {}
Config.Police.Callouts = {}

local C = Config.Police.Callouts

--  PARAMÈTRES GÉNÉRAUX

-- Interrupteur général — bascule aussi à chaud via /callouts on|off
C.Enabled = true

-- Mode debug : marqueurs de zones, états des PNJ, endurance des fuyards
C.Debug = false

-- Boombox mission « tapage » (via xsound, cf. client/callouts.lua)
C.BoomboxSound = {
    urls = {
        'https://cdn.pixabay.com/audio/2025/10/05/audio_03aa8a27b9.mp3',
        'https://cdn.pixabay.com/audio/2025/10/05/audio_02855cd1d3.mp3',
        'https://cdn.pixabay.com/audio/2025/10/14/audio_2dbd941d78.mp3',
        'https://cdn.pixabay.com/audio/2025/10/11/audio_6d9bca700d.mp3',
    },
    volume = 0.6,
    range  = 25.0, -- distance (m) au-delà de laquelle le son n'est plus audible
}

-- Rythme des appels
C.Interval        = 180      -- secondes entre deux tirages (3 min)
C.AcceptTimeout   = 60       -- délai de prise en charge avant classement sans suite
C.MissionTimeout  = 1200     -- durée max d'une intervention (20 min)
C.MaxActive       = 1        -- appels actifs simultanés

-- Placement
C.SpawnRadius        = 60.0   -- rayon de dispersion des suspects autour du requérant
C.SearchRadius       = 100.0  -- rayon du cercle de recherche affiché sur la carte
C.MinPlayerDistance  = 80.0   -- distance mini d'un joueur non-policier
C.LocationCooldown   = 1800   -- cooldown par emplacement (30 min)

-- Renforts
C.BackupCooldown = 60        -- délai entre deux demandes de renfort
C.BackupTimeout  = 120       -- expiration d'une demande sans réponse

-- Équipages (Police Secours)
C.CrewMaxSize = 4
C.Crews = {
    { id = 'alpha',   label = 'Équipage Alpha',   color = 3  },
    { id = 'bravo',   label = 'Équipage Bravo',   color = 5  },
    { id = 'charlie', label = 'Équipage Charlie', color = 47 },
}

-- Invite d'appel entrante (non bloquante)
C.PromptDuration  = 60       -- s d'affichage de l'invite (= AcceptTimeout)
C.PromptAcceptKey = 'Y'      -- touche par défaut pour prendre l'appel
C.PromptRefuseKey = 'N'      -- touche par défaut pour refuser
C.BackupKey       = 'H'      -- touche de demande de renfort (mission en cours)

-- Fuite et poursuite
C.FleeTriggerDistance = 5.0

-- Course : le fuyard sprinte à fond pendant un temps limité, puis
C.FleeSprintDuration  = 15    -- s de sprint à pleine vitesse
C.FleeSlowAt          = 18    -- s à partir desquelles il ralentit encore
C.FleeRateTired       = 0.50  -- allure entre les deux (1.0 = normale)
C.FleeRateExhausted   = 0.35  -- allure au-delà, il n'en peut plus

-- Une fois essoufflé, l'individu renonce si un agent le suit d'assez
C.FleeSurrenderDist   = 10.0
C.FleeMaxDuration     = 300   -- garde-fou : au-delà, fuyard déclaré échappé
C.EscapeDistance      = 300.0 -- distance d'échappement
C.EscapeDelay         = 30    -- durée à cette distance avant échappement
C.DropWeaponChance    = 25    -- % qu'un fuyard armé lâche son arme

-- Les individus d'une même intervention partent TOUS du même côté :
C.FleeConeDeg   = 60          -- ouverture du cône de dispersion (± 30°)
C.FleeTargetDst = 300.0       -- distance du point de fuite le long du cap

-- Rixes (bagarre de rue, rixe de soirée)
C.Brawl = {
    -- Journalise la détection de mise en joue dans le F8 : utile pour
    Debug = false,

    -- Distance sous laquelle ils cessent de se battre et font face aux
    NoticeDist = 12.0,

    -- Distance à laquelle une mise en joue est prise en compte.
    AimDist = 18.0,

    -- Chances (%) qu'un individu se rende plutôt que de se retourner
    SurrenderChance = 70,

    -- Un individu armé est plus enclin à résister.
    ArmedSurrenderMalus = 25,

    -- Reddition d'office au bout de ce délai au contact, SANS mise en
    PatienceDelay = 0,
}

-- Annoncer chaque reddition dans une bulle d'information. Désactivé :
C.SurrenderNotice = false

-- Ivresse publique manifeste
C.Drunk = {
    -- Jeu de déplacement titubant, essayés dans l'ordre.
    Clipsets = { 'move_m@drunk@verydrunk', 'move_m@drunk@moderatedrunk' },

    -- Perte d'équilibre : durée du vacillement (ms) et intervalle entre
    StumbleMin  = 14000,
    StumbleMax  = 26000,
    StumbleTime = 1600,
}

-- Levée de corps par les secours
C.Ambulance = {
    Enabled = true,

    -- Trace la chaîne complète dans le F8 de l'agent : quelle branche
    Debug = true,

    Model = 'ambulance',
    Peds  = { 's_m_m_paramedic_01', 's_m_m_doctor_01' },
    Crew  = 2,                 -- brancardiers à bord

    SpawnDist  = 110.0,        -- distance d'apparition, hors de vue
    ArriveDist = 6.0,          -- rayon d'arrêt sur le nœud routier visé
    ReachDist  = 2.5,          -- distance à laquelle un brancardier est « au corps »
    FinalApproach = 18.0,      -- au-delà, tentative d'approche directe hors route
    WalkTimeout = 25000,       -- délai max pour rejoindre le corps à pied
    DriveSpeed = 26.0,

    -- Style de conduite d'URGENCE : évite les véhicules, ignore les feux
    DriveStyle = 786469,

    -- Escalade quand la circulation ne se dégage pas. Une ambulance
    StuckDelay      = 4000,    -- ms d'immobilité avant de réagir
    StuckSwerve     = 2,       -- écarts tentés avant repositionnement
    StuckReposition = true,    -- en dernier recours, la rapprocher

    ApproachTimeout = 45000,   -- délai max pour rejoindre la scène (ms)
    WorkDelay       = 6000,    -- durée de la prise en charge du corps
    BoardDelay      = 6000,    -- délai pour remonter en ambulance
    Cleanup         = 45,      -- s avant suppression du convoi

    Siren = true,
}

-- Prise en charge des victimes
C.CarePenalty = {
    NotHealed     = 0.25,   -- part de prime perdue par victime non secourue
    NotIdentified = 0.10,   -- idem si son identité n'a pas été relevée
    Max           = 0.50,   -- plafond, toutes victimes confondues
}

-- Chances (%) que le véhicule visé par un vol en cours soit un
C.TargetBikeChance = 0

-- Animal dangereux
C.AnimalAggroDist = 10.0

-- Victime encore aux prises avec ses agresseurs (vol à l'arraché,
C.VictimAssaultAggroDist = 10.0

-- Distance à laquelle un suspect passif « roule le dé » pour se
C.AggroApproachDist = 4.0

-- Posture de la personne mordue une fois le chien détourné. Elle ne se
C.WoundedScenarios = {
    { dict = 'random@mugging4',    clip = 'flee_backward_loop_shopkeeper' }, -- Évanoui 5
    { dict = 'random@dealgonewrong', clip = 'idle_a' },                     -- Shot
}

-- Pose des corps (constatation de décès, tuerie de masse) : une posture
C.CorpsePoses = {
    { dict = 'missarmenian2', clip = 'drunk_loop' },                  -- Évanoui
    { dict = 'missarmenian2', clip = 'corpse_search_exit_ped' },      -- Évanoui 2
    { dict = 'mini@cpr@char_b@cpr_def', clip = 'cpr_pumpchest_idle' }, -- Évanoui 4
    { dict = 'anim@scripted@data_leak@fix_bil_ig2_chopper_crawl@',
      clip = 'fix_bil_ig2_chopper_crawl_loop_ped' },                  -- Évanoui 6
}

-- Distance des suspects autour du requérant quand le scénario les y
C.SuspectsAtCallerRange = 1.5

-- Contrainte non létale (§ moyens non létaux)
C.NonLethal = {
    ['WEAPON_STUNGUN']    = { hits = 1, duration = 6  },
    ['WEAPON_UNARMED']    = { hits = 3, duration = 6  },
    ['WEAPON_NIGHTSTICK'] = { hits = 3, duration = 6  },
    ['WEAPON_FLASHLIGHT'] = { hits = 3, duration = 6  },
}
C.NonLethalHealthFloor = 110   -- PV plancher restaurés après chaque impact

-- Les dégâts de ces armes sont divisés pendant une intervention. Sans
C.NonLethalDamageScale = 0.05

-- Le taser ne passe PLUS par le circuit de dégâts du jeu : la cible est
C.TaserScripted = true
C.MeleeHitResetDelay   = 10    -- s sans coup → remise à zéro du compteur

-- Interpellation et retour au poste
C.CustodyRadius    = 10.0   -- distance de présentation à Mike
C.FirstAidDuration = 8000   -- durée des premiers soins (ms)

-- Transport des individus
C.TransportSeats       = { 2, 1 }
C.TransportSearchRange = 6.0   -- rayon de recherche du véhicule de service
-- Modèles supplémentaires acceptés comme véhicules de police (addons).
C.ExtraPoliceVehicles  = {}

-- Témoins, badauds, requérant
C.WitnessErrorChance = 0      -- % d'erreur (0 = le témoin ne se trompe jamais)
C.CallerLeaveDelay   = 60     -- s avant que le requérant s'en aille
-- Les badauds ne sont pas systématiques : une scène déserte arrive, et
C.BystanderChance    = 55     -- % de chance qu'un attroupement se forme
C.BystandersMin      = 2
C.BystandersMax      = 4
-- Catégories d'emplacement où des badauds apparaissent
C.BystanderLocations = { street = true, nightlife = true, shop = true }

-- Fausses alertes
C.FalseAlarmChance = 8        -- % des appels
C.FalseAlarmReward = 150      -- prime versée malgré tout

-- Malus
C.MisconductTeamPenalty    = 0.25  -- baisse de prime des autres agents par bavure
C.MisconductTeamMaxPenalty = 0.75
C.ArmedDeliveryPenalty     = 0.25  -- baisse par suspect livré encore armé
C.ArmedDeliveryMaxPenalty  = 0.75

-- Mode test admin (/missionpnjadmin)
C.TestModeDefaultStaff = 8    -- effectif simulé par défaut
-- Tant que le mode test tourne, plus AUCUN appel n'est tiré
C.TestModeStopsScheduler = true

-- Sortie de scène en fin de mission
C.CleanupDelay = 90           -- secondes avant suppression effective

-- Sac mortuaire (constatation de décès)
C.BodyBagProps = {
    'xm_prop_body_bag_01',
    'p_cs_bodybag',
    'prop_bodybag_01',
}
C.BodyBagDuration = 6000      -- durée de l'animation de mise en housse

-- Anti-spawn sur les toits
C.MaxGroundDelta = 6.0

--  VALIDATION DES POSITIONS DE SPAWN

C.Spawn = {
    -- Journalise en console le motif de chaque rejet. À activer pour
    Debug = false,

    -- Recherche
    MaxAttempts   = 120,    -- tentatives avant abandon
    RadiusMin     = 2.0,   -- rayon de départ de la spirale
    RadiusMax     = 35.0,  -- rayon maximal exploré
    RadiusStep    = 2.5,   -- pas d'élargissement
    AnglesPerRing = 12,    -- directions testées par anneau

    -- Sol
    GroundOffset  = 1.0,   -- hauteur à laquelle le PNJ est posé
    -- Écart maximal avec le sol de référence (rejette toits et sous-sols)
    MaxLevelDelta = 6.0,

    -- Eau
    WaterMargin   = 0.6,

    -- Espace libre
    ClearRadius   = 1.2,   -- rayon devant être libre autour du PNJ
    ClearHeight   = 1.9,   -- hauteur libre requise au-dessus du point
    CheckPeds     = true,
    CheckVehicles = true,
    CheckObjects  = true,

    -- Navigation
    NavTolerance  = 5.0,

    -- Au-delà de la tolérance, la candidate est RAMENÉE sur le point
    NavSnapMax    = 20.0,

    -- Écart maximal toléré lors du recalage d'altitude. Au-delà, les
    MaxRebase     = 15.0,

    -- Proximité du joueur
    MinPlayerDist = 12.0,  -- distance mini d'un agent (0 = désactivé)
    AvoidFov      = true,  -- éviter d'apparaître dans son champ de vision
    FovRadius     = 1.5,   -- rayon testé pour la visibilité

    -- Corps des constatations de décès
    Corpse = {
        CollisionTimeout = 6000,  -- attente du chargement des collisions
        SettleTimeout    = 6000,  -- attente de stabilisation au sol
        SettleMinDelay   = 900,   -- délai minimal avant de juger stabilisé
        RagdollDelay     = 500,   -- entre l'effondrement et la mort
        VerifyDelay      = 2000,  -- entre la mort et la vérification finale
        MaxFloat         = 0.40,  -- hauteur au-dessus du sol tolérée
        GroundOffset     = 0.05,  -- hauteur de pose définitive
        CallerMinDist    = 2.5,   -- distance mini du témoin au corps
        CallerMaxDist    = 4.5,   -- distance maxi du témoin au corps

        -- Flaque de sang posée au sol une fois le corps figé. Décalque
        BloodDecal = {
            size    = 1.6,      -- diamètre du décalque, en mètres
            alpha   = 1.0,      -- opacité (0.0 à 1.0)
            timeout = 999999.0, -- durée avant disparition, en ms
        },
    },

    -- Repli
    AllowFallback = true,
}

-- Divers
C.BrainMaxDistance = 300.0    -- au-delà, le rôle de « cerveau » bascule
C.FallbackPed      = 'a_m_y_genstreet_01'

--  LES TROIS PNJ D'INTERACTION FIXES

C.Npcs = {

    -- ANNA — inscription au groupe d'intervention (commissariat)
    register = {
        name    = 'Anna',
        model   = 's_f_y_cop_01',
        coords  = vec3(441.270325, -976.364807, 30.678345),
        heading = 181.41731262207,
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip    = false,   -- volontairement absente de la carte
    },

    -- DAVID — remise des individus interpellés (commissariat)
    custody = {
        name    = 'David',
        model   = 's_m_y_cop_01',
        coords  = vec3(454.997803, -1025.235107, 28.471069),
        heading = 87.874015808105,
        scenario = 'WORLD_HUMAN_COP_IDLES',
        blip    = { sprite = 60, color = 3, scale = 0.8, label = 'Remise des individus' },
    },

    -- JESSIE — accueil hospitalier (scénario personne_errante)
    hospital = {
        name    = 'Jessie',
        model   = 's_f_y_scrubs_01',
        coords  = vec3(295.701111, -591.494507, 43.248291),
        heading = 70.866142272949,
        -- Entrée de l'établissement : Jessie et la personne prise en
        walkTo  = vec3(299.182434, -584.782410, 43.248291),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip    = { sprite = 61, color = 2, scale = 0.8, label = 'Accueil hospitalier' },
    },
}

--  POOLS DE MODÈLES DE PNJ

C.PedPools = {

    -- Petite délinquance de rue
    street_crime = {
        'a_m_y_stwhi_01', 'a_m_y_stbla_01', 'a_m_y_soucent_01', 'a_m_y_soucent_02',
        'g_m_y_strpunk_01', 'g_m_y_strpunk_02', 'a_m_y_methhead_01',
    },

    -- Bagarre / rixe : civils lambda, mixte H/F
    brawlers = {
        'a_m_y_soucent_01', 'a_m_y_soucent_03', 'a_m_m_soucent_01', 'a_m_m_soucent_02',
        'a_m_y_stwhi_02', 'a_f_y_soucent_01', 'a_f_y_soucent_02', 'a_m_y_latino_01',
    },

    -- Cambrioleurs / braqueurs
    gang = {
        'g_m_y_mexgoon_01', 'g_m_y_mexgoon_02', 'g_m_y_mexgoon_03',
        'g_m_y_salvagoon_01', 'g_m_y_salvagoon_02', 'g_m_y_salvagoon_03',
        'g_m_y_ballasout_01', 'g_m_y_famca_01', 'g_m_y_lost_01',
    },

    -- Trafic de stupéfiants
    dealers = {
        's_m_y_dealer_01', 'a_m_y_methhead_01', 'g_m_y_ballasout_01', 'a_m_m_tramp_01',
    },

    -- Individu isolé, marginal ou instable
    unstable = {
        -- a_m_y_stlunat_01 retiré : absent de la build (contrôle au
        'a_m_m_tramp_01', 'a_m_y_methhead_01', 'a_m_m_soucent_04',
        'a_m_m_soucent_02',
    },

    -- Racolage
    hookers = { 's_f_y_hooker_01', 's_f_y_hooker_02', 's_f_y_hooker_03' },

    -- Vie nocturne, mixte H/F
    clubbers = {
        'a_m_y_clubcust_01', 'a_m_y_clubcust_02', 'a_m_y_clubcust_03',
        'a_f_y_clubcust_01', 'a_f_y_clubcust_02', 'a_f_y_clubcust_03',
        'a_m_y_hipster_01', 'a_f_y_hipster_02',
    },

    -- Résidents : propriétaire, voisin, maître de chien
    residents = {
        'a_m_m_business_01', 'a_m_y_business_01', 'a_f_m_business_02',
        'a_m_m_eastsa_01', 'a_m_m_eastsa_02', 'a_f_m_eastsa_01',
        'a_m_m_golfer_01', 'a_f_m_fatwhite_01',
    },

    -- Témoins / requérants sur la voie publique
    witnesses = {
        'a_f_y_business_01', 'a_m_y_business_02', 'a_f_m_soucent_01',
        'a_m_m_tourist_01', 'a_f_y_tourist_01', 'a_m_y_genstreet_01',
    },

    -- Agents de sécurité / vigiles : costume sombre, oreillette.
    guards = {
        's_m_m_security_01', 's_m_m_highsec_01', 's_m_m_highsec_02',
        's_m_y_doorman_01', 's_m_m_bouncer_01',
    },

    -- Personnes âgées / désorientées
    elderly = {
        'a_m_m_prolhost_01', 'a_f_m_ktown_02', 'a_m_m_ktown_01', 'a_f_m_downtown_01',
    },

    -- Caissier de supérette : utilisé comme requérant du braquage.
    cashiers = {
        'mp_m_shopkeep_01',
    },

    -- Victime décédée (mise à 0 PV)
    deceased = {
        'a_m_m_eastsa_02', 'a_m_m_business_01', 'a_f_m_bevhills_01', 'a_m_m_farmer_01',
    },

    -- Victime blessée (délit de fuite)
    victims = {
        'a_m_y_genstreet_01', 'a_f_y_business_01', 'a_m_m_eastsa_01', 'a_f_m_soucent_01',
    },

    -- Animaux
    animals = { 'a_c_rottweiler', 'a_c_shepherd', 'a_c_husky' },
}

--  POPULATION PAR ZONE

C.ZonePeds = {

    -- Pavillonnaire : habitants, familles, promeneurs, retraités
    residential = {
        'a_m_m_eastsa_01', 'a_m_m_eastsa_02', 'a_f_m_eastsa_01',
        'a_m_y_stwhi_01', 'a_f_y_hipster_01', 'a_m_m_golfer_01',
        'a_f_m_fatwhite_01', 'a_m_o_genstreet_01', 'a_f_y_business_02',
        'a_m_m_prolhost_01', 'a_f_m_downtown_01',
    },

    -- Centre-ville et zones commerçantes : employés, passants, touristes
    downtown = {
        'a_m_y_business_01', 'a_m_y_business_02', 'a_m_m_business_01',
        'a_f_y_business_01', 'a_f_y_business_02', 'a_f_m_business_02',
        'a_m_m_tourist_01', 'a_f_y_tourist_01', 'a_f_y_tourist_02',
        'a_m_y_downtown_01', 'a_f_m_downtown_01', 'a_m_y_hipster_01',
    },

    -- Quartiers populaires denses : habitants et piétons du secteur
    urban = {
        'a_m_y_soucent_01', 'a_m_y_soucent_02', 'a_m_y_soucent_03',
        'a_m_m_soucent_01', 'a_m_m_soucent_02', 'a_f_y_soucent_01',
        'a_f_y_soucent_02', 'a_f_m_soucent_01', 'a_m_y_stbla_01',
        'a_m_y_stwhi_02', 'a_m_y_latino_01', 'a_f_m_ktown_01',
    },

    -- Zones industrielles et portuaires : ouvriers, chauffeurs, agents
    industrial = {
        -- s_m_y_garbage_01 retiré : absent de la build.
        's_m_y_construct_01', 's_m_y_construct_02', 's_m_m_dockwork_01',
        's_m_y_dockwork_01', 's_m_m_trucker_01',
        's_m_m_security_01', 'a_m_m_ktown_01', 'a_m_y_genstreet_01',
    },

    -- Front de mer : baigneurs, promeneurs, sportifs
    beach = {
        'a_m_y_beach_01', 'a_m_y_beach_02', 'a_m_y_beach_03',
        'a_f_y_beach_01', 'a_m_m_beach_01', 'a_m_m_beach_02',
        'a_f_m_beach_01', 'a_m_y_surfer_01', 'a_m_y_musclbeac_01',
        'a_f_y_fitness_01',
    },

    -- Parcs et espaces verts : joggeurs, familles, activités de plein air
    park = {
        'a_m_y_runner_01', 'a_m_y_runner_02', 'a_f_y_runner_01',
        'a_f_y_fitness_01', 'a_f_y_fitness_02', 'a_m_y_cyclist_01',
        'a_m_m_golfer_01', 'a_f_y_yoga_01', 'a_m_y_yoga_01',
    },

    -- Quartiers aisés : résidents et passants au train de vie visible
    affluent = {
        'a_m_y_bevhills_01', 'a_m_y_bevhills_02', 'a_m_m_bevhills_01',
        'a_m_m_bevhills_02', 'a_f_y_bevhills_01', 'a_f_y_bevhills_02',
        'a_f_m_bevhills_01', 'a_m_y_golfer_01', 'a_m_m_golfer_01',
        'a_f_y_business_01',
    },

    -- Campagne : habitants locaux, agriculteurs, randonneurs
    rural = {
        'a_m_m_farmer_01', 'a_m_m_hillbilly_01', 'a_m_m_hillbilly_02',
        'a_f_m_salton_01', 'a_m_m_salton_01', 'a_m_m_salton_02',
        'a_f_y_hiker_01', 'a_m_y_hiker_01',
    },

    -- Zones isolées ou désertiques : aucun profil urbain
    desert = {
        'a_m_m_salton_01', 'a_m_m_salton_02', 'a_m_m_salton_03',
        'a_f_m_salton_01', 'a_m_m_hillbilly_01', 'a_m_m_tramp_01',
    },
}

-- Zone déduite de la catégorie d'emplacement quand aucune n'est
C.ZoneByCategory = {
    street      = 'downtown',
    residential = 'residential',
    doorstep    = 'residential',
    shop        = 'downtown',
    dealpoint   = 'urban',
    nightlife   = 'downtown',
    parking     = 'downtown',
}

-- Zone utilisée si tout le reste échoue.
C.ZoneFallback = 'downtown'

-- Pools d'AMBIANCE remplacés par la population de la zone. Les autres
C.ZoneSubstitutedPools = {
    witnesses = true,   -- requérants et badauds
    residents = true,   -- riverains, propriétaires, voisins
    victims   = true,   -- blessés
    deceased  = true,   -- défunts
    brawlers  = true,   -- bagarres de rue entre civils
}

--  IDENTITÉS — Los Santos, démographie de Los Angeles

C.Names = {

    anglo = {
        male   = { 'James', 'Michael', 'Robert', 'John', 'David', 'Ryan',
                   'Tyler', 'Brandon', 'Cody', 'Austin', 'Dylan', 'Shawn' },
        female = { 'Jennifer', 'Ashley', 'Sarah', 'Megan', 'Brittany', 'Amber',
                   'Nicole', 'Kayla', 'Hannah', 'Courtney', 'Lindsey', 'Paige' },
        last   = { 'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Miller',
                   'Davis', 'Wilson', 'Anderson', 'Taylor', 'Thompson', 'Clark' },
    },

    hispanic = {
        male   = { 'José', 'Carlos', 'Miguel', 'Luis', 'Jesús', 'Javier',
                   'Ricardo', 'Alejandro', 'Rafael', 'Ernesto', 'Hector', 'Diego' },
        female = { 'María', 'Guadalupe', 'Rosa', 'Carmen', 'Lucía', 'Esperanza',
                   'Alejandra', 'Valeria', 'Yolanda', 'Marisol', 'Camila', 'Daniela' },
        last   = { 'García', 'Rodríguez', 'Martínez', 'Hernández', 'López',
                   'González', 'Pérez', 'Sánchez', 'Ramírez', 'Torres',
                   'Flores', 'Vásquez', 'Castillo', 'Mendoza' },
    },

    african_american = {
        male   = { 'Marcus', 'DeShawn', 'Andre', 'Terrell', 'Jamal', 'Darnell',
                   'Malik', 'Tyrone', 'Devon', 'Reginald', 'Lamar', 'Xavier' },
        female = { 'Tamika', 'Latoya', 'Keisha', 'Jasmine', 'Aaliyah', 'Ebony',
                   'Shanice', 'Destiny', 'Imani', 'Tanisha', 'Monique', 'Alicia' },
        last   = { 'Washington', 'Jefferson', 'Jackson', 'Robinson', 'Harris',
                   'Coleman', 'Freeman', 'Banks', 'Dawson', 'Whitfield',
                   'Carter', 'Bryant' },
    },

    asian = {
        male   = { 'Min-jun', 'Jae-won', 'Wei', 'Chen', 'Hiroshi', 'Kenji',
                   'Tuan', 'Duc', 'Sang-hoon', 'Kevin', 'Jimmy', 'Danny' },
        female = { 'Ji-woo', 'Soo-yeon', 'Mei', 'Lin', 'Yuki', 'Sakura',
                   'Linh', 'Thuy', 'Hye-jin', 'Grace', 'Amy', 'Jenny' },
        last   = { 'Kim', 'Park', 'Lee', 'Choi', 'Nguyen', 'Tran', 'Pham',
                   'Wang', 'Chen', 'Liu', 'Yamamoto', 'Tanaka' },
    },

    eastern_european = {
        male   = { 'Dimitri', 'Sergei', 'Viktor', 'Andrei', 'Mikhail', 'Pavel',
                   'Goran', 'Milos', 'Tomasz', 'Piotr' },
        female = { 'Natalia', 'Svetlana', 'Irina', 'Katarzyna', 'Magda',
                   'Ana', 'Milena', 'Elena', 'Olga', 'Zofia' },
        last   = { 'Petrov', 'Volkov', 'Sokolov', 'Kowalski', 'Nowak',
                   'Novak', 'Petrovic', 'Horvat', 'Ivanov', 'Kozlov' },
    },

    middle_eastern = {
        male   = { 'Omar', 'Karim', 'Youssef', 'Hassan', 'Amir', 'Farid',
                   'Sami', 'Tarek', 'Rami', 'Bilal' },
        female = { 'Layla', 'Yasmin', 'Nadia', 'Amina', 'Rania', 'Zahra',
                   'Farah', 'Salma', 'Dalia', 'Noor' },
        last   = { 'Hassan', 'Nasser', 'Khalil', 'Haddad', 'Saleh', 'Aziz',
                   'Rahman', 'Farouk', 'Mansour', 'Karam' },
    },

    -- Touristes étrangers de passage (surtout des témoins)
    tourist = {
        male   = { 'Klaus', 'Hans', 'Pierre', 'Jean-Luc', 'Giovanni', 'Marco',
                   'Lars', 'Sven', 'Diego', 'João', 'Liam', 'Oliver' },
        female = { 'Greta', 'Ingrid', 'Sophie', 'Camille', 'Giulia', 'Francesca',
                   'Astrid', 'Freya', 'Beatriz', 'Ana', 'Emma', 'Charlotte' },
        last   = { 'Müller', 'Schmidt', 'Dubois', 'Laurent', 'Rossi', 'Ferrari',
                   'Andersson', 'Nielsen', 'Silva', 'Costa', "O'Brien", 'Murphy' },
    },
}

-- Répartition des origines par pool de PNJ (poids relatifs)
C.PedPoolOrigins = {
    street_crime = { anglo = 30, hispanic = 30, african_american = 30, eastern_european = 10 },
    brawlers     = { anglo = 30, hispanic = 35, african_american = 25, asian = 10 },
    gang         = { hispanic = 55, african_american = 35, anglo = 10 },
    dealers      = { african_american = 40, hispanic = 35, anglo = 25 },
    unstable     = { anglo = 45, hispanic = 25, african_american = 25, eastern_european = 5 },
    hookers      = { anglo = 35, hispanic = 30, african_american = 25, eastern_european = 10 },
    clubbers     = { anglo = 40, hispanic = 25, african_american = 20, asian = 15 },
    residents    = { anglo = 45, hispanic = 20, asian = 15, african_american = 15, middle_eastern = 5 },
    witnesses    = { anglo = 30, hispanic = 25, african_american = 15, asian = 10,
                     tourist = 15, middle_eastern = 5 },
    elderly      = { anglo = 50, hispanic = 20, asian = 20, african_american = 10 },
    guards       = { anglo = 40, african_american = 30, hispanic = 25, eastern_european = 5 },
    deceased     = { anglo = 40, hispanic = 25, african_american = 20, asian = 15 },
    victims      = { anglo = 40, hispanic = 25, african_american = 20, asian = 15 },
}

C.DefaultOrigins = { anglo = 40, hispanic = 30, african_american = 20, asian = 10 }

--  VÉHICULES

C.Vehicles = {
    -- Deux-roues de fuite : petites cylindrées, la fuite doit rester rattrapable
    flee_bike = { 'faggio2', 'faggio3', 'bmx', 'scorcher', 'sanchez', 'ruffian' },

    -- Voitures de fuite (complice au volant)
    flee_car  = { 'sultan', 'buffalo', 'felon', 'premier', 'emperor', 'blista' },

    -- Véhicule CIBLE du vol en cours
    target_car = { 'blista', 'premier', 'emperor', 'ingot', 'asea', 'washington' },

    -- Deux-roues ciblé par le vol en cours
    target_bike = { 'faggio2', 'faggio3', 'sanchez', 'ruffian', 'pcj', 'bagger' },

    -- Véhicule accidenté du délit de fuite
    crashed_car = { 'blista', 'asea', 'washington', 'premier', 'emperor' },

    -- Véhicule-sono du tapage
    boombox_car = { 'blista', 'faction', 'buccaneer', 'manana', 'voodoo', 'peyote' },

    -- Véhicule du suspect sur une tuerie de masse, laissé sur place
    mass_incident_car = { 'asea', 'premier', 'washington', 'emperor', 'primo' },
}

-- Variantes d'accident pour le délit de fuite
C.CrashTypes = {
    { id = 'car_car',     label = 'collision entre deux véhicules', victim = true,  second = 'crashed_car' },
    { id = 'car_bike',    label = 'collision avec un deux-roues',   victim = true,  second = 'flee_bike'   },
    { id = 'car_ped',     label = 'piéton renversé',                victim = true,  second = nil           },
    -- Un délit de fuite sans blessé n'offre plus rien à faire sur place :
    { id = 'car_pole',    label = 'véhicule encastré',              victim = true,  second = nil           },
}

--  AMBIANCE SONORE

C.RadioStations = {
    'RADIO_02_POP', 'RADIO_03_HIPHOP_NEW', 'RADIO_16_SILVERLAKE',
    'RADIO_12_REGGAE', 'RADIO_06_COUNTRY',
}

C.AlarmSound = { name = 'Beep_Red', set = 'DLC_HEIST_HACKING_SNAKE_SOUNDS', range = 50.0 }

-- Dialogues d'ambiance (contextes GTA)
C.Speech = {
    greet      = { 'GENERIC_HI', 'GENERIC_HOWS_IT_GOING' },
    flee       = { 'GENERIC_FRIGHTENED_HIGH', 'COP_FLEE' },
    aimed      = { 'GENERIC_SHOCKED_HIGH', 'SURRENDER' },
    cuffed     = { 'GENERIC_CURSE_MED', 'GENERIC_INSULT_MED' },
    combat     = { 'GENERIC_WAR_CRY', 'CHALLENGE_THREATEN' },
    fight      = { 'FIGHT', 'GENERIC_CURSE_HIGH' },
    bystander  = { 'GENERIC_SHOCKED_MED' },
    surrender  = { 'SURRENDER', 'GENERIC_FRIGHTENED_MED' },
    hurt       = { 'GENERIC_FRIGHTENED_MED', 'CRASH_GENERIC' },
}
C.SpeechCooldown = 4000   -- ms entre deux répliques d'un même PNJ

--  BRAQUAGE DE SUPÉRETTE — MISE EN SCÈNE DYNAMIQUE

C.Heist = {

    Enabled = true,
    -- Trace en F8 : scénario tiré, profil du chef, effectifs, réaction
    Debug   = true,

    -- Détection de la police
    SightDist  = 35.0,   -- portée de vue, ligne de mire requise
    SirenDist  = 60.0,   -- portée d'une sirène en fonctionnement
    DecideWait = 1200,   -- délai de réaction du chef (ms)

    -- Scénarios
    Scenes = {
        {
            id = 'en_cours', weight = 40,
            label = 'braquage en cours',
            -- Le magasin est sous contrôle : caissier mains en l'air,
            inside = true,
            roles  = { lookout = 1, looter = 1 },
            cashier = 'handsup',
            clients = 'down',
            loot    = 'full',
        },
        {
            id = 'sortie', weight = 30,
            label = 'braquage terminé',
            -- Ils sortent au moment où la police arrive : le conducteur
            inside = false,
            boarding = true,
            cashier = 'phone',
            clients = 'recover',
            loot    = 'full',
        },
        {
            id = 'precipitation', weight = 20,
            label = 'police très rapide',
            -- Ils n'ont pas fini : une partie du butin reste sur place
            inside = true,
            roles  = { looter = 2 },
            cashier = 'crouch',
            clients = 'hide',
            loot    = 'partial',
            hurried = true,
        },
        {
            id = 'tourne_mal', weight = 10,
            label = 'braquage qui tourne mal',
            -- Le chef hésite, le groupe s'attarde. Reddition et
            inside = true,
            roles  = { lookout = 1 },
            cashier = 'counter',
            clients = 'frozen',
            loot    = 'full',
            hesitate = true,
            reactionShift = { surrender = 6, fight = 6, barricade = 3 },
        },
    },

    -- Réactions possibles du GROUPE
    Reactions = {
        flee_car   = 74,   -- repli sur le véhicule
        fight      = 10,   -- affrontement armé
        surrender  = 7,    -- reddition
        flee_foot  = 4,    -- fuite immédiate à pied
        barricade  = 4,    -- retranchement dans le magasin
    },

    -- Profils de chef
    Leaders = {
        { id = 'calme',      weight = 25,
          shift = { flee_car = 35, surrender = 5, fight = -6 } },
        { id = 'nerveux',    weight = 25,
          shift = { fight = 6, barricade = 2, flee_foot = 1 } },
        { id = 'expérimenté', weight = 20,
          shift = { flee_car = 42, surrender = -5, flee_foot = -1 } },
        { id = 'jeune',      weight = 20,
          shift = { flee_car = -35, surrender = 5, flee_foot = 2 } },
        { id = 'amateur',    weight = 10,
          shift = { flee_car = -42, surrender = 6, fight = -6, flee_foot = 1 } },
    },

    -- Civils
    Clients = {
        Min = 0, Max = 5,
        -- Répartition des postures pendant le braquage. Le scénario
        Postures = {
            down   = 4,   -- couché au sol
            crouch = 3,   -- accroupi
            hide   = 2,   -- caché derrière un rayon
            frozen = 2,   -- figé par la peur
            leave  = 1,   -- en train de sortir
        },
        -- Une fois les braqueurs partis
        After = {
            phone  = 4,   -- sort son téléphone
            call   = 3,   -- appelle les secours
            talk   = 3,   -- vient parler aux policiers
            leave  = 2,   -- quitte le magasin
        },
    },

    -- Véhicule de fuite
    Vehicle = {
        WaitDist    = 6.0,     -- distance d'attente devant l'entrée
        Headlights  = true,    -- phares allumés la nuit
        WatchAhead  = true,    -- le conducteur surveille la rue
        BoardDelay  = 800,     -- délai entre deux embarquements (ms)
        LeaveDelay  = 4000,    -- attente avant de partir sans un braqueur
        DriveSpeed  = 30.0,
        DriveStyle  = 786469,
    },
}

--  TUERIE DE MASSE — INCIDENT AVEC NOMBREUSES VICTIMES

C.MassShooting = {

    Enabled = true,
    Debug   = true,

    -- Scénarios (variantes A-E)
    Scenarios = {
        {
            id = 'A', weight = 100,
            label = 'incident en cours',
            suspectState = 'present',
            deaths  = { min = 6, max = 6 },
            wounded = { min = 6, max = 6 },
            witnesses = { min = 2, max = 3 },
            vehicle = 'none',
            panicStart = 5,   -- DANGER ACTIF
            dispatch = {
                "Coups de feu signalés %s, plusieurs victimes au sol. Tireur toujours actif.",
                "Fusillade en cours %s, de nombreux blessés. Extrême prudence.",
            },
        },
    },

    -- Témoins clés (2-3, individuellement interrogeables)
    Witnesses = {
        Profiles = {
            vu_suspect        = 3,  -- a vu le suspect, peut le décrire
            vu_vehicule        = 2,  -- a vu le véhicule et sa direction
            entendu_seulement  = 3,  -- n'a fait qu'entendre les tirs
            cherche_proche     = 2,  -- cherche un proche présent sur les lieux
        },
    },

    -- Victimes non décédées
    Victims = {
        Postures = {
            injured_down   = 4,  -- blessée, au sol
            injured_mobile = 2,  -- blessée mais capable de se déplacer
            shock          = 2,  -- état de choc, indemne
            hidden         = 2,  -- cachée
            panicked       = 1,  -- paniquée mais indemne
        },
    },
}

--  ANCRAGES DE SCÈNE — POSITIONS RELEVÉES À LA MAIN

-- Scénarios qui n'ont RIEN à mettre en scène : un seul PNJ, posé par
C.NoAnchorNeeded = {
    constatation_effraction = true,
}

-- Distance maximale entre le joueur et l'emplacement déclaré lors d'un
C.SurveyMaxDist = 80.0

C.SceneAnchors = {


    -- Vol de véhicule (générique : vol_vehicule + tapage)
    ['parking:2'] = {     -- Parking Pillbox Hill
        tapage = {
        suspect = {
            vector4(243.42, -786.72, 30.52, 260.8),
            vector4(244.14, -785.22, 30.54, 246.6),
            vector4(246.26, -785.90, 30.52, 337.4),
            vector4(245.02, -786.06, 30.52, 263.6),
            vector4(245.96, -787.54, 30.50, 275.0),
            vector4(247.30, -788.20, 30.48, 345.8),
            vector4(248.46, -787.18, 30.48, 62.4),
            vector4(247.64, -786.10, 30.50, 127.6),
        },
        vehicle = vector4(244.90, -789.58, 30.10, 70.4),
        },
        vehicle = vector4(238.98, -806.26, 29.94, 70.2),
        suspect = {
            vector4(238.86, -807.62, 30.30, 68.0),
            vector4(239.94, -804.62, 30.34, 87.8),
        },
        caller = vector4(247.30, -779.56, 30.84, 161.6),
    },
    ['parking:3'] = {     -- Parking de Vespucci Beach
        tapage = {
        suspect = {
            vector4(-1198.98, -1492.94, 4.36, 306.2),
            vector4(-1198.44, -1491.18, 4.38, 141.8),
            vector4(-1199.64, -1490.54, 4.36, 218.2),
            vector4(-1200.98, -1491.12, 4.36, 235.2),
            vector4(-1199.90, -1491.86, 4.36, 258.0),
            vector4(-1202.18, -1492.18, 4.34, 260.8),
            vector4(-1202.00, -1493.64, 4.34, 306.2),
            vector4(-1196.92, -1491.40, 4.38, 116.2),
        },
        vehicle = vector4(-1197.96, -1493.82, 3.98, 304.8),
        },
        caller = vector4(-1164.66, -1482.34, 4.38, 65.2),
        vehicle = vector4(-1189.54, -1473.16, 3.98, 306.0),
        suspect = {
            vector4(-1190.58, -1472.30, 4.38, 306.2),
            vector4(-1188.54, -1474.48, 4.38, 34.0),
        },
    },
    ['parking:5'] = {     -- Parking de Del Perro
        vehicle = vector4(-1447.90, -675.72, 26.08, 32.6),
        suspect = {
            vector4(-1448.82, -676.70, 26.46, 31.2),
            vector4(-1446.46, -674.92, 26.46, 110.6),
        },
        caller = vector4(-1436.14, -653.94, 28.68, 147.4),
    },
    ['parking:6'] = {     -- Rockford Plaza
        vehicle = vector4(-708.60, -880.40, 23.22, 0.6),
        suspect = {
            vector4(-709.92, -880.74, 23.60, 0.0),
            vector4(-707.02, -880.60, 23.60, 45.4),
        },
        caller = vector4(-696.06, -853.64, 23.68, 150.2),
    },
    ['parking:7'] = {     -- Parking du Casino
        tapage = {
        suspect = {
            vector4(887.82, -25.98, 78.76, 300.4),
            vector4(886.32, -24.48, 78.76, 204.0),
            vector4(884.72, -24.30, 78.76, 238.2),
            vector4(883.96, -25.24, 78.76, 266.4),
            vector4(884.58, -26.36, 78.76, 323.2),
            vector4(885.68, -27.16, 78.76, 357.2),
            vector4(887.10, -27.96, 78.76, 14.2),
            vector4(888.26, -27.60, 78.76, 51.0),
        },
        vehicle = vector4(888.22, -23.44, 78.38, 58.8),
        },
        caller = vector4(884.46, -0.34, 78.76, 153.0),
        vehicle = vector4(870.02, -36.24, 78.38, 59.0),
        suspect = {
            vector4(869.62, -37.52, 78.76, 56.6),
            vector4(871.14, -34.62, 78.76, 107.8),
        },
    },
    ['parking:8'] = {     -- Parking LSIA
        tapage = {
        suspect = {
            vector4(-978.10, -2711.40, 13.82, 354.4),
            vector4(-978.22, -2709.14, 13.84, 255.2),
            vector4(-979.46, -2710.20, 13.84, 209.8),
            vector4(-979.56, -2712.02, 13.82, 283.4),
            vector4(-979.68, -2707.68, 13.84, 204.0),
            vector4(-981.24, -2709.58, 13.82, 275.0),
            vector4(-982.16, -2711.42, 13.82, 275.0),
            vector4(-979.22, -2714.00, 14.04, 343.0),
        },
        vehicle = vector4(-976.74, -2711.24, 13.46, 352.6),
        },
        caller = vector4(-1001.56, -2710.58, 13.80, 133.2),
        vehicle = vector4(-967.78, -2696.32, 13.44, 151.0),
        suspect = {
            vector4(-966.54, -2697.32, 13.82, 56.6),
            vector4(-969.34, -2695.78, 13.82, 243.8),
        },
    },
    ['parking:9'] = {     -- Parking de La Puerta
        caller = vector4(-340.92, -1471.80, 30.74, 192.8),
        vehicle = vector4(-333.44, -1494.80, 30.26, 2.4),
        suspect = {
            vector4(-334.74, -1495.18, 30.62, 0.0),
            vector4(-331.84, -1494.64, 30.64, 79.4),
        },
    },
    ['parking:10'] = {     -- Parking du stade
        tapage = {
        suspect = {
            vector4(-608.62, -1213.96, 14.46, 306.2),
            vector4(-607.14, -1212.80, 14.68, 326.0),
            vector4(-608.84, -1211.56, 14.60, 201.2),
            vector4(-609.96, -1212.34, 14.46, 224.0),
            vector4(-611.20, -1213.54, 14.30, 246.6),
            vector4(-611.28, -1215.14, 14.20, 306.2),
            vector4(-610.54, -1216.46, 14.18, 207.0),
            vector4(-609.56, -1215.16, 14.34, 323.2),
        },
        vehicle = vector4(-607.38, -1216.04, 14.04, 313.0),
        },
        caller = vector4(-617.78, -1211.16, 14.14, 107.8),
        vehicle = vector4(-641.40, -1220.76, 11.06, 303.0),
        suspect = {
            vector4(-642.42, -1219.88, 11.36, 303.4),
            vector4(-640.64, -1222.16, 11.44, 357.2),
        },
    },
    ['parking:12'] = {     -- Parking du front de mer
        tapage = {
        vehicle = vector4(-1560.74, -1012.30, 12.62, 23.8),
        suspect = {
            vector4(-1561.80, -1014.60, 13.00, 19.8),
            vector4(-1562.50, -1012.90, 13.00, 19.8),
            vector4(-1563.84, -1011.96, 13.00, 215.4),
            vector4(-1564.36, -1013.16, 13.00, 306.2),
            vector4(-1564.40, -1014.44, 13.00, 309.0),
            vector4(-1562.82, -1013.98, 13.00, 306.2),
            vector4(-1563.70, -1014.74, 13.00, 328.8),
            vector4(-1562.70, -1015.68, 13.00, 348.6),
        },
        },
        vehicle = vector4(-1573.26, -1044.56, 12.62, 74.2),
        suspect = {
            vector4(-1573.30, -1045.92, 13.00, 73.8),
            vector4(-1572.90, -1043.20, 13.00, 136.0),
        },
        caller = vector4(-1608.88, -1047.24, 13.08, 275.0),
    },
    ['parking:13'] = {     -- Parking de Popular Street
        caller = vector4(1115.64, -1509.42, 34.84, 351.4),
        vehicle = vector4(1113.96, -1476.68, 34.30, 180.8),
        suspect = {
            vector4(1115.34, -1477.10, 34.68, 90.8),
            vector4(1112.34, -1477.08, 34.68, 275.0),
        },
    },
    ['parking:14'] = {     -- Parking de Davis
        caller = vector4(502.82, -1508.36, 29.24, 173.0),
        vehicle = vector4(502.44, -1526.56, 28.90, 139.2),
        suspect = {
            vector4(503.64, -1527.16, 29.28, 138.8),
            vector4(501.12, -1526.08, 29.28, 235.2),
        },
    },
    ['parking:15'] = {     -- Parking de Bay City
        tapage = {
        vehicle = vector4(-1127.68, -758.74, 18.74, 287.4),
        suspect = {
            vector4(-1124.12, -759.70, 19.16, 119.0),
            vector4(-1123.68, -760.56, 19.12, 116.2),
            vector4(-1125.20, -761.40, 19.02, 116.2),
            vector4(-1126.92, -762.38, 18.92, 116.2),
            vector4(-1127.38, -761.56, 18.96, 22.6),
            vector4(-1126.00, -760.88, 19.04, 303.4),
            vector4(-1124.00, -757.84, 19.24, 173.0),
            vector4(-1125.00, -756.60, 19.30, 195.6),
        },
        },
        vehicle = vector4(-1137.50, -746.78, 19.32, 287.8),
        suspect = {
            vector4(-1138.24, -745.68, 19.76, 289.2),
            vector4(-1137.30, -748.62, 19.60, 354.4),
        },
        caller = vector4(-1176.68, -746.84, 19.62, 275.0),
    },
    ['parking:16'] = {     -- Parking de Chamberlain
        tapage = {
        suspect = {
            vector4(58.34, -1546.04, 29.44, 337.4),
            vector4(59.70, -1546.94, 29.44, 252.2),
            vector4(61.22, -1547.54, 29.44, 22.6),
            vector4(59.92, -1548.56, 29.44, 22.6),
            vector4(57.86, -1547.52, 29.44, 317.4),
            vector4(58.22, -1544.08, 29.44, 201.2),
            vector4(56.34, -1546.18, 29.62, 275.0),
            vector4(56.22, -1547.44, 29.44, 300.4),
        },
        vehicle = vector4(61.14, -1544.80, 29.06, 50.4),
        },
        caller = vector4(42.14, -1599.42, 29.60, 62.4),
        vehicle = vector4(23.78, -1589.24, 28.82, 232.4),
        suspect = {
            vector4(24.62, -1588.18, 29.22, 150.2),
            vector4(22.62, -1590.52, 29.26, 314.6),
        },
    },
    ['parking:17'] = {     -- Parking de Little Seoul
        tapage = {
        vehicle = vector4(-335.94, -976.44, 30.68, 160.4),
        suspect = {
            vector4(-332.18, -980.22, 31.08, 53.8),
            vector4(-333.46, -979.80, 31.08, 68.0),
            vector4(-334.54, -978.72, 31.08, 269.2),
            vector4(-334.18, -977.28, 31.08, 340.2),
            vector4(-333.04, -975.84, 31.08, 218.2),
            vector4(-331.64, -975.80, 31.08, 161.6),
            vector4(-332.52, -977.24, 31.08, 158.8),
            vector4(-332.62, -979.04, 31.08, 90.8),
        },
        },
        vehicle = vector4(-361.08, -904.28, 30.68, 269.0),
        suspect = {
            vector4(-361.38, -902.96, 31.06, 269.2),
            vector4(-361.30, -905.92, 31.06, 294.8),
        },
        caller = vector4(-350.78, -871.02, 31.14, 158.8),
    },
    ['parking:18'] = {     -- Parking de Mirror Park Est
        tapage = {
        vehicle = vector4(1014.52, -762.80, 57.50, 220.6),
        suspect = {
            vector4(1010.86, -763.02, 57.88, 226.8),
            vector4(1010.08, -763.76, 57.88, 241.0),
            vector4(1009.42, -764.84, 57.88, 258.0),
            vector4(1009.38, -766.22, 57.88, 323.2),
            vector4(1010.72, -767.12, 57.88, 11.4),
            vector4(1012.44, -766.88, 57.88, 39.6),
            vector4(1013.16, -765.88, 57.88, 76.6),
            vector4(1012.74, -764.86, 57.88, 102.0),
        },
        },
        caller = vector4(1047.36, -766.24, 57.78, 127.6),
        vehicle = vector4(1027.58, -785.38, 57.48, 307.8),
        suspect = {
            vector4(1026.48, -784.58, 57.84, 309.0),
            vector4(1028.10, -787.18, 57.84, 8.6),
        },
    },
    -- Chien dangereux
    ['residential:11'] = {  -- Carson Avenue
        chien_dangereux = {
            caller  = vector4(-76.32, -1465.88, 32.10, 354.4),
            -- Le maître de l'animal est le MIS EN CAUSE, pas un
            suspect = vector4(-81.68, -1450.96, 31.96, 198.4),
            animal  = vector4(-80.46, -1454.88, 32.00, 14.2),
            victim  = vector4(-79.96, -1456.66, 32.04, 17.0),
        },
        animal  = vector4(-62.26, -1451.58, 32.12, 343.0),
        caller  = vector4(-65.56, -1454.30, 32.12, 317.4),
        suspect = vector4(-55.80, -1456.00, 32.10, 87.8),
    },
    ['residential:12'] = {  -- Roy Lowenstein Boulevard
        chien_dangereux = {
            caller  = vector4(325.78, -1698.20, 29.30, 252.2),
            -- Le maître de l'animal est le MIS EN CAUSE, pas un
            suspect = vector4(335.24, -1704.14, 29.30, 48.2),
            animal  = vector4(332.84, -1701.16, 29.28, 241.0),
            victim  = vector4(331.92, -1700.62, 29.28, 241.0),
        },
        suspect = vector4(380.46, -1651.70, 32.52, 42.6),
        caller  = vector4(388.54, -1656.72, 32.52, 48.2),
    },
    -- Vespucci Nord : scène complète, les quatre rôles figés.
    ['residential:15'] = {
        chien_dangereux = {
            caller  = vector4(-734.82, -889.92, 21.10, 8.6),
            suspect = vector4(-736.76, -874.64, 21.90, 192.8),
            animal  = vector4(-735.88, -879.00, 21.66, 241.0),
            victim  = vector4(-735.90, -880.14, 21.60, 0.0),
        },
        suspect = vector4(-735.82, -871.46, 22.08, 184.2),
        animal  = vector4(-735.16, -879.90, 21.64, 192.8),
        caller  = vector4(-734.66, -889.68, 21.10, 2.8),
        victim  = vector4(-735.58, -878.26, 21.72, 226.8),
    },
    ['residential:16'] = {  -- Morningwood
        chien_dangereux = {
            caller  = vector4(-1642.52, -352.54, 49.92, 258.0),
            suspect = vector4(-1633.10, -361.64, 48.06, 331.6),
            animal  = vector4(-1631.24, -357.50, 48.36, 348.6),
            victim  = vector4(-1629.92, -356.58, 48.48, 70.8),
        },
        caller = vector4(-1629.18, -356.88, 48.50, 110.6),
    },
    -- Vinewood Hills Sud : scène complète relevée sur le terrain.
    ['residential:19'] = {
        chien_dangereux = {
            caller  = vector4(334.42, -85.64, 68.38, 70.8),
            suspect = vector4(317.26, -78.72, 69.48, 62.4),
            animal  = vector4(321.90, -81.60, 69.18, 70.8),
            victim  = vector4(324.48, -82.44, 69.02, 70.8),
        },
        suspect = vector4(316.84, -78.40, 69.50, 235.2),
        animal  = vector4(323.80, -82.36, 69.06, 65.2),
        caller  = vector4(339.22, -87.56, 68.06, 70.8),
        victim  = vector4(320.78, -80.84, 69.24, 252.2),
    },
    ['residential:2'] = {   -- Richman Street
        chien_dangereux = {
            caller  = vector4(-1446.60, 22.60, 52.54, 8.6),
            suspect = vector4(-1448.16, 33.12, 52.66, 5.6),
            animal  = vector4(-1447.60, 29.34, 52.58, 5.6),
            victim  = vector4(-1447.32, 27.40, 52.58, 5.6),
        },
        suspect = vector4(-1400.80, 48.84, 53.24, 303.4),
    },
    ['residential:21'] = {  -- Mirror Park Est
        chien_dangereux = {
            caller  = vector4(1262.42, -425.88, 69.78, 48.2),
            suspect = vector4(1271.50, -427.04, 69.08, 207.0),
            animal  = vector4(1270.00, -423.66, 69.08, 207.0),
            victim  = vector4(1269.48, -422.54, 69.08, 207.0),
        },
        animal  = vector4(1255.50, -422.32, 69.44, 110.6),
        suspect = vector4(1256.14, -419.92, 69.42, 133.2),
        victim  = vector4(1253.24, -423.64, 69.44, 297.6),
        caller  = vector4(1262.18, -427.18, 69.78, 34.0),
    },
    ['residential:7'] = {   -- West Vinewood
        chien_dangereux = {
            caller  = vector4(107.02, 248.60, 108.06, 263.6),
            suspect = vector4(119.18, 245.44, 107.68, 65.2),
            animal  = vector4(116.28, 247.60, 107.80, 263.6),
            victim  = vector4(114.32, 247.84, 107.86, 263.6),
        },
        suspect = vector4(114.94, 247.86, 107.84, 79.4),
        caller  = vector4(111.14, 248.02, 107.96, 22.6),
    },

    -- Voie publique
    ['street:12'] = {      -- Eclipse Boulevard, racolage
        tuerie_masse = {
            victim = {
                vector4(-762.42, -18.36, 41.08, 192.8),
                vector4(-766.76, -10.36, 41.08, 28.4),
                vector4(-772.98, -0.24, 41.08, 25.6),
            },
            suspect = {
                vector4(-778.38, -3.98, 41.08, 209.8),
                vector4(-765.84, -25.26, 41.08, 215.4),
            },
            deceased = {
                vector4(-784.50, -5.40, 41.08, 17.0),
                vector4(-769.26, -5.98, 41.08, 204.0),
                vector4(-779.64, -1.28, 41.08, 28.4),
                vector4(-782.46, 4.18, 41.86, 90.8),
                vector4(-777.92, -9.78, 41.08, 297.6),
                vector4(-772.38, -13.90, 41.08, 209.8),
            },
            caller = vector4(-761.48, -16.92, 41.08, 76.6),
            bystander = {
                vector4(-758.94, -33.58, 37.82, 28.4),
                vector4(-756.10, -30.56, 37.82, 42.6),
                vector4(-768.28, -38.42, 37.82, 119.0),
                vector4(-766.08, -37.30, 37.82, 0.0),
            },
            vehicle = vector4(-758.12, -35.88, 37.30, 118.6),
        },
        vol_arrache = {
            caller  = vector4(-720.26, 9.04, 37.92, 226.8),
            victim  = vector4(-706.76, 1.16, 38.00, 326.0),
            suspect = {
                vector4(-706.32, 1.76, 38.00, 326.0),
                vector4(-707.44, 0.18, 37.96, 156.0),
            },
            bystander = {
                vector4(-699.52, 17.28, 38.36, 150.2),
                vector4(-697.94, -3.64, 38.16, 62.4),
                vector4(-695.42, -1.68, 38.26, 79.4),
                vector4(-692.68, -1.84, 38.32, 70.8),
            },
        },
        personne_armee = {
            caller  = vector4(-714.44, -67.32, 37.68, 221.2),
            suspect = vector4(-695.92, -85.58, 37.90, 348.6),
            bystander = {
                vector4(-709.18, -62.40, 37.68, 209.8),
                vector4(-710.32, -65.20, 37.68, 212.6),
                vector4(-672.76, -77.20, 37.88, 113.4),
                vector4(-672.44, -74.82, 37.86, 121.8),
            },
        },
        delit_fuite = {
            -- Requérant : celui du niveau générique de l'emplacement.
            victim  = vector4(-668.74, -53.48, 38.68, 138.8),
            vehicle = {
                vector4(-670.48, -54.76, 38.18, 202.4),
                vector4(-666.64, -55.14, 38.46, 103.2),
            },
            suspect = {
                vector4(-666.32, -52.62, 38.86, 116.2),
                vector4(-668.14, -46.38, 38.66, 190.0),
            },
            bystander = {
                vector4(-656.88, -44.90, 39.60, 130.4),
                vector4(-659.42, -44.92, 39.36, 113.4),
                vector4(-662.60, -65.98, 38.94, 31.2),
                vector4(-681.66, -53.70, 37.96, 263.6),
            },
        },
        bagarre_rue = {
            caller = vector4(-667.50, -67.42, 38.54, 36.8),
            suspect = {
                vector4(-681.98, -45.40, 38.04, 348.6),
                vector4(-680.54, -44.92, 38.10, 294.8),
                vector4(-681.86, -43.88, 38.10, 68.0),
                vector4(-683.42, -44.72, 38.00, 90.8),
            },
            bystander = {
                vector4(-690.82, -37.12, 37.88, 249.4),
                vector4(-682.26, -26.92, 38.28, 175.8),
                vector4(-671.64, -46.36, 38.44, 53.8),
                vector4(-673.12, -46.68, 38.34, 65.2),
            },
        },
        personne_errante = {
            caller   = vector4(-682.12, -49.60, 37.88, 334.4),
            wanderer = vector4(-681.36, -46.34, 38.00, 340.2),
        },
        decouverte_corps = {
            caller   = vector4(-664.72, -27.16, 38.96, 104.8),
            deceased = vector4(-658.62, -24.54, 39.38, 28.4),
        },
        racolage = {
            caller = vector4(-666.80, -69.32, 38.52, 45.4),
            suspect = {
                vector4(-677.70, -49.52, 38.10, 212.6),
                vector4(-668.80, -46.86, 38.64, 198.4),
                vector4(-661.18, -45.58, 39.20, 192.8),
            },
        },
        caller  = vector4(-685.34, -50.34, 37.84, 229.6),
        suspect = vector4(-674.76, -48.72, 38.24, 209.8),
    },
    ['street:13'] = {      -- Vespucci Boulevard
        vol_arrache = {
            caller  = vector4(-1203.28, -1168.08, 7.62, 99.2),
            victim  = vector4(-1226.08, -1171.06, 7.62, 121.8),
            suspect = {
                vector4(-1227.46, -1170.70, 7.62, 249.4),
                vector4(-1225.78, -1172.74, 7.62, 0.0),
            },
            bystander = {
                vector4(-1205.90, -1159.74, 7.72, 119.0),
                vector4(-1222.60, -1187.96, 7.70, 14.2),
                vector4(-1224.84, -1187.94, 7.70, 5.6),
                vector4(-1242.06, -1174.40, 7.50, 283.4),
            },
        },
        personne_armee = {
            caller  = vector4(-1196.80, -1196.50, 7.68, 56.6),
            suspect = vector4(-1223.74, -1183.86, 7.72, 11.4),
            bystander = {
                vector4(-1216.74, -1213.30, 7.68, 2.8),
                vector4(-1222.34, -1213.28, 7.62, 354.4),
                vector4(-1203.08, -1170.64, 7.62, 127.6),
                vector4(-1203.50, -1167.62, 7.62, 130.4),
            },
        },
        delit_fuite = {
            -- Requérant : celui du niveau générique de l'emplacement.
            victim  = vector4(-1191.78, -1206.12, 7.56, 22.6),
            vehicle = {
                vector4(-1194.92, -1207.86, 7.22, 306.8),
                vector4(-1192.60, -1204.54, 7.16, 99.6),
            },
            suspect = {
                vector4(-1194.58, -1209.74, 7.54, 314.6),
                vector4(-1196.30, -1206.90, 7.68, 303.4),
            },
            bystander = {
                vector4(-1198.90, -1199.48, 7.58, 212.6),
                vector4(-1197.12, -1199.78, 7.62, 212.6),
                vector4(-1189.42, -1212.04, 7.66, 56.6),
                vector4(-1187.16, -1210.80, 7.66, 56.6),
            },
        },
        bagarre_rue = {
            caller = vector4(-1197.98, -1197.64, 7.68, 351.4),
            suspect = {
                vector4(-1198.74, -1187.36, 7.68, 314.6),
                vector4(-1197.82, -1186.58, 7.68, 309.0),
                vector4(-1198.88, -1185.34, 7.68, 42.6),
                vector4(-1199.78, -1186.74, 7.68, 144.6),
            },
            bystander = {
                vector4(-1197.16, -1176.24, 7.70, 158.8),
                vector4(-1197.54, -1174.18, 7.70, 161.6),
                vector4(-1193.82, -1201.74, 7.64, 8.6),
                vector4(-1195.38, -1201.46, 7.60, 2.8),
            },
        },
        personne_errante = {
            caller   = vector4(-1223.28, -1207.56, 7.68, 280.6),
            wanderer = vector4(-1221.48, -1208.24, 7.68, 266.4),
        },
        decouverte_corps = {
            caller   = vector4(-1173.20, -1196.04, 4.86, 215.4),
            deceased = vector4(-1176.14, -1190.84, 5.62, 283.4),
        },
        racolage = {
            caller = vector4(-1193.18, -1198.20, 7.64, 124.8),
            suspect = {
                vector4(-1186.88, -1210.76, 7.64, 11.4),
                vector4(-1178.10, -1208.46, 6.00, 11.4),
                vector4(-1167.16, -1206.58, 4.36, 14.2),
            },
        },
        caller = vector4(-1187.76, -1199.82, 7.50, 297.6),
    },
    ['street:14'] = {      -- Davis Avenue
        vol_arrache = {
            caller  = vector4(120.06, -1467.38, 29.30, 127.6),
            victim  = vector4(105.76, -1478.42, 29.28, 133.2),
            suspect = {
                vector4(104.92, -1479.30, 29.28, 320.4),
                vector4(104.48, -1477.42, 29.28, 241.0),
            },
            bystander = {
                vector4(120.90, -1471.56, 29.22, 113.4),
                vector4(94.54, -1491.18, 29.28, 323.2),
                vector4(98.22, -1493.36, 29.28, 331.6),
                vector4(101.18, -1492.40, 29.26, 340.2),
            },
        },
        personne_armee = {
            caller  = vector4(152.86, -1442.76, 29.22, 104.8),
            suspect = vector4(129.30, -1451.92, 29.28, 326.0),
            bystander = {
                vector4(160.58, -1449.34, 29.22, 96.4),
                vector4(158.34, -1447.86, 29.22, 70.8),
                vector4(117.04, -1467.82, 29.28, 320.4),
                vector4(116.34, -1466.00, 29.30, 337.4),
            },
        },
        delit_fuite = {
            caller  = vector4(116.18, -1464.76, 29.30, 116.2),
            victim  = vector4(110.46, -1469.26, 29.22, 354.4),
            vehicle = {
                vector4(111.20, -1466.74, 28.84, 47.6),
                vector4(107.72, -1468.58, 28.80, 319.4),
            },
            suspect = {
                vector4(108.32, -1471.24, 29.22, 320.4),
                vector4(110.16, -1471.32, 29.28, 8.6),
            },
            bystander = {
                vector4(105.38, -1475.28, 29.28, 328.8),
                vector4(110.54, -1475.76, 29.28, 348.6),
                vector4(120.62, -1469.68, 29.24, 62.4),
                vector4(120.30, -1466.92, 29.30, 85.0),
            },
        },
        bagarre_rue = {
            caller = vector4(169.78, -1457.56, 29.22, 107.8),
            suspect = {
                vector4(165.68, -1461.76, 29.12, 127.6),
                vector4(164.26, -1462.94, 29.12, 127.6),
                vector4(163.36, -1461.76, 29.12, 34.0),
                vector4(164.66, -1460.46, 29.12, 17.0),
            },
            bystander = {
                vector4(163.02, -1449.42, 29.22, 175.8),
                vector4(158.82, -1448.02, 29.22, 192.8),
                vector4(164.10, -1471.68, 29.12, 11.4),
                vector4(166.08, -1473.38, 29.12, 19.8),
            },
        },
        personne_errante = {
            caller   = vector4(142.84, -1519.98, 29.84, 348.6),
            wanderer = vector4(142.58, -1517.52, 29.12, 294.8),
        },
        decouverte_corps = {
            caller   = vector4(177.62, -1516.74, 29.12, 136.0),
            deceased = vector4(185.98, -1507.58, 29.12, 130.4),
        },
        racolage = {
            caller = vector4(165.46, -1505.24, 29.22, 116.2),
            suspect = {
                vector4(130.82, -1511.20, 29.12, 226.8),
                vector4(134.58, -1507.20, 29.12, 207.0),
                vector4(139.36, -1501.10, 29.12, 226.8),
            },
        },
        deceased = vector4(138.00, -1480.04, 29.32, 17.0),
    },
    ['street:17'] = {      -- Cypress Flats
        personne_armee = {
            caller  = vector4(896.90, -1899.24, 30.62, 0.0),
            suspect = vector4(890.84, -1853.40, 30.62, 90.8),
            bystander = {
                vector4(902.58, -1821.38, 32.86, 158.8),
                vector4(904.36, -1814.62, 30.62, 161.6),
                vector4(904.36, -1812.00, 30.62, 161.6),
                vector4(896.44, -1908.56, 30.62, 0.0),
            },
        },
        delit_fuite = {
            caller  = vector4(942.14, -1884.64, 31.08, 292.0),
            victim  = vector4(955.42, -1882.50, 31.18, 76.6),
            vehicle = {
                vector4(956.16, -1881.08, 30.76, 84.4),
                vector4(952.42, -1880.96, 30.74, 355.6),
            },
            suspect = {
                vector4(953.30, -1884.24, 31.20, 320.4),
                vector4(951.50, -1884.48, 31.18, 286.2),
            },
            bystander = {
                vector4(956.96, -1893.28, 31.16, 17.0),
                vector4(959.64, -1892.34, 31.18, 17.0),
                vector4(941.20, -1888.60, 31.10, 297.6),
                vector4(941.30, -1891.34, 31.08, 300.4),
            },
        },
        personne_errante = {
            caller   = vector4(939.54, -1877.76, 32.46, 269.2),
            wanderer = vector4(941.06, -1878.90, 31.10, 263.6),
        },
        decouverte_corps = {
            caller   = vector4(921.88, -1893.40, 30.66, 175.8),
            deceased = vector4(921.50, -1890.08, 30.64, 235.2),
        },
        caller = vector4(897.68, -1898.42, 30.62, 107.8),
    },
    -- Vespucci Beach : la bagarre et le délit de fuite ne se jouent pas
    ['street:2'] = {
        tuerie_masse = {
            victim = {
                vector4(-1250.98, -1514.88, 4.32, 263.6),
                vector4(-1250.88, -1507.72, 4.44, 357.2),
                vector4(-1257.02, -1502.88, 4.74, 45.4),
            },
            suspect = {
                vector4(-1263.02, -1516.84, 4.30, 127.6),
                vector4(-1268.34, -1512.04, 4.30, 45.4),
            },
            deceased = {
                vector4(-1276.12, -1515.74, 4.30, 241.0),
                vector4(-1271.80, -1523.66, 4.30, 252.2),
                vector4(-1275.92, -1528.98, 4.30, 317.4),
                vector4(-1266.32, -1524.28, 4.30, 87.8),
                vector4(-1258.12, -1526.70, 4.30, 272.2),
                vector4(-1279.72, -1507.98, 4.42, 79.4),
            },
            caller = vector4(-1223.12, -1503.82, 4.32, 110.6),
            bystander = {
                vector4(-1236.98, -1499.40, 4.36, 28.4),
                vector4(-1235.36, -1502.50, 4.34, 133.2),
                vector4(-1242.14, -1535.46, 4.30, 334.4),
                vector4(-1243.58, -1539.12, 4.30, 68.0),
            },
            vehicle = vector4(-1261.30, -1484.36, 3.94, 160.2),
        },
        vol_arrache = {
            caller  = vector4(-1233.48, -1470.88, 4.30, 53.8),
            victim  = vector4(-1251.18, -1463.10, 4.26, 28.4),
            suspect = {
                vector4(-1250.10, -1464.48, 4.26, 28.4),
                vector4(-1252.64, -1461.12, 4.28, 221.2),
            },
            bystander = {
                vector4(-1238.62, -1476.80, 4.34, 42.6),
                vector4(-1237.34, -1475.54, 4.30, 45.4),
                vector4(-1263.98, -1464.40, 4.34, 280.6),
                vector4(-1265.82, -1460.10, 4.40, 263.6),
            },
        },
        personne_armee = {
            caller  = vector4(-1236.68, -1480.16, 4.36, 150.2),
            suspect = vector4(-1249.02, -1507.12, 4.42, 275.0),
            bystander = {
                vector4(-1231.58, -1485.46, 4.36, 138.8),
                vector4(-1225.02, -1497.50, 4.36, 99.2),
                vector4(-1231.38, -1511.06, 4.34, 73.8),
                vector4(-1248.12, -1488.50, 4.34, 340.2),
            },
        },
        personne_errante = {
            caller   = vector4(-1237.80, -1504.44, 4.32, 309.0),
            wanderer = vector4(-1235.50, -1502.66, 4.34, 309.0),
        },
        decouverte_corps = {
            caller   = vector4(-1203.48, -1480.32, 4.38, 241.0),
            deceased = vector4(-1207.96, -1480.48, 4.36, 246.6),
        },
        racolage = {
            caller = vector4(-1225.14, -1491.30, 4.34, 124.8),
            suspect = {
                vector4(-1243.54, -1491.92, 4.34, 320.4),
                vector4(-1241.12, -1495.36, 4.34, 300.4),
                vector4(-1238.02, -1498.98, 4.34, 309.0),
            },
        },
        bagarre_rue = {
            caller = vector4(-1242.66, -1495.50, 4.34, 124.8),
            suspect = {
                vector4(-1246.86, -1499.64, 4.56, 127.6),
                vector4(-1247.80, -1500.42, 4.56, 127.6),
                vector4(-1246.72, -1501.66, 4.52, 226.8),
                vector4(-1245.86, -1500.26, 4.52, 328.8),
            },
            bystander = {
                vector4(-1238.84, -1503.96, 4.32, 82.2),
                vector4(-1237.42, -1507.60, 4.32, 68.0),
                vector4(-1247.16, -1514.38, 4.32, 22.6),
                vector4(-1259.60, -1511.64, 4.32, 323.2),
            },
        },
        delit_fuite = {
            caller  = vector4(-1188.28, -1508.28, 4.38, 2.8),
            victim  = vector4(-1197.18, -1491.60, 4.38, 323.2),
            vehicle = {
                vector4(-1196.34, -1488.60, 3.98, 124.8),
                vector4(-1194.34, -1491.72, 3.98, 37.2),
            },
            suspect = {
                vector4(-1195.64, -1493.62, 4.38, 25.6),
                vector4(-1192.54, -1490.26, 4.38, 76.6),
            },
            bystander = {
                vector4(-1187.54, -1482.42, 4.38, 138.8),
                vector4(-1190.04, -1479.38, 4.38, 153.0),
                vector4(-1182.54, -1489.28, 4.38, 87.8),
                vector4(-1185.82, -1485.12, 4.38, 113.4),
            },
        },
    },
    -- Bay City Avenue : scène complète du délit de fuite.
    ['street:23'] = {
        vol_arrache = {
            caller  = vector4(-833.98, -1023.82, 13.28, 190.0),
            victim  = vector4(-831.00, -1039.10, 13.24, 345.8),
            suspect = {
                vector4(-830.98, -1040.96, 13.22, 0.0),
                vector4(-829.36, -1040.00, 13.22, 62.4),
            },
            bystander = {
                vector4(-837.68, -1028.90, 13.30, 215.4),
                vector4(-836.82, -1052.42, 10.96, 337.4),
                vector4(-835.56, -1054.54, 10.96, 345.8),
                vector4(-833.06, -1053.78, 10.96, 348.6),
            },
        },
        personne_armee = {
            caller  = vector4(-821.86, -1055.00, 12.86, 65.2),
            suspect = vector4(-844.50, -1048.16, 11.26, 303.4),
            bystander = {
                vector4(-851.64, -1063.02, 9.36, 331.6),
                vector4(-847.68, -1064.68, 9.72, 351.4),
                vector4(-858.52, -1051.84, 8.22, 269.2),
                vector4(-862.36, -1050.80, 7.54, 277.8),
            },
        },
        delit_fuite = {
            caller  = vector4(-816.80, -1081.18, 11.12, 212.6),
            victim  = vector4(-812.50, -1088.14, 10.92, 226.8),
            vehicle = {
                vector4(-812.24, -1090.54, 10.48, 266.2),
                vector4(-809.96, -1087.04, 10.56, 170.2),
            },
            suspect = {
                vector4(-811.72, -1085.60, 11.00, 170.0),
                vector4(-808.10, -1089.78, 10.90, 90.8),
            },
            bystander = {
                vector4(-799.54, -1091.74, 10.94, 62.4),
                vector4(-797.74, -1090.74, 10.94, 62.4),
                vector4(-820.58, -1098.74, 11.14, 309.0),
                vector4(-822.40, -1094.96, 11.14, 294.8),
            },
        },
        bagarre_rue = {
            caller = vector4(-818.90, -1081.26, 11.12, 215.4),
            suspect = {
                vector4(-815.56, -1086.22, 10.98, 212.6),
                vector4(-814.16, -1085.30, 10.98, 306.2),
                vector4(-813.56, -1086.68, 10.94, 229.6),
                vector4(-813.96, -1087.06, 10.94, 127.6),
            },
            bystander = {
                vector4(-825.52, -1090.52, 11.14, 297.6),
                vector4(-824.46, -1092.32, 11.14, 275.0),
                vector4(-808.68, -1076.50, 11.64, 158.8),
                vector4(-797.64, -1090.46, 10.94, 82.2),
            },
        },
        personne_errante = {
            caller   = vector4(-822.16, -1098.94, 11.14, 266.4),
            wanderer = vector4(-822.48, -1096.86, 11.14, 36.8),
        },
        decouverte_corps = {
            caller   = vector4(-834.52, -1070.96, 11.36, 328.8),
            deceased = vector4(-838.50, -1068.14, 11.02, 218.2),
        },
        racolage = {
            caller = vector4(-814.60, -1079.38, 11.12, 207.0),
            suspect = {
                vector4(-808.96, -1070.30, 11.98, 303.4),
                vector4(-797.14, -1091.48, 10.92, 300.4),
                vector4(-791.74, -1100.72, 10.64, 297.6),
            },
        },
        caller  = vector4(-824.60, -1091.62, 11.14, 323.2),
        suspect = vector4(-819.00, -1080.60, 11.12, 258.0),
        victim  = vector4(-813.72, -1078.04, 11.12, 221.2),
    },
    ['street:19'] = {      -- Downtown Vinewood
        bagarre_rue = {
            caller = vector4(250.74, 87.94, 94.08, 207.0),
            suspect = {
                vector4(257.84, 73.34, 94.38, 85.0),
                vector4(257.74, 71.98, 94.38, 65.2),
                vector4(256.58, 72.50, 94.38, 62.4),
                vector4(257.24, 73.82, 94.36, 331.6),
            },
            bystander = {
                vector4(281.12, 67.10, 94.36, 85.0),
                vector4(281.74, 68.82, 94.36, 87.8),
                vector4(283.50, 66.98, 94.36, 76.6),
                vector4(284.76, 68.08, 94.36, 76.6),
            },
        },
        personne_errante = {
            caller   = vector4(238.08, 92.94, 93.66, 124.8),
            wanderer = vector4(241.38, 93.74, 93.92, 331.6),
        },
        decouverte_corps = {
            caller   = vector4(245.50, 115.14, 102.52, 300.4),
            deceased = vector4(249.88, 111.78, 101.96, 334.4),
        },
        racolage = {
            caller = vector4(263.36, 134.98, 103.44, 345.8),
            suspect = {
                vector4(263.24, 155.76, 104.62, 343.0),
                vector4(280.08, 149.64, 104.30, 328.8),
                vector4(289.30, 146.82, 104.10, 340.2),
            },
        },
        suspect = vector4(251.08, 99.12, 96.58, 331.6),
    },
    -- Vespucci Boulevard Est : la victime est décalée d'un mètre du
    ['street:22'] = {
        tuerie_masse = {
            victim = {
                vector4(-268.20, -982.18, 31.20, 119.0),
                vector4(-269.76, -980.08, 31.20, 79.4),
                vector4(-248.94, -970.20, 31.22, 317.4),
            },
            suspect = {
                vector4(-260.06, -979.02, 31.22, 272.2),
                vector4(-256.66, -978.42, 31.22, 277.8),
            },
            deceased = {
                vector4(-262.70, -981.70, 31.22, 73.8),
                vector4(-260.68, -974.64, 31.22, 0.0),
                vector4(-250.04, -973.64, 31.22, 294.8),
                vector4(-254.10, -984.74, 31.22, 246.6),
                vector4(-255.08, -974.38, 31.22, 323.2),
                vector4(-260.96, -970.88, 31.22, 209.8),
            },
            caller = vector4(-267.54, -954.64, 31.22, 198.4),
            bystander = {
                vector4(-276.94, -979.76, 31.20, 252.2),
                vector4(-241.96, -991.06, 29.28, 317.4),
                vector4(-237.66, -980.72, 29.28, 343.0),
                vector4(-244.48, -961.08, 31.22, 343.0),
            },
            vehicle = vector4(-311.80, -985.86, 30.68, 162.2),
        },
        vol_arrache = {
            caller  = vector4(-240.22, -945.28, 31.22, 45.4),
            victim  = vector4(-255.54, -930.40, 31.22, 56.6),
            suspect = {
                vector4(-256.16, -930.30, 31.22, 260.8),
                vector4(-253.90, -930.92, 31.22, 70.8),
            },
            bystander = {
                vector4(-234.70, -937.96, 31.22, 68.0),
                vector4(-234.30, -936.76, 31.22, 73.8),
                vector4(-268.44, -932.16, 31.22, 275.0),
                vector4(-268.36, -934.24, 31.22, 280.6),
            },
        },
        personne_armee = {
            caller  = vector4(-277.72, -907.28, 31.80, 51.0),
            suspect = vector4(-300.90, -891.92, 31.06, 255.2),
            bystander = {
                vector4(-268.76, -900.88, 32.32, 76.6),
                vector4(-268.26, -896.70, 32.12, 65.2),
                vector4(-282.40, -878.14, 31.68, 156.0),
                vector4(-286.16, -877.14, 31.72, 164.4),
            },
        },
        bagarre_rue = {
            caller = vector4(-249.86, -970.84, 31.22, 130.4),
            suspect = {
                vector4(-253.92, -977.70, 31.22, 150.2),
                vector4(-254.94, -976.64, 31.22, 36.8),
                vector4(-256.40, -977.46, 31.22, 119.0),
                vector4(-255.70, -978.92, 31.22, 167.2),
            },
            bystander = {
                vector4(-261.46, -985.64, 31.20, 314.6),
                vector4(-263.54, -982.36, 31.22, 283.4),
                vector4(-265.22, -979.42, 31.22, 292.0),
                vector4(-264.36, -976.48, 31.22, 280.6),
            },
        },
        personne_errante = {
            caller   = vector4(-257.68, -974.40, 31.22, 289.2),
            wanderer = vector4(-255.34, -974.96, 31.22, 246.6),
        },
        racolage = {
            caller = vector4(-245.40, -954.72, 31.22, 243.8),
            suspect = {
                vector4(-226.86, -955.80, 29.28, 249.4),
                vector4(-225.34, -950.62, 29.28, 252.2),
                vector4(-228.94, -961.56, 29.28, 246.6),
            },
        },
        caller  = vector4(-248.38, -969.80, 31.22, 345.8),
        suspect = vector4(-246.50, -962.26, 31.22, 156.0),
        victim  = vector4(-245.60, -963.10, 31.22, 336.0),
    },
    ['street:4'] = {       -- Grove Street
        vol_arrache = {
            caller  = vector4(74.22, -1902.96, 21.54, 42.6),
            victim  = vector4(58.98, -1889.34, 21.60, 297.6),
            suspect = {
                vector4(60.20, -1888.64, 21.62, 215.4),
                vector4(57.94, -1890.68, 21.54, 331.6),
            },
            bystander = {
                vector4(78.82, -1893.92, 22.16, 73.8),
                vector4(80.26, -1891.62, 22.38, 85.0),
                vector4(47.88, -1901.82, 21.62, 320.4),
                vector4(50.12, -1903.84, 21.50, 326.0),
            },
        },
        personne_armee = {
            caller  = vector4(98.28, -1923.86, 20.74, 184.2),
            suspect = vector4(106.00, -1940.60, 20.78, 48.2),
            bystander = {
                vector4(118.64, -1929.48, 20.74, 124.8),
                vector4(118.80, -1949.74, 20.74, 153.0),
                vector4(120.64, -1944.48, 20.74, 73.8),
                vector4(120.94, -1945.18, 20.74, 70.8),
            },
        },
        delit_fuite = {
            caller  = vector4(108.14, -1953.96, 20.78, 340.2),
            victim  = vector4(109.00, -1946.76, 20.78, 19.8),
            vehicle = {
                vector4(111.14, -1945.68, 20.36, 51.0),
                vector4(107.80, -1943.84, 20.42, 320.4),
            },
            suspect = {
                vector4(106.66, -1947.30, 20.78, 306.2),
                vector4(107.68, -1948.62, 20.76, 343.0),
            },
            bystander = {
                vector4(118.04, -1941.12, 20.62, 119.0),
                vector4(117.42, -1936.88, 20.74, 136.0),
                vector4(115.56, -1931.44, 20.78, 150.2),
                vector4(110.88, -1927.94, 20.78, 175.8),
            },
        },
        bagarre_rue = {
            caller = vector4(90.40, -1958.92, 20.86, 150.2),
            suspect = {
                vector4(89.62, -1967.96, 20.74, 79.4),
                vector4(88.44, -1967.68, 20.74, 68.0),
                vector4(88.70, -1969.94, 20.74, 68.0),
                vector4(88.12, -1969.10, 20.74, 59.6),
            },
            bystander = {
                vector4(100.70, -1957.12, 20.74, 133.2),
                vector4(95.98, -1954.24, 20.76, 153.0),
                vector4(94.76, -1952.64, 20.74, 158.8),
                vector4(92.80, -1954.48, 20.76, 150.2),
            },
        },
        personne_errante = {
            caller   = vector4(111.62, -1958.32, 20.80, 19.8),
            wanderer = vector4(110.72, -1956.56, 20.74, 25.6),
        },
        decouverte_corps = {
            caller   = vector4(84.64, -1908.72, 21.10, 141.8),
            deceased = vector4(88.28, -1904.06, 21.14, 326.0),
        },
        racolage = {
            caller = vector4(85.50, -1958.52, 21.10, 328.8),
            suspect = {
                vector4(92.42, -1945.88, 20.78, 320.4),
                vector4(108.96, -1953.34, 20.78, 28.4),
                vector4(85.98, -1934.82, 20.78, 309.0),
            },
        },
        caller    = vector4(87.54, -1950.64, 20.82, 241.0),
        suspect   = vector4(93.76, -1963.84, 20.74, 334.4),
        deceased  = vector4(76.64, -1936.74, 20.94, 258.0),
        bystander = {
            vector4(80.28, -1934.74, 20.74, 127.6),
            vector4(78.14, -1933.34, 20.76, 156.0),
        },
    },
    ['street:6'] = {       -- Mirror Park, racolage
        vol_arrache = {
            victim = vector4(1058.52, -503.82, 62.60, 351.4),
            suspect = {
                vector4(1058.72, -502.74, 62.66, 351.4),
                vector4(1057.28, -503.90, 62.56, 283.4),
            },
            caller = vector4(1047.44, -506.06, 63.88, 277.8),
            bystander = {
                vector4(1061.64, -487.64, 63.50, 167.2),
                vector4(1060.06, -487.32, 63.50, 170.0),
                vector4(1049.28, -512.08, 61.88, 314.6),
                vector4(1050.44, -512.44, 61.92, 309.0),
            },
        },
        personne_armee = {
            caller  = vector4(1145.90, -453.40, 66.98, 192.8),
            suspect = vector4(1152.82, -474.56, 66.50, 184.2),
            bystander = {
                vector4(1160.26, -455.48, 66.98, 147.4),
                vector4(1161.82, -456.18, 66.98, 195.6),
                vector4(1137.90, -476.04, 66.38, 266.4),
                vector4(1138.04, -474.76, 66.46, 260.8),
            },
        },
        delit_fuite = {
            caller  = vector4(1053.92, -480.98, 63.92, 243.8),
            victim  = vector4(1055.54, -486.84, 63.76, 246.6),
            vehicle = {
                vector4(1059.58, -486.16, 63.22, 123.2),
                vector4(1056.06, -488.80, 63.26, 257.2),
            },
            suspect = {
                vector4(1058.60, -484.50, 63.68, 136.0),
                vector4(1060.28, -488.36, 63.46, 79.4),
            },
            bystander = {
                vector4(1058.30, -495.82, 63.02, 348.6),
                vector4(1060.14, -496.08, 63.04, 2.8),
                vector4(1063.70, -478.40, 64.00, 153.0),
                vector4(1061.66, -477.12, 64.06, 175.8),
            },
        },
        bagarre_rue = {
            caller = vector4(1075.14, -525.82, 62.50, 153.0),
            suspect = {
                vector4(1072.32, -535.34, 61.62, 158.8),
                vector4(1070.96, -534.80, 61.60, 65.2),
                vector4(1071.86, -533.60, 61.74, 326.0),
                vector4(1073.00, -534.28, 61.76, 156.0),
            },
            bystander = {
                vector4(1082.18, -530.70, 62.42, 110.6),
                vector4(1058.60, -533.06, 61.42, 266.4),
                vector4(1058.66, -534.84, 61.34, 277.8),
                vector4(1065.04, -543.34, 60.48, 326.0),
            },
        },
        personne_errante = {
            caller   = vector4(1091.74, -463.78, 66.78, 82.2),
            wanderer = vector4(1088.44, -463.46, 65.02, 82.2),
        },
        decouverte_corps = {
            caller   = vector4(1061.52, -495.38, 63.08, 272.2),
            deceased = vector4(1056.64, -498.36, 63.00, 79.4),
        },
        racolage = {
            caller = vector4(1087.24, -483.86, 65.14, 73.8),
            suspect = {
                vector4(1065.86, -478.38, 64.00, 249.4),
                vector4(1067.92, -467.12, 64.64, 255.2),
                vector4(1061.64, -499.80, 62.90, 260.8),
            },
        },
        caller = vector4(1087.22, -483.14, 65.16, 68.0),
    },
    ['street:7'] = {       -- Rockford Hills
        vol_arrache = {
            caller  = vector4(-1385.98, -361.86, 37.04, 249.4),
            victim  = vector4(-1374.18, -364.72, 36.62, 309.0),
            suspect = {
                vector4(-1372.70, -363.62, 36.68, 309.0),
                vector4(-1373.36, -366.26, 36.60, 28.4),
            },
            bystander = {
                vector4(-1361.20, -359.24, 36.68, 107.8),
                vector4(-1361.78, -357.74, 36.68, 119.0),
                vector4(-1389.18, -357.68, 37.46, 241.0),
                vector4(-1388.18, -357.20, 37.44, 241.0),
            },
        },
        personne_armee = {
            caller  = vector4(-1343.60, -411.52, 35.98, 328.8),
            suspect = vector4(-1333.80, -391.86, 36.62, 130.4),
            bystander = {
                vector4(-1316.34, -385.52, 36.62, 99.2),
                vector4(-1315.72, -392.16, 36.54, 85.0),
                vector4(-1322.38, -376.34, 36.72, 153.0),
                vector4(-1325.64, -376.24, 36.72, 144.6),
            },
        },
        delit_fuite = {
            -- Requérant : celui du niveau générique de l'emplacement.
            victim  = vector4(-1334.80, -377.78, 36.58, 297.6),
            vehicle = {
                vector4(-1332.74, -377.18, 36.26, 357.2),
                vector4(-1336.30, -376.26, 36.28, 294.0),
            },
            suspect = {
                vector4(-1333.96, -373.56, 36.72, 201.2),
                vector4(-1337.10, -379.18, 36.58, 297.6),
            },
            bystander = {
                vector4(-1335.96, -385.08, 36.72, 340.2),
                vector4(-1339.24, -382.40, 36.72, 326.0),
                vector4(-1318.54, -382.06, 36.72, 73.8),
                vector4(-1317.50, -383.64, 36.68, 65.2),
            },
        },
        bagarre_rue = {
            caller = vector4(-1318.16, -383.32, 36.70, 116.2),
            suspect = {
                vector4(-1324.04, -387.02, 36.56, 121.8),
                vector4(-1324.36, -386.48, 36.58, 25.6),
                vector4(-1325.94, -387.20, 36.58, 113.4),
                vector4(-1325.24, -388.64, 36.54, 212.6),
            },
            bystander = {
                vector4(-1325.36, -399.74, 36.60, 348.6),
                vector4(-1326.90, -401.06, 36.60, 351.4),
                vector4(-1336.30, -384.94, 36.72, 238.2),
                vector4(-1337.56, -385.12, 36.72, 241.0),
            },
        },
        personne_errante = {
            caller   = vector4(-1328.74, -402.50, 36.60, 25.6),
            wanderer = vector4(-1330.12, -399.86, 36.40, 25.6),
        },
        caller = vector4(-1322.70, -377.68, 36.72, 42.6),
        racolage = {
            suspect = vector4(-1328.00, -376.30, 36.72, 39.6),
        },
    },
    -- Strawberry : les badauds encadrent le corps, dont la mise en scène
    ['street:9'] = {
        vol_arrache = {
            caller  = vector4(249.16, -1810.70, 27.16, 221.2),
            victim  = vector4(258.84, -1823.50, 26.78, 238.2),
            suspect = {
                vector4(259.84, -1824.26, 26.76, 53.8),
                vector4(257.76, -1824.82, 26.76, 320.4),
            },
            bystander = {
                vector4(272.40, -1831.36, 26.72, 62.4),
                vector4(272.52, -1830.48, 26.74, 59.6),
                vector4(272.30, -1829.42, 26.76, 65.2),
                vector4(272.56, -1828.58, 26.78, 79.4),
            },
        },
        personne_armee = {
            caller  = vector4(348.14, -1814.58, 28.48, 2.8),
            suspect = vector4(349.86, -1803.38, 28.56, 51.0),
            bystander = {
                vector4(340.08, -1816.32, 28.06, 314.6),
                vector4(341.16, -1817.02, 28.12, 337.4),
                vector4(367.30, -1802.72, 29.06, 102.0),
                vector4(366.52, -1802.00, 29.08, 93.6),
            },
        },
        delit_fuite = {
            caller  = vector4(293.88, -1800.02, 27.58, 178.6),
            victim  = vector4(294.94, -1806.98, 27.22, 167.2),
            vehicle = {
                vector4(294.22, -1809.10, 26.78, 230.6),
                vector4(297.24, -1807.46, 26.70, 140.0),
            },
            suspect = {
                vector4(296.48, -1805.72, 27.32, 147.4),
                vector4(294.70, -1805.20, 27.32, 173.0),
            },
            bystander = {
                vector4(304.04, -1796.08, 27.72, 147.4),
                vector4(303.08, -1797.66, 27.68, 147.4),
                vector4(286.68, -1806.48, 27.20, 249.4),
                vector4(289.06, -1812.94, 27.08, 294.8),
            },
        },
        bagarre_rue = {
            caller = vector4(295.62, -1803.80, 27.42, 70.8),
            suspect = {
                vector4(289.08, -1803.42, 27.26, 65.2),
                vector4(287.64, -1804.32, 27.22, 113.4),
                vector4(287.86, -1802.42, 27.20, 76.6),
                vector4(286.34, -1803.20, 27.14, 153.0),
            },
            bystander = {
                vector4(289.68, -1813.02, 27.08, 11.4),
                vector4(288.44, -1812.26, 27.10, 22.6),
                vector4(290.58, -1812.20, 27.02, 17.0),
                vector4(291.58, -1811.00, 27.08, 34.0),
            },
        },
        personne_errante = {
            caller   = vector4(308.40, -1781.06, 28.50, 212.6),
            wanderer = vector4(311.20, -1781.08, 28.38, 337.4),
        },
        racolage = {
            caller = vector4(289.00, -1792.64, 28.08, 238.2),
            suspect = {
                vector4(297.00, -1804.02, 27.42, 232.4),
                vector4(301.30, -1798.72, 27.66, 226.8),
                vector4(304.98, -1794.14, 27.86, 229.6),
            },
        },
        decouverte_corps = {
            caller   = vector4(291.24, -1803.20, 27.40, 232.4),
            deceased = vector4(283.00, -1804.92, 27.10, 328.8),
            bystander = {
                vector4(298.86, -1801.48, 27.54, 345.8),
                vector4(295.10, -1800.48, 27.54, 309.0),
            },
        },
    },
    ['street:8'] = {       -- Textile City
        vol_arrache = {
            caller  = vector4(276.32, -1110.94, 29.40, 181.4),
            victim  = vector4(275.82, -1120.66, 29.36, 300.4),
            suspect = {
                vector4(277.14, -1120.68, 29.38, 87.8),
                vector4(274.32, -1120.98, 29.38, 272.2),
            },
            bystander = {
                vector4(288.32, -1117.30, 29.42, 107.8),
                vector4(288.62, -1121.58, 29.42, 82.2),
                vector4(274.48, -1138.62, 29.38, 357.2),
                vector4(275.82, -1138.64, 29.38, 2.8),
            },
        },
        personne_armee = {
            caller  = vector4(241.98, -1193.24, 29.32, 8.6),
            suspect = vector4(237.52, -1174.70, 29.28, 119.0),
            bystander = {
                vector4(249.08, -1189.46, 29.48, 79.4),
                vector4(246.76, -1189.60, 29.44, 28.4),
                vector4(248.58, -1192.66, 29.40, 22.6),
                vector4(249.92, -1193.04, 29.40, 31.2),
            },
        },
        delit_fuite = {
            caller  = vector4(236.08, -1151.38, 29.30, 130.4),
            victim  = vector4(232.10, -1159.20, 29.18, 62.4),
            vehicle = {
                vector4(230.04, -1157.24, 28.76, 100.8),
                vector4(229.36, -1161.16, 28.76, 9.6),
            },
            suspect = {
                vector4(231.30, -1162.02, 29.14, 11.4),
                vector4(233.02, -1161.38, 29.18, 36.8),
            },
            bystander = {
                vector4(232.98, -1170.78, 29.28, 14.2),
                vector4(235.62, -1167.88, 29.28, 25.6),
                vector4(230.90, -1146.94, 29.30, 184.2),
                vector4(229.06, -1147.02, 29.30, 187.0),
            },
        },
        bagarre_rue = {
            caller = vector4(268.78, -1154.70, 29.28, 87.8),
            suspect = {
                vector4(259.10, -1156.16, 29.26, 96.4),
                vector4(258.98, -1154.70, 29.28, 0.0),
                vector4(257.36, -1154.70, 29.28, 82.2),
                vector4(257.20, -1156.32, 29.26, 178.6),
            },
            bystander = {
                vector4(259.74, -1141.50, 29.34, 164.4),
                vector4(254.00, -1141.52, 29.34, 207.0),
                vector4(242.22, -1142.50, 29.30, 221.2),
                vector4(233.58, -1150.92, 29.26, 258.0),
            },
        },
        personne_errante = {
            caller   = vector4(268.02, -1155.62, 29.28, 93.6),
            wanderer = vector4(265.18, -1155.68, 29.28, 70.8),
        },
        decouverte_corps = {
            caller   = vector4(257.24, -1166.92, 29.32, 82.2),
            deceased = vector4(253.64, -1169.32, 29.64, 153.0),
        },
        racolage = {
            caller = vector4(242.96, -1118.60, 29.32, 204.0),
            suspect = {
                vector4(237.86, -1138.36, 29.30, 0.0),
                vector4(246.44, -1138.22, 29.32, 2.8),
                vector4(255.80, -1138.58, 29.34, 0.0),
            },
        },
        deceased = vector4(249.20, -1150.50, 29.26, 235.2),
    },

    ['street:1'] = {      -- Legion Square
        tuerie_masse = {
            deceased = {
                vector4(185.38, -918.26, 30.90, 59.6),
                vector4(192.42, -913.16, 30.90, 309.0),
                vector4(202.94, -918.84, 30.90, 161.6),
                vector4(211.62, -919.56, 31.50, 79.4),
                vector4(198.82, -912.22, 30.90, 59.6),
                vector4(185.74, -910.04, 30.90, 87.8),
            },
            caller = vector4(219.16, -943.40, 31.50, 215.4),
            suspect = {
                vector4(192.32, -920.84, 30.90, 0.0),
                vector4(189.04, -906.72, 30.90, 173.0),
            },
            vehicle = vector4(174.34, -1011.46, 28.88, 206.2),
            victim = {
                vector4(179.04, -918.50, 31.32, 156.0),
                vector4(186.36, -894.42, 30.20, 269.2),
                vector4(190.20, -894.40, 30.20, 272.2),
                vector4(174.98, -910.90, 31.32, 252.2),
                vector4(202.56, -937.12, 30.90, 173.0),
                vector4(179.12, -927.16, 30.90, 320.4),
            },
            bystander = {
                vector4(204.76, -951.74, 31.00, 104.8),
                vector4(202.06, -959.04, 31.00, 31.2),
                vector4(180.48, -958.24, 30.94, 345.8),
                vector4(177.62, -956.34, 30.94, 337.4),
            },
        },
        vol_arrache = {
            caller  = vector4(160.66, -936.80, 30.90, 85.0),
            victim  = vector4(148.84, -935.60, 29.90, 158.8),
            suspect = {
                vector4(149.40, -934.20, 29.92, 340.2),
                vector4(148.40, -937.58, 29.88, 345.8),
            },
            bystander = {
                vector4(152.54, -919.30, 30.12, 164.4),
                vector4(156.84, -921.46, 30.16, 153.0),
                vector4(141.92, -949.06, 29.72, 334.4),
                vector4(145.62, -950.70, 29.74, 351.4),
            },
        },
        personne_armee = {
            caller  = vector4(207.24, -935.56, 31.50, 292.0),
            suspect = vector4(229.14, -932.04, 32.04, 204.0),
            bystander = {
                vector4(207.86, -932.22, 31.50, 161.6),
                vector4(235.90, -948.60, 29.30, 2.8),
                vector4(229.68, -909.08, 30.84, 340.2),
                vector4(231.70, -907.92, 30.84, 150.2),
            },
        },
        bagarre_rue = {
            caller = vector4(217.54, -943.46, 30.68, 70.8),
            suspect = {
                vector4(201.44, -939.08, 30.68, 68.0),
                vector4(200.06, -937.88, 30.68, 65.2),
                vector4(200.78, -936.58, 30.68, 328.8),
                vector4(201.88, -937.64, 30.68, 232.4),
            },
            bystander = {
                vector4(197.12, -947.72, 30.08, 0.0),
                vector4(185.68, -940.36, 30.08, 309.0),
                vector4(187.60, -941.64, 30.08, 275.0),
                vector4(190.88, -943.24, 30.08, 334.4),
            },
        },
        personne_errante = {
            caller   = vector4(197.94, -919.44, 30.68, 229.6),
            wanderer = vector4(195.52, -916.20, 30.68, 39.6),
        },
        racolage = {
            caller = vector4(184.18, -919.68, 30.68, 226.8),
            suspect = {
                vector4(184.48, -938.38, 30.08, 252.2),
                vector4(202.08, -946.92, 30.68, 56.6),
                vector4(211.10, -932.22, 30.68, 99.2),
            },
        },
    },
    ['street:3'] = {      -- Vinewood Boulevard
        tuerie_masse = {
            victim = {
                vector4(308.30, 194.22, 104.08, 289.2),
                vector4(309.82, 199.42, 104.22, 348.6),
                vector4(289.66, 204.06, 104.36, 68.0),
            },
            bystander = {
                vector4(278.74, 188.76, 104.56, 19.8),
                vector4(287.14, 208.98, 104.36, 226.8),
                vector4(309.58, 187.44, 103.90, 116.2),
                vector4(312.22, 181.20, 103.78, 173.0),
            },
            deceased = {
                vector4(300.42, 182.10, 104.14, 221.2),
                vector4(304.48, 195.42, 104.18, 337.4),
                vector4(294.34, 197.38, 104.36, 76.6),
                vector4(289.66, 183.56, 104.34, 96.4),
                vector4(297.56, 199.84, 104.34, 340.2),
                vector4(299.06, 195.24, 104.30, 190.0),
            },
            caller = vector4(327.78, 174.86, 103.44, 70.8),
            suspect = {
                vector4(296.46, 187.08, 104.20, 232.4),
                vector4(291.10, 187.84, 104.32, 328.8),
            },
            vehicle = vector4(290.64, 177.28, 103.76, 69.0),
        },
        vol_arrache = {
            caller  = vector4(265.60, 197.04, 104.84, 235.2),
            victim  = vector4(277.02, 183.74, 104.56, 65.2),
            suspect = {
                vector4(275.22, 184.48, 104.60, 65.2),
                vector4(278.80, 183.08, 104.54, 68.0),
            },
            bystander = {
                vector4(288.56, 188.88, 104.38, 107.8),
                vector4(291.78, 180.60, 104.30, 73.8),
                vector4(292.48, 185.16, 104.30, 79.4),
                vector4(263.86, 191.24, 104.82, 241.0),
            },
        },
        personne_armee = {
            caller  = vector4(307.10, 172.24, 103.98, 59.6),
            suspect = vector4(293.20, 182.80, 104.28, 150.2),
            bystander = {
                vector4(305.56, 182.10, 103.96, 158.8),
                vector4(306.80, 192.42, 104.02, 121.8),
                vector4(295.26, 199.52, 104.36, 184.2),
                vector4(290.62, 199.14, 104.36, 190.0),
            },
        },
        bagarre_rue = {
            caller = vector4(306.04, 171.86, 104.00, 25.6),
            suspect = {
                vector4(298.44, 182.84, 104.18, 34.0),
                vector4(298.08, 184.48, 104.16, 348.6),
                vector4(296.48, 184.34, 104.22, 124.8),
                vector4(295.56, 182.70, 104.24, 141.8),
            },
            bystander = {
                vector4(284.10, 181.02, 104.44, 269.2),
                vector4(286.36, 188.44, 104.42, 238.2),
                vector4(304.90, 180.56, 104.04, 59.6),
                vector4(304.44, 179.72, 104.06, 68.0),
            },
        },
        personne_errante = {
            caller   = vector4(304.10, 189.08, 103.98, 48.2),
            wanderer = vector4(303.54, 191.76, 104.08, 19.8),
        },
        racolage = {
            caller = vector4(296.92, 187.72, 104.18, 158.8),
            suspect = {
                vector4(280.22, 181.52, 104.50, 156.0),
                vector4(273.42, 183.80, 104.62, 153.0),
                vector4(306.14, 171.56, 103.98, 156.0),
            },
        },
    },
    ['street:5'] = {      -- Little Seoul
        vol_arrache = {
            caller  = vector4(-618.80, -821.06, 25.34, 272.2),
            victim  = vector4(-599.52, -817.60, 25.76, 249.4),
            suspect = {
                vector4(-598.40, -818.06, 25.80, 252.2),
                vector4(-601.34, -816.64, 25.78, 241.0),
            },
            bystander = {
                vector4(-613.36, -807.08, 25.58, 229.6),
                vector4(-614.70, -808.86, 25.58, 241.0),
                vector4(-587.32, -823.90, 26.18, 62.4),
                vector4(-586.20, -821.76, 26.22, 76.6),
            },
        },
        personne_armee = {
            caller  = vector4(-605.14, -866.98, 25.62, 283.4),
            suspect = vector4(-585.54, -862.42, 25.86, 354.4),
            bystander = {
                vector4(-566.56, -854.28, 26.88, 107.8),
                vector4(-567.92, -849.20, 26.82, 127.6),
                vector4(-579.68, -849.14, 26.26, 164.4),
                vector4(-603.88, -857.64, 25.50, 260.8),
            },
        },
        delit_fuite = {
            caller  = vector4(-569.42, -855.26, 26.54, 25.6),
            victim  = vector4(-574.74, -846.18, 26.34, 286.2),
            vehicle = {
                vector4(-572.64, -846.86, 26.04, 331.0),
                vector4(-575.16, -844.18, 26.04, 270.2),
            },
            suspect = {
                vector4(-578.56, -844.44, 26.32, 258.0),
                vector4(-571.26, -842.76, 26.66, 147.4),
            },
            bystander = {
                vector4(-580.54, -852.94, 26.20, 317.4),
                vector4(-580.00, -849.70, 26.24, 331.6),
                vector4(-566.88, -849.34, 26.84, 51.0),
                vector4(-568.08, -850.66, 26.80, 45.4),
            },
        },
        bagarre_rue = {
            caller = vector4(-521.40, -855.52, 30.24, 286.2),
            suspect = {
                vector4(-518.70, -851.74, 30.38, 306.2),
                vector4(-516.90, -851.08, 30.40, 314.6),
                vector4(-515.70, -852.06, 30.38, 207.0),
                vector4(-516.54, -853.40, 30.40, 121.8),
            },
            bystander = {
                vector4(-517.72, -861.86, 29.86, 351.4),
                vector4(-512.74, -861.90, 29.96, 25.6),
                vector4(-527.20, -849.58, 29.98, 243.8),
                vector4(-528.72, -851.34, 29.88, 260.8),
            },
        },
        personne_errante = {
            caller   = vector4(-519.36, -856.00, 30.30, 317.4),
            wanderer = vector4(-517.52, -854.04, 30.40, 317.4),
        },
        decouverte_corps = {
            caller   = vector4(-570.10, -856.26, 26.60, 28.4),
            deceased = vector4(-568.92, -861.84, 26.36, 82.2),
        },
        racolage = {
            caller = vector4(-554.38, -853.14, 27.94, 294.8),
            suspect = {
                vector4(-529.48, -849.70, 29.88, 357.2),
                vector4(-535.46, -850.04, 29.46, 14.2),
                vector4(-541.14, -849.66, 29.02, 0.0),
            },
        },
    },
    ['street:10'] = {     -- Pillbox Hill
        vol_arrache = {
            caller  = vector4(395.96, -822.30, 29.28, 181.4),
            victim  = vector4(396.56, -836.30, 29.24, 53.8),
            suspect = {
                vector4(394.82, -836.52, 29.26, 294.8),
                vector4(397.34, -834.68, 29.26, 144.6),
            },
            bystander = {
                vector4(398.76, -823.48, 29.28, 164.4),
                vector4(382.54, -838.94, 29.28, 277.8),
                vector4(382.92, -835.14, 29.28, 263.6),
                vector4(414.06, -836.62, 29.34, 76.6),
            },
        },
        personne_armee = {
            caller  = vector4(452.08, -793.76, 27.34, 303.4),
            suspect = vector4(456.52, -764.42, 27.34, 8.6),
            bystander = {
                vector4(462.50, -786.06, 27.34, 19.8),
                vector4(451.68, -786.88, 27.34, 348.6),
                vector4(462.88, -778.04, 27.34, 79.4),
                vector4(462.68, -779.32, 27.34, 121.8),
            },
        },
        delit_fuite = {
            caller  = vector4(394.40, -745.50, 29.28, 221.2),
            victim  = vector4(399.08, -751.96, 29.22, 241.0),
            vehicle = {
                vector4(400.04, -754.00, 28.56, 270.6),
                vector4(401.30, -750.78, 28.82, 182.6),
            },
            suspect = {
                vector4(401.06, -747.72, 29.14, 170.0),
                vector4(398.80, -749.38, 29.28, 198.4),
            },
            bystander = {
                vector4(395.26, -758.58, 29.28, 306.2),
                vector4(397.48, -758.78, 29.28, 331.6),
                vector4(413.60, -756.76, 29.32, 76.6),
                vector4(413.52, -750.60, 29.28, 99.2),
            },
        },
        bagarre_rue = {
            caller = vector4(452.86, -813.98, 27.82, 0.0),
            suspect = {
                vector4(453.26, -808.20, 27.66, 357.2),
                vector4(454.72, -808.34, 27.60, 260.8),
                vector4(454.66, -806.88, 27.56, 70.8),
                vector4(453.58, -806.54, 27.60, 79.4),
            },
            bystander = {
                vector4(452.04, -796.92, 27.34, 187.0),
                vector4(453.42, -796.86, 27.34, 181.4),
                vector4(462.80, -807.26, 27.16, 79.4),
                vector4(462.12, -811.72, 27.16, 62.4),
            },
        },
        personne_errante = {
            caller   = vector4(394.32, -805.48, 29.28, 320.4),
            wanderer = vector4(395.66, -803.90, 29.28, 320.4),
        },
        decouverte_corps = {
            caller   = vector4(413.60, -776.88, 29.30, 133.2),
            deceased = vector4(417.12, -777.62, 29.38, 85.0),
        },
        racolage = {
            caller = vector4(416.72, -792.14, 29.36, 133.2),
            suspect = {
                vector4(399.54, -789.90, 29.28, 272.2),
                vector4(399.58, -801.64, 29.28, 266.4),
                vector4(413.22, -780.72, 29.30, 102.0),
            },
        },
    },
    ['street:11'] = {     -- Alta Street
        vol_arrache = {
            victim = vector4(318.92, -273.14, 53.90, 252.2),
            suspect = {
                vector4(320.26, -273.70, 53.90, 65.2),
                vector4(319.32, -271.34, 53.90, 164.4),
            },
            caller = vector4(330.04, -276.26, 53.94, 65.2),
            bystander = {
                vector4(325.64, -279.90, 54.16, 42.6),
                vector4(307.80, -267.24, 53.94, 246.6),
                vector4(305.12, -269.66, 53.96, 255.2),
                vector4(303.46, -272.00, 54.16, 275.0),
            },
        },
        personne_armee = {
            caller  = vector4(343.90, -251.22, 53.82, 266.4),
            suspect = vector4(379.68, -258.30, 53.88, 96.4),
            bystander = {
                vector4(386.98, -233.76, 55.14, 164.4),
                vector4(389.98, -234.66, 55.16, 156.0),
                vector4(361.22, -290.72, 53.84, 334.4),
                vector4(364.48, -290.86, 53.90, 343.0),
            },
        },
        bagarre_rue = {
            caller = vector4(362.24, -201.94, 57.46, 226.8),
            suspect = {
                vector4(356.20, -196.36, 57.60, 56.6),
                vector4(356.22, -195.40, 57.68, 5.6),
                vector4(357.28, -194.18, 58.00, 317.4),
                vector4(357.62, -194.82, 58.00, 212.6),
            },
            bystander = {
                vector4(362.62, -188.72, 59.36, 130.4),
                vector4(364.32, -189.46, 59.32, 113.4),
                vector4(337.84, -191.20, 57.22, 260.8),
                vector4(338.50, -189.64, 57.32, 283.4),
            },
        },
        personne_errante = {
            caller   = vector4(318.78, -196.54, 54.22, 187.0),
            wanderer = vector4(319.06, -199.52, 54.08, 187.0),
        },
        decouverte_corps = {
            caller   = vector4(328.40, -220.42, 54.08, 56.6),
            deceased = vector4(332.62, -220.76, 54.08, 65.2),
        },
        racolage = {
            caller = vector4(324.02, -230.88, 54.22, 136.0),
            suspect = {
                vector4(332.76, -249.08, 53.88, 156.0),
                vector4(320.00, -244.20, 53.94, 144.6),
                vector4(307.20, -239.04, 54.16, 158.8),
            },
        },
    },
    ['street:15'] = {     -- Innocence Boulevard
        vol_arrache = {
            caller  = vector4(305.64, -2028.34, 20.48, 51.0),
            victim  = vector4(292.04, -2019.96, 19.76, 147.4),
            suspect = {
                vector4(291.34, -2020.92, 19.68, 320.4),
                vector4(293.34, -2021.12, 19.80, 45.4),
            },
            bystander = {
                vector4(306.06, -2008.12, 20.46, 136.0),
                vector4(284.72, -2004.24, 20.22, 215.4),
                vector4(283.96, -2005.88, 20.18, 212.6),
                vector4(275.68, -2015.36, 19.56, 249.4),
            },
        },
        personne_armee = {
            caller  = vector4(288.66, -2031.08, 19.64, 28.4),
            suspect = vector4(276.04, -2014.38, 19.60, 280.6),
            bystander = {
                vector4(294.46, -2021.56, 19.88, 76.6),
                vector4(294.40, -2018.12, 19.82, 87.8),
                vector4(280.56, -2033.32, 18.76, 11.4),
                vector4(279.16, -2034.74, 18.64, 5.6),
            },
        },
        delit_fuite = {
            caller  = vector4(305.70, -2004.52, 20.56, 107.8),
            victim  = vector4(299.10, -2009.94, 20.08, 297.6),
            vehicle = {
                vector4(298.70, -2006.44, 20.06, 47.8),
                vector4(296.28, -2008.90, 19.94, 316.8),
            },
            suspect = {
                vector4(296.96, -2010.96, 19.98, 320.4),
                vector4(298.82, -2011.76, 20.00, 22.6),
            },
            bystander = {
                vector4(296.92, -2017.00, 19.94, 345.8),
                vector4(295.14, -2016.66, 19.84, 5.6),
                vector4(290.34, -1998.74, 20.32, 221.2),
                vector4(287.82, -2001.20, 20.32, 224.0),
            },
        },
        bagarre_rue = {
            caller = vector4(334.74, -2054.20, 20.82, 320.4),
            suspect = {
                vector4(337.84, -2049.54, 21.04, 328.8),
                vector4(338.84, -2048.00, 21.18, 328.8),
                vector4(340.06, -2048.84, 21.22, 232.4),
                vector4(338.96, -2049.84, 21.10, 130.4),
            },
            bystander = {
                vector4(343.02, -2062.80, 20.86, 5.6),
                vector4(351.96, -2039.10, 22.08, 144.6),
                vector4(349.86, -2037.42, 22.06, 175.8),
                vector4(344.28, -2030.64, 22.06, 190.0),
            },
        },
        personne_errante = {
            caller   = vector4(332.28, -2070.90, 20.94, 138.8),
            wanderer = vector4(329.82, -2071.34, 20.12, 127.6),
        },
        decouverte_corps = {
            caller   = vector4(312.56, -2054.02, 20.92, 147.4),
            deceased = vector4(308.42, -2051.72, 20.50, 147.4),
        },
        racolage = {
            caller = vector4(315.54, -2039.14, 20.76, 45.4),
            suspect = {
                vector4(292.36, -2018.46, 19.78, 48.2),
                vector4(289.92, -2021.74, 19.60, 51.0),
                vector4(304.60, -2004.96, 20.46, 48.2),
            },
        },
    },
    ['street:20'] = {     -- Hawick Avenue
        bagarre_rue = {
            caller = vector4(157.26, 37.70, 73.94, 209.8),
            suspect = {
                vector4(171.68, 25.18, 73.22, 147.4),
                vector4(170.84, 23.64, 73.22, 147.4),
                vector4(172.24, 22.90, 73.22, 269.2),
                vector4(173.46, 24.06, 73.22, 348.6),
            },
            bystander = {
                vector4(161.22, 13.24, 73.44, 314.6),
                vector4(162.36, 12.78, 73.42, 314.6),
                vector4(153.80, 20.62, 70.52, 275.0),
                vector4(152.44, 19.88, 70.32, 275.0),
            },
        },
        personne_errante = {
            caller   = vector4(204.96, 54.08, 83.70, 34.0),
            wanderer = vector4(205.06, 56.66, 83.68, 19.8),
        },
        decouverte_corps = {
            caller   = vector4(220.44, 38.06, 83.80, 0.0),
            deceased = vector4(220.40, 34.86, 83.72, 252.2),
        },
        racolage = {
            caller = vector4(163.46, 14.66, 73.42, 22.6),
            suspect = {
                vector4(157.84, 38.00, 74.04, 73.8),
                vector4(159.02, 42.80, 75.16, 62.4),
                vector4(161.22, 47.34, 76.36, 68.0),
            },
        },
    },
    ['street:24'] = {     -- Popular Street
        personne_armee = {
            caller  = vector4(1192.80, -1267.56, 35.18, 289.2),
            suspect = vector4(1207.06, -1262.20, 35.22, 0.0),
            bystander = {
                vector4(1218.68, -1267.34, 36.40, 82.2),
                vector4(1216.48, -1269.96, 35.36, 53.8),
                vector4(1213.42, -1250.42, 36.32, 156.0),
                vector4(1195.22, -1247.98, 35.22, 204.0),
            },
        },
        delit_fuite = {
            caller  = vector4(1227.06, -1296.78, 35.34, 286.2),
            victim  = vector4(1234.88, -1291.46, 34.78, 229.6),
            vehicle = {
                vector4(1234.74, -1294.02, 34.48, 237.6),
                vector4(1237.00, -1291.12, 34.54, 173.4),
            },
            suspect = {
                vector4(1236.68, -1297.50, 34.90, 2.8),
                vector4(1235.12, -1288.96, 34.80, 181.4),
            },
            bystander = {
                vector4(1232.88, -1283.82, 34.92, 207.0),
                vector4(1231.02, -1285.10, 35.06, 221.2),
                vector4(1231.64, -1302.14, 34.94, 326.0),
                vector4(1232.00, -1305.32, 34.90, 337.4),
            },
        },
        personne_errante = {
            caller   = vector4(1169.16, -1322.38, 34.90, 309.0),
            wanderer = vector4(1169.82, -1320.18, 34.92, 334.4),
        },
        decouverte_corps = {
            caller   = vector4(1171.34, -1316.46, 35.00, 263.6),
            deceased = vector4(1181.68, -1317.74, 34.98, 90.8),
        },
        racolage = {
            caller = vector4(1199.82, -1282.56, 35.36, 249.4),
            suspect = {
                vector4(1231.40, -1299.52, 34.96, 266.4),
                vector4(1231.18, -1305.92, 34.94, 266.4),
                vector4(1233.70, -1283.70, 34.90, 260.8),
            },
        },
    },
    ['street:16'] = {     -- El Burro Heights
        personne_errante = {
            caller   = vector4(1337.60, -1526.58, 54.04, 156.0),
            wanderer = vector4(1335.72, -1529.76, 53.34, 147.4),
        },
        decouverte_corps = {
            caller   = vector4(1357.94, -1493.68, 55.78, 59.6),
            deceased = vector4(1356.18, -1492.66, 55.48, 59.6),
        },
    },
    ['street:21'] = {     -- Banning
        personne_armee = {
            caller  = vector4(-61.12, -2446.78, 6.00, 192.8),
            suspect = vector4(-55.70, -2472.20, 6.02, 204.0),
            bystander = {
                vector4(-52.08, -2452.54, 6.00, 164.4),
                vector4(-54.06, -2451.30, 6.00, 167.2),
                vector4(-34.60, -2464.82, 6.00, 107.8),
                vector4(-33.86, -2463.44, 6.00, 104.8),
            },
        },
        personne_errante = {
            caller   = vector4(-61.30, -2446.28, 6.00, 116.2),
            wanderer = vector4(-63.60, -2446.82, 6.00, 300.4),
        },
        decouverte_corps = {
            caller   = vector4(-91.52, -2423.48, 6.00, 286.2),
            deceased = vector4(-90.16, -2421.20, 6.00, 192.8),
        },
    },
    ['street:18'] = {     -- Mission Row
        bagarre_rue = {
            caller = vector4(387.86, -993.54, 29.42, 340.2),
            suspect = {
                vector4(389.32, -983.68, 29.42, 8.6),
                vector4(390.78, -983.48, 29.42, 275.0),
                vector4(390.58, -984.94, 29.42, 173.0),
                vector4(389.08, -985.06, 29.42, 96.4),
            },
            bystander = {
                vector4(391.54, -973.38, 29.44, 175.8),
                vector4(388.66, -973.10, 29.44, 187.0),
                vector4(392.30, -996.98, 29.42, 357.2),
                vector4(391.26, -995.78, 29.42, 14.2),
            },
        },
        personne_errante = {
            caller   = vector4(418.12, -1005.36, 29.22, 73.8),
            wanderer = vector4(416.26, -1004.80, 29.26, 85.0),
        },
    },
    -- Vie nocturne (ivresse publique, rixe de sortie de boîte)
    ['nightlife:1'] = {    -- Tequi-la-la
        rixe_soiree = {
            caller = vector4(-544.18, 295.66, 83.02, 45.4),
            suspect = {
                vector4(-553.96, 300.06, 83.14, 326.0),
                vector4(-552.94, 301.54, 83.16, 326.0),
                vector4(-554.26, 302.48, 83.22, 62.4),
                vector4(-555.90, 301.96, 83.20, 141.8),
                vector4(-557.16, 303.12, 83.24, 99.2),
                vector4(-555.42, 304.60, 83.26, 5.6),
                vector4(-553.58, 304.60, 83.30, 348.6),
                vector4(-552.18, 303.92, 83.20, 235.2),
            },
            bystander = {
                vector4(-541.18, 312.44, 83.02, 116.2),
                vector4(-553.68, 294.04, 85.36, 348.6),
                vector4(-562.50, 294.94, 87.48, 311.8),
                vector4(-560.98, 294.72, 87.48, 258.0),
            },
        },
        ipm = {
            caller  = vector4(-570.24, 274.20, 82.94, 87.8),
            suspect = vector4(-577.76, 272.28, 82.72, 76.6),
        },
    },
    ['nightlife:2'] = {     -- Vanilla Unicorn
        ipm = {
            caller  = vector4(135.46, -1312.04, 29.16, 286.2),
            suspect = vector4(140.54, -1314.30, 29.14, 221.2),
        },
        rixe_soiree = {
            caller = vector4(139.02, -1301.02, 29.20, 235.2),
            suspect = {
                vector4(147.58, -1306.48, 29.20, 241.0),
                vector4(149.30, -1307.12, 29.20, 241.0),
                vector4(151.28, -1305.46, 29.20, 300.4),
                vector4(149.88, -1303.70, 29.18, 2.8),
                vector4(152.84, -1305.50, 29.20, 272.2),
                vector4(152.86, -1307.78, 29.20, 255.2),
                vector4(150.80, -1308.74, 29.20, 133.2),
                vector4(148.24, -1308.40, 29.20, 93.6),
            },
            bystander = {
                vector4(143.76, -1314.76, 29.04, 323.2),
                vector4(146.94, -1317.26, 29.06, 311.8),
                vector4(159.64, -1298.46, 29.16, 150.2),
                vector4(157.72, -1297.30, 29.16, 161.6),
            },
        },
    },
    ['nightlife:3'] = {     -- Del Perro Pier
        ipm = {
            caller  = vector4(-1605.66, -1008.40, 13.00, 198.4),
            suspect = vector4(-1603.50, -1016.62, 13.00, 243.8),
        },
        rixe_soiree = {
            caller = vector4(-1589.60, -1007.24, 13.02, 173.0),
            suspect = {
                vector4(-1589.72, -1023.90, 13.00, 164.4),
                vector4(-1590.56, -1025.46, 13.00, 184.2),
                vector4(-1589.00, -1025.92, 13.00, 292.0),
                vector4(-1587.14, -1024.06, 13.00, 357.2),
                vector4(-1589.68, -1022.82, 13.00, 70.8),
                vector4(-1591.06, -1023.98, 13.00, 127.6),
                vector4(-1593.12, -1025.52, 13.00, 138.8),
                vector4(-1592.64, -1027.90, 13.00, 209.8),
            },
            bystander = {
                vector4(-1593.24, -1037.30, 13.00, 348.6),
                vector4(-1591.68, -1038.66, 13.00, 0.0),
                vector4(-1604.68, -1025.68, 13.06, 314.6),
                vector4(-1604.92, -1023.22, 13.06, 272.2),
            },
        },
    },
    ['nightlife:4'] = {    -- Terrasse de Vespucci
        rixe_soiree = {
            caller = vector4(-1378.24, -579.08, 30.08, 229.6),
            suspect = {
                vector4(-1372.52, -582.88, 29.80, 218.2),
                vector4(-1371.08, -582.16, 29.86, 272.2),
                vector4(-1371.04, -583.86, 29.76, 232.4),
                vector4(-1369.68, -583.22, 29.82, 56.6),
                vector4(-1369.88, -580.86, 29.96, 198.4),
                vector4(-1371.34, -579.82, 30.00, 173.0),
                vector4(-1373.16, -579.70, 30.02, 215.4),
                vector4(-1374.60, -580.60, 29.94, 232.4),
            },
            bystander = {
                vector4(-1378.16, -584.02, 30.06, 260.8),
                vector4(-1377.18, -586.28, 29.94, 280.6),
                vector4(-1375.26, -590.02, 29.76, 328.8),
                vector4(-1373.10, -592.34, 29.66, 345.8),
            },
        },
        ipm = {
            caller  = vector4(-1384.02, -583.90, 30.18, 314.6),
            suspect = vector4(-1378.10, -583.46, 30.08, 218.2),
        },
    },
    ['nightlife:5'] = {     -- Bars de Vespucci Beach
        ipm = {
            caller  = vector4(-1171.02, -1506.52, 4.38, 25.6),
            suspect = vector4(-1176.22, -1501.50, 4.38, 11.4),
        },
        rixe_soiree = {
            caller = vector4(-1168.00, -1522.16, 4.36, 34.0),
            suspect = {
                vector4(-1185.04, -1502.18, 4.38, 0.0),
                vector4(-1185.82, -1499.70, 4.38, 36.8),
                vector4(-1183.18, -1499.74, 4.38, 294.8),
                vector4(-1183.60, -1497.36, 4.38, 2.8),
                vector4(-1187.94, -1500.02, 4.38, 144.6),
                vector4(-1186.80, -1503.18, 4.38, 190.0),
                vector4(-1183.68, -1502.50, 4.38, 328.8),
                vector4(-1181.74, -1499.80, 4.38, 198.4),
            },
            bystander = {
                vector4(-1175.28, -1506.30, 4.38, 48.2),
                vector4(-1172.86, -1504.28, 4.38, 343.0),
                vector4(-1171.10, -1502.60, 4.38, 36.8),
            },
        },
    },
    ['nightlife:6'] = {    -- Bar de West Vinewood
        rixe_soiree = {
            caller = vector4(-416.14, 283.22, 83.18, 22.6),
            suspect = {
                vector4(-417.46, 292.58, 83.22, 252.2),
                vector4(-415.86, 291.54, 83.22, 238.2),
                vector4(-416.68, 290.34, 83.22, 138.8),
                vector4(-419.12, 290.78, 83.06, 68.0),
                vector4(-420.36, 291.96, 83.12, 42.6),
                vector4(-420.06, 293.44, 83.22, 354.4),
                vector4(-419.08, 294.88, 83.22, 343.0),
                vector4(-417.60, 294.94, 83.22, 280.6),
            },
            bystander = {
                vector4(-420.98, 283.98, 83.18, 2.8),
                vector4(-423.60, 286.34, 83.22, 331.6),
                vector4(-427.18, 293.10, 83.22, 280.6),
                vector4(-427.38, 290.10, 83.22, 292.0),
            },
        },
        ipm = {
            caller  = vector4(-416.36, 258.80, 83.18, 343.0),
            suspect = vector4(-410.26, 271.10, 83.16, 357.2),
        },
    },
    ['nightlife:7'] = {    -- Front de mer de La Puerta
        ipm = {
            caller  = vector4(-820.32, -1334.22, 5.14, 0.0),
            suspect = vector4(-818.28, -1316.08, 5.08, 161.6),
        },
        rixe_soiree = {
            caller = vector4(-821.92, -1332.30, 5.14, 343.0),
            suspect = {
                vector4(-808.88, -1299.94, 5.00, 249.4),
                vector4(-808.62, -1301.52, 5.00, 195.6),
                vector4(-806.88, -1301.78, 5.00, 283.4),
                vector4(-805.90, -1300.40, 5.00, 345.8),
                vector4(-807.26, -1298.36, 5.00, 8.6),
                vector4(-804.88, -1298.62, 5.00, 283.4),
                vector4(-804.00, -1300.60, 5.00, 266.4),
                vector4(-804.26, -1303.08, 5.00, 150.2),
            },
            bystander = {
                vector4(-819.78, -1310.94, 5.08, 320.4),
                vector4(-821.36, -1308.46, 5.08, 300.4),
                vector4(-817.06, -1293.86, 5.08, 246.6),
                vector4(-817.60, -1296.28, 5.08, 249.4),
            },
        },
    },

    ['nightlife:8'] = {   -- Casino de Vinewood
        rixe_soiree = {
            caller = vector4(889.72, -1.18, 78.76, 141.8),
            suspect = {
                vector4(877.30, -13.36, 78.76, 70.8),
                vector4(876.42, -14.78, 78.76, 147.4),
                vector4(875.08, -14.18, 78.76, 68.0),
                vector4(875.56, -12.76, 78.76, 331.6),
                vector4(873.62, -14.02, 78.76, 113.4),
                vector4(873.50, -16.60, 78.76, 181.4),
                vector4(875.32, -17.78, 78.76, 198.4),
                vector4(877.34, -16.28, 78.76, 326.0),
            },
            bystander = {
                vector4(882.50, 1.00, 78.76, 150.2),
                vector4(884.20, -0.22, 78.76, 175.8),
                vector4(881.70, 3.08, 78.76, 158.8),
                vector4(883.54, 3.16, 78.76, 178.6),
            },
        },
        ipm = {
            caller  = vector4(903.08, 13.56, 79.00, 141.8),
            suspect = vector4(894.22, 0.26, 78.90, 147.4),
        },
    },
    ['nightlife:9'] = {   -- Ruelle de Bahama Mamas
        rixe_soiree = {
            caller = vector4(-1279.12, -640.88, 26.74, 246.6),
            suspect = {
                vector4(-1266.00, -640.50, 26.90, 209.8),
                vector4(-1266.62, -641.94, 26.90, 164.4),
                vector4(-1264.92, -642.22, 26.90, 218.2),
                vector4(-1265.90, -643.40, 26.90, 121.8),
                vector4(-1267.56, -644.62, 26.90, 195.6),
                vector4(-1266.10, -645.58, 26.90, 235.2),
                vector4(-1264.40, -645.86, 26.92, 297.6),
                vector4(-1262.78, -644.86, 26.92, 314.6),
            },
            bystander = {
                vector4(-1275.94, -643.36, 26.80, 258.0),
                vector4(-1273.60, -637.88, 26.86, 224.0),
                vector4(-1266.40, -636.98, 26.94, 207.0),
                vector4(-1268.14, -636.22, 26.92, 209.8),
            },
        },
        ipm = {
            caller  = vector4(-1289.56, -653.20, 26.54, 107.8),
            suspect = vector4(-1296.10, -656.14, 26.50, 136.0),
        },
    },

    -- Points de deal (trafic de stupéfiants)
    ['dealpoint:1'] = {              -- Grove Street
        trafic_stup = {
            caller = vector4(116.42, -1932.46, 20.74, 133.2),
            suspect = {
                vector4(98.42, -1959.38, 20.72, 53.8),
                vector4(97.38, -1958.56, 20.74, 221.2),
            },
        },
    },
    ['dealpoint:2'] = {              -- Forum Drive, Davis
        trafic_stup = {
            caller = vector4(142.86, -1792.78, 28.68, 207.0),
            suspect = {
                vector4(154.68, -1815.76, 28.08, 243.8),
                vector4(155.72, -1816.30, 28.10, 59.6),
            },
        },
    },
    ['dealpoint:3'] = {              -- Strawberry Avenue
        trafic_stup = {
            caller = vector4(224.56, -1712.96, 29.30, 221.2),
            suspect = {
                vector4(198.26, -1688.90, 29.60, 238.2),
                vector4(199.50, -1689.74, 29.70, 59.6),
            },
        },
    },
    ['dealpoint:4'] = {              -- Vespucci Canals
        trafic_stup = {
            caller = vector4(-1169.06, -1522.90, 4.40, 34.0),
            suspect = {
                vector4(-1153.50, -1530.40, 4.24, 292.0),
                vector4(-1152.52, -1529.94, 4.24, 107.8),
            },
        },
    },
    ['dealpoint:5'] = {              -- Rancho
        trafic_stup = {
            caller = vector4(416.16, -1888.82, 26.10, 39.6),
            suspect = {
                vector4(421.96, -1904.82, 25.62, 48.2),
                vector4(421.00, -1903.58, 25.62, 232.4),
            },
        },
    },
    ['dealpoint:6'] = {              -- Ruelle de Mirror Park
        trafic_stup = {
            caller = vector4(1066.78, -413.84, 67.14, 337.4),
            suspect = {
                vector4(1052.08, -434.92, 66.14, 348.6),
                vector4(1052.34, -433.68, 66.18, 153.0),
            },
        },
    },
    ['dealpoint:7'] = {              -- La Mesa
        trafic_stup = {
            caller = vector4(822.90, -1626.44, 31.10, 354.4),
            suspect = {
                vector4(823.42, -1600.94, 32.12, 286.2),
                vector4(824.34, -1599.58, 32.02, 141.8),
            },
        },
    },
    ['dealpoint:8'] = {              -- La Puerta
        trafic_stup = {
            caller = vector4(-617.06, -1212.40, 14.12, 317.4),
            suspect = {
                vector4(-629.22, -1220.66, 12.72, 42.6),
                vector4(-630.06, -1219.84, 12.70, 229.6),
            },
        },
    },
    ['dealpoint:9'] = {              -- Chamberlain Hills
        trafic_stup = {
            caller = vector4(-162.36, -1631.04, 33.62, 65.2),
            suspect = {
                vector4(-148.00, -1629.66, 33.04, 144.6),
                vector4(-148.62, -1630.78, 33.06, 314.6),
            },
        },
    },
    ['dealpoint:10'] = {             -- Ruelle de Textile City
        trafic_stup = {
            caller = vector4(494.04, -1271.56, 29.34, 334.4),
            suspect = {
                vector4(491.78, -1299.92, 29.30, 272.2),
                vector4(493.10, -1299.90, 29.30, 85.0),
            },
        },
    },
    ['dealpoint:11'] = {             -- Vespucci Beach Nord
        trafic_stup = {
            caller = vector4(-1289.68, -1131.48, 6.12, 82.2),
            suspect = {
                vector4(-1289.46, -1109.60, 6.82, 85.0),
                vector4(-1290.66, -1109.46, 6.80, 277.8),
            },
        },
    },
    ['dealpoint:12'] = {             -- El Burro Heights
        trafic_stup = {
            caller = vector4(1432.94, -1682.98, 64.86, 11.4),
            suspect = {
                vector4(1430.80, -1657.50, 62.78, 59.6),
                vector4(1428.82, -1658.74, 62.74, 277.8),
            },
        },
    },
    ['dealpoint:13'] = {             -- Ruelle de Strawberry
        trafic_stup = {
            caller = vector4(-53.72, -1052.86, 27.94, 56.6),
            suspect = {
                vector4(-51.54, -1083.12, 26.86, 348.6),
                vector4(-51.24, -1081.82, 26.88, 170.0),
            },
        },
    },
    ['dealpoint:14'] = {             -- Cypress Flats
        trafic_stup = {
            caller = vector4(968.94, -1752.74, 31.16, 190.0),
            suspect = {
                vector4(949.22, -1740.36, 31.16, 260.8),
                vector4(950.26, -1741.38, 31.18, 53.8),
            },
        },
    },
    ['dealpoint:15'] = {             -- Carson Avenue
        trafic_stup = {
            caller = vector4(-209.48, -1599.58, 34.86, 110.6),
            suspect = {
                vector4(-230.62, -1606.36, 34.32, 0.0),
                vector4(-230.64, -1604.72, 34.34, 173.0),
            },
        },
    },
    ['dealpoint:16'] = {             -- Davis Nord
        trafic_stup = {
            caller = vector4(293.20, -1444.78, 29.96, 328.8),
            suspect = {
                vector4(310.94, -1451.70, 29.96, 51.0),
                vector4(309.90, -1451.06, 29.96, 232.4),
            },
        },
    },

    -- Habitations avec intérieur (cambriolages)
    ['residential:22'] = {  -- El Burro Heights, maison
        chien_dangereux = {
            caller  = vector4(1322.88, -1718.80, 55.12, 229.6),
            -- Le maître de l'animal est le MIS EN CAUSE, pas un
            suspect = vector4(1338.76, -1716.40, 57.08, 144.6),
            animal  = vector4(1335.80, -1720.68, 56.74, 269.2),
            victim  = vector4(1335.00, -1720.70, 56.62, 289.2),
        },
        cambriolage = {
            caller = vector4(1254.76, -1751.48, 47.62, 104.8),
            chief  = vector4(1273.84, -1719.04, 54.76, 5.6),
            driver = vector4(1280.90, -1733.58, 52.52, 110.6),
            vehicle = vector4(1280.12, -1732.48, 52.16, 112.8),
            crew = {
                vector4(1274.74, -1714.82, 54.76, 345.8),
                vector4(1274.26, -1711.96, 54.76, 14.2),
                vector4(1273.26, -1708.36, 54.76, 107.8),
            },
        },
    },
    ['residential:23'] = {  -- Vinewood West, appartement
        chien_dangereux = {
            caller  = vector4(-69.78, -10.50, 69.44, 170.0),
            suspect = vector4(-70.08, -22.04, 67.30, 170.0),
            animal  = vector4(-69.66, -19.12, 67.88, 170.0),
            victim  = vector4(-69.54, -18.30, 68.06, 170.0),
        },
        cambriolage = {
            chief  = vector4(-109.58, -8.10,  70.52, 161.6),
            driver = vector4(-77.38,  -21.58, 66.28, 263.6),
            vehicle = vector4(-77.16,  -22.86, 65.92, 262.8),
            crew = {
                vector4(-96.66,  -8.66,  66.40, 337.4),
                vector4(-110.08, -11.64, 70.52, 14.2),
            },
        },
    },
    ['residential:24'] = {  -- La Puerta
        chien_dangereux = {
            caller = vector4(-1102.98, -1543.90, 4.30, 25.6),
            animal = vector4(-1107.30, -1534.86, 4.38, 25.6),
            suspect = vector4(-1111.00, -1529.94, 4.38, 224.0),
            victim = vector4(-1107.98, -1533.90, 4.38, 221.2),
        },
        cambriolage = {
            chief = vector4(-1151.86, -1516.80, 10.62, 156.0),
            crew = {
                vector4(-1157.02, -1522.40, 10.62, 201.2),
                vector4(-1157.20, -1518.26, 10.62, 19.8),
            },
            vehicle = vector4(-1154.74, -1524.10, 3.88, 35.8),
            driver = vector4(-1155.62, -1525.14, 4.24, 34.0),
            caller = vector4(-1146.70, -1508.08, 4.28, 11.4),
        },
    },
    ['residential:25'] = {  -- Rockford Hills
        chien_dangereux = {
            caller = vector4(-844.38, 201.64, 73.94, 275.0),
            animal = vector4(-834.30, 200.80, 74.24, 263.6),
            suspect = vector4(-831.30, 200.42, 74.32, 263.6),
            victim = vector4(-835.36, 200.94, 74.20, 263.6),
        },
        cambriolage = {
            chief = vector4(-799.76, 179.52, 72.82, 277.8),
            crew = {
                vector4(-807.64, 180.26, 72.14, 294.8),
                vector4(-804.26, 178.72, 76.72, 221.2),
            },
            vehicle = vector4(-824.72, 179.92, 71.12, 146.4),
            driver = vector4(-822.82, 180.10, 71.58, 144.6),
            caller = vector4(-868.30, 180.22, 69.68, 269.2),
        },
    },
    ['residential:26'] = {  -- Vinewood Hills
        cambriolage = {
            chief = vector4(6.56, 533.56, 175.50, 133.2),
            crew = {
                vector4(8.48, 527.10, 174.62, 56.6),
                vector4(6.98, 537.16, 170.62, 119.0),
            },
            vehicle = vector4(6.40, 546.20, 174.92, 304.0),
            driver = vector4(5.32, 547.10, 175.04, 306.2),
            caller = vector4(48.18, 563.54, 180.14, 82.2),
        },
    },

    ['residential:5'] = {  -- Grove Street
        chien_dangereux = {
            caller  = vector4(134.30, -1892.16, 23.58, 320.4),
            -- Le maître de l'animal est le MIS EN CAUSE, pas un
            suspect = vector4(141.28, -1891.82, 23.26, 39.6),
            animal  = vector4(139.42, -1888.70, 23.30, 258.0),
            victim  = vector4(138.20, -1888.42, 23.28, 258.0),
        },
    },
    ['residential:6'] = {  -- Chamberlain Hills
        chien_dangereux = {
            caller  = vector4(-106.96, -1600.16, 31.68, 138.8),
            -- Le maître de l'animal est le MIS EN CAUSE, pas un
            suspect = vector4(-116.06, -1611.58, 31.90, 147.4),
            animal  = vector4(-114.96, -1608.54, 31.82, 136.0),
            victim  = vector4(-114.14, -1607.60, 31.80, 136.0),
        },
    },
    ['residential:17'] = { -- Rancho
        chien_dangereux = {
            caller  = vector4(483.10, -1772.84, 28.52, 153.0),
            -- Le maître de l'animal est le MIS EN CAUSE, pas un
            suspect = vector4(478.26, -1779.74, 28.68, 56.6),
            animal  = vector4(475.34, -1777.56, 28.70, 198.4),
            victim  = vector4(475.10, -1776.94, 28.70, 269.2),
        },
    },
    ['residential:4'] = {  -- Mirror Park
        chien_dangereux = {
            caller  = vector4(1292.42, -560.72, 70.42, 260.8),
            suspect = vector4(1309.02, -564.36, 71.80, 258.0),
            animal  = vector4(1304.58, -563.08, 71.44, 260.8),
            victim  = vector4(1303.38, -562.82, 71.34, 260.8),
        },
    },
    ['residential:8'] = {  -- Vespucci Canals
        chien_dangereux = {
            caller  = vector4(-1100.74, -1007.26, 2.14, 334.4),
            suspect = vector4(-1093.88, -999.44, 2.14, 119.0),
            animal  = vector4(-1098.58, -1001.88, 2.14, 294.8),
            victim  = vector4(-1100.14, -1003.04, 2.14, 289.2),
        },
    },
    ['residential:13'] = { -- Prosperity Street
        chien_dangereux = {
            caller  = vector4(-1544.24, -693.32, 28.86, 221.2),
            suspect = vector4(-1538.76, -707.12, 28.74, 19.8),
            animal  = vector4(-1539.04, -702.52, 28.86, 36.8),
            victim  = vector4(-1539.90, -700.28, 28.96, 207.0),
        },
    },
    ['residential:14'] = { -- Hawick
        chien_dangereux = {
            caller  = vector4(1146.76, -992.20, 45.64, 184.2),
            suspect = vector4(1148.28, -1007.70, 44.84, 187.0),
            animal  = vector4(1147.70, -1002.02, 45.12, 187.0),
            victim  = vector4(1147.52, -1000.20, 45.22, 187.0),
        },
    },
    -- Commerces (braquages)
    ['shop:1'] = {          -- 24/7 Strawberry
        vol_etalage = {
            caller = vector4(28.48, -1339.26, 29.48, 187.0),
            suspect = {
                vector4(30.28, -1339.92, 29.48, 96.4),
                vector4(29.56, -1340.72, 29.48, 39.6),
            },
        },
        braquage_superette = {
            caller = vector4(24.30, -1347.46, 29.48, 275.0),
            chief  = vector4(26.22, -1347.02, 29.48, 85.0),
            driver = vector4(17.72, -1355.68, 29.18, 87.8),
            vehicle = vector4(17.42, -1354.34, 28.90, 89.4),
            crew = {
                vector4(25.92, -1340.06, 29.48, 275.0),
                vector4(28.32, -1350.46, 29.34, 147.4),
                vector4(30.68, -1347.86, 29.48, 87.8),
            },
            bystander = {
                vector4(32.96, -1343.82, 29.48, 110.6),
                vector4(33.24, -1345.22, 29.48, 110.6),
                vector4(33.20, -1348.00, 29.48, 76.6),
            },
        },
    },
    ['shop:2'] = {          -- LTD Davis
        vol_etalage = {
            caller = vector4(-44.22, -1749.54, 29.42, 297.6),
            suspect = {
                vector4(-42.90, -1748.82, 29.42, 119.0),
                vector4(-41.64, -1749.20, 29.42, 136.0),
            },
        },
        braquage_superette = {
            caller = vector4(-46.74, -1758.46, 29.42, 53.8),
            chief  = vector4(-49.62, -1757.28, 29.42, 232.4),
            driver = vector4(-56.96, -1759.80, 29.00, 53.8),
            vehicle = vector4(-56.46, -1758.52, 28.64, 54.8),
            crew = {
                vector4(-52.82, -1753.94, 29.42, 238.2),
                vector4(-46.76, -1753.72, 29.42, 184.2),
                vector4(-42.32, -1753.18, 29.46, 25.6),
            },
            bystander = {
                vector4(-53.32, -1749.02, 29.42, 226.8),
                vector4(-50.66, -1751.42, 29.42, 190.0),
                vector4(-52.50, -1751.40, 29.42, 190.0),
                vector4(-56.08, -1752.14, 29.42, 212.6),
            },
        },
    },
    ['shop:3'] = {          -- LTD Little Seoul
        vol_etalage = {
            caller = vector4(-709.56, -905.58, 19.20, 357.2),
            suspect = {
                vector4(-709.08, -904.48, 19.20, 158.8),
                vector4(-707.98, -904.36, 19.20, 138.8),
            },
        },
        braquage_superette = {
            caller = vector4(-706.10, -914.60, 19.20, 85.0),
            chief  = vector4(-707.42, -914.28, 19.20, 275.0),
            driver = vector4(-711.00, -922.14, 19.00, 85.0),
            vehicle = vector4(-711.22, -920.82, 18.62, 85.6),
            crew = {
                vector4(-712.00, -917.86, 19.20, 90.8),
                vector4(-712.20, -914.70, 19.20, 348.6),
                vector4(-705.98, -907.26, 19.20, 53.8),
            },
            bystander = {
                vector4(-710.86, -911.62, 19.20, 124.8),
                vector4(-713.86, -911.40, 19.20, 153.0),
                vector4(-715.10, -912.72, 19.20, 147.4),
                vector4(-716.46, -910.68, 19.20, 207.0),
                vector4(-709.26, -904.30, 19.20, 207.0),
            },
        },
    },
    ['shop:4'] = {          -- Rob's Liquor Hawick
        vol_etalage = {
            caller = vector4(1130.92, -981.10, 46.40, 187.0),
            suspect = {
                vector4(1130.66, -982.48, 46.40, 0.0),
                vector4(1131.20, -983.72, 46.40, 5.6),
            },
        },
        braquage_superette = {
            caller = vector4(1134.10, -982.16, 46.40, 283.4),
            chief  = vector4(1136.18, -981.66, 46.40, 96.4),
            driver = vector4(1147.16, -982.20, 46.12, 187.0),
            vehicle = vector4(1145.90, -982.60, 45.70, 185.0),
            crew = {
                vector4(1137.84, -979.22, 46.40, 124.8),
                vector4(1142.20, -979.22, 46.28, 269.2),
            },
            bystander = {
                vector4(1139.54, -983.82, 46.40, 79.4),
                vector4(1137.74, -984.26, 46.40, 102.0),
                vector4(1136.52, -983.90, 46.40, 87.8),
            },
        },
    },
    ['shop:5'] = {          -- Rob's Liquor Prosperity
        vol_etalage = {
            caller = vector4(-1221.92, -911.94, 12.32, 300.4),
            suspect = {
                vector4(-1220.66, -911.56, 12.32, 113.4),
                vector4(-1219.72, -910.62, 12.32, 156.0),
            },
        },
        braquage_superette = {
            caller = vector4(-1222.20, -908.58, 12.32, 34.0),
            chief  = vector4(-1223.30, -907.14, 12.32, 215.4),
            driver = vector4(-1230.56, -896.86, 12.10, 303.4),
            vehicle = vector4(-1229.54, -897.80, 11.80, 303.2),
            crew = {
                vector4(-1219.68, -915.96, 11.32, 104.8),
                vector4(-1225.38, -905.10, 12.32, 218.2),
                vector4(-1225.50, -900.84, 12.32, 36.8),
            },
            bystander = {
                vector4(-1226.92, -906.16, 12.32, 232.4),
                vector4(-1222.72, -903.30, 12.32, 258.0),
            },
        },
    },
    ['shop:6'] = {          -- Rob's Liquor Morningwood
        vol_etalage = {
            caller = vector4(-1482.66, -377.54, 40.14, 36.8),
            suspect = {
                vector4(-1483.48, -376.28, 40.14, 224.0),
                vector4(-1484.34, -375.38, 40.14, 226.8),
            },
        },
        braquage_superette = {
            caller = vector4(-1486.12, -378.16, 40.14, 133.2),
            chief  = vector4(-1486.58, -382.00, 40.14, 337.4),
            driver = vector4(-1505.44, -386.20, 40.50, 48.2),
            vehicle = vector4(-1504.84, -384.96, 40.18, 49.0),
            crew = {
                vector4(-1480.16, -374.00, 39.16, 212.6),
                vector4(-1487.38, -380.14, 40.14, 314.6),
                vector4(-1492.28, -382.90, 40.14, 130.4),
            },
            bystander = {
                vector4(-1478.76, -374.10, 39.16, 167.2),
                vector4(-1490.04, -378.78, 40.14, 314.6),
            },
        },
    },
    ['shop:7'] = {          -- 24/7 Vinewood
        vol_etalage = {
            caller = vector4(378.50, 333.08, 103.56, 238.2),
            suspect = {
                vector4(380.54, 332.04, 103.56, 53.8),
                vector4(379.16, 331.34, 103.56, 22.6),
            },
        },
        braquage_superette = {
            caller = vector4(372.56, 326.60, 103.56, 260.8),
            chief  = vector4(375.04, 327.88, 103.56, 90.8),
            driver = vector4(375.38, 317.78, 103.42, 73.8),
            vehicle = vector4(375.40, 319.14, 103.04, 75.6),
            crew = {
                vector4(374.56, 325.60, 103.56, 73.8),
                vector4(377.72, 332.62, 103.56, 260.8),
                vector4(376.62, 321.86, 103.42, 144.6),
            },
            bystander = {
                vector4(378.24, 328.82, 103.56, 241.0),
                vector4(381.42, 327.12, 103.56, 243.8),
                vector4(380.50, 323.92, 103.56, 173.0),
            },
        },
    },
    ['shop:8'] = {          -- 24/7 Mirror Park
        vol_etalage = {
            caller = vector4(1160.08, -314.98, 69.20, 345.8),
            suspect = {
                vector4(1160.38, -313.72, 69.20, 164.4),
                vector4(1161.70, -314.00, 69.20, 153.0),
            },
        },
        braquage_superette = {
            caller = vector4(1164.98, -323.80, 69.20, 93.6),
            chief  = vector4(1163.40, -323.72, 69.20, 277.8),
            driver = vector4(1162.66, -331.56, 68.92, 153.0),
            vehicle = vector4(1161.34, -331.26, 68.52, 153.6),
            crew = {
                vector4(1160.96, -324.60, 69.20, 283.4),
                vector4(1162.54, -316.04, 69.20, 79.4),
                vector4(1160.58, -320.18, 69.20, 93.6),
            },
            bystander = {
                vector4(1153.70, -321.58, 69.20, 224.0),
                vector4(1154.72, -320.74, 69.20, 280.6),
                vector4(1156.12, -322.60, 69.20, 170.0),
            },
        },
    },
    ['shop:9'] = {          -- Supérette Richman Glen
        vol_etalage = {
            caller = vector4(-1828.16, 798.08, 138.18, 22.6),
            suspect = {
                vector4(-1828.66, 799.30, 138.16, 209.8),
                vector4(-1827.82, 799.88, 138.14, 164.4),
            },
        },
        braquage_superette = {
            caller = vector4(-1819.68, 793.80, 138.08, 138.8),
            chief  = vector4(-1821.22, 791.48, 138.12, 314.6),
            driver = vector4(-1817.82, 785.94, 137.88, 173.0),
            vehicle = vector4(-1819.18, 785.78, 137.52, 174.0),
            crew = {
                vector4(-1822.42, 796.96, 138.10, 221.2),
                vector4(-1826.08, 798.68, 138.12, 102.0),
                vector4(-1822.94, 788.88, 138.18, 204.0),
            },
            bystander = {
                vector4(-1827.42, 785.12, 138.30, 323.2),
                vector4(-1829.94, 789.06, 138.30, 275.0),
                vector4(-1830.94, 789.44, 138.32, 323.2),
                vector4(-1827.12, 788.72, 138.24, 286.2),
            },
        },
    },
}

--  AMBIANCE DE SCÈNE — COMPORTEMENTS PENDANT L'APPROCHE

C.SceneAmbience = {

    Enabled = true,
    Debug   = false,

    -- Distance à laquelle les PNJ remarquent la police et cessent leur
    NoticeDist = 20.0,

    -- Ils ne s'éloignent jamais plus que ça de leur point de départ.
    LeashRadius = 4.0,

    -- Durée d'un comportement avant d'en tirer un autre (ms)
    HoldMin = 7000,
    HoldMax = 15000,

    -- Distance de sécurité visée par les comportements de recul.
    SafeDistance = 12.0,

    -- Niveau de danger par mission. Absent = 1 (calme).
    Danger = {
        personne_armee     = 3,
        braquage_superette = 3,
        bagarre_rue        = 2,
        rixe_soiree        = 2,
        vol_arrache        = 2,
        chien_dangereux    = 2,
        delit_fuite        = 2,
        vol_vehicule       = 2,
        trafic_stup        = 2,
        cambriolage        = 2,
    },

    -- Geste de désignation, vérifié au chargement. Absent = ignoré.
    PointAnim = {
        male   = { dict = 'gestures@m@standing@casual', anim = 'gesture_point' },
        female = { dict = 'gestures@f@standing@casual', anim = 'gesture_point' },
    },

    -- Comportements par défaut, selon le rôle
    Roles = {

        -- Badauds, toutes missions sans surcharge dédiée (cf. byScenario
        bystander = {
            { id = 'enregistrer',    weight = 1, kind = 'scenario',
              scenario = 'WORLD_HUMAN_MOBILE_FILM_SHOCKING', maxDanger = 2 },
            { id = 'envoyer un sms', weight = 1, kind = 'scenario',
              scenario = 'WORLD_HUMAN_STAND_MOBILE' },
            { id = 'filmer choquant', weight = 1, kind = 'scenario',
              scenario = 'WORLD_HUMAN_MOBILE_FILM_SHOCKING', maxDanger = 2 },
            { id = 'recule',       weight = 4, kind = 'backoff', minDanger = 2 },
            { id = 'se met à couvert', weight = 5, kind = 'cower', minDanger = 3 },
        },

        caller = {
            { id = 'guette la police', weight = 4, kind = 'observe' },
            { id = 'appelle les secours', weight = 4, kind = 'phone' },
            { id = 'désigne la scène', weight = 2, kind = 'point' },
            { id = 'fait les cent pas', weight = 2, kind = 'pace', maxDanger = 2 },
            { id = 'recule',       weight = 3, kind = 'backoff', minDanger = 2 },
            { id = 'se met à couvert', weight = 4, kind = 'cower', minDanger = 3 },
        },

        victim = {
            -- Une victime debout vérifie ses affaires et appelle.
            { id = 'vérifie ses affaires', weight = 4, kind = 'scenario',
              scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
            { id = 'appelle', weight = 4, kind = 'phone' },
            { id = 'désigne la fuite', weight = 2, kind = 'point' },
        },
    },

    -- Surcharges par mission
    byScenario = {

        -- On garde ses distances, on ne s'attroupe pas autour du corps.
        decouverte_corps = {
            bystander = {
                { id = 'observe à distance', weight = 5, kind = 'observe' },
                { id = 'appelle les secours', weight = 3, kind = 'phone' },
                { id = 'commente',   weight = 3, kind = 'talk' },
                { id = 'photographie', weight = 1, kind = 'film' },
                { id = 'recule',     weight = 2, kind = 'backoff' },
            },
        },

        -- Discrétion : personne ne filme un point de deal.
        trafic_stup = {
            bystander = {
                { id = 'passe son chemin', weight = 5, kind = 'pace' },
                { id = 'regarde ailleurs', weight = 4, kind = 'scenario',
                  scenario = 'WORLD_HUMAN_STAND_MOBILE' },
                { id = 'observe discrètement', weight = 2, kind = 'observe' },
                { id = 'recule',   weight = 3, kind = 'backoff' },
            },
            caller = {
                { id = 'observe de loin', weight = 4, kind = 'observe' },
                { id = 'téléphone',  weight = 4, kind = 'phone' },
                { id = 'recule',     weight = 2, kind = 'backoff' },
            },
        },

        -- Attroupement bruyant : on filme, on commente, on recule quand
        bagarre_rue = {
            bystander = {
                { id = 'filme',    weight = 4, kind = 'film' },
                { id = 'observe',  weight = 4, kind = 'observe' },
                { id = 'commente', weight = 3, kind = 'talk' },
                { id = 'recule',   weight = 3, kind = 'backoff' },
                { id = 'désigne',  weight = 1, kind = 'point' },
            },
        },
        rixe_soiree = {
            bystander = {
                { id = 'filme',    weight = 4, kind = 'film' },
                { id = 'observe',  weight = 4, kind = 'observe' },
                { id = 'commente', weight = 4, kind = 'talk' },
                { id = 'recule',   weight = 3, kind = 'backoff' },
            },
        },

        -- Personne armée : plus personne ne filme, tout le monde s'écarte.
        personne_armee = {
            bystander = {
                { id = 'se met à couvert', weight = 6, kind = 'cower' },
                { id = 'recule',      weight = 5, kind = 'backoff' },
                { id = 'observe de loin', weight = 2, kind = 'observe' },
                { id = 'appelle la police', weight = 2, kind = 'phone' },
            },
            caller = {
                { id = 'se met à couvert', weight = 4, kind = 'cower' },
                { id = 'recule',      weight = 4, kind = 'backoff' },
                { id = 'appelle la police', weight = 3, kind = 'phone' },
            },
        },

        -- Braquage supérette : mélange assis effrayé / reddition (module
        braquage_superette = {
            bystander = {
                { id = 'assis effrayé',   weight = 1, kind = 'anim',
                  dict = 'anim@heists@ornate_bank@hostages@hit', clip = 'hit_loop_ped_b', loop = true },
                { id = 'assis effrayé 2', weight = 1, kind = 'anim',
                  dict = 'anim@heists@ornate_bank@hostages@ped_c@', clip = 'flinch_loop', loop = true },
                { id = 'assis effrayé 3', weight = 1, kind = 'anim',
                  dict = 'anim@heists@ornate_bank@hostages@ped_e@', clip = 'flinch_loop', loop = true },
                { id = 'reddition',   weight = 1, kind = 'anim',
                  dict = 'random@arrests@busted', clip = 'idle_a', loop = true },
                { id = 'reddition 2', weight = 1, kind = 'anim',
                  dict = 'mp_bank_heist_1', clip = 'f_cower_02', loop = true },
                { id = 'reddition 3', weight = 1, kind = 'anim',
                  dict = 'mp_bank_heist_1', clip = 'm_cower_01', loop = true },
                { id = 'reddition 4', weight = 1, kind = 'anim',
                  dict = 'mp_bank_heist_1', clip = 'm_cower_02', loop = true },
                { id = 'reddition 5', weight = 1, kind = 'anim',
                  dict = 'random@arrests', clip = 'kneeling_arrest_idle', loop = true },
                { id = 'reddition 6', weight = 1, kind = 'anim',
                  dict = 'rcmbarry', clip = 'm_cower_01', loop = true },
            },
        },

        vol_arrache = {
            bystander = {
                { id = 'regarde la fuite', weight = 4, kind = 'observe' },
                { id = 'désigne la direction', weight = 4, kind = 'point' },
                { id = 'appelle la police', weight = 3, kind = 'phone' },
                { id = 'commente', weight = 2, kind = 'talk' },
            },
            victim = {
                { id = 'vérifie ses affaires', weight = 5, kind = 'scenario',
                  scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
                { id = 'appelle la police', weight = 4, kind = 'phone' },
                { id = 'désigne la fuite', weight = 3, kind = 'point' },
            },
        },

        -- On observe de loin, on ne se met pas devant le véhicule.
        vol_vehicule = {
            bystander = {
                { id = 'observe à distance', weight = 5, kind = 'observe' },
                { id = 'appelle la police', weight = 4, kind = 'phone' },
                { id = 'recule',   weight = 3, kind = 'backoff' },
                { id = 'commente', weight = 2, kind = 'talk' },
            },
            caller = {
                { id = 'observe à distance', weight = 4, kind = 'observe' },
                { id = 'appelle la police', weight = 4, kind = 'phone' },
                { id = 'recule',   weight = 2, kind = 'backoff' },
            },
        },

        -- On contourne, on ne s'attroupe pas autour d'un homme ivre.
        ipm = {
            bystander = {
                { id = 'contourne', weight = 5, kind = 'pace' },
                { id = 'observe',   weight = 2, kind = 'observe' },
                { id = 'appelle les secours', weight = 2, kind = 'phone' },
                { id = 'commente',  weight = 2, kind = 'talk' },
            },
        },

        chien_dangereux = {
            bystander = {
                { id = 'recule',    weight = 5, kind = 'backoff' },
                { id = 'observe de loin', weight = 3, kind = 'observe' },
                { id = 'appelle les secours', weight = 3, kind = 'phone' },
                { id = 'désigne l\'animal', weight = 2, kind = 'point' },
            },
        },

        -- Tuerie de masse : le SEUL scénario où le danger (co.dangerLevel,
        tuerie_masse = {
            -- Mélange assis effrayé / reddition (même mix que
            bystander = {
                { id = 'assis effrayé',   weight = 1, kind = 'anim',
                  dict = 'anim@heists@ornate_bank@hostages@hit', clip = 'hit_loop_ped_b', loop = true },
                { id = 'assis effrayé 2', weight = 1, kind = 'anim',
                  dict = 'anim@heists@ornate_bank@hostages@ped_c@', clip = 'flinch_loop', loop = true },
                { id = 'assis effrayé 3', weight = 1, kind = 'anim',
                  dict = 'anim@heists@ornate_bank@hostages@ped_e@', clip = 'flinch_loop', loop = true },
                { id = 'reddition',   weight = 1, kind = 'anim',
                  dict = 'random@arrests@busted', clip = 'idle_a', loop = true },
                { id = 'reddition 2', weight = 1, kind = 'anim',
                  dict = 'mp_bank_heist_1', clip = 'f_cower_02', loop = true },
                { id = 'reddition 3', weight = 1, kind = 'anim',
                  dict = 'mp_bank_heist_1', clip = 'm_cower_01', loop = true },
                { id = 'reddition 4', weight = 1, kind = 'anim',
                  dict = 'mp_bank_heist_1', clip = 'm_cower_02', loop = true },
                { id = 'reddition 5', weight = 1, kind = 'anim',
                  dict = 'random@arrests', clip = 'kneeling_arrest_idle', loop = true },
                { id = 'reddition 6', weight = 1, kind = 'anim',
                  dict = 'rcmbarry', clip = 'm_cower_01', loop = true },
            },
            victim = {
                -- Victimes DEBOUT non blessées graves (choc/paniquée/
                { id = 'fuit',           weight = 5, kind = 'backoff', minDanger = 4 },
                { id = 'se cache',       weight = 5, kind = 'cower',   minDanger = 4 },
                { id = 'sous le choc',   weight = 4, kind = 'observe', minDanger = 2, maxDanger = 3 },
                { id = 'cherche un proche', weight = 3, kind = 'pace', minDanger = 2, maxDanger = 3 },
                { id = 'appelle un proche', weight = 3, kind = 'phone', maxDanger = 2 },
                { id = 'parle aux agents', weight = 3, kind = 'talk', maxDanger = 2 },
            },
            caller = {
                { id = 'à couvert',  weight = 5, kind = 'cower',   minDanger = 4 },
                { id = 'recule',     weight = 4, kind = 'backoff', minDanger = 3 },
                { id = 'au téléphone avec les secours', weight = 4, kind = 'phone', maxDanger = 3 },
                { id = 'guette l\'arrivée des agents', weight = 3, kind = 'observe', maxDanger = 2 },
            },
        },
    },
}

--  ATTENTE DU REQUÉRANT AU SEUIL  (constatation de vol par effraction)

C.Doorstep = {

    -- Journalise le comportement tiré et les transitions
    Debug = true,

    -- Distance à laquelle le requérant remarque un agent et cesse
    NoticeDist = 14.0,

    -- Il ne s'éloigne JAMAIS plus que ça de son point d'entrée : la
    LeashRadius = 2.2,

    -- Durée d'un comportement avant d'en tirer un autre (ms)
    HoldMin = 7000,
    HoldMax = 14000,

    -- Salut de la main à l'arrivée de l'agent, pour attirer son
    Greet = {
        male   = { dict = 'rcmnigel1c', anim = 'hailing_whistle_waive_a' },
        female = { dict = 'rcmnigel1c', anim = 'hailing_whistle_waive_a' },
    },

    -- Comportements d'attente
    Wait = {
        -- Il surveille sa porte, revient à la rue, y retourne
        { id = 'surveille la porte', weight = 3,
          scenario = 'WORLD_HUMAN_STAND_IMPATIENT', lookDoor = true },

        -- Il est au téléphone, comme s'il rappelait le central
        { id = 'au téléphone', weight = 3,
          scenario = 'WORLD_HUMAN_STAND_MOBILE' },

        -- Il guette la rue, un peu nerveux
        { id = 'guette la rue', weight = 2,
          scenario = 'WORLD_HUMAN_STAND_IMPATIENT', scan = true },

        -- Quelques pas devant l'entrée, puis retour près de la porte
        { id = 'fait les cent pas', weight = 2, pace = true },

        -- Il fume en attendant
        { id = 'fume', weight = 1,
          scenario = 'WORLD_HUMAN_SMOKING' },
    },
}

--  AMBIANCE — POSTURES ET COMPORTEMENTS DE SCÈNE

C.Ambience = {

    -- Journalise le choix de chaque posture
    Debug = false,

    -- Posture de dernier recours si tout échoue
    Fallback = { scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },

    -- Postures par défaut, tous scénarios confondus
    roles = {

        -- Le requérant : il a appelé, il attend, il s'impatiente
        caller = {
            { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 3 },
            { scenario = 'WORLD_HUMAN_STAND_MOBILE',    weight = 2 },
            { scenario = 'WORLD_HUMAN_SMOKING',         weight = 1 },
            { scenario = 'WORLD_HUMAN_LEANING',         weight = 1, needsWall = true },
        },

        -- Les badauds : ils filment, commentent, regardent
        bystander = {
            { scenario = 'WORLD_HUMAN_PAPARAZZI',       weight = 3 },
            { scenario = 'WORLD_HUMAN_STAND_MOBILE',    weight = 2 },
            { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 2 },
            { scenario = 'WORLD_HUMAN_SMOKING',         weight = 1 },
            { scenario = 'WORLD_HUMAN_TOURIST_MOBILE',  weight = 1 },
            { scenario = 'WORLD_HUMAN_LEANING',         weight = 1, needsWall = true },
        },

        -- Un individu passif qui attend sur place
        suspect = {
            { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 3 },
            { scenario = 'WORLD_HUMAN_SMOKING',         weight = 2 },
            { scenario = 'WORLD_HUMAN_STAND_MOBILE',    weight = 2 },
            { scenario = 'WORLD_HUMAN_HANG_OUT_STREET', weight = 2 },
            { scenario = 'WORLD_HUMAN_LEANING',         weight = 1, needsWall = true },
            -- Certains font le guet plutôt que d'attendre simplement.
            { scenario = 'CODE_HUMAN_CROSS_ROAD_WAIT',  weight = 1 },
        },
    },

    -- Surcharges par mission
    byScenario = {

        constatation_effraction = {
            -- Devant sa porte, il guette la rue
            caller = {
                { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 3 },
                { scenario = 'WORLD_HUMAN_STAND_MOBILE',    weight = 3 },
                { scenario = 'WORLD_HUMAN_SMOKING',         weight = 2 },
            },
        },

        decouverte_corps = {
            -- Il vient de découvrir un cadavre : il est au téléphone ou
            caller = {
                { scenario = 'WORLD_HUMAN_STAND_MOBILE',    weight = 4 },
                { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 2 },
                { scenario = 'WORLD_HUMAN_SMOKING',         weight = 1 },
            },
            bystander = {
                { scenario = 'WORLD_HUMAN_PAPARAZZI',       weight = 4 },
                { scenario = 'WORLD_HUMAN_STAND_MOBILE',    weight = 3 },
                { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 2 },
            },
        },

        personne_errante = {
            caller = {
                { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 3 },
                { scenario = 'WORLD_HUMAN_STAND_MOBILE',    weight = 2 },
            },
        },

        racolage = {
            suspect = {
                { scenario = 'WORLD_HUMAN_PROSTITUTE_HIGH_CLASS', weight = 3 },
                { scenario = 'WORLD_HUMAN_PROSTITUTE_LOW_CLASS',  weight = 3 },
                { scenario = 'WORLD_HUMAN_SMOKING',               weight = 2 },
                { scenario = 'WORLD_HUMAN_STAND_MOBILE',          weight = 1 },
            },
        },

        trafic_stup = {
            suspect = {
                { scenario = 'WORLD_HUMAN_DRUG_DEALER',      weight = 3 },
                { scenario = 'WORLD_HUMAN_DRUG_DEALER_HARD', weight = 2 },
                { scenario = 'WORLD_HUMAN_SMOKING',          weight = 2 },
                { scenario = 'WORLD_HUMAN_HANG_OUT_STREET',  weight = 1 },
            },
        },

        ipm = {
            -- L'individu tient à peine debout
            suspect = {
                { scenario = 'WORLD_HUMAN_DRINKING',     weight = 4 },
                { scenario = 'WORLD_HUMAN_BUM_STANDING', weight = 2 },
                { scenario = 'WORLD_HUMAN_SMOKING',      weight = 1 },
            },
            caller = {
                { scenario = 'WORLD_HUMAN_SMOKING',         weight = 3 },
                { scenario = 'WORLD_HUMAN_STAND_MOBILE',    weight = 2 },
                { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 2 },
            },
        },

        vol_etalage = {
            -- Le vigile surveille, l'individu attend
            caller = {
                { scenario = 'WORLD_HUMAN_GUARD_STAND',     weight = 4 },
                { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 2 },
            },
            suspect = {
                { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 3 },
                { scenario = 'WORLD_HUMAN_SMOKING',         weight = 1 },
            },
        },

        rixe_soiree = {
            caller = {
                { scenario = 'WORLD_HUMAN_STAND_MOBILE',    weight = 3 },
                { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 2 },
                { scenario = 'WORLD_HUMAN_SMOKING',         weight = 2 },
            },
            bystander = {
                { scenario = 'WORLD_HUMAN_PAPARAZZI',    weight = 3 },
                { scenario = 'WORLD_HUMAN_STAND_MOBILE', weight = 3 },
                { scenario = 'WORLD_HUMAN_SMOKING',      weight = 2 },
                { scenario = 'WORLD_HUMAN_DRINKING',     weight = 2, night = true },
            },
        },

        cambriolage = {
            caller = {
                { scenario = 'WORLD_HUMAN_STAND_MOBILE',    weight = 3 },
                { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 3 },
            },
        },

        braquage_superette = {
            caller = {
                { scenario = 'WORLD_HUMAN_STAND_MOBILE',    weight = 3 },
                { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 2 },
                { scenario = 'WORLD_HUMAN_SMOKING',         weight = 2 },
            },
        },

        delit_fuite = {
            caller = {
                { scenario = 'WORLD_HUMAN_STAND_MOBILE',    weight = 4 },
                { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 2 },
            },
        },

        chien_dangereux = {
            -- Le maître, dépassé par son animal
            suspect = {
                { scenario = 'WORLD_HUMAN_STAND_IMPATIENT', weight = 3 },
                { scenario = 'WORLD_HUMAN_STAND_MOBILE',    weight = 1 },
            },
        },

        -- Tapage : ils font la fête autour de la voiture-sono. Mélange
        tapage = {
            suspect = {
                { dict = 'anim@amb@nightclub@dancers@podium_dancers@', anim = 'hi_dance_facedj_17_v2_male^5', weight = 1 },
                { dict = 'anim@amb@nightclub@mini@dance@dance_solo@male@var_b@', anim = 'high_center_down', weight = 1 },
                { dict = 'anim@amb@nightclub@mini@dance@dance_solo@male@var_a@', anim = 'high_center', weight = 1 },
                { dict = 'anim@amb@nightclub@mini@dance@dance_solo@male@var_b@', anim = 'high_center_up', weight = 1 },
                { dict = 'anim@amb@casino@mini@dance@dance_solo@female@var_a@', anim = 'med_center', weight = 1 },
                { dict = 'misschinese2_crystalmazemcs1_cs', anim = 'dance_loop_tao', weight = 1 },
                { dict = 'misschinese2_crystalmazemcs1_ig', anim = 'dance_loop_tao', weight = 1 },
                { dict = 'anim@amb@nightclub@mini@dance@dance_solo@female@var_a@', anim = 'med_center_up', weight = 1 },
                { dict = 'anim@amb@nightclub_island@dancers@beachdanceprop@', anim = 'mi_idle_c_m01', weight = 1 },
                { dict = 'anim@amb@nightclub_island@dancers@crowddance_single_props@', anim = 'hi_dance_prop_09_v1_male^3', weight = 1 },
            },
        },
    },
}

--  PHRASÉ RADIO DU CENTRAL — registre Police Nationale

C.Dispatch = {
    prefix   = 'Central à toutes les unités disponibles',
    taken    = 'Bien reçu, unité en route. Central terminé.',
    backup   = 'Central à toutes les unités — demande de renfort sur l\'intervention en cours, secteur %s. %d agent(s) déjà sur place.',
    unpicked = 'Central — appel sans réponse, classé sans suite. Terminé.',
    ended    = 'Bien reçu. %s. Central terminé.',
}

--  SIGNALEMENT — DESCRIPTION DES ARMES

C.WeaponDescriptions = {
    ['WEAPON_PISTOL']     = 'un pistolet',
    ['WEAPON_COMBATPISTOL'] = 'un pistolet',
    ['WEAPON_KNIFE']      = 'un couteau',
    ['WEAPON_BAT']        = 'une batte',
    ['WEAPON_MACHETE']    = 'une machette',
}
C.WeaponFallback = 'quelque chose à la main'

-- Désignation ADMINISTRATIVE des armes, pour la fiche d'intervention du
C.WeaponLabels = {
    ['WEAPON_PISTOL']       = 'Pistolet semi-automatique',
    ['WEAPON_COMBATPISTOL'] = 'Pistolet de combat',
    ['WEAPON_KNIFE']        = 'Couteau',
    ['WEAPON_BAT']          = 'Batte de baseball',
    ['WEAPON_MACHETE']      = 'Machette',
    ['WEAPON_STUNGUN']      = 'Pistolet à impulsion électrique',
    ['WEAPON_NIGHTSTICK']   = 'Matraque',
    ['WEAPON_FLASHLIGHT']   = 'Lampe torche',
    -- Tuerie de masse : armes automatiques du suspect, absentes de
    ['WEAPON_SMG']          = 'Mitraillette',
    ['WEAPON_MICROSMG']     = 'Mini-mitraillette',
    ['WEAPON_ASSAULTRIFLE'] = 'Fusil d\'assaut',
}

-- Points cardinaux utilisés pour la direction de fuite
C.Directions = {
    'vers le nord', 'vers le nord-est', 'vers l\'est', 'vers le sud-est',
    'vers le sud', 'vers le sud-ouest', 'vers l\'ouest', 'vers le nord-ouest',
}

-- Formulations de fausse alerte (révélées en interrogeant le requérant)
C.FalseAlarmLines = {
    "Excusez-moi… la dispute s'est terminée juste avant que vous arriviez.",
    "Je crois que je me suis trompé, l'individu était un livreur.",
    "Finalement le bruit venait d'une télévision chez le voisin.",
    "La personne est repartie d'elle-même, désolée de vous avoir dérangés.",
    "Je n'ai pas dû bien voir, tout a l'air normal maintenant.",
}

--  EMPLACEMENTS DE SPAWN — coordonnées du REQUÉRANT

C.Locations = {

    -- RUE / VOIE PUBLIQUE
    street = {
        -- Tuerie de masse : réservée aux 5 lieux relevés à la main
        { coords = vector4(195.0,   -933.6,  30.7,  145.0), label = 'Legion Square', zone = 'downtown',
          exclude = { 'decouverte_corps', 'delit_fuite' } },
        { coords = vector4(-1223.5, -1493.6, 4.4,   215.0), label = 'Vespucci Beach', zone = 'beach' },
        { coords = vector4(300.5,   200.3,   104.6, 70.0),  label = 'Vinewood Boulevard', zone = 'downtown',
          exclude = { 'decouverte_corps', 'delit_fuite' } },
        { coords = vector4(88.5,    -1959.5, 21.1,  320.0), label = 'Grove Street', zone = 'urban',
          exclude = { 'tuerie_masse' } },
        { coords = vector4(-540.0,  -855.0,  27.0,  180.0), label = 'Little Seoul', zone = 'urban',
          exclude = { 'tuerie_masse' } },
        { coords = vector4(1080.0,  -480.0,  64.0,  95.0),  label = 'Mirror Park', zone = 'downtown',
          exclude = { 'tuerie_masse' } },
        { coords = vector4(-1330.0, -370.0,  36.0,  250.0), label = 'Rockford Hills', zone = 'affluent',
          exclude = { 'decouverte_corps', 'tuerie_masse' } },
        { coords = vector4(250.0,   -1150.0, 29.3,  90.0),  label = 'Textile City', zone = 'downtown',
          exclude = { 'tuerie_masse' } },
        { coords = vector4(300.0,   -1800.0, 28.0,  45.0),  label = 'Strawberry', zone = 'urban',
          exclude = { 'tuerie_masse' } },
        { coords = vector4(430.0,   -800.0,  29.5,  180.0), label = 'Pillbox Hill', zone = 'downtown',
          exclude = { 'tuerie_masse' } },
        { coords = vector4(330.0,   -220.0,  54.0,  160.0), label = 'Alta Street', zone = 'affluent',
          exclude = { 'delit_fuite', 'tuerie_masse' } },
        { coords = vector4(-680.0,  -60.0,   41.0,  210.0), label = 'Eclipse Boulevard', zone = 'downtown' },
        { coords = vector4(-1180.0, -1200.0, 6.0,   300.0), label = 'Vespucci Boulevard', zone = 'urban',
          exclude = { 'tuerie_masse' } },
        { coords = vector4(150.0,   -1500.0, 29.2,  225.0), label = 'Davis Avenue', zone = 'urban',
          exclude = { 'tuerie_masse' } },
        { coords = vector4(330.0,   -2050.0, 20.5,  50.0),  label = 'Innocence Boulevard', zone = 'urban',
          exclude = { 'tuerie_masse' } },
        -- Terrain dégagé, quelques habitations éparses : crédible pour
        { coords = vector4(1350.0,  -1500.0, 57.0,  100.0), label = 'El Burro Heights', zone = 'industrial',
          only = { 'decouverte_corps', 'personne_errante' } },
        { coords = vector4(900.0,   -1900.0, 29.1,  270.0), label = 'Cypress Flats', zone = 'industrial',
          exclude = { 'racolage', 'bagarre_rue', 'vol_arrache', 'tuerie_masse' } },
        { coords = vector4(420.0,   -1000.0, 29.3,  15.0),  label = 'Mission Row', zone = 'downtown',
          exclude = { 'racolage', 'decouverte_corps', 'delit_fuite', 'personne_armee', 'vol_arrache', 'tuerie_masse' } },
        { coords = vector4(250.0,   100.0,   97.7,  340.0), label = 'Downtown Vinewood', zone = 'downtown',
          exclude = { 'delit_fuite', 'personne_armee', 'vol_arrache', 'tuerie_masse' } },
        { coords = vector4(200.0,   30.0,    81.4,  115.0), label = 'Hawick Avenue', zone = 'downtown',
          exclude = { 'delit_fuite', 'personne_armee', 'vol_arrache', 'tuerie_masse' } },
        { coords = vector4(-100.0,  -2450.0, 6.5,   45.0),  label = 'Banning', zone = 'industrial',
          exclude = { 'racolage', 'bagarre_rue', 'delit_fuite', 'vol_arrache', 'tuerie_masse' } },
        { coords = vector4(-260.0,  -960.0,  31.2,  250.0), label = 'Vespucci Boulevard Est', zone = 'urban',
          exclude = { 'decouverte_corps', 'delit_fuite' } },
        { coords = vector4(-820.0,  -1080.0, 11.0,  30.0),  label = 'Bay City Avenue', zone = 'beach',
          exclude = { 'tuerie_masse' } },
        { coords = vector4(1180.0,  -1300.0, 34.5,  270.0), label = 'Popular Street', zone = 'industrial',
          exclude = { 'bagarre_rue', 'vol_arrache', 'tuerie_masse' } },
    },

    -- SEUILS D'HABITATION
    doorstep = {
        -- COLLINES ET QUARTIERS HUPPÉS (34)
        { coords = vector4(41.06, 361.41, 116.04, 224.3), label = 'Vinewood West', zone = 'affluent' },
        { coords = vector4(-510.17, 100.86, 63.80, 8.8), label = 'Vinewood West', zone = 'affluent' },
        { coords = vector4(-161.34, -5.70, 62.46, 232.3), label = 'Vinewood West', zone = 'affluent' },
        { coords = vector4(-161.23, -5.65, 66.45, 238.4), label = 'Vinewood West', zone = 'affluent' },
        { coords = vector4(-103.91, 1.26, 70.24, 72.9), label = 'Vinewood West', zone = 'affluent' },
        { coords = vector4(-103.41, 0.83, 74.44, 327.3), label = 'Vinewood West', zone = 'affluent' },
        { coords = vector4(-1465.16, 51.09, 53.02, 355.5), label = 'Richman', zone = 'affluent' },
        { coords = vector4(-1565.44, 41.32, 58.85, 344.9), label = 'Richman', zone = 'affluent' },
        { coords = vector4(-178.36, 503.36, 136.85, 24.8), label = 'Vinewood Hills', zone = 'affluent' },
        { coords = vector4(-229.08, 490.13, 128.76, 14.4), label = 'Vinewood Hills', zone = 'affluent' },
        { coords = vector4(-318.93, 464.90, 108.71, 165.5), label = 'Vinewood Hills', zone = 'affluent' },
        { coords = vector4(-58.72, 493.39, 144.70, 347.3), label = 'Vinewood Hills', zone = 'affluent' },
        { coords = vector4(-5.64, 469.91, 145.88, 343.8), label = 'Vinewood Hills', zone = 'affluent' },
        { coords = vector4(59.73, 452.02, 146.78, 15.0), label = 'Vinewood Hills', zone = 'affluent' },
        { coords = vector4(51.85, 466.83, 146.73, 219.3), label = 'Vinewood Hills', zone = 'affluent' },
        { coords = vector4(169.55, 486.99, 142.94, 343.3), label = 'Vinewood Hills', zone = 'affluent' },
        { coords = vector4(221.61, 514.12, 140.74, 35.8), label = 'Vinewood Hills', zone = 'affluent' },
        { coords = vector4(319.02, 563.72, 154.54, 23.4), label = 'Vinewood Hills', zone = 'affluent' },
        { coords = vector4(371.04, 430.12, 145.10, 349.2), label = 'Centre de Vinewood', zone = 'affluent' },
        { coords = vector4(-1881.89, -579.27, 11.82, 314.6), label = 'Pacific Bluffs', zone = 'affluent' },
        { coords = vector4(-1919.31, -541.81, 11.84, 314.0), label = 'Pacific Bluffs', zone = 'affluent' },
        { coords = vector4(-1970.80, -531.32, 12.17, 101.5), label = 'Pacific Bluffs', zone = 'affluent' },
        { coords = vector4(-1954.27, -551.00, 11.86, 139.3), label = 'Pacific Bluffs', zone = 'affluent' },
        { coords = vector4(-1940.60, -562.96, 11.83, 133.5), label = 'Pacific Bluffs', zone = 'affluent' },
        { coords = vector4(-1922.08, -578.25, 11.85, 133.8), label = 'Pacific Bluffs', zone = 'affluent' },
        { coords = vector4(-1904.12, -593.34, 11.86, 138.0), label = 'Pacific Bluffs', zone = 'affluent' },
        { coords = vector4(-1886.39, -608.81, 11.82, 137.9), label = 'Pacific Bluffs', zone = 'affluent' },
        { coords = vector4(-1596.81, -353.58, 45.98, 229.1), label = 'Pacific Bluffs', zone = 'affluent' },
        { coords = vector4(-1621.53, -381.72, 43.72, 244.9), label = 'Pacific Bluffs', zone = 'affluent' },
        { coords = vector4(-1333.60, -260.45, 42.38, 126.6), label = 'Morningwood', zone = 'affluent' },
        { coords = vector4(-1303.08, -270.64, 40.07, 299.7), label = 'Morningwood', zone = 'affluent' },
        { coords = vector4(-1499.15, -201.89, 50.76, 313.3), label = 'Morningwood', zone = 'affluent' },
        { coords = vector4(-1356.72, -212.40, 43.69, 219.2), label = 'Rockford Hills', zone = 'affluent' },
        { coords = vector4(-1290.95, -279.56, 38.68, 31.9), label = 'Rockford Hills', zone = 'affluent' },

        -- IMMEUBLES DU CENTRE (14)
        { coords = vector4(-41.43, -57.64, 63.51, 72.4), label = 'Hawick', zone = 'downtown' },
        { coords = vector4(-19.00, -69.93, 61.38, 74.4), label = 'Hawick', zone = 'downtown' },
        { coords = vector4(-16.77, -59.20, 61.38, 134.3), label = 'Hawick', zone = 'downtown' },
        { coords = vector4(-27.91, -62.18, 63.57, 234.7), label = 'Hawick', zone = 'downtown' },
        { coords = vector4(-28.12, -61.76, 67.59, 345.9), label = 'Hawick', zone = 'downtown' },
        { coords = vector4(-25.82, -54.35, 67.59, 340.4), label = 'Hawick', zone = 'downtown' },
        { coords = vector4(-102.34, -32.95, 66.44, 247.6), label = 'Burton', zone = 'downtown' },
        { coords = vector4(-102.30, -33.06, 70.43, 242.1), label = 'Burton', zone = 'downtown' },
        { coords = vector4(-116.46, -36.53, 62.20, 46.1), label = 'Burton', zone = 'downtown' },
        { coords = vector4(7.36, -243.38, 47.66, 162.9), label = 'Alta', zone = 'downtown' },
        { coords = vector4(3.99, -241.43, 51.86, 72.1), label = 'Alta', zone = 'downtown' },
        { coords = vector4(9.44, -243.78, 51.86, 79.2), label = 'Alta', zone = 'downtown' },
        { coords = vector4(3.75, -241.40, 55.86, 88.8), label = 'Alta', zone = 'downtown' },
        { coords = vector4(9.55, -243.87, 55.86, 89.2), label = 'Alta', zone = 'downtown' },

        -- PAVILLONNAIRE ET FRONT DE MER (43)
        { coords = vector4(1303.00, -571.05, 71.61, 342.9), label = 'Mirror Park', zone = 'residential' },
        { coords = vector4(1303.08, -530.35, 71.26, 147.1), label = 'Mirror Park', zone = 'residential' },
        { coords = vector4(1370.91, -556.88, 74.34, 155.6), label = 'Mirror Park', zone = 'residential' },
        { coords = vector4(1384.61, -591.11, 74.34, 51.1), label = 'Mirror Park', zone = 'residential' },
        { coords = vector4(1226.83, -724.67, 60.63, 102.5), label = 'Mirror Park', zone = 'residential' },
        { coords = vector4(1220.29, -698.13, 60.78, 109.6), label = 'Mirror Park', zone = 'residential' },
        { coords = vector4(1204.61, -621.50, 66.12, 88.6), label = 'Mirror Park', zone = 'residential' },
        { coords = vector4(1270.43, -707.09, 64.72, 241.6), label = 'Mirror Park', zone = 'residential' },
        { coords = vector4(-1101.26, -1005.81, 2.15, 31.1), label = 'Canaux de Vespucci', zone = 'residential' },
        { coords = vector4(-1074.34, -1026.99, 4.55, 28.3), label = 'Canaux de Vespucci', zone = 'residential' },
        { coords = vector4(-1105.03, -1057.53, 2.13, 34.1), label = 'Canaux de Vespucci', zone = 'residential' },
        { coords = vector4(-1056.55, -997.28, 6.41, 191.3), label = 'Canaux de Vespucci', zone = 'residential' },
        { coords = vector4(-992.66, -1105.55, 2.15, 296.4), label = 'Canaux de Vespucci', zone = 'residential' },
        { coords = vector4(-891.70, -996.87, 2.16, 307.8), label = 'Canaux de Vespucci', zone = 'residential' },
        { coords = vector4(-933.11, -939.37, 2.15, 16.1), label = 'Canaux de Vespucci', zone = 'residential' },
        { coords = vector4(-1027.96, -921.08, 5.04, 287.4), label = 'Canaux de Vespucci', zone = 'residential' },
        { coords = vector4(-1062.35, -944.41, 2.18, 202.7), label = 'Canaux de Vespucci', zone = 'residential' },
        { coords = vector4(-1090.60, -923.94, 3.19, 32.3), label = 'Canaux de Vespucci', zone = 'residential' },
        { coords = vector4(-1072.31, -1653.50, 4.46, 116.9), label = 'La Puerta', zone = 'residential' },
        { coords = vector4(-1084.56, -1557.69, 4.51, 40.5), label = 'La Puerta', zone = 'residential' },
        { coords = vector4(-1078.29, -1551.40, 4.61, 59.4), label = 'La Puerta', zone = 'residential' },
        { coords = vector4(-1066.29, -1543.99, 4.85, 36.9), label = 'La Puerta', zone = 'residential' },
        { coords = vector4(-1058.30, -1538.83, 5.02, 33.8), label = 'La Puerta', zone = 'residential' },
        { coords = vector4(-1027.35, -1573.04, 5.18, 299.9), label = 'La Puerta', zone = 'residential' },
        { coords = vector4(-1754.73, -692.98, 10.13, 297.0), label = 'Del Perro', zone = 'residential' },
        { coords = vector4(-1769.68, -677.91, 10.36, 302.2), label = 'Del Perro', zone = 'residential' },
        { coords = vector4(-1811.99, -638.81, 10.94, 311.4), label = 'Del Perro', zone = 'residential' },
        { coords = vector4(-1867.32, -590.94, 11.86, 299.2), label = 'Del Perro', zone = 'residential' },
        { coords = vector4(-1857.11, -635.72, 11.03, 134.6), label = 'Del Perro', zone = 'residential' },
        { coords = vector4(-1829.69, -658.94, 10.52, 138.2), label = 'Del Perro', zone = 'residential' },
        { coords = vector4(-1820.08, -666.68, 10.54, 138.1), label = 'Del Perro', zone = 'residential' },
        { coords = vector4(-1793.91, -682.43, 10.64, 128.7), label = 'Del Perro', zone = 'residential' },
        { coords = vector4(-1778.94, -701.89, 10.41, 137.0), label = 'Del Perro', zone = 'residential' },
        { coords = vector4(-1754.07, -723.59, 10.39, 143.5), label = 'Del Perro', zone = 'residential' },
        { coords = vector4(771.00, -152.32, 74.42, 147.4), label = 'Vinewood East', zone = 'residential' },
        { coords = vector4(800.06, -157.87, 74.89, 135.7), label = 'Vinewood East', zone = 'residential' },
        { coords = vector4(806.56, -165.39, 74.02, 148.9), label = 'Vinewood East', zone = 'residential' },
        { coords = vector4(821.88, -155.52, 80.75, 166.0), label = 'Vinewood East', zone = 'residential' },
        { coords = vector4(839.73, -180.95, 74.19, 141.6), label = 'Vinewood East', zone = 'residential' },
        { coords = vector4(880.68, -206.14, 71.98, 55.8), label = 'Vinewood East', zone = 'residential' },
        { coords = vector4(919.10, -239.12, 70.10, 172.5), label = 'Vinewood East', zone = 'residential' },
        { coords = vector4(931.40, -247.95, 68.61, 105.8), label = 'Vinewood East', zone = 'residential' },
        { coords = vector4(949.59, -250.15, 67.63, 161.0), label = 'Vinewood East', zone = 'residential' },

        -- BORD DE PLAGE (4)
        { coords = vector4(-1104.19, -1636.12, 4.62, 304.3), label = 'Vespucci Beach', zone = 'beach' },
        { coords = vector4(-1118.52, -1625.18, 4.41, 307.7), label = 'Vespucci Beach', zone = 'beach' },
        { coords = vector4(-1351.24, -1160.96, 4.50, 97.5), label = 'Vespucci Beach', zone = 'beach' },
        { coords = vector4(-1334.84, -1145.41, 6.73, 93.1), label = 'Vespucci Beach', zone = 'beach' },

        -- SUD ET EST DE LOS SANTOS (53)
        { coords = vector4(291.52, -1792.02, 27.70, 231.0), label = 'Rancho', zone = 'urban' },
        { coords = vector4(480.11, -1771.46, 28.51, 260.2), label = 'Rancho', zone = 'urban' },
        { coords = vector4(474.24, -1777.14, 28.69, 250.8), label = 'Rancho', zone = 'urban' },
        { coords = vector4(456.19, -1579.95, 32.79, 309.9), label = 'Rancho', zone = 'urban' },
        { coords = vector4(468.87, -1589.87, 32.79, 62.0), label = 'Rancho', zone = 'urban' },
        { coords = vector4(82.73, -1946.77, 20.82, 325.6), label = 'Davis', zone = 'urban' },
        { coords = vector4(-52.79, -1784.08, 27.86, 130.1), label = 'Davis', zone = 'urban' },
        { coords = vector4(-47.56, -1796.63, 27.29, 133.7), label = 'Davis', zone = 'urban' },
        { coords = vector4(-32.73, -1845.71, 26.19, 245.8), label = 'Davis', zone = 'urban' },
        { coords = vector4(-20.61, -1856.81, 25.02, 324.7), label = 'Davis', zone = 'urban' },
        { coords = vector4(-3.85, -1870.22, 24.15, 6.9), label = 'Davis', zone = 'urban' },
        { coords = vector4(5.30, -1882.03, 23.32, 321.2), label = 'Davis', zone = 'urban' },
        { coords = vector4(25.14, -1896.10, 22.57, 328.9), label = 'Davis', zone = 'urban' },
        { coords = vector4(44.96, -1867.31, 22.85, 126.2), label = 'Davis', zone = 'urban' },
        { coords = vector4(-62.60, -1451.59, 32.12, 153.6), label = 'Strawberry', zone = 'urban' },
        { coords = vector4(-15.34, -1444.59, 30.65, 176.3), label = 'Strawberry', zone = 'urban' },
        { coords = vector4(13.59, -1454.01, 30.54, 159.9), label = 'Strawberry', zone = 'urban' },
        { coords = vector4(-160.28, -1637.79, 34.03, 43.4), label = 'Chamberlain Hills', zone = 'urban' },
        { coords = vector4(-162.59, -1637.19, 37.25, 254.8), label = 'Chamberlain Hills', zone = 'urban' },
        { coords = vector4(-213.90, -1617.70, 34.87, 8.4), label = 'Chamberlain Hills', zone = 'urban' },
        { coords = vector4(-222.59, -1586.86, 34.87, 274.3), label = 'Chamberlain Hills', zone = 'urban' },
        { coords = vector4(-216.78, -1576.48, 38.05, 185.8), label = 'Chamberlain Hills', zone = 'urban' },
        { coords = vector4(805.92, -1073.81, 28.65, 136.0), label = 'La Mesa', zone = 'urban' },
        { coords = vector4(781.41, -1299.96, 26.26, 264.5), label = 'La Mesa', zone = 'urban' },
        { coords = vector4(767.76, -1317.44, 27.28, 216.7), label = 'La Mesa', zone = 'urban' },
        { coords = vector4(782.38, -1277.62, 26.37, 262.2), label = 'La Mesa', zone = 'urban' },
        { coords = vector4(802.60, -989.32, 26.09, 160.1), label = 'La Mesa', zone = 'urban' },
        { coords = vector4(847.67, -1018.24, 27.83, 84.6), label = 'La Mesa', zone = 'urban' },
        { coords = vector4(1145.75, -1000.69, 45.25, 279.7), label = 'Murrieta Heights', zone = 'urban' },
        { coords = vector4(1143.36, -987.72, 45.85, 268.2), label = 'Murrieta Heights', zone = 'urban' },
        { coords = vector4(1212.21, -1389.35, 35.38, 178.4), label = 'Murrieta Heights', zone = 'urban' },
        { coords = vector4(1185.72, -1396.46, 35.14, 259.3), label = 'El Burro Heights', zone = 'urban' },
        { coords = vector4(1258.92, -1758.86, 49.26, 38.2), label = 'El Burro Heights', zone = 'urban' },
        { coords = vector4(1249.22, -1736.83, 51.63, 257.1), label = 'El Burro Heights', zone = 'urban' },
        { coords = vector4(1276.39, -1723.63, 54.65, 196.3), label = 'El Burro Heights', zone = 'urban' },
        { coords = vector4(1298.09, -1737.75, 53.88, 331.7), label = 'El Burro Heights', zone = 'urban' },
        { coords = vector4(1289.26, -1714.00, 55.03, 205.1), label = 'El Burro Heights', zone = 'urban' },
        { coords = vector4(1357.42, -1692.63, 60.52, 251.0), label = 'El Burro Heights', zone = 'urban' },
        { coords = vector4(1194.06, -1655.22, 43.03, 75.4), label = 'El Burro Heights', zone = 'urban' },
        { coords = vector4(1194.16, -1624.51, 45.22, 166.7), label = 'El Burro Heights', zone = 'urban' },
        { coords = vector4(1245.41, -1625.21, 53.28, 27.3), label = 'El Burro Heights', zone = 'urban' },
        { coords = vector4(-715.47, -865.56, 23.22, 272.0), label = 'Little Seoul', zone = 'urban' },
        { coords = vector4(-719.05, -899.23, 20.34, 342.1), label = 'Little Seoul', zone = 'urban' },
        { coords = vector4(-726.51, -904.86, 20.04, 159.0), label = 'Little Seoul', zone = 'urban' },
        { coords = vector4(-689.27, -911.40, 23.67, 71.8), label = 'Little Seoul', zone = 'urban' },
        { coords = vector4(-654.45, -933.40, 22.54, 348.6), label = 'Little Seoul', zone = 'urban' },
        { coords = vector4(-689.42, -893.71, 24.50, 273.2), label = 'Little Seoul', zone = 'urban' },
        { coords = vector4(-684.46, -876.52, 24.50, 177.1), label = 'Little Seoul', zone = 'urban' },
        { coords = vector4(-676.45, -884.11, 24.43, 87.1), label = 'Little Seoul', zone = 'urban' },
        { coords = vector4(-706.38, -1034.90, 16.11, 264.0), label = 'Little Seoul', zone = 'urban' },
        { coords = vector4(-712.02, -1027.11, 16.11, 266.1), label = 'Little Seoul', zone = 'urban' },
        { coords = vector4(-703.78, -1022.57, 16.11, 181.0), label = 'Little Seoul', zone = 'urban' },
        { coords = vector4(-700.21, -1030.93, 16.11, 192.6), label = 'Little Seoul', zone = 'urban' },
    },

    -- QUARTIERS RÉSIDENTIELS
    residential = {
        { coords = vector4(-179.5,  494.2,   132.0, 250.0), label = 'Wild Oats Drive', zone = 'affluent',
          exclude = { 'cambriolage' } },
        { coords = vector4(-1394.0, 55.0,    53.0,  120.0), label = 'Richman Street', zone = 'affluent',
          exclude = { 'cambriolage' } },
        { coords = vector4(-800.0,  180.0,   71.0,  120.0), label = 'Rockford Hills', zone = 'affluent',
          exclude = { 'cambriolage' } },
        { coords = vector4(1300.0,  -560.0,  70.0,  250.0), label = 'Mirror Park', zone = 'downtown',
          exclude = { 'cambriolage' } },
        { coords = vector4(120.0,   -1900.0, 22.0,  320.0), label = 'Grove Street', zone = 'urban',
          exclude = { 'cambriolage' } },
        { coords = vector4(-100.0,  -1600.0, 32.0,  210.0), label = 'Chamberlain Hills', zone = 'urban',
          exclude = { 'cambriolage' } },
        { coords = vector4(100.0,   250.0,   110.0, 85.0),  label = 'West Vinewood', zone = 'affluent',
          exclude = { 'cambriolage' } },
        { coords = vector4(-1100.0, -1000.0, 2.2,   160.0), label = 'Vespucci Canals', zone = 'beach',
          exclude = { 'cambriolage' } },
        { coords = vector4(1400.0,  -750.0,  67.0,  180.0), label = 'East Vinewood', zone = 'affluent',
          exclude = { 'cambriolage' } },
        { coords = vector4(-380.0,  -1700.0, 20.0,  50.0),  label = 'La Puerta', zone = 'industrial',
          exclude = { 'chien_dangereux', 'cambriolage' } },
        { coords = vector4(-60.0,   -1450.0, 32.0,  270.0), label = 'Carson Avenue', zone = 'urban',
          exclude = { 'cambriolage' } },
        { coords = vector4(370.0,   -1650.0, 29.3,  140.0), label = 'Roy Lowenstein Boulevard', zone = 'urban',
          exclude = { 'cambriolage' } },
        { coords = vector4(-1500.0, -680.0,  29.0,  35.0),  label = 'Prosperity Street', zone = 'urban',
          exclude = { 'cambriolage' } },
        { coords = vector4(1130.0,  -980.0,  46.0,  90.0),  label = 'Hawick', zone = 'downtown',
          exclude = { 'cambriolage' } },
        { coords = vector4(-720.0,  -900.0,  20.0,  180.0), label = 'Vespucci Nord', zone = 'urban',
          exclude = { 'cambriolage' } },
        { coords = vector4(-1620.0, -350.0,  46.0,  225.0), label = 'Morningwood', zone = 'affluent',
          exclude = { 'cambriolage' } },
        { coords = vector4(490.0,   -1770.0, 29.0,  310.0), label = 'Rancho', zone = 'urban',
          exclude = { 'cambriolage' } },
        { coords = vector4(970.0,   -1550.0, 31.0,  90.0),  label = 'Cypress Flats', zone = 'industrial',
          exclude = { 'chien_dangereux', 'cambriolage' } },
        { coords = vector4(340.0,   -60.0,   88.0,  250.0), label = 'Vinewood Hills Sud', zone = 'affluent',
          exclude = { 'cambriolage' } },
        { coords = vector4(-450.0,  260.0,   83.0,  140.0), label = 'North Sheldon Avenue', zone = 'affluent',
          exclude = { 'cambriolage' } },
        { coords = vector4(1250.0,  -420.0,  69.0,  200.0), label = 'Mirror Park Est', zone = 'downtown',
          exclude = { 'cambriolage' } },
        -- Habitations relevées à la main, avec intérieur accessible : la
        { coords = vector4(1276.81, -1725.16, 54.65, 210.7), label = 'El Burro Heights', zone = 'industrial' },
        { coords = vector4(-95.36,  -8.98,    66.40, 69.8),  label = 'Vinewood West', zone = 'downtown' },
        { coords = vector4(-1153.66, -1549.72, 4.28, 138.3), label = 'La Puerta', zone = 'industrial' },
        { coords = vector4(-830.94, 166.69, 69.43, 143.2), label = 'Rockford Hills', zone = 'affluent' },
        { coords = vector4(13.05, 547.62, 176.04, 329.4), label = 'Vinewood Hills', zone = 'affluent',
          exclude = { 'chien_dangereux' } },
    },

    -- COMMERCES / SUPÉRETTES
    shop = {
        { coords = vector4(25.7,    -1347.3, 29.5,  270.0), label = '24/7 Strawberry', zone = 'urban' },
        { coords = vector4(-47.4,   -1757.5, 29.4,  50.0),  label = 'LTD Davis', zone = 'urban' },
        { coords = vector4(-707.5,  -914.4,  19.2,  90.0),  label = 'LTD Little Seoul', zone = 'urban' },
        { coords = vector4(1135.8,  -982.3,  46.4,  270.0), label = "Rob's Liquor Hawick", zone = 'downtown' },
        { coords = vector4(-1222.9, -906.9,  12.3,  30.0),  label = "Rob's Liquor Prosperity", zone = 'urban' },
        { coords = vector4(-1487.5, -379.1,  40.1,  135.0), label = "Rob's Liquor Morningwood", zone = 'affluent' },
        { coords = vector4(373.9,   325.9,   103.6, 250.0), label = '24/7 Vinewood', zone = 'affluent' },
        { coords = vector4(1163.4,  -323.8,  69.2,  100.0), label = '24/7 Mirror Park', zone = 'downtown' },
        { coords = vector4(-1820.0, 793.0,   138.0, 130.0), label = 'Supérette Richman Glen', zone = 'affluent' },
    },

    -- POINTS DE DEAL
    dealpoint = {
        { coords = vector4(108.0,   -1961.0, 21.3,  320.0), label = 'Grove Street', zone = 'urban' },
        { coords = vector4(130.0,   -1780.0, 29.3,  230.0), label = 'Forum Drive, Davis', zone = 'urban' },
        { coords = vector4(200.0,   -1650.0, 29.5,  45.0),  label = 'Strawberry Avenue', zone = 'urban' },
        { coords = vector4(-1150.0, -1520.0, 10.6,  120.0), label = 'Vespucci Canals', zone = 'beach' },
        { coords = vector4(400.0,   -1900.0, 26.0,  180.0), label = 'Rancho', zone = 'urban' },
        { coords = vector4(1050.0,  -430.0,  64.0,  80.0),  label = 'Ruelle de Mirror Park', zone = 'downtown' },
        { coords = vector4(800.0,   -1600.0, 30.0,  270.0), label = 'La Mesa', zone = 'urban' },
        { coords = vector4(-600.0,  -1200.0, 15.0,  200.0), label = 'La Puerta', zone = 'industrial' },
        { coords = vector4(-160.0,  -1620.0, 34.0,  90.0),  label = 'Chamberlain Hills', zone = 'urban' },
        { coords = vector4(470.0,   -1300.0, 29.5,  310.0), label = 'Ruelle de Textile City', zone = 'downtown' },
        { coords = vector4(-1290.0, -1120.0, 6.5,   45.0),  label = 'Vespucci Beach Nord', zone = 'beach' },
        { coords = vector4(1420.0,  -1650.0, 63.0,  180.0), label = 'El Burro Heights', zone = 'industrial' },
        { coords = vector4(-70.0,   -1100.0, 26.5,  250.0), label = 'Ruelle de Strawberry', zone = 'urban' },
        { coords = vector4(940.0,   -1720.0, 30.5,  90.0),  label = 'Cypress Flats', zone = 'industrial' },
        { coords = vector4(-230.0,  -1600.0, 34.0,  200.0), label = 'Carson Avenue', zone = 'urban' },
        { coords = vector4(310.0,   -1450.0, 29.5,  140.0), label = 'Davis Nord', zone = 'urban' },
    },

    -- VIE NOCTURNE
    nightlife = {
        { coords = vector4(-565.2,  276.6,   83.2,  90.0),  label = 'Tequi-la-la', zone = 'downtown' },
        { coords = vector4(127.0,   -1307.0, 29.2,  210.0), label = 'Vanilla Unicorn', zone = 'downtown' },
        { coords = vector4(-1607.0, -1015.0, 13.0,  130.0), label = 'Del Perro Pier', zone = 'beach' },
        { coords = vector4(-1393.0, -589.0,  30.3,  35.0),  label = 'Terrasse de Vespucci', zone = 'beach' },
        { coords = vector4(-1180.0, -1500.0, 4.4,   215.0), label = 'Bars de Vespucci Beach', zone = 'beach' },
        { coords = vector4(-450.0,  270.0,   83.0,  180.0), label = 'Bar de West Vinewood', zone = 'affluent' },
        { coords = vector4(-810.0,  -1300.0, 5.0,   120.0), label = 'Front de mer de La Puerta', zone = 'beach' },
        { coords = vector4(910.0,   50.0,    79.0,  240.0), label = 'Casino de Vinewood', zone = 'affluent' },
        { coords = vector4(-1290.0, -650.0,  26.5,  300.0), label = 'Ruelle de Bahama Mamas', zone = 'downtown' },
    },

    -- PARKINGS / STATIONNEMENT
    parking = {
        { coords = vector4(215.0,   -800.0,  30.8,  70.0),  label = 'Parking de Legion Square', zone = 'downtown',
          exclude = { 'vol_vehicule', 'tapage' } },
        { coords = vector4(234.0,   -790.0,  30.6,  160.0), label = 'Parking Pillbox Hill', zone = 'downtown' },
        { coords = vector4(-1180.0, -1500.0, 4.4,   215.0), label = 'Parking de Vespucci Beach', zone = 'beach' },
        { coords = vector4(1140.0,  -650.0,  57.0,  85.0),  label = 'Parking de Mirror Park', zone = 'downtown',
          exclude = { 'vol_vehicule', 'tapage' } },
        { coords = vector4(-1450.0, -800.0,  22.0,  135.0), label = 'Parking de Del Perro', zone = 'beach',
          exclude = { 'tapage' } },
        { coords = vector4(-700.0,  -900.0,  24.0,  90.0),  label = 'Rockford Plaza', zone = 'affluent',
          exclude = { 'tapage' } },
        { coords = vector4(900.0,   50.0,    79.0,  240.0), label = 'Parking du Casino', zone = 'affluent' },
        { coords = vector4(-1000.0, -2700.0, 13.9,  330.0), label = 'Parking LSIA', zone = 'industrial' },
        { coords = vector4(-340.0,  -1550.0, 26.0,  260.0), label = 'Parking de La Puerta', zone = 'industrial',
          exclude = { 'tapage' } },
        { coords = vector4(-560.0,  -1250.0, 18.0,  30.0),  label = 'Parking du stade', zone = 'downtown' },
        { coords = vector4(290.0,   -350.0,  44.0,  160.0), label = 'Parking de Alta', zone = 'affluent',
          exclude = { 'vol_vehicule', 'tapage' } },
        { coords = vector4(-1620.0, -1050.0, 13.0,  135.0), label = 'Parking du front de mer', zone = 'beach' },
        { coords = vector4(1190.0,  -1420.0, 34.5,  270.0), label = 'Parking de Popular Street', zone = 'industrial',
          exclude = { 'tapage' } },
        { coords = vector4(480.0,   -1500.0, 29.3,  50.0),  label = 'Parking de Davis', zone = 'urban',
          exclude = { 'tapage' } },
        { coords = vector4(-1150.0, -740.0,  20.0,  300.0), label = 'Parking de Bay City', zone = 'beach' },
        { coords = vector4(60.0,    -1560.0, 29.6,  135.0), label = 'Parking de Chamberlain', zone = 'urban' },
        { coords = vector4(-350.0,  -880.0,  31.3,  250.0), label = 'Parking de Little Seoul', zone = 'urban' },
        { coords = vector4(1030.0,  -770.0,  58.0,  0.0),   label = 'Parking de Mirror Park Est', zone = 'downtown' },
    },
}
