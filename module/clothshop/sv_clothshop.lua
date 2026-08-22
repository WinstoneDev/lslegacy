-- ════════════════════════════════════════════════
--  LSLegacy – ClothShop Server
-- ════════════════════════════════════════════════

LSLegacy.Security.RegisterRateLimit('AddClothesInInventory', 20)
LSLegacy.Security.RegisterRateLimit('clothshop:createOutfit', 20)
LSLegacy.Security.RegisterRateLimit('clothshop:splitOutfit', 20)
LSLegacy.Security.RegisterRateLimit('clothshop:modifyOutfit', 20)
LSLegacy.Security.RegisterRateLimit('inventory:updateOutfitFromInventory', 20)

-- ── Helper: remove inventory item by uniqueId ─────
local function RemoveItemByUniqueId(player, uniqueId)
    if not player or not uniqueId then return end
    local inventory = player.inventory
    for k, v in pairs(inventory) do
        if tostring(v.uniqueId) == tostring(uniqueId) then
            table.remove(inventory, k)
            break
        end
    end
    player.inventory = inventory
    player.weight    = LSLegacy.Inventory.GetInventoryWeight(player.inventory)
    LSLegacy.SendEventToClient('UpdatePlayer', player.source, player)
end

-- ── Add single clothing item after purchase ───────
LSLegacy.RegisterServerEvent('AddClothesInInventory', function(item, label, data)
    local player = LSLegacy.Players.Get(source)
    LSLegacy.Inventory.AddItemInInventory(player, item, 1, label, nil, data)
end)

-- ── Create outfit from individual clothing items ──
LSLegacy.RegisterServerEvent('clothshop:createOutfit', function(name, itemsData, itemIds)
    local player = LSLegacy.Players.Get(source)
    if not player then return end

    -- Remove each consumed clothing item from inventory
    for _, entry in ipairs(itemIds or {}) do
        RemoveItemByUniqueId(player, entry.uniqueId)
    end

    -- Build outfit data: { tshirt: {drawable, texture}, ... }
    local outfitData = {}
    for slot, vals in pairs(itemsData or {}) do
        outfitData[slot] = { vals.drawable or 0, vals.texture or 0 }
    end

    -- Give outfit item with all clothing data embedded
    LSLegacy.Inventory.AddItemInInventory(player, 'outfit', 1, name, nil, outfitData)

    LSLegacy.SendEventToClient('clothshop:outfitCreated', source)
end)

-- ── Split outfit back into individual items ───────
LSLegacy.RegisterServerEvent('clothshop:splitOutfit', function(outfitItem)
    local player = LSLegacy.Players.Get(source)
    if not player then return end

    -- Remove the outfit item
    if outfitItem and outfitItem.uniqueId then
        RemoveItemByUniqueId(player, outfitItem.uniqueId)
    end

    -- Return each clothing item
    if outfitItem and outfitItem.data then
        local clothLabels = {
            tshirt='T-shirt', torso='Torse', arms='Bras', pants='Pantalon',
            shoes='Chaussures', helmet='Chapeau', glasses='Lunettes', chain='Chaîne',
            bags='Sac', ears='Oreillette', watches='Montre', bracelet='Bracelet',
            mask='Masque', decals='Badge', bproof='Gilet pare-balles'
        }
        for slot, vals in pairs(outfitItem.data) do
            local drawable = type(vals) == 'table' and (vals[1] or vals.drawable or 0) or 0
            local texture  = type(vals) == 'table' and (vals[2] or vals.texture  or 0) or 0
            local label    = (clothLabels[slot] or slot) .. ' #' .. drawable
            LSLegacy.Inventory.AddItemInInventory(player, slot, 1, label, nil, {drawable, texture})
        end
    end

    LSLegacy.SendEventToClient('clothshop:outfitSplit', source)
end)

-- ── Modify an existing outfit ─────────────────────
LSLegacy.RegisterServerEvent('clothshop:modifyOutfit', function(modData)
    local player = LSLegacy.Players.Get(source)
    if not player then return end

    -- Remove the old outfit item
    if modData.uniqueId then
        RemoveItemByUniqueId(player, modData.uniqueId)
    end

    -- Remove consumed individual clothing items
    for _, entry in ipairs(modData.itemIds or {}) do
        RemoveItemByUniqueId(player, entry.uniqueId)
    end

    -- Build new outfit data
    local outfitData = {}
    for slot, vals in pairs(modData.items or {}) do
        outfitData[slot] = { vals.drawable or 0, vals.texture or 0 }
    end

    -- Give back removed slots as individual items
    local clothLabels = {
        tshirt='T-shirt', torso='Torse', arms='Bras', pants='Pantalon',
        shoes='Chaussures', helmet='Chapeau', glasses='Lunettes', chain='Chaîne',
        bags='Sac', ears='Oreillette', watches='Montre', bracelet='Bracelet',
        mask='Masque', decals='Badge', bproof='Gilet pare-balles'
    }
    for slot, vals in pairs(modData.removedSlots or {}) do
        local drawable = type(vals) == 'table' and (vals[1] or vals.drawable or 0) or 0
        local texture  = type(vals) == 'table' and (vals[2] or vals.texture  or 0) or 0
        local label    = (clothLabels[slot] or slot) .. ' #' .. drawable
        LSLegacy.Inventory.AddItemInInventory(player, slot, 1, label, nil, {drawable, texture})
    end

    -- Give updated outfit item
    local name = modData.newName or 'Tenue'
    LSLegacy.Inventory.AddItemInInventory(player, 'outfit', 1, name, nil, outfitData)

    LSLegacy.SendEventToClient('clothshop:outfitModified', source)
end)

-- ── Modifier une tenue depuis l'inventaire (drag & drop) ──
LSLegacy.RegisterServerEvent('inventory:updateOutfitFromInventory', function(updateData)
    local player = LSLegacy.Players.Get(source)
    if not player or not updateData.outfitUniqueId then return end

    local clothLabels = {
        tshirt='T-shirt', torso='Torse', arms='Bras', pants='Pantalon',
        shoes='Chaussures', helmet='Chapeau', glasses='Lunettes', chain='Chaîne',
        bags='Sac', ears='Oreillette', watches='Montre', bracelet='Bracelet',
        mask='Masque', decals='Badge', bproof='Gilet pare-balles'
    }

    -- Mettre à jour les données de l'item outfit en place
    local inventory = player.inventory
    for k, v in pairs(inventory) do
        if v.name == 'outfit' and tostring(v.uniqueId) == tostring(updateData.outfitUniqueId) then
            inventory[k].data = updateData.newSlots or {}
            break
        end
    end
    player.inventory = inventory

    -- Retirer les vêtements individuels consommés (ajoutés à la tenue)
    for _, entry in ipairs(updateData.consumedItems or {}) do
        RemoveItemByUniqueId(player, entry.uniqueId)
    end

    -- Redonner comme items individuels les slots retirés de la tenue
    for slot, vals in pairs(updateData.removedSlots or {}) do
        local drawable = type(vals) == 'table' and (vals[1] or vals.drawable or 0) or 0
        local texture  = type(vals) == 'table' and (vals[2] or vals.texture  or 0) or 0
        local label    = (clothLabels[slot] or slot) .. ' #' .. drawable
        LSLegacy.Inventory.AddItemInInventory(player, slot, 1, label, nil, {drawable, texture})
    end

    -- Forcer la synchronisation si aucune opération d'ajout/suppression n'a déclenché UpdatePlayer
    if (not updateData.consumedItems or #updateData.consumedItems == 0) and
       (not updateData.removedSlots  or not next(updateData.removedSlots)) then
        player.weight = LSLegacy.Inventory.GetInventoryWeight(player.inventory)
        LSLegacy.SendEventToClient('UpdatePlayer', player.source, player)
    end
end)

-- ── Register shop zones ───────────────────────────
local number = 0

for k, v in pairs(Config.zoneClothShop) do
    for i = 1, #v, 1 do
        number = number + 1
        LSLegacy.RegisterZone('Magasin de vêtements n°'..number, v[i].coords, function(source)
            LSLegacy.SendEventToClient('openClothMenu', source, "Magasin de vêtements n°"..number, v.Type)
        end, 10.0, true, {
            markerType  = 25,
            markerColor = {r = 0, g = 125, b = 255, a = 255},
            markerSize  = {x = 1.0, y = 1.0, z = 1.0},
            markerPos   = v[i].coords
        }, true, {
            blipSprite = v.BlipId,
            blipColor  = v.BlipColor,
            blipScale  = v.BlipScale,
            blipName   = k
        }, true, {
            drawNotificationDistance = 2.5,
            notificationMessage      = "Appuyez sur ~INPUT_CONTEXT~ pour ouvrir le magasin de vêtements",
        }, false, {})
    end
end
