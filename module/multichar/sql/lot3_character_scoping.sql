-- =============================================================
--  Character-scoping — Lot 3 (véhicules)
--  À exécuter une seule fois. Faire un dump de sauvegarde avant.
--
--  persistent_vehicles n'a aucune colonne owner (purement clé sur plate) :
--  aucun changement de schéma nécessaire pour cette table.
-- =============================================================

ALTER TABLE `owned_vehicles` ADD COLUMN `character_id` INT NULL AFTER `owner`;
UPDATE `owned_vehicles` t JOIN `players` p ON p.identifier = t.owner AND p.slot = 1
    SET t.character_id = p.`boutique-id`;

ALTER TABLE `concessionnaire_occasions` ADD COLUMN `character_id` INT NULL AFTER `owner`;
UPDATE `concessionnaire_occasions` t JOIN `players` p ON p.identifier = t.owner AND p.slot = 1
    SET t.character_id = p.`boutique-id`;

ALTER TABLE `fourriere` ADD COLUMN `character_id` INT NULL AFTER `owner`;
UPDATE `fourriere` t JOIN `players` p ON p.identifier = t.owner AND p.slot = 1
    SET t.character_id = p.`boutique-id`;

-- -------------------------------------------------------------------
-- Hors périmètre de ce lot (reporté) :
--   la "fiche agent" MDT (mdt_agent_meta + mdt_agent_career/assignments/
--   commendations/skills, mdt_weapon_persons, mdt_training_signups) —
--   nécessite de faire circuler character_id jusqu'au JS du MDT
--   (module/mdt/html/js/mdt.js) et dans la liste des effectifs
--   (readHandlers.getRoster/getDashboard) — futur Lot 4.
--   LB-Phone — Lot 5.
-- -------------------------------------------------------------------
