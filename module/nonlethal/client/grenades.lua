-- Grenade lacrymogène (weapon_bzgas) et grenade fumigène (weapon_smokegrenade)
-- lancées à la main : au lieu du nuage natif GTA (petit, sans dégâts), on
-- déclenche notre zone d'effet custom (cf. Config.NonLethal.Zones et
-- client/effects.lua) au point de chute estimé.
--
-- Détection au lancer (IsControlJustPressed) + délai simulant le temps de
-- vol, plutôt que sur l'event explosionEvent natif : son champ weaponHash
-- n'est pas garanti selon la build FiveM, ce qui empêchait toute zone de se
-- déclencher.

local BZGAS_HASH        = GetHashKey('WEAPON_BZGAS')
local SMOKEGRENADE_HASH = GetHashKey('WEAPON_SMOKEGRENADE')

-- Neutralise les dégâts natifs de ces deux armes (WEAPON_BZGAS inflige de
-- vrais dégâts vanilla, non plafonnés) : seuls les dégâts scriptés de la
-- zone (Config.NonLethal.Zones, cf. effects.lua) doivent s'appliquer,
-- identiquement pour tout le monde dans le nuage.
CreateThread(function()
    SetWeaponDamageModifier(BZGAS_HASH, 0.001)
    SetWeaponDamageModifier(SMOKEGRENADE_HASH, 0.001)
end)

local THROW_RANGE   = 15.0
local FLIGHT_DELAY  = 1200 -- ms, approxime le temps de vol avant impact

local function ThrowZone(kind)
    local impact = LSLegacy.NonLethal.AimImpactPoint(THROW_RANGE)
    SetTimeout(FLIGHT_DELAY, function()
        LSLegacy.NonLethal.RequestZone(kind, impact)
    end)
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local sel = GetSelectedPedWeapon(ped)

        if sel == BZGAS_HASH and IsControlJustPressed(0, 24) then
            ThrowZone('gaz')
        elseif sel == SMOKEGRENADE_HASH and IsControlJustPressed(0, 24) then
            ThrowZone('fumigene')
        end

        Wait(0)
    end
end)
