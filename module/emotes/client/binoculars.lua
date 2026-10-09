-- Repris de rpemotes-reborn (client/Binoculars.lua), simplifié (sans vision nocturne/thermique) et traduit.

local usingBinoculars = false
local fov = 40.0
local cam = nil
local prop = nil
local scaleform = nil

local function LoadPropModel(model)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function CleanupBinoculars()
    ClearPedTasksImmediately(PlayerPedId())
    RenderScriptCams(false, false, 0, true, false)
    if scaleform then
        SetScaleformMovieAsNoLongerNeeded(scaleform)
        scaleform = nil
    end
    if cam then
        DestroyCam(cam, false)
        cam = nil
    end
    if prop and DoesEntityExist(prop) then
        DeleteEntity(prop)
    end
    prop = nil
end

local function HandleZoom()
    if IsControlPressed(0, 241) then -- molette avant
        fov = math.max(5.0, fov - 1.0)
        SetCamFov(cam, fov)
    elseif IsControlPressed(0, 242) then -- molette arrière
        fov = math.min(70.0, fov + 1.0)
        SetCamFov(cam, fov)
    end
end

function ToggleBinoculars()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) then return end

    usingBinoculars = not usingBinoculars
    if not usingBinoculars then
        CleanupBinoculars()
        return
    end

    fov = 40.0
    scaleform = RequestScaleformMovie("BINOCULARS")
    local timeout = GetGameTimer() + 3000
    while not HasScaleformMovieLoaded(scaleform) and GetGameTimer() < timeout do Wait(0) end

    local hash = LoadPropModel('prop_binoc_01')
    if hash then
        prop = CreateObject(hash, GetEntityCoords(ped), true, true, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 28422), 0.13, 0.05, 0.0, 90.0, 0.0, 0.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(hash)
    end

    cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
    AttachCamToEntity(cam, ped, 0.0, 0.0, 0.6, true)
    SetCamRot(cam, 0.0, 0.0, GetEntityHeading(ped), 2)
    SetCamFov(cam, fov)
    RenderScriptCams(true, false, 0, true, false)

    LSLegacy.ShowNotification("Emotes", "Jumelles activées. Molette pour zoomer, J ou Échap pour quitter.", 'info')

    CreateThread(function()
        while usingBinoculars and not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false) do
            Wait(0)
            HideHudAndRadarThisFrame()
            DisableControlAction(0, 25, true) -- viser
            DisableControlAction(0, 24, true) -- tirer
            DisableControlAction(0, 37, true) -- roue d'armes
            DisablePlayerFiring(ped, true)

            HandleZoom()

            if IsControlJustPressed(0, 202) then -- Échap
                usingBinoculars = false
            end

            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
        end
        usingBinoculars = false
        CleanupBinoculars()
    end)
end

RegisterCommand('lslegacy_binoculars', function()
    ToggleBinoculars()
end, false)

RegisterKeyMapping('lslegacy_binoculars', 'Utiliser les jumelles', 'keyboard', 'J')

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        usingBinoculars = false
        CleanupBinoculars()
    end
end)
