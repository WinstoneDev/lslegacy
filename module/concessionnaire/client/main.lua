-- ═══════════════════════════════════════════════════════════════════
--  CONCESSIONNAIRE — Client principal
--  PNJ vendeur + catalogue (ox_lib) + prévisualisation véhicule
--  Chargé dans le contexte lslegacy (globals Config / LSLegacy / lib)
-- ═══════════════════════════════════════════════════════════════════

Concessionnaire = Concessionnaire or {}

local spawnedPeds = {}

local function Notify(msg, type)
    TriggerEvent('notify', 'Concessionnaire', msg, type or 'info', 5000)
end
Concessionnaire.Notify = Notify

-- ── PNJ + ciblage ox_target ──────────────────────────────────────────
--  Le catalogue / les occasions / la revente sont définis dans
--  client/showroom.lua (exposés via la table globale Concessionnaire).

local function SpawnPed(cfg, options)
    if not cfg then return end
    local hash = GetHashKey(cfg.model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then return end

    local ped = CreatePed(4, hash, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.heading, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(hash)

    spawnedPeds[#spawnedPeds + 1] = ped
    exports.ox_target:addLocalEntity(ped, options)
    return ped
end

-- PNJ vendeur principal : catalogue + occasions
local function SpawnSellers()
    local buyOptions = {
        {
            name = 'concess_browse',
            icon = 'fa-solid fa-car-side',
            label = Lang.Concessionnaire.browse_catalog,
            distance = 2.5,
            onSelect = function() Concessionnaire.OpenCatalog() end,
        },
    }
    if Config.Concessionnaire.Occasion.enabled then
        buyOptions[#buyOptions + 1] = {
            name = 'concess_occasions',
            icon = 'fa-solid fa-car-side',
            label = Lang.Concessionnaire.occasion_option,
            distance = 2.5,
            onSelect = function() Concessionnaire.OpenOccasions() end,
        }
    end
    SpawnPed(Config.Concessionnaire.Seller, buyOptions)

    -- PNJ dédié à la revente
    if Config.Concessionnaire.Resale.enabled and Config.Concessionnaire.ResaleSeller then
        SpawnPed(Config.Concessionnaire.ResaleSeller, {
            {
                name = 'concess_resale',
                icon = 'fa-solid fa-hand-holding-dollar',
                label = Lang.Concessionnaire.resale_option,
                distance = 3.5,
                onSelect = function() Concessionnaire.OpenResale() end,
            },
        })
    end
end

-- ── Blip ─────────────────────────────────────────────────────────────

local function CreateBlip()
    local b = Config.Concessionnaire.Blip
    local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
    SetBlipSprite(blip, b.sprite)
    SetBlipColour(blip, b.color)
    SetBlipScale(blip, b.scale)
    SetBlipAsShortRange(blip, b.short)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(b.label)
    EndTextCommandSetBlipName(blip)
end

-- ── Anti-trafic PNJ — UNIQUEMENT à l'intérieur du bâtiment ───────────
-- Retire les véhicules ambiants présents dans la box du showroom, sans
-- toucher au trafic de la rue. Épargne : véhicules "mission" (aperçu),
-- véhicules occupés par un joueur.

local function GetTrafficBox()
    local z    = Config.Concessionnaire.NoTraffic
    local half = z.size / 2.0
    return z.center - half, z.center + half
end

local function DisableShowroomRoads()
    local mn, mx = GetTrafficBox()
    SetRoadsInArea(mn.x, mn.y, mn.z, mx.x, mx.y, mx.z, false, true)
end

local function IsInsideBox(p, mn, mx)
    return p.x >= mn.x and p.x <= mx.x
       and p.y >= mn.y and p.y <= mx.y
       and p.z >= mn.z and p.z <= mx.z
end

local function HasPlayerOccupant(veh)
    for _, pid in ipairs(GetActivePlayers()) do
        local pped = GetPlayerPed(pid)
        if pped ~= 0 and GetVehiclePedIsIn(pped, false) == veh then
            return true
        end
    end
    return false
end

-- Types de population "ambiants" créés par le moteur = trafic PNJ.
-- (1=RANDOM_PERMANENT 2=RANDOM_PARKED 3=RANDOM_PATROL 4=RANDOM_SCENARIO
--  5=RANDOM_AMBIENT).  6=PERMANENT et 7=MISSION = véhicules de script/joueur.
local AMBIENT_POP = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true }

-- Véhicule à NE JAMAIS supprimer (appartient au système / à un joueur).
-- Seuls les véhicules ambiants PNJ sont retirés.
local function IsProtectedVehicle(veh)
    if IsEntityAMissionEntity(veh) then return true end     -- script / aperçu / livré
    if not AMBIENT_POP[GetEntityPopulationType(veh)] then    -- pas un véhicule ambiant PNJ
        return true
    end
    if HasPlayerOccupant(veh) then return true end          -- un joueur est dedans
    return false
end

Citizen.CreateThread(function()
    local z = Config.Concessionnaire.NoTraffic
    DisableShowroomRoads()
    local nextRoads = GetGameTimer() + 5000
    while true do
        local wait = 2000
        local pos  = GetEntityCoords(PlayerPedId())
        -- Actif seulement quand on est proche (économie de perfs)
        if LSLegacy.Validate.Distance(pos, z.center, math.max(z.size.x, z.size.y) + 40.0) then
            wait = 500
            local mn, mx = GetTrafficBox()

            if GetGameTimer() >= nextRoads then
                nextRoads = GetGameTimer() + 5000
                DisableShowroomRoads()
            end

            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if not IsProtectedVehicle(veh)
                   and IsInsideBox(GetEntityCoords(veh), mn, mx) then
                    SetEntityAsMissionEntity(veh, true, true)
                    DeleteVehicle(veh)
                end
            end
        end
        Wait(wait)
    end
end)

-- ── Init ─────────────────────────────────────────────────────────────

Citizen.CreateThread(function()
    Wait(1000)
    CreateBlip()
    SpawnSellers()
end)

AddEventHandler('onResourceStop', function(res)
    if GetCurrentResourceName() ~= res then return end
    if Concessionnaire.ClearPreview   then Concessionnaire.ClearPreview()   end
    if Concessionnaire.ClearTestDrive then Concessionnaire.ClearTestDrive()  end
    for _, ped in ipairs(spawnedPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)
