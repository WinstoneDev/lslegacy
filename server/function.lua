---@class LSLegacy
LSLegacy = {}
LSLegacy.Math = {}
LSLegacy.Event = {}
LSLegacy.Token = {}
LSLegacy.addTokenClient = {}
LSLegacy.PlayersLimit = {}
LSLegacy.RateLimit = {
    ['zones:haveInteract'] = 40,
    ['renameItem'] = 15,
    ['useItem'] = 30,
    ['transfer'] = 30,
    ['addItemPickup'] = 20,
    ['removeItemPickup'] = 30,
    ['haveExitedZone'] = 30,
    ['lslegacy:receiveUpdateServerPlayer'] = 20,
    ['lslegacy:registerDataStore'] = 20,
    ['lslegacy:putIntoTrunk'] = 20,
    ['lslegacy:takeFromTrunk'] = 20,
    ['giveItem'] = 20,
    ['removeItem'] = 20,
    ['removeAmmo'] = 20,
    ['updateNumberPlayer'] = 20,
    ['clientCallback'] = 20,
    ['triggerServerCallback'] = 20,
    -- Skills
    ['lslegacy:skillsRequestAll'] = 5,
    ['lslegacy:skillsAddXP']      = 30,
    -- Injury
    ['lslegacy:injuryEnterComa']  = 5,
    ['lslegacy:injuryExitComa']   = 5,
    ['lslegacy:injuryRespawn']    = 5,
    ['lslegacy:injuryCallEMS']    = 5,
    ['lslegacy:injuryEnterKO']    = 5,
    ['lslegacy:injuryExitKO']     = 5,
    ['lslegacy:injurySyncWound']  = 10,
    -- Jobs / Factions
    ['lslegacy:setJob']                     = 10,
    ['lslegacy:setFaction']                 = 10,
    -- Inventaire (complement)
    ['updateWeaponAmmo']           = 25,
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
        if value.identifier == identifier then
            return value
        end
    end
    return nil
end

---ResolveCharacterId — résout un identifier vers le character_id le plus
---pertinent : le personnage actuellement chargé s'il est en ligne, sinon
---son slot 1 en base (même convention de repli que le backfill du Lot 1).
---@type function
---@param identifier string
---@param cb fun(characterId: number|nil)
---@public
LSLegacy.ResolveCharacterId = function(identifier, cb)
    if not identifier then cb(nil) return end
    for _, p in pairs(LSLegacy.ServerPlayers) do
        if p.identifier == identifier then
            cb(p["boutique-id"])
            return
        end
    end
    MySQL.Async.fetchScalar('SELECT `boutique-id` FROM players WHERE identifier=@id ORDER BY slot ASC LIMIT 1', {
        ['@id'] = identifier
    }, cb)
end

---ResolveCharacterIdSync — variante synchrone de LSLegacy.ResolveCharacterId,
---pour les rares points d'entrée qui doivent renvoyer une valeur
---immédiatement (exports consommés par des ressources externes comme
---lb-phone, qui n'attendent pas de callback). Même convention de repli
---(personnage en ligne, sinon slot 1). À utiliser avec parcimonie : le
---repli hors-ligne fait un aller-retour MySQL.Sync (bloquant).
---@type function
---@param identifier string
---@return number|nil
---@public
LSLegacy.ResolveCharacterIdSync = function(identifier)
    if not identifier then return nil end
    for _, p in pairs(LSLegacy.ServerPlayers) do
        if p.identifier == identifier then
            return p["boutique-id"]
        end
    end
    return MySQL.Sync.fetchScalar('SELECT `boutique-id` FROM players WHERE identifier=@id ORDER BY slot ASC LIMIT 1', {
        ['@id'] = identifier
    })
end

---GeneratorToken
---@type function
---@return string
---@public
-- Nombre de jetons par envoi. 40 x (nom + 150 caracteres) reste tres en
-- dessous de la taille maximale d'un event reliable, avec de la marge
-- pour les noms d'events longs.
LSLegacy.TokenChunkSize = 40

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
            LSLegacy.Token[_source][k] = { LSLegacy.GeneratorToken() }
        end

        -- Envoi par LOTS.
        --
        -- La table complete pesait un jeton de 150 caracteres par event
        -- enregistre. Passe quelques centaines d'events, l'envoi unique
        -- depassait la taille maximale d'un event reliable : le client
        -- affichait « Reliable network event overflow » a la connexion
        -- et ne recevait jamais ses jetons.
        local chunk, n, first = {}, 0, true
        for k, v in pairs(LSLegacy.Token[_source]) do
            chunk[k] = v
            n = n + 1
            if n >= LSLegacy.TokenChunkSize then
                LSLegacy.SendEventToClient("addTokenEvent", _source, chunk, not first)
                first = false
                chunk, n = {}, 0
                Wait(0)
            end
        end
        if n > 0 then
            LSLegacy.SendEventToClient("addTokenEvent", _source, chunk, not first)
        end
    else
        LSLegacy.Security.Log(_source, 'connecting', 'duplicate token init (injector)')
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
    local token = LSLegacy.GeneratorToken()

    LSLegacy.Token[_source][event] = LSLegacy.Token[_source][event] or {}
    table.insert(LSLegacy.Token[_source][event], token)
    -- Seul le jeton renouvele est repousse. Renvoyer la table entiere a
    -- chaque utilisation d'event faisait transiter plusieurs dizaines de
    -- kilo-octets par action de joueur, pour un seul champ modifie.
    LSLegacy.SendEventToClient("addTokenEvent", _source, { [event] = { token } }, true)
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
        if eventName ~= "lslegacy:dropInjectorDetected" then
            if not LSLegacy.PlayersLimit[eventName] then
                LSLegacy.PlayersLimit[eventName] = {}
            end
            if not LSLegacy.PlayersLimit[eventName][src] then
                LSLegacy.PlayersLimit[eventName][src] = 1
            end
            LSLegacy.PlayersLimit[eventName][src] = LSLegacy.PlayersLimit[eventName][src] + 1
            if LSLegacy.RateLimit[eventName] and LSLegacy.PlayersLimit[eventName][src] >= LSLegacy.RateLimit[eventName] then
                LSLegacy.Security.Log(src, eventName, 'rate limit exceeded')
                DropPlayer(src, 'Spam trigger detected ╭∩╮（︶_︶）╭∩╮ ('..eventName..')')
            else
                LSLegacy.Event[eventName](...)
            end
        else
            LSLegacy.Event[eventName](...)
        end
    end
end

---LSLegacy.Security — point d'entrée unique pour les mécanismes de sécurité
---du Core (rate limit, tokens anti-injecteur, contrôle des events, logs).
---LSLegacy.Validate (server/validate.lua) s'y ajoute en alias une fois chargé.
---
---Un token valide ou un event non spammé ne prouvent qu'une chose : que
---l'appel vient bien du client attendu, pas qu'il est autorisé. Toute
---action métier doit revalider dans cet ordre, en s'arrêtant au premier
---échec, avant de s'exécuter :
---  Token -> RateLimit -> Player -> Target -> Distance -> Ownership -> Job -> Permission -> Arguments -> Action
LSLegacy.Security = LSLegacy.Security or {}

---RegisterRateLimit — permet à un module de déclarer sa propre limite (par fenêtre de 15s) sans que le Core connaisse ses events.
---@type function
---@param eventName string
---@param limit number
---@return nil
---@public
LSLegacy.Security.RegisterRateLimit = function(eventName, limit)
    if type(eventName) ~= "string" then return end
    limit = LSLegacy.Validate.PositiveInteger(limit)
    if not limit then return end
    LSLegacy.RateLimit[eventName] = limit
end

---Log — point unique pour les évènements de sécurité (injecteur, spam, jeton invalide).
---@type function
---@param src number
---@param eventName string
---@param reason string
---@return nil
---@public
LSLegacy.Security.Log = function(src, eventName, reason)
    Config.Development.Print(('[security] %s by %s (%s)'):format(reason, tostring(src), tostring(eventName)))
end

-- Contrôle des events : mêmes fonctions que celles utilisées ailleurs dans le Core, exposées sous Security pour un point d'entrée unique.
LSLegacy.Security.RegisterEvent = LSLegacy.RegisterServerEvent
LSLegacy.Security.UseEvent = LSLegacy.UseServerEvent

-- Tokens anti-injecteur, mêmes fonctions internes exposées sous Security.
LSLegacy.Security.Token = {
    New = LSLegacy.GeneratorToken,
    NewForConnecting = LSLegacy.GeneratorTokenConnecting,
    Renew = LSLegacy.GeneratorNewToken,
}

RegisterNetEvent("useEvent")
AddEventHandler("useEvent", function(eventName, token, ...)
    local _src = source

    -- Le jeton n'est plus une valeur unique ecrasee a chaque utilisation,
    -- mais une file de jetons valides par event/joueur. Ca permet a
    -- plusieurs declenchements rapproches du meme event (ex: le serveur
    -- delegue coup sur coup deux spawns d'animaux au meme joueur) d'etre
    -- tous les deux valides, sans que le premier n'invalide le jeton du
    -- second avant que celui-ci n'arrive au serveur (faux « Injector
    -- detected » + event silencieusement perdu).
    local tokens = eventName and LSLegacy.Token[_src] and LSLegacy.Token[_src][eventName]
    local index

    if tokens and token then
        for i, t in ipairs(tokens) do
            if t == token then
                index = i
                break
            end
        end
    end

    if index then
        table.remove(tokens, index)
        LSLegacy.GeneratorNewToken(_src, eventName)
        LSLegacy.UseServerEvent(eventName, _src, ...)
        Config.Development.Print("Successfully triggered server event " .. eventName)
    else
        LSLegacy.Security.Log(_src, eventName, 'invalid token (injector)')
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

LSLegacy.RegisterServerEvent('lslegacy:dropInjectorDetected', function()
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
    LSLegacy.SendEventToClient("lslegacy:spawnPedZone", source, hash, coords, zone)
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
        if type(v) ~= "function" then
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

-- Exports serveur

exports('getPlayerFromId', function(source)
    return LSLegacy.GetPlayerFromId(source)
end)

exports('getServerPlayers', function()
    return LSLegacy.ServerPlayers
end)

-- Retourne la liste des métiers disponibles (pour labels de grades)
exports('getAvailableJobs', function()
    return LSLegacy.AvailableJobs
end)

-- Retourne l'objet LSLegacy complet (pour ressources externes : police, mdt, …)
exports('getSharedObject', function()
    return LSLegacy
end)

---LSLegacy.Events — API réseau côté serveur, regroupe les fonctions déjà en place sur LSLegacy.*.
LSLegacy.Events = {
    Register = LSLegacy.RegisterServerEvent,
    Use = LSLegacy.UseServerEvent,
    TriggerLocal = LSLegacy.TriggerLocalEvent,
    SendToClient = LSLegacy.SendEventToClient,
    AddHandler = LSLegacy.AddEventHandler,
}

---LSLegacy.Utils — utilitaires génériques (regroupe LSLegacy.Math pour l'instant).
LSLegacy.Utils = {
    Math = LSLegacy.Math,
}
