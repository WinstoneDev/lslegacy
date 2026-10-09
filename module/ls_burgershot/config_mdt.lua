--  MDT — Département BURGER SHOT
--
--  Même convention que les autres jobs (police/config_mdt.lua,
--  ems/config_mdt.lua, ls_kebabking/config_mdt.lua, …) : la déclaration du
--  département MDT vit dans le module du job lui-même, chargée juste après
--  sa config (fxmanifest.lua).
--
--  Le job lui-même ('burgershot') et ses grades sont enregistrés au
--  démarrage par module/ls_burgershot via exports('lslegacy'):registerJob(...)
--  (module/foodapi) — PAS ici. Les grades ci-dessous ne sont qu'un
--  DOUBLON d'affichage pour l'onglet "Organisation" (texte de poste plus
--  riche que le simple libellé de grade) : ils doivent rester alignés sur
--  ceux déclarés côté module/ls_burgershot/server/main.lua.
--
--  Aucune permission MDT spécifique n'est nécessaire pour les 3 onglets
--  génériques (dashboard/effectifs/organisation), donc `grants` reste vide,
--  comme pour les départements atelier.
--
--  dataStorePrefix/stockStores : lus par readHandlers.getRestoDashboard
--  (module/mdt/server/main.lua) pour afficher un tableau de bord réaliste
--  (stocks réels, pas des concepts de police) — voir html/js/kebabking.js
--  (renderRestoDashboard, partagé avec Burger Shot).

Config.MDT = Config.MDT or {}
Config.MDT.Departments = Config.MDT.Departments or {}

local BurgerShotServices = {
    {
        id = 'cuisine',
        label = 'Cuisine',
        units = {
            { id = 'preparation', label = 'Plan de préparation', description = "Découpe légumes, pâtes — mise en place avant service." },
            { id = 'grill',       label = 'Grill',                description = "Cuisson des steaks, poulet, bacon." },
            { id = 'friteuse',    label = 'Friteuse',              description = "Frites, onion rings, nuggets." },
            { id = 'assemblage',  label = 'Assemblage',            description = "Montage des burgers." },
        },
    },
    {
        id = 'salle',
        label = 'Salle & Service',
        units = {
            { id = 'boissons', label = 'Machine à boissons', description = "Sodas et milkshakes." },
            { id = 'desserts', label = 'Desserts',            description = "Sundae, chausson aux pommes, cookies." },
            { id = 'plateaux', label = 'Service en salle',    description = "Dépôt des commandes sur plateau pour le client." },
            { id = 'caisse',   label = 'Caisse',              description = "Encaissement des clients (espèces ou carte)." },
        },
    },
    {
        id = 'gestion',
        label = 'Gestion',
        units = {
            { id = 'stock',       label = 'Stock',      description = "Réserve, frigo, congélateur, stock boissons." },
            { id = 'facturation', label = 'Facturation', description = "Suivi des ventes et du coffre de l'entreprise." },
        },
    },
}

-- GRADES (0 → 4) — mêmes libellés que ls_burgershot/server/main.lua
-- (Core:registerJob). Ordre croissant d'ancienneté/responsabilité.
local BurgerShotGrades = {
    [0] = { label = 'Stagiaire',            grants = {}, responsibilities = "Observation, préparation simple sous supervision." },
    [1] = { label = 'Cuisinier',            grants = {}, responsibilities = "Toutes les stations de cuisine, service en salle." },
    [2] = { label = 'Cuisinier Confirmé',   grants = {}, responsibilities = "Gestion du stock (réserve, frigo, congélateur) et coffre." },
    [3] = { label = 'Responsable de Salle', grants = {}, responsibilities = "Facturation, accès au coffre de l'entreprise." },
    [4] = { label = 'Gérant',               grants = { 'manage_boutique', 'manage_personnel' }, responsibilities = "Administration complète du restaurant." },
}

Config.MDT.Departments.burgershot = {
    label = 'Burger Shot',
    color = '#e65100', -- orange enseigne, cohérent avec la charte Burger Shot
    logo  = 'burgershot.png', -- module/mdt/html/burgershot.png (à déposer manuellement)

    -- Onglet Effectifs/Organisation : "Agent"/👮 (par défaut, hérité des
    -- départements police/EMS) ne convient pas à un restaurant.
    staffLabel       = 'Employé',
    staffLabelPlural = 'Employés',
    staffIcon        = '🧑‍🍳',

    jobs = { 'burgershot' },
    tabs = { 'dashboard', 'effectifs', 'organisation', 'entreprise', 'boutique_tenue' },
    services = BurgerShotServices,
    grades = BurgerShotGrades,

    -- BOUTIQUE TENUES — point de retrait non précisé (aucun vestiaire
    -- n'existait pour ce job) : coordonnées placeholder (0,0,0) à ajuster
    -- une fois l'emplacement défini (arrière-cuisine, réserve...).
    boutique = {
        DeliveryCoords = vector3(0.0, 0.0, 0.0),
        ItemPrice      = 30,
        DeliveryDelay  = 3 * 60,
        MaxPendingPerAgent = 3,
        MaxItemsPerOrder = 15,
    },

    -- Tableau de bord réaliste (readHandlers.getRestoDashboard) : préfixe
    -- des DataStores du restaurant (voir ls_burgershot/shared/utils.lua,
    -- BS.DataStoreName / BSConfig.Prefix) et liste des stockages à afficher.
    dataStorePrefix = 'ls_burgershot',
    stockStores = {
        { id = 'reserve', label = 'Réserve' },
        { id = 'fridge',  label = 'Frigo' },
        { id = 'freezer', label = 'Congélateur' },
        { id = 'drinks',  label = 'Stock boissons' },
    },
}
