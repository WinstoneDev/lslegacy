--  MDT — COMMANDE DE PIÈCES (serveur, générique atelier)
--  Onglet MDT réservé aux départements ATELIER (Red's Tunershop, Benny's —
--  chacun déclare Config.MDT.Departments.<dep>.parts). Catalogue = les mêmes
--  pièces que le dépôt physique (Config.Atelier.Parts), débitées du compte
--  entreprise du job, livrées directement dans le stock du dépôt (DataStore
--  atelier_<company>) après un délai — le retrait reste l'interaction ALT/
--  ox_target déjà existante (module/atelier/client/inventory.lua).

LSLegacy.Security.RegisterRateLimit('mdtparts:query', 30)
LSLegacy.Security.RegisterRateLimit('mdtparts:order', 10)
LSLegacy.Security.RegisterRateLimit('mdtparts:cancel', 10)

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS mdt_atelier_parts_orders (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        department               VARCHAR(50)  NOT NULL DEFAULT '',
        batch_id                 VARCHAR(40)  NOT NULL DEFAULT '',
        ordered_by_character_id  INT          DEFAULT NULL,
        ordered_by_name          VARCHAR(100) NOT NULL DEFAULT '',
        item          VARCHAR(50)  NOT NULL,
        quantity      INT          NOT NULL DEFAULT 1,
        price         INT          NOT NULL DEFAULT 0,
        status        VARCHAR(12)  NOT NULL DEFAULT 'en_attente',
        created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
        ready_at      DATETIME     NOT NULL,
        KEY idx_parts_department (department),
        KEY idx_parts_batch (batch_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

local function Notify(src, msg, t) LSLegacy.Events.SendToClient('notify', src, 'Commande de pièces', msg, t or 'info', 6000) end

-- Département MDT + job + config parts du joueur connecté `src`, ou nil si
-- son job n'a pas de commande de pièces configurée.
local function PartsCtx(src)
    local player = LSLegacy.Players.Get(src)
    if not player then return nil end
    local depName = LSLegacy.MDT.GetDepartmentForJob(player.job)
    if not depName then return nil end
    local dep = LSLegacy.MDT.GetDepartment(depName)
    if not dep or not dep.parts then return nil end
    return player, depName, dep
end

-- ── Pont MDT : onglet « Commande de pièces » (lecture) ──────────────
local Handlers = {}

-- Ne liste que les pièces liées à une réparation que ce mécano a le droit
-- d'effectuer (même permission que les options ox_target "Réparer X" du menu
-- véhicule, cf. module/atelier/server/repairs.lua -> RequiredPermission).
Handlers.getCatalogue = function(dep, p, data, reply, depName, src)
    local items = {}
    for id, part in pairs(Config.Atelier.Parts) do
        local perm = LSLegacy.Atelier.RequiredPermissionForPart(part)
        if not perm or LSLegacy.Atelier.HasPerm(src, perm) then
            items[#items + 1] = { id = id, label = Config.Items[id] and Config.Items[id].label or id, price = part.price }
        end
    end
    table.sort(items, function(a, b) return a.label < b.label end)
    reply({
        items = items,
        delaySeconds = dep.parts.DeliveryDelay,
        maxQuantityPerOrder = dep.parts.MaxQuantityPerOrder,
        maxPendingOrders = dep.parts.MaxPendingOrders,
    })
end

Handlers.getHistory = function(dep, p, data, reply, depName)
    local rows = MySQL.Sync.fetchAll([[
        SELECT
            batch_id,
            MIN(id) AS id,
            MIN(created_at) AS created_at,
            MIN(ordered_by_name) AS ordered_by_name,
            SUM(price) AS price,
            COUNT(*) AS item_count,
            MIN(status) AS status,
            MIN(ready_at) AS ready_at,
            GREATEST(0, TIMESTAMPDIFF(SECOND, NOW(), MIN(ready_at))) AS remaining_seconds,
            GROUP_CONCAT(CONCAT_WS('::', item, quantity, price) SEPARATOR ';;') AS items_data
        FROM mdt_atelier_parts_orders
        WHERE department = @dep
        GROUP BY batch_id
        ORDER BY created_at DESC LIMIT 200
    ]], { ['@dep'] = depName }) or {}
    local monthSpend = MySQL.Sync.fetchScalar([[
        SELECT COALESCE(SUM(price), 0) FROM mdt_atelier_parts_orders
        WHERE department = @dep AND status != 'annule' AND created_at >= DATE_FORMAT(NOW(), '%Y-%m-01')
    ]], { ['@dep'] = depName }) or 0
    reply({ orders = rows, monthSpend = monthSpend })
end

LSLegacy.Events.Register('mdtparts:query', function(payload)
    local src = source
    local player, depName, dep = PartsCtx(src)
    if not player or type(payload) ~= 'table' or not payload.action then return end
    local reply = function(res) LSLegacy.Events.SendToClient('mdtparts:queryResult', src, { reqId = payload.reqId, result = res }) end
    if not HasPermission(src, 'manage_stock') then return reply(false) end
    if not LSLegacy.Bank.GetSocietyAccount(player.job) then return reply(false) end
    local h = Handlers[payload.action]
    if not h then return reply(false) end
    h(dep, player, type(payload.data) == 'table' and payload.data or {}, reply, depName, src)
end)

-- ── Commande (panier : plusieurs pièces = UNE seule commande) ──────
LSLegacy.Events.Register('mdtparts:order', function(data)
    local src = source
    local author, depName, dep = PartsCtx(src)
    if not author or type(data) ~= 'table' or not HasPermission(src, 'manage_stock') then return end
    if not LSLegacy.Bank.GetSocietyAccount(author.job) then
        return Notify(src, "Votre entreprise n'a pas de compte actif.", 'error')
    end
    local C = dep.parts

    local items = type(data.items) == 'table' and data.items or {}
    if #items == 0 then return Notify(src, 'Commande invalide.', 'error') end

    -- Chaque article du panier est revalidé côté serveur (jamais confiance en la NUI).
    local validated = {}
    for _, it in ipairs(items) do
        local part = Config.Atelier.Parts[it.item]
        local qty = math.floor(tonumber(it.quantity) or 0)
        if not part or qty <= 0 or qty > C.MaxQuantityPerOrder then
            return Notify(src, 'Commande invalide.', 'error')
        end
        -- Revalidation serveur du filtre de permission : un panier forgé côté NUI
        -- (item non listé dans le catalogue de ce mécano) ne doit jamais passer.
        local perm = LSLegacy.Atelier.RequiredPermissionForPart(part)
        if perm and not LSLegacy.Atelier.HasPerm(src, perm) then
            return Notify(src, "Vous n'avez pas la qualification pour commander cette pièce.", 'error')
        end
        validated[#validated + 1] = { item = it.item, quantity = qty, price = part.price * qty }
    end

    local pendingBatches = MySQL.Sync.fetchScalar(
        "SELECT COUNT(DISTINCT batch_id) FROM mdt_atelier_parts_orders WHERE department=@dep AND status IN ('en_attente','pret')",
        { ['@dep'] = depName }) or 0
    if pendingBatches >= C.MaxPendingOrders then
        return Notify(src, ("L'atelier a déjà %d commande(s) en attente (max %d)."):format(pendingBatches, C.MaxPendingOrders), 'error')
    end

    local total = 0
    for _, it in ipairs(validated) do total = total + it.price end
    if not LSLegacy.Bank.RemoveSocietyMoney(author.job, total, ('Commande de pièces — %d référence(s)'):format(#validated), 'Achat') then
        return Notify(src, 'Fonds insuffisants sur le compte entreprise.', 'error')
    end

    local orderedByName = ((author.characterInfos and author.characterInfos.Prenom or '') .. ' ' .. (author.characterInfos and author.characterInfos.NDF or '')):gsub('^%s+', ''):gsub('%s+$', '')
    -- Le batch_id est l'id (auto-incrémenté, donc unique par construction) du
    -- premier article inséré — même pattern que mdtboutique:order.
    local batchId = nil
    local orderIds = {}
    for _, it in ipairs(validated) do
        local orderId = MySQL.insert.await([[
            INSERT INTO mdt_atelier_parts_orders
                (department, batch_id, ordered_by_character_id, ordered_by_name, item, quantity, price, ready_at)
            VALUES (@dep, @batch, @oc, @on, @item, @qty, @price, DATE_ADD(NOW(), INTERVAL @delay SECOND))
        ]], {
            ['@dep'] = depName, ['@batch'] = batchId or '',
            ['@oc'] = author['boutique-id'], ['@on'] = orderedByName,
            ['@item'] = it.item, ['@qty'] = it.quantity, ['@price'] = it.price,
            ['@delay'] = C.DeliveryDelay,
        })
        if orderId then
            orderIds[#orderIds + 1] = orderId
            if not batchId then
                batchId = tostring(orderId)
                MySQL.Sync.execute('UPDATE mdt_atelier_parts_orders SET batch_id=@b WHERE id=@id', { ['@b'] = batchId, ['@id'] = orderId })
            end
        end
    end

    if #orderIds == 0 then
        LSLegacy.Bank.AddSocietyMoney(author.job, total, 'Commande de pièces — erreur BDD, remboursement', 'Remboursement')
        return Notify(src, 'Erreur base de données.', 'error')
    elseif #orderIds < #validated then
        local refunded = 0
        for i = #orderIds + 1, #validated do refunded = refunded + validated[i].price end
        LSLegacy.Bank.AddSocietyMoney(author.job, refunded, 'Commande de pièces — erreur BDD partielle, remboursement', 'Remboursement')
    end

    Notify(src, ('Commande envoyée : %d référence(s) (%d $).'):format(#orderIds, total), 'success')
    -- Livraison gérée par le thread de scrutation ci-dessous (persiste à un redémarrage serveur).
end)

-- Livraison par scrutation BDD plutôt que Citizen.SetTimeout : un timer en
-- mémoire est perdu si le serveur redémarre avant son échéance, ce qui
-- laissait la commande bloquée en 'en_attente' (jamais livrée au dépôt) alors
-- que le NUI affichait déjà "Prête" (calculé côté client depuis ready_at,
-- indépendamment du statut réel en base).
CreateThread(function()
    while true do
        Wait(15000)
        local batches = MySQL.Sync.fetchAll(
            "SELECT DISTINCT batch_id, department FROM mdt_atelier_parts_orders WHERE status='en_attente' AND ready_at <= NOW()", {}) or {}

        for _, b in ipairs(batches) do
            local affected = MySQL.Sync.execute(
                "UPDATE mdt_atelier_parts_orders SET status='pret' WHERE batch_id=@batch AND status='en_attente'",
                { ['@batch'] = b.batch_id })
            if affected and affected > 0 then
                local dep = LSLegacy.MDT.GetDepartment(b.department)
                local companyId = dep and dep.parts and dep.parts.companyId
                local ds = companyId and LSLegacy.Atelier.GetStash(companyId)
                if ds then
                    local rows = MySQL.Sync.fetchAll(
                        "SELECT item, quantity FROM mdt_atelier_parts_orders WHERE batch_id=@batch", { ['@batch'] = b.batch_id }) or {}
                    for _, it in ipairs(rows) do
                        LSLegacy.DataStore.AddItemInInventory(ds, it.item, it.quantity)
                    end
                    -- Statut "recupere" dès la livraison dans le stock : le retrait
                    -- physique passe ensuite par le dépôt (ALT/ox_target), hors suivi MDT.
                    MySQL.Sync.execute("UPDATE mdt_atelier_parts_orders SET status='recupere' WHERE batch_id=@batch", { ['@batch'] = b.batch_id })
                    for otherSrc, p in pairs(LSLegacy.Players.GetAll()) do
                        if LSLegacy.MDT.GetDepartmentForJob(p.job) == b.department then
                            Notify(otherSrc, 'Une commande de pièces est arrivée au dépôt.', 'success')
                        end
                    end
                end
            end
        end
    end
end)

-- ── Annulation (grade manage_stock uniquement) — annule la commande entière ──
LSLegacy.Events.Register('mdtparts:cancel', function(data)
    local src = source
    local author = PartsCtx(src)
    if not author or not HasPermission(src, 'manage_stock') then return end
    local batchId = tostring(type(data) == 'table' and data.batchId or data or '')
    if batchId == '' then return end
    local rows = MySQL.Sync.fetchAll("SELECT * FROM mdt_atelier_parts_orders WHERE batch_id=@b AND status IN ('en_attente','pret')", { ['@b'] = batchId })
    if not rows or #rows == 0 then return Notify(src, 'Commande introuvable ou déjà livrée.', 'error') end

    local refund, itemCount = 0, #rows
    for _, o in ipairs(rows) do refund = refund + o.price end
    MySQL.Sync.execute("UPDATE mdt_atelier_parts_orders SET status='annule' WHERE batch_id=@b AND status IN ('en_attente','pret')", { ['@b'] = batchId })
    LSLegacy.Bank.AddSocietyMoney(author.job, refund, ('Commande de pièces — commande annulée — remboursement (%d référence(s))'):format(itemCount), 'Remboursement')
    Notify(src, ('Commande annulée, %d $ remboursés.'):format(refund), 'success')
end)
