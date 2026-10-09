--  MDT — BOUTIQUE TENUES (serveur, générique multi-jobs)
--  Généralisation d'UNIPOL (ex module/police/server/vetipol.lua) à tout
--  département MDT qui déclare un Config.MDT.Departments.<dep>.boutique.
--  Commande de tenues par un agent habilité (manage_boutique) pour un collègue
--  nommé, débitée sur le compte entreprise du job, livrée après délai à un
--  point de retrait ox_target (module/mdt/client/boutique.lua).
--
--  Une commande peut contenir plusieurs articles : ils partagent un même
--  batch_id (même horodatage/délai/statut), affichés comme UNE seule ligne
--  d'historique. Chaque article porte un flag `as_outfit` : les articles
--  cochés sont remis groupés en UN SEUL item composite `outfit`
--  (module/clothshop) au retrait, les autres restent des items individuels
--  par slot, comme avant.

LSLegacy.Security.RegisterRateLimit('mdtboutique:query', 30)
LSLegacy.Security.RegisterRateLimit('mdtboutique:order', 10)
LSLegacy.Security.RegisterRateLimit('mdtboutique:cancel', 10)
LSLegacy.Security.RegisterRateLimit('boutique:pickup', 10)
LSLegacy.Security.RegisterRateLimit('mdtboutique:presetSave', 10)
LSLegacy.Security.RegisterRateLimit('mdtboutique:presetDelete', 10)

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_boutique_orders (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        department               VARCHAR(50)  NOT NULL DEFAULT '',
        batch_id                 VARCHAR(40)  NOT NULL DEFAULT '',
        target_character_id     INT          NOT NULL,
        target_name              VARCHAR(100) NOT NULL DEFAULT '',
        ordered_by_character_id  INT          DEFAULT NULL,
        ordered_by_name          VARCHAR(100) NOT NULL DEFAULT '',
        item_slot     VARCHAR(30)  NOT NULL,
        drawable      INT          NOT NULL DEFAULT 0,
        texture       INT          NOT NULL DEFAULT 0,
        item_label    VARCHAR(100) NOT NULL DEFAULT '',
        as_outfit     TINYINT(1)   NOT NULL DEFAULT 0,
        price         INT          NOT NULL DEFAULT 0,
        status        VARCHAR(12)  NOT NULL DEFAULT 'en_attente',
        created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
        ready_at      DATETIME     NOT NULL,
        KEY idx_boutique_target (target_character_id, status),
        KEY idx_boutique_batch (batch_id),
        KEY idx_boutique_department (department)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- Tenues pré-enregistrées par département : évite de resaisir chaque
-- drawable/texture à la main à chaque commande. `items` = JSON
-- { [slot] = {drawable, texture}, ... } au même format que le système
-- `outfit` du clothshop, pour rester compatible avec l'agrégation `as_outfit`.
MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_boutique_presets (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        department    VARCHAR(50)  NOT NULL DEFAULT '',
        name          VARCHAR(60)  NOT NULL DEFAULT '',
        items         LONGTEXT     NOT NULL,
        created_by_name VARCHAR(100) NOT NULL DEFAULT '',
        created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_boutique_preset (department, name),
        KEY idx_boutique_preset_department (department)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

local SLOTS = {}
for _, s in ipairs(Config.MDT.ClothingSlots) do SLOTS[s.id] = s.label end

local function Notify(src, msg, t) LSLegacy.Events.SendToClient('notify', src, 'Boutique tenues', msg, t or 'info', 6000) end

-- Département MDT + job + config boutique du joueur connecté `src`, ou nil
-- si le job n'a pas de boutique configurée.
local function BoutiqueCtx(src)
    local player = LSLegacy.Players.Get(src)
    if not player then return nil end
    local depName = LSLegacy.MDT.GetDepartmentForJob(player.job)
    if not depName then return nil end
    local dep = LSLegacy.MDT.GetDepartment(depName)
    if not dep or not dep.boutique then return nil end
    return player, depName, dep
end

local function SrcByCharId(charId)
    for src, p in pairs(LSLegacy.Players.GetAll()) do
        if p['boutique-id'] == charId then return src end
    end
    return nil
end

-- ── Props posé au point de retrait — visuel partagé par département ──
-- Un seul colis visible à la fois par département : apparaît dès qu'une
-- commande devient "prête", disparaît quand il ne reste plus aucune
-- commande "prête" (retrait ou annulation), quel que soit l'agent concerné.
local function DespawnPropIfEmpty(depName)
    local dep = LSLegacy.MDT.GetDepartment(depName)
    local C = dep and dep.boutique
    if not C or not C.DeliveryProp then return end
    local remaining = MySQL.Sync.fetchScalar("SELECT COUNT(DISTINCT batch_id) FROM mdt_boutique_orders WHERE department=@dep AND status='pret'", { ['@dep'] = depName }) or 0
    if remaining == 0 then
        LSLegacy.Events.SendToClient('boutique:deliveryPropDespawn', -1, { department = depName })
    end
end

-- ── Pont MDT : onglet « Boutique tenues » (lecture) ──────────────
local Handlers = {}

Handlers.getCatalogue = function(dep, p, data, reply)
    local C = dep.boutique
    reply({ slots = Config.MDT.ClothingSlots, price = C.ItemPrice, delaySeconds = C.DeliveryDelay, maxItemsPerOrder = C.MaxItemsPerOrder, maxPendingPerAgent = C.MaxPendingPerAgent })
end

Handlers.getPresets = function(dep, p, data, reply, depName)
    local rows = MySQL.Sync.fetchAll('SELECT id, name, items, created_by_name, created_at FROM mdt_boutique_presets WHERE department=@dep ORDER BY name ASC', { ['@dep'] = depName }) or {}
    for _, row in ipairs(rows) do
        local ok, items = pcall(json.decode, row.items)
        row.items = (ok and items) or {}
    end
    reply({ presets = rows })
end

Handlers.getHistory = function(dep, p, data, reply, depName)
    local rows = MySQL.Sync.fetchAll([[
        SELECT
            batch_id,
            MIN(id) AS id,
            MIN(created_at) AS created_at,
            target_character_id, target_name, ordered_by_name,
            SUM(price) AS price,
            COUNT(*) AS item_count,
            MIN(status) AS status,
            MIN(ready_at) AS ready_at,
            GREATEST(0, TIMESTAMPDIFF(SECOND, NOW(), MIN(ready_at))) AS remaining_seconds,
            GROUP_CONCAT(CONCAT_WS('::', item_slot, drawable, texture, item_label, as_outfit) SEPARATOR ';;') AS items_data
        FROM mdt_boutique_orders
        WHERE department = @dep
        GROUP BY batch_id
        ORDER BY created_at DESC LIMIT 200
    ]], { ['@dep'] = depName }) or {}
    local monthSpend = MySQL.Sync.fetchScalar([[
        SELECT COALESCE(SUM(price), 0) FROM mdt_boutique_orders
        WHERE department = @dep AND status != 'annule' AND created_at >= DATE_FORMAT(NOW(), '%Y-%m-01')
    ]], { ['@dep'] = depName }) or 0
    reply({ orders = rows, monthSpend = monthSpend })
end

LSLegacy.Events.Register('mdtboutique:query', function(payload)
    local src = source
    local player, depName, dep = BoutiqueCtx(src)
    if not player or type(payload) ~= 'table' or not payload.action then return end
    local reply = function(res) LSLegacy.Events.SendToClient('mdtboutique:queryResult', src, { reqId = payload.reqId, result = res }) end
    if not HasPermission(src, 'manage_boutique') then return reply(false) end
    if not LSLegacy.Bank.GetSocietyAccount(player.job) then return reply(false) end
    local h = Handlers[payload.action]
    if not h then return reply(false) end
    h(dep, player, type(payload.data) == 'table' and payload.data or {}, reply, depName)
end)

-- ── Commande (panier : plusieurs articles = UNE seule commande) ──
LSLegacy.Events.Register('mdtboutique:order', function(data)
    local src = source
    local author, depName, dep = BoutiqueCtx(src)
    if not author or type(data) ~= 'table' or not HasPermission(src, 'manage_boutique') then return end
    if not LSLegacy.Bank.GetSocietyAccount(author.job) then
        return Notify(src, "Votre entreprise n'a pas de compte actif.", 'error')
    end
    local C = dep.boutique

    local targetCharId = tonumber(data.targetCharacterId)
    local items = type(data.items) == 'table' and data.items or {}
    if not targetCharId or #items == 0 then
        return Notify(src, 'Commande invalide.', 'error')
    end
    if #items > C.MaxItemsPerOrder then
        return Notify(src, ('Une commande ne peut pas dépasser %d articles.'):format(C.MaxItemsPerOrder), 'error')
    end

    -- Chaque article du panier est revalidé côté serveur (jamais confiance en la NUI).
    local validated = {}
    for _, it in ipairs(items) do
        local slotLabel = SLOTS[it.slot]
        local drawable = tonumber(it.drawable)
        local texture = tonumber(it.texture) or 0
        if not slotLabel or not drawable or drawable < 0 or drawable > 999 or texture < 0 or texture > 99 then
            return Notify(src, 'Commande invalide.', 'error')
        end
        validated[#validated + 1] = { slot = it.slot, label = slotLabel .. ' #' .. drawable, drawable = drawable, texture = texture, asOutfit = it.asOutfit == true }
    end

    -- Le nom de l'agent est figé côté serveur (source fiable), jamais celui envoyé par la NUI.
    local rows = MySQL.Sync.fetchAll('SELECT `boutique-id` AS character_id, characterInfos, job FROM players WHERE `boutique-id`=@id LIMIT 1', { ['@id'] = targetCharId })
    local target = rows and rows[1]
    local targetInDep = false
    for _, j in ipairs(dep.jobs or {}) do if target and target.job == j then targetInDep = true break end end
    if not target or not targetInDep then return Notify(src, 'Agent introuvable.', 'error') end
    local ok, ci = pcall(json.decode, target.characterInfos)
    ci = (ok and ci) or {}
    local targetName = ((ci.Prenom or '') .. ' ' .. (ci.NDF or '')):gsub('^%s+', ''):gsub('%s+$', '')

    -- La limite compte des COMMANDES (batches) en attente, pas des articles.
    local pendingBatches = MySQL.Sync.fetchScalar(
        "SELECT COUNT(DISTINCT batch_id) FROM mdt_boutique_orders WHERE department=@dep AND target_character_id=@id AND status IN ('en_attente','pret')",
        { ['@dep'] = depName, ['@id'] = targetCharId }) or 0
    if pendingBatches >= C.MaxPendingPerAgent then
        return Notify(src, ('%s a déjà %d commande(s) en attente (max %d).'):format(targetName, pendingBatches, C.MaxPendingPerAgent), 'error')
    end

    local total = C.ItemPrice * #validated
    if not LSLegacy.Bank.RemoveSocietyMoney(author.job, total, ('Boutique tenues — %d article(s) pour %s'):format(#validated, targetName), 'Achat') then
        return Notify(src, "Fonds insuffisants sur le compte entreprise.", 'error')
    end

    local orderedByName = ((author.characterInfos and author.characterInfos.Prenom or '') .. ' ' .. (author.characterInfos and author.characterInfos.NDF or '')):gsub('^%s+', ''):gsub('%s+$', '')
    -- Le batch_id est l'id (auto-incrémenté, donc unique par construction) du
    -- premier article inséré : évite toute collision entre deux commandes
    -- passées la même seconde (risque réel avec un id généré côté Lua).
    local batchId = nil
    local orderIds = {}
    for _, it in ipairs(validated) do
        local orderId = MySQL.insert.await([[
            INSERT INTO mdt_boutique_orders
                (department, batch_id, target_character_id, target_name, ordered_by_character_id, ordered_by_name, item_slot, drawable, texture, item_label, as_outfit, price, ready_at)
            VALUES (@dep, @batch, @tc, @tn, @oc, @on, @slot, @draw, @tex, @label, @outfit, @price, DATE_ADD(NOW(), INTERVAL @delay SECOND))
        ]], {
            ['@dep'] = depName, ['@batch'] = batchId or '',
            ['@tc'] = targetCharId, ['@tn'] = targetName,
            ['@oc'] = author['boutique-id'], ['@on'] = orderedByName,
            ['@slot'] = it.slot, ['@draw'] = it.drawable, ['@tex'] = it.texture,
            ['@label'] = it.label, ['@outfit'] = it.asOutfit and 1 or 0,
            ['@price'] = C.ItemPrice, ['@delay'] = C.DeliveryDelay,
        })
        if orderId then
            orderIds[#orderIds + 1] = orderId
            if not batchId then
                batchId = tostring(orderId)
                MySQL.Sync.execute('UPDATE mdt_boutique_orders SET batch_id=@b WHERE id=@id', { ['@b'] = batchId, ['@id'] = orderId })
            end
        end
    end

    if #orderIds == 0 then
        LSLegacy.Bank.AddSocietyMoney(author.job, total, 'Boutique tenues — erreur BDD, remboursement', 'Remboursement')
        return Notify(src, 'Erreur base de données.', 'error')
    elseif #orderIds < #validated then
        -- Insertion partielle : on rembourse uniquement les articles non enregistrés.
        LSLegacy.Bank.AddSocietyMoney(author.job, C.ItemPrice * (#validated - #orderIds), 'Boutique tenues — erreur BDD partielle, remboursement', 'Remboursement')
    end

    Notify(src, ('Commande envoyée : %d article(s) (%d $) pour %s.'):format(#orderIds, C.ItemPrice * #orderIds, targetName), 'success')

    local targetSrc = SrcByCharId(targetCharId)
    if targetSrc then
        Notify(targetSrc, ('Une commande (%d article(s)) a été passée pour vous, prête dans %d min.'):format(#orderIds, math.ceil(C.DeliveryDelay / 60)), 'info')
    end

    -- Scène cosmétique optionnelle (camion + livreur, ex. police) : seulement
    -- si le département en a configuré une (DeliveryVanCoords). Le délai
    -- total de livraison (DeliveryDelay) reste inchangé qu'il y ait une
    -- scène ou non.
    if C.DeliveryVanCoords and C.SceneArrivalDelay then
        local sceneDelay = math.max(0, C.DeliveryDelay - C.SceneArrivalDelay)
        Citizen.SetTimeout(sceneDelay * 1000, function()
            LSLegacy.Events.SendToClient('boutique:deliveryScene', -1, {
                deliveryVanCoords = C.DeliveryVanCoords,
                deliveryVanHeading = C.DeliveryVanHeading,
                deliveryPedCoords = C.DeliveryPedCoords,
                deliveryPedHeading = C.DeliveryPedHeading,
                deliveryDoorCoords = C.DeliveryDoorCoords,
                deliveryProp = C.DeliveryProp,
            })
        end)
    end

    Citizen.SetTimeout(C.DeliveryDelay * 1000, function()
        MySQL.Async.execute("UPDATE mdt_boutique_orders SET status='pret' WHERE batch_id=@batch AND status='en_attente'", { ['@batch'] = batchId }, function(affected)
            if not affected or affected == 0 then return end
            local tsrc = SrcByCharId(targetCharId)
            if tsrc then Notify(tsrc, 'Votre commande est arrivée au point de retrait.', 'success') end
            if C.DeliveryProp and C.DeliveryCoords then
                LSLegacy.Events.SendToClient('boutique:deliveryPropSpawn', -1, {
                    department = depName,
                    coords = C.DeliveryCoords,
                    heading = C.DeliveryHeading,
                    model = C.DeliveryProp,
                })
            end
        end)
    end)
end)

-- ── Annulation (grade manage_boutique uniquement) — annule la commande entière ──
LSLegacy.Events.Register('mdtboutique:cancel', function(data)
    local src = source
    local author, depName = BoutiqueCtx(src)
    if not author or not HasPermission(src, 'manage_boutique') then return end
    local batchId = tostring(type(data) == 'table' and data.batchId or data or '')
    if batchId == '' then return end
    local rows = MySQL.Sync.fetchAll("SELECT * FROM mdt_boutique_orders WHERE batch_id=@b AND status IN ('en_attente','pret')", { ['@b'] = batchId })
    if not rows or #rows == 0 then return Notify(src, 'Commande introuvable ou déjà retirée.', 'error') end

    local refund, targetCharId, itemCount = 0, rows[1].target_character_id, #rows
    for _, o in ipairs(rows) do refund = refund + o.price end
    MySQL.Sync.execute("UPDATE mdt_boutique_orders SET status='annule' WHERE batch_id=@b AND status IN ('en_attente','pret')", { ['@b'] = batchId })
    LSLegacy.Bank.AddSocietyMoney(author.job, refund, ('Boutique tenues — commande annulée — remboursement (%d article(s))'):format(itemCount), 'Remboursement')
    Notify(src, ('Commande annulée, %d $ remboursés.'):format(refund), 'success')
    local tsrc = SrcByCharId(targetCharId)
    if tsrc then Notify(tsrc, 'Votre commande a été annulée.', 'info') end
    DespawnPropIfEmpty(depName)
end)

-- ── Tenues pré-enregistrées (grade manage_boutique uniquement) ───
LSLegacy.Events.Register('mdtboutique:presetSave', function(data)
    local src = source
    local author, depName = BoutiqueCtx(src)
    if not author or not HasPermission(src, 'manage_boutique') then return end
    if type(data) ~= 'table' then return end

    local name = tostring(data.name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' or #name > 60 then return Notify(src, 'Nom de tenue invalide.', 'error') end

    local items = type(data.items) == 'table' and data.items or {}
    local validated = {}
    for _, it in ipairs(items) do
        local slotLabel = SLOTS[it.slot]
        local drawable = tonumber(it.drawable)
        local texture = tonumber(it.texture) or 0
        if not slotLabel or not drawable or drawable < 0 or drawable > 999 or texture < 0 or texture > 99 then
            return Notify(src, 'Tenue invalide.', 'error')
        end
        validated[it.slot] = { drawable, texture }
    end
    if not next(validated) then return Notify(src, 'La tenue doit contenir au moins un article.', 'error') end

    local orderedByName = ((author.characterInfos and author.characterInfos.Prenom or '') .. ' ' .. (author.characterInfos and author.characterInfos.NDF or '')):gsub('^%s+', ''):gsub('%s+$', '')

    MySQL.Async.execute([[
        INSERT INTO mdt_boutique_presets (department, name, items, created_by_name)
        VALUES (@dep, @name, @items, @by)
        ON DUPLICATE KEY UPDATE items = @items, created_by_name = @by, created_at = CURRENT_TIMESTAMP
    ]], { ['@dep'] = depName, ['@name'] = name, ['@items'] = json.encode(validated), ['@by'] = orderedByName }, function(affected)
        if affected and affected > 0 then
            Notify(src, ('Tenue "%s" enregistrée.'):format(name), 'success')
        else
            Notify(src, 'Erreur lors de l\'enregistrement.', 'error')
        end
    end)
end)

LSLegacy.Events.Register('mdtboutique:presetDelete', function(data)
    local src = source
    local author, depName = BoutiqueCtx(src)
    if not author or not HasPermission(src, 'manage_boutique') then return end
    local presetId = tonumber(type(data) == 'table' and data.presetId or data)
    if not presetId then return end
    MySQL.Async.execute('DELETE FROM mdt_boutique_presets WHERE id=@id AND department=@dep', { ['@id'] = presetId, ['@dep'] = depName }, function(affected)
        if affected and affected > 0 then Notify(src, 'Tenue supprimée.', 'success') end
    end)
end)

-- ── Retrait au point dédié (agent nommé uniquement) ──────────────
LSLegacy.Events.Register('boutique:pickup', function()
    local src = source
    local player, depName = BoutiqueCtx(src)
    if not player then return end
    local charId = player['boutique-id']
    local pendingCount = MySQL.Sync.fetchScalar("SELECT COUNT(*) FROM mdt_boutique_orders WHERE department=@dep AND target_character_id=@id AND status IN ('en_attente','pret')", { ['@dep'] = depName, ['@id'] = charId }) or 0
    if pendingCount == 0 then return Notify(src, "Aucun colis en attente pour vous.", 'error') end

    -- Comparaison faite côté SQL (ready_at <= NOW()) pour éviter tout écart d'horloge.
    local readyRows = MySQL.Sync.fetchAll("SELECT * FROM mdt_boutique_orders WHERE department=@dep AND target_character_id=@id AND status IN ('en_attente','pret') AND ready_at <= NOW()", { ['@dep'] = depName, ['@id'] = charId }) or {}

    local deliveredBatches = {}
    -- Articles cochés « tenue » : agrégés en UN item composite outfit par
    -- batch (même mécanique que module/clothshop:createOutfit).
    local outfitDataByBatch = {}
    local outfitLabelByBatch = {}
    for _, o in ipairs(readyRows) do
        -- TINYINT(1) relu comme booléen par oxmysql (true/false), pas 1/0 —
        -- voir reference_lslegacy_pitfalls.md.
        if o.as_outfit == 1 or o.as_outfit == true then
            outfitDataByBatch[o.batch_id] = outfitDataByBatch[o.batch_id] or {}
            outfitDataByBatch[o.batch_id][o.item_slot] = { o.drawable, o.texture }
            outfitLabelByBatch[o.batch_id] = outfitLabelByBatch[o.batch_id] or ('Tenue ' .. o.target_name)
        else
            LSLegacy.Inventory.AddItemInInventory(player, o.item_slot, 1, o.item_label, nil, { o.drawable, o.texture })
        end
        MySQL.Async.execute("UPDATE mdt_boutique_orders SET status='recupere' WHERE id=@id", { ['@id'] = o.id })
        deliveredBatches[o.batch_id] = true
    end

    for batchId, outfitData in pairs(outfitDataByBatch) do
        LSLegacy.Inventory.AddItemInInventory(player, 'outfit', 1, outfitLabelByBatch[batchId], nil, outfitData)
    end

    -- Un colis = une commande (batch_id), pas un article : on compte les
    -- commandes distinctes, pas les lignes/articles individuels.
    local batchCount = 0
    for _ in pairs(deliveredBatches) do batchCount = batchCount + 1 end

    if batchCount == 1 then
        Notify(src, 'Vous avez récupéré votre colis.', 'success')
    elseif batchCount > 1 then
        Notify(src, ('Vous avez récupéré vos colis (%d).'):format(batchCount), 'success')
    else
        Notify(src, 'Votre colis est encore en cours de livraison, repassez plus tard.', 'info')
    end

    if batchCount > 0 then DespawnPropIfEmpty(depName) end
end)
