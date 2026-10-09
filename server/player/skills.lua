LSLegacy.Skills = {}

local SKILL_NAMES = {"endurance", "tir", "force", "furtivite", "pilotage", "conduite", "apnee"}

-- Crée la colonne skills si elle n'existe pas (migration douce)
CreateThread(function()
    Wait(3000)
    MySQL.Async.execute("ALTER TABLE `players` ADD COLUMN IF NOT EXISTS `skills` LONGTEXT NOT NULL DEFAULT '{}'", {})
end)

LSLegacy.Skills.GetLevel = function(xp)
    local level = 0
    for i, threshold in ipairs(Config.Skills.LevelThresholds) do
        if xp >= threshold then level = i else break end
    end
    return level
end

local MAX_XP = Config.Skills.LevelThresholds[Config.Skills.MaxLevel]

-- Suivi des gains par session (reset à la déco)
local sessionGains = {}

-- Envoyer les compétences complètes au client
LSLegacy.Events.Register("lslegacy:skillsRequestAll", function()
    local src = source
    local player = LSLegacy.ServerPlayers[src]
    if not player or not player.skills then return end
    LSLegacy.Events.SendToClient("lslegacy:skillsInit", src, player.skills)
end)

-- Gain d'XP validé serveur (1 XP par appel)
LSLegacy.Events.Register("lslegacy:skillsAddXP", function(skillName)
    local src = source
    local player = LSLegacy.ServerPlayers[src]
    if not player or not player.skills then return end

    local valid = false
    for _, n in ipairs(SKILL_NAMES) do if n == skillName then valid = true; break end end
    if not valid then return end

    local skill = player.skills[skillName]
    if not skill then
        skill = {xp = 0, lastActivity = 0}
        player.skills[skillName] = skill
    end

    local now = os.time()

    -- Anti-farm : cooldown entre deux gains
    if (now - (skill.lastActivity or 0)) < Config.Skills.ActivityInterval then return end

    -- Anti-farm : plafond par session
    if not sessionGains[src] then sessionGains[src] = {} end
    sessionGains[src][skillName] = (sessionGains[src][skillName] or 0) + 1
    if sessionGains[src][skillName] > Config.Skills.MaxSessionXP then return end

    local oldLevel = LSLegacy.Skills.GetLevel(skill.xp)
    skill.xp = math.min(skill.xp + 1, MAX_XP)
    skill.lastActivity = now
    local newLevel = LSLegacy.Skills.GetLevel(skill.xp)

    LSLegacy.Events.SendToClient("lslegacy:skillsUpdate", src, skillName, skill.xp, newLevel)

    if newLevel > oldLevel then
        LSLegacy.Events.SendToClient("lslegacy:skillsLevelUp", src, skillName, newLevel)
        Config.Development.Print(("[Skills] %s → %s niveau %d"):format(GetPlayerName(src), skillName, newLevel))
    end
end)

-- Decay horaire
CreateThread(function()
    Wait(Config.Skills.DecayCheckInterval * 1000)
    while true do
        local now = os.time()
        for _, player in pairs(LSLegacy.ServerPlayers) do
            if player and player.skills and player.source then
                for _, skillName in ipairs(SKILL_NAMES) do
                    local s = player.skills[skillName]
                    if s and s.xp > 0 then
                        local hoursInactive = (now - (s.lastActivity or 0)) / 3600
                        if hoursInactive >= Config.Skills.DecayThreshold then
                            local excessHours = hoursInactive - Config.Skills.DecayThreshold
                            local decay    = Config.Skills.DecayPerHour * excessHours
                            local oldLevel = LSLegacy.Skills.GetLevel(s.xp)
                            s.xp           = math.max(0, s.xp - decay)
                            -- Repousse la référence au seuil pile pour ne pas réappliquer
                            -- ce même écart (grandissant) au prochain tick de decay
                            s.lastActivity = now - (Config.Skills.DecayThreshold * 3600)
                            local newLevel = LSLegacy.Skills.GetLevel(s.xp)
                            LSLegacy.Events.SendToClient("lslegacy:skillsUpdate", player.source, skillName, s.xp, newLevel)
                            if newLevel < oldLevel then
                                LSLegacy.Events.SendToClient("lslegacy:skillsLevelDown", player.source, skillName, newLevel)
                            end
                        end
                    end
                end
            end
        end
        Wait(Config.Skills.DecayCheckInterval * 1000)
    end
end)

LSLegacy.Events.AddHandler("playerDropped", function()
    sessionGains[source] = nil
end)
