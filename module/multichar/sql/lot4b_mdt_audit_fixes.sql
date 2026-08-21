-- =============================================================
--  Character-scoping — corrections post-audit (après Lot 4)
--  À exécuter une seule fois. Faire un dump de sauvegarde avant.
--
--  Tables mdt_* repérées lors d'un audit de complétude comme manquant de
--  character_id alors qu'elles portent un dossier personnel (patient) :
--  mdt_med_entries, mdt_med_treatments, mdt_med_calls, et mdt_evidence
--  (sujet optionnel). Toutes les autres tables mdt_* auditées à cette
--  occasion (mdt_case_links, mdt_intervention_reports, mdt_laws,
--  mdt_reports, mdt_report_evidence, mdt_report_links, mdt_trainings,
--  mdt_vehicle_flags, mdt_weapons, mdt_weapon_reports, mdt_med_board,
--  mdt_med_docs) sont volontairement laissées telles quelles : leurs
--  colonnes identifier/officer sont de la traçabilité (qui a créé/lié
--  cet élément), pas un dossier personnel — même principe déjà appliqué
--  à `fourriere.officer`/`mdt_reports.author_identifier`.
-- =============================================================

ALTER TABLE `mdt_med_entries` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `mdt_med_entries` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;

ALTER TABLE `mdt_med_treatments` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `mdt_med_treatments` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;

-- mdt_med_calls : caller_identifier était jusqu'ici TOUJOURS NULL (bug
-- préexistant, cf. server/player/injury.lua, corrigé en même temps que
-- cette migration côté code) — rien à backfill pour les lignes déjà en
-- base sur caller_identifier, mais on ajoute la colonne pour les futurs appels.
ALTER TABLE `mdt_med_calls` ADD COLUMN `character_id` INT NULL AFTER `caller_identifier`;
UPDATE `mdt_med_calls` t JOIN `players` p ON p.identifier = t.caller_identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;

-- mdt_evidence : identifier est nullable (sujet optionnel d'une preuve).
ALTER TABLE `mdt_evidence` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `mdt_evidence` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;

-- -------------------------------------------------------------------
-- Cascade-delete étendue (module/multichar/server/main.lua) :
--   mdt_med_entries, mdt_med_treatments (dossier médical personnel,
--   même traitement que mdt_med_records).
-- Restent hors cascade (Groupe B, comme au Lot 1/2) :
--   mdt_evidence, mdt_med_calls.
-- -------------------------------------------------------------------
