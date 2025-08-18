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

---SetHunger
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.SetHunger = function(player, value)
    MadeInFrance.Status.GetStatuses(player).hunger = value
end

---SetThirst
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.SetThirst = function(player, value)
    MadeInFrance.Status.GetStatuses(player).thirst = value
end

---SetStamina
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.SetStamina = function(player, value)
    MadeInFrance.Status.GetStatuses(player).stamina = value
end

---AddHunger
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.AddHunger = function(player, value)
    MadeInFrance.Status.GetStatuses(player).hunger = MadeInFrance.Status.GetHunger(player) + value
end

---AddThirst
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.AddThirst = function(player, value)
    MadeInFrance.Status.GetStatuses(player).thirst = MadeInFrance.Status.GetThirst(player) + value
end

---AddStamina
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.AddStamina = function(player, value)
    MadeInFrance.Status.GetStatuses(player).stamina = MadeInFrance.Status.GetStamina(player) + value
end

---RemoveHunger
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.RemoveHunger = function(player, value)
    MadeInFrance.Status.GetStatuses(player).hunger = MadeInFrance.Status.GetHunger(player) - value
end

---RemoveThirst
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.RemoveThirst = function(player, value)
    MadeInFrance.Status.GetStatuses(player).thirst = MadeInFrance.Status.GetThirst(player) - value
end

---RemoveStamina
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.RemoveStamina = function(player, value)
    MadeInFrance.Status.GetStatuses(player).stamina = MadeInFrance.Status.GetStamina(player) - value
end

CreateThread(function()
    while true do
        Wait(Config.Status.UpdateInterval * 1000)

        for _, player in pairs(MadeInFrance.ServerPlayers) do
            if player and player.status then
                MadeInFrance.Status.RemoveHunger(player, Config.Status.Hunger.Loss)
                MadeInFrance.Status.RemoveThirst(player, Config.Status.Thirst.Loss)
                MadeInFrance.Status.RemoveStamina(player, Config.Status.Stamina.Loss)
            end
        end
    end
end)