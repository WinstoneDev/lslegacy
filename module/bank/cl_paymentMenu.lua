paymentMenu = {
    opened = false,
    price = nil,
    transactionMessage = nil,
    allowCash = true,
    meta = nil,
    actions = {}
}

local function GetCardsFromInventory(inventory)
    local cards = {}
    for key, value in pairs(inventory) do
        if value.name == "carte" then
            table.insert(cards, value)
        end
    end
    return cards
end

local function OpenPaymentNUI(transactionMessage, price, inventory, options)
    if paymentMenu.opened then return end
    options = options or {}
    paymentMenu.opened = true
    paymentMenu.price = price
    paymentMenu.transactionMessage = transactionMessage
    paymentMenu.allowCash = options.allowCash ~= false
    paymentMenu.meta = options.meta

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'payment:open',
        transactionMessage = transactionMessage,
        price = price,
        cards = GetCardsFromInventory(inventory),
        contactlessMax = (Config.Bank and Config.Bank.ContactlessMaxAmount) or 50,
        allowCash = paymentMenu.allowCash
    })
end

local function ClosePaymentNUI()
    if not paymentMenu.opened then return end
    paymentMenu.opened = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'payment:hide' })
end

LSLegacy.RegisterClientEvent('openPaymentMenu', function(transactionMessage, price, inventory, options)
    OpenPaymentNUI(transactionMessage, price, inventory, options)
end)

RegisterNUICallback('payment:close', function(data, cb)
    ClosePaymentNUI()
    -- fermeture manuelle sans paiement = échec, pour que l'appelant (ex. clothshop) nettoie sa caméra/HUD
    if paymentMenu.actions.onFailed ~= nil then
        local onFailed = paymentMenu.actions.onFailed
        paymentMenu.actions = {}
        Citizen.CreateThread(onFailed)
    end
    cb('ok')
end)

RegisterNUICallback('payment:payCash', function(data, cb)
    LSLegacy.SendEventToServer('pay', nil, paymentMenu.price, 'money', nil, paymentMenu.transactionMessage, nil, paymentMenu.meta)
    ClosePaymentNUI()
    cb('ok')
end)

RegisterNUICallback('payment:payContactless', function(data, cb)
    LSLegacy.SendEventToServer('pay', nil, paymentMenu.price, 'bank', data.card, paymentMenu.transactionMessage, true, paymentMenu.meta)
    ClosePaymentNUI()
    cb('ok')
end)

RegisterNUICallback('payment:payChip', function(data, cb)
    LSLegacy.SendEventToServer('pay', data.pin, paymentMenu.price, 'bank', data.card, paymentMenu.transactionMessage, false, paymentMenu.meta)
    ClosePaymentNUI()
    cb('ok')
end)

-- fire-and-forget : le feedback d'échec passe par 'notify', pas par ce NUI
LSLegacy.RegisterClientEvent('doActionsPayment', function(sucess)
    SendNUIMessage({ action = 'payment:sound', success = sucess })

    if sucess then
        if (paymentMenu.actions.onSucess ~= nil) then
            Citizen.CreateThread(function()
                paymentMenu.actions.onSucess()
                paymentMenu.actions = {}
            end)
        end
    else
        if (paymentMenu.actions.onFailed ~= nil) then
            Citizen.CreateThread(function()
                paymentMenu.actions.onFailed()
                paymentMenu.actions = {}
            end)
        end
    end
end)
