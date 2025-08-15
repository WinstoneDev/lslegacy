---@class MadeInFrance.DataStore
MadeInFrance.DataStore = {}
MadeInFrance.DataStores = {}

MySQL.ready(function()
    MySQL.Async.fetchAll('SELECT * FROM datastore', {}, function(result)
        for k, v in pairs(result) do
            MadeInFrance.DataStore[v.name] = v
        end
    end)
end)

---GetDataStore
---@type function
---@param name string
---@return table | nil
---@public
MadeInFrance.DataStore.GetDataStore = function(name)
    if not name then return end
    if MadeInFrance.DataStores[name] then
        return MadeInFrance.DataStores[name]
    else
        return nil
    end
end

---GetInventoryWeight
---@type function
---@param inventory table
---@return number
---@public
MadeInFrance.DataStore.GetInventoryWeight = function(inventory)
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
MadeInFrance.DataStore.CanStoreItem = function(datastore, item, quantity)
    if not datastore then return end
    if not item then return end
    if not quantity then quantity = 1 end
    if not MadeInFrance.Inventory.DoesItemExists(item) then return end
    local weight = MadeInFrance.DataStore.GetInventoryWeight(datastore.inventory)
    local itemWeight = Config.Items[item].weight * quantity
    if math.floor(weight + itemWeight) <= Config.Informations["MaxWeight"] then
        return true
    else
        return false
    end
end

---GetInventoryItem
---@type function
---@param datastore table
---@param item string
---@return table
---@public
MadeInFrance.DataStore.GetInventoryItem = function(datastore, item)
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
MadeInFrance.DataStore.AddItemInInventory = function(datastore, item, quantity, newLabel, uniqueId, data)
    if not datastore then return end
    if not item then return end
    if not quantity then return end
    local exist = false
    local source = source
    if MadeInFrance.Inventory.DoesItemExists(item) then
        if MadeInFrance.DataStore.CanStoreItem(datastore, item, quantity) then
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
            MadeInFrance.SendEventToClient('UpdateDatastore', source, MadeInFrance.DataStores)
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
MadeInFrance.DataStore.RemoveItemInInventory = function(datastore, item, quantity, itemLabel)
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
    MadeInFrance.SendEventToClient('UpdateDatastore', source, MadeInFrance.DataStores)
end

---RegisterDataStore
---@type function
---@param name string
---@param data table
---@return any
---@public
MadeInFrance.DataStore.RegisterDataStore = function(name, data)
    if not name or not data then return end
    if MadeInFrance.DataStores[name] then
        Config.Development.Print("DataStore " .. name .. " already exists.")
        return
    end
    MadeInFrance.DataStores[name] = data
    MadeInFrance.SendEventToClient('UpdateDatastore', source, MadeInFrance.DataStores)
end

MadeInFrance.RegisterServerEvent('RegisterDataStore', function(name, data)
    if not name or not data then return end
    MadeInFrance.DataStore.RegisterDataStore(name, data)
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000)
        for name, datastore in pairs(MadeInFrance.DataStores) do
            if datastore then
                MySQL.Async.fetchScalar(
                    'SELECT id FROM datastore WHERE name = @name AND type = @type LIMIT 1',
                    { ['@name'] = name, ['@type'] = datastore.type },
                    function(id)
                        if id then
                            MySQL.Async.execute(
                                'UPDATE datastore SET inventory = @inventory WHERE id = @id',
                                { ['@id'] = id, ['@inventory'] = json.encode(datastore.inventory) }
                            )
                        else
                            MySQL.Async.execute(
                                'INSERT INTO datastore (type, name, inventory) VALUES (@type, @name, @inventory)',
                                { ['@name'] = name, ['@type'] = datastore.type, ['@inventory'] = json.encode(datastore.inventory) }
                            )
                        end
                    end
                )
            end
        end
    end
end)