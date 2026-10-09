-- Lanceur Cougar : munition chargée au choix (lacrymogène / fumigène) via
-- le menu contextuel de l'inventaire (clic droit sur l'arme), consommée à
-- raison d'un item par tir. Le tir natif est BLOQUÉ (contrôle Attack
-- désactivé) tant qu'aucune munition n'est chargée ou que le stock du type
-- choisi est épuisé — sans ça l'arme continue de tirer indéfiniment via son
-- propre ammo_lgcougar, sans rapport avec les grenades réellement en stock.
--
-- L'impact est approximé par un tir tendu (LSLegacy.NonLethal.AimImpactPoint,
-- cf. effects.lua) : la vraie trajectoire en arc du lanceur n'est pas
-- rejouée, seul le point d'impact estimé sert à poser la zone d'effet.

local CFG         = Config.NonLethal.Cougar
local COUGAR_HASH = GetHashKey(CFG.weapon)

-- Neutralise l'explosion native du tir (dégâts vanilla non plafonnés,
-- redondants avec la zone scriptée posée par TryFire ci-dessous).
CreateThread(function()
    SetWeaponDamageModifier(COUGAR_HASH, 0.001)
end)

local function CurrentAmmoType()
    for _, v in pairs(LSLegacy.PlayerData.inventory or {}) do
        if v.name == 'weapon_lgcougar' then
            return (v.data and v.data.cougarAmmo) or nil
        end
    end
    return nil
end

local function StockFor(ammoType)
    local def = CFG.AmmoTypes[ammoType]
    if not def then return 0 end
    local owned = 0
    for _, v in pairs(LSLegacy.PlayerData.inventory or {}) do
        if v.name == def.item then owned = owned + v.count end
    end
    return owned
end

local function TryFire()
    local ammoType = CurrentAmmoType()
    if not ammoType or StockFor(ammoType) <= 0 then
        LSLegacy.ShowNotification(nil, "Aucune munition chargée dans le Cougar (clic droit sur l'arme dans l'inventaire).", 'error')
        return
    end
    local impact = LSLegacy.NonLethal.AimImpactPoint(CFG.MaxRange)
    LSLegacy.Events.SendToServer('nonlethal:cougar:fire', {
        ammoType = ammoType,
        coords   = { x = impact.x, y = impact.y, z = impact.z },
    })
end

CreateThread(function()
    while true do
        local ped     = PlayerPedId()
        local holding = GetSelectedPedWeapon(ped) == COUGAR_HASH

        if holding then
            local ammoType = CurrentAmmoType()
            local hasStock = ammoType and StockFor(ammoType) > 0

            if not hasStock then
                -- Empêche le tir natif (illimité via ammo_lgcougar sinon,
                -- sans rapport avec les grenades réellement possédées).
                DisableControlAction(0, 24, true) -- Attack
            elseif IsControlJustPressed(0, 24) then
                TryFire()
            end
        end

        Wait(holding and 0 or 300)
    end
end)

LSLegacy.Events.Register('nonlethal:cougar:ammoDenied', function(msg)
    LSLegacy.ShowNotification(nil, msg or 'Plus de munitions pour le Cougar.', 'error')
end)

-- ── Menu contextuel inventaire : choix de la munition chargée ──

function OpenCougarAmmoMenu(item)
    local options = {}
    for key, def in pairs(CFG.AmmoTypes) do
        local owned = 0
        for _, v in pairs(LSLegacy.PlayerData.inventory or {}) do
            if v.name == def.item then owned = owned + v.count end
        end
        options[#options + 1] = {
            title       = def.label,
            description = 'En stock : ' .. owned,
            disabled    = owned <= 0,
            onSelect    = function()
                item.data = item.data or {}
                item.data.cougarAmmo = key
                LSLegacy.Events.SendToServer('nonlethal:cougar:setAmmoType', item.uniqueId, key)
                LSLegacy.ShowNotification(nil, 'Cougar chargé : ' .. def.label .. '.', 'success')
            end,
        }
    end

    lib.registerContext({ id = 'cougar_ammo_menu', title = 'Charger le Cougar', options = options })
    lib.showContext('cougar_ammo_menu')
end
