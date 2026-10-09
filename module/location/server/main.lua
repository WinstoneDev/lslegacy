-- ═══════════════════════════════════════════════════════════════════
--  LOCATION DE VÉHICULES — Serveur principal
--  Contrat en BDD (location_contracts), paiement tokenisé via le TPE
--  partagé (module/bank), clé remise/retirée via module/keyhanger.
-- ═══════════════════════════════════════════════════════════════════

local rateLimits = {
    ['location:requestRent'] = 5,
    ['location:returnVehicle'] = 10,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local function GetPlayer(src) return LSLegacy.Players.Get(src) end

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS location_contracts (
        id           INT AUTO_INCREMENT PRIMARY KEY,
        plate        VARCHAR(12)  NOT NULL,
        character_id INT          NOT NULL,
        model        VARCHAR(60)  NOT NULL,
        price        INT          NOT NULL DEFAULT 0,
        hours        INT          NOT NULL DEFAULT 1,
        started_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
        expires_at   INT          NOT NULL,
        status       VARCHAR(10)  NOT NULL DEFAULT 'active',
        KEY idx_location_plate (plate),
        KEY idx_location_char (character_id, status)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

local PLATE_MAX = 8
local PLATE_PREFIX = 'LOC'
local ALPHANUM = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

local function RandomPlate()
    local suffix = {}
    for i = 1, PLATE_MAX - #PLATE_PREFIX do
        local idx = math.random(1, #ALPHANUM)
        suffix[i] = ALPHANUM:sub(idx, idx)
    end
    return PLATE_PREFIX .. table.concat(suffix)
end

local function IsPlateTaken(plate)
    local rows = MySQL.Sync.fetchAll(
        'SELECT plate FROM owned_vehicles WHERE plate = @p ' ..
        'UNION SELECT plate FROM persistent_vehicles WHERE plate = @p ' ..
        'UNION SELECT plate FROM concessionnaire_occasions WHERE plate = @p ' ..
        'UNION SELECT plate FROM location_contracts WHERE plate = @p LIMIT 1',
        { ['@p'] = plate }
    )
    return rows and #rows > 0
end

local function GenerateUniquePlate()
    for _ = 1, 20 do
        local plate = RandomPlate()
        if not IsPlateTaken(plate) then return plate:sub(1, PLATE_MAX) end
    end
    return nil
end

local function FindVehicleEntry(model)
    for _, v in ipairs(Config.Location.Vehicles) do
        if v.model == model then return v end
    end
    return nil
end

local function HasActiveContract(charId)
    local rows = MySQL.Sync.fetchAll(
        "SELECT id FROM location_contracts WHERE character_id = @c AND status = 'active' LIMIT 1",
        { ['@c'] = charId }
    )
    return rows and #rows > 0
end

local function DeliverRental(src, player, entry, plate, hours, price)
    local expiresAt = os.time() + hours * 3600

    MySQL.Async.execute(
        'INSERT INTO location_contracts (plate, character_id, model, price, hours, expires_at) ' ..
        'VALUES (@plate, @charId, @model, @price, @hours, @expires)',
        {
            ['@plate'] = plate, ['@charId'] = player["boutique-id"], ['@model'] = entry.model,
            ['@price'] = price, ['@hours'] = hours, ['@expires'] = expiresAt,
        }
    )

    exports.lslegacy:giveVehicleKey(src, plate, GetHashKey(entry.model), entry.label)

    TriggerClientEvent('location:deliverVehicle', src, {
        model = entry.model, plate = plate, hours = hours, expiresAt = expiresAt,
    })
    TriggerClientEvent('location:rentResult', src, { success = true })
end

-- token -> { src, entry, plate, hours, price }
local PendingRentals = {}

LSLegacy.Bank.RegisterPaymentResultHandler('location', function(token, success)
    local pending = PendingRentals[token]
    if not pending then return end
    PendingRentals[token] = nil
    if not success then
        TriggerClientEvent('location:rentResult', pending.src, { success = false, reason = 'payment_failed' })
        return
    end
    local player = GetPlayer(pending.src)
    if not player then return end
    DeliverRental(pending.src, player, pending.entry, pending.plate, pending.hours, pending.price)
end)

LSLegacy.Events.Register('location:requestRent', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    if not data or not data.model then return end

    local entry = FindVehicleEntry(data.model)
    if not entry then
        TriggerClientEvent('location:rentResult', src, { success = false, reason = 'invalid_vehicle' })
        return
    end

    local hours = math.floor(tonumber(data.hours) or 0)
    if hours < 1 or hours > Config.Location.MaxHours then
        TriggerClientEvent('location:rentResult', src, { success = false, reason = 'invalid_hours' })
        return
    end

    if HasActiveContract(player["boutique-id"]) then
        TriggerClientEvent('location:rentResult', src, { success = false, reason = 'already_rented' })
        return
    end

    Citizen.CreateThread(function()
        local plate = GenerateUniquePlate()
        if not plate then
            TriggerClientEvent('location:rentResult', src, { success = false, reason = 'purchase_failed' })
            return
        end

        local price = entry.pricePerHour * hours
        local token = ('location_%d_%d'):format(src, math.random(100000, 999999))
        PendingRentals[token] = { src = src, entry = entry, plate = plate, hours = hours, price = price }
        Citizen.SetTimeout(120000, function() PendingRentals[token] = nil end)

        LSLegacy.Bank.OpenPaymentMenu(src, ('Location %s (%dh)'):format(entry.label, hours), price, {
            allowCash = Config.Location.Payment.cash,
            meta = { type = 'location', refId = token },
        })
    end)
end)

LSLegacy.Events.Register('location:returnVehicle', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    if not data or not data.plate or not data.netId then return end

    local plate = tostring(data.plate):gsub('^%s+', ''):gsub('%s+$', '')

    local rows = MySQL.Sync.fetchAll(
        "SELECT id FROM location_contracts WHERE plate = @plate AND character_id = @charId AND status = 'active' LIMIT 1",
        { ['@plate'] = plate, ['@charId'] = player["boutique-id"] }
    )
    if not rows or #rows == 0 then return end

    MySQL.Async.execute("UPDATE location_contracts SET status = 'returned' WHERE id = @id", { ['@id'] = rows[1].id })
    exports.lslegacy:removeVehicleKey(src, plate)

    TriggerClientEvent('location:returnAuthorized', src, data.netId)
end)
