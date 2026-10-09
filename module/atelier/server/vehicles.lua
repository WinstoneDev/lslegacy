-- Table indexée sur la plaque, source de vérité pour les composants non exposés nativement par GTA V.
-- Les composants nativement observables sont recalés en continu depuis l'état réel, mais uniquement à
-- la baisse : remonter un pourcentage ne se fait QUE via une réparation explicite.

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

local function ClampPercent(v)
    v = tonumber(v) or 0
    if v < 0 then return 0 end
    if v > 100 then return 100 end
    return math.floor(v + 0.5)
end

-- Charge (ou crée) l'état d'une plaque et le renvoie via cb(state). Jamais lu depuis le client.
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

-- Fixe la valeur d'un composant et répare le natif GTA correspondant. `netId` optionnel : sans lui,
-- seule notre table est mise à jour (véhicule non chargé/hors de portée).
function LSLegacy.Atelier.RepairComponent(plate, netId, componentId, cb)
    local category, def = LSLegacy.Atelier.FindComponent(componentId)
    if not category then return cb and cb(false) end

    LSLegacy.Atelier.GetVehicleState(plate, function(state)
        state.components[category][componentId] = 100

        -- Une zone de déformation (cf. shared/components.lua) peut être partagée
        -- par plusieurs pièces (ex: capot + ailes + phares) : le dégât visuel
        -- n'est effacé qu'une fois TOUTES réparées, sinon réparer une seule
        -- pièce ferait disparaître le cabossage des autres gratuitement.
        local zoneFixed = nil
        if category == 'body' then
            local zone = LSLegacy.Atelier.FindDeformationZone(componentId)
            if zone then
                local allFixed = true
                for _, id in ipairs(zone.components) do
                    if (state.components.body[id] or 100) < 100 then allFixed = false break end
                end
                if allFixed then zoneFixed = zone end
            end
        end

        LSLegacy.Atelier.SaveVehicleState(plate)

        local entity = netId and NetworkGetEntityFromNetworkId(netId)
        if entity and DoesEntityExist(entity) then
            -- Aucun natif de réparation GTA (Set*Health, SetVehicleUndriveable,
            -- SetVehicleDeformationFixed, SetVehicleTyreFixed) n'existe côté serveur
            -- ("attempt to call a nil value") : tous délégués au mécano via 'atelier:repairResult'.

            -- Force une sauvegarde immédiate de persistent_vehicles plutôt que d'attendre le tick
            -- périodique — SAUF si une zone de déformation vient d'être validée : le client doit
            -- d'abord appliquer SetVehicleDamage (natif serveur inexistant) et redéclenchera lui-même
            -- ce rapport une fois fait, sinon la sauvegarde capturerait l'ancien cabossage.
            if not zoneFixed and LSLegacy.Event['ap:updateVehicle'] then
                LSLegacy.Event['ap:updateVehicle'](netId)
            end
        end

        if cb then cb(true, zoneFixed) end
    end)
end

-- Réconcilie notre état avec l'état réel du véhicule (GTA) ; ne remonte JAMAIS un pourcentage.
---@param snapshot table { engineHealth, bodyHealth, tyres = {[wheelIndex]=health0to1000}, doorsBroken = {[doorIndex]=bool} }
function LSLegacy.Atelier.ReconcileVehicleState(plate, snapshot)
    if not snapshot then return end
    LSLegacy.Atelier.GetVehicleState(plate, function(state)
        local changed = false

        if snapshot.engineHealth then
            local pct = ClampPercent(snapshot.engineHealth / 10)
            if pct < state.components.mechanical.moteur then
                state.components.mechanical.moteur = pct
                changed = true
            end
        end

        if snapshot.bodyHealth then
            local pct = ClampPercent(snapshot.bodyHealth / 10)
            if pct < state.components.body.carrosserie_generale then
                state.components.body.carrosserie_generale = pct
                changed = true
            end
        end

        if snapshot.tyres then
            for id, def in pairs(LSLegacy.Atelier.Components.tyres) do
                local health = snapshot.tyres[def.wheelIndex]
                if health then
                    local pct = ClampPercent(health / 10)
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

        -- Déformation par zone (avant/arrière/toit/gauche/droite, cf.
        -- shared/components.lua) : l'intensité de l'impact (même formule que la
        -- restauration AP, module/persistentvehicles) fixe un pourcentage plafond
        -- pour chaque pièce de carrosserie de cette zone, jamais remonté.
        if snapshot.deformation then
            for _, zone in ipairs(LSLegacy.Atelier.DeformationZones) do
                local intensity = snapshot.deformation[zone.id]
                if intensity and intensity > 0 then
                    local pct = ClampPercent(100 - intensity * 4)
                    for _, compId in ipairs(zone.components) do
                        if state.components.body[compId] and pct < state.components.body[compId] then
                            state.components.body[compId] = pct
                            changed = true
                        end
                    end
                end
            end
        end

        if changed then LSLegacy.Atelier.SaveVehicleState(plate) end
    end)
end

-- Dégrade les pièces mécaniques non observables nativement (freins, transmission,
-- suspension, embrayage, radiateur) au prorata du temps de conduite réelle
-- rapporté par le client (cf. client/interventions.lua) — jamais par le temps
-- calendaire, pour forcer une usure liée à l'usage.
function LSLegacy.Atelier.ApplyMechanicalWear(plate, drivenSeconds)
    if not drivenSeconds or drivenSeconds <= 0 then return end
    local lossPct = (drivenSeconds / 3600) * Config.Atelier.Wear.componentsPerHour
    if lossPct <= 0 then return end

    LSLegacy.Atelier.GetVehicleState(plate, function(state)
        local changed = false
        for id, def in pairs(LSLegacy.Atelier.Components.mechanical) do
            if not def.gta then
                local current = state.components.mechanical[id] or 100
                local updated = ClampPercent(current - lossPct)
                if updated ~= current then
                    state.components.mechanical[id] = updated
                    changed = true
                end
            end
        end
        if changed then LSLegacy.Atelier.SaveVehicleState(plate) end
    end)
end

LSLegacy.Events.Register('atelier:reportUsage', function(data)
    if not data or not data.plate then return end
    -- Borné au double de l'intervalle attendu : un client modifié ne peut pas
    -- gonfler l'usure réelle au-delà d'une marge raisonnable.
    local seconds = math.max(0, math.min(math.floor(tonumber(data.seconds) or 0), Config.Atelier.Wear.reportIntervalSeconds * 2))
    if seconds <= 0 then return end
    LSLegacy.Atelier.ApplyMechanicalWear(data.plate:upper(), seconds)
end)

-- Construit un instantané GTA-observable DIRECTEMENT depuis l'entité serveur, jamais depuis le
-- client — SAUF pneus/portières : GetTyreHealth et IsVehicleDoorDamaged n'existent que côté
-- client (crash "attempt to call a nil value" côté serveur), ces valeurs sont donc fournies par
-- l'appelant (relevées sur le client au moment de la demande de diagnostic) ; sans risque de
-- triche puisque ReconcileVehicleState ne fait jamais remonter un pourcentage déjà enregistré.
-- `deformation` (intensité par zone, cf. shared/components.lua -> DeformationZones)
-- est du même acabit que tyres/doorsBroken : GetVehicleDeformationAtPos existe
-- côté serveur mais ne reflète pas fidèlement les dégâts subis par les autres
-- joueurs (non répliqués), donc fournie par le client comme le reste.
function LSLegacy.Atelier.BuildGTASnapshot(entity, tyres, doorsBroken, deformation)
    if not DoesEntityExist(entity) then return nil end

    return {
        engineHealth = GetVehicleEngineHealth(entity),
        bodyHealth   = GetVehicleBodyHealth(entity),
        tyres        = tyres or {},
        doorsBroken  = doorsBroken or {},
        deformation  = deformation or {},
    }
end
