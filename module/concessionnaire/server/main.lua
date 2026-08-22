-- ═══════════════════════════════════════════════════════════════════
--  CONCESSIONNAIRE — Serveur principal
--  Validation stricte : prix/modèle re-vérifiés depuis Config (jamais client)
--  Possession enregistrée dans owned_vehicles (standard ESX)

local rateLimits = {
    ['concessionnaire:buy'] = 10, ['concessionnaire:sell'] = 10,
    ['concessionnaire:getOccasions'] = 15, ['concessionnaire:buyOccasion'] = 10,
    ['concessionnaire:persistDelivered'] = 10,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end
-- ═══════════════════════════════════════════════════════════════════

local function GetPlayer(src) return LSLegacy.Players.Get(src) end

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Concessionnaire', msg, t or 'info', 5000)
end

-- ── Table de possession (compatible ESX / lb-phone) ──────────────────
--  Le tuning/état vit dans persistent_vehicles (mis à jour en continu) ;
--  owned_vehicles ne porte plus que la possession (plus de colonne `vehicle`,
--  jamais mise à jour après achat et donc obsolète dès le premier trajet).

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS owned_vehicles (
        owner   VARCHAR(60)  DEFAULT NULL,
        character_id INT     DEFAULT NULL,
        plate   VARCHAR(12)  NOT NULL,
        type    VARCHAR(20)  DEFAULT 'car',
        job     VARCHAR(20)  DEFAULT NULL,
        stored  TINYINT(1)   DEFAULT 0,
        garage  VARCHAR(60)  DEFAULT NULL,
        PRIMARY KEY (plate),
        KEY idx_owned_vehicles_owner (owner)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
-- vehicle : jamais mise à jour après l'achat (obsolète) ; le modèle/tuning
-- vivent désormais dans persistent_vehicles, tenue à jour en continu.
MySQL.Async.execute("ALTER TABLE owned_vehicles DROP COLUMN IF EXISTS vehicle", {})
MySQL.Async.execute("ALTER TABLE owned_vehicles ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})

-- ── Marché de l'occasion (véhicules repris, remis en vente) ──────────

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS concessionnaire_occasions (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        model      VARCHAR(60)  NOT NULL,
        label      VARCHAR(100) NOT NULL DEFAULT '',
        price      INT          NOT NULL DEFAULT 0,
        props      LONGTEXT              DEFAULT NULL,
        plate      VARCHAR(12)           DEFAULT NULL,
        owner      VARCHAR(60)           DEFAULT NULL,
        created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
-- Migrations idempotentes : plaque + propriétaire d'origine (traçabilité MDT).
MySQL.Async.execute("ALTER TABLE concessionnaire_occasions ADD COLUMN IF NOT EXISTS plate VARCHAR(12) DEFAULT NULL", {})
MySQL.Async.execute("ALTER TABLE concessionnaire_occasions ADD COLUMN IF NOT EXISTS owner VARCHAR(60) DEFAULT NULL", {})
MySQL.Async.execute("ALTER TABLE concessionnaire_occasions ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})
-- props : snapshot complet (model + tuning + status) repris de persistent_vehicles
-- à la reprise, pour restituer le véhicule à l'identique à l'achat d'occasion.
MySQL.Async.execute("ALTER TABLE concessionnaire_occasions ADD COLUMN IF NOT EXISTS props LONGTEXT DEFAULT NULL", {})
-- color1/color2 remplacées par props (snapshot complet).
MySQL.Async.execute("ALTER TABLE concessionnaire_occasions DROP COLUMN IF EXISTS color1", {})
MySQL.Async.execute("ALTER TABLE concessionnaire_occasions DROP COLUMN IF EXISTS color2", {})

-- ── Recherche d'une entrée du catalogue (source de vérité) ───────────

local function EntryFromVeh(cat, veh)
    return {
        model = veh.model, label = veh.label, price = veh.price,
        vtype = (cat.category == 'Motos') and 'bike' or 'car',
    }
end

local function FindCatalogEntry(model)
    if not model then return nil end
    for _, cat in ipairs(Config.Concessionnaire.Catalog) do
        for _, veh in ipairs(cat.vehicles) do
            if veh.model == model then return EntryFromVeh(cat, veh) end
        end
    end
    return nil
end

-- Recherche par hash de modèle (revente : owned_vehicles stocke le hash)
local function FindCatalogEntryByHash(hash)
    for _, cat in ipairs(Config.Concessionnaire.Catalog) do
        for _, veh in ipairs(cat.vehicles) do
            if GetHashKey(veh.model) == hash then return EntryFromVeh(cat, veh) end
        end
    end
    return nil
end

-- ── Plaques ──────────────────────────────────────────────────────────

local LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

local function RandomPlate()
    local function l() return LETTERS:sub(math.random(1, 26), math.random(1, 26)) end
    return string.format('%s%s%03d%s%s', l(), l(), math.random(0, 999), l(), l())
end

local function IsPlateTaken(plate)
    local rows = MySQL.Sync.fetchAll(
        'SELECT plate FROM owned_vehicles WHERE plate = @p ' ..
        'UNION SELECT plate FROM persistent_vehicles WHERE plate = @p ' ..
        'UNION SELECT plate FROM concessionnaire_occasions WHERE plate = @p LIMIT 1',
        { ['@p'] = plate }
    )
    return rows and #rows > 0
end

local function GenerateUniquePlate()
    for _ = 1, 20 do
        local plate = RandomPlate()
        if not IsPlateTaken(plate) then return plate end
    end
    return nil
end

-- Plaques GTA : 8 caractères MAX en dur (le moteur tronque au-delà).
local PLATE_MAX = 8

-- Normalise une plaque : retire les espaces de tête ET de fin (le jeu
-- centre les plaques courtes → "  808   "), puis cape à 8 caractères.
local function CapPlate(p)
    p = tostring(p or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return p:sub(1, PLATE_MAX)
end

-- Nettoie une plaque personnalisée : majuscules, A-Z 0-9 espaces, longueur max
local function SanitizeCustomPlate(input)
    if not input then return nil end
    local cfgMax = tonumber(Config.Concessionnaire.CustomPlate.maxLength) or PLATE_MAX
    local maxLen = math.min(PLATE_MAX, cfgMax)
    local p = string.upper(tostring(input)):gsub('[^A-Z0-9 ]', '')
    p = p:gsub('^%s+', ''):gsub('%s+$', '')
    p = p:sub(1, maxLen)
    if p == '' then return nil end
    return p
end

-- ── Persistance (module persistent_vehicles) ────────────────────────
--  Un véhicule n'est suivi/sauvegardé que s'il figure dans
--  LSLegacy.AP.Active. Les véhicules du concess étant spawn côté client,
--  on les y inscrit (via le netId renvoyé par le client) et on insère
--  d'emblée une ligne dans persistent_vehicles pour survivre au reboot.

-- Achats en attente d'inscription :
-- plate -> { model=hash, primary, secondary, tuning?, status? }
-- tuning/status complets ne sont fournis que pour une occasion (snapshot repris
-- de persistent_vehicles à la revente) ; sinon véhicule neuf par défaut.
local pendingPersist = {}

local function PersistDelivered(plate, netId)
    plate = CapPlate(plate)
    local pend = pendingPersist[plate]
    if not pend then return end
    pendingPersist[plate] = nil

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    LSLegacy.AP = LSLegacy.AP or { Active = {} }
    LSLegacy.AP.Active = LSLegacy.AP.Active or {}

    local coords  = GetEntityCoords(entity)
    local heading = GetEntityHeading(entity)
    local tuning  = pend.tuning or { colorPrimary = pend.primary or 0, colorSecondary = pend.secondary or 0 }
    local status  = pend.status or {
        engine = 1000.0, body = 1000.0, tank = 1000.0, dirt = 0.0, fuel = 100.0,
        lock = 1, windows = {}, extras = {}, tyreData = {}, doorsBroken = {}, visualDamage = {},
    }

    -- Inscription dans le suivi actif : la boucle d'auto-save le reconnaîtra
    -- (et ne le re-spawnera pas en double au tick de maintenance).
    LSLegacy.AP.Active[plate] = {
        netId = netId, entity = entity, model = pend.model,
        fuel = status.fuel or 100.0, windows = status.windows or {}, extras = status.extras or {},
        tyreData = status.tyreData or {}, doorsBroken = status.doorsBroken or {},
        visualDamage = status.visualDamage or {}, tuning = tuning,
    }

    local position = { x = coords.x, y = coords.y, z = coords.z, h = heading }

    MySQL.Async.execute([[
        INSERT INTO persistent_vehicles (plate, model, position, status, tuning, trailer_plate, state_bags)
        VALUES (@plate, @model, @position, @status, @tuning, NULL, '{}')
        ON DUPLICATE KEY UPDATE model=@model, position=@position, status=@status, tuning=@tuning
    ]], {
        ['@plate']    = plate,
        ['@model']    = pend.model,
        ['@position'] = json.encode(position),
        ['@status']   = json.encode(status),
        ['@tuning']   = json.encode(tuning),
    })
end

-- Le client renvoie le netId du véhicule livré une fois spawn/coloré.
LSLegacy.Events.Register('concessionnaire:persistDelivered', function(data)
    local src = source
    if not GetPlayer(src) then return end
    if not data or not data.plate or not data.netId then return end
    PersistDelivered(data.plate, data.netId)
end)

-- ── Finalisation d'un achat (neuf ou occasion) ──────────────────────
--  Enregistre la possession, remet la clé, livre le véhicule, notifie.
--  snapshot (optionnel) : { tuning, status } repris d'une occasion (props de
--  concessionnaire_occasions) — restitué à l'identique. Sans snapshot (achat
--  neuf) : véhicule flambant neuf, couleur choisie (primary/secondary) ou d'origine.
local function DeliverPurchase(src, player, entry, plate, primary, secondary, snapshot)
    -- Garde-fou : plaque toujours ≤ 8 (identique à ce que le jeu affichera)
    plate = CapPlate(plate)
    local model = GetHashKey(entry.model)

    MySQL.Async.execute(
        'INSERT INTO owned_vehicles (owner, character_id, plate, type, job, stored) ' ..
        'VALUES (@owner, @charId, @plate, @type, NULL, 0)',
        {
            ['@owner'] = player.identifier,
            ['@charId'] = player["boutique-id"],
            ['@plate'] = plate,
            ['@type']  = entry.vtype,
        }
    )

    if Config.Concessionnaire.GiveKey then
        exports.lslegacy:giveVehicleKey(src, plate, model, entry.label)
    end

    local tuning = snapshot and snapshot.tuning or nil
    local status = snapshot and snapshot.status or nil
    if tuning then
        primary   = tuning.colorPrimary
        secondary = tuning.colorSecondary
    end

    -- Marque l'achat en attente : le client renverra le netId après spawn
    -- pour inscrire le véhicule dans persistent_vehicles (survie au reboot).
    pendingPersist[plate] = {
        model     = model,
        primary   = primary,
        secondary = secondary,
        tuning    = tuning,
        status    = status,
    }

    TriggerClientEvent('concessionnaire:deliverVehicle', src, {
        model     = entry.model,
        plate     = plate,
        primary   = primary,
        secondary = secondary,
        tuning    = tuning,
        status    = status,
        coords    = Config.Concessionnaire.Delivery.coords,
        heading   = Config.Concessionnaire.Delivery.heading,
    })

    TriggerClientEvent('concessionnaire:buyResult', src, { success = true, label = entry.label })
end

-- ── Paiement : carte uniquement, via le menu de paiement TPE partagé ──────
-- token -> { src, entry, plate, primary, secondary, snapshot }
local PendingPurchases = {}

LSLegacy.Bank.RegisterPaymentResultHandler('concessionnaire', function(token, success)
    local pending = PendingPurchases[token]
    if not pending then return end
    PendingPurchases[token] = nil
    if not success then
        if pending.onFail then pending.onFail() end
        TriggerClientEvent('concessionnaire:buyResult', pending.src, { success = false, reason = 'payment_failed' })
        return
    end
    local player = GetPlayer(pending.src)
    if not player then return end
    DeliverPurchase(pending.src, player, pending.entry, pending.plate, pending.primary, pending.secondary, pending.snapshot)
end)

-- Met l'achat en attente de paiement carte et ouvre le TPE sur l'acheteur.
-- `onFail` (optionnel) : rollback à exécuter si le paiement échoue (ex.
-- remettre en vente une occasion déjà retirée du marché).
local function QueuePurchase(src, entry, plate, primary, secondary, price, snapshot, onFail)
    local token = ('concess_%d_%d'):format(src, math.random(100000, 999999))
    PendingPurchases[token] = {
        src = src, entry = entry, plate = plate,
        primary = primary, secondary = secondary, snapshot = snapshot, onFail = onFail,
    }
    -- Purge de sécurité si le joueur abandonne/déconnecte avant de payer.
    Citizen.SetTimeout(120000, function() PendingPurchases[token] = nil end)
    LSLegacy.Bank.OpenPaymentMenu(src, 'Achat véhicule - ' .. entry.label, price, {
        allowCash = false,
        meta = { type = 'concessionnaire', refId = token },
    })
end

-- Résout la plaque (perso payante ou aléatoire). Renvoie plate, extra ou nil+raison.
local function ResolvePlate(data)
    if Config.Concessionnaire.CustomPlate.enabled and data.plate then
        local custom = SanitizeCustomPlate(data.plate)
        if custom then
            if IsPlateTaken(custom) then return nil, 'plate_taken' end
            return custom, Config.Concessionnaire.CustomPlate.price
        end
    end
    local plate = GenerateUniquePlate()
    if not plate then return nil, 'purchase_failed' end
    return plate, 0
end

-- ── Achat (neuf) ─────────────────────────────────────────────────────

LSLegacy.Events.Register('concessionnaire:buy', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    if not data or not data.model then return end

    local entry = FindCatalogEntry(data.model)
    if not entry then
        TriggerClientEvent('concessionnaire:buyResult', src, { success = false, reason = 'invalid_vehicle' })
        return
    end

    -- Peinture : payante uniquement si le joueur a choisi une couleur.
    local paint     = data.paint == true
    local primary   = paint and math.floor(tonumber(data.primary)   or 0) or nil
    local secondary = paint and math.floor(tonumber(data.secondary) or 0) or nil

    Citizen.CreateThread(function()
        local plate, extra = ResolvePlate(data)
        if not plate then
            TriggerClientEvent('concessionnaire:buyResult', src, { success = false, reason = extra })
            return
        end

        local price = entry.price + extra + (paint and Config.Concessionnaire.PaintPrice or 0)
        QueuePurchase(src, entry, plate, primary, secondary, price)
    end)
end)

-- ── Revente ──────────────────────────────────────────────────────────

LSLegacy.Events.Register('concessionnaire:sell', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    if not Config.Concessionnaire.Resale.enabled then return end
    if not data or not data.plate then return end

    local plate = CapPlate(data.plate)   -- retire espaces tête/fin + cape à 8

    Citizen.CreateThread(function()
        -- 1) Vérifier la possession + snapshot complet (model + tuning + status).
        -- owned_vehicles ne porte que la possession : le modèle/tuning viennent
        -- de persistent_vehicles, seule source de vérité tenue à jour en continu.
        local rows = MySQL.Sync.fetchAll([[
            SELECT ov.plate, pv.model, pv.tuning, pv.status
            FROM owned_vehicles ov
            LEFT JOIN persistent_vehicles pv ON pv.plate = ov.plate
            WHERE ov.character_id = @charId AND ov.plate = @plate LIMIT 1
        ]], { ['@charId'] = player["boutique-id"], ['@plate'] = plate })
        if not rows or #rows == 0 then
            TriggerClientEvent('concessionnaire:sellResult', src, { success = false, reason = 'resale_not_owner' })
            return
        end
        local row = rows[1]

        -- 2) Retrouver le prix catalogue via le hash du modèle
        local entry = row.model and FindCatalogEntryByHash(math.floor(row.model))
        if not entry then
            TriggerClientEvent('concessionnaire:sellResult', src, { success = false, reason = 'resale_not_catalog' })
            return
        end

        local refund = math.floor(entry.price * Config.Concessionnaire.Resale.rate)

        local tuning = type(row.tuning) == 'string' and json.decode(row.tuning) or row.tuning
        local status = type(row.status) == 'string' and json.decode(row.status) or row.status
        local snapshot = {
            model  = math.floor(tonumber(row.model) or 0),
            tuning = type(tuning) == 'table' and tuning or {},
            status = type(status) == 'table' and status or {},
        }

        -- 3) Supprimer la possession puis rembourser
        MySQL.Sync.execute('DELETE FROM owned_vehicles WHERE plate = @plate', { ['@plate'] = plate })
        MySQL.Async.execute('DELETE FROM persistent_vehicles WHERE plate = @plate', { ['@plate'] = plate })
        -- Nettoyage impératif : sans ça une plaque recyclée plus tard (nouvel
        -- achat) hérite d'une entrée Active obsolète (netId mort) et le spawn
        -- serveur est silencieusement sauté (cf. bug fourrière : netId invalide
        -- résolu côté client vers une entité qui n'est pas un véhicule).
        LSLegacy.AP = LSLegacy.AP or { Active = {} }
        LSLegacy.AP.Active = LSLegacy.AP.Active or {}
        LSLegacy.AP.Active[plate] = nil

        if Config.Concessionnaire.Resale.refundTo == 'cash' then
            LSLegacy.Money.AddPlayerMoney(player, refund)
        else
            exports.lslegacy:addBankMoneyByIdentifier(player.identifier, refund)
        end

        -- 4) Remise en vente d'occasion (80 % du prix neuf)
        if Config.Concessionnaire.Occasion.enabled then
            local occPrice = math.floor(entry.price * Config.Concessionnaire.Occasion.rate)
            MySQL.Async.execute(
                'INSERT INTO concessionnaire_occasions (model, label, price, props, plate, owner, character_id) ' ..
                'VALUES (@model, @label, @price, @props, @plate, @owner, @charId)',
                {
                    ['@model'] = entry.model, ['@label'] = entry.label, ['@price'] = occPrice,
                    ['@props'] = json.encode(snapshot),
                    ['@plate'] = plate, ['@owner'] = player.identifier, ['@charId'] = player["boutique-id"],
                }
            )
        end

        TriggerClientEvent('concessionnaire:sellResult', src, { success = true, refund = refund, plate = plate })
    end)
end)

-- ── Marché de l'occasion : liste ─────────────────────────────────────

LSLegacy.Events.Register('concessionnaire:getOccasions', function()
    local src = source
    if not GetPlayer(src) then return end
    if not Config.Concessionnaire.Occasion.enabled then
        TriggerClientEvent('concessionnaire:occasionsList', src, {})
        return
    end
    Citizen.CreateThread(function()
        local rows = MySQL.Sync.fetchAll(
            'SELECT id, model, label, price, props FROM concessionnaire_occasions ORDER BY created_at DESC',
            {}
        )
        -- color1/color2 dérivés du snapshot pour l'aperçu 3D client (showroom).
        for _, r in ipairs(rows or {}) do
            local ok, snap = pcall(json.decode, r.props or '{}')
            local tuning = (ok and type(snap) == 'table' and type(snap.tuning) == 'table') and snap.tuning or {}
            r.color1 = math.floor(tonumber(tuning.colorPrimary) or 0)
            r.color2 = math.floor(tonumber(tuning.colorSecondary) or 0)
        end
        TriggerClientEvent('concessionnaire:occasionsList', src, rows or {})
    end)
end)

-- ── Marché de l'occasion : achat ─────────────────────────────────────

LSLegacy.Events.Register('concessionnaire:buyOccasion', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    if not Config.Concessionnaire.Occasion.enabled then return end
    if not data or not data.id then return end

    -- Occasion : achat TEL QUEL. Aucune modification autorisée
    -- (ni peinture ni plaque perso) — on ignore volontairement data.paint,
    -- data.primary/secondary et data.plate envoyés par le client.

    Citizen.CreateThread(function()
        -- 1) Récupérer l'occasion
        local rows = MySQL.Sync.fetchAll(
            'SELECT id, model, label, price, props, plate, owner FROM concessionnaire_occasions WHERE id = @id LIMIT 1',
            { ['@id'] = tonumber(data.id) }
        )
        if not rows or #rows == 0 then
            TriggerClientEvent('concessionnaire:buyResult', src, { success = false, reason = 'occasion_gone' })
            return
        end
        local occ = rows[1]

        local entry = FindCatalogEntry(occ.model)
        if not entry then
            TriggerClientEvent('concessionnaire:buyResult', src, { success = false, reason = 'invalid_vehicle' })
            return
        end

        -- Snapshot complet (tuning + status) repris à la reprise : restitué à
        -- l'identique, aucune repeinture/modif autorisée sur une occasion.
        local ok, snapshot = pcall(json.decode, occ.props or '{}')
        if not ok or type(snapshot) ~= 'table' then snapshot = { tuning = {}, status = {} } end
        snapshot.tuning = type(snapshot.tuning) == 'table' and snapshot.tuning or {}
        snapshot.status = type(snapshot.status) == 'table' and snapshot.status or {}

        -- Fonction de remise en vente (rollback)
        local function restoreOccasion()
            MySQL.Async.execute(
                'INSERT INTO concessionnaire_occasions (model, label, price, props, plate, owner) VALUES (@m,@l,@p,@props,@plate,@owner)',
                { ['@m'] = occ.model, ['@l'] = occ.label, ['@p'] = occ.price,
                  ['@props'] = occ.props, ['@plate'] = occ.plate, ['@owner'] = occ.owner })
        end

        -- 2) Réserver l'occasion (atomique : le 1er DELETE gagne)
        local affected = MySQL.Sync.execute('DELETE FROM concessionnaire_occasions WHERE id = @id', { ['@id'] = occ.id })
        if not affected or affected == 0 then
            TriggerClientEvent('concessionnaire:buyResult', src, { success = false, reason = 'occasion_gone' })
            return
        end

        -- 3) Plaque aléatoire imposée (pas de plaque perso) + prix ferme
        local plate = GenerateUniquePlate()
        if not plate then
            restoreOccasion()
            TriggerClientEvent('concessionnaire:buyResult', src, { success = false, reason = 'purchase_failed' })
            return
        end

        local price = occ.price

        -- 4) Paiement carte (rollback occasion si échec/annulation)
        QueuePurchase(src, entry, plate, nil, nil, price, snapshot, restoreOccasion)
    end)
end)
