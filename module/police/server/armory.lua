--  MODULE POLICE NATIONALE — Armurerie (serveur)
--  Accès et stocks toujours revalidés ici : le client ne fait que proposer
--  un menu à partir de l'état renvoyé par police:armory:open.

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Police Nationale', msg, t or 'info', Config.Police.NotifyDuration or 30000)
end

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS police_personal_equipment (
        character_id INT         NOT NULL,
        item         VARCHAR(50) NOT NULL,
        taken        TINYINT(1)  NOT NULL DEFAULT 0,
        PRIMARY KEY (character_id, item)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- pool = 'chef' (Chef de poste) ou 'raid' (Armurier RAID) : deux stocks
-- dissociés même quand l'objet (ex: PIE) est identique dans les deux.
MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS police_armory_stock (
        pool  VARCHAR(20) NOT NULL,
        item  VARCHAR(50) NOT NULL,
        stock INT         NOT NULL DEFAULT 0,
        PRIMARY KEY (pool, item)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

local function FindArmoryWeapon(player, weaponUniqueId, weaponName)
    for _, v in pairs(player.inventory) do
        if v.name == weaponName and v.uniqueId == weaponUniqueId then return v end
    end
    return nil
end

local function FindArmoryComponentDef(weaponName, componentItem)
    local list = Config.WeaponComponents[weaponName]
    if not list then return nil end
    for _, def in pairs(list) do
        if def.item == componentItem then return def end
    end
    return nil
end

local function FindPersonalDef(item)
    for _, def in ipairs(Config.Police.Armory.PersonalItems) do
        if def.item == item then return def end
    end
    return nil
end

local function FindCollectiveDef(pool, item)
    local list = Config.Police.Armory.Collective[pool == 'raid' and 'raid' or 'police']
    for _, def in ipairs(list) do
        if def.item == item then return def end
    end
    return nil
end

-- `def.training` (code compétence MDT) et/ou `def.minGrade` (grade minimum,
-- l'un ou l'autre suffit) : Commissaire (grade 8) passe toujours.
local function HasArmoryTraining(src, charId, def)
    if not def.training then return true end
    if IsCommissaire(src) then return true end
    if def.minGrade and GetGrade(src) >= def.minGrade then return true end
    return LSLegacy.MDT.HasSkillCode(charId, def.training)
end

-- Revalide l'accès RAID/BRI en direct (pas de cache) à chaque action, sauf
-- pour un Commissaire (grade 8) qui a accès sans condition d'unité.
local function GuardRaidAccess(src, pnj, cb, notifyOnFail)
    if pnj ~= 'raid' then return cb() end
    if IsCommissaire(src) then return cb() end
    CheckRaidOrBriUnit(src, function(ok)
        if ok then return cb() end
        if notifyOnFail then Notify(src, 'Réservé aux unités RAID/BRI.', 'error') end
    end)
end

--  OUVERTURE DU MENU — envoie l'état courant (accessoires/personnel/collectif)

local function BuildArmoryState(src, pnj)
    local charId = GetCharacterId(src)
    if not charId then return end

    if pnj == 'armurier' then
        LSLegacy.Events.SendToClient('police:armory:state', src, {
            pnj = pnj,
            accessories = Config.Police.Armory.Accessories.standard,
        })
        return
    end

    if pnj ~= 'chef' and pnj ~= 'raid' then return end

    local commissaire = IsCommissaire(src)

    MySQL.Async.fetchAll('SELECT item, taken FROM police_personal_equipment WHERE character_id=@id', { ['@id'] = charId }, function(rows)
        local takenMap = {}
        for _, r in ipairs(rows or {}) do takenMap[r.item] = r.taken and true or false end

        local personal = {}
        for _, def in ipairs(Config.Police.Armory.PersonalItems) do
            personal[#personal + 1] = {
                item    = def.item,
                label   = def.label,
                taken   = takenMap[def.item] or false,
                trained = (not def.training) or commissaire or LSLegacy.MDT.HasSkillCode(charId, def.training),
            }
        end

        MySQL.Async.fetchAll('SELECT item, stock FROM police_armory_stock WHERE pool=@pool', { ['@pool'] = pnj }, function(stockRows)
            local stockMap = {}
            for _, r in ipairs(stockRows or {}) do stockMap[r.item] = r.stock end

            local collective = {}
            for _, def in ipairs(Config.Police.Armory.Collective[pnj == 'raid' and 'raid' or 'police']) do
                local maxStock = def.stock or Config.Police.Armory.CollectiveStock
                collective[#collective + 1] = {
                    item     = def.item,
                    label    = def.label,
                    stock    = stockMap[def.item] or maxStock,
                    maxStock = maxStock,
                    trained  = HasArmoryTraining(src, charId, def),
                }
            end

            LSLegacy.Events.SendToClient('police:armory:state', src, {
                pnj         = pnj,
                accessories = pnj == 'raid' and Config.Police.Armory.Accessories.raid or nil,
                personal    = personal,
                collective  = collective,
            })
        end)
    end)
end

LSLegacy.Events.Register('police:armory:open', function(data)
    local src = source
    if not IsPolice(src) or type(data) ~= 'table' then return end
    local pnj = data.pnj
    if pnj ~= 'armurier' and pnj ~= 'chef' and pnj ~= 'raid' then return end
    GuardRaidAccess(src, pnj, function() BuildArmoryState(src, pnj) end, true)
end)

--  ACCESSOIRES (Armurier / Armurier RAID) — installation directe sur l'arme

LSLegacy.Events.Register('police:armory:attachAccessory', function(data)
    local src = source
    if not IsPolice(src) or type(data) ~= 'table' then return end
    local pnj = data.pnj
    if pnj ~= 'armurier' and pnj ~= 'raid' then return end

    GuardRaidAccess(src, pnj, function()
        local allowed = Config.Police.Armory.Accessories[pnj == 'raid' and 'raid' or 'standard']
        local isAllowed = false
        for _, it in ipairs(allowed) do if it == data.componentItem then isAllowed = true; break end end
        if not isAllowed then return end

        local player = GetPlayer(src)
        if not player then return end

        local componentDef = FindArmoryComponentDef(data.weaponName, data.componentItem)
        if not componentDef then return end

        local weapon = FindArmoryWeapon(player, data.weaponUniqueId, data.weaponName)
        if not weapon then
            Notify(src, 'Vous ne possédez pas cette arme.', 'error')
            return
        end

        weapon.data = weapon.data or {}
        weapon.data.components = weapon.data.components or {}

        -- Un seul accessoire par emplacement : celui déjà en place est retiré
        -- (offert par l'armurier, il n'est pas rendu à l'inventaire du joueur).
        for i = #weapon.data.components, 1, -1 do
            local existing = weapon.data.components[i]
            local existingDef = FindArmoryComponentDef(data.weaponName, existing)
            if existingDef and existingDef.slot == componentDef.slot then
                table.remove(weapon.data.components, i)
            end
        end
        table.insert(weapon.data.components, data.componentItem)

        player:MarkDirty('inventory')
        LSLegacy.Events.SendToClient('lslegacy:updatePlayer', src, player)
        Notify(src, LSLegacy.Inventory.GetInfosItem(data.componentItem).label .. ' installé(e) par l\'armurier.', 'success')
    end)
end)

--  ÉQUIPEMENT PERSONNEL (Chef de poste / Armurier RAID)

LSLegacy.Events.Register('police:armory:personalAction', function(data)
    local src = source
    if not IsPolice(src) or type(data) ~= 'table' then return end
    local pnj = data.pnj
    if pnj ~= 'chef' and pnj ~= 'raid' then return end

    GuardRaidAccess(src, pnj, function()
        local def = FindPersonalDef(data.item)
        if not def then return end

        local player = GetPlayer(src)
        local charId = GetCharacterId(src)
        if not player or not charId then return end

        local commissaire = IsCommissaire(src)

        MySQL.Async.fetchScalar('SELECT taken FROM police_personal_equipment WHERE character_id=@id AND item=@item', {
            ['@id'] = charId, ['@item'] = def.item,
        }, function(taken)
            taken = taken and true or false

            if data.action == 'take' then
                if taken then return Notify(src, 'Vous avez déjà cet équipement.', 'error') end
                if def.training and not commissaire and not LSLegacy.MDT.HasSkillCode(charId, def.training) then
                    return Notify(src, 'Formation requise pour retirer cet équipement.', 'error')
                end
                LSLegacy.Inventory.AddItemInInventory(player, def.item, 1)
                MySQL.Async.execute(
                    'INSERT INTO police_personal_equipment (character_id, item, taken) VALUES (@id,@item,1) ON DUPLICATE KEY UPDATE taken=1',
                    { ['@id'] = charId, ['@item'] = def.item }
                )
                Notify(src, def.label .. ' récupéré.', 'success')
            elseif data.action == 'deposit' then
                if not taken then return Notify(src, "Vous n'avez pas cet équipement dehors.", 'error') end
                if not LSLegacy.Inventory.GetInventoryItem(player, def.item) then
                    return Notify(src, 'Vous ne possédez pas ' .. def.label .. ' sur vous.', 'error')
                end
                LSLegacy.Inventory.RemoveItemInInventory(player, def.item, 1)
                MySQL.Async.execute('UPDATE police_personal_equipment SET taken=0 WHERE character_id=@id AND item=@item', {
                    ['@id'] = charId, ['@item'] = def.item,
                })
                Notify(src, def.label .. ' rangé.', 'success')
            end
        end)
    end)
end)

--  ARMES COLLECTIVES (stock limité, Chef de poste / Armurier RAID)

LSLegacy.Events.Register('police:armory:collectiveAction', function(data)
    local src = source
    if not IsPolice(src) or type(data) ~= 'table' then return end
    local pnj = data.pnj
    if pnj ~= 'chef' and pnj ~= 'raid' then return end

    GuardRaidAccess(src, pnj, function()
        local def = FindCollectiveDef(pnj, data.item)
        if not def then return end

        local player = GetPlayer(src)
        local charId = GetCharacterId(src)
        if not player or not charId then return end

        local maxStock = def.stock or Config.Police.Armory.CollectiveStock

        if data.action == 'take' then
            if not HasArmoryTraining(src, charId, def) then
                return Notify(src, 'Formation requise pour retirer cette arme.', 'error')
            end
            MySQL.Async.execute(
                'INSERT INTO police_armory_stock (pool, item, stock) VALUES (@pool,@item,@max) ON DUPLICATE KEY UPDATE stock=stock',
                { ['@pool'] = pnj, ['@item'] = def.item, ['@max'] = maxStock }
            )
            MySQL.Async.execute(
                'UPDATE police_armory_stock SET stock=stock-1 WHERE pool=@pool AND item=@item AND stock > 0',
                { ['@pool'] = pnj, ['@item'] = def.item },
                function(affectedRows)
                    if affectedRows and affectedRows > 0 then
                        -- Gazeuse : 100 charges non rechargeables gravées sur l'item
                        -- dès la sortie du dépôt (cf. module/nonlethal).
                        local initialData = (def.item == 'weapon_gazeuse')
                            and { charges = Config.NonLethal.Gazeuse.maxCharges } or nil
                        LSLegacy.Inventory.AddItemInInventory(player, def.item, 1, nil, nil, initialData)
                        Notify(src, def.label .. ' récupéré au dépôt.', 'success')
                    else
                        Notify(src, 'Stock épuisé pour ' .. def.label .. '.', 'error')
                    end
                end
            )
        elseif data.action == 'deposit' then
            local owned = LSLegacy.Inventory.GetInventoryItem(player, def.item)
            if not owned then
                return Notify(src, 'Vous ne possédez pas ' .. def.label .. '.', 'error')
            end
            if def.item == 'weapon_gazeuse' and (not owned.data or (owned.data.charges or 0) > 0) then
                return Notify(src, 'Videz la gazeuse avant de la rendre au dépôt.', 'error')
            end
            LSLegacy.Inventory.RemoveItemInInventory(player, def.item, 1)
            MySQL.Async.execute(
                'UPDATE police_armory_stock SET stock=LEAST(stock+1,@max) WHERE pool=@pool AND item=@item',
                { ['@pool'] = pnj, ['@item'] = def.item, ['@max'] = maxStock }
            )
            Notify(src, def.label .. ' redéposé au stock.', 'success')
        end
    end)
end)
