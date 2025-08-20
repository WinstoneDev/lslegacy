---@class LSLegacy.Jobs
LSLegacy.Jobs = {}
LSLegacy.AvailableJobs = {}
LSLegacy.AvailableFactions = {}

---GetAvailableJobs
---@type function
---@return table
LSLegacy.Jobs.GetAvailableJobs = function()
    return LSLegacy.AvailableJobs
end

---GetAvailableFactions
---@type function
---@return table
LSLegacy.Jobs.GetAvailableFactions = function()
    return LSLegacy.AvailableFactions
end

---GetJobLabel
---@type function
---@param job string
---@return string
LSLegacy.Jobs.GetJobLabel = function(job)
    if LSLegacy.Jobs.DoesJobExist(job) then
        return LSLegacy.AvailableJobs[job].label
    end
    return 'Inconnu'
end

---GetFactionLabel
---@type function
---@param faction string
---@return string
LSLegacy.Jobs.GetFactionLabel = function(faction)
    if LSLegacy.Jobs.DoesFactionExist(faction) then
        return LSLegacy.AvailableFactions[faction].label
    end
    return 'Inconnu'
end

---GetJobGradeLabel
---@type function
---@param job string
---@param grade number
---@return string
LSLegacy.Jobs.GetJobGradeLabel = function(job, grade)
    if LSLegacy.Jobs.DoesJobExist(job) and LSLegacy.Jobs.DoesJobGradeExist(job, grade) then
        return LSLegacy.AvailableJobs[job].grades[grade].label
    end
    return 'Inconnu'
end

---GetFactionGradeLabel
---@type function
---@param faction string
---@param grade number
---@return string
LSLegacy.Jobs.GetFactionGradeLabel = function(faction, grade)
    if LSLegacy.Jobs.DoesFactionExist(faction) and LSLegacy.Jobs.DoesFactionGradeExist(faction, grade) then
        return LSLegacy.AvailableFactions[faction].grades[grade].label
    end
    return 'Inconnu'
end

---DoesJobExist
---@type function
---@param job string
---@return boolean
LSLegacy.Jobs.DoesJobExist = function(job)
    return LSLegacy.AvailableJobs[job] ~= nil
end

---DoesFactionExist
---@type function
---@param faction string
---@return boolean
LSLegacy.Jobs.DoesFactionExist = function(faction)
    return LSLegacy.AvailableFactions[faction] ~= nil
end

---DoesJobGradeExist
---@type function
---@param job string
---@param grade number
---@return boolean
LSLegacy.Jobs.DoesJobGradeExist = function(job, grade)
    if not LSLegacy.Jobs.DoesJobExist(job) then
        return false
    end
    return LSLegacy.AvailableJobs[job].grades[grade] ~= nil
end

---DoesFactionGradeExist
---@type function
---@param faction string
---@param grade number
---@return boolean
LSLegacy.Jobs.DoesFactionGradeExist = function(faction, grade)
    if not LSLegacy.Jobs.DoesFactionExist(faction) then
        return false
    end
    return LSLegacy.AvailableFactions[faction].grades[grade] ~= nil
end

---GetJob
---@type function
---@param player LSLegacy.Player
---@return string
LSLegacy.Jobs.GetJob = function(player)
    return player.job
end

---GetJobGrade
---@type function
---@param player LSLegacy.Player
---@return number
LSLegacy.Jobs.GetJobGrade = function(player)
    return player.job_grade
end

---GetFaction
---@type function
---@param player LSLegacy.Player
---@return string
LSLegacy.Jobs.GetFaction = function(player)
    return player.faction
end

---GetFactionGrade
---@type function
---@param player LSLegacy.Player
---@return number
LSLegacy.Jobs.GetFactionGrade = function(player)
    return player.faction_grade
end

---SetJob
---@type function
---@param player LSLegacy.Player
---@param job string
LSLegacy.Jobs.SetJob = function(player, job)
    player.job = job
    LSLegacy.SendEventToClient('UpdatePlayer', player.source, LSLegacy.ServerPlayers[player.source])
end

---SetJobGrade
---@type function
---@param player LSLegacy.Player
---@param grade number
LSLegacy.Jobs.SetJobGrade = function(player, grade)
    player.job_grade = grade
    LSLegacy.SendEventToClient('UpdatePlayer', player.source, LSLegacy.ServerPlayers[player.source])
end

---SetFaction
---@type function
---@param player LSLegacy.Player
---@param faction string
LSLegacy.Jobs.SetFaction = function(player, faction)
    player.faction = faction
    LSLegacy.SendEventToClient('UpdatePlayer', player.source, LSLegacy.ServerPlayers[player.source])
end

---SetFactionGrade
---@type function
---@param player LSLegacy.Player
---@param grade number
LSLegacy.Jobs.SetFactionGrade = function(player, grade)
    player.faction_grade = grade
    LSLegacy.SendEventToClient('UpdatePlayer', player.source, LSLegacy.ServerPlayers[player.source])
end

LSLegacy.RegisterServent('SetJob', function(job, grade)
    local _src = source
    local player = LSLegacy.GetPlayerFromId(_src)

    if LSLegacy.Jobs.DoesJobExist(job) and LSLegacy.Jobs.DoesJobGradeExist(job, grade) then
        LSLegacy.Jobs.SetJob(player, job)
        LSLegacy.Jobs.SetJobGrade(player, grade)
        LSLegacy.SendEventToClient('UpdatePlayer', _src, player)
        LSLegacy.SendEventToClient('notify', _src, nil, 'Votre métier a été mis à jour en '..LSLegacy.Jobs.GetJobLabel(job)..' - '..LSLegacy.Jobs.GetJobGradeLabel(job, grade)..'.', 'success')
    else
        LSLegacy.SendEventToClient('notify', _src, nil, 'Le métier ou le grade spécifié n\'existe pas.', 'error')
    end
end)

LSLegacy.RegisterServerEvent('SetFaction', function(faction, grade)
    local _src = source
    local player = LSLegacy.GetPlayerFromId(_src)

    if LSLegacy.Jobs.DoesFactionExist(faction) and LSLegacy.Jobs.DoesFactionGradeExist(faction, grade) then
        LSLegacy.Jobs.SetFaction(player, faction)
        LSLegacy.Jobs.SetFactionGrade(player, grade)
        LSLegacy.SendEventToClient('UpdatePlayer', _src, player)
        LSLegacy.SendEventToClient('notify', _src, nil, 'Votre faction a été mise à jour en '..LSLegacy.Jobs.GetFactionLabel(faction)..' - '..LSLegacy.Jobs.GetFactionGradeLabel(faction, grade)..'.', 'success')
    else
        LSLegacy.SendEventToClient('notify', _src, nil, 'La faction ou le grade spécifié n\'existe pas.', 'error')
    end
end)