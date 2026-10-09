-- Chaque étape (outils, quantités, succès du minijeu) est revalidée ici, jamais prise au mot du client.

local rateLimits = {
    ['farm:animalSpawned'] = 20, ['farm:requestGather'] = 20, ['farm:completeGather'] = 20,
    ['farm:requestPoach'] = 20, ['farm:requestProcess'] = 20, ['farm:completeProcess'] = 20,
    ['farm:sellProcessed'] = 15, ['farm:sellPoaching'] = 15, ['farm:compactStones'] = 15,
    ['farm:requestShopStock'] = 20, ['farm:buyShopItem'] = 15,
    ['farm:gunLoan:requestState'] = 20, ['farm:gunLoan:borrow'] = 10,
    ['farm:gunLoan:buyAmmo'] = 10, ['farm:gunLoan:return'] = 10,
    ['farm:tool:request'] = 10, ['farm:tool:return'] = 10,
    ['farm:metier:select'] = 10, ['farm:metier:requestState'] = 20, ['farm:metier:endService'] = 10, ['farm:metier:startService'] = 10,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local NodeCooldowns  = {} -- ['activityKey_nodeIndex'] = os.time() de la dernière récolte
local PendingGather   = {} -- [source] = { activity = activityKey, species = speciesTable|nil } — une autorisation en attente, consommée une seule fois
local LootedCorpses   = {} -- [netId] = true — cadavre de gibier déjà dépecé (chasseur)
local PoachedCorpses  = {} -- [netId] = true — peau déjà prélevée sur ce cadavre (indépendant du dépeçage, un cadavre peut être dépecé ET dépouillé)
local LastMinedNode   = {} -- ['identifier_activity'] = nodeIndex du dernier nœud miné (règle noRepeatNode, par joueur)

-- Outils délivrés par un PNJ (pioche, hache) : ['identifier|item'] = { freeRight = bool, uid = string|nil }
local ToolLoans = {}
local PendingTool = {}
local ToolCfg = { pioche = Config.Farm.Pickaxe, weapon_hatchet = Config.Farm.Hatchet }
local ToolMetier = { pioche = 'mineur', weapon_hatchet = 'bucheron' }

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS farm_pickaxe (
        identifier  VARCHAR(60) NOT NULL PRIMARY KEY,
        free_right  INT NOT NULL DEFAULT 1,
        pickaxe_uid VARCHAR(40) NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {}, function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS farm_tool_loans (
            identifier VARCHAR(60) NOT NULL,
            item       VARCHAR(40) NOT NULL,
            free_right INT NOT NULL DEFAULT 1,
            uid        VARCHAR(40) NULL,
            PRIMARY KEY (identifier, item)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], {}, function()
        MySQL.Async.execute([[
            INSERT IGNORE INTO farm_tool_loans (identifier, item, free_right, uid)
            SELECT identifier, 'pioche', free_right, pickaxe_uid FROM farm_pickaxe
        ]], {}, function()
            MySQL.Async.fetchAll('SELECT identifier, item, free_right, uid FROM farm_tool_loans', {}, function(rows)
                for _, row in ipairs(rows or {}) do
                    ToolLoans[row.identifier .. '|' .. row.item] = {
                        freeRight = tonumber(row.free_right) == 1,
                        uid       = row.uid,
                    }
                end
            end)
        end)
    end)
end)

local function GetToolRec(identifier, item)
    local key = identifier .. '|' .. item
    local rec = ToolLoans[key]
    if not rec then
        rec = { freeRight = true, uid = nil }
        ToolLoans[key] = rec
    end
    return rec
end

local function SaveToolRec(identifier, item)
    local rec = ToolLoans[identifier .. '|' .. item]
    MySQL.Async.execute(
        'INSERT INTO farm_tool_loans (identifier, item, free_right, uid) VALUES (@i, @t, @f, @u) ON DUPLICATE KEY UPDATE free_right=@f, uid=@u',
        { ['@i'] = identifier, ['@t'] = item, ['@f'] = rec.freeRight and 1 or 0, ['@u'] = rec.uid }
    )
end

local function FindIssuedTool(player, item)
    local rec = ToolLoans[player.identifier .. '|' .. item]
    if not rec or not rec.uid then return nil end
    for _, v in pairs(player.inventory or {}) do
        if v.name == item and v.uniqueId == rec.uid then return rec.uid end
    end
    return nil
end

local function HasIssuedTool(player, item)
    return FindIssuedTool(player, item) ~= nil
end

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

-- [item produit] = recette, construit une fois depuis toutes les activités. Ces items sont achetables sans avoir jamais eu de stock propre : `farm:buyShopItem` consomme leurs `inputs` (déjà en ShopStock via `multiSellItems`) à l'achat, au lieu de décrémenter un stock qui leur serait dédié.
local CraftRecipesByOutput = {}
for _, activity in pairs(Config.Farm.Activities) do
    for _, recipe in ipairs(activity.craftRecipes or {}) do
        CraftRecipesByOutput[recipe.output.item] = recipe
    end
end

-- Peuplement de la faune arbitré par le serveur : le client ne décide jamais seul du spawn (risque de double spawn si deux chasseurs se croisent), le serveur reste l'unique compteur et délègue juste la création au client le mieux placé.

local HuntZones         = {} -- [zoneTable de la config] = { model, coords, radius, count, netIds = {}, pending = 0 }
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
    end
end)

local function GetPlayer(src)
    return LSLegacy.Players.Get(src)
end

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Farm', msg, t or 'info', 5000)
end

local function GetItemCount(player, item)
    local entry = LSLegacy.Inventory.GetInventoryItem(player, item)
    return entry and entry.count or 0
end

-- ── Agence d'intérim : métier choisi et prise de service ─────────────
local MetierByIdentifier = {} -- [identifier] = { metier = key, inService = bool }

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS farm_metier (
        identifier VARCHAR(60) NOT NULL PRIMARY KEY,
        metier     VARCHAR(20) NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {}, function()
    MySQL.Async.execute('ALTER TABLE farm_metier ADD COLUMN IF NOT EXISTS in_service INT NOT NULL DEFAULT 0', {}, function()
        MySQL.Async.fetchAll('SELECT identifier, metier, in_service FROM farm_metier', {}, function(rows)
            for _, row in ipairs(rows or {}) do
                MetierByIdentifier[row.identifier] = { metier = row.metier, inService = tonumber(row.in_service) == 1 }
            end
        end)
    end)
end)

local function SaveMetier(identifier)
    local rec = MetierByIdentifier[identifier]
    if not rec then
        MySQL.Async.execute('DELETE FROM farm_metier WHERE identifier = @i', { ['@i'] = identifier })
        return
    end
    MySQL.Async.execute(
        'INSERT INTO farm_metier (identifier, metier, in_service) VALUES (@i, @m, @s) ON DUPLICATE KEY UPDATE metier=@m, in_service=@s',
        { ['@i'] = identifier, ['@m'] = rec.metier, ['@s'] = rec.inService and 1 or 0 }
    )
end

local function SetMetierState(src, identifier)
    local rec = MetierByIdentifier[identifier]
    TriggerClientEvent('farm:metier:state', src, {
        metier    = rec and rec.metier or nil,
        inService = rec and rec.inService or false,
    })
end

-- Renvoie le message de refus si le joueur ne peut pas agir pour ce métier, nil sinon.
local function MetierRefusal(player, metier)
    local rec = MetierByIdentifier[player.identifier]
    if rec and rec.metier == metier and rec.inService then return nil end
    if rec and rec.metier == metier then
        return ('Prenez votre service auprès de %s avant de travailler.'):format(Config.Farm.Metiers[metier].endPnj)
    end
    return 'Pour faire ce métier, inscrivez-vous à l\'agence d\'intérim (Kelly Chambers).'
end

local function CanStartService(player, metier)
    local rec = MetierByIdentifier[player.identifier]
    return rec ~= nil and rec.metier == metier and not rec.inService
end

FarmMetier = { Refusal = MetierRefusal, CanStart = CanStartService }

local function StartServiceNow(src, player)
    local rec = MetierByIdentifier[player.identifier]
    rec.inService = true
    SaveMetier(player.identifier)
    SetMetierState(src, player.identifier)
    Notify(src, 'Vous avez pris votre service.', 'success')
end

function FarmMetier.StartService(src)
    local player = GetPlayer(src)
    if player and MetierByIdentifier[player.identifier] then
        StartServiceNow(src, player)
    end
end

LSLegacy.Events.Register('farm:metier:requestState', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    SetMetierState(src, player.identifier)
end)

LSLegacy.Events.Register('farm:metier:select', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player or not data or not Config.Farm.Metiers[data.metier] then return end
    local rec = MetierByIdentifier[player.identifier]
    if rec and rec.inService then
        return Notify(src, ('Vous êtes en service comme %s : allez voir %s pour y mettre fin.'):format(Config.Farm.Metiers[rec.metier].label, Config.Farm.Metiers[rec.metier].endPnj), 'error')
    end
    MetierByIdentifier[player.identifier] = { metier = data.metier, inService = false }
    SaveMetier(player.identifier)
    SetMetierState(src, player.identifier)
    Notify(src, ('Rendez-vous auprès de %s pour prendre votre service.'):format(Config.Farm.Metiers[data.metier].endPnj), 'info')
end)


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
            table.insert(list, { item = entry.item, price = entry.price, lotSize = entry.lotSize, lotPrice = entry.lotPrice, shopItem = entry.shopItem })
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
    local refusal = activity and MetierRefusal(player, activity.metier)
    if refusal then TriggerClientEvent('farm:gatherDenied', src, refusal) return end
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
        if not LSLegacy.Validate.Distance(entCoords, playerCoords, Config.Farm.ZoneDistance + 3.0) then
            TriggerClientEvent('farm:gatherDenied', src, 'Trop loin du cadavre.')
            return
        end

        nodeKey = 'corpse_' .. data.netId
    end

    if ToolCfg[activity.tool] then
        if GetItemCount(player, activity.tool) <= 0 then
            TriggerClientEvent('farm:gatherDenied', src, 'Vous n\'avez pas d\'outil valide : allez voir le PNJ.')
            return
        end
    elseif activity.tool then
        if GetItemCount(player, activity.tool) <= 0 then
            local toolLabel = Config.Items[activity.tool] and Config.Items[activity.tool].label or activity.tool
            TriggerClientEvent('farm:gatherDenied', src, string.format(Lang.Farm.missing_tool, toolLabel))
            return
        end
    end

    if data.nodeIndex then
        if activity.noRepeatNode then
            local memKey = player.identifier .. '_' .. data.activity
            if LastMinedNode[memKey] == data.nodeIndex then
                TriggerClientEvent('farm:gatherDenied', src, 'Vous venez de miner ce nœud : changez de nœud.')
                return
            end
            LastMinedNode[memKey] = data.nodeIndex
        elseif activity.nodeCooldown then
            local now      = os.time()
            local lastTime = NodeCooldowns[nodeKey] or 0
            if (now - lastTime) < (activity.nodeCooldown / 1000) then
                TriggerClientEvent('farm:gatherDenied', src, Lang.Farm.node_cooldown)
                return
            end
            NodeCooldowns[nodeKey] = now
        end
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
    local refusal = MetierRefusal(player, activity.metier)
    if refusal then TriggerClientEvent('farm:poachResult', src, { success = false, reason = refusal }) return end

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
    local refusal = MetierRefusal(player, activity.metier)
    if refusal then TriggerClientEvent('farm:processDenied', src, refusal) return end

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
    local refusal = MetierRefusal(player, activity.metier)
    if refusal then Notify(src, refusal, 'error') return end

    local total = 0
    local sold  = {}

    for _, sellable in ipairs(GetSellableItems(activity)) do
        local have = GetItemCount(player, sellable.item)

        -- Vente par lot fixe (ex: planche vendue par 2) : seuls les lots complets partent, le reste reste en inventaire.
        if sellable.lotSize then
            local lots = math.floor(have / sellable.lotSize)
            if lots > 0 then
                local amount = lots * sellable.lotSize
                LSLegacy.Inventory.RemoveItemInInventory(player, sellable.item, amount)
                total = total + lots * sellable.lotPrice
                table.insert(sold, { item = sellable.item, amount = amount })

                if sellable.shopItem then
                    ShopStock[sellable.shopItem] = (ShopStock[sellable.shopItem] or 0) + amount
                    SaveShopStock(sellable.shopItem)
                end
            end
        elseif have > 0 then
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
    local refusal = MetierRefusal(player, activity.metier)
    if refusal then Notify(src, refusal, 'error') return end

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

    local amount = math.floor(tonumber(data.amount) or 0)
    if amount <= 0 then return end

    -- Ingrédients resto (steak haché, guanciale, jambon, ...) : pas de stock propre, l'achat consomme directement les intrants (viande/graisse_animale/abats) en ShopStock, au prorata du nombre de lots.
    local recipe = CraftRecipesByOutput[data.item]
    if recipe then
        local batches      = math.ceil(amount / recipe.output.amount)
        local totalAmount  = batches * recipe.output.amount
        local cost         = totalAmount * recipe.output.buyPrice

        for _, input in ipairs(recipe.inputs) do
            if (ShopStock[input.item] or 0) < input.amount * batches then
                TriggerClientEvent('farm:buyResult', src, { success = false, reason = 'no_stock' })
                return
            end
        end

        if (player.cash or 0) < cost then
            TriggerClientEvent('farm:buyResult', src, { success = false, reason = 'no_money' })
            return
        end

        if not LSLegacy.Inventory.CanCarryItem(player, data.item, totalAmount) then
            TriggerClientEvent('farm:buyResult', src, { success = false, reason = 'too_heavy' })
            return
        end

        for _, input in ipairs(recipe.inputs) do
            ShopStock[input.item] = (ShopStock[input.item] or 0) - input.amount * batches
            SaveShopStock(input.item)
        end

        LSLegacy.Money.RemovePlayerMoney(player, cost)
        LSLegacy.Inventory.AddItemInInventory(player, data.item, totalAmount)

        TriggerClientEvent('farm:buyResult', src, { success = true, item = data.item, amount = totalAmount, cost = cost })
        return
    end

    local buyPrice = ShopBuyPrices[data.item]
    if not buyPrice then return end

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
    for reqId, req in pairs(PendingHuntSpawns) do
        if req.src == source then
            req.target.pending = math.max(0, req.target.pending - 1)
            PendingHuntSpawns[reqId] = nil
        end
    end
end)

-- ── Garde-chasse : fusil, caution, cartouches ───────────────────────
local GL = Config.Farm.GunLoan
local GunLoansByIdentifier = {} -- [identifier] = { weaponUid, deposit, payType, src, inZone, outSince, lastReminder, lastCoords, forfeit }
local GunAmmo = {}              -- [identifier] = cartouches rendues au garde, restituées à la prochaine prise de service
local PendingGunLoans = {}      -- [token] = { kind, src, identifier, onDone }

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS farm_gun_loans (
        identifier VARCHAR(60) NOT NULL PRIMARY KEY,
        weapon_uid VARCHAR(40) NOT NULL,
        deposit    INT NOT NULL,
        pay_type   VARCHAR(10) NOT NULL,
        forfeit    INT NOT NULL DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {}, function()
    MySQL.Async.fetchAll('SELECT identifier, weapon_uid, deposit, pay_type, forfeit FROM farm_gun_loans', {}, function(rows)
        for _, row in ipairs(rows or {}) do
            GunLoansByIdentifier[row.identifier] = {
                weaponUid = row.weapon_uid,
                deposit   = tonumber(row.deposit),
                payType   = row.pay_type,
                forfeit   = tonumber(row.forfeit) == 1,
                inZone    = true,
            }
        end
    end)
end)

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS farm_gun_ammo (
        identifier VARCHAR(60) NOT NULL PRIMARY KEY,
        count      INT NOT NULL DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {}, function()
    MySQL.Async.fetchAll('SELECT identifier, count FROM farm_gun_ammo', {}, function(rows)
        for _, row in ipairs(rows or {}) do
            GunAmmo[row.identifier] = tonumber(row.count) or 0
        end
    end)
end)

local function SaveGunAmmo(identifier)
    MySQL.Async.execute(
        'INSERT INTO farm_gun_ammo (identifier, count) VALUES (@i, @c) ON DUPLICATE KEY UPDATE count=@c',
        { ['@i'] = identifier, ['@c'] = GunAmmo[identifier] or 0 }
    )
end

local function SaveGunLoan(identifier, loan)
    if not loan then
        MySQL.Async.execute('DELETE FROM farm_gun_loans WHERE identifier = @i', { ['@i'] = identifier })
        return
    end
    MySQL.Async.execute(
        'INSERT INTO farm_gun_loans (identifier, weapon_uid, deposit, pay_type, forfeit) VALUES (@i, @w, @d, @p, @f) ON DUPLICATE KEY UPDATE weapon_uid=@w, deposit=@d, pay_type=@p, forfeit=@f',
        { ['@i'] = identifier, ['@w'] = loan.weaponUid, ['@d'] = loan.deposit, ['@p'] = loan.payType, ['@f'] = loan.forfeit and 1 or 0 }
    )
end

local function CurrentRanger()
    local hour = LSLegacy.Weather.GetTime() or 12
    if hour >= GL.dayStart and hour < GL.dayEnd then return GL.rangers[1] end
    return GL.rangers[2]
end

local function IsInHuntZone(coords)
    for _, s in ipairs(Config.Farm.Activities.chasseur.species) do
        if s.rawItem and s.spawnZones then
            for _, z in ipairs(s.spawnZones) do
                local dx, dy = coords.x - z.coords.x, coords.y - z.coords.y
                if math.sqrt(dx * dx + dy * dy) <= z.radius then return true end
            end
        end
    end
    return false
end

local function SendGunState(src, identifier)
    local ranger = CurrentRanger()
    TriggerClientEvent('farm:gunLoan:state', src, {
        model  = ranger.model,
        name   = ranger.name,
        active = GunLoansByIdentifier[identifier] ~= nil,
    })
end

local function RemoveLoanedWeapon(player, loan)
    LSLegacy.Inventory.RemoveItemInInventory(player, GL.weapon, 1, nil, loan.weaponUid)
    TriggerClientEvent('farm:gunLoan:forceRemoveWeapon', player.source, GL.weapon)
end

local function RemoveAllAmmo(player)
    local n = GetItemCount(player, GL.ammoItem)
    if n > 0 then LSLegacy.Inventory.RemoveItemInInventory(player, GL.ammoItem, n) end
    GunAmmo[player.identifier] = 0
    SaveGunAmmo(player.identifier)
end

local function RefundDeposit(player, loan)
    if loan.payType == 'money' then
        LSLegacy.Money.AddPlayerMoney(player, loan.deposit)
    else
        exports.lslegacy:addBankMoneyByIdentifier(player.identifier, loan.deposit)
    end
end

local function EndGunLoan(identifier)
    GunLoansByIdentifier[identifier] = nil
    SaveGunLoan(identifier, nil)
end

CreateThread(function()
    while true do
        Wait(10000)
        local now = os.time()
        for identifier, loan in pairs(GunLoansByIdentifier) do
            local ped = loan.src and GetPlayerPed(loan.src) or 0
            if ped ~= 0 and not loan.forfeit then
                local coords = GetEntityCoords(ped)
                loan.lastCoords = coords
                loan.inZone = IsInHuntZone(coords)
                if loan.inZone then
                    loan.outSince = nil
                else
                    loan.outSince = loan.outSince or now
                    if now - loan.outSince >= GL.graceSec then
                        local player = GetPlayer(loan.src)
                        if player then
                            RemoveLoanedWeapon(player, loan)
                            RemoveAllAmmo(player)
                            Notify(loan.src, 'Fusil confisqué : vous êtes resté hors zone. Caution et cartouches perdues.', 'error')
                        end
                        EndGunLoan(identifier)
                    elseif now - (loan.lastReminder or 0) >= GL.reminderSec then
                        loan.lastReminder = now
                        Notify(loan.src, 'Vous êtes hors zone de chasse : rendez le fusil au garde-chasse.', 'error')
                    end
                end
            end
        end
    end
end)

LSLegacy.Events.Register('farm:gunLoan:requestState', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    local loan = GunLoansByIdentifier[player.identifier]
    if loan then
        loan.src = src
        if loan.forfeit then
            RemoveLoanedWeapon(player, loan)
            RemoveAllAmmo(player)
            EndGunLoan(player.identifier)
            Notify(src, 'Vous avez quitté la zone avec le fusil : caution et cartouches perdues.', 'error')
        end
    end
    SendGunState(src, player.identifier)
end)

local function OpenGunLoanPayment(src, identifier, kind, title, price, onDone)
    local token = ('gunloan_%s_%d'):format(kind, math.random(100000, 999999))
    PendingGunLoans[token] = { kind = kind, src = src, identifier = identifier, onDone = onDone }
    Citizen.SetTimeout(120000, function() PendingGunLoans[token] = nil end)
    LSLegacy.Bank.OpenPaymentMenu(src, title, price, {
        meta = { type = 'farm_gunloan', refId = token },
    })
end

-- Prise de service chasseur : caution (si pas déjà de fusil) puis remise du fusil.
local function StartGunService(src, player, onDone)
    if GunLoansByIdentifier[player.identifier] then return onDone() end
    if not LSLegacy.Inventory.CanCarryItem(player, GL.weapon, 1) then
        return Notify(src, 'Inventaire trop chargé pour ce fusil.', 'error')
    end
    OpenGunLoanPayment(src, player.identifier, 'borrow', 'Caution - Fusil de précision', GL.deposit, onDone)
end

LSLegacy.Events.Register('farm:gunLoan:buyAmmo', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    local refusal = MetierRefusal(player, 'chasseur')
    if refusal then return Notify(src, refusal, 'error') end
    if not GunLoansByIdentifier[player.identifier] then
        return Notify(src, 'Vous devez d\'abord emprunter un fusil.', 'error')
    end
    if not LSLegacy.Inventory.CanCarryItem(player, GL.ammoItem, GL.ammoBoxCount) then
        return Notify(src, 'Inventaire trop chargé pour ces munitions.', 'error')
    end
    OpenGunLoanPayment(src, player.identifier, 'ammo', 'Boîte de munitions .338 Lapua', GL.ammoBoxPrice)
end)

LSLegacy.Bank.RegisterPaymentResultHandler('farm_gunloan', function(token, success, payType)
    local pending = PendingGunLoans[token]
    if not pending then return end
    PendingGunLoans[token] = nil
    if not success then return end
    local player = GetPlayer(pending.src)
    if not player then return end

    if pending.kind == 'ammo' then
        LSLegacy.Inventory.AddItemInInventory(player, GL.ammoItem, GL.ammoBoxCount)
        Notify(pending.src, ('%d cartouches ajoutées à votre inventaire.'):format(GL.ammoBoxCount), 'success')
        return
    end

    if GunLoansByIdentifier[pending.identifier] then
        RefundDeposit(player, { payType = payType, deposit = GL.deposit })
        return Notify(pending.src, 'Vous avez déjà un fusil emprunté.', 'error')
    end
    local uid = LSLegacy.Inventory.GiveUniqueId()
    LSLegacy.Inventory.AddItemInInventory(player, GL.weapon, 1, nil, uid)
    local stored = GunAmmo[pending.identifier] or 0
    if stored > 0 then
        LSLegacy.Inventory.AddItemInInventory(player, GL.ammoItem, stored)
        GunAmmo[pending.identifier] = 0
        SaveGunAmmo(pending.identifier)
    end
    local loan = { weaponUid = uid, deposit = GL.deposit, payType = payType, src = pending.src, inZone = true, lastReminder = 0, forfeit = false }
    GunLoansByIdentifier[pending.identifier] = loan
    SaveGunLoan(pending.identifier, loan)
    Notify(pending.src, ('Fusil remis. %d cartouches restituées. Restez dans la zone de chasse.'):format(stored), 'success')
    SendGunState(pending.src, pending.identifier)
    if pending.onDone then pending.onDone() end
end)

AddEventHandler('playerDropped', function()
    local player = GetPlayer(source)
    if not player then return end
    local loan = GunLoansByIdentifier[player.identifier]
    if not loan or loan.src ~= source then return end
    loan.src = nil
    if loan.inZone == false then
        loan.forfeit = true
        SaveGunLoan(player.identifier, loan)
        if type(GetPoliceOfficers) == 'function' and loan.lastCoords then
            for officerSrc in pairs(GetPoliceOfficers()) do
                TriggerClientEvent('farm:gunLoan:alert', officerSrc, { coords = loan.lastCoords })
            end
        end
    end
end)

-- ── Outils (pioche, hache) : délivrés à la prise de service, repris à la fin ─────────
local function GiveTool(player, item, rec)
    local uid = LSLegacy.Inventory.GiveUniqueId()
    LSLegacy.Inventory.AddItemInInventory(player, item, 1, nil, uid)
    rec.uid = uid
    SaveToolRec(player.identifier, item)
end

local function ReturnTool(src, player, item)
    local uid = FindIssuedTool(player, item)
    if uid then LSLegacy.Inventory.RemoveItemInInventory(player, item, 1, nil, uid) end
    if GetItemCount(player, item) > 0 then LSLegacy.Inventory.RemoveItemInInventory(player, item, 1) end
    local rec = GetToolRec(player.identifier, item)
    rec.uid = nil
    rec.freeRight = true
    SaveToolRec(player.identifier, item)
    TriggerClientEvent('farm:tool:forceRemove', src, item)
end

-- Outil requis pour une prise de service : gratuit si le droit est disponible, sinon paiement (onDone après).
local function TryToolForService(src, player, item, onDone)
    if GetItemCount(player, item) > 0 then return onDone() end
    local rec = GetToolRec(player.identifier, item)
    if rec.freeRight then
        rec.freeRight = false
        GiveTool(player, item, rec)
        return onDone()
    end
    local token = ('tool_%d_%d'):format(src, math.random(100000, 999999))
    PendingTool[token] = { src = src, identifier = player.identifier, item = item, onDone = onDone }
    Citizen.SetTimeout(120000, function() PendingTool[token] = nil end)
    LSLegacy.Bank.OpenPaymentMenu(src, 'Nouvel outil - ' .. ToolCfg[item].name, ToolCfg[item].price, {
        meta = { type = 'farm_tool', refId = token },
    })
end

LSLegacy.Events.Register('farm:tool:request', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player or not data or not ToolCfg[data.item] then return end
    local item = data.item
    local refusal = MetierRefusal(player, ToolMetier[item])
    if refusal then return Notify(src, refusal, 'error') end
    if GetItemCount(player, item) > 0 then
        return Notify(src, 'Vous avez déjà cet outil.', 'error')
    end
    if not LSLegacy.Inventory.CanCarryItem(player, item, 1) then
        return Notify(src, 'Inventaire trop chargé pour cet outil.', 'error')
    end
    TryToolForService(src, player, item, function()
        Notify(src, 'Outil délivré.', 'success')
    end)
end)

LSLegacy.Events.Register('farm:tool:return', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player or not data or not ToolCfg[data.item] then return end
    if GetItemCount(player, data.item) <= 0 then
        return Notify(src, 'Vous n\'avez pas cet outil.', 'error')
    end
    ReturnTool(src, player, data.item)
    Notify(src, 'Outil rendu. Vous pouvez en obtenir un gratuit.', 'success')
end)

LSLegacy.Bank.RegisterPaymentResultHandler('farm_tool', function(token, success)
    local pending = PendingTool[token]
    if not pending then return end
    PendingTool[token] = nil
    if not success then return end
    local player = GetPlayer(pending.src)
    if not player then return end
    GiveTool(player, pending.item, GetToolRec(player.identifier, pending.item))
    if pending.onDone then pending.onDone() else Notify(pending.src, 'Nouvel outil acheté.', 'success') end
end)

-- ── Prise et fin de service ─────────────────────────────────────────────
local function EndServiceNow(src, player)
    local rec = MetierByIdentifier[player.identifier]
    if rec.metier == 'mineur' then
        ReturnTool(src, player, Config.Farm.Pickaxe.item)
    elseif rec.metier == 'bucheron' then
        ReturnTool(src, player, Config.Farm.Hatchet.item)
    elseif rec.metier == 'chasseur' then
        local loan = GunLoansByIdentifier[player.identifier]
        if loan then
            RemoveLoanedWeapon(player, loan)
            local n = GetItemCount(player, GL.ammoItem)
            if n > 0 then LSLegacy.Inventory.RemoveItemInInventory(player, GL.ammoItem, n) end
            GunAmmo[player.identifier] = n
            SaveGunAmmo(player.identifier)
            RefundDeposit(player, loan)
            EndGunLoan(player.identifier)
            Notify(src, ('Fusil rendu, caution remboursée. %d cartouches conservées pour votre prochain service.'):format(n), 'success')
        end
    end
    MetierByIdentifier[player.identifier] = nil
    SaveMetier(player.identifier)
    SetMetierState(src, player.identifier)
end

function FarmMetier.OnDeath(src)
    local player = GetPlayer(src)
    local rec = player and MetierByIdentifier[player.identifier]
    if rec and rec.inService then EndServiceNow(src, player) end
end

LSLegacy.Events.Register('farm:metier:startService', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player or not data then return end
    local rec = MetierByIdentifier[player.identifier]
    if not rec or rec.metier ~= data.metier or rec.inService then
        return Notify(src, 'Allez d\'abord choisir ce métier auprès de l\'agence d\'intérim.', 'error')
    end
    if data.metier == 'chauffeur_citerne' then
        return Notify(src, 'Prenez votre service auprès de Frank Martin.', 'error')
    end
    local pos = Config.Farm.Metiers[data.metier].blipCoords[1]
    if not LSLegacy.Validate.Distance(GetEntityCoords(GetPlayerPed(src)), pos, Config.Farm.ZoneDistance + 5.0) then
        return Notify(src, ('Rendez-vous auprès de %s.'):format(Config.Farm.Metiers[data.metier].endPnj), 'error')
    end
    local function Start() StartServiceNow(src, player) end
    if data.metier == 'mineur' then
        TryToolForService(src, player, Config.Farm.Pickaxe.item, Start)
    elseif data.metier == 'bucheron' then
        TryToolForService(src, player, Config.Farm.Hatchet.item, Start)
    elseif data.metier == 'chasseur' then
        StartGunService(src, player, Start)
    else
        Start()
    end
end)

LSLegacy.Events.Register('farm:metier:endService', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player or not data or not data.metier then return end
    local rec = MetierByIdentifier[player.identifier]
    if not rec or rec.metier ~= data.metier or not rec.inService then
        return Notify(src, 'Vous n\'êtes pas en service comme ça.', 'error')
    end
    if rec.metier == 'chauffeur_citerne' and Interim and Interim.Sessions and Interim.Sessions[src] then
        return Notify(src, 'Terminez d\'abord votre service auprès de Frank Martin.', 'error')
    end
    EndServiceNow(src, player)
    Notify(src, 'Service terminé.', 'success')
end)
