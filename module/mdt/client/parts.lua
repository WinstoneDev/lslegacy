--  MDT — COMMANDE DE PIÈCES (client, générique atelier)
--  Pont NUI de l'onglet MDT « Commande de pièces ». Pas de point de retrait
--  dédié : la livraison alimente directement le stock du dépôt de pièces
--  existant (module/atelier/client/inventory.lua), retiré à la touche ALT
--  (ox_target) comme n'importe quelle autre pièce en stock.

local pending, counter = {}, 0

LSLegacy.Events.Register('mdtparts:queryResult', function(payload)
    if type(payload) ~= 'table' then return end
    local cb = pending[payload.reqId]
    if cb then pending[payload.reqId] = nil; cb(payload.result) end
end)

local function Query(action, data, cb)
    counter = counter + 1
    local reqId = counter
    pending[reqId] = cb
    LSLegacy.Events.SendToServer('mdtparts:query', { reqId = reqId, action = action, data = data or {} })
    Citizen.SetTimeout(15000, function()
        if pending[reqId] then pending[reqId] = nil; cb(false) end
    end)
end

for _, name in ipairs({ 'getCatalogue', 'getHistory' }) do
    RegisterNUICallback('mdtparts:' .. name, function(data, cb)
        Query(name, type(data) == 'table' and data or {}, function(res) cb(res == nil and false or res) end)
    end)
end

RegisterNUICallback('mdtparts:order', function(data, cb)
    LSLegacy.Events.SendToServer('mdtparts:order', data)
    cb(true)
end)

RegisterNUICallback('mdtparts:cancel', function(data, cb)
    LSLegacy.Events.SendToServer('mdtparts:cancel', { batchId = data.batchId })
    cb(true)
end)
