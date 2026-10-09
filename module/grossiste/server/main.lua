-- module/grossiste (serveur) — achat/vente, stock illimité, prix fixes relus
-- depuis GRConfig.Catalog (jamais fournis par le client).

local Core = exports['lslegacy']

LSLegacy.Security.RegisterRateLimit('grossiste:buy', 20)
LSLegacy.Security.RegisterRateLimit('grossiste:sell', 20)

CreateThread(function()
    local count = Core:registerItems(GRConfig.Items)
    if GRConfig.Debug then print(('[grossiste] %d item(s) enregistrés'):format(count)) end
end)

local function Notify(src, msg, kind)
    TriggerClientEvent('notify', src, 'Grossiste', msg, kind or 'info', 5000)
end

local function NearPed(src, cfg)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - cfg.coords) <= (GRConfig.Security.maxDistance + 3.0)
end

local function SafeNameForJob(job)
    return job and GRConfig.CompanySafes[job] or nil
end

-- ── Achat ────────────────────────────────────────────────────────────────

local function GivePurchase(src, entry, qty)
    local totalCount = entry.packCount * qty
    if not Core:canCarry(src, entry.item, totalCount) then
        TriggerClientEvent('grossiste:buyResult', src, false, 'weight')
        return false
    end
    if entry.potUses then
        -- Un pot par lot, chacun avec SON PROPRE compteur d'utilisations
        -- (jamais une table partagée — même règle que ls_kebabking/server/craft.lua).
        for _ = 1, qty do
            Core:addItem(src, entry.item, 1, { uses = entry.potUses },
                ('%s (%d utilisations)'):format(GR.ItemLabel(entry.item), entry.potUses))
        end
    else
        Core:addItem(src, entry.item, totalCount)
    end
    return true
end

-- refId -> { src, entry, qty, price }
local pendingBuys = {}

-- openPaymentMenu (foodapi) installe son propre handler Bank et relaie le résultat par cet event.
AddEventHandler('lslegacy:foodapi:paymentResult', function(kind, refId, success)
    if kind ~= 'grossiste_buy' then return end
    local pending = pendingBuys[refId]
    if not pending then return end
    pendingBuys[refId] = nil
    if not success then
        TriggerClientEvent('grossiste:buyResult', pending.src, false, 'payment_failed')
        return
    end
    if GivePurchase(pending.src, pending.entry, pending.qty) then
        TriggerClientEvent('grossiste:buyResult', pending.src, true)
    end
end)

LSLegacy.Events.Register('grossiste:buy', function(item, qty, method)
    local src = source
    local player = LSLegacy.Players.Get(src)
    if not player then return end
    if not NearPed(src, GRConfig.Seller) then return end

    local entry = GR.GetCatalogEntry(item)
    qty = LSLegacy.Validate.PositiveInteger(qty)
    if not entry or not qty or qty > 50 then
        TriggerClientEvent('grossiste:buyResult', src, false, 'invalid_item')
        return
    end

    local price = math.floor(entry.buyUnit * entry.packCount * qty)

    if method == 'company' then
        local safe = SafeNameForJob(player.job)
        if not safe then
            TriggerClientEvent('grossiste:buyResult', src, false, 'no_company')
            return
        end
        Core:ensureDataStore(safe, 'safe', 100)
        if not Core:removeDataStoreMoney(safe, price) then
            TriggerClientEvent('grossiste:buyResult', src, false, 'payment_failed')
            return
        end
        if not GivePurchase(src, entry, qty) then
            Core:addDataStoreMoney(safe, price) -- rollback : poids insuffisant après débit
        else
            TriggerClientEvent('grossiste:buyResult', src, true)
        end
        return
    end

    -- 'personal' : délègue au TPE partagé (espèces/carte, choisi dans son UI).
    local refId = ('grossiste_%d_%d'):format(src, math.random(100000, 999999))
    pendingBuys[refId] = { src = src, entry = entry, qty = qty, price = price }
    Citizen.SetTimeout(120000, function() pendingBuys[refId] = nil end)
    local opened = Core:openPaymentMenu(src, 'Grossiste — ' .. entry.pack, price, 'grossiste_buy', refId)
    if not opened then
        pendingBuys[refId] = nil
        TriggerClientEvent('grossiste:buyResult', src, false, 'payment_failed')
    end
end)

-- ── Vente ────────────────────────────────────────────────────────────────

LSLegacy.Events.Register('grossiste:sell', function(item, qty)
    local src = source
    local player = LSLegacy.Players.Get(src)
    if not player then return end
    if not NearPed(src, Config.Avicole.Grossiste) then return end

    local entry = GR.GetCatalogEntry(item)
    qty = LSLegacy.Validate.PositiveInteger(qty)
    if not entry or not qty then
        TriggerClientEvent('grossiste:sellResult', src, false, 'invalid_item')
        return
    end

    local held = Core:getItemCount(src, item)
    if held < qty then
        TriggerClientEvent('grossiste:sellResult', src, false, 'missing')
        return
    end

    local amount = math.floor(entry.sellUnit * qty)
    if not Core:removeItem(src, item, qty) then
        TriggerClientEvent('grossiste:sellResult', src, false, 'missing')
        return
    end

    local safe = SafeNameForJob(player.job)
    if safe then
        Core:ensureDataStore(safe, 'safe', 100)
        Core:addDataStoreMoney(safe, amount)
        Notify(src, ('Revendu pour %d $, déposés sur le compte entreprise (Vente grossiste).'):format(amount), 'success')
        TriggerClientEvent('grossiste:sellResult', src, true, nil, amount)
    else
        LSLegacy.Money.AddPlayerMoney(player, amount)
        TriggerClientEvent('grossiste:sellResult', src, true, nil, amount)
    end
end)

-- ── Déballage retail (GRConfig.Unpacks) — chaque paquet/bouteille/pot
-- s'ouvre en N unités de l'ingrédient de base qu'il contient.
for packItem, def in pairs(GRConfig.Unpacks) do
    LSLegacy.RegisterUsableItem(packItem, function(_data, uniqueId)
        local src = source
        if Core:getItemCount(src, packItem) < 1 then return end
        if not Core:removeItem(src, packItem, 1) then return end
        Core:addItem(src, def.item, def.count)
        Notify(src, ('Vous ouvrez %s : %d %s.'):format(GR.ItemLabel(packItem), def.count, def.label), 'success')
    end)
end
