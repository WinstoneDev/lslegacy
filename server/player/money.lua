---@class MadeInFrance.Money
MadeInFrance.Money = {}

---GetPlayerMoney
---@type function
---@param player table
---@return number
---@public
MadeInFrance.Money.GetPlayerMoney = function(player)
    if player ~= nil then
        return player.cash
    end
end

---GetPlayerDirtyMoney
---@type function
---@param player table
---@return number
---@public
MadeInFrance.Money.GetPlayerDirtyMoney = function(player)
    if player ~= nil then
        return player.dirty
    end
end

---SetPlayerMoney
---@type function
---@param player table
---@param amount number
---@return any
---@public
MadeInFrance.Money.SetPlayerMoney = function(player, amount)
    if player ~= nil then
        player.cash = amount
        MadeInFrance.SendEventToClient('UpdatePlayer', player.source, player)
    end
end

---AddPlayerMoney
---@type function
---@param player table
---@param amount number
---@return any
---@public
MadeInFrance.Money.AddPlayerMoney = function(player, amount)
    if player ~= nil then
        player.cash = player.cash + amount
        MadeInFrance.SendEventToClient('UpdatePlayer', player.source, player)
    end
end

---RemovePlayerMoney
---@type function
---@param player table
---@param amount number
---@return any
---@public
MadeInFrance.Money.RemovePlayerMoney = function(player, amount)
    if player ~= nil then
        if player.cash >= tonumber(amount) then
            player.cash = player.cash - amount
            MadeInFrance.SendEventToClient('UpdatePlayer', player.source, player)
        end
    end
end

---SetPlayerDirtyMoney
---@type function
---@param player table
---@param amount number
---@return any
---@public
MadeInFrance.Money.SetPlayerDirtyMoney = function(player, amount)
    if player ~= nil then
        player.dirty = amount
        MadeInFrance.SendEventToClient('UpdatePlayer', player.source, player)
    end
end

---AddPlayerDirtyMoney
---@type function
---@param player table
---@param amount number
---@return any
---@public
MadeInFrance.Money.AddPlayerDirtyMoney = function(player, amount)
    if player ~= nil then
        player.dirty = player.dirty + amount
        MadeInFrance.SendEventToClient('UpdatePlayer', player.source, player)
    end
end

---RemovePlayerDirtyMoney
---@type function
---@param player table
---@param amount number
---@return any
---@public
MadeInFrance.Money.RemovePlayerDirtyMoney = function(player, amount)
    if player ~= nil then
        if player.dirty >= tonumber(amount) then
            player.dirty = player.dirty - amount
            MadeInFrance.SendEventToClient('UpdatePlayer', player.source, player)
        end
    end
end