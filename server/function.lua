---@class MadeInFrance
MadeInFrance = {}
MadeInFrance.Math = {}
MadeInFrance.Event = {}
MadeInFrance.Token = {}
MadeInFrance.addTokenClient = {}
MadeInFrance.PlayersLimit = {}
MadeInFrance.RateLimit = {
    ['AdminServerPlayers'] = 35,
    ['MessageAdmin'] = 25,
    ['TeleportPlayers'] = 35,
    ['SetBucket'] = 30,
    ['saveskin'] = 70,
    ['SetIdentity'] = 30,
    ['zones:haveInteract'] = 50,
    ['renameItem'] = 25,
    ['useItem'] = 40,
    ['transfer'] = 40,
    ['addItemPickup'] = 30,
    ['removeItemPickup'] = 40,
    ['haveExitedZone'] = 40,
    ['GetBankAccounts'] = 40,
    ['BankCreateAccount'] = 25,
    ['AddClothesInInventory'] = 30,
    ['BankChangeAccountStatus'] = 30,
    ['BankDeleteAccount'] = 30,
    ['BankCreateCard'] = 30,
    ['BankwithdrawMoney'] = 30,
    ['BankAddMoney'] = 30,
    ['attemptToPayMenu'] = 30,
    ['pay'] = 30,
    ['ReceiveUpdateServerPlayer'] = 30,
    ['RegisterDataStore'] = 30,
    ['PutIntoTrunk'] = 30,
    ['TakeFromTrunk'] = 30,
}

Citizen.CreateThread(function()
    while true do 
        Wait(15000)
        MadeInFrance.PlayersLimit = {}
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
---@param _source number
---@return string
---@public
MadeInFrance.GeneratorToken = function(_source)
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

        MadeInFrance.Token[_source] = MadeInFrance.GeneratorToken(_source)

        MadeInFrance.SendEventToClient("addTokenEvent", _source, MadeInFrance.Token[_source])
    else
        DropPlayer(_source, 'Injector detected ╭∩╮（︶_︶）╭∩╮')
    end
end

---GeneratorNewToken
---@type function
---@param _source number
---@return any
---@public
MadeInFrance.GeneratorNewToken = function(_source)
    token = MadeInFrance.GeneratorToken(_source)

    MadeInFrance.Token[_source] = nil
    MadeInFrance.Token[_source] = token
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
        if eventName ~= "updateNumberPlayer" and eventName ~= "DropInjectorDetected" then
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
    if eventName and token and MadeInFrance.Token[_src] == token then
        MadeInFrance.GeneratorNewToken(_src)
        MadeInFrance.UseServerEvent(eventName, _src, ...)
        Config.Development.Print("Successfully triggered server event " .. eventName)
    else
        if eventName ~= "updateNumberPlayer" and eventName ~= "DropInjectorDetected" and eventName ~= "ReceiveUpdateServerPlayer" and eventName ~= "useItem" then
            DropPlayer(_src, 'Injector detected ╭∩╮（︶_︶）╭∩╮')
            Config.Development.Print("Injector detected ╭∩╮（︶_︶）╭∩╮ " .. eventName)
        end
    end
end)

---TriggerLocalEvent
---@type function
---@param name string
---@param ... any
---@return any
---@public
MadeInFrance.TriggerLocalEvent = function(name, ...)
    local _source = source
    if not name then return end
    TriggerEvent(name, ...)
    Config.Development.Print("Successfully triggered event " .. name .. "from source ".. _source)
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

---SpawnPed
---@type function
---@param hash string
---@param coords table
---@param anim number
---@return void
---@public
MadeInFrance.SpawnPed = function(hash, coords, anim)
    local ped = CreatePed(4, hash, coords, false, false)
    FreezeEntityPosition(ped, true) 
    return ped
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