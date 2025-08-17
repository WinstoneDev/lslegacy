MadeInFrance.RegisterServerEvent('PutIntoTrunk', function(data, name)
    if not data or not name then return end
    local source = source
    local datastore = MadeInFrance.DataStore.GetDataStore(name)
    local player = MadeInFrance.GetPlayerFromId(source)
    if not datastore then
        Config.Development.Print("DataStore " .. name .. " does not exist.")
        return
    end

    if data.type == 'item_standard' then
        if MadeInFrance.Inventory.GetInventoryItem(player, data.name) ~= nil then
            if MadeInFrance.Inventory.GetInventoryItem(player, data.name).count >= data.count then
                if MadeInFrance.DataStore.CanStoreItem(datastore, data.name, data.count) then
                    MadeInFrance.Inventory.RemoveItemInInventory(player, data.name, data.count, data.label)
                    MadeInFrance.DataStore.AddItemInInventory(datastore, data.name, data.count, data.label, data.uniqueId, data.data)
                    MadeInFrance.SendEventToClient('notify', source, nil, data.count..' '..data.label..' ont été ajouté(s) au coffre.', 'success')
                else
                    MadeInFrance.SendEventToClient('notify', source, nil, 'Vous ne pouvez pas déposer cet objet.', 'error')
                end
            else
                MadeInFrance.SendEventToClient('notify', source, nil, 'Vous n\'avez pas assez de cet objet.', 'error')
            end
        else
            MadeInFrance.SendEventToClient('notify', source, nil, 'Vous n\'avez pas cet objet.', 'error')
        end
    elseif data.type == 'item_cash' then
        if MadeInFrance.Money.GetPlayerMoney(player) >= data.count then
            MadeInFrance.Money.RemovePlayerMoney(player, data.count)
            MadeInFrance.DataStore.AddMoney(datastore, data.count)
            MadeInFrance.SendEventToClient('notify', source, nil, data.count..' $ ont été ajouté(s) au coffre.', 'success')
        else
            MadeInFrance.SendEventToClient('notify', source, nil, 'Vous n\'avez pas assez d\'argent.', 'error')
        end
    elseif data.type == 'item_dirty' then
        if MadeInFrance.Money.GetPlayerDirtyMoney(player) >= data.count then
            MadeInFrance.Money.RemovePlayerDirtyMoney(player, data.count)
            MadeInFrance.DataStore.AddDirtyMoney(datastore, data.count)
            MadeInFrance.SendEventToClient('notify', source, nil, data.count..' $ ont été ajouté(s) au coffre.', 'success')
        else
            MadeInFrance.SendEventToClient('notify', source, nil, 'Vous n\'avez pas assez d\'argent.', 'error')
        end
    end
end)

MadeInFrance.RegisterServerEvent('TakeFromTrunk', function(data, name)
    if not data or not name then return end
    local source = source
    local datastore = MadeInFrance.DataStore.GetDataStore(name)
    local player = MadeInFrance.GetPlayerFromId(source)
    if not datastore then
        Config.Development.Print("DataStore " .. name .. " does not exist.")
        return
    end
    if data.type == 'item_standard' then
        if MadeInFrance.DataStore.GetInventoryItem(datastore, data.name) ~= nil then
            if MadeInFrance.DataStore.GetInventoryItem(datastore, data.name).count >= data.count then
                if MadeInFrance.Inventory.CanCarryItem(player, data.name, data.count) then
                    MadeInFrance.DataStore.RemoveItemInInventory(datastore, data.name, data.count)
                    MadeInFrance.Inventory.AddItemInInventory(player, data.name, data.count, data.label, data.uniqueId, data.data)
                    MadeInFrance.SendEventToClient('notify', source, nil, data.count..' '..data.label..' ont été retiré(s) du coffre.', 'success')
                else
                    MadeInFrance.SendEventToClient('notify', source, nil, 'Vous ne pouvez pas retirer cet objet.', 'error')
                end
            else
                MadeInFrance.SendEventToClient('notify', source, nil, 'Le coffre n\'a pas assez de cet objet.', 'error')
            end
        else
            MadeInFrance.SendEventToClient('notify', source, nil, 'Le coffre ne contient pas cet objet.', 'error')
        end
    elseif data.type == 'item_cash' then
        if MadeInFrance.DataStore.GetMoney(datastore) >= data.count then
            MadeInFrance.DataStore.RemoveMoney(datastore, data.count)
            MadeInFrance.Money.AddPlayerMoney(player, data.count)
            MadeInFrance.SendEventToClient('notify', source, nil, data.count..' $ ont été retiré(s) du coffre.', 'success')
        else
            MadeInFrance.SendEventToClient('notify', source, nil, 'Le coffre n\'a pas assez d\'argent.', 'error')
        end
    elseif data.type == 'item_dirty' then
        if MadeInFrance.DataStore.GetDirtyMoney(datastore) >= data.count then
            MadeInFrance.DataStore.RemoveDirtyMoney(datastore, data.count)
            MadeInFrance.Money.AddPlayerDirtyMoney(player, data.count)
            MadeInFrance.SendEventToClient('notify', source, nil, data.count..' $ ont été retiré(s) du coffre.', 'success')
        else
            MadeInFrance.SendEventToClient('notify', source, nil, 'Le coffre n\'a pas assez d\'argent sale.', 'error')
        end
    end
end)

MadeInFrance.RegisterServerEvent('removeAmmo', function(item, quantity)
    local _source = source
    local player = MadeInFrance.GetPlayerFromId(_source)

    if player then
        local invItem = MadeInFrance.Inventory.GetInventoryItem(player, item)
        if invItem then
            local playerCount = invItem.count
            local ammoToGive = math.min(playerCount, quantity)

            if ammoToGive > 0 then
                MadeInFrance.Inventory.RemoveItemInInventory(player, item, ammoToGive)
                MadeInFrance.SendEventToClient('notify', _source, nil, "Vous avez rechargé "..ammoToGive.." "..Config.Items[item].label, 'success')
                MadeInFrance.SendEventToClient('setAmmo', _source, item, ammoToGive)
            end
        end
    end
end)