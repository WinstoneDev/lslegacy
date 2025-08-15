---@class MadeInFrance.Pickup
MadeInFrance.Pickup = {}
MadeInFrance.PickupId = 0

MadeInFrance.RegisterServerEvent('madeinfrance:addItemPickup', function(itemName, itemType, itemLabel, itemCount, itemCoords, uniqueId, data)
	local _src = source
    local player = MadeInFrance.GetPlayerFromId(_src)
    if itemType == "item_standard" then
        local item = MadeInFrance.Inventory.GetInventoryItem(player, itemName)

        if item.count > 0 then
            if item.count >= itemCount then
                local pickupId = MadeInFrance.PickupId + 1
                local pTable = {id = pickupId, name = itemName, label = itemLabel, count = itemCount, model = Config.Items[itemName].props or "v_serv_abox_02", coords = itemCoords, uniqueId = uniqueId, data = data, type = itemType}
                MadeInFrance.Pickup[pickupId] = pTable
                MadeInFrance.PickupId = pickupId
                MadeInFrance.Inventory.RemoveItemInInventory(player, itemName, itemCount, itemLabel)
                MadeInFrance.SendEventToClient('madeinfrance:interactItemPickup', -1, "create", pTable)
                MadeInFrance.SendEventToClient('madeinfrance:notify', _src, itemCount..' '..itemLabel..' ont été ~r~retiré(s)~s~ à votre inventaire.')
            else
                MadeInFrance.SendEventToClient('madeinfrance:notify', _src, 'Vous n\'avez pas assez de '..itemLabel..'.')
            end
        end
    end

    if itemType == nil then
        if itemName == 'item_cash' then
            local cash = MadeInFrance.Money.GetPlayerMoney(player)
            if tonumber(cash) >= tonumber(itemCount) then
                local pickupId = MadeInFrance.PickupId + 1
                local pTable = {id = pickupId, name = itemName, label = itemLabel, count = itemCount, model = "v_serv_abox_02", coords = itemCoords, type = itemName}
                MadeInFrance.Pickup[pickupId] = pTable
                MadeInFrance.PickupId = pickupId
                MadeInFrance.Money.RemovePlayerMoney(player, itemCount)
                MadeInFrance.SendEventToClient('madeinfrance:interactItemPickup', -1, "create", pTable)
                MadeInFrance.SendEventToClient('madeinfrance:notify', _src, itemCount..'$ ont été retiré(s) à votre inventaire.')
            else
                MadeInFrance.SendEventToClient('madeinfrance:notify', _src, 'Vous n\'avez pas assez de $.')
            end
        end
        if itemName == 'item_dirty' then
            local dirty = MadeInFrance.Money.GetPlayerDirtyMoney(player)
            if dirty >= itemCount then
                local pickupId = MadeInFrance.PickupId + 1
                local pTable = {id = pickupId, name = itemName, label = itemLabel, count = itemCount, model = "v_serv_abox_02", coords = itemCoords, itemType = itemName}
                MadeInFrance.Pickup[pickupId] = pTable
                MadeInFrance.PickupId = pickupId
                MadeInFrance.Money.RemovePlayerDirtyMoney(player, itemCount)
                MadeInFrance.SendEventToClient('madeinfrance:interactItemPickup', -1, "create", pTable)
                MadeInFrance.SendEventToClient('madeinfrance:notify', _src, itemCount..'$ ont été retiré(s) à votre inventaire.')
            else
                MadeInFrance.SendEventToClient('madeinfrance:notify', _src, 'Vous n\'avez pas assez de $.')
            end
        end 
    end
end)

MadeInFrance.RegisterServerEvent('madeinfrance:removeItemPickup', function(data)
    local _src = source
    local player = MadeInFrance.GetPlayerFromId(_src)

    if #(GetEntityCoords(GetPlayerPed(_src)) - data.coords) <= 5.5 then
        if MadeInFrance.Pickup[data.id] then
                if data.type == 'item_cash' then
                    MadeInFrance.Pickup[data.id] = nil
                    MadeInFrance.Money.AddPlayerMoney(player, data.count)
                    MadeInFrance.SendEventToClient('madeinfrance:notify', _src, data.count..'$ ont été ajouté(s) à votre inventaire.')
                    MadeInFrance.SendEventToClient('madeinfrance:interactItemPickup', -1, "retrieve", data)
                end

                if data.type == 'item_dirty' then
                    MadeInFrance.Pickup[data.id] = nil
                    MadeInFrance.Money.AddPlayerDirtyMoney(player, data.count)
                    MadeInFrance.SendEventToClient('madeinfrance:notify', _src, data.count..'$ ont été ajouté(s) à votre inventaire.')
                    MadeInFrance.SendEventToClient('madeinfrance:interactItemPickup', -1, "retrieve", data)
                end

                if data.type == "item_standard" then
                    if MadeInFrance.Inventory.CanCarryItem(player, data.name, tonumber(data.count)) then
                        MadeInFrance.Pickup[data.id] = nil
                        MadeInFrance.Inventory.AddItemInInventory(player, data.name, tonumber(data.count), data.label, data.uniqueId, data.data)
                        MadeInFrance.SendEventToClient('madeinfrance:interactItemPickup', -1, "retrieve", data)
                        MadeInFrance.SendEventToClient('madeinfrance:notify', _src, data.count..' '..data.label..' ont été ~g~ajouté(s)~s~ à votre inventaire.')
                    else
                        MadeInFrance.SendEventToClient('madeinfrance:notify', source, '~r~Vous n\'avez plus de place.')
                    end
                end
        else
            MadeInFrance.SendEventToClient('madeinfrance:notify', source, '~r~ERREUR.')
        end
    end
end)