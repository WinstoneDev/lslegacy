LSLegacy.Bank = {}
LSLegacy.Bank.BankAccounts = {}

MySQL.ready(function()
    LSLegacy.Bank.GetAllAccounts()
end)

LSLegacy.Bank.GetAllAccounts = function()
    LSLegacy.Bank.BankAccounts = {}
    MySQL.Async.fetchAll('SELECT * FROM bankaccounts', {}, function(result)
        for i = 1, #result, 1 do
            LSLegacy.Bank.BankAccounts[result[i].id] = {
                id = result[i].id,
                owner = result[i].owner,
                owner_name = result[i].owner_name,
                iban = result[i].iban,
                amountMoney = result[i].amountMoney,
                transactions = json.decode(result[i].transactions),
                courant = result[i].courant,
                card_infos = json.decode(result[i].card_infos)
            }
        end
    end)
end

LSLegacy.Bank.GetPersonnalAccounts = function(identifier)
    local accounts = {}
    for k, v in pairs(LSLegacy.Bank.BankAccounts) do
        if v.owner == identifier then
            table.insert(accounts, v)
        end
    end
    return accounts
end

LSLegacy.RegisterZone('Guichet de banque', vector3(243.2082, 224.7312, 106.2869), function(source)
    LSLegacy.SendEventToClient('openBankMenu', source)
end, 10.0, false, {
    markerType = 25,
    markerColor = {r = 0, g = 125, b = 255, a = 255},
    markerSize = {x = 1.0, y = 1.0, z = 1.0},
    markerPos = vector3(-1093.411, -809.2663, 19.2816)
}, true, {
    blipSprite = 207,
    blipColor = 2,
    blipScale = 0.7,
    blipName = "Pacific Standard Bank"
}, true, {
    drawNotificationDistance = 1.7,
    notificationMessage = "Appuyez sur ~INPUT_CONTEXT~ pour parler à Bob",
}, true, {
    coords = vector4(243.74, 226.52, 105.3, 170.0),
    pedName = "Bob",
    pedModel = "cs_bankman",
    drawDistName = 5.0,
    scenario = {
        anim = "WORLD_HUMAN_CLIPBOARD"
    }
})

LSLegacy.RegisterServerEvent('GetBankAccounts', function()
    LSLegacy.SendEventToClient('receiveBankAccounts', source, LSLegacy.Bank.BankAccounts)
end)

LSLegacy.RegisterServerEvent('BankCreateAccount', function()
    local player = LSLegacy.GetPlayerFromId(source)
    local account = {
        owner = player.identifier,
        owner_name = player.characterInfos.Prenom .. " " .. player.characterInfos.NDF,
        amountMoney = 0,
        transactions = {},
        courant = false
    }
    MySQL.Async.execute('INSERT INTO bankaccounts (owner, owner_name, iban, amountMoney, transactions, courant) VALUES  (@owner, @owner_name, @iban, @amountMoney, @transactions, @courant)', {
        ['@owner'] = account.owner,
        ['@owner_name'] = account.owner_name,
        ['@iban'] = LSLegacy.Bank.GenerateIBAN(25),
        ['@amountMoney'] = account.amountMoney,
        ['@transactions'] = json.encode(account.transactions),
        ['@courant'] = LSLegacy.ConverToNumber(account.courant)
    })
    Wait(150)
    LSLegacy.Bank.GetAllAccounts()
    Wait(150)
    LSLegacy.SendEventToClient('receiveBankAccounts', player.source, LSLegacy.Bank.BankAccounts)
    LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Votre compte a été créé avec succès.', 'success')
end)

LSLegacy.RegisterServerEvent('BankChangeAccountStatus', function(id, state)
    local player = LSLegacy.GetPlayerFromId(source)
    MySQL.Async.execute('UPDATE bankaccounts SET courant = @courant WHERE id = @id', {
        ['@id'] = id,
        ['@courant'] = state
    })
    Wait(150)
    LSLegacy.Bank.GetAllAccounts()
    Wait(150)
    LSLegacy.SendEventToClient('receiveBankAccounts', player.source, LSLegacy.Bank.BankAccounts)
    LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Votre compte a été modifié avec succès.', 'success')
end)

LSLegacy.RegisterServerEvent('BankDeleteAccount', function(id)
    local player = LSLegacy.GetPlayerFromId(source)
    MySQL.Async.execute('DELETE FROM bankaccounts WHERE id = @id', {
        ['@id'] = id
    })
    Wait(150)
    LSLegacy.Bank.GetAllAccounts()
    Wait(150)
    LSLegacy.SendEventToClient('receiveBankAccounts', player.source, LSLegacy.Bank.BankAccounts)
    LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Votre compte a été supprimé avec succès.', 'success')
end)


LSLegacy.RegisterServerEvent('BankCreateCard', function(id)
    local player = LSLegacy.GetPlayerFromId(source)
    local card = {
        owner_name = player.characterInfos.Prenom .. " " .. player.characterInfos.NDF,
        card_number = LSLegacy.Bank.GenerateCardNumber(),
        card_pin = LSLegacy.Bank.GenerateCardPin(),
        card_cvv = LSLegacy.Bank.GenerateCardCVV(),
        card_expiration_date = LSLegacy.Bank.GenerateCardExpirationDate(),
        card_type = 'Mastercard',
        card_account = id
    }
    MySQL.Async.execute('UPDATE bankaccounts SET card_infos = @card_infos WHERE id = @id', {
        ['@id'] = id,
        ['@card_infos'] = json.encode(card)
    })
    if LSLegacy.Inventory.CanCarryItem(player, 'carte', 1) then
        LSLegacy.Inventory.AddItemInInventory(player, 'carte', 1, 'Compte n°' ..id, nil, card)
    end
    Wait(150)
    LSLegacy.Bank.GetAllAccounts()
    Wait(150)
    LSLegacy.SendEventToClient('receiveBankAccounts', player.source, LSLegacy.Bank.BankAccounts)
    LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Votre carte a été créée avec succès.', 'success')
end)

LSLegacy.Bank.GetAccount = function(id)
    local account = nil
    for k, v in pairs(LSLegacy.Bank.BankAccounts) do
        if v.id == id then
            account = v
            break
        end
    end
    return account
end

LSLegacy.Bank.AddTransaction = function(account, amount, message, type)
    local _src = source
    local player = LSLegacy.GetPlayerFromId(_src)
    local transaction = {
        amount = amount,
        type = type,
        message = message,
        date = os.date('%d/%m/%Y %H:%M:%S')
    }
    table.insert(account.transactions, transaction)
    MySQL.Async.execute('UPDATE bankaccounts SET transactions = @transactions WHERE id = @id', {
        ['@id'] = account.id,
        ['@transactions'] = json.encode(account.transactions)
    })
    Wait(150)
    LSLegacy.Bank.GetAllAccounts()
    Wait(150)
    LSLegacy.SendEventToClient('receiveBankAccounts', _src, LSLegacy.Bank.BankAccounts)
end

LSLegacy.Bank.UpdateAccount = function(account, amount)
    local _src = source
    local player = LSLegacy.GetPlayerFromId(_src)
    account.amountMoney = amount
    MySQL.Async.execute('UPDATE bankaccounts SET amountMoney = @amountMoney WHERE id = @id', {
        ['@id'] = account.id,
        ['@amountMoney'] = account.amountMoney
    })
    Wait(150)
    LSLegacy.Bank.GetAllAccounts()
    Wait(150)
    LSLegacy.SendEventToClient('receiveBankAccounts', _src, LSLegacy.Bank.BankAccounts)
end

LSLegacy.RegisterServerEvent('BankAddMoney', function(amount, id)
    local player = LSLegacy.GetPlayerFromId(source)
    local account = LSLegacy.Bank.GetAccount(id)
    if account ~= nil then
        if LSLegacy.Money.GetPlayerMoney(player) >= tonumber(amount) then
            LSLegacy.Money.RemovePlayerMoney(player, amount)
            LSLegacy.Bank.UpdateAccount(account, account.amountMoney + amount)
            LSLegacy.Bank.AddTransaction(account, amount, 'Ajout de '..amount..'$', 'Dépôt')
            LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Vous avez ajouté ' .. amount .. '$ à votre compte.', 'success')
        else
            LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Vous n\'avez pas assez d\'argent.', 'error')
        end
    end
end)

LSLegacy.RegisterServerEvent('BankwithdrawMoney', function(amount, id)
    local player = LSLegacy.GetPlayerFromId(source)
    local account = LSLegacy.Bank.GetAccount(id)
    if tonumber(account.amountMoney) >= tonumber(amount) then
        LSLegacy.Bank.AddTransaction(account, amount, 'Retrait de ' .. amount .. '$', 'Retrait')
        LSLegacy.Bank.UpdateAccount(account, account.amountMoney - amount)
        LSLegacy.Money.AddPlayerMoney(player, amount)
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Vous avez retiré ' .. amount .. '$ avec succès.', 'success')
    else
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Vous n\'avez pas assez d\'argent sur votre compte.', 'error')
    end
end)

LSLegacy.Bank.GenerateCardNumber = function()
    local number = ''
    for i = 1, 16 do
        number = number .. math.random(0, 9)
    end
    return number
end

LSLegacy.Bank.GenerateCardPin = function()
    local pin = ''
    for i = 1, 4 do
        pin = pin .. math.random(0, 9)
    end
    return pin
end 

LSLegacy.Bank.GenerateCardCVV = function()
    return math.random(100, 999)
end

LSLegacy.Bank.GenerateCardExpirationDate = function()
    local month = math.random(1, 12)
    local year = math.random(2022, 2030)
    return month .. '/' .. year
end

LSLegacy.Bank.GenerateIBAN = function(length)
    local string = ""
    for i = 1, length, 1 do
        local random = math.random(0, 1)
        if random == 0 then
            string = string .. math.random(0, 9)
        else
            string = string .. string.char(math.random(65, 90))
        end
    end

    string = 'LSL' .. string

    local exist = false

    for key, value in pairs(LSLegacy.Bank.BankAccounts) do
        if value.iban == string then
            exist = true
            break
        end
    end

    if exist then
        LSLegacy.Bank.GenerateIBAN(length)
    else
        return string
    end
end

LSLegacy.RegisterUsableItem('carte', function(data)
    local _src = source
    local player = LSLegacy.GetPlayerFromId(source)
    LSLegacy.SendEventToClient('useCarteBank', player.source, data)
end)