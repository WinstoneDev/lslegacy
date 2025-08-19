---@class MadeInFrance
MadeInFrance = {}
MadeInFrance.Math = {}
MadeInFrance.Event = {}
MadeInFrance.Token = {}
MadeInFrance.addTokenClient = {}
MadeInFrance.PlayersLimit = {}
MadeInFrance.RateLimit = {
    ['AdminServerPlayers'] = 25,
    ['MessageAdmin'] = 15,
    ['TeleportPlayers'] = 25,
    ['SetBucket'] = 20,
    ['saveskin'] = 20,
    ['SetIdentity'] = 20,
    ['zones:haveInteract'] = 40,
    ['renameItem'] = 15,
    ['useItem'] = 30,
    ['transfer'] = 30,
    ['addItemPickup'] = 20,
    ['removeItemPickup'] = 30,
    ['haveExitedZone'] = 30,
    ['GetBankAccounts'] = 30,
    ['BankCreateAccount'] = 15,
    ['AddClothesInInventory'] = 20,
    ['BankChangeAccountStatus'] = 20,
    ['BankDeleteAccount'] = 20,
    ['BankCreateCard'] = 20,
    ['BankwithdrawMoney'] = 20,
    ['BankAddMoney'] = 20,
    ['attemptToPayMenu'] = 20,
    ['pay'] = 20,
    ['ReceiveUpdateServerPlayer'] = 20,
    ['RegisterDataStore'] = 20,
    ['PutIntoTrunk'] = 20,
    ['TakeFromTrunk'] = 20,
    ['giveItem'] = 20,
    ['removeItem'] = 20,
    ['removeAmmo'] = 20,
    ['updateNumberPlayer'] = 20,
    ['applyNeedEffect'] = 20,
    ['ap:touchVehicle'] = 20,
    ['ap:updateVehicle'] = 20,
    ['ap:updateVehicleStatus'] = 20,
}

Citizen.CreateThread(function()
    while true do 
        MadeInFrance.PlayersLimit = {}
        Wait(15000)
    end
end)

---GetPlayerFromId
---@type function
---@param id number
---@return table
---@public
MadeInFrance.GetPlayerFromId = function(id)
    if not id then return end
    if MadeInFrance.ServerPlayers[id] then
        return MadeInFrance.ServerPlayers[id]
    else
        return nil
    end
end

---GetPlayerFromIdentifier
---@type function
---@param identifier string
---@return table
---@public
MadeInFrance.GetPlayerFromIdentifier = function(identifier)
    if not identifier then return end
    for key, value in pairs(MadeInFrance.ServerPlayers) do
        if v.identifier == identifier then
            break
            return value
        end
    end
end

---GeneratorToken
---@type function
---@return string
---@public
MadeInFrance.GeneratorToken = function()
	local token = ""

	for i = 1, 150 do
		token = token .. string.char(math.random(97, 122))
	end
    return token
end

---GeneratorTokenConnecting
---@type function
---@param _source number
---@return any
---@public
MadeInFrance.GeneratorTokenConnecting = function(_source)
    if not MadeInFrance.addTokenClient[_source] then
        MadeInFrance.addTokenClient[_source] = _source
        MadeInFrance.Token[_source] = {}
        Wait(1500)
        for k, v in pairs(MadeInFrance.Event) do
            MadeInFrance.Token[_source][k] = MadeInFrance.GeneratorToken()
        end

        MadeInFrance.SendEventToClient("addTokenEvent", _source, MadeInFrance.Token[_source])
    else
        DropPlayer(_source, 'Injector detected ╭∩╮（︶_︶）╭∩╮')
    end
end

---GeneratorNewToken
---@type function
---@param _source number
---@param event string
---@return any
---@public
MadeInFrance.GeneratorNewToken = function(_source, event)
    token = MadeInFrance.GeneratorToken()

    MadeInFrance.Token[_source][event] = nil
    MadeInFrance.Token[_source][event] = token
    MadeInFrance.SendEventToClient("addTokenEvent", _source,  MadeInFrance.Token[_source])
end

---RegisterServerEvent
---@type function
---@param eventName string
---@param cb function
---@return nil
---@public
MadeInFrance.RegisterServerEvent = function(eventName, cb)
    if not MadeInFrance.Event[eventName] then
	    MadeInFrance.Event[eventName] = cb
        Config.Development.Print("Successfully registered event " .. eventName)
    else
        return Config.Development.Print("Event " .. eventName .. " already registered")
    end
end

---UseServerEvent
---@type function
---@param eventName string
---@param src number
---@param ... any
---@return any
---@public
MadeInFrance.UseServerEvent = function(eventName, src, ...)
    if MadeInFrance.Event[eventName] then
        if eventName ~= "DropInjectorDetected" then
            if not MadeInFrance.PlayersLimit[eventName] then
                MadeInFrance.PlayersLimit[eventName] = {}
            end
            if not MadeInFrance.PlayersLimit[eventName][src] then
                MadeInFrance.PlayersLimit[eventName][src] = 1
            end
            MadeInFrance.PlayersLimit[eventName][src] = MadeInFrance.PlayersLimit[eventName][src] + 1
            if MadeInFrance.PlayersLimit[eventName][src] >= MadeInFrance.RateLimit[eventName] then
                DropPlayer(src, 'Spam trigger detected ╭∩╮（︶_︶）╭∩╮ ('..eventName..')')
            else
                MadeInFrance.Event[eventName](...)
            end
        else
            MadeInFrance.Event[eventName](...)
        end
    end
end

RegisterNetEvent("useEvent")
AddEventHandler("useEvent", function(eventName, token, ...)
    local _src = source

    if eventName == "SetIdentity" then
        MadeInFrance.GeneratorNewToken(_src, eventName)
        MadeInFrance.UseServerEvent(eventName, _src, ...)
        Config.Development.Print("Successfully triggered server event " .. eventName)
    end

    if eventName and token and MadeInFrance.Token[_src][eventName] == token then
        MadeInFrance.GeneratorNewToken(_src, eventName)
        MadeInFrance.UseServerEvent(eventName, _src, ...)
        Config.Development.Print("Successfully triggered server event " .. eventName)
    else
        MadeInFrance.GeneratorNewToken(_src, eventName)
        Config.Development.Print("Injector detected ╭∩╮（︶_︶）╭∩╮ " .. eventName.." by ".._src)
    end
end)

---TriggerLocalEvent
---@type function
---@param name string
---@param ... any
---@return any
---@public
MadeInFrance.TriggerLocalEvent = function(name, ...)
    if not name then return end
    TriggerEvent(name, ...)
    Config.Development.Print("Successfully triggered event " .. name)
end

---SendEventToClient
---@type function
---@param name string
---@param receiver number
---@param ... any
---@return any
---@public
MadeInFrance.SendEventToClient = function(name, receiver, ...)
    if not name then return end
    if not receiver then return end 

    TriggerClientEvent(name, receiver, ...)
    Config.Development.Print("Successfully sent event " .. name .. " to client ".. receiver)
end

---AddEventHandler
---@type function
---@param name string
---@param execute function
---@return any
---@public
MadeInFrance.AddEventHandler = function(name, execute)
    if not name then return end
    if not execute then return end
    AddEventHandler(name, function(...)
        execute(...)
    end)
    Config.Development.Print("Successfully added event " .. name)
end

---GetEntityCoords
---@type function
---@param entity number
---@return table
---@public
MadeInFrance.GetEntityCoords = function(entity)
    if not entity then return end
    local _entity = GetEntityCoords(GetPlayerPed(entity))
    return vector3(_entity.x, _entity.y, _entity.z)
end

MadeInFrance.RegisterServerEvent('updateNumberPlayer', function()
    local _source = source
    local number = 0
    for key, value in pairs(MadeInFrance.ServerPlayers) do
        number = number + 1
    end
    MadeInFrance.SendEventToClient('receiveNumberPlayers', _source, number)
end)

MadeInFrance.RegisterServerEvent('DropInjectorDetected', function()
    local _src = source
    DropPlayer(_src, 'Injector detected ╭∩╮（︶_︶）╭∩╮')
end)

---Round
---@type function
---@param value number
---@param numDecimalPlaces number
---@return number
---@public
MadeInFrance.Math.Round = function(value, numDecimalPlaces)
    if numDecimalPlaces then
        local power = 10^numDecimalPlaces
        return math.floor((value * power) + 0.5) / (power)
    else
        return math.floor(value + 0.5)
    end
end

---ConverToBoolean
---@type function
---@param number number
---@return boolean
---@public
MadeInFrance.ConverToBoolean = function(number)
    if number == 0 then
        return false
    elseif number == 1 then
        return true
    end
end

---ConverToNumber
---@type function
---@param boolean boolean
---@return number
---@public
MadeInFrance.ConverToNumber = function(boolean)
    if boolean == false then
        return 0
    elseif boolean == true then
        return 1
    end
end

---SpawnPedZone
---@type function
---@param hash string
---@param coords table
---@param zone string
---@param source number
---@return any
---@public
MadeInFrance.SpawnPedZone = function(hash, coords, zone, source)
    MadeInFrance.SendEventToClient("SpawnPedZone", source, hash, coords, zone)
end

---StringSplit
---@type function
---@param string string
---@param sep string
---@return table
---@public
MadeInFrance.StringSplit = function(string, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {} ; i = 1
    for str in string.gmatch(string, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

---CreateDuplicationOfATableWithoutFunctions
---@type function
---@param table table
---@return table
---@public
MadeInFrance.CreateDuplicationOfATableWithoutFunctions = function(table)
    local newTable = {}
    for k, v in pairs(table) do
        if not type(v) == "function" then
            newTable[k] = v
        end
    end
    return newTable
end

---GenerateNumeroDeSerie
---@return string
---@public
MadeInFrance.GenerateNumeroDeSerie = function()
    local chars = {}
    for i = 1, 3 do
        chars[i] = string.char(math.random(65, 90))
    end
    for i = 4, 10 do
        chars[i] = string.char(math.random(48, 57))
    end
    return table.concat(chars)
end