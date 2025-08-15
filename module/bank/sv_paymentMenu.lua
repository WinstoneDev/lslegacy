MadeInFrance.RegisterServerEvent('attemptToPayMenu', function(transactionMessage, price)
    local _src = source
    local player = MadeInFrance.GetPlayerFromId(_src)
    local inventory = player.inventory
    MadeInFrance.SendEventToClient('openPaymentMenu', player.source, transactionMessage, price, inventory)
end)

MadeInFrance.RegisterServerEvent('pay', function(codePin, price, type, cardInfos, transactionMessage)
    local _src = source
    local player = MadeInFrance.GetPlayerFromId(_src)
    if type == "money" then
        local money = MadeInFrance.Money.GetPlayerMoney(player)
        if money >= tonumber(price) then
            MadeInFrance.Money.RemovePlayerMoney(player, price)
            MadeInFrance.SendEventToClient('doActionsPayment', player.source, true)
            MadeInFrance.SendEventToClient('notify', player.source, nil, 'Vous avez payé ' .. price .. '$', 'success')
        else
            MadeInFrance.SendEventToClient('doActionsPayment', player.source, false)
            MadeInFrance.SendEventToClient('notify', player.source, nil, 'Vous n\'avez pas assez d\'argent', 'error')
        end
    elseif type == "bank" then
        local account = MadeInFrance.Bank.GetAccount(cardInfos.data.card_account)
        if account then
            if account.card_infos.card_pin == codePin then
                if account.amountMoney >= price then
                    MadeInFrance.Bank.AddTransaction(account, price, transactionMessage, 'Achat')
                    MadeInFrance.Bank.UpdateAccount(account, account.amountMoney - price)
                    MadeInFrance.SendEventToClient('doActionsPayment', player.source, true)
                    MadeInFrance.SendEventToClient('notify', player.source, nil, 'Vous avez payé ' .. price .. '$', 'success')
                else
                    MadeInFrance.SendEventToClient('notify', player.source, nil, 'La carte n\'a pas assez d\'argent', 'error')
                    MadeInFrance.SendEventToClient('doActionsPayment', player.source, false)
                end
            else
                DropPlayer(player.source, '╭∩╮（︶_︶）╭∩╮')
            end
        else
            DropPlayer(player.source, '╭∩╮（︶_︶）╭∩╮')
        end
    end
end)