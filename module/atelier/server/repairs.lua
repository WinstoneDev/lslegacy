--  MODULE ATELIER — Réparation (mécanique, pneus, carrosserie)
--  Un seul handler générique : la logique (permission → pièce tenue →
--  consommation → réparation → facturation) est identique pour les
--  trois catégories de composants, seule la permission requise diffère.

local function RequiredPermission(category)
    if category == 'body' then return 'repair_bodywork' end
    return 'repair_mechanical' -- mécanique ET pneus (§11 du cahier des charges)
end

-- Le joueur le plus proche du véhicule (hors mécanicien) : c'est TOUJOURS
-- le serveur qui résout cette distance, jamais une valeur envoyée par le
-- client.
local function GetNearestCustomer(entity, mecanoSrc, range)
    range = range or 10.0
    local coords = GetEntityCoords(entity)
    local closestSrc, closestDist = nil, range

    for src, p in pairs(LSLegacy.ServerPlayers) do
        if src ~= mecanoSrc then
            local ped = GetPlayerPed(src)
            if DoesEntityExist(ped) then
                local dist = #(coords - GetEntityCoords(ped))
                if dist < closestDist then
                    closestDist = dist
                    closestSrc  = src
                end
            end
        end
    end
    return closestSrc
end

local function PartCoversComponent(part, componentId)
    for _, id in ipairs(part.repairs) do
        if id == componentId then return true end
    end
    return false
end

LSLegacy.RegisterServerEvent('atelier:repairComponent', function(data)
    local src = source
    if not data or not data.vehNet or not data.componentId then return end

    local category, def = LSLegacy.Atelier.FindComponent(data.componentId)
    if not category then return end

    local ok, companyId = LSLegacy.Atelier.CanAct(src, RequiredPermission(category))
    if not ok then return end

    local entity = NetworkGetEntityFromNetworkId(data.vehNet)
    if not DoesEntityExist(entity) then return end
    local plate = GetVehicleNumberPlateText(entity):upper()

    local res = LSLegacy.Atelier.GetReservation(src)
    if not res then
        LSLegacy.Atelier.Notify(src, "Vous ne portez aucune pièce adaptée.", 'error')
        return
    end
    local part = Config.Atelier.Parts[res.item]
    if not part or not PartCoversComponent(part, data.componentId) then
        LSLegacy.Atelier.Notify(src, "Cette pièce ne correspond pas à ce composant.", 'error')
        return
    end

    LSLegacy.Atelier.GetVehicleState(plate, function(state)
        local current = state.components[category][data.componentId]
        if current >= 100 then
            LSLegacy.Atelier.Notify(src, Lang.Atelier.repair_not_needed, 'warning')
            return
        end

        local customerSrc = GetNearestCustomer(entity, src)
        if not customerSrc then
            LSLegacy.Atelier.Notify(src, Lang.Atelier.no_client_vehicle, 'error')
            return
        end

        local item = LSLegacy.Atelier.ConsumeReservation(src)
        local mecano = LSLegacy.Atelier.GetPlayer(src)
        LSLegacy.Inventory.RemoveItemInInventory(mecano, item, 1)

        LSLegacy.Atelier.RepairComponent(plate, data.vehNet, data.componentId, function(success)
            if not success then
                LSLegacy.SendEventToClient('atelier:repairResult', src, { success = false })
                return
            end

            local price = part.price + (Config.Atelier.LaborPrices[category] or 0)
            LSLegacy.Atelier.AddInvoiceLine(plate, companyId, customerSrc,
                'Réparation — ' .. def.label, price, item)

            LSLegacy.SendEventToClient('atelier:partInstalled', src)
            LSLegacy.SendEventToClient('atelier:repairResult', src, { success = true, componentId = data.componentId })
            LSLegacy.Atelier.Notify(customerSrc, string.format('%s réparé(e), en attente de facturation.', def.label), 'info')
        end)
    end)
end)
