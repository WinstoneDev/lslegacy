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
    -- options.society = job : seule la carte entreprise de ce job est acceptée (achat pour l'entreprise)
    meta.society = options.society
    if meta.society then meta.cardOnly = true; allowCash = false end

    -- le palier affiché sur l'item "carte" est figé à sa création : on le rafraîchit ici depuis bankaccounts (source de vérité)
    for _, item in pairs(player.inventory or {}) do
        if item.name == 'carte' and item.data and item.data.card_account then
            local account = LSLegacy.Bank.GetAccount(item.data.card_account)
            if account then
                item.data.card_tier = account.card_tier
            end
        end
    end

    LSLegacy.Events.SendToClient('openPaymentMenu', targetSrc, transactionMessage, price, player.inventory, { allowCash = allowCash, meta = meta, society = meta.society })
    return true
end

LSLegacy.Events.Register('attemptToPayMenu', function(transactionMessage, price)
    local _src = source
    LSLegacy.Bank.OpenPaymentMenu(_src, transactionMessage, price, nil)
end)

local function Finish(player, success, meta, payType)
    LSLegacy.Events.SendToClient('doActionsPayment', player.source, success)
    if meta and meta.type and LSLegacy.Bank.PaymentResultHandlers[meta.type] then
        -- payType : 'money' (cash) ou 'bank' (carte) — les handlers qui n'en ont pas besoin l'ignorent simplement.
        LSLegacy.Bank.PaymentResultHandlers[meta.type](meta.refId, success, payType)
    end
end

LSLegacy.Events.Register('pay', function(codePin, price, type, cardInfos, transactionMessage, contactless, meta)
    local _src = source
    local player = LSLegacy.Players.Get(_src)

    -- empêche un client modifié de payer en espèces un flux "carte uniquement"
    if meta and meta.cardOnly and type ~= "bank" then
        LSLegacy.Events.SendToClient('notify', player.source, nil, 'Paiement par carte obligatoire.', 'error')
        Finish(player, false, meta, type)
        return
    end

    if type == "money" then
        local money = LSLegacy.Money.GetPlayerMoney(player)
        if money >= tonumber(price) then
            LSLegacy.Money.RemovePlayerMoney(player, price)
            Finish(player, true, meta, type)
            LSLegacy.Events.SendToClient('notify', player.source, nil, 'Vous avez payé ' .. price .. '$', 'success')
        else
            Finish(player, false, meta, type)
            LSLegacy.Events.SendToClient('notify', player.source, nil, 'Vous n\'avez pas assez d\'argent', 'error')
        end
    elseif type == "bank" then
        local account = cardInfos and cardInfos.data and LSLegacy.Bank.GetAccount(cardInfos.data.card_account)
        if not account then
            DropPlayer(player.source, '╭∩╮（︶_︶）╭∩╮')
            return
        end
        -- carte bloquée / remplacée : refus quel que soit le mode
        local validCard, cardReason = LSLegacy.Bank.ValidateCard(account, cardInfos.data)
        if not validCard then
            LSLegacy.Events.SendToClient('notify', player.source, nil, cardReason, 'error')
            Finish(player, false, meta, type)
            return
        end
        -- carte entreprise : réservée aux membres du job ; flux "achat entreprise" : carte du bon job obligatoire
        if account.society and player.job ~= account.society then
            LSLegacy.Events.SendToClient('notify', player.source, nil, 'Cette carte entreprise ne vous appartient pas.', 'error')
            Finish(player, false, meta, type)
            return
        end
        if meta and meta.society and account.society ~= meta.society then
            LSLegacy.Events.SendToClient('notify', player.source, nil, 'Paiement avec la carte entreprise de votre service obligatoire.', 'error')
            Finish(player, false, meta, type)
            return
        end

        local authorized = false
        if contactless then
            -- sans contact : pas de PIN, mais plafond vérifié côté serveur
            local contactlessMax = (Config.Bank and Config.Bank.ContactlessMaxAmount) or 50
            if tonumber(price) > contactlessMax then
                LSLegacy.Events.SendToClient('notify', player.source, nil, 'Montant trop élevé pour le sans contact (max '..contactlessMax..'$).', 'error')
                Finish(player, false, meta, type)
                return
            end
            authorized = true
        else
            if account.card_infos.card_pin == codePin then
                authorized = true
            else
                LSLegacy.Events.SendToClient('notify', player.source, nil, "Code pin incorrect", 'error')
                return
            end
        end

        if authorized then
            local tierCfg = LSLegacy.Bank.GetCardTierConfig(account.card_tier)
            -- compte entreprise : pas de découvert ni de plafond carte
            local overdraft = account.society and 0 or tierCfg.overdraft_limit
            if (account.amountMoney + overdraft) < price then
                LSLegacy.Events.SendToClient('notify', player.source, nil, account.society and 'Le compte entreprise n\'a pas assez d\'argent' or 'La carte n\'a pas assez d\'argent', 'error')
                Finish(player, false, meta, type)
            else
                -- ne consommer le plafond que si le paiement a effectivement lieu
                local ok, remaining = true, 0
                if not account.society then
                    ok, remaining = LSLegacy.Bank.CheckAndConsumeCeiling(account, 'payment', price, tierCfg.payment_ceiling, tierCfg.cost_period)
                end
                if not ok then
                    LSLegacy.Events.SendToClient('notify', player.source, nil, 'Plafond de paiement atteint : il reste '..math.max(0, math.floor(remaining))..'$ sur '..tierCfg.payment_ceiling..'$ sur la période en cours.', 'error')
                    Finish(player, false, meta, type)
                else
                    local who = account.society and (' — ' .. player.characterInfos.Prenom .. ' ' .. player.characterInfos.NDF) or ''
                    LSLegacy.Bank.AddTransaction(account, price, transactionMessage .. (contactless and ' (sans contact)' or '') .. who, 'Achat')
                    LSLegacy.Bank.UpdateAccount(account, account.amountMoney - price)
                    Finish(player, true, meta, type)
                    LSLegacy.Events.SendToClient('notify', player.source, nil, 'Vous avez payé ' .. price .. '$', 'success')
                end
            end
        end
    end
end)
