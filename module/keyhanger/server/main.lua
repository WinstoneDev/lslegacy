-- Chaque porte-clés est adossé à un DataStore (comme un coffre) ; les clés sont déposées/récupérées via l'inventaire, les props visibles sont synchronisés à partir de son contenu.

local C = KeyHanger.Config

KeyHanger.Boards = {}     -- [id] = board (métadonnées ; le contenu est dans le DataStore)
KeyHanger.Loaded = false

-- Rate limiting (events sécurisés)
local rateLimits = {
    ['keyhanger:requestBoards'] = 10, ['keyhanger:create'] = 10, ['keyhanger:remove'] = 10,
    ['keyhanger:open'] = 30, ['keyhanger:rename'] = 10, ['keyhanger:share'] = 15,
    ['keyhanger:unshare'] = 15, ['keyhanger:createKey'] = 15,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local function dbg(...) if C.Debug then print("[keyhanger]", ...) end end

local function dsName(id) return "keyhanger_" .. id end

local function groupLevel(player)
    return LSLegacy.Permissions.GetLevel(player)
end

local function isStaff(player) return groupLevel(player) >= (C.Placement.group or 3) end

local function playerName(player)
    if player and player.characterInfos then
        return (player.characterInfos.Prenom or "?") .. " " .. (player.characterInfos.NDF or "?")
    end
    return "Inconnu"
end

--- Accès = peut ouvrir et déposer/récupérer des clés.
local function canAccess(player, board)
    if not player or not board then return false end
    local t = board.ownerType
    if t == "public" then return true end
    if t == "job" then return LSLegacy.Jobs.Is(player, board.ownerId) end
    if t == "faction" then return player.faction == board.ownerId end
    if board.ownerId == player.identifier then return true end
    if board.access and board.access[player.identifier] then return true end
    return false
end

--- Gestion = peut renommer / partager / retirer le support.
local function canManage(player, board)
    if not player or not board then return false end
    if isStaff(player) then return true end
    local t = board.ownerType
    if t == "job" then
        return LSLegacy.Jobs.Is(player, board.ownerId, C.ManageGrade or 0)
    elseif t == "faction" then
        return player.faction == board.ownerId and (player.faction_grade or 0) >= (C.ManageGrade or 0)
    end
    return board.ownerId == player.identifier
end

local function ensureDatastore(board)
    local name = dsName(board.id)
    local ds = LSLegacy.DataStores[name]
    if not ds then
        LSLegacy.DataStore.RegisterDataStore(name, {
            inventory = {}, name = name, type = 'trunk',
            money = 0, dirty = 0, maxWeight = C.Storage.maxWeight,
        })
        ds = LSLegacy.DataStores[name]
    else
        -- inventaire encore au format JSON (fenêtre de décodage au démarrage)
        if type(ds.inventory) ~= 'table' then ds.inventory = json.decode(ds.inventory) or {} end
        -- Garantit la capacité : au rechargement BDD, la colonne s'appelle 'weight'
        -- (et non 'maxWeight'), sinon CanStoreItem plante (compare number/nil).
        ds.maxWeight = C.Storage.maxWeight
    end
    return ds
end

--- Liste des clés (pour le rendu des props) à partir du contenu du DataStore.
local function boardKeys(board)
    local ds = LSLegacy.DataStores[dsName(board.id)]
    local out = {}
    if ds and type(ds.inventory) == 'table' then
        for _, it in pairs(ds.inventory) do
            if it.name == C.Item then
                local plate = (it.data and it.data.plate) or "??????"
                local n = it.count or 1
                for _ = 1, n do
                    out[#out + 1] = {
                        plate   = plate,
                        prop    = KeyHanger.PickKeyProp(plate),
                        label   = it.label,
                        display = (it.data and it.data.display) or plate,
                    }
                end
            end
        end
    end
    return out
end

local function keysSig(board)
    local ds = LSLegacy.DataStores[dsName(board.id)]
    if not ds or type(ds.inventory) ~= 'table' then return "∅" end
    local parts = {}
    for _, it in pairs(ds.inventory) do
        parts[#parts + 1] = (it.name or "?") .. ":" .. (it.count or 0) .. ":" .. ((it.data and it.data.plate) or "")
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

--- Représentation envoyée au client (métadonnées + clés calculées).
local function serializeBoard(board)
    return {
        id = board.id, label = board.label, board = board.board,
        ownerType = board.ownerType, ownerId = board.ownerId, ownerName = board.ownerName,
        coords = board.coords, heading = board.heading,
        access = board.access or {},
        keys = boardKeys(board),
    }
end

local function saveBoardDB(board)
    MySQL.update.await([[
        UPDATE keyhanger_boards
        SET label=?, board=?, owner_type=?, owner_id=?, owner_name=?, coords=?, heading=?, access=?
        WHERE id=?
    ]], {
        board.label, board.board, board.ownerType, board.ownerId, board.ownerName,
        json.encode(board.coords), board.heading, json.encode(board.access or {}), board.id,
    })
end

local function syncBoardToAll(board)
    LSLegacy.SendEventToClient('keyhanger:sync:board', -1, serializeBoard(board))
end

local function syncRemoveToAll(id)
    LSLegacy.SendEventToClient('keyhanger:sync:remove', -1, id)
end

local function syncAllTo(src)
    local list = {}
    for id, board in pairs(KeyHanger.Boards) do list[id] = serializeBoard(board) end
    LSLegacy.SendEventToClient('keyhanger:sync:all', src, list)
end

local prevGuard = LSLegacy.DataStoreGuard
LSLegacy.DataStoreGuard = function(src, name, action, item)
    if name and name:sub(1, 10) == "keyhanger_" then
        local id = tonumber(name:sub(11))
        local board = KeyHanger.Boards[id]
        local player = LSLegacy.Players.Get(src)
        if not board or not player then return false end
        if not canAccess(player, board) then return false end
        if C.Storage.onlyKeys and item ~= C.Item then return false end
        return true
    end
    if prevGuard then return prevGuard(src, name, action, item) end
    return true
end

-- Resynchronise les props quand le contenu d'un porte-clés change
AddEventHandler('lslegacy:containerUpdated', function(name)
    if not name or name:sub(1, 10) ~= "keyhanger_" then return end
    local id = tonumber(name:sub(11))
    local board = KeyHanger.Boards[id]
    if board then
        board._sig = keysSig(board)
        local keys = boardKeys(board)
        dbg(("containerUpdated %s -> %d clé(s)"):format(name, #keys))
        syncBoardToAll(board)
    end
end)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `keyhanger_boards` (
            `id`         INT(11)      NOT NULL AUTO_INCREMENT,
            `label`      VARCHAR(64)  NOT NULL DEFAULT 'Porte-clés',
            `board`      VARCHAR(32)  NOT NULL DEFAULT 'board_wood',
            `owner_type` VARCHAR(16)  NOT NULL DEFAULT 'personal',
            `owner_id`   VARCHAR(64)  NOT NULL DEFAULT '',
            `owner_name` VARCHAR(64)  NOT NULL DEFAULT '',
            `coords`     LONGTEXT     NOT NULL,
            `heading`    FLOAT        NOT NULL DEFAULT 0,
            `access`     LONGTEXT     NOT NULL DEFAULT '{}',
            `created_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    local rows = MySQL.query.await('SELECT * FROM keyhanger_boards') or {}
    for _, r in ipairs(rows) do
        KeyHanger.Boards[r.id] = {
            id        = r.id,
            label     = r.label,
            board     = r.board,
            ownerType = r.owner_type,
            ownerId   = r.owner_id,
            ownerName = r.owner_name,
            coords    = json.decode(r.coords),
            heading   = r.heading + 0.0,
            access    = json.decode(r.access or '{}') or {},
        }
    end
    KeyHanger.Loaded = true
    dbg(("chargement de %d porte-clés"):format(#rows))
    for src in pairs(LSLegacy.Players.GetAll()) do syncAllTo(src) end
end)

-- Synchronise à la connexion
LSLegacy.AddEventHandler('ap:clientsetonSpawn', function(src)
    if KeyHanger.Loaded then syncAllTo(src) end
end)

-- Filet de sécurité : resynchronise les props si un contenu a changé sans event
CreateThread(function()
    while true do
        Wait(C.Storage.syncInterval or 1500)
        if KeyHanger.Loaded then
            for _, board in pairs(KeyHanger.Boards) do
                local sig = keysSig(board)
                if board._sig ~= sig then
                    board._sig = sig
                    syncBoardToAll(board)
                end
            end
        end
    end
end)

LSLegacy.RegisterServerEvent('keyhanger:requestBoards', function()
    local src = source
    if not KeyHanger.Loaded then
        Citizen.CreateThread(function()
            while not KeyHanger.Loaded do Wait(100) end
            syncAllTo(src)
        end)
        return
    end
    syncAllTo(src)
end)

-- Ouverture du support comme un coffre (DataStore)
LSLegacy.RegisterServerEvent('keyhanger:open', function(boardId)
    local src = source
    local player = LSLegacy.Players.Get(src)
    local board = KeyHanger.Boards[boardId]
    if not player or not board then return end
    if not canAccess(player, board) then
        return LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('access_denied'), 'error')
    end
    ensureDatastore(board)
    LSLegacy.SendEventToClient('UpdateDatastore', src, LSLegacy.DataStores)
    LSLegacy.SendEventToClient('keyhanger:openContainer', src, dsName(boardId), board.label, C.Storage.maxWeight)
end)

LSLegacy.RegisterServerEvent('keyhanger:create', function(data)
    local src = source
    local player = LSLegacy.Players.Get(src)
    if not player or not data then return end
    if not isStaff(player) then
        return LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('manage_no_perm'), 'error')
    end
    if not C.Boards[data.board] then data.board = C.DefaultBoard end
    if not data.coords or not data.coords.x then return end

    local ownerType = data.ownerType or "personal"
    local valid = false
    for _, t in ipairs(C.AccessTypes) do if t.value == ownerType then valid = true break end end
    if not valid then ownerType = "personal" end

    local ownerId, ownerName
    if ownerType == "job" or ownerType == "faction" then
        ownerId, ownerName = data.ownerId or "", data.ownerId or ""
    else
        ownerId, ownerName = player.identifier, playerName(player)
    end

    local label = (data.label and data.label ~= "" and data.label) or KeyHanger.GetBoardDef(data.board).label

    local insertId = MySQL.insert.await([[
        INSERT INTO keyhanger_boards (label, board, owner_type, owner_id, owner_name, coords, heading, access)
        VALUES (?, ?, ?, ?, ?, ?, ?, '{}')
    ]], {
        label, data.board, ownerType, ownerId, ownerName,
        json.encode(data.coords), data.heading + 0.0,
    })
    if not insertId then return end

    local board = {
        id = insertId, label = label, board = data.board,
        ownerType = ownerType, ownerId = ownerId, ownerName = ownerName,
        coords = data.coords, heading = data.heading + 0.0, access = {},
    }
    KeyHanger.Boards[insertId] = board
    ensureDatastore(board)
    syncBoardToAll(board)
    LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('placement_created'), 'success')
    dbg(("create board #%d par %s"):format(insertId, player.identifier))
end)

-- Retrait d'un support (le contenu/DataStore est supprimé aussi)
LSLegacy.RegisterServerEvent('keyhanger:remove', function(boardId)
    local src = source
    local player = LSLegacy.Players.Get(src)
    local board = KeyHanger.Boards[boardId]
    if not player or not board then return end
    if not canManage(player, board) then
        return LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('manage_no_perm'), 'error')
    end
    local name = dsName(boardId)
    local ds = LSLegacy.DataStores[name]
    if ds and ds.inventory and #ds.inventory > 0 then
        return LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('manage_remove_notEmpty'), 'error')
    end
    LSLegacy.DataStores[name] = nil
    MySQL.query.await('DELETE FROM datastore WHERE name = ?', { name })
    KeyHanger.Boards[boardId] = nil
    MySQL.query.await('DELETE FROM keyhanger_boards WHERE id = ?', { boardId })
    syncRemoveToAll(boardId)
    LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('manage_remove') .. " ✓", 'success')
end)

LSLegacy.RegisterServerEvent('keyhanger:rename', function(boardId, newLabel)
    local src = source
    local player = LSLegacy.Players.Get(src)
    local board = KeyHanger.Boards[boardId]
    if not player or not board or not newLabel then return end
    if not canManage(player, board) then
        return LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('manage_no_perm'), 'error')
    end
    newLabel = tostring(newLabel):sub(1, 48)
    if newLabel == "" then return end
    board.label = newLabel
    saveBoardDB(board)
    syncBoardToAll(board)
end)

LSLegacy.RegisterServerEvent('keyhanger:share', function(boardId, targetSrc)
    local src = source
    local player = LSLegacy.Players.Get(src)
    local board = KeyHanger.Boards[boardId]
    local target = LSLegacy.Players.Get(tonumber(targetSrc))
    if not player or not board then return end
    if not canManage(player, board) then
        return LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('manage_no_perm'), 'error')
    end
    if not target then
        return LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('share_none_nearby'), 'error')
    end
    if target.identifier == player.identifier then
        return LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('share_self'), 'error')
    end
    local sp = GetEntityCoords(GetPlayerPed(src))
    local tp = GetEntityCoords(GetPlayerPed(target.source))
    if #(sp - tp) > 8.0 then
        return LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('share_none_nearby'), 'error')
    end
    board.access = board.access or {}
    if board.access[target.identifier] then
        return LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('share_already'), 'error')
    end
    local tName = playerName(target)
    board.access[target.identifier] = tName
    saveBoardDB(board)
    syncBoardToAll(board)
    LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('share_added', tName), 'success')
    LSLegacy.SendEventToClient('notify', target.source, KeyHanger.L('title'), KeyHanger.L('share_added', board.label), 'info')
end)

LSLegacy.RegisterServerEvent('keyhanger:unshare', function(boardId, identifier)
    local src = source
    local player = LSLegacy.Players.Get(src)
    local board = KeyHanger.Boards[boardId]
    if not player or not board or not identifier then return end
    if not canManage(player, board) then
        return LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('manage_no_perm'), 'error')
    end
    if board.access and board.access[identifier] then
        local name = board.access[identifier]
        board.access[identifier] = nil
        saveBoardDB(board)
        syncBoardToAll(board)
        LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('share_removed', name), 'success')
    end
end)

LSLegacy.RegisterUsableItem(C.Item, function(data)
    local src = source
    if not data or not data.plate then return end
    LSLegacy.SendEventToClient('keyhanger:useKey', src, data)
end)

--- Donne une clé de véhicule à un joueur. Réutilisable (concession, garage...).
local function giveVehicleKey(src, plate, vehModel, display, label)
    local player = LSLegacy.Players.Get(src)
    if not player or not plate then return false end
    plate = tostring(plate):gsub("%s+$", "")
    if not LSLegacy.Inventory.CanCarryItem(player, C.Item, 1) then
        LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), 'Inventaire plein.', 'error')
        return false
    end
    local data = { plate = plate, vehModel = vehModel, display = display or plate }
    LSLegacy.Inventory.AddItemInInventory(player, C.Item, 1, label or KeyHanger.L('key_label', plate), nil, data)
    LSLegacy.SendEventToClient('notify', src, KeyHanger.L('title'), KeyHanger.L('key_created', display or plate, plate), 'success')
    return true
end
exports('giveVehicleKey', giveVehicleKey)

LSLegacy.RegisterServerEvent('keyhanger:createKey', function(plate, vehModel, display)
    local src = source
    if not plate then return end
    giveVehicleKey(src, plate, vehModel, display)
end)

-- Installer un support par script (autres modules)
exports('createBoard', function(data)
    if not data or not data.coords then return end
    local board = (data.board and C.Boards[data.board]) and data.board or C.DefaultBoard
    local ownerType = data.ownerType or "public"
    local insertId = MySQL.insert.await([[
        INSERT INTO keyhanger_boards (label, board, owner_type, owner_id, owner_name, coords, heading, access)
        VALUES (?, ?, ?, ?, ?, ?, ?, '{}')
    ]], {
        data.label or KeyHanger.GetBoardDef(board).label, board, ownerType,
        data.ownerId or "", data.ownerName or "",
        json.encode(data.coords), (data.heading or 0.0) + 0.0,
    })
    if not insertId then return end
    local b = {
        id = insertId, label = data.label or KeyHanger.GetBoardDef(board).label, board = board,
        ownerType = ownerType, ownerId = data.ownerId or "", ownerName = data.ownerName or "",
        coords = data.coords, heading = (data.heading or 0.0) + 0.0, access = {},
    }
    KeyHanger.Boards[insertId] = b
    ensureDatastore(b)
    syncBoardToAll(b)
    return insertId
end)

LSLegacy.RegisterCommand(C.Placement.command, C.Placement.group, function(player)
    LSLegacy.SendEventToClient('keyhanger:placement:start', player.source)
end, { help = "Installer un porte-clés mural" })

if C.Key.createCommand.enabled then
    LSLegacy.RegisterCommand(C.Key.createCommand.name, C.Key.createCommand.group, function(player)
        LSLegacy.SendEventToClient('keyhanger:createKeyForNearest', player.source)
    end, { help = "Créer une clé pour le véhicule le plus proche" })
end
