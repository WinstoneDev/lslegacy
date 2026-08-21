---@class LSLegacy.Pickup
LSLegacy.Pickup = {}
LSLegacy.PickupId = 0

LSLegacy.RegisterServerEvent('addItemPickup', function(itemName, itemType, itemLabel, itemCount, itemCoords, uniqueId, data)
	local _src = source
    local player = LSLegacy.GetPlayerFromId(_src)
    if itemType == "item_standard" then
        local item = LSLegacy.Inventory.GetInventoryItem(player, itemName)

        if item.count > 0 then
            if item.count >= itemCount then
                local pickupId = LSLegacy.PickupId + 1
                local pTable = {id = pickupId, name = itemName, label = itemLabel, count = itemCount, model = Config.Items[itemName].props or "v_serv_abox_02", coords = itemCoords, uniqueId = uniqueId, data = data, type = itemType}
                LSLegacy.Pickup[pickupId] = pTable
                LSLegacy.PickupId = pickupId
                LSLegacy.Inventory.RemoveItemInInventory(player, itemName, itemCount, itemLabel)
                LSLegacy.SendEventToClient('interactItemPickup', -1, "create", pTable)
                LSLegacy.SendEventToClient('notify', _src, nil, itemCount..' '..itemLabel..' ont été retiré(s) de votre inventaire.', 'success')
            else
                LSLegacy.SendEventToClient('notify', _src, nil, 'Vous n\'avez pas assez de '..itemLabel..'.', 'error')
            end
        end
    end

    if itemType == nil then
        if itemName == 'item_cash' then
            local cash = LSLegacy.Money.GetPlayerMoney(player)
            if tonumber(cash) >= tonumber(itemCount) then
                local pickupId = LSLegacy.PickupId + 1
                local pTable = {id = pickupId, name = itemName, label = itemLabel, count = itemCount, model = "v_serv_abox_02", coords = itemCoords, type = itemName}
                LSLegacy.Pickup[pickupId] = pTable
                LSLegacy.PickupId = pickupId
                LSLegacy.Money.RemovePlayerMoney(player, itemCount)
                LSLegacy.SendEventToClient('interactItemPickup', -1, "create", pTable)
                LSLegacy.SendEventToClient('notify', _src, nil, itemCount..'$ ont été retiré(s) de votre inventaire.', 'success')
            else
                LSLegacy.SendEventToClient('notify', _src, nil, 'Vous n\'avez pas assez de $.', 'error')
            end
        end
        if itemName == 'item_dirty' then
            local dirty = LSLegacy.Money.GetPlayerDirtyMoney(player)
            if dirty >= itemCount then
                local pickupId = LSLegacy.PickupId + 1
                local pTable = {id = pickupId, name = itemName, label = itemLabel, count = itemCount, model = "v_serv_abox_02", coords = itemCoords, itemType = itemName}
                LSLegacy.Pickup[pickupId] = pTable
                LSLegacy.PickupId = pickupId
                LSLegacy.Money.RemovePlayerDirtyMoney(player, itemCount)
                LSLegacy.SendEventToClient('interactItemPickup', -1, "create", pTable)
                LSLegacy.SendEventToClient('notify', _src, nil, itemCount..'$ ont été retiré(s) de votre inventaire.', 'success')
            else
                LSLegacy.SendEventToClient('notify', _src, nil, 'Vous n\'avez pas assez de $.', 'error')
            end
        end 
    end
end)

LSLegacy.RegisterServerEvent('removeItemPickup', function(data)
    local _src = source
    local player = LSLegacy.GetPlayerFromId(_src)

    if #(GetEntityCoords(GetPlayerPed(_src)) - data.coords) <= 5.5 then
        if LSLegacy.Pickup[data.id] then
                if data.type == 'item_cash' then
                    LSLegacy.Pickup[data.id] = nil
                    LSLegacy.Money.AddPlayerMoney(player, data.count)
                    LSLegacy.SendEventToClient('notify', _src, nil, data.count..'$ ont été ajouté(s) à votre inventaire.', 'success')
                    LSLegacy.SendEventToClient('interactItemPickup', -1, "retrieve", data)
                end

                if data.type == 'item_dirty' then
                    LSLegacy.Pickup[data.id] = nil
                    LSLegacy.Money.AddPlayerDirtyMoney(player, data.count)
                    LSLegacy.SendEventToClient('notify', _src, nil, data.count..'$ ont été ajouté(s) à votre inventaire.', 'success')
                    LSLegacy.SendEventToClient('interactItemPickup', -1, "retrieve", data)
                end

                if data.type == "item_standard" then
                    if LSLegacy.Inventory.CanCarryItem(player, data.name, tonumber(data.count)) then
                        LSLegacy.Pickup[data.id] = nil
                        LSLegacy.Inventory.AddItemInInventory(player, data.name, tonumber(data.count), data.label, data.uniqueId, data.data)
                        LSLegacy.SendEventToClient('interactItemPickup', -1, "retrieve", data)
                        LSLegacy.SendEventToClient('notify', _src, nil, data.count..' '..data.label..' ont été ajouté(s) à votre inventaire.', 'success')
                    else
                        LSLegacy.SendEventToClient('notify', source, nil, 'Vous n\'avez plus de place.', 'error')
                    end
                end
        else
            LSLegacy.SendEventToClient('notify', source, nil, 'ERREUR.', 'error')
        end
    end
end)