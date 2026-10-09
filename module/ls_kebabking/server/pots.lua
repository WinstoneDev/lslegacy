-- ls_kebabking (serveur) — utilisation des pots de sauce.
--
-- Chaque pot (KKConfig.Pots) est un item unique (config/items.lua,
-- `unique = true`) fabriqué avec KKConfig.PotUses utilisations dans son
-- propre `data.uses` (voir server/craft.lua). Le bouton « Utiliser » de
-- l'inventaire déclenche l'event générique `useItem` du Core, qui appelle
-- le callback enregistré ici via LSLegacy.RegisterUsableItem : on ne fait
-- jamais confiance au `data` envoyé par le client, on relit l'instance
-- authoritative dans l'inventaire serveur avant de la modifier.

local Core = exports['lslegacy']

for potItem, def in pairs(KKConfig.Pots) do
    LSLegacy.RegisterUsableItem(potItem, function(_clientData, uniqueId)
        local src = source
        local player = LSLegacy.Players.Get(src)
        if not player then return end

        local inventory = player.inventory or {}
        local idx, entry
        for k, it in pairs(inventory) do
            if it.name == potItem and (uniqueId == nil or it.uniqueId == uniqueId) then
                idx, entry = k, it
                break
            end
        end
        if not entry then return end

        local uses = (entry.data and entry.data.uses) or 0
        if uses <= 0 then return end

        local result = Core:craftTransaction(src, {}, { { item = def.sauce, count = 1 } })
        if not result.ok then
            if result.reason == 'weight' then
                KK.Notify(src, "Vous ne pouvez pas porter davantage.", 'error')
            end
            return
        end

        uses = uses - 1
        if uses <= 0 then
            table.remove(inventory, idx)
            player.inventory = inventory
        else
            entry.data.uses = uses
            entry.label = ('%s (%d utilisations)'):format(KK.ItemLabel(potItem), uses)
        end

        player:MarkDirty('inventory')
        player.weight = LSLegacy.Inventory.GetInventoryWeight(player.inventory)
        LSLegacy.Events.SendToClient('lslegacy:updatePlayer', src, player)
    end)
end
