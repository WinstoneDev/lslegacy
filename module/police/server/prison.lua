--  MODULE POLICE NATIONALE — Prison & Garde à vue (serveur)
--  Timers persistants en BDD, libération automatique, historique

local ActiveSentences = {}  -- { [identifier] = { endTime, reason, duration, type } }
local ActiveCustody   = {}  -- { [identifier] = { endTime, reason, duration, officerId } }

-- Notify local : délai 6000ms spécifique aux notifications GAV/prison
local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Police Nationale', msg, t or 'info', Config.Police.NotifyDuration or 30000)
end

-- Tables SQL

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS police_custody (
        id          INT AUTO_INCREMENT PRIMARY KEY,
        identifier  VARCHAR(60)  NOT NULL,
        character_id INT         DEFAULT NULL,
        name        VARCHAR(100) NOT NULL DEFAULT '',
        reason      TEXT         NOT NULL,
        duration    INT          NOT NULL DEFAULT 30,
        started_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        ends_at     DATETIME     NOT NULL,
        released_at DATETIME     DEFAULT NULL,
        officer_id  VARCHAR(60)  NOT NULL DEFAULT '',
        officer_character_id INT DEFAULT NULL,
        officer_name VARCHAR(100) NOT NULL DEFAULT '',
        department  VARCHAR(50)  NOT NULL DEFAULT 'police',
        KEY idx_custody_ident (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS police_prison (
        id          INT AUTO_INCREMENT PRIMARY KEY,
        identifier  VARCHAR(60)  NOT NULL,
        character_id INT         DEFAULT NULL,
        name        VARCHAR(100) NOT NULL DEFAULT '',
        reason      TEXT         NOT NULL,
        duration    INT          NOT NULL DEFAULT 30,
        started_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        ends_at     DATETIME     NOT NULL,
        released_at DATETIME     DEFAULT NULL,
        officer_id  VARCHAR(60)  NOT NULL DEFAULT '',
        officer_character_id INT DEFAULT NULL,
        officer_name VARCHAR(100) NOT NULL DEFAULT '',
        KEY idx_prison_ident (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- Convertit un DATETIME MySQL ('YYYY-MM-DD HH:MM:SS') en epoch, en secondes restantes depuis maintenant
local function RemainingSecondsUntil(mysqlDatetime)
    local endEpoch = os.time({
        year  = tonumber(string.sub(mysqlDatetime, 1, 4)),
        month = tonumber(string.sub(mysqlDatetime, 6, 7)),
        day   = tonumber(string.sub(mysqlDatetime, 9, 10)),
        hour  = tonumber(string.sub(mysqlDatetime, 12, 13)),
        min   = tonumber(string.sub(mysqlDatetime, 15, 16)),
        sec   = tonumber(string.sub(mysqlDatetime, 18, 19)),
    })
    return math.max(0, os.difftime(endEpoch, os.time()))
end

-- Restaurer les peines actives au démarrage

Citizen.CreateThread(function()
    Wait(5000)
    -- Prison
    MySQL.Async.fetchAll(
        'SELECT * FROM police_prison WHERE released_at IS NULL AND ends_at > NOW()',
        {},
        function(rows)
            for _, row in ipairs(rows or {}) do
                local remaining = RemainingSecondsUntil(row.ends_at)
                if remaining > 0 then
                    ActiveSentences[row.identifier] = {
                        endTime  = os.time() + remaining,
                        reason   = row.reason,
                        duration = row.duration,
                        type     = 'prison',
                    }
                    SchedulePrisonRelease(row.identifier, remaining * 1000)
                end
            end
        end
    )
    -- Garde à vue
    MySQL.Async.fetchAll(
        'SELECT * FROM police_custody WHERE released_at IS NULL AND ends_at > NOW()',
        {},
        function(rows)
            for _, row in ipairs(rows or {}) do
                local remaining = RemainingSecondsUntil(row.ends_at)
                if remaining > 0 then
                    ActiveCustody[row.identifier] = {
                        endTime      = os.time() + remaining,
                        reason       = row.reason,
                        duration     = row.duration,
                        officerIdent = row.officer_id,
                        targetName   = row.name,
                    }
                    ScheduleCustodyRelease(row.identifier, remaining * 1000)
                end
            end
        end
    )
end)

-- GARDE À VUE

-- Libère une GAV active et notifie la cible + l'officier qui l'a posée
local function ReleaseCustody(ident)
    local custody = ActiveCustody[ident]
    if not custody then return end
    local savedOfficerIdent = custody.officerIdent
    local savedTargetName   = custody.targetName
    ActiveCustody[ident] = nil
    MySQL.Async.execute(
        'UPDATE police_custody SET released_at=NOW() WHERE identifier=@id AND released_at IS NULL',
        { ['@id'] = ident }
    )
    for pid, pd in pairs(LSLegacy.Players.GetAll()) do
        if pd.identifier == ident then
            TriggerClientEvent('police:releasedFromCustody', pid)
        end
        if pd.identifier == savedOfficerIdent then
            Notify(pid, string.format('La GAV de %s est terminée, allez le/la libérer.', savedTargetName), 'warning')
        end
    end
end

function ScheduleCustodyRelease(ident, delayMs)
    Citizen.CreateThread(function()
        Wait(delayMs)
        ReleaseCustody(ident)
    end)
end

LSLegacy.Events.Register('police:custody', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not HasPermission(src, 'manage_custody') then
        Notify(src, Lang.Police.grade_required, 'error') return
    end
    if not data or not data.target or not data.reason or not data.duration then return end

    local target  = tonumber(data.target)
    local tp      = GetPlayer(target)
    if not tp then return end

    local reason   = tostring(data.reason):sub(1, Config.MDT.Limits.MaxTextLength)
    local duration = math.min(tonumber(data.duration) or 30, 240)
    local ident    = tp.identifier
    local charId   = tp["boutique-id"]
    local tName    = GetName(target)
    local oName    = GetName(src)
    local oIdent   = GetIdent(src)
    local oCharId  = GetPlayer(src) and GetPlayer(src)["boutique-id"] or nil
    local endTime  = os.time() + duration * 60

    ActiveCustody[ident] = {
        endTime      = endTime,
        reason       = reason,
        duration     = duration,
        officerIdent = oIdent,
        targetName   = tName,
    }

    MySQL.Async.execute(
        'INSERT INTO police_custody (identifier, character_id, name, reason, duration, ends_at, officer_id, officer_character_id, officer_name) ' ..
        'VALUES (@id, @charId, @name, @reason, @dur, DATE_ADD(NOW(), INTERVAL @dur MINUTE), @oid, @oCharId, @oname)',
        { ['@id'] = ident, ['@charId'] = charId, ['@name'] = tName, ['@reason'] = reason,
          ['@dur'] = duration, ['@oid'] = oIdent, ['@oCharId'] = oCharId, ['@oname'] = oName }
    )

    -- Téléporter en cellule
    TriggerClientEvent('police:teleportToCustody', target, {
        x = Config.Police.CustodyCoords.x,
        y = Config.Police.CustodyCoords.y,
        z = Config.Police.CustodyCoords.z,
        h = Config.Police.CustodyHeading,
        duration = duration,
        reason   = reason,
    })

    Notify(target, string.format(Lang.Police.custody_placed .. ' — Durée : %d min', duration), 'error')
    Notify(src, Lang.Police.custody_placed, 'success')

    LogDiscord('Garde à vue',
        string.format('**%s** placé(e) en GAV par **%s**\nMotif : %s\nDurée : %d min',
            tName, oName, reason, duration), 15158332)

    IncrementPoliceStat(oIdent, oCharId, oName, 'custody_count', 1)
    ScheduleCustodyRelease(ident, duration * 60 * 1000)
end)


-- PRISON

-- Libère une peine de prison active et notifie la cible
local function ReleasePrison(ident)
    if not ActiveSentences[ident] then return end
    ActiveSentences[ident] = nil
    MySQL.Async.execute(
        'UPDATE police_prison SET released_at=NOW() WHERE identifier=@id AND released_at IS NULL',
        { ['@id'] = ident }
    )
    for pid, pd in pairs(LSLegacy.Players.GetAll()) do
        if pd.identifier == ident then
            TriggerClientEvent('police:releasedFromPrison', pid)
            Notify(pid, Lang.Police.prison_released, 'success')
            break
        end
    end
end

function SchedulePrisonRelease(ident, delayMs)
    Citizen.CreateThread(function()
        Wait(delayMs)
        ReleasePrison(ident)
    end)
end

LSLegacy.Events.Register('police:prison', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not HasPermission(src, 'manage_custody') then
        Notify(src, Lang.Police.grade_required, 'error') return
    end
    if not data or not data.target or not data.reason or not data.duration then return end

    local target   = tonumber(data.target)
    local tp       = GetPlayer(target)
    if not tp then return end

    local reason   = tostring(data.reason):sub(1, Config.MDT.Limits.MaxTextLength)
    local duration = math.min(tonumber(data.duration) or 30, 720)
    local ident    = tp.identifier
    local charId   = tp["boutique-id"]
    local tName    = GetName(target)
    local oName    = GetName(src)
    local oIdent   = GetIdent(src)
    local oCharId  = GetPlayer(src) and GetPlayer(src)["boutique-id"] or nil

    ActiveSentences[ident] = {
        endTime  = os.time() + duration * 60,
        reason   = reason,
        duration = duration,
        type     = 'prison',
    }

    MySQL.Async.execute(
        'INSERT INTO police_prison (identifier, character_id, name, reason, duration, ends_at, officer_id, officer_character_id, officer_name) ' ..
        'VALUES (@id, @charId, @name, @reason, @dur, DATE_ADD(NOW(), INTERVAL @dur MINUTE), @oid, @oCharId, @oname)',
        { ['@id'] = ident, ['@charId'] = charId, ['@name'] = tName, ['@reason'] = reason,
          ['@dur'] = duration, ['@oid'] = oIdent, ['@oCharId'] = oCharId, ['@oname'] = oName }
    )

    -- Enregistrer dans le casier MDT
    MySQL.Async.execute(
        'INSERT INTO mdt_criminal_records (department, identifier, character_id, citizen_name, charge, description, officer_identifier, officer_character_id, officer_name) ' ..
        'VALUES (@dep, @id, @charId, @cname, @charge, @desc, @oid, @oCharId, @oname)',
        { ['@dep'] = 'police', ['@id'] = ident, ['@charId'] = charId, ['@cname'] = tName,
          ['@charge'] = reason,
          ['@desc']   = 'Incarcération — ' .. duration .. ' min',
          ['@oid']    = oIdent, ['@oCharId'] = oCharId, ['@oname'] = oName }
    )

    TriggerClientEvent('police:sendToPrison', target, {
        x = Config.Police.PrisonCoords.x,
        y = Config.Police.PrisonCoords.y,
        z = Config.Police.PrisonCoords.z,
        h = Config.Police.PrisonHeading,
        duration = duration,
        reason   = reason,
    })

    Notify(src, string.format(Lang.Police.prison_sent, duration), 'success')
    Notify(target, string.format(Lang.Police.prison_sent, duration), 'error')

    LogDiscord('Incarcération',
        string.format('**%s** incarcéré(e) par **%s**\nChef : %s\nDurée : %d min',
            tName, oName, reason, duration), 10038562)

    IncrementPoliceStat(oIdent, oCharId, oName, 'prison_count', 1)
    SchedulePrisonRelease(ident, duration * 60 * 1000)
end)

-- Vérifier la peine à la connexion

AddEventHandler('police:checkPrisonOnSpawn', function(src)
    local ident = GetIdent(src)
    if not ident then return end
    local sentence = ActiveSentences[ident]
    if sentence and sentence.endTime > os.time() then
        local remaining = math.ceil((sentence.endTime - os.time()) / 60)
        Wait(3000)
        TriggerClientEvent('police:sendToPrison', src, {
            x = Config.Police.PrisonCoords.x,
            y = Config.Police.PrisonCoords.y,
            z = Config.Police.PrisonCoords.z,
            h = Config.Police.PrisonHeading,
            duration = remaining,
            reason   = sentence.reason,
        })
        Notify(src, string.format(Lang.Police.prison_sent, remaining), 'error')
    end
end)

-- Vérifier à la connexion
AddEventHandler('registerPlayer', function()
    local src = source
    Citizen.CreateThread(function()
        Wait(5000)
        TriggerEvent('police:checkPrisonOnSpawn', src)
    end)
end)

-- Export pour les autres modules
function GetActiveSentence(identifier)
    return ActiveSentences[identifier]
end
function GetActiveCustody(identifier)
    return ActiveCustody[identifier]
end
