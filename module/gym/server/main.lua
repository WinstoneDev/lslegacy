-- Salle de sport : accès police (job) gratuit, accès public (abonnement
-- payant en BDD) — validation stricte avant d'autoriser le client à lancer
-- la boucle d'entraînement. Le gain d'XP réutilise lslegacy:skillsAddXP
-- tel quel (server/player/skills.lua), aucune modif du système existant.

LSLegacy.Security.RegisterRateLimit('gym:startTraining', 15)
LSLegacy.Security.RegisterRateLimit('gym:requestSubscription', 5)
LSLegacy.Security.RegisterRateLimit('gym:openLocker', 20)

local CFG = Config.Gym

local function GetPlayer(src) return LSLegacy.Players.Get(src) end

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS gym_subscriptions (
        character_id INT NOT NULL,
        expires_at   DATETIME NOT NULL,
        PRIMARY KEY (character_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

local function HasActiveSubscription(characterId, cb)
    MySQL.Async.fetchAll(
        'SELECT expires_at FROM gym_subscriptions WHERE character_id = @id AND expires_at > NOW() LIMIT 1',
        { ['@id'] = characterId },
        function(rows) cb(rows and rows[1] ~= nil) end
    )
end

-- ── Démarrage d'un entraînement ──────────────────────────────────────

LSLegacy.Events.Register('gym:startTraining', function(salle, index)
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    if salle ~= 'police' and salle ~= 'public' then return end
    index = tonumber(index)
    if not index then return end

    local salleCfg = (salle == 'police') and CFG.Police or CFG.Public
    local machine = salleCfg.Machines[index]
    if not machine or not CFG.MachineTypes[machine.type] then return end

    local function Authorize()
        LSLegacy.Events.SendToClient('gym:trainingAuthorized', src, machine.type, machine.coords, machine.heading)
    end

    local function Deny(reason)
        LSLegacy.Events.SendToClient('gym:trainingDenied', src, reason)
    end

    if salle == 'police' then
        if player.job == CFG.Police.Job then
            Authorize()
        else
            Deny("Réservé aux forces de l'ordre.")
        end
        return
    end

    -- salle publique : abonnement actif requis
    HasActiveSubscription(player["boutique-id"], function(active)
        if active then Authorize() else Deny('Abonnement salle de sport requis.') end
    end)
end)

-- ── Casier personnel (vestiaire homme) ───────────────────────────────
-- Un DataStore par identifiant, partagé par les 3 casiers physiques :
-- dépôt et retrait fonctionnent depuis n'importe lequel d'entre eux.

local prevGymGuard = LSLegacy.DataStoreGuard
LSLegacy.DataStoreGuard = function(src, name, action, item)
    if type(name) == "string" and name:sub(1, 11) == "gym_locker_" then
        local player = GetPlayer(src)
        if not player then return false end
        return name == 'gym_locker_' .. player.identifier
    end
    if prevGymGuard then return prevGymGuard(src, name, action, item) end
    return true
end

LSLegacy.Events.Register('gym:openLocker', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    local name = 'gym_locker_' .. player.identifier
    if not LSLegacy.DataStores[name] then
        LSLegacy.DataStore.RegisterDataStore(name, {
            inventory = {}, name = name, type = 'trunk',
            money = 0, dirty = 0, maxWeight = CFG.Lockers.maxWeight,
        })
    end
    LSLegacy.Events.SendToClient('lslegacy:updateDatastore', src, LSLegacy.DataStores)
    LSLegacy.Events.SendToClient('inventory:openContainer', src, name, 'Casier personnel', CFG.Lockers.maxWeight)
end)

-- ── Abonnement (salle publique) ──────────────────────────────────────

local PendingSubscriptions = {}

LSLegacy.Bank.RegisterPaymentResultHandler('gym_sub', function(token, success)
    local pending = PendingSubscriptions[token]
    if not pending then return end
    PendingSubscriptions[token] = nil
    if not success then
        LSLegacy.Events.SendToClient('gym:subscriptionResult', pending.src, { success = false, reason = 'Paiement annulé.' })
        return
    end

    local characterId = pending.characterId
    local days = CFG.Public.Subscription.DurationDays

    MySQL.Async.fetchAll(
        'SELECT expires_at FROM gym_subscriptions WHERE character_id = @id LIMIT 1',
        { ['@id'] = characterId },
        function(rows)
            -- Un abonnement encore actif est prolongé depuis sa date d'expiration ;
            -- sinon la nouvelle période démarre à partir de maintenant.
            local extendFrom = (rows and rows[1] and rows[1].expires_at) or nil
            local query = extendFrom
                and 'UPDATE gym_subscriptions SET expires_at = GREATEST(expires_at, NOW()) + INTERVAL @days DAY WHERE character_id = @id'
                or  'INSERT INTO gym_subscriptions (character_id, expires_at) VALUES (@id, NOW() + INTERVAL @days DAY)'

            MySQL.Async.execute(query, { ['@id'] = characterId, ['@days'] = days }, function()
                MySQL.Async.fetchAll(
                    'SELECT expires_at FROM gym_subscriptions WHERE character_id = @id LIMIT 1',
                    { ['@id'] = characterId },
                    function(result)
                        local expiresAt = result and result[1] and result[1].expires_at or '?'

                        local player = GetPlayer(pending.src)
                        if player then
                            -- Remplace l'ancienne carte (renouvellement) plutôt que d'en empiler une nouvelle.
                            -- Collecte avant suppression : RemoveItemInInventory fait un table.remove sur
                            -- player.inventory, muter la table pendant son propre parcours sauterait des entrées.
                            local oldCards = {}
                            for _, it in pairs(player.inventory or {}) do
                                if it.name == 'carte_gym' then oldCards[#oldCards + 1] = it end
                            end
                            for _, it in ipairs(oldCards) do
                                LSLegacy.Inventory.RemoveItemInInventory(player, 'carte_gym', it.count, it.label, it.uniqueId)
                            end

                            local ci = player.characterInfos
                            local ownerName = ci and (ci.Prenom .. ' ' .. ci.NDF) or '?'
                            if LSLegacy.Inventory.CanCarryItem(player, 'carte_gym', 1) then
                                LSLegacy.Inventory.AddItemInInventory(player, 'carte_gym', 1, ownerName, nil, {
                                    owner_name = ownerName,
                                    expiration_date = expiresAt,
                                })
                            end
                        end

                        LSLegacy.Events.SendToClient('gym:subscriptionResult', pending.src, { success = true, expiresAt = expiresAt })
                    end
                )
            end)
        end
    )
end)

LSLegacy.Events.Register('gym:requestSubscription', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    local token = ('gym_%d_%d'):format(src, math.random(100000, 999999))
    PendingSubscriptions[token] = { src = src, characterId = player["boutique-id"] }
    Citizen.SetTimeout(120000, function() PendingSubscriptions[token] = nil end)

    LSLegacy.Bank.OpenPaymentMenu(
        src,
        ('Abonnement salle de sport - %d jours'):format(CFG.Public.Subscription.DurationDays),
        CFG.Public.Subscription.Price,
        { meta = { type = 'gym_sub', refId = token } }
    )
end)
