--  MODULE MÉCANICIEN — Achat et pose de pièces détachées (serveur)
--  Les pièces viennent du STOCK DU GARAGE (jamais du porte-monnaie du
--  mécanicien). Seul le client est facturé, à la pose / réparation.

local Stock = {}   -- { [item] = quantity } — chargé depuis mecanicien_stock

local function GetPlayer(src)   return LSLegacy.Players.Get(src) end
local function IsMecanicien(src) return LSLegacy.Jobs.Is(GetPlayer(src), Config.Mecanicien.Job) end
local function GetGrade(src)     return GetPlayer(src) and tonumber(GetPlayer(src).job_grade) or 0 end

local function Notify(src, msg, t)
    TriggerClientEvent(Config.Mecanicien.NotifyEvent, src, 'Mécanicien', msg, 5000, t or 'info')
end

-- Le client facturé est le joueur le plus proche de l'entité (hors mécanicien)
local function GetClosestPlayerToEntity(entity, mecanoSrc, range)
    range = range or 10.0
    local coords  = GetEntityCoords(entity)
    local closest, closestDist = nil, range

    for _, p in pairs(LSLegacy.Players.GetAll()) do
        if p.source and p.source ~= mecanoSrc then
            local ped = GetPlayerPed(p.source)
            if DoesEntityExist(ped) then
                local dist = #(coords - GetEntityCoords(ped))
                if dist < closestDist then
                    closestDist = dist
                    closest     = p
                end
            end
        end
    end
    return closest
end

-- Stock du garage (table SQL)

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mecanicien_stock (
        item      VARCHAR(60) PRIMARY KEY,
        quantity  INT NOT NULL DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.fetchAll('SELECT item, quantity FROM mecanicien_stock', {}, function(rows)
    for _, row in ipairs(rows or {}) do
        Stock[row.item] = row.quantity
    end
    -- Initialise les pièces jamais vues avec un stock de départ
    for itemName in pairs(Config.Mecanicien.Parts) do
        if Stock[itemName] == nil then
            Stock[itemName] = Config.Mecanicien.DefaultStock or 10
            MySQL.Async.execute(
                'INSERT INTO mecanicien_stock (item, quantity) VALUES (@i, @q) ON DUPLICATE KEY UPDATE quantity=quantity',
                { ['@i'] = itemName, ['@q'] = Stock[itemName] }
            )
        end
    end
end)

local function SaveStock(item)
    MySQL.Async.execute(
        'INSERT INTO mecanicien_stock (item, quantity) VALUES (@i, @q) ON DUPLICATE KEY UPDATE quantity=@q',
        { ['@i'] = item, ['@q'] = Stock[item] or 0 }
    )
end

LSLegacy.RegisterServerEvent('mecanicien:requestStock', function()
    local src = source
    if not IsMecanicien(src) then return end
    TriggerClientEvent('mecanicien:stockResult', src, Stock)
end)

--  PRISE D'UNE PIÈCE AU DÉPÔT (depuis le stock du garage — gratuit)

LSLegacy.RegisterServerEvent('mecanicien:buyPart', function(data)
    local src = source
    if not IsMecanicien(src) or not IsMecanicienOnDuty(src) then return end
    if not data or not data.item then return end

    local part = Config.Mecanicien.Parts[data.item]
    if not part then return end

    if (Stock[data.item] or 0) <= 0 then
        Notify(src, Lang.Mecanicien.depot_out_of_stock, 'error')
        return
    end

    Stock[data.item] = Stock[data.item] - 1
    SaveStock(data.item)

    local mecano = GetPlayer(src)
    LSLegacy.Inventory.AddItemInInventory(mecano, data.item, 1)

    TriggerClientEvent('mecanicien:partBought', src, { item = data.item, label = part.label })
end)

--  REMPLISSAGE MANUEL DU STOCK (Chef d'Atelier uniquement)
--  Le patron achète chez le grossiste IRL/RP (non simulé ici) puis
--  rentre lui-même la quantité reçue, pièce par pièce.

LSLegacy.RegisterServerEvent('mecanicien:restockDepot', function(data)
    local src = source
    if not IsMecanicien(src) or not IsMecanicienOnDuty(src) then return end
    if GetGrade(src) < 3 then
        Notify(src, Lang.Mecanicien.grade_required, 'error')
        return
    end
    if not data or not data.item or not Config.Mecanicien.Parts[data.item] then return end

    local amount = math.floor(tonumber(data.amount) or 0)
    if amount <= 0 then return end

    Stock[data.item] = (Stock[data.item] or 0) + amount
    SaveStock(data.item)

    TriggerClientEvent('mecanicien:restockResult', src, { success = true, item = data.item, amount = amount })
end)

--  POSE D'UNE PIÈCE PORTÉE EN MAIN

LSLegacy.RegisterServerEvent('mecanicien:installPart', function(data)
    local src = source
    if not IsMecanicien(src) or not IsMecanicienOnDuty(src) then return end
    if not data or not data.vehNet or not data.item then return end

    local part = Config.Mecanicien.Parts[data.item]
    if not part or not part.carried then return end

    local mecano = GetPlayer(src)
    local owned  = LSLegacy.Inventory.GetInventoryItem(mecano, data.item)
    if not owned or owned.count <= 0 then
        TriggerClientEvent('mecanicien:installResult', src, { success = false })
        return
    end

    local veh = NetworkGetEntityFromNetworkId(data.vehNet)
    if not DoesEntityExist(veh) then return end

    LSLegacy.Inventory.RemoveItemInInventory(mecano, data.item, 1)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)

    -- Facture le joueur le plus proche du véhicule (pièce + main d'œuvre — jamais le mécanicien)
    -- La pose est déjà appliquée à ce stade (comportement existant, inchangé) :
    -- la facturation reste "best effort", espèces ou TPE au choix du client.
    local customer = GetClosestPlayerToEntity(veh, src)
    if customer then
        local total = part.price + (Config.Mecanicien.LaborPrices.body or 0)
        LSLegacy.Bank.OpenPaymentMenu(customer.source, 'Réparation carrosserie', total, nil)
    end

    TriggerClientEvent('mecanicien:installResult', src, { success = true })
end)
