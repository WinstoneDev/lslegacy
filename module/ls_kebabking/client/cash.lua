-- ls_kebabking (client) — caisse : facturation client et coffre entreprise.
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
        { type = 'number', label = 'Montant ($)', required = true, min = 1, max = KKConfig.Cash.maxAmount, icon = 'dollar-sign' },
        { type = 'input',  label = 'Description', required = true, max = 60, default = 'Commande ' .. KKConfig.JobLabel },
    })
    if not input then return end

    local amount = math.floor(tonumber(input[1]) or 0)
    local label  = tostring(input[2] or '')
    if amount <= 0 then
        KK.Notify('Montant invalide.', 'error')
        return
    end

    TriggerServerEvent(KKConfig.Prefix .. ':cash:invoice', target.serverId, amount, label)
end

local function OpenInvoiceMenu()
    local players = NearbyPlayers(KKConfig.Cash.clientDistance)
    if #players == 0 then
        KK.Notify('Aucun client à proximité.', 'error')
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
        id      = KKConfig.Prefix .. '_invoice_target',
        title   = 'Facturer un client',
        menu    = KKConfig.Prefix .. '_cash',
        options = options,
    })
    lib.showContext(KKConfig.Prefix .. '_invoice_target')
end

function KK.OpenCash()
    if not KKConfig.Cash.enabled then return end
    if not KK.CanUseStation() then
        if not KK.IsEmployee() then
            KK.Notify("Vous n'avez pas accès à cet équipement.", 'error')
        else
            KK.Notify("Vous devez être en service pour utiliser cet équipement (tablette MDT).", 'error')
        end
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
            description = ('Grade %d minimum'):format(KKConfig.Cash.safeMinGrade),
            icon        = 'vault',
            onSelect    = function() TriggerServerEvent(KKConfig.Prefix .. ':cash:safe') end,
        },
    }

    lib.registerContext({
        id      = KKConfig.Prefix .. '_cash',
        title   = KKConfig.JobLabel .. ' — Caisse',
        options = options,
    })
    lib.showContext(KKConfig.Prefix .. '_cash')
end
