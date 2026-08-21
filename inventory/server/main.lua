-- Garde d'accès générique pour les DataStores (coffres, conteneurs, stashs).
-- Par défaut tout est autorisé ; des modules (ex. keyhanger) peuvent l'étendre
-- pour restreindre l'accès/les items selon le nom du DataStore.
LSLegacy.DataStoreGuard = LSLegacy.DataStoreGuard or function(_src, _name, _action, _item) return true end

LSLegacy.RegisterServerEvent('PutIntoTrunk', function(data, name)
    if not data or not name then return end
    local source = source
    local datastore = LSLegacy.DataStore.GetDataStore(name)
    local player = LSLegacy.GetPlayerFromId(source)
    if not datastore then
        Config.Development.Print("DataStore " .. name .. " does not exist.")
        return
    end
    if not LSLegacy.DataStoreGuard(source, name, 'put', data.name) then
        LSLegacy.SendEventToClient('notify', source, nil, 'Vous ne pouvez pas déposer cela ici.', 'error')
        return
    end

    if data.type == 'item_standard' then
        if LSLegacy.Inventory.GetInventoryItem(player, data.name) ~= nil then
            if LSLegacy.Inventory.GetInventoryItem(player, data.name).count >= data.count then
                if LSLegacy.DataStore.CanStoreItem(datastore, data.name, data.count) then
                    LSLegacy.Inventory.RemoveItemInInventory(player, data.name, data.count, data.label)
                    LSLegacy.DataStore.AddItemInInventory(datastore, data.name, data.count, data.label, data.uniqueId, data.data)
                    LSLegacy.SendEventToClient('notify', source, nil, data.count..' '..data.label..' ont été ajouté(s) au coffre.', 'success')
                    TriggerEvent('lslegacy:containerUpdated', name, source)
                else
                    LSLegacy.SendEventToClient('notify', source, nil, 'Vous ne pouvez pas déposer cet objet.', 'error')
                end
            else
                LSLegacy.SendEventToClient('notify', source, nil, 'Vous n\'avez pas assez de cet objet.', 'error')
            end
        else
            LSLegacy.SendEventToClient('notify', source, nil, 'Vous n\'avez pas cet objet.', 'error')
        end
    elseif data.type == 'item_cash' then
        if LSLegacy.Money.GetPlayerMoney(player) >= data.count then
            LSLegacy.Money.RemovePlayerMoney(player, data.count)
            LSLegacy.DataStore.AddMoney(datastore, data.count)
            LSLegacy.SendEventToClient('notify', source, nil, data.count..' $ ont été ajouté(s) au coffre.', 'success')
        else
            LSLegacy.SendEventToClient('notify', source, nil, 'Vous n\'avez pas assez d\'argent.', 'error')
        end
    elseif data.type == 'item_dirty' then
        if LSLegacy.Money.GetPlayerDirtyMoney(player) >= data.count then
            LSLegacy.Money.RemovePlayerDirtyMoney(player, data.count)
            LSLegacy.DataStore.AddDirtyMoney(datastore, data.count)
            LSLegacy.SendEventToClient('notify', source, nil, data.count..' $ ont été ajouté(s) au coffre.', 'success')
        else
            LSLegacy.SendEventToClient('notify', source, nil, 'Vous n\'avez pas assez d\'argent.', 'error')
        end
    end
end)

LSLegacy.RegisterServerEvent('TakeFromTrunk', function(data, name)
    if not data or not name then return end
    local source = source
    local datastore = LSLegacy.DataStore.GetDataStore(name)
    local player = LSLegacy.GetPlayerFromId(source)
    if not datastore then
        Config.Development.Print("DataStore " .. name .. " does not exist.")
        return
    end
    if not LSLegacy.DataStoreGuard(source, name, 'take', data.name) then
        LSLegacy.SendEventToClient('notify', source, nil, 'Vous ne pouvez pas prendre cela ici.', 'error')
        return
    end
    if data.type == 'item_standard' then
        if LSLegacy.DataStore.GetInventoryItem(datastore, data.name) ~= nil then
            if LSLegacy.DataStore.GetInventoryItem(datastore, data.name).count >= data.count then
                if LSLegacy.Inventory.CanCarryItem(player, data.name, data.count) then
                    LSLegacy.DataStore.RemoveItemInInventory(datastore, data.name, data.count)
                    LSLegacy.Inventory.AddItemInInventory(player, data.name, data.count, data.label, data.uniqueId, data.data)
                    LSLegacy.SendEventToClient('notify', source, nil, data.count..' '..data.label..' ont été retiré(s) du coffre.', 'success')
                    TriggerEvent('lslegacy:containerUpdated', name, source)
                else
                    LSLegacy.SendEventToClient('notify', source, nil, 'Vous ne pouvez pas retirer cet objet.', 'error')
                end
            else
                LSLegacy.SendEventToClient('notify', source, nil, 'Le coffre n\'a pas assez de cet objet.', 'error')
            end
        else
            LSLegacy.SendEventToClient('notify', source, nil, 'Le coffre ne contient pas cet objet.', 'error')
        end
    elseif data.type == 'item_cash' then
        if LSLegacy.DataStore.GetMoney(datastore) >= data.count then
            LSLegacy.DataStore.RemoveMoney(datastore, data.count)
            LSLegacy.Money.AddPlayerMoney(player, data.count)
            LSLegacy.SendEventToClient('notify', source, nil, data.count..' $ ont été retiré(s) du coffre.', 'success')
        else
            LSLegacy.SendEventToClient('notify', source, nil, 'Le coffre n\'a pas assez d\'argent.', 'error')
        end
    elseif data.type == 'item_dirty' then
        if LSLegacy.DataStore.GetDirtyMoney(datastore) >= data.count then
            LSLegacy.DataStore.RemoveDirtyMoney(datastore, data.count)
            LSLegacy.Money.AddPlayerDirtyMoney(player, data.count)
            LSLegacy.SendEventToClient('notify', source, nil, data.count..' $ ont été retiré(s) du coffre.', 'success')
        else
            LSLegacy.SendEventToClient('notify', source, nil, 'Le coffre n\'a pas assez d\'argent sale.', 'error')
        end
    end
end)

LSLegacy.RegisterServerEvent('removeAmmo', function(item, quantity, weaponName)
    local _source = source
    local player = LSLegacy.GetPlayerFromId(_source)

    if player then
        local invItem = LSLegacy.Inventory.GetInventoryItem(player, item)
        if invItem then
            local playerCount = invItem.count
            local ammoToGive = math.min(playerCount, quantity)

            if ammoToGive > 0 then
                LSLegacy.Inventory.RemoveItemInInventory(player, item, ammoToGive)
                LSLegacy.SendEventToClient('notify', _source, nil, "Vous avez rechargé "..ammoToGive.." "..LSLegacy.Inventory.GetInfosItem(item).label, 'success')
                LSLegacy.SendEventToClient('setAmmo', _source, item, ammoToGive, weaponName)
            end
        end
    end
end)

LSLegacy.RegisterServerEvent('updateWeaponAmmo', function(weaponName, ammoCount)
    local _source = source
    local player = LSLegacy.GetPlayerFromId(_source)
    if not player then return end
    for _, v in pairs(player.inventory) do
        if v.name == weaponName and v.data then
            v.data.ammo = tonumber(ammoCount) or 0
            local weight = LSLegacy.Inventory.GetInventoryWeight(player.inventory)
            player.weight = weight
            LSLegacy.SendEventToClient('UpdatePlayer', player.source, player)
            break
        end
    end
end)