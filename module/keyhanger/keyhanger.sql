-- =====================================================================
--  UTILITY KEYHANGER — Schéma SQL
--  La table est aussi créée automatiquement au démarrage de la ressource
--  (voir module/keyhanger/server/main.lua). Ce fichier sert de référence
--  et permet un import manuel.
--
--  Le CONTENU des porte-clés (les clés déposées) n'est PAS stocké ici :
--  il utilise le système DataStore existant (table `datastore`, name =
--  'keyhanger_<id>', type = 'trunk'), exactement comme les coffres.
-- =====================================================================

CREATE TABLE IF NOT EXISTS `keyhanger_boards` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `label`      VARCHAR(64)  NOT NULL DEFAULT 'Porte-clés',   -- nom affiché
    `board`      VARCHAR(32)  NOT NULL DEFAULT 'board_wood',   -- modèle de support (config)
    `owner_type` VARCHAR(16)  NOT NULL DEFAULT 'personal',     -- personal|job|faction|shared|public
    `owner_id`   VARCHAR(64)  NOT NULL DEFAULT '',             -- identifier / nom job / nom faction
    `owner_name` VARCHAR(64)  NOT NULL DEFAULT '',             -- nom lisible du propriétaire
    `coords`     LONGTEXT     NOT NULL,                        -- {"x":..,"y":..,"z":..}
    `heading`    FLOAT        NOT NULL DEFAULT 0,              -- orientation murale
    `access`     LONGTEXT     NOT NULL DEFAULT '{}',           -- { identifier = "Nom", ... } (partages)
    `created_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
