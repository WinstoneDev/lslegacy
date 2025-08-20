---@class LSLegacy.Inventory
LSLegacy.Inventory = {}
LSLegacy.Inventory.ActionItems = {}
LSLegacy.ItemsId = {}

MySQL.ready(function()
    MySQL.Async.fetchAll('SELECT inventory FROM players', {}, function(result)
        for k, v in pairs(result) do
            local inventory = json.decode(v.inventory)
            for key, value in pairs(inventory) do
                if value.uniqueId then
                    LSLegacy.ItemsId[value.uniqueId] = value.uniqueId
                end
            end
        end
    end)
end)

---GiveUniqueId
---@type function
---@return number
---@public
LSLegacy.Inventory.GiveUniqueId = function()
    local uniqueId = math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)..math.random(0, 9)

    if not LSLegacy.ItemsId[uniqueId] then
        LSLegacy.ItemsId[uniqueId] = uniqueId
        return uniqueId
    else
        LSLegacy.Inventory.GiveUniqueId()
    end
end

---GetAllItems
---@type function
---@return table
---@public
LSLegacy.Inventory.GetAllItems = function()
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
LSLegacy.Inventory.DoesItemExists = function(item)
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
LSLegacy.Inventory.GetInfosItem = function(item)
    if not item then return end
    if Config.Items[item] and LSLegacy.Inventory.DoesItemExists(item) then
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
LSLegacy.Inventory.GetInventoryWeight = function(inventory)
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
LSLegacy.Inventory.GetInventoryItem = function(player, item)
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
LSLegacy.Inventory.CanCarryItem = function(player, item, quantity)
    if not player then return end
    if not item then return end
    if not quantity then quantity = 1 end
    if not LSLegacy.Inventory.DoesItemExists(item) then return end
    local weight = LSLegacy.Inventory.GetInventoryWeight(player.inventory)
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
LSLegacy.Inventory.AddItemInInventory = function(player, item, quantity, newlabel, uniqueId, data)
    if not player then return end
    if not item then return end
    if not quantity then return end
    local exist = false

    if LSLegacy.Inventory.DoesItemExists(item) then
        if LSLegacy.Inventory.CanCarryItem(player, item, quantity) then
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
                        uniqueId = LSLegacy.Inventory.GiveUniqueId()
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
            local weight = LSLegacy.Inventory.GetInventoryWeight(player.inventory)
            player.weight = weight
            LSLegacy.SendEventToClient('UpdatePlayer', player.source, player)
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
LSLegacy.Inventory.RemoveItemInInventory = function(player, item, quantity, itemLabel)
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
    local weight = LSLegacy.Inventory.GetInventoryWeight(player.inventory)
    player.weight = weight
    LSLegacy.SendEventToClient('UpdatePlayer', player.source, player)
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
LSLegacy.Inventory.RenameItemLabel = function(player, name, lastLabel, newLabel, quantity, uniqueId)
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
    LSLegacy.SendEventToClient('notify', player.source, nil, "Vous avez changé le nom "..lastLabel.." en "..newLabel..".", 'success')
    player.inventory = inventory
    LSLegacy.SendEventToClient('UpdatePlayer', player.source, player)
end

---RegisterUsableItem
---@type function
---@param item string
---@param callback function
---@return any
---@public
LSLegacy.RegisterUsableItem = function(item, cb)
	LSLegacy.Inventory.ActionItems[item] = cb
end

---UseItem
---@type function
---@param item string
---@param ... any
---@return any
---@public
LSLegacy.UseItem = function(item, ...)
    if LSLegacy.Inventory.ActionItems[item] then
	    LSLegacy.Inventory.ActionItems[item](...)
    end
end

LSLegacy.RegisterServerEvent('renameItem', function(name, lastLabel, newLabel, quantity, uniqueId)
    local player = LSLegacy.GetPlayerFromId(source)
    LSLegacy.Inventory.RenameItemLabel(player, name, lastLabel, newLabel, quantity, uniqueId)
end)

LSLegacy.RegisterServerEvent('useItem', function(item, ...)
    local player = LSLegacy.GetPlayerFromId(source)
    if LSLegacy.Inventory.GetInventoryItem(player, item) ~= nil then
        if LSLegacy.Inventory.GetInventoryItem(player, item).count > 0 then
            LSLegacy.UseItem(item, ...)
        end
    end
end)

LSLegacy.RegisterServerEvent('transfer', function(table)
    local source = source
    local sourcePed = GetPlayerPed(source)
    local targetPed = GetPlayerPed(table.target)
    local player = LSLegacy.GetPlayerFromId(source)
    local target = LSLegacy.GetPlayerFromId(table.target)
    
    if #(GetEntityCoords(sourcePed)-GetEntityCoords(targetPed)) <= 7.0 then
        if table.type == 'item_standard' then
            if LSLegacy.Inventory.GetInventoryItem(player, table.name) ~= nil then
                if LSLegacy.Inventory.GetInventoryItem(player, table.name).count >= table.count then
                    if LSLegacy.Inventory.CanCarryItem(target, table.name, table.count) then
                        LSLegacy.Inventory.RemoveItemInInventory(player, table.name, table.count, table.label)
                        LSLegacy.Inventory.AddItemInInventory(target, table.name, table.count, table.label, table.uniqueId, table.data)
                        LSLegacy.SendEventToClient('notify', table.target, nil, table.count..' '..table.label..' ont été ajouté(s) à votre inventaire.', 'success')
                        LSLegacy.SendEventToClient('notify', source, nil, table.count..' '..table.label..' ont été retiré(s) de votre inventaire.', 'success')
                    else
                        LSLegacy.SendEventToClient('notify', table.target, nil, 'Vous ne pouvez pas transporter cet objet.', 'error')
                        LSLegacy.SendEventToClient('notify', source, nil, 'La personne ne peut pas transporter cet objet.', 'error')
                    end
                end
            end
        elseif table.type == 'item_cash' then
            if LSLegacy.Money.GetPlayerMoney(player) >= table.count then
                LSLegacy.Money.RemovePlayerMoney(player, table.count)
                LSLegacy.Money.AddPlayerMoney(target, table.count)
                LSLegacy.SendEventToClient('notify', table.target, nil, 'Vous avez reçu '..table.count..' $.', 'success')
                LSLegacy.SendEventToClient('notify', source, nil, 'Vous avez donné '..table.count..' $ à la personne.', 'success')
            else
                LSLegacy.SendEventToClient('notify', source, nil, 'Vous n\'avez pas assez d\'argent.', 'error')
            end
        elseif table.type == 'item_dirty' then
            if LSLegacy.Money.GetPlayerDirtyMoney(player) >= table.count then
                LSLegacy.Money.RemovePlayerDirtyMoney(player, table.count)
                LSLegacy.Money.AddPlayerDirtyMoney(target, table.count)
                LSLegacy.SendEventToClient('notify', table.target, nil, 'Vous avez reçu '..table.count..' $.', 'success')
                LSLegacy.SendEventToClient('notify', source, nil, 'Vous avez donné '..table.count..' $ à la personne.', 'success')
            else
                LSLegacy.SendEventToClient('notify', source, nil, 'Vous n\'avez pas assez d\'argent sale.', 'error')
            end
        end
    else
        LSLegacy.SendEventToClient('notify', source, nil, 'Il n\'y a aucune personne aux alentours de vous.', 'error')
    end
end)

LSLegacy.RegisterServerEvent('giveItem', function(item, quantity, newlabel, uniqueId, data)
    local _source = source
    local player = LSLegacy.GetPlayerFromId(_source)
    if player then
        if item == 'money' or item == 'dirty' then
			if item == 'money' then
				LSLegacy.Money.AddPlayerMoney(player, quantity)
				LSLegacy.SendEventToClient('notify', player.source, 'Inventaire', 'Vous avez reçu ' .. quantity .. '$', 'success')
			elseif item == 'dirty' then
				LSLegacy.Money.AddPlayerDirtyMoney(player, quantity)
				LSLegacy.SendEventToClient('notify', player.source, 'Inventaire', 'Vous avez reçu ' .. quantity .. '$', 'success')
			end
			return
		end

        if string.match(item, 'food_') then
            if LSLegacy.Inventory.CanCarryItem(player, item, quantity) then
                dataFood = {
                    durability = 100
                }
                LSLegacy.Inventory.AddItemInInventory(player, item, quantity, newlabel, uniqueId, dataFood)
                LSLegacy.SendEventToClient('notify', player.source, 'Inventaire', 'Vous avez reçu ' .. quantity .. 'x ' .. newlabel or LSLegacy.Inventory.GetInfosItem(item).label, 'success')
            else
                LSLegacy.SendEventToClient('notify', player.source, 'Inventaire', 'Vous ne pouvez pas porter + de cet item.', 'error')
            end
            return
        end

		if not string.match(item, 'weapon_') then
            if LSLegacy.Inventory.CanCarryItem(player, item, quantity) then
                LSLegacy.Inventory.AddItemInInventory(player, item, quantity, newlabel, uniqueId, data)
                LSLegacy.SendEventToClient('notify', player.source, 'Inventaire', 'Vous avez reçu ' .. quantity .. 'x ' .. newlabel or LSLegacy.Inventory.GetInfosItem(item).label, 'success')
            else
                LSLegacy.SendEventToClient('notify', player.source, 'Inventaire', 'Vous ne pouvez pas porter + de cet item.', 'error')
            end
		else
            if LSLegacy.Inventory.CanCarryItem(player, item, quantity) then
                dataWeapon = {
                    ammo = 0,
                    components = {},
                    serialNumber = LSLegacy.GenerateNumeroDeSerie()
                }
                LSLegacy.Inventory.AddItemInInventory(player, item, quantity, nil, nil, dataWeapon)
                LSLegacy.SendEventToClient('notify', player.source, 'Inventaire', 'Vous avez reçu ' .. quantity .. 'x ' .. LSLegacy.Inventory.GetInfosItem(item).label, 'success')
            else
                LSLegacy.SendEventToClient('notify', player.source, 'Inventaire', 'Vous ne pouvez pas porter + de cet item.', 'error')
            end
		end
    end
end)

LSLegacy.RegisterServerEvent('removeItem', function(item, quantity, label)
    local _source = source
    local player = LSLegacy.GetPlayerFromId(_source)
    if player then
        if LSLegacy.Inventory.GetInventoryItem(player, item) then
            if LSLegacy.Inventory.GetInventoryItem(player, item).count >= quantity then
                LSLegacy.Inventory.RemoveItemInInventory(player, item, quantity, label)
                LSLegacy.SendEventToClient('notify', _source, nil, "Vous avez perdu "..quantity.." "..label or LSLegacy.Inventory.GetInfosItem(item).label, 'success')
            end
        end
    end
end)