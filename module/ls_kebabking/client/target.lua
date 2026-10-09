-- ls_kebabking (client) — toutes les zones ox_target de la ressource.
-- Elles sont construites depuis config/config.lua : aucune coordonnée en dur ici.
--
-- Visibilité : les points « employés » (stations, stockages, caisse) ne sont
-- créés QUE pour un joueur du job kebabking actuellement en service — un
-- client ou un joueur non-employé ne les voit ni ne peut viser dessus. Les
-- zones sont donc ajoutées/retirées dynamiquement (KK.RefreshZones, appelée
-- depuis client/main.lua à chaque changement de job/service), pas créées
-- une fois pour toutes au chargement. Seuls les plateaux (quand leurs vraies
-- coordonnées seront fournies) resteraient visibles de tous, clients inclus.

local oxTarget = exports.ox_target

local employeeZoneIds = {}
local zonesVisible = false

local function AddEmployeeZones()
    -- ── Stations de cuisine ──────────────────────────────────────────────
    for stationId, station in pairs(KKConfig.Stations) do
        employeeZoneIds[#employeeZoneIds + 1] = oxTarget:addBoxZone({
            coords   = station.coords,
            size     = station.size,
            rotation = station.rotation,
            debug    = KKConfig.Debug,
            options  = {
                {
                    name        = KKConfig.Prefix .. '_station_' .. stationId,
                    icon        = station.icon,
                    label       = station.label,
                    distance    = station.distance or 2.0,
                    canInteract = function() return KK.CanUseStation(station.minGrade) end,
                    onSelect    = function() KK.OpenStation(stationId) end,
                },
            },
        })
    end

    -- ── Stockages ────────────────────────────────────────────────────────
    for storageId, storage in pairs(KKConfig.Storages) do
        if storage.enabled then
            employeeZoneIds[#employeeZoneIds + 1] = oxTarget:addBoxZone({
                coords   = storage.coords,
                size     = storage.size,
                rotation = storage.rotation,
                debug    = KKConfig.Debug,
                options  = {
                    {
                        name        = KKConfig.Prefix .. '_storage_' .. storageId,
                        icon        = storage.icon,
                        label       = storage.label,
                        distance    = storage.distance or 2.0,
                        canInteract = function() return KK.CanUseStation(storage.minGrade) end,
                        onSelect    = function() KK.OpenStorage(storageId) end,
                    },
                },
            })
        end
    end

    -- ── Caisse ───────────────────────────────────────────────────────────
    if KKConfig.Cash.enabled then
        employeeZoneIds[#employeeZoneIds + 1] = oxTarget:addBoxZone({
            coords   = KKConfig.Cash.coords,
            size     = KKConfig.Cash.size,
            rotation = KKConfig.Cash.rotation,
            debug    = KKConfig.Debug,
            options  = {
                {
                    name        = KKConfig.Prefix .. '_cash',
                    icon        = KKConfig.Cash.icon,
                    label       = KKConfig.Cash.label,
                    distance    = KKConfig.Cash.distance,
                    canInteract = function() return KK.CanUseStation() end,
                    onSelect    = function() KK.OpenCash() end,
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
---retire les zones employés que si l'état visible (employé + en service)
---a réellement changé, pour ne pas spammer ox_target à chaque event.
function KK.RefreshZones()
    local shouldShow = KK.IsEmployee() and KK.Client.onDuty
    if shouldShow == zonesVisible then return end
    zonesVisible = shouldShow
    if shouldShow then
        AddEmployeeZones()
    else
        RemoveEmployeeZones()
    end
end

-- ── Plateaux ─────────────────────────────────────────────────────────────
-- Seul point accessible aux clients : contrairement aux zones employés
-- ci-dessus, les plateaux sont créés une fois pour toutes au chargement,
-- visibles et ciblables par tout le monde (un client doit pouvoir récupérer
-- sa commande sans être employé ni en service).
CreateThread(function()
    if not KKConfig.Trays.enabled then return end
    for _, tray in ipairs(KKConfig.Trays.list) do
        oxTarget:addBoxZone({
            coords   = tray.coords,
            size     = KKConfig.Trays.size,
            rotation = KKConfig.Trays.rotation,
            debug    = KKConfig.Debug,
            options  = {
                {
                    name        = KKConfig.Prefix .. '_tray_' .. tray.id,
                    icon        = 'fa-solid fa-tray',
                    label       = tray.label,
                    distance    = KKConfig.Trays.distance,
                    canInteract = function()
                        if KK.IsEmployee() then return true end
                        return KKConfig.Trays.customersCanTake
                    end,
                    onSelect    = function() KK.OpenTray(tray.id) end,
                },
            },
        })
    end
end)

-- ox_target retire lui-même les zones d'une ressource à son arrêt
-- (onClientResourceStop dans ox_target/client/api.lua) : pas de nettoyage
-- manuel ici au-delà de KK.RefreshZones, il ne ferait que produire des
-- avertissements.
