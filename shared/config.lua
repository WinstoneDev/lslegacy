---@class Config
Config = {}

Config.Informations = {
    ["Version"] = "1.0.0",
    ["Name"] = "MadeInFrance",
    ["Description"] = "Serveur Roleplay Français",
    ["Discord"] = "discord.gg/xemBfKDQKf",
    ['MaxWeight'] = 50,
    ['StartMoney'] = {cash = 1500, dirty = 0},
}

Config.DiscordStatus = {
    ["ID"] = 964945522538455080,
    ["LargeIcon"] = "logo_discord",
    ["LargeIconText"] = Config.Informations["Discord"],
    ["SmallIcon"] = "logo_discord",
    ["SmallIconText"] = "MadeInFrance V"..Config.Informations["Version"],
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
            print("[MadeInFrance] " .. message)
        end
    end
}

Config.StaffGroups = {
    [0] = "user",
    [1] = "mod",
    [2] = "admin",
    [3] = "superadmin",
    [4] = "dev"
}

Config.Items = {
    ['food_bread'] = {label = "Pain", weight = 0.1, props = "prop_sandwich_01"},
    ['food_burger'] = {label = "Hamburger", weight = 0.250, props = "prop_sandwich_01"},
    ['food_water'] = {label = "Bouteille d'eau", weight = 0.3, props = "prop_ld_flow_bottle"},
    ['food_sprunk'] = {label = "Sprunk", weight = 0.3, props = "prop_ld_can_01"},
    ['radio'] = {label = "Radio", weight = 0.5, props = "prop_cs_hand_radio"},
    ['phone'] = {label = "Téléphone", weight = 0.250, props = "prop_phone_ing"},
    ['weapon_pistol'] = {label = "Beretta", weight = 1, props = "w_pi_pistol"},
    ['weapon_combatpistol'] = {label = "Glock-17", weight = 1, props = "w_pi_combatpistol"},
    ['idcard'] = {label = "Carte d'identité", weight = 0.005, props = "ch_prop_swipe_card_01c"},
    ['carte'] = {label = "Carte banquaire", weight = 0.005, props = "ch_prop_swipe_card_01c"},
    ['9mm_ammo'] = {label = "9mm", weight = 0.001, props = "prop_ld_ammo_pack_01"},

    ['tshirt'] = {label = "Haut", weight = 0.2, props = "prop_ld_tshirt_01"},
    ['pants'] = {label = "Pantalon", weight = 0.3, props = "prop_cs_box_clothes"},
    ['shoes'] = {label = "Chaussure", weight = 0.8, props = "prop_ld_shoe_01"},
    ['helmet'] = {label = "Chapeau", weight = 0.1, props = "prop_cs_box_clothes"},
    ['glasses'] = {label = "Lunettes", weight = 0.1, props = "prop_cs_sol_glasses"},
    ['chain'] = {label = "Chaine", weight = 0.2, props = "prop_cs_box_clothes"},
    ['bags'] = {label = "Sacs", weight = 0.5, props = "prop_cs_box_clothes"},
    ['helmet'] = {label = "Chapeau", weight = 0.1, props = "prop_cs_box_clothes"},
    ['ears'] = {label = "Oreillette", weight = 0.1, props = "prop_cs_box_clothes"}
}

Config.AmmoForWeapon = {
    ['weapon_pistol'] = '9mm_ammo',
    ['weapon_combatpistol'] = '9mm_ammo'
}

Config.NeedsItems = {
    ['food_bread'] = { hunger = 40, thirst = 0, stamina = 0, anim = 'eating', portion = 10 },
    ['food_burger'] = { hunger = 70, thirst = 0, stamina = 0, anim = 'eating', portion = 20 },
    ['food_water']  = { hunger = 0, thirst = 100, stamina = 0, anim = 'drinking', portion = 15 },
    ['food_sprunk'] = { hunger = 0, thirst = 80, stamina = 15, anim = 'drinking', portion = 15 },
}

Config.InsertItems = {
    ['idcard'] = true,
    ['carte'] = true,
    ['phone'] = true,
    ['weapon_pistol'] = true,
    ['weapon_combatpistol'] = true,
    ['food_bread'] = true,
    ['food_burger'] = true,
    ['food_water'] = true,
    ['food_sprunk'] = true,

    ['tshirt'] = true,
    ['pants'] = true,
    ['shoes'] = true,
    ['helmet'] = true,
    ['glasses'] = true,
    ['chain'] = true,
    ['bags'] = true,
    ['helmet'] = true,
    ['glasses'] = true,
    ['ears'] = true
}

Config.ResourcesClientEvent = {
    ['monitor'] = true,
    ['chat'] = true,
    ['mysql-async'] = true,
    ['madeinfrance'] = true,
    ['pma-voice'] = true,
    ['skinchanger'] = true,
    ['spawnmanager'] = true,
    ['webpack'] = true,
    ['yarn'] = true,
    ['brutal_notify'] = true,
    ['speedometer'] = true
}

Config.PickupModelCollision = {
	["p_ld_stinger_s"] = true,
	["prop_barrier_work05"] = true,
	["prop_mp_cone_02"] = true
}

Config.zoneClothShop = {
    Binco = {
        {coords = vector3(-822.42, -1073.55, 10.33)},
        {coords = vector3(75.34, -1393.00, 28.38)},
        {coords = vector3(425.59, -806.15, 28.49)},
        {coords = vector3(4.87, 6512.46, 30.88)},
        {coords = vector3(1693.92, 4822.82, 41.06)},
        {coords = vector3(1196.61, 2710.25, 37.22)},
        {coords = vector3(-1101.48, 2710.57, 18.11)},
        Header = "shopui_title_lowendfashion2",
        BlipId = 73,
        BlipColor = 5,
        BlipScale = 0.7,
        Type = "Cloth"
    },
    Suburban = {
        {coords = vector3(-1193.16, -767.98, 16.32)},
        {coords = vector3(125.77, -223.9, 53.56)},
        {coords = vector3(614.19, 2762.79, 41.09)},
        {coords = vector3(-3170.54, 1043.68, 19.86)},
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
    }
}