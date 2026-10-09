-- Postes de stationnement LSIA. `access` : nœud du relevé (survey.json) d'où part la ligne jaune menant au stand. `coords` = centre de l'avion à l'arrêt (origine de l'entité), `heading` = cap GTA de l'avion au parking.
-- `category` : commercial | business | heli. L'aviation militaire (miljet, velum) utilise les stands business. `spawnOffsetY` : recul (m) le long de l'axe
-- de l'avion à l'apparition pour éviter la collision avec la passerelle (négatif = vers l'arrière).

Config = Config or {}
Config.ATC = Config.ATC or {}

Config.ATC.Stands = {
    -- Aviation commerciale
    { id = 'C1',  label = 'Commercial 1',  category = 'commercial', coords = vector3(-1356.606567, -2712.145020, 13.929688), heading = 331.65353393555 },
    { id = 'C2',  label = 'Commercial 2',  category = 'commercial', coords = vector3(-1480.298950, -2724.197754, 13.929688), heading = 240.94488525391 },
    { id = 'C3',  label = 'Commercial 3',  category = 'commercial', coords = vector3(-1277.432983, -2755.635254, 13.929688), heading = 334.48818969727 },
    { id = 'C4',  label = 'Commercial 4',  category = 'commercial', coords = vector3(-1448.993408, -2658.197754, 13.929688), heading = 240.94488525391 },
    { id = 'C5',  label = 'Commercial 5',  category = 'commercial', coords = vector3(-1410.843994, -2594.479004, 13.929688), heading = 240.94488525391 },
    { id = 'C6',  label = 'Commercial 6',  category = 'commercial', coords = vector3(-1380.039551, -2527.331787, 13.929688), heading = 240.94488525391 },
    { id = 'C7',  label = 'Commercial 7',  category = 'commercial', coords = vector3(-1172.637329, -2573.894531, 13.929688), heading = 331.65353393555 },
    { id = 'C8',  label = 'Commercial 8',  category = 'commercial', coords = vector3(-1255.687866, -2537.340576, 13.929688), heading = 331.65353393555 },
    { id = 'C9',  label = 'Commercial 9',  category = 'commercial', coords = vector3(-1193.340698, -2609.709961, 13.929688), heading = 153.0708770752 },
    { id = 'C10', label = 'Commercial 10', category = 'commercial', coords = vector3(-1263.402222, -2550.210938, 13.929688), heading = 147.40158081055 },

    -- Aviation d'affaires + militaire (recul supplémentaire à l'apparition : passerelle proche)
    { id = 'B1', label = 'Affaires 1', category = 'business', coords = vector3(-1115.261597, -2943.046143, 14.536255), heading = 331.65353393555, spawnOffsetY = -6.0, access = 'D13' },
    { id = 'B2', label = 'Affaires 2', category = 'business', coords = vector3(-1153.081299, -2922.105469, 14.536255), heading = 331.65353393555, spawnOffsetY = -6.0, access = 'D11' },
    { id = 'B3', label = 'Affaires 3', category = 'business', coords = vector3(-1190.901123, -2901.059326, 13.929688), heading = 334.48818969727, spawnOffsetY = -6.0, access = 'D9' },
    { id = 'B4', label = 'Affaires 4', category = 'business', coords = vector3(-1229.604370, -2877.204346, 13.929688), heading = 331.65353393555, spawnOffsetY = -6.0, access = 'D8' },
    { id = 'B5', label = 'Affaires 5', category = 'business', coords = vector3(-1266.738403, -2859.177979, 13.929688), heading = 328.81890869141, spawnOffsetY = -6.0, access = 'D7' },

    -- Hélistations
    { id = 'H1', label = 'Hélipad 1', category = 'heli', coords = vector3(-1178.373657, -2845.780273, 13.929688), heading = 331.65353393555 },
    { id = 'H2', label = 'Hélipad 2', category = 'heli', coords = vector3(-1146.026367, -2864.518799, 13.929688), heading = 331.65353393555 },
    { id = 'H3', label = 'Hélipad 3', category = 'heli', coords = vector3(-1112.465942, -2883.731934, 13.929688), heading = 334.48818969727 },

}

-- Points d'attente, entrées de piste et réseau de taxiways : voir lsia_graph.lua (généré depuis data/survey.json).

-- Cible de pushback par stand : `node` = nœud de taxiway où s'arrête le recul, `dir` = sens dans
-- lequel le nez doit finir orienté le long de ce taxiway ('desc' = vers le nœud de numéro inférieur
-- du même groupe, 'asc' = vers le numéro supérieur). `via` = nœud intermédiaire à faire longer avant
-- le virage final (culs-de-sac C7/C9). Pour C1/C3 la cible dépend de la piste de décollage en service.
Config.ATC.PushbackTargets = {
    B1 = { node = 'D13', dir = 'desc' },
    B2 = { node = 'D11', dir = 'desc' },
    B3 = { node = 'D9',  dir = 'desc' },
    B4 = { node = 'D8',  dir = 'desc' },
    B5 = { node = 'D7',  dir = 'desc' },

    C1 = { ['12L'] = { node = 'D5', dir = 'desc' }, ['30R'] = { node = 'D2', dir = 'asc' } },
    C2 = { node = 'E2',  dir = 'desc' },
    C3 = { ['12L'] = { node = 'D7', dir = 'desc' }, ['30R'] = { node = 'D4', dir = 'asc' } },
    C4 = { node = 'E6',  dir = 'desc' },
    C5 = { node = 'E8',  dir = 'desc' },
    C6 = { node = 'E12', dir = 'desc' },
    C7 = { node = 'F14', dir = 'desc', via = 'P73' },
    C8 = { node = 'F13', dir = 'desc' },
    C9 = { node = 'F14', dir = 'desc', via = 'P93' },
    C10 = { node = 'F13', dir = 'desc' },
}

-- Stands trop proches pour être occupés simultanément (manque de place au sol) : chaque paire
-- s'exclut mutuellement, dans les deux sens.
Config.ATC.StandExclusions = {
    { 'C9', 'C7' },
    { 'C8', 'C10' },
}
