---@class MadeInFrance.ServerPlayers
MadeInFrance.ServerPlayers = {}

MadeInFrance.RegisterServerEvent('ReceiveUpdateServerPlayer', function(data)
    local source = source
    MadeInFrance.ServerPlayers[source] = data
end)

local function GetPlayerDiscord(source)
    local _source = source
    local discord = nil
    for _, v in pairs(GetPlayerIdentifiers(_source)) do
        if string.find(v, "discord:") then
            discord = v
        end
    end  
    if not discord then
        discord = "Aucun discord"
    end
    return discord
end

local function GetPlayerIndentifier(source)
    local _source = source
    local identifier = nil
    for _, v in pairs(GetPlayerIdentifiers(_source)) do
        if string.find(v, "license:") then
            identifier = v
        end
    end  
    if not identifier then
        identifier = "Aucune license"
    end
    return identifier
end

RegisterNetEvent("registerPlayer")
AddEventHandler("registerPlayer", function()
    local source = source

    if not MadeInFrance.ServerPlayers[source] then
        MadeInFrance.GeneratorTokenConnecting(source)
        MySQL.Async.fetchAll('SELECT * FROM players WHERE identifier = @identifier', {
            ['@identifier'] = GetPlayerIndentifier(source)
        }, function(result)
            if not result[1] then
                MadeInFrance.ServerPlayers[source] = {
                    name = GetPlayerName(source),
                    identifier = GetPlayerIndentifier(source),
                    ip = GetPlayerEP(source),
                    discordId = GetPlayerDiscord(source),
                    source = source,
                    token = GetPlayerToken(source),
                    characterInfos = {Sexe = "Aucun", LDN = "Aucun", Prenom = "Aucun", NDF = "Aucun", Taille = 180, DDN = "19/04/1999"},
                    inventory = {},
                    currentZone = "Aucune",
                    coords = vector3(0, 0, 0),
                    weight = MadeInFrance.Inventory.GetInventoryWeight({}) or 0,
                    health = 200,
                    armor = 0,
                    skin = nil,
                    cash = Config.Informations["StartMoney"].cash,
                    dirty = Config.Informations["StartMoney"].dirty,
                    group = Config.StaffGroups[0],
                    status = {
                        hunger = 100,
                        thirst = 100,
                        stamina = 100
                    }
                }
                MySQL.Async.insert('INSERT INTO players (identifier, discordId, token, characterInfos, coords, status) VALUES(@identifier, @discordId, @token, @characterInfos, @coords, @status)', {
                    ['@identifier'] = MadeInFrance.ServerPlayers[source].identifier,
                    ['@discordId'] = MadeInFrance.ServerPlayers[source].discordId,
                    ['@token'] = MadeInFrance.ServerPlayers[source].token,
                    ['@characterInfos'] = json.encode(MadeInFrance.ServerPlayers[source].characterInfos),
                    ['@coords'] = json.encode(MadeInFrance.ServerPlayers[source].coords),
                    ['@status'] = json.encode(MadeInFrance.ServerPlayers[source].status)
                }, function()
                end)
                Wait(500)
                MySQL.Async.fetchAll('SELECT * FROM players WHERE identifier = @identifier', {
                    ['@identifier'] = MadeInFrance.ServerPlayers[source].identifier
                }, function(result)
                    if result[1] then
                        MadeInFrance.ServerPlayers[source].id = result[1].id
                    end
                end)
                MadeInFrance.SendEventToClient('InitPlayer', source, MadeInFrance.ServerPlayers[source])
                MadeInFrance.RegisterPeds(MadeInFrance.RegisteredZones, source)
                for k, v in pairs(MadeInFrance.Commands) do
                    if v.suggestion then
                        if not v.suggestion.arguments then v.suggestion.arguments = {} end
                        if not v.suggestion.help then v.suggestion.help = '' end
                        TriggerClientEvent('chat:addSuggestion', source, ('/%s'):format(k), v.suggestion.help, v.suggestion.arguments)
                    end
                end
                Config.Development.Print("Successfully registered player " .. GetPlayerName(source))
                MadeInFrance.SendEventToClient('zones:registerBlips', source, MadeInFrance.RegisteredZones)
                MadeInFrance.SendEventToClient('UpdateDatastore', source, MadeInFrance.DataStores)
                Wait(5000)
                MadeInFrance.TriggerLocalEvent('ap:clientsetonSpawn', source)
            else
                MadeInFrance.ServerPlayers[source] = {
                    id = result[1].id,
                    name = GetPlayerName(source),
                    identifier = result[1].identifier,
                    ip = GetPlayerEP(source),
                    discordId = GetPlayerDiscord(source),
                    source = source,
                    token = GetPlayerToken(source),
                    characterInfos = json.decode(result[1].characterInfos),
                    inventory = json.decode(result[1].inventory),
                    currentZone = "Aucune",
                    coords = json.decode(result[1].coords),
                    weight = 0,
                    health = result[1].health,
                    skin = json.decode(result[1].skin),
                    cash = json.decode(result[1].money).cash,
                    dirty = json.decode(result[1].money).dirty,
                    group = result[1].group,
                    status = json.decode(result[1].status)
                }
                MySQL.Async.execute('UPDATE players SET token = @token, discordId = @discordId WHERE identifier = @identifier', {
                    ['@token'] = MadeInFrance.ServerPlayers[source].token,
                    ['@discordId'] = MadeInFrance.ServerPlayers[source].discordId,
                    ['@identifier'] = MadeInFrance.ServerPlayers[source].identifier
                })
                Wait(250)
                local weight = MadeInFrance.Inventory.GetInventoryWeight(MadeInFrance.ServerPlayers[source].inventory)
                MadeInFrance.ServerPlayers[source].weight = weight or 0
                Wait(250)
                MadeInFrance.SendEventToClient('InitPlayer', source, MadeInFrance.ServerPlayers[source])
                MadeInFrance.RegisterPeds(MadeInFrance.RegisteredZones, source)
                for k, v in pairs(MadeInFrance.Commands) do
                    if v.suggestion then
                        if not v.suggestion.arguments then v.suggestion.arguments = {} end
                        if not v.suggestion.help then v.suggestion.help = '' end
                
                        TriggerClientEvent('chat:addSuggestion', source, ('/%s'):format(k), v.suggestion.help, v.suggestion.arguments)
                    end
                end
                Config.Development.Print("Successfully registered player " .. GetPlayerName(source))
                MadeInFrance.SendEventToClient('zones:registerBlips', source, MadeInFrance.RegisteredZones)
                MadeInFrance.SendEventToClient('UpdateDatastore', source, MadeInFrance.DataStores)
                Wait(5000)
                MadeInFrance.TriggerLocalEvent('ap:clientsetonSpawn', source)
            end
        end)
    else
        Config.Development.Print("Player " .. source .. " already registered")
        DropPlayer(source, "Player " .. source .. " already registered ╭∩╮（︶_︶）╭∩╮")
    end
end)

Citizen.CreateThread(function()
    Wait(10000)
    while true do
        for k, player in pairs(MadeInFrance.ServerPlayers) do
            local _source = player.source
            local coords = MadeInFrance.GetEntityCoords(_source)
            player.coords = coords
            MySQL.Async.execute('UPDATE players SET coords = @coords, skin = @skin, inventory = @inventory, money = @money, status = @status WHERE id = @id', {
                ['@coords'] = json.encode(coords),
                ['@id'] = MadeInFrance.ServerPlayers[_source].id,
                ["@skin"] = json.encode(MadeInFrance.ServerPlayers[_source].skin),
                ['@inventory'] = json.encode(MadeInFrance.ServerPlayers[_source].inventory),
                ['@money'] = json.encode({cash = MadeInFrance.ServerPlayers[_source].cash, dirty = MadeInFrance.ServerPlayers[_source].dirty}),
                ['@health'] = GetEntityHealth(GetPlayerPed(_source)),
                ['@status'] = json.encode(MadeInFrance.ServerPlayers[_source].status)
            }) 
            MadeInFrance.SendEventToClient('UpdateServerPlayer', _source)
            MadeInFrance.SendEventToClient('UpdateDatastore', _source, MadeInFrance.DataStores)
            Wait(500)
            MadeInFrance.SendEventToClient('UpdatePlayer', _source, MadeInFrance.ServerPlayers[_source])
           
        end
        Wait(60000)
    end
end)


Citizen.CreateThread(function()
    Wait(10000)
    while true do
        MadeInFrance.SendEventToClient('notify', -1, 'Synchronisation automatique', 'Vous avez bien synchronisé votre personnage.', 'success')
        Wait(5*60000)
    end
end)

MadeInFrance.AddEventHandler('playerDropped', function()
    local _source = source
    if MadeInFrance.ServerPlayers[_source] then
        MySQL.Async.execute('UPDATE players SET coords = @coords, inventory = @inventory, money = @money, health = @health, skin = @skin, status = @status WHERE id = @id', {
            ['@coords'] = json.encode(MadeInFrance.ServerPlayers[_source].coords),
            ['@inventory'] = json.encode(MadeInFrance.ServerPlayers[_source].inventory),
            ['@money'] = json.encode({cash = MadeInFrance.ServerPlayers[_source].cash, dirty = MadeInFrance.ServerPlayers[_source].dirty}),
            ['@id'] = MadeInFrance.ServerPlayers[_source].id,
            ['@health'] = GetEntityHealth(GetPlayerPed(source)),
            ['@skin'] = json.encode(MadeInFrance.ServerPlayers[_source].skin),
            ['@status'] = json.encode(MadeInFrance.ServerPlayers[_source].status)
        })
        MadeInFrance.ServerPlayers[_source] = nil
        Config.Development.Print("Player " .. _source .. " disconnected")
    end
end)