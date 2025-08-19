MadeInFrance.Commands = {}

---RegisterCommand
---@type function
---@param name string
---@param group number
---@param callback function
---@param suggestion table
---@param console boolean
---@return void
---@public
MadeInFrance.RegisterCommand = function(name, group, callback, suggestion, console)
    if not name or not callback then
        return 
    end

    if not MadeInFrance.Commands[name] then
        if suggestion then
            if not suggestion.arguments then suggestion.arguments = {} end
            if not suggestion.help then suggestion.help = '' end
    
            TriggerClientEvent('chat:addSuggestion', -1, ('/%s'):format(name), suggestion.help, suggestion.arguments)
        end
        
        MadeInFrance.Commands[name] = {
            group = group,
            callback = callback,
            console = console,
            suggestion = suggestion
        }

        Config.Development.Print('Command ' .. name .. ' registered')

        RegisterCommand(name, function(source, args, rawCommand)
            local command = MadeInFrance.Commands[name]
            if source == 0 and not command.console then
                return Config.Development.Print("Command " .. name .. " cannot be executed from console.")
            end

            local player = MadeInFrance.GetPlayerFromId(source)

			local error = nil

            if command.suggestion then
				if command.suggestion.validate then
					if #args ~= #command.suggestion.arguments then
						error = 'Il vous manque des arguments ! (donnés ' .. #args .. ', voulus ' .. #command.suggestion.arguments .. ')'
					end
				end

				if not error and command.suggestion.arguments then
					local newArgs = {}

					for k,v in ipairs(command.suggestion.arguments) do
						if v.type then
							if v.type == 'fullstring' then
								newArgs[v.name] = args
							elseif v.type == 'number' then
								local newArg = tonumber(args[k])

								if newArg then
									newArgs[v.name] = newArg
								else
									error = 'Argument numéro' .. k .. ' manqué (donné texte, voulu nombre)'
								end
							elseif v.type == 'player' or v.type == 'playerId' then
								local targetPlayer = tonumber(args[k])

								if args[k] == 'me' then targetPlayer = source end

								if targetPlayer then
									local xTargetPlayer = MadeInFrance.GetPlayerFromId(targetPlayer)

									if xTargetPlayer then
										if v.type == 'player' then
											newArgs[v.name] = xTargetPlayer
										else
											newArgs[v.name] = targetPlayer
										end
									else
										error = 'Il n\'y a pas de joueur avec cet ID en jeu'
									end
								else
									error = 'Argument numéro' .. k .. ' manqué (donné texte, voulu nombre)'
								end
							elseif v.type == 'string' then
								newArgs[v.name] = args[k]
							elseif v.type == 'any' then
								newArgs[v.name] = args[k]
							end
						end

						if error then break end
					end

					args = newArgs
				end
			end



            if error then
				if source == 0 and command.console then
					Config.Development.Print(error)
				else
                    MadeInFrance.SendEventToClient('chat:addMessage', player.source, {args = {'^1MadeInFrance', error}})
				end
			else
                if source ~= 0 and player ~= nil then
                    for k,v in pairs(Config.StaffGroups) do
                        if player.group == v then
                            if k >= command.group then
                                command.callback(player or false, args, function(msg)
                                    if source == 0 and command.console then
                                        Config.Development.Print(msg)
                                    else
                                        MadeInFrance.SendEventToClient('chat:addMessage', player.source, {args = {'^1MadeInFrance', msg}})
                                    end
                                end, rawCommand)
                            else
                                MadeInFrance.SendEventToClient('chat:addMessage', player.source, {args = {'^1MadeInFrance', 'Vous n\'avez pas les permissions pour utiliser cette commande'}})
                            end
                        end
                    end
				elseif source == 0 and command.console then
					command.callback(player or false, args, function(msg)
						Config.Development.Print(msg)
					end, rawCommand)
                end
			end
        end, false)
    else
        return Config.Development.Print("Command " .. name .. " already registered")
    end
end

MadeInFrance.RegisterCommand('clear', 0, function(player, args, showError, rawCommand)
	MadeInFrance.SendEventToClient('chat:clear', player.source)
end, {help = "Clear le chat"}, false)

MadeInFrance.RegisterCommand('clearall', 3, function(player, args, showError, rawCommand)
	MadeInFrance.SendEventToClient('chat:clear', -1)
end, {help = "Clear le chat pour tout le monde"}, false)

MadeInFrance.RegisterCommand('announce', 3, function(player, args, showError, rawCommand)
	local text = ""
    sm = MadeInFrance.StringSplit(rawCommand, " ")
    for i = 2, #sm do
        text = text ..sm[i].. " " 
    end
	MadeInFrance.SendEventToClient('notify', -1, 'Administration', text, 'warning')
end, {help = "Affiche un message pour tout le serveur", validate = false, arguments = {{name = 'message', help = 'Message', type = 'fullstring'}}}, false)

MadeInFrance.RegisterCommand('kick', 1, function(player, args, showError, rawCommand)
	local player = args.playerId
	if player then
		sm = MadeInFrance.StringSplit(rawCommand, " ")
		message = ""
		for i = 3, #sm do
			message = message ..sm[i].. " "
		end
		DropPlayer(player.source, message .. ' (kick par ' .. player.name .. ')')
	end
end, {help = "Permet de déconnecter un joueur", validate = false, arguments = {{name = 'playerId', help = 'Id du joueur', type = 'player'}, {name = 'reason', help = "Raison du kick", type = "fullstring"}}}, false)

MadeInFrance.RegisterCommand('sync', 0, function(player, args, showError, rawCommand)
	local source = player.source
	MySQL.Async.execute('UPDATE players SET coords = @coords, inventory = @inventory, money = @money, health = @health, skin = @skin, status = @status WHERE id = @id', {
        ['@coords'] = json.encode(MadeInFrance.GetEntityCoords(source)),
        ['@inventory'] = json.encode(MadeInFrance.ServerPlayers[source].inventory),
        ['@money'] = json.encode({cash = MadeInFrance.ServerPlayers[source].cash, dirty = MadeInFrance.ServerPlayers[source].dirty}),
        ['@id'] = MadeInFrance.ServerPlayers[source].id,
        ['@health'] = GetEntityHealth(GetPlayerPed(source)),
		['@skin'] = json.encode(MadeInFrance.ServerPlayers[source].skin),
		['@status'] = json.encode(MadeInFrance.ServerPlayers[source].status)
    })
	MadeInFrance.SendEventToClient('UpdateServerPlayer', source)
	MadeInFrance.SendEventToClient('UpdateDatastore', source, MadeInFrance.DataStore)
	Wait(500)
	MadeInFrance.SendEventToClient('UpdatePlayer', source, MadeInFrance.ServerPlayers[source])
	MadeInFrance.SendEventToClient('notify', source, 'Sync', 'Vous avez bien synchronisé votre personnage.', 'success')
end, {help = "Permet de synchroniser son joueur"}, false)

MadeInFrance.RegisterCommand('debug', 0, function(player, args, showError, rawCommand)
	local source = player.source
	MadeInFrance.SendEventToClient('debug', source)
	MadeInFrance.SendEventToClient('notify', source, nil, 'Vous avez bien débug votre personnage.', 'success')
end, {help = "Permet de débug son joueur"}, false)

MadeInFrance.RegisterCommand('ban', 1, function(player, args, showError, rawCommand)
    local player = args.playerId
    local reason = ""
    sm = MadeInFrance.StringSplit(rawCommand, " ")
    for i = 4, #sm do
        reason = reason ..sm[i].. " " 
    end
    Shared.Anticheat.BanPlayer(player, args.time, reason, player.source)
end, {help = "Permet de bannir un joueur", validate = false, arguments = {{name = 'playerId', help = 'Id du joueur', type = 'player'}, {name = 'time', help = "Temps du ban (en heures)", type = "number"}, {name = "reason", help = "Raison du ban", type = "fullstring"}}}, false)

MadeInFrance.RegisterCommand('banreload', 4, function(player, args, showError, rawCommand)
    Shared.Anticheat.ReloadFromDatabase()
    showError('La banlist a été rechargée')
end, {help = "Permet de recharger la liste des bans", validate = false, arguments = {}}, true)

MadeInFrance.RegisterCommand('unban', 1, function(player, args, showError, rawCommand)
	local id = args.id
	if id then
		Shared.Anticheat.Unban(id)
		Shared.Anticheat.ReloadFromDatabase()
	end
end, {help = "Permet de débannir un joueur", validate = false, arguments = {{name = 'id', help = 'ID du bannissement', type = 'number'}}}, true)

MadeInFrance.RegisterCommand('giveitem', 1, function(player, args, showError, rawCommand)
	local item = args.item
	local quantity = args.quantity or 1
	local targetPlayer = args.playerId

	if item and targetPlayer then
		if item == 'money' or item == 'dirty' then
			if item == 'money' then
				MadeInFrance.Money.AddPlayerMoney(targetPlayer, quantity)
				MadeInFrance.SendEventToClient('notify', targetPlayer.source, 'Inventaire', 'Vous avez reçu ' .. quantity .. '$', 'success')
			elseif item == 'dirty' then
				MadeInFrance.Money.AddPlayerDirtyMoney(targetPlayer, quantity)
				MadeInFrance.SendEventToClient('notify', targetPlayer.source, 'Inventaire', 'Vous avez reçu ' .. quantity .. '$', 'success')
			end
			return
		end

		if string.match(item, 'food_') then
			if MadeInFrance.Inventory.CanCarryItem(targetPlayer, item, quantity) then
				dataFood = {
					durability = 100
				}
				MadeInFrance.Inventory.AddItemInInventory(targetPlayer, item, quantity, nil, nil, dataFood)
				MadeInFrance.SendEventToClient('notify', targetPlayer.source, 'Inventaire', 'Vous avez reçu ' .. quantity .. 'x ' .. MadeInFrance.Inventory.GetInfosItem(item).label, 'success')
			else
				showError('Vous ne pouvez pas porter + de cet item.')
			end
			return
        end


		if not string.match(item, 'weapon_') then
			if MadeInFrance.Inventory.CanCarryItem(targetPlayer, item, quantity) then
				MadeInFrance.Inventory.AddItemInInventory(targetPlayer, item, quantity)
				MadeInFrance.SendEventToClient('notify', targetPlayer.source, 'Inventaire', 'Vous avez reçu ' .. quantity .. 'x ' .. MadeInFrance.Inventory.GetInfosItem(item).label, 'success')
			else
				showError('Vous ne pouvez pas porter + de cet item.')
			end
		else
			if MadeInFrance.Inventory.CanCarryItem(targetPlayer, item, quantity) then
				data = {
					ammo = 0,
					components = {},
					serialNumber = MadeInFrance.GenerateNumeroDeSerie()
				}
				MadeInFrance.Inventory.AddItemInInventory(targetPlayer, item, quantity, nil, nil, data)
				MadeInFrance.SendEventToClient('notify', targetPlayer.source, 'Inventaire', 'Vous avez reçu ' .. quantity .. 'x ' .. MadeInFrance.Inventory.GetInfosItem(item).label, 'success')
			else
				showError('Vous ne pouvez pas porter + de cet item.')
			end
		end
	else
		showError('Veuillez spécifier un item et un joueur cible.')
	end
end, {help = "Permet de donner un item à un joueur", validate = false, arguments = {{name = 'playerId', help = 'ID du joueur cible', type = 'player'}, {name = 'item', help = 'Nom de l\'item', type = 'string'}, {name = 'quantity', help = 'Quantité de l\'item', type = 'number'}}}, false)

MadeInFrance.RegisterCommand('car', 1, function(player, args, showError, rawCommand)
    local modelName = args.model
    if not modelName or modelName == "" then
        showError("Vous devez spécifier un modèle de véhicule.")
        return
    end

    local playerPed = GetPlayerPed(player.source)
    local pos = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    local success, vehicleOrError = MadeInFrance.AP.SpawnPersistentVehicle(modelName, pos, heading, player.source)
    if success then
        MadeInFrance.SendEventToClient('notify', player.source, 'Véhicule', 'Votre véhicule a été spawn.', 'success')
    else
        showError(vehicleOrError)
    end
end,
{
    help = "Spawn un véhicule devant vous",
    validate = true,
    arguments = {{name = 'model', help = "Nom du modèle du véhicule", type = 'string'}}
}, false)

