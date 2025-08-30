---@class LSLegacy.DataStore
LSLegacy.DataStore = {}
LSLegacy.DataStores = {}

Citizen.CreateThread(function()
    MySQL.Async.fetchAll('SELECT * FROM datastore', {}, function(result)
        for k, v in pairs(result) do
            LSLegacy.DataStores[v.name] = v
        end
    end)
    for k, v in pairs(LSLegacy.DataStores) do
        if type(v.inventory) ~= "table" then
            v.inventory = json.decode(v.inventory)
        end
    end
end)

Citizen.CreateThread(function()
    Wait(5000)
    while true do
        for name, datastore in pairs(LSLegacy.DataStores) do
            if datastore then
                if type(datastore.inventory) ~= "table" then
                    datastore.inventory = json.decode(datastore.inventory)
                end
                MySQL.Async.fetchScalar(
                    'SELECT id FROM datastore WHERE name = @name AND type = @type LIMIT 1',
                    { ['@name'] = name, ['@type'] = datastore.type },
                    function(id)
                        if id then
                            MySQL.Async.execute(
                                'UPDATE datastore SET inventory = @inventory, money = @money, dirty = @dirty, weight = @weight WHERE id = @id',
                                {
                                    ['@id'] = id,
                                    ['@inventory'] = json.encode(datastore.inventory),
                                    ['@money'] = datastore.money or 0,
                                    ['@dirty'] = datastore.dirty or 0,
                                    ['@weight'] = datastore.maxWeight or 0
                                }
                            )
                        else
                            MySQL.Async.execute(
                                'INSERT INTO datastore (type, name, inventory, money, dirty, weight) VALUES (@type, @name, @inventory, @money, @dirty, @weight)',
                                {
                                    ['@name'] = name,
                                    ['@type'] = datastore.type,
                                    ['@inventory'] = json.encode(datastore.inventory),
                                    ['@money'] = datastore.money or 0,
                                    ['@dirty'] = datastore.dirty or 0,
                                    ['@weight'] = datastore.maxWeight or 0
                                }
                            )
                        end
                    end
                )
            end
        end
        Wait(15000)
    end
end)

---GetDataStore
---@type function
---@param name string
---@return table | nil
---@public
LSLegacy.DataStore.GetDataStore = function(name)
    if not name then return end
    if LSLegacy.DataStores[name] then
        return LSLegacy.DataStores[name]
    else
        return nil
    end
end

---GetInventoryWeight
---@type function
---@param inventory table
---@return number
---@public
LSLegacy.DataStore.GetInventoryWeight = function(inventory)
    if not inventory then return end
    local weight = 0

    for key, value in pairs(inventory) do
        weight = weight + Config.Items[value.name].weight * value.count
    end
    return weight
end

---CanStoreItem
---@type function
---@param datastore table
---@param item string
---@param quantity number
---@return boolean
---@public
LSLegacy.DataStore.CanStoreItem = function(datastore, item, quantity)
    if not datastore then return end
    if not item then return end
    if not quantity then quantity = 1 end
    if not LSLegacy.Inventory.DoesItemExists(item) then return end
    local weight = LSLegacy.DataStore.GetInventoryWeight(datastore.inventory)
    local itemWeight = Config.Items[item].weight * quantity
    if math.floor(weight + itemWeight) <= datastore.maxWeight then
        return true
    else
        return false
    end
end

---AddMoney
---@type function
---@param datastore table
---@param amount number
---@return any
---@public
LSLegacy.DataStore.AddMoney = function(datastore, amount)
    if not datastore or not amount then return end
    if not datastore.money then datastore.money = 0 end
    datastore.money = datastore.money + amount
    LSLegacy.SendEventToClient('UpdateDatastore', source, LSLegacy.DataStores)
end

---AddDirtyMoney
---@type function
---@param datastore table
---@param amount number
---@return any
---@public
LSLegacy.DataStore.AddDirtyMoney = function(datastore, amount)
    if not datastore or not amount then return end
    if not datastore.dirty then datastore.dirty = 0 end
    datastore.dirty = datastore.dirty + amount
    LSLegacy.SendEventToClient('UpdateDatastore', source, LSLegacy.DataStores)
end

---RemoveMoney
---@type function
---@param datastore table
---@param amount number
---@return any
---@public
LSLegacy.DataStore.RemoveMoney = function(datastore, amount)
    if not datastore or not amount then return false end
    if not datastore.money then datastore.money = 0 end
    if datastore.money >= amount then
        datastore.money = datastore.money - amount
        LSLegacy.SendEventToClient('UpdateDatastore', source, LSLegacy.DataStores)
    end
end

---RemoveDirtyMoney
---@type function
---@param datastore table
---@param amount number
---@return any
---@public
LSLegacy.DataStore.RemoveDirtyMoney = function(datastore, amount)
    if not datastore or not amount then return false end
    if not datastore.dirty then datastore.dirty = 0 end
    if datastore.dirty >= amount then
        datastore.dirty = datastore.dirty - amount
        LSLegacy.SendEventToClient('UpdateDatastore', source, LSLegacy.DataStores)
    end
end

---GetMoney
---@type function
---@param datastore table
---@return number
---@public
LSLegacy.DataStore.GetMoney = function(datastore)
    if not datastore then return 0 end
    if not datastore.money then datastore.money = 0 end
    return datastore.money
end

---GetDirtyMoney
---@type function
---@param datastore table
---@return number
---@public
LSLegacy.DataStore.GetDirtyMoney = function(datastore)
    if not datastore then return 0 end
    if not datastore.dirty then datastore.dirty = 0 end
    return datastore.dirty
end

---GetInventoryItem
---@type function
---@param datastore table
---@param item string
---@return table
---@public
LSLegacy.DataStore.GetInventoryItem = function(datastore, item)
    if not item then return end
    local count = 0
    local data = nil

    local inventory = datastore.inventory

    for key, value in pairs(inventory) do
        if value.name == item then
            count = count + value.count
            data = value
        end
    end
    if count ~= 0 then
        return {count = count, label = Config.Items[item].label, uniqueId = data.uniqueId, data = data.data}
    else
        return nil
    end
end

---AddItemInInventory
---@type function
---@param datastore table
---@param item string
---@param quantity number
---@param newLabel string
---@param uniqueId number
---@param data table
---@return any
LSLegacy.DataStore.AddItemInInventory = function(datastore, item, quantity, newLabel, uniqueId, data)
    if not datastore then return end
    if not item then return end
    if not quantity then return end
    local exist = false
    local source = source
    if LSLegacy.Inventory.DoesItemExists(item) then
        if LSLegacy.DataStore.CanStoreItem(datastore, item, quantity) then
            local inventory = datastore.inventory
            local Itemlabel = newLabel or Config.Items[item].label

            for k, v in pairs(inventory) do
                if not Config.InsertItems[v.name] then
                    if v.name == item and v.label == Itemlabel then
                        v.count = v.count + quantity
                        exist = true
                        break
                    end
                end
            end

            if not exist then
                if Config.InsertItems[item] then
                    if data ~= nil then
                        table.insert(inventory, {data = data, uniqueId = uniqueId, name = item, label = Itemlabel, count = quantity})
                    else
                        table.insert(inventory, {uniqueId = uniqueId, name = item, label = Itemlabel, count = quantity})
                    end
                else
                    table.insert(inventory, {name = item, label = Itemlabel, count = quantity})
                end
            end
            datastore.inventory = inventory
            LSLegacy.SendEventToClient('UpdateDatastore', source, LSLegacy.DataStores)
        end
    end
end

---RemoveItemInInventory
---@type function
---@param datastore table
---@param item string
---@param quantity number
---@param itemLabel string
---@return any
---@public
LSLegacy.DataStore.RemoveItemInInventory = function(datastore, item, quantity, itemLabel)
    if not datastore then return end
    if not item then return end
    if not quantity then return end
    local source = source
    local inventory = datastore.inventory
    local label = itemLabel or Config.Items[item].label
    local removed = false

    for k, v in pairs(inventory) do
        if v.name == item and v.label == label then
            if tonumber(v.count) >= tonumber(quantity) then
                v.count = v.count - quantity
                if v.count <= 0 then
                    table.remove(inventory, k)
                end
                removed = true
                break
            else
                break
            end
        end
    end

    if not removed then
        for k, v in pairs(inventory) do
            if v.name == item then
                if tonumber(v.count) >= tonumber(quantity) then
                    v.count = v.count - quantity
                    if v.count <= 0 then
                        table.remove(inventory, k)
                    end
                    break
                else
                    break
                end
            end
        end
    end
    datastore.inventory = inventory
    LSLegacy.SendEventToClient('UpdateDatastore', source, LSLegacy.DataStores)
end

---RegisterDataStore
---@type function
---@param name string
---@param data table
---@return any
---@public
LSLegacy.DataStore.RegisterDataStore = function(name, data)
    if not name or not data then return end
    if LSLegacy.DataStores[name] then
        Config.Development.Print("DataStore " .. name .. " already exists.")
        return
    end
    LSLegacy.DataStores[name] = data
    LSLegacy.SendEventToClient('UpdateDatastore', source, LSLegacy.DataStores)
end

LSLegacy.RegisterServerEvent('RegisterDataStore', function(name, data)
    if not name or not data then return end
    LSLegacy.DataStore.RegisterDataStore(name, data)
end)