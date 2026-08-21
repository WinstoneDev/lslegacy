-- =============================================================
--  Character-scoping — Lot 1
--  À exécuter une seule fois. Faire un dump de sauvegarde avant.
--
--  Corrige aussi le bug de doublon à la prise de service : 5 des 6 tables
--  "agent" n'avaient qu'un index normal sur `identifier`, pas une
--  contrainte UNIQUE, donc leur `ON DUPLICATE KEY UPDATE` ne se
--  déclenchait jamais (gendarmerie_officers avait déjà la bonne
--  contrainte). La nouvelle contrainte UNIQUE porte sur `character_id`.
-- =============================================================

-- -------------------------------------------------------------------
-- Groupe A — tables "agent de service" (cascade-delete à la suppression
-- d'un personnage, cf. module/multichar/server/main.lua)
-- -------------------------------------------------------------------

-- police_officers
ALTER TABLE `police_officers` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `police_officers` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
-- Dédoublonnage : garder la ligne la plus récente par identifier avant de poser la contrainte unique.
DELETE t1 FROM `police_officers` t1
    INNER JOIN `police_officers` t2
        ON t1.identifier = t2.identifier
        AND (t1.last_seen < t2.last_seen OR (t1.last_seen = t2.last_seen AND t1.id < t2.id));
ALTER TABLE `police_officers` ADD UNIQUE KEY `uq_po_character` (`character_id`);

-- pompiers_agents
ALTER TABLE `pompiers_agents` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `pompiers_agents` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
DELETE t1 FROM `pompiers_agents` t1
    INNER JOIN `pompiers_agents` t2
        ON t1.identifier = t2.identifier
        AND (t1.last_seen < t2.last_seen OR (t1.last_seen = t2.last_seen AND t1.id < t2.id));
ALTER TABLE `pompiers_agents` ADD UNIQUE KEY `uq_pa_character` (`character_id`);

-- mecanicien_agents
ALTER TABLE `mecanicien_agents` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `mecanicien_agents` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
DELETE t1 FROM `mecanicien_agents` t1
    INNER JOIN `mecanicien_agents` t2
        ON t1.identifier = t2.identifier
        AND (t1.last_seen < t2.last_seen OR (t1.last_seen = t2.last_seen AND t1.id < t2.id));
ALTER TABLE `mecanicien_agents` ADD UNIQUE KEY `uq_ma_character` (`character_id`);

-- ltd_agents
ALTER TABLE `ltd_agents` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `ltd_agents` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
DELETE t1 FROM `ltd_agents` t1
    INNER JOIN `ltd_agents` t2
        ON t1.identifier = t2.identifier
        AND (t1.last_seen < t2.last_seen OR (t1.last_seen = t2.last_seen AND t1.id < t2.id));
ALTER TABLE `ltd_agents` ADD UNIQUE KEY `uq_la_character` (`character_id`);

-- samu_agents
ALTER TABLE `samu_agents` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `samu_agents` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
DELETE t1 FROM `samu_agents` t1
    INNER JOIN `samu_agents` t2
        ON t1.identifier = t2.identifier
        AND (t1.last_seen < t2.last_seen OR (t1.last_seen = t2.last_seen AND t1.id < t2.id));
ALTER TABLE `samu_agents` ADD UNIQUE KEY `uq_sa_character` (`character_id`);

-- gendarmerie_officers (avait déjà UNIQUE(identifier), remplacée par UNIQUE(character_id))
ALTER TABLE `gendarmerie_officers` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `gendarmerie_officers` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
ALTER TABLE `gendarmerie_officers` DROP INDEX `uq_go_identifier`;
ALTER TABLE `gendarmerie_officers` ADD UNIQUE KEY `uq_go_character` (`character_id`);

-- police_radio_channels (table créée mais non utilisée actuellement par le code — migrée par cohérence)
ALTER TABLE `police_radio_channels` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `police_radio_channels` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;

-- -------------------------------------------------------------------
-- Groupe B — re-scope uniquement, PAS de cascade-delete (preuves/scènes)
-- -------------------------------------------------------------------

ALTER TABLE `interim_stations` ADD COLUMN `last_filled_by_character_id` INT NULL AFTER `last_filled_by`;
UPDATE `interim_stations` t JOIN `players` p ON p.identifier = t.last_filled_by AND p.slot = 1
    SET t.last_filled_by_character_id = p.`boutique-id`;

ALTER TABLE `police_blood_traces` ADD COLUMN `collected_by_character_id` INT NULL AFTER `collected_by`;
UPDATE `police_blood_traces` t JOIN `players` p ON p.identifier = t.collected_by AND p.slot = 1
    SET t.collected_by_character_id = p.`boutique-id`;

ALTER TABLE `police_crime_scenes` ADD COLUMN `created_by_character_id` INT NULL AFTER `created_by`;
UPDATE `police_crime_scenes` t JOIN `players` p ON p.identifier = t.created_by AND p.slot = 1
    SET t.created_by_character_id = p.`boutique-id`;

-- -------------------------------------------------------------------
-- Hors périmètre de ce lot (Lot 2/3/4, cf. plan) :
--   bankaccounts, fourriere, police_cuffed, police_custody, police_prison,
--   mdt_agent_meta (PK=identifier), mdt_med_records, mdt_custody,
--   mdt_criminal_records, mdt_fines, mdt_warrants, police_dna,
--   police_fingerprints, police_callout_agents, owned_vehicles,
--   persistent_vehicles, et la majorité de module/mdt/server/main.lua
--   (mdt_agent_assignments/career/commendations/skills/mdt_weapon_persons/
--   mdt_training_signups inclus : ces tables sont éditées via une UI
--   "fiche agent" qui référence un `identifier` cible envoyé par le client,
--   pas l'identifier de l'appelant — nécessite de faire remonter le
--   character_id jusqu'au JS du MDT, pas juste le Lua serveur), LB-Phone.
-- -------------------------------------------------------------------
