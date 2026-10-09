local lastVeh = nil

LSLegacy.Events.Register("ap:vehicleSpawned", function(data)
    local netId = data.netId
    local plate = data.plate
    -- attendre que l'entité soit réellement streamée (jusqu'à 8 s) au lieu de
    -- résoudre le netId une seule fois : sinon le rejeu était silencieusement sauté
    local entity = 0
    local deadline = GetGameTimer() + 8000
    repeat
        entity = NetworkGetEntityFromNetworkId(netId)
        if entity ~= 0 and DoesEntityExist(entity) then break end
        Wait(200)
    until GetGameTimer() > deadline
    Wait(300)
    if DoesEntityExist(entity) then
        local status = data.status
        if status then
                if status.visualDamage then
                    if status.visualDamage.bumpers then
                        if status.visualDamage.bumpers.front == true then
                            SetVehicleDamage(entity, 0.0, 2.0, 0.5, 500.0, 100.0, true)
                        end
                        if status.visualDamage.bumpers.rear == true then
                            SetVehicleDamage(entity, 0.0, -2.0, 0.5, 500.0, 100.0, true)
                        end
                    end

                    if status.visualDamage.doors then
                        for doorIndex, d in pairs(status.visualDamage.doors) do
                            local index = tonumber(doorIndex)
                            if index and GetIsDoorValid(entity, index) then
                                if d.damaged then
                                    SetVehicleDoorBroken(entity, index, true)
                                elseif d.angle and d.angle > 0.1 then
                                    SetVehicleDoorOpen(entity, index, false, true)
                                else
                                    SetVehicleDoorShut(entity, index, false)
                                end
                            end
                        end
                    end

                    if status.visualDamage and status.visualDamage.deformation then
                        for _, deform in pairs(status.visualDamage.deformation) do
                            if deform and deform.damage then
                                local dmg = deform.damage * 1000.0
                                SetVehicleDamage(entity, deform.x, deform.y, deform.z, dmg, 100.0, true)
                            end
                        end
                    end
                end
            if data.extras then
                for i = 0, 20 do
                    if DoesExtraExist(entity, i) then
                        LSLegacy.SetVehicleExtra_PreserveDamage(entity, i, false)
                    end
                end
                for k, v in pairs(data.extras) do
                    if DoesExtraExist(entity, v.id) then
                        if v.state then
                            LSLegacy.SetVehicleExtra_PreserveDamage(entity, v.id, true)
                        else
                            LSLegacy.SetVehicleExtra_PreserveDamage(entity, v.id, false)
                        end
                    end
                end
            end
            for k, v in pairs(status.windows) do
                if v ~= nil then
                    if v.broken then
                        SmashVehicleWindow(entity, v.id)
                        while IsVehicleWindowIntact(entity, v.id) do
                            SmashVehicleWindow(entity, v.id)
                            Wait(100)
                        end
                    end
                end
            end
            if status.doorsBroken then
                for doorIndex, isBroken in pairs(status.doorsBroken) do
                    local index = tonumber(doorIndex)
                    if index and isBroken and GetIsDoorValid(entity, index) then
                        SetVehicleDoorBroken(entity, index, true)
                    end
                end
            end
            if status.tyreData then
                local tyreData = status.tyreData
                
                if tyreData.driftEnabled ~= nil then
                    SetDriftTyresEnabled(entity, tyreData.driftEnabled)
                end
                if tyreData.canBurst ~= nil then
                    SetVehicleTyresCanBurst(entity, tyreData.canBurst)
                end
                if tyreData.smokeColor then
                    SetVehicleTyreSmokeColor(entity, tyreData.smokeColor.r, tyreData.smokeColor.g, tyreData.smokeColor.b)
                end

                if tyreData.wheels then
                    for wheelId, wheelData in pairs(tyreData.wheels) do
                        local id = tonumber(wheelId)
                        if tyreData.canBurst and wheelData.health == 0.0 then
                            SetVehicleTyreBurst(entity, id, true, 1000.0)
                        end
                        SetTyreHealth(entity, id, wheelData.health)
                        SetTyreWearMultiplier(entity, id, wheelData.wear)
                    end
                end
            end
        end
        SetVehicleEngineHealth(entity, data.engineHealth)
        SetVehiclePetrolTankHealth(entity, data.tankHealth)
        if status and status.body then SetVehicleBodyHealth(entity, status.body + 0.0) end
        if status and status.dirt then SetVehicleDirtLevel(entity, status.dirt + 0.0) end
        -- Le fuel est appliqué via le statebag 'fuelLevel' que le serveur pose au spawn (voir AddStateBagChangeHandler ci-dessous), pas ici.
        if data.tuning then
            -- indispensable : sans mod kit, SetVehicleMod / SetVehicleModColor_1/_2 sont ignorés
            SetVehicleModKit(entity, 0)
            -- Le type de roue doit être posé AVANT SetVehicleMod(23/24, ...) : l'indice
            -- de jante est interprété dans le contexte du wheel type déjà actif, sinon
            -- le rendu visuel de la jante peut ne pas correspondre à l'indice sauvegardé.
            if data.tuning.wheelType then
                SetVehicleWheelType(entity, data.tuning.wheelType)
            end
            if data.tuning.mods then
                for k, v in pairs(data.tuning.mods) do
                    if v ~= nil and tonumber(k) then
                        SetVehicleMod(entity, tonumber(k), v, false)
                    end
                end
            end
            if data.tuning.livery and data.tuning.livery >= 0 then
                SetVehicleLivery(entity, data.tuning.livery)
            end
            -- Couleurs : index GetVehicleColours (source de vérité, capturés côté client)
            -- puis RGB custom par-dessus si le cercle chromatique est actif. On n'utilise
            -- plus SetVehicleModColor_1/_2 : leur paramètre pearlescent écrasait le nacré
            -- et leur index n'est pas garanti identique à celui de SetVehicleColours.
            local p = data.tuning.paint
            local prim = data.tuning.colorPrimary or (p and p.primary and p.primary.color)
            local sec  = data.tuning.colorSecondary or (p and p.secondary and p.secondary.color)
            if prim and sec then
                SetVehicleColours(entity, math.floor(prim), math.floor(sec))
            end
            if p then
                -- Finition (mat/chrome/métallisé/...) : rejouée par-dessus SetVehicleColours
                -- via SetVehicleModColor_1/_2, avec le pearlColor déjà connu pour ne pas
                -- l'écraser. Ignoré si absent (anciennes sauvegardes sans champ "type").
                if p.primary and p.primary.type and p.primary.color then
                    SetVehicleModColor_1(entity, p.primary.type, math.floor(p.primary.color), data.tuning.pearlColor or 0)
                end
                if p.secondary and p.secondary.type and p.secondary.color then
                    SetVehicleModColor_2(entity, p.secondary.type, math.floor(p.secondary.color))
                end
                if p.primary and p.primary.custom and p.primary.r then
                    SetVehicleCustomPrimaryColour(entity, p.primary.r, p.primary.g, p.primary.b)
                end
                if p.secondary and p.secondary.custom and p.secondary.r then
                    SetVehicleCustomSecondaryColour(entity, p.secondary.r, p.secondary.g, p.secondary.b)
                end
            end
            if data.tuning.pearlColor and data.tuning.wheelColor then
                SetVehicleExtraColours(entity, data.tuning.pearlColor, data.tuning.wheelColor)
            end
            if data.tuning.windowTint then
                SetVehicleWindowTint(entity, data.tuning.windowTint)
            end
            if data.tuning.turboOn then
                ToggleVehicleMod(entity, 18, true)
            end
            if data.tuning.neon then
                local n = data.tuning.neon
                SetVehicleNeonLightEnabled(entity, 0, n.front == true)
                SetVehicleNeonLightEnabled(entity, 1, n.back == true)
                SetVehicleNeonLightEnabled(entity, 2, n.left == true)
                SetVehicleNeonLightEnabled(entity, 3, n.right == true)
                if n.r then
                    SetVehicleNeonLightsColour(entity, n.r, n.g, n.b)
                end
            end
        end
        print("[AP] Véhicule spawné :", plate)
        WatchFuelConvergence(entity)
    end
end)

LSLegacy.Events.Register("ap:findAndDeleteVehicle", function()
    local ped = PlayerPedId()
    local vehicleToDelete = nil

    if IsPedInAnyVehicle(ped, false) then
        vehicleToDelete = GetVehiclePedIsIn(ped, false)
    else
        local coords = GetEntityCoords(ped)
        local closestVehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 3.0, 0, 70)
        
        if closestVehicle ~= 0 and DoesEntityExist(closestVehicle) then
            vehicleToDelete = closestVehicle
        end
    end

    if vehicleToDelete then
        local netId = NetworkGetNetworkIdFromEntity(vehicleToDelete)
        local plate = GetVehicleNumberPlateText(vehicleToDelete)

        if NetworkDoesEntityExistWithNetworkId(netId) then
            LSLegacy.Events.SendToServer("ap:requestVehicleDeletion", netId, plate)
        else
            DeleteEntity(vehicleToDelete)
            LSLegacy.Events.SendToServer("ap:requestVehicleDeletion", 0, plate)
        end
    else
        LSLegacy.ShowNotification('Erreur', 'Aucun véhicule trouvé à proximité.', 'error')
    end
end)

LSLegacy.Events.Register("ap:findAndDespawnVehicle", function()
    local ped = PlayerPedId()
    local vehicleToDespawn = nil

    if IsPedInAnyVehicle(ped, false) then
        vehicleToDespawn = GetVehiclePedIsIn(ped, false)
    else
        local coords = GetEntityCoords(ped)
        local closestVehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 3.0, 0, 70)

        if closestVehicle ~= 0 and DoesEntityExist(closestVehicle) then
            vehicleToDespawn = closestVehicle
        end
    end

    if vehicleToDespawn then
        local netId = NetworkGetNetworkIdFromEntity(vehicleToDespawn)
        local plate = GetVehicleNumberPlateText(vehicleToDespawn)

        if NetworkDoesEntityExistWithNetworkId(netId) then
            LSLegacy.Events.SendToServer("ap:requestVehicleDespawn", netId, plate)
        else
            DeleteEntity(vehicleToDespawn)
            LSLegacy.Events.SendToServer("ap:requestVehicleDespawn", 0, plate)
        end
    else
        LSLegacy.ShowNotification('Erreur', 'Aucun véhicule trouvé à proximité.', 'error')
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 then
            lastVeh = veh
        elseif lastVeh ~= nil then
            LSLegacy.Events.SendToServer("ap:updateVehicle", NetworkGetNetworkIdFromEntity(lastVeh))
            lastVeh = nil
        end
        Wait(500)
    end
end)

-- Signale au serveur tout véhicule AP détruit (explosion, chute...) vu par ce
-- client, pour purge de persistent_vehicles/owned_vehicles. Dédup par netId
-- pour ne signaler qu'une fois par véhicule.
local ReportedDestroyed = {}
CreateThread(function()
    while true do
        Wait(10000)
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) and IsEntityDead(veh) then
                local netId = NetworkGetNetworkIdFromEntity(veh)
                if netId ~= 0 and not ReportedDestroyed[netId] then
                    ReportedDestroyed[netId] = true
                    LSLegacy.Events.SendToServer("ap:vehicleDestroyed", netId, GetVehicleNumberPlateText(veh))
                end
            end
        end
    end
end)

local function UpdateVehicleStatus(veh)
    if veh == 0 then return end

    local plate = GetVehicleNumberPlateText(veh)

    local tuningV = {}
    for i = 0, 49 do
        tuningV[i] = GetVehicleMod(veh, i)
    end

    local pearlColor, wheelColor = GetVehicleExtraColours(veh)
    local neonR, neonG, neonB = GetVehicleNeonLightsColour(veh)
    local colorPrimaryIdx, colorSecondaryIdx = GetVehicleColours(veh)

    -- SetVehicleModColor_1/_2 (Los Santos Customs) plutôt que SetVehicleColours,
    -- + couleur "cercle chromatique" (custom RGB) si active côté atelier/tuning.lua.
    local paintType1, colorPrimary   = GetVehicleModColor_1(veh)
    local paintType2, colorSecondary = GetVehicleModColor_2(veh)
    local customPrimaryR, customPrimaryG, customPrimaryB       = GetVehicleCustomPrimaryColour(veh)
    local customSecondaryR, customSecondaryG, customSecondaryB = GetVehicleCustomSecondaryColour(veh)
    local paint = {
        primary   = { type = paintType1, color = colorPrimary, custom = GetIsVehiclePrimaryColourCustom(veh) == true,
                      r = customPrimaryR, g = customPrimaryG, b = customPrimaryB },
        secondary = { type = paintType2, color = colorSecondary, custom = GetIsVehicleSecondaryColourCustom(veh) == true,
                      r = customSecondaryR, g = customSecondaryG, b = customSecondaryB },
    }

    local extras = {}
    for i = 0, 20 do
        if DoesExtraExist(veh, i) then
            local extraOn = IsVehicleExtraTurnedOn(veh, i)
            if extraOn == 1 then
                extras[i] = {id = i, state = true}
            elseif extraOn == false then
                extras[i] = {id = i, state = false}
            end
        end
    end

    local windows = {}
    for i = 0, 7 do
        table.insert(windows, {id = i, broken = not IsVehicleWindowIntact(veh, i)})
    end

    local r, g, b = GetVehicleTyreSmokeColor(veh)
    local tyreData = {
        canBurst = GetVehicleTyresCanBurst(veh),
        driftEnabled = GetDriftTyresEnabled(veh),
        smokeColor = { r = r, g = g, b = b },
        
        wheels = {}
    }

    for i = 0, 7 do
        tyreData.wheels[i] = {
            health = GetTyreHealth(veh, i),
            wear = GetTyreWearMultiplier(veh, i)
        }
    end

    local doorsBroken = {}
    for i = 0, 7 do 
        if IsVehicleDoorDamaged(veh, i) then
            doorsBroken[i] = true
        else
            doorsBroken[i] = false
        end
    end

    local bumpers = {
        front = IsVehicleBumperBrokenOff(veh, true),
        rear = IsVehicleBumperBrokenOff(veh, false)
    }

    local doors = {}
    for i = 0, 7 do
        if GetIsDoorValid(veh, i) then
            doors[i] = {
                damaged = IsVehicleDoorDamaged(veh, i),
                angle = GetVehicleDoorAngleRatio(veh, i)
            }
        end
    end

    local offsets = {
        {x=0.0, y=2.0, z=0.5},   -- avant
        {x=0.0, y=-2.0, z=0.5},  -- arrière
        {x=0.0, y=0.0, z=1.2},   -- toit
        {x=-1.0, y=0.0, z=0.5},  -- gauche
        {x=1.0, y=0.0, z=0.5}    -- droite
    }

    local deformation = {}
    for _, offset in ipairs(offsets) do
        local deform = GetVehicleDeformationAtPos(veh, vector3(offset.x, offset.y, offset.z))
        local intensity = #(deform)*5
        if intensity > 0.01 then 
            table.insert(deformation, {
                x = offset.x,
                y = offset.y,
                z = offset.z,
                damage = intensity
            })
        end
    end

    local status = {
        tuning = {
            mods = tuningV,
            paint = paint,
            colorPrimary = colorPrimaryIdx,
            colorSecondary = colorSecondaryIdx,
            pearlColor = pearlColor,
            wheelColor = wheelColor,
            wheelType = GetVehicleWheelType(veh),
            windowTint = GetVehicleWindowTint(veh),
            turboOn = IsToggleModOn(veh, 18),
            livery = GetVehicleLivery(veh),
            neon = {
                front = IsVehicleNeonLightEnabled(veh, 0),
                back  = IsVehicleNeonLightEnabled(veh, 1),
                left  = IsVehicleNeonLightEnabled(veh, 2),
                right = IsVehicleNeonLightEnabled(veh, 3),
                r = neonR, g = neonG, b = neonB
            }
        },
        windows = windows,
        extras = extras,
        tyreData = tyreData,
        doorsBroken = doorsBroken
    }


    status.visualDamage = {
        bumpers = bumpers,
        doors = doors,
        deformation = deformation
    }
    -- santés mesurées côté client : GetVehicleBodyHealth n'est pas répliqué
    -- fidèlement au serveur (carrosserie 100 % avec l'avant enfoncé)
    status.health = {
        engine = GetVehicleEngineHealth(veh),
        body = GetVehicleBodyHealth(veh),
        tank = GetVehiclePetrolTankHealth(veh),
        dirt = GetVehicleDirtLevel(veh),
    }

    LSLegacy.Events.SendToServer("ap:updateVehicleStatus", plate, status)
end

-- Exposée pour les modules qui modifient un véhicule sans être dedans (ex:
-- module/atelier/client/tuning.lua) : le thread ci-dessous ne rapporte QUE
-- si le joueur est assis dans le véhicule, donc un mécano qui tune un
-- véhicule depuis l'extérieur ne déclenche jamais de rapport tout seul.
LSLegacy.AP = LSLegacy.AP or {}
LSLegacy.AP.ReportVehicleStatus = UpdateVehicleStatus

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            UpdateVehicleStatus(veh)
        end
        Wait(Config.AP.UpdateIntervalMs) 
    end
end)

-- Statebag 'fuelLevel' = source de vérité unique du carburant, répliquée à
-- tous les clients (comme 'handbrake') et persistée par SaveVehicle côté
-- serveur : quel que soit le module qui modifie le fuel (pompe, conso,
-- regen...), il doit passer par SetSyncedFuelLevel pour rester cohérent
-- pour les autres joueurs et pour la sauvegarde du véhicule.
function SetSyncedFuelLevel(vehicle, percent)
    SetVehicleFuelLevel(vehicle, percent)
    Entity(vehicle).state:set('fuelLevel', percent, true)
end

-- Reforce le fuel natif vers la valeur attendue (statebag) pendant quelques
-- secondes après spawn : le native peut se réinitialiser tout seul le temps
-- que le handling du véhicule se résolve complètement.
function WatchFuelConvergence(entity)
    Citizen.CreateThread(function()
        for i = 1, 12 do
            if not DoesEntityExist(entity) then return end
            -- Relu à chaque itération (et non figé avant la boucle) : sinon ce
            -- watchdog écrase toute mise à jour légitime du fuel survenue
            -- pendant sa fenêtre de 10s (pompe, tuning...) en la retapant vers
            -- une valeur devenue périmée.
            local expected = Entity(entity).state.fuelLevel
            local current  = GetVehicleFuelLevel(entity)
            if expected and math.abs(current - expected) > 1.0 then
                SetVehicleFuelLevel(entity, expected)
            end
            Wait(500)
        end
    end)
end

AddStateBagChangeHandler('fuelLevel', nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end
    SetVehicleFuelLevel(entity, value)
end)

-- Statebag 'apSpawnGuard' posé par SpawnVehicle : SetEntityCollision est un natif
-- CLIENT uniquement, donc le serveur ne peut pas désactiver lui-même la collision
-- du véhicule fraîchement spawné (garde anti-collision doublon au restart).
AddStateBagChangeHandler('apSpawnGuard', nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end
    SetEntityCollision(entity, not value, not value)
end)

-- Statebag 'plate' posé par SpawnVehicle : filet de sécurité si SetVehicleNumberPlateText
-- (mod one-shot, réplication OneSync non garantie pour un client qui stream l'entité
-- juste après sa création) n'a pas atteint ce client avec la bonne plaque.
AddStateBagChangeHandler('plate', nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end
    if value and GetVehicleNumberPlateText(entity) ~= value then
        SetVehicleNumberPlateText(entity, value)
    end
end)

-- Délai de "settle" après lequel on fait confiance aux natives dépendant du
-- handling (GetVehicleHighGear, GetVehicleCurrentGear...) pour un véhicule
-- donné. Juste après un spawn/une entrée, ces natives peuvent renvoyer des
-- valeurs par défaut (handling pas encore résolu), ce qui faisait passer des
-- véhicules thermiques pour "électriques" (GetVehicleHighGear <= 1) et
-- déclenchait à tort la conso/regen électrique (fuel à 0 + à-coup de recul
-- via ApplyForceToEntity dans le thread de freinage régénératif).
local VehicleEnteredAt = {}
local function IsVehicleSettled(vehicle)
    local since = VehicleEnteredAt[vehicle]
    if not since then
        VehicleEnteredAt[vehicle] = GetGameTimer()
        return false
    end
    return (GetGameTimer() - since) > 3000
end

-- Correction rapprochée à l'entrée conducteur : le fuel natif peut diverger
-- de la valeur attendue (statebag) juste après montée/démarrage moteur,
-- le temps que le handling se stabilise. On reforce vers la valeur attendue.
local lastDriverVeh = nil
Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local isDriver = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped

        if isDriver and veh ~= lastDriverVeh then
            lastDriverVeh = veh
            VehicleEnteredAt[veh] = GetGameTimer()
            Citizen.CreateThread(function()
                for i = 1, 40 do
                    if not DoesEntityExist(veh) then return end
                    -- Idem WatchFuelConvergence : relu à chaque itération pour
                    -- ne pas fighter une mise à jour légitime (tuning, pompe)
                    -- survenue dans les 10s après être monté au volant.
                    local expected = Entity(veh).state.fuelLevel
                    local current  = GetVehicleFuelLevel(veh)
                    if expected and math.abs(current - expected) > 1.0 then
                        SetVehicleFuelLevel(veh, expected)
                    end
                    Wait(250)
                end
            end)
        elseif not isDriver then
            lastDriverVeh = nil
        end

        Wait(250)
    end
end)

-- Consommation de carburant en conduite ET au ralenti (GetVehicleHighGear <= 1 = électrique).
Citizen.CreateThread(function()
    while true do
        local waitTime  = 5000
        local playerPed = PlayerPedId()
        local vehicle   = GetVehiclePedIsIn(playerPed, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == playerPed and IsVehicleSettled(vehicle) then
            local vehicleClass = GetVehicleClass(vehicle)
            local baseLossRate = Config.FuelConsumption.LossRateByClass[vehicleClass]
            local isElectric   = GetVehicleHighGear(vehicle) <= 1
                and vehicleClass ~= 8   -- Motorcycles
                and vehicleClass ~= 13  -- Cycles
                and vehicleClass ~= 14  -- Boats
                and vehicleClass ~= 15  -- Helicopters
                and vehicleClass ~= 16  -- Planes
                and vehicleClass ~= 22  -- Open Wheels
            local speed        = GetEntitySpeed(vehicle)
            local isRunning    = GetIsVehicleEngineRunning(vehicle)

            if isRunning then
                local currentFuel = GetVehicleFuelLevel(vehicle)
                local newFuel

                -- Regen active → pas de consommation ici (gérée par l'autre thread, sinon on annulerait le gain)
                local regenActive = isElectric
                    and speed * 3.6 >= Config.FuelConsumption.RegenMinSpeedKmh
                    and GetControlNormal(0, 71) < 0.05
                    and GetVehicleCurrentGear(vehicle) > 0

                if regenActive then
                    -- rien : le thread regen gère le niveau de carburant
                elseif speed > 0.5 then
                    if baseLossRate and baseLossRate > 0 then
                        local speedKmh        = speed * 3.6
                        local speedMultiplier = math.max(0.5, speedKmh / 150.0)
                        if isElectric then
                            speedMultiplier = speedMultiplier * 1.2
                        end
                        newFuel = math.max(0, currentFuel - baseLossRate * speedMultiplier)
                    end
                else
                    -- Consommation au ralenti : IdleLossRate par tick de 5s, réduit pour les électriques
                    if baseLossRate and baseLossRate > 0 then
                        local idleLoss = Config.FuelConsumption.IdleLossRate
                        if isElectric then
                            idleLoss = idleLoss * Config.FuelConsumption.ElectricIdleMultiplier
                        end
                        newFuel = math.max(0, currentFuel - idleLoss)
                    end
                end

                if newFuel then
                    SetSyncedFuelLevel(vehicle, newFuel)

                    if newFuel <= 0 and GetIsVehicleEngineRunning(vehicle) then
                        SetVehicleEngineOn(vehicle, false, true, true)
                        local msg = isElectric
                            and "La batterie de votre véhicule est à plat !"
                            or  "Votre véhicule n'a plus d'essence !"
                        LSLegacy.ShowNotification(nil, msg, 'error')
                    end
                end
            end
        end

        Wait(waitTime)
    end
end)

-- Freinage régénératif électrique : décélère (ApplyForceToEntity, forceType=3 = impulsion externe) et récupère de l'énergie par palier d'1s quand l'accélérateur est relâché en roulant.
CreateThread(function()
    local lastRegenMs = 0

    while true do
        local playerPed = PlayerPedId()
        local vehicle   = GetVehiclePedIsIn(playerPed, false)
        local wait      = 500

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == playerPed and IsVehicleSettled(vehicle) then
            -- GetVehicleHighGear <= 1 attrape aussi motos/vélos/bateaux/hélicos/avions/Open Wheels ; on les exclut.
            local vClass     = GetVehicleClass(vehicle)
            local isElectric = GetVehicleHighGear(vehicle) <= 1
                and vClass ~= 8   -- Motorcycles
                and vClass ~= 13  -- Cycles
                and vClass ~= 14  -- Boats
                and vClass ~= 15  -- Helicopters
                and vClass ~= 16  -- Planes
                and vClass ~= 22  -- Open Wheels

            if isElectric and GetIsVehicleEngineRunning(vehicle) then
                local speedKmh = GetEntitySpeed(vehicle) * 3.6
                local throttle = GetControlNormal(0, 71)
                local gear     = GetVehicleCurrentGear(vehicle)

                if speedKmh >= Config.FuelConsumption.RegenMinSpeedKmh
                   and throttle < 0.05
                   and gear > 0
                then
                    local vel   = GetEntityVelocity(vehicle)
                    local speed = GetEntitySpeed(vehicle)

                    if speed > 0.1 then
                        local brk = Config.FuelConsumption.ElectricRegenBrakeForce
                        -- Force opposée à la vélocité normalisée = freinage régénératif
                        ApplyForceToEntity(vehicle, 3,
                            -vel.x / speed * brk,
                            -vel.y / speed * brk,
                            -vel.z / speed * brk,
                            0.0, 0.0, 0.0,
                            -1,    -- centre de masse
                            false, -- coordonnées monde
                            true,  -- ignoreUpVec
                            true,  -- isForceRel : scalé par masse → décél constante
                            false,
                            true
                        )
                    end

                    local now = GetGameTimer()
                    if now - lastRegenMs >= 1000 then
                        local regenAmount = speedKmh * Config.FuelConsumption.ElectricRegenRate
                        SetSyncedFuelLevel(vehicle, math.min(100.0, GetVehicleFuelLevel(vehicle) + regenAmount))
                        lastRegenMs = now
                    end

                    wait = 0
                end
            end
        end

        Wait(wait)
    end
end)