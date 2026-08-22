-- Réutilise interim_stations (job intérimaire) comme unique source de vérité du stock.

LSLegacy.Security.RegisterRateLimit('pompe:requestFill', 20)
LSLegacy.Security.RegisterRateLimit('pompe:payFuel', 15)

local CFG = Config.Pompe

local function GetPlayer(src) return LSLegacy.Players.Get(src) end

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient(CFG.NotifyEvent, src, 'Station essence', msg, 5000, t or 'info')
end

-- Vérifie l'argent du joueur ET le stock de la station avant d'autoriser le client à délivrer de l'essence.
LSLegacy.Events.Register('pompe:requestFill', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player or type(data) ~= 'table' then return end

    local stationId = data.stationId
    local currentLiters = math.floor(tonumber(data.currentLiters) or 0)
    local capacity = math.floor(tonumber(data.capacity) or 0)
    if type(stationId) ~= 'string' or capacity <= 0 then return end

    local needed = capacity - currentLiters
    if needed <= 0 then
        return Notify(src, 'Réservoir déjà plein.', 'error')
    end

    MySQL.Async.fetchAll('SELECT fuel_liters FROM interim_stations WHERE id=@id LIMIT 1', { ['@id'] = stationId }, function(rows)
        if not rows or not rows[1] then
            return Notify(src, 'Station introuvable.', 'error')
        end

        local stock = math.floor(tonumber(rows[1].fuel_liters) or 0)
        if stock <= 0 then
            return Notify(src, 'Cette station est actuellement à sec.', 'error')
        end

        -- Vérification de l'argent AVANT toute délivrance : le joueur ne
        -- peut jamais recevoir plus d'essence que ce qu'il peut payer.
        local money = LSLegacy.Money.GetPlayerMoney(player) or 0
        local affordableLiters = math.floor(money / CFG.PricePerLiter)
        if affordableLiters <= 0 then
            return Notify(src, 'Fonds insuffisants.', 'error')
        end

        local maxDeliverable = math.min(needed, stock, affordableLiters)
        if maxDeliverable <= 0 then
            return Notify(src, 'Rien à ravitailler.', 'error')
        end

        LSLegacy.Events.SendToClient('pompe:fillAuthorized', src, {
            stationId = stationId,
            maxDeliverable = maxDeliverable,
        })
    end)
end)

-- token -> { src, stationId, liters, price }
local PendingFuel = {}

LSLegacy.Bank.RegisterPaymentResultHandler('pompe', function(token, success)
    local pending = PendingFuel[token]
    if not pending then return end
    PendingFuel[token] = nil
    if not success then
        Notify(pending.src, 'Paiement annulé, plein non facturé.', 'error')
        return
    end

    -- Reclampe sur le stock actuel : il a pu bouger pendant la saisie du paiement.
    MySQL.Async.fetchAll('SELECT fuel_liters FROM interim_stations WHERE id=@id LIMIT 1', { ['@id'] = pending.stationId }, function(rows)
        if not rows or not rows[1] then return end
        local stock = math.floor(tonumber(rows[1].fuel_liters) or 0)
        local actualLiters = math.min(pending.liters, stock)
        if actualLiters <= 0 then return end

        MySQL.Async.execute(
            'UPDATE interim_stations SET fuel_liters = fuel_liters - @liters WHERE id=@id',
            { ['@liters'] = actualLiters, ['@id'] = pending.stationId },
            function()
                Notify(pending.src, ('Plein effectué : %dL (-%.2f $).'):format(actualLiters, pending.price), 'success')
            end
        )
    end)
end)

LSLegacy.Events.Register('pompe:payFuel', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player or type(data) ~= 'table' then return end

    local stationId = data.stationId
    local liters = math.floor(tonumber(data.liters) or 0)
    if type(stationId) ~= 'string' or liters <= 0 then return end

    MySQL.Async.fetchAll('SELECT fuel_liters FROM interim_stations WHERE id=@id LIMIT 1', { ['@id'] = stationId }, function(rows)
        if not rows or not rows[1] then return end

        -- Sécurité anti-triche : ne jamais débiter/facturer plus que le
        -- stock réel actuel de la station, quoi que le client ait annoncé.
        local stock = math.floor(tonumber(rows[1].fuel_liters) or 0)
        local actualLiters = math.min(liters, stock)
        if actualLiters <= 0 then return end

        local price = math.floor((actualLiters * CFG.PricePerLiter) * 100 + 0.5) / 100

        local token = ('pompe_%d_%d'):format(src, math.random(100000, 999999))
        PendingFuel[token] = { src = src, stationId = stationId, liters = actualLiters, price = price }
        Citizen.SetTimeout(120000, function() PendingFuel[token] = nil end)
        LSLegacy.Bank.OpenPaymentMenu(src, ('Essence - %dL'):format(actualLiters), price, { meta = { type = 'pompe', refId = token } })
    end)
end)
