local SKILL_LABELS = {
    endurance  = "Endurance",
    tir        = "Tir",
    force      = "Force",
    furtivite  = "Furtivité",
    pilotage   = "Pilotage",
    conduite   = "Conduite",
    apnee      = "Apnée",
}

-- Stats GTA Online : le préfixe MP0_ est obligatoire, sans lui les barres et effets ne s'appliquent pas
local GTA_STAT_HASHES = {
    endurance  = "MP0_STAMINA",
    tir        = "MP0_SHOOTING_ABILITY",
    force      = "MP0_STRENGTH",
    furtivite  = "MP0_STEALTH_ABILITY",
    pilotage   = "MP0_FLYING_ABILITY",
    conduite   = "MP0_WHEELIE_ABILITY",
    apnee      = "MP0_LUNG_CAPACITY",
}

local UNARMED_HASH = GetHashKey("weapon_unarmed")
local skills       = {}

-- Applique les stats GTA selon le niveau (0-10 → stat 0-100)
local function applyGTAStats()
    for skillName, statHash in pairs(GTA_STAT_HASHES) do
        if skills[skillName] then
            StatSetInt(statHash, math.min((skills[skillName].level or 0) * 10, 100), true)
        end
    end
end

-- Effets gameplay par compétence ; appelé après chaque mise à jour et toutes les 30s (GTA reset ces valeurs)
local function applySkillEffects()
    local pid       = PlayerId()
    local tir       = skills.tir       and skills.tir.level       or 0
    local force     = skills.force     and skills.force.level     or 0
    local furtivite = skills.furtivite and skills.furtivite.level or 0
    local conduite  = skills.conduite  and skills.conduite.level  or 0

    -- Tir : jusqu'à +50% dégâts armes à feu (niveau 10 = ×1.5)
    SetPlayerWeaponDamageModifier(pid, 1.0 + tir * 0.05)

    -- Force : jusqu'à +100% dégâts mêlée (niveau 10 = ×2.0)
    SetPlayerMeleeWeaponDamageModifier(pid, 1.0 + force * 0.1)

    -- Furtivité : jusqu'à -70% bruit (niveau 10 = ×0.30)
    SetPlayerNoiseMultiplier(pid, math.max(0.3, 1.0 - furtivite * 0.07))

    -- Conduite : jusqu'à +20% résistance dégâts en véhicule (niveau 10 = ×1.20)
    SetPlayerVehicleDefenseModifier(pid, 1.0 + conduite * 0.02)
end

local function showLevelUpNotif(skillName, newLevel)
    local label = SKILL_LABELS[skillName] or skillName
    LSLegacy.ShowNotification("Compétence en hausse", label .. " est passé niveau " .. newLevel .. " !", "success")
end

local function showLevelDownNotif(skillName, newLevel)
    local label = SKILL_LABELS[skillName] or skillName
    LSLegacy.ShowNotification("Compétence en baisse", label .. " est repassé niveau " .. newLevel .. ".", "warning")
end

LSLegacy.Events.Register("lslegacy:skills:init", function(data)
    for k, v in pairs(data) do
        local xp = v.xp or 0
        -- Calcul local du niveau (pas besoin du serveur ici)
        local level = 0
        for i, threshold in ipairs(Config.Skills.LevelThresholds) do
            if xp >= threshold then level = i else break end
        end
        skills[k] = {xp = xp, level = level}
    end
    applyGTAStats()
    applySkillEffects()
end)

LSLegacy.Events.Register("lslegacy:skills:update", function(skillName, xp, level)
    if not skills[skillName] then skills[skillName] = {} end
    skills[skillName].xp    = xp
    skills[skillName].level = level
    applyGTAStats()
    applySkillEffects()
end)

LSLegacy.Events.Register("lslegacy:skills:levelUp", function(skillName, newLevel)
    showLevelUpNotif(skillName, newLevel)
end)

LSLegacy.Events.Register("lslegacy:skills:levelDown", function(skillName, newLevel)
    showLevelDownNotif(skillName, newLevel)
end)

-- Demander les compétences dès que le joueur est initialisé
LSLegacy.Events.AddHandler("InitPlayer", function()
    Wait(4000)
    LSLegacy.Events.SendToServer("lslegacy:skills:requestAll")
end)

-- Expose le niveau d'une compétence aux autres systèmes (injury, etc.)
function GetSkillLevel(skillName)
    return skills[skillName] and skills[skillName].level or 0
end

-- Refresh des stats GTA toutes les 30s (GTA peut les reset après spawn/changement de ped)
CreateThread(function()
    Wait(15000)
    while true do
        applyGTAStats()
        applySkillEffects()
        Wait(30000)
    end
end)

CreateThread(function()
    Wait(12000)
    while true do
        Wait(5000)
        if not LSLegacy.PlayerData or not LSLegacy.PlayerData.name then goto skip end

        local ped = PlayerPedId()
        if not DoesEntityExist(ped) or IsEntityDead(ped) then goto skip end

        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            -- Uniquement si le joueur est le conducteur (siège -1)
            if GetPedInVehicleSeat(vehicle, -1) == ped then
                local vClass = GetVehicleClass(vehicle)
                local speed  = GetEntitySpeed(vehicle)   -- m/s
                if (vClass == 15 or vClass == 16) and speed > 10.0 then
                    LSLegacy.Events.SendToServer("lslegacy:skills:addXP", "pilotage")
                elseif vClass ~= 15 and vClass ~= 16 and speed > 5.0 then
                    LSLegacy.Events.SendToServer("lslegacy:skills:addXP", "conduite")
                end
            end
        else
            if IsPedSwimmingUnderWater(ped) then
                LSLegacy.Events.SendToServer("lslegacy:skills:addXP", "apnee")
            end
            if IsPedSprinting(ped) or IsPedRunning(ped) then
                LSLegacy.Events.SendToServer("lslegacy:skills:addXP", "endurance")
            end
            if IsPedShooting(ped) then
                LSLegacy.Events.SendToServer("lslegacy:skills:addXP", "tir")
            end
            local _, weaponHash = GetCurrentPedWeapon(ped, true)
            if weaponHash == UNARMED_HASH and IsPedInMeleeCombat(ped) then
                LSLegacy.Events.SendToServer("lslegacy:skills:addXP", "force")
            end
            if GetPedStealthMovement(ped) and GetEntitySpeed(ped) > 0.5 then
                LSLegacy.Events.SendToServer("lslegacy:skills:addXP", "furtivite")
            end
        end

        ::skip::
    end
end)
