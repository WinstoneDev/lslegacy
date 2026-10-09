--  MODULE POLICE NATIONALE — Stand de tir (serveur)
--  Réservé aux formateurs (compétence CZ001) et au Commissaire. Le
--  formateur sélectionne un agent à proximité, une difficulté et un
--  nombre de cibles ; le test se déroule sur le client du testé, jamais
--  sur celui du formateur. Le testé ne voit jamais son score — seul le
--  formateur en est notifié, et il n'est enregistré en base que si le
--  testé est policier (sert ensuite au bloc « Stand de tir » de sa fiche
--  agent MDT).

local C = Config.Police.ShootingRange
local DIFF_BY_ID, STAND_BY_ID = {}, {}
for _, d in ipairs(C.Difficulties) do DIFF_BY_ID[d.id] = d end
for _, s in ipairs(C.Stands) do STAND_BY_ID[s.id] = s end

LSLegacy.Security.RegisterRateLimit('range:getNearby', 20)
LSLegacy.Security.RegisterRateLimit('range:startTest', 10)
LSLegacy.Security.RegisterRateLimit('range:finishTest', 10)

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS police_range_scores (
        id                    INT AUTO_INCREMENT PRIMARY KEY,
        character_id          INT          NOT NULL,
        name                  VARCHAR(100) NOT NULL DEFAULT '',
        trainer_character_id  INT          DEFAULT NULL,
        trainer_name          VARCHAR(100) NOT NULL DEFAULT '',
        stand_id              VARCHAR(40)  NOT NULL DEFAULT '',
        difficulty            VARCHAR(20)  NOT NULL DEFAULT '',
        difficulty_label      VARCHAR(30)  NOT NULL DEFAULT '',
        target_count          INT          NOT NULL DEFAULT 0,
        hits                  INT          NOT NULL DEFAULT 0,
        score                 INT          NOT NULL DEFAULT 0,
        max_score             INT          NOT NULL DEFAULT 0,
        created_at            DATETIME     DEFAULT CURRENT_TIMESTAMP,
        KEY idx_range_character (character_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

local function Notify(src, msg, t) LSLegacy.Events.SendToClient('notify', src, 'Stand de tir', msg, t or 'info', 6000) end

-- Résolution identique à celle du MDT (code stocké directement, ou déduit
-- du nom via Config.MDT.TrainingCodes) — dupliquée ici pour rester
-- indépendant du module MDT (cf. UNIPOL).
local function HasSkillCode(characterId, code)
    local rows = MySQL.Sync.fetchAll('SELECT skill, code FROM mdt_agent_skills WHERE character_id=@id', { ['@id'] = characterId }) or {}
    local nameToCode = {}
    for _, tc in ipairs(Config.MDT.TrainingCodes or {}) do nameToCode[tc.name] = tc.code end
    for _, r in ipairs(rows) do
        local c = (r.code and r.code ~= '') and r.code or nameToCode[r.skill]
        if c == code then return true end
    end
    return false
end

local function IsInstructor(src)
    local player = GetPlayer(src)
    if not player or not IsPolice(src) then return false end
    if GetGrade(src) >= C.InstructorMinGrade then return true end
    return HasSkillCode(player['boutique-id'], C.InstructorSkillCode)
end

-- ── Sessions en cours (mémoire, non persistées avant la fin du test) ──
local activeSessions = {}
local sessionCounter = 0

-- ── Liste des joueurs à proximité du formateur ────────────────────
LSLegacy.Events.Register('range:getNearby', function(payload)
    local src = source
    local reply = function(res) LSLegacy.Events.SendToClient('range:nearbyResult', src, { reqId = payload and payload.reqId, result = res }) end
    if not IsInstructor(src) then return reply(false) end
    local me = GetEntityCoords(GetPlayerPed(src))
    local out = {}
    for otherSrc in pairs(LSLegacy.Players.GetAll()) do
        local ped = GetPlayerPed(otherSrc)
        if ped and ped ~= 0 and #(me - GetEntityCoords(ped)) <= 15.0 then
            local p = LSLegacy.Players.Get(otherSrc)
            out[#out + 1] = {
                src = otherSrc,
                character_id = p and p['boutique-id'],
                name = GetName(otherSrc),
                isPolice = IsPolice(otherSrc),
            }
        end
    end
    reply(out)
end)

-- ── Lancement d'un test (par le formateur, pour l'agent choisi) ───
LSLegacy.Events.Register('range:startTest', function(data)
    local src = source
    if not IsInstructor(src) or type(data) ~= 'table' then return end

    local stand = STAND_BY_ID[data.standId]
    local diff = DIFF_BY_ID[data.difficultyId]
    local targetCount = tonumber(data.targetCount)
    local targetSrc = tonumber(data.targetSrc)
    local validCount = false
    for _, n in ipairs(C.TargetCounts) do if n == targetCount then validCount = true break end end
    if not stand or not diff or not validCount or not targetSrc then return Notify(src, 'Paramètres invalides.', 'error') end

    local targetPlayer = LSLegacy.Players.Get(targetSrc)
    if not targetPlayer then return Notify(src, 'Agent introuvable.', 'error') end
    if not stand.targets or #stand.targets < targetCount then return Notify(src, 'Stand mal configuré (pas assez de cibles).', 'error') end

    -- Tirage de targetCount positions parmi celles du stand.
    local pool = {}
    for i, v in ipairs(stand.targets) do pool[i] = v end
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local chosen = {}
    for i = 1, targetCount do chosen[i] = pool[i] end

    sessionCounter = sessionCounter + 1
    local sessionId = sessionCounter
    local targetName = GetName(targetSrc)
    activeSessions[sessionId] = {
        trainerSrc      = src,
        trainerName     = GetName(src),
        trainerCharId   = GetPlayer(src)['boutique-id'],
        targetSrc       = targetSrc,
        targetCharId    = targetPlayer['boutique-id'],
        targetName      = targetName,
        targetIsPolice  = IsPolice(targetSrc),
        standId         = stand.id,
        difficultyId    = diff.id,
        difficultyLabel = diff.label,
        targetCount     = targetCount,
    }

    LSLegacy.Events.SendToClient('range:runTest', targetSrc, {
        sessionId    = sessionId,
        targets      = chosen,
        standType    = stand.type,
        interval     = diff.interval,
        targetProp   = C.TargetProp,
    })
    Notify(src, ('Test lancé pour %s (%s, %d cibles).'):format(targetName, diff.label, targetCount), 'success')

    -- Filet de sécurité si le résultat ne revient jamais (déco, bug client).
    Citizen.SetTimeout((targetCount * (diff.interval + 0.5) + 20) * 1000, function()
        activeSessions[sessionId] = nil
    end)
end)

-- ── Fin de test (rapporté par le client du testé) ─────────────────
LSLegacy.Events.Register('range:finishTest', function(data)
    local src = source
    local sessionId = type(data) == 'table' and tonumber(data.sessionId)
    local sess = sessionId and activeSessions[sessionId]
    if not sess or sess.targetSrc ~= src then return end
    activeSessions[sessionId] = nil

    local hits = math.max(0, math.min(sess.targetCount, tonumber(data.hits) or 0))
    local score = hits * C.PointsPerHit
    local maxScore = sess.targetCount * C.PointsPerHit

    -- Le testé ne reçoit jamais son résultat ; seul le formateur est notifié.
    Notify(sess.trainerSrc, ('%s — %s — %d/%d cibles touchées — %d/%d points.'):format(
        sess.targetName, sess.difficultyLabel, hits, sess.targetCount, score, maxScore), 'success')

    if sess.targetIsPolice then
        MySQL.Async.execute([[
            INSERT INTO police_range_scores
                (character_id, name, trainer_character_id, trainer_name, stand_id, difficulty, difficulty_label, target_count, hits, score, max_score)
            VALUES (@cid, @name, @tcid, @tname, @stand, @diff, @diffLabel, @count, @hits, @score, @max)
        ]], {
            ['@cid'] = sess.targetCharId, ['@name'] = sess.targetName,
            ['@tcid'] = sess.trainerCharId, ['@tname'] = sess.trainerName,
            ['@stand'] = sess.standId, ['@diff'] = sess.difficultyId, ['@diffLabel'] = sess.difficultyLabel,
            ['@count'] = sess.targetCount, ['@hits'] = hits, ['@score'] = score, ['@max'] = maxScore,
        })
    end
end)
