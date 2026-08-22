-- PORTER (/porter) — relais serveur : valide distance/état et relaie le
-- portage ; animation et attache gérées côté client (client/player/carry.lua)

local MAX_DISTANCE = Config.Carry.range + 1.0 -- marge pour la latence réseau

local Links = {} -- [src] = partnerSrc, dans les deux sens

local function GetDistance(a, b)
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if pedA == 0 or pedB == 0 then return 999.0 end
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB))
end

local function StartCarry(carrierSrc, carriedSrc)
    Links[carrierSrc] = carriedSrc
    Links[carriedSrc] = carrierSrc
    TriggerClientEvent('lslegacy_carry:clientStart', carrierSrc, carrierSrc, carriedSrc)
    TriggerClientEvent('lslegacy_carry:clientStart', carriedSrc, carrierSrc, carriedSrc)
end

local function StopCarry(src)
    local partner = Links[src]
    Links[src] = nil
    if partner then
        Links[partner] = nil
        TriggerClientEvent('lslegacy_carry:clientStop', partner)
    end
    TriggerClientEvent('lslegacy_carry:clientStop', src)
end

LSLegacy.Events.Register('lslegacy_carry:request', function(targetServerId)
    local src = source
    local target = tonumber(targetServerId)
    if not target or GetPlayerName(target) == nil or target == src then return end
    if Links[src] or Links[target] then return end
    if GetDistance(src, target) > MAX_DISTANCE then return end

    local targetPlayer = LSLegacy.ServerPlayers[target]

    if targetPlayer and (targetPlayer.isKO or targetPlayer.isComa) then
        -- Inconscient : pas besoin de consentement.
        StartCarry(src, target)
    else
        TriggerClientEvent('lslegacy_carry:clientRequest', target, src)
    end
end)

LSLegacy.Events.Register('lslegacy_carry:confirm', function(requesterServerId)
    local src = source
    local requester = tonumber(requesterServerId)
    if not requester or GetPlayerName(requester) == nil then return end
    if Links[src] or Links[requester] then return end
    if GetDistance(src, requester) > MAX_DISTANCE then return end

    StartCarry(requester, src)
end)

LSLegacy.Events.Register('lslegacy_carry:cancel', function()
    StopCarry(source)
end)

AddEventHandler('playerDropped', function()
    StopCarry(source)
end)
