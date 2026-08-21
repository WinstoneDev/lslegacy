-- =============================================================
--  Module multichar — migration
--  À exécuter une seule fois sur la base `players` existante.
--  Faire un dump de sauvegarde avant exécution.
-- =============================================================

-- 1) Colonne slot : identifie le personnage au sein d'un même compte
--    (identifier). Toutes les lignes existantes valent 1 par défaut,
--    donc chaque compte existant garde exactement son unique personnage
--    au slot 1 : aucune donnée de jeu n'est perdue ni déplacée.
ALTER TABLE `players`
    ADD COLUMN `slot` INT(11) NOT NULL DEFAULT 1 AFTER `identifier`;

-- 2) La contrainte "un seul personnage par identifier" est remplacée par
--    "un seul personnage par (identifier, slot)".
ALTER TABLE `players` DROP INDEX `uq_players_identifier`;
ALTER TABLE `players` ADD UNIQUE KEY `uq_players_identifier_slot` (`identifier`, `slot`);

-- -------------------------------------------------------------------
-- Phase 2 (hors périmètre de cette migration) :
--
-- De nombreux autres modules (police, gendarmerie, samu, pompiers,
-- mecanicien, ltd, mdt, adminmenu...) stockent des données propres au
-- personnage (job, casier judiciaire, dossier prison, carrière, service
-- actif...) mais les indexent aujourd'hui par `identifier` (le compte),
-- pas par personnage. Avec le multicharacter, ces données seront donc
-- partagées entre tous les personnages d'un même compte tant que ces
-- tables n'auront pas été migrées individuellement vers une clé par
-- personnage (`players.id`) — table par table, testée séparément.
--
-- Tables concernées (non-exhaustif, à vérifier au moment de la
-- migration de chaque module) : mecanicien_agents, gendarmerie_officers,
-- ltd_agents, samu_agents, mdt_med_records, mdt_med_entries,
-- mdt_med_treatments, mdt_med_calls, mdt_med_board, admin_warns,
-- pompiers_agents, police_officers, police_custody, police_prison,
-- mdt_agent_meta, mdt_agent_career, mdt_agent_assignments,
-- mdt_agent_commendations, mdt_agent_skills, mdt_criminal_records,
-- mdt_fines, mdt_warrants, mdt_custody, mdt_evidence,
-- mdt_weapon_persons, mdt_training_signups.
-- -------------------------------------------------------------------
