---@class MadeInFrance.Status
MadeInFrance.Status = {}

---GetStatuses
---@type function
---@param player MadeInFrance.Player
---@return table
MadeInFrance.Status.GetStatuses = function(player)
    return player.status
end

---GetHunger
---@type function
---@param player MadeInFrance.Player
---@return number
MadeInFrance.Status.GetHunger = function(player)
    return MadeInFrance.Status.GetStatuses(player).hunger
end

---GetThirst
---@type function
---@param player MadeInFrance.Player
---@return number
MadeInFrance.Status.GetThirst = function(player)
    return MadeInFrance.Status.GetStatuses(player).thirst
end

---GetStamina
---@type function
---@param player MadeInFrance.Player
---@return number
MadeInFrance.Status.GetStamina = function(player)
    return MadeInFrance.Status.GetStatuses(player).stamina
end