-- Ajoute des crédits boutique à un joueur via la commande Tebex.
-- L'identifier utilisé est "license:xxxx" (CFX/Rockstar license).
--
-- Commandes Tebex à configurer :
--   addcredits {identifier} {amount}
--   logpurchase {username} {transaction} {price} {currency} {date} {time} {email} {packageId} {packagePrice} {packageExpiry} {identifier} {packageName}

local WEBHOOK_URL = GetConvar('lslegacy_webhook_boutique', '')
local SERVER_NAME = "LS Legacy"

-- Epoch UTC du dernier dimanche d'un mois donné, à `hourUtc` heure UTC pile (bascules d'heure d'été).
local function LastSundayUtcEpoch(year, month, hourUtc)
    -- Astuce : le "jour 0" du mois suivant = dernier jour du mois demandé
    local lastDayTs = os.time({ year = year, month = month + 1, day = 0, hour = 12, min = 0, sec = 0 })
    local lastDayInfo = os.date("!*t", lastDayTs)
    -- wday : 1 = dimanche ... 7 = samedi (convention Lua/C)
    local sundayDay = lastDayInfo.day - (lastDayInfo.wday - 1)

    return os.time({ year = year, month = month, day = sundayDay, hour = hourUtc, min = 0, sec = 0 })
end

-- Détermine si `utcTs` (epoch UTC) tombe pendant l'heure d'été européenne (CEST, UTC+2)
-- ou l'heure d'hiver (CET, UTC+1). Règle UE : bascule à 1h UTC le dernier dimanche de
-- mars, et à 1h UTC le dernier dimanche d'octobre.
local function ParisUtcOffsetHours(utcTs)
    local year = os.date("!*t", utcTs).year
    local dstStart = LastSundayUtcEpoch(year, 3, 1)
    local dstEnd = LastSundayUtcEpoch(year, 10, 1)

    if utcTs >= dstStart and utcTs < dstEnd then
        return 2 -- CEST (été)
    end
    return 1 -- CET (hiver)
end

-- Convertit {date}/{time} Tebex (UTC) vers l'heure française, car Tebex envoie toujours ces valeurs en UTC.
local function ToLocalTime(dateStr, timeStr)
    local d64, m64, y64 = tostring(dateStr):match("^(%d%d)/(%d%d)/(%d%d)$")

    local y, m, d, hh, mm, ss

    if d64 then
        -- Format réellement envoyé par Tebex : date "JJ/MM/AA", heure "HH:MM" (sans secondes)
        d, m, y = d64, m64, y64
        y = tonumber(y) + 2000
        hh, mm = tostring(timeStr):match("^(%d%d):(%d%d)$")
        ss = 0
    else
        -- Tolère aussi un format ISO "YYYY-MM-DD" / "HH:MM:SS", au cas où Tebex changerait de format
        y, m, d = tostring(dateStr):match("(%d%d%d%d)-(%d%d)-(%d%d)")
        local ihh, imm, iss = tostring(timeStr):match("(%d%d):(%d%d):(%d%d)")
        hh, mm, ss = ihh, imm, iss or 0
    end

    if not (y and m and d and hh and mm) then
        print(("[Tebex-Credits] ToLocalTime: format inattendu, heure UTC brute conservée (date=%q, time=%q)"):format(
            tostring(dateStr), tostring(timeStr)
        ))
        return dateStr, timeStr
    end

    local rawTs = os.time({
        year = tonumber(y), month = tonumber(m), day = tonumber(d),
        hour = tonumber(hh), min = tonumber(mm), sec = tonumber(ss) or 0
    })
    local ts = rawTs + (ParisUtcOffsetHours(rawTs) * 3600)

    return os.date("!%d/%m/%Y", ts), os.date("!%H:%M:%S", ts)
end

local function GetPlayerLicense(source)
    for _, v in ipairs(GetPlayerIdentifiers(source)) do
        if string.find(v, "license:") then
            return v
        end
    end
    return nil
end

-- Nombre de transactions conservées par personnage (évite une colonne JSON qui grossit indéfiniment).
local MAX_TRANSACTIONS_HISTORY = 200

-- Ajoute la transaction à l'historique JSON du personnage (players.`boutique-transactions`), via son `boutique-id`.
local function LogTransactionToCharacter(identifier, record)
    if not identifier then return end

    MySQL.Async.fetchAll([[
        SELECT `characterInfos` FROM `players` WHERE `boutique-id` = @boutiqueId
    ]], { ['@boutiqueId'] = identifier }, function(rows)
        local row = rows and rows[1]
        if not row then
            print(("[Tebex-Credits] Impossible de logguer la transaction : personnage introuvable pour boutique-id %s"):format(tostring(identifier)))
            return
        end

        local ok, characterInfos = pcall(json.decode, row.characterInfos or "{}")
        if not ok or type(characterInfos) ~= "table" then characterInfos = {} end

        record.characterName = ("%s %s"):format(characterInfos.Prenom or "Inconnu", characterInfos.NDF or "Inconnu")

        -- Insertion atomique côté SQL (JSON_ARRAY_INSERT) : deux achats de la même commande
        -- arrivent quasi simultanément, un aller-retour lecture-Lua-puis-écriture perdrait l'un
        -- des deux (chacun écrasant l'historique lu par l'autre avant sa propre écriture).
        MySQL.Async.execute([[
            UPDATE `players`
            SET `boutique-transactions` = JSON_ARRAY_INSERT(
                IF(JSON_VALID(`boutique-transactions`), `boutique-transactions`, '[]'),
                '$[0]',
                JSON_COMPACT(@record)
            )
            WHERE `boutique-id` = @boutiqueId
        ]], {
            ['@boutiqueId'] = identifier,
            ['@record']     = json.encode(record),
        }, function()
            -- Élagage best-effort de l'historique (pas critique si une course le retarde d'un cran)
            MySQL.Async.fetchScalar([[
                SELECT JSON_LENGTH(`boutique-transactions`) FROM `players` WHERE `boutique-id` = @boutiqueId
            ]], { ['@boutiqueId'] = identifier }, function(length)
                if not length or length <= MAX_TRANSACTIONS_HISTORY then return end

                local paths = {}
                for i = length - 1, MAX_TRANSACTIONS_HISTORY, -1 do
                    paths[#paths + 1] = ("'$[%d]'"):format(i)
                end

                MySQL.Async.execute(([[
                    UPDATE `players` SET `boutique-transactions` = JSON_REMOVE(`boutique-transactions`, %s)
                    WHERE `boutique-id` = @boutiqueId
                ]]):format(table.concat(paths, ", ")), { ['@boutiqueId'] = identifier })
            end)
        end)
    end)
end

local function SendDiscordEmbed(embed)
    PerformHttpRequest(WEBHOOK_URL, function(statusCode, text, headers)
        if statusCode ~= 200 and statusCode ~= 204 then
            print(("[Tebex-Credits] Webhook Discord erreur HTTP %d : %s"):format(statusCode, tostring(text)))
        end
    end, "POST", json.encode({ embeds = { embed } }), { ["Content-Type"] = "application/json" })
end

-- Ajoute des crédits en BDD, que le joueur soit en ligne ou hors ligne.
local function AddCredits(identifier, amount)
    if not identifier or not amount then return end
    amount = LSLegacy.Validate.PositiveInteger(amount)
    if not amount then return end

    MySQL.Async.execute([[
        UPDATE players SET `boutique-credits` = `boutique-credits` + @amount
        WHERE `boutique-id` = @boutiqueId
    ]], {
        ['@boutiqueId'] = identifier,
        ['@amount']     = amount
    }, function(rowsAffected)
        if rowsAffected > 0 then
            print(("[Tebex-Credits] +%d crédits ajoutés pour %s"):format(amount, identifier))
        else
            print(("[Tebex-Credits] ERREUR : impossible d'ajouter les crédits pour %s"):format(identifier))
        end
    end)
end

RegisterCommand("addcredits", function(source, args, rawCommand)
    if source ~= 0 then
        print("[Tebex-Credits] Commande réservée à la console/Tebex.")
        return
    end

    local identifier = args[1]
    local amount     = tonumber(args[2])

    if not identifier or not amount then
        print("[Tebex-Credits] Usage : addcredits <identifier> <amount>")
        return
    end

    AddCredits(identifier, amount)
end, true)

-- Log un achat Tebex sur Discord. Tebex command à configurer (tout sur une seule ligne) :
--   logpurchase {username} {transaction} {price} {currency} {date} {time} {email} {packageId} {packagePrice} {packageExpiry} {identifier} {packageName}
-- {packageName} est en dernier pour capturer les espaces éventuels.
RegisterCommand("logpurchase", function(source, args, rawCommand)
    if source ~= 0 then
        print("[Tebex-Credits] logpurchase réservée à la console/Tebex.")
        return
    end

    -- Parsing des arguments (packageName = tout ce qui reste après l'arg 12)
    local username      = args[1]  or "Inconnu"
    local transaction   = args[2]  or "N/A"
    local price         = args[3]  or "?"
    local currency      = args[4]  or "EUR"
    local date          = args[5]  or "?"
    local timeVal      = args[6]  or "?"
    local email         = args[7]  or "N/A"
    local packageId     = args[8]  or "?"
    local packagePrice  = args[9]  or "?"
    local packageExpiry = args[10] or "Permanent"
    local identifier    = args[11] or "N/A"

    -- Reconstituer packageName (peut contenir des espaces)
    local pkgParts = {}
    for i = 12, #args do
        pkgParts[#pkgParts + 1] = args[i]
    end
    local packageName = #pkgParts > 0 and table.concat(pkgParts, " ") or "N/A"

    date, timeVal = ToLocalTime(date, timeVal)

    print(("[Tebex-Credits] Achat logué : %s a acheté '%s' (%.2f %s)"):format(
        username, packageName, tonumber(price) or 0, currency
    ))

    -- Historique des transactions rattaché au personnage (players.`boutique-transactions`)
    LogTransactionToCharacter(identifier, {
        transaction   = transaction,
        packageId     = packageId,
        packageName   = packageName,
        price         = tonumber(price) or 0,
        currency      = currency,
        date          = date,
        time          = timeVal,
        discordUsername = username,
    })

    -- Construction de l'embed Discord
    local embed = {
        title       = "🛒  Nouvel achat Tebex — " .. SERVER_NAME,
        description = ("**%s** vient d'acheter un package sur la boutique !"):format(username),
        color       = 0x2ECC71,  -- vert émeraude
        thumbnail   = { url = "https://i.imgur.com/1Bl2OxI.png" }, -- icône boutique
        fields      = {
            {
                name   = "👤  Joueur",
                value  = ("`%s`"):format(username),
                inline = true
            },
            {
                name   = "📦  Package",
                value  = ("`%s` (ID : %s)"):format(packageName, packageId),
                inline = true
            },
            {
                name   = "💰  Montant payé",
                value  = ("**%s %s**"):format(price, currency),
                inline = true
            },
            {
                name   = "🏷️  Prix du package",
                value  = ("%s %s"):format(packagePrice, currency),
                inline = true
            },
            {
                name   = "⏳  Durée / Expiration",
                value  = packageExpiry,
                inline = true
            },
            {
                name   = "🧾  Transaction ID",
                value  = ("`%s`"):format(transaction),
                inline = true
            },
            {
                name   = "🔑  Identifier Boutique",
                value  = ("`%s`"):format(identifier),
                inline = false
            },
            {
                name   = "📧  Email",
                value  = ("`%s`"):format(email),
                inline = true
            },
            {
                name   = "📅  Date & Heure",
                value  = ("%s à %s"):format(date, timeVal),
                inline = true
            },
        },
        footer = {
            text     = SERVER_NAME .. " • Tebex",
            icon_url = "https://i.imgur.com/1Bl2OxI.png"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    SendDiscordEmbed(embed)
end, true)

-- /idboutique affiche au joueur son ID boutique (players.`boutique-id`, à renseigner dans
-- la variable {boutique-id} du checkout Tebex pour recevoir ses crédits).
LSLegacy.RegisterCommand('idboutique', 0, function(player, args, showError, rawCommand)
    local boutiqueId = player and player["boutique-id"]
    if not boutiqueId then
        showError("Impossible de récupérer votre ID boutique pour le moment.")
        return
    end

    showError(("Votre ID boutique est : %d"):format(boutiqueId))
end, {help = "Affiche votre ID boutique à utiliser sur la boutique Tebex"}, false)
