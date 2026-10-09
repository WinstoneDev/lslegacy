LSLegacy = LSLegacy or {}
LSLegacy.Security.RegisterRateLimit('ap:updateVehicle', 20)
LSLegacy.Security.RegisterRateLimit('ap:updateVehicleStatus', 20)
LSLegacy.Security.RegisterRateLimit('ap:requestVehicleDeletion', 20)
LSLegacy.Security.RegisterRateLimit('ap:vehicleDestroyed', 5000)
LSLegacy.AP = { Active = {} }

-- Dédup limitée aux plaques suivies par l'AP : ne supprime jamais l'entité
-- référencée par LSLegacy.AP.Active (sinon l'entrée devient une référence
-- morte qui bloque tout respawn ultérieur), et ne touche pas aux plaques
-- fixes d'autres modules (POLICE, EMS, POMPIER, ATELIER, ESSAI...) qui
-- peuvent légitimement coexister en plusieurs exemplaires du même modèle.
CreateThread(function()
	while true do
		local allVeh = GetAllVehicles()
		for i = 1, #allVeh do
			local veh = allVeh[i]
			if DoesEntityExist(veh) then
				local plate = GetVehicleNumberPlateText(veh)
				local tracked = LSLegacy.AP.Active[plate]
				if tracked and tracked.entity and tracked.entity ~= veh and DoesEntityExist(tracked.entity) and GetEntityModel(veh) == tracked.model then
					DeleteEntity(veh)
				end
			end
		end
		Wait(5000)
	end
end)


local function IsBlacklisted(entity)
    local model = GetEntityModel(entity)
    for _, m in ipairs(Config.AP.Blacklist.Models) do
        if m == model then return true end
    end
    local plate = (GetVehicleNumberPlateText(entity) or ""):upper()
    for _, p in ipairs(Config.AP.Blacklist.Plates) do
        if plate:find(p, 1, true) then return true end
    end
    return false
end

-- Un véhicule est "possédé" s'il figure dans owned_vehicles (achat concess,
-- attribution job...). Sert de filtre optionnel (Config.AP.OnlyOwnedVehicles)
-- pour éviter de persister indéfiniment n'importe quel véhicule croisé.
local function IsOwnedVehicle(plate)
    local rows = MySQL.Sync.fetchAll('SELECT plate FROM owned_vehicles WHERE plate = @p LIMIT 1', { ['@p'] = plate })
    return rows and #rows > 0
end

local function SaveVehicle(entity)
    if not DoesEntityExist(entity) then return end
    if IsBlacklisted(entity) then return end

    local plate = (GetVehicleNumberPlateText(entity) or ""):upper()

    -- Véhicule jamais enregistré par l'AP (trouvé/emprunté par un joueur sans
    -- être passé par un spawn/achat persistant) : rien à sauvegarder.
    local active = LSLegacy.AP.Active[plate]
    if not active then return end

    if Config.AP.OnlyOwnedVehicles and not IsOwnedVehicle(plate) then return end

    local pos = GetEntityCoords(entity)

    -- Le statebag 'fuelLevel' (posé par pompe/conso/regen, voir persistentvehicles/client/main.lua)
    -- est la source de vérité : il est à jour même si personne n'est actuellement assis dans le véhicule.
    local fuelLevel = Entity(entity).state.fuelLevel or active.fuel or 50.0

    -- santés : valeurs du dernier rapport client si disponibles (le serveur ne
    -- voit pas une carrosserie fidèle), repli sur les natifs serveur
    local h = active.health or {}
    local status = {
        engine = h.engine or GetVehicleEngineHealth(entity),
        body = h.body or GetVehicleBodyHealth(entity),
        tank = h.tank or GetVehiclePetrolTankHealth(entity),
        dirt = h.dirt or GetVehicleDirtLevel(entity),
        lock = GetVehicleDoorLockStatus(entity),
        windows = active.windows or {},
        extras = active.extras or {},
        tyreData = active.tyreData or {},
        doorsBroken = active.doorsBroken or {},
        visualDamage = active.visualDamage or {}
    }

    local tuning = {}
    tuning.colorPrimary, tuning.colorSecondary = GetVehicleColours(entity)
    tuning.pearlColor, tuning.wheelColor = GetVehicleExtraColours(entity)
    tuning.wheelType = GetVehicleWheelType(entity)
    tuning.windowTint = GetVehicleWindowTint(entity)
    -- IsToggleModOn / IsVehicleNeonLightEnabled / GetVehicleNeonLightsColour sont des
    -- natifs CLIENT uniquement : turbo/néons ne sont donc renseignés que par le rapport
    -- périodique client (UpdateVehicleStatus → ap:updateVehicleStatus), jamais ici.

    if active.tuning then
        tuning = active.tuning
        if type(tuning) ~= 'table' then
            tuning = json.decode(tuning)
            active.tuning = tuning
        end
        -- le client est la source de vérité des couleurs ; les natifs serveur ne
        -- servent qu'à combler une sauvegarde ancienne qui n'aurait pas ces champs
        if tuning.colorPrimary == nil or tuning.colorSecondary == nil then
            tuning.colorPrimary, tuning.colorSecondary = GetVehicleColours(entity)
        end
        if tuning.pearlColor == nil or tuning.wheelColor == nil then
            tuning.pearlColor, tuning.wheelColor = GetVehicleExtraColours(entity)
        end
    end

    local snapshot = {
        position = { x = pos.x, y = pos.y, z = pos.z, h = GetEntityHeading(entity) },
        status = status,
        tuning = tuning,
        model = GetEntityModel(entity),
    }

    -- Entity(entity).state lit les bags côté serveur (synchronisés par les clients)
    local stateBags = { fuelLevel = fuelLevel }
    local hb = Entity(entity).state.handbrake
    if hb ~= nil then stateBags.handbrake = hb end

    MySQL.Async.execute([[
        INSERT INTO persistent_vehicles (plate, model, position, status, tuning, trailer_plate, state_bags)
        VALUES (@plate, @model, @position, @status, @tuning, NULL, @state_bags)
        ON DUPLICATE KEY UPDATE
        model=@model, position=@position, status=@status, tuning=@tuning, trailer_plate=NULL, state_bags=@state_bags, last_seen_at = CURRENT_TIMESTAMP
    ]], {
        ['@plate']      = plate,
        ['@model']      = snapshot.model,
        ['@position']   = json.encode(snapshot.position),
        ['@status']     = json.encode(snapshot.status),
        ['@tuning']     = json.encode(snapshot.tuning),
        ['@state_bags'] = json.encode(stateBags),
    })
end


-- Snapshot immédiat (module/garage : avant rangement).
function LSLegacy.AP.SaveVehicleNow(entity) SaveVehicle(entity) end

-- Réservation atomique d'un slot Active avant tout point de yield (Wait/async).
-- Empêche deux threads concurrents (ex: deux joueurs qui se reconnectent en
-- même temps après un restart) de spawner tous les deux la même plaque :
-- entre le check et l'écriture il n'y a aucun Wait, donc aucun autre thread
-- ne peut s'intercaler côté serveur (scheduler coopératif).
local function ReserveSlot(plate)
    if LSLegacy.AP.Active[plate] then return false end
    LSLegacy.AP.Active[plate] = { pending = true }
    return true
end

-- Couleurs appliquées côté serveur (natifs répliqués) : index GTA + RGB custom
-- si le "cercle chromatique" est actif. Le client rejoue ensuite mods/peinture
-- (SetVehicleModColor_1/_2) par-dessus ; ainsi, même si ce rejeu tarde, le
-- véhicule n'apparaît jamais avec la couleur par défaut du modèle.
function LSLegacy.AP.ApplyServerColours(entity, tuning)
    if type(tuning) ~= 'table' then return end
    local p = tuning.paint
    local prim = tuning.colorPrimary or (p and p.primary and p.primary.color)
    local sec  = tuning.colorSecondary or (p and p.secondary and p.secondary.color)
    if prim and sec then SetVehicleColours(entity, math.floor(prim), math.floor(sec)) end
    if Config.AP and Config.AP.DebugColours then
        print(('[AP] couleurs %s : prim=%s sec=%s pearl=%s wheel=%s custom=%s'):format(
            GetVehicleNumberPlateText(entity), tostring(prim), tostring(sec), tostring(tuning.pearlColor), tostring(tuning.wheelColor),
            tostring(p and p.primary and p.primary.custom)))
    end
    if p then
        if p.primary and p.primary.custom and p.primary.r then
            SetVehicleCustomPrimaryColour(entity, math.floor(p.primary.r), math.floor(p.primary.g), math.floor(p.primary.b))
        end
        if p.secondary and p.secondary.custom and p.secondary.r then
            SetVehicleCustomSecondaryColour(entity, math.floor(p.secondary.r), math.floor(p.secondary.g), math.floor(p.secondary.b))
        end
    end
end

-- Le thread de dédup (plus haut, Wait(5000)) supprime l'exemplaire en trop quand un
-- véhicule est respawné alors qu'un exemplaire existait déjà en jeu (Active vidé par
-- un redémarrage de ressource pendant qu'un joueur restait connecté). Avant sa passe,
-- les deux exemplaires se chevauchent aux mêmes coordonnées et se percutent : celui
-- qui survit est éjecté/tombe et encaisse des dégâts. On ne déclenche donc ce garde-fou
-- (spawn surélevé, figé, sans collision, reposé après la passe de dédup) que si un
-- exemplaire de la même plaque existe déjà en jeu — jamais sur un spawn normal.
local SPAWN_GUARD_Z_OFFSET = 5.0
local SPAWN_GUARD_DELAY_MS = 5500 -- > l'intervalle du thread de dédup (5000ms)

local function HasExistingVehicleWithPlate(plate)
    local allVeh = GetAllVehicles()
    for i = 1, #allVeh do
        local veh = allVeh[i]
        if DoesEntityExist(veh) and GetVehicleNumberPlateText(veh) == plate then
            return true
        end
    end
    return false
end

local function SpawnVehicle(row)
    local pos    = json.decode(row.position)
    local status = json.decode(row.status)
    local tuning = type(row.tuning) == "string" and json.decode(row.tuning) or row.tuning or {}
    local duplicateRisk = HasExistingVehicleWithPlate(row.plate)
    local spawnZ = duplicateRisk and (pos.z + SPAWN_GUARD_Z_OFFSET) or pos.z
    local entity = CreateVehicle(row.model, pos.x, pos.y, spawnZ, pos.h or 0.0, true, true)
    local spawnTimeout = 0
    while DoesEntityExist(entity) == false do
        Wait(100)
        spawnTimeout = spawnTimeout + 100
        if spawnTimeout >= 5000 then
            -- Modèle invalide/CreateVehicle en échec : on erroré volontairement pour que
            -- TrySpawnVehicle libère la réservation (sinon la plaque reste bloquée à vie
            -- dans Active tant que la ressource ne redémarre pas).
            error(("[AP] CreateVehicle a échoué pour la plaque %s (modèle %s)"):format(tostring(row.plate), tostring(row.model)))
        end
    end
    if duplicateRisk then
        FreezeEntityPosition(entity, true)
        -- SetEntityCollision est un natif CLIENT uniquement (crash "attempt to
        -- call a nil value" côté serveur) : la désactivation de collision est
        -- donc déléguée aux clients via ce statebag (voir AddStateBagChangeHandler
        -- côté client, même pattern que 'fuelLevel'/'handbrake').
        Entity(entity).state:set('apSpawnGuard', true, true)
        CreateThread(function()
            Wait(SPAWN_GUARD_DELAY_MS)
            if not DoesEntityExist(entity) then return end -- supprimé par le dédup : rien à faire
            -- Dégeler AVANT de repositionner : un entity figé n'a pas ses coords
            -- resynchronisées aux clients (netsync suppose un véhicule gelé statique),
            -- donc il resterait visuellement bloqué en l'air côté client sinon.
            FreezeEntityPosition(entity, false)
            SetEntityCoords(entity, pos.x, pos.y, pos.z, false, false, false, true)
            SetEntityHeading(entity, pos.h or 0.0)
            Entity(entity).state:set('apSpawnGuard', false, true)
        end)
    end
    -- KeepEntity : un véhicule persistant créé sans client à portée (sortie de
    -- garage, joueur encore dans l'IPL) était purgé par OneSync avant d'être streamé
    if SetEntityOrphanMode then SetEntityOrphanMode(entity, 2) end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    SetVehicleNumberPlateText(entity, row.plate)
    local appliedPlate = GetVehicleNumberPlateText(entity)
    if appliedPlate ~= row.plate then
        print(("[AP] ATTENTION : plaque demandée '%s' mais '%s' appliquée après SetVehicleNumberPlateText (row.plate=%s, type=%s)"):format(
            tostring(row.plate), tostring(appliedPlate), tostring(row.plate), type(row.plate)))
    end
    -- Statebag 'plate' (même pattern que fuelLevel/handbrake) : SetVehicleNumberPlateText
    -- est un mod one-shot dont la réplication OneSync à un client qui stream l'entité
    -- juste après sa création n'est pas garantie ; le statebag force une réapplication
    -- fiable côté client dès que l'entité est visible pour lui.
    Entity(entity).state:set("plate", row.plate, true)
    SetVehicleBodyHealth(entity, status.body or 1000.0)
    SetVehicleDirtLevel(entity, status.dirt or 0.0)
    SetVehicleDoorsLocked(entity, status.lock or 1)
    LSLegacy.AP.ApplyServerColours(entity, tuning)

    -- replicate=true : tous les clients reçoivent le bag au chargement, ce qui déclenche leur AddStateBagChangeHandler
    local rawBags = row.state_bags
    local stateBags = (type(rawBags) == "string" and rawBags ~= "") and json.decode(rawBags) or {}
    if stateBags.handbrake ~= nil then
        Entity(entity).state:set("handbrake", stateBags.handbrake, true)
    end
    -- state_bags.fuelLevel n'existe pas encore pour les véhicules sauvegardés
    -- avant cette migration : repli sur status.fuel (ancien format).
    local fuelLevel = stateBags.fuelLevel or status.fuel or 50.0
    Entity(entity).state:set("fuelLevel", fuelLevel, true)

    -- Fusionne dans le slot réservé par ReserveSlot plutôt que d'écraser :
    -- renseigne fuel/windows/extras/... dès le spawn pour que SaveVehicle
    -- n'ait jamais à attendre ces champs (ils ne restent plus jamais nil,
    -- y compris pour les véhicules spawnés par la boucle périodique).
    local slot = LSLegacy.AP.Active[row.plate] or {}
    slot.pending      = nil
    slot.netId        = netId
    slot.entity       = entity
    slot.model        = row.model
    slot.fuel         = fuelLevel
    slot.tuning       = tuning
    slot.windows      = status.windows or {}
    slot.extras       = status.extras or {}
    slot.tyreData     = status.tyreData or {}
    slot.doorsBroken  = status.doorsBroken or {}
    slot.visualDamage = status.visualDamage or {}
    LSLegacy.AP.Active[row.plate] = slot
end

-- Réserve puis spawn ; si SpawnVehicle échoue (JSON corrompu, modèle invalide,
-- CreateVehicle qui ne répond jamais), libère la réservation pour permettre un
-- nouvel essai au prochain connect/tick au lieu de bloquer la plaque à vie.
local function TrySpawnVehicle(row)
    if not ReserveSlot(row.plate) then return end
    local ok, err = pcall(SpawnVehicle, row)
    if not ok then
        LSLegacy.AP.Active[row.plate] = nil
        print(("[AP] Échec du spawn du véhicule %s : %s"):format(tostring(row.plate), tostring(err)))
    end
end

-- Spawn "à chaud" d'un véhicule persisté (ex. sortie de fourrière) en restaurant mods/couleurs/dégâts. Doit être appelée depuis un thread (utilise Wait).
function LSLegacy.AP.SpawnPersistedRow(row, target)
    if not row or not row.plate then return nil end
    local status = type(row.status) == "string" and json.decode(row.status) or row.status or {}
    local tuning = type(row.tuning) == "string" and json.decode(row.tuning) or row.tuning or {}

    TrySpawnVehicle(row)
    if not LSLegacy.AP.Active[row.plate] then return nil end

    local timeout = 0
    while not (LSLegacy.AP.Active[row.plate] and LSLegacy.AP.Active[row.plate].netId) do
        Wait(100)
        timeout = timeout + 100
        if timeout >= 10000 then return nil end
    end
    Wait(500)
    local a = LSLegacy.AP.Active[row.plate]
    a.tuning       = tuning or {}
    a.windows      = status.windows or {}
    a.extras       = status.extras or {}
    a.tyreData     = status.tyreData or {}
    a.doorsBroken  = status.doorsBroken or {}
    a.visualDamage = status.visualDamage or {}

    LSLegacy.Events.SendToClient("ap:vehicleSpawned", -1, {
        netId        = a.netId,
        plate        = row.plate,
        extras       = status.extras or {},
        tankHealth   = status.tank or 1000.0,
        engineHealth = status.engine or 1000.0,
        tuning       = tuning,
        fuel         = a.fuel or 50.0,
        status       = status,
    })
end

function LSLegacy.AP.SpawnPersistentVehicle(model, pos, heading, targetPlayer)
    local modelHash = tonumber(model) or GetHashKey(model)

    -- netMissionEntity=true (comme SpawnVehicle) : sinon le véhicule garde une
    -- population type ambiante et se fait verrouiller par le lock PNJ (population.lua)
    local vehicle = CreateVehicle(modelHash, pos.x, pos.y, pos.z, heading or 0.0, true, true)
    Wait(1000)
    if not DoesEntityExist(vehicle) then
        if targetPlayer then
            LSLegacy.Events.SendToClient('notify', targetPlayer, 'Erreur', 'Le véhicule n\'a pas pu être créé.', 'error')
        end
        return
    end
    local plate = GetVehicleNumberPlateText(vehicle)
    SetVehicleNumberPlateText(vehicle, plate)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    LSLegacy.AP.Active[plate] = { netId = netId, entity = vehicle, model = modelHash, extras = {}, tankHealth = 1000.0, engineHealth = 1000.0, fuel = 50.0, windows = {} }
    Entity(vehicle).state:set('fuelLevel', 50.0, true)
    Wait(500)
    if targetPlayer then
        local ped = GetPlayerPed(targetPlayer)
        if DoesEntityExist(ped) then
            TaskWarpPedIntoVehicle(ped, vehicle, -1)
        end
        LSLegacy.Events.SendToClient("ap:vehicleSpawned", -1, { netId = netId, plate = plate, extras = {}, tankHealth = 1000.0, engineHealth = 1000.0, fuel = 50.0, windows = {} })
    end
end

function LSLegacy.AP.DeleteVehicle(plate, entity)
    if LSLegacy.AP.Active[plate] then
        LSLegacy.AP.Active[plate] = nil
    end

    MySQL.Async.execute(
        'DELETE FROM persistent_vehicles WHERE plate = @plate',
        { ['@plate'] = plate }
    )

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

-- Retire l'entité du monde sans toucher à persistent_vehicles (même schéma que
-- le rangement garage : snapshot avant coupure, puis Active[plate] = nil pour
-- que le prochain spawn de cette plaque reparte de la BDD au lieu de pointer
-- sur une entité supprimée).
function LSLegacy.AP.DespawnVehicle(plate, entity)
    if DoesEntityExist(entity) then
        LSLegacy.AP.SaveVehicleNow(entity)
    end

    if LSLegacy.AP.Active[plate] then
        LSLegacy.AP.Active[plate] = nil
    end

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

LSLegacy.Events.Register("ap:requestVehicleDeletion", function(netId, plate)
    local source = source
    local player = LSLegacy.Players.Get(source)

    if not player then return end

    local entity = NetworkGetEntityFromNetworkId(netId)

    if DoesEntityExist(entity) then
        LSLegacy.AP.DeleteVehicle(plate, entity)
        LSLegacy.Events.SendToClient('notify', source, 'Succès', 'Le véhicule a été supprimé.', 'success')
    else
        LSLegacy.Events.SendToClient('notify', source, 'Erreur', 'Impossible de trouver le véhicule à supprimer.', 'error')
    end
end)

-- Véhicule AP détruit (explosion, chute...) signalé par un client : purge
-- persistent_vehicles ET owned_vehicles (contrairement à DeleteVehicle, qui
-- ne touche pas owned_vehicles, utilisé pour /dv). Idempotent : les DELETE
-- n'affectent aucune ligne si le véhicule n'était pas persistant/possédé.
-- L'entité n'est PAS supprimée : la carcasse reste visible en RP tant que le
-- serveur tourne, elle n'étant plus trackée par l'AP (Active[plate]=nil) elle
-- ne sera simplement jamais respawnée après le prochain reboot.
LSLegacy.Events.Register("ap:vehicleDestroyed", function(netId, plate)
    local source = source
    local player = LSLegacy.Players.Get(source)
    if not player then return end
    if not plate or plate == "" then return end
    plate = plate:upper()

    MySQL.Async.execute('DELETE FROM persistent_vehicles WHERE plate = @plate', { ['@plate'] = plate })
    MySQL.Async.execute('DELETE FROM owned_vehicles WHERE plate = @plate', { ['@plate'] = plate })

    LSLegacy.AP.Active[plate] = nil
end)

LSLegacy.Security.RegisterRateLimit('ap:requestVehicleDespawn', 20)
LSLegacy.Events.Register("ap:requestVehicleDespawn", function(netId, plate)
    local source = source
    local player = LSLegacy.Players.Get(source)

    if not player then return end

    local entity = NetworkGetEntityFromNetworkId(netId)

    if DoesEntityExist(entity) then
        LSLegacy.AP.DespawnVehicle(plate, entity)
        LSLegacy.Events.SendToClient('notify', source, 'Succès', 'Le véhicule a été retiré (conservé en base).', 'success')
    else
        LSLegacy.Events.SendToClient('notify', source, 'Erreur', 'Impossible de trouver le véhicule à retirer.', 'error')
    end
end)

LSLegacy.RegisterCommand('dv', 2, function(player, args, showError, rawCommand)
    LSLegacy.Events.SendToClient('ap:findAndDeleteVehicle', player.source) 
end,
{
    help = "Supprime le véhicule que vous conduisez ou le plus proche (rayon de 3m).",
    validate = false
}, false)

LSLegacy.Events.Register("ap:updateVehicleStatus", function(plate, status)
    if not plate or not status then return end
    if LSLegacy.AP.Active[plate] then
        LSLegacy.AP.Active[plate].tuning = status.tuning
        LSLegacy.AP.Active[plate].windows = status.windows
        LSLegacy.AP.Active[plate].extras = status.extras
        LSLegacy.AP.Active[plate].tyreData = status.tyreData
        LSLegacy.AP.Active[plate].doorsBroken = status.doorsBroken
        LSLegacy.AP.Active[plate].visualDamage = status.visualDamage
        LSLegacy.AP.Active[plate].health = status.health
    end
end)

LSLegacy.Events.Register("ap:updateVehicle", function(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then SaveVehicle(entity) end
end)

LSLegacy.Events.AddHandler('ap:clientsetonSpawn', function(source)
    MySQL.Async.fetchAll('SELECT * FROM persistent_vehicles WHERE garage_stored = 0', {}, function(rows)
        Citizen.CreateThread(function()
            for _, row in ipairs(rows) do
                local status = type(row.status) == "string" and json.decode(row.status) or row.status
                local tuning = type(row.tuning) == "string" and json.decode(row.tuning) or row.tuning

                TrySpawnVehicle(row)
                if not LSLegacy.AP.Active[row.plate] then goto continue end

                local timeout = 0
                while LSLegacy.AP.Active[row.plate] and LSLegacy.AP.Active[row.plate].netId == nil do
                    Wait(100)
                    timeout = timeout + 100
                    if timeout >= 10000 then goto continue end
                end
                if not LSLegacy.AP.Active[row.plate] then goto continue end
                LSLegacy.Events.SendToClient("ap:vehicleSpawned", source, {
                    netId = LSLegacy.AP.Active[row.plate].netId,
                    plate = row.plate,
                    extras = status.extras or {},
                    tankHealth = status.tank or 1000.0,
                    engineHealth = status.engine or 1000.0,
                    tuning = tuning,
                    fuel = LSLegacy.AP.Active[row.plate].fuel or 50.0,
                    status = status
                })
                ::continue::
            end
        end)
    end)
end)

CreateThread(function()
    while true do
        if not Config.AP.Enable then goto continue end
        local players = LSLegacy.Players.GetAll()

        if next(players) ~= nil then
            for plate, v in pairs(LSLegacy.AP.Active) do
                if v.entity and DoesEntityExist(v.entity) then
                    SaveVehicle(v.entity)
                end
            end

            MySQL.Async.fetchAll([[SELECT * FROM persistent_vehicles WHERE garage_stored = 0]], {}, function(rows)
                Citizen.CreateThread(function()
                    for _, row in ipairs(rows) do
                        -- Un véhicule déjà Active (le cas normal, à chaque tick) ne doit
                        -- jamais être rebroadcast : TrySpawnVehicle est un no-op pour lui,
                        -- mais renvoyer ap:vehicleSpawned réappliquerait les mods et
                        -- écraserait une tuning en cours. On ne diffuse que pour un
                        -- véhicule qui vient d'être respawné ici (Active vidé par un
                        -- redémarrage de ressource pendant que des joueurs restaient
                        -- connectés) : sinon lui seul restait sans mods/livrée/peinture,
                        -- le spawn serveur ne posant que santé/couleurs de base.
                        local wasActive = LSLegacy.AP.Active[row.plate] ~= nil
                        TrySpawnVehicle(row)
                        if not wasActive and LSLegacy.AP.Active[row.plate] then
                            local status = type(row.status) == "string" and json.decode(row.status) or row.status or {}
                            local tuning = type(row.tuning) == "string" and json.decode(row.tuning) or row.tuning or {}
                            local timeout = 0
                            while LSLegacy.AP.Active[row.plate] and LSLegacy.AP.Active[row.plate].netId == nil do
                                Wait(100)
                                timeout = timeout + 100
                                if timeout >= 10000 then goto continue end
                            end
                            if LSLegacy.AP.Active[row.plate] then
                                LSLegacy.Events.SendToClient("ap:vehicleSpawned", -1, {
                                    netId        = LSLegacy.AP.Active[row.plate].netId,
                                    plate        = row.plate,
                                    extras       = status.extras or {},
                                    tankHealth   = status.tank or 1000.0,
                                    engineHealth = status.engine or 1000.0,
                                    tuning       = tuning,
                                    fuel         = LSLegacy.AP.Active[row.plate].fuel or 50.0,
                                    status       = status,
                                })
                            end
                        end
                        ::continue::
                    end
                end)
            end)

            if Config.AP.Cleanup then
                -- SendCleanupToGarage : un véhicule inactif qui a déjà connu un garage
                -- y retourne (place libre requise, cf. module/garage) au lieu d'être purgé.
                if Config.AP.SendCleanupToGarage and LSLegacy.Garage and LSLegacy.Garage.ReturnToLastGarage then
                    MySQL.Async.fetchAll([[
                        SELECT plate FROM persistent_vehicles
                        WHERE garage IS NULL AND last_garage IS NOT NULL
                          AND last_seen_at < (NOW() - INTERVAL @days DAY)
                    ]], { ['@days'] = Config.AP.CleanupDays }, function(rows)
                        for _, r in ipairs(rows or {}) do LSLegacy.Garage.ReturnToLastGarage(r.plate) end
                    end)
                end
                MySQL.Async.execute([[
                    DELETE FROM persistent_vehicles
                    WHERE garage IS NULL AND last_seen_at < (NOW() - INTERVAL @days DAY)
                ]], { ['@days'] = Config.AP.CleanupDays })
            end
        end
        Wait(Config.AP.UpdateIntervalMs)
        ::continue::
    end
end)
