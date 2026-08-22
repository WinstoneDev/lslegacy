-- Un DataStore LSLegacy par entreprise. Réservation à la prise, restitution si annulée,
-- consommation définitive uniquement à la validation d'une intervention.

-- [src] = { item, companyId, expiresAt }
LSLegacy.Atelier.Reservations = LSLegacy.Atelier.Reservations or {}

local function StashName(companyId)
    local company = Config.Atelier.Companies[companyId]
    return company and company.stashName or nil
end

-- Chargement paresseux à dessein : LSLegacy.DataStores se charge en async au démarrage,
-- un enregistrement tenté trop tôt écraserait un stock déjà persisté (même pattern que
-- module/keyhanger/server/main.lua).
local function EnsureStash(companyId)
    local name = StashName(companyId)
    if not name then return nil end
    local ds = LSLegacy.DataStores[name]
    if not ds then
        LSLegacy.DataStore.RegisterDataStore(name, {
            inventory = {}, name = name, type = 'atelier_stock',
            money = 0, dirty = 0, maxWeight = Config.Atelier.StashMaxWeight,
        })
        ds = LSLegacy.DataStores[name]
    else
        if type(ds.inventory) ~= 'table' then ds.inventory = json.decode(ds.inventory) or {} end
        ds.maxWeight = Config.Atelier.StashMaxWeight
    end
    return ds
end

-- Les stashes atelier ne passent JAMAIS par les events génériques PutIntoTrunk/TakeFromTrunk, uniquement par ceux de ce fichier.
local prevGuard = LSLegacy.DataStoreGuard
LSLegacy.DataStoreGuard = function(src, name, action, item)
    if name and name:sub(1, 8) == 'atelier_' then return false end
    if prevGuard then return prevGuard(src, name, action, item) end
    return true
end

-- Consultation du stock

LSLegacy.Events.Register('atelier:requestStock', function()
    local src = source
    local companyId = LSLegacy.Atelier.GetCompany(src)
    if not companyId then return end

    local ds = EnsureStash(companyId)
    local stock = {}
    for item in pairs(Config.Atelier.Parts) do
        local entry = LSLegacy.DataStore.GetInventoryItem(ds, item)
        stock[item] = entry and entry.count or 0
    end
    LSLegacy.Events.SendToClient('atelier:stockResult', src, stock)
end)

-- Prise d'une pièce au dépôt (réservation)

LSLegacy.Events.Register('atelier:takePart', function(data)
    local src = source
    local ok, companyId = LSLegacy.Atelier.CanAct(src)
    if not ok then return end
    if not data or not data.item or not Config.Atelier.Parts[data.item] then return end

    if LSLegacy.Atelier.Reservations[src] then
        LSLegacy.Atelier.Notify(src, "Vous portez déjà une pièce, déposez-la avant.", 'error')
        return
    end

    local ds    = EnsureStash(companyId)
    local entry = LSLegacy.DataStore.GetInventoryItem(ds, data.item)
    if not entry or entry.count <= 0 then
        LSLegacy.Atelier.Notify(src, Lang.Atelier.depot_out_of_stock, 'error')
        return
    end

    local mecano = LSLegacy.Atelier.GetPlayer(src)
    if not LSLegacy.Inventory.CanCarryItem(mecano, data.item, 1) then
        LSLegacy.Atelier.Notify(src, 'Vous ne pouvez pas porter cette pièce (poids).', 'error')
        return
    end

    LSLegacy.DataStore.RemoveItemInInventory(ds, data.item, 1)
    LSLegacy.Inventory.AddItemInInventory(mecano, data.item, 1)

    LSLegacy.Atelier.Reservations[src] = {
        item      = data.item,
        companyId = companyId,
        expiresAt = os.time() + math.floor(Config.Atelier.PartReservationTimeoutMs / 1000),
    }

    local part = Config.Atelier.Parts[data.item]
    LSLegacy.Events.SendToClient('atelier:partTaken', src, { item = data.item, carried = part.carried })
end)

-- Restitue au stock la pièce réservée par src (annulation/expiration/drop).
-- N'est jamais appelée après consommation définitive (voir ConsumeReservation).
function LSLegacy.Atelier.ReturnReservation(src)
    local res = LSLegacy.Atelier.Reservations[src]
    if not res then return end
    LSLegacy.Atelier.Reservations[src] = nil

    local mecano = LSLegacy.Atelier.GetPlayer(src)
    if mecano then
        local owned = LSLegacy.Inventory.GetInventoryItem(mecano, res.item)
        if owned and owned.count > 0 then
            LSLegacy.Inventory.RemoveItemInInventory(mecano, res.item, 1)
        end
    end

    local ds = EnsureStash(res.companyId)
    if ds then LSLegacy.DataStore.AddItemInInventory(ds, res.item, 1) end
end

-- Consomme définitivement la réservation en cours de src (intervention
-- validée) : la pièce reste retirée du stock, plus de retour possible.
-- @return string|nil item réservé (nil si aucune réservation)
function LSLegacy.Atelier.ConsumeReservation(src)
    local res = LSLegacy.Atelier.Reservations[src]
    if not res then return nil end
    LSLegacy.Atelier.Reservations[src] = nil
    return res.item
end

function LSLegacy.Atelier.GetReservation(src)
    return LSLegacy.Atelier.Reservations[src]
end

LSLegacy.Events.Register('atelier:dropPart', function()
    local src = source
    LSLegacy.Atelier.ReturnReservation(src)
end)

-- Remplissage du stock (permission manage_stock)

LSLegacy.Events.Register('atelier:restockStock', function(data)
    local src = source
    local ok, companyId = LSLegacy.Atelier.CanAct(src, 'manage_stock')
    if not ok then return end
    if not data or not data.item or not Config.Atelier.Parts[data.item] then return end

    local amount = math.floor(tonumber(data.amount) or 0)
    if amount <= 0 then return end

    local ds = EnsureStash(companyId)
    LSLegacy.DataStore.AddItemInInventory(ds, data.item, amount)
    LSLegacy.Events.SendToClient('atelier:restockResult', src, { success = true, item = data.item, amount = amount })
end)

-- Nettoyage : expiration + déconnexion

CreateThread(function()
    while true do
        Wait(15000)
        local now = os.time()
        for src, res in pairs(LSLegacy.Atelier.Reservations) do
            if res.expiresAt and res.expiresAt <= now then
                LSLegacy.Atelier.ReturnReservation(src)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    LSLegacy.Atelier.ReturnReservation(source)
end)
