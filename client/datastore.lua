LSLegacy.DataStore = {}
LSLegacy.DataStores= {}

LSLegacy.RegisterClientEvent('UpdateDatastore', function(data)
    if not data then return end
    LSLegacy.DataStores = data
end)

LSLegacy.DataStore.RegisterDataStore = function(name, data)
    if not name or not data then return end
    LSLegacy.SendEventToServer('RegisterDataStore', name, data)
end

LSLegacy.DataStore.RegisterTrunk = function(vehicle)
    if not vehicle then return end
    local plate = GetVehicleNumberPlateText(vehicle)
    local data = {
        inventory = {},
        name = 'trunk_' .. plate,
        type = 'trunk',
        money = 0,
        dirty = 0,
        maxWeight = Config.VehicleTrunks[GetVehicleClass(vehicle)]
    }
    LSLegacy.SendEventToServer('RegisterDataStore', data.name, data)
end

LSLegacy.DataStore.RegisterBAG = function(vehicle)
    if not vehicle then return end
    local plate = GetVehicleNumberPlateText(vehicle)
    local data = {
        inventory = {},
        name = 'bag_' .. plate,
        type = 'trunk',
        money = 0,
        dirty = 0,
        maxWeight = Config.VehicleGloveboxes[GetVehicleClass(vehicle)]
    }
    LSLegacy.SendEventToServer('RegisterDataStore', data.name, data)
end

LSLegacy.DataStore.GetInventoryWeight = function(inventory)
    if not inventory then return end
    local weight = 0
    Wait(100)
    for key, value in pairs(inventory) do
        weight = weight + Config.Items[value.name].weight * value.count
    end
    return weight
end

LSLegacy.DataStore.GetTrunk = function(plate)
    if not plate then return end
    local name = 'trunk_' .. plate
    if LSLegacy.DataStores[name] then
        return LSLegacy.DataStores[name]
    else
        return nil
    end
end

LSLegacy.DataStore.GetBAG = function(plate)
    if not plate then return end
    local name = 'bag_' .. plate
    if LSLegacy.DataStores[name] then
        return LSLegacy.DataStores[name]
    else
        return nil
    end
end