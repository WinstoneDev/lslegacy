local bankState = {
    opened = false,
    mode = nil, -- 'branch' | 'atm'
    accounts = {},
    livrets = {},
    atmAccountId = nil,
    -- mis en cache car ces réponses arrivent souvent avant bankState.opened
    adminRates = nil,
    adminCardTiers = nil
}

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

      if distance < 1.3 then
        return true
      else
        return false
      end
end

local function GetPersonnalAccounts()
    local result = {}
    for key, value in pairs(bankState.accounts) do
        if value.character_id == LSLegacy.PlayerData["boutique-id"] then
            table.insert(result, value)
        end
    end
    return result
end

-- l'ATM identifie le compte par carte+PIN, pas par character_id (carte volée doit marcher)
local function GetAccountById(id)
    for key, value in pairs(bankState.accounts) do
        if value.id == id then
            return value
        end
    end
    return nil
end

local function GetMyLevel()
    for k, v in pairs(Config.StaffGroups) do
        if LSLegacy.PlayerData.group == v then return k end
    end
    return 0
end

local function OpenBankNUI(mode, theme, displayName)
    if bankState.opened then return end
    bankState.opened = true
    bankState.mode = mode

    local accounts
    if mode == 'atm' then
        local atmAccount = GetAccountById(bankState.atmAccountId)
        accounts = atmAccount and {atmAccount} or {}
    else
        accounts = GetPersonnalAccounts()
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'bank:open',
        mode = mode,
        theme = theme,
        displayName = displayName,
        accounts = accounts,
        livrets = bankState.livrets,
        isAdmin = (GetMyLevel() >= ((Config.Bank and Config.Bank.AdminMinLevel) or 3)),
        atmAccountId = bankState.atmAccountId,
        adminRates = bankState.adminRates,
        adminCardTiers = bankState.adminCardTiers
    })
end

local function CloseBankNUI()
    if not bankState.opened then return end
    bankState.opened = false
    bankState.mode = nil
    bankState.atmAccountId = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'bank:hide' })
end

LSLegacy.Events.Register('openBankMenu', function(theme, displayName)
    LSLegacy.Events.SendToServer('bank:getBankAccounts')
    LSLegacy.Events.SendToServer('bank:getLivrets')
    LSLegacy.Events.SendToServer('bank:adminGetRates')
    LSLegacy.Events.SendToServer('bank:adminGetCardTiers')
    Wait(150)
    OpenBankNUI('branch', theme or 'mazebank', displayName or 'Maze Bank')
end)

LSLegacy.Events.Register('useCarteBank', function(data)
    if NearAtms() then
        local input = LSLegacy.KeyboardInput('Code PIN', 4)
        if tonumber(input) then
            if tonumber(input) == tonumber(data.card_pin) then
                bankState.atmAccountId = data.card_account
                LSLegacy.Events.SendToServer('bank:getBankAccounts')
                LSLegacy.Events.SendToServer('bank:adminGetCardTiers')
                Wait(150)
                OpenBankNUI('atm', 'mazebank', 'Distributeur')
            else
                LSLegacy.ShowNotification('Maze Bank', 'Le code PIN est incorrect.', 'error')
            end
        else
            LSLegacy.ShowNotification('Maze Bank', 'Vous avez entré un code invalide.', 'error')
        end
    end
end)

LSLegacy.Events.Register('receiveBankAccounts', function(accounts)
    bankState.accounts = accounts
    if bankState.opened then
        local refreshed
        if bankState.mode == 'atm' then
            local atmAccount = GetAccountById(bankState.atmAccountId)
            refreshed = atmAccount and {atmAccount} or {}
        else
            refreshed = GetPersonnalAccounts()
        end
        SendNUIMessage({ action = 'bank:accounts', accounts = refreshed })
    end
end)

LSLegacy.Events.Register('receiveBankLivrets', function(livrets)
    bankState.livrets = livrets
    if bankState.opened then
        SendNUIMessage({ action = 'bank:livrets', livrets = livrets })
    end
end)

LSLegacy.Events.Register('receiveBankAdminRates', function(rates)
    bankState.adminRates = rates
    if bankState.opened then
        SendNUIMessage({ action = 'bank:adminRates', rates = rates })
    end
end)

LSLegacy.Events.Register('receiveBankAdminCardTiers', function(tiers)
    bankState.adminCardTiers = tiers
    if bankState.opened then
        SendNUIMessage({ action = 'bank:adminCardTiers', tiers = tiers })
    end
end)

-- relais purs vers les server events, pas de logique métier ici

RegisterNUICallback('bank:close', function(data, cb)
    CloseBankNUI()
    cb('ok')
end)

RegisterNUICallback('bank:createAccount', function(data, cb)
    LSLegacy.Events.SendToServer('bank:createAccount')
    cb('ok')
end)

RegisterNUICallback('bank:deleteAccount', function(data, cb)
    LSLegacy.Events.SendToServer('bank:deleteAccount', data.id)
    cb('ok')
end)

RegisterNUICallback('bank:setCourant', function(data, cb)
    LSLegacy.Events.SendToServer('bank:changeAccountStatus', data.id, data.state)
    cb('ok')
end)

RegisterNUICallback('bank:createCard', function(data, cb)
    LSLegacy.Events.SendToServer('bank:createCard', data.id, data.tier)
    cb('ok')
end)

RegisterNUICallback('bank:setCardTier', function(data, cb)
    LSLegacy.Events.SendToServer('bank:setCardTier', data.id, data.tier)
    cb('ok')
end)

RegisterNUICallback('bank:atmDeposit', function(data, cb)
    LSLegacy.Events.SendToServer('bank:addMoney', data.amount, data.id)
    cb('ok')
end)

RegisterNUICallback('bank:atmWithdraw', function(data, cb)
    LSLegacy.Events.SendToServer('bank:withdrawMoney', data.amount, data.id)
    cb('ok')
end)

RegisterNUICallback('bank:makeTransfer', function(data, cb)
    LSLegacy.Events.SendToServer('bank:transferByIban', data.fromAccountId, data.toIban, data.amount, data.message)
    cb('ok')
end)

RegisterNUICallback('bank:openLivret', function(data, cb)
    LSLegacy.Events.SendToServer('bank:openLivret', data.linkedAccountId, data.livretType, data.initialDeposit)
    cb('ok')
end)

RegisterNUICallback('bank:depositLivret', function(data, cb)
    LSLegacy.Events.SendToServer('bank:depositLivret', data.livretId, data.amount)
    cb('ok')
end)

RegisterNUICallback('bank:withdrawLivret', function(data, cb)
    LSLegacy.Events.SendToServer('bank:withdrawLivret', data.livretId, data.amount)
    cb('ok')
end)

RegisterNUICallback('bank:closeLivret', function(data, cb)
    LSLegacy.Events.SendToServer('bank:closeLivret', data.livretId)
    cb('ok')
end)

RegisterNUICallback('bank:getAdminRates', function(data, cb)
    LSLegacy.Events.SendToServer('bank:adminGetRates')
    cb('ok')
end)

RegisterNUICallback('bank:setAdminRate', function(data, cb)
    LSLegacy.Events.SendToServer('bank:adminSetRate', data.livretType, data.rate)
    cb('ok')
end)

RegisterNUICallback('bank:getAdminCardTiers', function(data, cb)
    LSLegacy.Events.SendToServer('bank:adminGetCardTiers')
    cb('ok')
end)

RegisterNUICallback('bank:setAdminCardTier', function(data, cb)
    LSLegacy.Events.SendToServer('bank:adminSetCardTier', data.tier, data.config)
    cb('ok')
end)
