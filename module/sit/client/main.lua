-- =====================================================================
--  MODULE SIT — Client
--  Port fidèle du fonctionnement de mnr_sitanywhere (bridge ox_target +
--  logique client), adapté aux conventions LSLegacy.
-- =====================================================================

local C = Sit.Config

local sitting  = false
local sitEntity = nil
local keybind  = nil

local function Notify(msg, type)
    if lib and lib.notify then
        lib.notify({ description = msg, type = type or 'info' })
    end
end

-- Tourne un offset LOCAL (x, y, z) par le heading de l'objet pour obtenir
-- un offset MONDE : c'est ce qui garantit une orientation correcte quelle
-- que soit la rotation du prop (banc de travers, chaise pivotée...).
local function RotateOffset(offset, heading)
    local rad = math.rad(heading)
    local cosH, sinH = math.cos(rad), math.sin(rad)
    local x = offset.x * cosH - offset.y * sinH
    local y = offset.x * sinH + offset.y * cosH
    return vector3(x, y, offset.z)
end

local function StandUp()
    if not sitting then return end
    sitting = false

    if keybind then keybind:disable(true) end
    lib.hideTextUI()
    ClearPedTasks(cache.ped)

    if sitEntity and DoesEntityExist(sitEntity) then
        local netId = NetworkGetNetworkIdFromEntity(sitEntity)
        TriggerServerEvent('sit:server:free', netId)
    end
    sitEntity = nil
end

local function PlaySit(entity, seatIndex)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    local taken = lib.callback.await('sit:server:occupy', false, netId, seatIndex)
    if not taken then
        Notify("Cette place est déjà occupée", "error")
        return
    end

    local hash = GetEntityModel(entity)
    local model = Sit.Models[hash]
    local seat = model.seats[seatIndex]
    local action = Sit.Actions[model.action]
    if not action then return end

    local entityCoords = GetEntityCoords(entity)
    local entityHeading = GetEntityHeading(entity)
    local rotated = RotateOffset(vector3(seat.x, seat.y, seat.z), entityHeading)
    local coords = entityCoords + rotated
    local heading = (entityHeading + seat.w) % 360.0

    sitting  = true
    sitEntity = entity

    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z, true, false, false, false)
    TaskStartScenarioAtPosition(cache.ped, action.scenario, coords.x, coords.y, coords.z, heading, 0, true, true)

    if not keybind then
        keybind = lib.addKeybind({
            name = 'sit:keybind:get_up',
            description = "Se relever (module sit)",
            defaultKey = C.Key,
            disabled = true,
            onReleased = function(self)
                self:disable(true)
                StandUp()
            end,
        })
    end

    lib.showTextUI(("[%s] Se relever"):format(C.Key))
    keybind:disable(false)
end

local function TrySit(entity)
    if sitting or cache.vehicle then return end
    if not DoesEntityExist(entity) then return end

    if not NetworkGetEntityIsNetworked(entity) then
        NetworkRegisterEntityAsNetworked(entity)
        Wait(100)
    end

    if not NetworkGetEntityIsNetworked(entity) then
        return
    end

    local hash = GetEntityModel(entity)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    local seatIndex = lib.callback.await('sit:server:getFree', 200, netId, hash)
    if not seatIndex then
        Notify("Cette place est déjà occupée", "error")
        return
    end

    PlaySit(entity, seatIndex)
end

-- ---------------------------------------------------------------------
--  CIBLAGE OX_TARGET — uniquement sur les modèles calibrés (data/models.lua)
-- ---------------------------------------------------------------------

local targetModels = {}
for hash in pairs(Sit.Models) do
    targetModels[#targetModels + 1] = hash
end

exports.ox_target:addModel(targetModels, {
    {
        name     = 'sit:target:sit',
        icon     = 'fa-solid fa-chair',
        label    = "S'asseoir",
        distance = C.Distance,
        canInteract = function(entity)
            return DoesEntityExist(entity) and not sitting and not cache.vehicle
        end,
        onSelect = function(data) TrySit(data.entity) end,
    },
})

RegisterNetEvent('sit:client:unregister', function(netId)
    if GetInvokingResource() then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
        NetworkUnregisterNetworkedEntity(entity)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and sitting then
        StandUp()
    end
end)
