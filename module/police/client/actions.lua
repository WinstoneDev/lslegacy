--  MODULE POLICE NATIONALE — Actions policières (client)
--  Toutes les actions sont validées côté SERVEUR.
--  Ciblage : ox_target (ALT sur un joueur) — Menus : ox_lib (context)

local Actions   = {}
local cooldowns = {}

local function Notify(msg, type)
    TriggerEvent(Config.Police.NotifyEvent, 'Police Nationale', msg,
        Config.Police.NotifyDuration or 30000, type or 'info')
end

-- Anti-abus cooldown

local function HasCooldown(action)
    if not cooldowns[action] then return false end
    return (GetGameTimer() - cooldowns[action]) < (Config.Police.Actions.cooldowns[action] or 3000)
end

local function SetCooldown(action)
    cooldowns[action] = GetGameTimer()
end

-- Conversion ped ciblé → id serveur (global — partagé avec investigation.lua)

function GetServerIdFromPed(ped)
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

--  ACTION : MENOTTER

Actions.Cuff = function(targetSrc, targetPed)
    if HasCooldown('cuff') then Notify(Lang.Police.action_cooldown, 'error') return end
    SetCooldown('cuff')

    -- Animation menottage
    local dict = 'mp_arresting'
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do Wait(100); t = t + 1 end

    -- Notifier la cible pour geler ses contrôles pendant l'animation
    LSLegacy.Events.SendToServer('police:cuffStart', {
        target   = targetSrc,
        duration = Config.Police.Actions.cuffDuration,
    })

    TaskPlayAnim(PlayerPedId(), dict, 'a_uncuff', 8.0, -8.0,
        Config.Police.Actions.cuffDuration, 49, 0, false, false, false)
    TaskPlayAnim(targetPed, dict, 'b_uncuff', 8.0, -8.0,
        Config.Police.Actions.cuffDuration, 49, 0, false, false, false)

    Wait(Config.Police.Actions.cuffDuration)
    ClearPedTasks(PlayerPedId())

    LSLegacy.Events.SendToServer('police:cuff', { target = targetSrc, cuffed = true })

end

Actions.Uncuff = function(targetSrc)
    if HasCooldown('cuff') then Notify(Lang.Police.action_cooldown, 'error') return end
    SetCooldown('cuff')
    local dict = 'mp_arresting'
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do Wait(100); t = t + 1 end

    TaskPlayAnim(PlayerPedId(), dict, 'a_uncuff', 8.0, -8.0,
        Config.Police.Actions.cuffDuration, 49, 0, false, false, false)
    Wait(Config.Police.Actions.cuffDuration)
    ClearPedTasks(PlayerPedId())

    LSLegacy.Events.SendToServer('police:cuff', { target = targetSrc, cuffed = false })

end

--  ACTION : FOUILLE (inventaire)

Actions.Search = function(targetSrc)
    if HasCooldown('search') then Notify(Lang.Police.action_cooldown, 'error') return end
    SetCooldown('search')
    Notify(Lang.Police.search_start, 'info')

    PlayAnim('amb@world_human_cop_idles@male@idle_a', 'idle_b',
        Config.Police.Actions.searchDuration, 49)

    LSLegacy.Events.SendToServer('police:search', { target = targetSrc })

end

-- Helper : vérifie si un item est saisissable selon les préfixes config
local function IsSeizable(itemName)
    for _, prefix in ipairs(Config.Police.Actions.seizablePrefixes) do
        if string.sub(itemName, 1, #prefix) == prefix then
            return true
        end
    end
    return false
end

local searchItems  = {}
local searchTarget = nil

local function OpenSearchMenu()
    if #searchItems == 0 then lib.hideContext() return end

    local options = {}
    for _, item in ipairs(searchItems) do
        local seizable = IsSeizable(item.name)
        options[#options + 1] = {
            title = item.label .. ' x' .. item.count,
            description = seizable and 'Saisir' or 'Non saisissable',
            icon = 'fa-solid fa-box',
            disabled = not seizable,
            onSelect = function()
                LSLegacy.Events.SendToServer('police:seizeItem', {
                    target   = searchTarget,
                    itemName = item.name,
                    count    = item.count,
                })
            end,
        }
    end

    lib.registerContext({ id = 'police_search', title = "Fouille complète — Inventaire de l'individu", options = options })
    lib.showContext('police_search')
end

LSLegacy.Events.Register('police:searchResult', function(data)
    if not data then return end
    if data.items and #data.items > 0 then
        searchItems  = data.items
        searchTarget = data.target
        OpenSearchMenu()
    else
        Notify(Lang.Police.search_empty, 'success')
    end
end)

--  ACTION : PALPATION DE SÉCURITÉ

Actions.Palpation = function(targetSrc)
    if HasCooldown('palpation') then Notify(Lang.Police.action_cooldown, 'error') return end
    SetCooldown('palpation')
    Notify(Lang.Police.palpation_start, 'info')

    PlayAnim('amb@world_human_cop_idles@male@idle_a', 'idle_c',
        Config.Police.Actions.palpationDuration, 49)

    LSLegacy.Events.SendToServer('police:palpation', { target = targetSrc })

end

local palpationWeapons = {}
local palpationTarget  = nil

local function OpenPalpationMenu()
    if #palpationWeapons == 0 then lib.hideContext() return end

    local options = {}
    for _, w in ipairs(palpationWeapons) do
        options[#options + 1] = {
            title = w.label,
            description = 'Saisir cette arme',
            icon = 'fa-solid fa-gun',
            onSelect = function()
                LSLegacy.Events.SendToServer('police:seizeItem', {
                    target   = palpationTarget,
                    itemName = w.name,
                    count    = w.count,
                })
            end,
        }
    end

    lib.registerContext({ id = 'police_palpation', title = 'Palpation de sécurité — Armes détectées', options = options })
    lib.showContext('police_palpation')
end

LSLegacy.Events.Register('police:palpationResult', function(data)
    if not data then return end
    if data.armed and data.weapons and #data.weapons > 0 then
        Notify(Lang.Police.palpation_armed, 'error')
        palpationWeapons = data.weapons
        palpationTarget  = data.target
        OpenPalpationMenu()
    else
        Notify(Lang.Police.palpation_clean, 'success')
    end
end)

--  ACTION : CONTRÔLE D'IDENTITÉ

Actions.IdCheck = function(targetSrc)
    if HasCooldown('id_check') then Notify(Lang.Police.action_cooldown, 'error') return end
    SetCooldown('id_check')
    Notify(Lang.Police.id_check_start, 'info')

    PlayAnim('amb@world_human_cop_idles@male@idle_a', 'idle_d',
        Config.Police.Actions.idCheckDuration, 49)

    LSLegacy.Events.SendToServer('police:idCheck', { target = targetSrc })

end

LSLegacy.Events.Register('police:idCheckResult', function(data)
    if not data then return end
    if data.hasId then
        TriggerEvent(Config.Police.NotifyEvent, 'Police Nationale',
            string.format(Lang.Police.id_result, data.name, data.dob, data.height),
            Config.Police.NotifyDuration or 30000, 'info')
    else
        Notify(Lang.Police.no_id, 'warning')
    end
end)

--  ACTION : VÉRIFICATION PERMIS DE CONDUIRE

Actions.LicenseCheck = function(targetSrc)
    if HasCooldown('id_check') then Notify(Lang.Police.action_cooldown, 'error') return end
    SetCooldown('id_check')
    Notify(Lang.Police.license_check_start, 'info')

    PlayAnim('amb@world_human_cop_idles@male@idle_a', 'idle_d',
        Config.Police.Actions.licenseCheckDuration, 49)

    LSLegacy.Events.SendToServer('police:licenseCheck', { target = targetSrc })
end

LSLegacy.Events.Register('police:licenseCheckResult', function(data)
    if not data then return end
    if data.valid then
        Notify(string.format(Lang.Police.license_valid, data.name), 'success')
    else
        Notify(Lang.Police.license_invalid, 'warning')
    end
end)

--  ACTION : ESCORTE

local escortTarget = nil

Actions.Escort = function(targetSrc)
    if HasCooldown('escort') then Notify(Lang.Police.action_cooldown, 'error') return end
    SetCooldown('escort')
    escortTarget = targetSrc
    LSLegacy.Events.SendToServer('police:escort', { target = targetSrc, active = true })

    local targetName = GetPlayerName(GetPlayerFromServerId(targetSrc)) or '?'
    Notify(string.format(Lang.Police.escort_start, targetName), 'success')

end

RegisterCommand('police_escort_stop', function()
    if not LSLegacy.MDT.IsLocalLeoOnDuty() or not escortTarget then return end
    LSLegacy.Events.SendToServer('police:escort', { target = escortTarget, active = false })
    escortTarget = nil
    Notify(Lang.Police.escort_stop, 'info')
end, false)

RegisterKeyMapping('police_escort_stop', "Arrêter l'escorte (Police)", 'keyboard', 'F9')

-- Cible de l'escorte : suit l'officier
local isEscorted   = false
local escortOfficer = nil

LSLegacy.Events.Register('police:escortedBy', function(data)
    if not data then return end
    if data.active then
        Notify(Lang.Police.escorted_by, 'info')
        isEscorted    = true
        escortOfficer = GetPlayerPed(GetPlayerFromServerId(data.officer))
        Citizen.CreateThread(function()
            while isEscorted do
                local myPed = PlayerPedId()
                local ofPos = GetEntityCoords(escortOfficer)
                local myPos = GetEntityCoords(myPed)
                if #(ofPos - myPos) > 2.5 then
                    TaskGoToCoordAnyMeans(myPed, ofPos.x, ofPos.y, ofPos.z, 1.5, 0, 0, 786603, 0xbf800000)
                end
                Wait(500)
            end
        end)
    else
        isEscorted    = false
        escortOfficer = nil
        Notify('Escorte terminée.', 'info')
        ClearPedTasks(PlayerPedId())
    end
end)

--  ACTION : MISE EN VÉHICULE / SORTIE

Actions.PutInVehicle = function(targetSrc)
    -- Trouver le véhicule de police le plus proche
    local ped    = PlayerPedId()
    local pos    = GetEntityCoords(ped)
    local veh    = GetVehiclePedIsIn(ped, false)

    if not DoesEntityExist(veh) or veh == 0 then
        -- Cherche un véhicule proche
        local closestVeh = 0
        local closestDist = 3.0
        for _, netVeh in ipairs(GetGamePool('CVehicle')) do
            local vPos = GetEntityCoords(netVeh)
            local dist = #(pos - vPos)
            if dist < closestDist then
                closestDist = dist
                closestVeh  = netVeh
            end
        end
        veh = closestVeh
    end

    if not DoesEntityExist(veh) or veh == 0 then
        Notify(Lang.Police.no_police_veh, 'error')
        return
    end

    LSLegacy.Events.SendToServer('police:putInVehicle', {
        target  = targetSrc,
        vehNet  = NetworkGetNetworkIdFromEntity(veh),
        seat    = 2, -- arrière droit
    })

end

Actions.GetOutVehicle = function()
    if not LSLegacy.MDT.IsLocalLeoOnDuty() then Notify(Lang.Police.not_police, 'error') return end

    -- Rayon élargi à 2 m pour atteindre un passager dans le véhicule
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local targetSrc, closestDist = nil, 3.0
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local d = #(pos - GetEntityCoords(GetPlayerPed(pid)))
            if d < closestDist then
                closestDist = d
                targetSrc   = GetPlayerServerId(pid)
            end
        end
    end
    if not targetSrc then Notify(Lang.Police.no_target, 'error') return end

    LSLegacy.Events.SendToServer('police:getOutVehicle', { target = targetSrc })

end

RegisterCommand('police_get_out_vehicle', function()
    Actions.GetOutVehicle()
end, false)

RegisterKeyMapping('police_get_out_vehicle', 'Sortir un passager du véhicule (Police)', 'keyboard', 'F10')

-- Handler : être placé dans un véhicule par un policier
LSLegacy.Events.Register('police:forcePutInVehicle', function(data)
    if not data then return end
    local veh  = NetToVeh(data.vehNet)
    if not DoesEntityExist(veh) then return end
    local ped  = PlayerPedId()
    local seat = data.seat or 2

    ClearPedTasksImmediately(ped)
    -- Ouvre la porte et joue l'animation d'entrée naturelle
    TaskEnterVehicle(ped, veh, -1, seat, 1.0, 0, 0)

    Notify('Vous avez été placé(e) dans le véhicule.', 'info')
end)

LSLegacy.Events.Register('police:forceGetOutVehicle', function()
    TaskLeaveVehicle(PlayerPedId(), GetVehiclePedIsIn(PlayerPedId(), false), 4160)
    Notify('Vous avez été sorti(e) du véhicule.', 'info')
end)

-- Nettoyage arme saisie : retire du ped + fast slots + DataStore
LSLegacy.Events.Register('police:clearWeapon', function(data)
    if not data or not data.itemName then return end
    prepareWeaponTransfer(data.itemName, nil)
end)

--  ACTION : SAISIE D'OBJET

Actions.SeizeItem = function(targetSrc)
    -- Ouvre un clavier pour saisir le nom de l'item
    local itemName = LSLegacy.KeyboardInput('Nom de l\'objet à saisir', 30)
    if not itemName or itemName == '' then return end

    PlayAnim('amb@world_human_cop_idles@male@idle_a', 'idle_b',
        Config.Police.Actions.seizeItemDuration, 49)

    LSLegacy.Events.SendToServer('police:seizeItem', {
        target   = targetSrc,
        itemName = string.lower(itemName),
        count    = 1,
    })

end

local function RemoveFromList(list, itemName)
    for i = #list, 1, -1 do
        if list[i].name == itemName then
            table.remove(list, i)
            return
        end
    end
end

LSLegacy.Events.Register('police:seizeResult', function(data)
    if not data then return end
    if data.success then
        Notify(string.format(Lang.Police.seize_item, data.label, data.count), 'success')
        if data.itemName then
            -- Retirer de la liste palpation
            RemoveFromList(palpationWeapons, data.itemName)
            if #palpationWeapons == 0 then
                lib.hideContext()
            else
                OpenPalpationMenu()
            end
            -- Retirer de la liste fouille
            RemoveFromList(searchItems, data.itemName)
            if #searchItems == 0 then
                lib.hideContext()
            else
                OpenSearchMenu()
            end
        end
    else
        Notify(Lang.Police.seize_nothing, 'warning')
    end
end)

--  ACTION : AMENDE

Actions.Fine = function(targetSrc)
    local reason = LSLegacy.KeyboardInput('Motif de l\'amende', 80)
    if not reason or reason == '' then return end
    local amountStr = LSLegacy.KeyboardInput('Montant ($)', 6)
    local amount    = tonumber(amountStr)
    if not amount or amount <= 0 then Notify('Montant invalide.', 'error') return end

    if amount > Config.MDT.Limits.MaxFine then
        Notify('Montant supérieur au plafond autorisé (' .. Config.MDT.Limits.MaxFine .. '$).', 'error')
        return
    end

    LSLegacy.Events.SendToServer('mdt:createFine', {
        target      = targetSrc,
        reason      = reason,
        amount      = amount,
        department  = 'police',
    })

    Notify(string.format(Lang.Police.fine_sent, amount), 'success')

end

--  ACTION : GARDE À VUE

Actions.PlaceCustody = function(targetSrc)
    if not LSLegacy.MDT.HasPermission('police', Police.GetGrade(), 'manage_custody') then
        Notify(Lang.Police.grade_required, 'error')
        return
    end

    local reason = LSLegacy.KeyboardInput('Motif de la garde à vue', 120)
    if not reason or reason == '' then return end
    local durationStr = LSLegacy.KeyboardInput('Durée (minutes, max 240)', 3)
    local duration    = math.min(tonumber(durationStr) or 30, 240)

    LSLegacy.Events.SendToServer('police:custody', {
        target   = targetSrc,
        reason   = reason,
        duration = duration,
    })

    Notify(Lang.Police.custody_placed, 'success')

end

--  ACTION : INCARCÉRATION

Actions.SendToPrison = function(targetSrc)
    if not LSLegacy.MDT.HasPermission('police', Police.GetGrade(), 'manage_custody') then
        Notify(Lang.Police.grade_required, 'error')
        return
    end

    local reason      = LSLegacy.KeyboardInput('Chef d\'inculpation', 120)
    if not reason or reason == '' then return end
    local durationStr = LSLegacy.KeyboardInput('Durée de peine (minutes, max 720)', 3)
    local duration    = math.min(tonumber(durationStr) or 30, 720)

    LSLegacy.Events.SendToServer('police:prison', {
        target   = targetSrc,
        reason   = reason,
        duration = duration,
    })

    Notify(string.format(Lang.Police.prison_sent, duration), 'success')

end

--  CIBLAGE OX_TARGET — Touche ALT sur un joueur

local function CanInteract(entity)
    return LSLegacy.MDT.IsLocalLeoOnDuty() and entity ~= PlayerPedId()
end

exports.ox_target:addGlobalPlayer({
    {
        name = 'police_id_check', icon = 'fa-solid fa-id-card', label = Lang.Police.action_id_check,
        distance = 2.0, canInteract = CanInteract,
        onSelect = function(data) Actions.IdCheck(GetServerIdFromPed(data.entity)) end,
    },
    {
        name = 'police_license', icon = 'fa-solid fa-id-badge', label = Lang.Police.action_license,
        distance = 2.0, canInteract = CanInteract,
        onSelect = function(data) Actions.LicenseCheck(GetServerIdFromPed(data.entity)) end,
    },
    {
        name = 'police_palpation', icon = 'fa-solid fa-hands', label = Lang.Police.action_palpation,
        distance = 2.0, canInteract = CanInteract,
        onSelect = function(data) Actions.Palpation(GetServerIdFromPed(data.entity)) end,
    },
    {
        name = 'police_search', icon = 'fa-solid fa-magnifying-glass', label = Lang.Police.action_search,
        distance = 2.0, canInteract = CanInteract,
        onSelect = function(data) Actions.Search(GetServerIdFromPed(data.entity)) end,
    },
    {
        name = 'police_cuff', icon = 'fa-solid fa-handcuffs', label = Lang.Police.action_cuff,
        distance = 2.0, canInteract = CanInteract,
        onSelect = function(data) Actions.Cuff(GetServerIdFromPed(data.entity), data.entity) end,
    },
    {
        name = 'police_uncuff', icon = 'fa-solid fa-unlock', label = Lang.Police.action_uncuff,
        distance = 2.0, canInteract = CanInteract,
        onSelect = function(data) Actions.Uncuff(GetServerIdFromPed(data.entity)) end,
    },
    {
        name = 'police_escort', icon = 'fa-solid fa-person-walking-arrow-right', label = Lang.Police.action_escort_start,
        distance = 2.0, canInteract = CanInteract,
        onSelect = function(data) Actions.Escort(GetServerIdFromPed(data.entity)) end,
    },
    {
        name = 'police_put_in_veh', icon = 'fa-solid fa-car-side', label = Lang.Police.action_put_in_veh,
        distance = 2.0, canInteract = CanInteract,
        onSelect = function(data) Actions.PutInVehicle(GetServerIdFromPed(data.entity)) end,
    },
    {
        name = 'police_seize', icon = 'fa-solid fa-box-open', label = Lang.Police.action_seize,
        distance = 2.0, canInteract = CanInteract,
        onSelect = function(data) Actions.SeizeItem(GetServerIdFromPed(data.entity)) end,
    },
    {
        name = 'police_fine', icon = 'fa-solid fa-money-bill', label = Lang.Police.action_fine,
        distance = 2.0, canInteract = CanInteract,
        onSelect = function(data) Actions.Fine(GetServerIdFromPed(data.entity)) end,
    },
    {
        name = 'police_custody', icon = 'fa-solid fa-jail', label = Lang.Police.action_custody,
        distance = 2.0, canInteract = CanInteract,
        onSelect = function(data) Actions.PlaceCustody(GetServerIdFromPed(data.entity)) end,
    },
    {
        name = 'police_prison', icon = 'fa-solid fa-building-shield', label = 'Incarcérer (Bolingbroke)',
        distance = 2.0, canInteract = CanInteract,
        onSelect = function(data) Actions.SendToPrison(GetServerIdFromPed(data.entity)) end,
    },
})

--  MENOTTES — État client (affichage + restriction mouvements)

local isCuffed = false
LSLegacy.IsCuffed = false  -- flag accessible à tous les scripts du même contexte Lua

LSLegacy.Events.Register('police:setCuffed', function(state)
    isCuffed          = state
    LSLegacy.IsCuffed = state
    if state then
        Notify(Lang.Police.cuffed, 'error')
    else
        Notify(Lang.Police.uncuffed, 'success')
        ClearPedTasks(PlayerPedId())
    end
end)

-- Boucle de restriction si menotté
Citizen.CreateThread(function()
    while true do
        if isCuffed then
            local ped = PlayerPedId()

            DisableControlAction(0, 24, true)   -- Attaque
            DisableControlAction(0, 25, true)   -- Viser
            DisableControlAction(0, 47, true)   -- Roue armes
            DisableControlAction(0, 58, true)   -- Arme 2
            DisableControlAction(0, 22, true)   -- Sauter
            DisableControlAction(0, 44, true)   -- Couverture
            DisableControlAction(0, 23, true)   -- Entrer/sortir véhicule (sol)
            DisableControlAction(0, 75, true)   -- Sortir véhicule (INPUT_VEH_EXIT)

            -- Empêcher de conduire : éjecter uniquement si siège conducteur
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                if GetPedInVehicleSeat(veh, -1) == ped then
                    TaskLeaveVehicle(ped, veh, 4160)
                end
            end

            -- Animation menottes en boucle (hors véhicule, pas pendant l'entrée)
            local enteringVeh = GetVehiclePedIsTryingToEnter(ped)
            if not IsPedInAnyVehicle(ped, false) and enteringVeh == 0 and
               not IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) then
                TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Gèle les contrôles de la cible pendant l'animation de menottage
LSLegacy.Events.Register('police:cuffAnimation', function(data)
    if not data then return end
    local duration = data.duration or 3000
    local ped      = PlayerPedId()

    RequestAnimDict('mp_arresting')
    local t = 0
    while not HasAnimDictLoaded('mp_arresting') and t < 50 do Wait(100); t = t + 1 end
    TaskPlayAnim(ped, 'mp_arresting', 'b_uncuff', 8.0, -8.0, duration, 49, 0, false, false, false)

    local endTime = GetGameTimer() + duration
    Citizen.CreateThread(function()
        while GetGameTimer() < endTime do
            DisableControlAction(0, 30, true)  -- Déplacement G/D
            DisableControlAction(0, 31, true)  -- Déplacement H/B
            DisableControlAction(0, 21, true)  -- Sprint
            DisableControlAction(0, 22, true)  -- Sauter
            DisableControlAction(0, 44, true)  -- Couverture
            Wait(0)
        end
    end)
end)
