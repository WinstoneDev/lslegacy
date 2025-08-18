-- CONST_POPULATION_TYPE_MISSION = 7

AddEventHandler('entityCreating', function(id)    
    local entityModel = GetEntityModel(id)
    local entityType = GetEntityType(id)

    if entityType == 3 then -- Objects
        if Shared.Anticheat.WhitelistObject then
            if Shared.Anticheat.ListObjects[entityModel] then
                CancelEvent()
            end
        end
    elseif entityType == 2 then -- Vehicles
        if Shared.Anticheat.BlacklistVehicle then
            if Shared.Anticheat.ListVehicles[entityModel] then
                CancelEvent()
            end
        end
    elseif entityType == 1 then -- Peds
        if Shared.Anticheat.BlacklistPed then
            if Shared.Anticheat.ListPeds[entityModel] then
                CancelEvent()
            end
        end
    end
end)

---BanPlayer
---@type function
---@param player table
---@param time number
---@param reason string
---@return void
---@public
Shared.Anticheat.BanPlayer = function(player, time, reason, source)
    local moderator = MadeInFrance.GetPlayerFromId(source)
    if tonumber(time) then
        if player then
            local CountHour = time
            local ids = Shared.Anticheat.ExtractIdentifiersBan(player.source)
            local ids2 = Shared.Anticheat.ExtractIdentifiersBan(moderator.source)
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
                    DropPlayer(player.source, "Vous êtes ban de MadeInFrance\nRaison : "..reason.."\nID Bannissement : "..result[1].idban)
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
                    DropPlayer(player.source, "Vous êtes ban de MadeInFrance\nRaison : "..reason.."\nID Bannissement : "..result[1].idban)
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

local ServerPassword = "mif"

MadeInFrance.AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
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
    print("Une connexion est en cours")

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

    if MadeInFrance.GetPlayerFromIdentifier(license) then
        return deferrals.done("Erreur : un joueur utilise déjà cette license.")
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
    end
end)