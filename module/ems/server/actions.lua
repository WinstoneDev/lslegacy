--  MODULE EMS — Actions de soins (serveur)
--  Validation stricte : job/grade depuis ServerPlayers, jamais client

local function GetPlayer(src)   return LSLegacy.Players.Get(src) end
local function IsEms(src)      return LSLegacy.Jobs.Is(GetPlayer(src), Config.EMS.Job) end
local function GetGrade(src)    return GetPlayer(src) and tonumber(LSLegacy.Jobs.GetGrade(GetPlayer(src))) or 0 end

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Emergency Medical Services', msg, t or 'info', 5000)
end

local function HasPermission(src, perm)
    return LSLegacy.MDT.HasPermission('ems', GetGrade(src), perm)
end

-- Le serveur suit l'état KO/coma via des events ponctuels
-- (lslegacy:injuryEnterComa) qui peuvent manquer : restart de ressource,
-- reconnexion, ou resumeComa qui ne le renvoie volontairement pas. Le patient
-- apparaissait alors inconscient à l'écran mais conscient pour le serveur —
-- donc "pas en détresse vitale" et impossible à réanimer. Le statebag
-- `injury`, republié en continu par la victime (client/player/injury.lua),
-- sert de repli et resynchronise l'état serveur au passage.
-- @param target number
-- @param targetPlayer table
-- @return boolean
local function IsDowned(target, targetPlayer)
    if targetPlayer.isKO or targetPlayer.isComa then return true end

    local state = Player(target).state.injury
    if state ~= 'ko' and state ~= 'coma' then return false end

    targetPlayer.isKO   = (state == 'ko')
    targetPlayer.isComa = (state == 'coma')
    Config.Development.Print(
        ('[EMS] État "%s" resynchronisé depuis le statebag pour le joueur %d'):format(state, target)
    )
    return true
end

--  HEALTH INSPECTION — mannequin par membre, trousse de soins

LSLegacy.Events.Register('ems:hiOpen', function(data)
    local src = source
    if not IsEms(src) or not IsEmsOnDuty(src) then return end
    if not data or not data.target then return end
    local target = tonumber(data.target)
    local targetPlayer = GetPlayer(target)
    local emsPlayer   = GetPlayer(src)
    if not targetPlayer or not emsPlayer then return end
    local targetPed = GetPlayerPed(target)
    if not DoesEntityExist(targetPed) then return end

    if not targetPlayer.wounds then LSLegacy.Injury.InitWounds(target) end

    local supplies = {}
    for itemName in pairs(Config.EMS.HealthInspection.Items) do
        local owned = LSLegacy.Inventory.GetInventoryItem(emsPlayer, itemName)
        supplies[itemName] = owned and owned.count or 0
    end

    TriggerClientEvent('ems:hiOpenResult', src, {
        success = true,
        target = target,
        parts = LSLegacy.Injury.GetWounds(target),
        overallHealthPct = math.max(0, math.min(100, GetEntityHealth(targetPed) - 100)),
        supplies = supplies,
        itemDefs = Config.EMS.HealthInspection.Items,
        injuryLabels = Config.EMS.HealthInspection.InjuryLabels,
        bodyPartLabels = Config.EMS.HealthInspection.BodyPartLabels,
    })
end)

LSLegacy.Events.Register('ems:hiUseItem', function(data)
    local src = source
    if not IsEms(src) or not IsEmsOnDuty(src) then return end
    if not data or not data.target or not data.item or not LSLegacy.Injury.IsValidPart(data.part) then return end
    local target       = tonumber(data.target)
    local itemName     = data.item
    local targetPlayer = GetPlayer(target)
    local emsPlayer   = GetPlayer(src)
    if not targetPlayer or not emsPlayer then return end

    local itemDef = Config.EMS.HealthInspection.Items[itemName]
    if not itemDef then return end

    -- Volontairement PAS de blocage sur IsDowned ici : le patient doit au
    -- contraire être soigné PENDANT le KO/coma, avant de pouvoir être
    -- réanimé (cf. ems:revive, qui exige LSLegacy.Injury.WasTreated).

    local owned = LSLegacy.Inventory.GetInventoryItem(emsPlayer, itemName)
    if not owned or owned.count <= 0 then
        TriggerClientEvent('ems:hiUseItemResult', src, { success = false, reason = 'missing_item', item = itemName })
        return
    end

    local targetPed = GetPlayerPed(target)
    if not DoesEntityExist(targetPed) then return end

    local current = GetEntityHealth(targetPed)
    if current >= 200 then
        TriggerClientEvent('ems:hiUseItemResult', src, { success = false, reason = 'full_health' })
        return
    end

    -- L'item doit traiter au moins une blessure réellement présente sur ce
    -- membre : sinon rien n'est consommé/soigné (cf. ApplyTreatment).
    if not LSLegacy.Injury.ApplyTreatment(target, data.part, itemDef) then
        TriggerClientEvent('ems:hiUseItemResult', src, { success = false, reason = 'wrong_treatment' })
        return
    end

    LSLegacy.Inventory.RemoveItemInInventory(emsPlayer, itemName, 1)

    local wounds = LSLegacy.Injury.GetWounds(target)
    local allHealed = true
    for _, p in ipairs(LSLegacy.Injury.BodyParts) do
        if not wounds[p] or wounds[p].hp < 100 then allHealed = false break end
    end

    if allHealed then
        -- Les 6 membres à 100% : on aligne la vraie vie GTA sur le maximum
        -- plutôt que de compter sur la somme des soins appliqués un à un —
        -- leurs montants ne collent pas forcément exactement au dégât réel
        -- encaissé (cf. ApplyTreatment), un patient "100% partout" pouvait
        -- donc rester avec des PV réels incomplets.
        SetEntityHealth(targetPed, 200)
    else
        SetEntityHealth(targetPed, math.min(200, current + itemDef.heal))
    end

    local owned2 = LSLegacy.Inventory.GetInventoryItem(emsPlayer, itemName)
    TriggerClientEvent('ems:hiUseItemResult', src, {
        success = true,
        part = data.part,
        item = itemName,
        label = itemDef.label,
        parts = wounds,
        overallHealthPct = math.max(0, math.min(100, GetEntityHealth(targetPed) - 100)),
        remainingCount = owned2 and owned2.count or 0,
    })
    TriggerClientEvent('ems:treated', target, itemDef.label)
end)

LSLegacy.Events.Register('ems:hiPoll', function(data)
    local src = source
    if not data or not data.reqId then return end
    local result = false
    if IsEms(src) and IsEmsOnDuty(src) and data.target then
        local target = tonumber(data.target)
        local targetPed = GetPlayerPed(target)
        if targetPed and DoesEntityExist(targetPed) then
            result = {
                parts = LSLegacy.Injury.GetWounds(target),
                overallHealthPct = math.max(0, math.min(100, GetEntityHealth(targetPed) - 100)),
            }
        end
    end
    TriggerClientEvent('ems:hiPollResult', src, { reqId = data.reqId, result = result })
end)

--  RÉASSORT DE LA TROUSSE (Centre Médical)

LSLegacy.Events.Register('ems:restock', function()
    local src = source
    if not IsEms(src) or not IsEmsOnDuty(src) then return end
    local emsPlayer = GetPlayer(src)
    if not emsPlayer then return end

    local now  = os.time()
    local last = emsPlayer.lastEmsRestock or 0
    if (now - last) < Config.EMS.RestockCooldown then
        TriggerClientEvent('ems:restockResult', src, { success = false })
        return
    end
    emsPlayer.lastEmsRestock = now

    for itemName, qty in pairs(Config.EMS.RestockItems) do
        LSLegacy.Inventory.AddItemInInventory(emsPlayer, itemName, qty)
    end

    TriggerClientEvent('ems:restockResult', src, { success = true })
end)

--  RÉANIMER (sortie de KO / coma)

-- Déclenché au tout début du geste côté client (avant de jouer l'anim, donc
-- AVANT le 'ems:revive' final qui n'arrive qu'une fois l'anim terminée côté
-- soignant) : sans ce relais séparé, le patient ne recevrait sa pose RCP
-- qu'après-coup, désynchronisée du geste du soignant.
LSLegacy.Events.Register('ems:reviveStartPose', function(data)
    local src = source
    if not IsEms(src) or not IsEmsOnDuty(src) then return end
    if not data or not data.target then return end
    local target = tonumber(data.target)
    local targetPlayer = GetPlayer(target)
    if not targetPlayer or not IsDowned(target, targetPlayer) then return end
    TriggerClientEvent('ems:revivePose', target, Config.EMS.Actions.reviveDuration)
end)

LSLegacy.Events.Register('ems:revive', function(data)
    local src = source
    if not IsEms(src) or not IsEmsOnDuty(src) then return end
    if not HasPermission(src, 'revive_player') then
        Notify(src, 'Votre grade est insuffisant pour réanimer.', 'error')
        return
    end
    if not data or not data.target then return end
    local target = tonumber(data.target)
    local targetPlayer = GetPlayer(target)
    if not targetPlayer then return end

    if not IsDowned(target, targetPlayer) then
        TriggerClientEvent('ems:reviveResult', src, { success = false })
        return
    end

    -- Le patient doit avoir reçu au moins un soin de la trousse (Health
    -- Inspection) avant de pouvoir être réanimé — pas de réanimation à froid.
    if not LSLegacy.Injury.WasTreated(target) then
        TriggerClientEvent('ems:reviveResult', src, { success = false, reason = 'not_treated' })
        return
    end

    LSLegacy.Injury.ClearState(target, Config.EMS.Actions.reviveHealth)

    TriggerClientEvent('ems:reviveResult', src, { success = true })
    TriggerClientEvent('ems:revived', target)
end)
