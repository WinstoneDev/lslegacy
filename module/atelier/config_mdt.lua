--  MDT — Départements ATELIER (un par entreprise)
--
--  Red's Tunershop et Benny's sont deux entreprises concurrentes et
--  indépendantes (module/atelier/config/companies.lua) : chacune a son
--  propre département MDT, donc son propre effectif et sa propre fiche
--  Organisation. Un mécano de l'une ne voit jamais les employés de l'autre.
--
--  Chaque département déclare :
--    • jobs        : un seul job LSLegacy (celui de l'entreprise)
--    • tabs        : uniquement dashboard/effectifs/organisation, les 3 seuls
--                    onglets génériques sans permission requise (Config.MDT.Tabs)
--    • services    : hiérarchie des pôles de l'atelier (affichage "Organisation")
--    • grades      : mêmes libellés que Config.Atelier.Companies.*.grades
--                     (companies.lua), pour cohérence entre le job et la fiche MDT
--
--  Département complémentaire au sens du cahier des charges : aucune
--  permission MDT spécifique n'est nécessaire (ni ici, ni dans
--  Config.MDT.Tabs pour ces 3 onglets), donc `grants` reste vide.

Config.MDT = Config.MDT or {}
Config.MDT.Departments = Config.MDT.Departments or {}

-- Services/unités et grades sont identiques pour les deux entreprises en V1
-- (mêmes métiers, même grille — voir DefaultGrades dans companies.lua).
local AtelierServices = {
    {
        id = 'mecanique',
        label = 'Mécanique & Diagnostic',
        units = {
            { id = 'diagnostic', label = 'Diagnostic', description = "Relevé des pannes et de l'état du véhicule." },
            { id = 'reparation', label = 'Réparation Mécanique', description = 'Remise en état moteur, freins, transmission.' },
        },
    },
    {
        id = 'carrosserie',
        label = 'Carrosserie & Pneus',
        units = {
            { id = 'carrosserie', label = 'Carrosserie', description = 'Débosselage, peinture, remise en état de la caisse.' },
            { id = 'pneus', label = 'Pneumatiques', description = 'Remplacement et équilibrage des pneus.' },
        },
    },
    {
        id = 'performance',
        label = 'Performance & Personnalisation',
        units = {
            { id = 'tuning', label = 'Préparation Performance', description = 'Réglages moteur, transmission, freins, tenue de route.' },
            { id = 'customisation', label = 'Personnalisation', description = 'Peinture, jantes, vitres teintées, accessoires.' },
        },
    },
    {
        id = 'gestion',
        label = "Gestion de l'Atelier",
        units = {
            { id = 'stock', label = 'Stock de Pièces', description = "Approvisionnement et suivi du stock de l'entreprise." },
            { id = 'facturation', label = 'Facturation', description = 'Suivi des tickets ouverts et des factures émises.' },
        },
    },
}

-- GRADES (0 → 7) — mêmes libellés que DefaultGrades (companies.lua).
local AtelierGrades = {
    [0] = { label = 'Stagiaire',             grants = {}, responsibilities = "Observation, aucune intervention seul." },
    [1] = { label = 'Apprenti Mécanicien',   grants = {}, responsibilities = "Diagnostic, réparation mécanique de base, facturation." },
    [2] = { label = 'Mécanicien',            grants = {}, responsibilities = "Carrosserie, préparation performance, personnalisation." },
    [3] = { label = 'Mécanicien Confirmé',   grants = {}, responsibilities = "Interventions complexes en autonomie." },
    [4] = { label = 'Expert Mécanicien',     grants = {}, responsibilities = "Référent technique de l'atelier." },
    [5] = { label = "Chef d'Équipe",         grants = { 'manage_stock' }, responsibilities = "Gestion du stock de pièces." },
    [6] = { label = 'Gérant',                grants = { 'manage_personnel' }, responsibilities = "Gestion des employés." },
    [7] = { label = 'Patron',                grants = { 'manage_boutique', 'manage_personnel' }, responsibilities = "Administration complète de l'entreprise." },
}

-- Grille Red's Tunershop : identique à AtelierGrades, + recrutement (bouton
-- "+ Ajouter effectif" de l'onglet Effectifs, gaté sur recruit_personnel côté
-- serveur dans mdt/server/main.lua). Copie dédiée pour ne pas l'activer chez
-- Benny's tant que la demande n'a pas été confirmée pour cette entreprise.
local AtelierGradesReds = {
    [0] = AtelierGrades[0],
    [1] = AtelierGrades[1],
    [2] = AtelierGrades[2],
    [3] = AtelierGrades[3],
    [4] = AtelierGrades[4],
    [5] = AtelierGrades[5],
    [6] = { label = 'Gérant', grants = { 'manage_personnel', 'recruit_personnel' }, responsibilities = "Gestion des employés." },
    [7] = { label = 'Patron', grants = { 'manage_boutique', 'manage_personnel', 'recruit_personnel' }, responsibilities = "Administration complète de l'entreprise." },
}

Config.MDT.Departments.atelier_reds = {
    label = "Red's Tunershop",
    color = '#8b1a1a', -- même rouge sombre/brique que companies.lua
    logo  = 'reds_tunershop.png', -- module/mdt/html/reds_tunershop.png

    jobs = { 'mechanic_reds' },
    tabs = { 'dashboard', 'effectifs', 'organisation', 'garage', 'entreprise', 'boutique_tenue', 'commande_pieces', 'grade_permissions' },
    services = AtelierServices,
    grades = AtelierGradesReds,

    -- BOUTIQUE TENUES — coordonnées reprises de l'ancien vestiaire
    -- (Config.Atelier.Companies.reds.clothingCoords, retiré).
    boutique = {
        DeliveryCoords  = vector3(-671.762634, -2462.268066, 13.929688),
        DeliveryHeading = 334.48818969727,
        ItemPrice      = 30,
        DeliveryDelay  = 3 * 60,
        MaxPendingPerAgent = 3,
        MaxItemsPerOrder = 15,
    },

    -- COMMANDE DE PIÈCES (module/mdt/server/parts.lua) — livrée directement
    -- au stock du dépôt de pièces de cette entreprise (module/atelier), pas
    -- à un point de retrait dédié : le dépôt existant (touche ALT/ox_target,
    -- module/atelier/client/inventory.lua) sert déjà de point de retrait.
    parts = {
        companyId          = 'reds',
        DeliveryDelay       = 5 * 60,
        MaxPendingOrders    = 5,
        MaxQuantityPerOrder = 50,
    },
}

Config.MDT.Departments.atelier_bennys = {
    label = "Benny's Original Motor Works",
    color = '#b8860b', -- même or/moutarde street que companies.lua
    logo  = 'bennys.png', -- module/mdt/html/bennys.png

    jobs = { 'mechanic_bennys' },
    tabs = { 'dashboard', 'effectifs', 'organisation', 'garage', 'entreprise', 'boutique_tenue', 'commande_pieces', 'grade_permissions' },
    services = AtelierServices,
    grades = AtelierGrades,

    -- BOUTIQUE TENUES — coordonnées reprises de l'ancien vestiaire
    -- (Config.Atelier.Companies.bennys.clothingCoords, retiré).
    boutique = {
        DeliveryCoords = vector3(-207.5, -1311.0, 31.29),
        ItemPrice      = 30,
        DeliveryDelay  = 3 * 60,
        MaxPendingPerAgent = 3,
        MaxItemsPerOrder = 15,
    },

    -- COMMANDE DE PIÈCES — cf. atelier_reds ci-dessus.
    parts = {
        companyId          = 'bennys',
        DeliveryDelay       = 5 * 60,
        MaxPendingOrders    = 5,
        MaxQuantityPerOrder = 50,
    },
}
