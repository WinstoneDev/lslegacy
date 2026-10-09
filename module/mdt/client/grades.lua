-- MDT — GESTION DES GRADES (client, pont NUI, atelier uniquement)

local pending, counter = {}, 0

LSLegacy.Events.Register('mdtgrades:queryResult', function(payload)
    if type(payload) ~= 'table' then return end
    local cb = pending[payload.reqId]
    if cb then pending[payload.reqId] = nil; cb(payload.result) end
end)

RegisterNUICallback('mdtgrades:get', function(data, cb)
    counter = counter + 1
    local reqId = counter
    pending[reqId] = function(res) cb(res == nil and false or res) end
    LSLegacy.Events.SendToServer('mdtgrades:query', { reqId = reqId })
    Citizen.SetTimeout(15000, function()
        if pending[reqId] then pending[reqId] = nil; cb(false) end
    end)
end)

RegisterNUICallback('mdtgrades:set', function(data, cb)
    LSLegacy.Events.SendToServer('mdtgrades:set', data)
    cb(true)
end)
