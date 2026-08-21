-- =====================================================================
--  MODULE ATELIER — Schéma SQL
--  Ces tables sont aussi créées automatiquement au démarrage de la
--  ressource (voir module/atelier/server/main.lua, vehicles.lua et
--  billing.lua). Ce fichier sert de référence et permet un import manuel.
-- =====================================================================

-- -------------------------------------------------------------
--  atelier_agents — Employés par entreprise (composite character_id+company)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `atelier_agents` (
    `id`           INT          NOT NULL AUTO_INCREMENT,
    `character_id` INT          NOT NULL,
    `company`      VARCHAR(20)  NOT NULL,
    `identifier`   VARCHAR(60)  NOT NULL,
    `name`         VARCHAR(100) NOT NULL DEFAULT '',
    `on_duty`      TINYINT(1)   NOT NULL DEFAULT 0,
    `duty_since`   DATETIME              DEFAULT NULL,
    `last_seen`    DATETIME              DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_atelier_agents_char_company` (`character_id`, `company`),
    KEY `idx_atelier_agents_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  atelier_vehicles — État des composants par plaque (carrosserie, etc.)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `atelier_vehicles` (
    `plate`       VARCHAR(12) NOT NULL,
    `components`  LONGTEXT    NOT NULL DEFAULT '{}',
    `maintenance` LONGTEXT    NOT NULL DEFAULT '{}',
    `updated_at`  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  atelier_invoices — Factures émises par une entreprise
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `atelier_invoices` (
    `id`                     INT          NOT NULL AUTO_INCREMENT,
    `company`                VARCHAR(20)  NOT NULL,
    `plate`                  VARCHAR(12)  NOT NULL,
    `customer_character_id`  INT                   DEFAULT NULL,
    `customer_name`          VARCHAR(100) NOT NULL DEFAULT '',
    `mecano_character_id`    INT                   DEFAULT NULL,
    `mecano_name`            VARCHAR(100) NOT NULL DEFAULT '',
    `total`                  INT          NOT NULL DEFAULT 0,
    `status`                 VARCHAR(20)  NOT NULL DEFAULT 'open',
    `created_at`             DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `paid_at`                DATETIME              DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_atelier_invoices_plate` (`plate`),
    KEY `idx_atelier_invoices_customer` (`customer_character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  atelier_invoice_lines — Lignes d'une facture (pièces/main d'œuvre)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `atelier_invoice_lines` (
    `id`         INT          NOT NULL AUTO_INCREMENT,
    `invoice_id` INT          NOT NULL,
    `label`      VARCHAR(150) NOT NULL,
    `amount`     INT          NOT NULL DEFAULT 0,
    `part_item`  VARCHAR(60)           DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_atelier_invoice_lines_invoice` (`invoice_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
