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
    ['lslegacy:requestBankBalance'] = 20,
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
    ['ap:requestVehicleDeletion'] = 20,
    ['clientCallback'] = 20,
    ['triggerServerCallback'] = 20,
    ['clothshop:createOutfit'] = 20,
    ['clothshop:splitOutfit'] = 20,
    ['clothshop:modifyOutfit'] = 20,
    ['inventory:updateOutfitFromInventory'] = 20,
    -- Admin
    ['admin:tpm'] = 30,
    ['admin:pos'] = 30,
    ['admin:freeze'] = 10,
    ['admin:heal'] = 10,
    ['admin:revive'] = 10,
    ['admin:resetNeeds'] = 10,
    ['admin:resetSkin'] = 5,
    ['admin:kick'] = 5,
    ['admin:tempban'] = 5,
    ['admin:permaban'] = 3,
    ['admin:warn'] = 10,
    ['admin:getWarns'] = 15,
    ['admin:screenshot'] = 5,
    ['admin:repairVehicle'] = 10,
    ['admin:deletePlayerVehicle'] = 10,
    ['admin:spawnVehicleForPlayer'] = 8,
    ['admin:spawnVehicle'] = 8,
    ['admin:deleteVehiclesInZone'] = 8,
    ['admin:giveMoney'] = 10,
    ['admin:removeMoney'] = 10,
    ['admin:giveItem'] = 10,
    ['admin:removeItem'] = 10,
    ['admin:giveWeapon'] = 10,
    ['admin:getPlayerInventory'] = 15,
    ['admin:getTickets'] = 15,
    ['admin:takeTicket'] = 10,
    ['admin:closeTicket'] = 10,
    ['admin:createTicket'] = 8,
    ['admin:tpToTicket'] = 10,
    ['admin:bringTicketPlayer'] = 10,
    ['admin:setGodmode'] = 10,
    ['admin:cleanVehicleDB'] = 10,
    ['admin:deleteWarn'] = 10,
    ['admin:multichar:returnToSelection'] = 5,
    ['admin:logIdentifiers'] = 5,
    ['admin:getTicketStats'] = 20,
    ['admin:setWorldTime'] = 15,
    -- Handbrake
    ['handbrake:broadcastSound'] = 30,
    -- Skills
    ['LSLegacy:skills:requestAll'] = 5,
    ['LSLegacy:skills:addXP']      = 30,
    -- Injury
    ['LSLegacy:injury:enterComa']  = 5,
    ['LSLegacy:injury:exitComa']   = 5,
    ['LSLegacy:injury:respawn']    = 5,
    ['LSLegacy:injury:callEMS']    = 5,
    ['LSLegacy:injury:enterKO']    = 5,
    ['LSLegacy:injury:exitKO']     = 5,
    -- MDT (lectures : dispatcher unique)
    ['mdt:query']                  = 80,
    -- MDT (écritures)
    ['mdt:createFine']             = 20,
    ['mdt:toggleFinePaid']         = 25,
    ['mdt:deleteFine']             = 15,
    ['mdt:addCriminalRecord']      = 20,
    ['mdt:deleteCriminalRecord']   = 15,
    ['mdt:createReport']           = 20,
    ['mdt:updateReport']           = 25,
    ['mdt:deleteReport']           = 15,
    ['mdt:createInterventionReport'] = 20,
    ['mdt:updateInterventionReport'] = 25,
    ['mdt:deleteInterventionReport'] = 15,
    ['mdt:linkCaseItem']           = 25,
    ['mdt:unlinkCaseItem']         = 25,
    ['mdt:linkReportItem']         = 25,
    ['mdt:unlinkReportItem']       = 25,
    ['mdt:setVehicleWanted']       = 20,
    ['mdt:setVehicleLocation']     = 20,
    ['mdt:createWarrant']          = 20,
    ['mdt:updateWarrant']          = 20,
    ['mdt:deleteWarrant']          = 15,
    ['mdt:createCustody']          = 20,
    ['mdt:addEvidence']            = 20,
    ['mdt:registerWeapon']         = 20,
    ['mdt:updateWeapon']           = 20,
    ['mdt:deleteWeapon']           = 15,
    ['mdt:seizeWeapon']            = 20,
    ['mdt:linkWeaponPerson']       = 25,
    ['mdt:unlinkWeaponPerson']     = 25,
    ['mdt:linkWeaponReport']       = 25,
    ['mdt:unlinkWeaponReport']     = 25,
    ['mdt:createLaw']              = 20,
    ['mdt:updateLaw']              = 20,
    ['mdt:deleteLaw']              = 15,
    ['mdt:createTraining']         = 20,
    ['mdt:updateTraining']         = 20,
    ['mdt:deleteTraining']         = 15,
    ['mdt:signupTraining']         = 25,
    ['mdt:unsignupTraining']       = 25,
    ['mdt:removeSignup']           = 25,
    ['mdt:deleteCustody']          = 15,
    ['mdt:linkPersonWeapon']       = 25,
    ['mdt:validateSignup']         = 25,
    ['mdt:updateEvidence']         = 25,
    ['mdt:linkReportEvidence']     = 25,
    ['mdt:unlinkReportEvidence']   = 25,
    ['mdt:saveAgentMeta']          = 20,
    ['mdt:saveCareer']             = 20,
    ['mdt:addAssignment']          = 25,
    ['mdt:updateAssignment']       = 25,
    ['mdt:deleteAssignment']       = 20,
    ['mdt:addCommendation']        = 20,
    ['mdt:deleteCommendation']     = 20,
    ['mdt:addSkill']               = 20,
    ['mdt:deleteSkill']            = 20,
    ['mdt:updateSkillDate']        = 20,
    -- Police Nationale — service
    ['police:onDuty']              = 10,
    ['police:offDuty']             = 10,
    ['gendarmerie:onDuty']         = 10,
    ['gendarmerie:offDuty']        = 10,
    ['police:spawnVehicle']        = 15,
    -- Police Nationale — actions
    ['police:cuff']                = 20,
    ['police:search']              = 15,
    ['police:palpation']           = 20,
    ['police:idCheck']             = 20,
    ['police:licenseCheck']        = 20,
    ['police:escort']              = 20,
    ['police:putInVehicle']        = 20,
    ['police:getOutVehicle']       = 20,
    ['police:seizeItem']           = 15,
    -- Police Nationale — judiciaire
    ['police:custody']             = 10,
    ['police:prison']              = 10,
    -- Police Nationale — investigation
    ['police:inv:collectFingerprints'] = 15,
    ['police:inv:collectDNA']      = 15,
    ['police:inv:collectBlood']    = 15,
    ['police:inv:createScene']     = 10,
    ['police:inv:compareFingerprints'] = 20,
    ['police:inv:compareDNA']      = 20,
    -- Police Nationale — radio (voix via pma-voice ; seul le tracking canal passe par le serveur)
    ['police:radio:join']          = 20,
    ['police:radio:leave']         = 20,
    -- Police Nationale — missions
    ['police:mission:accept']      = 10,
    ['police:mission:resolve']     = 10,
    -- Fourrière
    ['fourriere:impound']            = 15,
    ['fourriere:requestList']        = 15,
    ['fourriere:retrieve']           = 10,
    ['fourriere:persistDelivered']   = 15,
    -- Concessionnaire
    ['concessionnaire:buy']          = 10,
    ['concessionnaire:sell']         = 10,
    ['concessionnaire:getOccasions'] = 15,
    ['concessionnaire:buyOccasion']  = 10,
    ['concessionnaire:persistDelivered'] = 10,
    -- Injury (complement)
    ['LSLegacy:injury:syncWound']  = 10,
    -- Jobs / Factions
    ['SetJob']                     = 10,
    ['SetFaction']                 = 10,
    -- Inventaire (complement)
    ['updateWeaponAmmo']           = 25,
    -- Farm
    ['farm:animalSpawned']         = 20,
    ['farm:requestGather']         = 20,
    ['farm:completeGather']        = 20,
    ['farm:requestPoach']          = 20,
    ['farm:requestProcess']        = 20,
    ['farm:completeProcess']       = 20,
    ['farm:sellProcessed']         = 15,
    ['farm:sellPoaching']          = 15,
    ['farm:compactStones']         = 15,
    ['farm:requestShopStock']      = 20,
    ['farm:buyShopItem']           = 15,
    -- Interim
    ['interim:startDuty']          = 10,
    ['interim:endDuty']            = 10,
    ['interim:rigSpawned']         = 15,
    ['interim:trailerAttached']    = 15,
    ['interim:trailerDetached']    = 15,
    ['interim:requestFillTank']    = 20,
    ['interim:stationFillComplete'] = 15,
    -- LTD (superette)
    ['ltd:onDuty']                 = 10,
    ['ltd:offDuty']                = 10,
    ['ltd:requestShelfStock']      = 20,
    ['ltd:requestReserveStock']    = 20,
    ['ltd:sellItem']               = 20,
    ['ltd:restockShelf']           = 15,
    ['ltd:fillReserve']            = 15,
    ['ltd:triggerAlarm']           = 10,
    ['ltd:stealItem']              = 15,
    -- Atelier (remplace mecanicien:*, module multi-entreprises)
    ['atelier:onDuty']          = 10,
    ['atelier:offDuty']         = 10,
    ['atelier:spawnVehicle']    = 15,
    ['atelier:requestDiagnostic'] = 20,
    ['atelier:requestStock']    = 20,
    ['atelier:takePart']        = 15,
    ['atelier:dropPart']        = 20,
    ['atelier:restockStock']    = 15,
    ['atelier:repairComponent'] = 15,
    ['atelier:requestInvoice']  = 15,
    ['atelier:finalizeInvoice'] = 10,
    -- Pompe a essence
    ['pompe:requestFill']          = 20,
    ['pompe:payFuel']              = 15,
    -- Pompiers (SDIS)
    ['pompiers:onDuty']            = 10,
    ['pompiers:offDuty']           = 10,
    ['pompiers:spawnVehicle']      = 15,
    ['pompiers:rescue']            = 15,
    -- SAMU
    ['samu:onDuty']                = 10,
    ['samu:offDuty']               = 10,
    ['samu:spawnVehicle']          = 15,
    ['samu:restock']               = 15,
    ['samu:revive']                = 15,
    -- SAMU — Health Inspection
    ['samu:hi:open']               = 15,
    ['samu:hi:useItem']            = 20,
    ['samu:hi:poll']               = 40,
    ['samu:hi:damage']             = 40,
    -- MDT medical (SAMU)
    ['mdtmed:query']               = 40,
    ['mdtmed:saveRecord']          = 20,
    ['mdtmed:addEntry']            = 20,
    ['mdtmed:deleteEntry']         = 15,
    ['mdtmed:addTreatment']        = 20,
    ['mdtmed:setTreatmentStatus']  = 25,
    ['mdtmed:assignCall']          = 20,
    ['mdtmed:closeCall']           = 20,
    ['mdtmed:saveDoc']             = 15,
    ['mdtmed:deleteDoc']           = 15,
    ['mdtmed:postBoard']           = 15,
    ['mdtmed:removeBoard']         = 15,
    -- MDT co-pilote (dispatcher callouts)
    ['mdtco:query']                = 40,
    -- Police Nationale (complement)
    ['police:cuffStart']           = 20,
    -- Police Nationale — callouts
    ['police:callouts:askCrews']         = 15,
    ['police:callouts:register']         = 10,
    ['police:callouts:accept']           = 10,
    ['police:callouts:reposition']       = 40,
    ['police:callouts:corpseVisible']    = 20,
    ['police:callouts:reportStreet']     = 15,
    ['police:callouts:refuse']           = 10,
    ['police:callouts:leave']            = 15,
    ['police:callouts:requestBackup']    = 10,
    ['police:callouts:acceptBackup']     = 15,
    ['police:callouts:setStatus']        = 30,
    ['police:callouts:suspectStunned']   = 20,
    ['police:callouts:suspectCuffed']    = 20,
    ['police:callouts:suspectIdentify']  = 20,
    ['police:callouts:moveAlong']        = 20,
    ['police:callouts:victimStatement']  = 15,
    ['police:callouts:interrogate']      = 15,
    ['police:callouts:suspectSearched']  = 20,
    ['police:callouts:suspectDropWeapon'] = 20,
    ['police:callouts:pickupWeapon']     = 20,
    ['police:callouts:suspectDead']      = 15,
    ['police:callouts:suspectCombat']    = 30,
    ['police:callouts:suspectSurrender'] = 20,
    ['police:callouts:suspectEscaped']   = 15,
    ['police:callouts:suspectDelivered'] = 15,
    ['police:callouts:ambulanceLoaded']  = 15,
    ['police:callouts:objectiveDone']    = 20,
    ['police:callouts:firstAid']         = 15,
    ['police:callouts:askRadioOff']      = 15,
    ['police:callouts:radioOff']         = 15,
    ['police:callouts:dismissBystander'] = 15,
    ['police:callouts:reportHour']       = 10,
    ['police:callouts:askAdmin']         = 10,
    ['police:callouts:command']          = 15,
    ['police:callouts:spawnFail']        = 10,
    ['police:callouts:reportSpawn']      = 15,
    ['police:callouts:reportLocation']   = 30,
    ['police:callouts:reportMismatch']   = 15,
    ['police:callouts:anchorSurvey']     = 10,
    ['police:callouts:anchorHere']       = 10,
    ['police:callouts:anchorUndo']       = 10,
    ['police:callouts:adminAction']      = 10,

    ['lslegacy_emotes:requestShared'] = 20,
    ['lslegacy_emotes:confirmShared'] = 20,
    ['lslegacy_emotes:cancelShared']  = 30,
    ['lslegacy_emotes:getFavorites']  = 10,
    ['lslegacy_emotes:toggleFavorite'] = 30,

    ['weather:requestClockSync'] = 50
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
        if eventName ~= "DropInjectorDetected" then
            if not LSLegacy.PlayersLimit[eventName] then
                LSLegacy.PlayersLimit[eventName] = {}
            end
            if not LSLegacy.PlayersLimit[eventName][src] then
                LSLegacy.PlayersLimit[eventName][src] = 1
            end
            LSLegacy.PlayersLimit[eventName][src] = LSLegacy.PlayersLimit[eventName][src] + 1
            if LSLegacy.RateLimit[eventName] and LSLegacy.PlayersLimit[eventName][src] >= LSLegacy.RateLimit[eventName] then
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
