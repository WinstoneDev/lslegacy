RegisterCommand('tpm', function()
    local entity = PlayerPedId()
    local success = false
    local blipFound = false
    local blipIterator = GetBlipInfoIdIterator()
    local blip = GetFirstBlipInfoId(8)

    if IsPedInAnyVehicle(entity, false) then
        entity = GetVehiclePedIsUsing(entity)
    end

    while DoesBlipExist(blip) do
        if GetBlipInfoIdType(blip) == 4 then
            cx, cy, cz = table.unpack(Citizen.InvokeNative(0xFA7C7F0AADF25D09, blip, Citizen.ReturnResultAnyway(), Citizen.ResultAsVector()))
            blipFound = true
            break
        end
        blip = GetNextBlipInfoId(blipIterator)
        Wait(0)
    end
        
    if blipFound then
        local groundFound = false
        local yaw = GetEntityHeading(entity)
        
        for i = 0, 1000, 1 do
            SetEntityCoordsNoOffset(entity, cx, cy, ToFloat(i), false, false, false)
            SetEntityRotation(entity, 0, 0, 0, 0, 0)
            SetEntityHeading(entity, yaw)
            SetGameplayCamRelativeHeading(0)
            Wait(0)
            if GetGroundZFor_3dCoord(cx, cy, ToFloat(i), cz, false) then
                cz = ToFloat(i)
                groundFound = true
                break
            end
        end
        if not groundFound then
            cz = -300.0
        end
        success = true
    else
        success = false
    end
        
    if success then
        SetEntityCoordsNoOffset(entity, cx, cy, cz, false, false, true)
        SetGameplayCamRelativeHeading(0)
        if IsPedSittingInAnyVehicle(PlayerPedId()) then
            if GetPedInVehicleSeat(GetVehiclePedIsUsing(PlayerPedId()), -1) == PlayerPedId() then
                SetVehicleOnGroundProperly(GetVehiclePedIsUsing(PlayerPedId()))
            end
        end
    end
end)

RegisterCommand("car", function(source, args, rawCommand)
    RequestModel(GetHashKey(args[1]))
    while not HasModelLoaded(GetHashKey(args[1])) do
        Wait(1)
    end
    local pPed = PlayerPedId()
    local veh = CreateVehicle(GetHashKey(args[1]), GetEntityCoords(pPed), GetEntityHeading(pPed), 1, 0)
    TaskWarpPedIntoVehicle(pPed, veh, -1)
end, false)

RegisterCommand("revive", function(source, args, rawCommand)
    local pPed = PlayerPedId()
    ReviveInjuredPed(pPed)
    NetworkResurrectLocalPlayer(GetEntityCoords(pPed), 100.0, 0, 0)
end, false)

RegisterCommand("time", function(source, args, rawCommand)
    local weather = "EXTRASUNNY"
    SetWeatherTypeOverTime(weather, 15.0)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypePersist(weather)
    SetWeatherTypeNow(weather)
    SetWeatherTypeNowPersist(weather)
    NetworkOverrideClockTime(tonumber(args[1]), 00, 0)
end)

GetVehiclesInArea = function(coords, area)
	local vehicles       = ESX.Game.GetVehicles()
	local vehiclesInArea = {}

	for i=1, #vehicles, 1 do
		local vehicleCoords = GetEntityCoords(vehicles[i])
		local distance      = GetDistanceBetweenCoords(vehicleCoords, coords.x, coords.y, coords.z, true)

		if distance <= area then
			table.insert(vehiclesInArea, vehicles[i])
		end
	end

	return vehiclesInArea
end

RegisterCommand("dv", function(source, args, rawCommand)
	local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if DoesEntityExist(vehicle) and NetworkHasControlOfEntity(vehicle) then
        SetEntityAsMissionEntity(vehicle, false, true)
        DeleteVehicle(vehicle)
    end
end)

RegisterCommand('pos', function()
    Config.Development.Print(GetEntityCoords(PlayerPedId()))
    Config.Development.Print(GetEntityHeading(PlayerPedId()))
end)

-- -- Afficher/mettre à jour le HUD natif "Cash / Bank"
-- local function setNativeMoney(cash, bank, showMs)
--     -- 1) on met à jour les stats
--     StatSetInt(`MP0_WALLET_BALANCE`, cash or 0, true) -- portefeuille
--     StatSetInt(`BANK_BALANCE`, bank or 0, true)       -- banque

--     -- 2) on déclenche l’affichage du HUD natif pour qq secondes
--     Citizen.InvokeNative(0x170F541E1CADD1DE, true) -- (wrapper utilisé par Rockstar)
--     SetMultiplayerWalletCash()
--     SetMultiplayerBankCash()
--     Citizen.InvokeNative(0x170F541E1CADD1DE, false)

--     -- 3) garder le HUD visible un moment si tu veux
--     local untilTime = GetGameTimer() + (showMs or 5000)
--     CreateThread(function()
--         while GetGameTimer() < untilTime do
--             Wait(0)
--             DisplayCash(true)               -- autorise le rendu du cash
--             ShowHudComponentThisFrame(4)    -- composant HUD "MP cash"
--         end
--         RemoveMultiplayerWalletCash()
--         RemoveMultiplayerBankCash()
--     end)
-- end

-- -- Exemple de commande: /setmoney 1500 20000
-- RegisterCommand('setmoney', function(_, args)
--     setNativeMoney(tonumber(args[1]) or 0, tonumber(args[2]) or 0, 5000)
-- end)

-- -- Pour montrer juste une notif de variation (+$ / bank) sans tout réafficher :
-- -- /cashdelta 500 -1000  → +500 cash, -1000 bank (animation en haut-droite)
-- RegisterCommand('cashdelta', function(_, args)
--     ChangeFakeMpCash(tonumber(args[1]) or 0, tonumber(args[2]) or 0)
-- end)