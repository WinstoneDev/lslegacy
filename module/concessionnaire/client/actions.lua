-- L'achat / la revente sont entièrement validés côté serveur.

local function Notify(msg, type)
    TriggerEvent(Config.Concessionnaire.NotifyEvent, 'Concessionnaire', msg, 5000, type or 'info')
end

LSLegacy.Events.Register('concessionnaire:buyResult', function(data)
    if not data then return end
    if data.success then
        Notify(string.format(Lang.Concessionnaire.bought, data.label or '?'), 'success')
    else
        local msg = Lang.Concessionnaire[data.reason] or Lang.Concessionnaire.purchase_failed
        Notify(msg, 'error')
    end
end)

LSLegacy.Events.Register('concessionnaire:deliverVehicle', function(data)
    if not data or not data.model then return end
    if Concessionnaire and Concessionnaire.ClearPreview then Concessionnaire.ClearPreview() end

    local hash = GetHashKey(data.model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then
        Notify('Modèle introuvable : ' .. data.model, 'error')
        return
    end

    local d   = data.coords
    local veh = CreateVehicle(hash, d.x, d.y, d.z, data.heading or 0.0, true, false)
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)

    -- Prendre le contrôle réseau avant de forcer la plaque (sinon elle ne « colle » pas)
    local ct = 0
    while not NetworkHasControlOfEntity(veh) and ct < 30 do
        NetworkRequestControlOfEntity(veh)
        Wait(10); ct = ct + 1
    end
    SetVehicleNumberPlateText(veh, data.plate)
    Wait(50)

    if data.primary ~= nil then
        SetVehicleColours(veh, data.primary, data.secondary or 0)
    end
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleFuelLevel(veh, 100.0)

    if data.tuning then
        local tuning = data.tuning
        if tuning.mods then
            for k, v in pairs(tuning.mods) do
                if v ~= nil and tonumber(k) then SetVehicleMod(veh, tonumber(k), v, false) end
            end
        end
        if tuning.colorPrimary and tuning.colorSecondary then
            SetVehicleColours(veh, tuning.colorPrimary, tuning.colorSecondary)
        end
        if tuning.pearlColor and tuning.wheelColor then
            SetVehicleExtraColours(veh, tuning.pearlColor, tuning.wheelColor)
        end
        if tuning.wheelType then SetVehicleWheelType(veh, tuning.wheelType) end
        if tuning.windowTint then SetVehicleWindowTint(veh, tuning.windowTint) end
    end
    if data.status then
        local status = data.status
        SetVehicleEngineHealth(veh, status.engine or 1000.0)
        SetVehicleBodyHealth(veh, status.body or 1000.0)
        SetVehiclePetrolTankHealth(veh, status.tank or 1000.0)
        SetVehicleDirtLevel(veh, status.dirt or 0.0)
        SetVehicleFuelLevel(veh, status.fuel or 100.0)
    end

    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    SetModelAsNoLongerNeeded(hash)

    local netId = NetworkGetNetworkIdFromEntity(veh)
    if netId and netId ~= 0 then
        LSLegacy.Events.SendToServer('concessionnaire:persistDelivered', {
            plate = data.plate,
            netId = netId,
        })
    end

    Notify(Lang.Concessionnaire.delivered, 'success')
end)

LSLegacy.Events.Register('concessionnaire:sellResult', function(data)
    if not data then return end
    if not data.success then
        local msg = Lang.Concessionnaire[data.reason] or Lang.Concessionnaire.resale_failed
        Notify(msg, 'error')
        return
    end

    local function norm(p) return (tostring(p or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

    local target = data.plate and norm(data.plate)
    if target then
        local ped = PlayerPedId()
        local cur = GetVehiclePedIsIn(ped, false)
        if cur ~= 0 and norm(GetVehicleNumberPlateText(cur)) == target then
            SetEntityAsMissionEntity(cur, true, true)
            DeleteVehicle(cur)
        else
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if norm(GetVehicleNumberPlateText(veh)) == target then
                    SetEntityAsMissionEntity(veh, true, true)
                    DeleteVehicle(veh)
                    break
                end
            end
        end
    end

    Notify(string.format(Lang.Concessionnaire.resale_done, data.refund or 0), 'success')
end)
