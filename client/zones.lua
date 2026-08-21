LSLegacy.RegisterClientEvent('zones:registerBlips', function(zones)
    for name, zone in pairs(zones) do
        if zone.drawBlip then
            Config.Development.Print("Registering blip " .. zone.blipInfos.blipName)

            LSLegacy.AddBlip(
                zone.blipInfos.blipName,
                zone.blipInfos.blipSprite,
                zone.blipInfos.blipColor,
                zone.blipInfos.blipScale,
                zone.coords
            )
        end
    end
end)

LSLegacy.PedsZones = {}
LSLegacy.ActiveZones = {}
LSLegacy.ZoneDynamicState = LSLegacy.ZoneDynamicState or {}

LSLegacy.RegisterClientEvent('SpawnPedZone', function(hash, coords, zone)
    if not hash or not coords or not zone then return end

    if not LSLegacy.PedsZones[zone] then
        LSLegacy.PedsZones[zone] = {}
    end

    local pedHash = GetHashKey(hash)

    RequestModel(pedHash)

    while not HasModelLoaded(pedHash) do
        Wait(0)
    end

    local ped = CreatePed(
        4,
        pedHash,
        coords.x,
        coords.y,
        coords.z,
        coords.w or 0.0,
        false,
        true
    )

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)

    LSLegacy.PedsZones[zone].ped = ped

    SetModelAsNoLongerNeeded(pedHash)
end)

LSLegacy.RegisterClientEvent('zones:updateZoneState', function(name, state)
    LSLegacy.ZoneDynamicState[name] = state
end)

LSLegacy.RegisterClientEvent('zones:exitedZone', function(zoneName)
    LSLegacy.ActiveZones[zoneName] = nil
    LSLegacy.ZoneDynamicState[zoneName] = nil

    pedEntity = nil

    RageUI.CloseAll()
end)

LSLegacy.RegisterClientEvent('zones:enteredZone', function(zone)
    if not zone or not zone.name then return end

    -- Protection contre plusieurs threads pour la même zone
    if LSLegacy.ActiveZones[zone.name] then
        return
    end

    LSLegacy.ActiveZones[zone.name] = true
    LSLegacy.ZoneDynamicState[zone.name] = nil

    if zone.drawPed then
        local zonePed = LSLegacy.PedsZones[zone.name]

        if zonePed then
            pedEntity = zonePed.ped

            if DoesEntityExist(pedEntity) then
                SetPedHearingRange(pedEntity, 0.0)
                SetPedSeeingRange(pedEntity, 0.0)
                SetEntityInvincible(pedEntity, true)
                SetPedAlertness(pedEntity, 0.0)
                FreezeEntityPosition(pedEntity, true)
                SetPedFleeAttributes(pedEntity, 0, 0)
                SetBlockingOfNonTemporaryEvents(pedEntity, true)
                SetPedCombatAttributes(pedEntity, 46, true)

                if zone.pedInfos.scenario then
                    ClearPedTasksImmediately(pedEntity)

                    TaskStartScenarioInPlace(
                        pedEntity,
                        zone.pedInfos.scenario.anim,
                        0,
                        true
                    )
                end
            end
        end
    end

    while LSLegacy.ActiveZones[zone.name] do
        local coords = GetEntityCoords(PlayerPedId())
        local dist = GetDistanceBetweenCoords(coords, zone.coords, true)

        -- Sécurité supplémentaire côté client
        if dist > zone.drawDist then
            break
        end

        local dynState = LSLegacy.ZoneDynamicState[zone.name]
        local canInteract = not dynState or dynState.canInteract ~= false

        if canInteract then
            if zone.drawMarker then
                local color = (dynState and dynState.markerColor)
                    or zone.markerInfos.markerColor

                local scale = (dynState and dynState.markerScale)
                    or zone.markerInfos.markerScale

                LSLegacy.DrawMarker(
                    zone.markerInfos.markerType,
                    zone.coords,
                    color.r,
                    color.g,
                    color.b,
                    color.a,
                    scale
                )
            end

            if zone.drawNotification then
                if dist <= zone.notificationInfos.drawNotificationDistance
                    and not RageUI.GetInMenu()
                then
                    local message =
                        (dynState and dynState.notificationMessage)
                        or zone.notificationInfos.notificationMessage

                    LSLegacy.DisplayInteract(message)

                    if IsControlJustPressed(0, 51) then
                        LSLegacy.SendEventToServer(
                            'zones:haveInteract',
                            zone.name
                        )
                    end
                end
            end
        end

        if zone.drawPed then
            if dist <= zone.pedInfos.drawDistName then
                if DoesEntityExist(pedEntity) then
                    LSLegacy.DrawText3D(
                        zone.pedInfos.coords.x,
                        zone.pedInfos.coords.y,
                        zone.pedInfos.coords.z + 1.9,
                        zone.pedInfos.pedName,
                        5
                    )
                end
            end
        end

        Wait(0)
    end

    -- Le serveur gère officiellement la sortie.
    -- On nettoie seulement si le serveur n'a pas encore envoyé zones:exitedZone.
    if LSLegacy.ActiveZones[zone.name] then
        LSLegacy.ActiveZones[zone.name] = nil
        LSLegacy.ZoneDynamicState[zone.name] = nil

        pedEntity = nil

        RageUI.CloseAll()
    end
end)