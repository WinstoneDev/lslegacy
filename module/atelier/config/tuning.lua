-- Points de tuning (touche E, pas ox_target) : peinture/jantes/néons/vitres
-- ("esthétique") et moteur/freins/transmission/suspension/turbo ("performance").
-- Catalogue + tarifs communs aux deux entreprises ; seuls les emplacements
-- (Points) diffèrent par entreprise.

Config.Atelier.Tuning = {}

Config.Atelier.Tuning.InteractDistance = 8.0   -- distance d'affichage du prompt [E]
Config.Atelier.Tuning.VehicleSearchRadius = 6.0 -- rayon de recherche du véhicule ciblé autour du joueur

-- Coordonnées des postes de tuning, un point par emplacement physique.
-- Le Z d'origine (~14.26) plaçait le poste sous le niveau du quai (le
-- véhicule tuné apparaissait alors sous la structure de l'appontement,
-- caméra à moitié dans l'eau) : recalé sur le même niveau de sol que le
-- blip/QG (~17.25, coordonnée confirmée en jeu par l'utilisateur).
Config.Atelier.Tuning.Points = {
    reds = {
        vector3(-692.123047, -2437.569336, 17.249023),
        vector3(-688.536255, -2431.635254, 17.249023),
        vector3(-685.226379, -2425.622070, 17.249023),
        vector3(-681.863708, -2420.123047, 17.249023),
        vector3(-671.881348, -2466.514404, 16.996215), -- baie gros véhicules
    },
    bennys = {
        -- TODO : coordonnées non fournies pour Benny's, à ajuster à l'emplacement réel.
        vector3(-202.95, -1307.71, 31.29),
    },
}

-- PERFORMANCE (grant 'performance') — modType natif GTA (SetVehicleMod/GetVehicleMod).
-- Le nombre de paliers disponibles dépend du véhicule (GetNumVehicleMods) ; le
-- prix est payé pour le palier choisi, indépendamment du palier précédent.
Config.Atelier.Tuning.Performance = {
    { id = 'engine',       modType = 11, label = 'Moteur',       pricePerLevel = 1200 },
    { id = 'brakes',       modType = 12, label = 'Freins',       pricePerLevel = 700 },
    { id = 'transmission', modType = 13, label = 'Transmission', pricePerLevel = 900 },
    { id = 'suspension',   modType = 15, label = 'Suspension',   pricePerLevel = 600 },
}

-- Turbo : pas de palier, juste un toggle (ToggleVehicleMod).
Config.Atelier.Tuning.Turbo = { modType = 18, label = 'Turbo', price = 2500 }

-- SERVICES (grant 'maintenance' pour nettoyer) — forfait unique, mis en panier
-- mais exécuté seulement après paiement confirmé (cf. server/tuning.lua).
-- Pas de "Réparer le véhicule" ici : la réparation passe uniquement par le
-- diagnostic + les interventions ciblées (module/atelier/client/interventions.lua),
-- chaque intervention s'ajoutant à la même facture véhicule que le tuning.
Config.Atelier.Tuning.Services = {
    { id = 'clean',  label = 'Nettoyer le véhicule', price = 150 },
}

-- ESTHÉTIQUE (grant 'customization')

-- Carrosserie visuelle — même mécanique de palier que Performance
-- (SetVehicleMod/GetNumVehicleMods), catégories VMT_* natives GTA.
Config.Atelier.Tuning.Bodykit = {
    { id = 'spoiler',      modType = 0,  label = 'Aileron',            pricePerLevel = 350 },
    { id = 'bumperFront',  modType = 1,  label = 'Pare-choc avant',    pricePerLevel = 300 },
    { id = 'bumperRear',   modType = 2,  label = 'Pare-choc arrière',  pricePerLevel = 300 },
    { id = 'skirt',        modType = 3,  label = 'Bas de caisse',      pricePerLevel = 250 },
    { id = 'exhaust',      modType = 4,  label = 'Échappement',        pricePerLevel = 400 },
    { id = 'frame',        modType = 5,  label = 'Châssis',            pricePerLevel = 300 },
    { id = 'grille',       modType = 6,  label = 'Calandre',           pricePerLevel = 200 },
    { id = 'hood',         modType = 7,  label = 'Capot',              pricePerLevel = 350 },
    { id = 'fenderLeft',   modType = 8,  label = 'Aile gauche',        pricePerLevel = 250 },
    { id = 'fenderRight',  modType = 9,  label = 'Aile droite',        pricePerLevel = 250 },
    { id = 'roof',         modType = 10, label = 'Toit',               pricePerLevel = 300 },
}

Config.Atelier.Tuning.WheelTypes = {
    { id = 0, label = 'Sport' },
    { id = 1, label = 'Muscle' },
    { id = 2, label = 'Lowrider' },
    { id = 3, label = 'SUV' },
    { id = 4, label = 'Offroad' },
    { id = 5, label = 'Tuner' },
    { id = 6, label = 'Bike' },
    { id = 7, label = 'High End' },
}
Config.Atelier.Tuning.WheelPrice = 450 -- par jante posée (indice choisi dans le type)

-- Finition (native SetVehicleModColor_1/_2, comme à Los Santos Customs) —
-- indépendante de la couleur : même id de couleur, rendu différent selon le type.
Config.Atelier.Tuning.PaintTypes = {
    { id = 0, label = 'Normale' },
    { id = 1, label = 'Métallisée' },
    { id = 2, label = 'Perlée' },
    { id = 3, label = 'Mate' },
    { id = 4, label = 'Métal brossé' },
    { id = 5, label = 'Chromée' },
}

Config.Atelier.Tuning.PaintPrice = 350 -- par couche (type + couleur, primaire ou secondaire)

-- Palette de couleurs : repris tel quel de Config.Concessionnaire.Colors
-- (module/concessionnaire/config.lua) — la seule liste id → couleur déjà
-- vérifiée en jeu dans ce projet. Ma précédente liste "noms natifs" plus
-- large était reconstruite de mémoire et contenait de vraies erreurs
-- (ex: id 88 rendu jaune en jeu, pas blanc) : mieux vaut une liste courte
-- mais fiable qu'une longue et fausse. À étendre id par id, uniquement
-- après vérification en jeu.
Config.Atelier.Tuning.Paints = {
    { id = 0,   label = 'Noir' },
    { id = 4,   label = 'Gris' },
    { id = 5,   label = 'Argent' },
    { id = 111, label = 'Blanc' },
    { id = 27,  label = 'Rouge' },
    { id = 64,  label = 'Bleu' },
    { id = 70,  label = 'Bleu ciel' },
    { id = 53,  label = 'Vert' },
    { id = 88,  label = 'Jaune' },
    { id = 38,  label = 'Orange' },
    { id = 71,  label = 'Violet' },
    { id = 90,  label = 'Or' },
}

-- Peinture "cercle chromatique" (RGB précis, hors palette) — option payante :
-- SetVehicleCustomPrimaryColour/SetVehicleCustomSecondaryColour, prix plus
-- élevé qu'une couleur de palette classique.
Config.Atelier.Tuning.CustomPaintPrice = 900

Config.Atelier.Tuning.NeonPrice = 300
Config.Atelier.Tuning.NeonColors = {
    { label = 'Rouge',  r = 255, g = 0,   b = 0 },
    { label = 'Bleu',   r = 0,   g = 80,  b = 255 },
    { label = 'Vert',   r = 0,   g = 255, b = 90 },
    { label = 'Violet', r = 170, g = 0,   b = 255 },
    { label = 'Blanc',  r = 255, g = 255, b = 255 },
}

Config.Atelier.Tuning.TintPrice = 200
Config.Atelier.Tuning.Tints = {
    { id = 1, label = 'Léger' },
    { id = 2, label = 'Sombre' },
    { id = 3, label = 'Limousine' },
    { id = 5, label = 'Pur Noir' },
}

-- Motifs / livrées (native SetVehicleLivery) — le nombre de motifs disponibles
-- dépend du véhicule (GetVehicleLiveryCount), résolu côté client à l'ouverture.
Config.Atelier.Tuning.LiveryPrice = 500 -- par motif posé

-- Extras (native SetVehicleExtra, id 1 à 14) : pièces optionnelles propres à
-- certains modèles (spoilers/becquets/decos additionnels notamment sur les
-- véhicules addon Gabz [Véhicules]/gb_vehicles_*). Aucune liste figée par
-- modèle : on détecte à l'ouverture (DoesExtraExist) quels extras existent
-- réellement sur le véhicule ciblé et seuls ceux-là sont proposés.
Config.Atelier.Tuning.ExtraPrice = 400 -- par extra activé
