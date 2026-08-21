-- PedOffline - Serveur
-- Adapte pour LSLegacy (skinchanger, identifier license, events LSLegacy)

local dataLoaded = false
local entityList = {}   -- identifier -> netId (peds en cours de portage)
local skinCache  = {}   -- source -> { identifier, skin }

-- Rate limiting pour les events du module
LSLegacy.RateLimit['pedOffline:request:sleepingList']  = 5
LSLegacy.RateLimit['pedOffline:server:startCarrying']  = 15
LSLegacy.RateLimit['pedOffline:server:stopCarrying']   = 15
LSLegacy.RateLimit['pedOffline:server:putInVehicle']   = 10
LSLegacy.RateLimit['pedOffline:server:outVehicle']     = 10

-- Helpers

-- Clé du ped endormi : identifier + slot du personnage, pas juste
-- l'identifier. Sans le slot, se reconnecter avec un AUTRE personnage du
-- même compte supprimerait/écraserait le ped endormi du premier (les deux
-- partagent le même identifier).
local function buildCitizenId(identifier, slot)
    if not identifier then return nil end
    return identifier .. '#' .. tostring(slot or 1)
end

local function buildSkinData(skin)
    if not skin then return nil end
    local model = (skin.sex == 1) and `mp_f_freemode_01` or `mp_m_freemode_01`
    return { model = model, skin = skin }
end

-- Cache du skin (mis a jour a chaque spawn et periodiquement)

LSLegacy.AddEventHandler('ap:clientsetonSpawn', function(src)
    local player = LSLegacy.GetPlayerFromId(src)
    if not player then return end
    local identifier = player.identifier
    if not identifier or not player.skin then return end
    skinCache[src] = { identifier = identifier, slot = player.slot or 1, skin = player.skin }
    pedOfflineDebug("skinCache updated for", identifier, "slot", player.slot or 1)
end)

Citizen.CreateThread(function()
    while true do
        Wait(30000)
        for src, player in pairs(LSLegacy.ServerPlayers) do
            if player.identifier and player.skin then
                skinCache[src] = { identifier = player.identifier, slot = player.slot or 1, skin = player.skin }
            end
        end
    end
end)

-- Deconnexion (ou changement de personnage sans déco, cf. LSLegacy.PedOffline
-- .PutToSleep plus bas) -> creation du ped endormi

local function createSleepingPedFromCache(src, cached)
    if not cached then return false end
    local identifier = cached.identifier
    local slot        = cached.slot or 1
    local citizenId    = buildCitizenId(identifier, slot)
    local skin         = cached.skin

    if Sleeping.get(citizenId) then return false end
    local skinData = buildSkinData(skin)
    if not skinData then return false end

    local playerPed = GetPlayerPed(src)
    if not playerPed or not DoesEntityExist(playerPed) then return false end

    local coords  = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    Sleeping:new({
        citizenId      = citizenId,
        identifier     = identifier,
        slot           = slot,
        skinData       = skinData,
        playerCoords   = { x = coords.x, y = coords.y, z = coords.z, w = heading },
        animationIndex = math.random(1, #pedOfflineCfg.sleepAnimation),
        carrying       = false,
        ped            = nil,
        vehicle        = nil,
    })
    pedOfflineDebug("ped created for", citizenId)
    return true
end

LSLegacy.AddEventHandler('playerDropped', function()
    local src    = source
    local cached = skinCache[src]
    skinCache[src] = nil
    createSleepingPedFromCache(src, cached)
end)

-- Exposé pour module/multichar (commande /multichar, bouton "retour à la
-- sélection" du menu admin) : le joueur reste connecté, seul son personnage
-- change, donc `playerDropped` ne se déclenche jamais. Sans cet appel
-- explicite, le personnage laissé derrière ne serait jamais mis "au lit".
LSLegacy.PedOffline = LSLegacy.PedOffline or {}

function LSLegacy.PedOffline.PutToSleep(src)
    return createSleepingPedFromCache(src, skinCache[src])
end

-- Requete client : envoyer la liste des peds endormis + supprimer son propre ped

LSLegacy.RegisterServerEvent("pedOffline:request:sleepingList", function()
    local src = source
    Citizen.CreateThread(function()
        if not dataLoaded then while not dataLoaded do Wait(100) end end
        local player = LSLegacy.GetPlayerFromId(src)
        if player and player.identifier then
            local citizenId = buildCitizenId(player.identifier, player.slot or 1)
            local sp = Sleeping.get(citizenId)
            if sp then
                sp:delete()
                pedOfflineDebug("request:sleepingList: deleted own ped for", citizenId)
            end
        end
        local count = 0
        for k in pairs(pedOfflineSleepingList) do
            count = count + 1
            pedOfflineDebug("response:sleepingList -> includes", k)
        end
        pedOfflineDebug("response:sleepingList: envoi de", count, "ped(s) a", src)
        LSLegacy.SendEventToClient("pedOffline:response:sleepingList", src, pedOfflineSleepingList)
    end)
end)

-- Commande de test (admin)

LSLegacy.RegisterCommand(pedOfflineCfg.testCommand.name, pedOfflineCfg.testCommand.group,
    function(player, args, showError)
        local src = player.source
        if not player.identifier then return end
        local slot       = player.slot or 1
        local citizenId  = buildCitizenId(player.identifier, slot)

        local sp = Sleeping.get(citizenId)
        if sp then
            sp:delete()
            return
        end

        -- Toujours utiliser le skin serveur le plus recent (synce par skinchanger)
        local skin = player.skin

        -- Fallback sur le cache si le skin serveur est vide
        if not skin and skinCache[src] then
            skin = skinCache[src].skin
        end

        pedOfflineDebug("testCommand skin: " .. (skin and json.encode(skin) or "nil"))

        local skinData = buildSkinData(skin)
        if not skinData then
            print("[pedOffline] testCommand: skin introuvable pour " .. citizenId)
            return
        end

        local playerPed = GetPlayerPed(src)
        if not playerPed or not DoesEntityExist(playerPed) then return end
        local coords    = GetEntityCoords(playerPed)
        local heading   = GetEntityHeading(playerPed)

        Sleeping:new({
            citizenId      = citizenId,
            identifier     = player.identifier,
            slot           = slot,
            skinData       = skinData,
            playerCoords   = { x = coords.x, y = coords.y, z = coords.z, w = heading },
            animationIndex = math.random(1, #pedOfflineCfg.sleepAnimation),
            carrying       = false,
            ped            = nil,
            vehicle        = nil,
        })
    end,
    { help = "Toggle ped endormi (test pedOffline)" }
)

-- Porter un ped

LSLegacy.RegisterServerEvent('pedOffline:server:startCarrying', function(identifier, netId)
    local src = source
    local sp  = Sleeping.get(identifier)
    if not sp then return end
    sp:setCarrying(src, netId)
    entityList[identifier] = netId
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and DoesEntityExist(entity) then
        Entity(entity).state:set('pedOfflineAnim', true, true)
    end
    pedOfflineDebug("startCarrying", identifier, netId)
end)

LSLegacy.RegisterServerEvent('pedOffline:server:stopCarrying', function(identifier, netId)
    local src    = source
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and DoesEntityExist(entity) then
        Entity(entity).state:set('pedOfflineAnim', false, true)
    end

    local sp = Sleeping.get(identifier)
    if not sp then return end

    if entity and DoesEntityExist(entity) then DeleteEntity(entity) end

    local playerPed = GetPlayerPed(src)
    local coords    = GetEntityCoords(playerPed)
    local heading   = GetEntityHeading(playerPed)

    sp:stopCarrying()
    sp:setCoords({ x = coords.x, y = coords.y, z = coords.z, w = heading })
    sp:updateSql()
    entityList[identifier] = nil
    pedOfflineDebug("stopCarrying", identifier)
end)

-- Mettre dans un vehicule

LSLegacy.RegisterServerEvent('pedOffline:server:putInVehicle', function(identifier, vehicleNetId, seatIndex)
    local sp = Sleeping.get(identifier)
    if not sp then return end
    sp:putInVehicle(vehicleNetId, seatIndex)
end)

LSLegacy.RegisterServerEvent('pedOffline:server:outVehicle', function(identifier)
    local src = source
    local sp  = Sleeping.get(identifier)
    if not sp then return end
    sp:outVehicle()
    LSLegacy.SendEventToClient("pedOffline:client:TargetCarryAction", src, identifier)
end)

-- Chargement initial depuis MySQL

MySQL.ready(function()
    local rows = MySQL.query.await(
        'SELECT sleepData FROM exit_sleeping WHERE unixTime >= (UNIX_TIMESTAMP() - ?)',
        { pedOfflineCfg.purgeDay * 86400 }
    )
    if not rows then
        dataLoaded = true
        return
    end
    pedOfflineDebug("MySQL.ready: chargement de", #rows, "peds endormis")
    for i = 1, #rows do
        local sleepData = json.decode(rows[i].sleepData)
        if sleepData then
            sleepData.isOld   = true
            sleepData.vehicle = nil
            sleepData.netId   = nil
            Sleeping:new(sleepData)
        end
    end
    dataLoaded = true
end)

-- Purge des peds trop vieux (BDD + memoire si encore charges)

local function purgeOldSleepingPeds()
    local expireSeconds = pedOfflineCfg.purgeDay * 86400
    local rows = MySQL.query.await(
        'SELECT citizenid FROM `exit_sleeping` WHERE unixTime < (UNIX_TIMESTAMP() - ?)',
        { expireSeconds }
    )
    if not rows or #rows == 0 then return end

    for i = 1, #rows do
        local citizenId = rows[i].citizenid
        local sp = Sleeping.get(citizenId)
        if sp then
            sp:delete()
        else
            MySQL.query.await('DELETE FROM `exit_sleeping` WHERE citizenid = ?', { citizenId })
        end
    end
    pedOfflineDebug("purge:", #rows, "ped(s) supprime(s) (inactifs depuis plus de", pedOfflineCfg.purgeDay, "jours)")
end

Citizen.CreateThread(function()
    while not dataLoaded do Wait(1000) end
    while true do
        purgeOldSleepingPeds()
        Wait(24 * 60 * 60 * 1000) -- 1x par jour
    end
end)

-- Nettoyage a l'arret de la resource

LSLegacy.AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, netId in pairs(entityList) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
    end
end)
