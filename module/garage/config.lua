-- Module Garage : instances (buckets) façon GTA Online, garages extérieurs,
-- créateur RageUI, clés de garage, serrurier. Config partagée client + serveur.
Config = Config or {}
Config.Garage = {}
local C = Config.Garage

-- Bucket d'une instance = BucketOffset + id du garage (partagé entre tous les
-- occupants). Plage distincte de multichar (20000+src) et creatorperso (10000+src).
C.BucketOffset = 100000

-- Item "clé de garage" (garages personnels / propriétés) : data.garage = id
C.KeyItem = 'garage_key'
-- Item "clé de véhicule" (keyhanger) : data.plate
C.VehicleKeyItem = 'vehicle_key'

-- Distance d'interaction avec le marker d'entrée
C.EntranceRadius = 4.0
-- Distance d'affichage du marker / du texte d'aide
C.DrawDistance = 30.0
-- Portée de la fenêtre flottante au-dessus des véhicules garés
C.HudDistance = 7.0
C.HudMaxVehicles = 3

-- Types de places : modèle fantôme du créateur + classes GTA acceptées.
-- accepts : types de véhicule autorisés sur la place.
C.SlotTypes = {
    { id = 'car',   label = 'Voiture',      preview = 'sultan',   accepts = { car = true, moto = true } },
    { id = 'moto',  label = 'Moto / Vélo',  preview = 'bati',     accepts = { moto = true } },
    { id = 'heavy', label = 'Poids lourd',  preview = 'benson',   accepts = { car = true, moto = true, heavy = true } },
    { id = 'heli',  label = 'Hélicoptère',  preview = 'maverick', accepts = { heli = true } },
}

-- Classe GTA (GetVehicleClass) → type de véhicule
C.ClassToType = {
    [8] = 'moto', [13] = 'moto',
    [10] = 'heavy', [11] = 'heavy', [17] = 'heavy', [19] = 'heavy', [20] = 'heavy',
    [15] = 'heli', [16] = 'heli',
}

-- Décalages (relatifs au heading du point de sortie) testés si la place de
-- sortie est occupée : x = latéral, y = avant/arrière.
C.ExitOffsets = {
    { x = 0.0, y = 0.0 }, { x = 4.0, y = 0.0 }, { x = -4.0, y = 0.0 },
    { x = 0.0, y = 6.0 }, { x = 4.0, y = 6.0 }, { x = -4.0, y = 6.0 },
    { x = 0.0, y = -6.0 }, { x = 8.0, y = 0.0 }, { x = -8.0, y = 0.0 },
}
C.ExitClearRadius = 3.0

-- Blips
C.Blip = {
    sprite = 357, scale = 0.8,
    colors = { personal = 3, job = 38, faction = 1, public = 0 },
}

-- Marker d'entrée
C.Marker = { type = 1, size = vector3(2.5, 2.5, 0.6), color = { r = 40, g = 120, b = 255, a = 120 } }

-- Serrurier (doubles de clés de véhicules pour tout le monde)
C.Locksmith = {
    enabled = true,
    ped     = 'mp_m_waremech_01',
    coords  = vector3(170.136261, -1799.604370, 28.313599),
    heading = 325.98,
    price   = 250,
    blip    = { enabled = true, sprite = 134, color = 5, scale = 0.7, label = 'Serrurier' },
}


-- Logs Discord (convar) et nombre de lignes renvoyées au MDT
C.Webhook  = 'lslegacy_webhook_garage'
C.LogLimit = 100

-- Labels
C.OwnerTypes = {
    { id = 'personal', label = 'Personnel' },
    { id = 'job',      label = 'Entreprise (job)' },
    { id = 'faction',  label = 'Organisation (faction)' },
    { id = 'public',   label = 'Public' },
}
-- Bucket de travail du créateur (admin seul dans son instance) : base + src
C.CreatorBucketBase = 90000

-- Sensibilité souris des caméras orbitales (showroom, prévisualisation d'intérieur)
C.CamSensitivity = { yaw = 70.0, pitch = 40.0 }

-- Intérieurs IPL utilisables pour un garage intérieur (bob74_ipl 2.7.0).
-- Uniquement des coordonnées commentées dans les fichiers bob74 eux-mêmes.
-- coords = point d'arrivée de la prévisualisation ; load = chargement bob74
-- si l'intérieur n'est pas actif par défaut (pcall côté client).
local function CEO(exportName, part)
    return function()
        local o = exports['bob74_ipl'][exportName]()
        o.Part.Load(o.Part[part])
        o.Style.Set(o.Part[part], o.Style.concrete)
        o.Numbering.Set(o.Part[part], o.Numbering.Level1.style1)
        o.Lighting.Set(o.Part[part], o.Lighting.style1, true)
    end
end
C.Interiors = {
    -- dlc_import/garage1..4.lua (commentaires de chaque Part)
    { id = 'arcadius_1',  label = 'Arcadius - Garage 1 (CEO)',       coords = vec3(-191.0133, -579.1428, 135.0), heading = 0.0, load = CEO('GetImportCEOGarage1Object', 'Garage1') },
    { id = 'arcadius_2',  label = 'Arcadius - Garage 2 (CEO)',       coords = vec3(-117.4989, -568.1132, 135.0), heading = 0.0, load = CEO('GetImportCEOGarage1Object', 'Garage2') },
    { id = 'arcadius_3',  label = 'Arcadius - Garage 3 (CEO)',       coords = vec3(-136.0780, -630.1852, 135.0), heading = 0.0, load = CEO('GetImportCEOGarage1Object', 'Garage3') },
    { id = 'mazebank_1',  label = 'Maze Bank - Garage 1 (CEO)',      coords = vec3(-84.2193, -823.0851, 221.0),  heading = 0.0, load = CEO('GetImportCEOGarage2Object', 'Garage1') },
    { id = 'mazebank_2',  label = 'Maze Bank - Garage 2 (CEO)',      coords = vec3(-69.8627, -824.7498, 221.0),  heading = 0.0, load = CEO('GetImportCEOGarage2Object', 'Garage2') },
    { id = 'mazebank_3',  label = 'Maze Bank - Garage 3 (CEO)',      coords = vec3(-80.4318, -813.2536, 221.0),  heading = 0.0, load = CEO('GetImportCEOGarage2Object', 'Garage3') },
    { id = 'lombank_1',   label = 'Lom Bank - Garage 1 (CEO)',       coords = vec3(-1581.1120, -567.2450, 85.5), heading = 0.0, load = CEO('GetImportCEOGarage3Object', 'Garage1') },
    { id = 'lombank_2',   label = 'Lom Bank - Garage 2 (CEO)',       coords = vec3(-1568.7390, -562.0455, 85.5), heading = 0.0, load = CEO('GetImportCEOGarage3Object', 'Garage2') },
    { id = 'lombank_3',   label = 'Lom Bank - Garage 3 (CEO)',       coords = vec3(-1563.5570, -574.4314, 85.5), heading = 0.0, load = CEO('GetImportCEOGarage3Object', 'Garage3') },
    -- garage4 : parts 1 et 3 chevauchent FinanceOffice4 (avertissement bob74), seule la 2 est proposée
    { id = 'mazewest_2',  label = 'Maze Bank West - Garage 2 (CEO)', coords = vec3(-1388.8600, -478.7574, 48.1), heading = 0.0, load = CEO('GetImportCEOGarage4Object', 'Garage2') },
    -- dlc_import/vehicle_warehouse.lua
    { id = 'vwh_upper',   label = 'Entrepôt véhicules - Étage',       coords = vec3(994.5925, -3002.594, -39.64699), heading = 0.0 },
    { id = 'vwh_lower',   label = 'Entrepôt véhicules - Sous-sol',    coords = vec3(969.5376, -3000.411, -48.64689), heading = 0.0 },
    -- dlc_security/garage.lua
    { id = 'agency',      label = 'Garage Agence (The Contract)',     coords = vec3(-1071.83, -77.96, -95.0),        heading = 0.0 },
    -- dlc_drugwars/garage.lua
    { id = 'eclipse',     label = 'Eclipse Boulevard (50 places)',    coords = vec3(519.2477, -2618.788, -50.0),     heading = 0.0 },
    -- dlc_chopshop/cartel_garage.lua
    { id = 'cartel',      label = 'Garage du Cartel',                 coords = vec3(1220.133, -2277.844, -50.0),     heading = 0.0 },
    -- dlc_mercenaries/club.lua
    { id = 'carclub',     label = 'Vinewood Car Club',                coords = vec3(1202.407, -3251.251, -50.0),     heading = 0.0 },
    -- dlc_smuggler/hangar.lua
    { id = 'hangar',      label = 'Hangar (Smuggler)',                coords = vec3(-1267.0, -3013.135, -49.5),      heading = 0.0 },
    -- dlc_casino/casino.lua
    { id = 'casino_park', label = 'Casino - Parking',                 coords = vec3(1380.0, 200.0, -50.0),           heading = 0.0 },
    { id = 'casino_vip',  label = 'Casino - Parking VIP',             coords = vec3(1295.0, 230.0, -50.0),           heading = 0.0 },
}
function C.InteriorDef(id)
    for _, d in ipairs(C.Interiors) do if d.id == id then return d end end
    return nil
end

C.GarageTypes = {
    { id = 'exterior', label = 'En extérieur' },
    { id = 'interior', label = 'Intérieur (IPL/MLO)' },
}
