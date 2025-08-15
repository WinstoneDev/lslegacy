MadeInFrance.RegisterServerEvent('AdminServerPlayers', function()
    local _source = source

    MadeInFrance.SendEventToClient('AdminServerPlayers', _source, MadeInFrance.ServerPlayers)
end)

MadeInFrance.RegisterServerEvent('MessageAdmin', function(target, msg)
    local _source = target

    MadeInFrance.SendEventToClient('notify', target, "Administration", msg, "warning")
end)

MadeInFrance.RegisterServerEvent('TeleportPlayers', function(type, target)
    local _source = source

    if type == "tp" then
        SetEntityCoords(GetPlayerPed(_source), GetEntityCoords(GetPlayerPed(target)))
    elseif type == "bring" then
        SetEntityCoords(GetPlayerPed(target), GetEntityCoords(GetPlayerPed(_source)))
    end
end)