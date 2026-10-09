--  MODULE EMS — Actions de soins (client)
--  Toutes les actions sont validées côté SERVEUR.
--  Ciblage : ox_target (ALT sur un joueur) — Menus : ox_lib (context)

local cooldowns = {}

local function Notify(msg, type)
    TriggerEvent('notify', 'Emergency Medical Services', msg, type or 'info', 5000)
end

-- Anti-abus cooldown

local function HasCooldown(action)
    if not cooldowns[action] then return false end
    return (GetGameTimer() - cooldowns[action]) < (Config.EMS.Actions.cooldowns[action] or 3000)
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

-- fallbackDict/fallbackAnim : si `dict` ne charge pas dans les 5s (dict
-- introuvable/non streamable en dehors de son contexte d'origine), on bascule
-- sur un anim dict "sûr" plutôt que de laisser le joueur planté debout sans
-- rien jouer (TaskPlayAnim sur un dict non chargé ne fait strictement rien).
local function PlayAnim(dict, anim, duration, flag, fallbackDict, fallbackAnim)
    flag = flag or 49

    local function TryLoad(d)
        RequestAnimDict(d)
        local t = 0
        while not HasAnimDictLoaded(d) and t < 50 do
            Wait(100); t = t + 1
        end
        return HasAnimDictLoaded(d)
    end

    if not TryLoad(dict) then
        if not fallbackDict or not TryLoad(fallbackDict) then return end
        dict, anim = fallbackDict, fallbackAnim
    end

    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, duration, flag, 0, false, false, false)
    Wait(duration)
    ClearPedTasks(PlayerPedId())
end

--  TROUSSE DE SOINS — voir module/ems/client/health_inspection.lua
--  (EMS.OpenHealthInspection, ouverte via la cible ems_bag ci-dessous)

--  RÉANIMER (sortie de KO/coma)

-- L'anim de RCP est chorégraphiée pour un soignant collé au patient, face à
-- lui — jouée depuis une position/angle quelconques (cible juste à portée
-- ox_target) elle rend mal (mains qui ratent le torse, geste "debout").
-- On recolle donc le joueur au patient avant de la lancer.
local function PositionForCPR(targetPed)
    if LSLegacy.Anticheat then LSLegacy.Anticheat.AllowTeleport() end
    local ped = PlayerPedId()
    local t = GetEntityCoords(targetPed)
    local m = GetEntityCoords(ped)
    local dx, dy = t.x - m.x, t.y - m.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 0.05 then
        local nx, ny = dx / dist, dy / dist
        SetEntityCoords(ped, t.x - nx * 0.45, t.y - ny * 0.45, t.z, false, false, false, true)
    else
        SetEntityCoords(ped, t.x, t.y, t.z, false, false, false, true)
    end
    local now = GetEntityCoords(ped)
    SetEntityHeading(ped, GetHeadingFromVector_2d(t.x - now.x, t.y - now.y))
    Wait(50)
end

local function Revive(targetSrc, targetPed)
    if not LSLegacy.MDT.HasPermission('ems', EMS.GetGrade(), 'revive_player') then
        Notify(Lang.EMS.grade_required, 'error')
        return
    end
    if HasCooldown('revive') then Notify(Lang.EMS.action_cooldown, 'error') return end
    SetCooldown('revive')
    Notify(Lang.EMS.revive_start, 'info')

    if targetPed and DoesEntityExist(targetPed) then
        PositionForCPR(targetPed)
    end

    -- Départ de l'anim côté patient EN MÊME TEMPS que la nôtre : 'ems:revive'
    -- (plus bas) n'arrive au serveur qu'une fois notre propre anim terminée
    -- (PlayAnim est bloquant), donc trop tard pour synchroniser sa pose.
    LSLegacy.Events.SendToServer('ems:reviveStartPose', { target = targetSrc })

    -- Anim "cprs3" du menu émotes (module/emotes/data/emotes_shared.lua) : RCP
    -- version paramedic, plus cohérente pour l'EMS que le mini@cpr générique.
    -- Repli sur l'ancienne anim mini@cpr si ce dict ne charge pas (constaté
    -- en jeu : joueur resté debout, dict probablement non streamable hors
    -- contexte mission).
    -- Flag 1 (juste LOOP) et non 49 : le menu émotes joue cette même anim
    -- avec flag 1 (module/emotes/client/main.lua, StartEmote) et s'accroupit
    -- normalement — avec 49 (bits supplémentaires en trop) le personnage
    -- restait debout, l'accroupissement ne se faisait pas.
    PlayAnim('missheistfbi3b_ig8_2', 'cpr_loop_paramedic', Config.EMS.Actions.reviveDuration, 1,
        'mini@cpr@char_a@cpr_str', 'cpr_pumpchest')

    LSLegacy.Events.SendToServer('ems:revive', { target = targetSrc })
end

-- Résultats serveur

LSLegacy.Events.Register('ems:reviveResult', function(data)
    if not data then return end
    if data.success then
        Notify(Lang.EMS.revive_done, 'success')
    elseif data.reason == 'not_treated' then
        Notify(Lang.EMS.not_treated, 'warning')
    else
        Notify(Lang.EMS.not_unconscious, 'warning')
    end
end)

LSLegacy.Events.Register('ems:revived', function()
    Notify(Lang.EMS.revived_by, 'success')
end)

LSLegacy.Events.Register('ems:treated', function(label)
    Notify(string.format('Les secours vous ont soigné : %s.', label or '?'), 'success')
end)

LSLegacy.Events.Register('ems:restockResult', function(data)
    if not data then return end
    if data.success then
        Notify(Lang.EMS.restock_done, 'success')
    else
        Notify(Lang.EMS.restock_cooldown, 'error')
    end
end)

--  CIBLAGE OX_TARGET — Touche ALT sur un joueur

-- Diagnostic
-- ox_target masque une option aussi bien quand canInteract renvoie false
-- que quand elle lève une erreur (client/main.lua : `not success or not resp`),
-- d'où l'absence totale de retour visuel quand une cible ne s'affiche pas.
-- Cette commande imprime l'état réel, côté agent et côté patient visé.
RegisterCommand('emsdebug', function()
    local ok, onDuty = pcall(function() return EMS.IsOnDuty() end)
    print('[EMS DEBUG] ------------------------------')
    print('[EMS DEBUG] type(EMS)            = ' .. type(EMS))
    print('[EMS DEBUG] type(EMS.IsOnDuty)   = ' .. (type(EMS) == 'table' and type(EMS.IsOnDuty) or 'n/a'))
    print('[EMS DEBUG] EMS.OnDuty           = ' .. tostring(type(EMS) == 'table' and EMS.OnDuty))
    print('[EMS DEBUG] IsOnDuty() ok         = ' .. tostring(ok) .. ' / valeur = ' .. tostring(onDuty))
    print('[EMS DEBUG] job                   = ' .. tostring(LSLegacy.PlayerData and LSLegacy.PlayerData.job))
    print('[EMS DEBUG] job_grade             = ' .. tostring(LSLegacy.PlayerData and LSLegacy.PlayerData.job_grade))
    print('[EMS DEBUG] Config.EMS.Job       = ' .. tostring(Config.EMS and Config.EMS.Job))
    print('[EMS DEBUG] distance configurée   = ' .. tostring(Config.EMS and Config.EMS.Actions and Config.EMS.Actions.interactionRange))

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
        print('[EMS DEBUG] --- cible la plus proche ---')
        print('[EMS DEBUG] server id            = ' .. tostring(GetPlayerServerId(bestIdx)))
        print('[EMS DEBUG] distance             = ' .. string.format('%.2f m', bestDist))
        print('[EMS DEBUG] santé                = ' .. tostring(GetEntityHealth(best)) .. ' (seuil à terre : ' .. tostring(Config.EMS.Actions.downedHealthThreshold) .. ')')
        print('[EMS DEBUG] statebag injury      = ' .. tostring(Player(GetPlayerServerId(bestIdx)).state.injury))
        print('[EMS DEBUG] IsEntityDead         = ' .. tostring(IsEntityDead(best)))
        print('[EMS DEBUG] IsPedRagdoll         = ' .. tostring(IsPedRagdoll(best)))
        print('[EMS DEBUG] IsPedAPlayer         = ' .. tostring(IsPedAPlayer(best)))
    else
        print('[EMS DEBUG] aucune cible joueur à proximité')
    end
    print('[EMS DEBUG] ------------------------------')
end, false)

exports.ox_target:addGlobalPlayer({
    {
        name = 'ems_bag',
        icon = 'fa-solid fa-suitcase-medical',
        label = Lang.EMS.action_bag,
        distance = Config.EMS.Actions.interactionRange,
        canInteract = function(entity)
            return EMS.IsOnDuty() and entity ~= PlayerPedId()
        end,
        onSelect = function(data)
            local targetSrc = GetServerIdFromPed(data.entity)
            if not targetSrc then return end
            if HasCooldown('bag') then Notify(Lang.EMS.action_cooldown, 'error') return end
            SetCooldown('bag')
            EMS.OpenHealthInspection(targetSrc)
        end,
    },
    {
        name = 'ems_revive',
        icon = 'fa-solid fa-heart-pulse',
        label = Lang.EMS.action_revive,
        distance = Config.EMS.Actions.interactionRange,
        canInteract = function(entity)
            if not EMS.IsOnDuty() or entity == PlayerPedId() then return false end
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
            return GetEntityHealth(entity) <= Config.EMS.Actions.downedHealthThreshold
        end,
        onSelect = function(data)
            local targetSrc = GetServerIdFromPed(data.entity)
            if not targetSrc then return end
            Revive(targetSrc, data.entity)
        end,
    },
})
