---@class MadeInFrance
MadeInFrance = {}
MadeInFrance.Math = {}
MadeInFrance.Event = {}
MadeInFrance.Resource = {}
MadeInFrance.Token = {}
MadeInFrance.addTokenClient = {}
MadeInFrance.PlayersLimit = {}
MadeInFrance.RateLimit = {
    ['AdminServerPlayers'] = 35,
    ['MessageAdmin'] = 25,
    ['TeleportPlayers'] = 35,
    ['SetBucket'] = 30,
    ['madeinfrance:saveskin'] = 70,
    ['SetIdentity'] = 30,
    ['zones:haveInteract'] = 25,
    ['madeinfrance:renameItem'] = 25,
    ['madeinfrance:useItem'] = 40,
    ['madeinfrance:transfer'] = 40,
    ['madeinfrance:addItemPickup'] = 30,
    ['madeinfrance:removeItemPickup'] = 40,
    ['madeinfrance:haveExitedZone'] = 40,
    ['madeinfrance:GetBankAccounts'] = 40,
    ['madeinfrance:BankCreateAccount'] = 25,
    ['madeinfrance:AddClothesInInventory'] = 30,
    ['madeinfrance:BankChangeAccountStatus'] = 30,
    ['madeinfrance:BankDeleteAccount'] = 30,
    ['madeinfrance:BankCreateCard'] = 30,
    ['madeinfrance:BankwithdrawMoney'] = 30,
    ['madeinfrance:BankAddMoney'] = 30,
    ['madeinfrance:attemptToPayMenu'] = 30,
    ['madeinfrance:pay'] = 30
}

Citizen.CreateThread(function()
    while true do 
        Wait(10000)
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
    if MadeInFrance.Token[_source][token] then
        MadeInFrance.GeneratorToken(_source)
    else
        return token
    end
end

---GeneratorTokenConnecting
---@type function
---@param _source number
---@return any
---@public
MadeInFrance.GeneratorTokenConnecting = function(_source)
    if not MadeInFrance.addTokenClient[_source] then
        MadeInFrance.addTokenClient[_source] = _source

        MadeInFrance.Resource[_source] = {}
        MadeInFrance.Token[_source] = {}

        for i = 0, GetNumResources(), 1 do
            local resourceName = GetResourceByFindIndex(i)
    
            if resourceName then
                token = MadeInFrance.GeneratorToken(_source)
                MadeInFrance.Resource[_source][resourceName] = token
                MadeInFrance.Token[_source][token] = resourceName
            end
        end

        MadeInFrance.SendEventToClient("madeinfrance:addTokenEvent", _source, MadeInFrance.Resource[_source])
    else
        DropPlayer(_source, 'Injector detected ╭∩╮（︶_︶）╭∩╮')
    end
end

---GeneratorNewToken
---@type function
---@param _source number
---@param resourceName string
---@param lastToken string
---@return any
---@public
MadeInFrance.GeneratorNewToken = function(_source, resourceName, lastToken)
    token = MadeInFrance.GeneratorToken(_source)

    MadeInFrance.Token[_source][lastToken] = nil
    MadeInFrance.Resource[_source][resourceName] = token
    MadeInFrance.Token[_source][token] = resourceName
    MadeInFrance.SendEventToClient("madeinfrance:addTokenEvent", _source, MadeInFrance.Resource[_source])
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
        if eventName ~= "madeinfrance:updateNumberPlayer" and eventName ~= "DropInjectorDetected" then
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

RegisterNetEvent("madeinfrance:useEvent")
AddEventHandler("madeinfrance:useEvent", function(eventName, tokenResource, ...)
    local _src = source

    if eventName and tokenResource and MadeInFrance.Token[_src][tokenResource] then
        MadeInFrance.GeneratorNewToken(_src, MadeInFrance.Token[_src][tokenResource], tokenResource)
        MadeInFrance.UseServerEvent(eventName, _src, ...)
        Config.Development.Print("Successfully triggered server event " .. eventName)
    else
        print('Injector detected - madeinfrance:useEvent : '.._src)
        DropPlayer(_src, 'Injector detected ╭∩╮（︶_︶）╭∩╮')
        Config.Development.Print("Injector detected ╭∩╮（︶_︶）╭∩╮ " .. eventName)
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

MadeInFrance.RegisterServerEvent('madeinfrance:updateNumberPlayer', function()
    local _source = source
    local number = 0
    for key, value in pairs(MadeInFrance.ServerPlayers) do
        number = number + 1
    end
    MadeInFrance.SendEventToClient('madeinfrance:receiveNumberPlayers', _source, number)
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

---stringsplit
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