LSLegacy.Commands = {}

---RegisterCommand
---@type function
---@param name string
---@param group number
---@param callback function
---@param suggestion table
---@param console boolean
---@return void
---@public
LSLegacy.RegisterCommand = function(name, group, callback, suggestion, console)
    if not name or not callback then
        return 
    end

    if not LSLegacy.Commands[name] then
        if suggestion then
            if not suggestion.arguments then suggestion.arguments = {} end
            if not suggestion.help then suggestion.help = '' end
    
            TriggerClientEvent('chat:addSuggestion', -1, ('/%s'):format(name), suggestion.help, suggestion.arguments)
        end
        
        LSLegacy.Commands[name] = {
            group = group,
            callback = callback,
            console = console,
            suggestion = suggestion
        }

        Config.Development.Print('Command ' .. name .. ' registered')

        RegisterCommand(name, function(source, args, rawCommand)
            local command = LSLegacy.Commands[name]
            if source == 0 and not command.console then
                return Config.Development.Print("Command " .. name .. " cannot be executed from console.")
            end

            local player = LSLegacy.GetPlayerFromId(source)

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
									local xTargetPlayer = LSLegacy.GetPlayerFromId(targetPlayer)

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
                    LSLegacy.SendEventToClient('notify', player.source, 'LSLegacy', error, 'error')
				end
			else
                if source ~= 0 and player ~= nil then
                    if LSLegacy.Permissions.Has(player, command.group) then
                        command.callback(player or false, args, function(msg)
                            if source == 0 and command.console then
                                Config.Development.Print(msg)
                            else
                                LSLegacy.SendEventToClient('notify', player.source, 'LSLegacy', msg, 'success')
                            end
                        end, rawCommand)
                    else
                        LSLegacy.SendEventToClient('notify', player.source, 'LSLegacy', "Vous n'avez pas les permissions pour utiliser cette commande", 'error')
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

LSLegacy.RegisterCommand('clear', 0, function(player, args, showError, rawCommand)
	LSLegacy.SendEventToClient('chat:clear', player.source)
end, {help = "Clear le chat"}, false)

LSLegacy.RegisterCommand('clearall', 1, function(player, args, showError, rawCommand)
	LSLegacy.SendEventToClient('chat:clear', -1)
end, {help = "Clear le chat pour tout le monde"}, false)

LSLegacy.RegisterCommand('announce', 2, function(player, args, showError, rawCommand)
	local text = ""
    sm = LSLegacy.StringSplit(rawCommand, " ")
    for i = 2, #sm do
        text = text ..sm[i].. " " 
    end
	LSLegacy.SendEventToClient('notify', -1, 'Administration', text, 'warning')
end, {help = "Affiche un message pour tout le serveur", validate = false, arguments = {{name = 'message', help = 'Message', type = 'fullstring'}}}, true)

LSLegacy.RegisterCommand('kick', 2, function(player, args, showError, rawCommand)
	local player = args.playerId
	if player then
		sm = LSLegacy.StringSplit(rawCommand, " ")
		message = ""
		for i = 3, #sm do
			message = message ..sm[i].. " "
		end
		DropPlayer(player.source, message .. ' (kick par ' .. player.name .. ')')
	end
end, {help = "Permet de déconnecter un joueur", validate = false, arguments = {{name = 'playerId', help = 'Id du joueur', type = 'player'}, {name = 'reason', help = "Raison du kick", type = "fullstring"}}}, true)

LSLegacy.RegisterCommand('sync', 0, function(player, args, showError, rawCommand)
	local source = player.source
	MySQL.Async.execute('UPDATE players SET coords = @coords, inventory = @inventory, money = @money, health = @health, skin = @skin, status = @status, skills = @skills, job = @job, job_grade = @job_grade, faction = @faction, faction_grade = @faction_grade WHERE `boutique-id` = @id', {
        ['@coords'] = json.encode(LSLegacy.GetEntityCoords(source)),
        ['@inventory'] = json.encode(LSLegacy.ServerPlayers[source].inventory),
        ['@money'] = json.encode({cash = LSLegacy.ServerPlayers[source].cash, dirty = LSLegacy.ServerPlayers[source].dirty}),
        ['@id'] = LSLegacy.ServerPlayers[source]["boutique-id"],
        ['@health'] = GetEntityHealth(GetPlayerPed(source)),
		['@skin'] = json.encode(LSLegacy.ServerPlayers[source].skin),
		['@status'] = json.encode(LSLegacy.ServerPlayers[source].status),
		['@skills'] = json.encode(LSLegacy.ServerPlayers[source].skills),
		['@job'] = LSLegacy.ServerPlayers[source].job,
		['@job_grade'] = LSLegacy.ServerPlayers[source].job_grade,
		['@faction'] = LSLegacy.ServerPlayers[source].faction,
		['@faction_grade'] = LSLegacy.ServerPlayers[source].faction_grade
    })
	LSLegacy.SendEventToClient('UpdateServerPlayer', source)
	LSLegacy.SendEventToClient('UpdateDatastore', source, LSLegacy.DataStore)
	Wait(500)
	LSLegacy.SendEventToClient('UpdatePlayer', source, LSLegacy.ServerPlayers[source])
	LSLegacy.SendEventToClient('notify', source, 'Sync', 'Vous avez bien synchronisé votre personnage.', 'success')
end, {help = "Permet de synchroniser son joueur"}, false)

LSLegacy.RegisterCommand('debug', 0, function(player, args, showError, rawCommand)
	local source = player.source
	LSLegacy.SendEventToClient('debug', source)
	LSLegacy.SendEventToClient('notify', source, nil, 'Vous avez bien débug votre personnage.', 'success')
end, {help = "Permet de débug son joueur"}, false)

LSLegacy.RegisterCommand('ban', 2, function(player, args, showError, rawCommand)
    local player = args.playerId
    local reason = ""
    sm = LSLegacy.StringSplit(rawCommand, " ")
    for i = 4, #sm do
        reason = reason ..sm[i].. " " 
    end
    Shared.Anticheat.BanPlayer(player, args.time, reason, player.source)
end, {help = "Permet de bannir un joueur", validate = false, arguments = {{name = 'playerId', help = 'Id du joueur', type = 'player'}, {name = 'time', help = "Temps du ban (en heures)", type = "number"}, {name = "reason", help = "Raison du ban", type = "fullstring"}}}, true)

LSLegacy.RegisterCommand('banreload', 3, function(player, args, showError, rawCommand)
    Shared.Anticheat.ReloadFromDatabase()
    showError('La banlist a été rechargée')
end, {help = "Permet de recharger la liste des bans", validate = false, arguments = {}}, true)

LSLegacy.RegisterCommand('unban', 3, function(player, args, showError, rawCommand)
	local id = args.id
	if id then
		Shared.Anticheat.Unban(id)
		Shared.Anticheat.ReloadFromDatabase()
	end
end, {help = "Permet de débannir un joueur", validate = false, arguments = {{name = 'id', help = 'ID du bannissement', type = 'number'}}}, true)

LSLegacy.RegisterCommand('giveitem', 3, function(player, args, showError, rawCommand)
	local item = args.item
	local quantity = args.quantity or 1
	local targetPlayer = args.playerId

	if item and targetPlayer then

		if string.match(item, 'food_') then
			if LSLegacy.Inventory.CanCarryItem(targetPlayer, item, quantity) then
				dataFood = {
					durability = 100
				}
				LSLegacy.Inventory.AddItemInInventory(targetPlayer, item, quantity, nil, nil, dataFood)
				LSLegacy.SendEventToClient('notify', targetPlayer.source, 'Inventaire', 'Vous avez reçu ' .. quantity .. 'x ' .. LSLegacy.Inventory.GetInfosItem(item).label, 'success')
			else
				showError('Vous ne pouvez pas porter + de cet item.')
			end
			return
        end


		if not string.match(item, 'weapon_') then
			if LSLegacy.Inventory.CanCarryItem(targetPlayer, item, quantity) then
				LSLegacy.Inventory.AddItemInInventory(targetPlayer, item, quantity)
				LSLegacy.SendEventToClient('notify', targetPlayer.source, 'Inventaire', 'Vous avez reçu ' .. quantity .. 'x ' .. LSLegacy.Inventory.GetInfosItem(item).label, 'success')
			else
				showError('Vous ne pouvez pas porter + de cet item.')
			end
		else
			if LSLegacy.Inventory.CanCarryItem(targetPlayer, item, quantity) then
				data = {
					ammo = 0,
					components = {},
					serialNumber = LSLegacy.GenerateNumeroDeSerie()
				}
				LSLegacy.Inventory.AddItemInInventory(targetPlayer, item, quantity, nil, nil, data)
				LSLegacy.SendEventToClient('notify', targetPlayer.source, 'Inventaire', 'Vous avez reçu ' .. quantity .. 'x ' .. LSLegacy.Inventory.GetInfosItem(item).label, 'success')
			else
				showError('Vous ne pouvez pas porter + de cet item.')
			end
		end
	else
		showError('Veuillez spécifier un item et un joueur cible.')
	end
end, {help = "Permet de donner un item à un joueur", validate = true, arguments = {{name = 'playerId', help = 'ID du joueur cible', type = 'player'}, {name = 'item', help = 'Nom de l\'item', type = 'string'}, {name = 'quantity', help = 'Quantité de l\'item', type = 'number'}}}, true)

LSLegacy.RegisterCommand('car', 3, function(player, args, showError, rawCommand)
    local modelName = args.model
    if not modelName or modelName == "" then
        showError("Vous devez spécifier un modèle de véhicule.")
        return
    end

    local playerPed = GetPlayerPed(player.source)
    local pos = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    LSLegacy.AP.SpawnPersistentVehicle(modelName, pos, heading, player.source)
    LSLegacy.SendEventToClient('notify', player.source, 'Véhicule', 'Votre véhicule a été spawn.', 'success')
end,
{
    help = "Spawn un véhicule devant vous",
    validate = true,
    arguments = {{name = 'model', help = "Nom du modèle du véhicule", type = 'string'}}
}, false)

LSLegacy.RegisterCommand('tpm', 3, function(player, args, showError, rawCommand)
    LSLegacy.SendEventToClient('admin:doTpm', player.source)
end, {help = "Téléportation au marqueur de la carte"}, false)

LSLegacy.RegisterCommand('pos', 0, function(player, args, showError, rawCommand)
    local coords = LSLegacy.GetEntityCoords(player.source)
    local heading = GetEntityHeading(GetPlayerPed(player.source))
    LSLegacy.SendEventToClient('admin:showPos', player.source, coords.x, coords.y, coords.z, heading)
end, {help = "Affiche votre position actuelle"}, false)

LSLegacy.RegisterCommand('tp', 3, function(player, args, showError, rawCommand)
    local x, y, z = args.x, args.y, args.z
    SetEntityCoords(GetPlayerPed(player.source), x, y, z)
    LSLegacy.SendEventToClient('notify', player.source, 'Administration', 'Téléportation effectuée.', 'success')
end, {
    help = "Téléportation aux coordonnées",
    validate = true,
    arguments = {
        {name = 'x', help = 'Coordonnée X', type = 'number'},
        {name = 'y', help = 'Coordonnée Y', type = 'number'},
        {name = 'z', help = 'Coordonnée Z', type = 'number'}
    }
}, false)

LSLegacy.RegisterCommand('goto', 2, function(player, args, showError, rawCommand)
	local targetPlayer = args.playerId
	if not targetPlayer then
		showError('Veuillez spécifier un joueur cible.')
		return
	end
	local coords = GetEntityCoords(GetPlayerPed(targetPlayer.source))
	SetEntityCoords(GetPlayerPed(player.source), coords.x, coords.y, coords.z)
	LSLegacy.SendEventToClient('notify', player.source, 'Administration', 'Téléporté vers le joueur ' .. targetPlayer.source .. '.', 'success')
end, {help = "Téléporte vous vers un joueur", validate = true, arguments = {{name = 'playerId', help = 'ID du joueur cible', type = 'player'}}}, false)

LSLegacy.RegisterCommand('bring', 2, function(player, args, showError, rawCommand)
	local targetPlayer = args.playerId
	if not targetPlayer then
		showError('Veuillez spécifier un joueur cible.')
		return
	end
	local coords = GetEntityCoords(GetPlayerPed(player.source))
	SetEntityCoords(GetPlayerPed(targetPlayer.source), coords.x, coords.y + 1.5, coords.z)
	LSLegacy.SendEventToClient('notify', targetPlayer.source, 'Administration', 'Vous avez été téléporté par un membre du staff.', 'warning')
end, {help = "Téléporte un joueur vers vous", validate = true, arguments = {{name = 'playerId', help = 'ID du joueur cible', type = 'player'}}}, false)

LSLegacy.RegisterCommand('revive', 2, function(player, args, showError, rawCommand)
	local targetPlayer = args.playerId
	if not targetPlayer then
		showError('Veuillez spécifier un joueur cible.')
		return
	end
	if LSLegacy.Injury then LSLegacy.Injury.ClearState(targetPlayer.source) end
	LSLegacy.SendEventToClient('admin:revive', targetPlayer.source)
	LSLegacy.SendEventToClient('notify', targetPlayer.source, 'Administration', 'Vous avez été réanimé.', 'success')
end, {help = "Réanime un joueur", validate = true, arguments = {{name = 'playerId', help = 'ID du joueur cible', type = 'player'}}}, false)

LSLegacy.RegisterCommand('heal', 2, function(player, args, showError, rawCommand)
	local targetPlayer = args.playerId
	if not targetPlayer then
		showError('Veuillez spécifier un joueur cible.')
		return
	end
	if LSLegacy.Injury then LSLegacy.Injury.ClearState(targetPlayer.source) end
	LSLegacy.SendEventToClient('notify', targetPlayer.source, 'Administration', 'Vous avez été soigné.', 'success')
end, {help = "Soigne un joueur", validate = true, arguments = {{name = 'playerId', help = 'ID du joueur cible', type = 'player'}}}, false)

LSLegacy.RegisterCommand('freeze', 2, function(player, args, showError, rawCommand)
	local targetPlayer = args.playerId
	if not targetPlayer then
		showError('Veuillez spécifier un joueur cible.')
		return
	end
	LSLegacy.SendEventToClient('admin:setFreeze', targetPlayer.source, true)
	LSLegacy.SendEventToClient('notify', targetPlayer.source, 'Administration', 'Vous avez été freeze.', 'warning')
end, {help = "Freeze un joueur", validate = true, arguments = {{name = 'playerId', help = 'ID du joueur cible', type = 'player'}}}, false)

LSLegacy.RegisterCommand('unfreeze', 2, function(player, args, showError, rawCommand)
	local targetPlayer = args.playerId
	if not targetPlayer then
		showError('Veuillez spécifier un joueur cible.')
		return
	end
	LSLegacy.SendEventToClient('admin:setFreeze', targetPlayer.source, false)
	LSLegacy.SendEventToClient('notify', targetPlayer.source, 'Administration', 'Vous avez été unfreeze.', 'warning')
end, {help = "Unfreeze un joueur", validate = true, arguments = {{name = 'playerId', help = 'ID du joueur cible', type = 'player'}}}, false)

LSLegacy.RegisterCommand('setjob', 2, function(player, args, showError, rawCommand)
	local targetPlayer = args.playerId
	local job = args.job
	local grade = args.grade

	if targetPlayer and job and grade then
		if LSLegacy.Jobs.DoesJobExist(job) and LSLegacy.Jobs.DoesJobGradeExist(job, grade) then
			LSLegacy.Jobs.SetJob(targetPlayer, job)
			LSLegacy.Jobs.SetJobGrade(targetPlayer, grade)
			LSLegacy.SendEventToClient('notify', targetPlayer.source, nil, 'Votre métier a été mis à jour en ' .. LSLegacy.Jobs.GetJobLabel(job) .. ' - ' .. LSLegacy.Jobs.GetJobGradeLabel(job, grade) .. '.', 'success')
			showError('Le métier du joueur a été mis à jour.')
		else
			showError('Le métier ou le grade spécifié n\'existe pas.')
		end
	else
		showError('Veuillez spécifier un joueur cible, un métier et un grade.')
	end
end, {
	help = "Permet de changer le métier d'un joueur",
	validate = true,
	arguments = {
		{name = 'playerId', help = 'ID du joueur cible', type = 'player'},
		{name = 'job', help = 'Nom du métier', type = 'string'},
		{name = 'grade', help = 'Grade du métier', type = 'number'}
	}
}, true)

LSLegacy.RegisterCommand('setfaction', 2, function(player, args, showError, rawCommand)
	local targetPlayer = args.playerId
	local faction = args.faction
	local grade = args.grade

	if targetPlayer and faction and grade then
		if LSLegacy.Jobs.DoesFactionExist(faction) and LSLegacy.Jobs.DoesFactionGradeExist(faction, grade) then
			LSLegacy.Jobs.SetFaction(targetPlayer, faction)
			LSLegacy.Jobs.SetFactionGrade(targetPlayer, grade)
			LSLegacy.SendEventToClient('notify', targetPlayer.source, nil, 'Votre faction a été mis à jour en ' .. LSLegacy.Jobs.GetFactionLabel(faction) .. ' - ' .. LSLegacy.Jobs.GetFactionGradeLabel(faction, grade) .. '.', 'success')
			showError('La faction du joueur a été mis à jour.')
		else
			showError('La faction ou le grade spécifié n\'existe pas.')
		end
	else
		showError('Veuillez spécifier un joueur cible, une faction et un grade.')
	end
end, {
	help = "Permet de changer la faction d'un joueur",
	validate = true,
	arguments = {
		{name = 'playerId', help = 'ID du joueur cible', type = 'player'},
		{name = 'faction', help = 'Nom de la faction', type = 'string'},
		{name = 'grade', help = 'Grade de la faction', type = 'number'}
	}
}, true)