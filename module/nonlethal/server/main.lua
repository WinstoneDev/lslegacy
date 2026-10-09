-- Armes non-létales : validation serveur des zones d'effet (gaz/fumée) et
-- de la consommation de munitions (Cougar, Gazeuse). Le client ne fait que
-- proposer une action, tout est revalidé ici avant diffusion/retrait d'item.

local function FindItemByUniqueId(player, name, uniqueId)
    for _, v in pairs(player.inventory) do
        if v.name == name and v.uniqueId == uniqueId then return v end
    end
    return nil
end

local ZONE_CFG = {
    gaz          = Config.NonLethal.Zones.gaz,
    fumigene     = Config.NonLethal.Zones.fumigene,
    gaz_gazeuse  = Config.NonLethal.Gazeuse,
}

local function BroadcastZone(kind, coords)
    local cfg = ZONE_CFG[kind]
    if not cfg then return end
    TriggerClientEvent('nonlethal:zoneSpawned', -1, {
        kind          = (kind == 'gaz_gazeuse') and 'gaz' or kind,
        coords        = coords,
        radius        = cfg.radius,
        duration      = cfg.duration,
        damagePerTick = cfg.damagePerTick,
        damageTickMs  = cfg.damageTickMs,
    })
end

-- Grenades lancées à la main + jet de la gazeuse.
LSLegacy.Events.Register('nonlethal:createZone', function(data)
    if type(data) ~= 'table' or not data.coords or not ZONE_CFG[data.kind] then return end
    BroadcastZone(data.kind, data.coords)
end)

-- Cougar — choix de la munition chargée.
LSLegacy.Events.Register('nonlethal:cougar:setAmmoType', function(uniqueId, ammoType)
    local src = source
    if not Config.NonLethal.Cougar.AmmoTypes[ammoType] then return end

    local player = GetPlayer(src)
    if not player then return end

    local weapon = FindItemByUniqueId(player, 'weapon_lgcougar', uniqueId)
    if not weapon then return end

    weapon.data = weapon.data or {}
    weapon.data.cougarAmmo = ammoType
    player:MarkDirty('inventory')
    LSLegacy.Events.SendToClient('lslegacy:updatePlayer', src, player)
end)

-- Cougar — tir : consomme 1 grenade du type chargé, puis pose la même zone
-- que si elle avait été lancée à la main.
LSLegacy.Events.Register('nonlethal:cougar:fire', function(data)
    local src = source
    if type(data) ~= 'table' or not data.coords then return end
    local def = Config.NonLethal.Cougar.AmmoTypes[data.ammoType]
    if not def then return end

    local player = GetPlayer(src)
    if not player then return end

    local owned = LSLegacy.Inventory.GetInventoryItem(player, def.item)
    if not owned or owned.count < 1 then
        LSLegacy.Events.SendToClient('nonlethal:cougar:ammoDenied', src, 'Plus de ' .. def.label .. ' pour le Cougar.')
        return
    end

    LSLegacy.Inventory.RemoveItemInInventory(player, def.item, 1)
    BroadcastZone(def.zone, data.coords)
end)

-- Munition d'entrainement — choix du mode de rechargement pour une des 6
-- armes concernées (clic droit sur l'arme dans l'inventaire). Le mode ne
-- fait que déterminer quel item est consommé au prochain rechargement (R) ;
-- le type réellement chambré (data.ammoType) est tracé séparément par
-- inventory/server/main.lua au moment du rechargement effectif.
local TRAINING_WEAPONS = {}
for _, w in ipairs(Config.NonLethal.TrainingAmmo.weapons) do TRAINING_WEAPONS[w] = true end

LSLegacy.Events.Register('nonlethal:training:setAmmoMode', function(weaponName, uniqueId, mode)
    local src = source
    if not TRAINING_WEAPONS[weaponName] then return end
    if mode ~= 'live' and mode ~= 'training' then return end

    local player = GetPlayer(src)
    if not player then return end

    local weapon = FindItemByUniqueId(player, weaponName, uniqueId)
    if not weapon then return end

    weapon.data = weapon.data or {}
    weapon.data.ammoMode = mode
    player:MarkDirty('inventory')
    LSLegacy.Events.SendToClient('lslegacy:updatePlayer', src, player)
end)

-- Gazeuse — décompte des charges non rechargeables (item.data.charges).
LSLegacy.Events.Register('nonlethal:gazeuse:consumeCharge', function(remaining)
    local src = source
    remaining = tonumber(remaining)
    if not remaining then return end
    remaining = math.max(0, math.min(Config.NonLethal.Gazeuse.maxCharges, remaining))

    local player = GetPlayer(src)
    if not player then return end

    for _, v in pairs(player.inventory) do
        if v.name == 'weapon_gazeuse' then
            v.data = v.data or {}
            v.data.charges = remaining
        end
    end
    player:MarkDirty('inventory')
end)
