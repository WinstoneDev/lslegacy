paymentMenu = {
    opened = false,
    paymentType = nil,
    codePinProvided = nil,
    cardInfos = nil,
    actions = {}
}

paymentMenu.mainMenu = RageUI.CreateMenu(" ", "MadeInFrance~g~Pay~s~™", nil, 100, "root_cause", "shopui_title_mazebank")
paymentMenu.mainMenu:DisplayGlare(false)
paymentMenu.mainMenu.Closed = function()
    paymentMenu.opened = false
    RageUI.Visible(paymentMenu.mainMenu, false)
end
paymentMenu.cardsMenu = RageUI.CreateSubMenu(paymentMenu.mainMenu, " ", "Cartes")
paymentMenu.cardsMenu:DisplayGlare(false)
paymentMenu.cardsMenu:AcceptFilter(true)
paymentMenu.resumeTransactionMenu = RageUI.CreateSubMenu(paymentMenu.mainMenu, " ", "Résumé de la transaction")
paymentMenu.resumeTransactionMenu:DisplayGlare(false)

MadeInFrance.RegisterClientEvent('openPaymentMenu', function(transactionMessage, price, inventory)
    paymentMenu.openPaymentMenu(transactionMessage, price, inventory)
end)

paymentMenu.openPaymentMenu = function(transactionMessage, price, inventory)
    if RageUI.GetInMenu() then
        RageUI.CloseAll()
    end
    if paymentMenu.opened then
        paymentMenu.opened = false
        RageUI.Visible(paymentMenu.mainMenu, false)
    else
        paymentMenu.opened = true
        RageUI.Visible(paymentMenu.mainMenu, true)
    end
    Citizen.CreateThread(function()
        while paymentMenu.opened do
            RageUI.IsVisible(paymentMenu.mainMenu, function()
                if paymentMenu.paymentType ~= nil then
                    paymentMenu.paymentType = nil
                end
                RageUI.Separator('↓ Bienvenue sur MadeInFrance~g~Pay~s~™ ↓')
                RageUI.Separator('↓ Choississez votre moyen de paiement ↓')
                RageUI.Button('En espèces', nil , {}, true, {
                    onSelected = function()
                        paymentMenu.paymentType = "money"
                        RageUI.Visible(paymentMenu.mainMenu, false)
                        RageUI.Visible(paymentMenu.resumeTransactionMenu, true)
                    end
                })
                RageUI.Button('En carte bleue', nil , {}, true, {
                    onSelected = function()
                        paymentMenu.paymentType = "bank"
                        RageUI.Visible(paymentMenu.mainMenu, false)
                        RageUI.Visible(paymentMenu.cardsMenu, true)
                    end
                })
            end)
            RageUI.IsVisible(paymentMenu.cardsMenu, function()
                for key, value in pairs(inventory) do
                    if value.name == "carte" then
                        RageUI.Button(value.label, nil, {RightLabel = "→"}, true, {
                            onSelected = function()
                                local codePin = MadeInFrance.KeyboardInput('Code PIN', 4)
                                if tonumber(codePin) then
                                    if codePin == value.data.card_pin then
                                        RageUI.Visible(paymentMenu.cardsMenu, false)
                                        RageUI.Visible(paymentMenu.resumeTransactionMenu, true)
                                        paymentMenu.cardInfos = value
                                        paymentMenu.codePinProvided = codePin
                                    else
                                        MadeInFrance.ShowNotification("Maze Bank", "Code PIN incorrect", "error")
                                    end
                                else
                                    MadeInFrance.ShowNotification("Maze Bank", "Veuillez mettre seulement des chiffres", "error")
                                end
                            end
                        })
                    end
                end
            end)
            RageUI.IsVisible(paymentMenu.resumeTransactionMenu, function()
                RageUI.Separator('↓ Résumé de la transaction ↓')
                RageUI.Separator(transactionMessage)
                RageUI.Separator('Prix: ' .. price .. '$')
                RageUI.Button('Valider', nil, {}, true, {
                    onSelected = function()
                        if paymentMenu.paymentType == "money" then
                            MadeInFrance.SendEventToServer('pay', nil, price, paymentMenu.paymentType, nil, transactionMessage)
                        elseif paymentMenu.paymentType == "bank" then
                            MadeInFrance.SendEventToServer('pay', paymentMenu.codePinProvided, price, paymentMenu.paymentType, paymentMenu.cardInfos, transactionMessage)
                        end
                        paymentMenu.opened = false
                        paymentMenu.paymentType = nil
                        paymentMenu.codePinProvided = nil
                        RageUI.CloseAll()
                    end
                })
            end)
            Wait(1)
        end
    end)
end

MadeInFrance.RegisterClientEvent('doActionsPayment', function(sucess)
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