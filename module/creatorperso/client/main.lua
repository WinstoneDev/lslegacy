LSLegacy.CreatorPerso = {
    isOpen       = false,
    cameraData   = {},
    playerSex    = 0,
    skinData     = {},
    heritageData = {},
    identityData = {}
}

-- Réponse du serveur à creatorperso:setIdentity (validation) : nil = pas encore reçue,
-- true = accepté, false = rejeté. Utilisé pour bloquer la fermeture du
-- créateur tant que le serveur n'a pas confirmé que l'identité est valide.
local pendingIdentityResult = nil

-- Ack du serveur pour 'saveskin' : nil = pas encore reçue. creatorperso:setIdentity ne
-- doit être envoyé qu'une fois ce skin réellement committé en BDD, sinon
-- creatorperso:setIdentity peut le relire avant l'écriture et écraser le skin fraîchement
-- créé avec une valeur périmée (les deux handlers serveur tournent en
-- coroutines concurrentes, l'ordre d'arrivée réseau ne suffit pas).
local pendingSkinSaved = nil

LSLegacy.Events.Register('creatorperso:skinSaved', function(success)
    pendingSkinSaved = success
end)

LSLegacy.Events.Register('creatorperso:identityResult', function(success, outfitData)
    pendingIdentityResult = success
    if success and outfitData then
        for slot, vals in pairs(outfitData) do
            LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_1', vals[1])
            LSLegacy.Events.TriggerLocal('skinchanger:change', slot..'_2', vals[2])
        end
    end
end)

-- ─── Mapping slider id → propriété skinchanger ──────────────────────────────
local sliderMap = {
    -- Apparence
    hairStyle          = 'hair_1',
    hairColor1         = 'hair_color_1',
    hairColor2         = 'hair_color_2',
    beardStyle         = 'beard_1',
    beardOpacity       = 'beard_2',
    beardColor         = 'beard_3',
    chestHair          = 'chest_1',
    chestHairOpacity   = 'chest_2',
    eyebrows           = 'eyebrows_1',
    eyebrowsOpacity    = 'eyebrows_2',
    eyebrowsColor      = 'eyebrows_3',
    eyeColor           = 'eye_color',
    -- Traits du visage
    noseWidth          = 'nose_1',
    noseHeight         = 'nose_2',
    noseLength         = 'nose_3',
    noseBridge         = 'nose_4',
    noseTip            = 'nose_5',
    noseTwist          = 'nose_6',
    eyebrowHeight      = 'eyebrows_5',
    eyebrowDepth       = 'eyebrows_6',
    cheekboneHeight    = 'cheeks_1',
    cheekboneWidth     = 'cheeks_2',
    cheekWidth         = 'cheeks_3',
    lipThickness       = 'lip_thickness',
    jawWidth           = 'jaw_1',
    jawLength          = 'jaw_2',
    chinLowering       = 'chin_1',
    chinLength         = 'chin_2',
    chinWidth          = 'chin_3',
    chinDimple         = 'chin_4',
    neckThickness      = 'neck_thickness',
    -- Maquillage
    makeupStyle        = 'makeup_1',
    makeupOpacity      = 'makeup_2',
    makeupColor        = 'makeup_3',
    lipstickStyle      = 'lipstick_1',
    lipstickOpacity    = 'lipstick_2',
    lipstickColor      = 'lipstick_3',
    complexionStyle    = 'complexion_1',
    complexionOpacity  = 'complexion_2',
    wrinkles           = 'age_1',
    wrinklesOpacity    = 'age_2',
    bodyBlemishes      = 'bodyb_1',
    bodyBlemishesOpacity = 'bodyb_2',
    moles              = 'moles_1',
    molesOpacity       = 'moles_2',
    sunDamage          = 'sun_1',
    sunDamageOpacity   = 'sun_2',
}

-- Propriétés avec transformation spéciale avant envoi au skinchanger
local function ApplySpecial(id, value)
    if id == 'eyeOpening' then
        -- Ouverture inversée : 0 = fermé (squint max), 10 = ouvert (squint 0)
        LSLegacy.Events.TriggerLocal('skinchanger:change', 'eye_squint', 10 - value)
        return true
    elseif id == 'resemblance' then
        -- Ressemblance : 0 = tout mère, 10 = tout père
        LSLegacy.Events.TriggerLocal('skinchanger:change', 'face_md_weight', value * 10)
        return true
    elseif id == 'skinTone' then
        -- Teint : 0 = tout mère, 10 = tout père
        LSLegacy.Events.TriggerLocal('skinchanger:change', 'skin_md_weight', value * 10)
        return true
    end
    return false
end

-- Onglets qui déclenchent un zoom-in sur le visage
local ZOOM_IN_TABS = { visage = true, heritage = true, makeup = true, appearance = true }

-- ─── Ouverture ───────────────────────────────────────────────────────────────
function LSLegacy.CreatorPerso.Open()
    if LSLegacy.Anticheat then LSLegacy.Anticheat.AllowTeleport() end
    local interior = GetInteriorAtCoordsWithType(vector3(399.9, -998.7, -100.0), "v_mugshot")
    LoadInterior(interior)
    while not IsInteriorReady(interior) do
        Wait(0)
    end
    LSLegacy.Events.SendToServer("creatorperso:setBucket", true)
    -- Force le modèle freemode masculin (loadDefaultModel attend que le model soit streamé)
    local modelLoaded = false
    LSLegacy.Events.TriggerLocal('skinchanger:loadDefaultModel', true, function()
        modelLoaded = true
    end)
    while not modelLoaded do Wait(0) end
    LSLegacy.Events.TriggerLocal('skinchanger:loadSkin', {
        sex      = 0,
        tshirt_1 = 15,
        tshirt_2 = 0,
        arms_1   = 15,
        arms_2   = 0,
        torso_1  = 15,
        torso_2  = 0,
        pants_1  = 14,
        pants_2  = 0,
        shoes_1  = 118,
        shoes_2  = 0,
        helmet_1  = -1,
        helmet_2  = 0,
        glasses_1  = -1,
        glasses_2  = 0,
        chain_1 = 0,
        chain_2 = 0,
        decals_1 = 0,
        decals_2 = 0,
        bags_1 = 0,
        bags_2 = 0
    })
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityCoords(GetPlayerPed(-1), 399.9, -998.7, -100.0)
    DoScreenFadeOut(1500)
    Wait(3000)
    DoScreenFadeIn(1500)
    DisplayRadar(false)
    -- L'animation d'intro repositionne le personnage (couloir → point final)
    -- et le joue en entier AVANT d'activer la caméra de création : sinon la
    -- caméra scriptée s'active et se cadre pendant que le joueur est encore
    -- dans le couloir de départ, ce qui donne un cadrage faux le temps que
    -- la téléportation/anim se termine.
    AnimationIntro()
    CreatorLoadContent()
    Wait(1000)
    FreezeEntityPosition(PlayerPedId(), true)
    ClearPlayerWantedLevel(PlayerId())
    RequestAnimDict("mp_character_creation@customise@male_a")
    Wait(100)
    TaskPlayAnim(GetPlayerPed(-1), "mp_character_creation@customise@male_a", "loop", 2.5, -1.0,-1, 2, 0, 0, 0,0)
    LSLegacy.CreatorPerso.isOpen = true
    LSLegacy.Status.Displayed = false
    LSLegacy.PlayerData.inCreation = true
    SendNUIMessage({ action = "show", data = {} })
    SetNuiFocus(true, true)
    LSLegacy.Events.TriggerLocal('skinchanger:getData', function(_, maxVals)
        print('[CreatorPerso][DEBUG] Open() maxVals = ' .. json.encode(maxVals or {}))
        print('[CreatorPerso][DEBUG] Open() hair_1 max = ' .. tostring(maxVals and maxVals.hair_1))
        SendNUIMessage({ action = "setSliderMaxValues", data = maxVals })
    end)
end


-- ─── Fermeture ───────────────────────────────────────────────────────────────
function LSLegacy.CreatorPerso.Close()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "creator:hide" })
    DisplayRadar(true)
    CreatorZoomOut(GetCreatorCam())
    RageUI.CloseAll()
    Wait(1000)
    PlaySoundFrontend(-1, "Lights_On", "GTAO_MUGSHOT_ROOM_SOUNDS", true)
    DoScreenFadeOut(2500)
    Wait(2500)
    DestroyAllCams(true)
    RenderScriptCams(false, false, 0, true, true)
    FreezeEntityPosition(PlayerPedId(), false)
    ClearPedTasksImmediately(PlayerPedId())
    DeleteBoard()
    LSLegacy.Events.SendToServer("creatorperso:setBucket", false)
    LSLegacy.CreatorPerso.isOpen = false
    LSLegacy.Status.Displayed = true
    LSLegacy.PlayerData.inCreation = false
end

-- ─── Helpers ─────────────────────────────────────────────────────────────────
function LSLegacy.CreatorPerso.ApplySexChange(sex)
    LSLegacy.CreatorPerso.playerSex = sex
    DeleteBoard()
    LSLegacy.Events.TriggerLocal('skinchanger:change', 'sex', sex)
    -- Le modèle de ped change avec le sexe : les max réels (nombre de
    -- coiffures/barbes/etc. dispo) diffèrent aussi, il faut les rafraîchir.
    LSLegacy.Events.TriggerLocal('skinchanger:getData', function(_, maxVals)
        print('[CreatorPerso][DEBUG] ApplySexChange(' .. tostring(sex) .. ') maxVals = ' .. json.encode(maxVals or {}))
        print('[CreatorPerso][DEBUG] ApplySexChange hair_1 max = ' .. tostring(maxVals and maxVals.hair_1))
        SendNUIMessage({ action = "setSliderMaxValues", data = maxVals })
    end)

    if sex == 1 then
        LSLegacy.Events.TriggerLocal('skinchanger:loadSkin', {
            sex      = 1,
            tshirt_1 = 15,
            tshirt_2 = 0,
            arms_1   = 15,
            arms_2   = 0,
            torso_1  = 15,
            torso_2  = 0,
            pants_1  = 14,
            pants_2  = 0,
            shoes_1  = 119,
            shoes_2  = 0,
            helmet_1  = -1,
            helmet_2  = 0,
            glasses_1  = -1,
            glasses_2  = 0,
            chain_1 = 0,
            chain_2 = 0,
            decals_1 = 0,
            decals_2 = 0,
            bags_1 = 0,
            bags_2 = 0
        })
    else
        LSLegacy.Events.TriggerLocal('skinchanger:loadSkin', {
            sex      = 0,
            tshirt_1 = 15,
            tshirt_2 = 0,
            arms_1   = 15,
            arms_2   = 0,
            torso_1  = 15,
            torso_2  = 0,
            pants_1  = 14,
            pants_2  = 0,
            shoes_1  = 118,
            shoes_2  = 0,
            helmet_1  = -1,
            helmet_2  = 0,
            glasses_1  = -1,
            glasses_2  = 0,
            chain_1 = 0,
            chain_2 = 0,
            decals_1 = 0,
            decals_2 = 0,
            bags_1 = 0,
            bags_2 = 0
        })
    end

    ClearPedTasks(PlayerPedId())
    RequestAnimDict("mp_character_creation@customise@male_a")
    TaskPlayAnim(GetPlayerPed(-1), "mp_character_creation@customise@male_a", "drop_loop", 3.0, -1.0, -1, 2, 0, 0, 0, 0)
    CreateBoard()
    RequestAnimDict("mp_character_creation@customise@male_a")
    Wait(100)
    TaskPlayAnim(GetPlayerPed(-1), "mp_character_creation@customise@male_a", "loop", 2.5, -1.0,-1, 2, 0, 0, 0,0)
end

function LSLegacy.CreatorPerso.ApplySkinChange(property, value)
    LSLegacy.Events.TriggerLocal('skinchanger:change', property, value)
    LSLegacy.CreatorPerso.skinData[property] = value
end

function LSLegacy.CreatorPerso.RotateCharacter(angle)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityHeading(ped, GetEntityHeading(ped) + angle)
    FreezeEntityPosition(ped, true)
end

-- ─── Callback NUI ────────────────────────────────────────────────────────────
RegisterNuiCallbackType('creatorAction')

AddEventHandler('__cfx_nui:creatorAction', function(data, cb)
    local action = data.action

    if action == 'tabChange' then
        if ZOOM_IN_TABS[data.data] then
            CreatorZoomIn(GetCreatorCam())
        else
            CreatorZoomOut(GetCreatorCam())
        end

    elseif action == 'wheelZoom' then
        CreatorZoomAdjust(tonumber(data.data) or 0)

    elseif action == 'rotateCharacter' then
        LSLegacy.CreatorPerso.RotateCharacter(data.data)

    elseif action == 'dragLook' then
        local d = data.data or {}
        if d.dx and d.dx ~= 0 then
            LSLegacy.CreatorPerso.RotateCharacter(d.dx)
        end
        if d.dy and d.dy ~= 0 then
            CreatorLookAdjust(d.dy)
        end

    elseif action == 'changeSex' then
        LSLegacy.CreatorPerso.ApplySexChange(data.data)

    elseif action == 'updateCharacter' then
        local id    = data.data.id
        local value = tonumber(data.data.value) or 0

        -- Transformations spéciales (eyeOpening, resemblance, skinTone)
        if not ApplySpecial(id, value) then
            local prop = sliderMap[id]
            if prop then
                LSLegacy.CreatorPerso.ApplySkinChange(prop, math.floor(value))
            end
        end

    elseif action == 'updateHeritage' then
        local h = data.data
        LSLegacy.CreatorPerso.heritageData = h
        LSLegacy.Events.TriggerLocal('skinchanger:change', 'mom', h.mother)
        LSLegacy.Events.TriggerLocal('skinchanger:change', 'dad', h.father)
        LSLegacy.Events.TriggerLocal('skinchanger:change', 'face_md_weight', (h.resemblance or 5) * 10)
        LSLegacy.Events.TriggerLocal('skinchanger:change', 'skin_md_weight', 100 - (h.skinTone or 5) * 10)

    elseif action == 'updateIdentity' then
        LSLegacy.CreatorPerso.identityData = data.data

    elseif action == 'confirmCharacter' then
        local identity = LSLegacy.CreatorPerso.identityData

        if not identity.firstName or identity.firstName == '' or
           not identity.lastName  or identity.lastName  == '' or
           not identity.dateOfBirth or identity.dateOfBirth == '' or
           not identity.height    or identity.height == 0   or
           not identity.birthPlace or identity.birthPlace == '' then
            LSLegacy.ShowNotification("Erreur", "Veuillez remplir tous les champs d'identité", "error", 5000)
            cb('error')
            return
        end

        local sexString = LSLegacy.CreatorPerso.playerSex == 0 and "M" or "F"

        pendingSkinSaved = nil
        LSLegacy.Events.TriggerLocal('skinchanger:getSkin', function(skin)
            LSLegacy.Events.SendToServer('saveskin', skin)
        end)

        -- Attend la confirmation serveur que le skin est bien committé en
        -- BDD avant d'envoyer creatorperso:setIdentity (voir déclaration de
        -- pendingSkinSaved). Même borne que l'attente de creatorperso:setIdentity :
        -- pire cas du retry serveur (SaveWithRetry : jusqu'à 10 × 500ms).
        local skinWaitUntil = GetGameTimer() + 15000
        while pendingSkinSaved == nil and GetGameTimer() < skinWaitUntil do
            Wait(0)
        end

        if not pendingSkinSaved then
            LSLegacy.ShowNotification("Erreur", "Impossible d'enregistrer l'apparence, réessayez.", "error", 5000)
            cb('error')
            return
        end

        pendingIdentityResult = nil
        LSLegacy.Events.SendToServer('creatorperso:setIdentity',
            identity.lastName,
            identity.firstName,
            identity.dateOfBirth,
            sexString,
            identity.height,
            identity.birthPlace
        )

        -- Attend la validation serveur avant de fermer/téléporter : si le
        -- serveur rejette l'identité (ou ne répond pas), il ne faut pas
        -- créer le personnage côté client (sinon le joueur se retrouve
        -- sans characterInfos en base).
        -- Doit rester supérieur au pire cas du retry serveur (SaveWithRetry :
        -- jusqu'à 10 tentatives × 500ms + latence DB).
        local waitUntil = GetGameTimer() + 15000
        while pendingIdentityResult == nil and GetGameTimer() < waitUntil do
            Wait(0)
        end

        if pendingIdentityResult ~= true then
            LSLegacy.ShowNotification("Erreur", "Impossible de créer le personnage, réessayez.", "error", 5000)
            cb('error')
            return
        end

        LSLegacy.CreatorPerso.Close()
        -- Close() laisse l'écran fondu au noir : on le lève immédiatement,
        -- la cutscene elle-même sert de transition (comme au premier login
        -- GTA Online), pas un fondu classique.
        DoScreenFadeIn(0)
        LSLegacy.CreatorPerso.PlayIntroCutscene()
        DoScreenFadeOut(500)
        Wait(500)
        LSLegacy.SetCoords(vector3(-1149.811035, -2804.202148, 26.398560))
        SetEntityHeading(GetPlayerPed(-1), 243.77952575684)
        Wait(1000)
        DoScreenFadeIn(1500)
        LSLegacy.ShowNotification("Création", "Vous avez créé votre personnage.", 'success')
        DeleteBoard()
        LSLegacy.Events.SendToServer("creatorperso:setBucket", false)
        cb('ok')

    elseif action == 'resetCharacter' then
        LSLegacy.CreatorPerso.playerSex    = 0
        LSLegacy.CreatorPerso.skinData     = {}
        LSLegacy.CreatorPerso.heritageData = {}
        LSLegacy.CreatorPerso.identityData = {}
        LSLegacy.CreatorPerso.Close()
        Wait(500)
        LSLegacy.CreatorPerso.Open()
    end

    cb('ok')
end)

-- ─── Événements ──────────────────────────────────────────────────────────────
LSLegacy.Events.Register('creatorperso:create', function()
    LSLegacy.CreatorPerso.Open()
    LSLegacy.PlayerData.inCreation = true
end)

LSLegacy.Events.Register('closeCreatorPerso', function()
    LSLegacy.CreatorPerso.Close()
    LSLegacy.PlayerData.inCreation = false
end)