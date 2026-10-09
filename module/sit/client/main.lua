-- Port fidèle du fonctionnement de mnr_sitanywhere (bridge ox_target + logique client), adapté aux conventions LSLegacy.

local C = Sit.Config

local sitting  = false
local sitEntity = nil
local sitSeatKey = nil
local keybind  = nil

LSLegacy.Sit = LSLegacy.Sit or {}
LSLegacy.Sit.IsSitting = function() return sitting end

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

-- Les props issus de YMAP statiques (packs custom type turbosaif_/tstudio_/johanni_) ne peuvent
-- pas être réseautés : on les identifie par hash+coordonnées plutôt que par netId.
local function BuildSeatKey(entity, hash, networked)
    if networked then
        return tostring(NetworkGetNetworkIdFromEntity(entity))
    end
    local coords = GetEntityCoords(entity)
    return ('static:%d:%.2f:%.2f:%.2f'):format(hash, coords.x, coords.y, coords.z)
end

local function StandUp()
    if not sitting then return end
    sitting = false

    if keybind then keybind:disable(true) end
    lib.hideTextUI()
    ClearPedTasks(cache.ped)

    if sitSeatKey then
        TriggerServerEvent('sit:serverFree', sitSeatKey)
    end
    sitEntity = nil
    sitSeatKey = nil
end

local function PlaySit(entity, seatIndex, seatKey)
    local taken = LSLegacy.Callbacks.AwaitServer('sit:serverOccupy', seatKey, seatIndex)
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
    sitSeatKey = seatKey

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

    local hash = GetEntityModel(entity)

    local networked = NetworkGetEntityIsNetworked(entity)
    if not networked then
        NetworkRegisterEntityAsNetworked(entity)
        Wait(100)
        networked = NetworkGetEntityIsNetworked(entity)
    end

    local seatKey = BuildSeatKey(entity, hash, networked)
    local seatIndex = LSLegacy.Callbacks.AwaitServer('sit:serverGetFree', seatKey, hash)
    if not seatIndex then
        Notify("Cette place est déjà occupée", "error")
        return
    end

    PlaySit(entity, seatIndex, seatKey)
end

-- Niveau staff local (même mécanique que module/adminmenu : player.group <-> Config.StaffGroups)
local function GetMyStaffLevel()
    if not LSLegacy.PlayerData or not LSLegacy.PlayerData.group then return 0 end
    for level, name in pairs(Config.StaffGroups) do
        if name == LSLegacy.PlayerData.group then return level end
    end
    return 0
end

local editing = false
local previewPed = nil
local previewCam = nil
local editKeybinds = {}

-- Rotation inverse (monde -> local) : même formule que RotateOffset avec le heading opposé.
local function UnrotateOffset(offset, heading)
    return RotateOffset(offset, -heading)
end

local function EndPositionEdit()
    editing = false

    for _, kb in ipairs(editKeybinds) do
        kb:remove()
    end
    editKeybinds = {}

    if previewCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(previewCam, false)
        previewCam = nil
    end
    if previewPed and DoesEntityExist(previewPed) then
        DeletePed(previewPed)
    end
    previewPed = nil
end

-- On spawn un clone du joueur assis sur le siège, avec une caméra fixe braquée
-- dessus, et c'est LE CLONE qu'on bouge avec le gizmo (flèches translation/rotation) :
-- le vrai perso du joueur ne bouge jamais, pas de caméra hijack sur lui, pas de
-- conflit tâche-de-scénario puisque le clone n'a AUCUNE tâche pendant le drag
-- (l'anim assise n'est relancée qu'une fois, à la fin, sur la position validée).
local function OpenPositionEditor(entity, hash, seatIndex)
    if editing or sitting then return end
    if GetResourceState('object_gizmo') ~= 'started' then
        Notify("La ressource object_gizmo n'est pas démarrée", 'error')
        return
    end

    local model = Sit.Models[hash]
    local seat = model.seats[seatIndex]
    local action = Sit.Actions[model.action]
    if not action then return end

    local entityCoords = GetEntityCoords(entity)
    local entityHeading = GetEntityHeading(entity)
    local rotated = RotateOffset(vector3(seat.x, seat.y, seat.z), entityHeading)
    local coords = entityCoords + rotated
    local heading = (entityHeading + seat.w) % 360.0

    editing = true

    previewPed = ClonePed(cache.ped, false, false, false)
    SetEntityCoords(previewPed, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(previewPed, heading)
    -- Frozen dès le spawn : sinon la physique du ped (équilibre/ancrage au sol) réajuste
    -- l'orientation vers sa position de repos initiale dès qu'on tourne sur Z avec le gizmo.
    FreezeEntityPosition(previewPed, true)
    SetEntityInvincible(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)

    local camOffset = RotateOffset(vector3(0.0, 4.0, 1.6), heading)
    local camCoords = coords + camOffset
    previewCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camCoords.x, camCoords.y, camCoords.z, 0.0, 0.0, 0.0, 50.0, false, 0)
    PointCamAtCoord(previewCam, coords.x, coords.y, coords.z + 0.4)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, true, 500, true, true)

    Notify("Gizmo ouvert sur la dernière position enregistrée : [W] déplacer, [R] tourner, [Entrée] valider", 'inform')
    local result = exports.object_gizmo:useGizmo(previewPed)

    local finalPos = result.position
    local finalHeading = GetEntityHeading(previewPed)

    FreezeEntityPosition(previewPed, true)
    TaskStartScenarioAtPosition(previewPed, action.scenario, finalPos.x, finalPos.y, finalPos.z, finalHeading, 0, true, true)

    local localOffset = UnrotateOffset(finalPos - entityCoords, entityHeading)
    local localHeading = (finalHeading - entityHeading) % 360.0

    local ok = LSLegacy.Callbacks.AwaitServer('sit:saveSeat', model.name, seatIndex,
        localOffset.x, localOffset.y, localOffset.z, localHeading)

    if ok then
        -- Reflète en mémoire côté client aussi (Sit.Models est un copie locale par script,
        -- distincte de celle du serveur) pour que le prochain "S'asseoir" utilise la nouvelle place.
        model.seats[seatIndex] = vec4(localOffset.x, localOffset.y, localOffset.z, localHeading)
        Notify(("Position enregistrée (%.2f, %.2f, %.2f, %.1f)"):format(localOffset.x, localOffset.y, localOffset.z, localHeading), 'success')
    else
        Notify("Échec de l'enregistrement (permissions ?)", 'error')
    end

    Wait(1500)
    EndPositionEdit()
end

local function StartPositionEdit(entity)
    if editing or sitting or cache.vehicle then return end
    if not DoesEntityExist(entity) then return end

    local hash = GetEntityModel(entity)
    local model = Sit.Models[hash]
    if not model then return end

    if model.maxSeats <= 1 then
        OpenPositionEditor(entity, hash, 1)
        return
    end

    local options = {}
    for i = 1, model.maxSeats do
        options[#options + 1] = {
            title = ('Place %d'):format(i),
            onSelect = function() OpenPositionEditor(entity, hash, i) end,
        }
    end
    lib.registerContext({ id = 'sit_edit_seat', title = 'Ajuster la position', options = options })
    lib.showContext('sit_edit_seat')
end

-- Ciblage ox_target uniquement sur les modèles calibrés (data/models.lua)
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
            return DoesEntityExist(entity) and not sitting and not editing and not cache.vehicle
        end,
        onSelect = function(data) TrySit(data.entity) end,
    },
    {
        name     = 'sit:target:edit',
        icon     = 'fa-solid fa-arrows-up-down-left-right',
        label    = 'Ajuster la position',
        distance = C.Distance,
        canInteract = function(entity)
            return DoesEntityExist(entity) and not sitting and not editing and not cache.vehicle and GetMyStaffLevel() >= 2
        end,
        onSelect = function(data) StartPositionEdit(data.entity) end,
    },
})

RegisterNetEvent('sit:clientUnregister', function(seatKey)
    if GetInvokingResource() then return end
    local netId = tonumber(seatKey)
    if not netId then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
        NetworkUnregisterNetworkedEntity(entity)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if sitting then StandUp() end
    if editing then EndPositionEdit() end
end)
