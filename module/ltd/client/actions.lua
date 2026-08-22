-- Caisse / Réassort / Alarme / Vol (client). Chaque magasin (storeId) a son propre stock, totalement indépendant.

local cooldowns = {}

local function Notify(msg, type)
    TriggerEvent('notify', 'LTD', msg, type or 'info', 5000)
end

local function HasCooldown(action)
    if not cooldowns[action] then return false end
    return (GetGameTimer() - cooldowns[action]) < (Config.LTD.Actions.cooldowns[action] or 3000)
end

local function SetCooldown(action)
    cooldowns[action] = GetGameTimer()
end

local function GetClosestPlayerServerId(coords, range)
    range = range or Config.LTD.Actions.interactionRange
    local closest, closestDist = nil, range

    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local dist = #(coords - GetEntityCoords(GetPlayerPed(pid)))
            if dist < closestDist then
                closestDist = dist
                closest      = pid
            end
        end
    end
    if not closest then return nil end
    return GetPlayerServerId(closest)
end

local function OpenRegister(store)
    if not LTD.IsOnDuty() or LTD.GetStoreId() ~= store.id then
        Notify(Lang.LTD.not_employee, 'error') return
    end
    if HasCooldown('sell') then Notify(Lang.LTD.action_cooldown, 'error') return end

    local customerSrc = GetClosestPlayerServerId(store.registerCoords)
    if not customerSrc then Notify(Lang.LTD.sell_no_client, 'error') return end

    LTD.PendingCustomer = customerSrc
    LTD.PendingStore     = store.id
    LSLegacy.Events.SendToServer('ltd:requestShelfStock', { storeId = store.id })
end

LSLegacy.Events.Register('ltd:shelfStockResult', function(stock)
    stock = stock or {}
    local customerSrc = LTD.PendingCustomer
    local storeId      = LTD.PendingStore
    if not customerSrc or not storeId then return end

    local options = {}
    for _, entry in ipairs(Config.LTD.Items) do
        local qty       = stock[entry.item] or 0
        local available = qty > 0
        options[#options + 1] = {
            title = entry.label .. ' — ' .. entry.price .. '$' .. (available and (' (x' .. qty .. ')') or ''),
            description = available and 'Vendre au client le plus proche' or Lang.LTD.sell_no_stock,
            icon = 'fa-solid fa-cash-register',
            disabled = not available,
            onSelect = function()
                SetCooldown('sell')
                LSLegacy.Events.SendToServer('ltd:sellItem', { storeId = storeId, item = entry.item, customer = customerSrc })
            end,
        }
    end

    lib.registerContext({ id = 'ltd_register', title = Lang.LTD.register_title, options = options })
    lib.showContext('ltd_register')
end)

LSLegacy.Events.Register('ltd:sellResult', function(data)
    if not data then return end
    if data.success then
        Notify(string.format(Lang.LTD.sell_done, data.label, data.price), 'success')
    else
        Notify(data.reason == 'no_money' and Lang.LTD.sell_no_money or Lang.LTD.sell_no_stock, 'error')
    end
end)

LSLegacy.Events.Register('ltd:purchaseNotice', function(data)
    if not data then return end
    Notify(string.format(Lang.LTD.sold_to_you, data.label, data.price), 'info')
end)

local function OpenStorage(store)
    if not LTD.IsOnDuty() or LTD.GetStoreId() ~= store.id then
        Notify(Lang.LTD.not_employee, 'error') return
    end
    LTD.PendingStore = store.id
    LSLegacy.Events.SendToServer('ltd:requestReserveStock', { storeId = store.id })
end

LSLegacy.Events.Register('ltd:reserveStockResult', function(stock)
    stock = stock or {}
    local storeId = LTD.PendingStore
    if not storeId then return end
    local options = {}

    for _, entry in ipairs(Config.LTD.Items) do
        options[#options + 1] = {
            title = entry.label .. ' — Réserve : x' .. (stock[entry.item] or 0),
            description = 'Réapprovisionner le rayon (+' .. Config.LTD.RestockAmount .. ')',
            icon = 'fa-solid fa-boxes-stacked',
            disabled = (stock[entry.item] or 0) <= 0,
            onSelect = function()
                if HasCooldown('restock') then Notify(Lang.LTD.action_cooldown, 'error') return end
                SetCooldown('restock')
                LSLegacy.Events.SendToServer('ltd:restockShelf', { storeId = storeId, item = entry.item })
            end,
        }
    end

    if LTD.GetGrade() >= 3 then
        options[#options + 1] = {
            title = Lang.LTD.fill_title,
            description = "Responsable — après achat chez le grossiste",
            icon = 'fa-solid fa-truck-ramp-box',
            onSelect = function()
                local fillOptions = {}
                for _, entry in ipairs(Config.LTD.Items) do
                    fillOptions[#fillOptions + 1] = {
                        title = entry.label,
                        description = 'Ajouter une quantité à la réserve',
                        icon = 'fa-solid fa-box-open',
                        onSelect = function()
                            local qtyStr = LSLegacy.KeyboardInput('Quantité à ajouter à la réserve', 4)
                            local qty    = tonumber(qtyStr)
                            if not qty or qty <= 0 then return end
                            LSLegacy.Events.SendToServer('ltd:fillReserve', { storeId = storeId, item = entry.item, amount = math.floor(qty) })
                        end,
                    }
                end
                lib.registerContext({ id = 'ltd_fill', title = Lang.LTD.fill_title, menu = 'ltd_storage', options = fillOptions })
                lib.showContext('ltd_fill')
            end,
        }
    end

    lib.registerContext({ id = 'ltd_storage', title = Lang.LTD.restock_title, options = options })
    lib.showContext('ltd_storage')
end)

LSLegacy.Events.Register('ltd:restockResult', function(data)
    if not data then return end
    if data.success then
        Notify(string.format(Lang.LTD.restock_done, data.label, data.amount), 'success')
    else
        Notify(Lang.LTD.restock_empty_reserve, 'error')
    end
end)

LSLegacy.Events.Register('ltd:fillResult', function(data)
    if not data then return end
    if data.success then
        Notify(string.format(Lang.LTD.fill_added, data.amount, data.label), 'success')
    end
end)

RegisterCommand('ltd_alarm', function()
    if not LTD.IsOnDuty() then return end
    if HasCooldown('alarm') then Notify(Lang.LTD.action_cooldown, 'error') return end
    SetCooldown('alarm')
    LSLegacy.Events.SendToServer('ltd:triggerAlarm', { storeId = LTD.GetStoreId() })
    Notify(Lang.LTD.alarm_triggered, 'info')
end, false)

RegisterKeyMapping('ltd_alarm', 'Déclencher alarme silencieuse (LTD)', 'keyboard', 'F11')

LSLegacy.Events.Register('ltd:alarmReceived', function(data)
    if not data or not data.coords then return end
    Notify(Lang.LTD.alarm_received, 'error')
    SetNewWaypoint(data.coords.x, data.coords.y)
end)

-- Vol à l'étalage accessible à tous, sauf le personnel en service de ce magasin (un employé du magasin A peut voler au magasin B).
local function StealItem(store)
    if LTD.IsOnDuty() and LTD.GetStoreId() == store.id then return end
    if HasCooldown('theft') then Notify(Lang.LTD.action_cooldown, 'error') return end
    SetCooldown('theft')
    LSLegacy.Events.SendToServer('ltd:stealItem', { storeId = store.id })
end

LSLegacy.Events.Register('ltd:theftResult', function(data)
    if not data then return end
    if data.success then
        Notify(string.format(Lang.LTD.theft_done, data.label), 'success')
    else
        Notify(Lang.LTD.theft_none_available, 'warning')
    end
end)

LSLegacy.Events.Register('ltd:theftAlertEmployee', function()
    Notify(Lang.LTD.theft_alert_employee, 'error')
end)

for _, store in ipairs(Config.LTD.Stores) do
    exports.ox_target:addBoxZone({
        coords   = store.registerCoords,
        size     = vector3(1.5, 1.5, 2.0),
        rotation = store.headquartersHeading,
        debug    = false,
        options  = {
            {
                name = 'ltd_register_' .. store.id,
                icon = 'fa-solid fa-cash-register',
                label = 'Caisse — Vendre',
                distance = 2.0,
                canInteract = function() return LTD.IsOnDuty() and LTD.GetStoreId() == store.id end,
                onSelect = function() OpenRegister(store) end,
            },
        },
    })

    exports.ox_target:addBoxZone({
        coords   = store.storageCoords,
        size     = vector3(1.5, 1.5, 2.0),
        rotation = store.headquartersHeading,
        debug    = false,
        options  = {
            {
                name = 'ltd_storage_' .. store.id,
                icon = 'fa-solid fa-boxes-stacked',
                label = 'Réserve',
                distance = 2.0,
                canInteract = function() return LTD.IsOnDuty() and LTD.GetStoreId() == store.id end,
                onSelect = function() OpenStorage(store) end,
            },
        },
    })

    exports.ox_target:addBoxZone({
        coords   = store.shelfCoords,
        size     = vector3(1.5, 1.5, 2.0),
        rotation = store.headquartersHeading,
        debug    = false,
        options  = {
            {
                name = 'ltd_steal_' .. store.id,
                icon = 'fa-solid fa-hand',
                label = Lang.LTD.theft_title,
                distance = 2.0,
                canInteract = function() return not (LTD.IsOnDuty() and LTD.GetStoreId() == store.id) end,
                onSelect = function() StealItem(store) end,
            },
        },
    })
end
