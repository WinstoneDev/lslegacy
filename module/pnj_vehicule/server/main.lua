-- Le joueur monte au volant du véhicule PNJ abandonné (cf. client/main.lua) :
-- on crée le datastore de la boîte à gants (comme le ferait l'ouverture
-- normale de l'inventaire véhicule, cf. inventory/client/main.lua) et on tire
-- la chance d'y avoir déjà laissé la clé du véhicule (bonne plaque).
LSLegacy.Events.Register('pnjvehicule:seedGlovebox', function(plate, model, maxWeight)
    local src = source
    local player = LSLegacy.Validate.Player(src)
    if not player then return end

    plate = tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if plate == '' then return end

    local name = 'bag_' .. plate
    if LSLegacy.DataStores[name] then return end -- déjà créé (ex: le joueur remonte)

    maxWeight = LSLegacy.Validate.PositiveInteger(maxWeight, { allowZero = true }) or 5
    LSLegacy.DataStore.RegisterDataStore(name, {
        name = name,
        type = 'trunk',
        inventory = {},
        money = 0,
        dirty = 0,
        maxWeight = maxWeight,
    })

    if math.random(100) <= PNJVehicule.Config.GloveboxKeyChance then
        local datastore = LSLegacy.DataStores[name]
        LSLegacy.DataStore.AddItemInInventory(datastore, KeyHanger.Config.Item, 1,
            KeyHanger.L('key_label', plate), nil, { plate = plate, vehModel = model, display = plate })
        LSLegacy.Events.SendToClient('notify', src, KeyHanger.L('title'), PNJVehicule.Config.Messages.keysFound, 'success')
    end
end)
