--  MODULE POLICE NATIONALE — Investigation / Preuves (serveur)
--  Empreintes, ADN, sang, scènes de crime — stockage persistant

local sceneCounter = 0

local function HasInvPermission(src)
    if not IsLawEnforcementOnDuty(src) then return false end
    local grade = tonumber(GetPlayer(src).job_grade) or 0
    return LSLegacy.MDT.HasPermission('police', grade, 'view_evidence')
end

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, '🔬 PTS', msg, t or 'info', 5000)
end

local function GenerateRef(prefix)
    return string.format('%s-%d-%04d', prefix, os.time(), math.random(1000, 9999))
end

-- Tables SQL

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS police_fingerprints (
        id          INT AUTO_INCREMENT PRIMARY KEY,
        ref         VARCHAR(50)  NOT NULL UNIQUE,
        identifier  VARCHAR(60)  NOT NULL,
        character_id INT         DEFAULT NULL,
        citizen_name VARCHAR(100) NOT NULL DEFAULT '',
        collected_by VARCHAR(60)  NOT NULL DEFAULT '',
        collected_by_character_id INT DEFAULT NULL,
        officer_name VARCHAR(100) NOT NULL DEFAULT '',
        target_src  INT          DEFAULT NULL,
        created_at  DATETIME     DEFAULT CURRENT_TIMESTAMP,
        scene_id    VARCHAR(50)  DEFAULT NULL,
        KEY idx_fp_ident (identifier),
        KEY idx_fp_ref (ref)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS police_dna (
        id          INT AUTO_INCREMENT PRIMARY KEY,
        ref         VARCHAR(50)  NOT NULL UNIQUE,
        identifier  VARCHAR(60)  NOT NULL,
        character_id INT         DEFAULT NULL,
        citizen_name VARCHAR(100) NOT NULL DEFAULT '',
        collected_by VARCHAR(60)  NOT NULL DEFAULT '',
        collected_by_character_id INT DEFAULT NULL,
        officer_name VARCHAR(100) NOT NULL DEFAULT '',
        created_at  DATETIME     DEFAULT CURRENT_TIMESTAMP,
        scene_id    VARCHAR(50)  DEFAULT NULL,
        KEY idx_dna_ident (identifier),
        KEY idx_dna_ref (ref)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS police_blood_traces (
        id                     INT AUTO_INCREMENT PRIMARY KEY,
        ref                    VARCHAR(50)  NOT NULL UNIQUE,
        collected_by           VARCHAR(60)  NOT NULL DEFAULT '',
        collected_by_character_id INT      DEFAULT NULL,
        officer_name           VARCHAR(100) NOT NULL DEFAULT '',
        x                      FLOAT        NOT NULL DEFAULT 0,
        y                      FLOAT        NOT NULL DEFAULT 0,
        z                      FLOAT        NOT NULL DEFAULT 0,
        scene_id               VARCHAR(50)  DEFAULT NULL,
        created_at             DATETIME     DEFAULT CURRENT_TIMESTAMP,
        KEY idx_bt_scene (scene_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- Description détaillée éditable depuis le MDT (ajout rétro-compatible)
MySQL.Async.execute("ALTER TABLE police_fingerprints  ADD COLUMN IF NOT EXISTS description TEXT DEFAULT NULL", {})
MySQL.Async.execute("ALTER TABLE police_dna           ADD COLUMN IF NOT EXISTS description TEXT DEFAULT NULL", {})
MySQL.Async.execute("ALTER TABLE police_blood_traces  ADD COLUMN IF NOT EXISTS description TEXT DEFAULT NULL", {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS police_crime_scenes (
        id                  INT AUTO_INCREMENT PRIMARY KEY,
        scene_id            VARCHAR(50)  NOT NULL UNIQUE,
        created_by          VARCHAR(60)  NOT NULL DEFAULT '',
        created_by_character_id INT      DEFAULT NULL,
        officer_name        VARCHAR(100) NOT NULL DEFAULT '',
        x                   FLOAT        NOT NULL DEFAULT 0,
        y                   FLOAT        NOT NULL DEFAULT 0,
        z                   FLOAT        NOT NULL DEFAULT 0,
        secured             TINYINT(1)   NOT NULL DEFAULT 1,
        created_at          DATETIME     DEFAULT CURRENT_TIMESTAMP,
        closed_at           DATETIME     DEFAULT NULL,
        KEY idx_cs_scene (scene_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

--  EMPREINTES

LSLegacy.Events.Register('police:inv:collectFingerprints', function(data)
    local src = source
    if not HasInvPermission(src) then return end
    if not data or not data.target then return end

    local target   = tonumber(data.target)
    local tp       = GetPlayer(target)
    if not tp then return end

    local ref      = GenerateRef('FP')
    local oIdent   = GetIdent(src)
    local oCharId  = GetPlayer(src) and GetPlayer(src)["boutique-id"] or nil
    local oName    = GetName(src)
    local tIdent   = tp.identifier
    local tCharId  = tp["boutique-id"]
    local tName    = GetName(target)

    MySQL.Async.execute(
        'INSERT INTO police_fingerprints (ref, identifier, character_id, citizen_name, collected_by, collected_by_character_id, officer_name, target_src, scene_id) ' ..
        'VALUES (@ref, @id, @charId, @cname, @oid, @oCharId, @oname, @tsrc, @scene) ' ..
        'ON DUPLICATE KEY UPDATE ref=@ref',
        { ['@ref'] = ref, ['@id'] = tIdent, ['@charId'] = tCharId, ['@cname'] = tName,
          ['@oid'] = oIdent, ['@oCharId'] = oCharId, ['@oname'] = oName,
          ['@tsrc'] = target, ['@scene'] = data.sceneId }
    )

    TriggerClientEvent('police:inv:fingerprintsResult', src, {
        ref  = ref,
        name = tName,
    })

    -- Enregistrer la preuve dans le MDT
    MySQL.Async.execute(
        'INSERT INTO mdt_evidence (department, scene_id, type, ref, description, collected_by, officer_name, identifier) ' ..
        'VALUES (@dep, @sid, @type, @ref, @desc, @oid, @oname, @ident)',
        {
            ['@dep']   = 'police',
            ['@sid']   = data.sceneId or '',
            ['@type']  = 'fingerprint',
            ['@ref']   = ref,
            ['@desc']  = 'Empreintes relevées sur ' .. tName,
            ['@oid']   = oIdent,
            ['@oname'] = oName,
            ['@ident'] = tIdent,
        }
    )
end)

-- Comparaison empreintes
LSLegacy.Events.Register('police:inv:compareFingerprints', function(data)
    local src = source
    if not HasInvPermission(src) then return end
    if not data or not data.ref then return end

    MySQL.Async.fetchAll(
        'SELECT citizen_name, identifier FROM police_fingerprints WHERE ref=@ref LIMIT 1',
        { ['@ref'] = data.ref },
        function(rows)
            if rows and rows[1] then
                TriggerClientEvent('police:inv:fingerprintsMatch', src, {
                    name       = rows[1].citizen_name,
                    identifier = rows[1].identifier,
                })
            else
                TriggerClientEvent('police:inv:fingerprintsMatch', src, { name = nil })
            end
        end
    )
end)

--  ADN

LSLegacy.Events.Register('police:inv:collectDNA', function(data)
    local src = source
    if not HasInvPermission(src) then return end
    if not data or not data.target then return end

    local target = tonumber(data.target)
    local tp     = GetPlayer(target)
    if not tp then return end

    local ref    = GenerateRef('DNA')
    local oIdent = GetIdent(src)
    local oCharId = GetPlayer(src) and GetPlayer(src)["boutique-id"] or nil
    local oName  = GetName(src)
    local tIdent = tp.identifier
    local tCharId = tp["boutique-id"]
    local tName  = GetName(target)

    MySQL.Async.execute(
        'INSERT INTO police_dna (ref, identifier, character_id, citizen_name, collected_by, collected_by_character_id, officer_name, scene_id) ' ..
        'VALUES (@ref, @id, @charId, @cname, @oid, @oCharId, @oname, @scene)',
        { ['@ref'] = ref, ['@id'] = tIdent, ['@charId'] = tCharId, ['@cname'] = tName,
          ['@oid'] = oIdent, ['@oCharId'] = oCharId, ['@oname'] = oName, ['@scene'] = data.sceneId }
    )

    TriggerClientEvent('police:inv:dnaResult', src, { ref = ref, name = tName })

    MySQL.Async.execute(
        'INSERT INTO mdt_evidence (department, scene_id, type, ref, description, collected_by, officer_name, identifier) ' ..
        'VALUES (@dep, @sid, @type, @ref, @desc, @oid, @oname, @ident)',
        { ['@dep'] = 'police', ['@sid'] = data.sceneId or '', ['@type'] = 'dna',
          ['@ref'] = ref, ['@desc'] = 'Prélèvement ADN sur ' .. tName,
          ['@oid'] = oIdent, ['@oname'] = oName, ['@ident'] = tIdent }
    )
end)

LSLegacy.Events.Register('police:inv:compareDNA', function(data)
    local src = source
    if not HasInvPermission(src) then return end
    if not data or not data.ref then return end

    MySQL.Async.fetchAll(
        'SELECT citizen_name, identifier FROM police_dna WHERE ref=@ref LIMIT 1',
        { ['@ref'] = data.ref },
        function(rows)
            if rows and rows[1] then
                TriggerClientEvent('police:inv:dnaMatch', src, {
                    name       = rows[1].citizen_name,
                    identifier = rows[1].identifier,
                })
            else
                TriggerClientEvent('police:inv:dnaMatch', src, { name = nil })
            end
        end
    )
end)

--  TRACES DE SANG

LSLegacy.Events.Register('police:inv:collectBlood', function(data)
    local src = source
    if not HasInvPermission(src) then return end
    if not data then return end

    local ref    = GenerateRef('SANG')
    local oIdent = GetIdent(src)
    local oName  = GetName(src)

    MySQL.Async.execute(
        'INSERT INTO police_blood_traces (ref, collected_by, collected_by_character_id, officer_name, x, y, z, scene_id) ' ..
        'VALUES (@ref, @oid, @charId, @oname, @x, @y, @z, @scene)',
        { ['@ref'] = ref, ['@oid'] = oIdent, ['@charId'] = GetCharacterId(src), ['@oname'] = oName,
          ['@x'] = data.x or 0, ['@y'] = data.y or 0, ['@z'] = data.z or 0,
          ['@scene'] = data.sceneId }
    )

    TriggerClientEvent('police:inv:bloodResult', src, { ref = ref })

    MySQL.Async.execute(
        'INSERT INTO mdt_evidence (department, scene_id, type, ref, description, collected_by, officer_name) ' ..
        'VALUES (@dep, @sid, @type, @ref, @desc, @oid, @oname)',
        { ['@dep'] = 'police', ['@sid'] = data.sceneId or '', ['@type'] = 'blood',
          ['@ref'] = ref, ['@desc'] = string.format('Trace de sang — %.1f / %.1f / %.1f', data.x or 0, data.y or 0, data.z or 0),
          ['@oid'] = oIdent, ['@oname'] = oName }
    )
end)

--  SCÈNE DE CRIME

LSLegacy.Events.Register('police:inv:createScene', function(data)
    local src = source
    if not HasInvPermission(src) then return end
    if not LSLegacy.MDT.HasPermission('police', tonumber(GetPlayer(src).job_grade) or 0, 'manage_evidence') then
        LSLegacy.Events.SendToClient('notify', src, 'PTS', Lang.Police.grade_required, 'error', 4000)
        return
    end
    if not data then return end

    sceneCounter = sceneCounter + 1
    local sceneId = 'SC' .. os.time() .. '_' .. sceneCounter
    local oIdent  = GetIdent(src)
    local oName   = GetName(src)

    MySQL.Async.execute(
        'INSERT INTO police_crime_scenes (scene_id, created_by, created_by_character_id, officer_name, x, y, z) ' ..
        'VALUES (@sid, @oid, @charId, @oname, @x, @y, @z)',
        { ['@sid'] = sceneId, ['@oid'] = oIdent, ['@charId'] = GetCharacterId(src), ['@oname'] = oName,
          ['@x'] = data.x or 0, ['@y'] = data.y or 0, ['@z'] = data.z or 0 }
    )

    -- Diffuser la scène à tous les policiers en service
    for officer_src in pairs(GetPoliceOfficers()) do
        TriggerClientEvent('police:inv:sceneCreated', officer_src, {
            sceneId = sceneId,
            x = data.x, y = data.y, z = data.z,
        })
    end
end)

--  RADIO — Tracking canal (voix déléguée à pma-voice côté client)
--  Le serveur conserve seulement quel officier est sur quel canal
--  pour les logs et l'affichage HUD ; pma-voice gère tout le reste.

local OfficerChannels = {}  -- { [src] = channelId }

LSLegacy.Events.Register('police:radio:join', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not data or not data.channelId then return end
    OfficerChannels[src] = tonumber(data.channelId)
end)

LSLegacy.Events.Register('police:radio:leave', function()
    local src = source
    OfficerChannels[src] = nil
end)

AddEventHandler('police:radio:leaveAll', function(src)
    OfficerChannels[src] = nil
end)

-- Export : canal actif d'un officier (utilisable par d'autres modules)
function GetOfficerChannel(src)
    return OfficerChannels[src]
end

-- Nettoyage à la déco
AddEventHandler('playerDropped', function()
    OfficerChannels[source] = nil
end)
