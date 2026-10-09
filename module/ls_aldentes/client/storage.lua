-- ls_aldentes (client) — stockages et plateaux.
-- L'ouverture réelle est décidée par le serveur : le client demande, le
-- serveur vérifie (job, service, distance, grade) puis renvoie l'ordre
-- d'ouverture du conteneur.

function ALD.OpenStorage(storageId)
    local storage = ALDConfig.Storages[storageId]
    if not storage or not storage.enabled then return end
    TriggerServerEvent(ALDConfig.Prefix .. ':storage:open', storageId)
end

function ALD.OpenTray(trayId)
    if not ALDConfig.Trays.enabled then return end
    TriggerServerEvent(ALDConfig.Prefix .. ':tray:open', trayId)
end

-- Le conteneur générique du framework réutilise l'UI "coffre" de l'inventaire.
RegisterNetEvent(ALDConfig.Prefix .. ':container:open', function(name, label, maxWeight)
    if type(name) ~= 'string' then return end
    TriggerEvent('inventory:openContainer', name, label, maxWeight)
end)
