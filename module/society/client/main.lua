--  MODULE SOCIETY — client : pont NUI de l'onglet MDT « Entreprise ».
local pending, counter = {}, 0

LSLegacy.Events.Register('mdtsociety:queryResult', function(payload)
    if type(payload) ~= 'table' then return end
    local cb = pending[payload.reqId]
    if cb then pending[payload.reqId] = nil; cb(payload.result) end
end)

local function Query(action, data, cb)
    counter = counter + 1
    local reqId = counter
    pending[reqId] = cb
    LSLegacy.Events.SendToServer('mdtsociety:query', { reqId = reqId, action = action, data = data or {} })
    Citizen.SetTimeout(15000, function()
        if pending[reqId] then pending[reqId] = nil; cb(false) end
    end)
end

for _, name in ipairs({ 'getOverview', 'cancelInvoice', 'getNearby' }) do
    RegisterNUICallback('mdtsociety:' .. name, function(data, cb)
        Query(name, type(data) == 'table' and data or {}, function(res) cb(res == nil and false or res) end)
    end)
end

RegisterNUICallback('mdtsociety:invoiceNearby', function(data, cb)
    LSLegacy.Events.SendToServer('society:invoiceNearby', {
        targetSrc = tonumber(data.targetSrc), amount = tonumber(data.amount), reason = data.reason,
    })
    cb(true)
end)

RegisterNUICallback('mdtsociety:collectInvoice', function(data, cb)
    LSLegacy.Events.SendToServer('society:collectInvoice', tonumber(data.id))
    cb(true)
end)
