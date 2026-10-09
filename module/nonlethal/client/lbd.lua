-- LBD 40 : dégâts fixes (5 corps / 10 tête) au lieu des dégâts natifs de
-- l'arme, + réaction physique (déséquilibre bref sur le corps, chute plus
-- marquée + sprint/saut bloqués sur la tête).

local CFG      = Config.NonLethal.LBD
local LBD_HASH = GetHashKey(CFG.weapon)

-- Os tête, mêmes valeurs que client/player/injury.lua (BONE_HEAD).
local BONE_HEAD = { [31086] = true, [39317] = true }

-- Neutralise les dégâts natifs de l'arme : les dégâts réellement infligés
-- sont recalculés à la main dans le handler CEventNetworkEntityDamage
-- ci-dessous, sur la machine de la victime.
CreateThread(function()
    SetWeaponDamageModifier(LBD_HASH, 0.001)
end)

-- PV suivis à chaque frame (avant l'impact du tick courant), pour connaître
-- la vie exacte juste avant un coup de LBD malgré les dégâts natifs déjà
-- appliqués par le jeu au moment où l'event ci-dessous se déclenche.
local trackedHealth = GetEntityHealth(PlayerPedId())

CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            trackedHealth = GetEntityHealth(ped)
        end
    end
end)

local function StunHead()
    AnimpostfxPlay('DeathFailOut', 0, false)
    CreateThread(function()
        local until_ = GetGameTimer() + CFG.headStunMs
        while GetGameTimer() < until_ do
            Wait(0)
            DisableControlAction(0, 21, true) -- sprint
            DisableControlAction(0, 22, true) -- saut
        end
        AnimpostfxStop('DeathFailOut')
    end)
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local victim = args[1]
    if victim ~= PlayerPedId() then return end

    local wHash = args[5] or 0
    if wHash == 0 then
        local attacker = args[2]
        if attacker and attacker ~= 0 and IsEntityAPed(attacker) then
            local _, atkWeapon = GetCurrentPedWeapon(attacker, true)
            wHash = atkWeapon or 0
        end
    end
    if wHash ~= LBD_HASH then return end

    local _, bone = GetPedLastDamageBone(victim)
    local isHead  = bone and BONE_HEAD[bone]
    local dmg     = isHead and CFG.damageHead or CFG.damageBody

    local newHealth = math.max(101, trackedHealth - dmg)
    SetEntityHealth(victim, newHealth)
    trackedHealth = newHealth

    if isHead then
        SetPedToRagdoll(victim, CFG.headRagdollMs, CFG.headRagdollMs, 0, false, false, false)
        StunHead()
    else
        SetPedToRagdoll(victim, CFG.bodyRagdollMs, CFG.bodyRagdollMs, 0, false, false, false)
    end
end)
