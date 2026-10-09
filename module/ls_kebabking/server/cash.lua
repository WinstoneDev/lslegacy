-- ls_kebabking (serveur) — caisse : facturation et coffre de l'entreprise.
--
-- Aucune économie n'est recréée : la facture passe par le menu de paiement
-- du module bank de LSLegacy (espèces ou carte, plafonds et PIN inclus).

local Core = exports['lslegacy']

local PAYMENT_KIND = KKConfig.Prefix
local SAFE_NAME    = KKConfig.Prefix .. '_safe'

local pendingInvoices = {}   -- [refId] = { employee, employeeName, target, amount, label }
local invoiceCounter  = 0

local function EnsureSafe()
    Core:ensureDataStore(SAFE_NAME, 'safe', 100)
    return SAFE_NAME
end

-- Accès au coffre : employé gradé, en service, devant la caisse.
function KK.SafeGuard(src, name, _action, _item)
    if name ~= SAFE_NAME then return false end
    if not KK.Sec.Employee(src, KKConfig.Cash.safeMinGrade) then return false end
    if not KK.IsOnDuty(src) then return false end
    return KK.Sec.NearCoords(src, KKConfig.Cash.coords, KKConfig.Cash.distance + KKConfig.Security.maxDistance)
end

-- ── Facturation ──────────────────────────────────────────────────────────
RegisterNetEvent(KKConfig.Prefix .. ':cash:invoice', function(targetSrc, amount, label)
    local src = source
    if not KK.Sec.Allow(src, 'invoice') then return end
    if not KKConfig.Cash.enabled then return end

    -- Arguments
    targetSrc = tonumber(targetSrc)
    amount    = tonumber(amount)
    if not targetSrc or not amount then return end
    amount = math.floor(amount)
    if amount < 1 or amount > KKConfig.Cash.maxAmount then
        KK.Notify(src, ("Montant invalide (1 à %d $)."):format(KKConfig.Cash.maxAmount), 'error')
        return
    end
    if type(label) ~= 'string' or label == '' then label = 'Commande ' .. KKConfig.JobLabel end
    label = label:sub(1, 60)

    -- Employé
    local employee = KK.CanWork(src, KKConfig.MinGrade, KKConfig.Cash.coords,
        KKConfig.Cash.distance + KKConfig.Security.maxDistance)
    if not employee then return end

    -- Client
    if targetSrc == src then
        KK.Notify(src, "Vous ne pouvez pas vous facturer vous-même.", 'error')
        return
    end
    local target = KK.Sec.Player(targetSrc)
    if not target then
        KK.Notify(src, "Ce client n'est plus connecté.", 'error')
        return
    end

    local employeePed = GetPlayerPed(src)
    local targetPed   = GetPlayerPed(targetSrc)
    if not targetPed or targetPed == 0 then return end
    if #(GetEntityCoords(employeePed) - GetEntityCoords(targetPed)) > KKConfig.Cash.clientDistance then
        KK.Notify(src, "Le client est trop loin de la caisse.", 'error')
        return
    end

    invoiceCounter = invoiceCounter + 1
    local refId = ('%s_%d'):format(KKConfig.Prefix, invoiceCounter)
    pendingInvoices[refId] = {
        employee     = src,
        employeeName = employee.name or 'Employé',
        target       = targetSrc,
        amount       = amount,
        label        = label,
    }

    local opened = Core:openPaymentMenu(targetSrc, ('%s — %s'):format(KKConfig.JobLabel, label), amount, PAYMENT_KIND, refId)
    if not opened then
        pendingInvoices[refId] = nil
        KK.Notify(src, "Impossible d'ouvrir le paiement pour ce client.", 'error')
        return
    end

    KK.Notify(src, ("Facture de %d $ envoyée à %s."):format(amount, target.name or 'client'), 'success')
end)

-- Résultat du paiement, renvoyé par foodapi (module bank).
AddEventHandler('lslegacy:foodapi:paymentResult', function(kind, refId, success)
    if kind ~= PAYMENT_KIND then return end
    local invoice = pendingInvoices[refId]
    if not invoice then return end
    pendingInvoices[refId] = nil

    if not success then
        KK.Notify(invoice.employee, "Le client a refusé ou n'a pas pu payer la facture.", 'error')
        return
    end

    if KKConfig.Cash.safeToCompany then
        EnsureSafe()
        Core:addDataStoreMoney(SAFE_NAME, invoice.amount)
    end

    KK.Notify(invoice.employee, ("Facture réglée : %d $."):format(invoice.amount), 'success')
    KK.Notify(invoice.target, ("Vous avez réglé %d $ chez %s."):format(invoice.amount, KKConfig.JobLabel), 'success')
    KK.Log(('%s (%s) a encaissé %d $ — %s'):format(invoice.employeeName, invoice.employee, invoice.amount, invoice.label))
end)

-- Un joueur qui se déconnecte annule ses factures en attente.
AddEventHandler('playerDropped', function()
    local src = source
    for refId, invoice in pairs(pendingInvoices) do
        if invoice.employee == src or invoice.target == src then
            pendingInvoices[refId] = nil
        end
    end
end)

-- ── Coffre de l'entreprise ───────────────────────────────────────────────
RegisterNetEvent(KKConfig.Prefix .. ':cash:safe', function()
    local src = source
    if not KK.Sec.Allow(src, 'safe') then return end
    if not KKConfig.Cash.enabled then return end

    local player = KK.CanWork(src, KKConfig.Cash.safeMinGrade, KKConfig.Cash.coords,
        KKConfig.Cash.distance + KKConfig.Security.maxDistance)
    if not player then return end

    EnsureSafe()
    Core:syncDataStores(src)
    TriggerClientEvent(KKConfig.Prefix .. ':container:open', src, SAFE_NAME,
        KKConfig.JobLabel .. ' — Coffre', 100)
end)
