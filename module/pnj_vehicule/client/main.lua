local C = PNJVehicule.Config

-- véhicules dont le conducteur a fui : exclus du (re)verrouillage ambiant
-- (cf. client/population.lua, IsAmbientVehicle/IsFledPNJVehicle).
PNJVehiculeFledNets = PNJVehiculeFledNets or {}

local function Notify(msg, type)
    LSLegacy.ShowNotification(nil, msg, type or 'info')
end

local LethalWeaponHashes = {}
for _, name in ipairs(C.LethalWeapons) do
    LethalWeaponHashes[#LethalWeaponHashes + 1] = GetHashKey(name)
end

-- Pas besoin de munitions : l'arme létale en main suffit à faire peur au PNJ.
local function HasLethalWeaponEquipped(ped)
    local weapon = GetSelectedPedWeapon(ped)
    for i = 1, #LethalWeaponHashes do
        if LethalWeaponHashes[i] == weapon then
            return true
        end
    end
    return false
end

-- vehicle -> gametimer du prochain tirage autorisé (-1 = déjà géré, plus jamais retenté)
local nextRollAt = {}
-- vehicle -> true : boîte à gants déjà créée/tirée pour ce véhicule (une seule fois)
local seededGlovebox = {}

local function FleeAndUnlock(vehicle, driver)
    if not DoesEntityExist(vehicle) then return end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    PNJVehiculeFledNets[netId] = true
    SetVehicleDoorsLocked(vehicle, 1)

    if DoesEntityExist(driver) then
        ClearPedTasksImmediately(driver)
        SetBlockingOfNonTemporaryEvents(driver, false)
        TaskSmartFleePed(driver, PlayerPedId(), C.FleeRadius, -1, false, false)
    end

    Notify(C.Messages.fled, 'error')
end

local function TriggerHandsUp(vehicle, driver)
    nextRollAt[vehicle] = -1
    Notify(C.Messages.handsUp, 'warning')

    SetBlockingOfNonTemporaryEvents(driver, true)
    -- même sortie que le joueur avec [F] (TaskLeaveVehicle, flag 0 = normale, pas de saut par la fenêtre)
    TaskLeaveVehicle(driver, vehicle, 0)

    CreateThread(function()
        local timeout = GetGameTimer() + C.ExitVehicleTimeout
        while DoesEntityExist(driver) and IsPedInVehicle(driver, vehicle, false) and GetGameTimer() < timeout do
            Wait(0)
        end

        if not DoesEntityExist(driver) then return end
        ClearPedTasksImmediately(driver)
        TaskHandsUp(driver, -1, PlayerPedId(), -1, true)

        Wait(C.HandsUpDuration)
        FleeAndUnlock(vehicle, driver)
    end)
end

-- surveillance en continu : vise-t-on un conducteur PNJ (véhicule ambiant, cf.
-- LSLegacy.IsAmbientVehicle) avec une arme létale chargée ?
CreateThread(function()
    while true do
        Wait(300)
        if C.Enabled then
            local ped = PlayerPedId()
            if HasLethalWeaponEquipped(ped) then
                local playerId = PlayerId()
                local coords = GetEntityCoords(ped)
                for _, vehicle in ipairs(GetGamePool('CVehicle')) do
                    local rollAt = nextRollAt[vehicle]
                    if rollAt ~= -1 and (rollAt == nil or GetGameTimer() >= rollAt)
                        and LSLegacy.IsAmbientVehicle(vehicle)
                        and LSLegacy.Validate.Distance(GetEntityCoords(vehicle), coords, C.AimRange)
                    then
                        local driver = GetPedInVehicleSeat(vehicle, -1)
                        if driver ~= 0 and DoesEntityExist(driver) and not IsEntityDead(driver)
                            and IsPlayerFreeAimingAtEntity(playerId, driver)
                        then
                            if math.random(100) <= C.HandsUpChance then
                                TriggerHandsUp(vehicle, driver)
                            else
                                nextRollAt[vehicle] = GetGameTimer() + C.RetryCooldownMs
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ── Boîte à gants : montée à bord du véhicule abandonné → création du
-- datastore (comme le ferait l'ouverture normale de l'inventaire véhicule,
-- cf. inventory/client/main.lua LoadVehicleContainer/RegisterBAG), avec une
-- chance que le serveur y dépose directement la clé du véhicule.
CreateThread(function()
    while true do
        Wait(500)
        if C.Enabled then
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= 0 and not seededGlovebox[vehicle] and GetPedInVehicleSeat(vehicle, -1) == ped
                and LSLegacy.IsFledPNJVehicle(vehicle)
            then
                seededGlovebox[vehicle] = true
                local plate = GetVehicleNumberPlateText(vehicle):gsub('^%s+', ''):gsub('%s+$', '')
                local model = GetEntityModel(vehicle)
                local maxWeight = Config.VehicleGloveboxes[GetVehicleClass(vehicle)] or 5
                LSLegacy.Events.SendToServer('pnjvehicule:seedGlovebox', plate, model, maxWeight)
            end
        end
    end
end)
