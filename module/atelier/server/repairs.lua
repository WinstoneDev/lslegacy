-- Un seul handler générique : la logique est identique pour les trois catégories de composants, seule la permission diffère.

local function RequiredPermission(category)
    if category == 'body' then return 'repair_bodywork' end
    return 'repair_mechanical' -- mécanique ET pneus (§11 du cahier des charges)
end

local function PartCoversComponent(part, componentId)
    for _, id in ipairs(part.repairs) do
        if id == componentId then return true end
    end
    return false
end

-- Exposée pour module/mdt/server/parts.lua : permission requise pour commander/consommer
-- cette pièce, dérivée de son premier composant couvert (toujours homogène par pièce,
-- cf. Config.Atelier.Parts -> une pièce ne couvre jamais deux catégories différentes).
function LSLegacy.Atelier.RequiredPermissionForPart(part)
    local firstComponent = part.repairs and part.repairs[1]
    if not firstComponent then return nil end
    local category = LSLegacy.Atelier.FindComponent(firstComponent)
    if not category then return nil end
    return RequiredPermission(category)
end

-- La pièce à consommer n'est plus une "réservation" mais un item normal :
-- on cherche dans l'inventaire réel du mécano lequel couvre ce composant
-- (le dépôt est un vrai second inventaire depuis client/inventory.lua).
local function FindOwnedPart(mecano, componentId)
    for itemName, part in pairs(Config.Atelier.Parts) do
        if PartCoversComponent(part, componentId) then
            local owned = LSLegacy.Inventory.GetInventoryItem(mecano, itemName)
            if owned and owned.count > 0 then return itemName, part end
        end
    end
    return nil, nil
end

LSLegacy.Events.Register('atelier:repairComponent', function(data)
    local src = source
    if not data or not data.vehNet or not data.componentId then return end

    local category, def = LSLegacy.Atelier.FindComponent(data.componentId)
    if not category then return end

    local ok, companyId = LSLegacy.Atelier.CanAct(src, RequiredPermission(category))
    if not ok then return end

    local entity = NetworkGetEntityFromNetworkId(data.vehNet)
    if not DoesEntityExist(entity) then return end
    local plate = GetVehicleNumberPlateText(entity):upper()

    local mecano = LSLegacy.Atelier.GetPlayer(src)
    local item, part = FindOwnedPart(mecano, data.componentId)
    if not item then
        LSLegacy.Atelier.Notify(src, "Vous ne portez aucune pièce adaptée.", 'error')
        return
    end

    LSLegacy.Atelier.GetVehicleState(plate, function(state)
        local current = state.components[category][data.componentId]
        if current >= 100 then
            LSLegacy.Atelier.Notify(src, Lang.Atelier.repair_not_needed, 'warning')
            return
        end

        -- Re-vérifié ici (l'appel ci-dessus est async) : la pièce peut avoir
        -- été consommée/donnée entre-temps.
        local owned = LSLegacy.Inventory.GetInventoryItem(mecano, item)
        if not owned or owned.count <= 0 then
            LSLegacy.Atelier.Notify(src, "Vous ne portez plus cette pièce.", 'error')
            return
        end
        LSLegacy.Inventory.RemoveItemInInventory(mecano, item, 1)

        LSLegacy.Atelier.RepairComponent(plate, data.vehNet, data.componentId, function(success, zoneFixed)
            if not success then
                LSLegacy.Events.SendToClient('atelier:repairResult', src, { success = false })
                return
            end

            local price = part.price + (Config.Atelier.LaborPrices[category] or 0)
            LSLegacy.Atelier.AddInvoiceLine(plate, companyId, 'Réparation — ' .. def.label, price, item)

            LSLegacy.Events.SendToClient('atelier:partInstalled', src)
            LSLegacy.Events.SendToClient('atelier:repairResult', src, {
                success = true, componentId = data.componentId, vehNet = data.vehNet, zoneFixed = zoneFixed,
            })

            -- Le client n'a plus besoin d'être présent pour que le mécano travaille ;
            -- on le prévient seulement s'il se trouve là, sans bloquer la réparation.
            local nearbyCustomer = LSLegacy.Atelier.GetNearestCustomer(entity, src)
            if nearbyCustomer then
                LSLegacy.Atelier.Notify(nearbyCustomer, string.format('%s réparé(e), en attente de facturation.', def.label), 'info')
            end
        end)
    end)
end)
