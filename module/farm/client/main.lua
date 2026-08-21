-- ═══════════════════════════════════════════════════════════════════
--  MODULE FARM — Client principal
--  Activités de récolte (bûcheron/mineur/agriculteur)
--  Circuit : récolte → traitement → revente, chaque étape validée serveur
-- ═══════════════════════════════════════════════════════════════════

Farm = Farm or {}
Farm.Busy = false -- action en cours (récolte ou traitement) — anti double-déclenchement

local function Notify(msg, type)
    TriggerEvent(Config.Farm.NotifyEvent, 'Farm', msg, 5000, type or 'info')
end

---SpawnStaticPed
---PNJ statique et invincible avec des options ox_target attachées à lui
---directement (addLocalEntity) — pattern repris de module/concessionnaire.
local function SpawnStaticPed(coords, model, heading, options)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then return end

    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, heading or 0.0, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(hash)

    exports.ox_target:addLocalEntity(ped, options)
    return ped
end

-- ══════════════════════════════════════════════════════════════════
--  SPAWN DE LA FAUNE (chasseur) — ARBITRÉ PAR LE SERVEUR.
--  Le client ne décide jamais lui-même "il en manque un" : il exécute
--  uniquement la demande de spawn que le serveur lui délègue (lui seul
--  peut poser l'animal au sol / vérifier l'eau à proximité), et lui
--  renvoie le netId obtenu — le serveur reste l'unique compteur, ce qui
--  évite qu'un spawn en double survienne si deux chasseurs se croisent
--  sur la même zone.
-- ══════════════════════════════════════════════════════════════════

local function RandomPointInRadius(center, radius)
    local angle = math.random() * 2 * math.pi
    local dist  = math.random() * radius
    return vector3(center.x + math.cos(angle) * dist, center.y + math.sin(angle) * dist, center.z)
end

local function RandomPointAround(center, minDist, maxDist)
    local angle = math.random() * 2 * math.pi
    local dist  = minDist + math.random() * (maxDist - minDist)
    return vector3(center.x + math.cos(angle) * dist, center.y + math.sin(angle) * dist, center.z)
end

---IsNearWater
---Littoral uniquement (mouette) : eau détectée proche du niveau du sol
---du joueur, pas juste "présente sur la carte" (sinon toute la carte
---compterait vu la mer environnante). Nécessite une native client —
---c'est pour ça que le serveur délègue ce filtre au client concerné.
local function IsNearWater(coords)
    local found, waterZ = GetWaterHeight(coords.x, coords.y, coords.z)
    if not found then return false end
    return math.abs(coords.z - waterZ) < 25.0
end

local SpawnedAnimals = {} -- entités qu'on a nous-mêmes créées, pour le nettoyage à l'arrêt de la ressource

---EnsureNetworked
---Le gibier n'est pas toujours networké : les espèces sans `spawnZones`
---(cougar, oiseaux) sont des peds de la population ambiante vanilla, créés
---localement par le jeu — `NetworkGetNetworkIdFromEntity` sur ceux-là émet
---un warning "no net object for entity" et renvoie 0. On les enregistre
---donc à la demande, au moment où le serveur a réellement besoin du netId.
---@return number|nil netId utilisable côté serveur, nil si l'enregistrement échoue
local function EnsureNetworked(entity)
    if not DoesEntityExist(entity) then return nil end

    if not NetworkGetEntityIsNetworked(entity) then
        NetworkRegisterEntityAsNetworked(entity)
        local t = 0
        while not NetworkGetEntityIsNetworked(entity) and t < 20 do Wait(50); t = t + 1 end
        if not NetworkGetEntityIsNetworked(entity) then return nil end
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    return netId ~= 0 and netId or nil
end

local function SpawnAnimal(model, coords)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then return nil end

    local groundZ        = coords.z
    local found, foundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 50.0, false)
    if found then groundZ = foundZ end

    -- `isNetwork = true` : l'animal est répliqué aux autres joueurs, sinon
    -- chaque client verrait une population différente et incohérente.
    local ped = CreatePed(4, hash, coords.x, coords.y, groundZ, math.random(0, 359) + 0.0, true, true)
    SetModelAsNoLongerNeeded(hash)

    SetPedFleeAttributes(ped, 65536, true) -- fuit dès qu'on tire, comme la faune vanilla
    SetBlockingOfNonTemporaryEvents(ped, false)
    TaskWanderStandard(ped, 10.0, 10)

    SpawnedAnimals[#SpawnedAnimals + 1] = ped
    return ped
end

LSLegacy.RegisterClientEvent('farm:spawnZoneAnimal', function(data)
    if not data then return end
    local ped   = SpawnAnimal(data.model, RandomPointInRadius(data.coords, data.radius))
    local netId = ped and EnsureNetworked(ped) or nil
    LSLegacy.SendEventToServer('farm:animalSpawned', { reqId = data.reqId, netId = netId })
end)

LSLegacy.RegisterClientEvent('farm:spawnAmbientAnimal', function(data)
    if not data then return end
    local netId

    if not data.requiresWater or IsNearWater(GetEntityCoords(PlayerPedId())) then
        local playerCoords = GetEntityCoords(PlayerPedId())
        local ped = SpawnAnimal(data.model, RandomPointAround(playerCoords, Config.Farm.HuntSpawn.ambientSpawnMin, Config.Farm.HuntSpawn.ambientSpawnMax))
        netId = ped and EnsureNetworked(ped) or nil
    end

    LSLegacy.SendEventToServer('farm:animalSpawned', { reqId = data.reqId, netId = netId })
end)

AddEventHandler('onResourceStop', function(res)
    if GetCurrentResourceName() ~= res then return end
    for _, ped in ipairs(SpawnedAnimals) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)

-- ── Aide au placement des points de récolte ───────────────────────────
-- Affiche la position actuelle prête à coller dans `Config.Farm.Activities.
-- <activité>.nodes` — se placer à l'endroit voulu puis taper /farmpos.
RegisterCommand('farmpos', function()
    local c = GetEntityCoords(PlayerPedId())
    local line = string.format('{ coords = vector3(%.2f, %.2f, %.2f) },', c.x, c.y, c.z)
    print('[Farm] ' .. line)
    Notify('Position copiée en console F8 : ' .. line, 'info')
end, false)

-- ── Utilitaires ────────────────────────────────────────────────────

local function ItemCount(itemName)
    if not itemName then return 0 end
    local count = 0
    for _, v in pairs(GetPlayerInventoryItems()) do
        if v.name == itemName then count = count + tonumber(v.count) end
    end
    return count
end

local function HasItem(itemName)
    if not itemName then return true end
    return ItemCount(itemName) > 0
end

-- ── Outils custom tenus en main (pioche, etc. — pas de vraie arme GTA) ──
-- Contrairement à une arme (weapon_hatchet), un outil custom n'a pas de
-- notion native "équipé" : on gère nous-mêmes un prop attaché en main,
-- togglé par une touche, tant qu'il n'est pas rangé.
Farm.HeldTool     = nil
Farm.HeldToolProp = nil

local function FindActivityByTool(tool)
    for _, activity in pairs(Config.Farm.Activities) do
        if activity.tool == tool then return activity end
    end
    return nil
end

local function UnequipHeldTool(silent)
    if Farm.HeldToolProp and DoesEntityExist(Farm.HeldToolProp) then
        DeleteEntity(Farm.HeldToolProp)
    end
    Farm.HeldTool     = nil
    Farm.HeldToolProp = nil
    if not silent then Notify('Vous rangez votre outil.', 'info') end
end

local function EquipHeldTool(tool)
    if Farm.HeldTool == tool then return end

    local activity = FindActivityByTool(tool)
    if not activity or not activity.gatherAnim or not activity.gatherAnim.prop then return end

    UnequipHeldTool(true)

    local anim      = activity.gatherAnim
    local ped       = PlayerPedId()
    local propHash  = GetHashKey(anim.prop)
    RequestModel(propHash)
    local t = 0
    while not HasModelLoaded(propHash) and t < 50 do Wait(100); t = t + 1 end

    if HasModelLoaded(propHash) then
        local prop = CreateObject(propHash, GetEntityCoords(ped), true, true, true)
        -- ID d'os numérique (ex: 18905 = main droite) si fourni — pattern
        -- validé dans module/pompe (repris tel quel du script public ox_fuel).
        -- `GetEntityBoneIndexByName` avec 'SKEL_R_Hand' semble se rabattre sur
        -- un os rigide (le prop ne suit pas le bras pendant l'animation).
        local boneRef = anim.bone or 'SKEL_R_Hand'
        local bone = type(boneRef) == 'number' and GetPedBoneIndex(ped, boneRef) or GetEntityBoneIndexByName(ped, boneRef)
        local off  = anim.offset or vector3(0.0, 0.0, 0.0)
        local rot  = anim.rotation or vector3(0.0, 0.0, 0.0)
        AttachEntityToEntity(prop, ped, bone, off.x, off.y, off.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
        Farm.HeldTool     = tool
        Farm.HeldToolProp = prop
        local toolLabel = Config.Items[tool] and Config.Items[tool].label or tool
        Notify('Vous tenez : ' .. toolLabel, 'success')
    end
    SetModelAsNoLongerNeeded(propHash)
end

---IsToolEquipped
---Pour un outil qui est une vraie arme GTA (weapon_*), vérifie qu'elle est
---actuellement l'arme en main. Pour un outil custom (ex: pioche), équipe
---automatiquement le prop en main s'il ne l'est pas déjà (pas de touche
---manuelle à connaître — juste avoir l'outil dans l'inventaire suffit).
local function IsToolEquipped(tool)
    if not tool then return true end
    if string.match(tool, '^weapon_') then
        return GetSelectedPedWeapon(PlayerPedId()) == GetHashKey(tool)
    end
    if Farm.HeldTool ~= tool then
        EquipHeldTool(tool)
    end
    return Farm.HeldTool == tool
end

-- ── Blips ───────────────────────────────────────────────────────────

local function AddFarmBlip(coords, sprite, color, scale, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
end

local function CreateBlips()
    for _, activity in pairs(Config.Farm.Activities) do
        for _, node in ipairs(activity.nodes or {}) do
            AddFarmBlip(node.coords, activity.blipSprite, activity.blipColor, Config.Farm.NodeBlipScale, activity.label .. ' — Récolte')
        end
        if activity.sellPoint then
            AddFarmBlip(activity.processing.coords, activity.blipSprite, activity.blipColor, Config.Farm.ProcessingBlipScale, activity.label .. ' — Traitement')
            AddFarmBlip(activity.sellPoint, activity.blipSprite, activity.blipColor, Config.Farm.ProcessingBlipScale, activity.label .. ' — Vente')
        else
            AddFarmBlip(activity.processing.coords, activity.blipSprite, activity.blipColor, Config.Farm.ProcessingBlipScale, activity.label .. ' — Traitement / Revente')
        end
    end
end

CreateThread(function()
    Wait(2000)
    CreateBlips()
end)

-- ── Minijeu générique (barre + appui touche, identique à Mécanicien) ──
-- Réutilisé pour la récolte ET le traitement.

local function DrawMinigameBar(pos, zoneStart, zoneEnd)
    DrawRect(0.5, 0.85, 0.3, 0.03, 30, 30, 30, 180)
    DrawRect(0.5 - 0.15 + zoneStart * 0.3, 0.85, (zoneEnd - zoneStart) * 0.3, 0.03, 50, 200, 50, 180)
    DrawRect(0.5 - 0.15 + pos * 0.3, 0.85, 0.004, 0.05, 255, 255, 255, 230)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName('~b~[E]~w~ Valider au bon moment')
    EndTextCommandDisplayHelp(0, false, true, -1)
end

---RunMinigame
---@param onComplete function appelé avec (hits, rounds, success)
---@param anim table|nil { dict, clip } — si fourni, joué en boucle sur le ped pendant tout le minijeu
function Farm.RunMinigame(onComplete, anim)
    local cfg  = Config.Farm.Minigame
    local hits = 0
    local ped  = PlayerPedId()

    if anim then
        RequestAnimDict(anim.dict)
        local at = 0
        while not HasAnimDictLoaded(anim.dict) and at < 50 do Wait(100); at = at + 1 end
        if HasAnimDictLoaded(anim.dict) then
            TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false) -- flag=1 : boucle
        end
    end

    for _ = 1, cfg.rounds do
        local zoneStart = math.random(20, 70) / 100.0
        local zoneEnd   = math.min(1.0, zoneStart + cfg.zoneSize)
        local startTime = GetGameTimer()
        local done      = false
        local roundHit  = false
        local lastPos   = 0.0

        while not done do
            Wait(0)
            local elapsed = (GetGameTimer() - startTime) % cfg.roundDuration
            local t       = elapsed / cfg.roundDuration
            lastPos       = t < 0.5 and (t * 2) or (2 - t * 2)

            DrawMinigameBar(lastPos, zoneStart, zoneEnd)

            if IsControlJustReleased(0, 38) then -- E
                roundHit = lastPos >= zoneStart and lastPos <= zoneEnd
                done     = true
            end

            if (GetGameTimer() - startTime) > (cfg.roundDuration * 2) then
                done = true
            end
        end

        if roundHit then hits = hits + 1 end
        Wait(150)
    end

    if anim then
        ClearPedTasks(ped)
        RemoveAnimDict(anim.dict)
    end

    local success = hits >= cfg.requiredHits
    onComplete(hits, cfg.rounds, success)
end

---RunGatherAnim
---Joue une animation de coup d'outil (hache, etc.) avec le prop attaché en
---main, sans minijeu : un coup = une récolte réussie.
---@param anim table Config.Farm.Activities[x].gatherAnim
---@param onComplete function appelé avec (success)
---RunGatherAnim
---Le prop de l'outil (si custom, ex: pioche) est déjà attaché en permanence
---via Farm.HeldTool/EquipHeldTool tant qu'il est tenu — cette fonction ne
---gère plus que l'animation elle-même, pas de prop temporaire séparé (ça
---créait un doublon flottant en plus de l'outil déjà en main).
local function RunGatherAnim(anim, onComplete)
    local ped = PlayerPedId()

    RequestAnimDict(anim.dict)
    local t = 0
    while not HasAnimDictLoaded(anim.dict) and t < 50 do Wait(100); t = t + 1 end

    if HasAnimDictLoaded(anim.dict) then
        if anim.loopDuration then
            TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false) -- flag=1 : boucle
        else
            TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, anim.duration, 0, 0, false, false, false)
        end
    end
    Wait(anim.loopDuration or anim.duration)
    ClearPedTasks(ped)

    RemoveAnimDict(anim.dict)

    onComplete(true)
end

-- ══════════════════════════════════════════════════════════════════
--  RÉCOLTE
-- ══════════════════════════════════════════════════════════════════

---StartGather
---@param activityKey string
---@param nodeIndex number|nil point de récolte fixe
---@param entity number|nil cadavre ciblé (variante `species`, ex: chasseur)
local function StartGather(activityKey, nodeIndex, entity)
    if Farm.Busy then return end

    local activity = Config.Farm.Activities[activityKey]
    if not activity then return end

    local toolLabel = activity.tool and Config.Items[activity.tool] and Config.Items[activity.tool].label or activity.tool

    if not HasItem(activity.tool) then
        Notify(string.format(Lang.Farm.missing_tool, toolLabel), 'error')
        return
    end

    if not IsToolEquipped(activity.tool) then
        Notify(string.format(Lang.Farm.tool_not_equipped, toolLabel), 'error')
        return
    end

    local payload = { activity = activityKey, nodeIndex = nodeIndex }
    if entity then
        local netId = EnsureNetworked(entity)
        if not netId then
            Notify('Ce cadavre ne peut pas être récupéré.', 'error')
            return
        end
        payload.netId = netId
        Farm.LastHuntEntity = entity
    end

    Farm.Busy = true
    LSLegacy.SendEventToServer('farm:requestGather', payload)
end

LSLegacy.RegisterClientEvent('farm:gatherDenied', function(reason)
    Farm.Busy = false
    if reason then Notify(reason, 'error') end
end)

LSLegacy.RegisterClientEvent('farm:gatherAuthorized', function(data)
    if not data then Farm.Busy = false return end

    local activity = Config.Farm.Activities[data.activity]
    if not activity then Farm.Busy = false return end

    local function SendComplete(hits, rounds)
        LSLegacy.SendEventToServer('farm:completeGather', {
            activity  = data.activity,
            nodeIndex = data.nodeIndex,
            hits      = hits,
            rounds    = rounds,
        })
    end

    if activity.instantGather then
        -- Chasseur : la mise à mort EST l'action, pas de minijeu/anim en plus.
        SendComplete(Config.Farm.Minigame.rounds, Config.Farm.Minigame.rounds)
    elseif activity.gatherAnim then
        -- Un coup d'outil = une récolte réussie (pas de minijeu de précision).
        Notify(Lang.Farm.gather_start, 'info')
        RunGatherAnim(activity.gatherAnim, function()
            SendComplete(Config.Farm.Minigame.rounds, Config.Farm.Minigame.rounds)
        end)
    else
        Notify(Lang.Farm.gather_start, 'info')
        Farm.RunMinigame(function(hits, rounds)
            SendComplete(hits, rounds)
        end)
    end
end)

LSLegacy.RegisterClientEvent('farm:gatherResult', function(data)
    Farm.Busy = false
    -- L'outil custom (pioche, etc.) disparaît des mains dès la récolte
    -- terminée — il se rééquipera automatiquement au prochain coup.
    if Farm.HeldTool then UnequipHeldTool(true) end

    local huntEntity     = Farm.LastHuntEntity
    Farm.LastHuntEntity = nil

    if not data then return end

    if not data.success then
        -- `reason` présent = le serveur a déjà envoyé son propre message précis
        -- (ex: inventaire trop chargé) — évite un doublon contradictoire.
        if not data.reason then
            Notify(Lang.Farm.gather_failed, 'error')
        end
        return
    end

    -- Dépeçage réussi (chasseur) : le cadavre disparaît, pas de double-loot.
    if huntEntity and DoesEntityExist(huntEntity) then
        NetworkRequestControlOfEntity(huntEntity)
        Citizen.SetTimeout(50, function()
            if DoesEntityExist(huntEntity) then DeleteEntity(huntEntity) end
        end)
    end

    local itemLabel = Config.Items[data.item] and Config.Items[data.item].label or data.item
    Notify(string.format(Lang.Farm.gather_success, data.amount or 1, itemLabel), 'success')
end)

-- ── Braconnage — prélèvement de peau (bouton séparé, voir plus bas) ────

local SkinnedCorpses = {} -- [netId] = true — indice client pour masquer l'option une fois utilisée (le serveur reste seul juge)

local function StartPoach(activityKey, entity)
    local netId = EnsureNetworked(entity)
    if not netId then
        Notify('Ce cadavre ne peut pas être dépouillé.', 'error')
        return
    end
    LSLegacy.SendEventToServer('farm:requestPoach', { activity = activityKey, netId = netId })
end

LSLegacy.RegisterClientEvent('farm:poachResult', function(data)
    if not data then return end
    if data.success then
        if data.netId then SkinnedCorpses[data.netId] = true end
        local itemLabel = Config.Items[data.item] and Config.Items[data.item].label or data.item
        Notify(string.format('Braconnage : %s prélevée (illégal).', itemLabel), 'error')
    elseif data.reason then
        Notify(data.reason, 'error')
    end
end)

LSLegacy.RegisterClientEvent('farm:poachingAlertReceived', function(data)
    if not data or not data.coords then return end
    Notify('Braconnage signalé aux forces de l\'ordre.', 'error')
    SetNewWaypoint(data.coords.x, data.coords.y)
end)

-- ══════════════════════════════════════════════════════════════════
--  TRAITEMENT
-- ══════════════════════════════════════════════════════════════════

local function StartProcess(activityKey)
    if Farm.Busy then return end

    local activity = Config.Farm.Activities[activityKey]
    if not activity then return end

    local have = ItemCount(activity.rawItem)
    if have < activity.processing.inputPerUnit then
        local rawLabel = Config.Items[activity.rawItem] and Config.Items[activity.rawItem].label or activity.rawItem
        Notify(string.format(Lang.Farm.process_missing_raw, activity.processing.inputPerUnit, rawLabel), 'error')
        return
    end

    Farm.Busy = true
    LSLegacy.SendEventToServer('farm:requestProcess', { activity = activityKey })
end

LSLegacy.RegisterClientEvent('farm:processDenied', function(reason)
    Farm.Busy = false
    if reason then Notify(reason, 'error') end
end)

LSLegacy.RegisterClientEvent('farm:processAuthorized', function(data)
    if not data then Farm.Busy = false return end

    local activity = Config.Farm.Activities[data.activity]

    Notify(Lang.Farm.process_start, 'info')

    Farm.RunMinigame(function(hits, rounds, success)
        LSLegacy.SendEventToServer('farm:completeProcess', {
            activity = data.activity,
            hits     = hits,
            rounds   = rounds,
        })
    end, activity and (activity.processAnim or activity.gatherAnim))
end)

LSLegacy.RegisterClientEvent('farm:processResult', function(data)
    Farm.Busy = false
    if not data then return end

    if not data.success then
        if not data.reason then
            Notify(Lang.Farm.process_failed, 'error')
        end
        return
    end

    local itemLabel = Config.Items[data.item] and Config.Items[data.item].label or data.item
    Notify(string.format(Lang.Farm.process_success, data.amount, itemLabel), 'success')
end)

-- ══════════════════════════════════════════════════════════════════
--  REVENTE
-- ══════════════════════════════════════════════════════════════════

local function HasAnythingToSell(activity)
    if activity.processedItems then
        for _, entry in ipairs(activity.processedItems) do
            if ItemCount(entry.item) > 0 then return true end
        end
    elseif activity.processedItem and ItemCount(activity.processedItem) > 0 then
        return true
    end

    if activity.directSellItems then
        for _, entry in ipairs(activity.directSellItems) do
            if ItemCount(entry.item) > 0 then return true end
        end
    end

    if activity.multiSellItems then
        for _, ms in ipairs(activity.multiSellItems) do
            if ItemCount(ms.rawItem) > 0 then return true end
        end
    end

    return false
end

local function SellProcessed(activityKey)
    local activity = Config.Farm.Activities[activityKey]
    if not activity then return end

    if not HasAnythingToSell(activity) then
        Notify(Lang.Farm.sell_nothing_to_sell, 'error')
        return
    end

    LSLegacy.SendEventToServer('farm:sellProcessed', { activity = activityKey })
end

LSLegacy.RegisterClientEvent('farm:sellResult', function(data)
    if not data or not data.success then return end

    local parts = {}
    for _, entry in ipairs(data.sold or {}) do
        local itemLabel = Config.Items[entry.item] and Config.Items[entry.item].label or entry.item
        table.insert(parts, string.format('%d %s', entry.amount, itemLabel))
    end

    Notify(string.format(Lang.Farm.sell_done, table.concat(parts, ' + '), data.total), 'success')
end)

-- ══════════════════════════════════════════════════════════════════
--  COMPACTAGE — sac de pierres
-- ══════════════════════════════════════════════════════════════════

LSLegacy.RegisterClientEvent('farm:compactStonesResult', function(data)
    if not data or not data.success then return end
    Notify(string.format('%d sac(s) de pierres fabriqué(s).', data.bags), 'success')
end)

-- ══════════════════════════════════════════════════════════════════
--  BOUTIQUE — achat public, alimentée par les ventes des mineurs
-- ══════════════════════════════════════════════════════════════════

LSLegacy.RegisterClientEvent('farm:shopStockResult', function(stock)
    stock = stock or {}
    local options = {}
    local seen = {} -- évite les doublons : plusieurs espèces partagent les mêmes `shopItem` (viande, tripes, graisse)

    local function AddShopOption(entry)
        if not entry.shopItem or seen[entry.shopItem] then return end
        seen[entry.shopItem] = true
        local qty = stock[entry.shopItem] or 0
        local itemLabel = Config.Items[entry.shopItem] and Config.Items[entry.shopItem].label or entry.shopItem
        options[#options + 1] = {
            title = itemLabel .. (qty > 0 and (' (x' .. qty .. ')') or ' — Rupture de stock'),
            description = qty > 0 and (entry.buyPrice .. '$ / unité') or 'Aucun stock disponible',
            icon = 'fa-solid fa-cart-shopping',
            disabled = qty <= 0,
            onSelect = function()
                local qtyStr = LSLegacy.KeyboardInput('Quantité à acheter', 4)
                local amount = tonumber(qtyStr)
                if not amount or amount <= 0 then return end
                LSLegacy.SendEventToServer('farm:buyShopItem', { item = entry.shopItem, amount = math.floor(amount) })
            end,
        }
    end

    for _, activity in pairs(Config.Farm.Activities) do
        for _, entry in ipairs(activity.directSellItems or {}) do AddShopOption(entry) end
        for _, entry in ipairs(activity.processedItems or {}) do AddShopOption(entry) end
        if activity.multiSellItems then
            for _, ms in ipairs(activity.multiSellItems) do
                for _, entry in ipairs(ms.outputs) do AddShopOption(entry) end
            end
        end
    end

    lib.registerContext({ id = 'farm_shop', title = 'Boutique — Minéraux', options = options })
    lib.showContext('farm_shop')
end)

LSLegacy.RegisterClientEvent('farm:buyResult', function(data)
    if not data then return end
    if not data.success then
        local reasons = {
            no_stock  = 'Stock insuffisant.',
            no_money  = "Vous n'avez pas assez d'argent.",
            too_heavy = 'Inventaire trop chargé.',
        }
        Notify(reasons[data.reason] or 'Achat impossible.', 'error')
        return
    end
    local itemLabel = Config.Items[data.item] and Config.Items[data.item].label or data.item
    Notify(string.format('Achat effectué : %d %s pour %d$.', data.amount, itemLabel, data.cost), 'success')
end)

local function OpenShopMenu()
    LSLegacy.SendEventToServer('farm:requestShopStock')
end

if Config.Farm.StoneBagStation then
    exports.ox_target:addBoxZone({
        coords   = Config.Farm.StoneBagStation.coords,
        size     = Config.Farm.ZoneSize,
        rotation = 0.0,
        debug    = false,
        options  = {
            {
                name = 'farm_compact_stones',
                icon = 'fa-solid fa-box-archive',
                label = 'Compacter les pierres (sac de 20)',
                distance = Config.Farm.ZoneDistance,
                canInteract = function() return not Farm.Busy end,
                onSelect = function() LSLegacy.SendEventToServer('farm:compactStones') end,
            },
        },
    })
end

if Config.Farm.ShopBuyPoint then
    exports.ox_target:addBoxZone({
        coords   = Config.Farm.ShopBuyPoint,
        size     = Config.Farm.ZoneSize,
        rotation = 0.0,
        debug    = false,
        options  = {
            {
                name = 'farm_shop_buy',
                icon = 'fa-solid fa-cart-shopping',
                label = 'Boutique minéraux — Acheter',
                distance = Config.Farm.ZoneDistance,
                canInteract = function() return not Farm.Busy end,
                onSelect = OpenShopMenu,
            },
        },
    })
end

-- ══════════════════════════════════════════════════════════════════
--  ZONES OX_TARGET
-- ══════════════════════════════════════════════════════════════════

for activityKey, activity in pairs(Config.Farm.Activities) do
    -- Nœuds de récolte fixes
    for nodeIndex, node in ipairs(activity.nodes or {}) do
        exports.ox_target:addBoxZone({
            coords   = node.coords,
            size     = Config.Farm.ZoneSize,
            rotation = 0.0,
            debug    = false,
            options  = {
                {
                    name = 'farm_gather_' .. activityKey .. '_' .. nodeIndex,
                    icon = 'fa-solid fa-hand-fist',
                    label = activity.label .. ' — Récolter',
                    distance = Config.Farm.ZoneDistance,
                    canInteract = function() return not Farm.Busy end,
                    onSelect = function() StartGather(activityKey, nodeIndex) end,
                },
            },
        })
    end

    -- Gibier chassable (chasseur) — ciblage sur le cadavre une fois mort,
    -- n'importe où sur la carte (peds réels, contrairement au décor/arbres).
    -- Récupération instantanée (`instantGather`), pas de minijeu.
    --
    -- Le ramassage de la carcasse (label selon l'outil en main, purement
    -- cosmétique — le résultat est identique dans les deux cas, voir
    -- `StartGather`) est SÉPARÉ du prélèvement de la peau : la peau est un
    -- bouton en plus, uniquement sur les espèces braconnables
    -- (`species.peauItem`, coyote/cougar) et couteau en main — voir
    -- `Config.Farm.Activities.chasseur.poaching`.
    if activity.species then
        local modelHashes = {}
        for i, sp in ipairs(activity.species) do
            modelHashes[i] = GetHashKey(sp.model)
        end

        local knifeTool = activity.poaching and activity.poaching.tool

        local function FindSpeciesByEntity(entity)
            if not DoesEntityExist(entity) then return nil end
            local model = GetEntityModel(entity)
            for _, sp in ipairs(activity.species) do
                if GetHashKey(sp.model) == model then return sp end
            end
            return nil
        end

        exports.ox_target:addModel(modelHashes, {
            {
                name = 'farm_hunt_depecer_' .. activityKey,
                icon = 'fa-solid fa-hand-fist',
                label = activity.label .. ' — Dépecer',
                distance = Config.Farm.ZoneDistance,
                canInteract = function(entity)
                    if Farm.Busy or not DoesEntityExist(entity) or not IsEntityDead(entity) then return false end
                    if not (knifeTool and IsToolEquipped(knifeTool)) then return false end
                    -- Espèce sans `rawItem` (coyote, chassé pour la peau
                    -- seule) : aucune carcasse à récupérer.
                    local sp = FindSpeciesByEntity(entity)
                    return sp ~= nil and sp.rawItem ~= nil
                end,
                onSelect = function(data) StartGather(activityKey, nil, data.entity) end,
            },
            {
                name = 'farm_hunt_ramasser_' .. activityKey,
                icon = 'fa-solid fa-hand-fist',
                label = activity.label .. ' — Ramasser le cadavre',
                distance = Config.Farm.ZoneDistance,
                canInteract = function(entity)
                    if Farm.Busy or not DoesEntityExist(entity) or not IsEntityDead(entity) then return false end
                    if knifeTool and IsToolEquipped(knifeTool) then return false end
                    local sp = FindSpeciesByEntity(entity)
                    return sp ~= nil and sp.rawItem ~= nil
                end,
                onSelect = function(data) StartGather(activityKey, nil, data.entity) end,
            },
            {
                name = 'farm_hunt_skin_' .. activityKey,
                icon = 'fa-solid fa-knife',
                label = activity.label .. ' — Prélever la peau',
                distance = Config.Farm.ZoneDistance,
                canInteract = function(entity)
                    if not knifeTool or not IsToolEquipped(knifeTool) then return false end
                    if not DoesEntityExist(entity) or not IsEntityDead(entity) then return false end
                    -- Pas de `EnsureNetworked` ici : `canInteract` tourne à
                    -- chaque frame de visée et ne doit ni yield ni émettre de
                    -- warning sur les peds ambiants non networkés — on ne
                    -- consulte le netId que s'il en existe déjà un.
                    if NetworkGetEntityIsNetworked(entity)
                       and SkinnedCorpses[NetworkGetNetworkIdFromEntity(entity)] then
                        return false
                    end
                    local sp = FindSpeciesByEntity(entity)
                    return sp ~= nil and sp.peauItem ~= nil
                end,
                onSelect = function(data) StartPoach(activityKey, data.entity) end,
            },
        })
    end

    -- Station de traitement — sur un PNJ (`processingNpc`) si défini, sinon
    -- une zone au sol comme les autres activités. Absente si l'activité n'a
    -- rien à faire traiter par le joueur lui-même (ex: chasseur, où c'est le
    -- boucher qui transforme à la vente — voir `multiSellItems`).
    local hasSelfProcessing = activity.processedItems ~= nil or activity.processedItem ~= nil
    local processOptions = hasSelfProcessing and {
        {
            name = 'farm_process_' .. activityKey,
            icon = 'fa-solid fa-industry',
            label = activity.label .. ' — Traiter',
            distance = Config.Farm.ZoneDistance,
            canInteract = function() return not Farm.Busy end,
            onSelect = function() StartProcess(activityKey) end,
        },
    } or nil

    -- Point de revente — séparé de la station si `sellPoint` est défini,
    -- sinon même emplacement que le traitement (comportement historique).
    local sellOptions = {
        {
            name = 'farm_sell_' .. activityKey,
            icon = 'fa-solid fa-sack-dollar',
            label = activity.label .. ' — Vendre',
            distance = Config.Farm.ZoneDistance,
            canInteract = function() return not Farm.Busy end,
            onSelect = function() SellProcessed(activityKey) end,
        },
    }

    if activity.processingNpc and not activity.sellPoint then
        -- Même PNJ pour traiter (si applicable) ET vendre : les options
        -- s'attachent ensemble, un seul PNJ à spawn.
        local combined = {}
        for _, o in ipairs(processOptions or {}) do combined[#combined + 1] = o end
        for _, o in ipairs(sellOptions) do combined[#combined + 1] = o end
        SpawnStaticPed(activity.processing.coords, activity.processingNpc.model, activity.processingNpc.heading, combined)
    else
        if activity.processingNpc then
            if processOptions then
                SpawnStaticPed(activity.processing.coords, activity.processingNpc.model, activity.processingNpc.heading, processOptions)
            end
        elseif processOptions then
            exports.ox_target:addBoxZone({
                coords   = activity.processing.coords,
                size     = Config.Farm.ZoneSize,
                rotation = 0.0,
                debug    = false,
                options  = processOptions,
            })
        end

        exports.ox_target:addBoxZone({
            coords   = activity.sellPoint or activity.processing.coords,
            size     = Config.Farm.ZoneSize,
            rotation = 0.0,
            debug    = false,
            options  = sellOptions,
        })
    end

    -- Receleur (braconnage) — PNJ séparé du boucher, rachète les peaux
    -- uniquement, jamais dans la boutique publique.
    if activity.poaching and activity.poaching.fenceNpc and activity.poaching.fenceCoords then
        SpawnStaticPed(activity.poaching.fenceCoords, activity.poaching.fenceNpc.model, activity.poaching.fenceNpc.heading, {
            {
                name = 'farm_poaching_sell_' .. activityKey,
                icon = 'fa-solid fa-mask',
                label = 'Receleur — Vendre les peaux',
                distance = Config.Farm.ZoneDistance,
                canInteract = function() return not Farm.Busy end,
                onSelect = function() LSLegacy.SendEventToServer('farm:sellPoaching', { activity = activityKey }) end,
            },
        })
    end
end
