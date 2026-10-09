-- Gazeuse : jet façon extincteur (courte portée), 100 charges non
-- rechargeables gravées sur l'item (item.data.charges), consommées tant que
-- le tir est maintenu. Une fois à 0, l'arme ne peut plus être utilisée :
-- elle doit être rapportée au chef de poste/armurier RAID (menu armurerie
-- existant, "Déposer" — bloqué côté serveur tant qu'il reste des charges,
-- cf. module/police/server/armory.lua).
--
-- Détection du jet via IsControlPressed(Attack) plutôt qu'IsPedShooting :
-- la gazeuse est une arme de groupe GROUP_FIREEXTINGUISHER (comme
-- l'extincteur vanilla), pour laquelle IsPedShooting ne se déclenche pas de
-- façon fiable — c'est ce qui empêchait toute zone d'apparaître.

local CFG          = Config.NonLethal.Gazeuse
local GAZEUSE_HASH = GetHashKey(CFG.weapon)
local SPRAY_RANGE  = 5.0

local function RemainingCharges()
    for _, v in pairs(LSLegacy.PlayerData.inventory or {}) do
        if v.name == 'weapon_gazeuse' then
            return (v.data and v.data.charges) or CFG.maxCharges
        end
    end
    return 0
end

local function SetLocalCharges(n)
    for _, v in pairs(LSLegacy.PlayerData.inventory or {}) do
        if v.name == 'weapon_gazeuse' then
            v.data = v.data or {}
            v.data.charges = n
            return
        end
    end
end

local ZONE_REFRESH_MS = 1000 -- une zone dure CFG.duration, pas besoin d'en redemander une à chaque tick de charge

CreateThread(function()
    local spraying   = false
    local lastCharge = 0
    local lastZone   = 0

    while true do
        local ped     = PlayerPedId()
        local holding = GetSelectedPedWeapon(ped) == GAZEUSE_HASH

        if holding and IsControlPressed(0, 24) then
            if RemainingCharges() <= 0 then
                DisableControlAction(0, 24, true) -- vide : bloque le jet natif
                if spraying then
                    spraying = false
                    LSLegacy.ShowNotification(nil, 'Gazeuse vide : ramenez-la au dépôt.', 'error')
                end
            else
                spraying = true
                local now = GetGameTimer()
                if (now - lastCharge) >= CFG.tickMs then
                    lastCharge = now
                    local remaining = math.max(0, RemainingCharges() - CFG.chargePerTick)
                    SetLocalCharges(remaining)
                    LSLegacy.Events.SendToServer('nonlethal:gazeuse:consumeCharge', remaining)
                end
                if (now - lastZone) >= ZONE_REFRESH_MS then
                    lastZone = now
                    LSLegacy.NonLethal.RequestZone('gaz_gazeuse', LSLegacy.NonLethal.AimImpactPoint(SPRAY_RANGE))
                end
            end
        else
            spraying = false
        end

        Wait(holding and 0 or 300)
    end
end)
