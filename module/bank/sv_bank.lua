local rateLimits = {
    ['GetBankAccounts'] = 30, ['BankCreateAccount'] = 15, ['BankChangeAccountStatus'] = 20,
    ['BankDeleteAccount'] = 20, ['BankCreateCard'] = 20, ['BankwithdrawMoney'] = 20,
    ['BankAddMoney'] = 20, ['lslegacy:requestBankBalance'] = 20, ['attemptToPayMenu'] = 20,
    ['pay'] = 20,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

LSLegacy.Bank = {}
LSLegacy.Bank.BankAccounts = {}
LSLegacy.Bank.Livrets = {}
LSLegacy.Bank.InterestRates = {}
LSLegacy.Bank.CardTiers = {}

-- init tables BDD (redondant avec winframe_database.sql, garantit que la ressource marche sur une base pas migrée)

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS bank_livrets (
        id                      INT(11)      NOT NULL AUTO_INCREMENT,
        owner                   VARCHAR(60)  NOT NULL DEFAULT '',
        character_id            INT(11)      NULL,
        owner_name              VARCHAR(100) NOT NULL DEFAULT '',
        linked_account_id       INT(11)      NOT NULL,
        livret_type             ENUM('livret_a','ldds','compte_terme') NOT NULL,
        amountMoney             FLOAT        NOT NULL DEFAULT 0,
        opened_at               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
        maturity_date           DATETIME     NULL,
        interest_rate_snapshot  FLOAT        NOT NULL DEFAULT 0,
        transactions            LONGTEXT     NOT NULL DEFAULT '[]',
        status                  ENUM('active','closed') NOT NULL DEFAULT 'active',
        PRIMARY KEY (id),
        KEY idx_bank_livrets_owner (owner),
        KEY idx_bank_livrets_linked_account (linked_account_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS bank_interest_rates (
        livret_type                        VARCHAR(20) NOT NULL,
        rate_percent                       FLOAT       NOT NULL DEFAULT 0,
        deposit_cap                        FLOAT       NULL,
        early_withdrawal_penalty_percent   FLOAT       NULL,
        min_term_days                      INT(11)     NULL,
        updated_by                         VARCHAR(100) NULL,
        updated_at                         DATETIME     NULL,
        PRIMARY KEY (livret_type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS bank_card_tiers (
        tier                    VARCHAR(20) NOT NULL,
        cost_amount             FLOAT       NOT NULL DEFAULT 0,
        cost_period             ENUM('weekly','monthly') NOT NULL DEFAULT 'weekly',
        payment_ceiling         FLOAT       NOT NULL DEFAULT 0,
        withdrawal_ceiling      FLOAT       NOT NULL DEFAULT 0,
        transfer_ceiling        FLOAT       NOT NULL DEFAULT 0,
        overdraft_limit         FLOAT       NOT NULL DEFAULT 0,
        agios_rate_percent      FLOAT       NOT NULL DEFAULT 0,
        updated_by              VARCHAR(100) NULL,
        updated_at              DATETIME     NULL,
        PRIMARY KEY (tier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- taux journaliers (rate_percent = % versé chaque jour, composé), ajustables via le panneau admin
MySQL.Async.execute([[
    INSERT IGNORE INTO bank_interest_rates (livret_type, rate_percent, deposit_cap, early_withdrawal_penalty_percent, min_term_days) VALUES
        ('livret_a', 0.05, 15000, NULL, NULL),
        ('ldds', 0.045, 10000, NULL, NULL),
        ('compte_terme', 0.08, NULL, 50.0, 7)
]], {})

MySQL.Async.execute([[
    INSERT IGNORE INTO bank_card_tiers (tier, cost_amount, cost_period, payment_ceiling, withdrawal_ceiling, transfer_ceiling, overdraft_limit, agios_rate_percent) VALUES
        ('standard', 0, 'weekly', 2000, 1000, 3000, 0, 0),
        ('premier', 25, 'weekly', 5000, 2500, 8000, 1000, 3.0),
        ('platinum', 80, 'monthly', 15000, 5000, 25000, 5000, 2.0)
]], {})

MySQL.ready(function()
    LSLegacy.Bank.GetAllAccounts()
    LSLegacy.Bank.GetAllLivrets()
    LSLegacy.Bank.GetAllInterestRates()
    LSLegacy.Bank.GetAllCardTiers()
end)

-- oxmysql renvoie les DATETIME en chaînes "YYYY-MM-DD HH:MM:SS", conversion manuelle en timestamp Unix

local function ParseSqlDatetime(s)
    if not s or s == '' then return nil end
    local y, mo, d, h, mi, se = string.match(tostring(s), '(%d+)-(%d+)-(%d+)[ T](%d+):(%d+):(%d+)')
    if not y then return nil end
    return os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = tonumber(se) })
end

local function FormatSqlDatetime(timestamp)
    return os.date('%Y-%m-%d %H:%M:%S', timestamp)
end

-- `cb` (optionnel) n'est appelé qu'une fois BankAccounts réellement repeuplé — à utiliser plutôt qu'un délai deviné
LSLegacy.Bank.GetAllAccounts = function(cb)
    LSLegacy.Bank.BankAccounts = {}
    MySQL.Async.fetchAll('SELECT * FROM bankaccounts', {}, function(result)
        for i = 1, #result, 1 do
            LSLegacy.Bank.BankAccounts[result[i].id] = {
                id = result[i].id,
                owner = result[i].owner,
                character_id = result[i].character_id,
                owner_name = result[i].owner_name,
                iban = result[i].iban,
                amountMoney = result[i].amountMoney,
                transactions = json.decode(result[i].transactions),
                courant = result[i].courant,
                card_infos = json.decode(result[i].card_infos),
                card_tier = result[i].card_tier or 'standard',
                next_billing_at = result[i].next_billing_at,
                payment_spent = result[i].payment_spent or 0,
                withdrawal_spent = result[i].withdrawal_spent or 0,
                transfer_spent = result[i].transfer_spent or 0,
                ceiling_period_reset_at = result[i].ceiling_period_reset_at
            }
        end
        if cb then cb() end
    end)
end

LSLegacy.Bank.GetPersonnalAccounts = function(characterId)
    local accounts = {}
    for k, v in pairs(LSLegacy.Bank.BankAccounts) do
        if v.character_id == characterId then
            table.insert(accounts, v)
        end
    end
    return accounts
end

LSLegacy.RegisterZone('Guichet de banque', vector3(243.2082, 224.7312, 106.2869), function(source)
    LSLegacy.SendEventToClient('openBankMenu', source, 'mazebank', 'Maze Bank')
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
        character_id = player["boutique-id"],
        owner_name = player.characterInfos.Prenom .. " " .. player.characterInfos.NDF,
        amountMoney = 0,
        transactions = {},
        courant = false
    }
    MySQL.Async.execute('INSERT INTO bankaccounts (owner, character_id, owner_name, iban, amountMoney, transactions, courant) VALUES  (@owner, @character_id, @owner_name, @iban, @amountMoney, @transactions, @courant)', {
        ['@owner'] = account.owner,
        ['@character_id'] = account.character_id,
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
    local account = LSLegacy.Bank.GetAccount(id)
    if not account or account.character_id ~= player["boutique-id"] then return end

    if state then
        -- un seul compte courant par personnage : désactive l'ancien avant d'activer le nouveau
        MySQL.Async.execute('UPDATE bankaccounts SET courant = 0 WHERE character_id = @characterId', {
            ['@characterId'] = account.character_id
        })
    end

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
    local account = LSLegacy.Bank.GetAccount(id)
    if not account or account.character_id ~= player["boutique-id"] then return end
    MySQL.Async.execute('DELETE FROM bankaccounts WHERE id = @id', {
        ['@id'] = id
    })
    MySQL.Async.execute('DELETE FROM bank_livrets WHERE linked_account_id = @id', {
        ['@id'] = id
    })
    Wait(150)
    LSLegacy.Bank.GetAllAccounts()
    LSLegacy.Bank.GetAllLivrets()
    Wait(150)
    LSLegacy.SendEventToClient('receiveBankAccounts', player.source, LSLegacy.Bank.BankAccounts)
    LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Votre compte a été supprimé avec succès.', 'success')
end)


LSLegacy.RegisterServerEvent('BankCreateCard', function(id, tier)
    local player = LSLegacy.GetPlayerFromId(source)
    local account = LSLegacy.Bank.GetAccount(id)
    if not account or account.character_id ~= player["boutique-id"] then return end

    tier = LSLegacy.Bank.CardTiers[tier] and tier or 'standard'
    local tierCfg = LSLegacy.Bank.GetCardTierConfig(tier)

    local card = {
        owner_name = player.characterInfos.Prenom .. " " .. player.characterInfos.NDF,
        card_number = LSLegacy.Bank.GenerateCardNumber(),
        card_pin = LSLegacy.Bank.GenerateCardPin(),
        card_cvv = LSLegacy.Bank.GenerateCardCVV(),
        card_expiration_date = LSLegacy.Bank.GenerateCardExpirationDate(),
        card_type = 'Mastercarte',
        card_account = id,
        card_tier = tier
    }

    local nextBillingAt = nil
    if tierCfg.cost_amount and tierCfg.cost_amount > 0 then
        local days = tierCfg.cost_period == 'monthly' and 30 or 7
        nextBillingAt = FormatSqlDatetime(os.time() + days * 86400)
    end

    MySQL.Async.execute('UPDATE bankaccounts SET card_infos = @card_infos, card_tier = @card_tier, next_billing_at = @next_billing_at WHERE id = @id', {
        ['@id'] = id,
        ['@card_infos'] = json.encode(card),
        ['@card_tier'] = tier,
        ['@next_billing_at'] = nextBillingAt
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

LSLegacy.RegisterServerEvent('BankSetCardTier', function(id, tier)
    local player = LSLegacy.GetPlayerFromId(source)
    local account = LSLegacy.Bank.GetAccount(id)
    if not account or account.character_id ~= player["boutique-id"] then return end
    if not LSLegacy.Bank.CardTiers[tier] then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Palier de carte invalide.', 'error')
        return
    end

    local tierCfg = LSLegacy.Bank.GetCardTierConfig(tier)
    local nextBillingAt = nil
    if tierCfg.cost_amount and tierCfg.cost_amount > 0 then
        local days = tierCfg.cost_period == 'monthly' and 30 or 7
        nextBillingAt = FormatSqlDatetime(os.time() + days * 86400)
    end

    local cardInfos = account.card_infos
    if cardInfos then
        cardInfos.card_tier = tier
    end

    MySQL.Async.execute('UPDATE bankaccounts SET card_tier = @card_tier, next_billing_at = @next_billing_at, card_infos = @card_infos WHERE id = @id', {
        ['@id'] = id,
        ['@card_tier'] = tier,
        ['@next_billing_at'] = nextBillingAt,
        ['@card_infos'] = cardInfos and json.encode(cardInfos) or nil
    })
    Wait(150)
    LSLegacy.Bank.GetAllAccounts()
    Wait(150)
    LSLegacy.SendEventToClient('receiveBankAccounts', player.source, LSLegacy.Bank.BankAccounts)
    LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Votre palier de carte est maintenant '..tier..'.', 'success')
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

-- rechargement + push client seulement après confirmation de l'UPDATE (callback oxmysql), pas après un Wait deviné :
-- un virement enchaîne plusieurs Add/UpdateAccount et un simple délai pouvait écraser une écriture pas encore commitée
LSLegacy.Bank.AddTransaction = function(account, amount, message, type)
    local _src = source
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
    }, function()
        LSLegacy.Bank.GetAllAccounts(function()
            LSLegacy.SendEventToClient('receiveBankAccounts', _src, LSLegacy.Bank.BankAccounts)
        end)
    end)
end

LSLegacy.Bank.UpdateAccount = function(account, amount)
    local _src = source
    account.amountMoney = amount
    MySQL.Async.execute('UPDATE bankaccounts SET amountMoney = @amountMoney WHERE id = @id', {
        ['@id'] = account.id,
        ['@amountMoney'] = account.amountMoney
    }, function()
        LSLegacy.Bank.GetAllAccounts(function()
            LSLegacy.SendEventToClient('receiveBankAccounts', _src, LSLegacy.Bank.BankAccounts)
        end)
    end)
end
LSLegacy.RegisterServerEvent('BankAddMoney', function(amount, id)
    local player = LSLegacy.Validate.Player(source)
    local account = LSLegacy.Bank.GetAccount(id)
    if not player or not account then return end
    amount = LSLegacy.Validate.PositiveInteger(amount)
    if not amount then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Montant invalide.', 'error')
        return
    end
    if LSLegacy.Money.GetPlayerMoney(player) >= amount then
        LSLegacy.Money.RemovePlayerMoney(player, amount)
        LSLegacy.Bank.UpdateAccount(account, account.amountMoney + amount)
        LSLegacy.Bank.AddTransaction(account, amount, 'Ajout de '..amount..'$', 'Dépôt')
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Vous avez ajouté ' .. amount .. '$ à votre compte.', 'success')
    else
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Vous n\'avez pas assez d\'argent.', 'error')
    end
end)

LSLegacy.RegisterServerEvent('BankwithdrawMoney', function(amount, id)
    local player = LSLegacy.GetPlayerFromId(source)
    local account = LSLegacy.Bank.GetAccount(id)
    if not account then return end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    local tierCfg = LSLegacy.Bank.GetCardTierConfig(account.card_tier)

    if (account.amountMoney + tierCfg.overdraft_limit) >= amount then
        -- ne consommer le plafond que si le retrait va effectivement avoir lieu
        local ok, remaining = LSLegacy.Bank.CheckAndConsumeCeiling(account, 'withdrawal', amount, tierCfg.withdrawal_ceiling, tierCfg.cost_period)
        if not ok then
            LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Plafond de retrait atteint : il vous reste '..math.max(0, math.floor(remaining))..'$ sur '..tierCfg.withdrawal_ceiling..'$ sur la période en cours.', 'error')
            return
        end
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
    local year = math.random(2029, 2035)
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

-- Admin.CanDo/GetLevel du module adminmenu sont locaux à leur fichier : helper dupliqué ici, synchronisé via Config.StaffGroups

local function BankAdminLevel(source)
    local player = LSLegacy.GetPlayerFromId(source)
    if not player then return 0 end
    for k, v in pairs(Config.StaffGroups) do
        if player.group == v then return k end
    end
    return 0
end

local function BankAdminCanDo(source)
    return BankAdminLevel(source) >= (Config.Bank and Config.Bank.AdminMinLevel or 3)
end

local function GetSourceByCharacterIdForBank(characterId)
    if not characterId then return nil end
    for src, p in pairs(LSLegacy.ServerPlayers) do
        if p["boutique-id"] == characterId then
            return src
        end
    end
    return nil
end

-- paliers de carte (plafonds / découvert / agios / coût) — bank_card_tiers

LSLegacy.Bank.GetAllCardTiers = function()
    MySQL.Async.fetchAll('SELECT * FROM bank_card_tiers', {}, function(result)
        LSLegacy.Bank.CardTiers = {}
        for i = 1, #result, 1 do
            LSLegacy.Bank.CardTiers[result[i].tier] = result[i]
        end
    end)
end

LSLegacy.Bank.GetCardTierConfig = function(tierName)
    local cfg = LSLegacy.Bank.CardTiers[tierName] or LSLegacy.Bank.CardTiers['standard']
    return cfg or { cost_amount = 0, cost_period = 'weekly', payment_ceiling = 0, withdrawal_ceiling = 0, transfer_ceiling = 0, overdraft_limit = 0, agios_rate_percent = 0 }
end

-- plafonds cumulatifs sur une période glissante (pas par transaction) : la période de reset suit le cost_period
-- propre à la carte (bank_card_tiers, hebdo/mensuel), pas une constante globale

local CeilingField = {
    payment = 'payment_spent',
    withdrawal = 'withdrawal_spent',
    transfer = 'transfer_spent'
}

-- retourne (ok, remaining, spent) sans committer si ok est false ; si ok, met à jour mémoire + BDD
LSLegacy.Bank.CheckAndConsumeCeiling = function(account, ceilingType, amount, ceilingLimit, costPeriod)
    local field = CeilingField[ceilingType]
    if not field then return true, ceilingLimit end

    local now = os.time()
    local resetAt = ParseSqlDatetime(account.ceiling_period_reset_at)
    if not resetAt or now >= resetAt then
        account.payment_spent = 0
        account.withdrawal_spent = 0
        account.transfer_spent = 0
        local periodDays = (costPeriod == 'monthly') and 30 or 7
        account.ceiling_period_reset_at = FormatSqlDatetime(now + periodDays * 86400)
    end

    local spent = account[field] or 0
    local remaining = ceilingLimit - spent

    if amount > remaining then
        return false, remaining, spent
    end

    account[field] = spent + amount
    MySQL.Async.execute('UPDATE bankaccounts SET payment_spent = @payment_spent, withdrawal_spent = @withdrawal_spent, transfer_spent = @transfer_spent, ceiling_period_reset_at = @ceiling_period_reset_at WHERE id = @id', {
        ['@id'] = account.id,
        ['@payment_spent'] = account.payment_spent,
        ['@withdrawal_spent'] = account.withdrawal_spent,
        ['@transfer_spent'] = account.transfer_spent,
        ['@ceiling_period_reset_at'] = account.ceiling_period_reset_at
    })
    -- laisse l'UPDATE atteindre la BDD avant le reload des comptes qui suit presque toujours (AddTransaction/UpdateAccount)
    Wait(150)

    return true, remaining - amount, account[field]
end

-- lecture publique (non gated) : tout joueur doit voir taux/plafonds avant de choisir ; seule l'écriture est gated staff
LSLegacy.RegisterServerEvent('BankAdminGetCardTiers', function()
    LSLegacy.SendEventToClient('receiveBankAdminCardTiers', source, LSLegacy.Bank.CardTiers)
end)

LSLegacy.RegisterServerEvent('BankAdminSetCardTier', function(tier, data)
    local player = LSLegacy.GetPlayerFromId(source)
    if not BankAdminCanDo(source) then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Action non autorisée.', 'error')
        return
    end
    if not tier or type(data) ~= 'table' then return end

    MySQL.Async.execute([[
        UPDATE bank_card_tiers SET
            cost_amount = @cost_amount,
            cost_period = @cost_period,
            payment_ceiling = @payment_ceiling,
            withdrawal_ceiling = @withdrawal_ceiling,
            transfer_ceiling = @transfer_ceiling,
            overdraft_limit = @overdraft_limit,
            agios_rate_percent = @agios_rate_percent,
            updated_by = @updated_by,
            updated_at = @updated_at
        WHERE tier = @tier
    ]], {
        ['@tier'] = tier,
        ['@cost_amount'] = tonumber(data.cost_amount) or 0,
        ['@cost_period'] = (data.cost_period == 'monthly') and 'monthly' or 'weekly',
        ['@payment_ceiling'] = tonumber(data.payment_ceiling) or 0,
        ['@withdrawal_ceiling'] = tonumber(data.withdrawal_ceiling) or 0,
        ['@transfer_ceiling'] = tonumber(data.transfer_ceiling) or 0,
        ['@overdraft_limit'] = tonumber(data.overdraft_limit) or 0,
        ['@agios_rate_percent'] = tonumber(data.agios_rate_percent) or 0,
        ['@updated_by'] = player.characterInfos.Prenom .. " " .. player.characterInfos.NDF,
        ['@updated_at'] = FormatSqlDatetime(os.time())
    })
    Wait(150)
    LSLegacy.Bank.GetAllCardTiers()
    Wait(150)
    LSLegacy.SendEventToClient('receiveBankAdminCardTiers', player.source, LSLegacy.Bank.CardTiers)
    LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Palier '..tier..' mis à jour.', 'success')
end)

-- taux d'intérêt des livrets — bank_interest_rates

LSLegacy.Bank.GetAllInterestRates = function()
    MySQL.Async.fetchAll('SELECT * FROM bank_interest_rates', {}, function(result)
        LSLegacy.Bank.InterestRates = {}
        for i = 1, #result, 1 do
            LSLegacy.Bank.InterestRates[result[i].livret_type] = result[i]
        end
    end)
end

-- lecture publique (non gated), même raison que BankAdminGetCardTiers
LSLegacy.RegisterServerEvent('BankAdminGetRates', function()
    LSLegacy.SendEventToClient('receiveBankAdminRates', source, LSLegacy.Bank.InterestRates)
end)

LSLegacy.RegisterServerEvent('BankAdminSetRate', function(livretType, data)
    local player = LSLegacy.GetPlayerFromId(source)
    if not BankAdminCanDo(source) then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Action non autorisée.', 'error')
        return
    end
    if not (livretType == 'livret_a' or livretType == 'ldds' or livretType == 'compte_terme') or type(data) ~= 'table' then return end

    MySQL.Async.execute([[
        UPDATE bank_interest_rates SET
            rate_percent = @rate_percent,
            deposit_cap = @deposit_cap,
            early_withdrawal_penalty_percent = @early_withdrawal_penalty_percent,
            min_term_days = @min_term_days,
            updated_by = @updated_by,
            updated_at = @updated_at
        WHERE livret_type = @livret_type
    ]], {
        ['@livret_type'] = livretType,
        ['@rate_percent'] = tonumber(data.rate_percent) or 0,
        ['@deposit_cap'] = data.deposit_cap ~= nil and tonumber(data.deposit_cap) or nil,
        ['@early_withdrawal_penalty_percent'] = data.early_withdrawal_penalty_percent ~= nil and tonumber(data.early_withdrawal_penalty_percent) or nil,
        ['@min_term_days'] = data.min_term_days ~= nil and tonumber(data.min_term_days) or nil,
        ['@updated_by'] = player.characterInfos.Prenom .. " " .. player.characterInfos.NDF,
        ['@updated_at'] = FormatSqlDatetime(os.time())
    })
    Wait(150)
    LSLegacy.Bank.GetAllInterestRates()
    Wait(150)
    LSLegacy.SendEventToClient('receiveBankAdminRates', player.source, LSLegacy.Bank.InterestRates)
    LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Taux de '..livretType..' mis à jour.', 'success')
end)

-- livrets d'épargne — bank_livrets

LSLegacy.Bank.GetAllLivrets = function()
    MySQL.Async.fetchAll('SELECT * FROM bank_livrets', {}, function(result)
        LSLegacy.Bank.Livrets = {}
        for i = 1, #result, 1 do
            local row = result[i]
            LSLegacy.Bank.Livrets[row.id] = {
                id = row.id,
                owner = row.owner,
                character_id = row.character_id,
                owner_name = row.owner_name,
                linked_account_id = row.linked_account_id,
                livret_type = row.livret_type,
                amountMoney = row.amountMoney,
                opened_at = row.opened_at,
                maturity_date = row.maturity_date,
                interest_rate_snapshot = row.interest_rate_snapshot,
                transactions = json.decode(row.transactions),
                status = row.status
            }
        end
    end)
end

LSLegacy.Bank.GetLivret = function(id)
    return LSLegacy.Bank.Livrets[id]
end

LSLegacy.Bank.GetPersonnalLivrets = function(characterId)
    local livrets = {}
    for k, v in pairs(LSLegacy.Bank.Livrets) do
        if v.character_id == characterId then
            table.insert(livrets, v)
        end
    end
    return livrets
end

LSLegacy.RegisterServerEvent('BankGetLivrets', function()
    local player = LSLegacy.GetPlayerFromId(source)
    LSLegacy.SendEventToClient('receiveBankLivrets', source, LSLegacy.Bank.GetPersonnalLivrets(player["boutique-id"]))
end)

LSLegacy.RegisterServerEvent('BankOpenLivret', function(linkedAccountId, livretType, initialDeposit)
    local player = LSLegacy.GetPlayerFromId(source)
    local account = LSLegacy.Bank.GetAccount(linkedAccountId)
    if not account or account.character_id ~= player["boutique-id"] then return end
    if not (livretType == 'livret_a' or livretType == 'ldds' or livretType == 'compte_terme') then return end

    initialDeposit = tonumber(initialDeposit) or 0
    if initialDeposit < 0 then return end
    if livretType == 'compte_terme' and initialDeposit <= 0 then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Un compte à terme nécessite un dépôt initial.', 'error')
        return
    end

    local rateCfg = LSLegacy.Bank.InterestRates[livretType]
    if not rateCfg then return end

    if rateCfg.deposit_cap and initialDeposit > rateCfg.deposit_cap then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Plafond de dépôt dépassé (max '..rateCfg.deposit_cap..'$).', 'error')
        return
    end

    if initialDeposit > 0 and account.amountMoney < initialDeposit then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Solde insuffisant sur le compte lié.', 'error')
        return
    end

    local maturityDate = nil
    if livretType == 'compte_terme' then
        local days = rateCfg.min_term_days or 7
        maturityDate = FormatSqlDatetime(os.time() + days * 86400)
    end

    MySQL.Async.execute([[
        INSERT INTO bank_livrets (owner, character_id, owner_name, linked_account_id, livret_type, amountMoney, maturity_date, interest_rate_snapshot, transactions, status)
        VALUES (@owner, @character_id, @owner_name, @linked_account_id, @livret_type, @amountMoney, @maturity_date, @interest_rate_snapshot, @transactions, 'active')
    ]], {
        ['@owner'] = account.owner,
        ['@character_id'] = account.character_id,
        ['@owner_name'] = account.owner_name,
        ['@linked_account_id'] = linkedAccountId,
        ['@livret_type'] = livretType,
        ['@amountMoney'] = initialDeposit,
        ['@maturity_date'] = maturityDate,
        ['@interest_rate_snapshot'] = rateCfg.rate_percent,
        ['@transactions'] = json.encode(initialDeposit > 0 and {{amount = initialDeposit, type = 'Dépôt', message = 'Ouverture du livret', date = os.date('%d/%m/%Y %H:%M:%S')}} or {})
    })

    if initialDeposit > 0 then
        LSLegacy.Bank.AddTransaction(account, initialDeposit, 'Ouverture livret ('..livretType..')', 'Livret')
        LSLegacy.Bank.UpdateAccount(account, account.amountMoney - initialDeposit)
    end

    Wait(150)
    LSLegacy.Bank.GetAllLivrets()
    Wait(150)
    LSLegacy.SendEventToClient('receiveBankLivrets', player.source, LSLegacy.Bank.GetPersonnalLivrets(player["boutique-id"]))
    LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Livret ouvert avec succès.', 'success')
end)

LSLegacy.RegisterServerEvent('BankDepositLivret', function(livretId, amount)
    local player = LSLegacy.GetPlayerFromId(source)
    local livret = LSLegacy.Bank.GetLivret(livretId)
    if not livret or livret.character_id ~= player["boutique-id"] or livret.status ~= 'active' then return end
    if livret.livret_type == 'compte_terme' then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Un compte à terme ne peut recevoir qu\'un dépôt unique à l\'ouverture.', 'error')
        return
    end

    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    local account = LSLegacy.Bank.GetAccount(livret.linked_account_id)
    if not account or account.amountMoney < amount then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Solde insuffisant sur le compte lié.', 'error')
        return
    end

    local rateCfg = LSLegacy.Bank.InterestRates[livret.livret_type]
    if rateCfg and rateCfg.deposit_cap and (livret.amountMoney + amount) > rateCfg.deposit_cap then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Plafond de dépôt dépassé (max '..rateCfg.deposit_cap..'$).', 'error')
        return
    end

    livret.amountMoney = livret.amountMoney + amount
    table.insert(livret.transactions, { amount = amount, type = 'Dépôt', message = 'Dépôt sur livret', date = os.date('%d/%m/%Y %H:%M:%S') })
    MySQL.Async.execute('UPDATE bank_livrets SET amountMoney = @amountMoney, transactions = @transactions WHERE id = @id', {
        ['@id'] = livret.id,
        ['@amountMoney'] = livret.amountMoney,
        ['@transactions'] = json.encode(livret.transactions)
    })

    LSLegacy.Bank.AddTransaction(account, amount, 'Dépôt vers livret', 'Livret')
    LSLegacy.Bank.UpdateAccount(account, account.amountMoney - amount)

    Wait(150)
    LSLegacy.Bank.GetAllLivrets()
    Wait(150)
    LSLegacy.SendEventToClient('receiveBankLivrets', player.source, LSLegacy.Bank.GetPersonnalLivrets(player["boutique-id"]))
    LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Dépôt effectué avec succès.', 'success')
end)

-- montant net crédité + pénalité éventuelle (compte à terme retiré avant échéance)
local function ComputeLivretWithdrawal(livret, amount)
    local penalty = 0
    if livret.livret_type == 'compte_terme' then
        local maturityTs = ParseSqlDatetime(livret.maturity_date)
        if maturityTs and os.time() < maturityTs then
            local rateCfg = LSLegacy.Bank.InterestRates[livret.livret_type]
            local penaltyPercent = (rateCfg and rateCfg.early_withdrawal_penalty_percent) or 0
            penalty = amount * (penaltyPercent / 100)
        end
    end
    return amount - penalty, penalty
end

LSLegacy.RegisterServerEvent('BankWithdrawLivret', function(livretId, amount)
    local player = LSLegacy.GetPlayerFromId(source)
    local livret = LSLegacy.Bank.GetLivret(livretId)
    if not livret or livret.character_id ~= player["boutique-id"] or livret.status ~= 'active' then return end

    amount = tonumber(amount) or 0
    if amount <= 0 or amount > livret.amountMoney then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Montant invalide.', 'error')
        return
    end

    local account = LSLegacy.Bank.GetAccount(livret.linked_account_id)
    if not account then return end

    local netAmount, penalty = ComputeLivretWithdrawal(livret, amount)

    livret.amountMoney = livret.amountMoney - amount
    local message = penalty > 0 and ('Retrait anticipé (pénalité de '..math.floor(penalty)..'$)') or 'Retrait du livret'
    table.insert(livret.transactions, { amount = amount, type = 'Retrait', message = message, date = os.date('%d/%m/%Y %H:%M:%S') })
    MySQL.Async.execute('UPDATE bank_livrets SET amountMoney = @amountMoney, transactions = @transactions WHERE id = @id', {
        ['@id'] = livret.id,
        ['@amountMoney'] = livret.amountMoney,
        ['@transactions'] = json.encode(livret.transactions)
    })

    LSLegacy.Bank.AddTransaction(account, netAmount, message, 'Livret')
    LSLegacy.Bank.UpdateAccount(account, account.amountMoney + netAmount)

    Wait(150)
    LSLegacy.Bank.GetAllLivrets()
    Wait(150)
    LSLegacy.SendEventToClient('receiveBankLivrets', player.source, LSLegacy.Bank.GetPersonnalLivrets(player["boutique-id"]))
    if penalty > 0 then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Retrait anticipé : pénalité de '..math.floor(penalty)..'$ appliquée.', 'error')
    else
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Retrait effectué avec succès.', 'success')
    end
end)

LSLegacy.RegisterServerEvent('BankCloseLivret', function(livretId)
    local player = LSLegacy.GetPlayerFromId(source)
    local livret = LSLegacy.Bank.GetLivret(livretId)
    if not livret or livret.character_id ~= player["boutique-id"] or livret.status ~= 'active' then return end

    local account = LSLegacy.Bank.GetAccount(livret.linked_account_id)
    if not account then return end

    local amount = livret.amountMoney
    local netAmount, penalty = ComputeLivretWithdrawal(livret, amount)

    MySQL.Async.execute('UPDATE bank_livrets SET amountMoney = 0, status = @status, transactions = @transactions WHERE id = @id', {
        ['@id'] = livret.id,
        ['@status'] = 'closed',
        ['@transactions'] = json.encode((function()
            table.insert(livret.transactions, { amount = amount, type = 'Fermeture', message = penalty > 0 and ('Fermeture anticipée (pénalité de '..math.floor(penalty)..'$)') or 'Fermeture du livret', date = os.date('%d/%m/%Y %H:%M:%S') })
            return livret.transactions
        end)())
    })

    if netAmount > 0 then
        LSLegacy.Bank.AddTransaction(account, netAmount, 'Fermeture livret', 'Livret')
        LSLegacy.Bank.UpdateAccount(account, account.amountMoney + netAmount)
    end

    Wait(150)
    LSLegacy.Bank.GetAllLivrets()
    Wait(150)
    LSLegacy.SendEventToClient('receiveBankLivrets', player.source, LSLegacy.Bank.GetPersonnalLivrets(player["boutique-id"]))
    LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Livret fermé, '..math.floor(netAmount)..'$ reversés sur votre compte.', 'success')
end)

-- virements par IBAN

LSLegacy.RegisterServerEvent('BankTransferByIban', function(fromAccountId, toIban, amount, message)
    local player = LSLegacy.GetPlayerFromId(source)
    local fromAccount = LSLegacy.Bank.GetAccount(fromAccountId)
    if not fromAccount or fromAccount.character_id ~= player["boutique-id"] then return end

    amount = tonumber(amount) or 0
    if amount <= 0 then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Montant invalide.', 'error')
        return
    end

    local toAccount = nil
    for k, v in pairs(LSLegacy.Bank.BankAccounts) do
        if v.iban == toIban then
            toAccount = v
            break
        end
    end

    if not toAccount then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'IBAN introuvable.', 'error')
        return
    end
    if toAccount.id == fromAccount.id then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Vous ne pouvez pas virer un compte vers lui-même.', 'error')
        return
    end

    local tierCfg = LSLegacy.Bank.GetCardTierConfig(fromAccount.card_tier)

    local available = fromAccount.amountMoney + tierCfg.overdraft_limit
    if amount > available then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Solde insuffisant.', 'error')
        return
    end

    -- ne consommer le plafond que si le virement va effectivement avoir lieu
    local ok, remaining = LSLegacy.Bank.CheckAndConsumeCeiling(fromAccount, 'transfer', amount, tierCfg.transfer_ceiling, tierCfg.cost_period)
    if not ok then
        LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Plafond de virement atteint : il vous reste '..math.max(0, math.floor(remaining))..'$ sur '..tierCfg.transfer_ceiling..'$ sur la période en cours.', 'error')
        return
    end

    message = (message and message ~= '') and message or 'Virement'

    LSLegacy.Bank.AddTransaction(fromAccount, amount, 'Virement envoyé à '..toIban..' — '..message, 'Virement sortant')
    LSLegacy.Bank.UpdateAccount(fromAccount, fromAccount.amountMoney - amount)

    LSLegacy.Bank.AddTransaction(toAccount, amount, 'Virement reçu de '..fromAccount.iban..' ('..fromAccount.owner_name..') — '..message, 'Virement entrant')
    LSLegacy.Bank.UpdateAccount(toAccount, toAccount.amountMoney + amount)

    LSLegacy.SendEventToClient('notify', player.source, 'Maze Bank', 'Virement de '..amount..'$ envoyé.', 'success')

    local toSrc = GetSourceByCharacterIdForBank(toAccount.character_id)
    if toSrc then
        LSLegacy.SendEventToClient('receiveBankAccounts', toSrc, LSLegacy.Bank.BankAccounts)
        LSLegacy.SendEventToClient('notify', toSrc, 'Maze Bank', 'Vous avez reçu un virement de '..amount..'$.', 'success')
    end
end)

-- cycles serveur : intérêts des livrets + cotisation carte/agios, versement journalier composé sur le solde courant

LSLegacy.Bank.RunInterestPayout = function()
    local touchedCharacters = {}
    for id, livret in pairs(LSLegacy.Bank.Livrets) do
        if livret.status == 'active' and livret.amountMoney > 0 then
            local ratePercent
            if livret.livret_type == 'compte_terme' then
                -- taux garanti à l'ouverture : ne suit jamais le taux admin en direct
                ratePercent = livret.interest_rate_snapshot
            else
                local cfg = LSLegacy.Bank.InterestRates[livret.livret_type]
                ratePercent = cfg and cfg.rate_percent or 0
            end
            if ratePercent and ratePercent > 0 then
                local interest = livret.amountMoney * (ratePercent / 100)
                if interest > 0 then
                    livret.amountMoney = livret.amountMoney + interest
                    table.insert(livret.transactions, { amount = interest, type = 'Intérêts', message = 'Intérêts versés', date = os.date('%d/%m/%Y %H:%M:%S') })
                    MySQL.Async.execute('UPDATE bank_livrets SET amountMoney = @amountMoney, transactions = @transactions WHERE id = @id', {
                        ['@id'] = livret.id,
                        ['@amountMoney'] = livret.amountMoney,
                        ['@transactions'] = json.encode(livret.transactions)
                    })
                    touchedCharacters[livret.character_id] = true
                end
            end
        end
    end

    Wait(200)
    LSLegacy.Bank.GetAllLivrets()
    Wait(200)
    for characterId, _ in pairs(touchedCharacters) do
        local src = GetSourceByCharacterIdForBank(characterId)
        if src then
            LSLegacy.SendEventToClient('receiveBankLivrets', src, LSLegacy.Bank.GetPersonnalLivrets(characterId))
            LSLegacy.SendEventToClient('notify', src, 'Maze Bank', 'Des intérêts ont été versés sur vos livrets.', 'success')
        end
    end
end

LSLegacy.Bank.RunMaintenanceTick = function()
    local now = os.time()
    local touchedCharacters = {}

    for id, account in pairs(LSLegacy.Bank.BankAccounts) do
        local tierCfg = LSLegacy.Bank.GetCardTierConfig(account.card_tier)
        local changed = false

        -- Cotisation carte
        if tierCfg.cost_amount and tierCfg.cost_amount > 0 and account.next_billing_at then
            local billingTs = ParseSqlDatetime(account.next_billing_at)
            if billingTs and now >= billingTs then
                local available = account.amountMoney + tierCfg.overdraft_limit
                if available >= tierCfg.cost_amount then
                    account.amountMoney = account.amountMoney - tierCfg.cost_amount
                    table.insert(account.transactions, { amount = tierCfg.cost_amount, type = 'Cotisation', message = 'Cotisation carte '..account.card_tier, date = os.date('%d/%m/%Y %H:%M:%S') })
                    local days = tierCfg.cost_period == 'monthly' and 30 or 7
                    account.next_billing_at = FormatSqlDatetime(now + days * 86400)
                    MySQL.Async.execute('UPDATE bankaccounts SET amountMoney = @amountMoney, transactions = @transactions, next_billing_at = @next_billing_at WHERE id = @id', {
                        ['@id'] = account.id,
                        ['@amountMoney'] = account.amountMoney,
                        ['@transactions'] = json.encode(account.transactions),
                        ['@next_billing_at'] = account.next_billing_at
                    })
                else
                    account.card_tier = 'standard'
                    account.next_billing_at = nil
                    MySQL.Async.execute('UPDATE bankaccounts SET card_tier = @card_tier, next_billing_at = NULL WHERE id = @id', {
                        ['@id'] = account.id,
                        ['@card_tier'] = 'standard'
                    })
                    local src = GetSourceByCharacterIdForBank(account.character_id)
                    if src then
                        LSLegacy.SendEventToClient('notify', src, 'Maze Bank', 'Fonds insuffisants pour la cotisation : votre carte a été rétrogradée en Standard.', 'error')
                    end
                end
                changed = true
            end
        end

        -- Agios sur découvert
        if account.amountMoney < 0 and tierCfg.agios_rate_percent and tierCfg.agios_rate_percent > 0 then
            local agios = math.abs(account.amountMoney) * (tierCfg.agios_rate_percent / 100)
            if agios > 0 then
                account.amountMoney = account.amountMoney - agios
                table.insert(account.transactions, { amount = agios, type = 'Agios', message = 'Agios sur découvert', date = os.date('%d/%m/%Y %H:%M:%S') })
                MySQL.Async.execute('UPDATE bankaccounts SET amountMoney = @amountMoney, transactions = @transactions WHERE id = @id', {
                    ['@id'] = account.id,
                    ['@amountMoney'] = account.amountMoney,
                    ['@transactions'] = json.encode(account.transactions)
                })
                changed = true
            end
        end

        if changed then
            touchedCharacters[account.character_id] = true
        end
    end

    Wait(200)
    LSLegacy.Bank.GetAllAccounts()
    Wait(200)
    for characterId, _ in pairs(touchedCharacters) do
        local src = GetSourceByCharacterIdForBank(characterId)
        if src then
            LSLegacy.SendEventToClient('receiveBankAccounts', src, LSLegacy.Bank.BankAccounts)
        end
    end
end

-- millisecondes jusqu'à 8h prochain (heure serveur/OS du conteneur, actuellement UTC)
local function MsUntilNext8am()
    local now = os.time()
    local t = os.date('*t', now)
    local today8am = os.time({ year = t.year, month = t.month, day = t.day, hour = 8, min = 0, sec = 0 })
    local next8am = (now >= today8am) and (today8am + 86400) or today8am
    return (next8am - now) * 1000
end

Citizen.CreateThread(function()
    Wait(MsUntilNext8am())
    while true do
        LSLegacy.Bank.RunInterestPayout()
        Wait((Config.Bank and Config.Bank.InterestIntervalMs) or 86400000)
    end
end)

Citizen.CreateThread(function()
    Wait(15000)
    while true do
        Wait((Config.Bank and Config.Bank.MaintenanceIntervalMs) or 300000)
        LSLegacy.Bank.RunMaintenanceTick()
    end
end)

LSLegacy.RegisterUsableItem('carte', function(data)
    local _src = source
    local player = LSLegacy.GetPlayerFromId(source)
    LSLegacy.SendEventToClient('useCarteBank', player.source, data)
end)

-- Envoie uniquement le solde du compte courant à un joueur (pour lb-phone)
-- Utilise TriggerClientEvent direct, pas le système sécurisé LSLegacy
local function IsCourant(value)
    -- mysql-async peut retourner TINYINT(1) en booléen ou en entier selon la version
    return value == 1 or value == true
end

local function SendBalanceToClient(src, characterId)
    for _, account in pairs(LSLegacy.Bank.BankAccounts) do
        if account.character_id == characterId and IsCourant(account.courant) then
            TriggerClientEvent('lslegacy:phone:updateBalance', src, account.amountMoney)
            return
        end
    end
    TriggerClientEvent('lslegacy:phone:updateBalance', src, 0)
end

-- Trouve l'identifiant propriétaire d'un numéro de téléphone via phone_last_phone
local function GetOwnerIdentifierByPhone(phoneNumber, cb)
    MySQL.Async.fetchScalar(
        'SELECT `id` FROM phone_last_phone WHERE phone_number = @number',
        { ['@number'] = phoneNumber },
        cb
    )
end

-- Trouve le source d'un joueur connecté à partir de son character_id (le
-- personnage précis, pas juste le compte : plusieurs personnages du même
-- compte peuvent partager un identifier mais jamais un character_id)
local function GetSourceByCharacterId(characterId)
    if not characterId then return nil end
    for src, player in pairs(LSLegacy.ServerPlayers) do
        if player["boutique-id"] == characterId then
            return src
        end
    end
    return nil
end

-- Trouve le numéro de téléphone actif dans l'inventaire d'un joueur
local function GetPhoneNumberFromInventory(player)
    for _, item in pairs(player.inventory or {}) do
        if item.name == "phone" and item.data and item.data.lbPhoneNumber then
            return item.data.lbPhoneNumber
        end
    end
    return nil
end

-- Permet à lb-phone de demander son solde au chargement
LSLegacy.RegisterServerEvent("lslegacy:requestBankBalance", function()
    local src    = source
    local player = LSLegacy.GetPlayerFromId(src)
    if not player then return end

    local phoneNumber = GetPhoneNumberFromInventory(player)
    if not phoneNumber then
        TriggerClientEvent('lslegacy:phone:updateBalance', src, 0)
        return
    end

    GetOwnerIdentifierByPhone(phoneNumber, function(ownerIdentifier)
        if not ownerIdentifier then
            TriggerClientEvent('lslegacy:phone:updateBalance', src, 0)
            return
        end
        -- C'est toujours le personnage actuellement chargé (celui qui a
        -- demandé son propre solde) qui reçoit la réponse : pas besoin de
        -- résoudre ownerIdentifier vers un character_id, on connaît déjà
        -- le personnage exact via sa session (`player`).
        SendBalanceToClient(src, player["boutique-id"])
    end)
end)

-- Exports bank, utilisés par lb-phone

local function GetCompteCourant(characterId)
    if not characterId then return nil end
    for _, account in pairs(LSLegacy.Bank.BankAccounts) do
        if account.character_id == characterId and IsCourant(account.courant) then
            return account
        end
    end
    return nil
end

LSLegacy.Bank.GetCompteCourant = GetCompteCourant

-- Verse un salaire/gain de métier : sur le compte courant du personnage
-- (avec message de transaction dédié) s'il en a un, sinon en espèces.
-- `source` doit être celui du joueur qui gagne l'argent (appel synchrone
-- depuis son propre event handler) pour que AddTransaction/UpdateAccount
-- lui renvoient bien leur rafraîchissement.
LSLegacy.Bank.PaySalary = function(player, amount, message)
    if not player or amount <= 0 then return false end
    local account = GetCompteCourant(player["boutique-id"])
    if not account then
        LSLegacy.Money.AddPlayerMoney(player, amount)
        return false
    end
    LSLegacy.Bank.AddTransaction(account, amount, message, 'Salaire')
    LSLegacy.Bank.UpdateAccount(account, account.amountMoney + amount)
    return true
end

-- ─── Cœur crédit/débit compte courant, par character_id ──────────────────
-- Factorisé pour être appelé aussi bien par les exports `...ByIdentifier`
-- (lb-phone, qui ignore le multicharacter) que par `...ByCharacterId`
-- (menu admin, qui connaît déjà le personnage précis du joueur ciblé).
-- `message` optionnel : les exports `...ByIdentifier` (lb-phone) n'en
-- passent pas, d'où le libellé générique par défaut — mais l'opération
-- laisse maintenant toujours une trace dans l'historique du compte, ce qui
-- manquait totalement avant (crédit/débit silencieux, aucune transaction
-- consignée pour le virement par téléphone ni pour son destinataire).
local function AddCompteCourant(characterId, amount, message)
    if amount <= 0 or not characterId then return false end
    for k, account in pairs(LSLegacy.Bank.BankAccounts) do
        if account.character_id == characterId and IsCourant(account.courant) then
            account.amountMoney = account.amountMoney + amount
            table.insert(account.transactions, {
                amount = amount,
                type = 'Dépôt',
                message = message or 'Dépôt (téléphone)',
                date = os.date('%d/%m/%Y %H:%M:%S')
            })
            MySQL.Async.execute('UPDATE bankaccounts SET amountMoney = @amount, transactions = @transactions WHERE id = @id', {
                ['@amount']       = account.amountMoney,
                ['@transactions'] = json.encode(account.transactions),
                ['@id']           = account.id
            })
            local onlineSrc = GetSourceByCharacterId(characterId)
            if onlineSrc then
                SendBalanceToClient(onlineSrc, characterId)
                LSLegacy.SendEventToClient('receiveBankAccounts', onlineSrc, LSLegacy.Bank.BankAccounts)
            end
            return true
        end
    end
    return false
end

-- Débite le compte courant (false si aucun compte courant ou solde insuffisant)
local function RemoveCompteCourant(characterId, amount, message)
    if amount <= 0 or not characterId then return false end
    for k, account in pairs(LSLegacy.Bank.BankAccounts) do
        if account.character_id == characterId and IsCourant(account.courant) then
            if account.amountMoney < amount then return false end
            account.amountMoney = account.amountMoney - amount
            table.insert(account.transactions, {
                amount = amount,
                type = 'Retrait',
                message = message or 'Retrait (téléphone)',
                date = os.date('%d/%m/%Y %H:%M:%S')
            })
            MySQL.Async.execute('UPDATE bankaccounts SET amountMoney = @amount, transactions = @transactions WHERE id = @id', {
                ['@amount']       = account.amountMoney,
                ['@transactions'] = json.encode(account.transactions),
                ['@id']           = account.id
            })
            local onlineSrc = GetSourceByCharacterId(characterId)
            if onlineSrc then
                SendBalanceToClient(onlineSrc, characterId)
                LSLegacy.SendEventToClient('receiveBankAccounts', onlineSrc, LSLegacy.Bank.BankAccounts)
            end
            return true
        end
    end
    return false
end

-- Les exports `...ByIdentifier` sont consommés par lb-phone avec un
-- `identifier` brut (pas un character_id — lb-phone ignore le
-- multicharacter). On résout systématiquement vers le personnage précis via
-- LSLegacy.ResolveCharacterIdSync (personnage en ligne, sinon repli sur
-- son slot 1), même convention que le reste du Lot 2.

-- Solde du compte courant par identifier (utilisé par lb-phone via money.lua)
exports('getBankBalanceByIdentifier', function(identifier)
    local characterId = LSLegacy.ResolveCharacterIdSync(identifier)
    local account = GetCompteCourant(characterId)
    return account and account.amountMoney or 0
end)

-- Crédite le compte courant par identifier
-- Si le propriétaire est connecté, met aussi à jour son affichage wallet
exports('addBankMoneyByIdentifier', function(identifier, amount)
    return AddCompteCourant(LSLegacy.ResolveCharacterIdSync(identifier), amount)
end)

exports('removeBankMoneyByIdentifier', function(identifier, amount)
    return RemoveCompteCourant(LSLegacy.ResolveCharacterIdSync(identifier), amount)
end)

-- ─── Variantes par character_id (menu admin) ──────────────────────────────
-- Le joueur ciblé étant déjà en ligne et son personnage déjà connu (via
-- LSLegacy.ServerPlayers[target]["boutique-id"]), pas besoin de repasser par
-- la résolution identifier → character_id.
exports('getCompteCourantInfoByCharacterId', function(characterId)
    local account = GetCompteCourant(characterId)
    if not account then return { hasAccount = false, balance = 0 } end
    return { hasAccount = true, balance = account.amountMoney }
end)

exports('addBankMoneyByCharacterId', function(characterId, amount)
    return AddCompteCourant(characterId, amount)
end)

exports('removeBankMoneyByCharacterId', function(characterId, amount)
    return RemoveCompteCourant(characterId, amount)
end)

-- Crédite le compte courant hors-ligne par identifier. Le personnage ciblé
-- est celui en ligne au moment de l'appel s'il y en a un, sinon son slot 1
-- par convention (l'appelant — ex. script de paie — ne connaît qu'un
-- identifier de compte, jamais un personnage précis).
exports('addBankMoneyOffline', function(identifier, amount)
    if amount <= 0 then return false end
    amount = math.floor(amount + 0.5)
    local characterId = LSLegacy.ResolveCharacterIdSync(identifier)
    if not characterId then return false end
    local affected = MySQL.Sync.execute(
        'UPDATE bankaccounts SET amountMoney = amountMoney + @amount WHERE character_id = @characterId AND courant = 1',
        { ['@amount'] = amount, ['@characterId'] = characterId }
    )
    return (affected or 0) > 0
end)
