-- Chaque entreprise = un job LSLegacy + ses propres grades/permissions/zones/stock.
-- Permissions disponibles (voir shared/permissions.lua) : diagnostic, repair_mechanical,
-- repair_bodywork, maintenance, performance, customization, billing, manage_stock,
-- manage_employees, manage_company (= admin_atelier, accorde tout)

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

Config.Atelier.Companies.reds = {
    label     = "Red's Tunershop",
    job       = 'mechanic_reds',
    stashName = 'atelier_reds',     -- DataStore du stock de pièces
    color     = '#8b1a1a',          -- rouge sombre/brique, style brut orienté tuning pur

    headquarters        = vector3(-686.663757, -2454.026367, 17.249023),
    headquartersHeading = 280.62991333008,
    partsDepotCoords       = vector3(-663.718689, -2427.626465, 14.350952),

    blips = {
        { sprite = 446, color = 1, scale = 0.9, label = "Red's Tunershop" },
    },

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
    color     = '#b8860b',          -- or/moutarde street, assez sombre pour rester lisible en blanc sur l'en-tête MDT

    -- Reprend les coordonnées réelles de l'ancien module mecanicien.
    headquarters        = vector3(-202.95, -1307.71, 31.29),
    headquartersHeading = 30.0,
    partsDepotCoords       = vector3(-199.0, -1315.0, 31.29),

    blips = {
        { sprite = 446, color = 4, scale = 0.9, label = "Benny's Original Motor Works" },
    },

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
