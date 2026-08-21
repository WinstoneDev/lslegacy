--  MODULE ATELIER — État véhicule (serveur)
--  Table maison indexée sur la plaque : source de vérité pour tous les
--  composants que GTA V n'expose pas nativement (capot, ailes, pare-
--  chocs, bas de caisse, portières, coffre, vitres, phares). Pour les
--  composants nativement observables (moteur, carrosserie générale,
--  pneus), on RECALE en continu depuis l'état réel du véhicule, mais
--  uniquement à la baisse : remonter un pourcentage ne se fait QUE via
--  une réparation explicite (jamais par la réconciliation).

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS atelier_vehicles (
        plate        VARCHAR(12)  NOT NULL,
        components   LONGTEXT     NOT NULL DEFAULT '{}',
        maintenance  LONGTEXT     NOT NULL DEFAULT '{}',
        updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (plate)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- [plate] = { components = {mechanical={},tyres={},body={}}, maintenance = {}, dirty = bool }
LSLegacy.Atelier.VehicleState = LSLegacy.Atelier.VehicleState or {}

local function clampPercent(v)
    v = tonumber(v) or 0
    if v < 0 then return 0 end
    if v > 100 then return 100 end
    return math.floor(v + 0.5)
end

-- Charge (ou crée) l'état d'une plaque et le renvoie via cb(state).
-- Ne fait jamais confiance à un état fourni par le client : toujours lu
-- depuis la table atelier_vehicles ou initialisé par défaut ici.
function LSLegacy.Atelier.GetVehicleState(plate, cb)
    if not plate or plate == '' then return cb(nil) end
    plate = plate:upper()

    local cached = LSLegacy.Atelier.VehicleState[plate]
    if cached then return cb(cached) end

    MySQL.Async.fetchAll('SELECT * FROM atelier_vehicles WHERE plate = @p LIMIT 1', { ['@p'] = plate }, function(rows)
        local state
        if rows and rows[1] then
            local ok1, components  = pcall(json.decode, rows[1].components)
            local ok2, maintenance = pcall(json.decode, rows[1].maintenance)
            state = {
                components  = ok1 and components or LSLegacy.Atelier.DefaultComponentState(),
                maintenance = ok2 and maintenance or {},
            }
        else
            state = { components = LSLegacy.Atelier.DefaultComponentState(), maintenance = {} }
            MySQL.Async.execute(
                'INSERT INTO atelier_vehicles (plate, components, maintenance) VALUES (@p, @c, @m) ' ..
                'ON DUPLICATE KEY UPDATE plate=plate',
                { ['@p'] = plate, ['@c'] = json.encode(state.components), ['@m'] = json.encode(state.maintenance) }
            )
        end
        LSLegacy.Atelier.VehicleState[plate] = state
        cb(state)
    end)
end

function LSLegacy.Atelier.SaveVehicleState(plate)
    local state = LSLegacy.Atelier.VehicleState[plate]
    if not state then return end
    MySQL.Async.execute(
        'INSERT INTO atelier_vehicles (plate, components, maintenance) VALUES (@p, @c, @m) ' ..
        'ON DUPLICATE KEY UPDATE components=@c, maintenance=@m',
        { ['@p'] = plate, ['@c'] = json.encode(state.components), ['@m'] = json.encode(state.maintenance) }
    )
end

-- Fixe la valeur d'un composant (réparation explicite). Répare aussi le
-- natif GTA correspondant quand un existe. `netId` optionnel : sans lui,
-- seule notre table est mise à jour (véhicule non chargé/hors de portée).
function LSLegacy.Atelier.RepairComponent(plate, netId, componentId, cb)
    local category, def = LSLegacy.Atelier.FindComponent(componentId)
    if not category then return cb and cb(false) end

    LSLegacy.Atelier.GetVehicleState(plate, function(state)
        state.components[category][componentId] = 100
        LSLegacy.Atelier.SaveVehicleState(plate)

        local entity = netId and NetworkGetEntityFromNetworkId(netId)
        if entity and DoesEntityExist(entity) then
            if componentId == 'moteur' then
                SetVehicleEngineHealth(entity, 1000.0)
                SetVehicleUndriveable(entity, false)
            elseif componentId == 'carrosserie_generale' then
                SetVehicleBodyHealth(entity, 1000.0)
                SetVehicleDeformationFixed(entity)
            elseif def.wheelIndex then
                SetVehicleTyreFixed(entity, def.wheelIndex)
            end

            -- Force une sauvegarde immédiate de persistent_vehicles plutôt que
            -- d'attendre le prochain tick du thread périodique de
            -- module/persistent_vehicles (accès direct à LSLegacy.Event,
            -- alimentée par LSLegacy.RegisterServerEvent — aucune API inventée).
            if LSLegacy.Event['ap:updateVehicle'] then
                LSLegacy.Event['ap:updateVehicle'](netId)
            end
        end

        if cb then cb(true) end
    end)
end

-- Réconcilie notre état avec l'état réel du véhicule (GTA). N'abaisse
-- jamais un composant déjà endommagé, et ne remonte JAMAIS un
-- pourcentage (remonter = réparation explicite uniquement).
---@param snapshot table { engineHealth, bodyHealth, tyres = {[wheelIndex]=health0to1000}, doorsBroken = {[doorIndex]=bool} }
function LSLegacy.Atelier.ReconcileVehicleState(plate, snapshot)
    if not snapshot then return end
    LSLegacy.Atelier.GetVehicleState(plate, function(state)
        local changed = false

        if snapshot.engineHealth then
            local pct = clampPercent(snapshot.engineHealth / 10)
            if pct < state.components.mechanical.moteur then
                state.components.mechanical.moteur = pct
                changed = true
            end
        end

        if snapshot.bodyHealth then
            local pct = clampPercent(snapshot.bodyHealth / 10)
            if pct < state.components.body.carrosserie_generale then
                state.components.body.carrosserie_generale = pct
                changed = true
            end
        end

        if snapshot.tyres then
            for id, def in pairs(LSLegacy.Atelier.Components.tyres) do
                local health = snapshot.tyres[def.wheelIndex]
                if health then
                    local pct = clampPercent(health / 10)
                    if pct < state.components.tyres[id] then
                        state.components.tyres[id] = pct
                        changed = true
                    end
                end
            end
        end

        if snapshot.doorsBroken then
            for id, def in pairs(LSLegacy.Atelier.Components.body) do
                if def.doorIndex and snapshot.doorsBroken[def.doorIndex] then
                    if state.components.body[id] > 40 then
                        state.components.body[id] = 40
                        changed = true
                    end
                end
            end
        end

        if changed then LSLegacy.Atelier.SaveVehicleState(plate) end
    end)
end

-- Construit un instantané GTA-observable DIRECTEMENT depuis l'entité
-- serveur (jamais depuis une valeur envoyée par le client : les natifs de
-- lecture de santé/portières sont utilisables côté serveur sur une
-- entité réseauée, donc aucune confiance à faire au client ici).
function LSLegacy.Atelier.BuildGTASnapshot(entity)
    if not DoesEntityExist(entity) then return nil end

    local tyres = {}
    for _, def in pairs(LSLegacy.Atelier.Components.tyres) do
        tyres[def.wheelIndex] = GetTyreHealth(entity, def.wheelIndex)
    end

    local doorsBroken = {}
    for _, def in pairs(LSLegacy.Atelier.Components.body) do
        if def.doorIndex then
            doorsBroken[def.doorIndex] = IsVehicleDoorDamaged(entity, def.doorIndex)
        end
    end

    return {
        engineHealth = GetVehicleEngineHealth(entity),
        bodyHealth   = GetVehicleBodyHealth(entity),
        tyres        = tyres,
        doorsBroken  = doorsBroken,
    }
end
