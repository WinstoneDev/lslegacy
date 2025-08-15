MadeInFrance.RegisterServerEvent('PutIntoTrunk', function(data, name)
    if not data or not name then return end
    local source = source
    local datastore = MadeInFrance.DataStore.GetDataStore(name)
    local player = MadeInFrance.GetPlayerFromId(source)
    if not datastore then
        Config.Development.Print("DataStore " .. name .. " does not exist.")
        return
    end

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
end)