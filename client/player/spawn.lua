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
        Config.Development.Print("[spawn] spawnPlayer: début")
        local spawn = {}

        if type(spawnIdx) == 'table' then
            spawn = spawnIdx

            spawn.x = spawn.x + 0.00
            spawn.y = spawn.y + 0.00
            spawn.z = spawn.z - 1.0

            spawn.heading = spawn.heading or 0
        end

        if not spawn then
            Config.Development.Print("[spawn] spawnPlayer: spawn nil, abandon")
            return
        end

        VisiblePed(PlayerId(), true)

        if spawn.model then
            RequestModel(spawn.model)

            -- Borné : un modèle qui ne charge jamais (streaming bloqué...)
            -- ne doit pas figer tout le reste de la connexion indéfiniment.
            local modelTimer = GetGameTimer()
            while not HasModelLoaded(spawn.model) and (GetGameTimer() - modelTimer) < 10000 do
                RequestModel(spawn.model)
                Wait(0)
            end
            if not HasModelLoaded(spawn.model) then
                Config.Development.Print("[spawn] ATTENTION: modèle " .. tostring(spawn.model) .. " non chargé après 10s, on continue quand même")
            else
                Config.Development.Print("[spawn] modèle chargé")
            end

            SetPlayerModel(PlayerId(), spawn.model)
            SetModelAsNoLongerNeeded(spawn.model)

            if N_0x283978a15512b2fe then
				N_0x283978a15512b2fe(PlayerPedId(), true)
            end
        end

        if LSLegacy.Anticheat then LSLegacy.Anticheat.AllowTeleport() end
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
        Config.Development.Print("[spawn] collision " .. (HasCollisionLoadedAroundEntity(ped) and "chargée" or "timeout 2.5s, on continue quand même"))

        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
        Config.Development.Print("[spawn] ShutdownLoadingScreen appelé, IsScreenFadedOut=" .. tostring(IsScreenFadedOut()))

        if IsScreenFadedOut() then
            DoScreenFadeIn(500)
            -- Borné : si le fade-in ne "prend" jamais (état de fade
            -- incohérent après un forceReselect par ex.), on ne reste pas
            -- bloqué indéfiniment sur un écran noir.
            local fadeTimer = GetGameTimer()
            while not IsScreenFadedIn() and (GetGameTimer() - fadeTimer) < 5000 do
                Wait(0)
            end
            if not IsScreenFadedIn() then
                Config.Development.Print("[spawn] ATTENTION: fade-in non confirmé après 5s (IsScreenFadedIn=false), on continue quand même")
            end
        end

        VisiblePed(PlayerId(), false)
        Config.Development.Print("[spawn] spawnPlayer: terminé, callback")

        if (cb) then
            cb(spawn)
        end
    end)
end

AddEventHandler('skinchanger:modelLoaded', function()
    SetEntityHealth(PlayerPedId(), LSLegacy.PlayerData.health)
end)

LSLegacy.Player = LSLegacy.Player or {}

-- Sélection de personnage + spawn. Appelée au démarrage de la resource, et
-- ré-appelée telle quelle par le retour à la sélection multicharacter
-- (module/multichar/client/main.lua, event `multichar:forceReselect`) : un
-- changement de personnage en cours de session est donc traité exactement
-- comme la connexion initiale, sans logique dupliquée.
function LSLegacy.Player.RunLoginFlow()
    Config.Development.Print("[login] RunLoginFlow: début")
    LSLegacy.Multichar.RequestSelection()
    Config.Development.Print("[login] sélection résolue, attente de PlayerData.coords")

    local coordsTimer = GetGameTimer()
    while LSLegacy.PlayerData.coords == nil do
        Wait(5)
        if (GetGameTimer() - coordsTimer) % 3000 < 5 then
            Config.Development.Print("[login] toujours en attente de PlayerData.coords (InitPlayer pas encore reçu ?) depuis " .. (GetGameTimer() - coordsTimer) .. "ms")
        end
    end
    Config.Development.Print("[login] PlayerData.coords reçu, appel spawnPlayer")

    -- Le modèle de spawn doit refléter le sexe du personnage sauvegardé :
    -- sinon (redémarrage du framework en cours de session, skinchanger lui
    -- restant actif) le ped est forcé en homme puis skinchanger, comparant
    -- au skin déjà connu en mémoire, ne détecte aucun changement de sexe et
    -- ne recharge jamais le bon modèle → apparence figée/erronée.
    local savedSkin = LSLegacy.PlayerData.skin
    local spawnModel = (savedSkin and savedSkin.sex == 1) and GetHashKey("mp_f_freemode_01") or GetHashKey("mp_m_freemode_01")

    spawnPlayer({x = LSLegacy.PlayerData.coords.x, y = LSLegacy.PlayerData.coords.y, z = LSLegacy.PlayerData.coords.z, model = spawnModel, heading = LSLegacy.PlayerData.coords.h}, function()
        Config.Development.Print("[login] callback spawnPlayer exécuté")
        NetworkSetFriendlyFireOption(true)
        SetCanAttackFriendly(PlayerPedId(), true, true)
        SwitchTrainTrack(0, false)
        --SwitchTrainTrack(3, false)
       -- SetTrainTrackSpawnFrequency(0, 0)
        --SetRandomTrains(false)
        SetMaxWantedLevel(0)
        DisplayRadar(true)
        SetPlayerWantedLevel(PlayerId(), 0, false)
        SetPlayerHealthRechargeMultiplier(PlayerPedId(), 0.0)
        AddTextEntry('FE_THDR_GTAO', '~b~LSLegacy~s~ - ID '..GetPlayerServerId(PlayerId()))
        AddTextEntry('PM_PANE_LEAVE', 'Retourner à l\'acceuil')
        AddTextEntry('PM_PANE_QUIT', 'Quitter FiveM')
        AddTextEntry('PM_PANE_CFX', 'LSLegacy')
        if LSLegacy.PlayerData.skin == nil then
            Config.Development.Print("[login] skin nil -> CreatePerso")
            LSLegacy.Events.TriggerLocal('creatorperso:create')
        elseif json.encode(LSLegacy.PlayerData.skin) ~= "[]" then
            Config.Development.Print("[login] chargement du skin existant")
            TriggerEvent('skinchanger:loadSkin', LSLegacy.PlayerData.skin)
        end
    end)
    -- NB: spawnPlayer lance son propre thread et revient immédiatement, donc
    -- ces deux lignes s'exécutent AVANT la fin réelle du spawn ci-dessus
    -- (comportement préexistant, pas une régression du multichar).
    Config.Development.Print("[login] RunLoginFlow: fin (spawnPlayer tourne dans son propre thread)")
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end

Citizen.CreateThread(function()
    Config.Development.Print("[login] Spawn début")
    spawnPlayer({x = -427.727478, y = 1115.578003, z = 326.780273, model = GetHashKey("a_f_m_beach_01"), heading = 345.82678222656})
    LSLegacy.Player.RunLoginFlow()
end)