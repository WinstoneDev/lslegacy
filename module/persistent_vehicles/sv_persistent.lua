LSLegacy = LSLegacy or {}
LSLegacy.AP = { Active = {} }

local function isBlacklisted(entity)
    local model = GetEntityModel(entity)
    for _, m in ipairs(Config.AP.Blacklist.Models) do
        if m == model then return true end
    end
    local plate = (GetVehicleNumberPlateText(entity) or ""):upper()
    for _, p in ipairs(Config.AP.Blacklist.Plates) do
        if plate:find(p, 1, true) then return true end
    end
    return false
end

local function saveVehicle(entity)
    if not DoesEntityExist(entity) then return end
    if isBlacklisted(entity) then return end

    local plate = (GetVehicleNumberPlateText(entity) or ""):upper()
    local pos = GetEntityCoords(entity)

    while LSLegacy.AP.Active[plate] == nil do 
        Wait(100)
    end

    while LSLegacy.AP.Active[plate].fuel == nil do 
        Wait(100)
    end

    while LSLegacy.AP.Active[plate].windows == nil do 
        Wait(100)
    end

    while LSLegacy.AP.Active[plate].extras == nil do 
        Wait(100)
    end

    local status = {
        engine = GetVehicleEngineHealth(entity),
        body = GetVehicleBodyHealth(entity),
        tank = GetVehiclePetrolTankHealth(entity),
        dirt = GetVehicleDirtLevel(entity),
        fuel = LSLegacy.AP.Active[plate].fuel,
        lock = GetVehicleDoorLockStatus(entity),
        windows = LSLegacy.AP.Active[plate].windows or {},
        extras = LSLegacy.AP.Active[plate].extras or {},
        tyreData = LSLegacy.AP.Active[plate].tyreData or {},
        doorsBroken = LSLegacy.AP.Active[plate].doorsBroken or {},
        visualDamage = LSLegacy.AP.Active[plate].visualDamage or {}
    }

    local tuning = {}
    tuning.colorPrimary, tuning.colorSecondary = GetVehicleColours(entity)
    tuning.pearlColor, tuning.wheelColor = GetVehicleExtraColours(entity)
    tuning.wheelType = GetVehicleWheelType(entity)
    tuning.windowTint = GetVehicleWindowTint(entity)

    local state_bags = {}
    
    if LSLegacy.AP.Active[plate].tuning then
        tuning = LSLegacy.AP.Active[plate].tuning
        if type(tuning) ~= 'table' then
            tuning = json.decode(tuning)
            LSLegacy.AP.Active[plate].tuning = tuning
        end
    end

    local snapshot = {
        position = { x = pos.x, y = pos.y, z = pos.z, h = GetEntityHeading(entity) },
        status = status,
        tuning = tuning,
        state_bags = state_bags,
        model = GetEntityModel(entity),
        trailer = nil
    }

    MySQL.Async.execute([[
        INSERT INTO persistent_vehicles (plate, model, position, status, tuning, trailer_plate, state_bags)
        VALUES (@plate, @model, @position, @status, @tuning, @trailer, @bags)
        ON DUPLICATE KEY UPDATE
        model=@model, position=@position, status=@status, tuning=@tuning, trailer_plate=@trailer, state_bags=@bags, last_seen_at = CURRENT_TIMESTAMP
    ]], {
        ['@plate'] = plate,
        ['@model'] = snapshot.model,
        ['@position'] = json.encode(snapshot.position),
        ['@status'] = json.encode(snapshot.status),
        ['@tuning'] = json.encode(snapshot.tuning),
        ['@trailer'] = snapshot.trailer,
        ['@bags'] = json.encode(snapshot.state_bags)
    })
end


local function spawnVehicle(row)
    local pos = json.decode(row.position)
    local status = json.decode(row.status)
    local entity = CreateVehicle(row.model, pos.x, pos.y, pos.z, pos.h or 0.0, true, true)
    while DoesEntityExist(entity) == false do
        Wait(100)
    end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    SetVehicleNumberPlateText(entity, row.plate)
    SetVehicleBodyHealth(entity, status.body or 1000.0)
    SetVehicleDirtLevel(entity, status.dirt or 0.0)
    SetVehicleDoorsLocked(entity, status.lock or 1)
    LSLegacy.AP.Active[row.plate] = { netId = netId, entity = entity, model = row.model }
end

function LSLegacy.AP.SpawnPersistentVehicle(model, pos, heading, targetPlayer)
    local modelHash = tonumber(model) or GetHashKey(model)
    local vehicle = CreateVehicle(modelHash, pos.x, pos.y, pos.z, heading or 0.0, true, false)
    Wait(1000)
    plate = GetVehicleNumberPlateText(vehicle)
    SetVehicleNumberPlateText(vehicle, plate)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    LSLegacy.AP.Active[plate] = { netId = netId, entity = vehicle, model = modelHash, extras = {}, tankHealth = 1000.0, engineHealth = 1000.0, fuel = 50.0, windows = {} }
    Wait(500)
    if targetPlayer then
        local ped = GetPlayerPed(targetPlayer)
        if DoesEntityExist(ped) then
            TaskWarpPedIntoVehicle(ped, vehicle, -1)
        end
        LSLegacy.SendEventToClient("ap:vehicleSpawned", -1, { netId = netId, plate = plate, extras = {}, tankHealth = 1000.0, engineHealth = 1000.0, fuel = 50.0, windows = {} })
    end
end

function LSLegacy.AP.DeleteVehicle(plate, entity)
    if LSLegacy.AP.Active[plate] then
        LSLegacy.AP.Active[plate] = nil
    end

    MySQL.Async.execute(
        'DELETE FROM persistent_vehicles WHERE plate = @plate',
        { ['@plate'] = plate }
    )

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

LSLegacy.RegisterServerEvent("ap:requestVehicleDeletion", function(netId, plate)
    local source = source
    local player = LSLegacy.GetPlayerFromId(source)
    
    if not player then return end

    local entity = NetworkGetEntityFromNetworkId(netId)

    if DoesEntityExist(entity) then
        LSLegacy.AP.DeleteVehicle(plate, entity)
        LSLegacy.SendEventToClient('notify', source, 'Succès', 'Le véhicule a été supprimé.', 'success')
    else
        LSLegacy.SendEventToClient('notify', source, 'Erreur', 'Impossible de trouver le véhicule à supprimer.', 'error')
    end
end)

LSLegacy.RegisterCommand('dv', 1, function(player, args, showError, rawCommand)
    LSLegacy.SendEventToClient('ap:findAndDeleteVehicle', player.source)
end,
{
    help = "Supprime le véhicule que vous conduisez ou le plus proche (rayon de 3m).",
    validate = false
}, false)

LSLegacy.RegisterServerEvent("ap:updateVehicleStatus", function(plate, status)
    if not plate or not status then return end
    if LSLegacy.AP.Active[plate] then
        LSLegacy.AP.Active[plate].fuel = status.fuel
        LSLegacy.AP.Active[plate].tuning = status.tuning
        LSLegacy.AP.Active[plate].windows = status.windows
        LSLegacy.AP.Active[plate].extras = status.extras
        LSLegacy.AP.Active[plate].tyreData = status.tyreData
        LSLegacy.AP.Active[plate].doorsBroken = status.doorsBroken
        LSLegacy.AP.Active[plate].visualDamage = status.visualDamage
    end
end)

LSLegacy.RegisterServerEvent("ap:updateVehicle", function(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then saveVehicle(entity) end
end)

LSLegacy.AddEventHandler('ap:clientsetonSpawn', function(source)
    MySQL.Async.fetchAll('SELECT * FROM persistent_vehicles', {}, function(rows)
        for _, row in ipairs(rows) do
            local status = type(row.status) == "string" and json.decode(row.status) or row.status
            local tuning = type(row.tuning) == "string" and json.decode(row.tuning) or row.tuning
            while LSLegacy.AP.Active[row.plate] == nil do 
                Wait(100)
            end
            while LSLegacy.AP.Active[row.plate].netId == nil do
                Wait(100)
            end
            LSLegacy.SendEventToClient("ap:vehicleSpawned", source, { 
                netId = LSLegacy.AP.Active[row.plate].netId, 
                plate = row.plate, 
                extras = status.extras or {},
                tankHealth = status.tank or 1000.0,
                engineHealth = status.engine or 1000.0,
                tuning = tuning, 
                fuel = status.fuel or 50.0,
                status = status
            })
            LSLegacy.AP.Active[row.plate].fuel = status.fuel
            LSLegacy.AP.Active[row.plate].tuning = tuning or {}
            LSLegacy.AP.Active[row.plate].windows = status.windows or {}
            LSLegacy.AP.Active[row.plate].extras = status.extras or {}
            LSLegacy.AP.Active[row.plate].tyreData = status.tyreData or {}
            LSLegacy.AP.Active[row.plate].doorsBroken = status.doorsBroken or {}
            LSLegacy.AP.Active[row.plate].visualDamage = status.visualDamage or {}
        end
    end)
end)

CreateThread(function()
    while true do
        if not Config.AP.Enable then goto continue end
        local players = LSLegacy.ServerPlayers

        if json.encode(players) ~= "[]" then
            for plate, v in pairs(LSLegacy.AP.Active) do
                if DoesEntityExist(v.entity) then
                    saveVehicle(v.entity)
                end
            end


            MySQL.Async.fetchAll([[SELECT * FROM persistent_vehicles]], {}, function(rows)
                for _, row in ipairs(rows) do
                    if not LSLegacy.AP.Active[row.plate] then
                        spawnVehicle(row)
                    end
                end
            end)

            -- cleanup
            if Config.AP.Cleanup then
                MySQL.Async.execute([[
                    DELETE FROM persistent_vehicles
                    WHERE last_seen_at < (NOW() - INTERVAL @days DAY)
                ]], { ['@days'] = Config.AP.CleanupDays })
            end
        end
        Wait(Config.AP.UpdateIntervalMs)
        ::continue::
    end
end)
