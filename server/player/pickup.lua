---@class LSLegacy.Pickup
LSLegacy.Pickup = {}
-- table de données séparée de l'espace de noms LSLegacy.Pickup (qui porte aussi
-- SyncBucket) : éviter qu'un pairs() sur les pickups tombe sur une fonction
local PickupData = {}
LSLegacy.PickupId = 0

-- Diffuse un event uniquement aux joueurs du bucket donné : un objet jeté au sol
-- dans une instance (garage, appart, créateur…) ne doit être visible/ramassable
-- que par ceux qui y sont, jamais par tout le monde en bucket 0 ou une autre instance.
local function SendToBucket(bucket, event, ...)
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        if GetPlayerRoutingBucket(src) == bucket then
            LSLegacy.Events.SendToClient(event, src, ...)
        end
    end
end

-- Resynchronise les objets au sol visibles par un joueur après un changement de
-- bucket (entrée/sortie de garage, appart multichar, instance créateur…).
function LSLegacy.Pickup.SyncBucket(src, bucket)
    local list = {}
    for _, p in pairs(PickupData) do
        if p.bucket == bucket then list[#list + 1] = p end
    end
    LSLegacy.Events.SendToClient('pickup:syncBucket', src, list)
end

LSLegacy.Events.Register('addItemPickup', function(itemName, itemType, itemLabel, itemCount, itemCoords, uniqueId, data)
	local _src = source
	if Config.NonTransferableItems[itemName] then
		LSLegacy.Events.SendToClient('notify', _src, nil, 'Cet objet ne peut pas être transféré.', 'error')
		return
	end
    local player = LSLegacy.GetPlayerFromId(_src)
    local bucket = GetPlayerRoutingBucket(_src)
    if itemType == "item_standard" then
        local item = LSLegacy.Inventory.GetInventoryItem(player, itemName)

        if item.count > 0 then
            if item.count >= itemCount then
                local pickupId = LSLegacy.PickupId + 1
                local pTable = {id = pickupId, name = itemName, label = itemLabel, count = itemCount, model = Config.Items[itemName].props or "v_serv_abox_02", coords = itemCoords, uniqueId = uniqueId, data = data, type = itemType, bucket = bucket}
                PickupData[pickupId] = pTable
                LSLegacy.PickupId = pickupId
                LSLegacy.Inventory.RemoveItemInInventory(player, itemName, itemCount, itemLabel, uniqueId)
                SendToBucket(bucket, 'interactItemPickup', "create", pTable)
                LSLegacy.Events.SendToClient('notify', _src, nil, itemCount..' '..itemLabel..' ont été retiré(s) de votre inventaire.', 'success')
            else
                LSLegacy.Events.SendToClient('notify', _src, nil, 'Vous n\'avez pas assez de '..itemLabel..'.', 'error')
            end
        end
    end

    if itemType == nil then
        if itemName == 'item_cash' then
            local cash = LSLegacy.Money.GetPlayerMoney(player)
            if tonumber(cash) >= tonumber(itemCount) then
                local pickupId = LSLegacy.PickupId + 1
                local pTable = {id = pickupId, name = itemName, label = itemLabel, count = itemCount, model = "v_serv_abox_02", coords = itemCoords, type = itemName, bucket = bucket}
                PickupData[pickupId] = pTable
                LSLegacy.PickupId = pickupId
                LSLegacy.Money.RemovePlayerMoney(player, itemCount)
                SendToBucket(bucket, 'interactItemPickup', "create", pTable)
                LSLegacy.Events.SendToClient('notify', _src, nil, itemCount..'$ ont été retiré(s) de votre inventaire.', 'success')
            else
                LSLegacy.Events.SendToClient('notify', _src, nil, 'Vous n\'avez pas assez de $.', 'error')
            end
        end
        if itemName == 'item_dirty' then
            local dirty = LSLegacy.Money.GetPlayerDirtyMoney(player)
            if dirty >= itemCount then
                local pickupId = LSLegacy.PickupId + 1
                local pTable = {id = pickupId, name = itemName, label = itemLabel, count = itemCount, model = "v_serv_abox_02", coords = itemCoords, itemType = itemName, bucket = bucket}
                PickupData[pickupId] = pTable
                LSLegacy.PickupId = pickupId
                LSLegacy.Money.RemovePlayerDirtyMoney(player, itemCount)
                SendToBucket(bucket, 'interactItemPickup', "create", pTable)
                LSLegacy.Events.SendToClient('notify', _src, nil, itemCount..'$ ont été retiré(s) de votre inventaire.', 'success')
            else
                LSLegacy.Events.SendToClient('notify', _src, nil, 'Vous n\'avez pas assez de $.', 'error')
            end
        end
    end
end)

LSLegacy.Events.Register('removeItemPickup', function(data)
    local _src = source
    local player = LSLegacy.GetPlayerFromId(_src)

    if #(GetEntityCoords(GetPlayerPed(_src)) - data.coords) <= 5.5 then
        local pk = PickupData[data.id]
        if pk and pk.bucket ~= GetPlayerRoutingBucket(_src) then
            return LSLegacy.Events.SendToClient('notify', _src, nil, 'ERREUR.', 'error')
        end
        if pk then
                local bucket = pk.bucket
                if data.type == 'item_cash' then
                    PickupData[data.id] = nil
                    LSLegacy.Money.AddPlayerMoney(player, data.count)
                    LSLegacy.Events.SendToClient('notify', _src, nil, data.count..'$ ont été ajouté(s) à votre inventaire.', 'success')
                    SendToBucket(bucket, 'interactItemPickup', "retrieve", data)
                end

                if data.type == 'item_dirty' then
                    PickupData[data.id] = nil
                    LSLegacy.Money.AddPlayerDirtyMoney(player, data.count)
                    LSLegacy.Events.SendToClient('notify', _src, nil, data.count..'$ ont été ajouté(s) à votre inventaire.', 'success')
                    SendToBucket(bucket, 'interactItemPickup', "retrieve", data)
                end

                if data.type == "item_standard" then
                    if LSLegacy.Inventory.CanCarryItem(player, data.name, tonumber(data.count)) then
                        PickupData[data.id] = nil
                        LSLegacy.Inventory.AddItemInInventory(player, data.name, tonumber(data.count), data.label, data.uniqueId, data.data)
                        SendToBucket(bucket, 'interactItemPickup', "retrieve", data)
                        LSLegacy.Events.SendToClient('notify', _src, nil, data.count..' '..data.label..' ont été ajouté(s) à votre inventaire.', 'success')
                    else
                        LSLegacy.Events.SendToClient('notify', source, nil, 'Vous n\'avez plus de place.', 'error')
                    end
                end
        else
            LSLegacy.Events.SendToClient('notify', source, nil, 'ERREUR.', 'error')
        end
    end
end)
