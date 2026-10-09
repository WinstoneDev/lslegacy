-- Vendeur PNJ LTD Little Seoul : prix relus côté serveur, paiement via TPE partagé (espèces/carte).

local Core = exports['lslegacy']
local cfg  = Config.LTD.PedShop

LSLegacy.Security.RegisterRateLimit('ltd:pedshop:buy', 20)

local byItem = {}
for _, e in ipairs(cfg.items) do byItem[e.item] = e end

-- refId -> { src, entry, qty }
local pending = {}

-- openPaymentMenu (foodapi) installe son propre handler Bank et relaie le résultat par cet event.
AddEventHandler('lslegacy:foodapi:paymentResult', function(kind, refId, success)
    if kind ~= 'ltd_pedshop' then return end
    local p = pending[refId]
    if not p then return end
    pending[refId] = nil
    if not success then
        LSLegacy.Events.SendToClient('ltd:pedshop:result', p.src, false, 'payment_failed')
        return
    end
    local data = p.entry.item:find('^food_') and { durability = 100 } or nil
    Core:addItem(p.src, p.entry.item, p.qty, data)
    LSLegacy.Events.SendToClient('ltd:pedshop:result', p.src, true)
end)

LSLegacy.Events.Register('ltd:pedshop:buy', function(item, qty)
    local src = source
    if not LSLegacy.Players.Get(src) then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - cfg.coords) > cfg.maxDistance then return end

    local entry = type(item) == 'string' and byItem[item] or nil
    qty = LSLegacy.Validate.PositiveInteger(qty)
    if entry and entry.single then qty = 1 end
    if not entry or not qty or qty > cfg.maxQty then
        LSLegacy.Events.SendToClient('ltd:pedshop:result', src, false, 'invalid')
        return
    end

    if not Core:canCarry(src, entry.item, qty) then
        LSLegacy.Events.SendToClient('ltd:pedshop:result', src, false, 'weight')
        return
    end

    local refId = ('ltdps_%d_%d'):format(src, math.random(100000, 999999))
    pending[refId] = { src = src, entry = entry, qty = qty }
    Citizen.SetTimeout(120000, function() pending[refId] = nil end)
    if not Core:openPaymentMenu(src, 'LTD — ' .. entry.label, entry.price * qty, 'ltd_pedshop', refId) then
        pending[refId] = nil
        LSLegacy.Events.SendToClient('ltd:pedshop:result', src, false, 'payment_failed')
    end
end)
