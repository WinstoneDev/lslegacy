-- Aucun devis : affiche les prestations déjà accumulées côté serveur, puis déclenche le paiement.

local function Notify(msg, type)
    TriggerEvent(Config.Atelier.NotifyEvent, 'Atelier', msg, 5000, type or 'info')
end

local function CanBill()
    return Atelier.IsOnDuty() and LSLegacy.Atelier.HasPermission(Atelier.GetCompanyId(), Atelier.GetGrade(), 'billing')
end

LSLegacy.RegisterClientEvent('atelier:invoicePreview', function(data)
    if not data then return end

    local options = {
        { title = 'Client : ' .. data.customerName, disabled = true },
    }
    for _, line in ipairs(data.lines) do
        options[#options + 1] = { title = line.label, description = line.amount .. ' $', disabled = true }
    end
    options[#options + 1] = {
        title = 'Total : ' .. data.total .. ' $',
        description = 'Confirmer et envoyer au TPE / espèces du client',
        icon = 'fa-solid fa-file-invoice-dollar',
        onSelect = function()
            LSLegacy.SendEventToServer('atelier:finalizeInvoice', { plate = data.plate })
        end,
    }

    lib.registerContext({ id = 'atelier_invoice_preview', title = 'Facture — ' .. data.plate, options = options })
    lib.showContext('atelier_invoice_preview')
end)

exports.ox_target:addGlobalVehicle({
    {
        name = 'atelier_invoice', icon = 'fa-solid fa-file-invoice-dollar', label = 'Facture',
        distance = 3.0, canInteract = CanBill,
        onSelect = function(data)
            LSLegacy.SendEventToServer('atelier:requestInvoice', { vehNet = NetworkGetNetworkIdFromEntity(data.entity) })
        end,
    },
})
