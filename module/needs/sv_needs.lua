for item, _ in pairs(Config.NeedsItems) do
    MadeInFrance.RegisterUsableItem(item, function(data, uniqueId)
        MadeInFrance.SendEventToClient('useNeed', source, item, data, uniqueId)
    end)
end

function UpdateInventoryItem(player, name, uniqueId, durability)
    local inventory = player.inventory
    if not inventory then return end
    for i, item in pairs(inventory) do
        if item.name == name and item.uniqueId == uniqueId then
            item.data.durability = durability
            MadeInFrance.SendEventToClient("UpdatePlayer", player.source, MadeInFrance.ServerPlayers[player.source])
            break
        end
    end
end

MadeInFrance.RegisterServerEvent('applyNeedEffect', function(name, data, uniqueId)
    local src = source
    local xPlayer = MadeInFrance.GetPlayerFromId(src)
    local itemCfg = Config.NeedsItems[name]
    if not (xPlayer and itemCfg and data) then return end

    local durability = data.durability or 100
    local portion = itemCfg.portion or 25
    local itemWeightKg = itemCfg.weight or 0.1 
    local itemWeightGrams = itemWeightKg * 1000 

    local ratio = portion / itemWeightGrams

    if itemCfg.hunger and itemCfg.hunger > 0 then
        MadeInFrance.Status.AddHunger(xPlayer, math.floor(itemCfg.hunger * ratio))
    end
    if itemCfg.thirst and itemCfg.thirst > 0 then
        MadeInFrance.Status.AddThirst(xPlayer, math.floor(itemCfg.thirst * ratio))
    end
    if itemCfg.stamina and itemCfg.stamina > 0 then
        MadeInFrance.Status.AddStamina(xPlayer, math.floor(itemCfg.stamina * ratio))
    end

    local newDurability = durability - (ratio * 100)
    if newDurability > 0 then
        UpdateInventoryItem(xPlayer, name, uniqueId, newDurability)
        MadeInFrance.SendEventToClient("updateFoodDurability", src, uniqueId, newDurability)
    else
        MadeInFrance.Inventory.RemoveItemInInventory(xPlayer, name, 1)
        MadeInFrance.SendEventToClient("updateFoodDurability", src, uniqueId, 0)
    end
end)
