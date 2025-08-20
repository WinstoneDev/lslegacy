---@class LSLegacy.Status
LSLegacy.Status = {}

---GetStatuses
---@type function
---@param player LSLegacy.Player
---@return table
LSLegacy.Status.GetStatuses = function(player)
    return player.status
end

---GetHunger
---@type function
---@param player LSLegacy.Player
---@return number
LSLegacy.Status.GetHunger = function(player)
    return LSLegacy.Status.GetStatuses(player).hunger
end

---GetThirst
---@type function
---@param player LSLegacy.Player
---@return number
LSLegacy.Status.GetThirst = function(player)
    return LSLegacy.Status.GetStatuses(player).thirst
end

---GetStamina
---@type function
---@param player LSLegacy.Player
---@return number
LSLegacy.Status.GetStamina = function(player)
    return LSLegacy.Status.GetStatuses(player).stamina
end

---SetHunger
---@type function
---@param player LSLegacy.Player
---@param value number
LSLegacy.Status.SetHunger = function(player, value)
    local v = math.min(100, math.max(0, value))
    LSLegacy.Status.GetStatuses(player).hunger = v
    LSLegacy.SendEventToClient('UpdatePlayer', player.source, LSLegacy.ServerPlayers[player.source])
end

---SetThirst
---@type function
---@param player LSLegacy.Player
---@param value number
LSLegacy.Status.SetThirst = function(player, value)
    local v = math.min(100, math.max(0, value))
    LSLegacy.Status.GetStatuses(player).thirst = v
    LSLegacy.SendEventToClient('UpdatePlayer', player.source, LSLegacy.ServerPlayers[player.source])
end

---SetStamina
---@type function
---@param player LSLegacy.Player
---@param value number
LSLegacy.Status.SetStamina = function(player, value)
    local v = math.min(100, math.max(0, value))
    LSLegacy.Status.GetStatuses(player).stamina = v
    LSLegacy.SendEventToClient('UpdatePlayer', player.source, LSLegacy.ServerPlayers[player.source])
end

---AddHunger
---@type function
---@param player LSLegacy.Player
---@param value number
LSLegacy.Status.AddHunger = function(player, value)
    LSLegacy.Status.SetHunger(player, LSLegacy.Status.GetHunger(player) + value)
end

---AddThirst
---@type function
---@param player LSLegacy.Player
---@param value number
LSLegacy.Status.AddThirst = function(player, value)
    LSLegacy.Status.SetThirst(player, LSLegacy.Status.GetThirst(player) + value)
end

---AddStamina
---@type function
---@param player LSLegacy.Player
---@param value number
LSLegacy.Status.AddStamina = function(player, value)
    LSLegacy.Status.SetStamina(player, LSLegacy.Status.GetStamina(player) + value)
end

---RemoveHunger
---@type function
---@param player LSLegacy.Player
---@param value number
LSLegacy.Status.RemoveHunger = function(player, value)
    LSLegacy.Status.SetHunger(player, LSLegacy.Status.GetHunger(player) - value)
end

---RemoveThirst
---@type function
---@param player LSLegacy.Player
---@param value number
LSLegacy.Status.RemoveThirst = function(player, value)
    LSLegacy.Status.SetThirst(player, LSLegacy.Status.GetThirst(player) - value)
end

---RemoveStamina
---@type function
---@param player LSLegacy.Player
---@param value number
LSLegacy.Status.RemoveStamina = function(player, value)
    LSLegacy.Status.SetStamina(player, LSLegacy.Status.GetStamina(player) - value)
end

CreateThread(function()
    while true do
        Wait(Config.Status.UpdateInterval * 1000)

        for _, player in pairs(LSLegacy.ServerPlayers) do
            if player and player.status then
                LSLegacy.Status.RemoveHunger(player, Config.Status.Hunger.Loss)
                LSLegacy.Status.RemoveThirst(player, Config.Status.Thirst.Loss)
                LSLegacy.Status.RemoveStamina(player, Config.Status.Stamina.Loss)
            end
        end
    end
end)