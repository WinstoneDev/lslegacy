Offline.Commands = {}

---RegisterCommand
---@type function
---@param name string
---@param group number
---@param callback function
---@param suggestion table
---@param console boolean
---@return void
---@public
Offline.Commands.RegisterCommand = function(name, group, callback, suggestion, console)
    if not name or not callback then
        return 
    end

    if not Offline.Commands[name] then
        if suggestion then
            if not suggestion.arguments then suggestion.arguments = {} end
            if not suggestion.help then suggestion.help = '' end
    
            TriggerClientEvent('chat:addSuggestion', -1, ('/%s'):format(name), suggestion.help, suggestion.arguments)
        end
        
        Offline.Commands[name] = {
            group = group,
            callback = callback,
            console = console,
            suggestion = suggestion
        }

        Config.Development.Print('Command ' .. name .. ' registered')

        RegisterCommand(name, function(source, args, rawCommand)
            local command = Offline.Commands[name]
            if source == 0 and not command.console then
                return Config.Development.Print("Command " .. name .. " cannot be executed from console.")
            end

            local player = Offline.GetPlayerFromId(source)

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
									local xTargetPlayer = Offline.GetPlayerFromId(targetPlayer)

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
                    Offline.SendEventToClient('chat:addMessage', player.source, {args = {'^1Offline', error}})
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
                                        Offline.SendEventToClient('chat:addMessage', player.source, {args = {'^1Offline', msg}})
                                    end
                                end, rawCommand)
                            else
                                Offline.SendEventToClient('chat:addMessage', player.source, {args = {'^1Offline', 'Vous n\'avez pas les permissions pour utiliser cette commande'}})
                            end
                        end
                    end
				elseif source == 0 then
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

Offline.Commands.RegisterCommand('clear', 0, function(player, args, showError, rawCommand)
	Offline.SendEventToClient('chat:clear', player.source)
end, {help = "Clear le chat"}, false)

Offline.Commands.RegisterCommand('clearall', 3, function(player, args, showError, rawCommand)
	Offline.SendEventToClient('chat:clear', -1)
end, {help = "Clear le chat pour tout le monde"}, false)

Offline.Commands.RegisterCommand('announce', 3, function(player, args, showError, rawCommand)
	Offline.SendEventToClient('offline:notify', -1, '~b~Annonce Serveur~s~\n'..table.concat(args, " "))
end, {help = "Affiche un message pour tout le serveur", validate = true, arguments = {{name = 'message', help = 'Message', type = 'fullstring'}}}, false)

Offline.Commands.RegisterCommand('kick', 1, function(player, args, showError, rawCommand)
	local player = args.playerId
	if player then
		sm = Offline.StringSplit(rawCommand, " ")
		message = ""
		for i = 3, #sm do
			message = message ..sm[i].. " "
		end
		DropPlayer(player.source, message .. ' (kick par ' .. player.name .. ')')
	end
end, {help = "Permet de déconnecter un joueur", validate = false, arguments = {{name = 'playerId', help = 'Id du joueur', type = 'player'}, {name = 'reason', help = "Raison du kick", type = "fullstring"}}}, false)