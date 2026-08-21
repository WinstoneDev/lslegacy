---@class LSLegacy.RegisteredZones
LSLegacy.RegisteredZones = {}

---RegisterZone
---@type function
---@param name string
---@param coords table
---@param interactFunc function
---@param drawDist number
---@param drawMarker boolean
---@param markerInfos table markerType (integer), markerColor ({r,g,b,a}), markerScale (optional, {x,y,z} or number, default 0.7)
---@param drawBlip boolean
---@param blipInfos table
---@param drawNotification boolean
---@param notificationInfos table
---@param drawPed boolean
---@param pedInfos table
---@return any
---@public
LSLegacy.RegisterZone = function(
    name,
    coords,
    interactFunc,
    drawDist,
    drawMarker,
    markerInfos,
    drawBlip,
    blipInfos,
    drawNotification,
    notificationInfos,
    drawPed,
    pedInfos,
    canInteractFunc,
    dynamicFunc
)
    if not name then return end
    if not coords then return end
    if not interactFunc then return end
    if not drawDist then return end

    if not LSLegacy.RegisteredZones[name] then
        LSLegacy.RegisteredZones[name] = {
            name = name,
            coords = coords,
            interactFunc = interactFunc,
            drawDist = drawDist,
            drawMarker = drawMarker,
            markerInfos = markerInfos,
            drawBlip = drawBlip,
            blipInfos = blipInfos,
            drawNotification = drawNotification,
            notificationInfos = notificationInfos,
            drawPed = drawPed,
            pedInfos = pedInfos,
            canInteractFunc = canInteractFunc,
            dynamicFunc = dynamicFunc,
            lastDynamicPush = {}
        }

        Config.Development.Print(
            "Successfully registered zone " .. name
        )
    else
        return Config.Development.Print(
            "Zone " .. name .. " already registered"
        )
    end
end

LSLegacy.RegisterServerEvent('zones:haveInteract', function(zone)
    local _source = source

    Citizen.CreateThread(function()
        local registered = LSLegacy.RegisteredZones[zone]

        if not registered then
            return
        end

        if registered.canInteractFunc
            and not registered.canInteractFunc(_source)
        then
            return
        end

        if registered.interactFunc then
            registered.interactFunc(_source)
        end
    end)
end)

Citizen.CreateThread(function()
    Wait(15000)

    while true do
        for _, player in pairs(LSLegacy.ServerPlayers) do
            local coords = LSLegacy.GetEntityCoords(player.source)

            local foundZone = nil
            local foundZoneData = nil

            for name, zone in pairs(LSLegacy.RegisteredZones) do
                if #(coords - zone.coords) <= zone.drawDist then
                    foundZone = name
                    foundZoneData = zone

                    -- Entrée dans une nouvelle zone
                    if player.currentZone ~= name then
                        Config.Development.Print(
                            'Player '
                            .. player.source
                            .. ' entered zone '
                            .. name
                        )

                        player.currentZone = name

                        LSLegacy.SendEventToClient(
                            'zones:enteredZone',
                            player.source,
                            zone
                        )
                    end

                    -- Dynamic state
                    if zone.canInteractFunc or zone.dynamicFunc then
                        local now = GetGameTimer()
                        local last =
                            zone.lastDynamicPush[player.source] or 0

                        if now - last >= 1000 then
                            zone.lastDynamicPush[player.source] = now

                            local state = {}

                            if zone.canInteractFunc then
                                state.canInteract =
                                    zone.canInteractFunc(player.source)
                                    and true
                                    or false
                            end

                            if zone.dynamicFunc then
                                local dyn =
                                    zone.dynamicFunc(player.source) or {}

                                state.notificationMessage =
                                    dyn.notificationMessage

                                state.markerColor =
                                    dyn.markerColor

                                state.markerScale =
                                    dyn.markerScale
                            end

                            LSLegacy.SendEventToClient(
                                'zones:updateZoneState',
                                player.source,
                                name,
                                state
                            )
                        end
                    end

                    -- Une seule zone à la fois
                    break
                end
            end

            -- Joueur sorti de sa zone
            if not foundZone
                and player.currentZone
                and player.currentZone ~= "Aucune"
            then
                local oldZone = player.currentZone

                Config.Development.Print(
                    'Player '
                    .. player.source
                    .. ' exited zone '
                    .. oldZone
                )

                player.currentZone = "Aucune"

                -- Nettoyage du rate-limit dynamique
                local oldZoneData =
                    LSLegacy.RegisteredZones[oldZone]

                if oldZoneData then
                    oldZoneData.lastDynamicPush[player.source] = nil
                end

                LSLegacy.SendEventToClient(
                    'zones:exitedZone',
                    player.source,
                    oldZone
                )
            end
        end

        Wait(0)
    end
end)

---RegisterPeds
---@type function
---@param zones table
---@param source number
---@return any
---@public
LSLegacy.RegisterPeds = function(zones, source)
    for name, zone in pairs(zones) do
        if zone.drawPed then
            Config.Development.Print(
                "Registering ped " .. zone.pedInfos.pedName
            )

            LSLegacy.SpawnPedZone(
                zone.pedInfos.pedModel,
                zone.pedInfos.coords,
                zone.name,
                source
            )
        end
    end
end