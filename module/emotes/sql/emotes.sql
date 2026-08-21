-- =====================================================================
--  MODULE EMOTES — Schéma SQL
--  Table aussi créée automatiquement au démarrage de la ressource
--  (voir module/emotes/sv_emotes.lua). Ce fichier sert de référence
--  et permet un import manuel.
-- =====================================================================

CREATE TABLE IF NOT EXISTS `emotes_favorites` (
    `character_id` INT(11)     NOT NULL,
    `emote_key`    VARCHAR(80) NOT NULL,
    PRIMARY KEY (`character_id`, `emote_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
