--  MODULE SOCIETY — serveur : chef de job, factures, pont MDT, achats entreprise.
local C = Config.Society
LSLegacy.Society = LSLegacy.Society or {}

local rateLimits = { ['mdtsociety:query'] = 30, ['society:invoiceNearby'] = 10, ['society:collectInvoice'] = 10 }
for name, limit in pairs(rateLimits) do LSLegacy.Security.RegisterRateLimit(name, limit) end

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS society_invoices (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        society       VARCHAR(40)  NOT NULL,
        target_id     INT          NOT NULL,
        target_name   VARCHAR(100) DEFAULT NULL,
        author_id     INT          DEFAULT NULL,
        author_name   VARCHAR(100) DEFAULT NULL,
        amount        INT          NOT NULL,
        reason        VARCHAR(120) DEFAULT NULL,
        status        VARCHAR(10)  NOT NULL DEFAULT 'pending',
        created_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
        paid_at       TIMESTAMP    NULL DEFAULT NULL,
        KEY idx_society_invoices_society (society, status),
        KEY idx_society_invoices_target (target_id, status)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

local function GetPlayer(src) return LSLegacy.Players.Get(src) end
local function CharName(p) return p and p.characterInfos and ((p.characterInfos.Prenom or '') .. ' ' .. (p.characterInfos.NDF or '')) or '?' end
local function Notify(src, msg, t) LSLegacy.Events.SendToClient('notify', src, 'Entreprise', msg, t or 'info', 5000) end
local function Trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

-- Chef de job : grade max du job (ou Config.Society.BossGrades[job])
function LSLegacy.Society.IsBoss(player)
    if not player then return false end
    local job = player.job
    if not job or job == 'unemployed' then return false end
    local def = LSLegacy.AvailableJobs and LSLegacy.AvailableJobs[job]
    if not def or not def.grades then return false end
    local grade = tonumber(player.job_grade) or 0
    local minGrade = tonumber(C.BossGrades[job])
    if not minGrade then
        minGrade = 0
        for g in pairs(def.grades) do if tonumber(g) and g > minGrade then minGrade = g end end
    end
    return grade >= minGrade
end

-- Le joueur porte-t-il la carte entreprise (valide) de son job ?
function LSLegacy.Society.HasCompanyCard(player)
    if not player or not player.job then return false end
    local account = LSLegacy.Bank.GetSocietyAccount(player.job)
    if not account or not account.card_infos or account.card_blocked then return false end
    for _, item in pairs(player.inventory or {}) do
        if item.name == 'carte' and item.data and item.data.society == player.job
            and tostring(item.data.card_number) == tostring(account.card_infos.card_number) then
            return true
        end
    end
    return false
end

function LSLegacy.Society.GetBalance(job)
    local a = LSLegacy.Bank.GetSocietyAccount(job)
    return a and a.amountMoney or 0
end

local function Log(title, desc)
    if not C.Webhook or C.Webhook == '' then return end
    PerformHttpRequest(C.Webhook, function() end, 'POST', json.encode({ embeds = { {
        title = '[Entreprise] ' .. title, description = desc, color = 3447003,
        footer = { text = 'LSLegacy Society • ' .. os.date('%d/%m/%Y %H:%M:%S') },
    } } }), { ['Content-Type'] = 'application/json' })
end

local function SrcByCharId(charId)
    for src, p in pairs(LSLegacy.Players.GetAll()) do
        if p['boutique-id'] == charId then return src end
    end
    return nil
end

-- ── Factures (réglées au TPE, depuis le MDT) ─────────────────────
local function SettleInvoice(inv, payerName)
    MySQL.Sync.execute("UPDATE society_invoices SET status = 'paid', paid_at = NOW() WHERE id = @id AND status = 'pending'", { ['@id'] = inv.id })
    LSLegacy.Bank.AddSocietyMoney(inv.society, inv.amount, ('Facture #%d — %s (%s)'):format(inv.id, inv.reason or 'Facture', payerName), 'Facture')
    Log('Facture réglée', ('#%d · %s · %d $ · %s'):format(inv.id, LSLegacy.Jobs.GetJobLabel(inv.society) or inv.society, inv.amount, payerName))
    local authorSrc = inv.author_id and SrcByCharId(inv.author_id)
    if authorSrc then Notify(authorSrc, ('Facture #%d de %d $ réglée par %s.'):format(inv.id, inv.amount, payerName), 'success') end
end

local function OpenInvoiceTpe(inv, targetSrc)
    LSLegacy.Bank.OpenPaymentMenu(targetSrc, ('Facture %s — %s'):format(LSLegacy.Jobs.GetJobLabel(inv.society) or inv.society, inv.reason or ''), inv.amount, {
        meta = { type = 'society_invoice', refId = inv.id },
    })
end

-- Paiement sur place via TPE (facture présentée par l'agent)
LSLegacy.Bank.RegisterPaymentResultHandler('society_invoice', function(refId, success)
    if not success then return end
    local rows = MySQL.Sync.fetchAll("SELECT * FROM society_invoices WHERE id = @id AND status = 'pending' LIMIT 1", { ['@id'] = tonumber(refId) or -1 })
    local inv = rows and rows[1]
    if not inv then return end
    SettleInvoice(inv, inv.target_name or '?')
end)

local function CreateInvoice(author, targetPlayer, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > C.InvoiceMaxAmount then return nil, 'Montant invalide.' end
    reason = Trim(reason):sub(1, C.InvoiceMaxReason)
    if reason == '' then return nil, 'Motif manquant.' end
    if not LSLegacy.Bank.GetSocietyAccount(author.job) then return nil, "Votre entreprise n'a pas de compte bancaire." end
    local id = MySQL.insert.await('INSERT INTO society_invoices (society, target_id, target_name, author_id, author_name, amount, reason) VALUES (@s, @t, @tn, @a, @an, @amt, @r)', {
        ['@s'] = author.job, ['@t'] = targetPlayer['boutique-id'], ['@tn'] = CharName(targetPlayer),
        ['@a'] = author['boutique-id'], ['@an'] = CharName(author), ['@amt'] = amount, ['@r'] = reason,
    })
    if not id then return nil, 'Erreur BDD.' end
    Log('Facture émise', ('#%d · %s · %d $ · %s → %s · %s'):format(id, LSLegacy.Jobs.GetJobLabel(author.job) or author.job, amount, CharName(author), CharName(targetPlayer), reason))
    return id
end

-- Facturer un joueur proche depuis le MDT : le TPE s'ouvre immédiatement chez le client
LSLegacy.Events.Register('society:invoiceNearby', function(data)
    local src = source
    local author = GetPlayer(src)
    if not author or type(data) ~= 'table' then return end
    local target = GetPlayer(tonumber(data.targetSrc) or -1)
    if not target or target.source == src then return Notify(src, 'Client introuvable.', 'error') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target.source))) > 6.0 then return Notify(src, 'Client trop loin.', 'error') end
    local id, err = CreateInvoice(author, target, data.amount, data.reason)
    if not id then return Notify(src, err, 'error') end
    Notify(src, ('Facture #%d de %d $ présentée à %s.'):format(id, math.floor(tonumber(data.amount)), CharName(target)), 'success')
    OpenInvoiceTpe({ id = id, society = author.job, reason = Trim(data.reason), amount = math.floor(tonumber(data.amount)) }, target.source)
end)

-- Représenter une facture en attente (client refusé / parti) : il doit être à côté
LSLegacy.Events.Register('society:collectInvoice', function(id)
    local src = source
    local p = GetPlayer(src)
    if not p then return end
    local rows = MySQL.Sync.fetchAll("SELECT * FROM society_invoices WHERE id = @id AND society = @s AND status = 'pending' LIMIT 1", { ['@id'] = tonumber(id) or -1, ['@s'] = p.job })
    local inv = rows and rows[1]
    if not inv then return Notify(src, 'Facture introuvable ou déjà réglée.', 'error') end
    local tsrc = SrcByCharId(inv.target_id)
    if not tsrc then return Notify(src, 'Le client n\'est pas en ville.', 'error') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(tsrc))) > 6.0 then return Notify(src, 'Le client doit être à côté de vous.', 'error') end
    OpenInvoiceTpe(inv, tsrc)
    Notify(src, ('Facture #%d présentée à %s.'):format(inv.id, inv.target_name or '?'), 'success')
end)

-- ── Pont MDT : onglet « Entreprise » ─────────────────────────────
local Handlers = {}

Handlers.getOverview = function(p, data, reply)
    local job = p.job
    local account = LSLegacy.Bank.GetSocietyAccount(job)
    local invoices = MySQL.Sync.fetchAll('SELECT * FROM society_invoices WHERE society = @s ORDER BY created_at DESC LIMIT 100', { ['@s'] = job }) or {}
    local stats = MySQL.Sync.fetchAll([[
        SELECT
            SUM(CASE WHEN status = 'paid' AND paid_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN amount ELSE 0 END) AS paid_week,
            SUM(CASE WHEN status = 'paid' AND paid_at >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN amount ELSE 0 END) AS paid_month,
            SUM(CASE WHEN status = 'pending' THEN amount ELSE 0 END) AS pending_total,
            SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS pending_count
        FROM society_invoices WHERE society = @s
    ]], { ['@s'] = job })
    local tx = {}
    if account then
        local all = account.transactions or {}
        for i = #all, math.max(1, #all - 60), -1 do tx[#tx + 1] = all[i] end
    end
    reply({
        job = job, label = LSLegacy.Jobs.GetJobLabel(job) or job,
        isBoss = LSLegacy.Society.IsBoss(p),
        hasAccount = account ~= nil,
        balance = account and account.amountMoney or 0,
        iban = account and account.iban or nil,
        hasCard = account and account.card_infos ~= nil or false,
        cardBlocked = account and account.card_blocked or false,
        transactions = tx,
        invoices = invoices,
        stats = stats and stats[1] or {},
    })
end

Handlers.cancelInvoice = function(p, data, reply)
    local id = tonumber(data.id) or -1
    local rows = MySQL.Sync.fetchAll("SELECT * FROM society_invoices WHERE id = @id AND society = @s AND status = 'pending' LIMIT 1", { ['@id'] = id, ['@s'] = p.job })
    local inv = rows and rows[1]
    if not inv then return reply({ ok = false, message = 'Facture introuvable.' }) end
    if inv.author_id ~= p['boutique-id'] and not LSLegacy.Society.IsBoss(p) then return reply({ ok = false, message = 'Seul l\'émetteur ou le chef peut annuler.' }) end
    MySQL.Sync.execute("UPDATE society_invoices SET status = 'cancelled' WHERE id = @id", { ['@id'] = id })
    reply({ ok = true })
end

Handlers.getNearby = function(p, data, reply)
    local me = GetEntityCoords(GetPlayerPed(p.source))
    local out = {}
    for src, other in pairs(LSLegacy.Players.GetAll()) do
        if src ~= p.source then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 and #(me - GetEntityCoords(ped)) <= 6.0 then
                out[#out + 1] = { src = src, name = CharName(other) }
            end
        end
    end
    reply(out)
end

LSLegacy.Events.Register('mdtsociety:query', function(payload)
    local src = source
    local p = GetPlayer(src)
    if not p or type(payload) ~= 'table' or not payload.action then return end
    local reply = function(res) LSLegacy.Events.SendToClient('mdtsociety:queryResult', src, { reqId = payload.reqId, result = res }) end
    local h = Handlers[payload.action]
    if not h or not p.job or p.job == 'unemployed' then return reply(false) end
    h(p, type(payload.data) == 'table' and payload.data or {}, reply)
end)

-- Exports pour les autres modules
exports('isJobBoss', function(src) return LSLegacy.Society.IsBoss(GetPlayer(src)) end)
exports('getSocietyBalance', function(job) return LSLegacy.Society.GetBalance(job) end)
exports('addSocietyMoney', function(job, amount, message) return LSLegacy.Bank.AddSocietyMoney(job, amount, message) end)
exports('removeSocietyMoney', function(job, amount, message) return LSLegacy.Bank.RemoveSocietyMoney(job, amount, message) end)
