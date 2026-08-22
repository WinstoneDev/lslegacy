--  MDT MÉDICAL (SAMU) — Serveur
--
--  Module AUTONOME : il ne lit ni n'écrit aucune table `mdt_*` du MDT
--  police, et n'utilise aucun de ses handlers. Il expose son propre
--  pont de lecture (`mdtmed:query` → `mdtmed:queryResult`) et ses
--  propres events d'écriture, sur le modèle du MDT police.
--
--  SÉCURITÉ — invariants respectés partout ci-dessous :
--    • job/grade TOUJOURS résolus via LSLegacy.Players.Get(src),
--      jamais depuis le client ;
--    • seul le département `samu` peut appeler ces handlers ;
--    • chaque lecture ET chaque écriture revérifie sa permission ;
--    • aucune donnée judiciaire n'est jamais renvoyée (le dossier
--      médical ne contient que identité + médical).

local rateLimits = {
    ['mdtmed:query'] = 40, ['mdtmed:saveRecord'] = 20, ['mdtmed:addEntry'] = 20,
    ['mdtmed:deleteEntry'] = 15, ['mdtmed:addTreatment'] = 20, ['mdtmed:setTreatmentStatus'] = 25,
    ['mdtmed:assignCall'] = 20, ['mdtmed:closeCall'] = 20, ['mdtmed:saveDoc'] = 15,
    ['mdtmed:deleteDoc'] = 15, ['mdtmed:postBoard'] = 15, ['mdtmed:removeBoard'] = 15,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local L = Config.Medical.Limits

-- Création du schéma (miroir de sql/medical.sql)

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_med_records (
        id          INT(11)      NOT NULL AUTO_INCREMENT,
        identifier  VARCHAR(60)  NOT NULL,
        character_id INT                  DEFAULT NULL,
        blood_group VARCHAR(8)            DEFAULT NULL,
        allergies   TEXT                  DEFAULT NULL,
        antecedents TEXT                  DEFAULT NULL,
        ongoing     TEXT                  DEFAULT NULL,
        notes       TEXT                  DEFAULT NULL,
        dnr         TINYINT(1)   NOT NULL DEFAULT 0,
        created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        updated_by  VARCHAR(100)          DEFAULT NULL,
        PRIMARY KEY (id),
        UNIQUE KEY uniq_patient (character_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_med_entries (
        id                INT(11)      NOT NULL AUTO_INCREMENT,
        identifier        VARCHAR(60)  NOT NULL,
        character_id      INT                   DEFAULT NULL,
        type              VARCHAR(40)  NOT NULL DEFAULT 'consultation',
        title             VARCHAR(150) NOT NULL,
        content           TEXT                  DEFAULT NULL,
        author_identifier VARCHAR(60)           DEFAULT NULL,
        author_name       VARCHAR(100)          DEFAULT NULL,
        created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_patient (identifier),
        KEY idx_created (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
MySQL.Async.execute("ALTER TABLE mdt_med_entries ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_med_treatments (
        id                    INT(11)      NOT NULL AUTO_INCREMENT,
        identifier            VARCHAR(60)  NOT NULL,
        character_id          INT                   DEFAULT NULL,
        code                  VARCHAR(30)           DEFAULT NULL,
        label                 VARCHAR(150) NOT NULL,
        dosage                VARCHAR(100)          DEFAULT NULL,
        duration              VARCHAR(100)          DEFAULT NULL,
        notes                 TEXT                  DEFAULT NULL,
        status                VARCHAR(20)  NOT NULL DEFAULT 'actif',
        prescriber_identifier VARCHAR(60)           DEFAULT NULL,
        prescriber_name       VARCHAR(100)          DEFAULT NULL,
        created_at            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        ended_at              DATETIME              DEFAULT NULL,
        PRIMARY KEY (id),
        KEY idx_patient (identifier),
        KEY idx_status (status)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
MySQL.Async.execute("ALTER TABLE mdt_med_treatments ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_med_calls (
        id                  INT(11)      NOT NULL AUTO_INCREMENT,
        caller_identifier   VARCHAR(60)           DEFAULT NULL,
        character_id        INT                   DEFAULT NULL,
        caller_name         VARCHAR(100)          DEFAULT NULL,
        x                   FLOAT        NOT NULL DEFAULT 0,
        y                   FLOAT        NOT NULL DEFAULT 0,
        z                   FLOAT        NOT NULL DEFAULT 0,
        reason              VARCHAR(150)          DEFAULT NULL,
        status              VARCHAR(20)  NOT NULL DEFAULT 'pending',
        assigned_identifier VARCHAR(60)           DEFAULT NULL,
        assigned_name       VARCHAR(100)          DEFAULT NULL,
        created_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        closed_at           DATETIME              DEFAULT NULL,
        PRIMARY KEY (id),
        KEY idx_status (status),
        KEY idx_created (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
MySQL.Async.execute("ALTER TABLE mdt_med_calls ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})

MySQL.Async.execute([[
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- Helpers

local DEPARTMENT = 'samu'

-- Nom RP d'un joueur.
local function charName(player)
    if player and player.characterInfos then
        local ci = player.characterInfos
        return ((ci.Prenom or '') .. ' ' .. (ci.NDF or '')):gsub('^%s+', ''):gsub('%s+$', '')
    end
    return '?'
end

-- Contexte médical : (player, grade) si le joueur est bien du département
-- SAMU, nil sinon. Un policier qui déclencherait ces events est rejeté ici.
local function medCtx(src)
    local player = LSLegacy.Players.Get(src)
    if not player then return nil end
    local depName = LSLegacy.MDT.GetDepartmentForJob(player.job)
    if depName ~= DEPARTMENT then return nil end
    return player, tonumber(player.job_grade) or 0
end

-- Garde de permission. Renvoie (player, grade) ou nil.
local function can(src, perm)
    local player, grade = medCtx(src)
    if not player then return nil end
    if perm and not LSLegacy.MDT.HasPermission(DEPARTMENT, grade, perm) then return nil end
    return player, grade
end

local function safeText(v, maxLen)
    if type(v) ~= 'string' then return '' end
    v = v:gsub('%z', '')
    local m = maxLen or L.MaxTextLength
    if #v > m then v = v:sub(1, m) end
    return v
end

-- Identifier valide (chaîne non vide, longueur plausible).
local function safeIdentifier(v)
    if type(v) ~= 'string' then return nil end
    if v == '' or #v > 60 then return nil end
    return v
end

-- Réponse standardisée d'une écriture (notif + refresh ciblé côté NUI).
local function result(src, ok, message, refresh)
    LSLegacy.Events.SendToClient('mdt:result', src, { ok = ok, message = message, refresh = refresh })
end

-- Quartier le plus proche d'un point (nom de secteur pour le dispatch).
-- Comparaison au carré : pas besoin de racine pour un simple minimum.
local function nearestDistrict(x, y)
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return nil end
    local best, bestDist
    for _, d in ipairs(Config.Medical.Districts or {}) do
        local dx, dy = x - d.x, y - d.y
        local dist = dx * dx + dy * dy
        if not bestDist or dist < bestDist then
            best, bestDist = d.label, dist
        end
    end
    return best
end

-- Une valeur appartient-elle à une liste de clés autorisées ?
local function isAllowed(list, value, key)
    for _, v in ipairs(list or {}) do
        if (key and v[key] or v) == value then return true end
    end
    return false
end

--  LECTURES — dispatcher unique `mdtmed:query`

local readHandlers = {}

-- Catalogues métier nécessaires au NUI (groupes sanguins, types d'entrée,
-- traitements, catégories de documents, réglages de la carte).
---
-- Passe par une lecture dédiée plutôt que par le payload d'ouverture du
-- MDT : ça évite d'avoir à modifier module/mdt/server/main.lua, donc le
-- MDT police reste inchangé. Le NUI le met en cache au premier rendu.
readHandlers.getMedConfig = function(player, grade, data, reply)
    reply({
        bloodGroups       = Config.Medical.BloodGroups,
        entryTypes        = Config.Medical.EntryTypes,
        treatments        = Config.Medical.Treatments,
        treatmentStatuses = Config.Medical.TreatmentStatuses,
        docCategories     = Config.Medical.DocCategories,
        districts         = Config.Medical.Districts,
        dispatch          = {
            refreshInterval = Config.Medical.Dispatch.refreshInterval,
        },
    })
end

-- Recherche de patients. Ne renvoie QUE l'identité — aucune donnée
-- judiciaire, contrairement au handler homonyme du MDT police.
readHandlers.searchPatients = function(player, grade, data, reply)
    local query = type(data.query) == 'string' and data.query or ''
    if #query < L.SearchMinChars then return reply({}) end
    local like = '%' .. query:lower():gsub('[%%_\\]', '') .. '%'
    local limit = math.floor(L.MaxSearchResults)
    MySQL.Async.fetchAll([[
        SELECT p.identifier, p.`boutique-id` AS character_id, p.characterInfos,
               (SELECT COUNT(*) FROM mdt_med_records r WHERE r.character_id = p.`boutique-id`) AS has_record,
               (SELECT COUNT(*) FROM mdt_med_treatments t WHERE t.character_id = p.`boutique-id` AND t.status = 'actif') AS active_treatments
        FROM players p
        WHERE LOWER(JSON_UNQUOTE(JSON_EXTRACT(p.characterInfos, '$.NDF'))) LIKE @q
           OR LOWER(JSON_UNQUOTE(JSON_EXTRACT(p.characterInfos, '$.Prenom'))) LIKE @q
        LIMIT ]] .. limit, { ['@q'] = like }, function(rows)
        local out = {}
        for _, r in ipairs(rows or {}) do
            local ok, info = pcall(json.decode, r.characterInfos)
            if ok and info then
                out[#out + 1] = {
                    identifier       = r.identifier,
                    character_id     = r.character_id,
                    name             = ((info.Prenom or '') .. ' ' .. (info.NDF or '')):gsub('^%s+', ''):gsub('%s+$', ''),
                    sexe             = info.Sexe,
                    ddn              = info.DDN,
                    hasRecord        = (tonumber(r.has_record) or 0) > 0,
                    activeTreatments = tonumber(r.active_treatments) or 0,
                }
            end
        end
        reply(out)
    end)
end

-- Dossier médical complet d'un patient : identité + fiche + entrées +
-- traitements. Aucun casier, aucune amende, aucune garde à vue.
readHandlers.getPatient = function(player, grade, data, reply)
    local characterId = tonumber(data.character_id)
    if not characterId then return reply(false) end

    MySQL.Async.fetchAll('SELECT identifier, characterInfos FROM players WHERE `boutique-id` = @id LIMIT 1',
        { ['@id'] = characterId }, function(prows)
        local prow = prows and prows[1]
        if not prow then return reply(false) end
        local ok, info = pcall(json.decode, prow.characterInfos)
        if not ok or not info then return reply(false) end

        local identity = {
            identifier = prow.identifier,
            character_id = characterId,
            name   = ((info.Prenom or '') .. ' ' .. (info.NDF or '')):gsub('^%s+', ''):gsub('%s+$', ''),
            nom    = info.NDF,
            prenom = info.Prenom,
            sexe   = info.Sexe,
            ddn    = info.DDN,
            ldn    = info.LDN,
            taille = info.Taille,
        }

        MySQL.Async.fetchAll('SELECT * FROM mdt_med_records WHERE character_id = @id LIMIT 1',
            { ['@id'] = characterId }, function(rrows)
            local record = rrows and rrows[1] or nil
            MySQL.Async.fetchAll('SELECT * FROM mdt_med_entries WHERE character_id = @id ORDER BY created_at DESC LIMIT 100',
                { ['@id'] = characterId }, function(erows)
                MySQL.Async.fetchAll('SELECT * FROM mdt_med_treatments WHERE character_id = @id ORDER BY created_at DESC LIMIT 100',
                    { ['@id'] = characterId }, function(trows)
                    reply({
                        identity   = identity,
                        record     = record,
                        entries    = erows or {},
                        treatments = trows or {},
                    })
                end)
            end)
        end)
    end)
end

-- Traitements actifs, tous patients confondus (onglet Traitements).
readHandlers.getTreatments = function(player, grade, data, reply)
    local status = type(data.status) == 'string' and data.status or 'actif'
    if not isAllowed(Config.Medical.TreatmentStatuses, status, 'id') then status = 'actif' end
    MySQL.Async.fetchAll([[
        SELECT t.*, p.characterInfos
        FROM mdt_med_treatments t
        LEFT JOIN players p ON p.`boutique-id` = t.character_id
        WHERE t.status = @s
        ORDER BY t.created_at DESC
        LIMIT 200
    ]], { ['@s'] = status }, function(rows)
        local out = {}
        for _, r in ipairs(rows or {}) do
            local name = '?'
            if r.characterInfos then
                local ok, info = pcall(json.decode, r.characterInfos)
                if ok and info then
                    name = ((info.Prenom or '') .. ' ' .. (info.NDF or '')):gsub('^%s+', ''):gsub('%s+$', '')
                end
            end
            r.characterInfos = nil
            r.patientName = name
            out[#out + 1] = r
        end
        reply(out)
    end)
end

-- Données du dashboard : effectif en service, dernier appel, petit mot.
readHandlers.getDashboard = function(player, grade, data, reply)
    -- Effectif en service : source de vérité = la table en mémoire du
    -- module SAMU (GetSamuAgents), pas la BDD, pour refléter l'instant.
    local onDuty = {}
    if type(GetSamuAgents) == 'function' then
        for src, agent in pairs(GetSamuAgents() or {}) do
            if agent and agent.onDuty then
                local p = LSLegacy.Players.Get(src)
                onDuty[#onDuty + 1] = {
                    name       = agent.name or (p and charName(p)) or '?',
                    grade      = agent.grade or 0,
                    gradeLabel = LSLegacy.MDT.GetGradeLabel(DEPARTMENT, agent.grade or 0),
                }
            end
        end
    end
    table.sort(onDuty, function(a, b) return (a.grade or 0) > (b.grade or 0) end)

    MySQL.Async.fetchAll([[
        SELECT c.*, p.characterInfos
        FROM mdt_med_calls c
        LEFT JOIN players p ON p.identifier = c.caller_identifier
        ORDER BY c.created_at DESC LIMIT 5
    ]], {}, function(crows)
        -- Les 5 derniers appels (et non plus un seul) : la tuile en liste
        -- plusieurs, ce qui remplit utilement le tableau de bord.
        local recentCalls = {}
        for _, c in ipairs(crows or {}) do
            if c.characterInfos then
                local ok, info = pcall(json.decode, c.characterInfos)
                if ok and info then
                    c.callerName = ((info.Prenom or '') .. ' ' .. (info.NDF or '')):gsub('^%s+', ''):gsub('%s+$', '')
                end
                c.characterInfos = nil
            end
            c.callerName = c.callerName or c.caller_name or 'Inconnu'
            c.zone = nearestDistrict(c.x, c.y)
            recentCalls[#recentCalls + 1] = c
        end

        MySQL.Async.fetchAll('SELECT * FROM mdt_med_board WHERE active = 1 ORDER BY created_at DESC LIMIT 5',
            {}, function(brows)
            -- Chiffres de synthèse du service, en une seule requête.
            MySQL.Async.fetchAll([[
                SELECT
                    (SELECT COUNT(*) FROM mdt_med_calls  WHERE status = 'pending')   AS pending,
                    (SELECT COUNT(*) FROM mdt_med_calls  WHERE DATE(created_at) = CURDATE()) AS calls_today,
                    (SELECT COUNT(*) FROM mdt_med_records)                           AS patients,
                    (SELECT COUNT(*) FROM mdt_med_treatments WHERE status = 'actif')  AS treatments,
                    (SELECT COUNT(*) FROM mdt_med_entries WHERE DATE(created_at) = CURDATE()) AS entries_today,
                    (SELECT COUNT(*) FROM mdt_med_docs)                              AS docs
            ]], {}, function(st)
                local r = (st and st[1]) or {}
                reply({
                    onDuty       = onDuty,
                    onDutyCount  = #onDuty,
                    recentCalls  = recentCalls,
                    pendingCalls = tonumber(r.pending) or 0,
                    board        = brows or {},
                    canPostBoard = LSLegacy.MDT.HasPermission(DEPARTMENT, grade, 'manage_board'),
                    -- État de service du demandeur, pour le bouton du dashboard.
                    -- Lu côté serveur (source de vérité), jamais déduit du client.
                    meOnDuty     = (type(IsSamuOnDuty) == 'function' and IsSamuOnDuty(player.source) == true),
                    stats = {
                        patients     = tonumber(r.patients) or 0,
                        treatments   = tonumber(r.treatments) or 0,
                        callsToday   = tonumber(r.calls_today) or 0,
                        entriesToday = tonumber(r.entries_today) or 0,
                        docs         = tonumber(r.docs) or 0,
                    },
                })
            end)
        end)
    end)
end

-- Dispatch : appels ouverts + positions temps réel des ambulanciers.
readHandlers.getDispatch = function(player, grade, data, reply)
    -- Les appels sont lus D'ABORD : ils déterminent le statut des unités
    -- (une unité affectée à un appel ouvert est « en intervention »,
    -- sinon elle est « en patrouille »).
    MySQL.Async.fetchAll([[
        SELECT c.*, p.characterInfos
        FROM mdt_med_calls c
        LEFT JOIN players p ON p.identifier = c.caller_identifier
        WHERE c.status IN ('pending','assigned')
        ORDER BY c.created_at DESC LIMIT 50
    ]], {}, function(rows)
        local calls = {}
        local assignedTo = {} -- [identifier] = appel en cours de traitement

        for _, r in ipairs(rows or {}) do
            if r.characterInfos then
                local ok, info = pcall(json.decode, r.characterInfos)
                if ok and info then
                    r.callerName = ((info.Prenom or '') .. ' ' .. (info.NDF or '')):gsub('^%s+', ''):gsub('%s+$', '')
                end
                r.characterInfos = nil
            end
            r.callerName = r.callerName or r.caller_name or 'Inconnu'
            r.zone = nearestDistrict(r.x, r.y)
            calls[#calls + 1] = r

            if r.status == 'assigned' and r.assigned_identifier then
                assignedTo[r.assigned_identifier] = r
            end
        end

        local units = {}
        if type(GetSamuAgents) == 'function' then
            for src, agent in pairs(GetSamuAgents() or {}) do
                if agent and agent.onDuty then
                    local ped = GetPlayerPed(src)
                    local coords = ped and ped ~= 0 and GetEntityCoords(ped) or nil
                    local up = LSLegacy.Players.Get(src)
                    local ident = up and up.identifier or nil
                    local onCall = ident and assignedTo[ident] or nil

                    -- `GetVehiclePedIsIn` existe côté serveur ;
                    -- `IsPedInAnyVehicle` non (native client uniquement) —
                    -- même piège que `IsEntityDead`, qui plantait le module farm.
                    local veh = ped and ped ~= 0 and GetVehiclePedIsIn(ped) or nil

                    units[#units + 1] = {
                        name       = agent.name or (up and charName(up)) or '?',
                        gradeLabel = LSLegacy.MDT.GetGradeLabel(DEPARTMENT, agent.grade or 0),
                        grade      = agent.grade or 0,
                        zone       = coords and nearestDistrict(coords.x, coords.y) or nil,
                        inVehicle  = (veh ~= nil and veh ~= 0),
                        status     = onCall and 'inter' or 'patrouille',
                        callId     = onCall and onCall.id or nil,
                        callZone   = onCall and onCall.zone or nil,
                        callCaller = onCall and onCall.callerName or nil,
                    }
                end
            end
        end

        -- Interventions en tête, puis grade décroissant : ce qui demande
        -- une attention immédiate remonte en haut de liste.
        table.sort(units, function(a, b)
            if (a.status == 'inter') ~= (b.status == 'inter') then
                return a.status == 'inter'
            end
            return (a.grade or 0) > (b.grade or 0)
        end)

        reply({ units = units, calls = calls })
    end)
end

-- Historique des appels clos (onglet Dispatch, second bloc).
readHandlers.getCallHistory = function(player, grade, data, reply)
    MySQL.Async.fetchAll([[
        SELECT * FROM mdt_med_calls
        WHERE status IN ('done','cancelled')
        ORDER BY created_at DESC LIMIT 50
    ]], {}, function(rows)
        reply(rows or {})
    end)
end

-- Documents internes (liste, filtrable par catégorie).
readHandlers.getDocs = function(player, grade, data, reply)
    local category = type(data.category) == 'string' and data.category or ''
    if category ~= '' and not isAllowed(Config.Medical.DocCategories, category) then category = '' end
    local sql = 'SELECT * FROM mdt_med_docs'
    local params = {}
    if category ~= '' then
        sql = sql .. ' WHERE category = @c'
        params['@c'] = category
    end
    sql = sql .. ' ORDER BY pinned DESC, updated_at DESC LIMIT 200'
    MySQL.Async.fetchAll(sql, params, function(rows)
        reply(rows or {})
    end)
end

-- Permission requise par action de lecture.
local readPerms = {
    getMedConfig    = nil, -- simples catalogues, aucune donnée patient
    searchPatients  = 'view_med_records',
    getPatient      = 'view_med_records',
    getTreatments   = 'view_treatments',
    getDashboard    = nil, -- dashboard visible dès le grade 0
    getDispatch     = 'view_dispatch',
    getCallHistory  = 'view_dispatch',
    getDocs         = 'view_med_docs',
}

LSLegacy.Events.Register('mdtmed:query', function(data)
    local src = source
    if type(data) ~= 'table' or not data.reqId or type(data.action) ~= 'string' then return end

    local function reply(res)
        LSLegacy.Events.SendToClient('mdtmed:queryResult', src, { reqId = data.reqId, result = res })
    end

    local handler = readHandlers[data.action]
    if not handler then return reply(false) end

    local player, grade = medCtx(src)
    if not player then return reply(false) end

    local perm = readPerms[data.action]
    if perm and not LSLegacy.MDT.HasPermission(DEPARTMENT, grade, perm) then return reply(false) end

    handler(player, grade, type(data.data) == 'table' and data.data or {}, reply)
end)

--  ÉCRITURES

-- Fiche médicale : création si absente, mise à jour sinon.
LSLegacy.Events.Register('mdtmed:saveRecord', function(data)
    local src = source
    local player, grade = can(src, 'edit_med_records')
    if not player then return end
    if type(data) ~= 'table' then return end

    local ident = safeIdentifier(data.identifier)
    if not ident then return result(src, false, 'Patient invalide.') end

    local blood = type(data.blood_group) == 'string' and data.blood_group or ''
    if blood ~= '' and not isAllowed(Config.Medical.BloodGroups, blood) then blood = '' end

    local params = {
        ['@id']    = ident,
        ['@bg']    = blood ~= '' and blood or nil,
        ['@al']    = safeText(data.allergies, L.MaxTextLength),
        ['@an']    = safeText(data.antecedents, L.MaxTextLength),
        ['@on']    = safeText(data.ongoing, L.MaxTextLength),
        ['@no']    = safeText(data.notes, L.MaxTextLength),
        ['@dnr']   = data.dnr and 1 or 0,
        ['@by']    = charName(player),
    }

    LSLegacy.ResolveCharacterId(ident, function(charId)
        params['@charId'] = charId
        MySQL.Async.execute([[
            INSERT INTO mdt_med_records (identifier, character_id, blood_group, allergies, antecedents, ongoing, notes, dnr, updated_by)
            VALUES (@id, @charId, @bg, @al, @an, @on, @no, @dnr, @by)
            ON DUPLICATE KEY UPDATE
                blood_group = @bg, allergies = @al, antecedents = @an,
                ongoing = @on, notes = @no, dnr = @dnr, updated_by = @by
        ]], params, function()
            result(src, true, 'Dossier médical enregistré.', { view = 'med_patient', id = ident })
        end)
    end)
end)

-- Ajout d'une entrée (consultation, intervention…) au dossier.
LSLegacy.Events.Register('mdtmed:addEntry', function(data)
    local src = source
    local player, grade = can(src, 'med_add_entry')
    if not player then return end
    if type(data) ~= 'table' then return end

    local ident = safeIdentifier(data.identifier)
    if not ident then return result(src, false, 'Patient invalide.') end

    local title = safeText(data.title, L.MaxTitleLength)
    if title == '' then return result(src, false, 'Le titre est obligatoire.') end

    local etype = type(data.type) == 'string' and data.type or 'consultation'
    if not isAllowed(Config.Medical.EntryTypes, etype, 'id') then etype = 'consultation' end

    LSLegacy.ResolveCharacterId(ident, function(charId)
        MySQL.Async.execute([[
            INSERT INTO mdt_med_entries (identifier, character_id, type, title, content, author_identifier, author_name)
            VALUES (@id, @charId, @ty, @ti, @co, @ai, @an)
        ]], {
            ['@id'] = ident,
            ['@charId'] = charId,
            ['@ty'] = etype,
            ['@ti'] = title,
            ['@co'] = safeText(data.content, L.MaxTextLength),
            ['@ai'] = player.identifier,
            ['@an'] = charName(player),
        }, function()
            result(src, true, 'Entrée ajoutée au dossier.', { view = 'med_patient', id = ident })
        end)
    end)
end)

-- Suppression d'une entrée de dossier (chef de service uniquement).
LSLegacy.Events.Register('mdtmed:deleteEntry', function(data)
    local src = source
    local player = can(src, 'med_delete_entry')
    if not player then return end
    local id = tonumber(type(data) == 'table' and data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_med_entries WHERE id = @i', { ['@i'] = id }, function()
        result(src, true, 'Entrée supprimée.', { view = 'med_patient' })
    end)
end)

-- Prescription d'un traitement.
LSLegacy.Events.Register('mdtmed:addTreatment', function(data)
    local src = source
    local player = can(src, 'manage_treatments')
    if not player then return end
    if type(data) ~= 'table' then return end

    local ident = safeIdentifier(data.identifier)
    if not ident then return result(src, false, 'Patient invalide.') end

    local label = safeText(data.label, L.MaxTitleLength)
    if label == '' then return result(src, false, 'Le libellé du traitement est obligatoire.') end

    local code = type(data.code) == 'string' and data.code or ''
    if code ~= '' and not isAllowed(Config.Medical.Treatments, code, 'code') then code = '' end

    LSLegacy.ResolveCharacterId(ident, function(charId)
        MySQL.Async.execute([[
            INSERT INTO mdt_med_treatments
                (identifier, character_id, code, label, dosage, duration, notes, status, prescriber_identifier, prescriber_name)
            VALUES (@id, @charId, @cd, @la, @do, @du, @no, 'actif', @pi, @pn)
        ]], {
            ['@id'] = ident,
            ['@charId'] = charId,
            ['@cd'] = code ~= '' and code or nil,
            ['@la'] = label,
            ['@do'] = safeText(data.dosage, L.MaxShortLength),
            ['@du'] = safeText(data.duration, L.MaxShortLength),
            ['@no'] = safeText(data.notes, L.MaxTextLength),
            ['@pi'] = player.identifier,
            ['@pn'] = charName(player),
        }, function()
            result(src, true, 'Traitement prescrit.', { view = 'med_treatments', id = ident })
        end)
    end)
end)

-- Changement de statut d'un traitement (terminé / annulé / réactivé).
LSLegacy.Events.Register('mdtmed:setTreatmentStatus', function(data)
    local src = source
    local player = can(src, 'manage_treatments')
    if not player then return end
    if type(data) ~= 'table' then return end

    local id = tonumber(data.id)
    local status = type(data.status) == 'string' and data.status or ''
    if not id or not isAllowed(Config.Medical.TreatmentStatuses, status, 'id') then return end

    local ended = (status == 'actif') and 'NULL' or 'NOW()'
    MySQL.Async.execute(
        'UPDATE mdt_med_treatments SET status = @s, ended_at = ' .. ended .. ' WHERE id = @i',
        { ['@s'] = status, ['@i'] = id }, function()
        result(src, true, 'Traitement mis à jour.', { view = 'med_treatments' })
    end)
end)

-- Prise en charge d'un appel.
LSLegacy.Events.Register('mdtmed:assignCall', function(data)
    local src = source
    local player = can(src, 'manage_dispatch')
    if not player then return end
    local id = tonumber(type(data) == 'table' and data.id)
    if not id then return end
    MySQL.Async.execute([[
        UPDATE mdt_med_calls
        SET status = 'assigned', assigned_identifier = @ai, assigned_name = @an
        WHERE id = @i AND status = 'pending'
    ]], {
        ['@i']  = id,
        ['@ai'] = player.identifier,
        ['@an'] = charName(player),
    }, function()
        result(src, true, 'Appel pris en charge.', { view = 'med_dispatch' })
    end)
end)

-- Clôture d'un appel (traité ou annulé).
LSLegacy.Events.Register('mdtmed:closeCall', function(data)
    local src = source
    local player = can(src, 'manage_dispatch')
    if not player then return end
    if type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    if not id then return end
    local status = (data.status == 'cancelled') and 'cancelled' or 'done'
    MySQL.Async.execute(
        "UPDATE mdt_med_calls SET status = @s, closed_at = NOW() WHERE id = @i AND status IN ('pending','assigned')",
        { ['@s'] = status, ['@i'] = id }, function()
        result(src, true, status == 'done' and 'Appel clôturé.' or 'Appel annulé.', { view = 'med_dispatch' })
    end)
end)

-- Création / mise à jour d'un document interne.
LSLegacy.Events.Register('mdtmed:saveDoc', function(data)
    local src = source
    local player = can(src, 'manage_med_docs')
    if not player then return end
    if type(data) ~= 'table' then return end

    local title = safeText(data.title, L.MaxTitleLength)
    if title == '' then return result(src, false, 'Le titre est obligatoire.') end

    local category = type(data.category) == 'string' and data.category or 'Général'
    if not isAllowed(Config.Medical.DocCategories, category) then category = 'Général' end

    local id = tonumber(data.id)
    if id then
        MySQL.Async.execute([[
            UPDATE mdt_med_docs SET category = @ca, title = @ti, content = @co, pinned = @pi WHERE id = @i
        ]], {
            ['@i']  = id,
            ['@ca'] = category,
            ['@ti'] = title,
            ['@co'] = safeText(data.content, L.MaxTextLength),
            ['@pi'] = data.pinned and 1 or 0,
        }, function()
            result(src, true, 'Document mis à jour.', { view = 'med_docs' })
        end)
    else
        MySQL.Async.execute([[
            INSERT INTO mdt_med_docs (category, title, content, author_identifier, author_name, pinned)
            VALUES (@ca, @ti, @co, @ai, @an, @pi)
        ]], {
            ['@ca'] = category,
            ['@ti'] = title,
            ['@co'] = safeText(data.content, L.MaxTextLength),
            ['@ai'] = player.identifier,
            ['@an'] = charName(player),
            ['@pi'] = data.pinned and 1 or 0,
        }, function()
            result(src, true, 'Document créé.', { view = 'med_docs' })
        end)
    end
end)

-- Suppression d'un document interne.
LSLegacy.Events.Register('mdtmed:deleteDoc', function(data)
    local src = source
    local player = can(src, 'manage_med_docs')
    if not player then return end
    local id = tonumber(type(data) == 'table' and data.id)
    if not id then return end
    MySQL.Async.execute('DELETE FROM mdt_med_docs WHERE id = @i', { ['@i'] = id }, function()
        result(src, true, 'Document supprimé.', { view = 'med_docs' })
    end)
end)

-- Publication du petit mot du dashboard (cheffes d'équipe).
LSLegacy.Events.Register('mdtmed:postBoard', function(data)
    local src = source
    local player, grade = can(src, 'manage_board')
    if not player then return end
    if type(data) ~= 'table' then return end

    local message = safeText(data.message, L.MaxBoardLength)
    if message == '' then return result(src, false, 'Le message est vide.') end

    MySQL.Async.execute([[
        INSERT INTO mdt_med_board (author_identifier, author_name, author_grade, message)
        VALUES (@ai, @an, @ag, @me)
    ]], {
        ['@ai'] = player.identifier,
        ['@an'] = charName(player),
        ['@ag'] = LSLegacy.MDT.GetGradeLabel(DEPARTMENT, grade),
        ['@me'] = message,
    }, function()
        result(src, true, 'Message publié.', { view = 'med_dashboard' })
    end)
end)

-- Retrait d'un petit mot.
LSLegacy.Events.Register('mdtmed:removeBoard', function(data)
    local src = source
    local player = can(src, 'manage_board')
    if not player then return end
    local id = tonumber(type(data) == 'table' and data.id)
    if not id then return end
    MySQL.Async.execute('UPDATE mdt_med_board SET active = 0 WHERE id = @i', { ['@i'] = id }, function()
        result(src, true, 'Message retiré.', { view = 'med_dashboard' })
    end)
end)

--  HISTORISATION DES APPELS
--  Le module SAMU diffusait déjà `samu:patientCall` aux agents en
--  service sans jamais le stocker. On l'écoute en plus (sans le
--  remplacer) pour alimenter le dashboard et le dispatch.

AddEventHandler('samu:patientCall', function(data)
    if type(data) ~= 'table' or not data.coords then return end
    local c = data.coords
    -- `data.identifier` n'est jamais renseigné par l'appelant (lslegacy:injuryCallEMS
    -- ne le passe pas) : on résout l'appelant depuis `data.source`, toujours en ligne
    -- puisqu'il appelle depuis son propre coma.
    local caller = data.source and LSLegacy.Players.Get(data.source)
    MySQL.Async.execute([[
        INSERT INTO mdt_med_calls (caller_identifier, character_id, caller_name, x, y, z, reason, status)
        VALUES (@ci, @charId, @cn, @x, @y, @z, @re, 'pending')
    ]], {
        ['@ci'] = (caller and caller.identifier) or data.identifier or nil,
        ['@charId'] = caller and caller["boutique-id"] or nil,
        ['@cn'] = data.name or 'Inconnu',
        ['@x']  = tonumber(c.x) or 0.0,
        ['@y']  = tonumber(c.y) or 0.0,
        ['@z']  = tonumber(c.z) or 0.0,
        ['@re'] = data.reason or 'Appel patient',
    })
end)
