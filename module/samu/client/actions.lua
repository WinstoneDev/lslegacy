--  MODULE SAMU — Actions de soins (client)
--  Toutes les actions sont validées côté SERVEUR.
--  Ciblage : ox_target (ALT sur un joueur) — Menus : ox_lib (context)

local cooldowns = {}

local function Notify(msg, type)
    TriggerEvent(Config.SAMU.NotifyEvent, 'SAMU', msg, 5000, type or 'info')
end

-- Anti-abus cooldown

local function HasCooldown(action)
    if not cooldowns[action] then return false end
    return (GetGameTimer() - cooldowns[action]) < (Config.SAMU.Actions.cooldowns[action] or 3000)
end

local function SetCooldown(action)
    cooldowns[action] = GetGameTimer()
end

-- Conversion ped ciblé → id serveur

local function GetServerIdFromPed(ped)
    local playerIndex = NetworkGetPlayerIndexFromPed(ped)
    if not playerIndex then return nil end
    return GetPlayerServerId(playerIndex)
end

-- Jouer une animation avec durée

local function PlayAnim(dict, anim, duration, flag)
    flag = flag or 49
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do
        Wait(100); t = t + 1
    end
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, duration, flag, 0, false, false, false)
    Wait(duration)
    ClearPedTasks(PlayerPedId())
end

--  TROUSSE DE SOINS — voir module/samu/client/health_inspection.lua
--  (SAMU.OpenHealthInspection, ouverte via la cible samu_bag ci-dessous)

--  RÉANIMER (sortie de KO/coma)

local function Revive(targetSrc)
    if not LSLegacy.MDT.HasPermission('samu', SAMU.GetGrade(), 'revive_player') then
        Notify(Lang.SAMU.grade_required, 'error')
        return
    end
    if HasCooldown('revive') then Notify(Lang.SAMU.action_cooldown, 'error') return end
    SetCooldown('revive')
    Notify(Lang.SAMU.revive_start, 'info')

    PlayAnim('mini@cpr@char_a@cpr_str', 'cpr_pumpchest', Config.SAMU.Actions.reviveDuration, 49)

    LSLegacy.SendEventToServer('samu:revive', { target = targetSrc })
end

-- Résultats serveur

LSLegacy.RegisterClientEvent('samu:reviveResult', function(data)
    if not data then return end
    if data.success then
        Notify(Lang.SAMU.revive_done, 'success')
    else
        Notify(Lang.SAMU.not_unconscious, 'warning')
    end
end)

LSLegacy.RegisterClientEvent('samu:revivedByEms', function()
    Notify(Lang.SAMU.revived_by, 'success')
end)

LSLegacy.RegisterClientEvent('samu:treatedByEms', function(label)
    Notify(string.format('Les secours vous ont soigné : %s.', label or '?'), 'success')
end)

LSLegacy.RegisterClientEvent('samu:restockResult', function(data)
    if not data then return end
    if data.success then
        Notify(Lang.SAMU.restock_done, 'success')
    else
        Notify(Lang.SAMU.restock_cooldown, 'error')
    end
end)

--  CIBLAGE OX_TARGET — Touche ALT sur un joueur

-- Diagnostic
-- ox_target masque une option aussi bien quand canInteract renvoie false
-- que quand elle lève une erreur (client/main.lua : `not success or not resp`),
-- d'où l'absence totale de retour visuel quand une cible ne s'affiche pas.
-- Cette commande imprime l'état réel, côté agent et côté patient visé.
RegisterCommand('samudebug', function()
    local ok, onDuty = pcall(function() return SAMU.IsOnDuty() end)
    print('[SAMU DEBUG] ------------------------------')
    print('[SAMU DEBUG] type(SAMU)            = ' .. type(SAMU))
    print('[SAMU DEBUG] type(SAMU.IsOnDuty)   = ' .. (type(SAMU) == 'table' and type(SAMU.IsOnDuty) or 'n/a'))
    print('[SAMU DEBUG] SAMU.OnDuty           = ' .. tostring(type(SAMU) == 'table' and SAMU.OnDuty))
    print('[SAMU DEBUG] IsOnDuty() ok         = ' .. tostring(ok) .. ' / valeur = ' .. tostring(onDuty))
    print('[SAMU DEBUG] job                   = ' .. tostring(LSLegacy.PlayerData and LSLegacy.PlayerData.job))
    print('[SAMU DEBUG] job_grade             = ' .. tostring(LSLegacy.PlayerData and LSLegacy.PlayerData.job_grade))
    print('[SAMU DEBUG] Config.SAMU.Job       = ' .. tostring(Config.SAMU and Config.SAMU.Job))
    print('[SAMU DEBUG] distance configurée   = ' .. tostring(Config.SAMU and Config.SAMU.Actions and Config.SAMU.Actions.interactionRange))

    -- État réel du joueur le plus proche : c'est ce que voit canInteract.
    local me     = PlayerPedId()
    local myPos  = GetEntityCoords(me)
    local best, bestDist, bestIdx
    for _, playerIndex in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(playerIndex)
        if ped ~= me and DoesEntityExist(ped) then
            local d = #(GetEntityCoords(ped) - myPos)
            if not bestDist or d < bestDist then best, bestDist, bestIdx = ped, d, playerIndex end
        end
    end

    if best then
        print('[SAMU DEBUG] --- cible la plus proche ---')
        print('[SAMU DEBUG] server id            = ' .. tostring(GetPlayerServerId(bestIdx)))
        print('[SAMU DEBUG] distance             = ' .. string.format('%.2f m', bestDist))
        print('[SAMU DEBUG] santé                = ' .. tostring(GetEntityHealth(best)) .. ' (seuil à terre : ' .. tostring(Config.SAMU.Actions.downedHealthThreshold) .. ')')
        print('[SAMU DEBUG] statebag injury      = ' .. tostring(Player(GetPlayerServerId(bestIdx)).state.injury))
        print('[SAMU DEBUG] IsEntityDead         = ' .. tostring(IsEntityDead(best)))
        print('[SAMU DEBUG] IsPedRagdoll         = ' .. tostring(IsPedRagdoll(best)))
        print('[SAMU DEBUG] IsPedAPlayer         = ' .. tostring(IsPedAPlayer(best)))
    else
        print('[SAMU DEBUG] aucune cible joueur à proximité')
    end
    print('[SAMU DEBUG] ------------------------------')
end, false)

exports.ox_target:addGlobalPlayer({
    {
        name = 'samu_bag',
        icon = 'fa-solid fa-suitcase-medical',
        label = Lang.SAMU.action_bag,
        distance = Config.SAMU.Actions.interactionRange,
        canInteract = function(entity)
            return SAMU.IsOnDuty() and entity ~= PlayerPedId()
        end,
        onSelect = function(data)
            local targetSrc = GetServerIdFromPed(data.entity)
            if not targetSrc then return end
            if HasCooldown('bag') then Notify(Lang.SAMU.action_cooldown, 'error') return end
            SetCooldown('bag')
            SAMU.OpenHealthInspection(targetSrc)
        end,
    },
    {
        name = 'samu_revive',
        icon = 'fa-solid fa-heart-pulse',
        label = Lang.SAMU.action_revive,
        distance = Config.SAMU.Actions.interactionRange,
        canInteract = function(entity)
            if not SAMU.IsOnDuty() or entity == PlayerPedId() then return false end
            -- N'afficher "Réanimer" que sur un patient réellement à terre :
            -- le serveur refusait déjà l'action sur un joueur conscient, mais
            -- le bouton s'affichait quand même, sans rien indiquer d'utile.
            -- L'état vient du statebag répliqué par la victime
            -- (client/player/injury.lua) ; la santé ne sert que de repli le
            -- temps que la réplication arrive.
            local playerIndex = NetworkGetPlayerIndexFromPed(entity)
            if playerIndex then
                local state = Player(GetPlayerServerId(playerIndex)).state.injury
                if state == 'ko' or state == 'coma' then return true end
                if state == false then return false end
            end
            return GetEntityHealth(entity) <= Config.SAMU.Actions.downedHealthThreshold
        end,
        onSelect = function(data)
            local targetSrc = GetServerIdFromPed(data.entity)
            if not targetSrc then return end
            Revive(targetSrc)
        end,
    },
})
