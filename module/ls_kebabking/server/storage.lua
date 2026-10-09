-- ls_kebabking (serveur) — stockages (réserve, frigo, congélateur, boissons)
-- et plateaux, portés par le système DataStore générique de LSLegacy.
--
-- Aucun autre restaurant ne peut y accéder : la garde d'accès n'autorise que
-- les conteneurs dont le nom commence par KKConfig.Prefix, et uniquement pour
-- un employé de CE job (les plateaux font exception pour les clients).

local Core = exports['lslegacy']

-- Création paresseuse (même raison que module/atelier) : les DataStores sont
-- chargés en base de façon asynchrone au démarrage ; enregistrer trop tôt
-- écraserait un stock déjà persisté.
local function EnsureStorage(storageId)
    local storage = KKConfig.Storages[storageId]
    if not storage or not storage.enabled then return nil end
    local name = KK.DataStoreName('storage', storageId)
    Core:ensureDataStore(name, storage.cold == 'pro' and 'pro_fridge' or 'stash', storage.maxWeight)
    return name
end

local function EnsureTray(trayId)
    local tray = KK.GetTray(trayId)
    if not tray then return nil end
    local name = KK.DataStoreName('tray', trayId)
    Core:ensureDataStore(name, 'tray', KKConfig.Trays.maxWeight)
    return name
end

-- ── Garde d'accès ────────────────────────────────────────────────────────
CreateThread(function()
    Core:registerContainerGuard('^' .. KKConfig.Prefix .. '_', function(src, name, action, _item)
        -- Stockages professionnels : employé, en service, à portée.
        local storageId = name:match('^' .. KKConfig.Prefix .. '_storage_(.+)$')
        if storageId then
            local storage = KKConfig.Storages[storageId]
            if not storage or not storage.enabled then return false end
            if not KK.Sec.Employee(src, storage.minGrade) then return false end
            if not KK.IsOnDuty(src) then return false end
            return KK.Sec.NearCoords(src, storage.coords, (storage.distance or 2.0) + KKConfig.Security.maxDistance)
        end

        -- Plateaux : l'équipe dépose, le client récupère.
        local trayId = tonumber(name:match('^' .. KKConfig.Prefix .. '_tray_(%d+)$'))
        if trayId then
            local tray = KK.GetTray(trayId)
            if not tray then return false end
            if not KK.Sec.NearCoords(src, tray.coords, KKConfig.Trays.distance + KKConfig.Security.maxDistance) then
                return false
            end
            if KK.Sec.Employee(src) then
                -- Un employé hors service reste un client comme un autre.
                if KK.IsOnDuty(src) then return true end
            end
            if action == 'take' then return KKConfig.Trays.customersCanTake end
            return KKConfig.Trays.customersCanPut
        end

        -- Coffre de l'entreprise (server/cash.lua)
        if KK.SafeGuard then return KK.SafeGuard(src, name, action, _item) end

        return false
    end)
end)

-- ── Ouverture ────────────────────────────────────────────────────────────
RegisterNetEvent(KKConfig.Prefix .. ':storage:open', function(storageId)
    local src = source
    if not KK.Sec.Allow(src, 'storage') then return end
    if type(storageId) ~= 'string' then return end

    local storage = KKConfig.Storages[storageId]
    if not storage or not storage.enabled then
        KK.Notify(src, "Ce stockage est désactivé.", 'error')
        return
    end

    local player = KK.CanWork(src, storage.minGrade, storage.coords,
        (storage.distance or 2.0) + KKConfig.Security.maxDistance)
    if not player then return end

    local name = EnsureStorage(storageId)
    if not name then return end

    Core:syncDataStores(src)
    TriggerClientEvent(KKConfig.Prefix .. ':container:open', src, name,
        ('%s — %s'):format(KKConfig.JobLabel, storage.label), storage.maxWeight)
end)

RegisterNetEvent(KKConfig.Prefix .. ':tray:open', function(trayId)
    local src = source
    if not KK.Sec.Allow(src, 'tray') then return end
    if not KKConfig.Trays.enabled then return end

    trayId = tonumber(trayId)
    local tray = KK.GetTray(trayId)
    if not tray then return end

    if not KK.Sec.Player(src) then return end
    if not KK.Sec.NearCoords(src, tray.coords, KKConfig.Trays.distance + KKConfig.Security.maxDistance) then
        KK.Notify(src, "Vous êtes trop loin du plateau.", 'error')
        return
    end

    -- Un non-employé n'ouvre le plateau que si les clients peuvent y toucher.
    local isStaff = KK.Sec.Employee(src) ~= nil and KK.IsOnDuty(src)
    if not isStaff and not (KKConfig.Trays.customersCanTake or KKConfig.Trays.customersCanPut) then
        return
    end

    local name = EnsureTray(trayId)
    if not name then return end

    Core:syncDataStores(src)
    TriggerClientEvent(KKConfig.Prefix .. ':container:open', src, name, tray.label, KKConfig.Trays.maxWeight)
end)
