-- =============================================================
--  winframe — Base de données complète
--  Framework : LSLegacy (FiveM / GTA V)
--  Généré depuis l'analyse complète de la repo
--  Compatible : MySQL 5.7+ / MariaDB 10.3+
-- =============================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";
SET NAMES utf8mb4;

-- -------------------------------------------------------------
--  TABLE : players
--  Stocke les données persistantes de chaque joueur.
--  Créée/chargée dans : server/player/player.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `players` (
    `boutique-id`             INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier`     VARCHAR(60)  NOT NULL DEFAULT '',
    `discordId`      VARCHAR(60)  NOT NULL DEFAULT 'Aucun discord',
    `token`          VARCHAR(100) NOT NULL DEFAULT '',

    -- Infos RP du personnage : {NDF, Prenom, DDN, Sexe, Taille, LDN}
    `characterInfos` LONGTEXT     NOT NULL DEFAULT '{"NDF":"Aucun","Prenom":"Aucun","DDN":"19/04/1999","Sexe":"Aucun","Taille":180,"LDN":"Aucun"}',

    -- Position de sauvegarde : {x, y, z}
    `coords`         LONGTEXT     NOT NULL DEFAULT '{"x":0,"y":0,"z":0}',

    -- Jauges vitales : {hunger, thirst, stamina}
    `status`         LONGTEXT     NOT NULL DEFAULT '{"hunger":100,"thirst":100,"stamina":100}',

    -- Inventaire : tableau d'items [{name, label, count, ...}]
    `inventory`      LONGTEXT     NOT NULL DEFAULT '[]',

    -- Données de skin (PedFeatures, PedComponents, etc.)
    `skin`           LONGTEXT              DEFAULT NULL,

    -- Argent : {cash, dirty}
    `money`          LONGTEXT     NOT NULL DEFAULT '{"cash":1500,"dirty":0}',

    -- Santé brute GTA (100–200 = 0–100 HP en jeu)
    `health`         INT(11)      NOT NULL DEFAULT 200,

    -- Groupe staff (ex. "user", "moderateur", "admin", "superadmin")
    `group`          VARCHAR(50)  NOT NULL DEFAULT 'user',

    -- Métier actif et grade
    `job`            VARCHAR(50)  NOT NULL DEFAULT 'unemployed',
    `job_grade`      INT(11)      NOT NULL DEFAULT 0,

    -- Faction et grade
    `faction`        VARCHAR(50)  NOT NULL DEFAULT 'unemployed',
    `faction_grade`  INT(11)      NOT NULL DEFAULT 0,

    -- Compétences RP : {endurance, tir, force, furtivite, pilotage, conduite, apnee}
    `skills`         LONGTEXT     NOT NULL DEFAULT '{}',
    `boutique-credits`      INT(50)      NOT NULL DEFAULT 0,

    PRIMARY KEY (`boutique-id`),
    UNIQUE KEY `uq_players_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : banlist
--  Gère les bannissements temporaires et permanents.
--  Créée/chargée dans : server/anticheat.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `banlist` (
    `idban`      INT(11)      NOT NULL AUTO_INCREMENT,

    -- Identifiants du joueur banni
    `token`      VARCHAR(255)          DEFAULT NULL,
    `license`    VARCHAR(60)           DEFAULT 'Aucun',
    `identifier` VARCHAR(60)           DEFAULT 'Aucun',   -- steam:xxxx
    `liveid`     VARCHAR(60)           DEFAULT 'Aucun',
    `xbox`       VARCHAR(60)           DEFAULT 'Aucun',
    `discord`    VARCHAR(60)           DEFAULT 'Aucun',
    `ip`         VARCHAR(45)           DEFAULT 'Aucun',

    -- Informations du ban
    `moderator`  VARCHAR(100)          DEFAULT 'Inconnu',
    `reason`     TEXT                  DEFAULT NULL,

    -- Date du ban encodée en JSON : {year, month, day, hour, min, sec}
    `expiration` LONGTEXT              DEFAULT NULL,

    -- Durée en heures (999000 = permanent en pratique)
    `hourban`    INT(11)      NOT NULL DEFAULT 0,

    -- 1 = permanent, 0 = temporaire
    `permanent`  TINYINT(1)   NOT NULL DEFAULT 0,

    PRIMARY KEY (`idban`),
    KEY `idx_banlist_license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : bankaccounts
--  Comptes bancaires des joueurs (système Maze Bank).
--  Créée/chargée dans : module/bank/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `bankaccounts` (
    `id`           INT(11)       NOT NULL AUTO_INCREMENT,

    -- Identifiant du propriétaire (license:xxxx)
    `owner`        VARCHAR(60)   NOT NULL DEFAULT '',

    -- Nom affiché : Prenom + NDF du personnage
    `owner_name`   VARCHAR(100)  NOT NULL DEFAULT '',

    -- Numéro IBAN généré par LSLegacy.Bank.GenerateIBAN (préfixe "LSL")
    `iban`         VARCHAR(35)   NOT NULL DEFAULT '',

    -- Solde du compte
    `amountMoney`  FLOAT         NOT NULL DEFAULT 0,

    -- Historique des transactions : [{amount, type, message, date}]
    `transactions` LONGTEXT      NOT NULL DEFAULT '[]',

    -- 1 = compte courant (un seul par joueur), 0 = compte secondaire
    `courant`      TINYINT(1)    NOT NULL DEFAULT 0,

    -- Infos de la carte liée (null si aucune carte créée)
    -- {owner_name, card_number, card_pin, card_cvv, card_expiration_date, card_type, card_account, card_tier}
    `card_infos`   LONGTEXT               DEFAULT NULL,

    -- Identifiant du personnage (character_id, ajouté après coup, multichar)
    `character_id` INT(11)       NULL,

    -- Palier de compte : détermine plafonds/découvert/agios via bank_card_tiers.
    -- S'applique même sans carte physique créée.
    `card_tier`    VARCHAR(20)   NOT NULL DEFAULT 'standard',

    -- Prochaine échéance de cotisation carte (NULL = pas encore programmée)
    `next_billing_at` DATETIME  NULL,

    -- Cumul dépensé sur la période de plafond en cours (remise à zéro à
    -- ceiling_period_reset_at). Les plafonds sont cumulatifs sur la période,
    -- pas une limite par transaction.
    `payment_spent`    FLOAT     NOT NULL DEFAULT 0,
    `withdrawal_spent` FLOAT     NOT NULL DEFAULT 0,
    `transfer_spent`   FLOAT     NOT NULL DEFAULT 0,
    `ceiling_period_reset_at` DATETIME NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_bankaccounts_iban` (`iban`),
    KEY `idx_bankaccounts_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : bank_livrets
--  Livrets d'épargne (Livret A, LDDS, Compte à terme) rattachés
--  à un compte bancaire. Créée/chargée dans : module/bank/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `bank_livrets` (
    `id`                     INT(11)      NOT NULL AUTO_INCREMENT,
    `owner`                  VARCHAR(60)  NOT NULL DEFAULT '',
    `character_id`           INT(11)      NULL,
    `owner_name`             VARCHAR(100) NOT NULL DEFAULT '',
    `linked_account_id`      INT(11)      NOT NULL,
    `livret_type`            ENUM('livret_a','ldds','compte_terme') NOT NULL,
    `amountMoney`            FLOAT        NOT NULL DEFAULT 0,
    `opened_at`              DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `maturity_date`          DATETIME     NULL,
    `interest_rate_snapshot` FLOAT        NOT NULL DEFAULT 0,
    `transactions`           LONGTEXT     NOT NULL DEFAULT '[]',
    `status`                 ENUM('active','closed') NOT NULL DEFAULT 'active',
    PRIMARY KEY (`id`),
    KEY `idx_bank_livrets_owner` (`owner`),
    KEY `idx_bank_livrets_linked_account` (`linked_account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : bank_interest_rates
--  Taux d'intérêt par type de livret, éditables en direct par le
--  panneau admin de la banque. Créée/chargée dans : module/bank/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `bank_interest_rates` (
    `livret_type`                       VARCHAR(20) NOT NULL,
    `rate_percent`                      FLOAT       NOT NULL DEFAULT 0,
    `deposit_cap`                       FLOAT       NULL,
    `early_withdrawal_penalty_percent`  FLOAT       NULL,
    `min_term_days`                     INT(11)     NULL,
    `updated_by`                        VARCHAR(100) NULL,
    `updated_at`                        DATETIME     NULL,
    PRIMARY KEY (`livret_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : bank_card_tiers
--  Paliers de carte (Standard/Premier/Platinum) : coût, plafonds,
--  découvert autorisé, agios. Éditables en direct par le panneau
--  admin. Créée/chargée dans : module/bank/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `bank_card_tiers` (
    `tier`                   VARCHAR(20) NOT NULL,
    `cost_amount`            FLOAT       NOT NULL DEFAULT 0,
    `cost_period`            ENUM('weekly','monthly') NOT NULL DEFAULT 'weekly',
    `payment_ceiling`        FLOAT       NOT NULL DEFAULT 0,
    `withdrawal_ceiling`     FLOAT       NOT NULL DEFAULT 0,
    `transfer_ceiling`       FLOAT       NOT NULL DEFAULT 0,
    `overdraft_limit`        FLOAT       NOT NULL DEFAULT 0,
    `agios_rate_percent`     FLOAT       NOT NULL DEFAULT 0,
    `updated_by`             VARCHAR(100) NULL,
    `updated_at`             DATETIME     NULL,
    PRIMARY KEY (`tier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : persistent_vehicles
--  Véhicules persistants sauvegardés dans le monde.
--  Créée/chargée dans : module/persistent_vehicles/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `persistent_vehicles` (
    `id`            INT(11)      NOT NULL AUTO_INCREMENT,

    -- Plaque unique du véhicule (clé naturelle)
    `plate`         VARCHAR(10)  NOT NULL DEFAULT '',

    -- Hash du modèle GTA (INT signé 32 bits)
    `model`         INT(11)      NOT NULL DEFAULT 0,

    -- Position dans le monde : {x, y, z, h}
    `position`      LONGTEXT     NOT NULL DEFAULT '{"x":0,"y":0,"z":0,"h":0}',

    -- État du véhicule :
    -- {engine, body, tank, dirt, fuel, lock, windows, extras,
    --  tyreData, doorsBroken, visualDamage}
    `status`        LONGTEXT     NOT NULL DEFAULT '{"engine":1000,"body":1000,"tank":1000,"dirt":0,"fuel":50,"lock":1,"windows":{},"extras":{},"tyreData":{},"doorsBroken":{},"visualDamage":{}}',

    -- Tuning :
    -- {colorPrimary, colorSecondary, pearlColor, wheelColor, wheelType, windowTint}
    `tuning`        LONGTEXT     NOT NULL DEFAULT '{}',

    -- Plaque de la remorque attelée (null si aucune)
    `trailer_plate` VARCHAR(10)           DEFAULT NULL,

    -- State bags additionnels (usage futur)
    `state_bags`    LONGTEXT     NOT NULL DEFAULT '{}',

    -- Horodatage de la dernière sauvegarde (sert au cleanup)
    `last_seen_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
                                          ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_persistent_vehicles_plate` (`plate`),
    KEY `idx_persistent_vehicles_last_seen` (`last_seen_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : datastore
--  Stockages partagés (coffres, boutiques, garages, etc.).
--  Créée/chargée dans : server/datastore.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `datastore` (
    `id`        INT(11)      NOT NULL AUTO_INCREMENT,

    -- Catégorie du datastore (ex. "trunk", "shop", "garage")
    `type`      VARCHAR(50)  NOT NULL DEFAULT '',

    -- Identifiant unique du datastore (ex. "trunk_ABC123")
    `name`      VARCHAR(100) NOT NULL DEFAULT '',

    -- Contenu de l'inventaire : [{name, label, count, data?, uniqueId?}]
    `inventory` LONGTEXT     NOT NULL DEFAULT '[]',

    -- Argent propre stocké
    `money`     FLOAT        NOT NULL DEFAULT 0,

    -- Argent sale stocké
    `dirty`     FLOAT        NOT NULL DEFAULT 0,

    -- Poids maximal configuré (Config.VehicleTrunks, etc.)
    `weight`    FLOAT        NOT NULL DEFAULT 0,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_datastore_name_type` (`name`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : admin_warns
--  Historique des avertissements donnés par le staff.
--  Créée/chargée dans : module/adminmenu/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `admin_warns` (
    `id`                INT(11)      NOT NULL AUTO_INCREMENT,
    `player_identifier` VARCHAR(100) NOT NULL,
    `player_name`       VARCHAR(255)          DEFAULT NULL,
    `staff_identifier`  VARCHAR(100) NOT NULL,
    `staff_name`        VARCHAR(255)          DEFAULT NULL,
    `reason`            TEXT                  DEFAULT NULL,
    `created_at`        TIMESTAMP    NULL     DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- -------------------------------------------------------------
--  TABLE : support_tickets
--  Tickets d'aide ouverts par les joueurs (/report) et suivis par le staff.
--  Créée/chargée dans : module/adminmenu/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `support_tickets` (
    `id`                 INT(11) NOT NULL AUTO_INCREMENT,
    `player_id`          INT(11) NOT NULL,
    `player_name`        VARCHAR(255)                        DEFAULT NULL,
    `player_identifier`  VARCHAR(100)                        DEFAULT NULL,
    `subject`            TEXT                                DEFAULT NULL,

    -- open (nouveau) → taken (pris en charge) → closed (résolu)
    `status`             ENUM('open','taken','closed')       DEFAULT 'open',

    `assigned_to`        INT(11)                             DEFAULT NULL,
    `assigned_name`      VARCHAR(255)                        DEFAULT NULL,
    `created_at`         TIMESTAMP NULL                      DEFAULT CURRENT_TIMESTAMP,
    `closed_at`          TIMESTAMP NULL                      DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- -------------------------------------------------------------
--  TABLE : owned_vehicles
--  Registre d'immatriculation des véhicules achetés/possédés.
--  Créée/chargée dans : module/concessionnaire/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `owned_vehicles` (
    -- Identifiant du propriétaire (null = épave / non attribué)
    `owner`      VARCHAR(60) DEFAULT NULL,

    -- Plaque unique du véhicule (clé naturelle)
    `plate`      VARCHAR(12) NOT NULL,

    `type`       VARCHAR(20) DEFAULT 'car',

    -- Métier propriétaire si véhicule de service (ex. "police"), sinon NULL
    `job`        VARCHAR(20) DEFAULT NULL,

    -- 1 = rangé au garage, 0 = sur la voie publique / sorti
    `stored`     TINYINT(1)  DEFAULT 0,

    `garage`     VARCHAR(60) DEFAULT NULL,
    `bought_at`  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (`plate`),
    KEY `idx_owned_vehicles_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : concessionnaire_occasions
--  Annonces du marché de l'occasion (véhicules reposés en dépôt-vente).
--  Créée/chargée dans : module/concessionnaire/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `concessionnaire_occasions` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `model`      VARCHAR(60)  NOT NULL,
    `label`      VARCHAR(100) NOT NULL DEFAULT '',
    `price`      INT(11)      NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP    NULL     DEFAULT CURRENT_TIMESTAMP,

    -- Plaque/propriétaire d'origine (traçabilité de la reprise)
    `plate`      VARCHAR(12)           DEFAULT NULL,
    `owner`      VARCHAR(60)           DEFAULT NULL,

    -- Tuning/couleurs à réappliquer à la livraison
    `props`      LONGTEXT              DEFAULT NULL,

    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : fourriere
--  Véhicules mis en fourrière (saisie, infraction, épave).
--  Créée/chargée dans : module/fourriere/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `fourriere` (
    -- Plaque du véhicule saisi (clé naturelle)
    `plate`        VARCHAR(12)  NOT NULL,
    `owner`        VARCHAR(60)           DEFAULT NULL,
    `model`        BIGINT(20)            DEFAULT 0,
    `props`        LONGTEXT              DEFAULT NULL,
    `reason`       VARCHAR(255) NOT NULL DEFAULT '',

    -- Montant à payer pour récupérer le véhicule
    `fee`          INT(11)      NOT NULL DEFAULT 0,

    `officer`      VARCHAR(60)  NOT NULL DEFAULT '',
    `officer_name` VARCHAR(100) NOT NULL DEFAULT '',
    `impounded_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Date de sortie effective (null tant que non récupéré)
    `release_at`   TIMESTAMP    NULL     DEFAULT NULL,

    PRIMARY KEY (`plate`),
    KEY `idx_fourriere_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : interim_stations
--  Stations essence gérées par le métier Interim (remplissage manuel).
--  Créée/chargée dans : module/interim/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `interim_stations` (
    -- Identifiant de la station (clé de config, ex. "davis")
    `id`             VARCHAR(32) NOT NULL,
    `label`          VARCHAR(60) NOT NULL DEFAULT '',
    `last_filled_at` TIMESTAMP   NULL     DEFAULT NULL,
    `last_filled_by` VARCHAR(60)          DEFAULT NULL,
    `fuel_liters`    INT(11)     NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : farm_shop_stock
--  Stock du magasin de la ferme (achat/revente de denrées).
--  Créée/chargée dans : module/farm/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `farm_shop_stock` (
    `item`     VARCHAR(60) NOT NULL,
    `quantity` INT(11)     NOT NULL DEFAULT 0,
    PRIMARY KEY (`item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : gendarmerie_officers
--  Registre des agents du métier Gendarmerie (prise/fin de service).
--  Créée/chargée dans : module/gendarmerie/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `gendarmerie_officers` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60)  NOT NULL,
    `name`       VARCHAR(100) NOT NULL DEFAULT '',
    `unit`       VARCHAR(60)           DEFAULT NULL,
    `on_duty`    TINYINT(1)   NOT NULL DEFAULT 0,
    `duty_since` DATETIME              DEFAULT NULL,
    `last_seen`  DATETIME              DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_go_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : ltd_agents
--  Registre des employés du métier LTD (magasins de proximité).
--  Créée/chargée dans : module/ltd/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ltd_agents` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60)  NOT NULL,

    -- Magasin assigné (ex. "grapeseed", "groove"), null si non assigné
    `store_id`   VARCHAR(60)           DEFAULT NULL,

    `on_duty`    TINYINT(1)   NOT NULL DEFAULT 0,
    `duty_since` DATETIME              DEFAULT NULL,
    `last_seen`  DATETIME              DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_la_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : ltd_stock
--  Stock par magasin LTD (rayon + réserve).
--  Créée/chargée dans : module/ltd/server/stock.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ltd_stock` (
    `store_id`    VARCHAR(60) NOT NULL,
    `item`        VARCHAR(60) NOT NULL,
    `shelf_qty`   INT(11)     NOT NULL DEFAULT 0,
    `reserve_qty` INT(11)     NOT NULL DEFAULT 0,
    PRIMARY KEY (`store_id`, `item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : mecanicien_agents
--  Registre des employés du métier Mécanicien.
--  Créée/chargée dans : module/mecanicien/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mecanicien_agents` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60)  NOT NULL,
    `name`       VARCHAR(100) NOT NULL DEFAULT '',
    `on_duty`    TINYINT(1)   NOT NULL DEFAULT 0,
    `duty_since` DATETIME              DEFAULT NULL,
    `last_seen`  DATETIME              DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_ma_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : mecanicien_stock
--  Stock de pièces détachées du garage mécanicien.
--  Créée/chargée dans : module/mecanicien/server/parts.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mecanicien_stock` (
    `item`     VARCHAR(60) NOT NULL,
    `quantity` INT(11)     NOT NULL DEFAULT 0,
    PRIMARY KEY (`item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : pompiers_agents
--  Registre des agents du métier Pompiers (prise/fin de service).
--  Créée/chargée dans : module/pompiers/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `pompiers_agents` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60)  NOT NULL,
    `name`       VARCHAR(100) NOT NULL DEFAULT '',
    `on_duty`    TINYINT(1)   NOT NULL DEFAULT 0,
    `duty_since` DATETIME              DEFAULT NULL,
    `last_seen`  DATETIME              DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_pa_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : samu_agents
--  Registre des agents du métier SAMU (prise/fin de service).
--  Le dossier médical (mdt_med_*) est documenté séparément dans
--  module/samu/sql/medical.sql.
--  Créée/chargée dans : module/samu/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `samu_agents` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60)  NOT NULL,
    `name`       VARCHAR(100) NOT NULL DEFAULT '',
    `on_duty`    TINYINT(1)   NOT NULL DEFAULT 0,
    `duty_since` DATETIME              DEFAULT NULL,
    `last_seen`  DATETIME              DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_sa_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : police_officers
--  Registre des agents du métier Police (prise/fin de service).
--  Le MDT (mdt_*) est documenté séparément dans module/mdt/sql/mdt.sql.
--  Créée/chargée dans : module/police/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `police_officers` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60)  NOT NULL,
    `name`       VARCHAR(100) NOT NULL DEFAULT '',
    `service`    VARCHAR(60)           DEFAULT NULL,

    -- Unité spécialisée (ex. "raid", "bri"), null si service courant
    `unit`       VARCHAR(60)           DEFAULT NULL,

    `on_duty`    TINYINT(1)   NOT NULL DEFAULT 0,
    `duty_since` DATETIME              DEFAULT NULL,
    `last_seen`  DATETIME              DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_po_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : police_cuffed
--  État de menottage courant (source / cible, un enregistrement par action).
--  Créée/chargée dans : module/police/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `police_cuffed` (
    `id`         INT(11)     NOT NULL AUTO_INCREMENT,
    `source_id`  INT(11)     NOT NULL,
    `target_id`  INT(11)     NOT NULL,
    `officer_id` VARCHAR(60) NOT NULL,
    `target_id2` VARCHAR(60) NOT NULL,
    `cuffed`     TINYINT(1)  NOT NULL DEFAULT 1,
    `created_at` DATETIME             DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_pc_target` (`target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : police_radio_channels
--  Présence sur les canaux radio police (join/quitte un channel).
--  Créée/chargée dans : module/police/server/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `police_radio_channels` (
    `id`         INT(11)     NOT NULL AUTO_INCREMENT,
    `source_id`  INT(11)     NOT NULL,
    `identifier` VARCHAR(60) NOT NULL,
    `channel_id` INT(11)     NOT NULL,
    `joined_at`  DATETIME             DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_prc_source` (`source_id`),
    KEY `idx_prc_channel` (`channel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : police_custody
--  Gardes à vue en cours/passées (garde-à-vue temporaire, hors prison).
--  Créée/chargée dans : module/police/server/prison.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `police_custody` (
    `id`           INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier`   VARCHAR(60)  NOT NULL,
    `name`         VARCHAR(100) NOT NULL DEFAULT '',
    `reason`       TEXT         NOT NULL,

    -- Durée de la garde à vue, en minutes
    `duration`     INT(11)      NOT NULL DEFAULT 30,

    `started_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ends_at`      DATETIME     NOT NULL,
    `released_at`  DATETIME              DEFAULT NULL,
    `officer_id`   VARCHAR(60)  NOT NULL DEFAULT '',
    `officer_name` VARCHAR(100) NOT NULL DEFAULT '',

    -- Département ayant procédé au placement (police, gendarmerie, ...)
    `department`   VARCHAR(50)  NOT NULL DEFAULT 'police',

    PRIMARY KEY (`id`),
    KEY `idx_custody_ident` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : police_prison
--  Peines de prison fermes (distinctes de la garde à vue police_custody).
--  Créée/chargée dans : module/police/server/prison.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `police_prison` (
    `id`           INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier`   VARCHAR(60)  NOT NULL,
    `name`         VARCHAR(100) NOT NULL DEFAULT '',
    `reason`       TEXT         NOT NULL,

    -- Durée de la peine, en minutes
    `duration`     INT(11)      NOT NULL DEFAULT 30,

    `started_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ends_at`      DATETIME     NOT NULL,
    `released_at`  DATETIME              DEFAULT NULL,
    `officer_id`   VARCHAR(60)  NOT NULL DEFAULT '',
    `officer_name` VARCHAR(100) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    KEY `idx_prison_ident` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : police_callouts
--  Historique des interventions générées (callouts scénarisés).
--  Créée/chargée dans : module/police/server/callouts.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `police_callouts` (
    `id`                 INT(11)      NOT NULL AUTO_INCREMENT,

    -- Clé du scénario déclenché (ex. "braquage_superette", "code_dcd")
    `scenario_id`        VARCHAR(60)  NOT NULL,
    `label`              VARCHAR(120) NOT NULL,

    -- "x, y, z" du lieu d'intervention
    `coords`             VARCHAR(80)  NOT NULL,
    `zone`               VARCHAR(80)           DEFAULT NULL,

    `status`             ENUM('cancelled','success','failed') NOT NULL,

    -- 1 = fausse alerte signalée par les agents
    `false_alarm`        TINYINT(1)            DEFAULT 0,

    `agents_registered`  INT(11)               DEFAULT 0,
    `suspects_total`     INT(11)               DEFAULT 0,
    `suspects_delivered` INT(11)               DEFAULT 0,
    `suspects_killed`    INT(11)               DEFAULT 0,
    `suspects_escaped`   INT(11)               DEFAULT 0,

    -- Snapshot JSON des suspects/PNJ impliqués (rôle, nom, issue, arme...)
    `suspects_json`      TEXT                  DEFAULT NULL,

    -- Temps de réponse des agents, en secondes (null si non mesuré)
    `response_time`      INT(11)               DEFAULT NULL,

    `started_at`         DATETIME              DEFAULT CURRENT_TIMESTAMP,
    `ended_at`           DATETIME              DEFAULT NULL,

    -- Rapport rédigé a posteriori par un agent depuis le MDT
    `report`             TEXT                  DEFAULT NULL,
    `report_by`          VARCHAR(120)          DEFAULT NULL,
    `report_at`          DATETIME              DEFAULT NULL,

    -- Clôture administrative de l'intervention (indépendante du rapport)
    `closed_at`          DATETIME              DEFAULT NULL,
    `closed`             TINYINT(1)   NOT NULL DEFAULT 0,
    `closed_by`          VARCHAR(120)          DEFAULT NULL,

    -- Département ayant mené l'intervention (chef d'équipage sur mission conjointe)
    `department`         VARCHAR(50)  NOT NULL DEFAULT 'police',

    PRIMARY KEY (`id`),
    KEY `idx_pc_status` (`status`),
    KEY `idx_pc_started` (`started_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : police_callout_agents
--  Participation de chaque agent à un callout (une ligne par agent).
--  Créée/chargée dans : module/police/server/callouts.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `police_callout_agents` (
    `id`          INT(11)      NOT NULL AUTO_INCREMENT,
    `callout_id`  INT(11)      NOT NULL,
    `identifier`  VARCHAR(60)  NOT NULL,
    `name`        VARCHAR(120) NOT NULL,
    `grade`       INT(11)               DEFAULT 0,

    -- 1 = chef d'équipage (rapport/clôture attribués à lui par défaut)
    `is_leader`   TINYINT(1)            DEFAULT 0,

    `cuffed`      INT(11)               DEFAULT 0,
    `delivered`   INT(11)               DEFAULT 0,
    `killed`      INT(11)               DEFAULT 0,

    -- Compteur de fautes relevées (tir sur suspect passif, etc.)
    `misconduct`  INT(11)               DEFAULT 0,

    -- Prime perçue pour cette intervention
    `reward`      INT(11)               DEFAULT 0,

    `department`  VARCHAR(50)  NOT NULL DEFAULT 'police',

    PRIMARY KEY (`id`),
    KEY `idx_pca_callout` (`callout_id`),
    KEY `idx_pca_ident` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : police_crime_scenes
--  Scènes de crime ouvertes/sécurisées par les enquêteurs.
--  Créée/chargée dans : module/police/server/investigation.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `police_crime_scenes` (
    `id`           INT(11)      NOT NULL AUTO_INCREMENT,

    -- Identifiant technique de la scène (ex. "SC<timestamp>_<n>")
    `scene_id`     VARCHAR(50)  NOT NULL,

    `created_by`   VARCHAR(60)  NOT NULL DEFAULT '',
    `officer_name` VARCHAR(100) NOT NULL DEFAULT '',
    `x`            FLOAT        NOT NULL DEFAULT 0,
    `y`            FLOAT        NOT NULL DEFAULT 0,
    `z`            FLOAT        NOT NULL DEFAULT 0,

    -- 1 = périmètre toujours sécurisé/actif
    `secured`      TINYINT(1)   NOT NULL DEFAULT 1,

    `created_at`   DATETIME              DEFAULT CURRENT_TIMESTAMP,
    `closed_at`    DATETIME              DEFAULT NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `scene_id` (`scene_id`),
    KEY `idx_cs_scene` (`scene_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : police_fingerprints
--  Empreintes digitales relevées lors d'une enquête.
--  Créée/chargée dans : module/police/server/investigation.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `police_fingerprints` (
    `id`           INT(11)      NOT NULL AUTO_INCREMENT,

    -- Référence affichée aux joueurs (ex. "FP-<timestamp>-<n>")
    `ref`          VARCHAR(50)  NOT NULL,

    `identifier`   VARCHAR(60)  NOT NULL,
    `citizen_name` VARCHAR(100) NOT NULL DEFAULT '',
    `collected_by` VARCHAR(60)  NOT NULL DEFAULT '',
    `officer_name` VARCHAR(100) NOT NULL DEFAULT '',

    -- Player source au moment du prélèvement (traçabilité technique)
    `target_src`   INT(11)               DEFAULT NULL,

    `created_at`   DATETIME              DEFAULT CURRENT_TIMESTAMP,

    -- Scène de crime d'origine (module/police/server/investigation.lua), null si prélevé hors scène
    `scene_id`     VARCHAR(50)           DEFAULT NULL,
    `description`  TEXT                  DEFAULT NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `ref` (`ref`),
    KEY `idx_fp_ident` (`identifier`),
    KEY `idx_fp_ref` (`ref`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : police_dna
--  Échantillons ADN relevés lors d'une enquête.
--  Créée/chargée dans : module/police/server/investigation.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `police_dna` (
    `id`           INT(11)      NOT NULL AUTO_INCREMENT,

    -- Référence affichée aux joueurs (ex. "DNA-<timestamp>-<n>")
    `ref`          VARCHAR(50)  NOT NULL,

    `identifier`   VARCHAR(60)  NOT NULL,
    `citizen_name` VARCHAR(100) NOT NULL DEFAULT '',
    `collected_by` VARCHAR(60)  NOT NULL DEFAULT '',
    `officer_name` VARCHAR(100) NOT NULL DEFAULT '',
    `created_at`   DATETIME              DEFAULT CURRENT_TIMESTAMP,
    `scene_id`     VARCHAR(50)           DEFAULT NULL,
    `description`  TEXT                  DEFAULT NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `ref` (`ref`),
    KEY `idx_dna_ident` (`identifier`),
    KEY `idx_dna_ref` (`ref`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : police_blood_traces
--  Traces de sang relevées lors d'une enquête (peuvent rester non résolues).
--  Créée/chargée dans : module/police/server/investigation.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `police_blood_traces` (
    `id`           INT(11)      NOT NULL AUTO_INCREMENT,

    -- Référence affichée aux joueurs
    `ref`          VARCHAR(50)  NOT NULL,

    `collected_by` VARCHAR(60)  NOT NULL DEFAULT '',
    `officer_name` VARCHAR(100) NOT NULL DEFAULT '',
    `x`            FLOAT        NOT NULL DEFAULT 0,
    `y`            FLOAT        NOT NULL DEFAULT 0,
    `z`            FLOAT        NOT NULL DEFAULT 0,
    `scene_id`     VARCHAR(50)           DEFAULT NULL,
    `created_at`   DATETIME              DEFAULT CURRENT_TIMESTAMP,
    `description`  TEXT                  DEFAULT NULL,

    PRIMARY KEY (`id`),
    UNIQUE KEY `ref` (`ref`),
    KEY `idx_bt_scene` (`scene_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
--  TABLE : exit_sleeping
--  État des PNJ « ped hors-ligne » laissés endormis à la déconnexion.
--  Aucun CREATE TABLE explicite dans le module (table attendue pré-existante) —
--  lue/écrite dans : module/pedoffline/server/main.lua, module/pedoffline/class/main.lua
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `exit_sleeping` (
    -- Identifiant du joueur endormi (clé naturelle)
    `citizenid` VARCHAR(50) NOT NULL,

    -- Snapshot JSON du ped (skin, position, animation, portage, ...)
    `sleepData` LONGTEXT             DEFAULT NULL,

    -- Horodatage Unix de la dernière sauvegarde (sert au nettoyage/expiration)
    `unixTime`  INT(11)              DEFAULT UNIX_TIMESTAMP(),

    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- =============================================================
--  Tables documentées séparément (schémas dédiés par module)
-- =============================================================
--  - keyhanger_boards          → module/keyhanger/keyhanger.sql
--  - mdt_* (22 tables police)  → module/mdt/sql/mdt.sql
--  - mdt_med_* (SAMU)          → module/samu/sql/medical.sql
--  - atelier_* (4 tables)      → module/atelier/sql/atelier.sql
--  - emotes_favorites          → module/emotes/sql/emotes.sql
--  - phone_* (lb-phone)        → [Autres]/lb-phone/phone.sql (ressource tierce)
--  - multichar (migration)     → module/multichar/sql/multichar.sql
-- =============================================================


-- =============================================================
--  FIN DU FICHIER
--  Ordre de création respecté pour les dépendances :
--    1. players
--    2. banlist
--    3. bankaccounts
--    4. persistent_vehicles
--    5. datastore
--    6. admin_warns, support_tickets
--    7. owned_vehicles, concessionnaire_occasions
--    8. fourriere, interim_stations, farm_shop_stock
--    9. gendarmerie_officers, ltd_agents, ltd_stock,
--       mecanicien_agents, mecanicien_stock, pompiers_agents, samu_agents
--   10. police_officers, police_cuffed, police_radio_channels,
--       police_custody, police_prison
--   11. police_callouts, police_callout_agents
--   12. police_crime_scenes, police_fingerprints, police_dna, police_blood_traces
--   13. exit_sleeping
-- =============================================================
