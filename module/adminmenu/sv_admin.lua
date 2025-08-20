LSLegacy.RegisterServerEvent('AdminServerPlayers', function()
    local _source = source

    LSLegacy.SendEventToClient('AdminServerPlayers', _source, LSLegacy.ServerPlayers)
end)

LSLegacy.RegisterServerEvent('MessageAdmin', function(target, msg)
    local _source = target

    LSLegacy.SendEventToClient('notify', target, "Administration", msg, "warning")
end)

LSLegacy.RegisterServerEvent('TeleportPlayers', function(type, target)
    local _source = source

    if type == "tp" then
        SetEntityCoords(GetPlayerPed(_source), GetEntityCoords(GetPlayerPed(target)))
    elseif type == "bring" then
        SetEntityCoords(GetPlayerPed(target), GetEntityCoords(GetPlayerPed(_source)))
    end
end)