-- module/grossiste (client) — PNJ, menus achat/vente.
-- Le client n'envoie que item + quantité + méthode de paiement : le serveur
-- relit systématiquement le catalogue et les prix (jamais fournis par le client).

local spawnedPeds = {}

local function Notify(msg, kind)
    TriggerEvent('notify', 'Grossiste', msg, kind or 'info', 5000)
end

local function SpawnPed(cfg, options)
    local hash = GetHashKey(cfg.model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then return end

    local ped = CreatePed(4, hash, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.heading, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(hash)

    spawnedPeds[#spawnedPeds + 1] = ped
    exports.ox_target:addLocalEntity(ped, options)
end

-- ── Méthode de paiement ──────────────────────────────────────────────────
-- 'personal' délègue au TPE partagé (espèces/carte, choisis dans son UI) ;
-- 'company' règle directement depuis le coffre de l'employeur du joueur.

local function ChoosePaymentMethod(onChoose, companyEligible)
    local options = {
        {
            title = "Paiement personnel",
            description = "Espèces ou carte bancaire",
            icon = 'wallet',
            onSelect = function() onChoose('personal') end,
        },
    }
    if companyEligible then
        options[#options + 1] = {
            title = "Compte entreprise",
            description = "Débité depuis le coffre de votre employeur",
            icon = 'building',
            onSelect = function() onChoose('company') end,
        }
    end
    lib.registerContext({ id = 'grossiste_payment', title = "Méthode de paiement", options = options })
    lib.showContext('grossiste_payment')
end

-- ── Achat ────────────────────────────────────────────────────────────────

local function BuyEntry(entry)
    local input = lib.inputDialog(entry.pack, {
        { type = 'number', label = 'Nombre de lots', description = ('%d x %s par lot'):format(entry.packCount, GR.ItemLabel(entry.item)), default = 1, min = 1, max = 50, required = true },
    })
    if not input then return end
    local qty = math.floor(tonumber(input[1]) or 0)
    if qty <= 0 then return end

    ChoosePaymentMethod(function(method)
        LSLegacy.Events.SendToServer('grossiste:buy', entry.item, qty, method)
    end, true)
end

local function OpenCategory(category)
    local options = {}
    for _, entry in ipairs(GRConfig.Catalog) do
        if entry.category == category then
            options[#options + 1] = {
                title = entry.pack,
                description = ('%d x %s — %d $/lot'):format(entry.packCount, GR.ItemLabel(entry.item), math.floor(entry.buyUnit * entry.packCount)),
                icon = 'box',
                onSelect = function() BuyEntry(entry) end,
            }
        end
    end
    lib.registerContext({ id = 'grossiste_category', title = category, menu = 'grossiste_categories', options = options })
    lib.showContext('grossiste_category')
end

local function OpenCatalog()
    local seen, options = {}, {}
    for _, entry in ipairs(GRConfig.Catalog) do
        if not seen[entry.category] then
            seen[entry.category] = true
            options[#options + 1] = {
                title = entry.category,
                icon = 'store',
                onSelect = function() OpenCategory(entry.category) end,
            }
        end
    end
    lib.registerContext({ id = 'grossiste_categories', title = "Grossiste — Catalogue", options = options })
    lib.showContext('grossiste_categories')
end

-- ── Vente ────────────────────────────────────────────────────────────────

local function GetInventoryCounts()
    local counts = {}
    local data = exports['lslegacy']:getPlayerData()
    for _, item in pairs((data and data.inventory) or {}) do
        counts[item.name] = (counts[item.name] or 0) + (item.count or 0)
    end
    return counts
end

local function SellEntry(entry, have)
    local input = lib.inputDialog(GR.ItemLabel(entry.item), {
        { type = 'number', label = 'Quantité à vendre', description = ('%d $/unité — vous en avez %d'):format(entry.sellUnit, have), default = have, min = 1, max = have, required = true },
    })
    if not input then return end
    local qty = math.floor(tonumber(input[1]) or 0)
    if qty <= 0 then return end
    LSLegacy.Events.SendToServer('grossiste:sell', entry.item, qty)
end

local function OpenSell()
    local counts  = GetInventoryCounts()
    local options = {}
    for _, entry in ipairs(GRConfig.Catalog) do
        local have = counts[entry.item] or 0
        if have > 0 then
            options[#options + 1] = {
                title = GR.ItemLabel(entry.item),
                description = ('%d en stock — %d $/unité'):format(have, entry.sellUnit),
                icon = 'hand-holding-dollar',
                onSelect = function() SellEntry(entry, have) end,
            }
        end
    end
    if #options == 0 then
        Notify("Vous n'avez rien à vendre au grossiste.", 'error')
        return
    end
    lib.registerContext({ id = 'grossiste_sell', title = "Grossiste — Revente", options = options })
    lib.showContext('grossiste_sell')
end

-- ── Résultats serveur ────────────────────────────────────────────────────

RegisterNetEvent('grossiste:buyResult', function(ok, reason)
    if ok then return end
    local messages = {
        invalid_item = "Article inconnu.", weight = "Vous ne pouvez pas porter davantage.",
        no_company = "Vous n'avez pas d'entreprise éligible.", payment_failed = "Paiement refusé.",
    }
    Notify(messages[reason] or "Achat impossible.", 'error')
end)

RegisterNetEvent('grossiste:sellResult', function(ok, reason, amount)
    if ok then
        Notify(('Vendu pour %d $.'):format(amount), 'success')
    else
        local messages = { missing = "Vous n'avez pas cette quantité.", invalid_item = "Article invendable ici." }
        Notify(messages[reason] or "Vente impossible.", 'error')
    end
end)

-- Déclenché depuis le PNJ Janet Vance (module avicole), qui fait aussi office
-- de point de rachat grossiste général.
AddEventHandler('grossiste:openSellMenu', OpenSell)

-- ── Init ─────────────────────────────────────────────────────────────────

CreateThread(function()
    Wait(1000)
    if GRConfig.Blip.enabled then
        local b = GRConfig.Blip
        local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
        SetBlipSprite(blip, b.sprite)
        SetBlipColour(blip, b.color)
        SetBlipScale(blip, b.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(b.label)
        EndTextCommandSetBlipName(blip)
    end

    SpawnPed(GRConfig.Seller, {
        { name = 'grossiste_buy', icon = 'fa-solid fa-cart-shopping', label = "Acheter au grossiste", distance = 2.5, onSelect = OpenCatalog },
    })
end)

AddEventHandler('onResourceStop', function(res)
    if GetCurrentResourceName() ~= res then return end
    for _, ped in ipairs(spawnedPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)
