-- Munition d'entrainement (Sig, UMP9, HKg36, Benelli, Sako, Remington 870) :
-- dégâts neutralisés tant que l'arme équipée est chargée avec `ammo_training`
-- (data.ammoType, tracé par inventory/server/main.lua au rechargement),
-- effet visuel/sonore natif conservé, + réaction légère côté victime.
-- Le mode de rechargement (réelle/entrainement) se choisit via clic droit
-- sur l'arme dans l'inventaire (OpenTrainingAmmoMenu ci-dessous).

local CFG = Config.NonLethal.TrainingAmmo

local HASHES  = {}  -- weaponName -> hash
local HASH_SET = {} -- hash -> true (filtrage gameEventTriggered)
for _, w in ipairs(CFG.weapons) do
    local h = GetHashKey(w)
    HASHES[w] = h
    HASH_SET[h] = true
end

local function CurrentAmmoType(weaponName)
    for _, v in pairs(LSLegacy.PlayerData.inventory or {}) do
        if v.name == weaponName then
            return (v.data and v.data.ammoType) or 'live'
        end
    end
    return 'live'
end

-- Réapplique le modificateur de dégâts de l'arme tenue selon la munition
-- réellement chambrée (indépendant du mode choisi pour le rechargement).
CreateThread(function()
    while true do
        local weaponHash = GetSelectedPedWeapon(PlayerPedId())

        for name, hash in pairs(HASHES) do
            if hash == weaponHash then
                local trained = CurrentAmmoType(name) == 'training'
                SetWeaponDamageModifier(hash, trained and 0.001 or 1.0)
                break
            end
        end

        Wait(500)
    end
end)

-- PV suivis en continu (même principe que lbd.lua) pour mesurer le dégât
-- réellement encaissé sur un coup, et ne réagir que s'il est faible (signe
-- que le tireur avait bien la munition d'entrainement chargée).
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
    if not HASH_SET[wHash] then return end

    local newHealth = GetEntityHealth(victim)
    local dmg = trackedHealth - newHealth
    trackedHealth = newHealth

    if dmg > 0 and dmg < CFG.damageThreshold then
        SetPedToRagdoll(victim, CFG.ragdollMs, CFG.ragdollMs, 0, false, false, false)
    end
end)

-- ── Menu contextuel inventaire : choix du mode de rechargement ──

function OpenTrainingAmmoMenu(item)
    lib.registerContext({
        id = 'training_ammo_menu',
        title = 'Munition — ' .. (item.label or item.name),
        options = {
            {
                title = 'Munition réelle',
                description = 'Rechargement normal au prochain appui sur R.',
                onSelect = function()
                    item.data = item.data or {}
                    item.data.ammoMode = 'live'
                    LSLegacy.Events.SendToServer('nonlethal:training:setAmmoMode', item.name, item.uniqueId, 'live')
                    LSLegacy.ShowNotification(nil, 'Prochain rechargement : munition réelle.', 'success')
                end,
            },
            {
                title = "Munition d'entrainement",
                description = 'Dégâts neutralisés, effet visuel/sonore conservé.',
                onSelect = function()
                    item.data = item.data or {}
                    item.data.ammoMode = 'training'
                    LSLegacy.Events.SendToServer('nonlethal:training:setAmmoMode', item.name, item.uniqueId, 'training')
                    LSLegacy.ShowNotification(nil, "Prochain rechargement : munition d'entrainement.", 'success')
                end,
            },
        },
    })
    lib.showContext('training_ammo_menu')
end
