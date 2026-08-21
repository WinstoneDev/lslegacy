-- OTAGE (/otage) — relais serveur : relaie les events et suit qui tient qui
-- pour nettoyer à la déconnexion. Animation/attache côté client (client/player/hostage.lua)

local TakingHostage = {} -- [aggressorSrc] = targetSrc
local TakenHostage  = {} -- [targetSrc] = aggressorSrc

LSLegacy.RegisterServerEvent('lslegacy_hostage:sync', function(targetServerId)
    local src = source
    local target = tonumber(targetServerId)
    if not target or GetPlayerName(target) == nil or target == src then return end

    TriggerClientEvent('lslegacy_hostage:client:syncTarget', target, src)
    TakingHostage[src]   = target
    TakenHostage[target] = src
end)

LSLegacy.RegisterServerEvent('lslegacy_hostage:release', function(targetServerId)
    local src = source
    local target = tonumber(targetServerId)
    if target and TakenHostage[target] == src then
        TriggerClientEvent('lslegacy_hostage:client:release', target)
        TakingHostage[src]   = nil
        TakenHostage[target] = nil
    end
end)

LSLegacy.RegisterServerEvent('lslegacy_hostage:kill', function(targetServerId)
    local src = source
    local target = tonumber(targetServerId)
    if target and TakenHostage[target] == src then
        TriggerClientEvent('lslegacy_hostage:client:kill', target)
        TakingHostage[src]   = nil
        TakenHostage[target] = nil
    end
end)

LSLegacy.RegisterServerEvent('lslegacy_hostage:stop', function(targetServerId)
    local src = source
    local target = tonumber(targetServerId)

    if TakingHostage[src] then
        TriggerClientEvent('lslegacy_hostage:client:stop', target or TakingHostage[src])
        TakenHostage[TakingHostage[src]] = nil
        TakingHostage[src] = nil
    elseif TakenHostage[src] then
        TriggerClientEvent('lslegacy_hostage:client:stop', target or TakenHostage[src])
        TakingHostage[TakenHostage[src]] = nil
        TakenHostage[src] = nil
    end
end)

AddEventHandler('playerDropped', function()
    local src = source

    if TakingHostage[src] then
        TriggerClientEvent('lslegacy_hostage:client:stop', TakingHostage[src])
        TakenHostage[TakingHostage[src]] = nil
        TakingHostage[src] = nil
    end

    if TakenHostage[src] then
        TriggerClientEvent('lslegacy_hostage:client:stop', TakenHostage[src])
        TakingHostage[TakenHostage[src]] = nil
        TakenHostage[src] = nil
    end
end)
