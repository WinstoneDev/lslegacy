-- Postes de tuning (peinture/jantes/néons/vitres/perf/turbo/nettoyage/réparation)
-- — les mods esthétiques/performance sont appliqués côté client à titre
-- d'aperçu (natifs véhicule, syncés nativement par FiveM) ; nettoyage et
-- réparation, eux, ne sont exécutés côté client qu'APRÈS validation ici.
-- Dans tous les cas, seuls permission et facturation font autorité côté
-- serveur, comme pour les réparations classiques.
--
-- Deux modes de paiement au choix du mécano dans le panier :
--   'customer' (défaut) : facturé au client le plus proche du véhicule, comme
--                          n'importe quelle prestation atelier (ticket ouvert
--                          par plaque, payé ensuite via la facture classique).
--   'company'            : payé directement par la caisse de l'entreprise
--                          (solde `money` du DataStore atelier, cf.
--                          server/inventory.lua) — aucun client requis,
--                          facture enregistrée directement comme payée.

local function RequiredPermission(category)
    if category == 'performance' then return 'performance' end
    if category == 'clean' then return 'maintenance' end
    return 'customization' -- 'customization' et tout le reste (jantes/peinture/néons/vitres/carrosserie)
end

-- Enregistre directement une facture payée (mode 'company', pas de ticket
-- client à finaliser) — même schéma que le paiement classique validé dans
-- server/billing.lua, pour que la compta reste cohérente entre les deux modes.
local function RecordPaidInvoice(companyId, plate, mecanoCharId, mecanoName, lines, total)
    MySQL.Async.insert(
        'INSERT INTO atelier_invoices (company, plate, customer_character_id, customer_name, mecano_character_id, mecano_name, total, status, paid_at) ' ..
        'VALUES (@company, @plate, NULL, @custName, @mecaId, @mecaName, @total, @status, NOW())',
        {
            ['@company']  = companyId,
            ['@plate']    = plate,
            ['@custName'] = 'Société (entreprise)',
            ['@mecaId']   = mecanoCharId,
            ['@mecaName'] = mecanoName,
            ['@total']    = total,
            ['@status']   = 'paid',
        },
        function(invoiceId)
            if not invoiceId then return end
            for _, line in ipairs(lines) do
                MySQL.Async.execute(
                    'INSERT INTO atelier_invoice_lines (invoice_id, label, amount, part_item) VALUES (@id, @label, @amount, NULL)',
                    { ['@id'] = invoiceId, ['@label'] = line.label, ['@amount'] = line.amount }
                )
            end
        end
    )
end

LSLegacy.Events.Register('atelier:requestTuningCheckout', function(data)
    local src = source
    if not data or not data.vehNet or type(data.items) ~= 'table' or #data.items == 0 then return end

    local companyId = LSLegacy.Atelier.GetCompany(src)
    if not companyId or not LSLegacy.Atelier.IsOnDuty(src) then
        LSLegacy.Events.SendToClient('atelier:tuningCheckoutResult', src, { success = false })
        return
    end
    local grade = LSLegacy.Atelier.GetGrade(src)

    -- Revalidation intégrale ici : chaque ligne du panier envoyée par le client
    -- n'est qu'une proposition, jamais une autorité (prix/permission recalculés).
    local validItems, subtotal = {}, 0
    for _, item in ipairs(data.items) do
        if type(item) == 'table' and item.category and item.label and tonumber(item.price) then
            local ok = LSLegacy.Atelier.HasPermission(companyId, grade, RequiredPermission(item.category))
            if ok then
                validItems[#validItems + 1] = {
                    label  = item.label,
                    price  = math.floor(tonumber(item.price)),
                    action = (item.action == 'clean') and item.action or nil,
                }
                subtotal = subtotal + math.floor(tonumber(item.price))
            end
        end
    end

    if #validItems == 0 then
        LSLegacy.Events.SendToClient('atelier:tuningCheckoutResult', src, { success = false })
        return
    end

    local entity = NetworkGetEntityFromNetworkId(data.vehNet)
    if not DoesEntityExist(entity) then
        LSLegacy.Events.SendToClient('atelier:tuningCheckoutResult', src, { success = false })
        return
    end
    local plate = GetVehicleNumberPlateText(entity):upper()

    -- Réduction : jamais fait confiance côté client au-delà d'un pourcentage borné 0-100.
    local discountPercent = math.max(0, math.min(100, math.floor(tonumber(data.discountPercent) or 0)))
    local discountAmount  = math.floor(subtotal * discountPercent / 100)
    local total           = subtotal - discountAmount

    local paymentMode = (data.paymentMode == 'company') and 'company' or 'customer'
    -- 100% de réduction (ou plus, borné ci-dessus) : rien à facturer, ni au
    -- client ni à la société — on applique simplement les prestations.
    local isFree = total <= 0

    if paymentMode == 'company' then
        if not isFree then
            local ds = LSLegacy.Atelier.GetStash(companyId)
            if not ds or not LSLegacy.DataStore.RemoveMoney(ds, total) then
                LSLegacy.Atelier.Notify(src, string.format("Fonds de l'entreprise insuffisants (solde : %d$).", ds and LSLegacy.DataStore.GetMoney(ds) or 0), 'error')
                LSLegacy.Events.SendToClient('atelier:tuningCheckoutResult', src, { success = false })
                return
            end
        end

        local lines = {}
        for _, item in ipairs(validItems) do
            lines[#lines + 1] = { label = item.label, amount = item.price }
        end
        if discountAmount > 0 then
            lines[#lines + 1] = { label = string.format('Remise (-%d%%)', discountPercent), amount = -discountAmount }
        end

        local mecano = LSLegacy.Atelier.GetPlayer(src)
        RecordPaidInvoice(companyId, plate, mecano and mecano["boutique-id"] or nil, GetPlayerName(src) or 'Mécanicien', lines, total)
        LSLegacy.Atelier.Notify(src, isFree
            and string.format('%d prestation(s) offerte(s) par la société.', #validItems)
            or string.format('%d prestation(s) payée(s) par la société pour %d$.', #validItems, total), 'success')
    elseif isFree then
        for _, item in ipairs(validItems) do
            LSLegacy.Atelier.AddInvoiceLine(plate, companyId, item.label, item.price)
        end
        if discountAmount > 0 then
            LSLegacy.Atelier.AddInvoiceLine(plate, companyId, string.format('Remise (-%d%%)', discountPercent), -discountAmount)
        end
        -- Le client n'a plus besoin d'être présent (le ticket suit le véhicule) :
        -- on le prévient seulement s'il se trouve là, sans bloquer la prestation.
        local nearbyCustomer = LSLegacy.Atelier.GetNearestCustomer(entity, src)
        if nearbyCustomer then
            LSLegacy.Atelier.Notify(nearbyCustomer, string.format('%d prestation(s) offerte(s), aucun montant à régler.', #validItems), 'success')
        end
        LSLegacy.Atelier.Notify(src, string.format('%d prestation(s) appliquée(s) gratuitement.', #validItems), 'success')
    else
        for _, item in ipairs(validItems) do
            LSLegacy.Atelier.AddInvoiceLine(plate, companyId, item.label, item.price)
        end
        if discountAmount > 0 then
            LSLegacy.Atelier.AddInvoiceLine(plate, companyId, string.format('Remise (-%d%%)', discountPercent), -discountAmount)
        end
        local nearbyCustomer = LSLegacy.Atelier.GetNearestCustomer(entity, src)
        if nearbyCustomer then
            LSLegacy.Atelier.Notify(nearbyCustomer, string.format('%d prestation(s) effectuée(s) pour %d$, en attente de facturation.', #validItems, total), 'info')
        end
    end

    -- Force une sauvegarde immédiate de persistent_vehicles (même précaution que
    -- LSLegacy.Atelier.RepairComponent) plutôt que d'attendre le tick périodique de l'AP.
    if LSLegacy.Event['ap:updateVehicle'] then
        LSLegacy.Event['ap:updateVehicle'](data.vehNet)
    end

    LSLegacy.Events.SendToClient('atelier:tuningCheckoutResult', src, { success = true, items = validItems })
end)
