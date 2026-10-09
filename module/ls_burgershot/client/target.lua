-- ls_burgershot (client) — toutes les zones ox_target de la ressource.
-- Elles sont construites depuis config/config.lua : aucune coordonnée en dur ici.
--
-- Visibilité : les points « employés » (stations, stockages, caisse) ne sont
-- créés QUE pour un joueur du job burgershot actuellement en service — un
-- client ou un joueur non-employé ne les voit ni ne peut viser dessus. Les
-- zones sont donc ajoutées/retirées dynamiquement (BS.RefreshZones, appelée
-- depuis client/main.lua à chaque changement de job/service), pas créées une
-- fois pour toutes au chargement. Seuls les plateaux restent visibles de
-- tous, clients inclus — même patron que ls_kebabking/client/target.lua.
--
-- Prise de service : gérée via le MDT (BS.ToggleDuty), plus de point
-- physique dédié — voir client/main.lua.

local oxTarget = exports.ox_target

local employeeZoneIds = {}
local zonesVisible = false

local function AddEmployeeZones()
    -- ── Stations de cuisine ──────────────────────────────────────────────
    for stationId, station in pairs(BSConfig.Stations) do
        employeeZoneIds[#employeeZoneIds + 1] = oxTarget:addBoxZone({
            coords   = station.coords,
            size     = station.size,
            rotation = station.rotation,
            debug    = BSConfig.Debug,
            options  = {
                {
                    name        = BSConfig.Prefix .. '_station_' .. stationId,
                    icon        = station.icon,
                    label       = station.label,
                    distance    = station.distance or 2.0,
                    canInteract = function() return BS.CanUseStation(station.minGrade) end,
                    onSelect    = function() BS.OpenStation(stationId) end,
                },
            },
        })
    end

    -- ── Stockages ────────────────────────────────────────────────────────
    for storageId, storage in pairs(BSConfig.Storages) do
        if storage.enabled then
            employeeZoneIds[#employeeZoneIds + 1] = oxTarget:addBoxZone({
                coords   = storage.coords,
                size     = storage.size,
                rotation = storage.rotation,
                debug    = BSConfig.Debug,
                options  = {
                    {
                        name        = BSConfig.Prefix .. '_storage_' .. storageId,
                        icon        = storage.icon,
                        label       = storage.label,
                        distance    = storage.distance or 2.0,
                        canInteract = function() return BS.CanUseStation(storage.minGrade) end,
                        onSelect    = function() BS.OpenStorage(storageId) end,
                    },
                },
            })
        end
    end

    -- ── Caisse ───────────────────────────────────────────────────────────
    if BSConfig.Cash.enabled then
        employeeZoneIds[#employeeZoneIds + 1] = oxTarget:addBoxZone({
            coords   = BSConfig.Cash.coords,
            size     = BSConfig.Cash.size,
            rotation = BSConfig.Cash.rotation,
            debug    = BSConfig.Debug,
            options  = {
                {
                    name        = BSConfig.Prefix .. '_cash',
                    icon        = BSConfig.Cash.icon,
                    label       = BSConfig.Cash.label,
                    distance    = BSConfig.Cash.distance,
                    canInteract = function() return BS.CanUseStation() end,
                    onSelect    = function() BS.OpenCash() end,
                },
            },
        })
    end
end

local function RemoveEmployeeZones()
    for _, id in ipairs(employeeZoneIds) do
        oxTarget:removeZone(id)
    end
    employeeZoneIds = {}
end

---RefreshZones — à appeler à chaque changement de job/service. N'ajoute/ne
---retire les zones que si l'état visible a réellement changé, pour ne pas
---spammer ox_target à chaque event.
function BS.RefreshZones()
    local shouldShowEmployee = BS.IsEmployee() and BS.Client.onDuty
    if shouldShowEmployee ~= zonesVisible then
        zonesVisible = shouldShowEmployee
        if shouldShowEmployee then AddEmployeeZones() else RemoveEmployeeZones() end
    end
end

-- ── Plateaux ─────────────────────────────────────────────────────────────
-- Seul point accessible aux clients : contrairement aux zones employés
-- ci-dessus, les plateaux sont créés une fois pour toutes au chargement,
-- visibles et ciblables par tout le monde (un client doit pouvoir récupérer
-- sa commande sans être employé ni en service).
CreateThread(function()
    if not BSConfig.Trays.enabled then return end
    for _, tray in ipairs(BSConfig.Trays.list) do
        oxTarget:addBoxZone({
            coords   = tray.coords,
            size     = BSConfig.Trays.size,
            rotation = BSConfig.Trays.rotation,
            debug    = BSConfig.Debug,
            options  = {
                {
                    name        = BSConfig.Prefix .. '_tray_' .. tray.id,
                    icon        = 'fa-solid fa-tray',
                    label       = tray.label,
                    distance    = BSConfig.Trays.distance,
                    canInteract = function()
                        if BS.IsEmployee() then return true end
                        return BSConfig.Trays.customersCanTake
                    end,
                    onSelect    = function() BS.OpenTray(tray.id) end,
                },
            },
        })
    end
end)

-- ox_target retire lui-même les zones d'une ressource à son arrêt
-- (onClientResourceStop dans ox_target/client/api.lua) : pas de nettoyage
-- manuel ici au-delà de BS.RefreshZones, il ne ferait que produire des
-- avertissements.
