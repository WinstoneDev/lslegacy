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

LSLegacy.Events.Register('lslegacy:putIntoTrunk', function(data, name)
    if not data or not name then return end
    local source = source
    if data.name and Config.NonTransferableItems[data.name] then
        LSLegacy.Events.SendToClient('notify', source, nil, 'Cet objet ne peut pas être transféré.', 'error')
        return
    end
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
                    LSLegacy.Inventory.RemoveItemInInventory(player, data.name, data.count, data.label, sourceItem.uniqueId)
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

LSLegacy.Events.Register('lslegacy:takeFromTrunk', function(data, name)
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

                -- Trace le type de munition réellement chambrée (nul pour la
                -- plupart des armes, utile pour la munition d'entrainement :
                -- cf. module/nonlethal, neutralisation des dégâts en jeu).
                if weaponName and Config.NonLethal.TrainingAmmo.ammoItem then
                    for _, v in pairs(player.inventory) do
                        if v.name == weaponName and v.data then
                            v.data.ammoType = (item == Config.NonLethal.TrainingAmmo.ammoItem) and 'training' or 'live'
                            break
                        end
                    end
                end

                LSLegacy.Events.SendToClient('notify', _source, nil, "Vous avez rechargé "..ammoToGive.." "..LSLegacy.Inventory.GetInfosItem(item).label, 'success')
                LSLegacy.Events.SendToClient('setAmmo', _source, item, ammoToGive, weaponName)
                LSLegacy.Events.SendToClient('lslegacy:updatePlayer', _source, player)
            end
        end
    end
end)

-- Retrouve l'instance d'arme par uniqueId et vérifie que le component demandé
-- est bien compatible (Config.WeaponComponents), pour éviter tout appel forgé côté NUI.
local function FindOwnedWeapon(player, weaponUniqueId, weaponName)
    for _, v in pairs(player.inventory) do
        if v.name == weaponName and v.uniqueId == weaponUniqueId then
            return v
        end
    end
    return nil
end

local function FindComponentDef(weaponName, componentItem)
    local list = Config.WeaponComponents[weaponName]
    if not list then return nil end
    for _, def in pairs(list) do
        if def.item == componentItem then return def end
    end
    return nil
end

-- Suppression admin d'un item (ex : arme d'une ancienne version, injetable
-- suite à un renommage) depuis le clic gauche NUI, revalidée ici.
LSLegacy.Events.Register('inventory:adminDeleteItem', function(item, uniqueId)
    local source = source
    local player = LSLegacy.GetPlayerFromId(source)
    if not player or not item then return end
    if not LSLegacy.Permissions.Has(player, 3) then return end

    if not LSLegacy.Inventory.GetInventoryItem(player, item) then return end

    LSLegacy.Inventory.RemoveItemInInventory(player, item, 1, nil, uniqueId)
    LSLegacy.Events.SendToClient('notify', source, nil, (LSLegacy.Inventory.GetInfosItem(item) and LSLegacy.Inventory.GetInfosItem(item).label or item) .. ' supprimé.', 'info')
end)

LSLegacy.Events.Register('lslegacy:attachWeaponComponent', function(weaponUniqueId, weaponName, componentItem)
    local source = source
    local player = LSLegacy.GetPlayerFromId(source)
    if not player then return end

    local componentDef = FindComponentDef(weaponName, componentItem)
    if not componentDef then return end

    local weapon = FindOwnedWeapon(player, weaponUniqueId, weaponName)
    if not weapon then
        LSLegacy.Events.SendToClient('notify', source, nil, 'Vous ne possédez pas cette arme.', 'error')
        return
    end

    local owned = LSLegacy.Inventory.GetInventoryItem(player, componentItem)
    if not owned or owned.count < 1 then
        LSLegacy.Events.SendToClient('notify', source, nil, 'Vous n\'avez pas cet accessoire.', 'error')
        return
    end

    weapon.data = weapon.data or {}
    weapon.data.components = weapon.data.components or {}

    -- Un seul accessoire par slot : celui déjà en place est rendu à l'inventaire.
    for i = #weapon.data.components, 1, -1 do
        local existing = weapon.data.components[i]
        local existingDef = FindComponentDef(weaponName, existing)
        if existingDef and existingDef.slot == componentDef.slot then
            table.remove(weapon.data.components, i)
            LSLegacy.Inventory.AddItemInInventory(player, existing, 1)
        end
    end

    LSLegacy.Inventory.RemoveItemInInventory(player, componentItem, 1)
    table.insert(weapon.data.components, componentItem)
    player:MarkDirty('inventory')
    LSLegacy.Events.SendToClient('lslegacy:updatePlayer', player.source, player)
    LSLegacy.Events.SendToClient('notify', source, nil, LSLegacy.Inventory.GetInfosItem(componentItem).label..' attaché(e).', 'success')
end)

LSLegacy.Events.Register('lslegacy:detachWeaponComponent', function(weaponUniqueId, weaponName, componentItem)
    local source = source
    local player = LSLegacy.GetPlayerFromId(source)
    if not player then return end

    local weapon = FindOwnedWeapon(player, weaponUniqueId, weaponName)
    if not weapon or not weapon.data or not weapon.data.components then return end

    for i, existing in pairs(weapon.data.components) do
        if existing == componentItem then
            table.remove(weapon.data.components, i)
            LSLegacy.Inventory.AddItemInInventory(player, componentItem, 1)
            player:MarkDirty('inventory')
            LSLegacy.Events.SendToClient('lslegacy:updatePlayer', player.source, player)
            LSLegacy.Events.SendToClient('notify', source, nil, LSLegacy.Inventory.GetInfosItem(componentItem).label..' retiré(e).', 'success')
            return
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
            LSLegacy.Events.SendToClient('lslegacy:updatePlayer', player.source, player)
            break
        end
    end
end)

-- Protection restante d'un gilet : liée à l'instance exacte (uniqueId) pour
-- qu'un gilet endommagé garde sa valeur après un déséquipement/rééquipement.
-- uniqueId peut être celui d'un item 'bproof' seul ou d'une tenue ('outfit')
-- dans laquelle le gilet a été fusionné : dans ce cas la valeur est stockée
-- dans data.bproof_armor de la tenue plutôt que sur un item bproof à part.
LSLegacy.Events.Register('updateVestArmour', function(uniqueId, armourValue)
    local _source = source
    local player = LSLegacy.GetPlayerFromId(_source)
    if not player then return end
    local clamped = math.max(0, math.min(100, tonumber(armourValue) or 0))
    for _, v in pairs(player.inventory) do
        if v.uniqueId == uniqueId then
            if v.name == 'bproof' then
                v.armor = clamped
            elseif v.name == 'outfit' and v.data then
                v.data.bproof_armor = clamped
            else
                return
            end
            player:MarkDirty('inventory')
            LSLegacy.Events.SendToClient('lslegacy:updatePlayer', player.source, player)
            break
        end
    end
end)