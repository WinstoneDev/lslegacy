-- ls_burgershot (serveur) — stockages (réserve, frigo, congélateur, boissons)
-- et plateaux, portés par le système DataStore générique de LSLegacy.
--
-- Aucun autre restaurant ne peut y accéder : la garde d'accès n'autorise que
-- les conteneurs dont le nom commence par BSConfig.Prefix, et uniquement pour
-- un employé de CE job (les plateaux font exception pour les clients).

local Core = exports['lslegacy']

-- Création paresseuse (même raison que module/atelier) : les DataStores sont
-- chargés en base de façon asynchrone au démarrage ; enregistrer trop tôt
-- écraserait un stock déjà persisté.
local function EnsureStorage(storageId)
    local storage = BSConfig.Storages[storageId]
    if not storage or not storage.enabled then return nil end
    local name = BS.DataStoreName('storage', storageId)
    Core:ensureDataStore(name, storage.cold == 'pro' and 'pro_fridge' or 'stash', storage.maxWeight)
    return name
end

local function EnsureTray(trayId)
    local tray = BS.GetTray(trayId)
    if not tray then return nil end
    local name = BS.DataStoreName('tray', trayId)
    Core:ensureDataStore(name, 'tray', BSConfig.Trays.maxWeight)
    return name
end

-- ── Garde d'accès ────────────────────────────────────────────────────────
CreateThread(function()
    Core:registerContainerGuard('^' .. BSConfig.Prefix .. '_', function(src, name, action, _item)
        -- Stockages professionnels : employé, en service, à portée.
        local storageId = name:match('^' .. BSConfig.Prefix .. '_storage_(.+)$')
        if storageId then
            local storage = BSConfig.Storages[storageId]
            if not storage or not storage.enabled then return false end
            if not BS.Sec.Employee(src, storage.minGrade) then return false end
            if not BS.IsOnDuty(src) then return false end
            return BS.Sec.NearCoords(src, storage.coords, (storage.distance or 2.0) + BSConfig.Security.maxDistance)
        end

        -- Plateaux : l'équipe dépose, le client récupère.
        local trayId = tonumber(name:match('^' .. BSConfig.Prefix .. '_tray_(%d+)$'))
        if trayId then
            local tray = BS.GetTray(trayId)
            if not tray then return false end
            if not BS.Sec.NearCoords(src, tray.coords, BSConfig.Trays.distance + BSConfig.Security.maxDistance) then
                return false
            end
            if BS.Sec.Employee(src) then
                -- Un employé hors service reste un client comme un autre.
                if BS.IsOnDuty(src) then return true end
            end
            if action == 'take' then return BSConfig.Trays.customersCanTake end
            return BSConfig.Trays.customersCanPut
        end

        -- Coffre de l'entreprise (server/cash.lua)
        if BS.SafeGuard then return BS.SafeGuard(src, name, action, _item) end

        return false
    end)
end)

-- ── Ouverture ────────────────────────────────────────────────────────────
RegisterNetEvent(BSConfig.Prefix .. ':storage:open', function(storageId)
    local src = source
    if not BS.Sec.Allow(src, 'storage') then return end
    if type(storageId) ~= 'string' then return end

    local storage = BSConfig.Storages[storageId]
    if not storage or not storage.enabled then
        BS.Notify(src, "Ce stockage est désactivé.", 'error')
        return
    end

    local player = BS.CanWork(src, storage.minGrade, storage.coords,
        (storage.distance or 2.0) + BSConfig.Security.maxDistance)
    if not player then return end

    local name = EnsureStorage(storageId)
    if not name then return end

    Core:syncDataStores(src)
    TriggerClientEvent(BSConfig.Prefix .. ':container:open', src, name,
        ('%s — %s'):format(BSConfig.JobLabel, storage.label), storage.maxWeight)
end)

RegisterNetEvent(BSConfig.Prefix .. ':tray:open', function(trayId)
    local src = source
    if not BS.Sec.Allow(src, 'tray') then return end
    if not BSConfig.Trays.enabled then return end

    trayId = tonumber(trayId)
    local tray = BS.GetTray(trayId)
    if not tray then return end

    if not BS.Sec.Player(src) then return end
    if not BS.Sec.NearCoords(src, tray.coords, BSConfig.Trays.distance + BSConfig.Security.maxDistance) then
        BS.Notify(src, "Vous êtes trop loin du plateau.", 'error')
        return
    end

    -- Un non-employé n'ouvre le plateau que si les clients peuvent y toucher.
    local isStaff = BS.Sec.Employee(src) ~= nil and BS.IsOnDuty(src)
    if not isStaff and not (BSConfig.Trays.customersCanTake or BSConfig.Trays.customersCanPut) then
        return
    end

    local name = EnsureTray(trayId)
    if not name then return end

    Core:syncDataStores(src)
    TriggerClientEvent(BSConfig.Prefix .. ':container:open', src, name, tray.label, BSConfig.Trays.maxWeight)
end)
