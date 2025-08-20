LSLegacy.RegisterServerEvent('attemptToPayMenu', function(transactionMessage, price)
    local _src = source
    local player = LSLegacy.GetPlayerFromId(_src)
    local inventory = player.inventory
    LSLegacy.SendEventToClient('openPaymentMenu', player.source, transactionMessage, price, inventory)
end)

LSLegacy.RegisterServerEvent('pay', function(codePin, price, type, cardInfos, transactionMessage)
    local _src = source
    local player = LSLegacy.GetPlayerFromId(_src)
    if type == "money" then
        local money = LSLegacy.Money.GetPlayerMoney(player)
        if money >= tonumber(price) then
            LSLegacy.Money.RemovePlayerMoney(player, price)
            LSLegacy.SendEventToClient('doActionsPayment', player.source, true)
            LSLegacy.SendEventToClient('notify', player.source, nil, 'Vous avez payé ' .. price .. '$', 'success')
        else
            LSLegacy.SendEventToClient('doActionsPayment', player.source, false)
            LSLegacy.SendEventToClient('notify', player.source, nil, 'Vous n\'avez pas assez d\'argent', 'error')
        end
    elseif type == "bank" then
        local account = LSLegacy.Bank.GetAccount(cardInfos.data.card_account)
        if account then
            if account.card_infos.card_pin == codePin then
                if account.amountMoney >= price then
                    LSLegacy.Bank.AddTransaction(account, price, transactionMessage, 'Achat')
                    LSLegacy.Bank.UpdateAccount(account, account.amountMoney - price)
                    LSLegacy.SendEventToClient('doActionsPayment', player.source, true)
                    LSLegacy.SendEventToClient('notify', player.source, nil, 'Vous avez payé ' .. price .. '$', 'success')
                else
                    LSLegacy.SendEventToClient('notify', player.source, nil, 'La carte n\'a pas assez d\'argent', 'error')
                    LSLegacy.SendEventToClient('doActionsPayment', player.source, false)
                end
            else
                DropPlayer(player.source, '╭∩╮（︶_︶）╭∩╮')
            end
        else
            DropPlayer(player.source, '╭∩╮（︶_︶）╭∩╮')
        end
    end
end)