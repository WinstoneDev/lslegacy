-- Rendu physique des supports + clés, ciblage ox_target, synchronisation, et utilisation de la clé de véhicule.

local C = KeyHanger.Config
local ox_target = exports['ox_target']

KeyHanger.Boards = {}     -- [id] = board (synchronisé serveur, contient .keys pour les props)
local spawned   = {}      -- [id] = { board = handle, keys = {handle...}, sig = string }

local function Dbg(...) if C.Debug then print("[keyhanger]", ...) end end

local function LoadModel(model)
    local hash = type(model) == "number" and model or GetHashKey(model)
    if not IsModelValid(hash) then return nil end
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    end
    if not HasModelLoaded(hash) then return nil end
    return hash
end
KeyHanger.LoadModel = LoadModel

-- noCollision=true uniquement pour les clés décoratives. Le support garde sa collision, ox_target en a besoin (le raycast doit s'arrêter dessus).
local function MakeProp(model, x, y, z, heading, noCollision)
    local hash = LoadModel(model)
    if not hash then return nil end
    local obj = CreateObjectNoOffset(hash, x, y, z, false, false, false)
    SetEntityHeading(obj, heading or 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    if noCollision then SetEntityCollision(obj, false, false) end
    SetModelAsNoLongerNeeded(hash)
    return obj
end

local function CanManageLocal(board)
    local pd = LSLegacy.PlayerData
    if not pd or not board then return false end
    if board.ownerType == "job" then return pd.job == board.ownerId end
    if board.ownerType == "faction" then return pd.faction == board.ownerId end
    return board.ownerId == pd.identifier
end

-- Ciblage sur l'entité du support (le prop a sa collision, le raycast s'arrête dessus) : une zone sphère serait inutile ici.
local function AddBoardTarget(id, handle)
    ox_target:addLocalEntity(handle, {
        {
            name     = "keyhanger:open:" .. id,
            label    = KeyHanger.L('target_open'),
            icon     = C.Target.icon,
            distance = C.Target.distance,
            onSelect = function() KeyHanger.OpenBoard(id) end,
        },
        {
            name        = "keyhanger:manage:" .. id,
            label       = KeyHanger.L('target_manage'),
            icon        = "fa-solid fa-gear",
            distance    = C.Target.distance,
            canInteract = function() return CanManageLocal(KeyHanger.Boards[id]) end,
            onSelect    = function() KeyHanger.OpenManage(id) end,
        },
    })
end

local function RemoveBoardTarget(id, handle)
    if handle and DoesEntityExist(handle) then
        ox_target:removeLocalEntity(handle, { "keyhanger:open:" .. id, "keyhanger:manage:" .. id })
    end
end

local function KeysSignature(board)
    local t = {}
    for i, k in ipairs(board.keys or {}) do t[i] = k.prop end
    return table.concat(t, "|")
end

local function ClearKeys(s)
    for _, h in ipairs(s.keys) do
        if DoesEntityExist(h) then DeleteEntity(h) end
    end
    s.keys = {}
end

local function BuildKeys(id, board, showKeys)
    local s = spawned[id]
    if not s or not DoesEntityExist(s.board) then return end
    ClearKeys(s)
    s.sig = KeysSignature(board)
    Dbg(("buildKeys #%s show=%s keys=%d"):format(id, tostring(showKeys), #(board.keys or {})))
    if not showKeys then return end

    -- Placement en coordonnées monde depuis l'orientation du support, pour que les clés apparaissent toujours devant la planche.
    local bc = GetEntityCoords(s.board)
    local h  = math.rad(board.heading or 0.0)
    local fwdX, fwdY     = -math.sin(h), math.cos(h)
    local rightX, rightY =  math.cos(h), math.sin(h)

    local slots = KeyHanger.GetSlots(board.board)
    for i, key in ipairs(board.keys or {}) do
        local slot = slots[i]
        if slot then
            local kx = bc.x + rightX * slot.x + fwdX * slot.y
            local ky = bc.y + rightY * slot.x + fwdY * slot.y
            local kz = bc.z + slot.z
            local keyObj = MakeProp(key.prop, kx, ky, kz, board.heading, true)
            Dbg(("  key %d prop=%s obj=%s @ %.2f %.2f %.2f"):format(i, tostring(key.prop), tostring(keyObj), kx, ky, kz))
            if keyObj then
                SetEntityRotation(keyObj, C.KeyRotation.pitch, C.KeyRotation.roll, board.heading, 2, true)
                s.keys[i] = keyObj
            end
        end
    end
end

local function SpawnBoard(id, board)
    if spawned[id] then return end
    local c = board.coords
    local model = KeyHanger.GetBoardDef(board.board).model
    local handle = MakeProp(model, c.x, c.y, c.z, board.heading)
    Dbg(("spawnBoard #%s model=%s handle=%s @ %.2f %.2f %.2f"):format(id, tostring(model), tostring(handle), c.x, c.y, c.z))
    if not handle then return end   -- modèle pas (encore) chargé : réessai au prochain passage
    spawned[id] = { board = handle, keys = {}, sig = "" }
    AddBoardTarget(id, handle)
    BuildKeys(id, board, not C.Render.lod)
end

local function Despawn(id)
    local s = spawned[id]
    if not s then return end
    if s.board and DoesEntityExist(s.board) then RemoveBoardTarget(id, s.board) end
    ClearKeys(s)
    if s.board and DoesEntityExist(s.board) then DeleteEntity(s.board) end
    spawned[id] = nil
end
KeyHanger.Despawn = Despawn

CreateThread(function()
    while true do
        local pc = GetEntityCoords(PlayerPedId())
        for id, board in pairs(KeyHanger.Boards) do
            local c = board.coords
            local dist = #(pc - vector3(c.x, c.y, c.z))
            if dist <= C.Render.spawnDistance then
                if not spawned[id] then SpawnBoard(id, board) end
                local s = spawned[id]
                if s then
                    local showKeys = (not C.Render.lod) or dist <= C.Render.keyLodDistance
                    local sigNow = KeysSignature(board)
                    local haveKeys = #s.keys > 0
                    if s.sig ~= sigNow or (showKeys and not haveKeys and #(board.keys or {}) > 0) or (not showKeys and haveKeys) then
                        BuildKeys(id, board, showKeys)
                    end
                end
            else
                if spawned[id] then Despawn(id) end
            end
        end
        for id in pairs(spawned) do
            if not KeyHanger.Boards[id] then Despawn(id) end
        end
        Wait(800)
    end
end)

LSLegacy.Events.Register('keyhanger:syncAll', function(boards)
    KeyHanger.Boards = boards or {}
    local n = 0 ; for _ in pairs(KeyHanger.Boards) do n = n + 1 end
    Dbg("sync:all -> " .. n .. " support(s)")
    for id in pairs(spawned) do
        if not KeyHanger.Boards[id] then Despawn(id) end
    end
end)

LSLegacy.Events.Register('keyhanger:syncBoard', function(board)
    if not board or not board.id then return end
    Dbg("sync:board #" .. tostring(board.id))
    KeyHanger.Boards[board.id] = board
    local s = spawned[board.id]
    if s then
        local pc = GetEntityCoords(PlayerPedId())
        local dist = #(pc - vector3(board.coords.x, board.coords.y, board.coords.z))
        local showKeys = (not C.Render.lod) or dist <= C.Render.keyLodDistance
        BuildKeys(board.id, board, showKeys)
    end
end)

LSLegacy.Events.Register('keyhanger:syncRemove', function(id)
    KeyHanger.Boards[id] = nil
    Despawn(id)
end)

CreateThread(function()
    while not (LSLegacy.PlayerData and LSLegacy.PlayerData.identifier) do Wait(500) end
    Wait(1000)
    LSLegacy.Events.SendToServer('keyhanger:requestBoards')
end)

local function ReachAnim()
    LSLegacy.RequestAnimDict("anim@heists@keycard@", function()
        TaskPlayAnim(PlayerPedId(), "anim@heists@keycard@", "exit", 8.0, -8.0, 600, 48, 0, false, false, false)
    end)
    Wait(450)
    ClearPedTasks(PlayerPedId())
end

function KeyHanger.OpenBoard(id)
    if not KeyHanger.Boards[id] then return end
    ReachAnim()
    LSLegacy.Events.SendToServer('keyhanger:open', id)
end

-- Le serveur demande d'ouvrir l'inventaire du conteneur
LSLegacy.Events.Register('keyhanger:openContainer', function(name, label, maxWeight)
    TriggerEvent('inventory:openContainer', name, KeyHanger.L('container_label', label or "?"), maxWeight)
end)

local MG = {}
MG.menu   = RageUI.CreateMenu("Porte-clés", "Gestion du support")
MG.shares = RageUI.CreateSubMenu(MG.menu, "Porte-clés", "Personnes autorisées")
MG.menu:DisplayGlare(true)

local function GetBoard() return KeyHanger.Boards[KeyHanger.CurrentBoard] end

local function RenderManage()
    local board = GetBoard()
    if not board then return RageUI.CloseAll() end
    RageUI.Separator("↓ " .. board.label .. " ↓")
    RageUI.Button(KeyHanger.L('manage_rename'), KeyHanger.L('manage_rename_desc', board.label), {}, true, {
        onSelected = function()
            local name = LSLegacy.KeyboardInput(KeyHanger.L('manage_rename_input'), 48)
            if name and name ~= "" then
                LSLegacy.Events.SendToServer('keyhanger:rename', board.id, name)
            end
        end,
    })
    if board.ownerType == "personal" or board.ownerType == "shared" then
        RageUI.Button(KeyHanger.L('manage_share'), KeyHanger.L('manage_share_desc'), {}, true, {
            onSelected = function()
                local closest = LSLegacy.GetClosestPlayer(PlayerPedId(), 4.0)
                if closest and closest ~= 0 then
                    local serverId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(closest))
                    LSLegacy.Events.SendToServer('keyhanger:share', board.id, serverId)
                else
                    LSLegacy.ShowNotification(KeyHanger.L('title'), KeyHanger.L('share_none_nearby'), 'error')
                end
            end,
        })
        local count = 0
        for _ in pairs(board.access or {}) do count = count + 1 end
        RageUI.Button(KeyHanger.L('manage_shares', count), KeyHanger.L('manage_shares_desc'), { RightLabel = "→" }, true, {}, MG.shares)
    end
    RageUI.Line()
    RageUI.Button(KeyHanger.L('manage_remove'), KeyHanger.L('manage_remove_desc'), {}, true, {
        onSelected = function()
            LSLegacy.Events.SendToServer('keyhanger:remove', board.id)
            RageUI.CloseAll()
        end,
    })
end

local function RenderShares()
    local board = GetBoard()
    if not board then return RageUI.CloseAll() end
    RageUI.Separator(KeyHanger.L('manage_shares', 0))
    local any = false
    for identifier, name in pairs(board.access or {}) do
        any = true
        RageUI.Button(name, identifier, { RightLabel = "✖" }, true, {
            onSelected = function()
                LSLegacy.Events.SendToServer('keyhanger:unshare', board.id, identifier)
            end,
        })
    end
    if not any then RageUI.Button("Aucun partage", nil, {}, false, {}) end
end

function KeyHanger.OpenManage(id)
    if not KeyHanger.Boards[id] then return end
    KeyHanger.CurrentBoard = id
    if RageUI.GetInMenu() then RageUI.CloseAll() end
    RageUI.Visible(MG.menu, true)
    if MG.rendering then return end
    MG.rendering = true
    CreateThread(function()
        while MG.rendering do
            Wait(0)
            RageUI.IsVisible(MG.menu, function() RenderManage() end)
            RageUI.IsVisible(MG.shares, function() RenderShares() end)
            if not RageUI.Visible(MG.menu) and not RageUI.Visible(MG.shares) then
                MG.rendering = false
                KeyHanger.CurrentBoard = nil
            end
        end
    end)
end

local function Trim(s) return (s and s:gsub("%s+$", "")) or "" end

LSLegacy.Events.Register('keyhanger:useKey', function(data)
    if not data or not data.plate then return end
    local target = Trim(data.plate)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local veh, best = nil, C.Key.useDistance
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if Trim(GetVehicleNumberPlateText(v)) == target then
            local d = #(coords - GetEntityCoords(v))
            if d <= best then best = d ; veh = v end
        end
    end

    if not veh then
        return LSLegacy.ShowNotification(KeyHanger.L('title'), KeyHanger.L('key_too_far'), 'error')
    end

    LSLegacy.RequestAnimDict("anim@mp_player_intmenu@key_fob@", function()
        TaskPlayAnim(ped, "anim@mp_player_intmenu@key_fob@", "fob_click", 4.0, -1, 600, 48, 0, false, false, false)
    end)

    local locked = GetVehicleDoorLockStatus(veh) == 2
    if locked then
        SetVehicleDoorsLocked(veh, 1)
        SetVehicleDoorsLockedForAllPlayers(veh, false)
        LSLegacy.ShowNotification(KeyHanger.L('title'), KeyHanger.L('key_unlocked'), 'success')
    else
        SetVehicleDoorsLocked(veh, 2)
        SetVehicleDoorsLockedForAllPlayers(veh, true)
        LSLegacy.ShowNotification(KeyHanger.L('title'), KeyHanger.L('key_locked'), 'success')
    end

    if C.Key.honkOnLock then
        SetVehicleLights(veh, 2)
        Citizen.SetTimeout(150, function() if DoesEntityExist(veh) then SetVehicleLights(veh, 0) end end)
        StartVehicleHorn(veh, 80, GetHashKey("HELDDOWN"), false)
    end
    Citizen.SetTimeout(700, function() ClearPedTasks(ped) end)
end)

LSLegacy.Events.Register('keyhanger:createKeyForNearest', function()
    local ped = PlayerPedId()
    local veh = LSLegacy.GetClosestVehicle(GetEntityCoords(ped), 6.0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        return LSLegacy.ShowNotification(KeyHanger.L('title'), KeyHanger.L('key_no_vehicle'), 'error')
    end
    local plate = Trim(GetVehicleNumberPlateText(veh))
    local modelHash = GetEntityModel(veh)
    local display = GetLabelText(GetDisplayNameFromVehicleModel(modelHash))
    if not display or display == "NULL" then display = GetDisplayNameFromVehicleModel(modelHash) end
    LSLegacy.Events.SendToServer('keyhanger:createKey', plate, modelHash, display)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(spawned) do Despawn(id) end
end)
