-- ls_aldentes (serveur) — stockages (réserve, frigo, congélateur, boissons)
-- et plateaux, portés par le système DataStore générique de LSLegacy.
--
-- Aucun autre restaurant ne peut y accéder : la garde d'accès n'autorise que
-- les conteneurs dont le nom commence par ALDConfig.Prefix, et uniquement pour
-- un employé de CE job (les plateaux font exception pour les clients).

local Core = exports['lslegacy']

-- Création paresseuse (même raison que module/atelier) : les DataStores sont
-- chargés en base de façon asynchrone au démarrage ; enregistrer trop tôt
-- écraserait un stock déjà persisté.
local function EnsureStorage(storageId)
    local storage = ALDConfig.Storages[storageId]
    if not storage or not storage.enabled then return nil end
    local name = ALD.DataStoreName('storage', storageId)
    Core:ensureDataStore(name, storage.cold == 'pro' and 'pro_fridge' or 'stash', storage.maxWeight)
    return name
end

local function EnsureTray(trayId)
    local tray = ALD.GetTray(trayId)
    if not tray then return nil end
    local name = ALD.DataStoreName('tray', trayId)
    Core:ensureDataStore(name, 'tray', ALDConfig.Trays.maxWeight)
    return name
end

-- ── Garde d'accès ────────────────────────────────────────────────────────
CreateThread(function()
    Core:registerContainerGuard('^' .. ALDConfig.Prefix .. '_', function(src, name, action, _item)
        -- Stockages professionnels : employé, en service, à portée.
        local storageId = name:match('^' .. ALDConfig.Prefix .. '_storage_(.+)$')
        if storageId then
            local storage = ALDConfig.Storages[storageId]
            if not storage or not storage.enabled then return false end
            if not ALD.Sec.Employee(src, storage.minGrade) then return false end
            if not ALD.IsOnDuty(src) then return false end
            return ALD.Sec.NearCoords(src, storage.coords, (storage.distance or 2.0) + ALDConfig.Security.maxDistance)
        end

        -- Plateaux : l'équipe dépose, le client récupère.
        local trayId = tonumber(name:match('^' .. ALDConfig.Prefix .. '_tray_(%d+)$'))
        if trayId then
            local tray = ALD.GetTray(trayId)
            if not tray then return false end
            if not ALD.Sec.NearCoords(src, tray.coords, ALDConfig.Trays.distance + ALDConfig.Security.maxDistance) then
                return false
            end
            if ALD.Sec.Employee(src) then
                -- Un employé hors service reste un client comme un autre.
                if ALD.IsOnDuty(src) then return true end
            end
            if action == 'take' then return ALDConfig.Trays.customersCanTake end
            return ALDConfig.Trays.customersCanPut
        end

        -- Coffre de l'entreprise (server/cash.lua)
        if ALD.SafeGuard then return ALD.SafeGuard(src, name, action, _item) end

        return false
    end)
end)

-- ── Ouverture ────────────────────────────────────────────────────────────
RegisterNetEvent(ALDConfig.Prefix .. ':storage:open', function(storageId)
    local src = source
    if not ALD.Sec.Allow(src, 'storage') then return end
    if type(storageId) ~= 'string' then return end

    local storage = ALDConfig.Storages[storageId]
    if not storage or not storage.enabled then
        ALD.Notify(src, "Ce stockage est désactivé.", 'error')
        return
    end

    local player = ALD.CanWork(src, storage.minGrade, storage.coords,
        (storage.distance or 2.0) + ALDConfig.Security.maxDistance)
    if not player then return end

    local name = EnsureStorage(storageId)
    if not name then return end

    Core:syncDataStores(src)
    TriggerClientEvent(ALDConfig.Prefix .. ':container:open', src, name,
        ('%s — %s'):format(ALDConfig.JobLabel, storage.label), storage.maxWeight)
end)

RegisterNetEvent(ALDConfig.Prefix .. ':tray:open', function(trayId)
    local src = source
    if not ALD.Sec.Allow(src, 'tray') then return end
    if not ALDConfig.Trays.enabled then return end

    trayId = tonumber(trayId)
    local tray = ALD.GetTray(trayId)
    if not tray then return end

    if not ALD.Sec.Player(src) then return end
    if not ALD.Sec.NearCoords(src, tray.coords, ALDConfig.Trays.distance + ALDConfig.Security.maxDistance) then
        ALD.Notify(src, "Vous êtes trop loin du plateau.", 'error')
        return
    end

    -- Un non-employé n'ouvre le plateau que si les clients peuvent y toucher.
    local isStaff = ALD.Sec.Employee(src) ~= nil and ALD.IsOnDuty(src)
    if not isStaff and not (ALDConfig.Trays.customersCanTake or ALDConfig.Trays.customersCanPut) then
        return
    end

    local name = EnsureTray(trayId)
    if not name then return end

    Core:syncDataStores(src)
    TriggerClientEvent(ALDConfig.Prefix .. ':container:open', src, name, tray.label, ALDConfig.Trays.maxWeight)
end)
