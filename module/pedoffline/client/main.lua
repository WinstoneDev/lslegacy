-- Variable de promesse pour attendre la liste des peds endormis
local pedOfflineLoadPromise = nil

local pedOfflineLoading  = false
local pedOfflineSettled  = false   -- evite de resoudre 2x la promesse (state n'est pas une string fiable)

local function pedOfflineLoadSleepingList()
    if pedOfflineLoading then return end
    pedOfflineLoading = true
    pedOfflineSettled = false

    -- Vider la liste locale : supprimer d'abord les peds déjà spawnés dans le
    -- monde, sinon ils deviennent orphelins (plus suivis par rien) et un
    -- doublon apparaît quand la liste fraîche recrée l'entrée juste après.
    -- Se produit sans reconnexion : InitPlayer se redéclenche au changement
    -- de personnage (module/multichar) alors que cette resource continue de
    -- tourner, avec les peds du personnage précédent encore en mémoire.
    for k, sp in pairs(pedOfflineSleepingList) do
        if sp.deletePed then sp:deletePed() end
        pedOfflineSleepingList[k] = nil
    end

    -- Creer une promesse locale et envoyer la requete au serveur
    local prom = promise:new()
    pedOfflineLoadPromise = prom
    LSLegacy.Events.SendToServer("pedOffline:request:sleepingList")

    -- Timeout de securite : 10 secondes
    SetTimeout(10000, function()
        if not pedOfflineSettled then
            pedOfflineSettled = true
            prom:resolve({})
        end
    end)

    Citizen.Await(prom)
    if pedOfflineLoadPromise == prom then pedOfflineLoadPromise = nil end

    local list = prom.value
    if list then
        for _, sp in pairs(list) do
            Sleeping:new(sp)
        end
    end

    pedOfflineLoading = false
end

-- InitPlayer est deja enregistre dans player.lua -> LSLegacy.Events.AddHandler pour un 2e handler
LSLegacy.Events.AddHandler('lslegacy:initPlayer', pedOfflineLoadSleepingList)

-- Couvre le cas d'un (re)demarrage de la resource alors que le joueur est deja connecte
-- (InitPlayer ne se redeclenche pas dans ce cas)
Citizen.CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    while not LSLegacy.Token or not LSLegacy.Token["pedOffline:request:sleepingList"] do Wait(250) end
    pedOfflineLoadSleepingList()
end)

-- Reponse du serveur avec la liste des peds endormis
LSLegacy.Events.Register("pedOffline:response:sleepingList", function(list)
    local count = 0
    if list then for _ in pairs(list) do count = count + 1 end end
    pedOfflineDebug("response:sleepingList recue, taille =", count)
    if pedOfflineLoadPromise and not pedOfflineSettled then
        pedOfflineSettled = true
        pedOfflineLoadPromise:resolve(list)
    end
end)

-- Synchronisation des actions depuis le serveur
LSLegacy.Events.Register("pedOffline:client:sync", function(action, identifier, data)
    pedOfflineDebug("sync", action, identifier)
    if action == "new" then
        Sleeping:new(data)
    elseif action == "delete" then
        Sleeping:delete(identifier)  -- appel sur la classe avec identifier comme arg
    elseif action == "setCarrying" then
        local sp = Sleeping.get(identifier)
        if not sp then return end
        sp:setCarrying(data.carryPlayer, data.netId)
    elseif action == "stopCarrying" then
        local sp = Sleeping.get(identifier)
        if not sp then return end
        sp:stopCarrying()
    elseif action == "setCoords" then
        local sp = Sleeping.get(identifier)
        if not sp then return end
        sp:setCoords(data)
    elseif action == "putInVehicle" then
        local sp = Sleeping.get(identifier)
        if not sp then return end
        sp:putInVehicle(data.vehicleNetId, data.seat)
    elseif action == "outVehicle" then
        local sp = Sleeping.get(identifier)
        if not sp then return end
        sp:outVehicle()
    end
end)

-- Ordre du serveur de lacher le ped (lors d'un putInVehicle)
LSLegacy.Events.Register("pedOffline:client:forceStopCarrying", function()
    Sleeping.StopCarrying(false)
end)

-- Declenche par le serveur apres outVehicle
LSLegacy.Events.Register("pedOffline:client:TargetCarryAction", function(identifier)
    local sp = Sleeping.get(identifier)
    if not sp then return end
    Sleeping.TargetCarryAction(sp)
end)

-- Animation du ped porte via StateBag
AddStateBagChangeHandler("pedOfflineAnim", nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then return end
    local p2Anim = pedOfflineCfg.carryAnimation.player2
    if not value then
        StopAnimTask(entity, p2Anim.dict, p2Anim.anim, 8.0)
        return
    end
    if not HasAnimDictLoaded(p2Anim.dict) then
        RequestAnimDict(p2Anim.dict)
        while not HasAnimDictLoaded(p2Anim.dict) do Wait(100) end
    end
    TaskPlayAnim(entity, p2Anim.dict, p2Anim.anim, 8.0, 8.0, -1, p2Anim.flags, 0, false, false, false)
end)

-- Boucle de spawn/despawn selon la distance
local pedOfflineLastDebugLoop = 0
Citizen.CreateThread(function()
    while true do
        Wait(250)
        local playerPed    = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local doDebug      = pedOfflineCfg.debug and (GetGameTimer() - pedOfflineLastDebugLoop > 5000)
        if doDebug then pedOfflineLastDebugLoop = GetGameTimer() end

        for citizenId, sp in pairs(pedOfflineSleepingList) do
            local pedExists = sp.ped and DoesEntityExist(sp.ped)
            local dist      = sp.playerCoords and #(vector3(sp.playerCoords.x, sp.playerCoords.y, sp.playerCoords.z) - playerCoords)
            local canSpawn  = dist and not sp.carrying and not sp.vehicle and dist < pedOfflineCfg.pedSpawnDist

            if doDebug then
                pedOfflineDebug("loop", citizenId, "dist=", dist, "carrying=", sp.carrying, "vehicle=", sp.vehicle, "pedExists=", pedExists, "canSpawn=", canSpawn)
            end

            if not pedExists and canSpawn then
                sp:spawnPed()
            elseif pedExists and not canSpawn then
                sp:deletePed()
            end
        end
    end
end)

LSLegacy.Events.AddHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Supprime tous les peds endormis spawned localement (evite les duplis au reload)
    for _, sp in pairs(pedOfflineSleepingList) do
        sp:deletePed()
    end

    -- Si on est en train de porter un ped (test), nettoie le ped et le target associe
    if pedOfflineCarrying and pedOfflineCarryData then
        if pedOfflineCarryData.serverPed and DoesEntityExist(pedOfflineCarryData.serverPed) then
            DetachEntity(pedOfflineCarryData.serverPed, true, false)
            DeleteEntity(pedOfflineCarryData.serverPed)
        end
        ox_target:removeGlobalVehicle("pedOffline-put-in-vehicle")
        ClearPedTasks(PlayerPedId())
        pedOfflineCarrying  = false
        pedOfflineCarryData = nil
    end
end)
