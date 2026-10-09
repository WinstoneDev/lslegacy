LSLegacy.Pickup = {}

LSLegacy.IsRetrieving = false

local function SpawnPickupObject(data)
    local object = CreateObject(data.model, data.coords.x, data.coords.y, data.coords.z - 1, false, false, false)
    SetEntityHeading(object, data.coords.w)
    SetEntityAsMissionEntity(object, true, false)
    if Config.PickupModelCollision[data.model] then
        SetEntityLodDist(object, 250)
    else
        SetEntityLodDist(object, 20)
        SetEntityCollision(object, false, false)
    end
    return object
end

LSLegacy.Events.Register('interactItemPickup', function(type, data)
    if type == "create" then
        LSLegacy.Pickup[data.id] = {
            id = data.id,
            object = SpawnPickupObject(data),
            name = data.name,
            label = data.label,
            count = data.count,
            coords = vector3(data.coords.x, data.coords.y, data.coords.z),
            uniqueId = data.uniqueId,
            data = data.data,
            type = data.type
        }
    elseif type == "retrieve" then
        if LSLegacy.Pickup[data.id] then
            DeleteEntity(LSLegacy.Pickup[data.id].object)
            LSLegacy.Pickup[data.id] = nil
        end
        LSLegacy.IsRetrieving = false
    end
end)

-- Resynchronisation après un changement de bucket (garage, appart, instance créateur…) :
-- les objets jetés ailleurs ne doivent plus être visibles/ramassables ici, et ceux
-- déjà présents dans ce bucket doivent apparaître.
LSLegacy.Events.Register('pickup:syncBucket', function(list)
    for _, p in pairs(LSLegacy.Pickup) do
        if p.object and DoesEntityExist(p.object) then DeleteEntity(p.object) end
    end
    LSLegacy.Pickup = {}
    for _, data in ipairs(list or {}) do
        LSLegacy.Pickup[data.id] = {
            id = data.id,
            object = SpawnPickupObject(data),
            name = data.name,
            label = data.label,
            count = data.count,
            coords = vector3(data.coords.x, data.coords.y, data.coords.z),
            uniqueId = data.uniqueId,
            data = data.data,
            type = data.type
        }
    end
end)

Citizen.CreateThread(function()
    local time = 1000
    while true do
        if #LSLegacy.Pickup == 0 then
            time = 1000
        end
        for k, v in pairs(LSLegacy.Pickup) do
            local pPed = PlayerPedId()
            local pCoords = GetEntityCoords(pPed)
            local distance = GetDistanceBetweenCoords(pCoords, vector3(v.coords.x, v.coords.y, v.coords.z), true)

            if distance <= 3.5 then
                time = 1
                LSLegacy.DrawText3D(v.coords.x, v.coords.y, v.coords.z - 0.7, "Appuyez sur ~b~E~s~ pour ramasser\n~y~"..v.label, 5)
                if IsControlJustPressed(0, 51) and distance < 1.5 and not IsPedInAnyVehicle(pPed, false) and IsPedOnFoot(pPed) and not IsPedCuffed(pPed) and not LSLegacy.IsRetrieving then
                    if LSLegacy.GetClosestPlayer(PlayerPedId(), 3.5) == nil then
                        LSLegacy.IsRetrieving = true
                        RequestAnimDict('random@domestic')
                        while not HasAnimDictLoaded('random@domestic') do
                            Wait(100)
                        end
                        TaskPlayAnim(pPed, 'random@domestic', 'pickup_low', 8.0, 8.0, -1, 0, 1, 0, 0, 0)
                        Wait(150)
                        LSLegacy.Events.SendToServer("removeItemPickup", {
                            id = v.id,
                            object = v.object,
                            name = v.name,
                            label = v.label,
                            count = v.count,
                            coords = v.coords,
                            uniqueId = v.uniqueId,
                            data = v.data,
                            type = v.type
                        })
                    end
                end
            end
        end
        Wait(time)
    end
end)
