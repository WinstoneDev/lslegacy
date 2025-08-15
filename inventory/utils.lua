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
        MadeInFrance.ShowNotification(nil, "Il n'y a aucune personne aux alentours de vous.", 'error')
        return false
    end

    if #pSelected == 1 then
        return pSelected[1]
    end

    MadeInFrance.ShowNotification(nil, "Appuyer sur E pour valider~n~Appuyer sur A pour changer de cible~n~Appuyer sur X pour annuler", 'info')
    Citizen.Wait(100)
    local pSelect = 1
    while GetGameTimer() <= Timer do
        Citizen.Wait(0)
        DisableControlAction(0, 38, true)
        DisableControlAction(0, 73, true)
        DisableControlAction(0, 44, true)
        if IsDisabledControlJustPressed(0, 38) then
            return pSelected[pSelect]
        elseif IsDisabledControlJustPressed(0, 73) then
            MadeInFrance.ShowNotification(nil, "Vous avez annulé cette action", 'success')
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