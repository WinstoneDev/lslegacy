local CFG = Config.Population

CreateThread(function()
    while true do
        SetPedDensityMultiplierThisFrame(CFG.PedDensity)
        SetScenarioPedDensityMultiplierThisFrame(CFG.PedDensity, CFG.PedDensity)
        SetVehicleDensityMultiplierThisFrame(CFG.VehicleDensity)
        SetRandomVehicleDensityMultiplierThisFrame(CFG.VehicleDensity)
        SetParkedVehicleDensityMultiplierThisFrame(CFG.ParkedVehicleDensity)
        Wait(0)
    end
end)

-- RANDOM_PERMANENT(0) / RANDOM_PARKED(1) / RANDOM_PATROL(2) / RANDOM_SCENARIO(3) /
-- RANDOM_AMBIENT(4) = trafic généré nativement par le jeu. Mais les maps/trafic
-- custom du serveur (tstudio_zmapdata, mnr_cayo...) spawnent souvent leurs
-- véhicules en tant que MISSION(6), alors qu'ils sont bien conduits par un PNJ :
-- sans ce deuxième critère, tout le trafic custom échappait au verrouillage.
-- Un véhicule vide et scripté (job, concessionnaire, persistentvehicles...)
-- n'a pas de conducteur PNJ et reste donc exclu.
-- Véhicules d'une intervention police en cours (moto de rodéo urbain,
-- voiture-sono, véhicule accidenté/visé...) : un PNJ de mission au volant
-- ne doit pas être traité comme du trafic ambiant, sans quoi les agents
-- ne peuvent plus jamais y monter (cf. PoliceMissionVehicleNets,
-- module/police/client/callouts.lua).
local function IsPoliceMissionVehicle(vehicle)
    local nets = PoliceMissionVehicleNets
    if not nets or not next(nets) then return false end
    return nets[NetworkGetNetworkIdFromEntity(vehicle)] == true
end

-- Un véhicule dont le conducteur PNJ a fui après un braquage réussi (cf.
-- module/pnj_vehicule/client/main.lua) reste déverrouillé en permanence : il
-- ne doit plus jamais être reverrouillé par le thread ci-dessous.
local function IsFledPNJVehicle(vehicle)
    local nets = PNJVehiculeFledNets
    if not nets or not next(nets) then return false end
    return nets[NetworkGetNetworkIdFromEntity(vehicle)] == true
end

local function IsAmbientVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    if IsPoliceMissionVehicle(vehicle) then return false end
    if IsFledPNJVehicle(vehicle) then return false end
    if GetEntityPopulationType(vehicle) <= 4 then return true end
    local driver = GetPedInVehicleSeat(vehicle, -1)
    return driver ~= 0 and DoesEntityExist(driver) and not IsPedAPlayer(driver)
end

-- réutilisé par module/pnj_vehicule (menace conducteur + fouille boîte à gants).
-- IsFledPNJVehicle est exposée à part : un véhicule abandonné après fuite n'est
-- plus "ambiant" (il ne doit plus être reverrouillé), mais reste une cible
-- valide pour la fouille de la boîte à gants.
LSLegacy.IsAmbientVehicle = IsAmbientVehicle
LSLegacy.IsFledPNJVehicle = IsFledPNJVehicle

if CFG.LockAmbientVehicles then
    -- le lock (SetVehicleDoorsLocked) est une propriété réseau du véhicule,
    -- déjà répliquée nativement par onesync à tous les clients qui l'ont en
    -- scope : pas besoin de relais serveur. Un relais broadcast à -1 posait
    -- en plus un netId non résolvable aux clients hors scope, d'où le spam
    -- "GetNetworkObject: no object by ID" côté client et le log serveur
    -- associé à chaque déclenchement.
    local function LockVehicle(vehicle)
        SetVehicleDoorsLocked(vehicle, 2)
    end

    -- verrouille en continu les véhicules PNJ à portée du joueur (roulants et garés),
    -- sauf celui qu'il occupe déjà. Limité à un rayon autour du joueur : verrouiller
    -- tout le pool sans limite de distance maintenait artificiellement en vie des
    -- véhicules hors de portée (native appelée en continu dessus), alors que leur
    -- PNJ conducteur suivait le cycle de despawn normal du moteur (plus court) :
    -- le véhicule survivait seul à son conducteur, d'où des épaves qui s'accumulaient.
    local LOCK_RADIUS = 50.0
    CreateThread(function()
        while true do
            local playerPed = PlayerPedId()
            local playerVeh = GetVehiclePedIsIn(playerPed, false)
            local coords = GetEntityCoords(playerPed)
            for _, vehicle in ipairs(GetGamePool('CVehicle')) do
                if vehicle ~= playerVeh and IsAmbientVehicle(vehicle) and GetVehicleDoorLockStatus(vehicle) ~= 2
                    and LSLegacy.Validate.Distance(GetEntityCoords(vehicle), coords, LOCK_RADIUS)
                then
                    LockVehicle(vehicle)
                end
            end
            Wait(2000)
        end
    end)

    -- filet de sécurité, à chaque frame : coupe toute tentative d'entrée (approche,
    -- ouverture normale ou bris de vitre) sur un véhicule PNJ pas encore verrouillé.
    -- Le contrôle Entrer/Sortir est désactivé en amont dès qu'un véhicule PNJ
    -- verrouillé est à portée, pour empêcher la tâche d'entrée de démarrer du tout
    -- plutôt que de devoir l'interrompre une fois lancée (bris de vitre inclus).
    CreateThread(function()
        local lastNotify = 0
        while true do
            local ped = PlayerPedId()

            if not IsPedInAnyVehicle(ped, false) then
                local coords = GetEntityCoords(ped)
                local nearVehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 3.0, 0, 70)
                if IsAmbientVehicle(nearVehicle) and GetVehicleDoorLockStatus(nearVehicle) ~= 2 then
                    DisableControlAction(0, 75, true) -- INPUT_VEH_EXIT / entrer-sortir
                end
            end

            local vehicle = GetVehiclePedIsEntering(ped)
            if vehicle == 0 then vehicle = GetVehiclePedIsTryingToEnter(ped) end

            if IsAmbientVehicle(vehicle) then
                local lock = GetVehicleDoorLockStatus(vehicle)
                if lock == 0 or lock == 1 then
                    LockVehicle(vehicle)
                    ClearPedTasksImmediately(ped)
                    if GetGameTimer() - lastNotify > 2000 then
                        lastNotify = GetGameTimer()
                        LSLegacy.ShowNotification(nil, "Ce véhicule est verrouillé.", 'error')
                    end
                end
            end
            Wait(0)
        end
    end)
end
