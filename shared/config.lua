---@class Config
Config = {}

Config.Informations = {
    ["Version"] = "1.0.0",
    ["Name"] = "LSLegacy",
    ["Description"] = "Serveur Roleplay Français",
    ["Discord"] = "discord.gg/stCUrVA7UQ",
    ['MaxWeight'] = 50,
    ['StartMoney'] = {cash = 1500, dirty = 0},
}

Config.DiscordStatus = {
    ["ID"] = 964945522538455080,
    ["LargeIcon"] = "logo_discord",
    ["LargeIconText"] = Config.Informations["Discord"],
    ["SmallIcon"] = "logo_discord",
    ["SmallIconText"] = "LSLegacy RP V"..Config.Informations["Version"],
}

Config.UseStamina = false

Config.Population = {
    PedDensity = 0.5,
    VehicleDensity = 0.5,
    ParkedVehicleDensity = 0.5,
    LockAmbientVehicles = true,
}

Config.AP = {}
Config.AP.Enable = true
Config.AP.UpdateIntervalMs = 10000
Config.AP.Cleanup = false
Config.AP.CleanupDays = 31
Config.AP.SendCleanupToGarage = true
Config.AP.OnlyOwnedVehicles = false
Config.AP.Blacklist = {
    Models = { `cargoplane` },
    Plates = { "ADMIN", "TEST" }
}

-- Autonomie réelle (plein -> vide) = 100 / (LossRateByClass × 4.8) km, à
-- vitesse de croisière (persistentvehicles/client/main.lua) — INDÉPENDANTE de la capacité du
-- réservoir (TankCapacityByClass plus bas), qui n'est qu'un habillage
-- d'affichage. Valeurs recalibrées pour une autonomie cohérente par palier
-- (~450 km citadines/berlines → ~150 km monoplaces), au lieu de l'ancien
-- éventail 104-694 km qui n'avait pas de logique inter-catégories.
Config.FuelConsumption = {
    LossRateByClass = {
        [0] = 0.046, -- Compacts        (~450 km)
        [1] = 0.046, -- Sedans          (~450 km)
        [2] = 0.052, -- SUVs            (~400 km)
        [3] = 0.052, -- Coupes          (~400 km)
        [4] = 0.060, -- Muscle          (~350 km)
        [5] = 0.060, -- Sports Classics (~350 km)
        [6] = 0.069, -- Sports          (~300 km)
        [7] = 0.083, -- Super           (~250 km)
        [8] = 0.060, -- Motorcycles     (~350 km)
        [9] = 0.060, -- Off-road        (~350 km)
        [10] = 0.069,-- Industrial      (~300 km)
        [11] = 0.060,-- Utility         (~350 km)
        [12] = 0.052,-- Vans            (~400 km)
        [13] = 0,    -- Cycles
        [14] = 0.069,-- Boats           (~300 km)
        [15] = 0.069,-- Helicopters     (~300 km)
        [16] = 0.060,-- Planes          (~350 km)
        [17] = 0.052,-- Service         (~400 km)
        [18] = 0.052,-- Emergency       (~400 km)
        [19] = 0.069,-- Military        (~300 km)
        [20] = 0.069,-- Commercial      (~300 km)
        [21] = 0,    -- Trains
        [22] = 0.139 -- Open Wheels (F1/monoplaces) (~150 km)
    },

    -- Capacité du réservoir en litres par catégorie (GET_VEHICLE_CLASS),
    -- valeurs réalistes calquées sur les équivalents du monde réel — utilisé
    -- par les pompes à essence publiques (module pompe) pour convertir le
    -- pourcentage natif GetVehicleFuelLevel/SetVehicleFuelLevel (0-100) en
    -- litres affichés au joueur.
    TankCapacityByClass = {
        [0] = 45,   -- Compacts
        [1] = 60,   -- Sedans
        [2] = 70,   -- SUVs
        [3] = 60,   -- Coupes
        [4] = 70,   -- Muscle
        [5] = 65,   -- Sports Classics
        [6] = 65,   -- Sports
        [7] = 85,   -- Super
        [8] = 15,   -- Motorcycles
        [9] = 90,   -- Off-road
        [10] = 150, -- Industrial
        [11] = 100, -- Utility
        [12] = 80,  -- Vans
        [13] = 0,   -- Cycles
        [14] = 120, -- Boats
        [15] = 300, -- Helicopters
        [16] = 800, -- Planes
        [17] = 70,  -- Service
        [18] = 80,  -- Emergency
        [19] = 200, -- Military
        [20] = 300, -- Commercial
        [21] = 0,   -- Trains
        [22] = 110, -- Open Wheels (F1/monoplaces)
    },

    -- Consommation au ralenti : moteur tournant, véhicule immobile (par tick de 5s)
    -- Représente la consommation de maintien en chauffe / climatisation / électronique
    IdleLossRate = 0.002,

    -- Multiplicateur de conso au ralenti pour véhicules électriques
    -- 0.2 = 80 % moins qu'un thermique à l'arrêt (veille très efficiente)
    ElectricIdleMultiplier = 0.2,

    -- Régénération électrique : énergie récupérée par km/h par tick de 1 seconde
    -- À 100 km/h : 100 × 0.00002 = 0.002 / s ≈ 0.12 / min
    -- Ajuster à la hausse pour une regen plus agressive (max 0.0001 recommandé)
    ElectricRegenRate = 0.0001,

    -- Vitesse minimale (km/h) pour que la régénération soit active
    RegenMinSpeedKmh = 10.0,

    -- Force de freinage régénératif
    -- ApplyForceToEntity type 3 (impulse), isForceRel=true (scalé par masse)
    -- La valeur est indépendante de la masse du véhicule.
    --   0.1  → freinage léger, à peine perceptible
    --   0.3  → freinage modéré (mode EV standard)
    --   0.6  → freinage fort  (one-pedal driving)
    ElectricRegenBrakeForce = 0.1,
}

Config.VehicleTrunks = {
    [0] = 75,   -- Compacts
    [1] = 100,  -- Sedans
    [2] = 150,  -- SUVs
    [3] = 80,   -- Coupes
    [4] = 90,   -- Muscle
    [5] = 85,   -- Sports Classics
    [6] = 65,   -- Sports
    [7] = 50,   -- Super
    [8] = 15,   -- Motorcycles
    [9] = 200,  -- Off-road
    [10] = 500, -- Industrial
    [11] = 250, -- Utility
    [12] = 350, -- Vans
    [13] = 0,   -- Cycles
    [14] = 100, -- Boats
    [15] = 75,  -- Helicopters
    [16] = 200, -- Planes
    [17] = 180, -- Service
    [18] = 150, -- Emergency
    [19] = 300, -- Military
    [20] = 400, -- Commercial
    [21] = 0,   -- Trains
    [22] = 0    -- Open Wheels (monoplaces — pas de coffre)
}

Config.VehicleGloveboxes = {
    [0] = 10,   -- Compacts
    [1] = 15,   -- Sedans
    [2] = 20,   -- SUVs
    [3] = 10,   -- Coupes
    [4] = 10,   -- Muscle
    [5] = 10,   -- Sports Classics
    [6] = 5,    -- Sports
    [7] = 5,    -- Super
    [8] = 2,    -- Motorcycles
    [9] = 15,   -- Off-road
    [10] = 25,  -- Industrial
    [11] = 25,  -- Utility
    [12] = 20,  -- Vans
    [13] = 0,   -- Cycles
    [14] = 10,  -- Boats
    [15] = 10,  -- Helicopters
    [16] = 15,  -- Planes
    [17] = 20,  -- Service
    [18] = 20,  -- Emergency
    [19] = 20,  -- Military
    [20] = 25,  -- Commercial
    [21] = 0,   -- Trains
    [22] = 0    -- Open Wheels (monoplaces — pas de boîte à gants)
}

Config.Development = {
    Debug = true,
    ---Print
    ---@type function
    ---@param message string
    ---@return any
    ---@public
    Print = function(message)
        if Config.Development.Debug then
            print("[LSLegacy] " .. message)
        end
    end
}

Config.StaffGroups = {
    [0] = "user",
    [1] = "support",
    [2] = "mod",
    [3] = "admin",
    [4] = "superadmin",
    [5] = "dev"
}

Config.Bank = {
    -- Intervalle entre deux versements d'intérêts sur les livrets, UNE FOIS
    -- que le premier versement s'est calé sur minuit (heure serveur, voir
    -- bank/server/main.lua). Le taux admin (bank_interest_rates.rate_percent) est un
    -- taux JOURNALIER : versé chaque jour à 00h, calculé sur le solde
    -- courant du livret (donc composé sur les intérêts déjà versés).
    InterestIntervalMs = 86400000,
    -- Intervalle de vérification des cotisations carte / agios de découvert.
    -- Plus fréquent que les intérêts pour une granularité correcte sur des
    -- échéances hebdomadaires/mensuelles.
    MaintenanceIntervalMs = 300000,
    -- Niveau Config.StaffGroups minimum pour éditer taux/plafonds en jeu.
    AdminMinLevel = 3,
    -- Montant maximum autorisé en paiement sans contact (TPE). Au-delà,
    -- la carte doit être insérée + code PIN. Vérifié côté serveur, jamais
    -- seulement côté client.
    ContactlessMaxAmount = 50
    -- Les plafonds (paiement/retrait/virement) sont CUMULATIFS sur une
    -- période glissante, pas une limite par transaction : si le plafond est
    -- de 50$ et que 40$ ont déjà été dépensés, il ne reste que 10$ jusqu'à
    -- la remise à zéro. Cette période suit la PÉRIODICITÉ DE LA CARTE
    -- (bank_card_tiers.cost_period, hebdo ou mensuelle) — voir
    -- LSLegacy.Bank.CheckAndConsumeCeiling dans bank/server/main.lua.
}

Config.Items = {
    ['food_bread']  = {label = "Pain",                  weight = 0.1, props = "prop_sandwich_01"},
    ['food_burger'] = {label = "Hamburger",             weight = 0.250, props = "prop_sandwich_01"},
    ['food_water']  = {label = "Bouteille d'eau",       weight = 0.3, props = "prop_ld_flow_bottle"},
    ['food_sprunk'] = {label = "Sprunk",                weight = 0.3, props = "prop_ld_can_01"},
    ['radio']       = {label = "Radio",                 weight = 0.5, props = "prop_cs_hand_radio"},
    ['phone']       = {label = "Téléphone",             weight = 0.250, props = "prop_phone_ing"},
    ['ticket']      = {label = "Ticket de métro",       weight = 0.01, props = "prop_cs_documents_01"},

    -- ── Armes ajoutées (2026-07-19) ──────────────────────────────────
    -- ATTENTION : noms de props (modèles GTA V) non testés en jeu, à
    -- vérifier/corriger si un modèle ne charge pas (cf. convention TODO
    -- déjà utilisée pour les coordonnées à revoir dans module/atelier).
    -- Armes blanches — pas de munition
    ['weapon_bat']         = {label = "Batte",                    weight = 1.5, props = "w_me_bat"},
    ['weapon_golfclub']    = {label = "Club de golf",             weight = 1.5, props = "w_me_golfclub"},
    ['weapon_knife']       = {label = "Couteau",                  weight = 1.5, props = "w_me_knife"},
    ['weapon_switchblade'] = {label = "Couteau à cran d'arrêt",   weight = 1.5, props = "w_me_switchblade"},
    ['weapon_dagger']      = {label = "Dague",                    weight = 1.5, props = "w_me_dagger"},
    ['weapon_battleaxe']   = {label = "Hache de guerre",          weight = 1.5, props = "w_me_battleaxe"},
    ['weapon_hatchet']     = {label = "Hachette",                 weight = 1.5, props = "w_me_hatchet"},
    ['weapon_machete']     = {label = "Machette",                 weight = 1.5, props = "w_me_machette"},
    ['weapon_flashlight']  = {label = "Lampe torche",             weight = 1.5, props = "w_me_flashlight"},
    ['weapon_hammer']      = {label = "Marteau",                  weight = 1.5, props = "w_me_hammer"},
    ['weapon_nightstick']  = {label = "Matraque",                 weight = 1.5, props = "w_me_nightstick"},
    ['weapon_knuckle']     = {label = "Poing américain",          weight = 1.5, props = "w_me_knuckle"},

    -- Armes de jet / usage unique — pas de munition séparée
    ['weapon_molotov']      = {label = "Cocktail Molotov",  weight = 0.5, props = "w_ex_molotov"},
    ['weapon_bzgas']        = {label = "Gaz BZ",            weight = 0.5, props = "w_ex_bzgas"},
    ['weapon_smokegrenade'] = {label = "Grenade fumigène",  weight = 0.5, props = "w_ex_grenadesmoke"},
    ['weapon_grenade']      = {label = "Grenade",           weight = 0.5, props = "w_ex_grenade"},
    ['weapon_flare']        = {label = "Fusée de détresse", weight = 0.5, props = "w_am_flare"},

    -- Armes de poing
    ['weapon_pistol']        = {label = "Beretta",              weight = 1, props = "w_pi_pistol"},
    ['weapon_combatpistol']  = {label = "SIG Saueur P 2022",    weight = 1, props = "w_pi_combatpistol"},
    ['weapon_pistol_mk2']    = {label = "Beretta Mk II",        weight = 1, props = "w_pi_pistol_mk2"},
    ['weapon_machinepistol'] = {label = "Tec 9 mini",           weight = 1, props = "w_pi_machinepistol"},
    ['weapon_pistol50']      = {label = "Desert Eagle",         weight = 1, props = "w_pi_pistol50"},
    ['weapon_heavypistol']   = {label = "Staccato 2011",        weight = 1, props = "w_pi_heavypistol"},
    ['weapon_stungun']       = {label = "PIE",                  weight = 1, props = "w_am_stungun"},
    ['weapon_vintagepistol'] = {label = "Colt M1903",           weight = 1, props = "w_pi_vintagepistol"},
    ['weapon_snspistol']     = {label = "Kel-Tec P11",          weight = 1, props = "w_pi_snspistol"},
    ['weapon_snspistol_mk2'] = {label = "Kel-Tec P11 Mk II",    weight = 1, props = "w_pi_snspistol_mk2"},
    ['weapon_revolver']      = {label = "Revolver",             weight = 1, props = "w_pi_revolver"},
    ['weapon_revolver_mk2']  = {label = "Revolver Mk II",       weight = 1, props = "w_pi_revolver_mk2"},

    -- Pistolets-mitrailleurs
    ['weapon_assaultsmg'] = {label = "FN P90",      weight = 1.8, props = "w_sb_assaultsmg"},
    ['weapon_smg']        = {label = "MP5A3",       weight = 1.8, props = "w_sb_smg"},
    ['weapon_microsmg']   = {label = "Mini Uzi",    weight = 1.8, props = "w_sb_microsmg"},
    ['weapon_minismg']    = {label = "Škorpion",    weight = 1.8, props = "w_sb_minismg"},
    ['weapon_gusenberg']  = {label = "Thompson",    weight = 1.8, props = "w_sb_gusenberg"},

    -- Fusils
    ['weapon_carbinerifle']        = {label = "HK416",                      weight = 2.8, props = "w_ar_carbinerifle"},
    ['weapon_carbinerifle_mk2']    = {label = "HK416 Mk II",                weight = 2.8, props = "w_ar_carbinerifle_mk2"},
    ['weapon_specialcarbine']      = {label = "HK G36C",                    weight = 2.8, props = "w_ar_specialcarbine"},
    ['weapon_specialcarbine_mk2']  = {label = "HK G36C Mk II",              weight = 2.8, props = "w_ar_specialcarbine_mk2"},
    ['weapon_compactrifle']        = {label = "AKS-74U",                    weight = 2.8, props = "w_ar_compactrifle"},
    ['weapon_bullpuprifle']        = {label = "QBZ-95",                     weight = 2.8, props = "w_ar_bullpuprifle"},
    ['weapon_bullpuprifle_mk2']    = {label = "QBZ-95 Mk II",               weight = 2.8, props = "w_ar_bullpuprifle_mk2"},
    ['weapon_militaryrifle']       = {label = "Fusil de Formation",         weight = 2.8, props = "w_ar_militaryrifle"},
    ['weapon_assaultrifle']        = {label = "AKM",                        weight = 2.8, props = "w_ar_assaultrifle"},
    ['weapon_assaultrifle_mk2']    = {label = "AKM Mk II",                  weight = 2.8, props = "w_ar_assaultrifle_mk2"},
    ['weapon_musket']              = {label = "Mousquet",                   weight = 2.8, props = "w_ar_musket"},

    -- Mitrailleuse
    ['weapon_mg'] = {label = "PKM", weight = 3.5, props = "w_mg_mg"},

    -- Fusils à pompe / à canon
    ['weapon_sawnoffshotgun']   = {label = "Canon scié",            weight = 2.8, props = "w_sg_sawnoff"},
    ['weapon_dbshotgun']        = {label = "Double canon",          weight = 2.8, props = "w_sg_dbshotgun"},
    ['weapon_pumpshotgun']      = {label = "Remington 870",         weight = 2.8, props = "w_sg_pumpshotgun"},
    ['weapon_pumpshotgun_mk2']  = {label = "Remington 870 Mk II",   weight = 2.8, props = "w_sg_pumpshotgun_mk2"},
    ['weapon_combatshotgun']    = {label = "Spas-12",               weight = 2.8, props = "w_sg_bullpupshotgun"},

    -- Fusils de précision
    ['weapon_sniperrifle'] = {label = "Remington 700",      weight = 3.5, props = "w_sr_sniperrifle"},
    ['weapon_heavysniper']  = {label = "AW50",              weight = 3.5, props = "w_sr_heavysniper"},

    -- Munitions
    ['ammo_50ae']      = {label = ".50 AE",                 weight = 0.001, props = "prop_ld_ammo_pack_01"},
    ['ammo_45acp']     = {label = ".45 ACP",                weight = 0.001, props = "prop_ld_ammo_pack_01"},
    ['ammo_ax']        = {label = "AX",                     weight = 0.001, props = "prop_ld_ammo_pack_01"},
    ['ammo_40sw']      = {label = ".40 S&W",                weight = 0.001, props = "prop_ld_ammo_pack_01"},
    ['ammo_44magnum']  = {label = ".44 Magnum",             weight = 0.001, props = "prop_ld_ammo_pack_01"},
    ['ammo_556']       = {label = "5.56mm",                 weight = 0.001, props = "prop_ld_ammo_pack_01"},
    ['ammo_545']       = {label = "5.45mm",                 weight = 0.001, props = "prop_ld_ammo_pack_01"},
    ['ammo_762']       = {label = "7.62mm",                 weight = 0.001, props = "prop_ld_ammo_pack_01"},
    ['ammo_plomb']     = {label = "Plomb de Mousquet",      weight = 0.001, props = "prop_ld_ammo_pack_01"},
    ['ammo_12gauge']   = {label = "12 Gauge",               weight = 0.001, props = "prop_ld_ammo_pack_01"},
    ['ammo_338']       = {label = ".338 Lapua",             weight = 0.001, props = "prop_ld_ammo_pack_01"},
    ['ammo_50bmg']     = {label = ".50 BMG",                weight = 0.001, props = "prop_ld_ammo_pack_01"},
    ['ammo_9mm']       = {label = "9mm",                    weight = 0.001, props = "prop_ld_ammo_pack_01"},

    ['idcard'] = {label = "Carte d'identité", weight = 0.005, props = "ch_prop_swipe_card_01c"},
    ['carte'] = {label = "Carte banquaire", weight = 0.005, props = "ch_prop_swipe_card_01c"},

    -- ── Crochetage (ox_doorlock) ─────────────────────────────────────
    ['lockpick_porte'] = {label = "Kit de serrurerie", weight = 0.3, props = "prop_tool_pliers"},

    -- ── Outils / ressources module Farm ─────────────────────────────
    ['pioche']              = {label = "Pioche",               weight = 2.0, props = "prop_tool_pickaxe"},
    ['bois']                = {label = "Bois",                 weight = 1.0, props = "prop_log_01"},
    ['minerai']             = {label = "Minerai",              weight = 1.5, props = "prop_rock_2_a"},
    ['pierre']              = {label = "Pierre",               weight = 1.0, props = "prop_rock_4_a"},
    ['tas_pierre']          = {label = "Tas de pierres",       weight = 1.5, props = "prop_rock_4_b"},
    ['legume']              = {label = "Légumes",              weight = 0.3, props = "prop_veg_box_01"},
    ['planche']             = {label = "Planche de bois",      weight = 1.2, props = "prop_ld_plank_01"},
    ['minerai_fer']         = {label = "Minerai de fer",       weight = 2.0, props = "prop_gold_ing_pile"},
    ['minerai_cuivre']      = {label = "Minerai de cuivre",    weight = 2.0, props = "prop_gold_ing_pile"},
    ['minerai_or']          = {label = "Minerai d'or",         weight = 2.0, props = "prop_gold_ing_pile"},
    ['diamant']             = {label = "Diamant",              weight = 0.1, props = "prop_diamond_01"},
    ['minerai_charbon']     = {label = "Minerai de charbon",   weight = 1.0, props = "prop_rock_4_a"},
    ['minerai_soufre']      = {label = "Minerai de soufre",    weight = 1.0, props = "prop_rock_4_a"},
    ['minerai_salpetre']    = {label = "Minerai de salpêtre",  weight = 1.0, props = "prop_rock_4_a"},
    ['minerai_plomb']       = {label = "Minerai de plomb",     weight = 1.5, props = "prop_rock_4_a"},
    ['minerai_zinc']        = {label = "Minerai de zinc",      weight = 1.5, props = "prop_rock_4_a"},
    ['minerai_carbone']     = {label = "Minerai de carbone",   weight = 1.5, props = "prop_rock_4_a"},
    ['minerai_argile']      = {label = "Minerai d'argile",     weight = 1.0, props = "prop_rock_4_a"},
    -- Items "boutique" — obtenus uniquement en achetant au magasin du mineur
    -- (alimenté par la revente des minerai_XXX correspondants), jamais loot
    -- directement sur un rocher.
    ['charbon']     = {label = "Charbon",   weight = 1.0, props = "prop_rock_4_a"},
    ['soufre']      = {label = "Soufre",    weight = 1.0, props = "prop_rock_4_a"},
    ['salpetre']    = {label = "Salpêtre",  weight = 1.0, props = "prop_rock_4_a"},
    ['plomb']       = {label = "Plomb",     weight = 1.5, props = "prop_rock_4_a"},
    ['zinc']        = {label = "Zinc",      weight = 1.5, props = "prop_rock_4_a"},
    ['carbone']     = {label = "Carbone",   weight = 1.5, props = "prop_rock_4_a"},
    ['argile']      = {label = "Argile",    weight = 1.0, props = "prop_rock_4_a"},
    -- Métaux "boutique" — obtenus en achetant au magasin (alimenté par la
    -- revente des minerai_fer/cuivre/or fondus), jamais directement en jeu.
    ['fer']             = {label = "Fer",                   weight = 1.8, props = "prop_gold_ing_pile"},
    ['cuivre']          = {label = "Cuivre",                weight = 1.8, props = "prop_gold_ing_pile"},
    ['or']              = {label = "Or",                    weight = 1.8, props = "prop_gold_ing_pile"},
    ['sac_pierre']      = {label = "Sac de pierres",        weight = 10.0, props = "prop_sack_pile_01"},
    ['panier_legumes']  = {label = "Panier de légumes",     weight = 1.0, props = "prop_fruit_stand_01"},

    -- ── Module Farm — Chasseur ───────────────────────────────────────
    -- Une carcasse par espèce (le boucher découpe différemment selon
    -- l'animal — voir module/farm/config.lua `multiSellItems`).
    ['carcasse_cerf']       = {label = "Carcasse de cerf",     weight = 5.0, props = "prop_ld_steak"},
    ['carcasse_porc']       = {label = "Carcasse de porc",     weight = 4.5, props = "prop_ld_steak"},
    ['carcasse_sanglier']   = {label = "Carcasse de sanglier", weight = 4.5, props = "prop_ld_steak"},
    ['carcasse_lapin']      = {label = "Carcasse de lapin",    weight = 0.8, props = "prop_ld_steak"},
    ['carcasse_oiseau']     = {label = "Carcasse d'oiseau",    weight = 0.3, props = "prop_ld_steak"},
    -- Ni coyote ni cougar n'ont d'entrée ici : chassés pour leur peau seule
    -- (pas de `rawItem` sur ces espèces, voir module/farm/config.lua) — leur
    -- carcasse n'est jamais récupérable.
    ['tripes']              = {label = "Tripes",               weight = 0.6, props = "prop_ld_steak"},
    ['abats']               = {label = "Abats",                weight = 0.4, props = "prop_ld_steak"},
    ['sang']                = {label = "Sang",                 weight = 0.3, props = "prop_ld_steak"},
    ['graisse_animale']     = {label = "Graisse animale",      weight = 0.4, props = "prop_ld_steak"},
    ['steak_gibier']        = {label = "Steak de gibier",      weight = 1.0, props = "prop_food_bs_ribs"},

    -- ── Module Farm — Braconnage (peau, illégal) — coyote et cougar uniquement ──
    -- Outil : `weapon_knife` (déjà existant, pas d'item dédié).
    ['peau_coyote']       = {label = "Peau de coyote",       weight = 1.0, props = "prop_ld_steak"},
    ['peau_cougar']       = {label = "Peau de cougar",       weight = 2.5, props = "prop_ld_steak"},

    -- ── Trousse de soins SAMU — Health Inspection ────────────────────
    ['bandage']    = {label = "Bandage",                    weight = 0.25, props = "prop_med_bandage_01"},
    ['med_kit']    = {label = "Kit de Premiers Secours",    weight = 1.75, props = "prop_ld_health_pack"},
    ['forceps']    = {label = "Forceps",                    weight = 0.70, props = "prop_tool_pliers"},
    ['pliers']     = {label = "Pince",                      weight = 0.175, props = "prop_tool_pliers"},
    ['suture']     = {label = "Suture",                     weight = 0.175, props = "prop_med_syringe_01"},
    ['splint']     = {label = "Attelle",                    weight = 0.50, props = "prop_med_brace_01"},
    ['burn_cream'] = {label = "Crème pour Brûlures",        weight = 0.10, props = "prop_cs_pill_bottle"},
    ['ice_pack']   = {label = "Poche de Glace",             weight = 0.25, props = "prop_cs_ciggy_pkt_01"},
    ['trauma_kit'] = {label = "Kit de Traumatologie",       weight = 0.75, props = "prop_ld_health_pack"},
    ['medbag']     = {label = "Sac Médical",                weight = 0.05, props = "prop_cs_box_clothes"},

    -- ── Pièces détachées Atelier (prop placeholder, voir TODO module/atelier/config/parts.lua) ──
    ['piece_capot']             = {label = "Capot",                weight = 8.0, props = "prop_tool_boxv1"},
    ['piece_pare_choc_avant']   = {label = "Pare-choc avant",      weight = 6.0, props = "prop_tool_boxv1"},
    ['piece_pare_choc_arriere'] = {label = "Pare-choc arrière",    weight = 6.0, props = "prop_tool_boxv1"},
    ['piece_portiere']          = {label = "Portière",             weight = 10.0, props = "prop_tool_boxv1"},
    ['piece_aile']              = {label = "Aile",                 weight = 7.0, props = "prop_tool_boxv1"},
    ['piece_bas_caisse']        = {label = "Bas de caisse",        weight = 9.0, props = "prop_tool_boxv1"},
    ['piece_coffre']            = {label = "Coffre / hayon",       weight = 9.0, props = "prop_tool_boxv1"},
    ['piece_vitre']             = {label = "Vitre",                weight = 4.0, props = "prop_tool_boxv1"},
    ['piece_phare']             = {label = "Phare",                weight = 2.0, props = "prop_tool_boxv1"},
    ['piece_pneu']               = {label = "Pneu",                weight = 5.0, props = "prop_wheel_01a"},
    -- Pièces mécaniques : posées sous le capot, jamais portées en main.
    ['piece_moteur']             = {label = "Pièce moteur",             weight = 6.0},
    ['piece_freins']             = {label = "Pièce de freinage",        weight = 3.0},
    ['piece_transmission']       = {label = "Pièce de transmission",    weight = 5.0},
    ['piece_suspension']         = {label = "Pièce de suspension",      weight = 5.0},
    ['piece_embrayage']          = {label = "Pièce d'embrayage",        weight = 3.0},
    ['piece_radiateur']          = {label = "Radiateur",                weight = 4.0},

    -- ── Articles LTD ───────────────────────────────────────────────
    ['cigarettes'] = {label = "Cigarettes",                 weight = 0.1, props = "prop_cs_cigar_packet"},

    ['tshirt']          = {label = "Haut",                  weight = 0.2, props = "prop_ld_tshirt_01"},
    ['torso']           = {label = "Haut",                  weight = 0.2, props = "prop_ld_tshirt_01"},
    ['arms']            = {label = "Gants/Bras",            weight = 0.5, props = "prop_boxing_glove_01"},
    ['pants']           = {label = "Pantalon",              weight = 0.3, props = "prop_cs_box_clothes"},
    ['shoes']           = {label = "Chaussure",             weight = 0.8, props = "prop_ld_shoe_01"},
    ['helmet']          = {label = "Chapeau",               weight = 0.1, props = "prop_cs_box_clothes"},
    ['glasses']         = {label = "Lunettes",              weight = 0.1, props = "prop_cs_sol_glasses"},
    ['chain']           = {label = "Chaine",                weight = 0.2, props = "prop_cs_box_clothes"},
    ['bags']            = {label = "Sacs",                  weight = 0.5, props = "prop_cs_box_clothes"},
    ['ears']            = {label = "Oreillette",            weight = 0.1, props = "prop_cs_box_clothes"},
    ['watches']         = {label = "Montre",                weight = 0.1, props = "p_watch_04"},
    ['bracelet']        = {label = "Bracelet",              weight = 0.1, props = "p_watch_04"},
    ['mask']            = {label = "Masque",                weight = 0.1, props = "p_mask_01"},
    ['decals']          = {label = "Badge",                 weight = 0.1, props = "prop_cs_box_clothes"},
    ['outfit']          = {label = "Tenue",                 weight = 0.5, props = "prop_cs_box_clothes"},
    ['vehicle_key']     = {label = "Clé de véhicule",       weight = 0.05, props = "prop_cs_keys_01"},
    ['tablette_mdt']    = {label = "Tablette MDT",          weight = 0.5, props = "prop_cs_tablet"}
}

Config.AmmoForWeapon = {
    -- Armes ajoutées (2026-07-19)
    ['weapon_pistol']             = 'ammo_9mm',
    ['weapon_combatpistol']       = 'ammo_9mm',
    ['weapon_pistol_mk2']         = 'ammo_9mm',
    ['weapon_machinepistol']      = 'ammo_9mm',
    ['weapon_snspistol_mk2']      = 'ammo_9mm',
    ['weapon_assaultsmg']         = 'ammo_9mm',
    ['weapon_microsmg']           = 'ammo_9mm',
    ['weapon_minismg']            = 'ammo_9mm',
    ['weapon_smg']                = 'ammo_9mm',
    ['weapon_pistol50']           = 'ammo_50ae',
    ['weapon_heavypistol']        = 'ammo_45acp',
    ['weapon_vintagepistol']      = 'ammo_45acp',
    ['weapon_gusenberg']          = 'ammo_45acp',
    ['weapon_stungun']            = 'ammo_ax',
    ['weapon_snspistol']          = 'ammo_40sw',
    ['weapon_revolver']           = 'ammo_44magnum',
    ['weapon_revolver_mk2']       = 'ammo_44magnum',
    ['weapon_carbinerifle']       = 'ammo_556',
    ['weapon_carbinerifle_mk2']   = 'ammo_556',
    ['weapon_specialcarbine']     = 'ammo_556',
    ['weapon_specialcarbine_mk2'] = 'ammo_556',
    ['weapon_bullpuprifle']       = 'ammo_556',
    ['weapon_bullpuprifle_mk2']   = 'ammo_556',
    ['weapon_militaryrifle']      = 'ammo_556',
    ['weapon_mg']                 = 'ammo_556',
    ['weapon_compactrifle']       = 'ammo_545',
    ['weapon_assaultrifle']       = 'ammo_762',
    ['weapon_assaultrifle_mk2']   = 'ammo_762',
    ['weapon_musket']             = 'ammo_plomb',
    ['weapon_sawnoffshotgun']     = 'ammo_12gauge',
    ['weapon_dbshotgun']          = 'ammo_12gauge',
    ['weapon_pumpshotgun']        = 'ammo_12gauge',
    ['weapon_pumpshotgun_mk2']    = 'ammo_12gauge',
    ['weapon_combatshotgun']      = 'ammo_12gauge',
    ['weapon_sniperrifle']        = 'ammo_338',
    ['weapon_heavysniper']        = 'ammo_50bmg',
}

Config.NeedsItems = {
    ['food_bread']  = { hunger = 70, thirst = 0, stamina = 0, anim = 'eating', portion = 10 },
    ['food_burger'] = { hunger = 80, thirst = 0, stamina = 0, anim = 'eating', portion = 20 },
    ['food_water']  = { hunger = 0, thirst = 80, stamina = 0, anim = 'drinking', portion = 15 },
    ['food_sprunk'] = { hunger = 0, thirst = 60, stamina = 50, anim = 'drinking', portion = 15 }
}

Config.InsertItems = {
    -- Armes ajoutées (2026-07-19)
    ['idcard'] = true,
    ['carte'] = true,
    ['phone'] = true,
    -- Chaque ticket porte son heure d'émission dans son label → instance unique
    ['ticket'] = true,
    ['weapon_pistol'] = true,
    ['weapon_combatpistol'] = true,
    ['weapon_bat'] = true,
    ['weapon_golfclub'] = true,
    ['weapon_knife'] = true,
    ['weapon_switchblade'] = true,
    ['weapon_dagger'] = true,
    ['weapon_battleaxe'] = true,
    ['weapon_hatchet'] = true,
    ['weapon_machete'] = true,
    ['weapon_flashlight'] = true,
    ['weapon_hammer'] = true,
    ['weapon_nightstick'] = true,
    ['weapon_knuckle'] = true,
    ['weapon_molotov'] = true,
    ['weapon_bzgas'] = true,
    ['weapon_smokegrenade'] = true,
    ['weapon_grenade'] = true,
    ['weapon_flare'] = true,
    ['weapon_pistol_mk2'] = true,
    ['weapon_machinepistol'] = true,
    ['weapon_pistol50'] = true,
    ['weapon_heavypistol'] = true,
    ['weapon_stungun'] = true,
    ['weapon_vintagepistol'] = true,
    ['weapon_snspistol'] = true,
    ['weapon_snspistol_mk2'] = true,
    ['weapon_revolver'] = true,
    ['weapon_revolver_mk2'] = true,
    ['weapon_assaultsmg'] = true,
    ['weapon_microsmg'] = true,
    ['weapon_minismg'] = true,
    ['weapon_smg'] = true,
    ['weapon_gusenberg'] = true,
    ['weapon_carbinerifle'] = true,
    ['weapon_carbinerifle_mk2'] = true,
    ['weapon_specialcarbine'] = true,
    ['weapon_specialcarbine_mk2'] = true,
    ['weapon_compactrifle'] = true,
    ['weapon_bullpuprifle'] = true,
    ['weapon_bullpuprifle_mk2'] = true,
    ['weapon_militaryrifle'] = true,
    ['weapon_assaultrifle'] = true,
    ['weapon_assaultrifle_mk2'] = true,
    ['weapon_musket'] = true,
    ['weapon_mg'] = true,
    ['weapon_sawnoffshotgun'] = true,
    ['weapon_dbshotgun'] = true,
    ['weapon_pumpshotgun'] = true,
    ['weapon_pumpshotgun_mk2'] = true,
    ['weapon_combatshotgun'] = true,
    ['weapon_sniperrifle'] = true,
    ['weapon_heavysniper'] = true,

    ['food_bread'] = true,
    ['food_burger'] = true,
    ['food_water'] = true,
    ['food_sprunk'] = true,

    ['tshirt'] = true,
    ['torso'] = true,
    ['arms'] = true,
    ['pants'] = true,
    ['shoes'] = true,
    ['helmet'] = true,
    ['glasses'] = true,
    ['chain'] = true,
    ['bags'] = true,
    ['ears'] = true,
    ['watches'] = true,
    ['bracelet'] = true,
    ['mask'] = true,
    ['decals'] = true,
    ['outfit'] = true,
    ['vehicle_key'] = true,
    ['tablette_mdt'] = true
}

Config.ResourcesClientEvent = {
    ['monitor'] = true,
    ['chat'] = true,
    ['oxmysql'] = true,
    ['lslegacy'] = true,
    ['pma-voice'] = true,
    ['skinchanger'] = true,
    ['spawnmanager'] = true,
    ['webpack'] = true,
    ['yarn'] = true,
    ['brutal_notify'] = true,
    ['screenshot-basic'] = true,
    ['bob74_ipl'] = true,
    ['lb-phone'] = true,
    ['tuff'] = true,
    ['tuff-hud'] = true,
    ['tuff-loading'] = true,
    ['ox_target'] = true,
}

Config.PickupModelCollision = {
    ["p_ld_stinger_s"] = true,
    ["prop_barrier_work05"] = true,
    ["prop_mp_cone_02"] = true
}

Config.zoneClothShop = {
    Binco = {
        {coords = vector3(429.916473, -805.740662, 28.969629)},
        {coords = vector3(70.984619, -1393.173584, 28.868555)},
        {coords = vector3(1698.263794, 4823.749512, 41.556421)},
        {coords = vector3(8.004395, 6509.433105, 31.362329)},
        {coords = vector3(1196.400024, 2714.597900, 37.714624)},
        {coords = vector3(-824.835144, -1069.898926, 10.822290)},
        {coords = vector3(-1104.659302, 2713.714355, 18.590112)},
        Header = "shopui_title_lowendfashion2",
        BlipId = 73,
        BlipColor = 5,
        BlipScale = 0.7,
        Type = "Cloth"
    },
    Suburban = {
        {coords = vector3(-1193.16, -767.98, 15.82)},
        {coords = vector3(125.77, -223.9, 52.96)},
        {coords = vector3(614.19, 2762.79, 40.49)},
        {coords = vector3(-3170.54, 1043.68, 19.26)},
        Header = "shopui_title_midfashion",
        BlipId = 73,
        BlipColor = 5,
        BlipScale = 0.7,
        Type = "Cloth",
    },
    Ponsonbys = {
        {coords = vector3(-709.86, -153.1, 36.42)},
        {coords = vector3(-163.37, -302.73, 38.73)},
        {coords = vector3(-1450.42, -237.66, 48.81)},
        {coords = vector3(-1114.523071, -2787.956055, 25.599634)},
        {coords = vector3(-1102.865967, -2794.153809, 25.599634)},
        Header = "shopui_title_highendfashion",
        BlipId = 73,
        BlipColor = 5,
        BlipScale = 0.7,
        Type = "Cloth"
    },
    Masques = {
        {coords = vector3(-1337.25, -1277.54, 3.88)},
        Header = "shopui_title_movie_masks",
        BlipId = 362,
        BlipColor = 5,
        BlipScale = 0.7,
        Type = "Mask"
    }
}

Config.Status = {
    UpdateInterval = 60,

    Hunger = {
        Loss = 0.83
    },

    Thirst = {
        Loss = 1.11
    },

    Stamina = {
        Loss = 0.83
    },

    DisplayEnabled = false,

    -- Dégâts de santé lorsque faim ou soif = 0
    HungerHPLoss  = 3,   -- HP perdus par tick quand faim = 0
    ThirstHPLoss  = 5,   -- HP perdus par tick quand soif = 0 (soif plus critique)
    HPLossNotifInterval = 120,  -- secondes entre deux notifications de malaise
}

-- -----------------------------------------------------------------------
--  COMPÉTENCES
-- -----------------------------------------------------------------------
Config.Skills = {
    -- XP nécessaire pour atteindre chaque niveau (niveau 1 à 10)
    LevelThresholds = {100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700, 3250},
    MaxLevel        = 10,

    -- Secondes minimum entre deux gains d'XP (anti-farm côté serveur)
    ActivityInterval = 45,

    -- XP maximum gagnable par compétence par connexion (anti-farm session)
    MaxSessionXP = 25,

    -- Dégradation : heures d'inactivité avant que l'XP commence à baisser
    DecayThreshold = 48,
    -- XP perdu par heure d'inactivité au-delà du seuil
    DecayPerHour   = 1,
    -- Intervalle de vérification du decay côté serveur (secondes)
    DecayCheckInterval = 3600,
}

-- -----------------------------------------------------------------------
--  BLESSURES / KO / COMA
-- -----------------------------------------------------------------------
Config.Injury = {
    -- Santé GTA (100-200) en dessous de laquelle le joueur boite
    LimpThreshold   = 130,

    -- En dessous de cette santé, réduction progressive de vitesse (+ ralentit la course)
    SlowThreshold   = 150,

    -- Durée du KO suite à un combat à mains nues (secondes)
    KODuration      = 45,

    -- Durée du coma avant respawn automatique (secondes)
    ComaDuration    = 300,

    -- Lieux de respawn (Centre Médical de LS) — plusieurs points possibles,
    -- un point est tiré au sort à chaque respawn pour éviter que les joueurs
    -- ne se superposent.
    RespawnCoords   = {
        {x = -824.334045, y = -1247.432983, z = 6.717896, w = 53.858268737793},
        {x = -826.140686, y = -1249.490112, z = 6.717896, w = 25.511812210083},
        {x = -827.472534, y = -1251.586792, z = 6.717896, w = 53.858268737793},
        {x = -829.305481, y = -1253.498901, z = 6.717896, w = 25.511812210083},
    },
}

-- ─────────────────────────────────────────────────────────────────────────────
--  FREIN À MAIN MANUEL
-- ─────────────────────────────────────────────────────────────────────────────
Config.Handbrake = {
    -- Active le roulement naturel sur les pentes (désactive le frein de parking GTA V)
    RollingEnabled = true,

    -- Multiplicateur gravitationnel pour les pentes NORMALES (≥ LowSlopeThreshold)
    -- 0.5 → ~1.2 m/s² sur 15°, ~2.5 m/s² sur 30°
    RollMultiplier = 0.5,

    -- Multiplicateur pour les PETITES pentes (MinimumSlope → LowSlopeThreshold)
    -- Lerp lisse vers RollMultiplier.
    LowSlopeMultiplier = 1.0,

    -- Angle (degrés) à partir duquel on bascule totalement sur RollMultiplier.
    LowSlopeThreshold = 8.0,

    -- Angle minimum (degrés) — zone morte : en dessous, AUCUN roulement.
    -- Mettre à 3.0 neutralise les micro-pentes invisibles (trottoirs, routes
    -- légèrement bombées) qui faisaient s'envoler le véhicule.
    MinimumSlope = 3.0,

    -- (RollingFriction supprimé : la vitesse terminale est désormais gérée par
    -- speedFactor qui réduit l'accélération à mesure qu'on approche MaxRollSpeed.
    -- L'arrêt en terrain plat utilise 10 %/frame hardcodé dans le thread.)

    -- Touche d'activation du frein à main : 22 = INPUT_JUMP (ESPACE)
    -- Référence complète : https://docs.fivem.net/docs/game-references/controls/
    HandbrakeKey = 22,

    -- Classes de véhicules exclues du système
    -- 8=Motos, 13=Vélos, 14=Bateaux, 15=Hélicoptères, 16=Avions, 22=Open Wheels, 18=Urgences
    DisabledClasses = { 8, 13, 14, 15, 16, 22, 18 },

    -- Modèles individuels exclus du système (hash GTA V)
    DisabledModels = {
        --`rhino`,
        --`lazer`,
    },

    -- Vitesse terminale de roulement (m/s)
    -- La force décroît progressivement vers 0 quand on approche cette vitesse
    -- → comportement comme une résistance aérodynamique, pas de coupure brusque.
    --   15.0 m/s ≈ 54 km/h   (défaut)
    --   20.0 m/s ≈ 72 km/h   (pentes rapides)
    --    8.0 m/s ≈ 29 km/h   (très prudent)
    -- Vitesse max absolue (m/s) — atteinte uniquement sur les grosses pentes.
    -- Sur les pentes plus douces : vitesse max = MaxRollSpeed × sin(pente)/sin(MaxRollSpeedAngle)
    MaxRollSpeed = 5.0,

    -- Angle (°) à partir duquel MaxRollSpeed est atteint.
    -- En dessous → vitesse max réduite proportionnellement.
    MaxRollSpeedAngle = 25.0,
}

-- ─────────────────────────────────────────────────────────────────────────────
--  STABILITÉ DES VÉHICULES TERRESTRES — contrôle aérien & anti-retournement
-- ─────────────────────────────────────────────────────────────────────────────
Config.VehicleStability = {
    Enabled = true,

    -- Classes de véhicules EXCLUES (ont besoin du contrôle aérien pour piloter)
    -- 14=Bateaux, 15=Hélicoptères, 16=Avions
    ExcludedClasses = { 14, 15, 16 },

    -- Composante Z du vecteur "haut" du véhicule en dessous de laquelle on
    -- considère qu'il est sur le toit (-1 = parfaitement renversé, 0 = sur le flanc).
    UpsideDownThreshold = -0.5,
}

-- ─────────────────────────────────────────────────────────────────────────────
--  PORTER (/porter) — transporter un autre joueur
-- ─────────────────────────────────────────────────────────────────────────────
Config.Carry = {
    range = 3.0, -- distance max (m) pour initier le portage

    -- Réutilise la paire d'émotes synchronisées existante
    -- (module/emotes/data/emotes_shared.lua) : "carry" = porteur,
    -- "carry2" = porté, attaché à l'os 40269 (épaule) du porteur.
    carrierEmote = 'carry',
    carriedEmote = 'carry2',
}

-- ─────────────────────────────────────────────────────────────────────────────
--  OTAGE (/otage) — prise d'otage sous la menace d'une arme de poing
-- ─────────────────────────────────────────────────────────────────────────────
Config.Hostage = {
    range = 3.0, -- distance max (m) pour initier la prise d'otage

    -- Réutilise la paire d'émotes synchronisées existante
    -- (module/emotes/data/emotes_shared.lua) : "hostage" = preneur d'otage,
    -- "hostage2" = otage, attaché au bassin (bone -1) du preneur d'otage.
    takerEmote   = 'hostage',
    hostageEmote = 'hostage2',
}

-- Armes autorisées pour /otage : uniquement les armes à feu de poing
-- (sous-ensemble de la section "Armes de poing" de Config.Items ci-dessus).
-- weapon_stungun est volontairement exclu : ce n'est pas une arme à feu.
-- Garder cette liste synchronisée avec la section "Armes de poing".
Config.HostageWeapons = {
    'weapon_pistol',
    'weapon_combatpistol',
    'weapon_pistol_mk2',
    'weapon_machinepistol',
    'weapon_pistol50',
    'weapon_heavypistol',
    'weapon_vintagepistol',
    'weapon_snspistol',
    'weapon_snspistol_mk2',
    'weapon_revolver',
    'weapon_revolver_mk2',
}