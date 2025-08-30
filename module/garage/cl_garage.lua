function GetPlayers()
	local players = {}

	for _,player in ipairs(GetActivePlayers()) do
		local ped = GetPlayerPed(player)

		if DoesEntityExist(ped) then
			table.insert(players, player)
		end
	end

	return players
end

function GetNearbyPlayers(distance)
	local pPed = GetPlayerPed(-1)
	local pPedPos = GetEntityCoords(pPed)
	local nearbyPlayers = {}

	for key, value in pairs(GetPlayers()) do
		local xPed = GetPlayerPed(value)
		local xPedPos = xPed ~= pPed and IsEntityVisible(xPed) and GetEntityCoords(xPed)

		if xPedPos and GetDistanceBetweenCoords(xPedPos, pPedPos) <= distance then
            table.insert(nearbyPlayers, value)
		end
	end
	return nearbyPlayers
end

function GetNearbyPlayer(distance)
    local Timer = GetGameTimer() + 10000
    local pSelected = GetNearbyPlayers(distance)

    if #pSelected == 0 then
        LSLegacy.ShowNotification(nil, "Il n'y a aucune personne aux alentours de vous.", 'error')
        return false
    end

    if #pSelected == 1 then
        return pSelected[1]
    end

    LSLegacy.ShowNotification(nil, "Appuyer sur E pour valider~n~Appuyer sur A pour changer de cible~n~Appuyer sur X pour annuler", 'info')
    Wait(100)
    local pSelect = 1
    while GetGameTimer() <= Timer do
        Wait(0)
        DisableControlAction(0, 38, true)
        DisableControlAction(0, 73, true)
        DisableControlAction(0, 44, true)
        if IsDisabledControlJustPressed(0, 38) then
            return pSelected[pSelect]
        elseif IsDisabledControlJustPressed(0, 73) then
            LSLegacy.ShowNotification(nil, "Vous avez annulé cette action", 'success')
            break
        elseif IsDisabledControlJustPressed(0, 44) then
            pSelect = (pSelect == #pSelected) and 1 or (pSelect + 1)
        end
        local xPed = GetPlayerPed(pSelected[pSelect])
        local xPedPos = GetEntityCoords(xPed)
        DrawMarker(0, xPedPos.x, xPedPos.y, xPedPos.z + 1.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.1, 0.1, 0.1, 0, 180, 10, 30, 1, 1, 0, 0, 0, 0, 0)
    end
    return false
end

garagemenu = {
    opened = false,
    type = {"En extérieur", "IPL/MLO"},
    typeChosen = "En extérieur",
    typeIndex = 1,
    ownertype = {"Personnel", "Général", "Entreprise", "Organisation (Job2)"},
    ownertypeChosen = "Personnel",
    ownertypeIndex = 1,
    playerNameSelected = 'Aucun',
    jobSelected = 'Aucun',
    factionSelected = 'Aucune'
}

garagemenu.mainMenu = RageUI.CreateMenu("GarageCreator", "Création de garages")
garagemenu.mainMenu:DisplayGlare(true)
garagemenu.mainMenu.Closed = function()
    garagemenu.opened = false
    RageUI.Visible(garagemenu.mainMenu, false)
end

garagemenu.openMainMenu = function()
    if RageUI.GetInMenu() then
        RageUI.CloseAll()
    end
    if garagemenu.opened then
        garagemenu.opened = false
        RageUI.Visible(garagemenu.mainMenu, false)
    else
        garagemenu.opened = true
        RageUI.Visible(garagemenu.mainMenu, true)
    end
    CreateThread(function()
        while garagemenu.opened do
            RageUI.IsVisible(garagemenu.mainMenu, function()
                RageUI.Line()
                RageUI.Separator("↓ Bienvenue sur la création de garages ↓")
                RageUI.Line()
                RageUI.List("Type de garage", garagemenu.type, garagemenu.typeIndex, nil, {}, true, {
                    onListChange = function(Index)
                        garagemenu.typeIndex = Index
                        garagemenu.typeChosen = garagemenu.type[garagemenu.typeIndex]
                        LSLegacy.ShowNotification('Garage Creator', string.format("Type séléctionné : %s", garagemenu.typeChosen), 'info')
                    end,
                })
                RageUI.List("Type d'owner", garagemenu.ownertype, garagemenu.ownertypeIndex, nil, {}, true, {
                    onListChange = function(Index)
                        garagemenu.ownertypeIndex = Index
                        garagemenu.ownertypeChosen = garagemenu.ownertype[garagemenu.ownertypeIndex] 
                        LSLegacy.ShowNotification('Garage Creator', string.format("Type séléctionné : %s", garagemenu.ownertypeChosen), 'info')
                    end,
                })
                if garagemenu.typeIndex == 2 then
                    RageUI.Button("Choisir un MLO/IPL", nil, {RightLabel = "→"}, true, {})
                end
                if garagemenu.ownertypeIndex == 1 then
                    RageUI.Button(string.format("Choisir un joueur : %s", garagemenu.playerNameSelected), nil, {RightLabel = "→"}, true, {
                        onSelected = function()
                            local closestPlayer = GetNearbyPlayer(3.0)
                            if closestPlayer then
                                ESX.TriggerServerCallback('garageCreator:getPlayerName', function(playerName)
                                    if playerName then
                                        garagemenu.playerNameSelected = playerName
                                    else
                                        ESX.ShowNotification(Translate('error'))
                                    end 
                                end, GetPlayerServerId(closestPlayer))  
                            else
                                LSLegacy.ShowNotification('Garage Creator', 'Aucun joueur à proximité !', 'error')
                                ESX.TriggerServerCallback('garageCreator:getPlayerName', function(playerName)
                                    if playerName then
                                        garagemenu.playerNameSelected = playerName
                                    else
                                        LSLegacy.ShowNotification('Garage Creator', 'Erreur lors de la récupération du nom du joueur.', 'error')
                                    end 
                                end, GetPlayerServerId(PlayerId()))  
                            end
                        end
                    })
                end
                if garagemenu.ownertypeIndex == 3 then
                    RageUI.Button(string.format(Translate('choose_job'), garagemenu.jobSelected), nil, {RightLabel = "→"}, true, {})
                end
                if garagemenu.ownertypeIndex == 4 then
                    RageUI.Button(string.format(Translate('choose_job2'), garagemenu.factionSelected), nil, {RightLabel = "→"}, true, {})
                end
            end)

            Wait(1)
        end
    end)
end