-- Garde d'accès générique pour les DataStores (coffres, conteneurs, stashs).
-- Par défaut tout est autorisé ; des modules (ex. keyhanger, atelier) peuvent
-- l'étendre pour restreindre l'accès/les items selon le nom du DataStore.
LSLegacy.DataStoreGuard = LSLegacy.DataStoreGuard or function(_src, _name, _action, _item) return true end

-- Plaque devinable dans le nom du DataStore : on exige un véhicule réel à proximité.
local function FindNearbyVehicleByPlate(plate, coords)
    for _, vehicle in pairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and GetVehicleNumberPlateText(vehicle) == plate then
            if LSLegacy.Validate.Distance(coords, GetEntityCoords(vehicle), 5.0) then
                return vehicle
            end
        end
    end
    return nil
end

local prevGuard = LSLegacy.DataStoreGuard
LSLegacy.DataStoreGuard = function(src, name, action, item)
    if type(name) == "string" then
        local plate = name:match("^trunk_(.+)$") or name:match("^bag_(.+)$")
        if plate then
            local player = LSLegacy.Validate.Player(src)
            if not player then return false end
            if not FindNearbyVehicleByPlate(plate, GetEntityCoords(GetPlayerPed(src))) then return false end
            return true
        end
    end
    if prevGuard then return prevGuard(src, name, action, item) end
    return true
end

LSLegacy.Events.Register('PutIntoTrunk', function(data, name)
    if not data or not name then return end
    local source = source
    local datastore = LSLegacy.DataStore.GetDataStore(name)
    local player = LSLegacy.GetPlayerFromId(source)
    if not datastore then
        Config.Development.Print("DataStore " .. name .. " does not exist.")
        return
    end
    if not LSLegacy.DataStoreGuard(source, name, 'put', data.name) then
        LSLegacy.Events.SendToClient('notify', source, nil, 'Vous ne pouvez pas déposer cela ici.', 'error')
        return
    end

    if data.type == 'item_standard' then
        local sourceItem = LSLegacy.Inventory.GetInventoryItem(player, data.name)
        if sourceItem ~= nil then
            if sourceItem.count >= data.count then
                if LSLegacy.DataStore.CanStoreItem(datastore, data.name, data.count) then
                    LSLegacy.Inventory.RemoveItemInInventory(player, data.name, data.count, data.label)
                    LSLegacy.DataStore.AddItemInInventory(datastore, data.name, data.count, data.label, sourceItem.uniqueId, sourceItem.data)
                    LSLegacy.Events.SendToClient('notify', source, nil, data.count..' '..data.label..' ont été ajouté(s) au coffre.', 'success')
                    TriggerEvent('lslegacy:containerUpdated', name, source)
                else
                    LSLegacy.Events.SendToClient('notify', source, nil, 'Vous ne pouvez pas déposer cet objet.', 'error')
                end
            else
                LSLegacy.Events.SendToClient('notify', source, nil, 'Vous n\'avez pas assez de cet objet.', 'error')
            end
        else
            LSLegacy.Events.SendToClient('notify', source, nil, 'Vous n\'avez pas cet objet.', 'error')
        end
    elseif data.type == 'item_cash' then
        if LSLegacy.Money.GetPlayerMoney(player) >= data.count then
            LSLegacy.Money.RemovePlayerMoney(player, data.count)
            LSLegacy.DataStore.AddMoney(datastore, data.count)
            LSLegacy.Events.SendToClient('notify', source, nil, data.count..' $ ont été ajouté(s) au coffre.', 'success')
        else
            LSLegacy.Events.SendToClient('notify', source, nil, 'Vous n\'avez pas assez d\'argent.', 'error')
        end
    elseif data.type == 'item_dirty' then
        if LSLegacy.Money.GetPlayerDirtyMoney(player) >= data.count then
            LSLegacy.Money.RemovePlayerDirtyMoney(player, data.count)
            LSLegacy.DataStore.AddDirtyMoney(datastore, data.count)
            LSLegacy.Events.SendToClient('notify', source, nil, data.count..' $ ont été ajouté(s) au coffre.', 'success')
        else
            LSLegacy.Events.SendToClient('notify', source, nil, 'Vous n\'avez pas assez d\'argent.', 'error')
        end
    end
end)

LSLegacy.Events.Register('TakeFromTrunk', function(data, name)
    if not data or not name then return end
    local source = source
    local datastore = LSLegacy.DataStore.GetDataStore(name)
    local player = LSLegacy.GetPlayerFromId(source)
    if not datastore then
        Config.Development.Print("DataStore " .. name .. " does not exist.")
        return
    end
    if not LSLegacy.DataStoreGuard(source, name, 'take', data.name) then
        LSLegacy.Events.SendToClient('notify', source, nil, 'Vous ne pouvez pas prendre cela ici.', 'error')
        return
    end
    if data.type == 'item_standard' then
        local storedItem = LSLegacy.DataStore.GetInventoryItem(datastore, data.name)
        if storedItem ~= nil then
            if storedItem.count >= data.count then
                if LSLegacy.Inventory.CanCarryItem(player, data.name, data.count) then
                    LSLegacy.DataStore.RemoveItemInInventory(datastore, data.name, data.count)
                    LSLegacy.Inventory.AddItemInInventory(player, data.name, data.count, data.label, storedItem.uniqueId, storedItem.data)
                    LSLegacy.Events.SendToClient('notify', source, nil, data.count..' '..data.label..' ont été retiré(s) du coffre.', 'success')
                    TriggerEvent('lslegacy:containerUpdated', name, source)
                else
                    LSLegacy.Events.SendToClient('notify', source, nil, 'Vous ne pouvez pas retirer cet objet.', 'error')
                end
            else
                LSLegacy.Events.SendToClient('notify', source, nil, 'Le coffre n\'a pas assez de cet objet.', 'error')
            end
        else
            LSLegacy.Events.SendToClient('notify', source, nil, 'Le coffre ne contient pas cet objet.', 'error')
        end
    elseif data.type == 'item_cash' then
        if LSLegacy.DataStore.GetMoney(datastore) >= data.count then
            LSLegacy.DataStore.RemoveMoney(datastore, data.count)
            LSLegacy.Money.AddPlayerMoney(player, data.count)
            LSLegacy.Events.SendToClient('notify', source, nil, data.count..' $ ont été retiré(s) du coffre.', 'success')
        else
            LSLegacy.Events.SendToClient('notify', source, nil, 'Le coffre n\'a pas assez d\'argent.', 'error')
        end
    elseif data.type == 'item_dirty' then
        if LSLegacy.DataStore.GetDirtyMoney(datastore) >= data.count then
            LSLegacy.DataStore.RemoveDirtyMoney(datastore, data.count)
            LSLegacy.Money.AddPlayerDirtyMoney(player, data.count)
            LSLegacy.Events.SendToClient('notify', source, nil, data.count..' $ ont été retiré(s) du coffre.', 'success')
        else
            LSLegacy.Events.SendToClient('notify', source, nil, 'Le coffre n\'a pas assez d\'argent sale.', 'error')
        end
    end
end)

LSLegacy.Events.Register('removeAmmo', function(item, quantity, weaponName)
    local _source = source
    local player = LSLegacy.GetPlayerFromId(_source)

    if player then
        local invItem = LSLegacy.Inventory.GetInventoryItem(player, item)
        if invItem then
            local playerCount = invItem.count
            local ammoToGive = math.min(playerCount, quantity)

            if ammoToGive > 0 then
                LSLegacy.Inventory.RemoveItemInInventory(player, item, ammoToGive)
                LSLegacy.Events.SendToClient('notify', _source, nil, "Vous avez rechargé "..ammoToGive.." "..LSLegacy.Inventory.GetInfosItem(item).label, 'success')
                LSLegacy.Events.SendToClient('setAmmo', _source, item, ammoToGive, weaponName)
            end
        end
    end
end)

LSLegacy.Events.Register('updateWeaponAmmo', function(weaponName, ammoCount)
    local _source = source
    local player = LSLegacy.GetPlayerFromId(_source)
    if not player then return end
    for _, v in pairs(player.inventory) do
        if v.name == weaponName and v.data then
            v.data.ammo = tonumber(ammoCount) or 0
            local weight = LSLegacy.Inventory.GetInventoryWeight(player.inventory)
            player.weight = weight
            LSLegacy.Events.SendToClient('UpdatePlayer', player.source, player)
            break
        end
    end
end)