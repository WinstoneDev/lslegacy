-- Chaque étape (outils, quantités, succès du minijeu) est revalidée ici, jamais prise au mot du client.

local rateLimits = {
    ['farm:animalSpawned'] = 20, ['farm:requestGather'] = 20, ['farm:completeGather'] = 20,
    ['farm:requestPoach'] = 20, ['farm:requestProcess'] = 20, ['farm:completeProcess'] = 20,
    ['farm:sellProcessed'] = 15, ['farm:sellPoaching'] = 15, ['farm:compactStones'] = 15,
    ['farm:requestShopStock'] = 20, ['farm:buyShopItem'] = 15,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local NodeCooldowns  = {} -- ['activityKey_nodeIndex'] = os.time() de la dernière récolte
local PendingGather   = {} -- [source] = { activity = activityKey, species = speciesTable|nil } — une autorisation en attente, consommée une seule fois
local LootedCorpses   = {} -- [netId] = true — cadavre de gibier déjà dépecé (chasseur)
local PoachedCorpses  = {} -- [netId] = true — peau déjà prélevée sur ce cadavre (indépendant du dépeçage, un cadavre peut être dépecé ET dépouillé)

-- Stock boutique (mineur), pattern repris de module/ltd/server/stock.lua : une seule boutique globale ici.
local ShopStock = {} -- [item] = quantity

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS farm_shop_stock (
        item     VARCHAR(60) NOT NULL PRIMARY KEY,
        quantity INT NOT NULL DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.fetchAll('SELECT item, quantity FROM farm_shop_stock', {}, function(rows)
    for _, row in ipairs(rows or {}) do
        ShopStock[row.item] = row.quantity
    end
end)

local function SaveShopStock(item)
    MySQL.Async.execute(
        'INSERT INTO farm_shop_stock (item, quantity) VALUES (@i, @q) ON DUPLICATE KEY UPDATE quantity=@q',
        { ['@i'] = item, ['@q'] = ShopStock[item] or 0 }
    )
end

-- [shopItem] = buyPrice, construit une fois depuis toutes les activités.
local ShopBuyPrices = {}
for _, activity in pairs(Config.Farm.Activities) do
    local lists = {}
    if activity.directSellItems then table.insert(lists, activity.directSellItems) end
    if activity.processedItems then table.insert(lists, activity.processedItems) end
    if activity.multiSellItems then
        for _, ms in ipairs(activity.multiSellItems) do table.insert(lists, ms.outputs) end
    end
    for _, list in ipairs(lists) do
        for _, entry in ipairs(list) do
            if entry.shopItem and entry.buyPrice then
                ShopBuyPrices[entry.shopItem] = entry.buyPrice
            end
        end
    end
end

-- Peuplement de la faune arbitré par le serveur : le client ne décide jamais seul du spawn (risque de double spawn si deux chasseurs se croisent), le serveur reste l'unique compteur et délègue juste la création au client le mieux placé.

local HuntZones         = {} -- [zoneTable de la config] = { model, coords, radius, count, netIds = {}, pending = 0 }
local AmbientTracking    = {} -- [src] = { [speciesTable de la config] = { netIds = {}, pending = 0 } }
local PendingHuntSpawns  = {} -- [reqId] = { target = state|track, src = source } — requête envoyée, pas encore confirmée
local nextHuntRequestId  = 0

do
    local chasseur = Config.Farm.Activities.chasseur
    if chasseur and chasseur.species then
        for _, sp in ipairs(chasseur.species) do
            for _, zone in ipairs(sp.spawnZones or {}) do
                HuntZones[zone] = {
                    model = sp.model, coords = zone.coords, radius = zone.radius, count = zone.count,
                    netIds = {}, pending = 0,
                }
            end
        end
    end
end

-- Rectangle approximatif de la zone urbaine dense de Los Santos, copie de la même heuristique côté client — pure géométrie, pas besoin de native ici.
local function IsRuralAreaServer(coords)
    local inCity = coords.x > -1300.0 and coords.x < 1300.0
               and coords.y > -3200.0 and coords.y < 1300.0
    return not inCity
end

local function PurgeDeadNetIds(list)
    for i = #list, 1, -1 do
        local ent = NetworkGetEntityFromNetworkId(list[i])
        if not DoesEntityExist(ent) then table.remove(list, i) end
    end
end

-- Envoie la demande à un seul client et marque la place "en attente" pour ne pas la redemander avant confirmation.
local function RequestHuntSpawn(src, target, event, payload)
    nextHuntRequestId = nextHuntRequestId + 1
    local reqId = nextHuntRequestId
    PendingHuntSpawns[reqId] = { target = target, src = src }
    target.pending = target.pending + 1
    payload.reqId = reqId
    TriggerClientEvent(event, src, payload)
end

-- `netId` présent si le spawn a réussi côté client, absent sinon (modèle non chargé, filtre eau raté...) — dans les deux cas la place "pending" est libérée.
LSLegacy.Events.Register('farm:animalSpawned', function(data)
    local src = source
    if not data or not data.reqId then return end
    local req = PendingHuntSpawns[data.reqId]
    if not req or req.src ~= src then return end
    PendingHuntSpawns[data.reqId] = nil
    req.target.pending = math.max(0, req.target.pending - 1)
    if data.netId then table.insert(req.target.netIds, data.netId) end
end)

Citizen.CreateThread(function()
    local chasseur = Config.Farm.Activities.chasseur
    if not chasseur or not chasseur.species then return end

    while true do
        Wait(Config.Farm.HuntSpawn.checkInterval)

        for zone, state in pairs(HuntZones) do
            PurgeDeadNetIds(state.netIds)

            if (#state.netIds + state.pending) < state.count then
                -- Délègue au joueur connecté le plus proche, dans le rayon de déclenchement.
                local bestSrc, bestDist
                for _, playerId in ipairs(GetPlayers()) do
                    local ped = GetPlayerPed(playerId)
                    if ped ~= 0 then
                        local dist = #(GetEntityCoords(ped) - state.coords)
                        if dist <= Config.Farm.HuntSpawn.triggerRadius and (not bestDist or dist < bestDist) then
                            bestSrc, bestDist = tonumber(playerId), dist
                        end
                    end
                end

                if bestSrc then
                    RequestHuntSpawn(bestSrc, state, 'farm:spawnZoneAnimal', {
                        model = state.model, coords = state.coords, radius = state.radius,
                    })
                end
            end
        end

        -- Oiseaux ambiants : centrés sur chaque joueur, pas de zone fixe.
        for _, sp in ipairs(chasseur.species) do
            if sp.ambient then
                for _, playerId in ipairs(GetPlayers()) do
                    local src = tonumber(playerId)
                    local ped = GetPlayerPed(playerId)
                    if ped ~= 0 then
                        AmbientTracking[src] = AmbientTracking[src] or {}
                        local track = AmbientTracking[src][sp]
                        if not track then
                            track = { netIds = {}, pending = 0 }
                            AmbientTracking[src][sp] = track
                        end

                        PurgeDeadNetIds(track.netIds)

                        local coords  = GetEntityCoords(ped)
                        local ruralOk = not sp.ambient.ruralOnly or IsRuralAreaServer(coords)

                        if ruralOk and (#track.netIds + track.pending) < sp.ambient.maxNearby then
                            RequestHuntSpawn(src, track, 'farm:spawnAmbientAnimal', {
                                model = sp.model, requiresWater = sp.ambient.requiresWater or false,
                            })
                        end
                    end
                end
            end
        end
    end
end)

local function GetPlayer(src)
    return LSLegacy.Players.Get(src)
end

local function Notify(src, msg, t)
    TriggerClientEvent(Config.Farm.NotifyEvent, src, 'Farm', msg, 5000, t or 'info')
end

local function GetItemCount(player, item)
    local entry = LSLegacy.Inventory.GetInventoryItem(player, item)
    return entry and entry.count or 0
end

---@param list table { { item = string, weight = number, ... }, ... }
---@return table l'entrée tirée
local function PickWeighted(list)
    local total = 0
    for _, entry in ipairs(list) do total = total + entry.weight end

    local roll = math.random() * total
    local acc  = 0
    for _, entry in ipairs(list) do
        acc = acc + entry.weight
        if roll <= acc then return entry end
    end
    return list[#list]
end

-- Liste unifiée de tout ce qui se vend au point de vente d'une activité (produits transformés + items bruts vendables directement).
---@param activity table
---@return table { { item = string, price = number }, ... }
local function GetSellableItems(activity)
    local list = {}

    if activity.processedItems then
        for _, entry in ipairs(activity.processedItems) do
            table.insert(list, { item = entry.item, price = entry.price, shopItem = entry.shopItem })
        end
    elseif activity.processedItem then
        table.insert(list, { item = activity.processedItem, price = activity.sellPrice })
    end

    if activity.directSellItems then
        for _, entry in ipairs(activity.directSellItems) do
            table.insert(list, { item = entry.item, price = entry.price, shopItem = entry.shopItem })
        end
    end

    return list
end

LSLegacy.Events.Register('farm:requestGather', function(data)
    local src    = source
    local player = GetPlayer(src)
    if not player then return end
    if not data or not data.activity then return end
    if not data.nodeIndex and not data.netId then return end

    local activity = Config.Farm.Activities[data.activity]
    if not activity then return end

    -- Deux variantes de nœud : point fixe (cooldown temporel) ou cadavre de gibier réel (un seul dépeçage possible, pas de cooldown).
    local nodeKey
    local huntedSpecies -- espèce identifiée par le modèle du cadavre (chasseur uniquement)

    if data.nodeIndex then
        local node = activity.nodes and activity.nodes[data.nodeIndex]
        if not node then return end
        nodeKey = data.activity .. '_n' .. data.nodeIndex
    else
        if not activity.species then return end
        if LootedCorpses[data.netId] then
            TriggerClientEvent('farm:gatherDenied', src, 'Ce cadavre a déjà été dépecé.')
            return
        end

        local entity = NetworkGetEntityFromNetworkId(data.netId)
        -- `IsEntityDead` n'existe pas côté serveur sur ce build fxserver
        -- (native client-only ici) — santé <= 0 est l'équivalent fiable.
        if not DoesEntityExist(entity) or GetEntityHealth(entity) > 0 then
            TriggerClientEvent('farm:gatherDenied', src, 'Cadavre introuvable.')
            return
        end

        local model = GetEntityModel(entity)
        for _, sp in ipairs(activity.species) do
            if GetHashKey(sp.model) == model then huntedSpecies = sp break end
        end
        -- Sans `rawItem`, l'espèce n'a pas de carcasse récupérable (coyote) — refuse ici aussi le cas d'un event forgé.
        if not huntedSpecies or not huntedSpecies.rawItem then return end

        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        local entCoords     = GetEntityCoords(entity)
        if #(entCoords - playerCoords) > (Config.Farm.ZoneDistance + 3.0) then
            TriggerClientEvent('farm:gatherDenied', src, 'Trop loin du cadavre.')
            return
        end

        nodeKey = 'corpse_' .. data.netId
    end

    if activity.tool then
        if GetItemCount(player, activity.tool) <= 0 then
            local toolLabel = Config.Items[activity.tool] and Config.Items[activity.tool].label or activity.tool
            TriggerClientEvent('farm:gatherDenied', src, string.format(Lang.Farm.missing_tool, toolLabel))
            return
        end
    end

    if data.nodeIndex then
        local now      = os.time()
        local lastTime = NodeCooldowns[nodeKey] or 0
        if (now - lastTime) < (activity.nodeCooldown / 1000) then
            TriggerClientEvent('farm:gatherDenied', src, Lang.Farm.node_cooldown)
            return
        end
        NodeCooldowns[nodeKey] = now
    else
        LootedCorpses[data.netId] = true
    end
    PendingGather[src] = { activity = data.activity, species = huntedSpecies }
    TriggerClientEvent('farm:gatherAuthorized', src, { activity = data.activity, nodeIndex = data.nodeIndex })
end)

LSLegacy.Events.Register('farm:completeGather', function(data)
    local src     = source
    local player  = GetPlayer(src)
    if not player then return end
    if not data or not data.activity then return end
    local pending = PendingGather[src]
    if not pending or pending.activity ~= data.activity then return end
    PendingGather[src] = nil

    local activity = Config.Farm.Activities[data.activity]
    if not activity then return end

    local hits    = math.min(tonumber(data.hits) or 0, Config.Farm.Minigame.rounds)
    local success = hits >= Config.Farm.Minigame.requiredHits

    if not success then
        TriggerClientEvent('farm:gatherResult', src, { success = false })
        return
    end

    -- Quantité et item toujours dérivés de la config serveur, jamais du client.
    local amount = (activity.gatherAnim and activity.gatherAnim.yieldAmount) or 1

    -- Chasseur : l'item rendu dépend de l'espèce identifiée à l'autorisation, jamais du client.
    local item = (pending.species and pending.species.rawItem) or activity.rawItem
    if activity.gatherYields then
        item = PickWeighted(activity.gatherYields).item
    end

    if not LSLegacy.Inventory.CanCarryItem(player, item, amount) then
        -- `reason` distinct de l'échec de minijeu, pour éviter un message générique contradictoire côté client.
        TriggerClientEvent('farm:gatherResult', src, { success = false, reason = 'too_heavy' })
        Notify(src, 'Inventaire trop chargé pour récolter.', 'error')
        return
    end

    LSLegacy.Inventory.AddItemInInventory(player, item, amount)

    TriggerClientEvent('farm:gatherResult', src, { success = true, item = item, amount = amount })
end)

-- Braconnage (chasseur, coyote/cougar uniquement) : action séparée du dépeçage, le cadavre reste en place après.
LSLegacy.Events.Register('farm:requestPoach', function(data)
    local src    = source
    local player = GetPlayer(src)
    if not player then return end
    if not data or not data.activity or not data.netId then return end

    local activity = Config.Farm.Activities[data.activity]
    if not activity or not activity.poaching or not activity.species then return end

    if PoachedCorpses[data.netId] then
        TriggerClientEvent('farm:poachResult', src, { success = false, reason = 'Peau déjà prélevée sur ce cadavre.' })
        return
    end

    local entity = NetworkGetEntityFromNetworkId(data.netId)
    if not DoesEntityExist(entity) or GetEntityHealth(entity) > 0 then
        TriggerClientEvent('farm:poachResult', src, { success = false, reason = 'Cadavre introuvable.' })
        return
    end

    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local entCoords     = GetEntityCoords(entity)
    if #(entCoords - playerCoords) > (Config.Farm.ZoneDistance + 3.0) then
        TriggerClientEvent('farm:poachResult', src, { success = false, reason = 'Trop loin du cadavre.' })
        return
    end

    local model = GetEntityModel(entity)
    local species
    for _, sp in ipairs(activity.species) do
        if GetHashKey(sp.model) == model then species = sp break end
    end
    if not species or not species.peauItem then return end

    -- Le couteau en main est vérifié côté client pour l'affichage ; ici on revalide juste sa présence en inventaire, seule chose fiable côté serveur.
    if GetItemCount(player, activity.poaching.tool) <= 0 then
        local toolLabel = Config.Items[activity.poaching.tool] and Config.Items[activity.poaching.tool].label or activity.poaching.tool
        TriggerClientEvent('farm:poachResult', src, { success = false, reason = string.format(Lang.Farm.missing_tool, toolLabel) })
        return
    end

    if not LSLegacy.Inventory.CanCarryItem(player, species.peauItem, 1) then
        TriggerClientEvent('farm:poachResult', src, { success = false, reason = 'Inventaire trop chargé.' })
        return
    end

    PoachedCorpses[data.netId] = true
    LSLegacy.Inventory.AddItemInInventory(player, species.peauItem, 1)

    if math.random() < (activity.poaching.policeAlertChance or 0) and type(GetPoliceOfficers) == 'function' then
        local coords = GetEntityCoords(GetPlayerPed(src))
        for officerSrc in pairs(GetPoliceOfficers()) do
            TriggerClientEvent('farm:poachingAlertReceived', officerSrc, { coords = coords })
        end
    end

    TriggerClientEvent('farm:poachResult', src, { success = true, item = species.peauItem, netId = data.netId })
end)

LSLegacy.Events.Register('farm:requestProcess', function(data)
    local src    = source
    local player = GetPlayer(src)
    if not player then return end
    if not data or not data.activity then return end

    local activity = Config.Farm.Activities[data.activity]
    if not activity then return end

    local have = GetItemCount(player, activity.rawItem)
    if have < activity.processing.inputPerUnit then
        local rawLabel = Config.Items[activity.rawItem] and Config.Items[activity.rawItem].label or activity.rawItem
        TriggerClientEvent('farm:processDenied', src, string.format(Lang.Farm.process_missing_raw, activity.processing.inputPerUnit, rawLabel))
        return
    end

    TriggerClientEvent('farm:processAuthorized', src, { activity = data.activity })
end)

LSLegacy.Events.Register('farm:completeProcess', function(data)
    local src    = source
    local player = GetPlayer(src)
    if not player then return end
    if not data or not data.activity then return end

    local activity = Config.Farm.Activities[data.activity]
    if not activity then return end

    local hits    = math.min(tonumber(data.hits) or 0, Config.Farm.Minigame.rounds)
    local success = hits >= Config.Farm.Minigame.requiredHits

    if not success then
        TriggerClientEvent('farm:processResult', src, { success = false })
        return
    end

    -- Revalidation : les matières premières sont toujours là au moment de conclure
    local have = GetItemCount(player, activity.rawItem)
    if have < activity.processing.inputPerUnit then
        TriggerClientEvent('farm:processResult', src, { success = false })
        return
    end

    -- Sortie fixe ou tirage pondéré parmi plusieurs variantes (ex : métaux du mineur), jamais décidé par le client.
    local outputItem = activity.processedItem
    if activity.processedItems then
        outputItem = PickWeighted(activity.processedItems).item
    end

    if not LSLegacy.Inventory.CanCarryItem(player, outputItem, activity.processing.outputPerUnit) then
        TriggerClientEvent('farm:processResult', src, { success = false, reason = 'too_heavy' })
        Notify(src, 'Inventaire trop chargé pour ce traitement.', 'error')
        return
    end

    LSLegacy.Inventory.RemoveItemInInventory(player, activity.rawItem, activity.processing.inputPerUnit)
    LSLegacy.Inventory.AddItemInInventory(player, outputItem, activity.processing.outputPerUnit)

    TriggerClientEvent('farm:processResult', src, {
        success = true,
        item    = outputItem,
        amount  = activity.processing.outputPerUnit,
    })
end)

LSLegacy.Events.Register('farm:sellProcessed', function(data)
    local src    = source
    local player = GetPlayer(src)
    if not player then return end
    if not data or not data.activity then return end

    local activity = Config.Farm.Activities[data.activity]
    if not activity then return end

    local total = 0
    local sold  = {}

    for _, sellable in ipairs(GetSellableItems(activity)) do
        local have = GetItemCount(player, sellable.item)
        if have > 0 then
            LSLegacy.Inventory.RemoveItemInInventory(player, sellable.item, have)
            total = total + have * sellable.price
            table.insert(sold, { item = sellable.item, amount = have })

            if sellable.shopItem then
                ShopStock[sellable.shopItem] = (ShopStock[sellable.shopItem] or 0) + have
                SaveShopStock(sellable.shopItem)
            end
        end
    end

    -- Vente directe avec découpe fixe par unité et par espèce (boucher du chasseur), jamais décidé par le client.
    if activity.multiSellItems then
        for _, ms in ipairs(activity.multiSellItems) do
            local have = GetItemCount(player, ms.rawItem)
            if have > 0 then
                LSLegacy.Inventory.RemoveItemInInventory(player, ms.rawItem, have)

                for _, output in ipairs(ms.outputs) do
                    local amount = output.amount * have
                    total = total + amount * output.price
                    table.insert(sold, { item = output.item, amount = amount })
                    if output.shopItem then
                        ShopStock[output.shopItem] = (ShopStock[output.shopItem] or 0) + amount
                        SaveShopStock(output.shopItem)
                    end
                end
            end
        end
    end

    if total == 0 then
        TriggerClientEvent('farm:sellResult', src, { success = false })
        return
    end

    if activity.dirty then
        LSLegacy.Money.AddPlayerDirtyMoney(player, total)
    else
        LSLegacy.Bank.PaySalary(player, total, 'Salaire - Vente ' .. (activity.label or data.activity))
    end

    TriggerClientEvent('farm:sellResult', src, {
        success = true,
        sold    = sold,
        total   = total,
    })
end)

-- Revente des peaux : passe uniquement par le receleur, jamais par la boutique publique (absentes de `directSellItems`/`multiSellItems`). Argent normal, pas sale.
LSLegacy.Events.Register('farm:sellPoaching', function(data)
    local src    = source
    local player = GetPlayer(src)
    if not player then return end
    if not data or not data.activity then return end

    local activity = Config.Farm.Activities[data.activity]
    if not activity or not activity.poaching or not activity.species then return end

    local total = 0
    local sold  = {}

    for _, sp in ipairs(activity.species) do
        if sp.peauItem then
            local have = GetItemCount(player, sp.peauItem)
            if have > 0 then
                LSLegacy.Inventory.RemoveItemInInventory(player, sp.peauItem, have)
                total = total + have * (sp.peauPrice or 0)
                table.insert(sold, { item = sp.peauItem, amount = have })
            end
        end
    end

    if total == 0 then
        TriggerClientEvent('farm:sellResult', src, { success = false })
        return
    end

    LSLegacy.Money.AddPlayerMoney(player, total)

    TriggerClientEvent('farm:sellResult', src, {
        success = true,
        sold    = sold,
        total   = total,
    })
end)

LSLegacy.Events.Register('farm:compactStones', function()
    local src     = source
    local player  = GetPlayer(src)
    if not player then return end

    local station = Config.Farm.StoneBagStation
    local have    = GetItemCount(player, station.inputItem)
    local bags    = math.floor(have / station.inputAmount)

    if bags < 1 then
        local label = Config.Items[station.inputItem] and Config.Items[station.inputItem].label or station.inputItem
        Notify(src, string.format('Il vous faut au moins %d %s.', station.inputAmount, label), 'error')
        return
    end

    if not LSLegacy.Inventory.CanCarryItem(player, station.outputItem, bags) then
        Notify(src, 'Inventaire trop chargé pour ce sac.', 'error')
        return
    end

    LSLegacy.Inventory.RemoveItemInInventory(player, station.inputItem, bags * station.inputAmount)
    LSLegacy.Inventory.AddItemInInventory(player, station.outputItem, bags)

    TriggerClientEvent('farm:compactStonesResult', src, { success = true, bags = bags })
end)

LSLegacy.Events.Register('farm:requestShopStock', function()
    local src = source
    TriggerClientEvent('farm:shopStockResult', src, ShopStock)
end)

LSLegacy.Events.Register('farm:buyShopItem', function(data)
    local src    = source
    local player = GetPlayer(src)
    if not player then return end
    if not data or not data.item then return end

    local buyPrice = ShopBuyPrices[data.item]
    if not buyPrice then return end

    local amount = math.floor(tonumber(data.amount) or 0)
    if amount <= 0 then return end

    local stock = ShopStock[data.item] or 0
    if stock < amount then
        TriggerClientEvent('farm:buyResult', src, { success = false, reason = 'no_stock' })
        return
    end

    local cost = amount * buyPrice
    if (player.cash or 0) < cost then
        TriggerClientEvent('farm:buyResult', src, { success = false, reason = 'no_money' })
        return
    end

    if not LSLegacy.Inventory.CanCarryItem(player, data.item, amount) then
        TriggerClientEvent('farm:buyResult', src, { success = false, reason = 'too_heavy' })
        return
    end

    ShopStock[data.item] = stock - amount
    SaveShopStock(data.item)

    LSLegacy.Money.RemovePlayerMoney(player, cost)
    LSLegacy.Inventory.AddItemInInventory(player, data.item, amount)

    TriggerClientEvent('farm:buyResult', src, { success = true, item = data.item, amount = amount, cost = cost })
end)

AddEventHandler('playerDropped', function()
    PendingGather[source]    = nil
    AmbientTracking[source]  = nil
    for reqId, req in pairs(PendingHuntSpawns) do
        if req.src == source then
            req.target.pending = math.max(0, req.target.pending - 1)
            PendingHuntSpawns[reqId] = nil
        end
    end
end)
