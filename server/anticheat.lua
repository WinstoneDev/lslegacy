local ResourceMetadata = {}
local passWordNeeded = false
local ServerPassword = GetConvar('lslegacy_anticheat_password', '')

---BanPlayer
---@type function
---@param player table
---@param time number
---@param reason string
---@return void
---@public
Shared.Anticheat.BanPlayer = function(player, time, reason, source)
    local moderator = LSLegacy.GetPlayerFromId(source) or {}
    if source == 0 then
        moderator.name = "Anticheat"
    end
    if tonumber(time) then
        if player then
            local CountHour = time
            local ids = Shared.Anticheat.ExtractIdentifiersBan(player.source)
            local license = ids.license
            local identifier = ids.steam
            local live = ids.live
            local xbl = ids.xbl
            local discord = ids.discord
            local ip = ids.ip
            local date = {
                year = os.date("*t").year, month = os.date("*t").month, day = os.date("*t").day, hour = os.date("*t").hour, min = os.date("*t").min, sec = os.date("*t").sec
            }

            if license == nil then
                license = 'Aucun'
            end
            if identifier == nil then
                identifier = 'Aucun'
            end
            if live == nil then
                live = 'Aucun'
            end
            if xbl == nil then
                xbl = 'Aucun'
            end
            if discord == nil then
                discord = 'Aucun'
            end
            if ip == nil then
                ip = 'Aucun'
            end

            if tonumber(CountHour) == 0 then
                MySQL.Async.execute('INSERT INTO banlist (token, license, identifier, liveid, xbox, discord, ip, moderator, reason, expiration, hourban, permanent) VALUES (@token, @license, @identifier, @liveid, @xbox, @discord, @ip, @moderator, @reason, @expiration, @hourban, @permanent)', {
                    ['@token'] = GetPlayerToken(player.source),
                    ['@license'] = license, 
                    ['@identifier'] = identifier, 
                    ['@liveid'] = live, 
                    ['@xbox'] = xbl, 
                    ['@discord'] = discord, 
                    ['@ip'] = ip, 
                    ['@moderator'] = moderator.name,
                    ['@reason'] = reason,
                    ['@expiration'] = json.encode(date),
                    ['@hourban'] = 999000,
                    ['@permanent'] = 1
                })
                Wait(1000)
                MySQL.Async.fetchAll('SELECT * FROM banlist WHERE license = @license', {
                    ['@license'] = license
                }, function(result)
                    table.insert(Shared.Anticheat.BanList, {
                        idban      = result[1].idban or "Aucun",
                        token      = GetPlayerToken(player.source),
                        license    = license,
                        steam      = identifier,
                        live       = live,
                        xbl        = xbl,
                        discord    = discord,
                        ip         = ip,
                        moderator  = moderator.name or "Inconnu",
                        reason     = reason,
                        expiration = json.encode(date),
                        hourban    = 999000,
                        permanent  = 1
                    })
                    DropPlayer(player.source, "Vous êtes ban de LSLegacy\nRaison : "..reason.."\nID Bannissement : "..result[1].idban)
                end)
            else
                MySQL.Async.execute('INSERT INTO banlist (token, license, identifier, liveid, xbox, discord, ip, moderator, reason, expiration, hourban) VALUES (@token, @license, @identifier, @liveid, @xbox, @discord, @ip, @moderator, @reason, @expiration, @hourban)', {
                    ['@token'] = GetPlayerToken(player.source),
                    ['@license'] = license, 
                    ['@identifier'] = identifier,
                    ['@liveid'] = live,
                    ['@xbox'] = xbl, 
                    ['@discord'] = discord,
                    ['@ip'] = ip, 
                    ['@moderator'] = moderator.name,
                    ['@reason'] = reason,
                    ['@expiration'] = json.encode(date),
                    ['@hourban'] = CountHour
                })
                Wait(1000)
                MySQL.Async.fetchAll('SELECT * FROM banlist WHERE license = @license', {
                    ['@license'] = license
                }, function(result)
                    table.insert(Shared.Anticheat.BanList, {
                        idban      = result[1].idban or "Aucun",
                        token      = GetPlayerToken(player.source),
                        license    = license,
                        steam      = identifier,
                        live       = live,
                        xbl        = xbl,
                        discord    = discord,
                        ip         = ip,
                        moderator  = moderator.name,
                        reason     = reason,
                        expiration = json.encode(date),
                        hourban    = CountHour,
                        permanent  = 0
                    })
                    DropPlayer(player.source, "Vous êtes ban de LSLegacy\nRaison : "..reason.."\nID Bannissement : "..result[1].idban)
                end)
            end
        end
    end
end

Shared.Anticheat.BanList = {}
Shared.Anticheat.BanListActualize = {}

---ExtractIdentifiersBan
---@type function
---@param src number
---@return string
---@public
Shared.Anticheat.ExtractIdentifiersBan = function(src)
    local identifiers = {
        steam = nil,
        ip = nil,
        discord = nil,
        license = nil,
        xbl = nil,
        live = nil,
    }
    
    for k, v in pairs(GetPlayerIdentifiers(src)) do 
        if string.sub(v, 1, string.len("steam:")) == "steam:" then
            identifiers.steam = v
        elseif string.sub(v, 1, string.len("license:")) == "license:" then
            identifiers.license = v
        elseif string.sub(v, 1, string.len("xbl:")) == "xbl:" then
            identifiers.xbl  = v
        elseif string.sub(v, 1, string.len("ip:")) == "ip:" then
            identifiers.ip = v
        elseif string.sub(v, 1, string.len("discord:")) == "discord:" then
            identifiers.discord = v
        elseif string.sub(v, 1, string.len("live:")) == "live:" then
            identifiers.live = v
        end
    end

    return identifiers
end

MySQL.ready(function()
    Shared.Anticheat.ReloadFromDatabase()
end)

---ReloadFromDatabase
---@type function
---@public
Shared.Anticheat.ReloadFromDatabase = function()
    MySQL.Async.fetchAll('SELECT * FROM banlist', {}, function(result)
		if result then
		    Shared.Anticheat.BanList = {}
		    for i = 1, #result, 1 do
                table.insert(Shared.Anticheat.BanList, {
                    idban      = result[i].idban or "Aucun",
                    token      = result[i].token or "Aucun",
                    license    = result[i].license or "Aucun",
                    steam      = result[i].identifier or "Aucun",
                    live       = result[i].liveid or "Aucun",
                    xbl        = result[i].xbox or "Aucun",
                    discord    = result[i].discord or "Aucun",
                    ip         = result[i].ip or "Aucun",
                    moderator  = result[i].moderator or "Aucun",
                    reason     = result[i].reason or "Aucun",
                    expiration = result[i].expiration or "Aucun",
                    hourban    = result[i].hourban or "Aucun",
                    permanent  = result[i].permanent or "Aucun",
                })
		    end
            Config.Development.Print("Actualise Banlist")
		end
	end)
end

---AfficheBan
---@type function
---@param raison string
---@param idban number
---@param dateunban string
---@return table
---@public
Shared.Anticheat.AfficheBan = function(raison, idban, dateunban)
    card = DeferralCards.Card:Create({
        body = {
            DeferralCards.Container:Create({
                items = {
                    DeferralCards.CardElement:Image({
                        url = 'https://i.postimg.cc/pd29WJ1M/MIF-ASE.png',
                        size = 'large',
                        horizontalAlignment = 'center'
                    }),
                    DeferralCards.CardElement:TextBlock({
                        text = "Vous êtes banni du serveur.",
                        weight = 'Light',
                        size = 'large',
                        horizontalAlignment = 'left'
                    }),
                    DeferralCards.CardElement:TextBlock({
                        text = "Raison : "..raison,
                        weight = 'Light',
                        size = 'large',
                        horizontalAlignment = 'left'
                    }),
                    DeferralCards.CardElement:TextBlock({
                        text = "ID Banissement : "..idban,
                        weight = 'Light',
                        size = 'large',
                        horizontalAlignment = 'left'
                    }),
                    DeferralCards.CardElement:TextBlock({
                        text = "Date unban : "..dateunban,
                        weight = 'Light',
                        size = 'large',
                        horizontalAlignment = 'left'
                    }),
                    DeferralCards.CardElement:TextBlock({
                        text = "discord.gg/xemBfKDQKf",
                        weight = 'Light',
                        size = 'large',
                        horizontalAlignment = 'left'
                    })
                },
                isVisible = true
            })
        }
    })
    return card
end

Shared.Anticheat.Unban = function(id)
    MySQL.Async.execute("DELETE FROM `banlist` WHERE `idban` = @idban", {
        ["@idban"] = id,
    }, function(affectedRows)
        if affectedRows > 0 then
            for k, v in pairs(Shared.Anticheat.BanList) do
                if v.idban == id then
                    table.remove(Shared.Anticheat.BanList, k)
                    Config.Development.Print("Suppression du ban numéro : " .. id)
                    break
                end
            end
        else
            Config.Development.Print("Aucun ban trouvé avec l'ID : " .. id)
        end
    end)
end

LSLegacy.AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
    local _src = source
    playerBanned = false
    local ids = Shared.Anticheat.ExtractIdentifiersBan(_src)
    local ping = GetPlayerPing(_src)
    local token = GetPlayerToken(_src)
    local steam = ids.steam
    local ip = ids.ip
    local discord = ids.discord
    local license = ids.license
    local xbl = ids.xbl
    local live = ids.live
    print("Une connexion est en cours "..GetPlayerName(_src))

    deferrals.defer()

    if not license or license == '' then
        return deferrals.done("Votre license rockstar est introuvable.")
    end

    if not discord or discord == '' then
        return deferrals.done("Votre discord est introuvable.")
    end

    if not steam or steam == '' then
        return deferrals.done("Votre steam est introuvable.")
    end

    if json.encode(Shared.Anticheat.BanList) ~= "[]" then
        for k, v in pairs(Shared.Anticheat.BanList) do
            if tostring(v.token) == token or tostring(v.steam) == tostring(steam) or tostring(v.ip) == tostring(ip) or tostring(v.discord) == tostring(discord) or tostring(v.license) == tostring(license) or tostring(v.xbl) == tostring(xbl) or tostring(v.live) == tostring(live) then
                reason = v.reason
                idban = v.idban
                expiration = json.decode(v.expiration)
                hourban = v.hourban
                permanent = v.permanent

                if permanent == 1 then
                    playerBanned = true
                    Citizen.CreateThread(function()
                        while true do
                            local card = Shared.Anticheat.AfficheBan(reason, idban, "Permanent")
                            deferrals.presentCard(card)
                            Wait(1000)
                        end
                    end)
                else 
                    local difftime = os.difftime(os.time(), os.time{year = expiration.year, month = expiration.month, day = expiration.day, hour = expiration.hour, min = expiration.min, sec = expiration.sec}) / 3600
                    if (hourban - math.floor(difftime)) <= 0 then
                        deferrals.done()
                        table.remove(Shared.Anticheat.BanList, k)
                        MySQL.Async.execute("DELETE FROM `banlist` WHERE `idban` = @idban", {["@idban"] = idban})
                    else
                        local endtime = os.time({year = expiration.year, month = expiration.month, day = expiration.day, hour = expiration.hour + hourban, min = expiration.min, sec = expiration.sec})
                        playerBanned = true
                        Citizen.CreateThread(function()
                            while true do
                                local card = Shared.Anticheat.AfficheBan(reason, idban, os.date("%d-%m-%Y %H:%M", endtime))
                                deferrals.presentCard(card)
                                Wait(1000)
                            end
                        end)
                    end
                end
            end
        end
    end

    if not playerBanned then
        if passWordNeeded then
            Citizen.CreateThread(function()
                local validated = false

                while not validated do
                    local card = DeferralCards.Card:Create({
                        body = {
                            DeferralCards.Container:Create({
                                items = {
                                    DeferralCards.CardElement:TextBlock({
                                        text = "Mot de passe requis pour rejoindre le serveur.",
                                        weight = 'Bolder',
                                        size = 'Large',
                                        horizontalAlignment = 'center'
                                    }),
                                    DeferralCards.Input:Text({
                                        id = "password",
                                        placeholder = "Entrez le mot de passe..."
                                    }),
                                    DeferralCards.Container:ActionSet({
                                        actions = {
                                            DeferralCards.Action:Submit({
                                                title = "Valider",
                                                data = { action = "check_password" }
                                            })
                                        }
                                    })
                                }
                            })
                        }
                    })

                    deferrals.presentCard(card, function(data, rawData)
                        if data.action == "check_password" then
                            if data.password and data.password == ServerPassword then
                                validated = true
                                deferrals.done()
                            else
                                deferrals.done("Mot de passe incorrect. Merci de réessayer.")
                            end
                        end
                    end)

                    Wait(1000)
                end
            end)
        else
            deferrals.done()
        end
    end
end)

-- Whitelist auto : tout joueur dont le grade staff (Config.StaffGroups) est
-- supérieur à 2 ("mod") est exempté de l'anticheat.
function IsPlayerWhitelisted(playerId)
    local player = LSLegacy.GetPlayerFromId(playerId)
    return player.group >= 2
end

function sendwebhooktodc(content)
    local _source = source
    local connect = 
    {
        {
            ["color"] = "23295",
            ["title"] = "LSLegacy AntiCheat",
            ["description"] = "Joueur : "..GetPlayerName(_source).. " "  ..GetPlayerIdentifiers(_source)[1].."", content,
            ["footer"] = {
            ["text"] = "github.com/WinstoneDev/lslegacy",
            },
        }
    }
    PerformHttpRequest(Shared.Anticheat.WebhookDiscord, function(err, text, headers) end, 'POST', json.encode({username = "LSLegacy Anticheat", embeds = connect}), { ['Content-Type'] = 'application/json' })
end

-- kickorbancheater(source,"Content Text", "Info Text",kick,ban) c = Kick d = Ban
-- Example use: kickorbancheater(_src,"Weapon Explosion Detected", "This Player tried to change bullet type",true,true) 

function kickorbancheater(source,content,info,c,d)
    local _source = source
    local sname = GetPlayerName(_source)
    local steam = "unknown"
	local discord = "unknown"
	local license = "unknown"
	local live = "unknown"
	local xbl = "unknown"

    if IsPlayerWhitelisted(_source) then
        return
    end

	for m, n in ipairs(GetPlayerIdentifiers(_source)) do
	    if n:match("steam") then
	    	steam = n
	    elseif n:match("discord") then
	    	discord = n:gsub("discord:", "")
	    elseif n:match("license") then
	    	license = n
	    elseif n:match("live") then
	    	live = n
	    elseif n:match("xbl") then
	    	xbl = n
	    end
	end

    if IsPlayerWhitelisted(_source) then
        return
    end

    local discordinfo = {
        {
            ["color"] = "23295",
            ["title"] = "LSLegacy AntiCheat",
            ["description"] = "**Joueur : **"..sname.. "\n**ServerID :** ".._source.."\n**Violation :** "..content.."\n**Details :** "..info.."\n**Steam :** "..steam.."\n**License : **"..license.."\n**Xbl : **"..xbl.."\n**Live : **"..live.."\n**Discord**: <@"..discord..">",
            ["footer"] = {
            ["text"] = "github.com/WinstoneDev/lslegacy " ..os.date("%c").. "",
            },
        }
    }
    PerformHttpRequest(Shared.Anticheat.WebhookDiscord, function(err, text, headers) end, 'POST', json.encode({username = "LSLegacy Anticheat", embeds = discordinfo}), { ['Content-Type'] = 'application/json' })

    if d then
        if IsPlayerWhitelisted(_source) then
            return
        end
        Shared.Anticheat.BanPlayer(LSLegacy.GetPlayerFromId(_source), 0, content, 0)
    end

    if c then
        if IsPlayerWhitelisted(_source) then
            return
        end
        DropPlayer(source, "L'anticheat vous a kick")
    end
end


RegisterServerEvent("8jWpZudyvjkDXQ2RVXf9")
AddEventHandler("8jWpZudyvjkDXQ2RVXf9", function(type, item)
    local _type = type or "default"
    local _src = source
    local _item = item or "none"
    local _name = GetPlayerName(_src)
    _type = string.lower(_type)

        if (_type == "invisible") then
            kickorbancheater(_src,"Tentative d'invisibilité", "Ce joueur a tenté de devenir invisible",true,true)
        elseif (_type == "antiragdoll") then
            kickorbancheater(_src,"Anti-Ragdoll détecté", "Ce joueur a tenté d'activer l'Anti-Ragdoll",true,true)
        elseif (_type == "displayradar") then
            kickorbancheater(_src,"Radar détecté", "Ce joueur a tenté d'activer le radar",true,true)
        elseif (_type == "explosiveweapon") then
            kickorbancheater(_src,"Explosion d'arme détectée", "Ce joueur a tenté de changer le type de munitions",true,true)
        elseif (_type == "spectatormode") then
            kickorbancheater(_src,"Spectateur détecté", "Ce joueur a tenté d'espionner un autre joueur",true,true)
        elseif (_type == "speedhack") then
            kickorbancheater(_src,"SpeedHack détecté", "Ce joueur a tenté d'utiliser un SpeedHack",true,true)
        elseif (_type == "blacklistedweapons") then
            kickorbancheater(_src,"Arme blacklistée", "Ce joueur a tenté de faire apparaître une arme blacklistée",true,true)
        elseif (_type == "thermalvision") then
            kickorbancheater(_src,"Caméra thermique détectée", "Ce joueur a tenté d'utiliser une caméra thermique",true,true)
        elseif (_type == "nightvision") then
            kickorbancheater(_src,"Vision nocturne détectée", "Ce joueur a tenté d'utiliser la vision nocturne",true,true)
        elseif (_type == "antiresourcestop") then
            kickorbancheater(_src,"Ressource arrêtée", "Ce joueur a tenté d'arrêter/démarrer une ressource",true,true)
        elseif (_type == "pedchanged") then
            kickorbancheater(_src,"Ped changé", "Ce joueur a tenté de changer son PED",true,true)
        elseif (_type == "freecam") then
            kickorbancheater(_src,"FreeCam détectée", "Ce joueur a tenté d'utiliser une FreeCam (Fallout ou similaire)",true,true)
        elseif (_type == "infiniteammo") then
            kickorbancheater(_src,"Munitions infinies détectées", "Ce joueur a tenté d'obtenir des munitions infinies",true,true)
        elseif (_type == "resourcestarted") then
            kickorbancheater(_src,"AntiResourceStart", "Ce joueur a tenté de démarrer une ressource",true,true)
        elseif (_type == "menyoo") then
            kickorbancheater(_src,"Anti Menyoo", "Ce joueur a tenté d'injecter le menu Menyoo",true,true)
        elseif (_type == "givearmour") then
            kickorbancheater(_src,"Anti Give Armor", "Ce joueur a tenté de se donner de l'armure",true,true)
        elseif (_type == "aimassist") then
            kickorbancheater(_src,"Aim Assist", "Ce joueur a déclenché une détection d'Aim Assist. Mode : ",false,false)
        elseif (_type == "infinitestamina") then
            kickorbancheater(_src,"Anti Endurance Infinie", "Ce joueur a tenté d'utiliser l'endurance infinie",true,true)
        elseif (_type == "superjump") then
            if IsPlayerUsingSuperJump(_src) then
                kickorbancheater(_src,"Super-saut détecté", "Ce joueur a tenté d'utiliser le super-saut",true,true)
            end
        elseif (_type == "vehicleweapons") then
            kickorbancheater(_src,"Armes de véhicule détectées", "Ce joueur a tenté d'utiliser des armes de véhicule",true,true)
        elseif (_type == "blacklistedtask") then
            kickorbancheater(_src,"Tâche blacklistée", "A tenté d'exécuter une tâche blacklistée.",true,true)
        elseif (_type == "blacklistedanim") then
            kickorbancheater(_src,"Animation blacklistée", "A tenté d'exécuter une animation blacklistée. Ce joueur n'est peut-être pas un tricheur.",true,true)
        elseif (_type == "receivedpickup") then
            kickorbancheater(_src,"Pickup reçu", "Pickup reçu.",true,true)
        elseif (_type == "shotplayerwithoutbeingonhisscreen") then
            kickorbancheater(_src,"Anti Aimbot/TriggerBot", "A touché un joueur sans être visible sur son écran. Aimbot/TriggerBot/RageBot possible. Différence de distance.",false,false) -- can do wrong ban
        elseif (_type == "aimbot") then
            kickorbancheater(_src,"Anti Aimbot", "Aimbot détecté.",true,true)
        elseif (_type == "silentaim") then
            kickorbancheater(_src,"Silent Aim détecté", "Logique de Silent Aim déclenchée. " .. (_item or ""), true, true)
        elseif (_type == "noclip") then
             kickorbancheater(_src, "Noclip détecté", "Vérification de distance déclenchée. " .. (_item or ""), true, true)
        elseif (_type == "damagemodifier") then
             kickorbancheater(_src, "Modificateur de dégâts détecté", "Dégâts anormaux détectés. " .. (_item or ""), true, true)
        elseif (_type == "menu_global") then
             kickorbancheater(_src, "Injection globale détectée", "Variable globale malveillante détectée : " .. (_item or ""), true, true)
        elseif (_type == "overlay_detection") then
             kickorbancheater(_src, "Manipulation d'overlay/résolution", "Changement de résolution suspect détecté. " .. (_item or ""), true, true)
        elseif (_type == "stoppedac") then
            kickorbancheater(_src,"Anti Resource Stop", "A tenté d'arrêter l'anticheat.",true,true)
        elseif (_type == "stoppedresource") then
            kickorbancheater(_src,"Anti Resource Stop", "A tenté d'arrêter une ressource.",true,true)
        end
end)

RegisterNetEvent('JzKD3yfGZMSLTqu9L4Qy')
AddEventHandler('JzKD3yfGZMSLTqu9L4Qy', function(resource, info)
    local _src = source
    if resource ~= nil and info ~= nil then
        kickorbancheater(_src,"Injection détectée", "Injection détectée dans la resource : "..resource.. "Type: "..info,true,true)
     end
end)

RegisterNetEvent('tYdirSYpJtB77dRC3cvX')
AddEventHandler('tYdirSYpJtB77dRC3cvX', function()
    local _src = source
        local players = {}
        for _,v in pairs(GetPlayers()) do
            table.insert(players, {
                name = GetPlayerName(v),
                id = v
            })
        end
        kickorbancheater(_src,"Don d'arme à un Ped", "Ce joueur a tenté de donner une arme à un Ped.",true,true)
end)
if Shared.Anticheat.AntiResource or Shared.Anticheat.AntiResourceManipulation then
    RegisterNetEvent('PJHxig0KJQFvQsrIhd5h')
    AddEventHandler('PJHxig0KJQFvQsrIhd5h', function(clientResourceList)
        local _src = source
        if not clientResourceList then return end

        local serverResources = {}
        local numResources = GetNumResources()
        for i = 0, numResources - 1 do
            local resName = GetResourceByFindIndex(i)
            if resName and GetResourceState(resName) == "started" then
                serverResources[resName] = true
            end
        end

        for resName, metadata in pairs(clientResourceList) do
            if not serverResources[resName] then
                if not Shared.Anticheat.WhitelistedResources[resName] and resName ~= "_cfx_internal" then
                     kickorbancheater(_src, "Manipulation de ressource", "Ressource inconnue détectée en cours d'exécution côté client : " .. resName, true, true)
                end
            end
        end

        for resName, _ in pairs(serverResources) do
             if GetResourceMetadata(resName, 'client_script', 0) or GetResourceMetadata(resName, 'client_scripts', 0) then
                 if not clientResourceList[resName] then
                      if not Shared.Anticheat.WhitelistedResources[resName] then
                          kickorbancheater(_src, "Manipulation de ressource", "Ressource attendue arrêtée : " .. resName, true, true)
                      end
                 end
             end
        end

        for k, v in pairs(clientResourceList) do
             if k == "unex" or k == "Unex" or k == "rE" or k == "redENGINE" or k == "Eulen" then
                kickorbancheater(_src,"Injection de ressource", "Executor détecté : "..k,true,true)
            end
        end
    end)
end

AddEventHandler('explosionEvent', function(sender, ev)
    local name = GetPlayerName(sender)
    local _src = source

    if ev.damageScale ~= 0.0 and ev.ownerNetId == 0 then
        kickorbancheater(_src, "Événement d'explosion détecté", "Type d'explosion : "..ev.explosionType,true,true)
        CancelEvent()
    end
end)

-- TODO: Maybe rework from entityCreated to entityCreating for server-side performance. Disabled for now.

local PlayerHeartbeats = {}

if Shared.Anticheat.Heartbeat then
    RegisterServerEvent("rwe:HeartbeatReturn")
    AddEventHandler("rwe:HeartbeatReturn", function(token)
        local _src = source
        if PlayerHeartbeats[_src] and PlayerHeartbeats[_src].token == token then
            PlayerHeartbeats[_src].lastBeat = os.time()
        end
    end)

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(Shared.Anticheat.HeartbeatInterval or 30000)
            local current = os.time()
            for _, playerId in ipairs(GetPlayers()) do
                playerId = tonumber(playerId)
                if not PlayerHeartbeats[playerId] then
                    PlayerHeartbeats[playerId] = { lastBeat = current, token = math.random(100000, 999999) }
                    TriggerClientEvent("rwe:HeartbeatCheck", playerId, PlayerHeartbeats[playerId].token)
                else
                    if os.difftime(current, PlayerHeartbeats[playerId].lastBeat) > ((Shared.Anticheat.HeartbeatInterval / 1000) * 3) then
                         kickorbancheater(playerId, "Heartbeat Failed", "Client not responding.", true, true)
                    else
                        PlayerHeartbeats[playerId].token = math.random(100000, 999999)
                        TriggerClientEvent("rwe:HeartbeatCheck", playerId, PlayerHeartbeats[playerId].token)
                    end
                end
            end
        end
    end)
    
    AddEventHandler('playerDropped', function()
        local _src = source
        PlayerHeartbeats[_src] = nil
    end)
end

function CaptureScreenshot(target)
    if not Shared.Anticheat.OCR then return end
    local webhook = Shared.Anticheat.OCRWebhook ~= "" and Shared.Anticheat.OCRWebhook or Shared.Anticheat.WebhookDiscord
    
    if GetResourceState('screenshot-basic') == 'started' then
        exports['screenshot-basic']:requestClientScreenshot(target, {
            encoding = 'jpg',
            quality = 0.8
        }, function(err, data)
            if not err and data then
                PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({
                    username = "LSLegacy Screen",
                    embeds = {{
                        title = "Capture",
                        description = "Screenshot Player ID: " .. target,
                        image = { url = data }
                    }}
                }), { ['Content-Type'] = 'application/json' })
            end
        end)
    end
end

local BlacklistedVehiclesHash = {}
local BlacklistedPedsHash = {}
local BlacklistedObjectsHash = {}

Citizen.CreateThread(function()
    -- Convert arrays to hash maps for O(1) lookup
    for _, name in ipairs(Shared.Anticheat.BlacklistedVehicles) do
        BlacklistedVehiclesHash[GetHashKey(name)] = true
        BlacklistedVehiclesHash[name] = true
    end
    for _, name in ipairs(Shared.Anticheat.BlacklistedPeds) do
        BlacklistedPedsHash[GetHashKey(name)] = true
        BlacklistedPedsHash[name] = true
    end
    for _, name in ipairs(Shared.Anticheat.BlacklistedObjects) do
        BlacklistedObjectsHash[GetHashKey(name)] = true
        BlacklistedObjectsHash[name] = true
    end
end)

if Shared.Anticheat.AntiEntity then
    AddEventHandler('entityCreating', function(entity)
        if not DoesEntityExist(entity) then return end

        local src = NetworkGetEntityOwner(entity)
        local script = GetEntityScript(entity)
        local type = GetEntityType(entity) -- 1: Ped, 2: Vehicle, 3: Object
        local model = GetEntityModel(entity)

        -- Source 0 usually means server-side script, verify script name
        if src == 0 or src == nil then
            if script ~= nil then return end -- Trusted server script
        end

        if type == 1 and Shared.Anticheat.AntiSpawnPeds then -- Ped
            if BlacklistedPedsHash[model] then
                CancelEvent()
                if src and src > 0 then
                    --kickorbancheater(src, "Blacklisted Ped Spawn", "Spawning blacklisted ped: " .. tostring(model) .. " (Script: "..(script or "None")..")", true, true)
                end
                return
            end
        elseif type == 2 and Shared.Anticheat.AntiSpawnVehicles then -- Vehicle
             if BlacklistedVehiclesHash[model] then
                CancelEvent()
                if src and src > 0 then
                    --kickorbancheater(src, "Blacklisted Vehicle Spawn", "Spawning blacklisted vehicle: " .. tostring(model).. " (Script: "..(script or "None")..")", true, true)
                end
                return
            end
        elseif type == 3 and Shared.Anticheat.AntiSpawnObjects then -- Object
             if BlacklistedObjectsHash[model] then
                CancelEvent()
                if src and src > 0 then
                     --kickorbancheater(src, "Blacklisted Object Spawn", "Spawning blacklisted object: " .. tostring(model).. " (Script: "..(script or "None")..")", true, true)
                end
                return
            end
        end
    end)
end


if Shared.Anticheat.AntiEntityCoords then
    Citizen.CreateThread(function()
        local lastCoords = {}
        while true do
            Citizen.Wait(2000)
            for _, player in ipairs(GetPlayers()) do
                local _src = tonumber(player)
                local ped = GetPlayerPed(_src)
                if DoesEntityExist(ped) then
                    local vehicle = GetVehiclePedIsIn(ped, false)
                    if vehicle and vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
                        local currentCoords = GetEntityCoords(vehicle)
                        if lastCoords[_src] then
                            local dist = #(currentCoords - lastCoords[_src])
                            -- 2 seconds interval. Max speed of fastest car ~140 mph ~= 62 m/s = 124m, margin to 400m for falling/lag.
                            if dist > 400.0 then
                                -- Beware of interior teleports (check if routing bucket changed? FiveM handles this, coords usually jump)
                                if GetEntityHeightAboveGround(vehicle) > 50.0 and not IsPedInAnyPlane(ped) and not IsPedInAnyHeli(ped) then
                                     kickorbancheater(_src, "Vol/téléportation de véhicule", "A parcouru " .. math.ceil(dist) .. " unités en 2s.", true, true)
                                end
                            end
                        end
                        lastCoords[_src] = currentCoords
                    else
                        lastCoords[_src] = nil
                    end
                end
            end
        end
    end)
end

if Shared.Anticheat.AntiSpoofProjectile then
    AddEventHandler("weaponDamageEvent", function(sender, data)
        local _src = sender
        -- data struct: damageType, weaponType, destructionDamage, tyreIndex...
        -- FiveM doesn't give projectile origin explicitly in this event easily without parsing damageFlags
        if data.weaponType ~= 911657153 and data.weaponType ~= 0 then -- Ignore Unarmed/Stun
             local victim = NetworkGetEntityFromNetworkId(data.hitGlobalId)
             local shooter = GetPlayerPed(_src)
             if DoesEntityExist(victim) and DoesEntityExist(shooter) then
                 local vCoords = GetEntityCoords(victim)
                 local sCoords = GetEntityCoords(shooter)
                 local dist = #(vCoords - sCoords)

                 -- Hard limit for most guns is around 250-300m, snipers more
                 if dist > 600.0 then
                      kickorbancheater(_src, "Spoof de projectile", "A touché un joueur situé à " .. math.floor(dist) .. "m de distance.", true, true)
                      CancelEvent()
                 end
             end
        end
    end)
end

RegisterNetEvent('chat:server:ServerPSA')
AddEventHandler('chat:server:ServerPSA', function()
	local _src = source
    kickorbancheater(_src,"Faux message détecté", "Faux message détecté",true,true)
end)

RegisterServerEvent('rwe:WeaponFlag')
AddEventHandler('rwe:WeaponFlag', function(weapon)
    local _src = source
	TriggerClientEvent("rwe:RemoveInventoryWeapons", _src) 
    kickorbancheater(_src,"Anti Weapon Flag", "S'est donné une arme. Arme : "..weapon,true,true)
end)


if Shared.Anticheat.EventsDetect then
    for k, v in pairs(Shared.Anticheat.Events) do
        RegisterServerEvent(v)
        AddEventHandler(v, function()
            local _src = source
            kickorbancheater(_src,"Événement blacklisté", "Événement blacklisté intercepté. Event : "..v,true,true)
            CancelEvent()
        end)
    end
end

AddEventHandler('chatMessage', function(source, color, message)
    local _src = source
    if not message then return end

    if Shared.Anticheat.AntiBlacklistedWords then
        for k, v in pairs(Shared.Anticheat.BlacklistWords) do
            if string.match(message, v) then
                Citizen.Wait(1500)
                kickorbancheater(_src, "Mots blacklistés détectés", "Mots blacklistés détectés. Mots : "..v, true, true)
                CancelEvent()
                return
            end
        end
    end
end)

RegisterServerEvent('_chat:messageEntered')
AddEventHandler('_chat:messageEntered', function(author, color, message)
    if not message then return end
    local src = source

    for k, v in pairs(Shared.Anticheat.BlacklistWords) do
        if string.match(message, v) then
            Citizen.Wait(1500)
            kickorbancheater(src, "Mots blacklistés détectés", "Mots blacklistés détectés. Mots : "..v, true, true)
            CancelEvent()
            return
        end
    end
end)

Citizen.CreateThread(function()
    for i=1, #Shared.Anticheat.BlacklistedCommands, 1 do
        RegisterCommand(Shared.Anticheat.BlacklistedCommands[i], function(source)
            local _src = source
            kickorbancheater(_src, "Commande blacklistée détectée", "Commande blacklistée détectée.", true, true)
        end)
    end
end)

AddEventHandler("weaponDamageEvent", function(sender, data)
    if Shared.Anticheat.AntiTaze then
        local _src = sender
        if data.weaponType == 911657153 or data.weaponType == GetHashKey("WEAPON_STUNGUN") then
            kickorbancheater(_src, "Anti Taser", "A tenté de tirer avec un taser", true, true)
            CancelEvent()
        end
    end
end)

AddEventHandler("giveWeaponEvent", function(sender,data)
    if Shared.Anticheat.AntiGiveWeaponEvent then
        local _src = sender
        if data.givenAsPickup == false then
            kickorbancheater(_src, "Anti Give Weapon (event)", "A tenté de donner des armes à un Ped", true, true)
            CancelEvent()
        end
    end
end)

if Shared.Anticheat.AntiCrash then
    AddEventHandler("playerDropped", function(reason)
        for k, v in pairs(Shared.Anticheat.BlacklistedCrash) do
            local _src = source
            if reason == v then
                kickorbancheater(_src, "Crash détecté", "Crash blacklisté détecté", true, true)
            end
        end
    end)
end

local Charset = {}
for i = 65, 90 do table.insert(Charset, string.char(i)) end
for i = 97, 122 do table.insert(Charset, string.char(i)) end

RandomLetter = function(length)
    if length > 0 then
        return RandomLetter(length - 1) .. Charset[math.random(1, #Charset)]
    end
    return ""
end

AddEventHandler('chatMessage', function(source, color, message)
    local _src = source
    if not message then
        return
    end

    if Shared.Anticheat.AntiBlacklistedWords then
        for k, v in pairs(Shared.Anticheat.BlacklistWords) do
            if string.match(message, v) then
                Citizen.Wait(1500)
                kickorbancheater(_src,"Mots blacklistés détectés", "Mots blacklistés détectés. Mots : "..v,true,true)
                CancelEvent()
            end
            return
        end
    end
end)

RegisterServerEvent('_chat:messageEntered')
AddEventHandler('_chat:messageEntered', function(author, color, message)
    if not message then
        return
    end
    local src = source

    for k, v in pairs(Shared.Anticheat.BlacklistWords) do
        if string.match(message, v) then
            Citizen.Wait(1500)
            kickorbancheater(src,"Mots blacklistés détectés", "Mots blacklistés détectés. Mots : "..v,true,true)
            CancelEvent()
        end
      return
    end
end)

Citizen.CreateThread(function()
    for i=1, #Shared.Anticheat.BlacklistedCommands, 1 do
        RegisterCommand(Shared.Anticheat.BlacklistedCommands[i], function(source)
            local _src = source
            kickorbancheater(_src,"Commande blacklistée détectée", "Commande blacklistée détectée.",true,true)
        end)
    end
end)

RegisterNetEvent('rwdeletevehiclesc', function(playerId)
	local coords = GetEntityCoords(GetPlayerPed(playerId))
	for _, v in pairs(GetAllVehicles()) do
		local objCoords = GetEntityCoords(v)
		local dist = #(coords - objCoords)
		if dist < 2000 then
			if DoesEntityExist(v) then
				DeleteEntity(v)
            end
        end
    end
end)

RegisterNetEvent('rwdeletepedsc', function(playerId)
	local coords = GetEntityCoords(GetPlayerPed(playerId))
	for _, v in pairs(GetAllPeds()) do
		local objCoords = GetEntityCoords(v)
		local dist = #(coords - objCoords)
		if dist < 2000 then
			if DoesEntityExist(v) then
				DeleteEntity(v)
            end
        end
    end
end)

RegisterNetEvent('rwdeleteobjectsc', function(playerId)
	local coords = GetEntityCoords(GetPlayerPed(playerId))
	for _, v in pairs(GetAllObjects()) do
		local objCoords = GetEntityCoords(v)
		local dist = #(coords - objCoords)
		if dist < 2000 then
			if DoesEntityExist(v) then
				DeleteEntity(v)
            end
        end
    end
end)

RegisterCommand("allentitywipe", function(source)
    local _src = source
    if IsPlayerWhitelisted(_src) then
        TriggerEvent('rwdeletevehiclesc', tonumber(_src))
        TriggerEvent('rwdeletepedsc', tonumber(_src))
        TriggerEvent('rwdeleteobjectsc', tonumber(_src))
    end
end, false)

-- EntityCreated, version alternative avec affichage client
AddEventHandler('entityCreated', function(entity)
    if DoesEntityExist(entity) then
        local src = source
        local model = GetEntityModel(entity)
        if model == 3 then
            for _, blacklistedProps in pairs(Shared.Anticheat.BlacklistedObjects) do
                if model == blacklistedProps then
                    TriggerClientEvent('rwe:antiProp', -1)
                    kickorbancheater(src,"Objet blacklisté détecté", "Prop : "..blacklistedProps.. " https://mwojtasik.dev/tools/gtav/objects/search?name="..blacklistedProps,true,true)
                    CancelEvent()
                    return
                end
            end
        elseif model == 2 then
            for _, blacklistedVeh in pairs(Shared.Anticheat.BlacklistedVehicles) do
                if model == blacklistedVeh then
                    TriggerClientEvent('rwe:AntiVehicle', -1)
                    kickorbancheater(src,"Véhicule blacklisté détecté", "Véhicule : "..blacklistedVeh.. " https://www.gtabase.com/search?searchword="..blacklistedVeh,true,true)
                    CancelEvent()
                    return
                end
            end
        elseif model == 1 then
            for _, blacklistedPed in pairs(Shared.Anticheat.BlacklistedPeds) do
                if model == blacklistedPed then
                    TriggerClientEvent('rwe:antiPed', -1)
                    kickorbancheater(src,"Ped blacklisté détecté", "Ped : "..blacklistedPed.. " https://docs.fivem.net/peds/"..blacklistedPed..'.png',true,true)
                    CancelEvent()
                    return
                end
            end
        end
    end
end)

AddEventHandler("weaponDamageEvent", function(sender, data)
    if Shared.Anticheat.AntiTaze then
        local _src = sender
        if data.weaponType == 911657153 or data.weaponType == GetHashKey("WEAPON_STUNGUN") then
            kickorbancheater(_src,"Anti Taser", "A tenté de tirer avec un taser",true,true)
            CancelEvent()
        end
    end
end)

AddEventHandler("giveWeaponEvent", function(sender, data)
    if Shared.Anticheat.AntiGiveWeapon or Shared.Anticheat.AntiGiveWeaponEvent then
        local _src = sender
        -- If givenAsPickup is false, it means it was likely script/menu injected directly into inventory
        -- Legitimate pickups usually have this as true, or are handled server-side without this event
        if data.givenAsPickup == false then
            kickorbancheater(_src, "Anti Give Weapon", "A tenté de donner des armes à un Ped (Script/Menu)", true, true)
            CancelEvent()
        end
    end
end)

AddEventHandler("removeWeaponEvent", function(sender, data)
    if Shared.Anticheat.AntiRemoveWeapon then
        local _src = sender
        kickorbancheater(_src, "Anti Remove Weapon", "A tenté de retirer des armes (potentiellement à un autre joueur)", true, true)
        CancelEvent()
    end
end)

local Charset = {}
for i = 65, 90 do
    table.insert(Charset, string.char(i))
end
for i = 97, 122 do
    table.insert(Charset, string.char(i))
end

RandomLetter = function(length)
    if length > 0 then
        return RandomLetter(length - 1) .. Charset[math.random(1, #Charset)]
    end
    return ""
end
