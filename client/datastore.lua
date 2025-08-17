MadeInFrance.DataStore = {}
MadeInFrance.DataStores= {}

MadeInFrance.RegisterClientEvent('UpdateDatastore', function(data)
    if not data then return end
    MadeInFrance.DataStores = data
end)

MadeInFrance.DataStore.RegisterDataStore = function(name, data)
    if not name or not data then return end
    MadeInFrance.SendEventToServer('RegisterDataStore', name, data)
end

MadeInFrance.DataStore.RegisterTrunk = function(vehicle)
    if not vehicle then return end
    local plate = GetVehicleNumberPlateText(vehicle)
    local data = {
        inventory = {},
        name = 'trunk_' .. plate,
        type = 'trunk',
        money = 0,
        dirty = 0
    }
    MadeInFrance.SendEventToServer('RegisterDataStore', data.name, data)
end

MadeInFrance.DataStore.RegisterBAG = function(vehicle)
    if not vehicle then return end
    local plate = GetVehicleNumberPlateText(vehicle)
    local data = {
        inventory = {},
        name = 'bag_' .. plate,
        type = 'trunk',
        money = 0,
        dirty = 0
    }
    MadeInFrance.SendEventToServer('RegisterDataStore', data.name, data)
end

MadeInFrance.DataStore.GetInventoryWeight = function(inventory)
    if not inventory then return end
    local weight = 0
    Wait(100)
    for key, value in pairs(inventory) do
        weight = weight + Config.Items[value.name].weight * value.count
    end
    return weight
end

MadeInFrance.DataStore.GetTrunk = function(plate)
    if not plate then return end
    local name = 'trunk_' .. plate
    if MadeInFrance.DataStores[name] then
        return MadeInFrance.DataStores[name]
    else
        return nil
    end
end

MadeInFrance.DataStore.GetBAG = function(plate)
    if not plate then return end
    local name = 'bag_' .. plate
    if MadeInFrance.DataStores[name] then
        return MadeInFrance.DataStores[name]
    else
        return nil
    end
end