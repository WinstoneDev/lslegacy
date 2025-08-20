function VisiblePed(id, freeze)
    local player = id
    SetPlayerControl(player, not freeze, false)

    local ped = GetPlayerPed(player)

    if not freeze then
        if not IsEntityVisible(ped) then
            SetEntityVisible(ped, true)
        end

        if not IsPedInAnyVehicle(ped) then
            SetEntityCollision(ped, true)
        end

        FreezeEntityPosition(ped, false)
        SetPlayerInvincible(player, false)
    else
        if IsEntityVisible(ped) then
            SetEntityVisible(ped, false)
        end

        SetEntityCollision(ped, false)
        FreezeEntityPosition(ped, true)
        SetPlayerInvincible(player, true)

        if not IsPedFatallyInjured(ped) then
            ClearPedTasksImmediately(ped)
        end
    end
end

function spawnPlayer(spawnIdx, cb)
    Citizen.CreateThread(function()
        local spawn = {}

        if type(spawnIdx) == 'table' then
            spawn = spawnIdx

            spawn.x = spawn.x + 0.00
            spawn.y = spawn.y + 0.00
            spawn.z = spawn.z - 1.0

            spawn.heading = spawn.heading or 0
        end

        if not spawn then
            return
        end

        VisiblePed(PlayerId(), true)

        if spawn.model then
            RequestModel(spawn.model)

            while not HasModelLoaded(spawn.model) do
                RequestModel(spawn.model)
                Wait(0)
            end

            SetPlayerModel(PlayerId(), spawn.model)
            SetModelAsNoLongerNeeded(spawn.model)
            
            if N_0x283978a15512b2fe then
				N_0x283978a15512b2fe(PlayerPedId(), true)
            end
        end

        RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
        local ped = PlayerPedId()
        SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false, true)
        NetworkResurrectLocalPlayer(spawn.x, spawn.y, spawn.z, spawn.heading, true, true, false)
        ClearPedTasksImmediately(ped)
        RemoveAllPedWeapons(ped)
        ClearPlayerWantedLevel(PlayerId())

        local time = GetGameTimer()
        while (not HasCollisionLoadedAroundEntity(ped) and (GetGameTimer() - time) < 2500) do
            Wait(0)
        end

        ShutdownLoadingScreen()

        if IsScreenFadedOut() then
            DoScreenFadeIn(500)
            while not IsScreenFadedIn() do Wait(0) end
        end

        VisiblePed(PlayerId(), false)

        if (cb) then
            cb(spawn)
        end
    end)
end

AddEventHandler('skinchanger:modelLoaded', function()
    SetEntityHealth(PlayerPedId(), LSLegacy.PlayerData.health)
end)

Citizen.CreateThread(function()
    TriggerServerEvent('registerPlayer')
    while LSLegacy.PlayerData.coords == nil do Wait(5) end
    spawnPlayer({x = LSLegacy.PlayerData.coords.x, y = LSLegacy.PlayerData.coords.y, z = LSLegacy.PlayerData.coords.z, model = GetHashKey("mp_m_freemode_01"), heading = 215.0}, function()
        NetworkSetFriendlyFireOption(true)
        SetCanAttackFriendly(PlayerPedId(), true, true)
        SwitchTrainTrack(0, false)
        SwitchTrainTrack(3, false)
        SetTrainTrackSpawnFrequency(0, 0)
        SetRandomTrains(false)
        SetMaxWantedLevel(0)
        DisplayRadar(true)
        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerHealthRechargeMultiplier(PlayerPedId(), 0.0)
        AddTextEntry('FE_THDR_GTAO', '~b~LSLegacy~s~ - ID '..GetPlayerServerId(PlayerId()))
        AddTextEntry('PM_PANE_LEAVE', 'Retourner à l\'acceuil')
        AddTextEntry('PM_PANE_QUIT', 'Quitter FiveM')
        AddTextEntry('PM_PANE_CFX', 'LSLegacy')
        if LSLegacy.PlayerData.skin == nil then
            LSLegacy.TriggerLocalEvent('CreatePerso')
        elseif json.encode(LSLegacy.PlayerData.skin) ~= "[]" then
            TriggerEvent('skinchanger:loadSkin', LSLegacy.PlayerData.skin)
        end
    end)
end)