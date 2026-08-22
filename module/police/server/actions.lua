--  MODULE POLICE NATIONALE — Actions policières (serveur)
--  Validation stricte : job/grade depuis ServerPlayers, jamais client

local CuffedPlayers = {}    -- { [src] = { officer = officerSrc, time = ts } }
local EscortLinks   = {}    -- { [targetSrc] = officerSrc }

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Police Nationale', msg, t or 'info', Config.Police.NotifyDuration or 30000)
end

--  MENOTTAGE

-- Relaie le signal de début d'animation vers la cible
LSLegacy.Events.Register('police:cuffStart', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not data or not data.target then return end
    local target = tonumber(data.target)
    if not GetPlayer(target) then return end
    TriggerClientEvent('police:cuffAnimation', target, { duration = data.duration or 3000 })
end)

LSLegacy.Events.Register('police:cuff', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not data or not data.target then return end

    local target  = tonumber(data.target)
    if not GetPlayer(target) then return end

    if data.cuffed then
        if CuffedPlayers[target] then
            Notify(src, Lang.Police.already_cuffed, 'error')
            return
        end
        CuffedPlayers[target] = { officer = src, time = os.time() }
        TriggerClientEvent('police:setCuffed', target, true)
        Notify(src,    string.format(Lang.Police.cuffed_other, GetName(target)), 'success')
        Notify(target, Lang.Police.cuffed, 'error')
    else
        if not CuffedPlayers[target] then
            Notify(src, Lang.Police.not_cuffed, 'error')
            return
        end
        CuffedPlayers[target] = nil
        TriggerClientEvent('police:setCuffed', target, false)
        Notify(src,    string.format(Lang.Police.uncuffed_other, GetName(target)), 'success')
        Notify(target, Lang.Police.uncuffed, 'info')
    end
end)

--  FOUILLE

LSLegacy.Events.Register('police:search', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not data or not data.target then return end

    local target = tonumber(data.target)
    local tp     = GetPlayer(target)
    if not tp then return end

    local inventory = tp.inventory or {}
    local items     = {}
    for _, item in pairs(inventory) do
        if item and item.name and item.count and item.count > 0 then
            local label = (Config.Items and Config.Items[item.name] and Config.Items[item.name].label) or item.name
            table.insert(items, { name = item.name, label = label, count = item.count })
        end
    end

    TriggerClientEvent('police:searchResult', src, { items = items, target = target })
    Notify(target, 'Vous avez été fouillé(e) par un agent.', 'warning')
end)

--  PALPATION DE SÉCURITÉ

LSLegacy.Events.Register('police:palpation', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not data or not data.target then return end

    local target = tonumber(data.target)
    if not GetPlayer(target) then return end

    local tp        = GetPlayer(target)
    local inventory = tp.inventory or {}
    local weapons   = {}

    for _, item in pairs(inventory) do
        if item and item.name and item.count and item.count > 0 then
            if string.sub(item.name, 1, 7) == 'weapon_' then
                local meta  = Config.Items and Config.Items[item.name]
                local label = meta and meta.label or item.name
                table.insert(weapons, { name = item.name, label = label, count = item.count })
            end
        end
    end

    TriggerClientEvent('police:palpationResult', src, {
        armed   = #weapons > 0,
        weapons = weapons,
        target  = target,
    })
    Notify(target, 'Vous avez fait l\'objet d\'une palpation de sécurité.', 'warning')
end)

--  CONTRÔLE D'IDENTITÉ

LSLegacy.Events.Register('police:idCheck', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not data or not data.target then return end

    local target = tonumber(data.target)
    local tp     = GetPlayer(target)
    if not tp then return end

    local ci = tp.characterInfos
    if ci and ci.Prenom and ci.NDF and ci.DDN then
        TriggerClientEvent('police:idCheckResult', src, {
            hasId  = true,
            name   = (ci.Prenom or '?') .. ' ' .. (ci.NDF or '?'),
            dob    = ci.DDN   or '?',
            height = ci.Taille or '?',
        })
    else
        TriggerClientEvent('police:idCheckResult', src, { hasId = false })
    end
    Notify(target, 'Un agent a contrôlé votre identité.', 'info')
end)

--  CONTRÔLE PERMIS

LSLegacy.Events.Register('police:licenseCheck', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not data or not data.target then return end

    local target = tonumber(data.target)
    local tp     = GetPlayer(target)
    if not tp then return end

    -- On cherche un item "permis_conduire" dans l'inventaire
    local hasLicense = false
    local inv = tp.inventory or {}
    for _, item in pairs(inv) do
        if item and item.name == 'permis_conduire' and item.count and item.count > 0 then
            hasLicense = true
            break
        end
    end

    local ci  = tp.characterInfos
    local name = ci and (ci.Prenom or '') .. ' ' .. (ci.NDF or '') or '?'

    TriggerClientEvent('police:licenseCheckResult', src, {
        valid = hasLicense,
        name  = name,
    })
end)

--  ESCORTE

LSLegacy.Events.Register('police:escort', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not data or not data.target then return end

    local target = tonumber(data.target)
    if not GetPlayer(target) then return end

    if data.active then
        EscortLinks[target] = src
        TriggerClientEvent('police:escortedBy', target, { active = true, officer = src })
    else
        EscortLinks[target] = nil
        TriggerClientEvent('police:escortedBy', target, { active = false, officer = src })
    end
end)

--  MISE EN VÉHICULE

LSLegacy.Events.Register('police:putInVehicle', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not data or not data.target or not data.vehNet then return end

    local target = tonumber(data.target)
    if not GetPlayer(target) then return end

    TriggerClientEvent('police:forcePutInVehicle', target, {
        vehNet = data.vehNet,
        seat   = data.seat or 2,
    })
    local tName = GetName(target)
    local oName = GetName(src)
    Notify(src,    string.format(Lang.Police.put_in_veh, tName), 'success')
end)

LSLegacy.Events.Register('police:getOutVehicle', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not data or not data.target then return end

    local target = tonumber(data.target)
    if not GetPlayer(target) then return end

    TriggerClientEvent('police:forceGetOutVehicle', target)
    Notify(src, string.format(Lang.Police.got_out_veh, GetName(target)), 'success')
end)

--  SAISIE D'OBJET

LSLegacy.Events.Register('police:seizeItem', function(data)
    local src = source
    if not IsLawEnforcementOnDuty(src) then return end
    if not data or not data.target or not data.itemName then return end

    local target = tonumber(data.target)
    local tp     = GetPlayer(target)
    if not tp then return end

    local count = tonumber(data.count) or 1
    local inv   = tp.inventory or {}
    local found = false

    for i, item in pairs(inv) do
        if item and item.name == data.itemName and item.count and item.count >= count then
            found = true
            local meta  = Config.Items and Config.Items[data.itemName]
            local label = meta and meta.label or data.itemName
            -- Retire de la cible
            LSLegacy.Inventory.RemoveItemInInventory(tp, data.itemName, count, label)
            -- Donne à l'officier
            LSLegacy.Inventory.AddItemInInventory(GetPlayer(src), data.itemName, count, label)
            -- Nettoyer ped + fast slots côté client de la cible
            TriggerClientEvent('police:clearWeapon', target, { itemName = data.itemName })
            TriggerClientEvent('police:seizeResult', src, {
                success  = true,
                label    = label,
                count    = count,
                itemName = data.itemName,
            })
            Notify(target, 'Un objet a été saisi : ' .. label, 'warning')
            break
        end
    end

    if not found then
        TriggerClientEvent('police:seizeResult', src, { success = false })
    end
end)

-- Nettoyage
AddEventHandler('playerDropped', function()
    local src = source
    CuffedPlayers[src] = nil
    EscortLinks[src]   = nil
    for target, officer in pairs(EscortLinks) do
        if officer == src then EscortLinks[target] = nil end
    end
end)
