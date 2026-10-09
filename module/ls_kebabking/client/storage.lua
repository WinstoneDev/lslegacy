-- ls_kebabking (client) — stockages et plateaux.
-- L'ouverture réelle est décidée par le serveur : le client demande, le
-- serveur vérifie (job, service, distance, grade) puis renvoie l'ordre
-- d'ouverture du conteneur.

function KK.OpenStorage(storageId)
    local storage = KKConfig.Storages[storageId]
    if not storage or not storage.enabled then return end
    TriggerServerEvent(KKConfig.Prefix .. ':storage:open', storageId)
end

function KK.OpenTray(trayId)
    if not KKConfig.Trays.enabled then return end
    TriggerServerEvent(KKConfig.Prefix .. ':tray:open', trayId)
end

-- Le conteneur générique du framework réutilise l'UI "coffre" de l'inventaire.
RegisterNetEvent(KKConfig.Prefix .. ':container:open', function(name, label, maxWeight)
    if type(name) ~= 'string' then return end
    TriggerEvent('inventory:openContainer', name, label, maxWeight)
end)
