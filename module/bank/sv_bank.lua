MadeInFrance.Bank = {}
MadeInFrance.Bank.BankAccounts = {}

MySQL.ready(function()
    MadeInFrance.Bank.GetAllAccounts()
end)

MadeInFrance.Bank.GetAllAccounts = function()
    MadeInFrance.Bank.BankAccounts = {}
    MySQL.Async.fetchAll('SELECT * FROM bankaccounts', {}, function(result)
        for i = 1, #result, 1 do
            MadeInFrance.Bank.BankAccounts[result[i].id] = {
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

MadeInFrance.Bank.GetPersonnalAccounts = function(identifier)
    local accounts = {}
    for k, v in pairs(MadeInFrance.Bank.BankAccounts) do
        if v.owner == identifier then
            table.insert(accounts, v)
        end
    end
    return accounts
end

MadeInFrance.RegisterZone('Guichet de banque', vector3(243.2082, 224.7312, 106.2869), function(source)
    MadeInFrance.SendEventToClient('openBankMenu', source)
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

MadeInFrance.RegisterServerEvent('GetBankAccounts', function()
    MadeInFrance.SendEventToClient('receiveBankAccounts', source, MadeInFrance.Bank.BankAccounts)
end)

MadeInFrance.RegisterServerEvent('BankCreateAccount', function()
    local player = MadeInFrance.GetPlayerFromId(source)
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
        ['@iban'] = MadeInFrance.Bank.GenerateIBAN(25),
        ['@amountMoney'] = account.amountMoney,
        ['@transactions'] = json.encode(account.transactions),
        ['@courant'] = MadeInFrance.ConverToNumber(account.courant)
    })
    Wait(150)
    MadeInFrance.Bank.GetAllAccounts()
    Wait(150)
    MadeInFrance.SendEventToClient('receiveBankAccounts', player.source, MadeInFrance.Bank.BankAccounts)
    MadeInFrance.SendEventToClient('notify', player.source, 'Maze Bank', 'Votre compte a été créé avec succès.', 'success')
end)

MadeInFrance.RegisterServerEvent('BankChangeAccountStatus', function(id, state)
    local player = MadeInFrance.GetPlayerFromId(source)
    MySQL.Async.execute('UPDATE bankaccounts SET courant = @courant WHERE id = @id', {
        ['@id'] = id,
        ['@courant'] = state
    })
    Wait(150)
    MadeInFrance.Bank.GetAllAccounts()
    Wait(150)
    MadeInFrance.SendEventToClient('receiveBankAccounts', player.source, MadeInFrance.Bank.BankAccounts)
    MadeInFrance.SendEventToClient('notify', player.source, 'Maze Bank', 'Votre compte a été modifié avec succès.', 'success')
end)

MadeInFrance.RegisterServerEvent('BankDeleteAccount', function(id)
    local player = MadeInFrance.GetPlayerFromId(source)
    MySQL.Async.execute('DELETE FROM bankaccounts WHERE id = @id', {
        ['@id'] = id
    })
    Wait(150)
    MadeInFrance.Bank.GetAllAccounts()
    Wait(150)
    MadeInFrance.SendEventToClient('receiveBankAccounts', player.source, MadeInFrance.Bank.BankAccounts)
    MadeInFrance.SendEventToClient('notify', player.source, 'Maze Bank', 'Votre compte a été supprimé avec succès.', 'success')
end)


MadeInFrance.RegisterServerEvent('BankCreateCard', function(id)
    local player = MadeInFrance.GetPlayerFromId(source)
    local card = {
        owner_name = player.characterInfos.Prenom .. " " .. player.characterInfos.NDF,
        card_number = MadeInFrance.Bank.GenerateCardNumber(),
        card_pin = MadeInFrance.Bank.GenerateCardPin(),
        card_cvv = MadeInFrance.Bank.GenerateCardCVV(),
        card_expiration_date = MadeInFrance.Bank.GenerateCardExpirationDate(),
        card_type = 'Mastercard',
        card_account = id
    }
    MySQL.Async.execute('UPDATE bankaccounts SET card_infos = @card_infos WHERE id = @id', {
        ['@id'] = id,
        ['@card_infos'] = json.encode(card)
    })
    if MadeInFrance.Inventory.CanCarryItem(player, 'carte', 1) then
        MadeInFrance.Inventory.AddItemInInventory(player, 'carte', 1, 'Compte n°' ..id, nil, card)
    end
    Wait(150)
    MadeInFrance.Bank.GetAllAccounts()
    Wait(150)
    MadeInFrance.SendEventToClient('receiveBankAccounts', player.source, MadeInFrance.Bank.BankAccounts)
    MadeInFrance.SendEventToClient('notify', player.source, 'Maze Bank', 'Votre carte a été créée avec succès.', 'success')
end)

MadeInFrance.Bank.GetAccount = function(id)
    local account = nil
    for k, v in pairs(MadeInFrance.Bank.BankAccounts) do
        if v.id == id then
            account = v
            break
        end
    end
    return account
end

MadeInFrance.Bank.AddTransaction = function(account, amount, message, type)
    local _src = source
    local player = MadeInFrance.GetPlayerFromId(_src)
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
    MadeInFrance.Bank.GetAllAccounts()
    Wait(150)
    MadeInFrance.SendEventToClient('receiveBankAccounts', _src, MadeInFrance.Bank.BankAccounts)
end

MadeInFrance.Bank.UpdateAccount = function(account, amount)
    local _src = source
    local player = MadeInFrance.GetPlayerFromId(_src)
    account.amountMoney = amount
    MySQL.Async.execute('UPDATE bankaccounts SET amountMoney = @amountMoney WHERE id = @id', {
        ['@id'] = account.id,
        ['@amountMoney'] = account.amountMoney
    })
    Wait(150)
    MadeInFrance.Bank.GetAllAccounts()
    Wait(150)
    MadeInFrance.SendEventToClient('receiveBankAccounts', _src, MadeInFrance.Bank.BankAccounts)
end

MadeInFrance.RegisterServerEvent('BankAddMoney', function(amount, id)
    local player = MadeInFrance.GetPlayerFromId(source)
    local account = MadeInFrance.Bank.GetAccount(id)
    if account ~= nil then
        if MadeInFrance.Money.GetPlayerMoney(player) >= tonumber(amount) then
            MadeInFrance.Money.RemovePlayerMoney(player, amount)
            MadeInFrance.Bank.UpdateAccount(account, account.amountMoney + amount)
            MadeInFrance.Bank.AddTransaction(account, amount, 'Ajout de '..amount..'$', 'Dépôt')
            MadeInFrance.SendEventToClient('notify', player.source, 'Maze Bank', 'Vous avez ajouté ' .. amount .. '$ à votre compte.', 'success')
        else
            MadeInFrance.SendEventToClient('notify', player.source, 'Maze Bank', 'Vous n\'avez pas assez d\'argent.', 'error')
        end
    end
end)

MadeInFrance.RegisterServerEvent('BankwithdrawMoney', function(amount, id)
    local player = MadeInFrance.GetPlayerFromId(source)
    local account = MadeInFrance.Bank.GetAccount(id)
    if tonumber(account.amountMoney) >= tonumber(amount) then
        MadeInFrance.Bank.AddTransaction(account, amount, 'Retrait de ' .. amount .. '$', 'Retrait')
        MadeInFrance.Bank.UpdateAccount(account, account.amountMoney - amount)
        MadeInFrance.Money.AddPlayerMoney(player, amount)
        MadeInFrance.SendEventToClient('notify', player.source, 'Maze Bank', 'Vous avez retiré ' .. amount .. '$ avec succès.', 'success')
    else
        MadeInFrance.SendEventToClient('notify', player.source, 'Maze Bank', 'Vous n\'avez pas assez d\'argent sur votre compte.', 'error')
    end
end)

MadeInFrance.Bank.GenerateCardNumber = function()
    local number = ''
    for i = 1, 16 do
        number = number .. math.random(0, 9)
    end
    return number
end

MadeInFrance.Bank.GenerateCardPin = function()
    local pin = ''
    for i = 1, 4 do
        pin = pin .. math.random(0, 9)
    end
    return pin
end 

MadeInFrance.Bank.GenerateCardCVV = function()
    return math.random(100, 999)
end

MadeInFrance.Bank.GenerateCardExpirationDate = function()
    local month = math.random(1, 12)
    local year = math.random(2022, 2030)
    return month .. '/' .. year
end

MadeInFrance.Bank.GenerateIBAN = function(length)
    local string = ""
    for i = 1, length, 1 do
        local random = math.random(0, 1)
        if random == 0 then
            string = string .. math.random(0, 9)
        else
            string = string .. string.char(math.random(65, 90))
        end
    end

    string = 'MIF' .. string

    local exist = false

    for key, value in pairs(MadeInFrance.Bank.BankAccounts) do
        if value.iban == string then
            exist = true
            break
        end
    end

    if exist then
        MadeInFrance.Bank.GenerateIBAN(length)
    else
        return string
    end
end

MadeInFrance.RegisterUsableItem('carte', function(data)
    local _src = source
    local player = MadeInFrance.GetPlayerFromId(source)
    MadeInFrance.SendEventToClient('useCarteBank', player.source, data)
end)