---@class MadeInFrance.Inventory
MadeInFrance.Inventory = {}
MadeInFrance.Inventory.ActionItems = {}
MadeInFrance.ItemsId = {}

MySQL.ready(function()
    MySQL.Async.fetchAll('SELECT inventory FROM players', {}, function(result)
        for k, v in pairs(result) do
            local inventory = json.decode(v.inventory)
            for key, value in pairs(inventory) do
                if value.uniqueId then
                    MadeInFrance.ItemsId[value.uniqueId] = value.uniqueId
                end
            end
        end
    end)
end)

---GiveUniqueId
---@type function
---@return number
---@public
MadeInFrance.Inventory.GiveUniqueId = function()
    local uniqueId = math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)

    if not MadeInFrance.ItemsId[uniqueId] then
        MadeInFrance.ItemsId[uniqueId] = uniqueId
        return uniqueId
    else
        MadeInFrance.Inventory.GiveUniqueId()
    end
end

---GetAllItems
---@type function
---@return table
---@public
MadeInFrance.Inventory.GetAllItems = function()
    local items = {}
    for key, value in pairs(Config.Items) do
        items[key] = value
    end
    return items
end

---DoesItemExists
---@type function
---@param item string
---@return boolean
---@public
MadeInFrance.Inventory.DoesItemExists = function(item)
    if not item then return false end
    if Config.Items[item] then
        return true
    else
        return false
    end
end

---GetInfosItem
---@type function
---@param item string
---@return table
---@public
MadeInFrance.Inventory.GetInfosItem = function(item)
    if not item then return end
    if Config.Items[item] and MadeInFrance.Inventory.DoesItemExists(item) then
        return Config.Items[item]
    else
        return nil
    end
end

---GetInventoryWeight
---@type function
---@param inventory table
---@return number
---@public
MadeInFrance.Inventory.GetInventoryWeight = function(inventory)
    if not inventory then return end
    local weight = 0

    for key, value in pairs(inventory) do
        weight = weight + Config.Items[value.name].weight * value.count
    end
    return weight
end

---GetInventoryItem
---@type function
---@param player table
---@param item string
---@return table
---@public
MadeInFrance.Inventory.GetInventoryItem = function(player, item)
    if not item then return end
    local count = 0
    local data = nil

    local inventory = player.inventory

    for key, value in pairs(inventory) do
        if value.name == item then
            count = count + value.count
            data = value
        end
    end
    if count ~= 0 then
        return {count = count, label = Config.Items[item].label, uniqueId = data.uniqueId, data = data.data}
    else
        return nil
    end
end

---CanCarryItem
---@type function
---@param player table
---@param item string
---@param quantity number
---@return boolean
---@public
MadeInFrance.Inventory.CanCarryItem = function(player, item, quantity)
    if not player then return end
    if not item then return end
    if not quantity then quantity = 1 end
    if not MadeInFrance.Inventory.DoesItemExists(item) then return end
    local weight = MadeInFrance.Inventory.GetInventoryWeight(player.inventory)
    local itemWeight = Config.Items[item].weight * quantity
    if math.floor(weight + itemWeight) <= Config.Informations["MaxWeight"] then
        return true
    else
        return false
    end
end

---AddItemInInventory
---@type function
---@param player table
---@param item string
---@param quantity number
---@param newLabel string
---@param uniqueId number
---@param data table
---@return any
MadeInFrance.Inventory.AddItemInInventory = function(player, item, quantity, newlabel, uniqueId, data)
    if not player then return end
    if not item then return end
    if not quantity then return end
    local exist = false

    if MadeInFrance.Inventory.DoesItemExists(item) then
        if MadeInFrance.Inventory.CanCarryItem(player, item, quantity) then
            local inventory = player.inventory
            local Itemlabel = newlabel or Config.Items[item].label

            for k, v in pairs(inventory) do
                if not Config.InsertItems[v.name] then
                    if v.name == item and v.label == Itemlabel then
                        v.count = v.count + quantity
                        exist = true
                        break
                    end
                end
            end

            if not exist then
                if Config.InsertItems[item] then
                    if uniqueId == nil then
                        uniqueId = MadeInFrance.Inventory.GiveUniqueId()
                    end 
                    if data ~= nil then
                        table.insert(inventory, {data = data, uniqueId = uniqueId, name = item, label = Itemlabel, count = quantity})
                    else
                        table.insert(inventory, {uniqueId = uniqueId, name = item, label = Itemlabel, count = quantity})
                    end
                else
                    table.insert(inventory, {name = item, label = Itemlabel, count = quantity})
                end
            end

            player.inventory = inventory
            local weight = MadeInFrance.Inventory.GetInventoryWeight(player.inventory)
            player.weight = weight
            MadeInFrance.SendEventToClient('UpdatePlayer', player.source, player)
        end
    end
end

---RemoveItemInInventory
---@type function
---@param player table
---@param item string
---@param quantity number
---@param itemLabel string
---@return any
---@public
MadeInFrance.Inventory.RemoveItemInInventory = function(player, item, quantity, itemLabel)
    if not player then return end
    if not item then return end
    if not quantity then return end
    local inventory = player.inventory
    local label = itemLabel or Config.Items[item].label
    local removed = false

    for k, v in pairs(inventory) do
        if v.name == item and v.label == label then
            if tonumber(v.count) >= tonumber(quantity) then
                v.count = v.count - quantity
                if v.count <= 0 then
                    table.remove(inventory, k)
                end
                removed = true
                break
            else
                break
            end
        end
    end

    if not removed then
        for k, v in pairs(inventory) do
            if v.name == item then
                if tonumber(v.count) >= tonumber(quantity) then
                    v.count = v.count - quantity
                    if v.count <= 0 then
                        table.remove(inventory, k)
                    end
                    break
                else
                    break
                end
            end
        end
    end

    player.inventory = inventory
    local weight = MadeInFrance.Inventory.GetInventoryWeight(player.inventory)
    player.weight = weight
    MadeInFrance.SendEventToClient('UpdatePlayer', player.source, player)
end

---RenameItemLabel
---@type function
---@param player table
---@param name string
---@param lastLabel string
---@param newLabel string
---@param quantity number
---@param uniqueId number
---@return any
---@public
MadeInFrance.Inventory.RenameItemLabel = function(player, name, lastLabel, newLabel, quantity, uniqueId)
    if not player then return end
    if not name then return end
    if not lastLabel then return end
    if not newLabel then return end
    if not quantity then return end
    if lastLabel == newLabel then return end

    local inventory = player.inventory
    local exist = false
    local itemName = nil

    if Config.InsertItems[name] then
        for k, v in pairs(inventory) do
            if v.uniqueId == uniqueId then
                v.label = newLabel
                exist = true
                break
            end
        end
    else
        for k, v in pairs(inventory) do
            if v.name == name and v.label == lastLabel then
                if tonumber(v.count) >= tonumber(quantity) then
                    itemName = v.name
                    v.count = v.count - quantity
                    if v.count <= 0 then
                        table.remove(inventory, k)
                    end

                    for key, value in pairs(inventory) do
                        if value.name == itemName and value.label == newLabel then
                            value.count = value.count + quantity
                            exist = true
                            break
                        end
                    end
                else
                    break
                end
            end
        end
    end

    if not exist then
        table.insert(inventory, {name = itemName, label = newLabel, count = quantity})
    end
    MadeInFrance.SendEventToClient('madeinfrance:notify', player.source, "Vous avez changé le nom ~b~"..lastLabel.."~s~ en ~b~"..newLabel.."~s~.")
    player.inventory = inventory
    MadeInFrance.SendEventToClient('UpdatePlayer', player.source, player)
end

---RegisterUsableItem
---@type function
---@param item string
---@param callback function
---@return any
---@public
MadeInFrance.RegisterUsableItem = function(item, cb)
	MadeInFrance.Inventory.ActionItems[item] = cb
end

---UseItem
---@type function
---@param item string
---@param ... any
---@return any
---@public
MadeInFrance.UseItem = function(item, ...)
    if MadeInFrance.Inventory.ActionItems[item] then
	    MadeInFrance.Inventory.ActionItems[item](...)
    end
end

MadeInFrance.RegisterServerEvent('madeinfrance:renameItem', function(name, lastLabel, newLabel, quantity, uniqueId)
    local player = MadeInFrance.GetPlayerFromId(source)
    MadeInFrance.Inventory.RenameItemLabel(player, name, lastLabel, newLabel, quantity, uniqueId)
end)

MadeInFrance.RegisterServerEvent('madeinfrance:useItem', function(item, ...)
    local player = MadeInFrance.GetPlayerFromId(source)
    if MadeInFrance.Inventory.GetInventoryItem(player, item) ~= nil then
        if MadeInFrance.Inventory.GetInventoryItem(player, item).count > 0 then
            MadeInFrance.UseItem(item, ...)
        end
    end
end)

MadeInFrance.RegisterServerEvent('madeinfrance:transfer', function(table)
    local source = source
    local sourcePed = GetPlayerPed(source)
    local targetPed = GetPlayerPed(table.target)
    local player = MadeInFrance.GetPlayerFromId(source)
    local target = MadeInFrance.GetPlayerFromId(table.target)
    if #(GetEntityCoords(sourcePed)-GetEntityCoords(targetPed)) <= 7.0 then
        if MadeInFrance.Inventory.GetInventoryItem(player, table.name) ~= nil then
            if MadeInFrance.Inventory.GetInventoryItem(player, table.name).count >= table.count then
                if MadeInFrance.Inventory.CanCarryItem(target, table.name, table.count) then
                    MadeInFrance.Inventory.RemoveItemInInventory(player, table.name, table.count, table.label)
                    MadeInFrance.Inventory.AddItemInInventory(target, table.name, table.count, table.label, table.uniqueId, table.data)
                    MadeInFrance.SendEventToClient('madeinfrance:notify', table.target,  table.count..' '..table.label..' ont été ~g~ajouté(s)~s~ à votre inventaire.')
                    MadeInFrance.SendEventToClient('madeinfrance:notify', source, table.count..' '..table.label..' ont été ~r~retiré(s)~s~ à votre inventaire.')
                else
                    MadeInFrance.SendEventToClient('madeinfrance:notify', table.target, '~r~Vous ne pouvez pas transporter cet objet.')
                    MadeInFrance.SendEventToClient('madeinfrance:notify', source, '~r~La personne ne peut pas transporter cet objet.')
                end
            end
        end
    else
        MadeInFrance.SendEventToClient('madeinfrance:notify', source, '~r~Il n\'y a aucune personne aux alentours de vous.')
    end
end)