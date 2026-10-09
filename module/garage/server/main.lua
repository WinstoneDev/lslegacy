--  MODULE GARAGE — Serveur
--  Garages instanciés (buckets), garages extérieurs (véhicule figé sur place),
--  créateur, clés de garage, serrurier, journal d'accès, API propriétés.
local C = Config.Garage
LSLegacy.Garage = LSLegacy.Garage or {}
local G = LSLegacy.Garage

local rateLimits = {
    ['garage:requestSync'] = 5, ['garage:store'] = 10, ['garage:takeout'] = 10,
    ['garage:enter'] = 10, ['garage:leave'] = 10, ['garage:moveSlot'] = 10,
    ['garage:locksmithList'] = 5, ['garage:locksmithDuplicate'] = 5,
    ['garage:create'] = 5, ['garage:update'] = 5, ['garage:delete'] = 5, ['garage:giveKey'] = 5,
    ['garage:addFleetVehicle'] = 5, ['garage:getSlots'] = 20, ['garage:getOwners'] = 5,
    ['garage:getPlayerInfo'] = 10, ['garage:requestVisuals'] = 10, ['mdtgarage:query'] = 20,
    ['garage:creatorInstance'] = 10,
}
for name, limit in pairs(rateLimits) do LSLegacy.Security.RegisterRateLimit(name, limit) end

-- ── BDD ────────────────────────────────────────────────────────────
MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS garages (
        id             INT AUTO_INCREMENT PRIMARY KEY,
        name           VARCHAR(60)  NOT NULL,
        type           VARCHAR(10)  NOT NULL DEFAULT 'exterior',
        owner_type     VARCHAR(10)  NOT NULL DEFAULT 'public',
        owner_id       VARCHAR(60)  DEFAULT NULL,
        owner_name     VARCHAR(100) DEFAULT NULL,
        property_id    VARCHAR(60)  DEFAULT NULL,
        entrance       LONGTEXT     NOT NULL,
        exit_spawn     LONGTEXT     DEFAULT NULL,
        interior_spawn LONGTEXT     DEFAULT NULL,
        interior_exit  LONGTEXT     DEFAULT NULL,
        slots          LONGTEXT     NOT NULL DEFAULT '[]',
        blip           TINYINT(1)   NOT NULL DEFAULT 1,
        created_at     TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
        KEY idx_garages_owner (owner_type, owner_id),
        KEY idx_garages_property (property_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS garage_logs (
        id           INT AUTO_INCREMENT PRIMARY KEY,
        garage_id    INT NOT NULL,
        plate        VARCHAR(12) NOT NULL,
        character_id INT DEFAULT NULL,
        name         VARCHAR(100) DEFAULT NULL,
        action       VARCHAR(20) NOT NULL,
        created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        KEY idx_garage_logs_garage (garage_id, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})
-- garage : id du garage où le véhicule est rangé ; garage_stored = 1 si hors
-- monde (intérieur, ignoré par l'AP), 0 si figé sur une place extérieure.
MySQL.Async.execute("ALTER TABLE garages ADD COLUMN IF NOT EXISTS interior VARCHAR(40) DEFAULT NULL", {})
-- Marker d'entrée alternatif pour les poids lourds (place 'heavy') : certains
-- garages ont une entrée standard trop étroite pour y faire rentrer un camion.
MySQL.Async.execute("ALTER TABLE garages ADD COLUMN IF NOT EXISTS heavy_entrance LONGTEXT DEFAULT NULL", {})
MySQL.Async.execute("ALTER TABLE persistent_vehicles ADD COLUMN IF NOT EXISTS garage INT DEFAULT NULL", {})
MySQL.Async.execute("ALTER TABLE persistent_vehicles ADD COLUMN IF NOT EXISTS garage_slot INT DEFAULT NULL", {})
MySQL.Async.execute("ALTER TABLE persistent_vehicles ADD COLUMN IF NOT EXISTS garage_stored TINYINT(1) NOT NULL DEFAULT 0", {})
MySQL.Async.execute("ALTER TABLE persistent_vehicles ADD COLUMN IF NOT EXISTS last_garage INT DEFAULT NULL", {})

-- ── Cache ──────────────────────────────────────────────────────────
local Garages = {}          -- [id] = row décodée
local Instances = {}        -- [id] = { players = {src=true}, vehicles = {plate=entity} }
local PlayerInstance = {}   -- [src] = garageId

local function DecodeRow(row)
    local g = {
        id = row.id, name = row.name, type = row.type, owner_type = row.owner_type,
        owner_id = row.owner_id, owner_name = row.owner_name, property_id = row.property_id,
        interior = row.interior,
        entrance = json.decode(row.entrance or '{}'),
        heavy_entrance = row.heavy_entrance and json.decode(row.heavy_entrance) or nil,
        exit_spawn = row.exit_spawn and json.decode(row.exit_spawn) or nil,
        interior_spawn = row.interior_spawn and json.decode(row.interior_spawn) or nil,
        interior_exit = row.interior_exit and json.decode(row.interior_exit) or nil,
        slots = json.decode(row.slots or '[]'),
        blip = tonumber(row.blip) == 1 or row.blip == true,
    }
    return g
end

local function LoadGarages()
    local rows = MySQL.Sync.fetchAll('SELECT * FROM garages', {})
    Garages = {}
    for _, row in ipairs(rows or {}) do Garages[row.id] = DecodeRow(row) end
end
LoadGarages()

local function PublicList()
    local out = {}
    for _, g in pairs(Garages) do out[#out + 1] = g end
    return out
end

local function Broadcast(target)
    LSLegacy.Events.SendToClient('garage:sync', target or -1, PublicList())
end

-- ── Helpers joueur ─────────────────────────────────────────────────
local function GetPlayer(src) return LSLegacy.Players.Get(src) end
local function CharId(p) return p and tonumber(p['boutique-id']) or nil end
local function CharName(p)
    local ci = p and p.characterInfos or {}
    return ((ci.Prenom or '') .. ' ' .. (ci.Nom or '')):gsub('^%s+', ''):gsub('%s+$', '')
end
local function Notify(src, msg, t) LSLegacy.Events.SendToClient('notify', src, 'Garage', msg, t or 'info', 5000) end
local function Trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

local function HasGarageKey(p, garageId)
    for _, it in pairs(p.inventory or {}) do
        if it.name == C.KeyItem and it.data and tonumber(it.data.garage) == garageId then return true end
    end
    return false
end

local function HasVehicleKey(p, plate)
    plate = Trim(plate)
    for _, it in pairs(p.inventory or {}) do
        if it.name == C.VehicleKeyItem and it.data and Trim(it.data.plate) == plate then return true end
    end
    return false
end

local function RemoveVehicleKeys(p, plate)
    plate = Trim(plate)
    local toRemove = {}
    for _, it in pairs(p.inventory or {}) do
        if it.name == C.VehicleKeyItem and it.data and Trim(it.data.plate) == plate then
            toRemove[#toRemove + 1] = { count = it.count, label = it.label, uid = it.uniqueId }
        end
    end
    for _, r in ipairs(toRemove) do
        LSLegacy.Inventory.RemoveItemInInventory(p, C.VehicleKeyItem, r.count, r.label, r.uid)
    end
end

local function GetOwnedRow(plate)
    local rows = MySQL.Sync.fetchAll('SELECT owner, character_id, job, type FROM owned_vehicles WHERE plate=@p LIMIT 1', { ['@p'] = plate })
    return rows and rows[1] or nil
end

local function GetPersistedRow(plate)
    local rows = MySQL.Sync.fetchAll('SELECT * FROM persistent_vehicles WHERE plate=@p LIMIT 1', { ['@p'] = plate })
    return rows and rows[1] or nil
end

-- ── Accès ──────────────────────────────────────────────────────────
function G.CanAccess(p, g)
    if not p or not g then return false end
    if g.owner_type == 'public' then return true end
    if g.owner_type == 'job' then return p.job == g.owner_id end
    if g.owner_type == 'faction' then return p.faction == g.owner_id end
    if g.owner_type == 'personal' then
        return tostring(CharId(p)) == tostring(g.owner_id) or HasGarageKey(p, g.id)
    end
    return false
end

-- Véhicule d'entreprise : dans un garage job, tout véhicule sans propriétaire
-- personnel (flotte, achat entreprise, ancien véhicule de service sans ligne owned).
local function IsJobVehicle(g, owned)
    if g.owner_type ~= 'job' then return false end
    if not owned then return true end
    if owned.job and owned.job ~= '' then return owned.job == g.owner_id end
    local noChar = owned.character_id == nil or tostring(owned.character_id) == ''
    local noOwner = owned.owner == nil or owned.owner == ''
    return noChar and noOwner
end

-- Rangement : accès au garage suffit. Un véhicule d'entreprise ne se range
-- que dans un garage de son entreprise.
local function CanStore(p, g, owned)
    if not G.CanAccess(p, g) then return false, "Vous n'avez pas accès à ce garage." end
    if owned and owned.job and owned.job ~= '' and not (g.owner_type == 'job' and g.owner_id == owned.job) then
        return false, "Ce véhicule d'entreprise doit être rangé dans le garage de son entreprise."
    end
    return true
end

-- Sortie : véhicule d'entreprise → job suffit ; sinon clé ou propriétaire.
local function CanTake(p, g, plate, owned)
    if not G.CanAccess(p, g) then return false, "Vous n'avez pas accès à ce garage." end
    if IsJobVehicle(g, owned) then return true, true end
    if owned and tostring(owned.character_id) == tostring(CharId(p)) then return true, false end
    if HasVehicleKey(p, plate) then return true, false end
    return false, "Vous n'avez pas la clé de ce véhicule."
end

-- ── Places ─────────────────────────────────────────────────────────
local function SlotDef(typeId)
    for _, s in ipairs(C.SlotTypes) do if s.id == typeId then return s end end
    return C.SlotTypes[1]
end

local function SlotAccepts(slot, vtype)
    return SlotDef(slot.type or 'car').accepts[vtype] == true
end

-- Type serveur du véhicule (GetVehicleType) affiné par la classe client (poids lourd).
local function VehicleTypeOf(entity, clientClass)
    local vt = GetVehicleType(entity)
    if vt == 'bike' or vt == 'bicycle' then return 'moto' end
    if vt == 'heli' or vt == 'plane' or vt == 'blimp' then return 'heli' end
    local mapped = C.ClassToType[tonumber(clientClass) or -1]
    if mapped == 'heavy' then return 'heavy' end
    return 'car'
end

-- Occupation : [slotIndex] = plate
local function GetOccupancy(garageId)
    local rows = MySQL.Sync.fetchAll('SELECT plate, garage_slot, model FROM persistent_vehicles WHERE garage=@g', { ['@g'] = garageId })
    local occ = {}
    for _, r in ipairs(rows or {}) do if r.garage_slot then occ[r.garage_slot] = r end end
    return occ
end

local function FindFreeSlot(g, occ, vtype, wanted)
    if wanted then
        local s = g.slots[wanted]
        if s and not occ[wanted] and SlotAccepts(s, vtype) then return wanted end
        return nil
    end
    for i, s in ipairs(g.slots) do
        if not occ[i] and SlotAccepts(s, vtype) then return i end
    end
    return nil
end

-- ── Journal ────────────────────────────────────────────────────────
local function Log(g, plate, p, action)
    MySQL.Async.execute('INSERT INTO garage_logs (garage_id, plate, character_id, name, action) VALUES (@g,@p,@c,@n,@a)', {
        ['@g'] = g.id, ['@p'] = plate, ['@c'] = CharId(p), ['@n'] = CharName(p), ['@a'] = action,
    })
    local hook = GetConvar(C.Webhook, '')
    if hook == '' then return end
    PerformHttpRequest(hook, function() end, 'POST', json.encode({ embeds = {{
        title = ('[GARAGE] %s'):format(action == 'store' and 'Véhicule rangé' or action == 'takeout' and 'Véhicule sorti' or action),
        description = ('**Garage :** %s (#%d)\n**Plaque :** %s\n**Joueur :** %s (%s)'):format(g.name, g.id, plate, CharName(p), tostring(CharId(p))),
        color = 10181046,
        footer = { text = 'LSLegacy Garage • ' .. os.date('%d/%m/%Y %H:%M:%S') },
    }} }), { ['Content-Type'] = 'application/json' })
end

-- ── Instances ──────────────────────────────────────────────────────
local function BucketOf(g) return C.BucketOffset + g.id end

-- Copie conforme d'une ligne persistent_vehicles dans l'instance : même
-- séquence serveur que LSLegacy.AP.SpawnVehicle (plaque, santé carrosserie,
-- saleté, statebags), le tuning/dégâts étant rejoués côté client via
-- ap:vehicleSpawned (SendVisuals) exactement comme pour l'AP.
local function SpawnInstanceVehicle(g, inst, row)
    local slot = g.slots[row.garage_slot]
    if not slot then return end
    local veh = CreateVehicle(row.model, slot.x, slot.y, slot.z, slot.h or 0.0, true, true)
    local t = 0
    while not DoesEntityExist(veh) and t < 50 do Wait(100); t = t + 1 end
    if not DoesEntityExist(veh) then return end
    -- KeepEntity : jamais supprimé par le serveur faute de joueur à proximité
    -- (cause du "premier véhicule qui ne réapparaît pas")
    if SetEntityOrphanMode then SetEntityOrphanMode(veh, 2) end
    SetEntityRoutingBucket(veh, BucketOf(g))
    local status = type(row.status) == 'string' and json.decode(row.status) or row.status or {}
    local tuning = type(row.tuning) == 'string' and json.decode(row.tuning) or row.tuning or {}
    local bags = type(row.state_bags) == 'string' and row.state_bags ~= '' and json.decode(row.state_bags) or {}
    SetVehicleNumberPlateText(veh, row.plate)
    Entity(veh).state:set('plate', row.plate, true)
    SetVehicleBodyHealth(veh, status.body or 1000.0)
    SetVehicleDirtLevel(veh, status.dirt or 0.0)
    SetVehicleDoorsLocked(veh, 2)
    FreezeEntityPosition(veh, true)
    if LSLegacy.AP.ApplyServerColours then LSLegacy.AP.ApplyServerColours(veh, tuning) end
    if bags.handbrake ~= nil then Entity(veh).state:set('handbrake', bags.handbrake, true) end
    Entity(veh).state:set('fuelLevel', bags.fuelLevel or status.fuel or 50.0, true)
    Entity(veh).state:set('garageVeh', { garage = g.id, slot = row.garage_slot, plate = row.plate, mode = 'interior' }, true)
    inst.vehicles[row.plate] = { entity = veh, row = row, status = status, tuning = tuning, fuel = bags.fuelLevel or status.fuel or 50.0 }
end

-- Rejoue le payload AP (tuning/dégâts) pour un client donné (toutes les plaques ou une seule)
local function SendVisuals(src, inst, onlyPlate)
    for plate, v in pairs(inst.vehicles) do
        if (not onlyPlate or onlyPlate == plate) and DoesEntityExist(v.entity) then
            local status = v.status
            LSLegacy.Events.SendToClient('ap:vehicleSpawned', src, {
                netId = NetworkGetNetworkIdFromEntity(v.entity), plate = plate,
                extras = status.extras or {}, tankHealth = status.tank or 1000.0,
                engineHealth = status.engine or 1000.0, tuning = v.tuning,
                fuel = v.fuel, status = status,
            })
        end
    end
end

-- Recrée les véhicules attendus dont l'entité a disparu (auto-réparation)
local function HealInstance(g, inst)
    local rows = MySQL.Sync.fetchAll('SELECT * FROM persistent_vehicles WHERE garage=@g AND garage_stored=1', { ['@g'] = g.id })
    local expected = {}
    for _, row in ipairs(rows or {}) do
        expected[row.plate] = true
        local v = inst.vehicles[row.plate]
        if not v or not DoesEntityExist(v.entity) then SpawnInstanceVehicle(g, inst, row) end
    end
    for plate, v in pairs(inst.vehicles) do
        if not expected[plate] then
            if DoesEntityExist(v.entity) then DeleteEntity(v.entity) end
            inst.vehicles[plate] = nil
        end
    end
end

local function EnsureInstance(g)
    local inst = Instances[g.id]
    if not inst then
        inst = { players = {}, vehicles = {} }
        Instances[g.id] = inst
    end
    HealInstance(g, inst)
    return inst
end

local function DestroyInstanceIfEmpty(id)
    local inst = Instances[id]
    if not inst or next(inst.players) then return end
    for _, v in pairs(inst.vehicles) do
        if DoesEntityExist(v.entity) then DeleteEntity(v.entity) end
    end
    Instances[id] = nil
end

function G.Enter(src, g)
    if not g or g.type ~= 'interior' or not g.interior_spawn then return false end
    -- le joueur rejoint le bucket AVANT le spawn : les entités serveur ont ainsi
    -- toujours un client candidat pour être créées et streamées
    PlayerInstance[src] = g.id
    SetPlayerRoutingBucket(src, BucketOf(g))
    LSLegacy.Pickup.SyncBucket(src, BucketOf(g))
    local inst = EnsureInstance(g)
    inst.players[src] = true
    LSLegacy.Events.SendToClient('garage:enterInstance', src, { garage = g.id, spawn = g.interior_spawn, interior = g.interior })
    return true
end

function G.Leave(src, teleport)
    local id = PlayerInstance[src]
    if not id then return end
    local g = Garages[id]
    PlayerInstance[src] = nil
    if Instances[id] then Instances[id].players[src] = nil end
    SetPlayerRoutingBucket(src, 0)
    LSLegacy.Pickup.SyncBucket(src, 0)
    if teleport and g then LSLegacy.Events.SendToClient('garage:leftInstance', src, { coords = g.entrance }) end
    DestroyInstanceIfEmpty(id)
end

-- Éjecte à l'entrée tous les joueurs présents dans l'instance d'un garage intérieur
-- (sauf exceptSrc) : appelé chaque fois qu'un véhicule en sort (takeout, voiturier)
-- pour empêcher qu'un joueur resté dedans interagisse avec la même plaque en même
-- temps (fenêtre de duplication entre la suppression de l'entité et la MAJ BDD).
function G.KickInstance(g, exceptSrc)
    if not g or g.type ~= 'interior' then return end
    local inst = Instances[g.id]
    if not inst then return end
    for src in pairs(inst.players) do
        if src ~= exceptSrc then G.Leave(src, true) end
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    if PlayerInstance[src] then G.Leave(src, false) end
end)

-- ── Extérieur : figer / libérer via statebag + natives serveur ─────
local function FreezeExterior(entity, g, slotIndex, plate)
    FreezeEntityPosition(entity, true)
    SetVehicleDoorsLocked(entity, 2)
    Entity(entity).state:set('garageVeh', { garage = g.id, slot = slotIndex, plate = plate, mode = 'exterior' }, true)
end

local function ReleaseExterior(entity)
    FreezeEntityPosition(entity, false)
    SetVehicleDoorsLocked(entity, 1)
    Entity(entity).state:set('garageVeh', nil, true)
end

-- Après reboot : l'AP respawn les véhicules extérieurs, on leur remet l'état figé.
CreateThread(function()
    while true do
        Wait(15000)
        local rows = MySQL.Sync.fetchAll('SELECT plate, garage, garage_slot FROM persistent_vehicles WHERE garage IS NOT NULL AND garage_stored=0', {})
        for _, r in ipairs(rows or {}) do
            local a = LSLegacy.AP.Active[r.plate]
            local g = Garages[r.garage]
            if a and a.entity and DoesEntityExist(a.entity) and g then
                local st = Entity(a.entity).state.garageVeh
                if not st then
                    local slot = g.slots[r.garage_slot]
                    if slot then
                        SetEntityCoords(a.entity, slot.x, slot.y, slot.z)
                        SetEntityHeading(a.entity, slot.h or 0.0)
                    end
                    FreezeExterior(a.entity, g, r.garage_slot, r.plate)
                end
            end
        end
    end
end)

-- ── Sync client ────────────────────────────────────────────────────
LSLegacy.Events.Register('garage:requestSync', function()
    local src = source
    if not GetPlayer(src) then return end
    Broadcast(src)
end)

LSLegacy.Callbacks.RegisterServer('garage:getSlots', function(src, cb, garageId)
    local p = GetPlayer(src)
    local g = Garages[tonumber(garageId) or -1]
    if not p or not g or not G.CanAccess(p, g) then return cb(nil) end
    local occ = GetOccupancy(g.id)
    local out = {}
    for i, s in ipairs(g.slots) do
        out[i] = { type = s.type or 'car', plate = occ[i] and occ[i].plate or nil, model = occ[i] and occ[i].model or nil }
    end
    cb(out)
end)

LSLegacy.Events.Register('garage:requestVisuals', function(plate)
    local src = source
    local id = PlayerInstance[src]
    if id and Instances[id] then SendVisuals(src, Instances[id], type(plate) == 'string' and plate or nil) end
end)

-- ── Entrer / sortir à pied ─────────────────────────────────────────
LSLegacy.Events.Register('garage:enter', function(garageId)
    local src = source
    local p = GetPlayer(src)
    local g = Garages[tonumber(garageId) or -1]
    if not p or not g or g.type ~= 'interior' then return end
    if not G.CanAccess(p, g) then return Notify(src, "Vous n'avez pas accès à ce garage.", 'error') end
    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - vector3(g.entrance.x, g.entrance.y, g.entrance.z)) > C.EntranceRadius + 3.0 then return end
    G.Enter(src, g)
end)

LSLegacy.Events.Register('garage:leave', function()
    G.Leave(source, true)
end)

-- ── Ranger ─────────────────────────────────────────────────────────
LSLegacy.Events.Register('garage:store', function(data)
    local src = source
    local p = GetPlayer(src)
    if not p or type(data) ~= 'table' then return end
    local g = Garages[tonumber(data.garage) or -1]
    if not g then return end
    local entity = NetworkGetEntityFromNetworkId(tonumber(data.netId) or 0)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return Notify(src, 'Véhicule introuvable.', 'error') end
    local plate = Trim(GetVehicleNumberPlateText(entity))
    local ped = GetPlayerPed(src)
    -- Le marker "poids lourd" (s'il existe) est un point de rangement valide
    -- au même titre que l'entrée standard.
    local distEntrance = #(GetEntityCoords(ped) - vector3(g.entrance.x, g.entrance.y, g.entrance.z))
    local distHeavy = g.heavy_entrance and #(GetEntityCoords(ped) - vector3(g.heavy_entrance.x, g.heavy_entrance.y, g.heavy_entrance.z)) or nil
    if distEntrance > C.EntranceRadius + 4.0 and (not distHeavy or distHeavy > C.EntranceRadius + 4.0) then return end
    if #(GetEntityCoords(entity) - GetEntityCoords(ped)) > 12.0 then return end
    if GetPedInVehicleSeat(entity, -1) ~= 0 then return Notify(src, 'Le véhicule doit être vide.', 'error') end

    local row = GetPersistedRow(plate)
    if not row or not LSLegacy.AP.Active[plate] then return Notify(src, "Ce véhicule n'est pas immatriculé, impossible de le ranger.", 'error') end
    if row.garage then return Notify(src, 'Ce véhicule est déjà garé.', 'error') end
    local owned = GetOwnedRow(plate)
    local ok, err = CanStore(p, g, owned)
    if not ok then return Notify(src, err, 'error') end

    local vtype = VehicleTypeOf(entity, data.class)
    local occ = GetOccupancy(g.id)
    local slotIndex = FindFreeSlot(g, occ, vtype, tonumber(data.slot))
    if not slotIndex then return Notify(src, 'Aucune place libre adaptée à ce véhicule.', 'error') end
    local slot = g.slots[slotIndex]

    -- Snapshot à jour avant tout (tuning/dégâts/carburant)
    if LSLegacy.AP.SaveVehicleNow then LSLegacy.AP.SaveVehicleNow(entity) end

    if g.type == 'interior' then
        LSLegacy.AP.Active[plate] = nil
        DeleteEntity(entity)
        MySQL.Sync.execute('UPDATE persistent_vehicles SET garage=@g, garage_slot=@s, garage_stored=1, last_garage=@g WHERE plate=@p', { ['@g'] = g.id, ['@s'] = slotIndex, ['@p'] = plate })
    else
        SetEntityCoords(entity, slot.x, slot.y, slot.z)
        SetEntityHeading(entity, slot.h or 0.0)
        FreezeExterior(entity, g, slotIndex, plate)
        MySQL.Sync.execute('UPDATE persistent_vehicles SET garage=@g, garage_slot=@s, garage_stored=0, last_garage=@g, position=@pos WHERE plate=@p', {
            ['@g'] = g.id, ['@s'] = slotIndex, ['@p'] = plate,
            ['@pos'] = json.encode({ x = slot.x, y = slot.y, z = slot.z, h = slot.h or 0.0 }),
        })
    end
    MySQL.Async.execute('UPDATE owned_vehicles SET stored=1, garage=@g WHERE plate=@p', { ['@g'] = tostring(g.id), ['@p'] = plate })

    -- Clé temporaire d'un véhicule d'entreprise : reprise au rangement
    if IsJobVehicle(g, owned) then
        if not owned then
            MySQL.Async.execute('INSERT IGNORE INTO owned_vehicles (owner, character_id, plate, type, job, stored, garage) VALUES (NULL, NULL, @p, @t, @j, 1, @g)', {
                ['@p'] = plate, ['@t'] = 'car', ['@j'] = g.owner_id, ['@g'] = tostring(g.id),
            })
        end
        RemoveVehicleKeys(p, plate)
    end

    Log(g, plate, p, 'store')
    Notify(src, ('Véhicule rangé sur la place %d.'):format(slotIndex), 'success')
    if g.type == 'interior' then
        -- G.Enter → EnsureInstance/HealInstance recrée l'instance à partir de la BDD
        -- (véhicule fraîchement rangé inclus), bucket rejoint avant les spawns
        G.Enter(src, g)
    end
end)

-- ── Sortir ─────────────────────────────────────────────────────────
local function IsSpotClear(x, y, z, ignoreEntity)
    for _, v in ipairs(GetAllVehicles()) do
        if v ~= ignoreEntity and DoesEntityExist(v) and GetEntityRoutingBucket(v) == 0 then
            if #(GetEntityCoords(v) - vector3(x, y, z)) < C.ExitClearRadius then return false end
        end
    end
    return true
end

local function FindExitSpot(g, heavy)
    -- Une place 'heavy' fait ressortir le véhicule par le marker poids lourd
    -- (mêmes contraintes d'encombrement que la sortie standard) plutôt que
    -- par le point de sortie normal, souvent trop étroit pour un camion.
    local e = (heavy and g.heavy_entrance) or g.exit_spawn or g.entrance
    local h = e.h or 0.0
    local rad = math.rad(h)
    for _, o in ipairs(C.ExitOffsets) do
        -- rotation du décalage local (x latéral, y avant) selon le heading
        local wx = e.x + o.x * math.cos(rad) - o.y * math.sin(rad)
        local wy = e.y + o.x * math.sin(rad) + o.y * math.cos(rad)
        if IsSpotClear(wx, wy, e.z, nil) then return { x = wx, y = wy, z = e.z, h = h } end
    end
    return nil
end

LSLegacy.Events.Register('garage:takeout', function(data)
    local src = source
    local p = GetPlayer(src)
    if not p or type(data) ~= 'table' then return end
    local g = Garages[tonumber(data.garage) or -1]
    local plate = Trim(data.plate)
    if not g or plate == '' then return end
    local row = GetPersistedRow(plate)
    if not row or tonumber(row.garage) ~= g.id then return Notify(src, "Ce véhicule n'est pas dans ce garage.", 'error') end
    local owned = GetOwnedRow(plate)
    local ok, jobOrErr = CanTake(p, g, plate, owned)
    if not ok then return Notify(src, jobOrErr, 'error') end
    local isJobVeh = jobOrErr == true
    local slotDef = g.slots[tonumber(row.garage_slot) or 0]
    local isHeavy = slotDef and slotDef.type == 'heavy'

    if g.type == 'interior' then
        if PlayerInstance[src] ~= g.id then return end
        local spot = FindExitSpot(g, isHeavy)
        if not spot then return Notify(src, 'La sortie du garage est encombrée.', 'error') end
        local inst = Instances[g.id]
        if inst and inst.vehicles[plate] then
            if DoesEntityExist(inst.vehicles[plate].entity) then DeleteEntity(inst.vehicles[plate].entity) end
            inst.vehicles[plate] = nil
        end
        -- ferme la fenêtre de dupli : personne d'autre ne doit rester dans l'instance
        -- pendant que la BDD est mise à jour pour cette plaque
        G.KickInstance(g, src)
        MySQL.Sync.execute('UPDATE persistent_vehicles SET garage=NULL, garage_slot=NULL, garage_stored=0, position=@pos WHERE plate=@p', {
            ['@pos'] = json.encode(spot), ['@p'] = plate,
        })
        MySQL.Async.execute('UPDATE owned_vehicles SET stored=0, garage=NULL WHERE plate=@p', { ['@p'] = plate })
        G.Leave(src, false)
        -- le joueur est téléporté à la sortie AVANT le spawn : le véhicule a ainsi
        -- un client à portée dès sa création (sinon purge OneSync possible)
        LSLegacy.Events.SendToClient('garage:leftInstance', src, { coords = spot })
        local fresh = GetPersistedRow(plate)
        CreateThread(function()
            Wait(900)
            LSLegacy.AP.SpawnPersistedRow(fresh)
            local a = LSLegacy.AP.Active[plate]
            if a and a.entity and DoesEntityExist(a.entity) then
                SetVehicleDoorsLocked(a.entity, 1)
                LSLegacy.Events.SendToClient('garage:warpInto', src, { netId = a.netId })
            end
        end)
    else
        local a = LSLegacy.AP.Active[plate]
        if not a or not a.entity or not DoesEntityExist(a.entity) then return Notify(src, 'Véhicule introuvable.', 'error') end
        local warp = false
        if isHeavy and g.heavy_entrance then
            local e = g.heavy_entrance
            if not IsSpotClear(e.x, e.y, e.z, a.entity) then
                return Notify(src, 'La sortie poids lourd est encombrée.', 'error')
            end
            ReleaseExterior(a.entity)
            SetEntityCoords(a.entity, e.x, e.y, e.z)
            SetEntityHeading(a.entity, e.h or 0.0)
            warp = true
        else
            ReleaseExterior(a.entity)
        end
        MySQL.Sync.execute('UPDATE persistent_vehicles SET garage=NULL, garage_slot=NULL, garage_stored=0 WHERE plate=@p', { ['@p'] = plate })
        MySQL.Async.execute('UPDATE owned_vehicles SET stored=0, garage=NULL WHERE plate=@p', { ['@p'] = plate })
        -- warp=true : le véhicule vient d'être téléporté au marker poids lourd (loin
        -- du joueur), TaskEnterVehicle (pathfind) ne convient pas, il faut tp direct
        LSLegacy.Events.SendToClient('garage:released', src, { netId = a.netId, warp = warp, coords = warp and g.heavy_entrance or nil })
    end

    if isJobVeh and not HasVehicleKey(p, plate) then
        exports.lslegacy:giveVehicleKey(src, plate, row.model, g.owner_name or g.name)
    end
    Log(g, plate, p, 'takeout')
    Notify(src, 'Véhicule sorti du garage.', 'success')
end)

-- ── Changer de place ───────────────────────────────────────────────
LSLegacy.Events.Register('garage:moveSlot', function(data)
    local src = source
    local p = GetPlayer(src)
    if not p or type(data) ~= 'table' then return end
    local g = Garages[tonumber(data.garage) or -1]
    local plate = Trim(data.plate)
    local target = tonumber(data.slot)
    if not g or plate == '' or not target or not g.slots[target] then return end
    local row = GetPersistedRow(plate)
    if not row or tonumber(row.garage) ~= g.id then return end
    local owned = GetOwnedRow(plate)
    local ok, err = CanTake(p, g, plate, owned)
    if not ok then return Notify(src, err, 'error') end
    local occ = GetOccupancy(g.id)
    if occ[target] then return Notify(src, 'Cette place est occupée.', 'error') end
    local fromSlot = g.slots[row.garage_slot or 0]
    if fromSlot and SlotDef(g.slots[target].type or 'car') ~= SlotDef(fromSlot.type or 'car') then
        -- Autorise uniquement si la nouvelle place accepte au moins ce que l'ancienne acceptait strictement
        local newAcc = SlotDef(g.slots[target].type or 'car').accepts
        local oldId = fromSlot.type or 'car'
        if not newAcc[oldId == 'heavy' and 'heavy' or oldId == 'heli' and 'heli' or oldId == 'moto' and 'moto' or 'car'] then
            return Notify(src, "Cette place n'est pas adaptée à ce véhicule.", 'error')
        end
    end
    local slot = g.slots[target]
    MySQL.Sync.execute('UPDATE persistent_vehicles SET garage_slot=@s' .. (g.type == 'exterior' and ', position=@pos' or '') .. ' WHERE plate=@p', {
        ['@s'] = target, ['@p'] = plate, ['@pos'] = json.encode({ x = slot.x, y = slot.y, z = slot.z, h = slot.h or 0.0 }),
    })
    if g.type == 'interior' then
        local inst = Instances[g.id]
        local v = inst and inst.vehicles[plate]
        if v and DoesEntityExist(v.entity) then
            SetEntityCoords(v.entity, slot.x, slot.y, slot.z)
            SetEntityHeading(v.entity, slot.h or 0.0)
            Entity(v.entity).state:set('garageVeh', { garage = g.id, slot = target, plate = plate, mode = 'interior' }, true)
            v.row.garage_slot = target
        end
    else
        local a = LSLegacy.AP.Active[plate]
        if a and a.entity and DoesEntityExist(a.entity) then
            SetEntityCoords(a.entity, slot.x, slot.y, slot.z)
            SetEntityHeading(a.entity, slot.h or 0.0)
            FreezeExterior(a.entity, g, target, plate)
        end
    end
    Notify(src, ('Véhicule déplacé sur la place %d.'):format(target), 'success')
end)

-- ── Doubles de clés ────────────────────────────────────────────────
-- Depuis un garage personnel : réservé au propriétaire du garage, pour un véhicule qu'il possède.
-- Serrurier : liste des véhicules possédés par le personnage
LSLegacy.Events.Register('garage:locksmithList', function()
    local src = source
    local p = GetPlayer(src)
    if not p or not C.Locksmith.enabled then return end
    local rows = MySQL.Sync.fetchAll([[
        SELECT ov.plate, pv.model FROM owned_vehicles ov
        LEFT JOIN persistent_vehicles pv ON pv.plate = ov.plate
        WHERE ov.character_id=@c
    ]], { ['@c'] = CharId(p) })
    LSLegacy.Events.SendToClient('garage:locksmithList', src, rows or {}, C.Locksmith.price)
end)

local pendingLocksmith = {}
LSLegacy.Bank.RegisterPaymentResultHandler('locksmith', function(refId, success)
    local pend = pendingLocksmith[refId]
    pendingLocksmith[refId] = nil
    if not pend or not success then return end
    local p = GetPlayer(pend.src)
    if not p then return end
    exports.lslegacy:giveVehicleKey(pend.src, pend.plate, pend.model, nil)
end)

LSLegacy.Events.Register('garage:locksmithDuplicate', function(plate)
    local src = source
    local p = GetPlayer(src)
    plate = Trim(plate)
    if not p or plate == '' or not C.Locksmith.enabled then return end
    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - C.Locksmith.coords) > 6.0 then return end
    local owned = GetOwnedRow(plate)
    if not owned or tostring(owned.character_id) ~= tostring(CharId(p)) then
        return Notify(src, "Ce véhicule n'est pas à votre nom.", 'error')
    end
    local row = GetPersistedRow(plate)
    local token = ('lk_%d_%d'):format(src, GetGameTimer())
    pendingLocksmith[token] = { src = src, plate = plate, model = row and row.model or nil }
    LSLegacy.Bank.OpenPaymentMenu(src, 'Serrurier - double ' .. plate, C.Locksmith.price, { meta = { type = 'locksmith', refId = token } })
end)

-- ── Créateur (groupe 2) ────────────────────────────────────────────
local function IsAdmin(src)
    local p = GetPlayer(src)
    return p and LSLegacy.Permissions.Has(p, 2)
end

LSLegacy.RegisterCommand('garageCreator', 2, function(xPlayer)
    LSLegacy.Events.SendToClient('garageCreator:openMenu', xPlayer.source)
end, { help = 'Ouvrir le menu de création de garages', validate = false }, false)

-- Instance de travail du créateur : l'admin seul dans son bucket pour
-- prévisualiser un intérieur et y placer markers/places.
LSLegacy.Events.Register('garage:creatorInstance', function(on)
    local src = source
    if not IsAdmin(src) then return end
    if PlayerInstance[src] then G.Leave(src, false) end
    local bucket = on and (C.CreatorBucketBase + src) or 0
    SetPlayerRoutingBucket(src, bucket)
    LSLegacy.Pickup.SyncBucket(src, bucket)
end)

LSLegacy.Callbacks.RegisterServer('garage:getOwners', function(src, cb)
    if not IsAdmin(src) then return cb(nil) end
    local jobs, factions = {}, {}
    for id, j in pairs(LSLegacy.AvailableJobs) do if id ~= 'unemployed' then jobs[#jobs + 1] = { id = id, label = j.label } end end
    for id, f in pairs(LSLegacy.AvailableFactions) do if id ~= 'unemployed' then factions[#factions + 1] = { id = id, label = f.label } end end
    table.sort(jobs, function(a, b) return a.label < b.label end)
    table.sort(factions, function(a, b) return a.label < b.label end)
    cb({ jobs = jobs, factions = factions })
end)

LSLegacy.Callbacks.RegisterServer('garage:getPlayerInfo', function(src, cb, targetId)
    if not IsAdmin(src) then return cb(nil) end
    local t = GetPlayer(tonumber(targetId) or -1)
    if not t then return cb(nil) end
    cb({ charId = CharId(t), name = CharName(t) })
end)

local function SanitizeGarage(data)
    if type(data) ~= 'table' then return nil, 'Données invalides.' end
    local name = Trim(data.name):sub(1, 60)
    if name == '' then return nil, 'Nom manquant.' end
    local gtype = data.type == 'interior' and 'interior' or 'exterior'
    local otype = data.owner_type
    if otype ~= 'personal' and otype ~= 'job' and otype ~= 'faction' and otype ~= 'public' then return nil, 'Type de propriétaire invalide.' end
    if otype == 'public' and gtype == 'interior' then return nil, 'Un garage public doit être extérieur.' end
    if otype ~= 'public' and (not data.owner_id or Trim(data.owner_id) == '') then return nil, 'Propriétaire manquant.' end
    local function pt(v, withH)
        if type(v) ~= 'table' or not tonumber(v.x) or not tonumber(v.y) or not tonumber(v.z) then return nil end
        local o = { x = tonumber(v.x) + 0.0, y = tonumber(v.y) + 0.0, z = tonumber(v.z) + 0.0 }
        if withH then o.h = (tonumber(v.h) or 0.0) + 0.0 end
        return o
    end
    local entrance = pt(data.entrance, true)
    if not entrance then return nil, "Point d'entrée manquant." end
    local slots = {}
    for _, s in ipairs(type(data.slots) == 'table' and data.slots or {}) do
        local p = pt(s, true)
        if p then p.type = SlotDef(s.type).id; slots[#slots + 1] = p end
    end
    if #slots == 0 then return nil, 'Aucune place définie.' end
    local out = {
        name = name, type = gtype, owner_type = otype,
        owner_id = otype ~= 'public' and Trim(data.owner_id) or nil,
        owner_name = data.owner_name and Trim(data.owner_name):sub(1, 100) or nil,
        entrance = entrance, heavy_entrance = pt(data.heavy_entrance, true), exit_spawn = pt(data.exit_spawn, true),
        interior_spawn = pt(data.interior_spawn, true), interior_exit = pt(data.interior_exit, false),
        slots = slots, blip = data.blip ~= false,
        interior = (gtype == 'interior' and type(data.interior) == 'string' and C.InteriorDef(data.interior)) and data.interior or nil,
    }
    if gtype == 'interior' and (not out.interior_spawn or not out.interior_exit or not out.exit_spawn) then
        return nil, "Un garage intérieur requiert : spawn piéton, sortie piéton et point de sortie véhicule."
    end
    return out
end

local function InsertGarage(d, propertyId)
    local id = MySQL.insert.await([[
        INSERT INTO garages (name, type, owner_type, owner_id, owner_name, property_id, entrance, heavy_entrance, exit_spawn, interior_spawn, interior_exit, slots, blip, interior)
        VALUES (@name, @type, @ot, @oid, @oname, @prop, @ent, @hent, @exit, @ispawn, @iexit, @slots, @blip, @interior)
    ]], {
        ['@interior'] = d.interior, ['@name'] = d.name, ['@type'] = d.type, ['@ot'] = d.owner_type, ['@oid'] = d.owner_id, ['@oname'] = d.owner_name,
        ['@prop'] = propertyId, ['@ent'] = json.encode(d.entrance), ['@hent'] = d.heavy_entrance and json.encode(d.heavy_entrance) or nil,
        ['@exit'] = d.exit_spawn and json.encode(d.exit_spawn) or nil,
        ['@ispawn'] = d.interior_spawn and json.encode(d.interior_spawn) or nil, ['@iexit'] = d.interior_exit and json.encode(d.interior_exit) or nil,
        ['@slots'] = json.encode(d.slots), ['@blip'] = d.blip and 1 or 0,
    })
    if not id then return nil end
    local row = MySQL.Sync.fetchAll('SELECT * FROM garages WHERE id=@id', { ['@id'] = id })[1]
    Garages[id] = DecodeRow(row)
    Broadcast()
    return id
end

local function UpdateGarage(id, d)
    MySQL.Sync.execute([[
        UPDATE garages SET name=@name, type=@type, owner_type=@ot, owner_id=@oid, owner_name=@oname, entrance=@ent, heavy_entrance=@hent, exit_spawn=@exit,
        interior_spawn=@ispawn, interior_exit=@iexit, slots=@slots, blip=@blip, interior=@interior WHERE id=@id
    ]], {
        ['@interior'] = d.interior, ['@id'] = id, ['@name'] = d.name, ['@type'] = d.type, ['@ot'] = d.owner_type, ['@oid'] = d.owner_id, ['@oname'] = d.owner_name,
        ['@ent'] = json.encode(d.entrance), ['@hent'] = d.heavy_entrance and json.encode(d.heavy_entrance) or nil,
        ['@exit'] = d.exit_spawn and json.encode(d.exit_spawn) or nil,
        ['@ispawn'] = d.interior_spawn and json.encode(d.interior_spawn) or nil, ['@iexit'] = d.interior_exit and json.encode(d.interior_exit) or nil,
        ['@slots'] = json.encode(d.slots), ['@blip'] = d.blip and 1 or 0,
    })
    local row = MySQL.Sync.fetchAll('SELECT * FROM garages WHERE id=@id', { ['@id'] = id })[1]
    Garages[id] = DecodeRow(row)
    -- Instance active : on la vide pour la reconstruire avec les nouvelles places
    local inst = Instances[id]
    if inst then
        for src in pairs(inst.players) do G.Leave(src, true) end
    end
    Broadcast()
end

-- Suppression : les véhicules rangés sont libérés (remis dans la persistance à l'entrée).
local function DeleteGarage(id)
    local g = Garages[id]
    if not g then return false end
    local inst = Instances[id]
    if inst then for src in pairs(inst.players) do G.Leave(src, true) end end
    local rows = MySQL.Sync.fetchAll('SELECT plate, garage_stored FROM persistent_vehicles WHERE garage=@g', { ['@g'] = id })
    for _, r in ipairs(rows or {}) do
        if tonumber(r.garage_stored) == 1 then
            MySQL.Sync.execute('UPDATE persistent_vehicles SET garage=NULL, garage_slot=NULL, garage_stored=0, position=@pos WHERE plate=@p', {
                ['@pos'] = json.encode({ x = g.entrance.x, y = g.entrance.y, z = g.entrance.z, h = g.entrance.h or 0.0 }), ['@p'] = r.plate,
            })
        else
            local a = LSLegacy.AP.Active[r.plate]
            if a and a.entity and DoesEntityExist(a.entity) then ReleaseExterior(a.entity) end
            MySQL.Sync.execute('UPDATE persistent_vehicles SET garage=NULL, garage_slot=NULL, garage_stored=0 WHERE plate=@p', { ['@p'] = r.plate })
        end
    end
    MySQL.Async.execute('UPDATE owned_vehicles SET stored=0, garage=NULL WHERE garage=@g', { ['@g'] = tostring(id) })
    MySQL.Sync.execute('DELETE FROM garages WHERE id=@id', { ['@id'] = id })
    Garages[id] = nil
    Broadcast()
    return true
end

LSLegacy.Events.Register('garage:create', function(data)
    local src = source
    if not IsAdmin(src) then return end
    local d, err = SanitizeGarage(data)
    if not d then return Notify(src, err, 'error') end
    local id = InsertGarage(d, nil)
    if not id then return Notify(src, 'Erreur BDD.', 'error') end
    if d.owner_type == 'personal' then
        local t = nil
        for s, p in pairs(LSLegacy.Players.GetAll()) do if tostring(CharId(p)) == tostring(d.owner_id) then t = p break end end
        if t then LSLegacy.Inventory.AddItemInInventory(t, C.KeyItem, 1, 'Clé de garage - ' .. d.name, nil, { garage = id, name = d.name }) end
    end
    Notify(src, ('Garage "%s" créé (#%d).'):format(d.name, id), 'success')
end)

LSLegacy.Events.Register('garage:update', function(id, data)
    local src = source
    if not IsAdmin(src) then return end
    id = tonumber(id)
    if not id or not Garages[id] then return end
    local d, err = SanitizeGarage(data)
    if not d then return Notify(src, err, 'error') end
    UpdateGarage(id, d)
    Notify(src, ('Garage #%d mis à jour.'):format(id), 'success')
end)

LSLegacy.Events.Register('garage:delete', function(id)
    local src = source
    if not IsAdmin(src) then return end
    id = tonumber(id)
    if id and DeleteGarage(id) then Notify(src, ('Garage #%d supprimé.'):format(id), 'success') end
end)

LSLegacy.Events.Register('garage:giveKey', function(id, targetId)
    local src = source
    if not IsAdmin(src) then return end
    local g = Garages[tonumber(id) or -1]
    local t = GetPlayer(tonumber(targetId) or -1)
    if not g or not t or g.owner_type ~= 'personal' then return end
    LSLegacy.Inventory.AddItemInInventory(t, C.KeyItem, 1, 'Clé de garage - ' .. g.name, nil, { garage = g.id, name = g.name })
    Notify(src, 'Clé donnée à ' .. CharName(t) .. '.', 'success')
end)

-- Véhicule de flotte : créé persistant à la sortie du garage, possédé par l'entreprise.
local LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
local function RandomPlate()
    local function l() return LETTERS:sub(math.random(1, 26), math.random(1, 26)) end
    return ('%s%s%03d%s%s'):format(l(), l(), math.random(0, 999), l(), l())
end
local function UniquePlate()
    for _ = 1, 20 do
        local pl = RandomPlate()
        local rows = MySQL.Sync.fetchAll('SELECT plate FROM owned_vehicles WHERE plate=@p UNION SELECT plate FROM persistent_vehicles WHERE plate=@p LIMIT 1', { ['@p'] = pl })
        if not rows or #rows == 0 then return pl end
    end
end

LSLegacy.Events.Register('garage:addFleetVehicle', function(id, model)
    local src = source
    if not IsAdmin(src) then return end
    local g = Garages[tonumber(id) or -1]
    if not g or g.owner_type ~= 'job' then return end
    model = Trim(model):lower()
    if model == '' then return end
    local plate = UniquePlate()
    if not plate then return Notify(src, 'Impossible de générer une plaque.', 'error') end
    local spot = FindExitSpot(g) or g.exit_spawn or g.entrance
    local hash = GetHashKey(model)
    local veh = CreateVehicle(hash, spot.x, spot.y, spot.z, spot.h or 0.0, true, true)
    local t = 0
    while not DoesEntityExist(veh) and t < 50 do Wait(100); t = t + 1 end
    if not DoesEntityExist(veh) then return Notify(src, 'Modèle invalide : ' .. model, 'error') end
    SetVehicleNumberPlateText(veh, plate)
    Entity(veh).state:set('plate', plate, true)
    Entity(veh).state:set('fuelLevel', 100.0, true)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local status = { engine = 1000.0, body = 1000.0, tank = 1000.0, dirt = 0.0, fuel = 100.0, lock = 1, windows = {}, extras = {}, tyreData = {}, doorsBroken = {}, visualDamage = {} }
    LSLegacy.AP.Active[plate] = { netId = netId, entity = veh, model = hash, fuel = 100.0, windows = {}, extras = {}, tyreData = {}, doorsBroken = {}, visualDamage = {}, tuning = {} }
    MySQL.Sync.execute([[
        INSERT INTO persistent_vehicles (plate, model, position, status, tuning, trailer_plate, state_bags)
        VALUES (@plate, @model, @pos, @status, '{}', NULL, '{"fuelLevel":100.0}')
        ON DUPLICATE KEY UPDATE model=@model, position=@pos, status=@status
    ]], { ['@plate'] = plate, ['@model'] = hash, ['@pos'] = json.encode(spot), ['@status'] = json.encode(status) })
    MySQL.Sync.execute('INSERT INTO owned_vehicles (owner, character_id, plate, type, job, stored) VALUES (NULL, NULL, @p, @t, @j, 0)', {
        ['@p'] = plate, ['@t'] = 'car', ['@j'] = g.owner_id,
    })
    LSLegacy.Events.SendToClient('ap:vehicleSpawned', -1, { netId = netId, plate = plate, extras = {}, tankHealth = 1000.0, engineHealth = 1000.0, tuning = {}, fuel = 100.0, status = status })
    Notify(src, ('Véhicule de flotte %s (%s) créé devant le garage. Rangez-le pour l\'ajouter.'):format(model, plate), 'success')
end)

-- Cleanup AP (Config.AP.SendCleanupToGarage) : renvoie un véhicule inactif dans
-- son dernier garage sur la première place libre au lieu de le purger.
function G.ReturnToLastGarage(plate)
    local row = GetPersistedRow(plate)
    if not row or row.garage or not row.last_garage then return false end
    local g = Garages[tonumber(row.last_garage)]
    if not g then return false end
    local occ = GetOccupancy(g.id)
    local slotIndex = FindFreeSlot(g, occ, 'car', nil) or FindFreeSlot(g, occ, 'moto', nil)
    if not slotIndex then return false end
    local a = LSLegacy.AP.Active[plate]
    if a and a.entity and DoesEntityExist(a.entity) then
        if LSLegacy.AP.SaveVehicleNow then LSLegacy.AP.SaveVehicleNow(a.entity) end
        LSLegacy.AP.Active[plate] = nil
        DeleteEntity(a.entity)
    end
    local slot = g.slots[slotIndex]
    if g.type == 'interior' then
        MySQL.Sync.execute('UPDATE persistent_vehicles SET garage=@g, garage_slot=@s, garage_stored=1 WHERE plate=@p', { ['@g'] = g.id, ['@s'] = slotIndex, ['@p'] = plate })
    else
        MySQL.Sync.execute('UPDATE persistent_vehicles SET garage=@g, garage_slot=@s, garage_stored=0, position=@pos WHERE plate=@p', {
            ['@g'] = g.id, ['@s'] = slotIndex, ['@p'] = plate, ['@pos'] = json.encode({ x = slot.x, y = slot.y, z = slot.z, h = slot.h or 0.0 }),
        })
    end
    MySQL.Async.execute('UPDATE owned_vehicles SET stored=1, garage=@g WHERE plate=@p', { ['@g'] = tostring(g.id), ['@p'] = plate })
    return true
end

-- ── MDT : journal d'accès des garages du job ───────────────────────
LSLegacy.Events.Register('mdtgarage:query', function(payload)
    local src = source
    local p = GetPlayer(src)
    if not p or type(payload) ~= 'table' then return end
    local reply = function(res) LSLegacy.Events.SendToClient('mdtgarage:queryResult', src, { reqId = payload.reqId, result = res }) end
    if payload.action ~= 'getLogs' then return reply(false) end
    local ids, names = {}, {}
    for id, g in pairs(Garages) do
        if g.owner_type == 'job' and g.owner_id == p.job then ids[#ids + 1] = id; names[id] = g.name end
    end
    if #ids == 0 then return reply({ garages = {}, logs = {} }) end
    local rows = MySQL.Sync.fetchAll(('SELECT garage_id, plate, name, action, created_at FROM garage_logs WHERE garage_id IN (%s) ORDER BY created_at DESC LIMIT %d'):format(table.concat(ids, ','), C.LogLimit), {})
    for _, r in ipairs(rows or {}) do r.garage = names[r.garage_id] end
    local occ = {}
    local vrows = MySQL.Sync.fetchAll(('SELECT plate, model, garage, garage_slot FROM persistent_vehicles WHERE garage IN (%s)'):format(table.concat(ids, ',')), {})
    for _, v in ipairs(vrows or {}) do occ[#occ + 1] = { plate = v.plate, model = v.model, garage = names[v.garage], slot = v.garage_slot } end
    reply({ garages = names, logs = rows or {}, vehicles = occ })
end)

-- ── API propriétés (Quasar Housing ou autre) ──────────────────────
-- data : { property_id, name, owner_char_id, owner_name, type, entrance, exit_spawn, interior_spawn, interior_exit, slots, blip }
exports('createPropertyGarage', function(data)
    if type(data) ~= 'table' or not data.property_id then return nil end
    local d, err = SanitizeGarage({
        name = data.name, type = data.type or 'interior', owner_type = 'personal',
        owner_id = tostring(data.owner_char_id or ''), owner_name = data.owner_name,
        entrance = data.entrance, exit_spawn = data.exit_spawn, interior_spawn = data.interior_spawn,
        interior_exit = data.interior_exit, slots = data.slots, blip = data.blip == true,
    })
    if not d then print('[garage] createPropertyGarage : ' .. tostring(err)) return nil end
    return InsertGarage(d, tostring(data.property_id))
end)

exports('setPropertyGarageOwner', function(propertyId, ownerCharId, ownerName)
    for id, g in pairs(Garages) do
        if g.property_id == tostring(propertyId) then
            MySQL.Sync.execute('UPDATE garages SET owner_id=@o, owner_name=@n WHERE id=@id', { ['@o'] = tostring(ownerCharId), ['@n'] = ownerName, ['@id'] = id })
            g.owner_id = tostring(ownerCharId); g.owner_name = ownerName
            Broadcast()
            return true
        end
    end
    return false
end)

exports('deletePropertyGarage', function(propertyId)
    for id, g in pairs(Garages) do
        if g.property_id == tostring(propertyId) then return DeleteGarage(id) end
    end
    return false
end)

exports('getPropertyGarage', function(propertyId)
    for _, g in pairs(Garages) do if g.property_id == tostring(propertyId) then return g end end
    return nil
end)

exports('enterGarage', function(src, garageId)
    local p = GetPlayer(src)
    local g = Garages[tonumber(garageId) or -1]
    if not p or not g or not G.CanAccess(p, g) then return false end
    return G.Enter(src, g)
end)

exports('giveGarageKey', function(src, garageId)
    local p = GetPlayer(src)
    local g = Garages[tonumber(garageId) or -1]
    if not p or not g then return false end
    LSLegacy.Inventory.AddItemInInventory(p, C.KeyItem, 1, 'Clé de garage - ' .. g.name, nil, { garage = g.id, name = g.name })
    return true
end)

G.Get = function(id) return Garages[id] end
G.GetAll = function() return Garages end

-- ── Valet (lb-phone) : uniquement les véhicules personnels rangés en garage perso ──
local function ValetEligible(charId, plate)
    local owned = GetOwnedRow(plate)
    if not owned then return nil, 'Véhicule introuvable.' end
    if owned.job and owned.job ~= '' then return nil, "Véhicule d'entreprise : passez par le garage du service." end
    if tostring(owned.character_id) ~= tostring(charId) then return nil, "Ce véhicule ne vous appartient pas." end
    local row = GetPersistedRow(plate)
    if not row or not row.garage then return nil, "Ce véhicule n'est pas dans un garage." end
    local g = Garages[tonumber(row.garage)]
    if not g or g.owner_type ~= 'personal' then return nil, "Le voiturier ne dessert que les garages personnels." end
    return row, g
end

exports('valetGetVehicles', function(charId)
    charId = tonumber(charId)
    if not charId then return {} end
    local rows = MySQL.Sync.fetchAll([[
        SELECT pv.plate, pv.model, pv.status, g.name AS garage_name
        FROM owned_vehicles ov
        JOIN persistent_vehicles pv ON pv.plate = ov.plate
        JOIN garages g ON g.id = pv.garage
        WHERE ov.character_id = @c AND (ov.job IS NULL OR ov.job = '') AND g.owner_type = 'personal' AND pv.garage IS NOT NULL
    ]], { ['@c'] = charId })
    local out = {}
    for _, r in ipairs(rows or {}) do
        local status = type(r.status) == 'string' and json.decode(r.status) or r.status or {}
        out[#out + 1] = {
            plate = Trim(r.plate),
            model = tonumber(r.model) or 0,
            type = 'vehicle',
            location = r.garage_name,
            statistics = { engine = status.engine, body = status.body, fuel = status.fuel },
        }
    end
    return out
end)

exports('valetGetVehicle', function(src, plate)
    local p = GetPlayer(src)
    if not p then return nil end
    local row = ValetEligible(CharId(p), Trim(plate))
    if not row then return nil end
    return { plate = Trim(row.plate), model = tonumber(row.model) or 0 }
end)

-- Vérité BDD sur "est-ce que ce véhicule est dans un garage", indépendante de
-- l'existence d'une entité serveur : un véhicule stocké en garage intérieur a
-- une entité bien réelle (visible par les joueurs présents dans l'instance),
-- donc un scan brut d'entités le fait passer à tort pour "sorti" (ex: lb-phone).
exports('isVehicleStored', function(plate)
    local row = GetPersistedRow(Trim(plate))
    return row ~= nil and row.garage ~= nil
end)

-- Sort un véhicule personnel de son garage aux coordonnées données (voiturier lb-phone),
-- copie conforme via LSLegacy.AP comme un garage:takeout classique. Retourne le netId.
exports('valetTakeout', function(src, plate, coords, heading)
    local p = GetPlayer(src)
    if not p then return nil, 'Joueur introuvable.' end
    plate = Trim(plate)
    local row, gOrErr = ValetEligible(CharId(p), plate)
    if not row then return nil, gOrErr end
    local g = gOrErr

    if g.type == 'interior' then
        local inst = Instances[g.id]
        if inst and inst.vehicles[plate] then
            if DoesEntityExist(inst.vehicles[plate].entity) then DeleteEntity(inst.vehicles[plate].entity) end
            inst.vehicles[plate] = nil
        end
        -- le voiturier agit à distance : quiconque est resté dans l'instance doit
        -- en sortir pour éviter d'interagir avec la plaque pendant la mise à jour BDD
        G.KickInstance(g, nil)
    else
        local a = LSLegacy.AP.Active[plate]
        if a and a.entity and DoesEntityExist(a.entity) then
            ReleaseExterior(a.entity)
            DeleteEntity(a.entity)
        end
    end
    LSLegacy.AP.Active[plate] = nil

    MySQL.Sync.execute('UPDATE persistent_vehicles SET garage=NULL, garage_slot=NULL, garage_stored=0, position=@pos WHERE plate=@p', {
        ['@pos'] = json.encode({ x = coords.x, y = coords.y, z = coords.z, h = heading or 0.0 }), ['@p'] = plate,
    })
    MySQL.Async.execute('UPDATE owned_vehicles SET stored=0, garage=NULL WHERE plate=@p', { ['@p'] = plate })
    Log(g, plate, p, 'valet')

    local fresh = GetPersistedRow(plate)
    if not fresh then return nil, 'Erreur interne.' end
    LSLegacy.AP.SpawnPersistedRow(fresh)
    local timeout = 0
    while not (LSLegacy.AP.Active[plate] and LSLegacy.AP.Active[plate].netId) do
        Wait(100)
        timeout = timeout + 100
        if timeout >= 8000 then return nil, 'Le voiturier ne parvient pas à sortir le véhicule.' end
    end
    return LSLegacy.AP.Active[plate].netId
end)
