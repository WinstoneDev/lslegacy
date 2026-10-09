-- ls_aldentes (serveur) — caisse : facturation et coffre de l'entreprise.
--
-- Aucune économie n'est recréée : la facture passe par le menu de paiement
-- du module bank de LSLegacy (espèces ou carte, plafonds et PIN inclus).

local Core = exports['lslegacy']

local PAYMENT_KIND = ALDConfig.Prefix
local SAFE_NAME    = ALDConfig.Prefix .. '_safe'

local pendingInvoices = {}   -- [refId] = { employee, employeeName, target, amount, label }
local invoiceCounter  = 0

local function EnsureSafe()
    Core:ensureDataStore(SAFE_NAME, 'safe', 100)
    return SAFE_NAME
end

-- Accès au coffre : employé gradé, en service, devant la caisse.
function ALD.SafeGuard(src, name, _action, _item)
    if name ~= SAFE_NAME then return false end
    if not ALD.Sec.Employee(src, ALDConfig.Cash.safeMinGrade) then return false end
    if not ALD.IsOnDuty(src) then return false end
    return ALD.Sec.NearCoords(src, ALDConfig.Cash.coords, ALDConfig.Cash.distance + ALDConfig.Security.maxDistance)
end

-- ── Facturation ──────────────────────────────────────────────────────────
RegisterNetEvent(ALDConfig.Prefix .. ':cash:invoice', function(targetSrc, amount, label)
    local src = source
    if not ALD.Sec.Allow(src, 'invoice') then return end
    if not ALDConfig.Cash.enabled then return end

    -- Arguments
    targetSrc = tonumber(targetSrc)
    amount    = tonumber(amount)
    if not targetSrc or not amount then return end
    amount = math.floor(amount)
    if amount < 1 or amount > ALDConfig.Cash.maxAmount then
        ALD.Notify(src, ("Montant invalide (1 à %d $)."):format(ALDConfig.Cash.maxAmount), 'error')
        return
    end
    if type(label) ~= 'string' or label == '' then label = 'Commande ' .. ALDConfig.JobLabel end
    label = label:sub(1, 60)

    -- Employé
    local employee = ALD.CanWork(src, ALDConfig.MinGrade, ALDConfig.Cash.coords,
        ALDConfig.Cash.distance + ALDConfig.Security.maxDistance)
    if not employee then return end

    -- Client
    if targetSrc == src then
        ALD.Notify(src, "Vous ne pouvez pas vous facturer vous-même.", 'error')
        return
    end
    local target = ALD.Sec.Player(targetSrc)
    if not target then
        ALD.Notify(src, "Ce client n'est plus connecté.", 'error')
        return
    end

    local employeePed = GetPlayerPed(src)
    local targetPed   = GetPlayerPed(targetSrc)
    if not targetPed or targetPed == 0 then return end
    if #(GetEntityCoords(employeePed) - GetEntityCoords(targetPed)) > ALDConfig.Cash.clientDistance then
        ALD.Notify(src, "Le client est trop loin de la caisse.", 'error')
        return
    end

    invoiceCounter = invoiceCounter + 1
    local refId = ('%s_%d'):format(ALDConfig.Prefix, invoiceCounter)
    pendingInvoices[refId] = {
        employee     = src,
        employeeName = employee.name or 'Employé',
        target       = targetSrc,
        amount       = amount,
        label        = label,
    }

    local opened = Core:openPaymentMenu(targetSrc, ('%s — %s'):format(ALDConfig.JobLabel, label), amount, PAYMENT_KIND, refId)
    if not opened then
        pendingInvoices[refId] = nil
        ALD.Notify(src, "Impossible d'ouvrir le paiement pour ce client.", 'error')
        return
    end

    ALD.Notify(src, ("Facture de %d $ envoyée à %s."):format(amount, target.name or 'client'), 'success')
end)

-- Résultat du paiement, renvoyé par foodapi (module bank).
AddEventHandler('lslegacy:foodapi:paymentResult', function(kind, refId, success)
    if kind ~= PAYMENT_KIND then return end
    local invoice = pendingInvoices[refId]
    if not invoice then return end
    pendingInvoices[refId] = nil

    if not success then
        ALD.Notify(invoice.employee, "Le client a refusé ou n'a pas pu payer la facture.", 'error')
        return
    end

    if ALDConfig.Cash.safeToCompany then
        EnsureSafe()
        Core:addDataStoreMoney(SAFE_NAME, invoice.amount)
    end

    ALD.Notify(invoice.employee, ("Facture réglée : %d $."):format(invoice.amount), 'success')
    ALD.Notify(invoice.target, ("Vous avez réglé %d $ chez %s."):format(invoice.amount, ALDConfig.JobLabel), 'success')
    ALD.Log(('%s (%s) a encaissé %d $ — %s'):format(invoice.employeeName, invoice.employee, invoice.amount, invoice.label))
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
RegisterNetEvent(ALDConfig.Prefix .. ':cash:safe', function()
    local src = source
    if not ALD.Sec.Allow(src, 'safe') then return end
    if not ALDConfig.Cash.enabled then return end

    local player = ALD.CanWork(src, ALDConfig.Cash.safeMinGrade, ALDConfig.Cash.coords,
        ALDConfig.Cash.distance + ALDConfig.Security.maxDistance)
    if not player then return end

    EnsureSafe()
    Core:syncDataStores(src)
    TriggerClientEvent(ALDConfig.Prefix .. ':container:open', src, SAFE_NAME,
        ALDConfig.JobLabel .. ' — Coffre', 100)
end)
