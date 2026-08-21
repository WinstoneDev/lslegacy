-- =====================================================================
--  CAMÉRA NEWS — touche H
--  Repris de rpemotes-reborn (client/NewsCam.lua). Utilise le scaleform
--  vanilla "breaking_news" du jeu (aucun fichier NUI nécessaire) et le
--  clavier à l'écran natif pour éditer les textes.
-- =====================================================================

local usingNewscam = false
local fov = 40.0
local cam = nil
local scaleform = nil

local title  = "VOTRE TITRE ICI"
local bottom = "VOTRE SOUS-TITRE ICI"
local msg    = "VOTRE MESSAGE ICI"

local function buildScaleform()
    if scaleform then
        SetScaleformMovieAsNoLongerNeeded(scaleform)
    end
    scaleform = RequestScaleformMovie("breaking_news")
    local timeout = GetGameTimer() + 3000
    while not HasScaleformMovieLoaded(scaleform) and GetGameTimer() < timeout do Wait(0) end

    PushScaleformMovieFunction(scaleform, "breaking_news")
    PopScaleformMovieFunctionVoid()

    BeginScaleformMovieMethod(scaleform, 'SET_TEXT')
    PushScaleformMovieMethodParameterString(msg)
    PushScaleformMovieMethodParameterString(bottom)
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(scaleform, 'SET_SCROLL_TEXT')
    PushScaleformMovieMethodParameterInt(0)
    PushScaleformMovieMethodParameterInt(0)
    PushScaleformMovieMethodParameterString(title)
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(scaleform, 'DISPLAY_SCROLL_TEXT')
    PushScaleformMovieMethodParameterInt(0)
    PushScaleformMovieMethodParameterInt(0)
    EndScaleformMovieMethod()
end

local function editNewscamText()
    local newTitle = LSLegacy.KeyboardInput("Titre défilant en haut", 100)
    if newTitle and #newTitle > 0 then title = newTitle end

    local newBottom = LSLegacy.KeyboardInput("Sous-titre en bas", 100)
    if newBottom and #newBottom > 0 then bottom = newBottom end

    local newMsg = LSLegacy.KeyboardInput("Message principal", 100)
    if newMsg and #newMsg > 0 then msg = newMsg end

    buildScaleform()
end

local function cleanupNewscam()
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
end

local function handleZoom()
    if IsControlPressed(0, 241) then
        fov = math.max(5.0, fov - 1.0)
        SetCamFov(cam, fov)
    elseif IsControlPressed(0, 242) then
        fov = math.min(70.0, fov + 1.0)
        SetCamFov(cam, fov)
    end
end

function ToggleNewscam()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) then return end

    usingNewscam = not usingNewscam
    if not usingNewscam then
        cleanupNewscam()
        return
    end

    fov = 40.0
    -- On demande le texte avant d'afficher quoi que ce soit : la caméra et
    -- le bandeau n'apparaissent qu'une fois la saisie terminée.
    editNewscamText()

    if not usingNewscam then return end -- le joueur a pu quitter pendant la saisie

    cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
    AttachCamToEntity(cam, ped, 0.0, 0.0, 1.2, true)
    SetCamRot(cam, 0.0, 0.0, GetEntityHeading(ped), 2)
    SetCamFov(cam, fov)
    RenderScriptCams(true, false, 0, true, false)

    LSLegacy.ShowNotification("Emotes", "Caméra news activée. Molette : zoom, G : éditer le texte, H ou Échap : quitter.", 'info')

    CreateThread(function()
        while usingNewscam and not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false) do
            Wait(0)
            HideHudAndRadarThisFrame()
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 37, true)
            DisablePlayerFiring(ped, true)

            handleZoom()

            if IsControlJustPressed(0, 202) then -- Échap
                usingNewscam = false
            end

            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
        end
        usingNewscam = false
        cleanupNewscam()
    end)
end

RegisterCommand('lslegacy_newscam', function()
    ToggleNewscam()
end, false)
RegisterKeyMapping('lslegacy_newscam', 'Utiliser la caméra news', 'keyboard', 'I')

RegisterCommand('lslegacy_newscam_edit', function()
    if usingNewscam then editNewscamText() end
end, false)
RegisterKeyMapping('lslegacy_newscam_edit', "Éditer le texte de la caméra news", 'keyboard', 'G')

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        usingNewscam = false
        cleanupNewscam()
    end
end)
