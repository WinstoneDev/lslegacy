-- ls_burgershot (client) — stockages et plateaux.
-- L'ouverture réelle est décidée par le serveur : le client demande, le
-- serveur vérifie (job, service, distance, grade) puis renvoie l'ordre
-- d'ouverture du conteneur.

function BS.OpenStorage(storageId)
    local storage = BSConfig.Storages[storageId]
    if not storage or not storage.enabled then return end
    TriggerServerEvent(BSConfig.Prefix .. ':storage:open', storageId)
end

function BS.OpenTray(trayId)
    if not BSConfig.Trays.enabled then return end
    TriggerServerEvent(BSConfig.Prefix .. ':tray:open', trayId)
end

-- Le conteneur générique du framework réutilise l'UI "coffre" de l'inventaire.
RegisterNetEvent(BSConfig.Prefix .. ':container:open', function(name, label, maxWeight)
    if type(name) ~= 'string' then return end
    TriggerEvent('inventory:openContainer', name, label, maxWeight)
end)
