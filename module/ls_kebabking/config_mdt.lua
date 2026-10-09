--  MDT — Département KEBAB KING
--
--  Même convention que les autres jobs (police/config_mdt.lua,
--  ems/config_mdt.lua, …) : la déclaration du département MDT vit dans le
--  module du job lui-même, chargée juste après sa config (fxmanifest.lua).
--
--  Le job lui-même ('kebabking') et ses grades sont enregistrés au
--  démarrage par module/ls_kebabking via exports('lslegacy'):registerJob(...)
--  (module/foodapi) — PAS ici. Les grades ci-dessous ne sont qu'un
--  DOUBLON d'affichage pour l'onglet "Organisation" (texte de poste plus
--  riche que le simple libellé de grade) : ils doivent rester alignés sur
--  ceux déclarés côté module/ls_kebabking/server/main.lua.
--
--  Aucune permission MDT spécifique n'est nécessaire pour les 3 onglets
--  génériques (dashboard/effectifs/organisation), donc `grants` reste vide,
--  comme pour les départements atelier.
--
--  dataStorePrefix/stockStores : lus par readHandlers.getRestoDashboard
--  (module/mdt/server/main.lua) pour afficher un tableau de bord réaliste
--  (stocks réels, pas des concepts de police) — voir html/js/kebabking.js.

Config.MDT = Config.MDT or {}
Config.MDT.Departments = Config.MDT.Departments or {}

local KebabKingServices = {
    {
        id = 'cuisine',
        label = 'Cuisine',
        units = {
            { id = 'preparation', label = 'Préparation', description = "Légumes, sauces, pain — mise en place avant service." },
            { id = 'cuisson',     label = 'Cuisson',      description = "Broche à viande, grill, friteuse." },
            { id = 'montage',     label = 'Montage',      description = "Assemblage des kebabs, galettes et tacos." },
        },
    },
    {
        id = 'salle',
        label = 'Salle & Service',
        units = {
            { id = 'plateaux', label = 'Service en salle', description = "Dépôt des commandes sur plateau pour le client." },
            { id = 'caisse',   label = 'Caisse',            description = "Encaissement des clients (espèces ou carte)." },
        },
    },
    {
        id = 'gestion',
        label = 'Gestion',
        units = {
            { id = 'stock',       label = 'Stock',       description = "Réserve, frigo, congélateur, stock boissons." },
            { id = 'facturation', label = 'Facturation',  description = "Suivi des ventes et du coffre de l'entreprise." },
        },
    },
}

-- GRADES (0 → 4) — mêmes libellés que ls_kebabking/server/main.lua
-- (Core:registerJob). Ordre croissant d'ancienneté/responsabilité.
local KebabKingGrades = {
    [0] = { label = 'Stagiaire',            grants = {}, responsibilities = "Observation, préparation simple sous supervision." },
    [1] = { label = 'Cuisinier',            grants = {}, responsibilities = "Toutes les stations de cuisine, service en salle." },
    [2] = { label = 'Cuisinier Confirmé',   grants = {}, responsibilities = "Gestion du stock (réserve, frigo, congélateur)." },
    [3] = { label = 'Responsable de Salle', grants = {}, responsibilities = "Facturation, accès au coffre de l'entreprise." },
    [4] = { label = 'Gérant',               grants = { 'manage_boutique', 'manage_personnel' }, responsibilities = "Administration complète du restaurant." },
}

Config.MDT.Departments.kebabking = {
    label = 'Kebab King',
    color = '#c62828', -- rouge kebab, cohérent avec l'enseigne
    logo  = 'kebabking.png', -- module/mdt/html/kebabking.png (à déposer manuellement)

    -- Onglet Effectifs/Organisation : "Agent"/👮 (par défaut, hérité des
    -- départements police/EMS) ne convient pas à un restaurant.
    staffLabel       = 'Employé',
    staffLabelPlural = 'Employés',
    staffIcon        = '🧑‍🍳',

    jobs = { 'kebabking' },
    tabs = { 'dashboard', 'effectifs', 'organisation', 'entreprise', 'boutique_tenue' },
    services = KebabKingServices,
    grades = KebabKingGrades,

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
    -- des DataStores du restaurant (voir ls_kebabking/shared/utils.lua,
    -- KK.DataStoreName) et liste des stockages à afficher.
    dataStorePrefix = 'ls_kebabking',
    stockStores = {
        { id = 'reserve', label = 'Réserve' },
        { id = 'fridge',  label = 'Frigo' },
        { id = 'freezer', label = 'Congélateur' },
        { id = 'drinks',  label = 'Stock boissons' },
    },
}
