-- ls_burgershot (client) — caisse : facturation client et coffre entreprise.
-- La facturation réutilise le menu de paiement du module bank de LSLegacy
-- (espèces / carte), aucun système d'argent n'est recréé ici.

local function NearbyPlayers(maxDistance)
    local list = {}
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    for _, playerId in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(playerId)
        if ped ~= myPed and DoesEntityExist(ped) then
            local dist = #(myCoords - GetEntityCoords(ped))
            if dist <= maxDistance then
                list[#list + 1] = {
                    serverId = GetPlayerServerId(playerId),
                    name     = GetPlayerName(playerId),
                    distance = dist,
                }
            end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

local function AskInvoice(target)
    local input = lib.inputDialog('Facture — ' .. target.name, {
        { type = 'number', label = 'Montant ($)', required = true, min = 1, max = BSConfig.Cash.maxAmount, icon = 'dollar-sign' },
        { type = 'input',  label = 'Description', required = true, max = 60, default = 'Commande ' .. BSConfig.JobLabel },
    })
    if not input then return end

    local amount = math.floor(tonumber(input[1]) or 0)
    local label  = tostring(input[2] or '')
    if amount <= 0 then
        BS.Notify('Montant invalide.', 'error')
        return
    end

    TriggerServerEvent(BSConfig.Prefix .. ':cash:invoice', target.serverId, amount, label)
end

local function OpenInvoiceMenu()
    local players = NearbyPlayers(BSConfig.Cash.clientDistance)
    if #players == 0 then
        BS.Notify('Aucun client à proximité.', 'error')
        return
    end

    local options = {}
    for _, p in ipairs(players) do
        options[#options + 1] = {
            title       = p.name,
            description = ('à %.1f m'):format(p.distance),
            icon        = 'user',
            onSelect    = function() AskInvoice(p) end,
        }
    end

    lib.registerContext({
        id      = BSConfig.Prefix .. '_invoice_target',
        title   = 'Facturer un client',
        menu    = BSConfig.Prefix .. '_cash',
        options = options,
    })
    lib.showContext(BSConfig.Prefix .. '_invoice_target')
end

function BS.OpenCash()
    if not BSConfig.Cash.enabled then return end
    if not BS.CanUseStation() then
        BS.Notify(BSConfig.Duty.required and "Vous devez être en service pour utiliser cet équipement."
                  or "Vous n'avez pas accès à cet équipement.", 'error')
        return
    end

    local options = {
        {
            title       = 'Créer une facture',
            description = 'Encaisser un client à proximité',
            icon        = 'file-invoice-dollar',
            onSelect    = OpenInvoiceMenu,
        },
        {
            title       = 'Coffre de l\'entreprise',
            description = ('Grade %d minimum'):format(BSConfig.Cash.safeMinGrade),
            icon        = 'vault',
            onSelect    = function() TriggerServerEvent(BSConfig.Prefix .. ':cash:safe') end,
        },
    }

    lib.registerContext({
        id      = BSConfig.Prefix .. '_cash',
        title   = BSConfig.JobLabel .. ' — Caisse',
        options = options,
    })
    lib.showContext(BSConfig.Prefix .. '_cash')
end
