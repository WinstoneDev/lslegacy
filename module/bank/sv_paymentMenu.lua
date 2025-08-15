MadeInFrance.RegisterServerEvent('madeinfrance:attemptToPayMenu', function(transactionMessage, price)
    local _src = source
    local player = MadeInFrance.GetPlayerFromId(_src)
    local inventory = player.inventory
    MadeInFrance.SendEventToClient('madeinfrance:openPaymentMenu', player.source, transactionMessage, price, inventory)
end)

MadeInFrance.RegisterServerEvent('madeinfrance:pay', function(codePin, price, type, cardInfos, transactionMessage)
    local _src = source
    local player = MadeInFrance.GetPlayerFromId(_src)
    if type == "money" then
        local money = MadeInFrance.Money.GetPlayerMoney(player)
        if money >= tonumber(price) then
            MadeInFrance.Money.RemovePlayerMoney(player, price)
            MadeInFrance.SendEventToClient('madeinfrance:doActionsPayment', player.source, true)
            MadeInFrance.SendEventToClient('madeinfrance:notify', player.source, '~g~Vous avez payé ' .. price .. '$')
        else
            MadeInFrance.SendEventToClient('madeinfrance:doActionsPayment', player.source, false)
            MadeInFrance.SendEventToClient('madeinfrance:notify', player.source, '~r~Vous n\'avez pas assez d\'argent')
        end
    elseif type == "bank" then
        local account = MadeInFrance.Bank.GetAccount(cardInfos.data.card_account)
        if account then
            if account.card_infos.card_pin == codePin then
                if account.amountMoney >= price then
                    MadeInFrance.Bank.AddTransaction(account, price, transactionMessage, 'Achat')
                    MadeInFrance.Bank.UpdateAccount(account, account.amountMoney - price)
                    MadeInFrance.SendEventToClient('madeinfrance:doActionsPayment', player.source, true)
                    MadeInFrance.SendEventToClient('madeinfrance:notify', player.source, '~g~Vous avez payé ' .. price .. '$')
                else
                    MadeInFrance.SendEventToClient('madeinfrance:notify', player.source, '~r~La carte n\'a pas assez d\'argent')
                    MadeInFrance.SendEventToClient('madeinfrance:doActionsPayment', player.source, false)
                end
            else
                DropPlayer(player.source, '╭∩╮（︶_︶）╭∩╮')
            end
        else
            DropPlayer(player.source, '╭∩╮（︶_︶）╭∩╮')
        end
    end
end)