-- ════════════════════════════════════════════════════════════════════
--  MDT MÉDICAL (SAMU) — Schéma
--
--  Toutes les tables sont préfixées `mdt_med_` : aucun recouvrement avec
--  les 12 tables `mdt_*` du MDT police, qui ne sont ni lues ni écrites
--  par ce module.
--
--  Le patient est identifié par `identifier` (identifiant LSLegacy du
--  joueur), la même clé que le reste du framework — le dossier médical
--  suit donc le personnage, mais reste invisible du MDT police.
-- ════════════════════════════════════════════════════════════════════

-- ── Dossier médical : une fiche unique par patient ──────────────────
CREATE TABLE IF NOT EXISTS mdt_med_records (
    id            INT(11)      NOT NULL AUTO_INCREMENT,
    identifier    VARCHAR(60)  NOT NULL,
    blood_group   VARCHAR(8)            DEFAULT NULL,
    allergies     TEXT                  DEFAULT NULL,
    antecedents   TEXT                  DEFAULT NULL,
    ongoing       TEXT                  DEFAULT NULL, -- traitement(s) en cours, texte libre
    notes         TEXT                  DEFAULT NULL,
    dnr           TINYINT(1)   NOT NULL DEFAULT 0,    -- "ne pas réanimer"
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by    VARCHAR(100)          DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_patient (identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Entrées du dossier : consultations, actes, hospitalisations ─────
CREATE TABLE IF NOT EXISTS mdt_med_entries (
    id                INT(11)      NOT NULL AUTO_INCREMENT,
    identifier        VARCHAR(60)  NOT NULL, -- patient
    type              VARCHAR(40)  NOT NULL DEFAULT 'consultation',
    title             VARCHAR(150) NOT NULL,
    content           TEXT                  DEFAULT NULL,
    author_identifier VARCHAR(60)           DEFAULT NULL,
    author_name       VARCHAR(100)          DEFAULT NULL,
    created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_patient (identifier),
    KEY idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Traitements / prescriptions ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS mdt_med_treatments (
    id                    INT(11)      NOT NULL AUTO_INCREMENT,
    identifier            VARCHAR(60)  NOT NULL, -- patient
    code                  VARCHAR(30)           DEFAULT NULL, -- code du catalogue (Config.Medical.Treatments)
    label                 VARCHAR(150) NOT NULL,
    dosage                VARCHAR(100)          DEFAULT NULL,
    duration              VARCHAR(100)          DEFAULT NULL,
    notes                 TEXT                  DEFAULT NULL,
    status                VARCHAR(20)  NOT NULL DEFAULT 'actif', -- actif | termine | annule
    prescriber_identifier VARCHAR(60)           DEFAULT NULL,
    prescriber_name       VARCHAR(100)          DEFAULT NULL,
    created_at            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at              DATETIME              DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_patient (identifier),
    KEY idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Appels (dispatch) ───────────────────────────────────────────────
-- Alimentée par les appels patient relayés depuis lslegacy:injury:callEMS
-- (jusqu'ici purement éphémères, non historisés).
CREATE TABLE IF NOT EXISTS mdt_med_calls (
    id                  INT(11)      NOT NULL AUTO_INCREMENT,
    caller_identifier   VARCHAR(60)           DEFAULT NULL,
    caller_name         VARCHAR(100)          DEFAULT NULL,
    x                   FLOAT        NOT NULL DEFAULT 0,
    y                   FLOAT        NOT NULL DEFAULT 0,
    z                   FLOAT        NOT NULL DEFAULT 0,
    reason              VARCHAR(150)          DEFAULT NULL,
    status              VARCHAR(20)  NOT NULL DEFAULT 'pending', -- pending | assigned | done | cancelled
    assigned_identifier VARCHAR(60)           DEFAULT NULL,
    assigned_name       VARCHAR(100)          DEFAULT NULL,
    created_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at           DATETIME              DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_status (status),
    KEY idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Documents internes ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mdt_med_docs (
    id                INT(11)      NOT NULL AUTO_INCREMENT,
    category          VARCHAR(60)  NOT NULL DEFAULT 'Général',
    title             VARCHAR(150) NOT NULL,
    content           TEXT                  DEFAULT NULL,
    author_identifier VARCHAR(60)           DEFAULT NULL,
    author_name       VARCHAR(100)          DEFAULT NULL,
    pinned            TINYINT(1)   NOT NULL DEFAULT 0,
    created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_category (category),
    KEY idx_pinned (pinned)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Petits mots des cheffes d'équipe (encart du dashboard) ──────────
CREATE TABLE IF NOT EXISTS mdt_med_board (
    id                INT(11)      NOT NULL AUTO_INCREMENT,
    author_identifier VARCHAR(60)           DEFAULT NULL,
    author_name       VARCHAR(100)          DEFAULT NULL,
    author_grade      VARCHAR(100)          DEFAULT NULL,
    message           TEXT         NOT NULL,
    active            TINYINT(1)   NOT NULL DEFAULT 1,
    created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_active (active, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
