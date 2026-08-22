--  MDT — Serveur (générique multi-jobs, premier département : police)
--
--  Sécurité :
--   • Toute action revalide job/grade/permission depuis ServerPlayers,
--     jamais depuis le payload client.
--   • Communication client→serveur via le SEUL mécanisme fiable du
--     framework : events tokenisés (LSLegacy.RegisterServerEvent +
--     SendEventToServer), plutôt que LSLegacy.Callbacks (aller-retour).
--   • Lectures  : event 'mdt:query' (dispatcher) → réponse 'mdt:queryResult'.
--   • Écritures : un event par action → réponse 'mdt:result'.
--   • Limites déclarées ci-dessous via LSLegacy.Security.RegisterRateLimit.

local rateLimits = {
    ['mdt:query'] = 80,
    ['mdt:createFine'] = 20, ['mdt:toggleFinePaid'] = 25, ['mdt:deleteFine'] = 15,
    ['mdt:addCriminalRecord'] = 20, ['mdt:deleteCriminalRecord'] = 15,
    ['mdt:createReport'] = 20, ['mdt:updateReport'] = 25, ['mdt:deleteReport'] = 15,
    ['mdt:createInterventionReport'] = 20, ['mdt:updateInterventionReport'] = 25,
    ['mdt:deleteInterventionReport'] = 15, ['mdt:linkCaseItem'] = 25, ['mdt:unlinkCaseItem'] = 25,
    ['mdt:linkReportItem'] = 25, ['mdt:unlinkReportItem'] = 25, ['mdt:setVehicleWanted'] = 20,
    ['mdt:setVehicleLocation'] = 20, ['mdt:createWarrant'] = 20, ['mdt:updateWarrant'] = 20,
    ['mdt:deleteWarrant'] = 15, ['mdt:createCustody'] = 20, ['mdt:addEvidence'] = 20,
    ['mdt:registerWeapon'] = 20, ['mdt:updateWeapon'] = 20, ['mdt:deleteWeapon'] = 15,
    ['mdt:seizeWeapon'] = 20, ['mdt:linkWeaponPerson'] = 25, ['mdt:unlinkWeaponPerson'] = 25,
    ['mdt:linkWeaponReport'] = 25, ['mdt:unlinkWeaponReport'] = 25, ['mdt:createLaw'] = 20,
    ['mdt:updateLaw'] = 20, ['mdt:deleteLaw'] = 15, ['mdt:createTraining'] = 20,
    ['mdt:updateTraining'] = 20, ['mdt:deleteTraining'] = 15, ['mdt:signupTraining'] = 25,
    ['mdt:unsignupTraining'] = 25, ['mdt:removeSignup'] = 25, ['mdt:deleteCustody'] = 15,
    ['mdt:linkPersonWeapon'] = 25, ['mdt:validateSignup'] = 25, ['mdt:updateEvidence'] = 25,
    ['mdt:linkReportEvidence'] = 25, ['mdt:unlinkReportEvidence'] = 25, ['mdt:saveAgentMeta'] = 20,
    ['mdt:saveCareer'] = 20, ['mdt:addAssignment'] = 25, ['mdt:updateAssignment'] = 25,
    ['mdt:deleteAssignment'] = 20, ['mdt:addCommendation'] = 20, ['mdt:deleteCommendation'] = 20,
    ['mdt:addSkill'] = 20, ['mdt:deleteSkill'] = 20, ['mdt:updateSkillDate'] = 20,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local L = Config.MDT.Limits

--  Création des tables au démarrage (idempotent)
MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_criminal_records (
        id INT(11) NOT NULL AUTO_INCREMENT,
        department VARCHAR(50) NOT NULL DEFAULT 'police',
        identifier VARCHAR(60) NOT NULL,
        character_id INT DEFAULT NULL,
        citizen_name VARCHAR(100) NOT NULL DEFAULT '',
        charge VARCHAR(255) NOT NULL DEFAULT '',
        description TEXT DEFAULT NULL,
        officer_identifier VARCHAR(60) NOT NULL DEFAULT '',
        officer_character_id INT DEFAULT NULL,
        officer_name VARCHAR(100) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_mdt_records_identifier (identifier),
        KEY idx_mdt_records_department (department)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_fines (
        id INT(11) NOT NULL AUTO_INCREMENT,
        department VARCHAR(50) NOT NULL DEFAULT 'police',
        identifier VARCHAR(60) NOT NULL,
        character_id INT DEFAULT NULL,
        citizen_name VARCHAR(100) NOT NULL DEFAULT '',
        amount INT(11) NOT NULL DEFAULT 0,
        reason VARCHAR(255) NOT NULL DEFAULT '',
        plate VARCHAR(12) DEFAULT NULL,
        officer_identifier VARCHAR(60) NOT NULL DEFAULT '',
        officer_character_id INT DEFAULT NULL,
        officer_name VARCHAR(100) NOT NULL DEFAULT '',
        paid TINYINT(1) NOT NULL DEFAULT 0,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_mdt_fines_identifier (identifier),
        KEY idx_mdt_fines_plate (plate),
        KEY idx_mdt_fines_department (department)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_reports (
        id INT(11) NOT NULL AUTO_INCREMENT,
        department VARCHAR(50) NOT NULL DEFAULT 'police',
        type VARCHAR(30) NOT NULL DEFAULT 'intervention',
        title VARCHAR(255) NOT NULL DEFAULT '',
        content LONGTEXT DEFAULT NULL,
        involved LONGTEXT NOT NULL DEFAULT '[]',
        author_identifier VARCHAR(60) NOT NULL DEFAULT '',
        author_name VARCHAR(100) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_mdt_reports_dep_type (department, type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_warrants (
        id INT(11) NOT NULL AUTO_INCREMENT,
        department VARCHAR(50) NOT NULL DEFAULT 'police',
        identifier VARCHAR(60) DEFAULT NULL,
        character_id INT DEFAULT NULL,
        citizen_name VARCHAR(100) NOT NULL DEFAULT '',
        reason TEXT DEFAULT NULL,
        danger_level INT NOT NULL DEFAULT 1,
        status VARCHAR(20) NOT NULL DEFAULT 'active',
        author_identifier VARCHAR(60) NOT NULL DEFAULT '',
        author_character_id INT DEFAULT NULL,
        author_name VARCHAR(100) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_mdt_warrants_dep_status (department, status),
        KEY idx_mdt_warrants_identifier (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_custody (
        id INT(11) NOT NULL AUTO_INCREMENT,
        department VARCHAR(50) NOT NULL DEFAULT 'police',
        identifier VARCHAR(60) NOT NULL,
        character_id INT DEFAULT NULL,
        citizen_name VARCHAR(100) NOT NULL DEFAULT '',
        reason TEXT DEFAULT NULL,
        duration INT(11) NOT NULL DEFAULT 0,
        pv LONGTEXT DEFAULT NULL,
        officer_identifier VARCHAR(60) NOT NULL DEFAULT '',
        officer_character_id INT DEFAULT NULL,
        officer_name VARCHAR(100) NOT NULL DEFAULT '',
        started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        ends_at TIMESTAMP NULL DEFAULT NULL,
        PRIMARY KEY (id),
        KEY idx_mdt_custody_identifier (identifier),
        KEY idx_mdt_custody_department (department)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_evidence (
        id INT(11) NOT NULL AUTO_INCREMENT,
        department VARCHAR(50) NOT NULL DEFAULT 'police',
        case_id INT(11) DEFAULT NULL,
        type VARCHAR(30) NOT NULL DEFAULT 'empreinte',
        label VARCHAR(255) NOT NULL DEFAULT '',
        data LONGTEXT NOT NULL DEFAULT '{}',
        status VARCHAR(30) NOT NULL DEFAULT 'collected',
        identifier VARCHAR(60) DEFAULT NULL,
        character_id INT DEFAULT NULL,
        collected_by VARCHAR(60) NOT NULL DEFAULT '',
        collected_by_name VARCHAR(100) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_mdt_evidence_department (department),
        KEY idx_mdt_evidence_case (case_id),
        KEY idx_mdt_evidence_type (type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_weapons (
        id INT(11) NOT NULL AUTO_INCREMENT,
        department VARCHAR(50) NOT NULL DEFAULT 'police',
        serial_number VARCHAR(20) DEFAULT NULL,
        category VARCHAR(20) NOT NULL DEFAULT 'firearm',
        model VARCHAR(120) NOT NULL DEFAULT '',
        notes TEXT DEFAULT NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'registered',
        seized TINYINT(1) NOT NULL DEFAULT 0,
        seized_case_id INT(11) DEFAULT NULL,
        seized_by VARCHAR(60) DEFAULT NULL,
        seized_by_name VARCHAR(100) DEFAULT NULL,
        seized_at TIMESTAMP NULL DEFAULT NULL,
        registered_by VARCHAR(60) NOT NULL DEFAULT '',
        registered_by_name VARCHAR(100) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_mdt_weapons_serial (serial_number),
        KEY idx_mdt_weapons_department (department),
        KEY idx_mdt_weapons_seized (seized)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_weapon_persons (
        id INT(11) NOT NULL AUTO_INCREMENT,
        weapon_id INT(11) NOT NULL,
        identifier VARCHAR(60) NOT NULL,
        character_id INT DEFAULT NULL,
        citizen_name VARCHAR(100) NOT NULL DEFAULT '',
        relation VARCHAR(40) NOT NULL DEFAULT 'lie',
        linked_by VARCHAR(60) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_mwp (weapon_id, character_id),
        KEY idx_mwp_weapon (weapon_id),
        KEY idx_mwp_person (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
MySQL.Async.execute("ALTER TABLE mdt_weapon_persons ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_weapon_reports (
        id INT(11) NOT NULL AUTO_INCREMENT,
        weapon_id INT(11) NOT NULL,
        report_id INT(11) NOT NULL,
        linked_by VARCHAR(60) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_mwr (weapon_id, report_id),
        KEY idx_mwr_weapon (weapon_id),
        KEY idx_mwr_report (report_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_laws (
        id INT(11) NOT NULL AUTO_INCREMENT,
        department VARCHAR(50) NOT NULL DEFAULT 'police',
        article VARCHAR(40) NOT NULL DEFAULT '',
        name VARCHAR(255) NOT NULL DEFAULT '',
        description TEXT DEFAULT NULL,
        fine INT(11) NOT NULL DEFAULT 0,
        jail VARCHAR(120) NOT NULL DEFAULT '',
        category VARCHAR(60) NOT NULL DEFAULT '',
        created_by VARCHAR(60) NOT NULL DEFAULT '',
        created_by_name VARCHAR(100) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_mdt_laws_department (department),
        KEY idx_mdt_laws_category (category)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_trainings (
        id INT(11) NOT NULL AUTO_INCREMENT,
        department VARCHAR(50) NOT NULL DEFAULT 'police',
        name VARCHAR(255) NOT NULL DEFAULT '',
        scheduled_at VARCHAR(40) NOT NULL DEFAULT '',
        description TEXT DEFAULT NULL,
        max_slots INT(11) NOT NULL DEFAULT 0,
        created_by VARCHAR(60) NOT NULL DEFAULT '',
        created_by_name VARCHAR(100) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_mdt_trainings_department (department)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_training_signups (
        id INT(11) NOT NULL AUTO_INCREMENT,
        training_id INT(11) NOT NULL,
        identifier VARCHAR(60) NOT NULL,
        character_id INT DEFAULT NULL,
        citizen_name VARCHAR(100) NOT NULL DEFAULT '',
        grade INT(11) NOT NULL DEFAULT 0,
        grade_label VARCHAR(60) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_mts (training_id, character_id),
        KEY idx_mts_training (training_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- Statut de validation des inscriptions (pending | validated | refused)
MySQL.Async.execute("ALTER TABLE mdt_training_signups ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'pending'", {})
MySQL.Async.execute("ALTER TABLE mdt_training_signups ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})
-- Code de formation associé (formations + compétences)
MySQL.Async.execute("ALTER TABLE mdt_trainings ADD COLUMN IF NOT EXISTS code VARCHAR(10) NOT NULL DEFAULT ''", {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_report_evidence (
        id INT(11) NOT NULL AUTO_INCREMENT,
        report_id INT(11) NOT NULL,
        ev_type VARCHAR(20) NOT NULL DEFAULT '',
        ev_ref VARCHAR(60) NOT NULL,
        label VARCHAR(200) NOT NULL DEFAULT '',
        linked_by VARCHAR(60) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_mre (report_id, ev_ref),
        KEY idx_mre_report (report_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- Rapports d'intervention : le compte rendu rédigé par les agents après
-- une intervention. Distinct de l'enquête (mdt_reports), qui les agrège.
MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_intervention_reports (
        id INT(11) NOT NULL AUTO_INCREMENT,
        department VARCHAR(50) NOT NULL DEFAULT 'police',
        type VARCHAR(30) NOT NULL DEFAULT 'intervention',
        content LONGTEXT DEFAULT NULL,
        agents LONGTEXT NOT NULL DEFAULT '[]',
        involved LONGTEXT NOT NULL DEFAULT '[]',
        joint TINYINT(1) NOT NULL DEFAULT 0,
        author_identifier VARCHAR(60) NOT NULL DEFAULT '',
        author_name VARCHAR(100) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_mir_dep_date (department, created_at),
        KEY idx_mir_type (type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- Éléments rattachés à une enquête. On ne stocke QUE la référence : le
-- libellé est résolu à la lecture par jointure, il n'y a donc jamais de
-- copie d'une donnée qui vit ailleurs (rapport, véhicule, citoyen).
--   kind = 'report'  → ref = mdt_intervention_reports.id
--   kind = 'vehicle' → ref = plaque d'immatriculation
--   kind = 'person'  → ref = identifier du citoyen
-- Les preuves et les armes conservent leurs tables de liaison dédiées
-- (mdt_report_evidence, mdt_weapon_reports), déjà en place et exploitées
-- ailleurs — les dupliquer ici créerait deux sources de vérité.
MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_case_links (
        id INT(11) NOT NULL AUTO_INCREMENT,
        case_id INT(11) NOT NULL,
        kind VARCHAR(20) NOT NULL,
        ref VARCHAR(60) NOT NULL,
        note VARCHAR(120) DEFAULT NULL,
        linked_by VARCHAR(60) NOT NULL DEFAULT '',
        linked_by_name VARCHAR(100) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_mcl (case_id, kind, ref),
        KEY idx_mcl_case (case_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- Armes et véhicules associés à un RAPPORT D'INTERVENTION (distinct de
-- mdt_case_links, qui rattache des éléments à une ENQUÊTE). Même principe :
-- seule la référence est stockée.
--   kind = 'weapon'  → ref = mdt_weapons.id
--   kind = 'vehicle' → ref = plaque d'immatriculation
MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_report_links (
        id INT(11) NOT NULL AUTO_INCREMENT,
        report_id INT(11) NOT NULL,
        kind VARCHAR(20) NOT NULL,
        ref VARCHAR(60) NOT NULL,
        linked_by VARCHAR(60) NOT NULL DEFAULT '',
        linked_by_name VARCHAR(100) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_mrl (report_id, kind, ref),
        KEY idx_mrl_report (report_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_agent_skills (
        id INT(11) NOT NULL AUTO_INCREMENT,
        department VARCHAR(50) NOT NULL DEFAULT 'police',
        identifier VARCHAR(60) NOT NULL,
        character_id INT DEFAULT NULL,
        skill VARCHAR(150) NOT NULL,
        obtained_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_mas (character_id, skill),
        KEY idx_mas_identifier (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
-- Code de formation de la compétence (pour déblocages + recyclage)
MySQL.Async.execute("ALTER TABLE mdt_agent_skills ADD COLUMN IF NOT EXISTS code VARCHAR(10) NOT NULL DEFAULT ''", {})
MySQL.Async.execute("ALTER TABLE mdt_agent_skills ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})

-- Fiche détaillée agent : infos RH (1 ligne par PERSONNAGE, matricule unique).
-- PK = id surrogate (pas `identifier`) : un compte multichar peut avoir
-- plusieurs personnages agents, chacun avec sa propre fiche.
MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_agent_meta (
        id INT(11) NOT NULL AUTO_INCREMENT,
        identifier VARCHAR(60) NOT NULL,
        character_id INT DEFAULT NULL,
        department VARCHAR(50) NOT NULL DEFAULT 'police',
        matricule VARCHAR(20) NOT NULL DEFAULT '',
        hire_date VARCHAR(20) NOT NULL DEFAULT '',
        tenure_date VARCHAR(20) NOT NULL DEFAULT '',
        service_weapon VARCHAR(20) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uq_meta_matricule (matricule),
        UNIQUE KEY uq_meta_character (character_id),
        KEY idx_meta_identifier (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
MySQL.Async.execute("ALTER TABLE mdt_agent_meta ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})

-- Historique de carrière (1 ligne par grade par personnage)
MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_agent_career (
        id INT(11) NOT NULL AUTO_INCREMENT,
        identifier VARCHAR(60) NOT NULL,
        character_id INT DEFAULT NULL,
        grade_index INT(11) NOT NULL,
        start_date VARCHAR(20) NOT NULL DEFAULT '',
        end_date VARCHAR(20) NOT NULL DEFAULT '',
        PRIMARY KEY (id),
        UNIQUE KEY uq_career (character_id, grade_index),
        KEY idx_career_identifier (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
MySQL.Async.execute("ALTER TABLE mdt_agent_career ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})

-- Affectations opérationnelles
MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_agent_assignments (
        id INT(11) NOT NULL AUTO_INCREMENT,
        identifier VARCHAR(60) NOT NULL,
        character_id INT DEFAULT NULL,
        code VARCHAR(80) NOT NULL DEFAULT '',
        start_date VARCHAR(20) NOT NULL DEFAULT '',
        end_date VARCHAR(20) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_assign_identifier (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
MySQL.Async.execute("ALTER TABLE mdt_agent_assignments ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})

-- Lettres de félicitations / sanctions
MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_agent_commendations (
        id INT(11) NOT NULL AUTO_INCREMENT,
        identifier VARCHAR(60) NOT NULL,
        character_id INT DEFAULT NULL,
        obtained_date VARCHAR(20) NOT NULL DEFAULT '',
        nature VARCHAR(40) NOT NULL DEFAULT '',
        reason VARCHAR(255) NOT NULL DEFAULT '',
        details TEXT DEFAULT NULL,
        author VARCHAR(60) NOT NULL DEFAULT '',
        author_name VARCHAR(100) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_comm_identifier (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
MySQL.Async.execute("ALTER TABLE mdt_agent_commendations ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})

-- Marquage administratif d'un véhicule (recherché + localisation) par plaque.
MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_vehicle_flags (
        plate VARCHAR(12) NOT NULL,
        department VARCHAR(50) NOT NULL DEFAULT 'police',
        wanted INT NOT NULL DEFAULT 0,
        reason VARCHAR(255) NOT NULL DEFAULT '',
        location VARCHAR(20) NOT NULL DEFAULT 'circulation',
        officer_identifier VARCHAR(60) NOT NULL DEFAULT '',
        officer_name VARCHAR(100) NOT NULL DEFAULT '',
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (plate)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
-- Migrations idempotentes (si la table existait déjà sans ces colonnes)
MySQL.Async.execute("ALTER TABLE mdt_vehicle_flags ADD COLUMN IF NOT EXISTS location VARCHAR(20) NOT NULL DEFAULT 'circulation'", {})
-- Date d'achat des véhicules (table du concessionnaire). Les nouveaux achats
-- prennent CURRENT_TIMESTAMP ; les lignes existantes prennent la date de migration.
MySQL.Async.execute("ALTER TABLE owned_vehicles ADD COLUMN IF NOT EXISTS bought_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP", {})
MySQL.Async.execute("ALTER TABLE mdt_evidence ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})

-- Bodycam supprimée : on retire l'ancienne table (peut être enlevé après un démarrage).
MySQL.Async.execute("DROP TABLE IF EXISTS mdt_bodycam", {})

-- Migration : danger_level doit être INT et non TINYINT(1) (ce dernier est
-- relu comme booléen par le driver mysql → 2/3 deviennent `true` → perdu).
-- Idempotent : MODIFY réapplique simplement le type.
MySQL.Async.execute("ALTER TABLE mdt_warrants MODIFY COLUMN danger_level INT NOT NULL DEFAULT 1", {})

--  Helpers

-- Nom RP d'un objet joueur (Prénom NOM).
local function charName(player)
    if player and player.characterInfos then
        return ((player.characterInfos.Prenom or '') .. ' ' .. (player.characterInfos.NDF or '')):gsub('^%s+', ''):gsub('%s+$', '')
    end
    return '?'
end

-- Contexte MDT d'un joueur : (player, department, grade) ou nil.
local function ctx(src)
    local player = LSLegacy.GetPlayerFromId(src)
    if not player then return nil end
    local depName = LSLegacy.MDT.GetDepartmentForJob(player.job)
    if not depName then return nil end
    return player, depName, tonumber(player.job_grade) or 0
end

-- Clause SQL de portée pour une table de la base commune.
---
-- Police et gendarmerie travaillent sur le même fichier judiciaire : une
-- lecture ne peut donc plus se limiter au département du demandeur, sinon
-- un avis de recherche émis par un pôle serait invisible pour l'autre.
-- L'implémentation vit dans shared/permissions.lua, partagée avec les
-- modules métier (le pont MDT des interventions s'en sert aussi).
local function scopeClause(depName, tableName, column)
    return LSLegacy.MDT.ScopeClause(depName, tableName, column)
end

-- Permissions effectives (grade + déblocages par compétence) mises en cache
-- à l'ouverture du MDT, par character_id : mdt_agent_skills est désormais
-- per-personnage, un cache par identifier mélangerait les compétences de
-- deux personnages agents d'un même compte multichar.
local grantedPerms = {}

-- Permission effective : grade OU débloquée par compétence.
local function mdtHasPerm(player, depName, grade, perm)
    if not perm then return true end
    if LSLegacy.MDT.HasPermission(depName, grade, perm) then return true end
    local g = player and grantedPerms[player["boutique-id"]]
    return (g and (g[perm] or g.admin_mdt)) == true
end

-- Garde de permission pour les écritures. Renvoie (player, department, grade) ou nil.
local function can(src, perm)
    local player, depName, grade = ctx(src)
    if not player then return nil end
    if perm and not mdtHasPerm(player, depName, grade, perm) then return nil end
    return player, depName, grade
end

-- Texte sûr : string tronquée à maxLen, sinon ''.
local function safeText(v, maxLen)
    if type(v) ~= 'string' then return '' end
    v = v:gsub('%z', '')
    if #v > (maxLen or L.MaxTextLength) then v = v:sub(1, maxLen or L.MaxTextLength) end
    return v
end

-- Plaque normalisée (A-Z 0-9, max 12) ou nil.
local function safePlate(v)
    if type(v) ~= 'string' then return nil end
    v = v:upper():gsub('[^A-Z0-9 ]', ''):gsub('%s+', ''):sub(1, 12)
    if v == '' then return nil end
    return v
end

-- Envoi standardisé d'un résultat d'écriture au client (notif + refresh éventuel).
local function result(src, ok, message, refresh)
    LSLegacy.SendEventToClient('mdt:result', src, { ok = ok, message = message, refresh = refresh })
end

-- Log Discord MDT (no-op si webhook vide).
local function mdtLog(title, desc, fields)
    local hook = Config.MDT.Webhook
    if not hook or hook == '' then return end
    local body = json.encode({
        embeds = { {
            title = '[MDT] ' .. title,
            description = desc or '',
            color = 1942146,
            fields = fields or {},
            footer = { text = 'LSLegacy MDT • ' .. os.date('%d/%m/%Y %H:%M:%S') },
        } },
    })
    PerformHttpRequest(hook, function() end, 'POST', body, { ['Content-Type'] = 'application/json' })
end

-- Résout le nom RP d'un citoyen (online ou BDD) puis appelle cb(name|nil).
local function resolveCitizenName(identifier, cb)
    if type(identifier) ~= 'string' or identifier == '' then return cb(nil) end
    for _, p in pairs(LSLegacy.Players.GetAll()) do
        if p.identifier == identifier then return cb(charName(p)) end
    end
    MySQL.Async.fetchAll('SELECT characterInfos FROM players WHERE identifier = @id LIMIT 1', { ['@id'] = identifier }, function(rows)
        if rows and rows[1] then
            local ok, info = pcall(json.decode, rows[1].characterInfos)
            if ok and info then
                return cb(((info.Prenom or '') .. ' ' .. (info.NDF or '')):gsub('^%s+', ''):gsub('%s+$', ''))
            end
        end
        cb(nil)
    end)
end

--  Ouverture du MDT (item tablette)

-- Construit la liste des grades pour l'onglet Organisation.
local function buildGrades(depName, dep)
    local out = {}
    if not dep or not dep.grades then return out end
    for i = 0, 30 do
        local g = dep.grades[i]
        if g then
            local permSet = LSLegacy.MDT.GetPermissions(depName, i)
            local permList = {}
            for p, _ in pairs(permSet) do permList[#permList + 1] = p end
            out[#out + 1] = {
                grade = i,
                label = g.label,
                responsibilities = g.responsibilities or '',
                vehicles = g.vehicles or {},
                units = g.units or {},
                permissions = permList,
            }
        end
    end
    return out
end

local function openMDT(src)
    local player, depName, grade = ctx(src)
    if not player then
        LSLegacy.SendEventToClient('notify', src, nil, "Vous n'avez pas accès au MDT.", 'error')
        return
    end
    local dep = LSLegacy.MDT.GetDepartment(depName)
    -- On charge les compétences pour accorder des permissions dynamiques
    -- (ex : CS037 → Enquête, CZ001 → création de formation).
    -- map nom→code (compétences obtenues sans code stocké)
    -- On lit le cursus du département quand il en déclare un (gendarmerie,
    -- SAMU…), sinon la liste globale : sans cela, une compétence saisie
    -- sans code ne serait jamais reconnue pour ces départements.
    local nameToCode = {}
    for _, tc in ipairs(dep.trainingCodes or Config.MDT.TrainingCodes or {}) do
        nameToCode[tc.name] = tc.code
    end
    MySQL.Async.fetchAll('SELECT skill, code FROM mdt_agent_skills WHERE character_id=@id', { ['@id'] = player["boutique-id"] }, function(srows)
        local perms = LSLegacy.MDT.GetPermissions(depName, grade)
        for _, r in ipairs(srows or {}) do
            local code = (r.code and r.code ~= '') and r.code or nameToCode[r.skill]
            local unlock = code and Config.MDT.SkillUnlocks[code]
            if unlock then for _, p in ipairs(unlock) do perms[p] = true end end
        end
        -- cache des permissions effectives (consulté par mdtHasPerm côté serveur)
        grantedPerms[player["boutique-id"]] = perms
        -- Onglets visibles selon le set de permissions FINAL (grade + déblocages)
        local tabs = {}
        local enabled = {}
        for _, t in ipairs(dep.tabs or {}) do enabled[t] = true end
        for _, tab in ipairs(Config.MDT.Tabs or {}) do
            if enabled[tab.id] and (not tab.permission or perms.admin_mdt or perms[tab.permission]) then
                tabs[#tabs + 1] = { id = tab.id, label = tab.label, icon = tab.icon }
            end
        end
        -- Libellés des départements de la sphère : la NUI s'en sert pour
        -- estampiller chaque pièce du dossier commun (« Police » /
        -- « Gendarmerie »). Un département seul dans sa sphère n'en reçoit
        -- qu'un seul, et la NUI n'affiche alors aucun badge.
        local group = LSLegacy.MDT.GetDataGroup(depName)
        local depLabels = {}
        for _, d in ipairs(group) do
            local other = LSLegacy.MDT.GetDepartment(d)
            if other then
                depLabels[d] = { label = other.label, short = other.short or d, color = other.color }
            end
        end

        local payload = {
            department       = depName,
            departmentLabel  = dep.label,
            departmentColor  = dep.color,
            dataGroup        = group,
            departmentLabels = depLabels,
            job              = player.job,
            grade            = grade,
            gradeLabel       = LSLegacy.MDT.GetGradeLabel(depName, grade),
            officerName      = charName(player),
            myIdentifier     = player.identifier,
            permissions      = perms,
            tabs             = tabs,
            services         = dep.services or {},
            grades           = buildGrades(depName, dep),
            reportTypes      = Config.MDT.ReportTypes,
            dangerLevels     = Config.MDT.DangerLevels,
            lawCategories    = Config.MDT.LawCategories,
            -- Un département peut fournir ses propres codes de formation
            -- (ex. SAMU : PSE1/PSE2/RCP…). Sans override, on garde la liste
            -- globale — le comportement police est donc inchangé.
            trainingCodes    = dep.trainingCodes or Config.MDT.TrainingCodes,
            skillRecycleDays = Config.MDT.SkillRecycleDays,
        }
        LSLegacy.SendEventToClient('mdt:open', src, payload)
    end)
end

LSLegacy.RegisterUsableItem(Config.MDT.Item, function()
    local src = source
    openMDT(src)
end)

-- Commande admin de test : se donner (ou donner) la tablette MDT.
-- ID cible optionnel parsé depuis rawCommand (pas d'argument typé pour
-- éviter l'erreur de validation quand l'argument est absent).
LSLegacy.RegisterCommand('givemdt', 3, function(player, args, showError, rawCommand)
    local target = player
    local parts = LSLegacy.StringSplit(rawCommand or '', ' ')
    local id = tonumber(parts[2])
    if id then
        local tp = LSLegacy.GetPlayerFromId(id)
        if tp then target = tp end
    end
    if not target then return end
    LSLegacy.Inventory.AddItemInInventory(target, Config.MDT.Item, 1, 'Tablette MDT', nil, nil)
    LSLegacy.SendEventToClient('notify', target.source, nil, 'Tablette MDT ajoutée à votre inventaire.', 'success')
end, { help = 'Se donner une tablette MDT (ID joueur optionnel)' }, false)

--  LECTURES — dispatcher 'mdt:query' → réponse 'mdt:queryResult'
--  Chaque handler : (player, depName, grade, data, reply). reply(result)
--  renvoie au client, qui résout le fetch NUI correspondant.

local readHandlers = {}

-- Recherche de citoyens par nom/prénom
readHandlers.searchCitizens = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_citizens') then return reply(false) end
    local query = type(data.query) == 'string' and data.query or ''
    if #query < L.SearchMinChars then return reply({}) end
    -- LOWER des deux côtés : JSON_EXTRACT renvoie une collation binaire
    -- (sensible à la casse) → on normalise pour que "bastien" trouve "Bastien".
    local like = '%' .. query:lower():gsub('[%%_\\]', '') .. '%'
    local limit = math.floor(L.MaxSearchResults)
    MySQL.Async.fetchAll([[
        SELECT identifier, characterInfos, job, job_grade
        FROM players
        WHERE LOWER(JSON_UNQUOTE(JSON_EXTRACT(characterInfos, '$.NDF'))) LIKE @q
           OR LOWER(JSON_UNQUOTE(JSON_EXTRACT(characterInfos, '$.Prenom'))) LIKE @q
        LIMIT ]] .. limit, { ['@q'] = like }, function(rows)
        rows = rows or {}
        MySQL.Async.fetchAll("SELECT DISTINCT identifier FROM mdt_warrants WHERE status = 'active' AND "
            .. scopeClause(depName, 'mdt_warrants'), {}, function(wrows)
            local wanted = {}
            for _, w in ipairs(wrows or {}) do if w.identifier then wanted[w.identifier] = true end end
            local out = {}
            for _, r in ipairs(rows) do
                local ok, info = pcall(json.decode, r.characterInfos)
                if ok and info then
                    out[#out + 1] = {
                        identifier = r.identifier,
                        name = ((info.Prenom or '') .. ' ' .. (info.NDF or '')):gsub('^%s+', ''):gsub('%s+$', ''),
                        sexe = info.Sexe, ddn = info.DDN,
                        wanted = wanted[r.identifier] == true,
                    }
                end
            end
            reply(out)
        end)
    end)
end

-- Fiche complète d'un citoyen
readHandlers.getCitizen = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_citizens') then return reply(false) end
    local identifier = type(data.identifier) == 'string' and data.identifier or ''
    if identifier == '' then return reply(false) end
    MySQL.Async.fetchAll('SELECT identifier, characterInfos, job, job_grade, inventory FROM players WHERE identifier = @id LIMIT 1', { ['@id'] = identifier }, function(prows)
        if not prows or not prows[1] then return reply(false) end
        local ok, info = pcall(json.decode, prows[1].characterInfos)
        if not ok or not info then return reply(false) end
        -- Permis : déduits des items d'inventaire (Config.MDT.Licenses), dans l'ordre configuré
        local licenses = {}
        local invOk, inv = pcall(json.decode, prows[1].inventory or '[]')
        if invOk and type(inv) == 'table' then
            local owned = {}
            for _, it in pairs(inv) do
                if type(it) == 'table' and it.name and (tonumber(it.count) or 0) > 0 then
                    owned[it.name] = true
                end
            end
            for _, lic in ipairs(Config.MDT.Licenses or {}) do
                if owned[lic.item] then licenses[#licenses + 1] = lic.label end
            end
        end
        local identity = {
            identifier = prows[1].identifier,
            name = ((info.Prenom or '') .. ' ' .. (info.NDF or '')):gsub('^%s+', ''):gsub('%s+$', ''),
            prenom = info.Prenom, nom = info.NDF, sexe = info.Sexe,
            ddn = info.DDN, ldn = info.LDN, taille = info.Taille,
            job = prows[1].job, job_grade = prows[1].job_grade,
            licenses = licenses,
        }
        -- Fiche judiciaire commune aux forces de l'ordre : le casier, les
        -- amendes, les avis de recherche et les gardes à vue remontent quel
        -- que soit le pôle qui les a saisis. Chaque ligne porte sa colonne
        -- `department`, qui sert d'estampille d'origine côté NUI.
        local p = { ['@id'] = identifier }
        MySQL.Async.fetchAll('SELECT * FROM mdt_criminal_records WHERE identifier=@id AND ' .. scopeClause(depName, 'mdt_criminal_records') .. ' ORDER BY created_at DESC', p, function(records)
            MySQL.Async.fetchAll('SELECT * FROM mdt_fines WHERE identifier=@id AND ' .. scopeClause(depName, 'mdt_fines') .. ' ORDER BY created_at DESC', p, function(fines)
                MySQL.Async.fetchAll('SELECT * FROM mdt_warrants WHERE identifier=@id AND ' .. scopeClause(depName, 'mdt_warrants') .. ' ORDER BY created_at DESC', p, function(warrants)
                    MySQL.Async.fetchAll('SELECT * FROM mdt_custody WHERE identifier=@id AND ' .. scopeClause(depName, 'mdt_custody') .. ' ORDER BY started_at DESC', p, function(custody)
                        reply({
                            identity = identity,
                            records = records or {}, fines = fines or {},
                            warrants = warrants or {}, custody = custody or {},
                        })
                    end)
                end)
            end)
        end)
    end)
end

-- Maps résolus paresseusement depuis la config du concessionnaire (chargée
-- en shared dans lslegacy) : hash de modèle → nom lisible, id couleur → nom.
local vehLabelByHash, colorLabelById
local function ensureVehicleMaps()
    if not vehLabelByHash then
        vehLabelByHash = {}
        local cat = (Config.Concessionnaire and Config.Concessionnaire.Catalog) or {}
        for _, cats in pairs(cat) do
            for _, v in ipairs(cats.vehicles or {}) do
                if v.model and v.label then vehLabelByHash[GetHashKey(v.model)] = v.label end
            end
        end
    end
    if not colorLabelById then
        colorLabelById = {}
        for _, c in ipairs((Config.Concessionnaire and Config.Concessionnaire.Colors) or {}) do
            if c.id ~= nil and c.label then colorLabelById[c.id] = c.label end
        end
    end
end

-- Construit une ligne véhicule à partir d'un enregistrement owned_vehicles
-- (+ characterInfos du propriétaire jointe). Modèle/couleur viennent de
-- persistent_vehicles (pv.model, pv.tuning), seule source de vérité tenue à
-- jour en continu — owned_vehicles ne porte que la possession.
local function buildVehicleRow(r)
    ensureVehicleMaps()
    local modelName, colorName
    if r.model then
        modelName = vehLabelByHash[math.tointeger(r.model) or r.model]
    end
    if r.tuning then
        local ok, tuning = pcall(json.decode, r.tuning)
        if ok and type(tuning) == 'table' and tuning.colorPrimary ~= nil then
            colorName = colorLabelById[math.tointeger(tuning.colorPrimary) or tuning.colorPrimary]
        end
    end
    local ownerName
    if r.characterInfos then
        local ok, info = pcall(json.decode, r.characterInfos)
        if ok and type(info) == 'table' then
            ownerName = ((info.Prenom or '') .. ' ' .. (info.NDF or '')):gsub('^%s+', ''):gsub('%s+$', '')
            if ownerName == '' then ownerName = nil end
        end
    end
    return {
        plate            = r.plate,
        model_name       = modelName,
        color            = colorName,
        vtype            = r.type,
        stored           = (r.stored == 1 or r.stored == true),
        wanted           = (r.wanted == 1 or r.wanted == true),
        wanted_reason    = r.wanted_reason,
        location         = (r.location and r.location ~= '') and r.location or 'circulation',
        bought_at        = r.bought_at,
        owner_identifier = r.owner,
        owner_name       = ownerName,
    }
end

-- Construit une ligne véhicule depuis une occasion (véhicule au concessionnaire).
-- La localisation est forcée à 'concessionnaire' (auto-détection).
-- Couleur dérivée de o.props (snapshot tuning+status repris à la reprise).
local function buildOccasionRow(o)
    ensureVehicleMaps()
    local ownerName
    if o.characterInfos then
        local ok, info = pcall(json.decode, o.characterInfos)
        if ok and type(info) == 'table' then
            ownerName = ((info.Prenom or '') .. ' ' .. (info.NDF or '')):gsub('^%s+', ''):gsub('%s+$', '')
            if ownerName == '' then ownerName = nil end
        end
    end
    local colorName
    if o.props then
        local ok, snap = pcall(json.decode, o.props)
        if ok and type(snap) == 'table' and type(snap.tuning) == 'table' and snap.tuning.colorPrimary ~= nil then
            colorName = colorLabelById[math.tointeger(snap.tuning.colorPrimary) or snap.tuning.colorPrimary]
        end
    end
    return {
        plate            = o.plate,
        model_name       = o.label,
        color            = colorName,
        vtype            = nil,
        stored           = false,
        wanted           = (o.wanted == 1 or o.wanted == true),
        wanted_reason    = o.wanted_reason,
        location         = 'concessionnaire',
        bought_at        = nil,
        owner_identifier = o.owner,
        owner_name       = ownerName,
    }
end

-- Recherche de véhicules possédés (plaque OU propriétaire) dans owned_vehicles
readHandlers.searchVehicles = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_vehicles') then return reply(false) end
    local query = type(data.query) == 'string' and data.query or ''
    if #query < L.SearchMinChars then return reply({}) end
    local plateLike = '%' .. query:upper():gsub('[%%_\\]', '') .. '%'
    local nameLike  = '%' .. query:lower():gsub('[%%_\\]', '') .. '%'
    local limit = math.floor(L.MaxSearchResults)
    MySQL.Async.fetchAll([[
        SELECT ov.plate, ov.type, ov.stored, ov.owner, ov.bought_at, p.characterInfos,
               pv.model, pv.tuning,
               vf.wanted, vf.reason AS wanted_reason, vf.location
        FROM owned_vehicles ov
        LEFT JOIN players p ON p.`boutique-id` = ov.character_id
        LEFT JOIN persistent_vehicles pv ON pv.plate = ov.plate
        LEFT JOIN mdt_vehicle_flags vf ON vf.plate = ov.plate AND ]] .. scopeClause(depName, 'mdt_vehicle_flags', 'vf.department') .. [[

        WHERE UPPER(ov.plate) LIKE @plate
           OR LOWER(JSON_UNQUOTE(JSON_EXTRACT(p.characterInfos, '$.NDF'))) LIKE @name
           OR LOWER(JSON_UNQUOTE(JSON_EXTRACT(p.characterInfos, '$.Prenom'))) LIKE @name
        LIMIT ]] .. limit, { ['@plate'] = plateLike, ['@name'] = nameLike }, function(rows)
        local out = {}
        for _, r in ipairs(rows or {}) do
            out[#out + 1] = buildVehicleRow(r)
        end
        -- Véhicules actuellement en vente au concessionnaire (occasions)
        MySQL.Async.fetchAll([[
            SELECT o.plate, o.label, o.props, o.owner, p.characterInfos,
                   vf.wanted, vf.reason AS wanted_reason
            FROM concessionnaire_occasions o
            LEFT JOIN players p ON p.`boutique-id` = o.character_id
            LEFT JOIN mdt_vehicle_flags vf ON vf.plate = o.plate AND ]] .. scopeClause(depName, 'mdt_vehicle_flags', 'vf.department') .. [[

            WHERE o.plate IS NOT NULL AND (
                   UPPER(o.plate) LIKE @plate
                OR LOWER(JSON_UNQUOTE(JSON_EXTRACT(p.characterInfos, '$.NDF'))) LIKE @name
                OR LOWER(JSON_UNQUOTE(JSON_EXTRACT(p.characterInfos, '$.Prenom'))) LIKE @name)
            LIMIT ]] .. limit, { ['@plate'] = plateLike, ['@name'] = nameLike }, function(orows)
            for _, o in ipairs(orows or {}) do
                out[#out + 1] = buildOccasionRow(o)
            end
            reply(out)
        end)
    end)
end

-- Fiche véhicule (propriétaire) + historique d'infractions (amendes par plaque)
readHandlers.getVehicle = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_vehicles') then return reply(false) end
    local plate = safePlate(data.plate)
    if not plate then return reply(false) end
    MySQL.Async.fetchAll([[
        SELECT ov.plate, ov.type, ov.stored, ov.owner, ov.bought_at, p.characterInfos,
               pv.model, pv.tuning,
               vf.wanted, vf.reason AS wanted_reason, vf.location
        FROM owned_vehicles ov
        LEFT JOIN players p ON p.`boutique-id` = ov.character_id
        LEFT JOIN persistent_vehicles pv ON pv.plate = ov.plate
        LEFT JOIN mdt_vehicle_flags vf ON vf.plate = ov.plate AND ]] .. scopeClause(depName, 'mdt_vehicle_flags', 'vf.department') .. [[

        WHERE UPPER(ov.plate)=@p LIMIT 1
    ]], { ['@p'] = plate }, function(vrows)
        local function finish(row)
            local vehicle, owner
            if row then
                vehicle = { plate = row.plate, model_name = row.model_name, color = row.color, vtype = row.vtype,
                            stored = row.stored, wanted = row.wanted, wanted_reason = row.wanted_reason,
                            location = row.location, bought_at = row.bought_at }
                if row.owner_name then owner = { name = row.owner_name, identifier = row.owner_identifier } end
            else
                vehicle = { plate = plate, model_name = nil, wanted = false, location = 'circulation' }
            end
            MySQL.Async.fetchAll('SELECT * FROM mdt_fines WHERE plate=@p AND ' .. scopeClause(depName, 'mdt_fines') .. ' ORDER BY created_at DESC', { ['@p'] = plate }, function(fines)
                reply({ vehicle = vehicle, owner = owner, fines = fines or {} })
            end)
        end
        if vrows and vrows[1] then
            finish(buildVehicleRow(vrows[1]))
        else
            -- Pas dans owned_vehicles : peut-être en vente au concessionnaire.
            MySQL.Async.fetchAll([[
                SELECT o.plate, o.label, o.props, o.owner, p.characterInfos,
                       vf.wanted, vf.reason AS wanted_reason
                FROM concessionnaire_occasions o
                LEFT JOIN players p ON p.`boutique-id` = o.character_id
                LEFT JOIN mdt_vehicle_flags vf ON vf.plate = o.plate AND ]] .. scopeClause(depName, 'mdt_vehicle_flags', 'vf.department') .. [[

                WHERE UPPER(o.plate) = @p LIMIT 1
            ]], { ['@p'] = plate }, function(orows)
                finish(orows and orows[1] and buildOccasionRow(orows[1]) or nil)
            end)
        end
    end)
end

-- Liste des dossiers (option : type)
readHandlers.getReports = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_reports') then return reply(false) end
    local reportType = data.type
    local scope = scopeClause(depName, 'mdt_reports')
    if type(reportType) == 'string' and reportType ~= '' and reportType ~= 'all' then
        MySQL.Async.fetchAll('SELECT * FROM mdt_reports WHERE ' .. scope .. ' AND type=@t ORDER BY updated_at DESC LIMIT 100',
            { ['@t'] = reportType }, function(rows) reply(rows or {}) end)
    else
        MySQL.Async.fetchAll('SELECT * FROM mdt_reports WHERE ' .. scope .. ' ORDER BY updated_at DESC LIMIT 100',
            {}, function(rows) reply(rows or {}) end)
    end
end

-- Un dossier précis + preuves liées
readHandlers.getReport = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_reports') then return reply(false) end
    local reportId = tonumber(data.id)
    if not reportId then return reply(false) end
    MySQL.Async.fetchAll('SELECT * FROM mdt_reports WHERE id=@id AND ' .. scopeClause(depName, 'mdt_reports') .. ' LIMIT 1', { ['@id'] = reportId }, function(rows)
        if not rows or not rows[1] then return reply(false) end
        local report = rows[1]
        -- Seul l'auteur peut modifier titre/contenu/personnes. Un dossier
        -- rédigé par l'autre pôle est donc consultable, jamais modifiable.
        report.canEdit = (report.author_identifier == player.identifier)
        if mdtHasPerm(player, depName, grade, 'view_evidence') then
            MySQL.Async.fetchAll('SELECT * FROM mdt_report_evidence WHERE report_id=@id ORDER BY created_at DESC', { ['@id'] = reportId }, function(ev)
                report.evidence = ev or {}
                reply(report)
            end)
        else
            report.evidence = {}
            reply(report)
        end
    end)
end

-- Avis de recherche (option : status)
readHandlers.getWarrants = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_warrants') then return reply(false) end
    local status = (data.status == 'closed') and 'closed' or 'active'
    MySQL.Async.fetchAll('SELECT * FROM mdt_warrants WHERE ' .. scopeClause(depName, 'mdt_warrants') .. ' AND status=@s ORDER BY danger_level DESC, created_at DESC LIMIT 100',
        { ['@s'] = status }, function(rows) reply(rows or {}) end)
end

-- Historique des gardes à vue
readHandlers.getCustodyHistory = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'manage_custody') then return reply(false) end
    MySQL.Async.fetchAll('SELECT * FROM mdt_custody WHERE ' .. scopeClause(depName, 'mdt_custody') .. ' ORDER BY started_at DESC LIMIT 100',
        {}, function(rows) reply(rows or {}) end)
end

-- Preuves (option : case_id)
readHandlers.getEvidence = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_evidence') then return reply(false) end
    local caseId = tonumber(data.case_id)
    -- Les preuves restent propres à chaque pôle (Config.MDT.SharedTables) :
    -- chacun instruit ses propres scellés. Passer par scopeClause permet de
    -- basculer ce choix d'une seule ligne de config.
    local scope = scopeClause(depName, 'mdt_evidence')
    if caseId then
        MySQL.Async.fetchAll('SELECT * FROM mdt_evidence WHERE ' .. scope .. ' AND case_id=@c ORDER BY created_at DESC LIMIT 200',
            { ['@c'] = caseId }, function(rows) reply(rows or {}) end)
    else
        MySQL.Async.fetchAll('SELECT * FROM mdt_evidence WHERE ' .. scope .. ' ORDER BY created_at DESC LIMIT 200',
            {}, function(rows) reply(rows or {}) end)
    end
end

LSLegacy.RegisterServerEvent('mdt:query', function(payload)
    local src = source
    if type(payload) ~= 'table' or not payload.action then return end
    local reply = function(res)
        LSLegacy.SendEventToClient('mdt:queryResult', src, { reqId = payload.reqId, result = res })
    end
    local player, depName, grade = ctx(src)
    if not player then return reply(false) end
    local handler = readHandlers[payload.action]
    if not handler then return reply(false) end
    handler(player, depName, grade, type(payload.data) == 'table' and payload.data or {}, reply)
end)

--  ÉCRITURES (events tokenisés) — chaque nom est dans LSLegacy.RateLimit

-- Résout le `source` en ligne d'un personnage précis (pas juste son compte :
-- utile pour ouvrir le menu de paiement directement sur le joueur verbalisé).
local function GetOnlineSourceByCharacterId(charId)
    if not charId then return nil end
    for src, p in pairs(LSLegacy.Players.GetAll()) do
        if p["boutique-id"] == charId then return src end
    end
    return nil
end

LSLegacy.Bank.RegisterPaymentResultHandler('fine', function(refId, success)
    if not success then return end
    MySQL.Async.execute('UPDATE mdt_fines SET paid=1 WHERE id=@id', { ['@id'] = refId })
end)

-- Créer une amende
LSLegacy.RegisterServerEvent('mdt:createFine', function(data)
    local src = source
    local player, depName = can(src, 'create_fine')
    if not player or type(data) ~= 'table' then return end
    -- Deux entrées possibles : l'UI du MDT (data.identifier, déjà résolu via
    -- une recherche citoyen) ou l'action rapide ox_target (data.target, un
    -- source numérique — jamais un identifier client-fourni, revérifié ici).
    local identifier = type(data.identifier) == 'string' and data.identifier or nil
    if not identifier and data.target then
        local targetPlayer = LSLegacy.GetPlayerFromId(tonumber(data.target))
        identifier = targetPlayer and targetPlayer.identifier or nil
    end
    if not identifier then return result(src, false, 'Citoyen invalide.') end
    local amount = math.floor(tonumber(data.amount) or 0)
    if amount <= 0 or amount > L.MaxFine then return result(src, false, 'Montant invalide.') end
    local reason = safeText(data.reason, 255)
    if reason == '' then return result(src, false, 'Motif requis.') end
    local plate = safePlate(data.plate)
    resolveCitizenName(identifier, function(name)
        if not name then return result(src, false, 'Citoyen introuvable.') end
        LSLegacy.ResolveCharacterId(identifier, function(charId)
            MySQL.Async.insert('INSERT INTO mdt_fines (department, identifier, character_id, citizen_name, amount, reason, plate, officer_identifier, officer_character_id, officer_name) VALUES (@dep,@id,@charId,@name,@amount,@reason,@plate,@oid,@oCharId,@oname)', {
                ['@dep'] = depName, ['@id'] = identifier, ['@charId'] = charId, ['@name'] = name, ['@amount'] = amount,
                ['@reason'] = reason, ['@plate'] = plate, ['@oid'] = player.identifier, ['@oCharId'] = player["boutique-id"], ['@oname'] = charName(player),
            }, function(insertId)
                result(src, true, 'Amende de ' .. amount .. '$ enregistrée.', { view = 'citizen', id = identifier })
                mdtLog('Amende', ('**%s** a verbalisé **%s** : %d$\n%s'):format(charName(player), name, amount, reason))

                local targetSrc = GetOnlineSourceByCharacterId(charId)
                if targetSrc then
                    LSLegacy.Bank.OpenPaymentMenu(targetSrc, 'Amende - ' .. reason, amount, { meta = { type = 'fine', refId = insertId } })
                end
            end)
        end)
    end)
end)

-- Marquer une amende payée / impayée
LSLegacy.RegisterServerEvent('mdt:toggleFinePaid', function(data)
    local src = source
    local player, depName = can(src, 'create_fine')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    local paid = data.paid and 1 or 0
    MySQL.Async.execute('UPDATE mdt_fines SET paid=@p WHERE id=@id AND ' .. scopeClause(depName, 'mdt_fines'), { ['@p'] = paid, ['@id'] = id }, function()
        result(src, true, paid == 1 and 'Amende marquée payée.' or 'Amende marquée impayée.', { view = 'citizen', id = data.identifier })
    end)
end)

-- Supprimer une amende
LSLegacy.RegisterServerEvent('mdt:deleteFine', function(data)
    local src = source
    local player, depName = can(src, 'delete_records')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_fines WHERE id=@id AND ' .. scopeClause(depName, 'mdt_fines'), { ['@id'] = id }, function()
        result(src, true, 'Amende supprimée.', { view = 'citizen', id = data.identifier })
    end)
end)

-- Ajouter une entrée au casier judiciaire
LSLegacy.RegisterServerEvent('mdt:addCriminalRecord', function(data)
    local src = source
    local player, depName = can(src, 'manage_records')
    if not player or type(data) ~= 'table' then return end
    local identifier = type(data.identifier) == 'string' and data.identifier or nil
    if not identifier then return result(src, false, 'Citoyen invalide.') end
    local charge = safeText(data.charge, 255)
    if charge == '' then return result(src, false, "Chef d'accusation requis.") end
    local description = safeText(data.description, L.MaxTextLength)
    resolveCitizenName(identifier, function(name)
        if not name then return result(src, false, 'Citoyen introuvable.') end
        LSLegacy.ResolveCharacterId(identifier, function(charId)
            MySQL.Async.insert('INSERT INTO mdt_criminal_records (department, identifier, character_id, citizen_name, charge, description, officer_identifier, officer_character_id, officer_name) VALUES (@dep,@id,@charId,@name,@charge,@desc,@oid,@oCharId,@oname)', {
                ['@dep'] = depName, ['@id'] = identifier, ['@charId'] = charId, ['@name'] = name, ['@charge'] = charge,
                ['@desc'] = description, ['@oid'] = player.identifier, ['@oCharId'] = player["boutique-id"], ['@oname'] = charName(player),
            }, function()
                result(src, true, 'Entrée ajoutée au casier.', { view = 'citizen', id = identifier })
                mdtLog('Casier', ('**%s** a inscrit au casier de **%s** : %s'):format(charName(player), name, charge))
            end)
        end)
    end)
end)

-- Supprimer une entrée de casier
LSLegacy.RegisterServerEvent('mdt:deleteCriminalRecord', function(data)
    local src = source
    local player, depName = can(src, 'delete_records')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_criminal_records WHERE id=@id AND ' .. scopeClause(depName, 'mdt_criminal_records'), { ['@id'] = id }, function()
        result(src, true, 'Entrée de casier supprimée.', { view = 'citizen', id = data.identifier })
    end)
end)

-- Valide un type de dossier connu.
local function isValidReportType(t)
    for _, rt in ipairs(Config.MDT.ReportTypes) do if rt.id == t then return true end end
    return false
end

-- Nettoie/borne la liste des personnes impliquées d'un rapport.
local function sanitizeInvolved(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    for i, v in ipairs(list) do
        if i > 30 then break end
        if type(v) == 'table' then
            out[#out + 1] = {
                identifier = type(v.identifier) == 'string' and v.identifier:sub(1, 60) or nil,
                name = safeText(v.name, 100),
                role = safeText(v.role, 60),
            }
        end
    end
    return out
end

-- Créer une enquête. Seuls le titre et le contenu sont demandés : tout le
-- reste (rapports, preuves, armes, véhicules, personnes) se rattache
-- ensuite, au fil de l'instruction.
LSLegacy.RegisterServerEvent('mdt:createReport', function(data)
    local src = source
    local player, depName = can(src, 'create_report')
    if not player or type(data) ~= 'table' then return end
    local title = safeText(data.title, L.MaxTitleLength)
    if title == '' then return result(src, false, 'Titre requis.') end
    local content = safeText(data.content, L.MaxTextLength)
    MySQL.Async.insert("INSERT INTO mdt_reports (department, type, title, content, involved, author_identifier, author_name) VALUES (@dep,'enquete',@title,@content,'[]',@oid,@oname)", {
        ['@dep'] = depName, ['@title'] = title, ['@content'] = content,
        ['@oid'] = player.identifier, ['@oname'] = charName(player),
    }, function(id)
        -- On ouvre directement l'enquête créée : c'est là que l'agent va
        -- rattacher ses éléments.
        result(src, true, 'Enquête ouverte.', { view = 'report', id = id })
        mdtLog('Enquête', ('**%s** a ouvert une enquête : %s'):format(charName(player), title))
    end)
end)

-- Modifier une enquête (titre / contenu)
LSLegacy.RegisterServerEvent('mdt:updateReport', function(data)
    local src = source
    local player, depName = can(src, 'create_report')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    local title = safeText(data.title, L.MaxTitleLength)
    if title == '' then return result(src, false, 'Titre requis.') end
    local content = safeText(data.content, L.MaxTextLength)
    -- Seul le créateur de l'enquête peut en modifier le titre / contenu.
    MySQL.Async.fetchScalar('SELECT author_identifier FROM mdt_reports WHERE id=@id AND ' .. scopeClause(depName, 'mdt_reports') .. ' LIMIT 1', { ['@id'] = id }, function(author)
        if author ~= player.identifier then
            return result(src, false, "Seul l'auteur de l'enquête peut la modifier.")
        end
        MySQL.Async.execute('UPDATE mdt_reports SET title=@title, content=@content WHERE id=@id AND ' .. scopeClause(depName, 'mdt_reports'), {
            ['@title'] = title, ['@content'] = content, ['@id'] = id,
        }, function()
            result(src, true, 'Enquête mise à jour.', { view = 'report', id = id })
        end)
    end)
end)

--  RAPPORTS D'INTERVENTION
--  Le compte rendu qu'un agent rédige après une intervention. Il vit sa
--  propre vie : une enquête peut en agréger plusieurs, mais un rapport
--  existe sans enquête.

-- Liste de noms libres (agents engagés), une entrée par ligne côté NUI.
local function sanitizeNameList(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    for i, v in ipairs(list) do
        if i > 30 then break end
        local name = safeText(v, 100)
        if name ~= '' then out[#out + 1] = name end
    end
    return out
end

-- Liste des rapports + total des 30 derniers jours (affiché en tête d'onglet)
readHandlers.getInterventionReports = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_reports') then return reply(false) end
    local scope = scopeClause(depName, 'mdt_intervention_reports')
    local rtype = type(data.type) == 'string' and data.type or ''
    local clause, params = scope, {}
    if rtype ~= '' and rtype ~= 'all' and isValidReportType(rtype) then
        clause = clause .. ' AND type=@t'
        params['@t'] = rtype
    end
    MySQL.Async.fetchAll('SELECT * FROM mdt_intervention_reports WHERE ' .. clause
        .. ' ORDER BY created_at DESC LIMIT 100', params, function(rows)
        MySQL.Async.fetchScalar('SELECT COUNT(*) FROM mdt_intervention_reports WHERE ' .. scope
            .. ' AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)', {}, function(n)
            reply({ rows = rows or {}, last30 = tonumber(n) or 0 })
        end)
    end)
end

-- Un rapport précis
readHandlers.getInterventionReport = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_reports') then return reply(false) end
    local id = tonumber(data.id)
    if not id then return reply(false) end
    MySQL.Async.fetchAll('SELECT * FROM mdt_intervention_reports WHERE id=@id AND '
        .. scopeClause(depName, 'mdt_intervention_reports') .. ' LIMIT 1', { ['@id'] = id }, function(rows)
        if not rows or not rows[1] then return reply(false) end
        local r = rows[1]
        -- Un rapport rédigé par l'autre pôle reste consultable, jamais
        -- modifiable : seul son auteur y touche.
        r.canEdit = (r.author_identifier == player.identifier)
        reply(r)
    end)
end

LSLegacy.RegisterServerEvent('mdt:createInterventionReport', function(data)
    local src = source
    local player, depName = can(src, 'create_report')
    if not player or type(data) ~= 'table' then return end
    local rtype = type(data.type) == 'string' and data.type or ''
    if not isValidReportType(rtype) then return result(src, false, "Type d'intervention invalide.") end
    local content = safeText(data.content, L.MaxTextLength)
    if content == '' then return result(src, false, 'Compte rendu requis.') end
    MySQL.Async.insert('INSERT INTO mdt_intervention_reports (department, type, content, agents, involved, joint, author_identifier, author_name) '
        .. 'VALUES (@dep,@t,@content,@agents,@involved,@joint,@oid,@oname)', {
        ['@dep'] = depName, ['@t'] = rtype, ['@content'] = content,
        ['@agents'] = json.encode(sanitizeNameList(data.agents)),
        ['@involved'] = json.encode(sanitizeInvolved(data.involved)),
        ['@joint'] = data.joint and 1 or 0,
        ['@oid'] = player.identifier, ['@oname'] = charName(player),
    }, function(id)
        result(src, true, "Rapport d'intervention enregistré.", { view = 'int_reports' })
        mdtLog("Rapport d'intervention",
            ('**%s** a enregistré un rapport [%s]%s'):format(charName(player), rtype,
                data.joint and ' — intervention conjointe' or ''))
    end)
end)

LSLegacy.RegisterServerEvent('mdt:updateInterventionReport', function(data)
    local src = source
    local player, depName = can(src, 'create_report')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    local rtype = type(data.type) == 'string' and data.type or ''
    if not isValidReportType(rtype) then return result(src, false, "Type d'intervention invalide.") end
    local content = safeText(data.content, L.MaxTextLength)
    if content == '' then return result(src, false, 'Compte rendu requis.') end
    MySQL.Async.fetchScalar('SELECT author_identifier FROM mdt_intervention_reports WHERE id=@id AND '
        .. scopeClause(depName, 'mdt_intervention_reports') .. ' LIMIT 1', { ['@id'] = id }, function(author)
        if author ~= player.identifier then
            return result(src, false, "Seul l'auteur du rapport peut le modifier.")
        end
        MySQL.Async.execute('UPDATE mdt_intervention_reports SET type=@t, content=@content, agents=@agents, '
            .. 'involved=@involved, joint=@joint WHERE id=@id AND '
            .. scopeClause(depName, 'mdt_intervention_reports'), {
            ['@t'] = rtype, ['@content'] = content,
            ['@agents'] = json.encode(sanitizeNameList(data.agents)),
            ['@involved'] = json.encode(sanitizeInvolved(data.involved)),
            ['@joint'] = data.joint and 1 or 0, ['@id'] = id,
        }, function()
            result(src, true, 'Rapport mis à jour.', { view = 'int_report', id = id })
        end)
    end)
end)

LSLegacy.RegisterServerEvent('mdt:deleteInterventionReport', function(data)
    local src = source
    local player, depName = can(src, 'delete_records')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_intervention_reports WHERE id=@id AND '
        .. scopeClause(depName, 'mdt_intervention_reports'), { ['@id'] = id }, function()
        -- Le rapport disparaît aussi des enquêtes qui le référençaient, et
        -- de ses propres armes / véhicules associés.
        MySQL.Async.execute("DELETE FROM mdt_case_links WHERE kind='report' AND ref=@ref",
            { ['@ref'] = tostring(id) })
        MySQL.Async.execute('DELETE FROM mdt_report_links WHERE report_id=@id', { ['@id'] = id }, function()
            result(src, true, 'Rapport supprimé.', { view = 'int_reports' })
        end)
    end)
end)

--  ARMES ET VÉHICULES ASSOCIÉS À UN RAPPORT D'INTERVENTION
--  Même permission que la rédaction du rapport (create_report) : il ne
--  s'agit pas de gérer des scellés (ça, c'est le rôle du Labo / PTS),
--  mais de documenter ce qui a été porté ou utilisé pendant l'intervention.

readHandlers.getReportLinks = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_reports') then return reply(false) end
    local reportId = tonumber(data.reportId)
    if not reportId then return reply(false) end
    local out = { weapons = {}, vehicles = {} }

    local function loadVehicles()
        MySQL.Async.fetchAll([[
            SELECT l.id, l.ref, l.linked_by_name, l.created_at,
                   ov.type, ov.stored, ov.owner, pv.model, pv.tuning, p.characterInfos
            FROM mdt_report_links l
            LEFT JOIN owned_vehicles ov ON ov.plate = l.ref
            LEFT JOIN persistent_vehicles pv ON pv.plate = l.ref
            LEFT JOIN players p ON p.`boutique-id` = ov.character_id
            WHERE l.report_id = @id AND l.kind = 'vehicle'
            ORDER BY l.created_at DESC
        ]], { ['@id'] = reportId }, function(rows)
            for _, r in ipairs(rows or {}) do
                r.plate = r.ref
                local v = buildVehicleRow(r)
                v.id = r.id
                v.linked_by_name = r.linked_by_name
                out.vehicles[#out.vehicles + 1] = v
            end
            reply(out)
        end)
    end

    MySQL.Async.fetchAll([[
        SELECT l.id, l.linked_by_name, l.created_at,
               w.id AS weapon_id, w.serial_number, w.category, w.model, w.seized
        FROM mdt_report_links l
        JOIN mdt_weapons w ON w.id = CAST(l.ref AS UNSIGNED)
        WHERE l.report_id = @id AND l.kind = 'weapon' AND ]] .. scopeClause(depName, 'mdt_weapons', 'w.department') .. [[

        ORDER BY l.created_at DESC
    ]], { ['@id'] = reportId }, function(rows)
        out.weapons = rows or {}
        loadVehicles()
    end)
end

LSLegacy.RegisterServerEvent('mdt:linkReportItem', function(data)
    local src = source
    local player, depName = can(src, 'create_report')
    if not player or type(data) ~= 'table' then return end
    local reportId = tonumber(data.reportId)
    local kind = type(data.kind) == 'string' and data.kind or ''
    if not reportId or (kind ~= 'weapon' and kind ~= 'vehicle') then return end

    -- Le rapport doit exister dans la portée du demandeur avant tout ajout.
    MySQL.Async.fetchScalar('SELECT id FROM mdt_intervention_reports WHERE id=@id AND '
        .. scopeClause(depName, 'mdt_intervention_reports') .. ' LIMIT 1', { ['@id'] = reportId }, function(found)
        if not found then return result(src, false, 'Rapport introuvable.') end

        if kind == 'weapon' then
            local serial = type(data.ref) == 'string' and data.ref:upper():gsub('[^A-Z0-9]', '') or ''
            if serial == '' then return result(src, false, 'Numéro de série requis.') end
            MySQL.Async.fetchAll('SELECT id FROM mdt_weapons WHERE serial_number=@s AND '
                .. scopeClause(depName, 'mdt_weapons') .. ' LIMIT 1', { ['@s'] = serial }, function(rows)
                if not rows or not rows[1] then return result(src, false, 'Aucune arme avec ce numéro de série.') end
                MySQL.Async.execute('INSERT IGNORE INTO mdt_report_links (report_id, kind, ref, linked_by, linked_by_name) '
                    .. "VALUES (@r,'weapon',@ref,@by,@byname)", {
                    ['@r'] = reportId, ['@ref'] = tostring(rows[1].id),
                    ['@by'] = player.identifier, ['@byname'] = charName(player),
                }, function() result(src, true, 'Arme associée au rapport.', { view = 'int_report', id = reportId }) end)
            end)
        else -- vehicle
            local plate = safePlate(data.ref)
            if not plate then return result(src, false, 'Plaque invalide.') end
            MySQL.Async.execute('INSERT IGNORE INTO mdt_report_links (report_id, kind, ref, linked_by, linked_by_name) '
                .. "VALUES (@r,'vehicle',@ref,@by,@byname)", {
                ['@r'] = reportId, ['@ref'] = plate,
                ['@by'] = player.identifier, ['@byname'] = charName(player),
            }, function() result(src, true, 'Véhicule associé au rapport.', { view = 'int_report', id = reportId }) end)
        end
    end)
end)

LSLegacy.RegisterServerEvent('mdt:unlinkReportItem', function(data)
    local src = source
    local player, depName = can(src, 'create_report')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    local reportId = tonumber(data.reportId)
    if not id or not reportId then return end
    MySQL.Async.execute('DELETE FROM mdt_report_links WHERE id=@id AND report_id=@r',
        { ['@id'] = id, ['@r'] = reportId }, function()
        result(src, true, 'Élément retiré.', { view = 'int_report', id = reportId })
    end)
end)

-- Supprimer une enquête (et ses rattachements, qui n'ont plus d'objet)
LSLegacy.RegisterServerEvent('mdt:deleteReport', function(data)
    local src = source
    local player, depName = can(src, 'delete_records')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_reports WHERE id=@id AND ' .. scopeClause(depName, 'mdt_reports'), { ['@id'] = id }, function()
        MySQL.Async.execute('DELETE FROM mdt_case_links WHERE case_id=@id', { ['@id'] = id })
        MySQL.Async.execute('DELETE FROM mdt_report_evidence WHERE report_id=@id', { ['@id'] = id })
        MySQL.Async.execute('DELETE FROM mdt_weapon_reports WHERE report_id=@id', { ['@id'] = id }, function()
            result(src, true, 'Enquête supprimée.', { view = 'reports' })
        end)
    end)
end)

--  ÉLÉMENTS RATTACHÉS À UNE ENQUÊTE (rapports, véhicules, personnes)
--
--  Seule la référence est stockée ; le libellé est résolu ici par
--  jointure. Une plaque qui change de propriétaire ou un rapport qui est
--  corrigé se reflètent donc immédiatement dans l'enquête.
--  Les preuves et les armes passent par leurs tables dédiées.

local CASE_LINK_KINDS = { report = true, vehicle = true, person = true }

readHandlers.getCaseLinks = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_reports') then return reply(false) end
    local caseId = tonumber(data.caseId)
    if not caseId then return reply(false) end
    local out = { reports = {}, vehicles = {}, persons = {} }

    local function loadPersons()
        MySQL.Async.fetchAll([[
            SELECT l.id, l.ref, l.note, l.linked_by_name, l.created_at, p.characterInfos
            FROM mdt_case_links l
            LEFT JOIN players p ON p.identifier = l.ref
            WHERE l.case_id = @id AND l.kind = 'person'
            ORDER BY l.created_at DESC
        ]], { ['@id'] = caseId }, function(rows)
            for _, r in ipairs(rows or {}) do
                local name
                if r.characterInfos then
                    local ok, info = pcall(json.decode, r.characterInfos)
                    if ok and type(info) == 'table' then
                        name = ((info.Prenom or '') .. ' ' .. (info.NDF or '')):gsub('^%s+', ''):gsub('%s+$', '')
                    end
                end
                out.persons[#out.persons + 1] = {
                    id = r.id, identifier = r.ref, note = r.note,
                    name = (name and name ~= '') and name or 'Citoyen inconnu',
                    linked_by_name = r.linked_by_name, created_at = r.created_at,
                }
            end
            reply(out)
        end)
    end

    local function loadVehicles()
        MySQL.Async.fetchAll([[
            SELECT l.id, l.ref, l.note, l.linked_by_name, l.created_at,
                   ov.type, ov.stored, ov.owner, pv.model, pv.tuning, p.characterInfos
            FROM mdt_case_links l
            LEFT JOIN owned_vehicles ov ON ov.plate = l.ref
            LEFT JOIN persistent_vehicles pv ON pv.plate = l.ref
            LEFT JOIN players p ON p.`boutique-id` = ov.character_id
            WHERE l.case_id = @id AND l.kind = 'vehicle'
            ORDER BY l.created_at DESC
        ]], { ['@id'] = caseId }, function(rows)
            for _, r in ipairs(rows or {}) do
                r.plate = r.ref
                local v = buildVehicleRow(r)
                v.id = r.id
                v.note = r.note
                v.linked_by_name = r.linked_by_name
                v.created_at = r.created_at
                out.vehicles[#out.vehicles + 1] = v
            end
            loadPersons()
        end)
    end

    -- Le rapport est lu dans la portée du demandeur : un rapport devenu
    -- inaccessible n'est pas remonté, mais le lien reste (il redeviendra
    -- visible si la configuration de partage change).
    MySQL.Async.fetchAll('SELECT l.id, l.ref, l.note, l.linked_by_name, l.created_at, '
        .. 'r.type, r.content, r.author_name, r.department, r.joint, r.created_at AS report_at '
        .. 'FROM mdt_case_links l '
        .. 'JOIN mdt_intervention_reports r ON r.id = CAST(l.ref AS UNSIGNED) '
        .. "WHERE l.case_id = @id AND l.kind = 'report' AND "
        .. scopeClause(depName, 'mdt_intervention_reports', 'r.department')
        .. ' ORDER BY r.created_at DESC', { ['@id'] = caseId }, function(rows)
        out.reports = rows or {}
        loadVehicles()
    end)
end

-- Rattacher un élément à l'enquête
LSLegacy.RegisterServerEvent('mdt:linkCaseItem', function(data)
    local src = source
    local player, depName = can(src, 'create_report')
    if not player or type(data) ~= 'table' then return end
    local caseId = tonumber(data.caseId)
    local kind = type(data.kind) == 'string' and data.kind or ''
    if not caseId or not CASE_LINK_KINDS[kind] then return end
    local note = safeText(data.note, 120)

    local function insert(ref, label)
        MySQL.Async.execute('INSERT IGNORE INTO mdt_case_links (case_id, kind, ref, note, linked_by, linked_by_name) '
            .. 'VALUES (@c,@k,@r,@n,@by,@byname)', {
            ['@c'] = caseId, ['@k'] = kind, ['@r'] = ref, ['@n'] = (note ~= '' and note or nil),
            ['@by'] = player.identifier, ['@byname'] = charName(player),
        }, function()
            result(src, true, label .. ' rattaché(e) à l\'enquête.', { view = 'report', id = caseId })
        end)
    end

    -- L'enquête doit exister dans la portée du demandeur avant tout ajout.
    MySQL.Async.fetchScalar('SELECT id FROM mdt_reports WHERE id=@id AND '
        .. scopeClause(depName, 'mdt_reports') .. ' LIMIT 1', { ['@id'] = caseId }, function(found)
        if not found then return result(src, false, 'Enquête introuvable.') end

        if kind == 'report' then
            local rid = tonumber(data.ref)
            if not rid then return result(src, false, 'Rapport invalide.') end
            MySQL.Async.fetchScalar('SELECT id FROM mdt_intervention_reports WHERE id=@id AND '
                .. scopeClause(depName, 'mdt_intervention_reports') .. ' LIMIT 1', { ['@id'] = rid }, function(ok)
                if not ok then return result(src, false, 'Rapport introuvable.') end
                insert(tostring(rid), 'Rapport')
            end)

        elseif kind == 'vehicle' then
            local plate = safePlate(data.ref)
            if not plate then return result(src, false, 'Plaque invalide.') end
            -- Un véhicule non immatriculé en base reste rattachable : il
            -- peut s'agir d'un véhicule croisé en patrouille.
            insert(plate, 'Véhicule')

        else -- person
            local identifier = type(data.ref) == 'string' and data.ref or ''
            if identifier == '' then return result(src, false, 'Citoyen invalide.') end
            resolveCitizenName(identifier, function(name)
                if not name then return result(src, false, 'Citoyen introuvable.') end
                insert(identifier:sub(1, 60), 'Personne')
            end)
        end
    end)
end)

-- Détacher un élément de l'enquête
LSLegacy.RegisterServerEvent('mdt:unlinkCaseItem', function(data)
    local src = source
    local player, depName = can(src, 'create_report')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    local caseId = tonumber(data.caseId)
    if not id or not caseId then return end
    MySQL.Async.execute('DELETE FROM mdt_case_links WHERE id=@id AND case_id=@c',
        { ['@id'] = id, ['@c'] = caseId }, function()
        result(src, true, 'Élément détaché.', { view = 'report', id = caseId })
    end)
end)

-- Créer un avis de recherche
LSLegacy.RegisterServerEvent('mdt:createWarrant', function(data)
    local src = source
    local player, depName = can(src, 'manage_warrants')
    if not player or type(data) ~= 'table' then return end
    local reason = safeText(data.reason, L.MaxTextLength)
    if reason == '' then return result(src, false, 'Motif requis.') end
    local danger = math.floor(tonumber(data.danger_level) or 1)
    if danger < 1 or danger > 3 then danger = 1 end
    local identifier = type(data.identifier) == 'string' and data.identifier ~= '' and data.identifier or nil
    local function insert(name, charId)
        local finalName = (name and name ~= '') and name or safeText(data.citizen_name, 100)
        if finalName == '' then finalName = 'Individu non identifié' end
        MySQL.Async.insert("INSERT INTO mdt_warrants (department, identifier, character_id, citizen_name, reason, danger_level, status, author_identifier, author_character_id, author_name) VALUES (@dep,@id,@charId,@name,@reason,@danger,'active',@oid,@oCharId,@oname)", {
            ['@dep'] = depName, ['@id'] = identifier, ['@charId'] = charId, ['@name'] = finalName,
            ['@reason'] = reason, ['@danger'] = danger, ['@oid'] = player.identifier, ['@oCharId'] = player["boutique-id"], ['@oname'] = charName(player),
        }, function()
            result(src, true, 'Avis de recherche créé.', { view = 'warrants' })
            mdtLog('Avis de recherche', ('**%s** a émis un avis (niveau %d) : %s'):format(charName(player), danger, finalName))
        end)
    end
    if identifier then
        resolveCitizenName(identifier, function(n)
            LSLegacy.ResolveCharacterId(identifier, function(charId) insert(n, charId) end)
        end)
    else
        insert(nil, nil)
    end
end)

-- Modifier un avis de recherche
LSLegacy.RegisterServerEvent('mdt:updateWarrant', function(data)
    local src = source
    local player, depName = can(src, 'manage_warrants')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    local reason = safeText(data.reason, L.MaxTextLength)
    local danger = math.floor(tonumber(data.danger_level) or 1)
    if danger < 1 or danger > 3 then danger = 1 end
    local status = (data.status == 'closed') and 'closed' or 'active'
    local identifier = type(data.identifier) == 'string' and data.identifier ~= '' and data.identifier or nil
    local function upd(name, charId)
        local finalName = (name and name ~= '') and name or safeText(data.citizen_name, 100)
        if finalName == '' then finalName = 'Individu non identifié' end
        MySQL.Async.execute('UPDATE mdt_warrants SET reason=@reason, danger_level=@danger, status=@status, identifier=@wid_ident, character_id=@charId, citizen_name=@name WHERE id=@id AND ' .. scopeClause(depName, 'mdt_warrants'), {
            ['@reason'] = reason, ['@danger'] = danger, ['@status'] = status,
            ['@wid_ident'] = identifier, ['@charId'] = charId, ['@name'] = finalName, ['@id'] = id,
        }, function()
            result(src, true, 'Avis de recherche mis à jour.', { view = 'warrants' })
        end)
    end
    if identifier then
        resolveCitizenName(identifier, function(n)
            LSLegacy.ResolveCharacterId(identifier, function(charId) upd(n, charId) end)
        end)
    else
        upd(nil, nil)
    end
end)

-- Supprimer un avis de recherche
LSLegacy.RegisterServerEvent('mdt:deleteWarrant', function(data)
    local src = source
    local player, depName = can(src, 'manage_warrants')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_warrants WHERE id=@id AND ' .. scopeClause(depName, 'mdt_warrants'), { ['@id'] = id }, function()
        result(src, true, 'Avis de recherche supprimé.', { view = 'warrants' })
    end)
end)

-- Marquer / lever "recherché par les autorités" sur un véhicule (par plaque)
LSLegacy.RegisterServerEvent('mdt:setVehicleWanted', function(data)
    local src = source
    local player, depName = can(src, 'manage_warrants')
    if not player or type(data) ~= 'table' then return end
    local plate = safePlate(data.plate)
    if not plate then return result(src, false, 'Plaque invalide.') end
    local wanted = data.wanted and 1 or 0
    local reason = safeText(data.reason, 255)
    MySQL.Async.execute([[
        INSERT INTO mdt_vehicle_flags (plate, department, wanted, reason, officer_identifier, officer_name)
        VALUES (@plate, @dep, @wanted, @reason, @oid, @oname)
        ON DUPLICATE KEY UPDATE wanted=@wanted, reason=@reason, officer_identifier=@oid, officer_name=@oname
    ]], {
        ['@plate'] = plate, ['@dep'] = depName, ['@wanted'] = wanted, ['@reason'] = reason,
        ['@oid'] = player.identifier, ['@oname'] = charName(player),
    }, function()
        result(src, true, wanted == 1 and 'Véhicule signalé recherché.' or 'Recherche levée.', { view = 'vehicle', id = plate })
    end)
end)

-- Définir la localisation administrative d'un véhicule
local VEHICLE_LOCATIONS = { circulation = true, concessionnaire = true, saisie = true, detruit = true }
LSLegacy.RegisterServerEvent('mdt:setVehicleLocation', function(data)
    local src = source
    local player, depName = can(src, 'manage_warrants')
    if not player or type(data) ~= 'table' then return end
    local plate = safePlate(data.plate)
    if not plate then return result(src, false, 'Plaque invalide.') end
    local loc = type(data.location) == 'string' and data.location or ''
    if not VEHICLE_LOCATIONS[loc] then return result(src, false, 'Localisation invalide.') end
    MySQL.Async.execute([[
        INSERT INTO mdt_vehicle_flags (plate, department, location, officer_identifier, officer_name)
        VALUES (@plate, @dep, @loc, @oid, @oname)
        ON DUPLICATE KEY UPDATE location=@loc, officer_identifier=@oid, officer_name=@oname
    ]], {
        ['@plate'] = plate, ['@dep'] = depName, ['@loc'] = loc,
        ['@oid'] = player.identifier, ['@oname'] = charName(player),
    }, function()
        result(src, true, 'Localisation mise à jour.', { view = 'vehicle', id = plate })
    end)
end)

-- Enregistrer une garde à vue (mise en cellule = système physique à venir ;
-- ici enregistrement + procès-verbal, persistants)
LSLegacy.RegisterServerEvent('mdt:createCustody', function(data)
    local src = source
    local player, depName = can(src, 'manage_custody')
    if not player or type(data) ~= 'table' then return end
    local identifier = type(data.identifier) == 'string' and data.identifier or nil
    if not identifier then return result(src, false, 'Citoyen invalide.') end
    local reason = safeText(data.reason, L.MaxTextLength)
    local duration = math.max(0, math.min(1440, math.floor(tonumber(data.duration) or 0)))
    local pv = safeText(data.pv, L.MaxTextLength)
    resolveCitizenName(identifier, function(name)
        if not name then return result(src, false, 'Citoyen introuvable.') end
        LSLegacy.ResolveCharacterId(identifier, function(charId)
            MySQL.Async.insert('INSERT INTO mdt_custody (department, identifier, character_id, citizen_name, reason, duration, pv, officer_identifier, officer_character_id, officer_name, ends_at) VALUES (@dep,@id,@charId,@name,@reason,@dur,@pv,@oid,@oCharId,@oname, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL @dur MINUTE))', {
                ['@dep'] = depName, ['@id'] = identifier, ['@charId'] = charId, ['@name'] = name, ['@reason'] = reason,
                ['@dur'] = duration, ['@pv'] = pv, ['@oid'] = player.identifier, ['@oCharId'] = player["boutique-id"], ['@oname'] = charName(player),
            }, function()
                result(src, true, 'Garde à vue enregistrée.', { view = 'citizen', id = identifier })
                mdtLog('Garde à vue', ('**%s** a placé **%s** en GAV (%d min)'):format(charName(player), name, duration))
            end)
        end)
    end)
end)

-- Ajouter une preuve (collecte physique à venir ; table prête pour persistance)
LSLegacy.RegisterServerEvent('mdt:addEvidence', function(data)
    local src = source
    local player, depName = can(src, 'manage_evidence')
    if not player or type(data) ~= 'table' then return end
    local etype = type(data.type) == 'string' and data.type or ''
    local valid = { empreinte = true, adn = true, sang = true, scene = true }
    if not valid[etype] then return result(src, false, 'Type de preuve invalide.') end
    local label = safeText(data.label, 255)
    local caseId = tonumber(data.case_id)
    local identifier = type(data.identifier) == 'string' and data.identifier ~= '' and data.identifier or nil
    local function insert(charId)
        MySQL.Async.insert("INSERT INTO mdt_evidence (department, case_id, type, label, data, status, identifier, character_id, collected_by, collected_by_name) VALUES (@dep,@case,@type,@label,@data,'collected',@id,@charId,@cid,@cname)", {
            ['@dep'] = depName, ['@case'] = caseId, ['@type'] = etype, ['@label'] = label,
            ['@data'] = json.encode(type(data.data) == 'table' and data.data or {}),
            ['@id'] = identifier, ['@charId'] = charId, ['@cid'] = player.identifier, ['@cname'] = charName(player),
        }, function()
            result(src, true, 'Preuve enregistrée.', { view = 'evidence', id = caseId })
        end)
    end
    if identifier then LSLegacy.ResolveCharacterId(identifier, insert) else insert(nil) end
end)

--  Nouvelles queries police — empreintes, ADN

-- Comparaison empreintes
-- Preuves enrichies (union police_fingerprints + police_dna + police_blood_traces)
readHandlers.getEvidence = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_evidence') then return reply(false) end
    MySQL.Async.fetchAll([[
        SELECT 'fingerprint' AS type, ref, identifier, citizen_name,
               COALESCE(description,'') AS description,
               CONCAT('Empreintes — ', citizen_name) AS label,
               officer_name, scene_id, created_at
        FROM police_fingerprints
        UNION ALL
        SELECT 'dna', ref, identifier, citizen_name,
               COALESCE(description,''),
               CONCAT('ADN — ', citizen_name),
               officer_name, scene_id, created_at
        FROM police_dna
        UNION ALL
        SELECT 'blood', ref, NULL, '',
               COALESCE(description,''),
               CONCAT('Sang — X:', ROUND(x,1), ' Y:', ROUND(y,1)),
               officer_name, scene_id, created_at
        FROM police_blood_traces
        ORDER BY created_at DESC
        LIMIT 200
    ]], {}, function(rows) reply(rows or {}) end)
end

--  ARMES — registre, liaisons personnes/dossiers, saisies

-- Génère un numéro de série unique (vérifié contre mdt_weapons).
local function generateUniqueSerial(cb, attempts)
    attempts = attempts or 0
    local serial = LSLegacy.GenerateNumeroDeSerie()
    MySQL.Async.fetchScalar('SELECT id FROM mdt_weapons WHERE serial_number=@s LIMIT 1', { ['@s'] = serial }, function(existing)
        if existing and attempts < 10 then
            generateUniqueSerial(cb, attempts + 1)
        else
            cb(serial)
        end
    end)
end

-- Recherche d'armes (numéro de série ou modèle ; option seized)
readHandlers.searchWeapons = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_weapons') then return reply(false) end
    local query = type(data.query) == 'string' and data.query or ''
    local like = '%' .. query:upper():gsub('[%%_\\]', '') .. '%'
    local limit = math.floor(L.MaxSearchResults)
    local seizedClause = data.seized == true and ' AND seized=1' or ''
    MySQL.Async.fetchAll(
        "SELECT id, serial_number, category, model, seized, status FROM mdt_weapons " ..
        "WHERE " .. scopeClause(depName, 'mdt_weapons') .. seizedClause .. " AND (UPPER(serial_number) LIKE @q OR UPPER(model) LIKE @q) " ..
        "ORDER BY created_at DESC LIMIT " .. limit,
        { ['@q'] = like }, function(rows) reply(rows or {}) end)
end

-- Fiche complète d'une arme + personnes + dossiers liés
readHandlers.getWeapon = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_weapons') then return reply(false) end
    local id = tonumber(data.id)
    if not id then return reply(false) end
    MySQL.Async.fetchAll('SELECT * FROM mdt_weapons WHERE id=@id AND ' .. scopeClause(depName, 'mdt_weapons') .. ' LIMIT 1', { ['@id'] = id }, function(wrows)
        if not wrows or not wrows[1] then return reply(false) end
        local weapon = wrows[1]
        MySQL.Async.fetchAll('SELECT * FROM mdt_weapon_persons WHERE weapon_id=@id ORDER BY created_at DESC', { ['@id'] = id }, function(persons)
            MySQL.Async.fetchAll([[
                SELECT wr.id AS link_id, r.id AS report_id, r.type, r.title, r.created_at
                FROM mdt_weapon_reports wr
                JOIN mdt_reports r ON r.id = wr.report_id
                WHERE wr.weapon_id=@id ORDER BY r.updated_at DESC
            ]], { ['@id'] = id }, function(reports)
                reply({ weapon = weapon, persons = persons or {}, reports = reports or {} })
            end)
        end)
    end)
end

-- Armes liées à une personne (fiche citoyen)
readHandlers.getPersonWeapons = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_weapons') then return reply({}) end
    local identifier = type(data.identifier) == 'string' and data.identifier or ''
    if identifier == '' then return reply({}) end
    MySQL.Async.fetchAll([[
        SELECT w.id, w.serial_number, w.category, w.model, w.seized, wp.relation
        FROM mdt_weapon_persons wp
        JOIN mdt_weapons w ON w.id = wp.weapon_id
        WHERE wp.identifier=@id AND ]] .. scopeClause(depName, 'mdt_weapons', 'w.department') .. [[

        ORDER BY wp.created_at DESC
    ]], { ['@id'] = identifier }, function(rows) reply(rows or {}) end)
end

-- Armes liées à un dossier (fiche dossier)
readHandlers.getReportWeapons = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_reports') then return reply({}) end
    local reportId = tonumber(data.reportId)
    if not reportId then return reply({}) end
    MySQL.Async.fetchAll([[
        SELECT w.id, w.serial_number, w.category, w.model, w.seized
        FROM mdt_weapon_reports wr
        JOIN mdt_weapons w ON w.id = wr.weapon_id
        WHERE wr.report_id=@rid AND ]] .. scopeClause(depName, 'mdt_weapons', 'w.department') .. [[

        ORDER BY wr.created_at DESC
    ]], { ['@rid'] = reportId }, function(rows) reply(rows or {}) end)
end

-- Enregistrer une arme (numéro de série auto pour les armes à feu)
LSLegacy.RegisterServerEvent('mdt:registerWeapon', function(data)
    local src = source
    local player, depName = can(src, 'manage_weapons')
    if not player or type(data) ~= 'table' then return end
    local category = (data.category == 'melee') and 'melee' or 'firearm'
    local model = safeText(data.model, 120)
    if model == '' then return result(src, false, 'Désignation requise.') end
    local notes = safeText(data.notes, L.MaxTextLength)

    local function insert(serial)
        MySQL.Async.insert('INSERT INTO mdt_weapons (department, serial_number, category, model, notes, registered_by, registered_by_name) VALUES (@dep,@serial,@cat,@model,@notes,@oid,@oname)', {
            ['@dep'] = depName, ['@serial'] = serial, ['@cat'] = category, ['@model'] = model,
            ['@notes'] = notes, ['@oid'] = player.identifier, ['@oname'] = charName(player),
        }, function()
            result(src, true, serial and ('Arme enregistrée (n° ' .. serial .. ').') or 'Arme enregistrée.', { view = 'weapons' })
            mdtLog('Arme', ('**%s** a enregistré une arme : %s%s'):format(charName(player), model, serial and (' — ' .. serial) or ''))
        end)
    end

    if category == 'firearm' then
        local provided = type(data.serial) == 'string' and data.serial:upper():gsub('[^A-Z0-9]', '') or ''
        if provided ~= '' then
            MySQL.Async.fetchScalar('SELECT id FROM mdt_weapons WHERE serial_number=@s LIMIT 1', { ['@s'] = provided }, function(existing)
                if existing then return result(src, false, 'Ce numéro de série existe déjà.') end
                insert(provided)
            end)
        else
            generateUniqueSerial(function(serial) insert(serial) end)
        end
    else
        insert(nil)
    end
end)

-- Modifier une arme (désignation / notes)
LSLegacy.RegisterServerEvent('mdt:updateWeapon', function(data)
    local src = source
    local player, depName = can(src, 'manage_weapons')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    local model = safeText(data.model, 120)
    if model == '' then return result(src, false, 'Désignation requise.') end
    MySQL.Async.execute('UPDATE mdt_weapons SET model=@model, notes=@notes WHERE id=@id AND ' .. scopeClause(depName, 'mdt_weapons'), {
        ['@model'] = model, ['@notes'] = safeText(data.notes, L.MaxTextLength), ['@id'] = id,
    }, function() result(src, true, 'Arme mise à jour.', { view = 'weapon', id = id }) end)
end)

-- Supprimer une arme + ses liaisons
LSLegacy.RegisterServerEvent('mdt:deleteWeapon', function(data)
    local src = source
    local player, depName = can(src, 'manage_weapons')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_weapons WHERE id=@id AND ' .. scopeClause(depName, 'mdt_weapons'), { ['@id'] = id }, function()
        MySQL.Async.execute('DELETE FROM mdt_weapon_persons WHERE weapon_id=@id', { ['@id'] = id })
        MySQL.Async.execute('DELETE FROM mdt_weapon_reports WHERE weapon_id=@id', { ['@id'] = id })
        result(src, true, 'Arme supprimée.', { view = 'weapons' })
    end)
end)

-- Saisir / relâcher une arme (pièce à conviction)
LSLegacy.RegisterServerEvent('mdt:seizeWeapon', function(data)
    local src = source
    local player, depName = can(src, 'manage_weapons')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    if data.seized then
        MySQL.Async.execute("UPDATE mdt_weapons SET seized=1, status='seized', seized_case_id=@case, seized_by=@oid, seized_by_name=@oname, seized_at=CURRENT_TIMESTAMP WHERE id=@id AND " .. scopeClause(depName, 'mdt_weapons'), {
            ['@case'] = tonumber(data.caseId), ['@oid'] = player.identifier, ['@oname'] = charName(player), ['@id'] = id,
        }, function() result(src, true, 'Arme placée sous scellés.', { view = 'weapon', id = id }) end)
    else
        MySQL.Async.execute("UPDATE mdt_weapons SET seized=0, status='registered', seized_case_id=NULL, seized_by=NULL, seized_by_name=NULL, seized_at=NULL WHERE id=@id AND " .. scopeClause(depName, 'mdt_weapons'), {
            ['@id'] = id,
        }, function() result(src, true, 'Arme retirée des scellés.', { view = 'weapon', id = id }) end)
    end
end)

-- Lier une personne à une arme
LSLegacy.RegisterServerEvent('mdt:linkWeaponPerson', function(data)
    local src = source
    local player, depName = can(src, 'manage_weapons')
    if not player or type(data) ~= 'table' then return end
    local weaponId = tonumber(data.weaponId)
    local identifier = type(data.identifier) == 'string' and data.identifier or nil
    if not weaponId or not identifier then return result(src, false, 'Données invalides.') end
    local relation = safeText(data.relation, 40)
    if relation == '' then relation = 'lie' end
    resolveCitizenName(identifier, function(name)
        if not name then return result(src, false, 'Citoyen introuvable.') end
        LSLegacy.ResolveCharacterId(identifier, function(charId)
            MySQL.Async.execute('INSERT INTO mdt_weapon_persons (weapon_id, identifier, character_id, citizen_name, relation, linked_by) VALUES (@w,@id,@charId,@name,@rel,@by) ON DUPLICATE KEY UPDATE relation=@rel, citizen_name=@name', {
                ['@w'] = weaponId, ['@id'] = identifier, ['@charId'] = charId, ['@name'] = name, ['@rel'] = relation, ['@by'] = player.identifier,
            }, function() result(src, true, "Personne liée à l'arme.", { view = 'weapon', id = weaponId }) end)
        end)
    end)
end)

-- Délier une personne d'une arme
LSLegacy.RegisterServerEvent('mdt:unlinkWeaponPerson', function(data)
    local src = source
    local player, depName = can(src, 'manage_weapons')
    if not player or type(data) ~= 'table' then return end
    local linkId = tonumber(data.linkId)
    if not linkId then return end
    MySQL.Async.execute('DELETE FROM mdt_weapon_persons WHERE id=@id', { ['@id'] = linkId }, function()
        result(src, true, 'Liaison retirée.', { view = 'weapon', id = tonumber(data.weaponId) })
    end)
end)

-- Lier une arme à un dossier via son numéro de série
LSLegacy.RegisterServerEvent('mdt:linkWeaponReport', function(data)
    local src = source
    -- gestion des armes d'un dossier = compétence PTS (manage_evidence / CS037)
    local player, depName = can(src, 'manage_evidence')
    if not player or type(data) ~= 'table' then return end
    local reportId = tonumber(data.reportId)
    local serial = type(data.serial) == 'string' and data.serial:upper():gsub('[^A-Z0-9]', '') or ''
    if not reportId or serial == '' then return result(src, false, 'Numéro de série requis.') end
    MySQL.Async.fetchAll('SELECT id FROM mdt_weapons WHERE serial_number=@s AND ' .. scopeClause(depName, 'mdt_weapons') .. ' LIMIT 1', { ['@s'] = serial }, function(rows)
        if not rows or not rows[1] then return result(src, false, 'Aucune arme avec ce numéro de série.') end
        MySQL.Async.execute('INSERT IGNORE INTO mdt_weapon_reports (weapon_id, report_id, linked_by) VALUES (@w,@r,@by)', {
            ['@w'] = rows[1].id, ['@r'] = reportId, ['@by'] = player.identifier,
        }, function() result(src, true, 'Arme liée au dossier.', { view = 'report', id = reportId }) end)
    end)
end)

-- Délier une arme d'un dossier
LSLegacy.RegisterServerEvent('mdt:unlinkWeaponReport', function(data)
    local src = source
    local player, depName = can(src, 'manage_evidence')
    if not player or type(data) ~= 'table' then return end
    local weaponId = tonumber(data.weaponId)
    local reportId = tonumber(data.reportId)
    if not weaponId or not reportId then return end
    MySQL.Async.execute('DELETE FROM mdt_weapon_reports WHERE weapon_id=@w AND report_id=@r', { ['@w'] = weaponId, ['@r'] = reportId }, function()
        result(src, true, "Arme retirée du dossier.", { view = 'report', id = reportId })
    end)
end)

--  EFFECTIFS — agents connectés du département + statut de service

-- Fonctions globales de statut "en service" exposées par chaque module métier.
-- Lookup par job → générique (aucune dépendance directe aux modules).
local DUTY_CHECKERS = {
    police      = 'IsOfficerOnDuty',
    gendarmerie = 'IsGendarmeOnDuty',
    samu        = 'IsSamuOnDuty',
    pompiers    = 'IsPompierOnDuty',
}

-- Le joueur est-il en service, quel que soit son métier ?
local function isPlayerOnDuty(src, job)
    local checkerName = DUTY_CHECKERS[job]
    local checker = checkerName and _G[checkerName]
    return (type(checker) == 'function' and checker(src) == true) or false
end

-- Appartenance aux forces de l'ordre (exposé aux autres modules)
-- Les missions PNJ sont conjointes : un gendarme doit pouvoir s'engager
-- sur un appel 17 au même titre qu'un policier. Plutôt que de tester un
-- job en dur, on s'appuie sur la sphère de données qui contient déjà la
-- police — ajouter un pôle à Config.MDT.DataGroups suffit donc à l'y
-- inclure.

-- Département MDT d'un joueur connecté, ou nil s'il n'en a aucun.
function GetMdtDepartment(src)
    local p = LSLegacy.Players.Get(src)
    if not p or not p.job then return nil end
    return LSLegacy.MDT.GetDepartmentForJob(p.job)
end

-- Le joueur appartient-il à une force de l'ordre ?
function IsLawEnforcement(src)
    local depName = GetMdtDepartment(src)
    if not depName then return false end
    for _, d in ipairs(LSLegacy.MDT.GetDataGroup('police')) do
        if d == depName then return true end
    end
    return false
end

-- Force de l'ordre ET en service (chaque pôle a sa propre bascule).
function IsLawEnforcementOnDuty(src)
    if not IsLawEnforcement(src) then return false end
    local p = LSLegacy.Players.Get(src)
    return isPlayerOnDuty(src, p and p.job)
end

-- Liste des agents connectés du département du demandeur, triés par grade décroissant.
readHandlers.getRoster = function(player, depName, grade, data, reply)
    local dep = LSLegacy.MDT.GetDepartment(depName)
    if not dep then return reply({}) end
    local jobsSet = {}
    for _, j in ipairs(dep.jobs or {}) do jobsSet[j] = true end

    local out = {}
    for src, p in pairs(LSLegacy.Players.GetAll()) do
        if p.job and jobsSet[p.job] then
            local g = tonumber(p.job_grade) or 0
            local onDuty = isPlayerOnDuty(src, p.job)
            local ci = p.characterInfos or {}
            out[#out + 1] = {
                identifier = p.identifier,
                character_id = p["boutique-id"],
                name = ((ci.Prenom or '') .. ' ' .. (ci.NDF or '')):gsub('^%s+', ''):gsub('%s+$', ''),
                grade = g,
                gradeLabel = LSLegacy.MDT.GetGradeLabel(depName, g),
                onDuty = onDuty,
                -- extensible : unité, radio… (à ajouter ici plus tard)
            }
        end
    end

    table.sort(out, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        return (a.name or '') < (b.name or '')
    end)
    reply(out)
end

--  TABLEAU DE BORD — vue d'ensemble des forces de l'ordre
--
--  Un seul aller-retour qui rassemble ce qu'un agent veut voir en
--  ouvrant sa tablette : qui est en service, ce qui est en cours
--  (avis de recherche, gardes à vue), et les dernières pièces versées
--  au dossier commun. Chaque bloc respecte les permissions du grade.

readHandlers.getDashboard = function(player, depName, grade, data, reply)
    local dep = LSLegacy.MDT.GetDepartment(depName)
    if not dep then return reply(false) end

    -- Effectif en service (agents connectés du département, en service).
    local jobsSet = {}
    for _, j in ipairs(dep.jobs or {}) do jobsSet[j] = true end
    local onDuty, meOnDuty = {}, false
    for src, p in pairs(LSLegacy.Players.GetAll()) do
        if p.job and jobsSet[p.job] and isPlayerOnDuty(src, p.job) then
            local g = tonumber(p.job_grade) or 0
            local ci = p.characterInfos or {}
            onDuty[#onDuty + 1] = {
                identifier = p.identifier,
                character_id = p["boutique-id"],
                name = ((ci.Prenom or '') .. ' ' .. (ci.NDF or '')):gsub('^%s+', ''):gsub('%s+$', ''),
                grade = g,
                gradeLabel = LSLegacy.MDT.GetGradeLabel(depName, g),
            }
            if p.identifier == player.identifier then meOnDuty = true end
        end
    end
    table.sort(onDuty, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        return (a.name or '') < (b.name or '')
    end)

    local canWarrants = mdtHasPerm(player, depName, grade, 'view_warrants')
    local canReports  = mdtHasPerm(player, depName, grade, 'view_reports')
    local canCustody  = mdtHasPerm(player, depName, grade, 'manage_custody')

    local out = {
        onDuty   = onDuty,
        meOnDuty = meOnDuty,
        stats    = {},
        warrants = {},
        reports  = {},
        custody  = {},
    }

    -- Les blocs s'enchaînent : oxmysql étant asynchrone, on termine la
    -- réponse dans le dernier callback plutôt que de compter des retours.
    local function finish() reply(out) end

    local function loadCustody()
        if not canCustody then return finish() end
        -- Gardes à vue non expirées = celles réellement en cours.
        MySQL.Async.fetchAll('SELECT id, citizen_name, reason, duration, officer_name, department, started_at, ends_at '
            .. 'FROM mdt_custody WHERE ' .. scopeClause(depName, 'mdt_custody')
            .. ' AND ends_at IS NOT NULL AND ends_at > NOW() ORDER BY ends_at ASC LIMIT 5', {}, function(rows)
            out.custody = rows or {}
            out.stats.custodyActive = #out.custody
            finish()
        end)
    end

    local function loadReports()
        if not canReports then return loadCustody() end
        MySQL.Async.fetchAll('SELECT id, type, title, author_name, department, updated_at '
            .. 'FROM mdt_reports WHERE ' .. scopeClause(depName, 'mdt_reports')
            .. ' ORDER BY updated_at DESC LIMIT 5', {}, function(rows)
            out.reports = rows or {}
            MySQL.Async.fetchScalar('SELECT COUNT(*) FROM mdt_reports WHERE ' .. scopeClause(depName, 'mdt_reports')
                .. ' AND DATE(created_at) = CURDATE()', {}, function(n)
                out.stats.reportsToday = tonumber(n) or 0
                loadCustody()
            end)
        end)
    end

    local function loadWarrants()
        if not canWarrants then return loadReports() end
        MySQL.Async.fetchAll("SELECT id, identifier, citizen_name, reason, danger_level, author_name, department, created_at "
            .. 'FROM mdt_warrants WHERE ' .. scopeClause(depName, 'mdt_warrants')
            .. " AND status='active' ORDER BY danger_level DESC, created_at DESC LIMIT 5", {}, function(rows)
            out.warrants = rows or {}
            MySQL.Async.fetchScalar('SELECT COUNT(*) FROM mdt_warrants WHERE ' .. scopeClause(depName, 'mdt_warrants')
                .. " AND status='active'", {}, function(n)
                out.stats.warrantsActive = tonumber(n) or 0
                loadReports()
            end)
        end)
    end

    -- Amendes impayées : visible de tous, c'est l'indicateur d'activité le
    -- plus parlant sur la base commune.
    MySQL.Async.fetchScalar('SELECT COUNT(*) FROM mdt_fines WHERE ' .. scopeClause(depName, 'mdt_fines')
        .. ' AND paid=0', {}, function(n)
        out.stats.finesUnpaid = tonumber(n) or 0
        loadWarrants()
    end)
end

--  CODE JURIDIQUE — lois / infractions (CRUD)

-- Liste des lois (recherche article/infraction/catégorie + filtre catégorie)
readHandlers.getLaws = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_laws') then return reply(false) end
    local query = type(data.query) == 'string' and data.query:lower():gsub('[%%_\\]', '') or ''
    local category = type(data.category) == 'string' and data.category or ''
    local clauses = { scopeClause(depName, 'mdt_laws') }
    local params = {}
    if category ~= '' and category ~= 'all' then
        clauses[#clauses + 1] = 'category=@cat'
        params['@cat'] = category
    end
    if query ~= '' then
        clauses[#clauses + 1] = '(LOWER(article) LIKE @q OR LOWER(name) LIKE @q OR LOWER(category) LIKE @q)'
        params['@q'] = '%' .. query .. '%'
    end
    MySQL.Async.fetchAll(
        'SELECT * FROM mdt_laws WHERE ' .. table.concat(clauses, ' AND ') .. ' ORDER BY category ASC, article ASC LIMIT 500',
        params, function(rows) reply(rows or {}) end)
end

-- Créer une loi
LSLegacy.RegisterServerEvent('mdt:createLaw', function(data)
    local src = source
    local player, depName = can(src, 'manage_laws')
    if not player or type(data) ~= 'table' then return end
    local name = safeText(data.name, 255)
    if name == '' then return result(src, false, "Nom de l'infraction requis.") end
    MySQL.Async.insert('INSERT INTO mdt_laws (department, article, name, description, fine, jail, category, created_by, created_by_name) VALUES (@dep,@article,@name,@desc,@fine,@jail,@cat,@oid,@oname)', {
        ['@dep'] = depName, ['@article'] = safeText(data.article, 40), ['@name'] = name,
        ['@desc'] = safeText(data.description, L.MaxTextLength),
        ['@fine'] = math.max(0, math.floor(tonumber(data.fine) or 0)),
        ['@jail'] = safeText(data.jail, 120), ['@cat'] = safeText(data.category, 60),
        ['@oid'] = player.identifier, ['@oname'] = charName(player),
    }, function()
        result(src, true, 'Article ajouté au code juridique.', { view = 'laws' })
        mdtLog('Code juridique', ('**%s** a ajouté un article : [%s] %s'):format(charName(player), safeText(data.article, 40), name))
    end)
end)

-- Modifier une loi
LSLegacy.RegisterServerEvent('mdt:updateLaw', function(data)
    local src = source
    local player, depName = can(src, 'manage_laws')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    local name = safeText(data.name, 255)
    if name == '' then return result(src, false, "Nom de l'infraction requis.") end
    MySQL.Async.execute('UPDATE mdt_laws SET article=@article, name=@name, description=@desc, fine=@fine, jail=@jail, category=@cat WHERE id=@id AND ' .. scopeClause(depName, 'mdt_laws'), {
        ['@article'] = safeText(data.article, 40), ['@name'] = name,
        ['@desc'] = safeText(data.description, L.MaxTextLength),
        ['@fine'] = math.max(0, math.floor(tonumber(data.fine) or 0)),
        ['@jail'] = safeText(data.jail, 120), ['@cat'] = safeText(data.category, 60),
        ['@id'] = id,
    }, function() result(src, true, 'Article mis à jour.', { view = 'laws' }) end)
end)

-- Supprimer une loi
LSLegacy.RegisterServerEvent('mdt:deleteLaw', function(data)
    local src = source
    local player, depName = can(src, 'manage_laws')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_laws WHERE id=@id AND ' .. scopeClause(depName, 'mdt_laws'), { ['@id'] = id }, function()
        result(src, true, 'Article supprimé.', { view = 'laws' })
    end)
end)

--  FORMATIONS / STAGES

-- Liste des formations (+ nb inscrits + si le demandeur est inscrit)
readHandlers.getTrainings = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'view_trainings') then return reply(false) end
    MySQL.Async.fetchAll([[
        SELECT t.*,
               (SELECT COUNT(*) FROM mdt_training_signups s  WHERE s.training_id  = t.id) AS signups,
               (SELECT COUNT(*) FROM mdt_training_signups s2 WHERE s2.training_id = t.id AND s2.identifier = @me) AS me
        FROM mdt_trainings t
        WHERE t.department = @dep
        ORDER BY t.scheduled_at ASC, t.created_at ASC
    ]], { ['@dep'] = depName, ['@me'] = player.identifier }, function(rows) reply(rows or {}) end)
end

-- Liste des inscrits d'une formation (réservé gestionnaires)
readHandlers.getTrainingSignups = function(player, depName, grade, data, reply)
    if not mdtHasPerm(player, depName, grade, 'manage_trainings') then return reply(false) end
    local tid = tonumber(data.trainingId)
    if not tid then return reply({}) end
    MySQL.Async.fetchAll('SELECT * FROM mdt_training_signups WHERE training_id=@t ORDER BY grade DESC, created_at ASC', { ['@t'] = tid }, function(rows) reply(rows or {}) end)
end

-- Créer une formation
LSLegacy.RegisterServerEvent('mdt:createTraining', function(data)
    local src = source
    local player, depName = can(src, 'manage_trainings')
    if not player or type(data) ~= 'table' then return end
    local name = safeText(data.name, 255)
    if name == '' then return result(src, false, 'Nom de la formation requis.') end
    MySQL.Async.insert('INSERT INTO mdt_trainings (department, name, code, scheduled_at, description, max_slots, created_by, created_by_name) VALUES (@dep,@name,@code,@sched,@desc,@max,@oid,@oname)', {
        ['@dep'] = depName, ['@name'] = name, ['@code'] = safeText(data.code, 10),
        ['@sched'] = safeText(data.scheduled_at, 40),
        ['@desc'] = safeText(data.description, L.MaxTextLength),
        ['@max'] = math.max(0, math.floor(tonumber(data.max_slots) or 0)),
        ['@oid'] = player.identifier, ['@oname'] = charName(player),
    }, function()
        result(src, true, 'Formation créée.', { view = 'trainings' })
        mdtLog('Formation', ('**%s** a créé la formation : %s'):format(charName(player), name))
    end)
end)

-- Modifier une formation
LSLegacy.RegisterServerEvent('mdt:updateTraining', function(data)
    local src = source
    local player, depName = can(src, 'manage_trainings')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    local name = safeText(data.name, 255)
    if name == '' then return result(src, false, 'Nom de la formation requis.') end
    MySQL.Async.execute('UPDATE mdt_trainings SET name=@name, scheduled_at=@sched, description=@desc, max_slots=@max WHERE id=@id AND department=@dep', {
        ['@name'] = name, ['@sched'] = safeText(data.scheduled_at, 40),
        ['@desc'] = safeText(data.description, L.MaxTextLength),
        ['@max'] = math.max(0, math.floor(tonumber(data.max_slots) or 0)), ['@id'] = id, ['@dep'] = depName,
    }, function() result(src, true, 'Formation mise à jour.', { view = 'trainings' }) end)
end)

-- Supprimer / annuler une formation (+ ses inscriptions)
LSLegacy.RegisterServerEvent('mdt:deleteTraining', function(data)
    local src = source
    local player, depName = can(src, 'manage_trainings')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_trainings WHERE id=@id AND department=@dep', { ['@id'] = id, ['@dep'] = depName }, function()
        MySQL.Async.execute('DELETE FROM mdt_training_signups WHERE training_id=@id', { ['@id'] = id })
        result(src, true, 'Formation annulée.', { view = 'trainings' })
    end)
end)

-- S'inscrire (place vérifiée + une seule inscription)
LSLegacy.RegisterServerEvent('mdt:signupTraining', function(data)
    local src = source
    local player, depName, grade = can(src, 'view_trainings')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.fetchAll('SELECT max_slots, (SELECT COUNT(*) FROM mdt_training_signups s WHERE s.training_id=t.id) AS signups FROM mdt_trainings t WHERE t.id=@id AND t.department=@dep LIMIT 1', { ['@id'] = id, ['@dep'] = depName }, function(rows)
        if not rows or not rows[1] then return result(src, false, 'Formation introuvable.') end
        local maxSlots = tonumber(rows[1].max_slots) or 0
        local signups = tonumber(rows[1].signups) or 0
        if maxSlots > 0 and signups >= maxSlots then return result(src, false, 'Formation complète.') end
        MySQL.Async.execute('INSERT IGNORE INTO mdt_training_signups (training_id, identifier, character_id, citizen_name, grade, grade_label) VALUES (@t,@id,@charId,@name,@grade,@glabel)', {
            ['@t'] = id, ['@id'] = player.identifier, ['@charId'] = player["boutique-id"], ['@name'] = charName(player),
            ['@grade'] = grade, ['@glabel'] = LSLegacy.MDT.GetGradeLabel(depName, grade),
        }, function()
            result(src, true, 'Inscription enregistrée.', { view = 'trainings' })
        end)
    end)
end)

-- Se désinscrire
LSLegacy.RegisterServerEvent('mdt:unsignupTraining', function(data)
    local src = source
    local player, depName = can(src, 'view_trainings')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_training_signups WHERE training_id=@t AND character_id=@id', { ['@t'] = id, ['@id'] = player["boutique-id"] }, function()
        result(src, true, 'Désinscription effectuée.', { view = 'trainings' })
    end)
end)

-- Retirer une inscription (gestionnaire)
LSLegacy.RegisterServerEvent('mdt:removeSignup', function(data)
    local src = source
    local player, depName = can(src, 'manage_trainings')
    if not player or type(data) ~= 'table' then return end
    local signupId = tonumber(data.signupId)
    if not signupId then return end
    MySQL.Async.execute('DELETE FROM mdt_training_signups WHERE id=@id', { ['@id'] = signupId }, function()
        result(src, true, 'Inscription supprimée.', { view = 'training', id = tonumber(data.trainingId) })
    end)
end)

--  AJOUTS — casier (suppr. GAV), arme liée au citoyen

-- Supprimer une garde à vue du casier d'un citoyen
-- Réservé aux grades supérieurs (Commandant / Commissaire côté police,
-- leurs équivalents côté gendarmerie) : la GAV reste consultable et
-- gérable par tous les grades qui en ont déjà le droit, mais sa
-- suppression est une décision de commandement.
LSLegacy.RegisterServerEvent('mdt:deleteCustody', function(data)
    local src = source
    local player, depName = can(src, 'delete_custody')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_custody WHERE id=@id AND ' .. scopeClause(depName, 'mdt_custody'), { ['@id'] = id }, function()
        result(src, true, 'Garde à vue supprimée du casier.', { view = 'citizen', id = data.identifier })
    end)
end)

-- Lier une arme à un citoyen depuis sa fiche (par n° de série)
LSLegacy.RegisterServerEvent('mdt:linkPersonWeapon', function(data)
    local src = source
    local player, depName = can(src, 'manage_weapons')
    if not player or type(data) ~= 'table' then return end
    local identifier = type(data.identifier) == 'string' and data.identifier or nil
    local serial = type(data.serial) == 'string' and data.serial:upper():gsub('[^A-Z0-9]', '') or ''
    if not identifier or serial == '' then return result(src, false, 'Numéro de série requis.') end
    local relation = safeText(data.relation, 40)
    if relation == '' then relation = 'lie' end
    MySQL.Async.fetchAll('SELECT id FROM mdt_weapons WHERE serial_number=@s AND ' .. scopeClause(depName, 'mdt_weapons') .. ' LIMIT 1', { ['@s'] = serial }, function(rows)
        if not rows or not rows[1] then return result(src, false, 'Aucune arme avec ce numéro de série.') end
        resolveCitizenName(identifier, function(name)
            LSLegacy.ResolveCharacterId(identifier, function(charId)
                MySQL.Async.execute('INSERT INTO mdt_weapon_persons (weapon_id, identifier, character_id, citizen_name, relation, linked_by) VALUES (@w,@id,@charId,@name,@rel,@by) ON DUPLICATE KEY UPDATE relation=@rel, citizen_name=@name', {
                    ['@w'] = rows[1].id, ['@id'] = identifier, ['@charId'] = charId, ['@name'] = name or safeText(data.citizen_name, 100),
                    ['@rel'] = relation, ['@by'] = player.identifier,
                }, function() result(src, true, "Arme liée au citoyen.", { view = 'citizen', id = identifier }) end)
            end)
        end)
    end)
end)

-- Valider / refuser la formation d'un inscrit (valide → compétence auto)
LSLegacy.RegisterServerEvent('mdt:validateSignup', function(data)
    local src = source
    local player, depName = can(src, 'manage_trainings')
    if not player or type(data) ~= 'table' then return end
    local signupId = tonumber(data.signupId)
    if not signupId then return end
    if data.valid == true then
        MySQL.Async.fetchAll([[
            SELECT s.identifier, s.character_id, t.name AS training_name, t.code AS training_code
            FROM mdt_training_signups s JOIN mdt_trainings t ON t.id = s.training_id
            WHERE s.id=@id LIMIT 1
        ]], { ['@id'] = signupId }, function(rows)
            if not rows or not rows[1] then return result(src, false, 'Inscription introuvable.') end
            MySQL.Async.execute("UPDATE mdt_training_signups SET status='validated' WHERE id=@id", { ['@id'] = signupId })
            MySQL.Async.execute('INSERT INTO mdt_agent_skills (department, identifier, character_id, skill, code) VALUES (@dep,@id,@charId,@skill,@code) ON DUPLICATE KEY UPDATE obtained_at=CURRENT_TIMESTAMP, code=@code', {
                ['@dep'] = depName, ['@id'] = rows[1].identifier, ['@charId'] = rows[1].character_id, ['@skill'] = rows[1].training_name, ['@code'] = rows[1].training_code or '',
            }, function()
                result(src, true, 'Formation validée — compétence ajoutée.', { view = 'training', id = tonumber(data.trainingId) })
            end)
        end)
    else
        MySQL.Async.execute("UPDATE mdt_training_signups SET status='refused' WHERE id=@id", { ['@id'] = signupId }, function()
            result(src, true, 'Formation refusée.', { view = 'training', id = tonumber(data.trainingId) })
        end)
    end
end)

--  ENQUÊTE — description des preuves + liaison preuve↔dossier

local EVIDENCE_TABLES = { fingerprint = 'police_fingerprints', dna = 'police_dna', blood = 'police_blood_traces' }

-- Renseigner / modifier la description détaillée d'une preuve
LSLegacy.RegisterServerEvent('mdt:updateEvidence', function(data)
    local src = source
    local player, depName = can(src, 'manage_evidence')
    if not player or type(data) ~= 'table' then return end
    local tbl = EVIDENCE_TABLES[data.type]
    local ref = type(data.ref) == 'string' and data.ref or ''
    if not tbl or ref == '' then return result(src, false, 'Preuve invalide.') end
    MySQL.Async.execute('UPDATE ' .. tbl .. ' SET description=@desc WHERE ref=@ref', {
        ['@desc'] = safeText(data.description, L.MaxTextLength), ['@ref'] = ref,
    }, function() result(src, true, 'Description enregistrée.', { view = 'evidence' }) end)
end)

-- Lier une preuve (par référence) à un dossier
LSLegacy.RegisterServerEvent('mdt:linkReportEvidence', function(data)
    local src = source
    local player, depName = can(src, 'view_evidence')
    if not player or type(data) ~= 'table' then return end
    local reportId = tonumber(data.reportId)
    local ref = type(data.ref) == 'string' and data.ref:upper():gsub('%s+', '') or ''
    if not reportId or ref == '' then return result(src, false, 'Référence requise.') end
    MySQL.Async.fetchAll([[
        SELECT 'fingerprint' AS t, CONCAT('Empreintes — ', citizen_name) AS label FROM police_fingerprints WHERE ref=@ref
        UNION ALL SELECT 'dna', CONCAT('ADN — ', citizen_name) FROM police_dna WHERE ref=@ref
        UNION ALL SELECT 'blood', CONCAT('Sang — ', ref) FROM police_blood_traces WHERE ref=@ref
        LIMIT 1
    ]], { ['@ref'] = ref }, function(rows)
        if not rows or not rows[1] then return result(src, false, 'Aucune preuve avec cette référence.') end
        MySQL.Async.execute('INSERT IGNORE INTO mdt_report_evidence (report_id, ev_type, ev_ref, label, linked_by) VALUES (@r,@t,@ref,@label,@by)', {
            ['@r'] = reportId, ['@t'] = rows[1].t, ['@ref'] = ref, ['@label'] = rows[1].label, ['@by'] = player.identifier,
        }, function() result(src, true, 'Preuve liée au dossier.', { view = 'report', id = reportId }) end)
    end)
end)

-- Délier une preuve d'un dossier
LSLegacy.RegisterServerEvent('mdt:unlinkReportEvidence', function(data)
    local src = source
    local player = can(src, 'view_evidence')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_report_evidence WHERE id=@id', { ['@id'] = id }, function()
        result(src, true, 'Preuve retirée du dossier.', { view = 'report', id = tonumber(data.reportId) })
    end)
end)

--  FICHE DÉTAILLÉE AGENT (RH, carrière, affectations, sanctions, compétences)

local function generateMatricule(cb, attempts)
    attempts = attempts or 0
    local m = 'PN' .. tostring(math.random(10000, 99999))
    MySQL.Async.fetchScalar('SELECT identifier FROM mdt_agent_meta WHERE matricule=@m LIMIT 1', { ['@m'] = m }, function(existing)
        if existing and attempts < 12 then generateMatricule(cb, attempts + 1) else cb(m) end
    end)
end

-- Fiche complète d'un agent (consultation : tout membre du département).
-- Clé = character_id (le personnage précis) et non identifier (le compte) :
-- un compte multichar peut avoir plusieurs personnages agents, chacun avec
-- sa propre fiche RH.
readHandlers.getAgentFile = function(player, depName, grade, data, reply)
    local characterId = tonumber(data.character_id)
    if not characterId then return reply(false) end
    MySQL.Async.fetchAll('SELECT identifier, characterInfos, job, job_grade FROM players WHERE `boutique-id`=@id LIMIT 1', { ['@id'] = characterId }, function(prows)
        if not prows or not prows[1] then return reply(false) end
        local identifier = prows[1].identifier
        local ok, info = pcall(json.decode, prows[1].characterInfos)
        info = (ok and info) or {}
        local function loadAll(meta)
            local p = { ['@id'] = characterId }
            MySQL.Async.fetchAll('SELECT grade_index, start_date, end_date FROM mdt_agent_career WHERE character_id=@id', p, function(career)
                MySQL.Async.fetchAll('SELECT * FROM mdt_agent_assignments WHERE character_id=@id ORDER BY created_at ASC', p, function(assignments)
                    MySQL.Async.fetchAll('SELECT * FROM mdt_agent_commendations WHERE character_id=@id ORDER BY obtained_date DESC', p, function(comms)
                        MySQL.Async.fetchAll('SELECT id, skill, code, obtained_at, DATEDIFF(NOW(), obtained_at) AS days_since FROM mdt_agent_skills WHERE character_id=@id ORDER BY obtained_at DESC', p, function(skills)
                            local careerMap = {}
                            for _, c in ipairs(career or {}) do careerMap[tostring(c.grade_index)] = { start_date = c.start_date, end_date = c.end_date } end
                            -- statut de recyclage calculé serveur (fiable, indépendant du transport)
                            local nameToCode = {}
                            for _, tc in ipairs(Config.MDT.TrainingCodes or {}) do nameToCode[tc.name] = tc.code end
                            for _, s in ipairs(skills or {}) do
                                local code = (s.code and s.code ~= '') and s.code or nameToCode[s.skill]
                                local days = code and Config.MDT.SkillRecycleDays[code]
                                if days then
                                    s.recycle_status = (tonumber(s.days_since) or 0) <= days and 'valid' or 'expired'
                                end
                            end
                            reply({
                                identity = {
                                    identifier = identifier,
                                    character_id = characterId,
                                    prenom = info.Prenom, nom = info.NDF, ddn = info.DDN,
                                    name = ((info.Prenom or '') .. ' ' .. (info.NDF or '')):gsub('^%s+', ''):gsub('%s+$', ''),
                                    job = prows[1].job, job_grade = prows[1].job_grade,
                                    gradeLabel = LSLegacy.MDT.GetGradeLabel(depName, tonumber(prows[1].job_grade) or 0),
                                },
                                meta = meta,
                                career = careerMap,
                                assignments = assignments or {},
                                commendations = comms or {},
                                skills = skills or {},
                            })
                        end)
                    end)
                end)
            end)
        end
        MySQL.Async.fetchAll('SELECT * FROM mdt_agent_meta WHERE character_id=@id LIMIT 1', { ['@id'] = characterId }, function(mrows)
            if mrows and mrows[1] then
                loadAll(mrows[1])
            else
                generateMatricule(function(m)
                    MySQL.Async.execute('INSERT INTO mdt_agent_meta (identifier, character_id, department, matricule) VALUES (@id,@charId,@dep,@m) ON DUPLICATE KEY UPDATE matricule=matricule', {
                        ['@id'] = identifier, ['@charId'] = characterId, ['@dep'] = depName, ['@m'] = m,
                    }, function()
                        loadAll({ identifier = identifier, character_id = characterId, matricule = m, hire_date = '', tenure_date = '', service_weapon = '' })
                    end)
                end)
            end
        end)
    end)
end

-- Infos RH (date entrée, titularisation, arme de service)
LSLegacy.RegisterServerEvent('mdt:saveAgentMeta', function(data)
    local src = source
    local player, depName = can(src, 'manage_personnel')
    if not player or type(data) ~= 'table' then return end
    local characterId = tonumber(data.character_id)
    if not characterId then return end
    MySQL.Async.execute('UPDATE mdt_agent_meta SET hire_date=@h, tenure_date=@t, service_weapon=@w WHERE character_id=@id', {
        ['@h'] = safeText(data.hire_date, 20), ['@t'] = safeText(data.tenure_date, 20),
        ['@w'] = safeText(data.service_weapon, 20), ['@id'] = characterId,
    }, function() result(src, true, 'Informations enregistrées.', { view = 'agent', id = characterId }) end)
end)

-- Historique de carrière (dates par grade, enregistré en bloc)
LSLegacy.RegisterServerEvent('mdt:saveCareer', function(data)
    local src = source
    local player, depName = can(src, 'manage_personnel')
    if not player or type(data) ~= 'table' then return end
    local characterId = tonumber(data.character_id)
    local identifier = type(data.identifier) == 'string' and data.identifier or nil
    if not characterId or not identifier then return end
    local entries = type(data.entries) == 'table' and data.entries or {}
    for _, e in ipairs(entries) do
        local gi = tonumber(e.grade)
        if gi then
            MySQL.Async.execute('INSERT INTO mdt_agent_career (identifier, character_id, grade_index, start_date, end_date) VALUES (@ident,@id,@gi,@s,@e) ON DUPLICATE KEY UPDATE start_date=@s, end_date=@e', {
                ['@ident'] = identifier, ['@id'] = characterId, ['@gi'] = gi, ['@s'] = safeText(e.start, 20), ['@e'] = safeText(e.endDate, 20),
            })
        end
    end
    result(src, true, 'Historique de carrière enregistré.', { view = 'agent', id = characterId })
end)

-- Affectations
LSLegacy.RegisterServerEvent('mdt:addAssignment', function(data)
    local src = source
    local player, depName = can(src, 'manage_personnel')
    if not player or type(data) ~= 'table' then return end
    local characterId = tonumber(data.character_id)
    local identifier = type(data.identifier) == 'string' and data.identifier or nil
    if not characterId or not identifier then return end
    local code = safeText(data.code, 80)
    if code == '' then return result(src, false, "Code d'affectation requis.") end
    MySQL.Async.insert('INSERT INTO mdt_agent_assignments (identifier, character_id, code, start_date, end_date) VALUES (@ident,@id,@code,@s,@e)', {
        ['@ident'] = identifier, ['@id'] = characterId, ['@code'] = code, ['@s'] = safeText(data.start_date, 20), ['@e'] = safeText(data.end_date, 20),
    }, function() result(src, true, 'Affectation ajoutée.', { view = 'agent', id = characterId }) end)
end)

LSLegacy.RegisterServerEvent('mdt:updateAssignment', function(data)
    local src = source
    local player = can(src, 'manage_personnel')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('UPDATE mdt_agent_assignments SET code=@code, start_date=@s, end_date=@e WHERE id=@id', {
        ['@code'] = safeText(data.code, 80), ['@s'] = safeText(data.start_date, 20), ['@e'] = safeText(data.end_date, 20), ['@id'] = id,
    }, function() result(src, true, 'Affectation mise à jour.', { view = 'agent', id = data.character_id }) end)
end)

LSLegacy.RegisterServerEvent('mdt:deleteAssignment', function(data)
    local src = source
    local player = can(src, 'manage_personnel')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_agent_assignments WHERE id=@id', { ['@id'] = id }, function()
        result(src, true, 'Affectation supprimée.', { view = 'agent', id = data.character_id })
    end)
end)

-- Félicitations / sanctions
LSLegacy.RegisterServerEvent('mdt:addCommendation', function(data)
    local src = source
    local player, depName = can(src, 'manage_personnel')
    if not player or type(data) ~= 'table' then return end
    local characterId = tonumber(data.character_id)
    local identifier = type(data.identifier) == 'string' and data.identifier or nil
    if not characterId or not identifier then return end
    local nature = (data.nature == 'sanction') and 'sanction' or 'felicitation'
    local reason = safeText(data.reason, 255)
    if reason == '' then return result(src, false, 'Motif requis.') end
    MySQL.Async.insert('INSERT INTO mdt_agent_commendations (identifier, character_id, obtained_date, nature, reason, details, author, author_name) VALUES (@ident,@id,@d,@n,@r,@det,@oid,@oname)', {
        ['@ident'] = identifier, ['@id'] = characterId, ['@d'] = safeText(data.obtained_date, 20), ['@n'] = nature,
        ['@r'] = reason, ['@det'] = safeText(data.details, L.MaxTextLength),
        ['@oid'] = player.identifier, ['@oname'] = charName(player),
    }, function()
        result(src, true, 'Entrée ajoutée.', { view = 'agent', id = characterId })
        mdtLog('Personnel', ('**%s** a ajouté une %s'):format(charName(player), nature))
    end)
end)

LSLegacy.RegisterServerEvent('mdt:deleteCommendation', function(data)
    local src = source
    local player = can(src, 'manage_personnel')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_agent_commendations WHERE id=@id', { ['@id'] = id }, function()
        result(src, true, 'Entrée supprimée.', { view = 'agent', id = data.character_id })
    end)
end)

-- Ajouter une compétence manuellement (Commissaire / Commandant)
LSLegacy.RegisterServerEvent('mdt:addSkill', function(data)
    local src = source
    local player, depName = can(src, 'manage_personnel')
    if not player or type(data) ~= 'table' then return end
    local characterId = tonumber(data.character_id)
    local identifier = type(data.identifier) == 'string' and data.identifier or nil
    if not characterId or not identifier then return end
    local skill = safeText(data.skill, 150)
    if skill == '' then return result(src, false, 'Compétence requise.') end
    MySQL.Async.execute('INSERT INTO mdt_agent_skills (department, identifier, character_id, skill, code) VALUES (@dep,@ident,@id,@skill,@code) ON DUPLICATE KEY UPDATE code=@code, obtained_at=CURRENT_TIMESTAMP', {
        ['@dep'] = depName, ['@ident'] = identifier, ['@id'] = characterId, ['@skill'] = skill, ['@code'] = safeText(data.code, 10),
    }, function() result(src, true, 'Compétence ajoutée.', { view = 'agent', id = characterId }) end)
end)

-- Supprimer une compétence
LSLegacy.RegisterServerEvent('mdt:deleteSkill', function(data)
    local src = source
    local player = can(src, 'manage_personnel')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_agent_skills WHERE id=@id', { ['@id'] = id }, function()
        result(src, true, 'Compétence supprimée.', { view = 'agent', id = data.character_id })
    end)
end)

-- Modifier la date d'obtention d'une compétence (Commissaire / Commandant)
LSLegacy.RegisterServerEvent('mdt:updateSkillDate', function(data)
    local src = source
    local player = can(src, 'manage_personnel')
    if not player or type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    local date = safeText(data.obtained_date, 20)
    if not id or date == '' then return end
    MySQL.Async.execute('UPDATE mdt_agent_skills SET obtained_at=@d WHERE id=@id', { ['@d'] = date, ['@id'] = id }, function()
        result(src, true, "Date d'obtention mise à jour.", { view = 'agent', id = data.character_id })
    end)
end)
