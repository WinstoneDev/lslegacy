-- Vendeur PNJ LTD Little Seoul : menu ox_lib, le serveur relit prix et distance.

local cfg = Config.LTD.PedShop

local function Notify(msg, kind)
    TriggerEvent('notify', 'LTD', msg, kind or 'info', 5000)
end

local function BuyEntry(entry)
    if entry.single then
        LSLegacy.Events.SendToServer('ltd:pedshop:buy', entry.item, 1)
        return
    end
    local input = lib.inputDialog(entry.label, {
        { type = 'number', label = 'Quantité', description = ('%d $ l\'unité'):format(entry.price), default = 1, min = 1, max = cfg.maxQty, required = true },
    })
    if not input then return end
    local qty = math.floor(tonumber(input[1]) or 0)
    if qty <= 0 then return end
    LSLegacy.Events.SendToServer('ltd:pedshop:buy', entry.item, qty)
end

local function OpenShop()
    local options = {}
    for _, entry in ipairs(cfg.items) do
        options[#options + 1] = {
            title = entry.label,
            description = ('%d $'):format(entry.price),
            icon = 'basket-shopping',
            onSelect = function() BuyEntry(entry) end,
        }
    end
    lib.registerContext({ id = 'ltd_pedshop', title = cfg.label, options = options })
    lib.showContext('ltd_pedshop')
end

LSLegacy.Events.Register('ltd:pedshop:result', function(ok, reason)
    if ok then Notify('Achat effectué.', 'success') return end
    local messages = { weight = 'Vous ne pouvez pas porter davantage.', payment_failed = 'Paiement refusé.' }
    Notify(messages[reason] or 'Achat impossible.', 'error')
end)

local ped

CreateThread(function()
    Wait(1500)

    local blip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
    SetBlipSprite(blip, cfg.blipSprite)
    SetBlipColour(blip, cfg.blipColor)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(cfg.label)
    EndTextCommandSetBlipName(blip)

    local hash = GetHashKey(cfg.model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then return end

    ped = CreatePed(4, hash, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.heading, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(hash)

    exports.ox_target:addLocalEntity(ped, {
        { name = 'ltd_pedshop', icon = 'fa-solid fa-cart-shopping', label = 'Acheter — ' .. cfg.label, distance = 2.5, onSelect = OpenShop },
    })
end)

AddEventHandler('onResourceStop', function(res)
    if GetCurrentResourceName() ~= res then return end
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
end)
