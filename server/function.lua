---@class LSLegacy
LSLegacy = {}
LSLegacy.Math = {}
LSLegacy.Event = {}
LSLegacy.Token = {}
LSLegacy.addTokenClient = {}
LSLegacy.PlayersLimit = {}
LSLegacy.RateLimit = {
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
    ['ap:updateVehicle'] = 20,
    ['ap:updateVehicleStatus'] = 20,
}

Citizen.CreateThread(function()
    while true do 
        LSLegacy.PlayersLimit = {}
        Wait(15000)
    end
end)

---GetPlayerFromId
---@type function
---@param id number
---@return table
---@public
LSLegacy.GetPlayerFromId = function(id)
    if not id then return end
    if LSLegacy.ServerPlayers[id] then
        return LSLegacy.ServerPlayers[id]
    else
        return nil
    end
end

---GetPlayerFromIdentifier
---@type function
---@param identifier string
---@return table
---@public
LSLegacy.GetPlayerFromIdentifier = function(identifier)
    if not identifier then return end
    for key, value in pairs(LSLegacy.ServerPlayers) do
        if v.identifier == identifier then
            break
            return value
        end
    end
    return nil
end

---GeneratorToken
---@type function
---@return string
---@public
LSLegacy.GeneratorToken = function()
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
LSLegacy.GeneratorTokenConnecting = function(_source)
    if not LSLegacy.addTokenClient[_source] then
        LSLegacy.addTokenClient[_source] = _source
        LSLegacy.Token[_source] = {}
        Wait(1500)
        for k, v in pairs(LSLegacy.Event) do
            LSLegacy.Token[_source][k] = LSLegacy.GeneratorToken()
        end
        LSLegacy.SendEventToClient("addTokenEvent", _source, LSLegacy.Token[_source])
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
LSLegacy.GeneratorNewToken = function(_source, event)
    token = LSLegacy.GeneratorToken()

    LSLegacy.Token[_source][event] = nil
    LSLegacy.Token[_source][event] = token
    LSLegacy.SendEventToClient("addTokenEvent", _source,  LSLegacy.Token[_source])
end

---RegisterServerEvent
---@type function
---@param eventName string
---@param cb function
---@return nil
---@public
LSLegacy.RegisterServerEvent = function(eventName, cb)
    if not LSLegacy.Event[eventName] then
	    LSLegacy.Event[eventName] = cb
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
LSLegacy.UseServerEvent = function(eventName, src, ...)
    if LSLegacy.Event[eventName] then
        if eventName ~= "DropInjectorDetected" then
            if not LSLegacy.PlayersLimit[eventName] then
                LSLegacy.PlayersLimit[eventName] = {}
            end
            if not LSLegacy.PlayersLimit[eventName][src] then
                LSLegacy.PlayersLimit[eventName][src] = 1
            end
            LSLegacy.PlayersLimit[eventName][src] = LSLegacy.PlayersLimit[eventName][src] + 1
            if LSLegacy.PlayersLimit[eventName][src] >= LSLegacy.RateLimit[eventName] then
                DropPlayer(src, 'Spam trigger detected ╭∩╮（︶_︶）╭∩╮ ('..eventName..')')
            else
                LSLegacy.Event[eventName](...)
            end
        else
            LSLegacy.Event[eventName](...)
        end
    end
end

RegisterNetEvent("useEvent")
AddEventHandler("useEvent", function(eventName, token, ...)
    local _src = source

    if eventName == "SetIdentity" then
        LSLegacy.GeneratorNewToken(_src, eventName)
        LSLegacy.UseServerEvent(eventName, _src, ...)
        Config.Development.Print("Successfully triggered server event " .. eventName)
    end

    if eventName and token and LSLegacy.Token[_src][eventName] == token then
        LSLegacy.GeneratorNewToken(_src, eventName)
        LSLegacy.UseServerEvent(eventName, _src, ...)
        Config.Development.Print("Successfully triggered server event " .. eventName)
    else
        LSLegacy.GeneratorNewToken(_src, eventName)
        Config.Development.Print("Injector detected ╭∩╮（︶_︶）╭∩╮ " .. eventName.." by ".._src)
    end
end)

---TriggerLocalEvent
---@type function
---@param name string
---@param ... any
---@return any
---@public
LSLegacy.TriggerLocalEvent = function(name, ...)
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
LSLegacy.SendEventToClient = function(name, receiver, ...)
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
LSLegacy.AddEventHandler = function(name, execute)
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
LSLegacy.GetEntityCoords = function(entity)
    if not entity then return end
    local _entity = GetEntityCoords(GetPlayerPed(entity))
    return vector3(_entity.x, _entity.y, _entity.z)
end

LSLegacy.RegisterServerEvent('updateNumberPlayer', function()
    local _source = source
    local number = 0
    for key, value in pairs(LSLegacy.ServerPlayers) do
        number = number + 1
    end
    LSLegacy.SendEventToClient('receiveNumberPlayers', _source, number)
end)

LSLegacy.RegisterServerEvent('DropInjectorDetected', function()
    local _src = source
    DropPlayer(_src, 'Injector detected ╭∩╮（︶_︶）╭∩╮')
end)

---Round
---@type function
---@param value number
---@param numDecimalPlaces number
---@return number
---@public
LSLegacy.Math.Round = function(value, numDecimalPlaces)
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
LSLegacy.ConverToBoolean = function(number)
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
LSLegacy.ConverToNumber = function(boolean)
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
LSLegacy.SpawnPedZone = function(hash, coords, zone, source)
    LSLegacy.SendEventToClient("SpawnPedZone", source, hash, coords, zone)
end

---StringSplit
---@type function
---@param string string
---@param sep string
---@return table
---@public
LSLegacy.StringSplit = function(string, sep)
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
LSLegacy.CreateDuplicationOfATableWithoutFunctions = function(table)
    local newTable = {}
    for k, v in pairs(table) do
        if not type(v) == "function" then
            newTable[k] = v
        end
    end
    return newTable
end

---GenerateNumeroDeSerie
---@type function
---@return string
---@public
LSLegacy.GenerateNumeroDeSerie = function()
    local chars = {}
    for i = 1, 2 do
        chars[i] = string.char(math.random(65, 90))
    end
    for i = 3, 9 do
        chars[i] = string.char(math.random(48, 57))
    end
    return table.concat(chars)
end