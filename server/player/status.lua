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
    local v = math.min(100, math.max(0, value))
    MadeInFrance.Status.GetStatuses(player).hunger = v
    MadeInFrance.SendEventToClient('UpdatePlayer', player.source, MadeInFrance.ServerPlayers[player.source])
end

---SetThirst
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.SetThirst = function(player, value)
    local v = math.min(100, math.max(0, value))
    MadeInFrance.Status.GetStatuses(player).thirst = v
    MadeInFrance.SendEventToClient('UpdatePlayer', player.source, MadeInFrance.ServerPlayers[player.source])
end

---SetStamina
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.SetStamina = function(player, value)
    local v = math.min(100, math.max(0, value))
    MadeInFrance.Status.GetStatuses(player).stamina = v
    MadeInFrance.SendEventToClient('UpdatePlayer', player.source, MadeInFrance.ServerPlayers[player.source])
end

---AddHunger
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.AddHunger = function(player, value)
    MadeInFrance.Status.SetHunger(player, MadeInFrance.Status.GetHunger(player) + value)
end

---AddThirst
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.AddThirst = function(player, value)
    MadeInFrance.Status.SetThirst(player, MadeInFrance.Status.GetThirst(player) + value)
end

---AddStamina
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.AddStamina = function(player, value)
    MadeInFrance.Status.SetStamina(player, MadeInFrance.Status.GetStamina(player) + value)
end

---RemoveHunger
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.RemoveHunger = function(player, value)
    MadeInFrance.Status.SetHunger(player, MadeInFrance.Status.GetHunger(player) - value)
end

---RemoveThirst
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.RemoveThirst = function(player, value)
    MadeInFrance.Status.SetThirst(player, MadeInFrance.Status.GetThirst(player) - value)
end

---RemoveStamina
---@type function
---@param player MadeInFrance.Player
---@param value number
MadeInFrance.Status.RemoveStamina = function(player, value)
    MadeInFrance.Status.SetStamina(player, MadeInFrance.Status.GetStamina(player) - value)
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