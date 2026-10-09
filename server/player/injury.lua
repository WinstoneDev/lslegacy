LSLegacy.Events.Register("lslegacy:injuryEnterComa", function()
    local src = source
    local player = LSLegacy.ServerPlayers[src]
    if not player then return end
    player.isComa            = true
    player.isKO              = false
    player.wasTreated        = false
    player.status.comaUntil  = os.time() + Config.Injury.ComaDuration
    Config.Development.Print(("[Injury] %s est en coma jusqu'à %d"):format(GetPlayerName(src), player.status.comaUntil))
    if FarmMetier then FarmMetier.OnDeath(src) end
end)

LSLegacy.Events.Register("lslegacy:injuryExitComa", function()
    local src = source
    local player = LSLegacy.ServerPlayers[src]
    if not player then return end
    player.isComa            = false
    player.status.comaUntil  = nil
end)

LSLegacy.Events.Register("lslegacy:injuryRespawn", function()
    local src = source
    local player = LSLegacy.ServerPlayers[src]
    if not player then return end
    player.isComa            = false
    player.isKO              = false
    player.status.comaUntil  = nil
    player.health            = 125
    LSLegacy.Injury.SyncWoundsToHealth(src, 125) -- 125 = santé réelle appliquée par lslegacy:clientRespawn (25%)
    LSLegacy.Events.SendToClient("lslegacy:clientRespawn", src)
end)

-- Relayé au module EMS via "ems:patientCall" pour notifier ses agents en service
LSLegacy.Events.Register("lslegacy:injuryCallEMS", function()
    local src = source
    local player = LSLegacy.ServerPlayers[src]
    if not player or not player.isComa then return end
    local ped    = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    TriggerEvent("ems:patientCall", { source = src, coords = coords, name = GetPlayerName(src) })
    Config.Development.Print(("[Injury] %s appelle les EMS depuis le coma"):format(GetPlayerName(src)))
end)

LSLegacy.Events.Register("lslegacy:injuryEnterKO", function()
    local src = source
    local player = LSLegacy.ServerPlayers[src]
    if not player then return end
    player.isKO      = true
    player.isComa    = false
    player.wasTreated = false
end)

LSLegacy.Events.Register("lslegacy:injuryExitKO", function()
    local src = source
    local player = LSLegacy.ServerPlayers[src]
    if not player then return end
    player.isKO = false
end)

-- Utilisé par la trousse de soins EMS/LSFD
LSLegacy.Events.Register("lslegacy:injurySyncWound", function(data)
    local src = source
    local player = LSLegacy.ServerPlayers[src]
    if not player or not data then return end
    player.lastWound = { category = data.category, zone = data.zone, time = os.time() }
end)

-- Health Inspection — état des blessures par membre (EMS). En mémoire
-- uniquement, remis à zéro à la reconnexion et à chaque sortie de KO/coma/respawn.
LSLegacy.Injury = {}

LSLegacy.Injury.BodyParts   = { 'head', 'body', 'arm_l', 'arm_r', 'leg_l', 'leg_r' }
LSLegacy.Injury.InjuryTypes = { 'blunt', 'broken', 'bruising', 'burns', 'gunshot', 'laceration', 'taser' }

local function FreshWounds()
    local wounds = {}
    for _, part in ipairs(LSLegacy.Injury.BodyParts) do
        local injuries = {}
        for _, t in ipairs(LSLegacy.Injury.InjuryTypes) do injuries[t] = 0 end
        wounds[part] = { hp = 100, injuries = injuries }
    end
    return wounds
end

---InitWounds : (ré)initialise l'état des 6 membres à 100% / 0 blessure.
---@param src number
LSLegacy.Injury.InitWounds = function(src)
    local player = LSLegacy.ServerPlayers[src]
    if not player then return end
    player.wounds = FreshWounds()
end

LSLegacy.Injury.ResetWounds = LSLegacy.Injury.InitWounds

---SyncWoundsToHealth : la santé GTA ne remonte que partiellement après
---réanimation/respawn (125/200 = 25%) ; remonte chaque membre au plancher
---correspondant sans jamais le faire redescendre, et sans toucher aux compteurs de blessures.
---@param src number
---@param health number Santé GTA (100-200) restaurée
LSLegacy.Injury.SyncWoundsToHealth = function(src, health)
    local player = LSLegacy.ServerPlayers[src]
    if not player then return end
    if not player.wounds then LSLegacy.Injury.InitWounds(src) end
    local floor = math.max(0, math.min(100, (health or 200) - 100))
    for _, part in ipairs(LSLegacy.Injury.BodyParts) do
        local w = player.wounds[part]
        if w then w.hp = math.max(w.hp, floor) end
    end
end

---GetWounds
---@param src number
---@return table|nil {part = {hp, injuries={type=count}}}
LSLegacy.Injury.GetWounds = function(src)
    local player = LSLegacy.ServerPlayers[src]
    return player and player.wounds or nil
end

LSLegacy.Injury.IsValidPart = function(part)
    for _, p in ipairs(LSLegacy.Injury.BodyParts) do
        if p == part then return true end
    end
    return false
end

---ApplyDamage : constate un dégât sur un membre (cosmétique/compteur — ne
---touche jamais GetEntityHealth/SetEntityHealth, le moteur GTA gère déjà la
---vraie santé tout seul ; voir ApplyTreatment pour le seul chemin qui soigne).
---@param src number
---@param part string
---@param injuryType string
---@param amount number points de vie perdus (échelle 0-100, comme hp du membre)
LSLegacy.Injury.ApplyDamage = function(src, part, injuryType, amount)
    local player = LSLegacy.ServerPlayers[src]
    if not player then return end
    if not player.wounds then LSLegacy.Injury.InitWounds(src) end
    local w = player.wounds[part]
    if not w then return end
    w.hp = math.max(0, w.hp - amount)
    if w.injuries[injuryType] ~= nil then
        w.injuries[injuryType] = w.injuries[injuryType] + 1
    end
end

---ApplyTreatment : soigne le membre ciblé (plafond 100) et décrémente les
---compteurs des types de blessures traités par l'item, s'ils sont présents.
---@param src number
---@param part string
---@param itemDef table {heal, treats={type,...}}
---@return boolean success
LSLegacy.Injury.ApplyTreatment = function(src, part, itemDef)
    local player = LSLegacy.ServerPlayers[src]
    if not player then return false end
    if not player.wounds then LSLegacy.Injury.InitWounds(src) end
    local w = player.wounds[part]
    if not w then return false end

    if w.hp >= 100 then return false end

    -- Un item ne soigne QUE s'il traite au moins une blessure réellement
    -- présente sur ce membre (ex. poche de glace {bruising,blunt} sur une
    -- blessure par balle ne fait RIEN). Le bon soin traite intégralement
    -- CE type de blessure (compteur remis à 0 d'un coup, pas décrémenté au
    -- montant fixe de l'item) : plus de reliquat de PV à combler une fois
    -- le mauvais soin exclu.
    local treatedAny = false
    for _, t in ipairs(itemDef.treats) do
        if (w.injuries[t] or 0) > 0 then
            w.injuries[t] = 0
            treatedAny = true
        end
    end
    if not treatedAny then return false end

    -- S'il ne reste plus AUCUNE blessure active sur le membre (cas courant :
    -- un seul type de blessure à la fois), il repasse directement à 100%.
    -- S'il reste un AUTRE type non traité par cet item (plusieurs blessures
    -- différentes sur le même membre), seul le montant de soin de l'item
    -- s'applique — un autre soin adapté reste nécessaire pour le reste.
    local stillInjured = false
    for _, t in ipairs(LSLegacy.Injury.InjuryTypes) do
        if (w.injuries[t] or 0) > 0 then stillInjured = true break end
    end
    w.hp = stillInjured and math.min(100, w.hp + itemDef.heal) or 100

    -- Marque le patient comme pris en charge : condition à la réanimation
    -- (cf. ems:revive), remis à false à chaque nouvelle entrée en KO/coma.
    player.wasTreated = true
    return true
end

---WasTreated : le patient a-t-il reçu au moins un soin depuis son dernier
---passage en KO/coma ? Condition préalable à la réanimation (ems:revive).
---@param src number
---@return boolean
LSLegacy.Injury.WasTreated = function(src)
    local player = LSLegacy.ServerPlayers[src]
    return player ~= nil and player.wasTreated == true
end

-- Le SERVEUR fait la conversion catégorie→type de blessure (jamais confiance
-- au client) ; aucun SetEntityHealth ici, cf. ApplyDamage.
LSLegacy.Events.Register('ems:hiDamage', function(data)
    local src = source
    if type(data) ~= 'table' then return end

    -- batch groupe les dégâts pour ne pas dépasser la limite anti-spam
    local entries = data.batch
    if type(entries) ~= 'table' then entries = { data } end

    -- Au-delà du nombre de couples (membre, catégorie) possibles, client forgé
    local maxEntries = #LSLegacy.Injury.BodyParts * #LSLegacy.Injury.InjuryTypes
    local processed = 0

    for _, entry in ipairs(entries) do
        processed = processed + 1
        if processed > maxEntries then break end
        if type(entry) == 'table' and LSLegacy.Injury.IsValidPart(entry.part) then
            local injuryType = Config.EMS.HealthInspection.CategoryToInjury[entry.category] or 'broken'
            local amount = math.min(100, math.max(0, tonumber(entry.amount) or 0))
            if amount > 0 then
                LSLegacy.Injury.ApplyDamage(src, entry.part, injuryType, amount)
            end
        end
    end
end)

-- Force la sortie du coma/KO (appelé par admin heal/revive)
---ClearState
---@param src number
---@param health number|nil Santé GTA (100-200) après la sortie de KO/coma. Défaut 200 (revive admin).
LSLegacy.Injury.ClearState = function(src, health)
    local player = LSLegacy.ServerPlayers[src]
    if not player then return end
    player.isKO             = false
    player.isComa           = false
    player.status.comaUntil = nil
    LSLegacy.Injury.SyncWoundsToHealth(src, health or 200)
    LSLegacy.Events.SendToClient("lslegacy:injuryAdminRevive", src, health or 200)
end

---GetWound
---@param src number
---@return table {category, zone, time}|nil
LSLegacy.Injury.GetWound = function(src)
    local player = LSLegacy.ServerPlayers[src]
    return player and player.lastWound or nil
end
