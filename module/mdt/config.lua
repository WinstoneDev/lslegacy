--  MDT — Configuration GÉNÉRIQUE (cœur multi-jobs)
--  Ce fichier ne contient RIEN de spécifique à la police.
--  Chaque métier (police, ems, …) déclare son département dans son
--  propre fichier (ex: config_police.lua) via Config.MDT.Departments.

Config.MDT = Config.MDT or {}

-- Logs de debug du module (réutilise Config.Development.Print)
Config.MDT.Debug = false

-- Item d'inventaire qui ouvre le MDT
Config.MDT.Item = 'tablette_mdt'

-- Départements actifs. Pour en ajouter un : créer son config_<dep>.lua,
-- l'enregistrer dans Config.MDT.Departments, puis l'activer ici.
Config.MDT.ActiveDepartments = { 'police', 'samu', 'pompiers', 'gendarmerie' }

-- Sphères de données partagées
-- Par défaut chaque département est étanche : toutes les lectures sont
-- filtrées sur `department = <le sien>`. Une sphère regroupe plusieurs
-- départements qui travaillent sur la MÊME base (police et gendarmerie
-- partagent le fichier judiciaire : un avis de recherche émis par l'un
-- doit être connu de l'autre).
--
-- L'ÉCRITURE, elle, reste toujours estampillée au département réel de
-- l'auteur : c'est ce qui permet d'afficher « Police » ou « Gendarmerie »
-- sur chaque pièce du dossier.
Config.MDT.DataGroups = {
    { id = 'forces_ordre', label = "Forces de l'ordre", departments = { 'police', 'gendarmerie' } },
}

-- Tables effectivement mises en commun au sein d'une sphère.
-- `true`  → lecture élargie à tous les départements de la sphère ;
-- absente ou `false` → la table reste propre à chaque département.
--
-- Ce qui touche au citoyen et à la procédure est commun ; ce qui relève
-- de la vie interne d'un pôle (ses formations, ses documents) ne l'est pas.
Config.MDT.SharedTables = {
    mdt_criminal_records = true,   -- casier judiciaire
    mdt_fines            = true,   -- amendes
    mdt_warrants         = true,   -- avis de recherche
    mdt_custody          = true,   -- gardes à vue (suivent la fiche citoyen)
    mdt_reports          = true,   -- enquêtes
    mdt_intervention_reports = true, -- rapports d'intervention
    mdt_case_links       = true,   -- éléments rattachés à une enquête
    mdt_weapons          = true,   -- registre des armes
    mdt_vehicle_flags    = true,   -- véhicules signalés
    mdt_laws             = true,   -- code juridique
    police_callouts      = true,   -- interventions (appels 17) conjointes

    mdt_evidence         = false,  -- preuves : chaque pôle instruit les siennes
    mdt_trainings        = false,  -- formations internes au pôle
}

-- Webhook Discord optionnel pour les logs MDT (laisser '' pour désactiver)
Config.MDT.Webhook = GetConvar('lslegacy_webhook_mdt', '')

-- Onglets disponibles (génériques)
-- Chaque département choisit le sous-ensemble qu'il active (champ `tabs`).
-- `permission` : permission requise pour afficher l'onglet (nil = toujours visible
-- dès que le département a activé l'onglet).
Config.MDT.Tabs = {
    -- `dashboard` est en tête : c'est l'onglet ouvert par défaut pour les
    -- départements qui l'activent. Son rendu dépend du métier (vue SAMU
    -- pour le service médical, vue forces de l'ordre sinon).
    { id = 'dashboard',     label = 'Tableau de bord',   icon = '🏠', permission = nil },
    { id = 'citizens',      label = 'Citoyens',          icon = '👤', permission = 'view_citizens' },
    { id = 'vehicles',      label = 'Véhicules',         icon = '🚓', permission = 'view_vehicles' },
    { id = 'weapons',       label = 'Armes',             icon = '🔫', permission = 'view_weapons' },
    -- `int_reports` : les comptes rendus rédigés par les agents.
    -- `dossiers`    : les enquêtes, qui agrègent rapports, preuves, armes,
    --                 véhicules et personnes (l'id historique est conservé).
    { id = 'int_reports',   label = "Rapports d'intervention", icon = '📝', permission = 'view_reports' },
    { id = 'dossiers',      label = 'Enquête',           icon = '🕵️', permission = 'view_reports' },
    { id = 'warrants',      label = 'Avis de recherche', icon = '🚨', permission = 'view_warrants' },
    { id = 'custody',       label = 'Garde à vue',       icon = '🔒', permission = 'manage_custody' },
    -- `investigation` = le laboratoire : les preuves relevées sur le terrain.
    { id = 'investigation', label = 'Labo',              icon = '🔬', permission = 'view_evidence' },
    { id = 'laws',          label = 'Code Juridique',    icon = '⚖️', permission = 'view_laws' },
    -- `interventions` = les appels 17 générés par les PNJ (missions).
    { id = 'interventions', label = 'Appel 17',          icon = '📞', permission = 'view_callouts' },
    { id = 'effectifs',     label = 'Effectifs',         icon = '👮', permission = nil },
    { id = 'trainings',     label = 'Formations',        icon = '🎓', permission = 'view_trainings' },
    { id = 'organisation',  label = 'Organisation',      icon = '🏛️', permission = nil },
}

-- Bornes de validation serveur (anti-abus, partagées)
Config.MDT.Limits = {
    MaxFine          = 50000,  -- montant maximal d'une amende
    MaxSearchResults = 25,     -- nombre max de résultats de recherche renvoyés
    SearchMinChars   = 2,      -- longueur minimale d'une requête de recherche
    MaxTextLength    = 5000,   -- longueur max d'un champ texte libre (rapport, motif…)
    MaxTitleLength   = 150,    -- longueur max d'un titre
}

-- Niveaux de danger pour les avis de recherche
Config.MDT.DangerLevels = {
    [1] = { label = 'Faible',  color = '#2ecc71' },
    [2] = { label = 'Modéré',  color = '#f39c12' },
    [3] = { label = 'Élevé',   color = '#e74c3c' },
}

-- Types d'intervention. Alimente le menu déroulant du formulaire de
-- rapport d'intervention (onglet « Rapports d'intervention »).
Config.MDT.ReportTypes = {
    { id = 'intervention',  label = "Intervention" },
    { id = 'maincourante',  label = 'Main courante' },
    { id = 'accident',      label = "Accident de la circulation" },
    { id = 'judiciaire',    label = 'Affaire judiciaire' },
}

-- Catégories du Code Juridique (onglet "Code Juridique").
-- Ajouter une catégorie ici suffit : formulaire et filtres la prennent en compte.
Config.MDT.LawCategories = {
    'Code pénal',
    'Code civil',
    'Code du travail',
}

-- Permis détenus par un citoyen (affichés dans la synthèse de sa fiche).
-- Chaque permis = un item d'inventaire ; l'ordre définit l'ordre d'affichage.
-- Adapter les `item` aux noms réels de tes items de permis.
Config.MDT.Licenses = {
    { item = 'permis_a',       label = 'A' },
    { item = 'permis_b',       label = 'B' },
    { item = 'permis_c',       label = 'C' },
    { item = 'permis_d',       label = 'D' },
    { item = 'permis_moto',    label = 'Moto' },
    { item = 'permis_fluvial', label = 'Fluvial' },
    { item = 'permis_cotier',  label = 'Côtier' },
    { item = 'permis_avion',   label = 'Avion' },
    { item = 'permis_port',    label = "Port d'arme" },
    -- Compat ancien item générique
    { item = 'permis_conduire', label = 'Conduite' },
}

-- Codes de formation (utilisés pour les formations/stages et les compétences).
-- Sélectionner un code dans "Nouvelle formation" remplit automatiquement le nom.
Config.MDT.TrainingCodes = {
    { code = 'BZ003', name = 'Habilitation bâton' },
    { code = 'BZ006', name = 'Formation DIVA' },
    { code = 'BZ025', name = 'Intervention Autoroute' },
    { code = 'BZ029', name = 'Sécurité Personnelle Scientifique' },
    { code = 'CA003', name = 'Tireur Opérationnel' },
    { code = 'CA004', name = 'Tireur Haute Précision' },
    { code = 'CA005', name = 'Habilitation FAP Benelli' },
    { code = 'CA011', name = 'Tireur Qualifié' },
    { code = 'CA012', name = 'Information EEI' },
    { code = 'CA019', name = 'Tir Moto' },
    { code = 'CA025', name = 'Habilitation Sig' },
    { code = 'CA027', name = 'Tireur De Précision' },
    { code = 'CA033', name = 'Tir Moto Escorte HP' },
    { code = 'CA034', name = 'Tireur Qualifié Arme Épaule' },
    { code = 'CA037', name = 'Habilitation LBD' },
    { code = 'CA041', name = 'Habilitation FAP Calibre 12' },
    { code = 'CA045', name = 'Sensibilisation Menace Engin Explo' },
    { code = 'CA066', name = 'Habilitation HK G36' },
    { code = 'CA068', name = 'TDM 1' },
    { code = 'CA069', name = 'TDM 2' },
    { code = 'CA070', name = 'Habilitation HK UMP9' },
    { code = 'CA072', name = 'Habilitation Cougar' },
    { code = 'CA090', name = 'Tireur Certifié' },
    { code = 'CA096', name = 'Habilitation PIE' },
    { code = 'CA102', name = 'Tir En Civile' },
    { code = 'CA104', name = 'Découverte Objets Suspect' },
    { code = 'CA108', name = 'Tireur Qualifié Moto' },
    { code = 'CB008', name = 'Secourisme Tactique' },
    { code = 'CB014', name = 'TSU' },
    { code = 'CG011', name = 'Recyclage Bâton' },
    { code = 'CH012', name = 'Habilitation HK G36 Milieu OP' },
    { code = 'CH014', name = 'Recyclage Benelli' },
    { code = 'CH020', name = 'Recyclage LBD' },
    { code = 'CH021', name = 'Recyclage HK G36' },
    { code = 'CH022', name = 'Recyclage HK UMP9' },
    { code = 'CH023', name = 'Recyclage Cougar' },
    { code = 'CH027', name = 'Recyclage PIE' },
    { code = 'CJ012', name = 'Conduite Voiture Police' },
    { code = 'CJ013', name = 'Evaluation Conduite Voiture Police' },
    { code = 'CJ016', name = "Conduite Situation d'Urgence" },
    { code = 'CK016', name = 'Conduite Milieu sensible' },
    { code = 'CN012', name = 'Formation Intervention' },
    { code = 'CN017', name = 'Tir Fusil De Précision' },
    { code = 'CN018', name = 'Tir Sig' },
    { code = 'CS037', name = 'Police Technique lvl1' },
    { code = 'CZ001', name = 'Formation Formateur' },
    { code = 'CZ007', name = 'Formation OPJ' },
    { code = 'DH120', name = 'Lutte Criminalité BRI' },
    { code = 'DW007', name = 'Réglementation Armes' },
    { code = 'EK018', name = 'Consigne Alerte À La Bombe' },
    { code = 'EK061', name = 'Formation Escortes' },
    { code = 'EK062', name = 'Formation Escortes 2' },
    { code = 'EK065', name = 'Escortes Sensibles' },
    { code = 'EK071', name = 'Risque NRBC' },
    { code = 'EY005', name = 'Stupéfiant' },
}

-- Compétences à recycler : durée de validité (jours) après obtention.
-- Au-delà → statut "À recycler" (rouge), sinon "Validé" (vert).
Config.MDT.SkillRecycleDays = {
    CN018 = 30, CH022 = 30, CH021 = 30, CH014 = 30, CN017 = 30,
    CH023 = 90, CH020 = 90, CH027 = 90, CG011 = 90,
}

-- Compétences qui débloquent des permissions MDT (accordées à l'ouverture).
Config.MDT.SkillUnlocks = {
    CS037 = { 'view_evidence', 'manage_evidence' }, -- onglet Enquête + gestion preuves
    CZ001 = { 'manage_trainings' },                 -- création de formation
}

-- Table remplie par les config_<dep>.lua de chaque métier
Config.MDT.Departments = Config.MDT.Departments or {}
