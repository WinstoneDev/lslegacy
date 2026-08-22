local isLimping     = false
local isKO          = false
local isComa        = false
local koEndTime     = 0
local lastHealth    = 200
local lastDmgWeapon     = 0
local lastDmgWeaponTime = 0
local lastDamageBone    = 0
local emsCallled    = false
local lastPainNotif = 0

local UNARMED_HASH  = GetHashKey("weapon_unarmed")
local TASER_HASH     = GetHashKey("weapon_stungun")

-- Catégories d'armes pour les messages contextuels
local MELEE_HASHES = {}
for _, n in ipairs({"weapon_knife","weapon_dagger","weapon_machete","weapon_switchblade",
    "weapon_bat","weapon_crowbar","weapon_golfclub","weapon_hammer",
    "weapon_hatchet","weapon_knuckle","weapon_nightstick","weapon_pipe_wrench"}) do
    MELEE_HASHES[GetHashKey(n)] = true
end

local EXPLOSION_HASHES = {}
for _, n in ipairs({"weapon_grenade","weapon_stickybomb","weapon_proxmine","weapon_molotov",
    "weapon_rpg","weapon_grenadelauncher","weapon_hominglauncher","weapon_explosion"}) do
    EXPLOSION_HASHES[GetHashKey(n)] = true
end

local VEHICLE_HASHES = {}
for _, n in ipairs({"weapon_rammed_by_car","weapon_run_over_by_car","weapon_fall","weapon_drowning"}) do
    VEHICLE_HASHES[GetHashKey(n)] = true
end

-- Os GTA V → zone du corps
local BONE_HEAD = { [31086]=true, [39317]=true, [36864]=true }
local BONE_ARM  = { [53675]=true, [54187]=true, [61163]=true, [61685]=true, [26610]=true, [57005]=true }
local BONE_LEG  = { [58271]=true, [51826]=true, [16335]=true, [16337]=true, [63931]=true, [35502]=true, [14201]=true, [52301]=true }

-- Os GTA V → membre gauche/droite pour la Health Inspection (SAMU).
-- ATTENTION : valeurs à VÉRIFIER EN JEU (coup contrôlé par membre + log du
-- bone reçu) avant de leur faire confiance — un conflit a été repéré entre
-- deux sources : 36864 est classé "tête" ci-dessus mais "mollet droit" dans
-- une table externe, donc R_Calf a été volontairement omis de BONE_LEG_R.
local BONE_ARM_L = { [45509]=true, [61163]=true } -- SKEL_L_UpperArm, SKEL_L_Forearm
local BONE_ARM_R = { [40269]=true, [28252]=true } -- SKEL_R_UpperArm, SKEL_R_Forearm
local BONE_LEG_L = { [58271]=true, [63931]=true, [14201]=true } -- SKEL_L_Thigh/Calf/Foot
local BONE_LEG_R = { [51826]=true, [52301]=true } -- SKEL_R_Thigh/Foot

local PAIN_MSGS = {
    unarmed = {
        light = {
            "Votre arcade sourcilière s'est ouvert, le sang vous coule dans les yeux.",
            "Vous sentez vos côtes endolories, chaque respiration tire.",
            "Votre lèvre explose, vous retenez un gémissement.",
            "Le coup vous a sonné, vos oreilles bourdonnent encore.",
        },
        heavy = {
            "Vous crachez du sang, une côte est certainement fêlée.",
            "Votre mâchoire vous élance tellement que vous avez du mal à parler.",
            "Vous voyez double, les coups à la tête commencent à avoir raison de vous.",
            "Vous respirez par à-coups, les coups ont sérieusement amoché votre torse.",
        },
    },
    melee = {
        light = {
            "Une entaille vous brûle à chaque mouvement, le tissu colle à la plaie.",
            "La lame vous a effleuré mais ça saigne, vous comprimez la blessure.",
            "Vous sentez une vive brûlure là où la lame vous a touché.",
        },
        heavy = {
            "Vous appuyez fort sur la plaie pour freiner l'hémorragie, vos mains sont poisseuses.",
            "La lame a mordu profond, chaque foulée rouvre la blessure.",
            "Vous serrez les dents, l'arme blanche a laissé une marque sérieuse.",
            "Le sang imprègne vos vêtements, la blessure par arme blanche est profonde.",
        },
    },
    firearm = {
        head = {
            "La balle a frôlé votre crâne, des vertiges intenses vous submergent.",
            "Vous avez du sang plein les yeux, l'impact près de la tête vous étourdit.",
            "Votre tête résonne comme une cloche, vous avez du mal à rester concentré.",
        },
        torso = {
            "La balle dans votre poitrine rend chaque inspiration douloureuse.",
            "Vous pressez votre abdomen des deux mains pour contenir le saignement.",
            "Le projectile dans le thorax vous comprime les poumons, vous cherchez votre souffle.",
            "La douleur dans le ventre irradie jusqu'au dos, vous vous pliez en deux.",
        },
        arm = {
            "Votre bras touché tremble incontrôlablement, vous avez du mal à tenir quoi que ce soit.",
            "La balle dans le bras vous irradie jusqu'à l'épaule, le membre est presque inutilisable.",
            "Vous serrez votre bras blessé contre vous, le sang traverse le tissu.",
        },
        leg = {
            "Votre jambe touchée vous lâche, vous devez lutter pour ne pas vous effondrer.",
            "La balle dans la cuisse vous brûle à chaque appui, vous boitez sévèrement.",
            "Votre genou ne vous porte plus correctement depuis que la balle vous a touché.",
        },
        generic = {
            light = {
                "La balle vous a touché, une brûlure vive irradie depuis la plaie.",
                "Vous comprimez votre blessure par balle, ça pulse sous vos doigts.",
            },
            heavy = {
                "Vous perdez du sang trop vite, la balle a touché quelque chose d'important.",
                "Chaque pas est une torture, la balle logée dans votre corps vous rappelle sa présence.",
                "Vous vous sentez faiblir, la blessure par balle est sérieuse.",
            },
        },
    },
    explosion = {
        "Vos oreilles sifflent, le souffle de l'explosion vous a désorienti.",
        "Des éclats vous ont transpercé en plusieurs endroits, la douleur est diffuse et intense.",
        "L'onde de choc vous a projeté, tout votre corps proteste à chaque mouvement.",
        "Vous saignez de multiples plaies, les éclats ont criblé votre peau.",
    },
    vehicle = {
        "L'impact du véhicule a été violent, vous sentez quelque chose de cassé.",
        "Le choc vous a secoué dans tous les sens, vos articulations vous font souffrir.",
        "Vous avez du mal à reprendre vos esprits après la collision.",
        "Votre corps a encaissé le choc de plein fouet, chaque os vous fait mal.",
    },
    generic = {
        light = {
            "Vous ressentez une douleur vive mais supportable.",
            "Vos blessures commencent à se faire sentir sérieusement.",
        },
        heavy = {
            "Vous avez du mal à tenir debout tellement la douleur est intense.",
            "Vous perdez du sang abondamment, vous vous sentez faiblir.",
            "Votre vue se brouille à cause de la souffrance, tenez bon.",
        },
    },
}

local function DrawCenteredText(text, x, y, scale, font, r, g, b, a)
    SetTextFont(font or 4)
    SetTextScale(0.0, scale or 0.5)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    SetTextCentre(true)
    SetTextDropShadow()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

local function startLimp(ped)
    if isLimping then return end
    isLimping = true
    RequestAnimSet("move_m@injured")
    local t = 0
    while not HasAnimSetLoaded("move_m@injured") and t < 20 do Wait(100); t = t + 1 end
    SetPedMovementClipset(ped, "move_m@injured", 0.3)
end

local function stopLimp(ped)
    if not isLimping then return end
    isLimping = false
    ResetPedMovementClipset(ped, 0.3)
end

local function updateSpeedModifier(health)
    if isKO or isComa then return end
    local ped            = PlayerPedId()
    local enduranceBonus = GetSkillLevel("endurance") / 20.0  -- 0 à 0.5

    if health < Config.Injury.LimpThreshold then
        -- Le clipset move_m@injured gère visuellement le ralentissement, pas besoin de MoveRateOverride
        SetPedMoveRateOverride(ped, 1.0)
        startLimp(ped)
    elseif health < Config.Injury.SlowThreshold then
        local severity = 1.0 - ((health - Config.Injury.LimpThreshold) / (Config.Injury.SlowThreshold - Config.Injury.LimpThreshold))
        local rate     = math.max(0.55, 1.0 - (severity * 0.4) + enduranceBonus)
        SetPedMoveRateOverride(ped, rate)
        stopLimp(ped)
    else
        SetPedMoveRateOverride(ped, 1.0)
        stopLimp(ped)
    end
end

local function getPainMsg(health)
    local isHeavy = health < 115
    local w       = lastDmgWeapon
    local b       = lastDamageBone

    if w == UNARMED_HASH then
        local pool = isHeavy and PAIN_MSGS.unarmed.heavy or PAIN_MSGS.unarmed.light
        return pool[math.random(#pool)]
    elseif MELEE_HASHES[w] then
        local pool = isHeavy and PAIN_MSGS.melee.heavy or PAIN_MSGS.melee.light
        return pool[math.random(#pool)]
    elseif VEHICLE_HASHES[w] then
        local pool = PAIN_MSGS.vehicle
        return pool[math.random(#pool)]
    elseif EXPLOSION_HASHES[w] then
        local pool = PAIN_MSGS.explosion
        return pool[math.random(#pool)]
    elseif w ~= 0 then
        -- Arme à feu : message spécifique selon la zone touchée
        local pool
        if BONE_HEAD[b] then
            pool = PAIN_MSGS.firearm.head
        elseif BONE_ARM[b] then
            pool = PAIN_MSGS.firearm.arm
        elseif BONE_LEG[b] then
            pool = PAIN_MSGS.firearm.leg
        else
            pool = isHeavy and PAIN_MSGS.firearm.generic.heavy or PAIN_MSGS.firearm.generic.light
            if not pool or #pool == 0 then pool = PAIN_MSGS.firearm.torso end
        end
        return pool[math.random(#pool)]
    else
        local pool = isHeavy and PAIN_MSGS.generic.heavy or PAIN_MSGS.generic.light
        return pool[math.random(#pool)]
    end
end

local function checkPainNotif(health)
    if isKO or isComa then return end
    local now = GetGameTimer()
    if health < Config.Injury.LimpThreshold and (now - lastPainNotif) > 45000 then
        lastPainNotif = now
        LSLegacy.ShowNotification("Douleur", getPainMsg(health), "error")
    end
end

-- Catégorie + zone de la blessure, utilisée par le SAMU/Pompiers pour proposer la trousse de soins adaptée.
local function getWoundCategory()
    local w = lastDmgWeapon
    local b = lastDamageBone

    if w == UNARMED_HASH then return 'unarmed', 'none' end
    if w == TASER_HASH then return 'taser', 'none' end
    if MELEE_HASHES[w] then return 'melee', 'none' end
    if VEHICLE_HASHES[w] then return 'vehicle', 'none' end
    if EXPLOSION_HASHES[w] then return 'explosion', 'none' end
    if w ~= 0 then
        if BONE_HEAD[b] then return 'firearm', 'head' end
        if BONE_ARM[b] then return 'firearm', 'arm' end
        if BONE_LEG[b] then return 'firearm', 'leg' end
        return 'firearm', 'torso'
    end
    return 'generic', 'none'
end

-- Membre du mannequin Health Inspection (SAMU) touché par le dernier coup —
-- indépendant de getWoundCategory()/syncWound() ci-dessus, qui gardent leur
-- rôle existant (messages de douleur, ancien système de trousse).
local function getWoundPart(bone)
    if BONE_HEAD[bone] then return 'head' end
    if BONE_ARM_L[bone] then return 'arm_l' end
    if BONE_ARM_R[bone] then return 'arm_r' end
    if BONE_LEG_L[bone] then return 'leg_l' end
    if BONE_LEG_R[bone] then return 'leg_r' end
    return 'body'
end

local lastWoundSync = 0
local function syncWound(force)
    local now = GetGameTimer()
    if not force and (now - lastWoundSync) < 8000 then return end
    lastWoundSync = now
    local category, zone = getWoundCategory()
    LSLegacy.Events.SendToServer("lslegacy:injurySyncWound", { category = category, zone = zone })
end

local function enterKO(ped)
    if isKO or isComa then return end
    isKO      = true
    koEndTime = GetGameTimer() + Config.Injury.KODuration * 1000
    syncWound(true)
    LSLegacy.Events.SendToServer("lslegacy:injuryEnterKO")
    stopLimp(ped)
    SetPedMoveRateOverride(ped, 1.0)
    SetPedToRagdoll(ped, Config.Injury.KODuration * 1000, Config.Injury.KODuration * 1000, 0, false, false, false)

    CreateThread(function()
        while isKO do
            Wait(0)
            local p = PlayerPedId()
            if GetEntityHealth(p) <= 100 then SetEntityHealth(p, 105) end

            -- Maintenir la ragdoll : si GTA relève le ped, on le remet au sol
            if not IsPedRagdoll(p) then
                SetPedToRagdoll(p, 2000, 2000, 0, false, false, false)
            end

            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 36, true)

            local remaining = math.max(0, (koEndTime - GetGameTimer()) / 1000)

            DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, 140)
            DrawRect(0.5, 0.008, 1.0, 0.016, 180, 0, 0, 210)
            DrawRect(0.5, 0.992, 1.0, 0.016, 180, 0, 0, 210)
            DrawCenteredText("~r~K.O.", 0.5, 0.38, 1.8, 4, 255, 50, 50, 240)
            DrawCenteredText("Vous récupérez dans ~y~" .. math.ceil(remaining) .. "s", 0.5, 0.52, 0.42, 4, 255, 255, 255, 200)

            local progress = remaining / Config.Injury.KODuration
            DrawRect(0.5, 0.60, 0.30, 0.011, 40, 40, 40, 180)
            if progress > 0 then
                DrawRect(0.5 - (0.30 * (1.0 - progress)) / 2.0, 0.60, 0.30 * progress, 0.011, 180, 0, 0, 220)
            end

            if remaining <= 0 then isKO = false end
        end

        local p = PlayerPedId()
        -- 25 % de HP (100 = mort, 200 = plein → 125 = 25%)
        SetEntityHealth(p, 125)
        SetPedCanRagdoll(p, false)
        ClearPedTasksImmediately(p)
        SetPedCanRagdoll(p, true)
        SetPedMoveRateOverride(p, 1.0)
        LSLegacy.Events.SendToServer("lslegacy:injuryExitKO")
    end)
end

-- Boucle d'affichage coma, partagée entre enterComa et resumeComa.
local function runComaScreen(totalSeconds)
    local endTime = GetGameTimer() + totalSeconds * 1000

    CreateThread(function()
        while isComa do
            Wait(0)
            local p = PlayerPedId()
            if GetEntityHealth(p) <= 100 then SetEntityHealth(p, 101) end

            -- Maintenir le patient au sol pendant toute la durée du coma :
            -- une ragdoll expire au bout de sa durée et le ped se relève,
            -- ce que les autres joueurs voyaient (patient "debout en coma").
            -- Même entretien que la boucle KO.
            if not IsPedRagdoll(p) then
                SetPedToRagdoll(p, 10000, 10000, 0, false, false, false)
            end

            local remaining = math.max(0, (endTime - GetGameTimer()) / 1000)
            local minutes   = math.floor(remaining / 60)
            local seconds   = math.floor(remaining % 60)

            DrawRect(0.5, 0.5,  1.0,  1.0,  0,  0,  0, 245)
            DrawRect(0.5, 0.0,  1.0,  0.05, 80, 0,  0, 150)
            DrawRect(0.5, 1.0,  1.0,  0.05, 80, 0,  0, 150)
            DrawRect(0.0, 0.5,  0.05, 1.0,  80, 0,  0, 150)
            DrawRect(1.0, 0.5,  0.05, 1.0,  80, 0,  0, 150)

            DrawCenteredText("C O M A", 0.5, 0.30, 1.5, 4, 220, 30, 30, 255)
            DrawCenteredText(string.format("%d:%02d", minutes, seconds), 0.5, 0.44, 1.1, 4, 255, 255, 255, 230)
            DrawCenteredText("Retour à l'hôpital dans", 0.5, 0.53, 0.37, 4, 170, 170, 170, 200)

            local progress = remaining / totalSeconds
            DrawRect(0.5, 0.60, 0.35, 0.010, 40, 40, 40, 180)
            if progress > 0 then
                DrawRect(0.5 - (0.35 * (1.0 - progress)) / 2.0, 0.60, 0.35 * progress, 0.010, 200, 30, 30, 220)
            end

            local emsText = emsCallled and "~g~Appel EMS envoyé" or "~w~[E] Appeler les EMS"
            DrawCenteredText(emsText, 0.5, 0.68, 0.37, 4, 220, 220, 220, 200)

            if remaining <= 0 then
                isComa = false
                LSLegacy.Events.SendToServer("lslegacy:injuryRespawn")
            end
        end

        -- Ne PAS dégeler/retirer l'invincibilité ici : le vrai téléport et la
        -- remontée de santé n'arrivent qu'après l'aller-retour serveur
        -- (lslegacy:clientRespawn plus bas), qui s'en charge une fois la
        -- téléportation et SetEntityHealth effectués. Sinon le joueur reste
        -- debout à 101 HP, vulnérable, pendant cette fenêtre — la moindre
        -- chute/ragdoll le refait retomber sous le seuil et relance le coma.
        LSLegacy.Events.SendToServer("lslegacy:injuryExitComa")
    end)
end

local function enterComa()
    if isComa then return end
    isComa     = true
    isKO       = false
    emsCallled = false
    local ped  = PlayerPedId()
    SetEntityInvincible(ped, true)
    SetPedMoveRateOverride(ped, 1.0)
    stopLimp(ped)
    syncWound(true)
    LSLegacy.Events.SendToServer("lslegacy:injuryEnterComa")
    -- Mettre explicitement au sol : on ne peut pas compter sur la ragdoll
    -- laissée par les dégâts (elle a pu se terminer, ou n'avoir jamais eu
    -- lieu sur un dégât non projetant). L'ancien code figeait la position
    -- 1,5 s plus tard sans vérifier la posture — un ped déjà relevé se
    -- retrouvait donc figé DEBOUT pendant tout le coma. La boucle
    -- runComaScreen entretient ensuite cette ragdoll.
    SetPedToRagdoll(ped, 10000, 10000, 0, false, false, false)
    runComaScreen(Config.Injury.ComaDuration)
end

-- Reprise du coma après reconnexion : le serveur envoie le temps restant.
LSLegacy.Events.Register("lslegacy:injuryResumeComa", function(remaining)
    if isComa then return end
    isComa     = true
    isKO       = false
    emsCallled = false
    local ped  = PlayerPedId()
    SetEntityInvincible(ped, true)
    SetPedMoveRateOverride(ped, 1.0)
    stopLimp(ped)
    -- Au sol plutôt que figé debout, cf. enterComa
    SetPedToRagdoll(ped, 10000, 10000, 0, false, false, false)
    -- enterComa déjà enregistré côté serveur avant la déco, on ne le renvoie pas
    runComaScreen(remaining)
end)

LSLegacy.Events.Register("lslegacy:injuryAdminRevive", function(health)
    isKO   = false
    isComa = false
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    SetEntityHealth(ped, health or 200)
    -- Reste au sol, figé quelques secondes (massage cardiaque encore visible/
    -- crédible), avant de se relever — au lieu de se remettre debout d'un coup.
    FreezeEntityPosition(ped, true)
    Citizen.SetTimeout(Config.SAMU.Actions.reviveGroundDuration or 2500, function()
        local p = PlayerPedId()
        FreezeEntityPosition(p, false)
        -- Couper la ragdoll du coma, sinon elle continue de courir et le
        -- patient reste au sol malgré TaskGetUp (même motif que la sortie de KO).
        SetPedCanRagdoll(p, false)
        ClearPedTasksImmediately(p)
        SetPedCanRagdoll(p, true)
        TaskGetUp(p) -- se relève avec une animation naturelle, pas un snap instantané
        SetPedMoveRateOverride(p, 1.0)
        stopLimp(p)
    end)
end)

LSLegacy.Events.Register("lslegacy:clientRespawn", function()
    isKO   = false
    isComa = false
    local ped    = PlayerPedId()
    local points = Config.Injury.RespawnCoords
    local coords = points[math.random(#points)]
    -- Rester figé/invincible jusqu'à la téléportation + santé restaurée
    -- (voir commentaire dans runComaScreen) : évite de retomber en coma
    -- pendant la fenêtre du fade-out.
    DoScreenFadeOut(500)
    Wait(600)
    if LSLegacy.Anticheat then LSLegacy.Anticheat.AllowTeleport() end
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    if coords.w then SetEntityHeading(ped, coords.w) end
    SetEntityHealth(ped, 125)
    SetPedArmour(ped, 0)
    -- Couper la ragdoll du coma : sans ça le joueur arrive à l'hôpital
    -- toujours au sol, immobilisé jusqu'à expiration de la ragdoll.
    SetPedCanRagdoll(ped, false)
    ClearPedTasksImmediately(ped)
    SetPedCanRagdoll(ped, true)
    SetPedMoveRateOverride(ped, 1.0)
    stopLimp(ped)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    DoScreenFadeIn(1200)
end)

Keys.Register("e", "callems_coma", "Appeler les EMS (état coma)", function()
    if not isComa or emsCallled then return end
    emsCallled = true
    LSLegacy.Events.SendToServer("lslegacy:injuryCallEMS")
    LSLegacy.ShowNotification("EMS", "Appel envoyé aux services médicaux d'urgence.", "info")
end)

-- Suivi de la dernière arme reçue, en fallback si GetPedCauseOfDeath échoue.
LSLegacy.Events.AddHandler("gameEventTriggered", function(name, args)
    if name ~= "CEventNetworkEntityDamage" then return end
    local victim = args[1]
    if victim ~= PlayerPedId() then return end

    -- args[5] est souvent 0 en PvP réseau, on fallback sur l'arme en main de l'attaquant
    local wHash = args[5] or 0
    if wHash == 0 then
        local attacker = args[2]
        if attacker and attacker ~= 0 and IsEntityAPed(attacker) then
            local _, atkWeapon = GetCurrentPedWeapon(attacker, true)
            wHash = atkWeapon or 0
        end
    end
    if wHash ~= 0 then
        lastDmgWeapon     = wHash
        lastDmgWeaponTime = GetGameTimer()
    end

    local _, bone = GetPedLastDamageBone(victim)
    if bone and bone ~= 0 then lastDamageBone = bone end

    -- Anti-mort-native (bis) : on ne peut pas attendre le prochain tick de la
    -- boucle Wait(0) plus bas, ce délai d'une frame suffit à laisser GTA
    -- déclencher son "wasted" natif avant qu'enterKO/enterComa n'ait la main
    -- (mort en un seul coup : rafale, explosion, chute). gameEventTriggered
    -- se déclenche au moment exact du coup, donc on intercepte ici.
    if isKO or isComa then return end
    if GetEntityHealth(victim) <= 100 then
        -- Remonter la vie AVANT d'appeler enterKO/enterComa : ces fonctions
        -- ne touchent pas la santé tout de suite (seule la boucle du thread
        -- qu'elles lancent le fait, une frame plus tard). Sur un gros burst
        -- de dégâts, le moteur peut avoir déjà marqué le ped mort en interne
        -- avant même que ce handler ne s'exécute — remonter la vie ici,
        -- synchrone, est le seul moyen de couper court avant que GTA ne
        -- lance sa propre séquence de mort/respawn natif (cause du corps
        -- orphelin/dupliqué observé en test).
        SetEntityHealth(victim, 101)
        if wHash == UNARMED_HASH then
            enterKO(victim)
        else
            enterComa()
        end
    end
end)

-- isKO/isComa n'existent que sur la machine de la victime ; on publie donc l'état
-- dans un statebag répliqué pour que le SAMU sache si son patient est inconscient.
-- Recopié en boucle plutôt qu'à chaque point d'entrée/sortie : il y a six endroits
-- qui remettent isKO/isComa à false, en oublier un laisserait un patient marqué
-- inconscient à vie.
CreateThread(function()
    local last = false
    while true do
        Wait(500)
        local state = (isComa and 'coma') or (isKO and 'ko') or false
        if state ~= last then
            last = state
            LocalPlayer.state:set('injury', state, true)
        end
    end
end)

-- Health Inspection (SAMU) : un envoi par frame faisait sauter la limite anti-spam
-- du serveur (samu:hiDamage = 40 events / 15 s, cf. server/function.lua) dès qu'une
-- source de dégâts continue entrait en jeu. On accumule donc les dégâts par
-- (membre, catégorie) et on les envoie groupés une fois par seconde.
local woundDamageBuffer = {}

local function queueWoundDamage(part, category, amount)
    if not part or not category or amount <= 0 then return end
    local key = part .. '|' .. category
    local entry = woundDamageBuffer[key]
    if entry then
        entry.amount = entry.amount + amount
    else
        woundDamageBuffer[key] = { part = part, category = category, amount = amount }
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        local batch, count = {}, 0
        for key, entry in pairs(woundDamageBuffer) do
            count = count + 1
            batch[count] = entry
            woundDamageBuffer[key] = nil
        end
        if count > 0 then
            LSLegacy.Events.SendToServer('samu:hiDamage', { batch = batch })
        end
    end
end)

-- Filet de sécurité : sur un burst de dégâts, le moteur peut tuer le ped avant que
-- le moindre code Lua n'ait la main, ce qui laisse un cadavre orphelin non networké
-- (invisible pour ox_target, donc inaccessible au SAMU) pendant que le joueur
-- réapparaît ailleurs sans son skin. On ne cherche donc plus à empêcher la mort,
-- on la rattrape : dès la frame où le ped est mort, NetworkResurrectLocalPlayer le
-- ressuscite sur place avant que le moteur ne déroule sa séquence "wasted".
local lastResurrect = 0

CreateThread(function()
    Wait(8000)
    while true do
        Wait(0)
        if LSLegacy.PlayerData and LSLegacy.PlayerData.name then
            local ped = PlayerPedId()
            -- Le verrou temporel est indispensable : IsEntityDead reste vrai
            -- pendant plusieurs frames après l'appel à la résurrection, donc
            -- sans lui cette boucle (Wait(0)) rappelait
            -- NetworkResurrectLocalPlayer des dizaines de fois d'affilée — et
            -- chaque appel laisse une copie du corps derrière lui, d'où les
            -- peds dupliqués vus au sol après une réanimation.
            if DoesEntityExist(ped) and IsEntityDead(ped)
               and (GetGameTimer() - lastResurrect) > 3000 then
                lastResurrect = GetGameTimer()
                local c       = GetEntityCoords(ped)
                local heading = GetEntityHeading(ped)

                -- Relever la cause AVANT la résurrection : elle réinitialise
                -- GetPedCauseOfDeath.
                local causeHash = GetPedCauseOfDeath(ped)
                if causeHash == 0 and (GetGameTimer() - lastDmgWeaponTime) < 4000 then
                    causeHash = lastDmgWeapon
                end

                if LSLegacy.Anticheat then LSLegacy.Anticheat.AllowTeleport() end
                NetworkResurrectLocalPlayer(c.x, c.y, c.z, heading, true, true, false)

                local p = PlayerPedId()
                SetEntityHealth(p, 101)
                lastHealth = 101
                -- Garder le joueur au sol : la résurrection remet le ped
                -- debout, ce qui trahirait le rattrapage. enterComa() gèle
                -- ensuite la position une fois la ragdoll posée.
                SetPedToRagdoll(p, 5000, 5000, 0, false, false, false)

                if not isKO and not isComa then
                    if causeHash == UNARMED_HASH then
                        enterKO(p)
                    else
                        enterComa()
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    Wait(8000)
    while true do
        Wait(0)
        if not LSLegacy.PlayerData or not LSLegacy.PlayerData.name then Wait(1000); goto skip end
        if isKO or isComa then goto skip end

        local ped = PlayerPedId()
        if not DoesEntityExist(ped) then Wait(500); goto skip end

        -- Anti-mort-native : sans ça, un headshot applique un multiplicateur
        -- de dégâts critiques qui peut faire passer la vie de >100 à ≤0 en un
        -- seul coup, avant même que cette boucle (Wait(0), donc à la frame
        -- suivante) ait la main pour planchonner la vie via enterKO/enterComa
        -- — le jeu déclenche alors sa propre mort/respawn natif, en dehors du
        -- système KO/coma (c'est ce qui provoque le ped dupliqué ailleurs).
        -- Réappliqué en boucle car un changement de skin peut réinitialiser
        -- ce flag sur le nouveau ped.
        SetPedSuffersCriticalHits(ped, false)

        -- Empêche GTA de spawn un pickup arme+chargeur au sol si le ped
        -- meurt nativement (chute, explosion, etc.) malgré les gardes-fous
        -- KO/coma ci-dessus. Même réapplication en boucle : reset au respawn/skin.
        SetPedDropsWeaponsWhenDead(ped, false)

        local health = GetEntityHealth(ped)

        updateSpeedModifier(health)
        checkPainNotif(health)
        if health < Config.Injury.SlowThreshold then syncWound() end

        if health <= 100 and lastHealth > 100 then
            local causeHash  = GetPedCauseOfDeath(ped)
            local weaponHash = causeHash
            if weaponHash == 0 then
                -- Fallback : n'utiliser lastDmgWeapon que s'il est récent (< 4s)
                -- Sinon défaut coma (chute, véhicule, dégât inconnu)
                if (GetGameTimer() - lastDmgWeaponTime) < 4000 then
                    weaponHash = lastDmgWeapon
                end
            end
            if weaponHash == UNARMED_HASH then
                enterKO(ped)
            else
                enterComa()
            end
        end

        -- Health Inspection (SAMU) : attribution du dégât constaté au membre
        -- touché. Chaque perte de vie réelle est comptabilisée, mais mise en
        -- tampon plutôt qu'envoyée immédiatement (cf. queueWoundDamage) —
        -- l'envoi par frame déconnectait le joueur pour spam d'events.
        if health < lastHealth then
            local category = getWoundCategory()
            local part = getWoundPart(lastDamageBone)
            queueWoundDamage(part, category, lastHealth - health)
        end

        lastHealth = health
        ::skip::
    end
end)
