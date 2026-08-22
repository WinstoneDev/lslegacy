-- registre extensible : chaque module consommateur (amendes, concessionnaire...) enregistre son propre handler
LSLegacy.Bank.PaymentResultHandlers = {}
LSLegacy.Bank.RegisterPaymentResultHandler = function(kind, fn)
    LSLegacy.Bank.PaymentResultHandlers[kind] = fn
end

-- ouvre le menu de paiement sur n'importe quel joueur connecté (achat initié par lui, ou paiement imposé par un tiers)
LSLegacy.Bank.OpenPaymentMenu = function(targetSrc, transactionMessage, price, options)
    local player = LSLegacy.Players.Get(targetSrc)
    if not player then return false end
    options = options or {}
    local allowCash = options.allowCash ~= false
    local meta = options.meta or {}
    meta.cardOnly = not allowCash

    -- le palier affiché sur l'item "carte" est figé à sa création : on le rafraîchit ici depuis bankaccounts (source de vérité)
    for _, item in pairs(player.inventory or {}) do
        if item.name == 'carte' and item.data and item.data.card_account then
            local account = LSLegacy.Bank.GetAccount(item.data.card_account)
            if account then
                item.data.card_tier = account.card_tier
            end
        end
    end

    LSLegacy.SendEventToClient('openPaymentMenu', targetSrc, transactionMessage, price, player.inventory, { allowCash = allowCash, meta = meta })
    return true
end

LSLegacy.RegisterServerEvent('attemptToPayMenu', function(transactionMessage, price)
    local _src = source
    LSLegacy.Bank.OpenPaymentMenu(_src, transactionMessage, price, nil)
end)

local function Finish(player, success, meta)
    LSLegacy.SendEventToClient('doActionsPayment', player.source, success)
    if meta and meta.type and LSLegacy.Bank.PaymentResultHandlers[meta.type] then
        LSLegacy.Bank.PaymentResultHandlers[meta.type](meta.refId, success)
    end
end

LSLegacy.RegisterServerEvent('pay', function(codePin, price, type, cardInfos, transactionMessage, contactless, meta)
    local _src = source
    local player = LSLegacy.Players.Get(_src)

    -- empêche un client modifié de payer en espèces un flux "carte uniquement"
    if meta and meta.cardOnly and type ~= "bank" then
        LSLegacy.SendEventToClient('notify', player.source, nil, 'Paiement par carte obligatoire.', 'error')
        Finish(player, false, meta)
        return
    end

    if type == "money" then
        local money = LSLegacy.Money.GetPlayerMoney(player)
        if money >= tonumber(price) then
            LSLegacy.Money.RemovePlayerMoney(player, price)
            Finish(player, true, meta)
            LSLegacy.SendEventToClient('notify', player.source, nil, 'Vous avez payé ' .. price .. '$', 'success')
        else
            Finish(player, false, meta)
            LSLegacy.SendEventToClient('notify', player.source, nil, 'Vous n\'avez pas assez d\'argent', 'error')
        end
    elseif type == "bank" then
        local account = LSLegacy.Bank.GetAccount(cardInfos.data.card_account)
        if not account then
            DropPlayer(player.source, '╭∩╮（︶_︶）╭∩╮')
            return
        end

        local authorized = false
        if contactless then
            -- sans contact : pas de PIN, mais plafond vérifié côté serveur
            local contactlessMax = (Config.Bank and Config.Bank.ContactlessMaxAmount) or 50
            if tonumber(price) > contactlessMax then
                LSLegacy.SendEventToClient('notify', player.source, nil, 'Montant trop élevé pour le sans contact (max '..contactlessMax..'$).', 'error')
                Finish(player, false, meta)
                return
            end
            authorized = true
        else
            if account.card_infos.card_pin == codePin then
                authorized = true
            else
                LSLegacy.SendEventToClient('notify', player.source, nil, "Code pin incorrect", 'error')
                return
            end
        end

        if authorized then
            local tierCfg = LSLegacy.Bank.GetCardTierConfig(account.card_tier)
            if (account.amountMoney + tierCfg.overdraft_limit) < price then
                LSLegacy.SendEventToClient('notify', player.source, nil, 'La carte n\'a pas assez d\'argent', 'error')
                Finish(player, false, meta)
            else
                -- ne consommer le plafond que si le paiement a effectivement lieu
                local ok, remaining = LSLegacy.Bank.CheckAndConsumeCeiling(account, 'payment', price, tierCfg.payment_ceiling, tierCfg.cost_period)
                if not ok then
                    LSLegacy.SendEventToClient('notify', player.source, nil, 'Plafond de paiement atteint : il reste '..math.max(0, math.floor(remaining))..'$ sur '..tierCfg.payment_ceiling..'$ sur la période en cours.', 'error')
                    Finish(player, false, meta)
                else
                    LSLegacy.Bank.AddTransaction(account, price, transactionMessage .. (contactless and ' (sans contact)' or ''), 'Achat')
                    LSLegacy.Bank.UpdateAccount(account, account.amountMoney - price)
                    Finish(player, true, meta)
                    LSLegacy.SendEventToClient('notify', player.source, nil, 'Vous avez payé ' .. price .. '$', 'success')
                end
            end
        end
    end
end)
