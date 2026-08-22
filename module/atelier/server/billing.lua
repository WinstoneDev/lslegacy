-- Les prestations s'accumulent sur un "ticket" ouvert par plaque jusqu'à ce qu'un mécano déclenche la facture finale.

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS atelier_invoices (
        id                    INT AUTO_INCREMENT PRIMARY KEY,
        company               VARCHAR(20)  NOT NULL,
        plate                 VARCHAR(12)  NOT NULL,
        customer_character_id INT          DEFAULT NULL,
        customer_name         VARCHAR(100) NOT NULL DEFAULT '',
        mecano_character_id   INT          DEFAULT NULL,
        mecano_name           VARCHAR(100) NOT NULL DEFAULT '',
        total                 INT          NOT NULL DEFAULT 0,
        status                VARCHAR(20)  NOT NULL DEFAULT 'open',
        created_at            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        paid_at               DATETIME     DEFAULT NULL,
        KEY idx_atelier_invoices_plate (plate),
        KEY idx_atelier_invoices_customer (customer_character_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS atelier_invoice_lines (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        invoice_id INT          NOT NULL,
        label      VARCHAR(150) NOT NULL,
        amount     INT          NOT NULL DEFAULT 0,
        part_item  VARCHAR(60)  DEFAULT NULL,
        KEY idx_atelier_invoice_lines_invoice (invoice_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- [plate] = { companyId, customerSrc, customerCharId, customerName, lines = { {label, amount, partItem} }, total }
LSLegacy.Atelier.Tickets = LSLegacy.Atelier.Tickets or {}

local function GetOrCreateTicket(plate, companyId, customerSrc)
    local ticket = LSLegacy.Atelier.Tickets[plate]
    if ticket then return ticket end

    local customer = LSLegacy.Atelier.GetPlayer(customerSrc)
    if not customer then return nil end

    ticket = {
        companyId      = companyId,
        customerSrc    = customerSrc,
        customerCharId = customer["boutique-id"],
        customerName   = GetPlayerName(customerSrc) or 'Client',
        lines          = {},
        total          = 0,
    }
    LSLegacy.Atelier.Tickets[plate] = ticket
    return ticket
end

-- Ajoute une ligne de prestation au ticket ouvert d'une plaque (créé si
-- nécessaire). Revient false si le client n'est plus valide.
-- @return boolean ok
function LSLegacy.Atelier.AddInvoiceLine(plate, companyId, customerSrc, label, amount, partItem)
    local ticket = GetOrCreateTicket(plate, companyId, customerSrc)
    if not ticket then return false end

    ticket.lines[#ticket.lines + 1] = { label = label, amount = amount, partItem = partItem }
    ticket.total = ticket.total + amount
    return true
end

function LSLegacy.Atelier.GetTicket(plate)
    return LSLegacy.Atelier.Tickets[plate]
end

-- Facture finale

LSLegacy.Events.Register('atelier:requestInvoice', function(data)
    local src = source
    local ok = LSLegacy.Atelier.CanAct(src, 'billing')
    if not ok then return end
    if not data or not data.vehNet then return end

    local entity = NetworkGetEntityFromNetworkId(data.vehNet)
    if not DoesEntityExist(entity) then return end
    local plate = GetVehicleNumberPlateText(entity):upper()

    local ticket = LSLegacy.Atelier.Tickets[plate]
    if not ticket or #ticket.lines == 0 then
        LSLegacy.Atelier.Notify(src, "Aucune prestation en attente pour ce véhicule.", 'error')
        return
    end

    LSLegacy.Events.SendToClient('atelier:invoicePreview', src, {
        plate = plate, lines = ticket.lines, total = ticket.total, customerName = ticket.customerName,
    })
end)

LSLegacy.Events.Register('atelier:finalizeInvoice', function(data)
    local src = source
    local ok = LSLegacy.Atelier.CanAct(src, 'billing')
    if not ok then return end
    if not data or not data.plate then return end

    local plate  = data.plate:upper()
    local ticket = LSLegacy.Atelier.Tickets[plate]
    if not ticket or #ticket.lines == 0 then return end

    local mecano = LSLegacy.Atelier.GetPlayer(src)
    ticket.mecanoCharId = mecano and mecano["boutique-id"] or nil
    ticket.mecanoName   = GetPlayerName(src) or 'Mécanicien'

    LSLegacy.Bank.OpenPaymentMenu(ticket.customerSrc, 'Facture atelier — ' .. plate, ticket.total, {
        meta = { type = 'atelier', refId = plate },
    })
end)

LSLegacy.Bank.RegisterPaymentResultHandler('atelier', function(plate, success)
    local ticket = LSLegacy.Atelier.Tickets[plate]
    if not ticket then return end

    if not success then
        if ticket.customerSrc then
            LSLegacy.Atelier.Notify(ticket.customerSrc, Lang.Atelier.invoice_refused, 'error')
        end
        return
    end

    LSLegacy.Atelier.Tickets[plate] = nil

    MySQL.Async.insert(
        'INSERT INTO atelier_invoices (company, plate, customer_character_id, customer_name, mecano_character_id, mecano_name, total, status, paid_at) ' ..
        'VALUES (@company, @plate, @custId, @custName, @mecaId, @mecaName, @total, @status, NOW())',
        {
            ['@company']  = ticket.companyId,
            ['@plate']    = plate,
            ['@custId']   = ticket.customerCharId,
            ['@custName'] = ticket.customerName,
            ['@mecaId']   = ticket.mecanoCharId,
            ['@mecaName'] = ticket.mecanoName,
            ['@total']    = ticket.total,
            ['@status']   = 'paid',
        },
        function(invoiceId)
            if not invoiceId then return end
            for _, line in ipairs(ticket.lines) do
                MySQL.Async.execute(
                    'INSERT INTO atelier_invoice_lines (invoice_id, label, amount, part_item) VALUES (@id, @label, @amount, @item)',
                    { ['@id'] = invoiceId, ['@label'] = line.label, ['@amount'] = line.amount, ['@item'] = line.partItem }
                )
            end
        end
    )

    if ticket.customerSrc then
        LSLegacy.Atelier.Notify(ticket.customerSrc, string.format(Lang.Atelier.invoice_created, ticket.total), 'success')
    end
end)

-- Un ticket abandonné reste en mémoire tant que le serveur tourne ; purge après 6h.
CreateThread(function()
    while true do
        Wait(3600000)
        -- Pas d'horodatage individuel : on ne purge que si le client associé est hors ligne.
        for plate, ticket in pairs(LSLegacy.Atelier.Tickets) do
            if not LSLegacy.Atelier.GetPlayer(ticket.customerSrc) then
                LSLegacy.Atelier.Tickets[plate] = nil
            end
        end
    end
end)
