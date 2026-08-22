--  MDT MÉDICAL (SAMU) — Configuration
--
--  Ce fichier fait deux choses :
--    1. il déclare Config.Medical (catalogues métier : traitements,
--       catégories de documents, types d'entrées de dossier, quartiers)
--    2. il ENREGISTRE les onglets médicaux dans Config.MDT.Tabs
--
--  Le point 2 mérite une explication : le cœur MDT construit la barre
--  latérale en parcourant Config.MDT.Tabs et en ne gardant que les
--  onglets que le département a activés (champ `tabs` de config_mdt).
--  On ajoute donc nos onglets à ce registre depuis ICI, plutôt que
--  d'éditer module/mdt/config.lua — la police n'active aucun de ces
--  onglets, elle ne voit donc strictement aucun changement.
--
--  Doit être chargé APRÈS module/mdt/config.lua (voir fxmanifest).

Config.Medical = Config.Medical or {}

-- Enregistrement des onglets médicaux
-- `dashboard` est désormais déclaré par le cœur MDT (module/mdt/config.lua),
-- en tête du registre : c'est le premier onglet, donc celui ouvert par
-- défaut, des départements qui l'activent. On le rajoute ici uniquement
-- si le cœur ne l'a pas fourni, pour rester tolérant à un ordre de
-- chargement inattendu.
Config.MDT           = Config.MDT or {}
Config.MDT.Tabs      = Config.MDT.Tabs or {}

local hasDashboard = false
for _, t in ipairs(Config.MDT.Tabs) do
    if t.id == 'dashboard' then hasDashboard = true break end
end
if not hasDashboard then
    table.insert(Config.MDT.Tabs, 1, { id = 'dashboard', label = 'Tableau de bord', icon = '🏠', permission = nil })
end

-- Les autres s'ajoutent à la fin : pour le SAMU l'ordre final devient
-- Dashboard · Effectifs · Formations · Dossier médical · Traitements ·
-- Dispatch · Documents internes (Effectifs/Formations étant déjà
-- déclarés au milieu du registre par le cœur MDT).
local medicalTabs = {
    { id = 'med_records',    label = 'Dossier médical',     icon = '🩺', permission = 'view_med_records' },
    { id = 'med_treatments', label = 'Traitements',         icon = '💊', permission = 'view_treatments' },
    { id = 'med_dispatch',   label = 'Dispatch',            icon = '🚑', permission = 'view_dispatch' },
    { id = 'med_docs',       label = 'Documents internes',  icon = '📄', permission = 'view_med_docs' },
}
for _, t in ipairs(medicalTabs) do
    Config.MDT.Tabs[#Config.MDT.Tabs + 1] = t
end

-- Groupes sanguins (liste du formulaire de dossier)
Config.Medical.BloodGroups = { 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-' }

-- Types d'entrées d'un dossier médical
Config.Medical.EntryTypes = {
    { id = 'consultation',   label = 'Consultation' },
    { id = 'intervention',   label = 'Intervention sur place' },
    { id = 'hospitalisation',label = 'Hospitalisation' },
    { id = 'chirurgie',      label = 'Chirurgie' },
    { id = 'psy',            label = 'Suivi psychologique' },
    { id = 'certificat',     label = 'Certificat médical' },
}

-- Catalogue des traitements
-- Sélectionner un code dans le formulaire remplit le libellé et le
-- dosage par défaut. Le champ reste éditable : ce n'est qu'une aide.
Config.Medical.Treatments = {
    { code = 'ANT001', label = 'Antalgique léger',        dosage = '1 g / 6 h' },
    { code = 'ANT002', label = 'Antalgique opioïde',      dosage = '10 mg / 8 h' },
    { code = 'ATB001', label = 'Antibiotique large spectre', dosage = '500 mg / 8 h' },
    { code = 'ANX001', label = 'Anxiolytique',            dosage = '0,5 mg / soir' },
    { code = 'CRD001', label = 'Traitement cardiaque',    dosage = '5 mg / jour' },
    { code = 'INS001', label = 'Insulinothérapie',        dosage = 'Selon glycémie' },
    { code = 'PER001', label = 'Perfusion NaCl',          dosage = '500 mL' },
    { code = 'TRA001', label = 'Transfusion sanguine',    dosage = '1 poche' },
    { code = 'ORT001', label = 'Immobilisation / plâtre', dosage = '4 à 6 semaines' },
    { code = 'REE001', label = 'Rééducation',             dosage = '3 séances / semaine' },
    { code = 'VAC001', label = 'Vaccination',             dosage = 'Dose unique' },
    { code = 'SUR001', label = 'Surveillance simple',     dosage = '24 h' },
}

-- Statuts possibles d'un traitement (le serveur n'accepte que ces clés)
Config.Medical.TreatmentStatuses = {
    { id = 'actif',   label = 'En cours' },
    { id = 'termine', label = 'Terminé' },
    { id = 'annule',  label = 'Annulé' },
}

-- Catégories de documents internes
Config.Medical.DocCategories = {
    'Protocole de soins',
    'Note de service',
    'Compte rendu de réunion',
    'Formation interne',
    'Règlement',
    'Général',
}

-- Dispatch
-- Plus de carte : le dispatch liste les unités en service avec leur
-- quartier (voir Config.Medical.Districts) et leur statut, patrouille ou
-- intervention. Le statut est déduit côté serveur des appels affectés.
Config.Medical.Dispatch = {
    refreshInterval = 2000, -- ms entre deux rafraîchissements de la liste (NUI)
}

-- Quartiers
-- Nomment la position des ambulances et des appels dans le dispatch
-- ("Sandy Shores"), à la place d'une carte. Le quartier retenu est le
-- plus proche du point — centres approximatifs, suffisant pour situer
-- une intervention. En ajouter un ici affine immédiatement l'affichage.
Config.Medical.Districts = {
    -- Los Santos et alentours
    { label = 'Centre-ville',        x =   200.0, y =  -900.0 },
    { label = 'Mission Row',         x =   420.0, y = -1000.0 },
    { label = 'Vespucci',            x = -1250.0, y = -1400.0 },
    { label = 'Del Perro',           x = -1650.0, y =  -900.0 },
    { label = 'Rockford Hills',      x =  -800.0, y =  -200.0 },
    { label = 'Vinewood',            x =   300.0, y =   200.0 },
    { label = 'Vinewood Hills',      x =  -500.0, y =   600.0 },
    { label = 'Mirror Park',         x =  1100.0, y =  -600.0 },
    { label = 'La Mesa',             x =   800.0, y = -1300.0 },
    { label = 'Cypress Flats',       x =   700.0, y = -2000.0 },
    { label = 'Aéroport (LSIA)',     x = -1000.0, y = -2600.0 },
    { label = 'Elysian Island',      x =   200.0, y = -2800.0 },
    { label = 'Chamberlain Hills',   x =  -200.0, y = -1600.0 },
    -- Comté de Blaine et ouest
    { label = 'Chumash',             x = -3200.0, y =  1100.0 },
    { label = 'Banham Canyon',       x = -2900.0, y =   400.0 },
    { label = 'Great Chaparral',     x =  -100.0, y =  1800.0 },
    { label = 'Fort Zancudo',        x = -2100.0, y =  3200.0 },
    { label = 'Harmony',             x =   400.0, y =  2600.0 },
    { label = 'Grand Senora',        x =   800.0, y =  3100.0 },
    { label = 'Sandy Shores',        x =  1900.0, y =  3700.0 },
    { label = 'Monts Tataviam',      x =  1300.0, y =  2000.0 },
    { label = 'Palomino Highlands',  x =  2400.0, y =  1900.0 },
    { label = 'Grapeseed',           x =  2000.0, y =  4800.0 },
    { label = 'Mont Chiliad',        x =   450.0, y =  5700.0 },
    { label = 'Paleto Bay',          x =  -300.0, y =  6300.0 },
    { label = 'Braddock Pass',       x =  1500.0, y =  3400.0 },
}

-- Bornes de validation serveur (anti-abus)
Config.Medical.Limits = {
    MaxTextLength    = 5000,
    MaxTitleLength   = 150,
    MaxShortLength   = 100,
    MaxSearchResults = 25,
    SearchMinChars   = 2,
    MaxBoardLength   = 600,
}
