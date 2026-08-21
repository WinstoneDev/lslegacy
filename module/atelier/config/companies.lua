--  MODULE ATELIER — Entreprises
--  Chaque entreprise = un job LSLegacy + ses propres grades/permissions/
--  zones/stock. Aucune coordonnée ni job n'est en dur ailleurs dans le
--  module : tout le reste itère sur Config.Atelier.Companies.
--
--  Permissions disponibles (voir shared/permissions.lua) :
--    diagnostic, repair_mechanical, repair_bodywork, maintenance,
--    performance, customization, billing, manage_stock,
--    manage_employees, manage_company (= admin_atelier, accorde tout)

Config.Atelier.Companies = {}

-- Grades communs aux deux entreprises en V1 (§7 du cahier des charges).
-- Cumulatif : chaque grade n'ajoute QUE ce qu'il apporte en plus du
-- précédent (même convention que module/mdt).
local DefaultGrades = {
    [0] = { label = "Stagiaire",             grants = {} },
    [1] = { label = "Apprenti Mécanicien",   grants = { 'diagnostic', 'repair_mechanical', 'maintenance', 'billing' } },
    [2] = { label = "Mécanicien",            grants = { 'repair_bodywork', 'performance', 'customization' } },
    [3] = { label = "Mécanicien Confirmé",   grants = {} },
    [4] = { label = "Expert Mécanicien",     grants = {} },
    [5] = { label = "Chef d'Équipe",         grants = { 'manage_stock' } },
    [6] = { label = "Gérant",                grants = { 'manage_employees' } },
    [7] = { label = "Patron",                grants = { 'manage_company' } },
}

-- Tenues de vestiaire par défaut (grade 0 = accessible à tous les employés)
local function DefaultOutfits()
    return {
        {
            label = 'Bleu de travail',
            grade = 0,
            male   = {
                tshirt_1 = 13, tshirt_2 = 0, torso_1 = 12, torso_2 = 0,
                pants_1  = 4,  pants_2  = 0, shoes_1 = 6,  shoes_2 = 0,
                helmet_1 = -1, helmet_2 = -1, chain_1 = -1, chain_2 = -1, ears_1 = -1, ears_2 = -1,
            },
            female = {
                tshirt_1 = 13, tshirt_2 = 0, torso_1 = 11, torso_2 = 0,
                pants_1  = 8,  pants_2  = 0, shoes_1 = 4,  shoes_2 = 0,
                helmet_1 = -1, helmet_2 = -1, chain_1 = -1, chain_2 = -1, ears_1 = -1, ears_2 = -1,
            },
        },
    }
end

Config.Atelier.Companies.reds = {
    label     = "Red's Tunershop",
    job       = 'mechanic_reds',
    stashName = 'atelier_reds',     -- DataStore du stock de pièces
    color     = '#c0392b',

    -- TODO : coordonnées non fournies dans le cahier des charges, à
    -- ajuster à l'emplacement réel de Red's Tunershop sur votre map.
    headquarters        = vector3(732.36, -1088.16, 22.17),
    headquartersHeading = 0.0,
    clothingCoords       = vector3(736.0, -1092.0, 22.17),
    garageCoords          = vector3(725.0, -1085.0, 22.17),
    partsDepotCoords       = vector3(730.0, -1080.0, 22.17),

    blips = {
        { sprite = 446, color = 4, scale = 0.9, label = "Red's Tunershop" },
    },

    outfits = DefaultOutfits(),

    vehicles = {
        tow = {
            { model = 'towtruck',  label = 'Dépanneuse légère',  grade = 0 },
            { model = 'towtruck2', label = 'Dépanneuse plateau', grade = 2 },
            { model = 'flatbed',   label = 'Camion plateau',     grade = 3 },
        },
    },

    grades = DefaultGrades,
}

Config.Atelier.Companies.bennys = {
    label     = "Benny's Original Motor Works",
    job       = 'mechanic_bennys',
    stashName = 'atelier_bennys',
    color     = '#2980b9',

    -- Reprend les coordonnées réelles de l'ancien module mecanicien.
    headquarters        = vector3(-202.95, -1307.71, 31.29),
    headquartersHeading = 30.0,
    clothingCoords       = vector3(-207.5, -1311.0, 31.29),
    garageCoords          = vector3(-195.0, -1303.0, 31.29),
    partsDepotCoords       = vector3(-199.0, -1315.0, 31.29),

    blips = {
        { sprite = 446, color = 5, scale = 0.9, label = "Benny's Original Motor Works" },
    },

    outfits = DefaultOutfits(),

    vehicles = {
        tow = {
            { model = 'towtruck',  label = 'Dépanneuse légère',  grade = 0 },
            { model = 'towtruck2', label = 'Dépanneuse plateau', grade = 2 },
            { model = 'flatbed',   label = 'Camion plateau',     grade = 3 },
        },
    },

    grades = DefaultGrades,
}

-- Stock de départ (quantité) attribué à chaque pièce jamais vue dans le
-- DataStore d'une entreprise.
Config.Atelier.DefaultStock = 10
