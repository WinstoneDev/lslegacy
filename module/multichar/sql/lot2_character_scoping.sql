-- =============================================================
--  Character-scoping — Lot 2
--  À exécuter une seule fois. Faire un dump de sauvegarde avant.
--
--  Beaucoup de ces tables ont un double rôle (sujet + officier) :
--  `character_id` = le sujet (citoyen/patient/détenu), `*_character_id`
--  dédié = l'officier qui a fait l'action. Seul le rôle "sujet" est
--  utilisé pour la suppression en cascade (cf. module/multichar/server/main.lua) :
--  supprimer le personnage d'un officier ne doit pas effacer le casier
--  d'un citoyen tiers qu'il a arrêté.
-- =============================================================

-- -------------------------------------------------------------------
-- police_cuffed : table historique jamais lue/écrite par le code (le
-- menottage est géré en mémoire via statebag, cf. module/police/server/actions.lua).
-- Confirmé vide et sans usage — suppression pure, pas de migration.
-- -------------------------------------------------------------------
DROP TABLE IF EXISTS `police_cuffed`;

-- -------------------------------------------------------------------
-- police_custody / police_prison — sujet + officier tous deux résolus
-- en ligne au moment de l'écriture (module/police/server/prison.lua)
-- -------------------------------------------------------------------

ALTER TABLE `police_custody` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
ALTER TABLE `police_custody` ADD COLUMN `officer_character_id` INT NULL AFTER `officer_id`;
UPDATE `police_custody` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
UPDATE `police_custody` t JOIN `players` p ON p.identifier = t.officer_id AND p.slot = 1
    SET t.officer_character_id = p.`boutique-id`;

ALTER TABLE `police_prison` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
ALTER TABLE `police_prison` ADD COLUMN `officer_character_id` INT NULL AFTER `officer_id`;
UPDATE `police_prison` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
UPDATE `police_prison` t JOIN `players` p ON p.identifier = t.officer_id AND p.slot = 1
    SET t.officer_character_id = p.`boutique-id`;

-- -------------------------------------------------------------------
-- mdt_custody / mdt_criminal_records / mdt_fines / mdt_warrants —
-- sujet potentiellement hors-ligne (data.identifier client), officier
-- toujours en ligne (module/mdt/server/main.lua)
-- -------------------------------------------------------------------

ALTER TABLE `mdt_custody` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
ALTER TABLE `mdt_custody` ADD COLUMN `officer_character_id` INT NULL AFTER `officer_identifier`;
UPDATE `mdt_custody` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
UPDATE `mdt_custody` t JOIN `players` p ON p.identifier = t.officer_identifier AND p.slot = 1
    SET t.officer_character_id = p.`boutique-id`;

ALTER TABLE `mdt_criminal_records` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
ALTER TABLE `mdt_criminal_records` ADD COLUMN `officer_character_id` INT NULL AFTER `officer_identifier`;
UPDATE `mdt_criminal_records` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
UPDATE `mdt_criminal_records` t JOIN `players` p ON p.identifier = t.officer_identifier AND p.slot = 1
    SET t.officer_character_id = p.`boutique-id`;

ALTER TABLE `mdt_fines` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
ALTER TABLE `mdt_fines` ADD COLUMN `officer_character_id` INT NULL AFTER `officer_identifier`;
UPDATE `mdt_fines` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
UPDATE `mdt_fines` t JOIN `players` p ON p.identifier = t.officer_identifier AND p.slot = 1
    SET t.officer_character_id = p.`boutique-id`;

-- mdt_warrants.identifier est nullable (avis "individu non identifié") ;
-- character_id reste nullable aussi, pas de contrainte NOT NULL ajoutée.
ALTER TABLE `mdt_warrants` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
ALTER TABLE `mdt_warrants` ADD COLUMN `author_character_id` INT NULL AFTER `author_identifier`;
UPDATE `mdt_warrants` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
UPDATE `mdt_warrants` t JOIN `players` p ON p.identifier = t.author_identifier AND p.slot = 1
    SET t.author_character_id = p.`boutique-id`;

-- -------------------------------------------------------------------
-- mdt_med_records — rôle unique (patient), module/samu/server/mdt_medical.lua
-- -------------------------------------------------------------------

ALTER TABLE `mdt_med_records` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `mdt_med_records` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
ALTER TABLE `mdt_med_records` DROP INDEX `uniq_patient`;
ALTER TABLE `mdt_med_records` ADD UNIQUE KEY `uniq_patient` (`character_id`);

-- -------------------------------------------------------------------
-- bankaccounts — rôle unique (owner), mais devient VRAIMENT per-personnage
-- (plus seulement pour la cascade) : le menu banque et les 3 exports
-- lb-phone (getBankBalanceByIdentifier / addBankMoneyByIdentifier /
-- removeBankMoneyByIdentifier / addBankMoneyOffline, module/bank/sv_bank.lua)
-- matchent désormais sur character_id, résolu via
-- LSLegacy.ResolveCharacterIdSync (personnage en ligne, sinon repli slot 1).
-- -------------------------------------------------------------------

ALTER TABLE `bankaccounts` ADD COLUMN `character_id` INT NULL AFTER `owner`;
UPDATE `bankaccounts` t JOIN `players` p ON p.identifier = t.owner AND p.slot = 1
    SET t.character_id = p.`boutique-id`;

-- -------------------------------------------------------------------
-- Groupe B — re-scope uniquement, PAS de cascade-delete (preuves, comme
-- police_blood_traces/police_crime_scenes au Lot 1)
-- -------------------------------------------------------------------

ALTER TABLE `police_dna` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
ALTER TABLE `police_dna` ADD COLUMN `collected_by_character_id` INT NULL AFTER `collected_by`;
UPDATE `police_dna` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
UPDATE `police_dna` t JOIN `players` p ON p.identifier = t.collected_by AND p.slot = 1
    SET t.collected_by_character_id = p.`boutique-id`;

ALTER TABLE `police_fingerprints` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
ALTER TABLE `police_fingerprints` ADD COLUMN `collected_by_character_id` INT NULL AFTER `collected_by`;
UPDATE `police_fingerprints` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;
UPDATE `police_fingerprints` t JOIN `players` p ON p.identifier = t.collected_by AND p.slot = 1
    SET t.collected_by_character_id = p.`boutique-id`;

ALTER TABLE `police_callout_agents` ADD COLUMN `character_id` INT NULL AFTER `identifier`;
UPDATE `police_callout_agents` t JOIN `players` p ON p.identifier = t.identifier AND p.slot = 1
    SET t.character_id = p.`boutique-id`;

-- -------------------------------------------------------------------
-- Hors périmètre de ce lot (reporté) :
--   mdt_agent_meta (PK=identifier, nécessite une restructuration de la PK
--   + faire remonter character_id jusqu'au JS du MDT — regroupée avec
--   mdt_agent_career/assignments/commendations/skills/mdt_weapon_persons/
--   mdt_training_signups déjà reportées au Lot 1, futur lot "fiche agent
--   MDT + JS") ;
--   fourriere (owner recopié depuis owned_vehicles.owner, dépend donc de
--   la migration de owned_vehicles — reportée au Lot 3 avec les véhicules).
-- -------------------------------------------------------------------
