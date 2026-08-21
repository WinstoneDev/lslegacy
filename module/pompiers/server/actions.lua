--  MODULE SAPEURS-POMPIERS — Actions de secours (serveur)
--  Validation stricte : job/grade depuis ServerPlayers, jamais client

local function GetPlayer(src)   return LSLegacy.ServerPlayers[src] end
local function IsPompier(src)   return GetPlayer(src) and GetPlayer(src).job == Config.Pompiers.Job end
local function GetGrade(src)    return GetPlayer(src) and tonumber(GetPlayer(src).job_grade) or 0 end

local function Notify(src, msg, t)
    TriggerClientEvent(Config.Pompiers.NotifyEvent, src, 'Sapeurs-Pompiers', msg, 5000, t or 'info')
end

local function HasPermission(src, perm)
    return LSLegacy.MDT.HasPermission('pompiers', GetGrade(src), perm)
end

--  DÉSINCARCÉRATION / SECOURS

LSLegacy.RegisterServerEvent('pompiers:rescue', function(data)
    local src = source
    if not IsPompier(src) or not IsPompierOnDuty(src) then return end
    if not HasPermission(src, 'rescue_victim') then
        Notify(src, 'Votre grade est insuffisant pour désincarcérer.', 'error')
        return
    end
    if not data or not data.target then return end
    local target = tonumber(data.target)
    local targetPlayer = GetPlayer(target)
    if not targetPlayer then return end

    if targetPlayer.isKO or targetPlayer.isComa then
        -- Victime inconsciente : on stabilise comme une réanimation d'urgence
        LSLegacy.Injury.ClearState(target, Config.Pompiers.Actions.rescueHealth)
    else
        -- Victime consciente : simple soin + extraction du véhicule
        local targetPed = GetPlayerPed(target)
        if DoesEntityExist(targetPed) then
            local current = GetEntityHealth(targetPed)
            SetEntityHealth(targetPed, math.min(200, current + Config.Pompiers.Actions.rescueHealAmount))
        end
    end

    TriggerClientEvent('pompiers:rescueResult', src, { success = true })
    TriggerClientEvent('pompiers:rescuedByFiremen', target)
end)
