MadeInFrance.RegisterClientEvent('zones:registerBlips', function(zones)
    for name, zone in pairs(zones) do
        if zone.drawBlip then
            Config.Development.Print("Registering blip " .. zone.blipInfos.blipName)
            MadeInFrance.AddBlip(zone.blipInfos.blipName, zone.blipInfos.blipSprite, zone.blipInfos.blipColor, zone.blipInfos.blipScale, zone.coords)
        end
    end
end)

local pedEntity = nil

MadeInFrance.RegisterClientEvent('zones:enteredZone', function(zone)
    if zone.drawPed then
        pedEntity = NetworkGetEntityFromNetworkId(zone.pedNetId)
        if DoesEntityExist(pedEntity) then
            SetPedHearingRange(pedEntity, 0.0)
            SetPedSeeingRange(pedEntity, 0.0)
            SetEntityInvincible(pedEntity, true)
            SetPedAlertness(pedEntity, 0.0)
            FreezeEntityPosition(pedEntity, true) 
            SetPedFleeAttributes(pedEntity, 0, 0)
            SetBlockingOfNonTemporaryEvents(pedEntity, true)
            SetPedCombatAttributes(pedEntity, 46, true)
            SetPedFleeAttributes(pedEntity, 0, 0)
            if zone.pedInfos.scenario then
                ClearPedTasksImmediately(pedEntity)
                TaskStartScenarioInPlace(pedEntity, zone.pedInfos.scenario.anim, 0, true)
            end
        end
    end
    while true do 
        local coords = GetEntityCoords(PlayerPedId())
        local dist = GetDistanceBetweenCoords(coords, zone.coords, true)
        if dist <= zone.drawDist then
            if zone.drawMarker then
                MadeInFrance.DrawMarker(zone.markerInfos.markerType, zone.coords, zone.markerInfos.markerColor.r, zone.markerInfos.markerColor.g, zone.markerInfos.markerColor.b, zone.markerInfos.markerColor.a)
            end
            if zone.drawNotification then
                if dist <= zone.notificationInfos.drawNotificationDistance and not RageUI.GetInMenu() then
                    MadeInFrance.DisplayInteract(zone.notificationInfos.notificationMessage)
                    if IsControlJustPressed(0, 51) then
                        MadeInFrance.SendEventToServer('zones:haveInteract', zone.name)
                    end
                end
            end
            if zone.drawPed then
                if dist <= zone.pedInfos.drawDistName then
                    if DoesEntityExist(pedEntity) then
                        MadeInFrance.DrawText3D(zone.pedInfos.coords.x, zone.pedInfos.coords.y, zone.pedInfos.coords.z + 1.9, zone.pedInfos.pedName, 5)
                    end
                end
            end
        else
            pedEntity = nil
            MadeInFrance.SendEventToServer('madeinfrance:haveExitedZone')
            RageUI.CloseAll()
            break
        end
        Wait(0)
    end
end)