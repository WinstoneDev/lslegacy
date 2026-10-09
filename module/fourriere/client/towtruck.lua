local CFG = Config.Fourriere
local TC  = Config.Towtruck or {}

local function Notify(msg, t)
    TriggerEvent('notify', 'Fourrière', msg, t or 'info', 5000)
end

LSLegacy.Events.Register('fourriere:towtruckDebug', function(msg)
    print('^3[towtruck]^7 ' .. tostring(msg))
end)

local function TowEntity(netId, tries)
    local t = 0
    while t < (tries or 60) do
        if NetworkDoesNetworkIdExist(netId) then
            local e = NetworkGetEntityFromNetworkId(netId)
            if e and e ~= 0 and DoesEntityExist(e) then return e end
        end
        Wait(100) t = t + 1
    end
    return nil
end

local function LoadAnim(dict)
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do Wait(50) t = t + 1 end
    return HasAnimDictLoaded(dict)
end

local function RequestControl(entity, tries)
    if not entity or not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end
    for _ = 1, (tries or 20) do
        NetworkRequestControlOfEntity(entity)
        if NetworkHasControlOfEntity(entity) then return true end
        Wait(50)
    end
    return NetworkHasControlOfEntity(entity)
end

-- Conduite routière avec gestion du blocage, jusqu'à `stopAt` (rayon
-- `arrive`). Reprend la logique déjà éprouvée du convoi d'ambulance.
-- `near` (optionnel) = { coords, dist, speed } : ralentit à `speed` une fois
-- à `dist` de `coords` — approche plus sûre du véhicule à accrocher.
local function DriveTo(driver, veh, stopAt, arrive, timeout, near)
    local speed = TC.DriveSpeed or 24.0
    TaskVehicleDriveToCoordLongrange(driver, veh, stopAt.x, stopAt.y, stopAt.z,
        speed, TC.DriveStyle or 786469, arrive)

    local deadline = GetGameTimer() + (timeout or TC.ApproachTimeout or 45000)
    local lastPos = GetEntityCoords(veh)
    local stuck, swerves = 0, 0
    local stuckTicks = math.max(2, math.floor((TC.StuckDelay or 4000) / 500))
    local slowed = false

    while GetGameTimer() < deadline do
        Wait(500)
        if not DoesEntityExist(veh) then return false end
        local vp = GetEntityCoords(veh)
        if #(vp - stopAt) <= (arrive + 2.0) then return true end

        if near and not slowed and #(vp - near.coords) <= near.dist then
            slowed = true
            speed = near.speed or (speed * 0.4)
            TaskVehicleDriveToCoordLongrange(driver, veh, stopAt.x, stopAt.y, stopAt.z,
                speed, TC.DriveStyle or 786469, arrive)
        end

        if #(vp - lastPos) < 1.0 then stuck = stuck + 1 else stuck = 0 end
        lastPos = vp

        if stuck >= stuckTicks then
            stuck = 0
            swerves = swerves + 1
            if swerves <= (TC.StuckSwerve or 2) then
                TaskVehicleTempAction(driver, veh, (swerves % 2 == 1) and 11 or 10, 1800)
                Wait(1900)
                if not DoesEntityExist(veh) then return false end
                TaskVehicleDriveToCoordLongrange(driver, veh, stopAt.x, stopAt.y, stopAt.z,
                    speed, TC.DriveStyle or 786469, arrive)
            elseif TC.StuckReposition ~= false then
                local okR, foundR, posR, headR = pcall(
                    GetClosestVehicleNodeWithHeading, stopAt.x, stopAt.y, stopAt.z, 1, 3.0, 0)
                if okR and foundR and posR then
                    RequestControl(veh)
                    SetEntityCoordsNoOffset(veh, posR.x, posR.y, posR.z + 1.0, false, false, false)
                    SetEntityHeading(veh, (headR or 0.0) + 0.0)
                    SetVehicleOnGroundProperly(veh)
                end
                return true
            else
                return true
            end
        end
    end
    return true
end

LSLegacy.Events.Register('fourriere:towtruck', function(data)
    if not data then return end
    -- Diffusé à tous les joueurs pour que le convoi soit visible de tous ;
    -- seul l'agent demandeur pilote (les entités, déjà réseau, s'affichent
    -- normalement chez les autres sans qu'ils exécutent quoi que ce soit).
    if data.driver and data.driver ~= GetPlayerServerId(PlayerId()) then return end
    print('^2[towtruck]^7 Événement fourriere:towtruck reçu.')

    CreateThread(function()
        print(('^2[towtruck]^7 Résolution des entités — truckNet=%s driverNet=%s targetNet=%s')
            :format(tostring(data.truckNet), tostring(data.driverNet), tostring(data.targetNet)))
        local truck = TowEntity(data.truckNet)
        if not truck then print('^1[towtruck]^7 Dépanneuse jamais reçue — séquence abandonnée.') return end
        local driver = TowEntity(data.driverNet, 20)
        if not driver then print('^1[towtruck]^7 Chauffeur jamais reçu — séquence abandonnée.') return end
        local target = TowEntity(data.targetNet, 20)
        if not target then print('^1[towtruck]^7 Véhicule à remorquer jamais reçu — séquence abandonnée.') return end
        print('^2[towtruck]^7 Entités résolues, départ vers le véhicule.')

        RequestControl(truck)
        RequestControl(driver)
        SetBlockingOfNonTemporaryEvents(driver, true)
        SetEntityInvincible(driver, true)
        SetPedCanRagdollFromPlayerImpact(driver, false)

        -- Recalage sur la chaussée, comme le convoi d'ambulance.
        local vc = GetEntityCoords(truck)
        local okNode, found, nodePos, nodeHead = pcall(
            GetClosestVehicleNodeWithHeading, vc.x + 0.0, vc.y + 0.0, vc.z + 0.0, 1, 3.0, 0)
        if okNode and found and nodePos then
            SetEntityCoordsNoOffset(truck, nodePos.x, nodePos.y, nodePos.z + 1.0, false, false, false)
            SetEntityHeading(truck, (nodeHead or 0.0) + 0.0)
        end
        SetVehicleEngineOn(truck, true, true, false)
        SetVehicleOnGroundProperly(truck)

        SetPedIntoVehicle(driver, truck, -1)
        SetDriverAbility(driver, 1.0)
        SetDriverAggressiveness(driver, 1.0)
        SetPedKeepTask(driver, true)
        Wait(300)
        if not IsPedInVehicle(driver, truck, false) then SetPedIntoVehicle(driver, truck, -1) end

        -- Étape 1 : approche d'un point devant le véhicule visé, dépanneuse
        -- orientée à l'opposé — prête à reculer vers l'arrière du véhicule.
        local tCoords = GetEntityCoords(target)
        local tHeading = GetEntityHeading(target)
        local fwd = GetEntityForwardVector(target)
        local staging = vector3(
            tCoords.x + fwd.x * (TC.StagingDist or 12.0),
            tCoords.y + fwd.y * (TC.StagingDist or 12.0),
            tCoords.z)
        -- Même cap que le véhicule (pas +180°) : la dépanneuse, placée devant
        -- lui, a alors le nez tourné vers l'avant et l'arrière (le crochet)
        -- vers le véhicule — reculer la rapproche donc bien de sa cible.
        local stagingHeading = tHeading % 360.0

        print(('^2[towtruck]^7 Cible (%.1f, %.1f, %.1f) — approche du point de mise en ligne.')
            :format(tCoords.x, tCoords.y, tCoords.z))
        local reached = DriveTo(driver, truck, staging, TC.FinalApproach or 18.0, TC.ApproachTimeout or 45000,
            { coords = tCoords, dist = TC.ApproachSlowDist or 15.0, speed = TC.ApproachSlowSpeed or 8.0 })
        if not reached or not DoesEntityExist(truck) then
            print('^1[towtruck]^7 Approche échouée ou dépanneuse disparue — séquence abandonnée.')
            return
        end
        print('^2[towtruck]^7 Point de mise en ligne atteint.')

        local gotCtrl = RequestControl(truck, 40)
        if not gotCtrl then
            print('^1[towtruck]^7 Contrôle réseau de la dépanneuse non obtenu — recalage annulé.')
        end
        ClearPedTasksImmediately(driver)
        SetEntityCoordsNoOffset(truck, staging.x, staging.y, staging.z, false, false, false)
        SetEntityHeading(truck, stagingHeading)
        SetVehicleOnGroundProperly(truck)
        Wait(300)
        print(('^2[towtruck]^7 Recalage — contrôle=%s distance résiduelle à la cible=%.2f')
            :format(tostring(gotCtrl), #(GetEntityCoords(truck) - tCoords)))

        -- Un long téléport instantané du véhicule peut laisser le chauffeur
        -- assis dehors (désync FiveM) — on le rassoit avant de reculer.
        if DoesEntityExist(driver) and not IsPedInVehicle(driver, truck, false) then
            SetPedIntoVehicle(driver, truck, -1)
            Wait(200)
        end

        if TC.Hazards ~= false then SetVehicleIndicatorLights(truck, 0, true); SetVehicleIndicatorLights(truck, 1, true) end

        -- Étape 2 : crochet baissé au maximum (équivalent CTRL+G), puis
        -- marche arrière jusqu'au contact — l'accroche et son son sont
        -- gérés nativement par le moteur, pas besoin de les simuler.
        RequestControl(target)
        pcall(SetEntityDistanceCullingRadius, target, 500.0)

        -- Second contrôle juste avant de reculer : le premier recalage a pu
        -- éjecter le chauffeur un instant après le check précédent.
        if DoesEntityExist(driver) and DoesEntityExist(truck) and not IsPedInVehicle(driver, truck, false) then
            SetPedIntoVehicle(driver, truck, -1)
            Wait(200)
        end
        SetVehicleTowTruckArmPosition(truck, 1.0)
        Wait(400)
        print('^2[towtruck]^7 Crochet baissé, début de la marche arrière.')

        local revDeadline = GetGameTimer() + (TC.ReverseTimeout or 15000)
        local attached = false
        while GetGameTimer() < revDeadline do
            if not DoesEntityExist(truck) or not DoesEntityExist(target) then return end
            if IsVehicleAttachedToTowTruck(truck, target) then attached = true break end
            local d = #(GetEntityCoords(truck) - tCoords)
            if d <= (TC.ReachDist or 5.5) then break end
            SetVehicleForwardSpeed(truck, -(TC.ReverseSpeed or 2.5))
            Wait(0)
        end
        SetVehicleForwardSpeed(truck, 0.0)
        BringVehicleToHalt(truck, 1.0, 1000, false)
        Wait(300)

        if not attached then
            print(('^3[towtruck]^7 Pas encore accroché après la marche arrière (distance=%.2f) — appel explicite.')
                :format(#(GetEntityCoords(truck) - tCoords)))
        end
        -- Filet de sécurité : le contact scripté n'est pas toujours aussi
        -- précis qu'un joueur au volant — sans ça, un accrochage manqué
        -- laisserait le convoi repartir à vide.
        if not attached and not IsVehicleAttachedToTowTruck(truck, target) then
            AttachVehicleToTowTruck(truck, target, false, 0.0, 0.0, 0.0)
        end
        print(('^2[towtruck]^7 Véhicule accroché : %s.'):format(tostring(IsVehicleAttachedToTowTruck(truck, target))))

        -- Crochet remonté (équivalent MAJ+G) : la voiture peut partir.
        SetVehicleTowTruckArmPosition(truck, 0.0)
        Wait(500)

        -- Le conducteur descend mimer l'accroche avant de repartir.
        if TC.HookDelay and TC.HookDelay > 0 then
            TaskLeaveVehicle(driver, truck, 0)
            Wait(1500)
            -- Portée commune aux deux blocs ci-dessous (marche puis mime).
            local hookPoint = tCoords
            if DoesEntityExist(driver) then
                -- Marche jusqu'au crochet (entre la dépanneuse et le véhicule
                -- accroché) au lieu de mimer sur place, à côté de sa portière.
                if DoesEntityExist(truck) and DoesEntityExist(target) then
                    local truckPos, targetPos = GetEntityCoords(truck), GetEntityCoords(target)
                    hookPoint = vector3((truckPos.x + targetPos.x) / 2,
                        (truckPos.y + targetPos.y) / 2, targetPos.z)
                end
                ClearPedTasks(driver)
                TaskFollowNavMeshToCoord(driver, hookPoint.x, hookPoint.y, hookPoint.z,
                    1.2, -1, 1.0, false, 0)
                local walkDeadline = GetGameTimer() + 6000
                while GetGameTimer() < walkDeadline do
                    Wait(200)
                    if not DoesEntityExist(driver) then break end
                    if #(GetEntityCoords(driver) - hookPoint) <= 1.3 then break end
                end
            end
            if DoesEntityExist(driver) then
                ClearPedTasks(driver)
                TaskTurnPedToFaceCoord(driver, hookPoint.x, hookPoint.y, hookPoint.z, 500)
                Wait(600)
                if LoadAnim('mini@repair') then
                    TaskPlayAnim(driver, 'mini@repair', 'fixing_a_ped', 4.0, -4.0, -1, 1, 0, false, false, false)
                end
                Wait(TC.HookDelay)
                if DoesEntityExist(driver) and DoesEntityExist(truck) then
                    ClearPedTasks(driver)
                    TaskEnterVehicle(driver, truck, 8000, -1, 1.5, 1, 0)
                    Wait(2000)
                    if not IsPedInVehicle(driver, truck, false) then SetPedIntoVehicle(driver, truck, -1) end
                end
            end
        end

        if TC.Hazards ~= false then SetVehicleIndicatorLights(truck, 0, false); SetVehicleIndicatorLights(truck, 1, false) end

        -- Étape 3 : trajet retour vers la fourrière.
        print('^2[towtruck]^7 Départ vers la fourrière.')
        local dest = vector3(data.dest.x + 0.0, data.dest.y + 0.0, data.dest.z + 0.0)
        DriveTo(driver, truck, dest, TC.ArriveDist or 6.0, TC.TravelTimeout or 60000)
        if DoesEntityExist(truck) then
            TaskVehicleTempAction(driver, truck, 6, 2000)
            Wait(1200)
            if data.dest.h then SetEntityHeading(truck, data.dest.h + 0.0) end
        end

        print('^2[towtruck]^7 Arrivée à la fourrière — mise en fourrière effective.')
        LSLegacy.Events.SendToServer('fourriere:impound', data.impound)
        LSLegacy.Events.SendToServer('fourriere:towtruck:cleanup', data.id)
    end)
end)
