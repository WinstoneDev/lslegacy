---@class LSLegacy.ServerPlayers
LSLegacy.ServerPlayers = {}

-- Whitelist des champs que le client est autorisé à pousser vers le serveur
-- via ReceiveUpdateServerPlayer. Un remplacement complet de
-- LSLegacy.ServerPlayers[source] écraserait toute mutation faite côté
-- serveur (argent, job, inventaire, skills...) survenue depuis le dernier
-- push client, d'où un merge ciblé sur cette liste plutôt qu'un
-- remplacement. N'y ajouter un champ que s'il est réellement modifié côté
-- client dans LSLegacy.PlayerData (aujourd'hui : uniquement le skin, via la
-- boucle de poll de client/player/player.lua) — tout le reste de
-- LSLegacy.PlayerData n'est qu'un miroir en lecture de l'état serveur.
local ClientWritableFields = {
    'skin',
}

LSLegacy.RegisterServerEvent('ReceiveUpdateServerPlayer', function(data)
    local source = source
    if not LSLegacy.ServerPlayers[source] then return end
    for _, field in ipairs(ClientWritableFields) do
        LSLegacy.ServerPlayers[source][field] = data[field]
    end
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
AddEventHandler("registerPlayer", function(characterId)
    local source = source
    Config.Development.Print("[registerPlayer] reçu de " .. source .. ", characterId=" .. tostring(characterId))

    if LSLegacy.ServerPlayers[source] then
        Config.Development.Print("Player " .. source .. " already registered")
        DropPlayer(source, "Player " .. source .. " already registered ╭∩╮（︶_︶）╭∩╮")
        return
    end

    Config.Development.Print("[registerPlayer] " .. source .. ": GeneratorTokenConnecting...")
    LSLegacy.GeneratorTokenConnecting(source)
    Config.Development.Print("[registerPlayer] " .. source .. ": jetons générés")
    local identifier = GetPlayerIndentifier(source)

    -- Chargement d'un personnage existant (row = ligne players)
    local function LoadCharacter(row)
        Config.Development.Print("[registerPlayer] " .. source .. ": LoadCharacter(id=" .. tostring(row["boutique-id"]) .. ", slot=" .. tostring(row.slot) .. ")")
        local defaultSkills = {
            endurance = {xp = 0, lastActivity = 0},
            tir       = {xp = 0, lastActivity = 0},
            force     = {xp = 0, lastActivity = 0},
            furtivite = {xp = 0, lastActivity = 0},
            pilotage  = {xp = 0, lastActivity = 0},
            conduite  = {xp = 0, lastActivity = 0},
            apnee     = {xp = 0, lastActivity = 0},
        }
        local rawSkills = row.skills and row.skills ~= '{}' and json.decode(row.skills) or {}
        for k, v in pairs(defaultSkills) do
            if not rawSkills[k] then rawSkills[k] = v end
        end
        LSLegacy.ServerPlayers[source] = {
            ["boutique-id"] = row["boutique-id"],
            slot = row.slot,
            name = GetPlayerName(source),
            identifier = row.identifier,
            ip = GetPlayerEP(source),
            discordId = GetPlayerDiscord(source),
            source = source,
            token = GetPlayerToken(source),
            characterInfos = json.decode(row.characterInfos),
            inventory = json.decode(row.inventory),
            currentZone = "Aucune",
            coords = json.decode(row.coords),
            weight = 0,
            health = row.health,
            skin = json.decode(row.skin),
            cash = json.decode(row.money).cash,
            dirty = json.decode(row.money).dirty,
            group = row.group,
            status = json.decode(row.status),
            skills = rawSkills,
            isKO   = false,
            isComa = false,
            job = row.job,
            job_grade = row.job_grade,
            faction = row.faction,
            faction_grade = row.faction_grade
        }
        -- Accès command.doorlock (ox_doorlock) pour tout personnage superadmin,
        -- sans passer par une liste d'identifiants figée dans server.cfg
        -- (voir "add_ace group.superadmin command.doorlock allow").
        if row.group == Config.StaffGroups[4] then
            ExecuteCommand(('add_principal identifier.%s group.superadmin'):format(row.identifier))
        end
        MySQL.Async.execute('UPDATE players SET token = @token, discordId = @discordId WHERE `boutique-id` = @id', {
            ['@token'] = LSLegacy.ServerPlayers[source].token,
            ['@discordId'] = LSLegacy.ServerPlayers[source].discordId,
            ['@id'] = LSLegacy.ServerPlayers[source]["boutique-id"]
        })
        Wait(250)
        local weight = LSLegacy.Inventory.GetInventoryWeight(LSLegacy.ServerPlayers[source].inventory)
        LSLegacy.ServerPlayers[source].weight = weight or 0
        LSLegacy.Injury.InitWounds(source)
        Wait(250)
        Config.Development.Print("[registerPlayer] " .. source .. ": envoi InitPlayer (LoadCharacter)")
        LSLegacy.SendEventToClient('InitPlayer', source, LSLegacy.ServerPlayers[source])
        TriggerClientEvent('lslegacy:phone:playerReady', source)
        LSLegacy.RegisterPeds(LSLegacy.RegisteredZones, source)
        for k, v in pairs(LSLegacy.Commands) do
            if v.suggestion then
                if not v.suggestion.arguments then v.suggestion.arguments = {} end
                if not v.suggestion.help then v.suggestion.help = '' end

                TriggerClientEvent('chat:addSuggestion', source, ('/%s'):format(k), v.suggestion.help, v.suggestion.arguments)
            end
        end
        Config.Development.Print("Successfully registered player " .. GetPlayerName(source))
        LSLegacy.SendEventToClient('zones:registerBlips', source, LSLegacy.RegisteredZones)
        LSLegacy.SendEventToClient('UpdateDatastore', source, LSLegacy.DataStores)
        LSLegacy.TriggerLocalEvent('ap:clientsetonSpawn', source)

        -- Vérification coma persistant après reconnexion
        local _src = source
        Citizen.SetTimeout(6000, function()
            local p = LSLegacy.ServerPlayers[_src]
            if not p or not p.status then return end
            local comaUntil = p.status.comaUntil
            if comaUntil then
                local remaining = comaUntil - os.time()
                if remaining > 0 then
                    p.isComa = true
                    TriggerClientEvent("LSLegacy:injury:resumeComa", _src, remaining)
                end
            end
        end)
    end

    -- Création d'un nouveau personnage (nouveau compte, ou nouveau slot)
    local function CreateCharacter(slot)
        Config.Development.Print("[registerPlayer] " .. source .. ": CreateCharacter(slot=" .. tostring(slot) .. ")")
        LSLegacy.ServerPlayers[source] = {
            slot = slot,
            name = GetPlayerName(source),
            identifier = identifier,
            ip = GetPlayerEP(source),
            discordId = GetPlayerDiscord(source),
            source = source,
            token = GetPlayerToken(source),
            characterInfos = {Sexe = "Aucun", LDN = "Aucun", Prenom = "Aucun", NDF = "Aucun", Taille = 180, DDN = "19/04/1999"},
            inventory = {},
            currentZone = "Aucune",
            coords = {x = -427.727478, y = 1115.578003, z = 326.780273, h = 243.77952575684},
            weight = LSLegacy.Inventory.GetInventoryWeight({}) or 0,
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
            },
            skills = {
                endurance = {xp = 0, lastActivity = 0},
                tir       = {xp = 0, lastActivity = 0},
                force     = {xp = 0, lastActivity = 0},
                furtivite = {xp = 0, lastActivity = 0},
                pilotage  = {xp = 0, lastActivity = 0},
                conduite  = {xp = 0, lastActivity = 0},
                apnee     = {xp = 0, lastActivity = 0},
            },
            isKO    = false,
            isComa  = false,
            job = "unemployed",
            job_grade = 0,
            faction = "unemployed",
            faction_grade = 0
        }
        local insertReceived, insertId = false, nil
        MySQL.Async.insert('INSERT INTO players (identifier, slot, discordId, token, characterInfos, coords, status) VALUES(@identifier, @slot, @discordId, @token, @characterInfos, @coords, @status)', {
            ['@identifier'] = LSLegacy.ServerPlayers[source].identifier,
            ['@slot'] = slot,
            ['@discordId'] = LSLegacy.ServerPlayers[source].discordId,
            ['@token'] = LSLegacy.ServerPlayers[source].token,
            ['@characterInfos'] = json.encode(LSLegacy.ServerPlayers[source].characterInfos),
            ['@coords'] = json.encode(LSLegacy.ServerPlayers[source].coords),
            ['@status'] = json.encode(LSLegacy.ServerPlayers[source].status)
        }, function(newId)
            insertId = newId
            insertReceived = true
        end)
        while not insertReceived do Wait(0) end
        LSLegacy.ServerPlayers[source]["boutique-id"] = insertId
        LSLegacy.Injury.InitWounds(source)
        Config.Development.Print("[registerPlayer] " .. source .. ": envoi InitPlayer (CreateCharacter), id=" .. tostring(LSLegacy.ServerPlayers[source]["boutique-id"]))
        LSLegacy.SendEventToClient('InitPlayer', source, LSLegacy.ServerPlayers[source])
        TriggerClientEvent('lslegacy:phone:playerReady', source)
        LSLegacy.RegisterPeds(LSLegacy.RegisteredZones, source)
        for k, v in pairs(LSLegacy.Commands) do
            if v.suggestion then
                if not v.suggestion.arguments then v.suggestion.arguments = {} end
                if not v.suggestion.help then v.suggestion.help = '' end
                TriggerClientEvent('chat:addSuggestion', source, ('/%s'):format(k), v.suggestion.help, v.suggestion.arguments)
            end
        end
        Config.Development.Print("Successfully registered player " .. GetPlayerName(source))
        LSLegacy.SendEventToClient('zones:registerBlips', source, LSLegacy.RegisteredZones)
        LSLegacy.SendEventToClient('UpdateDatastore', source, LSLegacy.DataStores)
        LSLegacy.TriggerLocalEvent('ap:clientsetonSpawn', source)
    end

    if characterId ~= nil and characterId ~= "new" then
        Config.Development.Print("[registerPlayer] " .. source .. ": branche id explicite, requête SELECT...")
        -- Sélection explicite depuis l'écran multicharacter : on vérifie que
        -- le personnage appartient bien à l'identifier connecté (un client
        -- modifié ne peut pas charger le personnage d'un autre compte).
        MySQL.Async.fetchAll('SELECT * FROM players WHERE `boutique-id` = @id AND identifier = @identifier', {
            ['@id'] = tonumber(characterId),
            ['@identifier'] = identifier
        }, function(result)
            Config.Development.Print("[registerPlayer] " .. source .. ": SELECT terminé, résultat=" .. tostring(result[1] ~= nil))
            if result[1] then
                LoadCharacter(result[1])
            else
                Config.Development.Print("Tentative de chargement d'un personnage invalide par " .. source)
                DropPlayer(source, "Personnage invalide ╭∩╮（︶_︶）╭∩╮")
            end
        end)
    elseif characterId == "new" then
        Config.Development.Print("[registerPlayer] " .. source .. ": branche 'new', requête MAX(slot)...")
        MySQL.Async.fetchAll('SELECT COALESCE(MAX(slot), 0) AS maxSlot FROM players WHERE identifier = @identifier', {
            ['@identifier'] = identifier
        }, function(rows)
            Config.Development.Print("[registerPlayer] " .. source .. ": MAX(slot) reçu")
            local nextSlot = (rows[1] and tonumber(rows[1].maxSlot) or 0) + 1
            CreateCharacter(nextSlot)
        end)
    else
        Config.Development.Print("[registerPlayer] " .. source .. ": branche fast-path (slot 1), requête SELECT...")
        -- Pas d'id fourni : multicharacter désactivé / fast-path avec un
        -- seul slot → comportement identique à l'ancien flux (slot 1).
        MySQL.Async.fetchAll('SELECT * FROM players WHERE identifier = @identifier AND slot = 1', {
            ['@identifier'] = identifier
        }, function(result)
            Config.Development.Print("[registerPlayer] " .. source .. ": SELECT terminé, résultat=" .. tostring(result[1] ~= nil))
            if result[1] then
                LoadCharacter(result[1])
            else
                CreateCharacter(1)
            end
        end)
    end
end)

Citizen.CreateThread(function()
    Wait(10000)
    while true do
        for k, player in pairs(LSLegacy.ServerPlayers) do
            local _source = player.source
            local ped = GetPlayerPed(_source)
            local coords
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                coords = GetEntityCoords(ped)
                LSLegacy.ServerPlayers[_source].coords = coords
            else
                coords = player.coords
            end
            if not LSLegacy.ServerPlayers[_source] then goto continue end
            MySQL.Async.execute('UPDATE players SET coords = @coords, skin = @skin, inventory = @inventory, money = @money, health = @health, status = @status, skills = @skills, job = @job, job_grade = @job_grade, faction = @faction, faction_grade = @faction_grade WHERE `boutique-id` = @id', {
                ['@coords'] = json.encode(coords),
                ['@id'] = LSLegacy.ServerPlayers[_source]["boutique-id"],
                ["@skin"] = json.encode(LSLegacy.ServerPlayers[_source].skin),
                ['@inventory'] = json.encode(LSLegacy.ServerPlayers[_source].inventory),
                ['@money'] = json.encode({cash = LSLegacy.ServerPlayers[_source].cash, dirty = LSLegacy.ServerPlayers[_source].dirty}),
                ['@health'] = ped and ped ~= 0 and DoesEntityExist(ped) and GetEntityHealth(ped) or player.health,
                ['@status'] = json.encode(LSLegacy.ServerPlayers[_source].status),
                ['@skills'] = json.encode(LSLegacy.ServerPlayers[_source].skills or {}),
                ['@job'] = LSLegacy.ServerPlayers[_source].job,
                ['@job_grade'] = LSLegacy.ServerPlayers[_source].job_grade,
                ['@faction'] = LSLegacy.ServerPlayers[_source].faction,
                ['@faction_grade'] = LSLegacy.ServerPlayers[_source].faction_grade
            })
            LSLegacy.SendEventToClient('UpdateServerPlayer', _source)
            LSLegacy.SendEventToClient('UpdateDatastore', _source, LSLegacy.DataStores)
            Wait(500)
            if LSLegacy.ServerPlayers[_source] then
                LSLegacy.SendEventToClient('UpdatePlayer', _source, LSLegacy.ServerPlayers[_source])
            end
            ::continue::
        end
        Wait(15000)
    end
end)


LSLegacy.AddEventHandler('playerDropped', function()
    local _source = source
    local player = LSLegacy.ServerPlayers[_source]
    if player then
        if player["boutique-id"] then
            MySQL.Async.execute('UPDATE players SET skin = @skin, inventory = @inventory, money = @money, health = @health, status = @status, skills = @skills, job = @job, job_grade = @job_grade, faction = @faction, faction_grade = @faction_grade WHERE `boutique-id` = @id', {
                ['@id']        = player["boutique-id"],
                ['@skin']      = json.encode(player.skin),
                ['@inventory'] = json.encode(player.inventory),
                ['@money']     = json.encode({cash = player.cash, dirty = player.dirty}),
                ['@health']    = player.health,
                ['@status']    = json.encode(player.status),
                ['@skills']    = json.encode(player.skills or {}),
                ['@job'] = player.job,
                ['@job_grade'] = player.job_grade,
                ['@faction'] = player.faction,
                ['@faction_grade'] = player.faction_grade
            })
        end
        LSLegacy.ServerPlayers[_source] = nil
        Config.Development.Print("Player " .. _source .. " disconnected")
    end
end)