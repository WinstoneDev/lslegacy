local rateLimits = {
    ['fourriere:impound'] = 15, ['fourriere:requestList'] = 15,
    ['fourriere:retrieve'] = 10, ['fourriere:persistDelivered'] = 15,
    ['fourriere:towtruck:call'] = 10, ['fourriere:towtruck:cleanup'] = 15,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local CFG = Config.Fourriere
local TC  = Config.Towtruck or {}

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS fourriere (
        plate        VARCHAR(12)  NOT NULL,
        owner        VARCHAR(60)           DEFAULT NULL,
        character_id INT                   DEFAULT NULL,
        model        BIGINT                DEFAULT 0,
        props        LONGTEXT              DEFAULT NULL,
        reason       VARCHAR(255) NOT NULL DEFAULT '',
        fee          INT          NOT NULL DEFAULT 0,
        officer      VARCHAR(60)  NOT NULL DEFAULT '',
        officer_name VARCHAR(100) NOT NULL DEFAULT '',
        impounded_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        release_at   TIMESTAMP    NULL     DEFAULT NULL,
        PRIMARY KEY (plate),
        KEY idx_fourriere_owner (owner)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
MySQL.Async.execute("ALTER TABLE fourriere ADD COLUMN IF NOT EXISTS release_at TIMESTAMP NULL DEFAULT NULL", {})
-- props : snapshot du véhicule (model + tuning + status) repris de persistent_vehicles, pour un respawn à l'identique.
MySQL.Async.execute("ALTER TABLE fourriere ADD COLUMN IF NOT EXISTS props LONGTEXT DEFAULT NULL", {})
MySQL.Async.execute("ALTER TABLE fourriere ADD COLUMN IF NOT EXISTS character_id INT DEFAULT NULL", {})

local function GetPlayer(src) return LSLegacy.Players.Get(src) end

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Fourrière', msg, t or 'info', 5000)
end

local function CharName(player)
    if player and player.characterInfos then
        return ((player.characterInfos.Prenom or '') .. ' ' .. (player.characterInfos.NDF or ''))
            :gsub('^%s+', ''):gsub('%s+$', '')
    end
    return '?'
end

local function NormPlate(p)
    return (tostring(p or ''):upper():gsub('^%s+', ''):gsub('%s+$', '')):sub(1, 8)
end

local function IsCop(player)
    return LSLegacy.Jobs.Is(player, CFG.Job)
end

local function IsOnDuty(src)
    if not CFG.RequireOnDuty then return true end
    local ok, st = pcall(function() return Player(src).state.policeOnDuty end)
    return ok and st == true
end

local function ReasonInfo(label)
    for _, r in ipairs(CFG.Reasons) do
        if r.label == label then
            return math.floor(r.fee or CFG.BaseFee), math.floor(r.duration or CFG.BaseDuration)
        end
    end
    return CFG.BaseFee, CFG.BaseDuration
end

local function SetMdtLocation(plate, location, officer)
    MySQL.Async.execute([[
        INSERT INTO mdt_vehicle_flags (plate, department, location, officer_identifier)
        VALUES (@plate, @dep, @loc, @oid)
        ON DUPLICATE KEY UPDATE location=@loc, officer_identifier=@oid
    ]], { ['@plate'] = plate, ['@dep'] = CFG.Department, ['@loc'] = location, ['@oid'] = officer or '' })
end

local function PerformImpound(src, data)
    local player = GetPlayer(src)
    if not player or type(data) ~= 'table' then return end
    if not IsCop(player) then return Notify(src, 'Action réservée à la police.', 'error') end
    if not IsOnDuty(src) then return Notify(src, 'Vous devez être en service.', 'error') end

    local plate = NormPlate(data.plate)
    if plate == '' then return Notify(src, 'Plaque introuvable.', 'error') end
    local reason = tostring(data.reason or 'Autre'):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 255)
    if reason == '' then reason = 'Motif personnalisé' end
    local fee, duration
    if data.custom and CFG.AllowCustom then
        -- borné côté serveur (anti-abus)
        fee      = math.max(0, math.min(CFG.MaxFee, math.floor(tonumber(data.fee) or CFG.BaseFee)))
        duration = math.max(0, math.min(CFG.MaxDuration, math.floor(tonumber(data.duration) or CFG.BaseDuration)))
    else
        fee, duration = ReasonInfo(reason)
    end
    -- LSLegacy.AP.Active[plate] doit être nettoyé ici : sinon l'entrée obsolète bloque
    -- tout respawn ultérieur (SpawnPersistedRow la croit active, diffuse un netId mort).
    local despawn = function()
        MySQL.Async.execute('DELETE FROM persistent_vehicles WHERE UPPER(TRIM(plate))=@p', { ['@p'] = plate })
        LSLegacy.AP = LSLegacy.AP or { Active = {} }
        LSLegacy.AP.Active = LSLegacy.AP.Active or {}
        LSLegacy.AP.Active[plate] = nil
        LSLegacy.Events.SendToClient('fourriere:removeVehicle', src, { plate = plate })
        -- Notifie le module police (même ressource, appel direct) : une
        -- mission en cours peut exiger que CE véhicule soit mis en
        -- fourrière pour se clore (ex. delit_fuite / requireImpound).
        if type(_G.LSLegacy_NotifyVehicleImpounded) == 'function' then
            LSLegacy_NotifyVehicleImpounded(src, tonumber(data.netId))
        end
    end

    -- Lu AVANT le despawn (qui supprime la ligne persistent_vehicles) pour restaurer à l'identique.
    MySQL.Async.fetchAll('SELECT model, tuning, status FROM persistent_vehicles WHERE UPPER(TRIM(plate))=@p LIMIT 1',
        { ['@p'] = plate }, function(pv)
        local snapshot = nil
        if pv and pv[1] then
            local tuning = type(pv[1].tuning) == 'string' and json.decode(pv[1].tuning) or pv[1].tuning
            local status = type(pv[1].status) == 'string' and json.decode(pv[1].status) or pv[1].status
            snapshot = {
                model  = math.floor(tonumber(pv[1].model) or 0),
                tuning = type(tuning) == 'table' and tuning or {},
                status = type(status) == 'table' and status or {},
            }
        end

        -- owned_vehicles ne porte que la possession : modèle/tuning viennent de persistent_vehicles.
        MySQL.Async.fetchAll('SELECT owner, character_id FROM owned_vehicles WHERE UPPER(plate)=@p LIMIT 1',
            { ['@p'] = plate }, function(rows)
            if rows and rows[1] then
                local owner = rows[1].owner
                local charId = rows[1].character_id
                if not snapshot then snapshot = { model = 0, tuning = {}, status = {} } end
                local model = snapshot.model or 0

                MySQL.Async.execute([[
                    INSERT INTO fourriere (plate, owner, character_id, model, props, reason, fee, officer, officer_name, release_at)
                    VALUES (@plate, @owner, @charId, @model, @props, @reason, @fee, @officer, @oname, DATE_ADD(NOW(), INTERVAL @dur MINUTE))
                    ON DUPLICATE KEY UPDATE owner=@owner, character_id=@charId, model=@model, props=@props,
                                            reason=@reason, fee=@fee, officer=@officer, officer_name=@oname,
                                            impounded_at=CURRENT_TIMESTAMP,
                                            release_at=DATE_ADD(NOW(), INTERVAL @dur MINUTE)
                ]], {
                    ['@plate'] = plate, ['@owner'] = owner, ['@charId'] = charId, ['@model'] = model,
                    ['@props'] = json.encode(snapshot),
                    ['@reason'] = reason, ['@fee'] = fee, ['@dur'] = duration,
                    ['@officer'] = player.identifier, ['@oname'] = CharName(player),
                }, function()
                    SetMdtLocation(plate, 'fourriere', player.identifier)
                    despawn()
                    Notify(src, ('Véhicule %s mis en fourrière (%d $ · %d min).'):format(plate, fee, duration), 'success')
                end)
            else
                despawn()
                Notify(src, ('Véhicule %s non immatriculé — retiré de la voie.'):format(plate), 'success')
            end
        end)
    end)
end

LSLegacy.Events.Register('fourriere:impound', function(data)
    PerformImpound(source, data)
end)

--  DÉPANNEUSE NPC
-- Convoi qui vient accrocher le véhicule visé avant sa mise en fourrière
-- effective (PerformImpound, déclenchée par le client à l'arrivée sur site).

local Towtrucks = {}        -- { [id] = { entities = {truck, driver}, targetNetId, src } }
local TowtruckSeq = 0
local TowtruckByNetId = {}  -- verrou anti-double-convoi par véhicule

local function TowLog(src, fmt, ...)
    local msg = select('#', ...) > 0 and fmt:format(...) or fmt
    if TC.Debug then print('^3[fourriere:towtruck]^7 ' .. msg) end
    if src and src ~= 0 then LSLegacy.Events.SendToClient('fourriere:towtruckDebug', src, msg) end
end

local function ClearTowtruck(id)
    local t = Towtrucks[id]
    if not t then return end
    Towtrucks[id] = nil
    if t.targetNetId then TowtruckByNetId[t.targetNetId] = nil end
    for _, e in ipairs(t.entities or {}) do
        if DoesEntityExist(e) then DeleteEntity(e) end
    end
end

local function CountTowtrucks()
    local n = 0
    for _ in pairs(Towtrucks) do n = n + 1 end
    return n
end

-- Sans ça, un redémarrage de ressource laisse dépanneuses/chauffeurs en
-- jeu : les entités serveur ne sont pas supprimées automatiquement.
AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    for id in pairs(Towtrucks) do ClearTowtruck(id) end
end)

LSLegacy.Events.Register('fourriere:towtruck:call', function(data)
    local src = source
    TowLog(src, 'Requête reçue — netId=%s plate=%s', tostring(data and data.netId), tostring(data and data.plate))

    local player = GetPlayer(src)
    if not player or type(data) ~= 'table' then
        TowLog(src, 'Rejeté : joueur introuvable ou payload invalide.')
        return
    end
    if not IsCop(player) then
        TowLog(src, 'Rejeté : pas policier.')
        return Notify(src, 'Action réservée à la police.', 'error')
    end
    if not IsOnDuty(src) then
        TowLog(src, 'Rejeté : hors service.')
        return Notify(src, 'Vous devez être en service.', 'error')
    end

    if not TC.Enabled then
        TowLog(src, 'Config.Towtruck.Enabled = false — mise en fourrière directe.')
        return PerformImpound(src, data)
    end

    local netId = tonumber(data.netId)
    local veh = netId and NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        TowLog(src, 'Rejeté : véhicule introuvable pour netId=%s.', tostring(netId))
        return Notify(src, 'Véhicule introuvable.', 'error')
    end
    if TowtruckByNetId[netId] then
        TowLog(src, 'Rejeté : convoi #%s déjà actif pour ce véhicule.', tostring(TowtruckByNetId[netId]))
        return Notify(src, 'Une dépanneuse est déjà en route pour ce véhicule.', 'warning')
    end
    if CountTowtrucks() >= (TC.MaxConcurrent or 5) then
        TowLog(src, 'Rejeté : %d/%d convois déjà actifs.', CountTowtrucks(), TC.MaxConcurrent or 5)
        return Notify(src, 'Toutes les dépanneuses sont occupées, réessayez plus tard.', 'error')
    end
    if GetEntitySpeed(veh) > 0.5 then
        TowLog(src, 'Rejeté : véhicule en mouvement (%.2f m/s).', GetEntitySpeed(veh))
        return Notify(src, "Le véhicule doit être à l'arrêt.", 'error')
    end
    -- GetVehicleNumberOfPassengers n'existe pas côté serveur (client-only) —
    -- on parcourt les sièges à la place (0..7 couvre tout sauf les bus).
    local occupied = GetPedInVehicleSeat(veh, -1) ~= 0
    if not occupied then
        for seat = 0, 7 do
            local ok, ped = pcall(GetPedInVehicleSeat, veh, seat)
            if ok and ped ~= 0 then occupied = true break end
        end
    end
    if occupied then
        TowLog(src, 'Rejeté : véhicule occupé.')
        return Notify(src, 'Le véhicule est occupé.', 'error')
    end

    TowLog(src, 'Contrôles OK — construction du convoi…')

    -- La demande d'enlèvement suffit à valider une mission requireImpound
    -- (delit_fuite) : l'agent n'a plus à attendre l'arrivée effective du
    -- véhicule en fourrière, seulement à avoir déclenché la procédure.
    if type(_G.LSLegacy_NotifyVehicleImpounded) == 'function' then
        LSLegacy_NotifyVehicleImpounded(src, netId)
    end

    local vc  = GetEntityCoords(veh)
    local ang = math.random() * math.pi * 2
    local dist = TC.SpawnDist or 110.0
    local sx, sy = vc.x + math.cos(ang) * dist, vc.y + math.sin(ang) * dist

    local function NetIdOf(entity)
        if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
        local ok, id = pcall(NetworkGetNetworkIdFromEntity, entity)
        return (ok and id and id ~= 0) and id or nil
    end
    local function Settle(entity)
        for _ = 1, 20 do
            if entity and entity ~= 0 and DoesEntityExist(entity) then
                local id = NetIdOf(entity)
                if id then return id end
            end
            Wait(50)
        end
        return nil
    end

    local truck = CreateVehicle(GetHashKey(TC.Model or 'towtruck'),
        sx, sy, vc.z + 1.0, math.deg(ang) + 180.0, true, true)
    local truckNet = Settle(truck)
    if not truckNet then
        TowLog(src, 'Dépanneuse non enregistrée sur le réseau — mise en fourrière directe.')
        if truck and truck ~= 0 and DoesEntityExist(truck) then DeleteEntity(truck) end
        return PerformImpound(src, data)
    end
    pcall(SetEntityDistanceCullingRadius, truck, 500.0)

    local driver = CreatePed(4, GetHashKey(TC.Driver or 's_m_y_construct_01'),
        sx, sy, vc.z + 1.0, 0.0, true, true)
    local driverNet = Settle(driver)
    if not driverNet then
        TowLog(src, 'Chauffeur non enregistré — mise en fourrière directe.')
        if truck and DoesEntityExist(truck) then DeleteEntity(truck) end
        if driver and driver ~= 0 and DoesEntityExist(driver) then DeleteEntity(driver) end
        return PerformImpound(src, data)
    end
    pcall(SetEntityDistanceCullingRadius, driver, 500.0)

    TowtruckSeq = TowtruckSeq + 1
    local id = TowtruckSeq
    Towtrucks[id] = { entities = { truck, driver }, targetNetId = netId, src = src }
    TowtruckByNetId[netId] = id

    local lifespan = (TC.ApproachTimeout or 45000) + (TC.TravelTimeout or 60000)
        + ((TC.Cleanup or 45) * 1000) + 60000
    SetTimeout(lifespan, function() ClearTowtruck(id) end)

    TowLog(src, 'Convoi #%d créé pour %s.', id, tostring(data.plate))
    Notify(src, 'Dépanneuse en route.', 'info')

    -- Diffusé à TOUS les joueurs (-1) : le convoi doit être visible pour
    -- tout le monde, pas seulement l'agent qui l'a demandé. `driver` dit
    -- à chaque client si c'est lui qui pilote (seul l'agent demandeur
    -- exécute la logique de conduite/accroche — les autres se contentent
    -- de voir les entités, déjà synchronisées par le réseau).
    LSLegacy.Events.SendToClient('fourriere:towtruck', -1, {
        id = id, truckNet = truckNet, driverNet = driverNet, targetNet = netId,
        dest = TC.Delivery
            and { x = TC.Delivery.x, y = TC.Delivery.y, z = TC.Delivery.z, h = TC.Delivery.h }
            or { x = CFG.Ped.coords.x, y = CFG.Ped.coords.y, z = CFG.Ped.coords.z },
        driver = src,
        impound = data,
    })
end)

-- Nettoyage du convoi (dépanneuse + chauffeur) une fois la fourrière
-- effective déclenchée côté client. Le véhicule accroché n'est PAS listé
-- dans entities : sa suppression passe par fourriere:removeVehicle
-- (recherche par plaque), déclenchée par PerformImpound.
LSLegacy.Events.Register('fourriere:towtruck:cleanup', function(id)
    local src = source
    local t = Towtrucks[tonumber(id or 0)]
    if not t or t.src ~= src then return end
    ClearTowtruck(tonumber(id))
end)

LSLegacy.Events.Register('fourriere:requestList', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    MySQL.Async.fetchAll([[
        SELECT plate, model, props, reason, fee,
               GREATEST(TIMESTAMPDIFF(SECOND, NOW(), release_at), 0) AS remaining_sec
        FROM fourriere WHERE character_id=@charId ORDER BY impounded_at DESC
    ]], { ['@charId'] = player["boutique-id"] }, function(rows)
        LSLegacy.Events.SendToClient('fourriere:list', src, rows or {})
    end)
end)

-- Re-spawn via persistence : ré-insertion dans persistent_vehicles puis LSLegacy.AP.SpawnPersistedRow.
-- token -> { src, player, plate, rec }
local PendingRetrievals = {}

local function ReleaseVehicle(src, player, plate, rec)
    MySQL.Async.execute('DELETE FROM fourriere WHERE plate=@p', { ['@p'] = plate })
    SetMdtLocation(plate, 'circulation', player.identifier)

    local snap = nil
    if rec.props then
        local ok, decoded = pcall(json.decode, rec.props)
        if ok and type(decoded) == 'table' then snap = decoded end
    end
    local model  = math.floor(tonumber((snap and snap.model) or rec.model) or 0)
    local tuning = (snap and type(snap.tuning) == 'table') and snap.tuning or {}
    local status = (snap and type(snap.status) == 'table') and snap.status or {}

    local position = { x = CFG.Spawn.x, y = CFG.Spawn.y, z = CFG.Spawn.z, h = CFG.Spawn.h }
    MySQL.Async.execute([[
        INSERT INTO persistent_vehicles (plate, model, position, status, tuning, trailer_plate, state_bags)
        VALUES (@plate, @model, @position, @status, @tuning, NULL, '{}')
        ON DUPLICATE KEY UPDATE model=@model, position=@position, status=@status, tuning=@tuning
    ]], {
        ['@plate'] = plate, ['@model'] = model,
        ['@position'] = json.encode(position),
        ['@status']   = json.encode(status),
        ['@tuning']   = json.encode(tuning),
    })
    LSLegacy.AP.SpawnPersistedRow({
        plate = plate, model = model,
        position = json.encode(position),
        status = json.encode(status),
        tuning = json.encode(tuning),
        state_bags = '{}',
    }, src)
end

LSLegacy.Bank.RegisterPaymentResultHandler('fourriere', function(token, success)
    local pending = PendingRetrievals[token]
    if not pending then return end
    PendingRetrievals[token] = nil
    if not success then
        Notify(pending.src, 'Paiement refusé, véhicule toujours en fourrière.', 'error')
        return
    end
    ReleaseVehicle(pending.src, pending.player, pending.plate, pending.rec)
end)

LSLegacy.Events.Register('fourriere:retrieve', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player or type(data) ~= 'table' then return end
    local plate = NormPlate(data.plate)

    MySQL.Async.fetchAll([[
        SELECT owner, character_id, model, props, fee,
               GREATEST(TIMESTAMPDIFF(SECOND, NOW(), release_at), 0) AS remaining_sec
        FROM fourriere WHERE plate=@p LIMIT 1
    ]], { ['@p'] = plate }, function(rows)
        if not rows or not rows[1] then return Notify(src, 'Véhicule introuvable en fourrière.', 'error') end
        local rec = rows[1]
        if rec.character_id ~= player["boutique-id"] then return Notify(src, "Ce n'est pas votre véhicule.", 'error') end
        local remaining = math.floor(tonumber(rec.remaining_sec) or 0)
        if remaining > 0 then
            local mins = math.ceil(remaining / 60)
            return Notify(src, ('Véhicule encore immobilisé (%d min restantes).'):format(mins), 'error')
        end
        local fee = math.floor(tonumber(rec.fee) or CFG.BaseFee)

        local token = ('fourriere_%d_%d'):format(src, math.random(100000, 999999))
        PendingRetrievals[token] = { src = src, player = player, plate = plate, rec = rec }
        Citizen.SetTimeout(120000, function() PendingRetrievals[token] = nil end)
        LSLegacy.Bank.OpenPaymentMenu(src, 'Fourrière - ' .. plate, fee, { meta = { type = 'fourriere', refId = token } })
    end)
end)
