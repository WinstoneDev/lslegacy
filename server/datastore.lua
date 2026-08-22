---@class LSLegacy.DataStore
LSLegacy.DataStore = {}
LSLegacy.DataStores = {}

-- Mêmes MarkDirty/SaveDirty que côté joueur (voir server/player/player.lua) :
-- seuls les datastores réellement modifiés depuis le dernier tick sont réécrits.
local DataStoreMethods = {}
LSLegacy.DataStoreMeta = {__index = DataStoreMethods}

DataStoreMethods.MarkDirty = function(self)
    self._dirty = true
end

DataStoreMethods.SaveDirty = function(self, id)
    if not self._dirty then return end
    if type(self.inventory) ~= "table" then
        self.inventory = json.decode(self.inventory)
    end
    MySQL.Async.execute(
        'UPDATE datastore SET inventory = @inventory, money = @money, dirty = @dirty, weight = @weight WHERE id = @id',
        {
            ['@id'] = id,
            ['@inventory'] = json.encode(self.inventory),
            ['@money'] = self.money or 0,
            ['@dirty'] = self.dirty or 0,
            ['@weight'] = self.maxWeight or 0
        }
    )
    self._dirty = false
end

Citizen.CreateThread(function()
    MySQL.Async.fetchAll('SELECT * FROM datastore', {}, function(result)
        for k, v in pairs(result) do
            setmetatable(v, LSLegacy.DataStoreMeta)
            LSLegacy.DataStores[v.name] = v
            -- La colonne BDD se nomme 'weight' mais le code utilise 'maxWeight' :
            -- on remappe au chargement pour éviter les comparaisons number/nil.
            if v.maxWeight == nil then v.maxWeight = v.weight end
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
                            -- Ligne déjà en base : on ne réécrit que si le datastore a
                            -- réellement changé depuis le dernier tick (voir MarkDirty
                            -- dans LSLegacy.DataStore.Add/Remove*).
                            datastore:SaveDirty(id)
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
                            datastore._dirty = false
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
    if not datastore then return false end
    amount = LSLegacy.Validate.PositiveInteger(amount)
    if not amount then return false end
    if not datastore.money then datastore.money = 0 end
    datastore.money = datastore.money + amount
    datastore:MarkDirty()
    LSLegacy.Events.SendToClient('UpdateDatastore', source, LSLegacy.DataStores)
    return true
end

---AddDirtyMoney
---@type function
---@param datastore table
---@param amount number
---@return any
---@public
LSLegacy.DataStore.AddDirtyMoney = function(datastore, amount)
    if not datastore then return false end
    amount = LSLegacy.Validate.PositiveInteger(amount)
    if not amount then return false end
    if not datastore.dirty then datastore.dirty = 0 end
    datastore.dirty = datastore.dirty + amount
    datastore:MarkDirty()
    LSLegacy.Events.SendToClient('UpdateDatastore', source, LSLegacy.DataStores)
    return true
end

---RemoveMoney
---@type function
---@param datastore table
---@param amount number
---@return any
---@public
LSLegacy.DataStore.RemoveMoney = function(datastore, amount)
    if not datastore then return false end
    amount = LSLegacy.Validate.PositiveInteger(amount)
    if not amount then return false end
    if not datastore.money then datastore.money = 0 end
    if datastore.money >= amount then
        datastore.money = datastore.money - amount
        datastore:MarkDirty()
        LSLegacy.Events.SendToClient('UpdateDatastore', source, LSLegacy.DataStores)
        return true
    end
    return false
end

---RemoveDirtyMoney
---@type function
---@param datastore table
---@param amount number
---@return any
---@public
LSLegacy.DataStore.RemoveDirtyMoney = function(datastore, amount)
    if not datastore then return false end
    amount = LSLegacy.Validate.PositiveInteger(amount)
    if not amount then return false end
    if not datastore.dirty then datastore.dirty = 0 end
    if datastore.dirty >= amount then
        datastore.dirty = datastore.dirty - amount
        datastore:MarkDirty()
        LSLegacy.Events.SendToClient('UpdateDatastore', source, LSLegacy.DataStores)
        return true
    end
    return false
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
    quantity = LSLegacy.Validate.PositiveInteger(quantity)
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
            datastore:MarkDirty()
            LSLegacy.Events.SendToClient('UpdateDatastore', source, LSLegacy.DataStores)
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
    quantity = LSLegacy.Validate.PositiveInteger(quantity)
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
    datastore:MarkDirty()
    LSLegacy.Events.SendToClient('UpdateDatastore', source, LSLegacy.DataStores)
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
    setmetatable(data, LSLegacy.DataStoreMeta)
    LSLegacy.DataStores[name] = data
    LSLegacy.Events.SendToClient('UpdateDatastore', source, LSLegacy.DataStores)
end

-- Event réseau : contenu toujours forcé vide côté serveur, jamais celui du client.
LSLegacy.Events.Register('RegisterDataStore', function(name, data)
    local player = LSLegacy.Validate.Player(source)
    if not player then return end
    if type(name) ~= "string" or type(data) ~= "table" then return end
    local maxWeight = LSLegacy.Validate.PositiveInteger(data.maxWeight, {allowZero = true}) or 0
    LSLegacy.DataStore.RegisterDataStore(name, {
        name = name,
        type = data.type,
        inventory = {},
        money = 0,
        dirty = 0,
        maxWeight = maxWeight
    })
end)