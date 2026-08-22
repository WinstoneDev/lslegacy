local rateLimits = {
    ['fourriere:impound'] = 15, ['fourriere:requestList'] = 15,
    ['fourriere:retrieve'] = 10, ['fourriere:persistDelivered'] = 15,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local CFG = Config.Fourriere

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS fourriere (
        plate        VARCHAR(12)  NOT NULL,
        owner        VARCHAR(60)           DEFAULT NULL,
        character_id INT                   DEFAULT NULL,
        model        BIGINT                DEFAULT 0,
        props        LONGTEXT              DEFAULT NULL,
        reason       VARCHAR(255) NOT NULL DEFAULT '',
        fee          INT          NOT NULL DEFAULT 0,
        officer      VARCHAR(60)  NOT NULL DEFAULT '',
        officer_name VARCHAR(100) NOT NULL DEFAULT '',
        impounded_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        release_at   TIMESTAMP    NULL     DEFAULT NULL,
        PRIMARY KEY (plate),
        KEY idx_fourriere_owner (owner)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
MySQL.Async.execute("ALTER TABLE fourriere ADD COLUMN IF NOT EXISTS release_at TIMESTAMP NULL DEFAULT NULL", {})
-- props : snapshot du véhicule (model + tuning + status) repris de persistent_vehicles, pour un respawn à l'identique.
MySQL.Async.execute("ALTER TABLE fourriere ADD COLUMN IF NOT EXISTS props LONGTEXT DEFAULT NULL", {})
MySQL.Async.execute("ALTER TABLE fourriere ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})

local function GetPlayer(src) return LSLegacy.Players.Get(src) end

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient(CFG.NotifyEvent, src, 'Fourrière', msg, 5000, t or 'info')
end

local function charName(player)
    if player and player.characterInfos then
        return ((player.characterInfos.Prenom or '') .. ' ' .. (player.characterInfos.NDF or ''))
            :gsub('^%s+', ''):gsub('%s+$', '')
    end
    return '?'
end

local function normPlate(p)
    return (tostring(p or ''):upper():gsub('^%s+', ''):gsub('%s+$', '')):sub(1, 8)
end

local function isCop(player)
    return LSLegacy.Jobs.Is(player, CFG.Job)
end

local function isOnDuty(src)
    if not CFG.RequireOnDuty then return true end
    local ok, st = pcall(function() return Player(src).state.policeOnDuty end)
    return ok and st == true
end

local function reasonInfo(label)
    for _, r in ipairs(CFG.Reasons) do
        if r.label == label then
            return math.floor(r.fee or CFG.BaseFee), math.floor(r.duration or CFG.BaseDuration)
        end
    end
    return CFG.BaseFee, CFG.BaseDuration
end

local function setMdtLocation(plate, location, officer)
    MySQL.Async.execute([[
        INSERT INTO mdt_vehicle_flags (plate, department, location, officer_identifier)
        VALUES (@plate, @dep, @loc, @oid)
        ON DUPLICATE KEY UPDATE location=@loc, officer_identifier=@oid
    ]], { ['@plate'] = plate, ['@dep'] = CFG.Department, ['@loc'] = location, ['@oid'] = officer or '' })
end

LSLegacy.Events.Register('fourriere:impound', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player or type(data) ~= 'table' then return end
    if not isCop(player) then return Notify(src, 'Action réservée à la police.', 'error') end
    if not isOnDuty(src) then return Notify(src, 'Vous devez être en service.', 'error') end

    local plate = normPlate(data.plate)
    if plate == '' then return Notify(src, 'Plaque introuvable.', 'error') end
    local reason = tostring(data.reason or 'Autre'):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 255)
    if reason == '' then reason = 'Motif personnalisé' end
    local fee, duration
    if data.custom and CFG.AllowCustom then
        -- borné côté serveur (anti-abus)
        fee      = math.max(0, math.min(CFG.MaxFee, math.floor(tonumber(data.fee) or CFG.BaseFee)))
        duration = math.max(0, math.min(CFG.MaxDuration, math.floor(tonumber(data.duration) or CFG.BaseDuration)))
    else
        fee, duration = reasonInfo(reason)
    end
    -- LSLegacy.AP.Active[plate] doit être nettoyé ici : sinon l'entrée obsolète bloque
    -- tout respawn ultérieur (SpawnPersistedRow la croit active, diffuse un netId mort).
    local despawn = function()
        MySQL.Async.execute('DELETE FROM persistent_vehicles WHERE UPPER(TRIM(plate))=@p', { ['@p'] = plate })
        LSLegacy.AP = LSLegacy.AP or { Active = {} }
        LSLegacy.AP.Active = LSLegacy.AP.Active or {}
        LSLegacy.AP.Active[plate] = nil
        LSLegacy.Events.SendToClient('fourriere:removeVehicle', src, { plate = plate })
    end

    -- Lu AVANT le despawn (qui supprime la ligne persistent_vehicles) pour restaurer à l'identique.
    MySQL.Async.fetchAll('SELECT model, tuning, status FROM persistent_vehicles WHERE UPPER(TRIM(plate))=@p LIMIT 1',
        { ['@p'] = plate }, function(pv)
        local snapshot = nil
        if pv and pv[1] then
            local tuning = type(pv[1].tuning) == 'string' and json.decode(pv[1].tuning) or pv[1].tuning
            local status = type(pv[1].status) == 'string' and json.decode(pv[1].status) or pv[1].status
            snapshot = {
                model  = math.floor(tonumber(pv[1].model) or 0),
                tuning = type(tuning) == 'table' and tuning or {},
                status = type(status) == 'table' and status or {},
            }
        end

        -- owned_vehicles ne porte que la possession : modèle/tuning viennent de persistent_vehicles.
        MySQL.Async.fetchAll('SELECT owner, character_id FROM owned_vehicles WHERE UPPER(plate)=@p LIMIT 1',
            { ['@p'] = plate }, function(rows)
            if rows and rows[1] then
                local owner = rows[1].owner
                local charId = rows[1].character_id
                if not snapshot then snapshot = { model = 0, tuning = {}, status = {} } end
                local model = snapshot.model or 0

                MySQL.Async.execute([[
                    INSERT INTO fourriere (plate, owner, character_id, model, props, reason, fee, officer, officer_name, release_at)
                    VALUES (@plate, @owner, @charId, @model, @props, @reason, @fee, @officer, @oname, DATE_ADD(NOW(), INTERVAL @dur MINUTE))
                    ON DUPLICATE KEY UPDATE owner=@owner, character_id=@charId, model=@model, props=@props,
                                            reason=@reason, fee=@fee, officer=@officer, officer_name=@oname,
                                            impounded_at=CURRENT_TIMESTAMP,
                                            release_at=DATE_ADD(NOW(), INTERVAL @dur MINUTE)
                ]], {
                    ['@plate'] = plate, ['@owner'] = owner, ['@charId'] = charId, ['@model'] = model,
                    ['@props'] = json.encode(snapshot),
                    ['@reason'] = reason, ['@fee'] = fee, ['@dur'] = duration,
                    ['@officer'] = player.identifier, ['@oname'] = charName(player),
                }, function()
                    setMdtLocation(plate, 'fourriere', player.identifier)
                    despawn()
                    Notify(src, ('Véhicule %s mis en fourrière (%d $ · %d min).'):format(plate, fee, duration), 'success')
                end)
            else
                despawn()
                Notify(src, ('Véhicule %s non immatriculé — retiré de la voie.'):format(plate), 'success')
            end
        end)
    end)
end)

LSLegacy.Events.Register('fourriere:requestList', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    MySQL.Async.fetchAll([[
        SELECT plate, model, props, reason, fee,
               GREATEST(TIMESTAMPDIFF(SECOND, NOW(), release_at), 0) AS remaining_sec
        FROM fourriere WHERE character_id=@charId ORDER BY impounded_at DESC
    ]], { ['@charId'] = player["boutique-id"] }, function(rows)
        LSLegacy.Events.SendToClient('fourriere:list', src, rows or {})
    end)
end)

-- Re-spawn via persistence : ré-insertion dans persistent_vehicles puis LSLegacy.AP.SpawnPersistedRow.
-- token -> { src, player, plate, rec }
local PendingRetrievals = {}

local function ReleaseVehicle(src, player, plate, rec)
    MySQL.Async.execute('DELETE FROM fourriere WHERE plate=@p', { ['@p'] = plate })
    setMdtLocation(plate, 'circulation', player.identifier)

    local snap = nil
    if rec.props then
        local ok, decoded = pcall(json.decode, rec.props)
        if ok and type(decoded) == 'table' then snap = decoded end
    end
    local model  = math.floor(tonumber((snap and snap.model) or rec.model) or 0)
    local tuning = (snap and type(snap.tuning) == 'table') and snap.tuning or {}
    local status = (snap and type(snap.status) == 'table') and snap.status or {}

    local position = { x = CFG.Spawn.x, y = CFG.Spawn.y, z = CFG.Spawn.z, h = CFG.Spawn.h }
    MySQL.Async.execute([[
        INSERT INTO persistent_vehicles (plate, model, position, status, tuning, trailer_plate, state_bags)
        VALUES (@plate, @model, @position, @status, @tuning, NULL, '{}')
        ON DUPLICATE KEY UPDATE model=@model, position=@position, status=@status, tuning=@tuning
    ]], {
        ['@plate'] = plate, ['@model'] = model,
        ['@position'] = json.encode(position),
        ['@status']   = json.encode(status),
        ['@tuning']   = json.encode(tuning),
    })
    LSLegacy.AP.SpawnPersistedRow({
        plate = plate, model = model,
        position = json.encode(position),
        status = json.encode(status),
        tuning = json.encode(tuning),
        state_bags = '{}',
    }, src)
end

LSLegacy.Bank.RegisterPaymentResultHandler('fourriere', function(token, success)
    local pending = PendingRetrievals[token]
    if not pending then return end
    PendingRetrievals[token] = nil
    if not success then
        Notify(pending.src, 'Paiement refusé, véhicule toujours en fourrière.', 'error')
        return
    end
    ReleaseVehicle(pending.src, pending.player, pending.plate, pending.rec)
end)

LSLegacy.Events.Register('fourriere:retrieve', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player or type(data) ~= 'table' then return end
    local plate = normPlate(data.plate)

    MySQL.Async.fetchAll([[
        SELECT owner, character_id, model, props, fee,
               GREATEST(TIMESTAMPDIFF(SECOND, NOW(), release_at), 0) AS remaining_sec
        FROM fourriere WHERE plate=@p LIMIT 1
    ]], { ['@p'] = plate }, function(rows)
        if not rows or not rows[1] then return Notify(src, 'Véhicule introuvable en fourrière.', 'error') end
        local rec = rows[1]
        if rec.character_id ~= player["boutique-id"] then return Notify(src, "Ce n'est pas votre véhicule.", 'error') end
        local remaining = math.floor(tonumber(rec.remaining_sec) or 0)
        if remaining > 0 then
            local mins = math.ceil(remaining / 60)
            return Notify(src, ('Véhicule encore immobilisé (%d min restantes).'):format(mins), 'error')
        end
        local fee = math.floor(tonumber(rec.fee) or CFG.BaseFee)

        local token = ('fourriere_%d_%d'):format(src, math.random(100000, 999999))
        PendingRetrievals[token] = { src = src, player = player, plate = plate, rec = rec }
        Citizen.SetTimeout(120000, function() PendingRetrievals[token] = nil end)
        LSLegacy.Bank.OpenPaymentMenu(src, 'Fourrière - ' .. plate, fee, { meta = { type = 'fourriere', refId = token } })
    end)
end)
