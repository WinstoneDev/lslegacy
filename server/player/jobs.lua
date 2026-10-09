---@class LSLegacy.Jobs
LSLegacy.Jobs = {}
LSLegacy.AvailableJobs = {
    ['unemployed'] = {
        label = "Chômeur",
        grades = {
            [0] = {
                label = "Chômeur"
            }
        }
    },
    ['police'] = {
        label = "Police Nationale",
        grades = {
            [0] = { label = "Policier Adjoint" },
            [1] = { label = "Gardien de la Paix Stagiaire" },
            [2] = { label = "Gardien de la Paix" },
            [3] = { label = "Brigadier Chef" },
            [4] = { label = "Major" },
            [5] = { label = "Lieutenant" },
            [6] = { label = "Capitaine" },
            [7] = { label = "Commandant" },
            [8] = { label = "Commissaire" },
        }
    },
    ['sheriff'] = {
        label = "Blaine County Sheriff's Office",
        grades = {
            [0] = { label = "Explorer" },
            [1] = { label = "Deputy Trainee" },
            [2] = { label = "Deputy Sheriff I" },
            [3] = { label = "Deputy Sheriff II" },
            [4] = { label = "Corporal" },
            [5] = { label = "Sergeant" },
            [6] = { label = "Staff Sergeant" },
            [7] = { label = "Lieutenant" },
            [8] = { label = "Captain" },
            [9] = { label = "Commander" },
            [10] = { label = "Undersheriff" },
            [11] = { label = "Sheriff" },
        }
    },
    ['ems'] = {
        label = "Emergency Medical Services",
        grades = {
            [0] = { label = "Stagiaire EMS" },
            [1] = { label = "Auxiliaire Ambulancier" },
            [2] = { label = "Ambulancier" },
            [3] = { label = "Ambulancier Confirmé" },
            [4] = { label = "Infirmier" },
            [5] = { label = "Infirmier Anesthésiste" },
            [6] = { label = "Interne en Médecine" },
            [7] = { label = "Médecin" },
            [8] = { label = "Médecin Chef de Service" },
            [9] = { label = "Médecin Coordinateur EMS" },
        }
    },
    ['lsfd'] = {
        label = "LSFD - Los Santos Fire Department",
        grades = {
            [0] = { label = "Sapeur Stagiaire" },
            [1] = { label = "Sapeur" },
            [2] = { label = "Caporal" },
            [3] = { label = "Sergent" },
            [4] = { label = "Capitaine — Chef de Centre" },
        }
    },
    ['mechanic_reds'] = {
        label = "Red's Tunershop",
        grades = {
            [0] = { label = "Stagiaire" },
            [1] = { label = "Apprenti Mécanicien" },
            [2] = { label = "Mécanicien" },
            [3] = { label = "Mécanicien Confirmé" },
            [4] = { label = "Expert Mécanicien" },
            [5] = { label = "Chef d'Équipe" },
            [6] = { label = "Gérant" },
            [7] = { label = "Patron" },
        }
    },
    ['mechanic_bennys'] = {
        label = "Benny's Original Motor Works",
        grades = {
            [0] = { label = "Stagiaire" },
            [1] = { label = "Apprenti Mécanicien" },
            [2] = { label = "Mécanicien" },
            [3] = { label = "Mécanicien Confirmé" },
            [4] = { label = "Expert Mécanicien" },
            [5] = { label = "Chef d'Équipe" },
            [6] = { label = "Gérant" },
            [7] = { label = "Patron" },
        }
    },
    ['ltd'] = {
        label = "LTD",
        grades = {
            [0] = { label = "Stagiaire LTD" },
            [1] = { label = "Employé LTD" },
            [2] = { label = "Employé Confirmé" },
            [3] = { label = "Responsable de Magasin" },
        }
    },
    ['atc'] = {
        label = "Contrôleur aérien",
        grades = {
            [0] = { label = "Stagiaire" },
            [1] = { label = "Normal" },
            [2] = { label = "Divisionnaire" },
            [3] = { label = "En chef" },
        }
    }
}
LSLegacy.AvailableFactions = {
    ['unemployed'] = {
        label = "Aucune",
        grades = {
            [0] = {
                label = "Aucune"
            }
        }
    }
}

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
    player.job       = job
    player.job_label = LSLegacy.Jobs.GetJobLabel(job)
    player:MarkDirty('job')
    LSLegacy.Events.SendToClient('lslegacy:updatePlayer', player.source, LSLegacy.ServerPlayers[player.source])
end

---SetJobGrade
---@type function
---@param player LSLegacy.Player
---@param grade number
LSLegacy.Jobs.SetJobGrade = function(player, grade)
    local oldGrade = player.job_grade
    player.job_grade       = grade
    player.job_grade_label = LSLegacy.Jobs.GetJobGradeLabel(player.job, grade)
    player:MarkDirty('job_grade')
    LSLegacy.Events.SendToClient('lslegacy:updatePlayer', player.source, LSLegacy.ServerPlayers[player.source])
    -- Notifie les modules métier (ex. réaffectation d'unité MDT) sans les connaître.
    if oldGrade ~= grade then
        TriggerEvent('lslegacy:jobGradeChanged', player.source, player.job, oldGrade, grade)
    end
end

---SetFaction
---@type function
---@param player LSLegacy.Player
---@param faction string
LSLegacy.Jobs.SetFaction = function(player, faction)
    player.faction = faction
    player:MarkDirty('faction')
    LSLegacy.Events.SendToClient('lslegacy:updatePlayer', player.source, LSLegacy.ServerPlayers[player.source])
end

---SetFactionGrade
---@type function
---@param player LSLegacy.Player
---@param grade number
LSLegacy.Jobs.SetFactionGrade = function(player, grade)
    player.faction_grade = grade
    player:MarkDirty('faction_grade')
    LSLegacy.Events.SendToClient('lslegacy:updatePlayer', player.source, LSLegacy.ServerPlayers[player.source])
end

---Get / GetGrade — alias de confort de GetJob/GetJobGrade.
---@type function
LSLegacy.Jobs.Get = LSLegacy.Jobs.GetJob
LSLegacy.Jobs.GetGrade = LSLegacy.Jobs.GetJobGrade

---LSLegacy.Factions — même mécanique que les jobs (grade hiérarchique), API dédiée pour l'appelant.
LSLegacy.Factions = {
    GetAvailable = LSLegacy.Jobs.GetAvailableFactions,
    GetLabel = LSLegacy.Jobs.GetFactionLabel,
    GetGradeLabel = LSLegacy.Jobs.GetFactionGradeLabel,
    Exists = LSLegacy.Jobs.DoesFactionExist,
    GradeExists = LSLegacy.Jobs.DoesFactionGradeExist,
    Get = LSLegacy.Jobs.GetFaction,
    GetGrade = LSLegacy.Jobs.GetFactionGrade,
    Set = LSLegacy.Jobs.SetFaction,
    SetGrade = LSLegacy.Jobs.SetFactionGrade,
}

---Is / Require — vrai si le joueur a un des jobs attendus (et un grade
---suffisant). À utiliser à la place de `player.job == ...` /
---`player.job_grade >= ...` dispersés dans les modules.
---@type function
---@param player table
---@param jobs string|table
---@param minGrade number|nil
---@return boolean
---@public
LSLegacy.Jobs.Is = LSLegacy.Validate.Job
LSLegacy.Jobs.Require = LSLegacy.Validate.Job

LSLegacy.Events.Register('lslegacy:setJob', function(job, grade)
    local _src = source
    local player = LSLegacy.GetPlayerFromId(_src)

    if LSLegacy.Jobs.DoesJobExist(job) and LSLegacy.Jobs.DoesJobGradeExist(job, grade) then
        LSLegacy.Jobs.SetJob(player, job)
        LSLegacy.Jobs.SetJobGrade(player, grade)
        LSLegacy.Events.SendToClient('lslegacy:updatePlayer', _src, player)
        LSLegacy.Events.SendToClient('notify', _src, nil, 'Votre métier a été mis à jour en '..LSLegacy.Jobs.GetJobLabel(job)..' - '..LSLegacy.Jobs.GetJobGradeLabel(job, grade)..'.', 'success')
    else
        LSLegacy.Events.SendToClient('notify', _src, nil, 'Le métier ou le grade spécifié n\'existe pas.', 'error')
    end
end)

LSLegacy.Events.Register('lslegacy:setFaction', function(faction, grade)
    local _src = source
    local player = LSLegacy.GetPlayerFromId(_src)

    if LSLegacy.Jobs.DoesFactionExist(faction) and LSLegacy.Jobs.DoesFactionGradeExist(faction, grade) then
        LSLegacy.Jobs.SetFaction(player, faction)
        LSLegacy.Jobs.SetFactionGrade(player, grade)
        LSLegacy.Events.SendToClient('lslegacy:updatePlayer', _src, player)
        LSLegacy.Events.SendToClient('notify', _src, nil, 'Votre faction a été mise à jour en '..LSLegacy.Jobs.GetFactionLabel(faction)..' - '..LSLegacy.Jobs.GetFactionGradeLabel(faction, grade)..'.', 'success')
    else
        LSLegacy.Events.SendToClient('notify', _src, nil, 'La faction ou le grade spécifié n\'existe pas.', 'error')
    end
end)