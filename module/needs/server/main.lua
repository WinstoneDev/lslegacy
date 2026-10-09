LSLegacy.Security.RegisterRateLimit('applyNeedEffect', 20)

for item, _ in pairs(Config.NeedsItems) do
    LSLegacy.RegisterUsableItem(item, function(data, uniqueId)
        LSLegacy.Events.SendToClient('useNeed', source, item, data, uniqueId)
    end)
end

function UpdateInventoryItem(player, name, uniqueId, durability)
    local inventory = player.inventory
    if not inventory then return end
    for i, item in pairs(inventory) do
        if item.name == name and item.uniqueId == uniqueId then
            item.data.durability = durability
            LSLegacy.Events.SendToClient("lslegacy:updatePlayer", player.source, LSLegacy.Players.Get(player.source))
            break
        end
    end
end

LSLegacy.Events.Register('applyNeedEffect', function(name, data, uniqueId)
    local src = source
    local xPlayer = LSLegacy.Players.Get(src)
    local itemCfg = Config.NeedsItems[name]
    if not (xPlayer and itemCfg) then return end

    -- Item empilable (sans data/uniqueId, ex. achat en magasin) : consommé en entier, pas de durabilité.
    local stackable = (data == nil)
    local durability = data and data.durability or 100
    local portion = itemCfg.portion or 25
    local itemWeightKg = itemCfg.weight or 0.1 
    local itemWeightGrams = itemWeightKg * 1000 

    local ratio = stackable and 1 or (portion / itemWeightGrams)

    if itemCfg.hunger and itemCfg.hunger > 0 then
        LSLegacy.Status.AddHunger(xPlayer, math.floor(itemCfg.hunger * ratio))
    end
    if itemCfg.thirst and itemCfg.thirst > 0 then
        LSLegacy.Status.AddThirst(xPlayer, math.floor(itemCfg.thirst * ratio))
    end
    if itemCfg.stamina and itemCfg.stamina > 0 then
        LSLegacy.Status.AddStamina(xPlayer, math.floor(itemCfg.stamina * ratio))
    end

    if stackable then
        LSLegacy.Inventory.RemoveItemInInventory(xPlayer, name, 1)
        return
    end

    local newDurability = durability - (ratio * 100)
    if newDurability > 0 then
        UpdateInventoryItem(xPlayer, name, uniqueId, newDurability)
        LSLegacy.Events.SendToClient("updateFoodDurability", src, uniqueId, newDurability)
    else
        LSLegacy.Inventory.RemoveItemInInventory(xPlayer, name, 1)
        LSLegacy.Events.SendToClient("updateFoodDurability", src, uniqueId, 0)
    end
end)
