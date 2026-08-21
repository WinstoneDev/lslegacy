--  MODULE POLICE NATIONALE — Prison & Garde à vue (serveur)
--  Timers persistants en BDD, libération automatique, historique

local ActiveSentences = {}  -- { [identifier] = { endTime, reason, duration, type } }
local ActiveCustody   = {}  -- { [identifier] = { endTime, reason, duration, officerId } }

-- Notify local : délai 6000ms spécifique aux notifications GAV/prison
local function Notify(src, msg, t)
    TriggerClientEvent(Config.Police.NotifyEvent, src, 'Police Nationale', msg,
        Config.Police.NotifyDuration or 30000, t or 'info')
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

-- Restaurer les peines actives au démarrage

Citizen.CreateThread(function()
    Wait(5000)
    -- Prison
    MySQL.Async.fetchAll(
        'SELECT * FROM police_prison WHERE released_at IS NULL AND ends_at > NOW()',
        {},
        function(rows)
            for _, row in ipairs(rows or {}) do
                local endEpoch = os.time() + math.max(0,
                    os.difftime(
                        os.time(({year=tonumber(string.sub(row.ends_at,1,4)),
                            month=tonumber(string.sub(row.ends_at,6,7)),
                            day=tonumber(string.sub(row.ends_at,9,10)),
                            hour=tonumber(string.sub(row.ends_at,12,13)),
                            min=tonumber(string.sub(row.ends_at,15,16)),
                            sec=tonumber(string.sub(row.ends_at,18,19))})[1] or os.time()),
                        os.time()
                    )
                )
                if endEpoch > os.time() then
                    ActiveSentences[row.identifier] = {
                        endTime  = endEpoch,
                        reason   = row.reason,
                        duration = row.duration,
                        type     = 'prison',
                    }
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
                ActiveCustody[row.identifier] = {
                    endTime  = os.time() + 60,
                    reason   = row.reason,
                    duration = row.duration,
                    type     = 'custody',
                }
            end
        end
    )
end)

-- GARDE À VUE

LSLegacy.RegisterServerEvent('police:custody', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not LSLegacy.MDT.HasPermission('police', tonumber(GetPlayer(src).job_grade) or 0, 'manage_custody') then
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

    -- Timer de libération automatique
    Citizen.CreateThread(function()
        Wait(duration * 60 * 1000)
        local custody = ActiveCustody[ident]
        if custody then
            local savedOfficerIdent = custody.officerIdent
            local savedTargetName   = custody.targetName
            ActiveCustody[ident] = nil
            MySQL.Async.execute(
                'UPDATE police_custody SET released_at=NOW() WHERE identifier=@id AND released_at IS NULL',
                { ['@id'] = ident }
            )
            for pid, pd in pairs(LSLegacy.ServerPlayers) do
                -- Notifier l'individu (une seule notif via l'event client)
                if pd.identifier == ident then
                    TriggerClientEvent('police:releasedFromCustody', pid)
                end
                -- Notifier l'officier qui a posé la GAV
                if pd.identifier == savedOfficerIdent then
                    Notify(pid, string.format('La GAV de %s est terminée, allez le/la libérer.', savedTargetName), 'warning')
                end
            end
        end
    end)
end)


-- PRISON

LSLegacy.RegisterServerEvent('police:prison', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not LSLegacy.MDT.HasPermission('police', tonumber(GetPlayer(src).job_grade) or 0, 'manage_custody') then
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

    -- Timer libération
    Citizen.CreateThread(function()
        Wait(duration * 60 * 1000)
        if ActiveSentences[ident] then
            ActiveSentences[ident] = nil
            MySQL.Async.execute(
                'UPDATE police_prison SET released_at=NOW() WHERE identifier=@id AND released_at IS NULL',
                { ['@id'] = ident }
            )
            for pid, pd in pairs(LSLegacy.ServerPlayers) do
                if pd.identifier == ident then
                    TriggerClientEvent('police:releasedFromPrison', pid)
                    Notify(pid, Lang.Police.prison_released, 'success')
                    break
                end
            end
        end
    end)
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
