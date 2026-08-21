local handbrakeActive = false   -- état du frein à main pour ce client
local currentVehicle  = 0       -- véhicule actuellement conduit

-- Véhicules sans conducteur à surveiller pour le roulement libre
local rollingVehicles = {}

-- Vitesse de roulement accumulée par véhicule (m/s)
local rollingSpeed = {}

-- Timestamp de sortie du véhicule ; délai de 2s avant physique de roulement pour éviter un départ immédiat.
local rollingDelay = {}

local function isVehicleEligible(veh)
    local class = GetVehicleClass(veh)
    for _, disabledClass in ipairs(Config.Handbrake.DisabledClasses) do
        if class == disabledClass then return false end
    end
    local model = GetEntityModel(veh)
    for _, disabledModel in ipairs(Config.Handbrake.DisabledModels) do
        if model == disabledModel then return false end
    end
    return true
end

-- Force de gravité projetée sur la pente, appliquée en continu (bScaleByMass=true pour une accélération indépendante de la masse).
local GRAVITY = 9.8

local function applySlopeForce(veh)
    -- GetEntityUpVector n'existe pas dans FiveM ; reconstruit via GetOffsetFromEntityInWorldCoords (point à 1 unité au-dessus, en espace local).
    local pos   = GetEntityCoords(veh)
    local upOff = GetOffsetFromEntityInWorldCoords(veh, 0.0, 0.0, 1.0)
    local nx = upOff.x - pos.x
    local ny = upOff.y - pos.y
    local nz = upOff.z - pos.z

    local slopeDeg = math.deg(math.acos(math.max(-1.0, math.min(1.0, nz))))
    if slopeDeg < Config.Handbrake.MinimumSlope then return end

    -- Projection de g sur la surface : a = g - (g·n)·n  →  g·n = -9.8·nz
    local ax = GRAVITY * nz * nx
    local ay = GRAVITY * nz * ny

    -- Multiplicateur interpolé : LowSlopeMultiplier → RollMultiplier
    local low  = Config.Handbrake.LowSlopeMultiplier
    local high = Config.Handbrake.RollMultiplier
    local t    = math.min(1.0, (slopeDeg - Config.Handbrake.MinimumSlope)
                              / (Config.Handbrake.LowSlopeThreshold - Config.Handbrake.MinimumSlope))
    local accel = (low + (high - low) * t) * GRAVITY / 60.0

    local slopeMag = math.sqrt(ax * ax + ay * ay)
    if slopeMag < 0.001 then return end

    if not rollingSpeed[veh] then rollingSpeed[veh] = 0.0 end

    -- Vitesse max proportionnelle à l'angle (ratio de sinus), plafonnée à MaxRollSpeed.
    local refSin = math.sin(math.rad(Config.Handbrake.MaxRollSpeedAngle))
    local maxSpd = math.min(
        Config.Handbrake.MaxRollSpeed * math.sin(math.rad(slopeDeg)) / refSin,
        Config.Handbrake.MaxRollSpeed
    )

    -- speedFactor : accélération réduite vers 0 quand on approche maxSpd
    local sFactor = math.max(0.0, 1.0 - rollingSpeed[veh] / maxSpd)
    rollingSpeed[veh] = math.min(rollingSpeed[veh] + accel * sFactor, maxSpd)
    local spd = rollingSpeed[veh]

    -- Suit la vélocité réelle dès que le véhicule bouge (virages) ; direction de pente au démarrage.
    local vel       = GetEntityVelocity(veh)
    local actualSpd = math.sqrt(vel.x * vel.x + vel.y * vel.y)
    local dirX, dirY
    if actualSpd > 0.15 then
        dirX = vel.x / actualSpd
        dirY = vel.y / actualSpd
    else
        dirX = ax / slopeMag
        dirY = ay / slopeMag
    end

    SetEntityVelocity(veh, dirX * spd, dirY * spd, vel.z)
end

local function engageHandbrake(veh)
    handbrakeActive = true
    SetVehicleHandbrake(veh, true)
    SetVehicleBrakeLights(veh, true)
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    LSLegacy.ShowNotification("Frein à main", "Frein à main engagé", "info")
    Entity(veh).state:set("handbrake", true, true)
    LSLegacy.SendEventToServer("handbrake:broadcastSound", VehToNet(veh), true)
end

local function releaseHandbrake(veh)
    handbrakeActive = false
    SetVehicleHandbrake(veh, false)
    SetVehicleBrakeLights(veh, false)
    PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    LSLegacy.ShowNotification("Frein à main", "Frein à main désengagé", "error")
    Entity(veh).state:set("handbrake", false, true)
    LSLegacy.SendEventToServer("handbrake:broadcastSound", VehToNet(veh), false)
end

-- NOTE : aucune force de pente n'est appliquée ici ; GTA V gère le freinage via les pédales quand le joueur est au volant. Le roulement libre ne s'active que hors véhicule sans frein à main.
CreateThread(function()
    while true do
        local wait = 500
        local ped  = PlayerPedId()
        local veh  = GetVehiclePedIsIn(ped, false)
        local isDriver = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped

        if isDriver and isVehicleEligible(veh) then
            wait = 0

            -- Transition : entrée dans un nouveau véhicule
            if currentVehicle ~= veh then
                handbrakeActive = Entity(veh).state.handbrake == true
                rollingVehicles[veh] = nil
                rollingSpeed[veh]    = nil
                rollingDelay[veh]    = nil
                currentVehicle = veh
            end

            -- IsControlJustPressed permet un vrai toggle ; IsDisabledControlPressed déclenchait engage+release sur un simple tap.
            --DisableControlAction(0, Config.Handbrake.HandbrakeKey, true)

            if IsControlJustPressed(0, Config.Handbrake.HandbrakeKey) and GetEntitySpeed(veh)*3.6 < 5 then
                if handbrakeActive then
                    releaseHandbrake(veh)
                else
                    engageHandbrake(veh)
                end
            end

        else
            -- Le joueur n'est plus conducteur
            if currentVehicle ~= 0 then
                local exitedVeh = currentVehicle

                if not handbrakeActive then
                    -- Pas de frein laissé → reset state bag pour les autres clients
                    Entity(exitedVeh).state:set("handbrake", false, true)

                    if Config.Handbrake.RollingEnabled then
                        local rot = GetEntityRotation(exitedVeh, 2)
                        local slope = math.sqrt(rot.x * rot.x + rot.y * rot.y)
                        if slope >= Config.Handbrake.MinimumSlope then
                            rollingVehicles[exitedVeh] = true
                            rollingDelay[exitedVeh]    = GetGameTimer()  -- timestamp sortie
                        end
                    end
                end
                -- Si frein à main engagé : state bag reste true,
                -- le véhicule reste immobilisé, les feux stop restent allumés.

                handbrakeActive = false
                currentVehicle  = 0
            end
        end

        Wait(wait)
    end
end)

-- Surveille les véhicules abandonnés en pente ; sort du suivi si détruit, remonté, freiné à distance, ou terrain plat.
CreateThread(function()
    while true do
        local hasWork = false

        for veh, _ in pairs(rollingVehicles) do
            if not DoesEntityExist(veh) then
                rollingVehicles[veh] = nil
                rollingSpeed[veh]    = nil
                rollingDelay[veh]    = nil

            elseif GetPedInVehicleSeat(veh, -1) ~= 0 then
                rollingVehicles[veh] = nil
                rollingSpeed[veh]    = nil
                rollingDelay[veh]    = nil

            elseif Entity(veh).state.handbrake == true then
                rollingVehicles[veh] = nil
                rollingSpeed[veh]    = nil
                rollingDelay[veh]    = nil

            else
                -- Délai de 2s après la sortie pour éviter un départ immédiat (animation, micro-déséquilibre).
                local elapsed = GetGameTimer() - (rollingDelay[veh] or 0)
                if elapsed < 2000 then
                    hasWork = true  -- maintenir la boucle active pendant le délai
                else

                local spd       = rollingSpeed[veh] or 0.0
                local vel       = GetEntityVelocity(veh)
                local actualSpd = math.sqrt(vel.x * vel.x + vel.y * vel.y)

                -- Détection d'obstacle, avant application de la force pour arrêter proprement.
                if spd > 1.0 and actualSpd < spd * 0.30 then
                    SetEntityVelocity(veh, 0.0, 0.0, vel.z)
                    rollingVehicles[veh] = nil
                    rollingSpeed[veh]    = nil
                    rollingDelay[veh]    = nil

                else
                    local rot   = GetEntityRotation(veh, 2)
                    local slope = math.sqrt(rot.x * rot.x + rot.y * rot.y)

                    if slope < Config.Handbrake.MinimumSlope then
                        if spd > 0.1 then
                            rollingSpeed[veh] = spd * 0.90
                            if actualSpd > 0.05 then
                                SetEntityVelocity(veh,
                                    vel.x / actualSpd * rollingSpeed[veh],
                                    vel.y / actualSpd * rollingSpeed[veh],
                                    vel.z
                                )
                                hasWork = true
                            else
                                rollingVehicles[veh] = nil
                                rollingSpeed[veh]    = nil
                                rollingDelay[veh]    = nil
                            end
                        else
                            rollingVehicles[veh] = nil
                            rollingSpeed[veh]    = nil
                            rollingDelay[veh]    = nil
                        end

                    else
                        if not NetworkHasControlOfEntity(veh) then
                            NetworkRequestControlOfEntity(veh)
                        end
                        FreezeEntityPosition(veh, false)
                        ActivatePhysics(veh)
                        SetVehicleHandbrake(veh, false)
                        applySlopeForce(veh)
                        hasWork = true
                    end
                end

                end  -- fin du bloc délai
            end
        end

        -- Boucle chaque frame si des véhicules sont en roulement actif,
        -- sinon vérification toutes les 500ms (économie CPU)
        Wait(hasWork and 0 or 500)
    end
end)

-- Relaie le son du frein à main pour les joueurs proches (positionnel sur l'entité).
LSLegacy.RegisterClientEvent("handbrake:playSound", function(netId, isEngage)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return end

    CreateThread(function()
        local soundId   = GetSoundId()
        local soundName = isEngage and "SELECT" or "BACK"
        PlaySoundFromEntity(soundId, soundName, entity, "HUD_FRONTEND_DEFAULT_SOUNDSET", false, 0)
        Wait(300)
        StopSound(soundId)
        ReleaseSoundId(soundId)
    end)
end)

AddStateBagChangeHandler("handbrake", nil, function(bagName, key, value, reserved, replicated)
    local entity = GetEntityFromStateBagName(bagName)

    if entity == 0
       or not DoesEntityExist(entity)
       or GetEntityType(entity) ~= 2
    then return end

    -- Ignorer le propre véhicule du conducteur local (déjà géré dans la boucle)
    local ped      = PlayerPedId()
    local localVeh = GetVehiclePedIsIn(ped, false)
    if entity == localVeh and GetPedInVehicleSeat(localVeh, -1) == ped then return end

    -- Déclenché aussi au spawn : le serveur pose le bag, chaque client qui charge l'entité applique l'état.
    SetVehicleBrakeLights(entity, value == true)
    SetVehicleHandbrake(entity, value == true)
end)
