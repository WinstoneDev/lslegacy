local bankMenu = {
    opened = false,
    accounts = {},
    selectedAccount = nil
}

local atmMenu = {
    opened = false
}

bankMenu.mainMenu = RageUI.CreateMenu(" ", "Banque", nil, 100, "root_cause", "shopui_title_mazebank")
bankMenu.mainMenu:DisplayGlare(false)
bankMenu.accountsMenu = RageUI.CreateSubMenu(bankMenu.mainMenu, " ", "Comptes", nil, 100, "root_cause", "shopui_title_mazebank")
bankMenu.accountsMenu:DisplayGlare(false)
bankMenu.accountSelectedMenu = RageUI.CreateSubMenu(bankMenu.accountsMenu, " ", "Compte", nil, 100, "root_cause", "shopui_title_mazebank")
bankMenu.accountSelectedMenu:DisplayGlare(false)
bankMenu.transactionsMenu = RageUI.CreateSubMenu(bankMenu.accountSelectedMenu, " ", "Transactions", nil, 100, "root_cause", "shopui_title_mazebank")
bankMenu.transactionsMenu:DisplayGlare(false)
bankMenu.accountActionsMenu = RageUI.CreateSubMenu(bankMenu.accountSelectedMenu, " ", "Actions", nil, 100, "root_cause", "shopui_title_mazebank")
bankMenu.accountActionsMenu:DisplayGlare(false)
bankMenu.cardMenu = RageUI.CreateSubMenu(bankMenu.accountSelectedMenu, " ", "Carte", nil, 100, "root_cause", "shopui_title_mazebank")
bankMenu.cardMenu:DisplayGlare(false)

bankMenu.accountsMenu:AcceptFilter(true)
bankMenu.transactionsMenu:AcceptFilter(true)


bankMenu.mainMenu.Closed = function()
    bankMenu.opened = false
end

atmMenu.mainMenu = RageUI.CreateMenu(" ", "Banque", nil, 100, "root_cause", "shopui_title_mazebank")
atmMenu.mainMenu:DisplayGlare(false)

atmMenu.mainMenu.Closed = function()
    atmMenu.opened = false
end

bankMenu.GetAccount = function(id)
    for key, value in pairs(bankMenu.accounts) do
        if value.id == id then
            return value
        end
    end
end

bankMenu.GetPersonnalAccounts = function(accounts)
    local result = {}
    for key, value in pairs(accounts) do
        if value.owner == MadeInFrance.PlayerData.identifier then
            table.insert(result, value)
        end
    end
    return result
end

atmMenu.OpenMenu = function(data)
    if RageUI.GetInMenu() then
        return
    end
    if atmMenu.opened then
        atmMenu.opened = false
        RageUI.Visible(atmMenu.mainMenu, false)
    else
        atmMenu.opened = true
        RageUI.Visible(atmMenu.mainMenu, true)
        CreateThread(function()
            while atmMenu.opened do
                Wait(0)
                RageUI.IsVisible(atmMenu.mainMenu, function()
                    RageUI.Separator("↓ Argent sur votre compte : "..bankMenu.GetAccount(data.card_account).amountMoney..'~g~$~s~ ↓')
                    RageUI.Button('Ajouter de l\'argent', nil, {}, true, {
                        onSelected = function()
                            local amount = MadeInFrance.KeyboardInput('Somme', 10)
                            if tonumber(amount) then
                                if tonumber(amount) > 0 then
                                    MadeInFrance.SendEventToServer('madeinfrance:BankAddMoney', amount, data.card_account)
                                else
                                    MadeInFrance.ShowNotification('Vous devez entrer un montant positif.')
                                end
                            else
                                MadeInFrance.ShowNotification('Vous devez entrer un montant valide.')
                            end
                        end
                    })
                    RageUI.Button('Retirer de l\'argent', nil, {}, true, {
                        onSelected = function()
                            local amount = MadeInFrance.KeyboardInput('Somme', 10)
                            if tonumber(amount) then
                                if tonumber(amount) > 0 then
                                    MadeInFrance.SendEventToServer('madeinfrance:BankwithdrawMoney', amount, data.card_account)
                                else
                                    MadeInFrance.ShowNotification('Vous devez entrer un montant positif.')
                                end
                            else
                                MadeInFrance.ShowNotification('Vous devez entrer un montant valide.')
                            end
                        end
                    })
                end)
            end
        end)
    end
end

bankMenu.OpenMenu = function()
    if RageUI.GetInMenu() then
        return
    end
    if bankMenu.opened then
        bankMenu.opened = false
        RageUI.Visible(bankMenu.mainMenu, false)
    else
        bankMenu.opened = true
        RageUI.Visible(bankMenu.mainMenu, true)
        CreateThread(function()
            while bankMenu.opened do
                Wait(0)
                RageUI.IsVisible(bankMenu.mainMenu, function()
                    RageUI.Button('Mes comptes banquaires', nil, {RightLabel = '→'}, true, {}, bankMenu.accountsMenu)
                    RageUI.Button('Créer un compte', nil, {RightLabel = '→'}, true, {
                        onSelected = function()
                            MadeInFrance.SendEventToServer('madeinfrance:BankCreateAccount')
                        end
                    })
                end)
                RageUI.IsVisible(bankMenu.accountsMenu, function()
                    local accounts = bankMenu.GetPersonnalAccounts(bankMenu.accounts)
                    if json.encode(accounts) == '[]' then
                        RageUI.Separator()
                        RageUI.Separator('↓ Aucun compte banquaire ↓')
                        RageUI.Separator()
                    else
                        for key, value in pairs(accounts) do
                            RageUI.Button('Compte n°'..value.id, nil, {RightLabel = '→'}, true, {
                                onSelected = function()
                                    bankMenu.selectedAccount = value
                                    bankMenu.selectedAccount.text = not value.courant and '~r~Non' or '~g~Oui'
                                    RageUI.Visible(bankMenu.accountSelectedMenu, true)
                                end
                            })
                        end
                    end
                end)
                RageUI.IsVisible(bankMenu.accountSelectedMenu, function()
                    RageUI.Separator('↓ Compte ~g~n°'..bankMenu.selectedAccount.id..'~s~ ↓')
                    RageUI.Separator('Appartenant à ~b~'..bankMenu.selectedAccount.owner_name)
                    RageUI.Separator('IBAN : ~g~'..bankMenu.selectedAccount.iban)
                    RageUI.Separator('Compte courant : '..bankMenu.selectedAccount.text..'~s~')
                    RageUI.Separator('Solde : ~g~'..bankMenu.selectedAccount.amountMoney..'$')
                    RageUI.Button('Liste des transactions', nil, {RightLabel = '→'}, true, {}, bankMenu.transactionsMenu)
                    RageUI.Button('Actions liées au compte', nil, {RightLabel = '→'}, true, {}, bankMenu.accountActionsMenu)
                end)
                RageUI.IsVisible(bankMenu.transactionsMenu, function()
                    if json.encode(bankMenu.selectedAccount.transactions) == "[]" then
                        RageUI.Separator()
                        RageUI.Separator('↓ Aucune transaction ↓')
                        RageUI.Separator()
                    else
                        for key, value in pairs(bankMenu.selectedAccount.transactions) do
                            RageUI.Button(value.message, '~b~Date~s~ : '..value.date, {RightLabel = value.type}, true, {})
                        end
                    end
                end)
                RageUI.IsVisible(bankMenu.accountActionsMenu, function()
                    local text = bankMenu.selectedAccount.text == '~r~Non' and '~r~Non courant~s~' or '~g~Courant~s~'
                    RageUI.Button('Changer le statut du compte ['..text..']', nil, {RightLabel = '→'}, true, {
                        onSelected = function()
                            if bankMenu.selectedAccount.courant then
                                bankMenu.selectedAccount.courant = false
                                bankMenu.selectedAccount.text = '~r~Non'
                                RageUI.Visible(bankMenu.accountActionsMenu, false)
                                RageUI.Visible(bankMenu.mainMenu, true)
                                MadeInFrance.SendEventToServer('madeinfrance:BankChangeAccountStatus', bankMenu.selectedAccount.id, bankMenu.selectedAccount.courant)
                            else
                                local exist = false
                                for key, value in pairs(bankMenu.GetPersonnalAccounts(bankMenu.accounts)) do
                                    if value.courant then
                                        exist = true
                                        break
                                    end
                                end
                                if not exist then
                                    bankMenu.selectedAccount.courant = true
                                    bankMenu.selectedAccount.text = '~g~Oui'
                                    RageUI.Visible(bankMenu.accountActionsMenu, false)
                                    RageUI.Visible(bankMenu.mainMenu, true)
                                    MadeInFrance.SendEventToServer('madeinfrance:BankChangeAccountStatus', bankMenu.selectedAccount.id, bankMenu.selectedAccount.courant)
                                else
                                    MadeInFrance.ShowNotification('~r~Maze Bank~s~\nVous avez ~r~déjà~s~ un compte courant.')
                                end                                
                            end
                        end
                    })
                    if bankMenu.selectedAccount.card_infos == nil then
                        RageUI.Button('Créer une carte banquaire', nil, {RightLabel = '→'}, true, {
                            onSelected = function()
                                RageUI.Visible(bankMenu.accountActionsMenu, false)
                                RageUI.Visible(bankMenu.mainMenu, true)
                                MadeInFrance.SendEventToServer('madeinfrance:BankCreateCard', bankMenu.selectedAccount.id)
                            end
                        })
                    else
                        RageUI.Button('Infos/Actions sur votre carte banquaire', nil, {RightLabel = '→'}, true, {
                            onSelected = function()
                                bankMenu.selectedCard = bankMenu.selectedAccount.card_infos
                                RageUI.Visible(bankMenu.cardMenu, true)
                            end
                        })
                    end
                    RageUI.Button('Supprimer le compte', nil, {RightLabel = '→'}, true, {
                        onSelected = function()
                            RageUI.Visible(bankMenu.accountActionsMenu, false)
                            RageUI.Visible(bankMenu.mainMenu, true)
                            MadeInFrance.SendEventToServer('madeinfrance:BankDeleteAccount', bankMenu.selectedAccount.id)
                        end
                    })
                end)
                RageUI.IsVisible(bankMenu.cardMenu, function()
                    RageUI.Separator('Numéro : ~g~'..MadeInFrance.RegroupNumbers(bankMenu.selectedCard.card_number)..'~s~')
                    RageUI.Separator('Appartenant à ~b~'..bankMenu.selectedCard.owner_name)
                    RageUI.Separator('Expiration : ~g~'..bankMenu.selectedCard.card_expiration_date)
                    RageUI.Separator('CVV : ~g~'..bankMenu.selectedCard.card_cvv)
                    RageUI.Separator('Code PIN : ~g~'..bankMenu.selectedCard.card_pin)
                    RageUI.Separator('Type : ~g~'..bankMenu.selectedCard.card_type)
                end)
            end
        end)
    end
end

MadeInFrance.RegisterClientEvent('madeinfrance:openBankMenu', function()
    MadeInFrance.SendEventToServer('madeinfrance:GetBankAccounts')
    bankMenu.OpenMenu()
end)

local ATMProps = {{prop = 'prop_atm_02'}, {prop = 'prop_atm_03'}, {prop = 'prop_fleeca_atm'}, {prop = 'prop_atm_01'}}

function NearAtms()
    local objects = {}
    for _,v in pairs(ATMProps) do
      table.insert(objects, v.prop)
    end
  
    local ped = PlayerPedId()
    local list = {}
  
    for _,v in pairs(objects) do
        local obj = GetClosestObjectOfType(GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z, 5.0, GetHashKey(v), false, true ,true)
        local dist = GetDistanceBetweenCoords(GetEntityCoords(ped), GetEntityCoords(obj), true)
        table.insert(list, {object = obj, distance = dist})
      end
  
      local closest = list[1]
      for _,v in pairs(list) do
        if v.distance < closest.distance then
          closest = v
        end
      end
  
      local distance = closest.distance
      local object = closest.object

      local heading = GetEntityHeading(props)

      local pheading = GetEntityHeading(ped)

      if distance < 1.3 then
        return true 
      else
        return false
      end
end

MadeInFrance.RegisterClientEvent('madeinfrance:useCarteBank', function(data)
    if NearAtms() then
        local input = MadeInFrance.KeyboardInput('Code PIN', 4)
        if tonumber(input) then
            if tonumber(input) == tonumber(data.card_pin) then
                MadeInFrance.SendEventToServer('madeinfrance:GetBankAccounts')
                Wait(100)
                atmMenu.OpenMenu(data)
            else
                MadeInFrance.ShowNotification('~r~Maze Bank~s~\nLe code PIN est incorrect.')
            end
        else
            MadeInFrance.ShowNotification('~r~Maze Bank~s~\nVous avez ~r~entré~s~ un code invalide.')
        end
    end
end)

MadeInFrance.RegisterClientEvent('madeinfrance:receiveBankAccounts', function(accounts)
    bankMenu.accounts = accounts
end)