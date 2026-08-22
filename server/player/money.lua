---@class LSLegacy.Money
LSLegacy.Money = {}

---GetPlayerMoney
---@type function
---@param player table
---@return number
---@public
LSLegacy.Money.GetPlayerMoney = function(player)
    if player ~= nil then
        return player.cash
    end
end

---GetPlayerDirtyMoney
---@type function
---@param player table
---@return number
---@public
LSLegacy.Money.GetPlayerDirtyMoney = function(player)
    if player ~= nil then
        return player.dirty
    end
end

---SetPlayerMoney
---@type function
---@param player table
---@param amount number
---@return boolean
---@public
LSLegacy.Money.SetPlayerMoney = function(player, amount)
    if player == nil then return false end
    amount = LSLegacy.Validate.PositiveInteger(amount, {allowZero = true})
    if not amount then return false end
    player.cash = amount
    player:MarkDirty('money')
    LSLegacy.Events.SendToClient('UpdatePlayer', player.source, player)
    return true
end

---AddPlayerMoney
---@type function
---@param player table
---@param amount number
---@return boolean
---@public
LSLegacy.Money.AddPlayerMoney = function(player, amount)
    if player == nil then return false end
    amount = LSLegacy.Validate.PositiveInteger(amount)
    if not amount then return false end
    player.cash = player.cash + amount
    player:MarkDirty('money')
    LSLegacy.Events.SendToClient('UpdatePlayer', player.source, player)
    return true
end

---RemovePlayerMoney
---@type function
---@param player table
---@param amount number
---@return boolean
---@public
LSLegacy.Money.RemovePlayerMoney = function(player, amount)
    if player == nil then return false end
    amount = LSLegacy.Validate.PositiveInteger(amount)
    if not amount then return false end
    if player.cash < amount then return false end
    player.cash = player.cash - amount
    player:MarkDirty('money')
    LSLegacy.Events.SendToClient('UpdatePlayer', player.source, player)
    return true
end

---SetPlayerDirtyMoney
---@type function
---@param player table
---@param amount number
---@return boolean
---@public
LSLegacy.Money.SetPlayerDirtyMoney = function(player, amount)
    if player == nil then return false end
    amount = LSLegacy.Validate.PositiveInteger(amount, {allowZero = true})
    if not amount then return false end
    player.dirty = amount
    player:MarkDirty('money')
    LSLegacy.Events.SendToClient('UpdatePlayer', player.source, player)
    return true
end

---AddPlayerDirtyMoney
---@type function
---@param player table
---@param amount number
---@return boolean
---@public
LSLegacy.Money.AddPlayerDirtyMoney = function(player, amount)
    if player == nil then return false end
    amount = LSLegacy.Validate.PositiveInteger(amount)
    if not amount then return false end
    player.dirty = player.dirty + amount
    player:MarkDirty('money')
    LSLegacy.Events.SendToClient('UpdatePlayer', player.source, player)
    return true
end

---RemovePlayerDirtyMoney
---@type function
---@param player table
---@param amount number
---@return boolean
---@public
LSLegacy.Money.RemovePlayerDirtyMoney = function(player, amount)
    if player == nil then return false end
    amount = LSLegacy.Validate.PositiveInteger(amount)
    if not amount then return false end
    if player.dirty < amount then return false end
    player.dirty = player.dirty - amount
    player:MarkDirty('money')
    LSLegacy.Events.SendToClient('UpdatePlayer', player.source, player)
    return true
end

-- Débit unifié par SOURCE (cash ou banque). Utilisable en cross-ressource :
-- on ne passe qu'un `src` (nombre), jamais le table `player` (non sérialisable).
-- Renvoie true si le débit a réussi.
exports('chargePlayerBySource', function(src, method, amount)
    local player = LSLegacy.GetPlayerFromId(src)
    if not player then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    if method == 'bank' then
        return exports.lslegacy:removeBankMoneyByIdentifier(player.identifier, amount) and true or false
    else
        if (player.cash or 0) < amount then return false end
        LSLegacy.Money.RemovePlayerMoney(player, amount)
        return true
    end
end)