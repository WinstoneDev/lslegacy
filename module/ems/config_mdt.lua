--  MDT — Département EMS
--
--  Ce fichier déclare Config.MDT.Departments.ems :
--    • jobs        : les métiers LSLegacy rattachés à ce département
--    • tabs        : onglets MDT activés pour ce département
--    • services    : hiérarchie des services / unités (affichage)
--    • grades      : 10 grades, chacun débloque permissions / véhicules
--
--  IMPORTANT — Permissions CUMULATIVES :
--  Chaque grade ne liste dans `grants` que les permissions QU'IL AJOUTE.
--  shared/permissions.lua cumule tous les `grants` des grades de 0 jusqu'au
--  grade du joueur.

Config.MDT = Config.MDT or {}
Config.MDT.Departments = Config.MDT.Departments or {}

Config.MDT.Departments.ems = {
    label = 'Emergency Medical Services',
    color = '#c0392b', -- rouge/blanc EMS

    jobs = { 'ems' },

    -- Onglets du MDT médical. `citizens` (fiche judiciaire police) a été
    -- retiré volontairement : les médecins passent par `med_records`, qui
    -- affiche l'identité SANS casier ni amendes. `organisation` affiche
    -- l'organigramme (services/unités + grille des grades avec leurs
    -- responsabilités), généré depuis `services`/`grades` ci-dessous.
    -- L'ordre d'affichage vient du registre Config.MDT.Tabs, pas de cette
    -- liste (voir config_medical.lua).
    tabs = {
        'dashboard',
        'garage',
        'entreprise',
        'effectifs',
        'organisation',
        'trainings',
        'med_records',
        'med_treatments',
        'med_dispatch',
        'med_docs',
        'boutique_tenue',
    },

    -- BOUTIQUE TENUES — commande de tenues livrées au point ci-dessous,
    -- débitées sur le compte entreprise EMS. Coordonnées reprises de
    -- l'ancien vestiaire (Config.EMS.ClothingCoords, retiré : plus de tenue
    -- appliquée directement, la remise se fait toujours en inventaire).
    boutique = {
        DeliveryCoords = vector3(-807.296692, -1224.553833, 11.301147),
        ItemPrice      = 30,
        DeliveryDelay  = 3 * 60,
        MaxPendingPerAgent = 3,
        MaxItemsPerOrder = 15,
    },

    -- Codes de formation propres à l'EMS (sinon le cœur MDT retomberait
    -- sur Config.MDT.TrainingCodes, qui ne contient que du police : tir,
    -- LBD, bâton…). Lu par le serveur via `dep.trainingCodes`.
    trainingCodes = {
        { code = 'MA001', name = 'PSC1 — Prévention et secours civiques' },
        { code = 'MA002', name = 'PSE1 — Premiers secours en équipe' },
        { code = 'MA003', name = 'PSE2 — Premiers secours en équipe 2' },
        { code = 'MA010', name = 'Conduite de véhicule sanitaire' },
        { code = 'MA011', name = 'Conduite en urgence' },
        { code = 'MB001', name = 'Réanimation cardio-pulmonaire' },
        { code = 'MB002', name = 'Défibrillateur automatisé' },
        { code = 'MB003', name = 'Intubation et voies aériennes' },
        { code = 'MB004', name = 'Perfusion et voie veineuse' },
        { code = 'MB005', name = 'Immobilisation et relevage' },
        { code = 'MC001', name = 'Accouchement inopiné' },
        { code = 'MC002', name = 'Urgences pédiatriques' },
        { code = 'MC003', name = 'Brûlés graves' },
        { code = 'MC004', name = 'Traumatologie lourde' },
        { code = 'MD001', name = 'Risque NRBC — décontamination' },
        { code = 'MD002', name = 'Damage control / plaie par arme' },
        { code = 'ME001', name = 'Héliportage sanitaire' },
        { code = 'ME002', name = 'Triage de victimes multiples' },
        { code = 'MF001', name = 'Encadrement d\'équipe' },
        { code = 'MF002', name = 'Formation de formateur' },
    },

    services = {
        {
            id = 'secours_urgence',
            label = "Secours d'Urgence",
            units = {
                { id = 'ambulance', label = 'Ambulance',  description = 'Intervention de premiers secours.' },
                { id = 'smur',      label = 'SMUR',       description = 'Service mobile d\'urgence et de réanimation.' },
            },
        },
    },

    -- GRADES (0 → 9)
    --  Permissions CUMULATIVES : chaque grade ne liste que ce qu'il AJOUTE.
    --  Échelons intermédiaires propres à la filière secours/soins réelle
    --  (Ambulancier Confirmé, Infirmier Anesthésiste, Interne, Médecin) :
    --  certains grades n'ajoutent aucune permission, la promotion étant
    --  alors une reconnaissance d'ancienneté/spécialisation, pas un nouveau
    --  droit.
    --
    --  SÉCURITÉ — `view_citizens` a été RETIRÉ du grade 0.
    --  Cette permission est celle du MDT police : elle donne accès aux
    --  handlers `getCitizen`/`searchCitizens`, qui renvoient casier
    --  judiciaire, amendes et gardes à vue. Tant que l'EMS la possédait,
    --  un membre pouvait lire le dossier judiciaire d'un citoyen même sans
    --  l'onglet (il suffit d'appeler l'event). Les médecins utilisent
    --  désormais `view_med_records`, dont le handler ne renvoie QUE
    --  l'identité et les données médicales.
    grades = {
        [0] = {
            label = 'Stagiaire EMS',
            grants = {
                'heal_player',
                'view_med_records',   -- lecture des dossiers médicaux
                'view_treatments',    -- lecture des traitements
                'view_dispatch',      -- carte + appels en cours
                'view_med_docs',      -- documents internes
                'view_trainings',     -- onglet Formations
            },
            vehicles = { 'Ambulance' },
            units = { 'ambulance' },
            responsibilities = "Premiers soins encadrés, transport de patients.",
        },
        [1] = {
            label = 'Auxiliaire Ambulancier',
            grants = {
                'revive_player',
                'med_add_entry',      -- ajouter une entrée à un dossier
            },
            vehicles = { 'Ambulance' },
            units = { 'ambulance' },
            responsibilities = "Premiers secours, réanimation de base.",
        },
        [2] = {
            label = 'Ambulancier',
            grants = {
                'edit_med_records',   -- modifier la fiche (groupe sanguin, allergies…)
                'manage_dispatch',    -- prendre en charge / clore un appel
            },
            vehicles = { 'Ambulance' },
            units = { 'ambulance', 'smur' },
            responsibilities = "Intervention autonome, gestion des urgences courantes.",
        },
        [3] = {
            label = 'Ambulancier Confirmé',
            grants = {}, -- ancienneté, aucune permission supplémentaire
            vehicles = { 'Ambulance' },
            units = { 'ambulance', 'smur' },
            responsibilities = "Ambulancier expérimenté, encadrement des stagiaires sur le terrain.",
        },
        [4] = {
            label = 'Infirmier',
            grants = {
                'advanced_care',
                'manage_treatments',  -- prescrire / clore un traitement
            },
            vehicles = { 'Ambulance', 'Hélicoptère médical' },
            units = { 'ambulance', 'smur' },
            responsibilities = "Soins avancés, héliportage des urgences vitales.",
        },
        [5] = {
            label = 'Infirmier Anesthésiste',
            grants = {}, -- spécialisation IADE, déjà couverte par advanced_care
            vehicles = { 'Ambulance', 'Hélicoptère médical' },
            units = { 'ambulance', 'smur' },
            responsibilities = "Anesthésie et réanimation avancée en SMUR.",
        },
        [6] = {
            label = 'Interne en Médecine',
            grants = {}, -- médecin en formation, supervisé
            vehicles = { 'Ambulance', 'Hélicoptère médical' },
            units = { 'ambulance', 'smur' },
            responsibilities = "Médecin en formation, supervisé par un médecin senior.",
        },
        [7] = {
            label = 'Médecin',
            grants = {
                'med_delete_entry',   -- supprimer une entrée de dossier
            },
            vehicles = { 'Ambulance', 'Hélicoptère médical' },
            units = { 'ambulance', 'smur' },
            responsibilities = "Diagnostic et prescription en autonomie complète.",
        },
        [8] = {
            label = 'Médecin Chef de Service',
            grants = {
                'manage_service',
                'manage_med_docs',    -- créer/modifier/supprimer un document interne
                'manage_board',       -- publier le petit mot du dashboard
                'manage_trainings',   -- créer une formation
                'manage_boutique',    -- onglet Boutique tenues
                'manage_personnel',   -- affectations/carrière (onglet Effectifs → fiche agent)
            },
            vehicles = { 'Ambulance', 'Hélicoptère médical' },
            units = { 'ambulance', 'smur' },
            responsibilities = "Coordination du service, gestion des effectifs EMS.",
        },
        [9] = {
            label = 'Médecin Coordinateur EMS',
            grants = {}, -- déjà tout, via le cumul des grades précédents
            vehicles = { 'Ambulance', 'Hélicoptère médical' },
            units = { 'ambulance', 'smur' },
            responsibilities = "Direction médicale de l'EMS, coordination générale des secours.",
        },
    },
}
