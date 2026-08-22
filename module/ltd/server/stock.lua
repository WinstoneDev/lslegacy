-- Stock et alarme indépendants par magasin (storeId).

local ShelfStock   = {}  -- { [storeId] = { [item] = quantity } }
local ReserveStock = {}  -- { [storeId] = { [item] = quantity } }
local lastAlarm    = {}  -- { [storeId] = os.time() }

local function GetPlayer(src)   return LSLegacy.Players.Get(src) end
local function IsEmployee(src)  return GetPlayer(src) and GetPlayer(src).job == Config.LTD.Job end
local function GetGrade(src)    return GetPlayer(src) and tonumber(GetPlayer(src).job_grade) or 0 end

local function Notify(src, msg, t)
    TriggerClientEvent(Config.LTD.NotifyEvent, src, 'LTD', msg, 5000, t or 'info')
end

local function GetItemConfig(itemName)
    for _, entry in ipairs(Config.LTD.Items) do
        if entry.item == itemName then return entry end
    end
    return nil
end

local function IsValidStore(storeId)
    for _, s in ipairs(Config.LTD.Stores) do
        if s.id == storeId then return true end
    end
    return false
end

local function GetStoreCoords(storeId)
    for _, s in ipairs(Config.LTD.Stores) do
        if s.id == storeId then return s.headquarters end
    end
    return nil
end

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS ltd_stock (
        store_id    VARCHAR(60) NOT NULL,
        item        VARCHAR(60) NOT NULL,
        shelf_qty   INT NOT NULL DEFAULT 0,
        reserve_qty INT NOT NULL DEFAULT 0,
        PRIMARY KEY (store_id, item)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.fetchAll('SELECT store_id, item, shelf_qty, reserve_qty FROM ltd_stock', {}, function(rows)
    for _, row in ipairs(rows or {}) do
        ShelfStock[row.store_id]   = ShelfStock[row.store_id] or {}
        ReserveStock[row.store_id] = ReserveStock[row.store_id] or {}
        ShelfStock[row.store_id][row.item]   = row.shelf_qty
        ReserveStock[row.store_id][row.item] = row.reserve_qty
    end

    for _, store in ipairs(Config.LTD.Stores) do
        ShelfStock[store.id]   = ShelfStock[store.id] or {}
        ReserveStock[store.id] = ReserveStock[store.id] or {}
        for _, entry in ipairs(Config.LTD.Items) do
            if ShelfStock[store.id][entry.item] == nil then
                ShelfStock[store.id][entry.item]   = Config.LTD.DefaultShelfStock or 10
                ReserveStock[store.id][entry.item] = Config.LTD.DefaultReserveStock or 0
                MySQL.Async.execute(
                    'INSERT INTO ltd_stock (store_id, item, shelf_qty, reserve_qty) VALUES (@st, @i, @s, @r) ' ..
                    'ON DUPLICATE KEY UPDATE shelf_qty=shelf_qty',
                    { ['@st'] = store.id, ['@i'] = entry.item, ['@s'] = ShelfStock[store.id][entry.item], ['@r'] = ReserveStock[store.id][entry.item] }
                )
            end
        end
    end
end)

local function SaveStock(storeId, item)
    MySQL.Async.execute(
        'INSERT INTO ltd_stock (store_id, item, shelf_qty, reserve_qty) VALUES (@st, @i, @s, @r) ' ..
        'ON DUPLICATE KEY UPDATE shelf_qty=@s, reserve_qty=@r',
        { ['@st'] = storeId, ['@i'] = item, ['@s'] = ShelfStock[storeId][item] or 0, ['@r'] = ReserveStock[storeId][item] or 0 }
    )
end

LSLegacy.RegisterServerEvent('ltd:requestShelfStock', function(data)
    local src = source
    if not data or not IsValidStore(data.storeId) then return end
    if not IsEmployee(src) or not IsLtdOnDutyAt(src, data.storeId) then return end
    TriggerClientEvent('ltd:shelfStockResult', src, ShelfStock[data.storeId])
end)

LSLegacy.RegisterServerEvent('ltd:requestReserveStock', function(data)
    local src = source
    if not data or not IsValidStore(data.storeId) then return end
    if not IsEmployee(src) or not IsLtdOnDutyAt(src, data.storeId) then return end
    TriggerClientEvent('ltd:reserveStockResult', src, ReserveStock[data.storeId])
end)

-- token -> { employeeSrc, storeId, item, customerSrc }
local PendingSales = {}

LSLegacy.Bank.RegisterPaymentResultHandler('ltd', function(token, success)
    local pending = PendingSales[token]
    if not pending then return end
    PendingSales[token] = nil

    if not success then
        TriggerClientEvent('ltd:sellResult', pending.employeeSrc, { success = false, reason = 'payment_failed' })
        return
    end

    local entry = GetItemConfig(pending.item)
    local stock = ShelfStock[pending.storeId]
    if not entry or not stock or (stock[pending.item] or 0) <= 0 then
        TriggerClientEvent('ltd:sellResult', pending.employeeSrc, { success = false, reason = 'no_stock' })
        return
    end

    stock[pending.item] = stock[pending.item] - 1
    SaveStock(pending.storeId, pending.item)

    local customer = GetPlayer(pending.customerSrc)
    if customer then
        LSLegacy.Inventory.AddItemInInventory(customer, pending.item, 1)
    end

    TriggerClientEvent('ltd:sellResult', pending.employeeSrc, { success = true, label = entry.label, price = entry.price })
    TriggerClientEvent('ltd:purchaseNotice', pending.customerSrc, { label = entry.label, price = entry.price })
end)

LSLegacy.RegisterServerEvent('ltd:sellItem', function(data)
    local src = source
    if not data or not IsValidStore(data.storeId) then return end
    if not IsEmployee(src) or not IsLtdOnDutyAt(src, data.storeId) then return end
    if not data.item or not data.customer then return end

    local entry = GetItemConfig(data.item)
    if not entry then return end

    local stock = ShelfStock[data.storeId]
    if (stock[data.item] or 0) <= 0 then
        TriggerClientEvent('ltd:sellResult', src, { success = false, reason = 'no_stock' })
        return
    end

    local customer = GetPlayer(data.customer)
    if not customer then
        TriggerClientEvent('ltd:sellResult', src, { success = false, reason = 'no_money' })
        return
    end

    local token = ('ltd_%d_%d'):format(src, math.random(100000, 999999))
    PendingSales[token] = { employeeSrc = src, storeId = data.storeId, item = data.item, customerSrc = data.customer }
    Citizen.SetTimeout(120000, function() PendingSales[token] = nil end)
    LSLegacy.Bank.OpenPaymentMenu(data.customer, 'Achat - ' .. entry.label, entry.price, { meta = { type = 'ltd', refId = token } })
end)

LSLegacy.RegisterServerEvent('ltd:restockShelf', function(data)
    local src = source
    if not data or not IsValidStore(data.storeId) then return end
    if not IsEmployee(src) or not IsLtdOnDutyAt(src, data.storeId) then return end
    if not data.item then return end

    local entry = GetItemConfig(data.item)
    if not entry then return end

    local reserve = ReserveStock[data.storeId]
    local shelf    = ShelfStock[data.storeId]
    local amount   = Config.LTD.RestockAmount or 5

    if (reserve[data.item] or 0) < amount then
        TriggerClientEvent('ltd:restockResult', src, { success = false })
        return
    end

    reserve[data.item] = reserve[data.item] - amount
    shelf[data.item]   = (shelf[data.item] or 0) + amount
    SaveStock(data.storeId, data.item)

    TriggerClientEvent('ltd:restockResult', src, { success = true, label = entry.label, amount = amount })
end)

LSLegacy.RegisterServerEvent('ltd:fillReserve', function(data)
    local src = source
    if not data or not IsValidStore(data.storeId) then return end
    if not IsEmployee(src) or not IsLtdOnDutyAt(src, data.storeId) then return end
    if GetGrade(src) < 3 then
        Notify(src, Lang.LTD.grade_required, 'error')
        return
    end
    if not data.item then return end

    local entry = GetItemConfig(data.item)
    if not entry then return end

    local amount = math.floor(tonumber(data.amount) or 0)
    if amount <= 0 then return end

    local reserve = ReserveStock[data.storeId]
    reserve[data.item] = (reserve[data.item] or 0) + amount
    SaveStock(data.storeId, data.item)

    TriggerClientEvent('ltd:fillResult', src, { success = true, label = entry.label, amount = amount })
end)

local function TriggerAlarm(storeId)
    local now = os.time()
    if (now - (lastAlarm[storeId] or 0)) < (Config.LTD.Actions.cooldowns.alarm or 30000) / 1000 then return end
    lastAlarm[storeId] = now

    local coords = GetStoreCoords(storeId)
    if not coords then return end

    -- Notifie uniquement les LTD en service SUR CE MAGASIN
    for src in pairs(GetLtdAgentsAt(storeId)) do
        TriggerClientEvent('ltd:theftAlertEmployee', src)
    end

    -- Notifie les policiers en service (module police, si présent)
    if Config.MDT and Config.MDT.ActiveDepartments then
        for _, dep in ipairs(Config.MDT.ActiveDepartments) do
            if dep == 'police' and GetPoliceOfficers then
                for src in pairs(GetPoliceOfficers()) do
                    TriggerClientEvent('ltd:alarmReceived', src, { coords = coords })
                end
            end
        end
    end
end

LSLegacy.RegisterServerEvent('ltd:triggerAlarm', function(data)
    local src = source
    if not data or not IsValidStore(data.storeId) then return end
    if not IsEmployee(src) or not IsLtdOnDutyAt(src, data.storeId) then return end
    TriggerAlarm(data.storeId)
end)

LSLegacy.RegisterServerEvent('ltd:stealItem', function(data)
    local src = source
    if not data or not IsValidStore(data.storeId) then return end
    if IsLtdOnDutyAt(src, data.storeId) then return end

    local stock      = ShelfStock[data.storeId]
    local candidates = {}
    for _, entry in ipairs(Config.LTD.Items) do
        if (stock[entry.item] or 0) > 0 then
            candidates[#candidates + 1] = entry
        end
    end
    if #candidates == 0 then
        TriggerClientEvent('ltd:theftResult', src, { success = false })
        return
    end

    local picked = candidates[math.random(#candidates)]
    stock[picked.item] = stock[picked.item] - 1
    SaveStock(data.storeId, picked.item)

    local player = GetPlayer(src)
    if player then
        LSLegacy.Inventory.AddItemInInventory(player, picked.item, 1)
    end

    TriggerClientEvent('ltd:theftResult', src, { success = true, label = picked.label })
    TriggerAlarm(data.storeId)
end)
