--  MODULE SAMU — Actions de soins (serveur)
--  Validation stricte : job/grade depuis ServerPlayers, jamais client

local function GetPlayer(src)   return LSLegacy.Players.Get(src) end
local function IsSamu(src)      return LSLegacy.Jobs.Is(GetPlayer(src), Config.SAMU.Job) end
local function GetGrade(src)    return GetPlayer(src) and tonumber(LSLegacy.Jobs.GetGrade(GetPlayer(src))) or 0 end

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'SAMU', msg, t or 'info', 5000)
end

local function HasPermission(src, perm)
    return LSLegacy.MDT.HasPermission('samu', GetGrade(src), perm)
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
        ('[SAMU] État "%s" resynchronisé depuis le statebag pour le joueur %d'):format(state, target)
    )
    return true
end

--  HEALTH INSPECTION — mannequin par membre, trousse de soins

LSLegacy.Events.Register('samu:hi:open', function(data)
    local src = source
    if not IsSamu(src) or not IsSamuOnDuty(src) then return end
    if not data or not data.target then return end
    local target = tonumber(data.target)
    local targetPlayer = GetPlayer(target)
    local samuPlayer   = GetPlayer(src)
    if not targetPlayer or not samuPlayer then return end
    local targetPed = GetPlayerPed(target)
    if not DoesEntityExist(targetPed) then return end

    if not targetPlayer.wounds then LSLegacy.Injury.InitWounds(target) end

    local supplies = {}
    for itemName in pairs(Config.SAMU.HealthInspection.Items) do
        local owned = LSLegacy.Inventory.GetInventoryItem(samuPlayer, itemName)
        supplies[itemName] = owned and owned.count or 0
    end

    TriggerClientEvent('samu:hi:openResult', src, {
        success = true,
        target = target,
        parts = LSLegacy.Injury.GetWounds(target),
        overallHealthPct = math.max(0, math.min(100, GetEntityHealth(targetPed) - 100)),
        supplies = supplies,
        itemDefs = Config.SAMU.HealthInspection.Items,
        injuryLabels = Config.SAMU.HealthInspection.InjuryLabels,
        bodyPartLabels = Config.SAMU.HealthInspection.BodyPartLabels,
    })
end)

LSLegacy.Events.Register('samu:hi:useItem', function(data)
    local src = source
    if not IsSamu(src) or not IsSamuOnDuty(src) then return end
    if not data or not data.target or not data.item or not LSLegacy.Injury.IsValidPart(data.part) then return end
    local target       = tonumber(data.target)
    local itemName     = data.item
    local targetPlayer = GetPlayer(target)
    local samuPlayer   = GetPlayer(src)
    if not targetPlayer or not samuPlayer then return end

    local itemDef = Config.SAMU.HealthInspection.Items[itemName]
    if not itemDef then return end

    if IsDowned(target, targetPlayer) then
        TriggerClientEvent('samu:hi:useItemResult', src, { success = false, reason = 'unconscious' })
        return
    end

    local owned = LSLegacy.Inventory.GetInventoryItem(samuPlayer, itemName)
    if not owned or owned.count <= 0 then
        TriggerClientEvent('samu:hi:useItemResult', src, { success = false, reason = 'missing_item', item = itemName })
        return
    end

    local targetPed = GetPlayerPed(target)
    if not DoesEntityExist(targetPed) then return end

    local current = GetEntityHealth(targetPed)
    if current >= 200 then
        TriggerClientEvent('samu:hi:useItemResult', src, { success = false, reason = 'full_health' })
        return
    end

    LSLegacy.Inventory.RemoveItemInInventory(samuPlayer, itemName, 1)
    LSLegacy.Injury.ApplyTreatment(target, data.part, itemDef)
    SetEntityHealth(targetPed, math.min(200, current + itemDef.heal))

    local owned2 = LSLegacy.Inventory.GetInventoryItem(samuPlayer, itemName)
    TriggerClientEvent('samu:hi:useItemResult', src, {
        success = true,
        part = data.part,
        item = itemName,
        label = itemDef.label,
        parts = LSLegacy.Injury.GetWounds(target),
        overallHealthPct = math.max(0, math.min(100, GetEntityHealth(targetPed) - 100)),
        remainingCount = owned2 and owned2.count or 0,
    })
    TriggerClientEvent('samu:treatedByEms', target, itemDef.label)
end)

LSLegacy.Events.Register('samu:hi:poll', function(data)
    local src = source
    if not data or not data.reqId then return end
    local result = false
    if IsSamu(src) and IsSamuOnDuty(src) and data.target then
        local target = tonumber(data.target)
        local targetPed = GetPlayerPed(target)
        if targetPed and DoesEntityExist(targetPed) then
            result = {
                parts = LSLegacy.Injury.GetWounds(target),
                overallHealthPct = math.max(0, math.min(100, GetEntityHealth(targetPed) - 100)),
            }
        end
    end
    TriggerClientEvent('samu:hi:pollResult', src, { reqId = data.reqId, result = result })
end)

--  RÉASSORT DE LA TROUSSE (Centre Médical)

LSLegacy.Events.Register('samu:restock', function()
    local src = source
    if not IsSamu(src) or not IsSamuOnDuty(src) then return end
    local samuPlayer = GetPlayer(src)
    if not samuPlayer then return end

    local now  = os.time()
    local last = samuPlayer.lastSamuRestock or 0
    if (now - last) < Config.SAMU.RestockCooldown then
        TriggerClientEvent('samu:restockResult', src, { success = false })
        return
    end
    samuPlayer.lastSamuRestock = now

    for itemName, qty in pairs(Config.SAMU.RestockItems) do
        LSLegacy.Inventory.AddItemInInventory(samuPlayer, itemName, qty)
    end

    TriggerClientEvent('samu:restockResult', src, { success = true })
end)

--  RÉANIMER (sortie de KO / coma)

LSLegacy.Events.Register('samu:revive', function(data)
    local src = source
    if not IsSamu(src) or not IsSamuOnDuty(src) then return end
    if not HasPermission(src, 'revive_player') then
        Notify(src, 'Votre grade est insuffisant pour réanimer.', 'error')
        return
    end
    if not data or not data.target then return end
    local target = tonumber(data.target)
    local targetPlayer = GetPlayer(target)
    if not targetPlayer then return end

    if not IsDowned(target, targetPlayer) then
        TriggerClientEvent('samu:reviveResult', src, { success = false })
        return
    end

    LSLegacy.Injury.ClearState(target, Config.SAMU.Actions.reviveHealth)

    TriggerClientEvent('samu:reviveResult', src, { success = true })
    TriggerClientEvent('samu:revivedByEms', target)
end)
