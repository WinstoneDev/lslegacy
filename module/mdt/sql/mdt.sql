-- =============================================================
--  MDT — Mobile Data Terminal (générique multi-jobs)
--  Framework : LSLegacy (FiveM / GTA V)
--  Premier département implémenté : Police
--
--  Toutes les tables portent une colonne `department` afin de
--  rester réutilisables par n'importe quel futur job (EMS, etc.).
--
--  Ces tables sont AUSSI créées automatiquement au démarrage par
--  module/mdt/server/main.lua (CREATE TABLE IF NOT EXISTS).
--  Ce fichier sert de référence / import manuel.
--
--  Les citoyens proviennent de la table `players` existante
--  (characterInfos) ; les véhicules de `persistent_vehicles`.
--  On ne duplique donc PAS ces données ici.
--
--  Compatible : MySQL 5.7+ / MariaDB 10.3+
-- =============================================================

SET NAMES utf8mb4;

-- -------------------------------------------------------------
--  mdt_criminal_records — Casier judiciaire / antécédents
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_criminal_records` (
    `id`                 INT(11)      NOT NULL AUTO_INCREMENT,
    `department`         VARCHAR(50)  NOT NULL DEFAULT 'police',
    `identifier`         VARCHAR(60)  NOT NULL,            -- citoyen concerné (license:xxx)
    `citizen_name`       VARCHAR(100) NOT NULL DEFAULT '', -- snapshot Prénom NOM
    `charge`             VARCHAR(255) NOT NULL DEFAULT '', -- chef d'accusation / infraction
    `description`        TEXT                  DEFAULT NULL,
    `officer_identifier` VARCHAR(60)  NOT NULL DEFAULT '',
    `officer_name`       VARCHAR(100) NOT NULL DEFAULT '',
    `created_at`         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_mdt_records_identifier` (`identifier`),
    KEY `idx_mdt_records_department` (`department`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  mdt_fines — Amendes
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_fines` (
    `id`                 INT(11)      NOT NULL AUTO_INCREMENT,
    `department`         VARCHAR(50)  NOT NULL DEFAULT 'police',
    `identifier`         VARCHAR(60)  NOT NULL,
    `citizen_name`       VARCHAR(100) NOT NULL DEFAULT '',
    `amount`             INT(11)      NOT NULL DEFAULT 0,
    `reason`             VARCHAR(255) NOT NULL DEFAULT '',
    `plate`              VARCHAR(12)           DEFAULT NULL,    -- véhicule lié (optionnel) → historique infractions
    `officer_identifier` VARCHAR(60)  NOT NULL DEFAULT '',
    `officer_name`       VARCHAR(100) NOT NULL DEFAULT '',
    `paid`               TINYINT(1)   NOT NULL DEFAULT 0,
    `created_at`         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_mdt_fines_identifier` (`identifier`),
    KEY `idx_mdt_fines_plate` (`plate`),
    KEY `idx_mdt_fines_department` (`department`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  mdt_intervention_reports — Rapports d'intervention
--  Le compte rendu rédigé par un agent après une intervention.
--  type  : intervention | maincourante | accident | judiciaire
--  joint : intervention menée conjointement police / gendarmerie
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_intervention_reports` (
    `id`                INT(11)      NOT NULL AUTO_INCREMENT,
    `department`        VARCHAR(50)  NOT NULL DEFAULT 'police',
    `type`              VARCHAR(30)  NOT NULL DEFAULT 'intervention',
    `content`           LONGTEXT              DEFAULT NULL,
    `agents`            LONGTEXT     NOT NULL DEFAULT '[]',   -- JSON ["Nom", …]
    `involved`          LONGTEXT     NOT NULL DEFAULT '[]',   -- JSON [{name,role}]
    `joint`             TINYINT(1)   NOT NULL DEFAULT 0,
    `author_identifier` VARCHAR(60)  NOT NULL DEFAULT '',
    `author_name`       VARCHAR(100) NOT NULL DEFAULT '',
    `created_at`        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_mir_dep_date` (`department`, `created_at`),
    KEY `idx_mir_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  mdt_case_links — Éléments rattachés à une enquête
--  Seule la RÉFÉRENCE est stockée ; le libellé est résolu à la
--  lecture par jointure, jamais recopié.
--    kind = 'report'  → ref = mdt_intervention_reports.id
--    kind = 'vehicle' → ref = plaque d'immatriculation
--    kind = 'person'  → ref = identifier du citoyen
--  Les preuves et les armes passent par leurs tables dédiées
--  (mdt_report_evidence, mdt_weapon_reports).
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_case_links` (
    `id`             INT(11)      NOT NULL AUTO_INCREMENT,
    `case_id`        INT(11)      NOT NULL,          -- mdt_reports.id
    `kind`           VARCHAR(20)  NOT NULL,
    `ref`            VARCHAR(60)  NOT NULL,
    `note`           VARCHAR(120)          DEFAULT NULL,  -- qualité / précision
    `linked_by`      VARCHAR(60)  NOT NULL DEFAULT '',
    `linked_by_name` VARCHAR(100) NOT NULL DEFAULT '',
    `created_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_mcl` (`case_id`, `kind`, `ref`),
    KEY `idx_mcl_case` (`case_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  mdt_report_links — Armes et véhicules associés à un RAPPORT
--  D'INTERVENTION (distinct de mdt_case_links, qui rattache des
--  éléments à une ENQUÊTE). Même principe : seule la référence
--  est stockée.
--    kind = 'weapon'  → ref = mdt_weapons.id
--    kind = 'vehicle' → ref = plaque d'immatriculation
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_report_links` (
    `id`             INT(11)      NOT NULL AUTO_INCREMENT,
    `report_id`      INT(11)      NOT NULL,          -- mdt_intervention_reports.id
    `kind`           VARCHAR(20)  NOT NULL,
    `ref`            VARCHAR(60)  NOT NULL,
    `linked_by`      VARCHAR(60)  NOT NULL DEFAULT '',
    `linked_by_name` VARCHAR(100) NOT NULL DEFAULT '',
    `created_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_mrl` (`report_id`, `kind`, `ref`),
    KEY `idx_mrl_report` (`report_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  mdt_reports — Enquêtes (dossiers d'instruction)
--  Créée avec un titre et une description ; tout le reste s'y
--  rattache ensuite via mdt_case_links et les tables de liaison.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_reports` (
    `id`                 INT(11)      NOT NULL AUTO_INCREMENT,
    `department`         VARCHAR(50)  NOT NULL DEFAULT 'police',
    `type`               VARCHAR(30)  NOT NULL DEFAULT 'intervention',
    `title`              VARCHAR(255) NOT NULL DEFAULT '',
    `content`            LONGTEXT              DEFAULT NULL,   -- corps du rapport
    `involved`           LONGTEXT     NOT NULL DEFAULT '[]',   -- JSON [{identifier,name,role}]
    `author_identifier`  VARCHAR(60)  NOT NULL DEFAULT '',
    `author_name`        VARCHAR(100) NOT NULL DEFAULT '',
    `created_at`         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_mdt_reports_dep_type` (`department`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  mdt_warrants — Avis de recherche
--  danger_level : 1 (faible) | 2 (modéré) | 3 (élevé)
--  status       : active | closed
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_warrants` (
    `id`                 INT(11)      NOT NULL AUTO_INCREMENT,
    `department`         VARCHAR(50)  NOT NULL DEFAULT 'police',
    `identifier`         VARCHAR(60)           DEFAULT NULL,   -- citoyen recherché (peut être inconnu)
    `citizen_name`       VARCHAR(100) NOT NULL DEFAULT '',
    `reason`             TEXT                  DEFAULT NULL,
    `danger_level`       INT(11)      NOT NULL DEFAULT 1,   -- INT et pas TINYINT(1) : ce dernier est relu comme booléen
    `status`             VARCHAR(20)  NOT NULL DEFAULT 'active',
    `author_identifier`  VARCHAR(60)  NOT NULL DEFAULT '',
    `author_name`        VARCHAR(100) NOT NULL DEFAULT '',
    `created_at`         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_mdt_warrants_dep_status` (`department`, `status`),
    KEY `idx_mdt_warrants_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  mdt_custody — Gardes à vue
--  La MISE en GAV reste un système physique à développer (visuel),
--  mais la table est prête : historique + procès-verbal persistants.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_custody` (
    `id`                 INT(11)      NOT NULL AUTO_INCREMENT,
    `department`         VARCHAR(50)  NOT NULL DEFAULT 'police',
    `identifier`         VARCHAR(60)  NOT NULL,
    `citizen_name`       VARCHAR(100) NOT NULL DEFAULT '',
    `reason`             TEXT                  DEFAULT NULL,    -- motif
    `duration`           INT(11)      NOT NULL DEFAULT 0,       -- durée en minutes
    `pv`                 LONGTEXT              DEFAULT NULL,     -- procès-verbal
    `officer_identifier` VARCHAR(60)  NOT NULL DEFAULT '',
    `officer_name`       VARCHAR(100) NOT NULL DEFAULT '',
    `started_at`         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ends_at`            TIMESTAMP    NULL     DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_mdt_custody_identifier` (`identifier`),
    KEY `idx_mdt_custody_department` (`department`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  mdt_evidence — Preuves d'enquête
--  type : empreinte | adn | sang | scene
--  Collecte/analyse = systèmes physiques à développer (visuel),
--  mais TOUTE preuve doit être persistée → table prête.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_evidence` (
    `id`                 INT(11)      NOT NULL AUTO_INCREMENT,
    `department`         VARCHAR(50)  NOT NULL DEFAULT 'police',
    `case_id`            INT(11)               DEFAULT NULL,   -- lien vers mdt_reports.id (dossier judiciaire)
    `type`               VARCHAR(30)  NOT NULL DEFAULT 'empreinte',
    `label`              VARCHAR(255) NOT NULL DEFAULT '',
    `data`               LONGTEXT     NOT NULL DEFAULT '{}',   -- JSON (résultats, correspondance…)
    `status`             VARCHAR(30)  NOT NULL DEFAULT 'collected', -- collected | analyzed | matched
    `identifier`         VARCHAR(60)           DEFAULT NULL,   -- citoyen lié si correspondance
    `collected_by`       VARCHAR(60)  NOT NULL DEFAULT '',
    `collected_by_name`  VARCHAR(100) NOT NULL DEFAULT '',
    `created_at`         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_mdt_evidence_department` (`department`),
    KEY `idx_mdt_evidence_case` (`case_id`),
    KEY `idx_mdt_evidence_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  mdt_weapons — Registre des armes (géré manuellement par la police)
--  category : firearm (num. de série unique) | melee (pas de série)
--  Une arme saisie = seized=1 (liste des pièces à conviction).
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_weapons` (
    `id`                 INT(11)      NOT NULL AUTO_INCREMENT,
    `department`         VARCHAR(50)  NOT NULL DEFAULT 'police',
    `serial_number`      VARCHAR(20)           DEFAULT NULL,   -- NULL pour les armes de mêlée
    `category`           VARCHAR(20)  NOT NULL DEFAULT 'firearm', -- firearm | melee
    `model`              VARCHAR(120) NOT NULL DEFAULT '',      -- désignation (ex: Glock 17)
    `notes`              TEXT                  DEFAULT NULL,
    `status`             VARCHAR(20)  NOT NULL DEFAULT 'registered', -- registered | seized | destroyed
    `seized`             TINYINT(1)   NOT NULL DEFAULT 0,
    `seized_case_id`     INT(11)               DEFAULT NULL,   -- dossier de saisie (mdt_reports.id)
    `seized_by`          VARCHAR(60)           DEFAULT NULL,
    `seized_by_name`     VARCHAR(100)          DEFAULT NULL,
    `seized_at`          TIMESTAMP    NULL     DEFAULT NULL,
    `registered_by`      VARCHAR(60)  NOT NULL DEFAULT '',
    `registered_by_name` VARCHAR(100) NOT NULL DEFAULT '',
    `created_at`         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_mdt_weapons_serial` (`serial_number`),   -- plusieurs NULL autorisés (mêlée)
    KEY `idx_mdt_weapons_department` (`department`),
    KEY `idx_mdt_weapons_seized` (`seized`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  mdt_weapon_persons — Liaison Armes ↔ Personnes (N-N)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_weapon_persons` (
    `id`            INT(11)      NOT NULL AUTO_INCREMENT,
    `weapon_id`     INT(11)      NOT NULL,
    `identifier`    VARCHAR(60)  NOT NULL,
    `citizen_name`  VARCHAR(100) NOT NULL DEFAULT '',
    `relation`      VARCHAR(40)  NOT NULL DEFAULT 'lie',  -- proprietaire|detenteur|suspect|temoin|lie
    `linked_by`     VARCHAR(60)  NOT NULL DEFAULT '',
    `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_mwp` (`weapon_id`, `identifier`),
    KEY `idx_mwp_weapon` (`weapon_id`),
    KEY `idx_mwp_person` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  mdt_weapon_reports — Liaison Armes ↔ Dossiers / Enquêtes (N-N)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_weapon_reports` (
    `id`            INT(11)     NOT NULL AUTO_INCREMENT,
    `weapon_id`     INT(11)     NOT NULL,
    `report_id`     INT(11)     NOT NULL,
    `linked_by`     VARCHAR(60) NOT NULL DEFAULT '',
    `created_at`    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_mwr` (`weapon_id`, `report_id`),
    KEY `idx_mwr_weapon` (`weapon_id`),
    KEY `idx_mwr_report` (`report_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  mdt_laws — Code juridique (lois / infractions)
--  jail = texte libre (ex : "Perpétuité", "5 ans") pour supporter
--  les peines non numériques de l'exemple.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_laws` (
    `id`              INT(11)      NOT NULL AUTO_INCREMENT,
    `department`      VARCHAR(50)  NOT NULL DEFAULT 'police',
    `article`         VARCHAR(40)  NOT NULL DEFAULT '',
    `name`            VARCHAR(255) NOT NULL DEFAULT '',
    `description`     TEXT                  DEFAULT NULL,
    `fine`            INT(11)      NOT NULL DEFAULT 0,
    `jail`            VARCHAR(120) NOT NULL DEFAULT '',   -- durée de peine (texte)
    `category`        VARCHAR(60)  NOT NULL DEFAULT '',
    `created_by`      VARCHAR(60)  NOT NULL DEFAULT '',
    `created_by_name` VARCHAR(100) NOT NULL DEFAULT '',
    `created_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_mdt_laws_department` (`department`),
    KEY `idx_mdt_laws_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  mdt_trainings — Formations / stages internes
--  scheduled_at = texte ISO (YYYY-MM-DDTHH:MM) → tri chronologique
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_trainings` (
    `id`              INT(11)      NOT NULL AUTO_INCREMENT,
    `department`      VARCHAR(50)  NOT NULL DEFAULT 'police',
    `name`            VARCHAR(255) NOT NULL DEFAULT '',
    `scheduled_at`    VARCHAR(40)  NOT NULL DEFAULT '',
    `description`     TEXT                  DEFAULT NULL,
    `max_slots`       INT(11)      NOT NULL DEFAULT 0,
    `created_by`      VARCHAR(60)  NOT NULL DEFAULT '',
    `created_by_name` VARCHAR(100) NOT NULL DEFAULT '',
    `created_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_mdt_trainings_department` (`department`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------------
--  mdt_training_signups — Inscriptions (1 par agent par formation)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mdt_training_signups` (
    `id`            INT(11)      NOT NULL AUTO_INCREMENT,
    `training_id`   INT(11)      NOT NULL,
    `identifier`    VARCHAR(60)  NOT NULL,
    `citizen_name`  VARCHAR(100) NOT NULL DEFAULT '',
    `grade`         INT(11)      NOT NULL DEFAULT 0,
    `grade_label`   VARCHAR(60)  NOT NULL DEFAULT '',
    `created_at`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_mts` (`training_id`, `identifier`),
    KEY `idx_mts_training` (`training_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
--  FIN DU FICHIER
-- =============================================================
