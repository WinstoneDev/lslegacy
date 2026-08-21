-- =============================================================
--  Character-scoping — Lot 4 (fiche agent MDT)
--  À exécuter une seule fois. Faire un dump de sauvegarde avant.
--
--  mdt_agent_meta change de clé primaire : `identifier` (le compte) ne
--  peut plus être PK, car un compte multichar peut avoir plusieurs
--  personnages agents, chacun avec sa propre fiche. Nouvelle PK = `id`
--  (surrogate), `character_id` devient la contrainte d'unicité réelle.
-- =============================================================

ALTER TABLE `mdt_agent_meta`
    ADD COLUMN `id` INT NOT NULL AUTO_INCREMENT FIRST,
    ADD COLUMN `character_id` INT NULL AFTER `identifier`,
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (`id`);
UPDATE `mdt_agent_meta` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
ALTER TABLE `mdt_agent_meta` ADD UNIQUE KEY `uq_meta_character` (`character_id`);

-- mdt_agent_career : UNIQUE(identifier, grade_index) -> UNIQUE(character_id, grade_index)
ALTER TABLE `mdt_agent_career` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `mdt_agent_career` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
ALTER TABLE `mdt_agent_career` DROP INDEX `uq_career`;
ALTER TABLE `mdt_agent_career` ADD UNIQUE KEY `uq_career` (`character_id`, `grade_index`);

-- mdt_agent_assignments : pas de contrainte UNIQUE, juste ajout + backfill
ALTER TABLE `mdt_agent_assignments` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `mdt_agent_assignments` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;

-- mdt_agent_commendations : idem
ALTER TABLE `mdt_agent_commendations` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `mdt_agent_commendations` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;

-- mdt_agent_skills : UNIQUE(identifier, skill) -> UNIQUE(character_id, skill)
ALTER TABLE `mdt_agent_skills` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `mdt_agent_skills` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
ALTER TABLE `mdt_agent_skills` DROP INDEX `uq_mas`;
ALTER TABLE `mdt_agent_skills` ADD UNIQUE KEY `uq_mas` (`character_id`, `skill`);

-- mdt_weapon_persons : UNIQUE(weapon_id, identifier) -> UNIQUE(weapon_id, character_id)
-- Peut lier un citoyen hors-ligne (pas seulement un agent) : backfill identique
-- (repli slot 1), résolution en ligne gérée par LSLegacy.ResolveCharacterId côté code.
ALTER TABLE `mdt_weapon_persons` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `mdt_weapon_persons` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
ALTER TABLE `mdt_weapon_persons` DROP INDEX `uq_mwp`;
ALTER TABLE `mdt_weapon_persons` ADD UNIQUE KEY `uq_mwp` (`weapon_id`, `character_id`);

-- mdt_training_signups : UNIQUE(training_id, identifier) -> UNIQUE(training_id, character_id)
ALTER TABLE `mdt_training_signups` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `mdt_training_signups` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
ALTER TABLE `mdt_training_signups` DROP INDEX `uq_mts`;
ALTER TABLE `mdt_training_signups` ADD UNIQUE KEY `uq_mts` (`training_id`, `character_id`);

-- -------------------------------------------------------------------
-- Il ne reste plus, hors périmètre de tous les lots livrés, que LB-Phone
-- (Lot 5 — décision à part vu le risque de perte des téléphones existants).
-- -------------------------------------------------------------------
