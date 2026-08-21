-- ════════════════════════════════════════════════════════════════════════════
-- FREIN À MAIN MANUEL — Module persistent_vehicles
-- Auteur   : LSLegacy Framework
-- Synchro  : State Bags FiveM (frein/feux stop) + LSLegacy events (sons)
--
-- Comportement :
--   • Conducteur à bord → GTA V gère naturellement le freinage via les pédales.
--     Aucune force de pente n'est appliquée : le joueur garde le contrôle normal.
--   • Conducteur sort SANS frein à main → le véhicule est surveillé et
--     les forces de pente sont appliquées pour simuler un roulement réaliste.
--   • Frein à main engagé → véhicule immobilisé, feux stop allumés, état synchronisé.
-- ════════════════════════════════════════════════════════════════════════════

local handbrakeActive = false   -- état du frein à main pour ce client
local currentVehicle  = 0       -- véhicule actuellement conduit

-- Véhicules sans conducteur à surveiller pour le roulement libre
-- { [entityHandle] = true }
local rollingVehicles = {}

-- Vitesse de roulement accumulée par véhicule (m/s)
local rollingSpeed = {}

-- Timestamp GetGameTimer() de la sortie du véhicule par axe.
-- Permet d'attendre 2 secondes avant d'appliquer la physique de roulement,
-- évitant que la voiture parte au moment exact où le joueur sort.
local rollingDelay = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- HELPER : vérifie si le véhicule est soumis au système
--
-- GetVehicleClass(vehicle) → entier de classe (0=Compacts, 8=Motos, 13=Vélos…)
-- GetEntityModel(vehicle)  → hash du modèle, compatible avec les littéraux `rhino`
-- ─────────────────────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────────────────────
-- HELPER : roulement gravitationnel
--
-- PHYSIQUE (cf. schéma) :
--   n̂ = GetEntityUpVector → normale surface (normalisée)
--   g⃗ = (0, 0, −9.8)
--   a⃗_pente = g⃗ − (g⃗·n̂)·n̂  →  a_x = 9.8·n̂z·n̂x,  a_y = 9.8·n̂z·n̂y
--
-- NATIVE ApplyForceToEntityCenterOfMass :
--   bLocalForce  = false → vecteur déjà en espace monde (calculé ci-dessus)
--   bScaleByMass = true  → force × masse en interne ⟹ accélération = valeur passée
--                          indépendamment de la masse du véhicule
--   forceType    = 1     → force continue, intégrée par le moteur physique
--                          (pas d'impulsion brusque → pas de saccades)
--
-- VITESSE TERMINALE naturelle (pas de plafond dur) :
--   speedFactor = 1 − (v / MaxRollSpeed)
--   Quand v → 0       : force pleine → accélération maximale
--   Quand v → MaxRoll : force → 0   → vitesse se stabilise
--   Comportement identique à une résistance aérodynamique progressive.
-- ─────────────────────────────────────────────────────────────────────────────
local GRAVITY = 9.8

local function applySlopeForce(veh)
    -- GetEntityUpVector n'est pas exposé dans FiveM.
    -- Équivalent : GetOffsetFromEntityInWorldCoords(veh, 0, 0, 1)
    --   retourne la position monde du point situé 1 unité AU-DESSUS du véhicule
    --   dans son espace local (Z local = haut du véhicule).
    --   Différence avec GetEntityCoords → vecteur haut normalisé (longueur ≈ 1).
    local pos   = GetEntityCoords(veh)
    local upOff = GetOffsetFromEntityInWorldCoords(veh, 0.0, 0.0, 1.0)
    local nx = upOff.x - pos.x
    local ny = upOff.y - pos.y
    local nz = upOff.z - pos.z

    -- Angle d'inclinaison = arccos(n.z)
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

    -- Direction de la pente (monde, normalisée)
    local slopeMag = math.sqrt(ax * ax + ay * ay)
    if slopeMag < 0.001 then return end

    if not rollingSpeed[veh] then rollingSpeed[veh] = 0.0 end

    -- Vitesse maximale proportionnelle à l'angle de la pente :
    --   effectiveMax = MaxRollSpeed × sin(slopeDeg) / sin(MaxRollSpeedAngle)
    --   plafonnée à MaxRollSpeed.
    --
    -- Exemples avec MaxRollSpeed=5 m/s, MaxRollSpeedAngle=25° :
    --   3°  → 5 × sin(3°)/sin(25°)  ≈ 0.61 m/s  (~2.2 km/h)
    --   10° → 5 × sin(10°)/sin(25°) ≈ 2.04 m/s  (~7.3 km/h)
    --   20° → 5 × sin(20°)/sin(25°) ≈ 3.95 m/s  (~14 km/h)
    --   25°+→ 5 m/s (cap)           ≈ 5.00 m/s  (~18 km/h)
    local refSin = math.sin(math.rad(Config.Handbrake.MaxRollSpeedAngle))
    local maxSpd = math.min(
        Config.Handbrake.MaxRollSpeed * math.sin(math.rad(slopeDeg)) / refSin,
        Config.Handbrake.MaxRollSpeed
    )

    -- speedFactor : accélération réduite vers 0 quand on approche maxSpd
    local sFactor = math.max(0.0, 1.0 - rollingSpeed[veh] / maxSpd)
    rollingSpeed[veh] = math.min(rollingSpeed[veh] + accel * sFactor, maxSpd)
    local spd = rollingSpeed[veh]

    -- Direction : suivre la vélocité réelle GTA V dès que le véhicule bouge
    -- (virages, contours de route naturels) ; direction de pente au démarrage.
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

-- ─────────────────────────────────────────────────────────────────────────────
-- Engage le frein à main (conducteur)
--
-- SetVehicleHandbrake(vehicle, bool)
--   true  → verrouille les roues arrière (frein à main réel)
--
-- SetVehicleBrakeLights(vehicle, bool)
--   true  → allume les feux stop manuellement
--
-- Entity(entity).state:set(key, value, replicate)
--   replicate = true → diffuse à TOUS les clients + serveur via state bag
-- ─────────────────────────────────────────────────────────────────────────────
local function engageHandbrake(veh)
    handbrakeActive = true
    SetVehicleHandbrake(veh, true)
    SetVehicleBrakeLights(veh, true)
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    LSLegacy.ShowNotification("Frein à main", "Frein à main engagé", "info")
    Entity(veh).state:set("handbrake", true, true)
    LSLegacy.SendEventToServer("handbrake:broadcastSound", VehToNet(veh), true)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Désengage le frein à main (conducteur)
-- ─────────────────────────────────────────────────────────────────────────────
local function releaseHandbrake(veh)
    handbrakeActive = false
    SetVehicleHandbrake(veh, false)
    SetVehicleBrakeLights(veh, false)
    PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    LSLegacy.ShowNotification("Frein à main", "Frein à main désengagé", "error")
    Entity(veh).state:set("handbrake", false, true)
    LSLegacy.SendEventToServer("handbrake:broadcastSound", VehToNet(veh), false)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- BOUCLE PRINCIPALE — gestion du frein à main pour le conducteur
--
--   wait = 0   → traitement chaque frame (conducteur en véhicule éligible)
--   wait = 500 → vérification légère (hors véhicule)
--
-- DisableControlAction(group, control, disable)
--   Intercepte INPUT_JUMP (22 = ESPACE) en véhicule pour que GTA V ne
--   l'interprète plus comme son frein à main natif. Doit être rappelé chaque
--   frame pour rester actif.
--
-- IsDisabledControlPressed(group, control)
--   Lit l'état de la touche APRÈS désactivation native.
--
-- NOTE IMPORTANTE : aucune force de pente n'est appliquée ici (contrairement
-- à la version précédente). Quand le joueur est au volant, GTA V gère le
-- freinage naturellement via les pédales. Le roulement libre ne se produit
-- que lorsque le joueur quitte le véhicule sans frein à main.
-- ─────────────────────────────────────────────────────────────────────────────
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
                -- Stopper le suivi de roulement si on monte dans ce véhicule
                rollingVehicles[veh] = nil
                rollingSpeed[veh]    = nil
                rollingDelay[veh]    = nil
                currentVehicle = veh
            end

            -- Intercepte ESPACE avant le traitement natif de GTA V
            -- IsDisabledControlJustPressed → true UNE SEULE fois, sur le premier
            -- frame du press. Permet un comportement TOGGLE (appui = bascule),
            -- contrairement à IsDisabledControlPressed (true tant que maintenu)
            -- qui provoquait engage+release sur un simple tap.
            --DisableControlAction(0, Config.Handbrake.HandbrakeKey, true)

            if IsControlJustPressed(0, Config.Handbrake.HandbrakeKey) and GetEntitySpeed(veh)*3.6 < 5 then
                if handbrakeActive then
                    releaseHandbrake(veh)
                else
                    engageHandbrake(veh)
                end
            end

            -- Aucune force de pente ici : le joueur gère via les pédales.

        else
            -- Le joueur n'est plus conducteur
            if currentVehicle ~= 0 then
                local exitedVeh = currentVehicle

                if not handbrakeActive then
                    -- Pas de frein laissé → reset state bag pour les autres clients
                    Entity(exitedVeh).state:set("handbrake", false, true)

                    -- Ajouter au suivi de roulement si le véhicule est sur une pente
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

-- ─────────────────────────────────────────────────────────────────────────────
-- THREAD DE ROULEMENT — surveille les véhicules abandonnés sur une pente
--
-- S'active uniquement quand rollingVehicles contient au moins un véhicule.
-- Se met en veille (500ms) quand la table est vide.
--
-- NetworkHasControlOfEntity(entity)
--   → true si ce client a l'autorité réseau sur l'entité (nécessaire pour
--     que ApplyForceToEntity soit synchronisé chez tous les clients)
--
-- NetworkRequestControlOfEntity(entity)
--   → demande l'autorité réseau (asynchrone). En attendant, la force est
--     appliquée localement ; au prochain tick on aura probablement le contrôle.
--
-- Conditions de sortie du suivi :
--   • Entité détruite
--   • Un conducteur est entré (driver seat occupé)
--   • Le frein à main a été enclenché à distance (state bag = true)
--   • La pente est inférieure au seuil (terrain plat atteint)
-- ─────────────────────────────────────────────────────────────────────────────
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
                -- ── Délai de 2 secondes après la sortie du véhicule ──────────
                -- Empêche la voiture de partir au moment exact où le joueur sort
                -- (animation de sortie, micro-déséquilibre physique).
                local elapsed = GetGameTimer() - (rollingDelay[veh] or 0)
                if elapsed < 2000 then
                    hasWork = true  -- maintenir la boucle active pendant le délai
                else

                local spd       = rollingSpeed[veh] or 0.0
                local vel       = GetEntityVelocity(veh)
                local actualSpd = math.sqrt(vel.x * vel.x + vel.y * vel.y)

                -- ── Détection d'obstacle ─────────────────────────────────────
                -- Fait AVANT l'application de force pour arrêter proprement.
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

-- ─────────────────────────────────────────────────────────────────────────────
-- RÉCEPTION — son positionnel pour les joueurs proches (relayé depuis le serveur)
--
-- NetworkGetEntityFromNetworkId(netId) → handle local depuis le network ID
-- GetSoundId / PlaySoundFromEntity / StopSound / ReleaseSoundId
--   → son GTA V avec identifiant explicite, positionné sur l'entité
-- ─────────────────────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────────────────────
-- SYNCHRONISATION — feux stop des véhicules conduits par d'autres joueurs
--
-- AddStateBagChangeHandler(keyFilter, bagNameFilter, callback)
--   keyFilter     = "handbrake" → uniquement la clé "handbrake"
--   bagNameFilter = nil         → tous les state bags d'entités
--
-- GetEntityFromStateBagName(bagName)
--   → handle local de l'entité depuis son nom de bag ("entity:<networkId>")
--
-- GetEntityType(entity) → 0=invalide, 1=ped, 2=véhicule, 3=objet
-- ─────────────────────────────────────────────────────────────────────────────
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

    -- Feux stop + verrouillage des roues
    -- Déclenché aussi au spawn : le serveur pose le bag → chaque client qui
    -- charge l'entité le reçoit et applique l'état (voiture parquée frein serré)
    SetVehicleBrakeLights(entity, value == true)
    SetVehicleHandbrake(entity, value == true)
end)
