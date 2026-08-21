-- ─── Scène "appartement" de sélection de personnage ────────────────────────
-- Remplace la liste-carte par une pièce instanciée (bucket dédié au joueur) :
-- un ped assis par slot de personnage, portant son skin sauvegardé. Survol
-- souris -> tooltip NUI (identité, position, argent, job/grade) ; clic sur un
-- ped -> sélection (identique au clic sur une carte de l'ancien NUI) ; clic
-- sur un siège vide -> création d'un nouveau personnage.
--
-- Mêmes contraintes que client/main.lua : events serveur bruts (pas de
-- jetons anti-triche à ce stade de la connexion).

LSLegacy.Multichar = LSLegacy.Multichar or {}

-- Anim de l'émote "sitchair" (module/emotes/data/emotes_emotes.lua) : mêmes
-- dict/clip, jouée en boucle sur chaque ped assis de la scène.
local SIT_ANIM = { dict = "timetable@ron@ig_3_couch", clip = "base" }

-- Les coords /e sitchair sont prises debout ; le ped assis doit être rabaissé
-- d'autant pour retomber au niveau de l'assise du canapé (ajustable ici si
-- encore trop haut/bas en jeu).
local SIT_Z_OFFSET = -1.0

local active = false
local cam = nil
local pinnedInterior = nil
local slots = {} -- { {seat=cfg, character=data|nil, ped=entity|nil} , ... }

-- ─── Application du skin sur un ped (pas nécessairement le ped joueur) ─────
-- skinchanger ([Autres]/skinchanger/client/main.lua) applique toujours sur
-- PlayerPedId() : on reproduit ici exactement la même logique (mêmes maps,
-- mêmes normalisations, même ORDRE critique headblend -> reste), juste
-- paramétrée sur un ped arbitraire au lieu du ped joueur.
local FaceFeatureMap = {
    nose_1 = 0, nose_2 = 1, nose_3 = 2, nose_4 = 3, nose_5 = 4, nose_6 = 5,
    eyebrows_5 = 6, eyebrows_6 = 7,
    cheeks_1 = 8, cheeks_2 = 9, cheeks_3 = 10,
    eye_squint = 11, lip_thickness = 12,
    jaw_1 = 13, jaw_2 = 14,
    chin_1 = 15, chin_2 = 16, chin_3 = 17, chin_4 = 18,
    neck_thickness = 19,
}

local OverlayMap = {
    blemishes_1  = { id = 0,  opa = 'blemishes_2' },
    beard_1      = { id = 1,  opa = 'beard_2',     c1 = 'beard_3',     c2 = 'beard_4',    colorType = 1 },
    eyebrows_1   = { id = 2,  opa = 'eyebrows_2',  c1 = 'eyebrows_3',  c2 = 'eyebrows_4', colorType = 1 },
    age_1        = { id = 3,  opa = 'age_2' },
    makeup_1     = { id = 4,  opa = 'makeup_2',    c1 = 'makeup_3',    c2 = 'makeup_4',   colorType = 2 },
    blush_1      = { id = 5,  opa = 'blush_2',     c1 = 'blush_3',                         colorType = 2 },
    complexion_1 = { id = 6,  opa = 'complexion_2' },
    sun_1        = { id = 7,  opa = 'sun_2' },
    lipstick_1   = { id = 8,  opa = 'lipstick_2',  c1 = 'lipstick_3',  c2 = 'lipstick_4', colorType = 2 },
    moles_1      = { id = 9,  opa = 'moles_2' },
    chest_1      = { id = 10, opa = 'chest_2',     c1 = 'chest_3',                         colorType = 1 },
    bodyb_1      = { id = 11, opa = 'bodyb_2' },
}

local ClothesMap = {
    mask_1   = { cid = 1,  tex = 'mask_2' },
    arms_1   = { cid = 3,  tex = 'arms_2' },
    pants_1  = { cid = 4,  tex = 'pants_2' },
    bags_1   = { cid = 5,  tex = 'bags_2' },
    shoes_1  = { cid = 6,  tex = 'shoes_2' },
    chain_1  = { cid = 7,  tex = 'chain_2' },
    tshirt_1 = { cid = 8,  tex = 'tshirt_2' },
    bproof_1 = { cid = 9,  tex = 'bproof_2' },
    decals_1 = { cid = 10, tex = 'decals_2' },
    torso_1  = { cid = 11, tex = 'torso_2' },
}

local PropMap = {
    helmet_1    = { pid = 0, tex = 'helmet_2' },
    glasses_1   = { pid = 1, tex = 'glasses_2' },
    ears_1      = { pid = 2, tex = 'ears_2' },
    watches_1   = { pid = 6, tex = 'watches_2' },
    bracelets_1 = { pid = 7, tex = 'bracelets_2' },
}

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi else return v end
end

local function normalizeFaceFeature(v)
    if v == nil then return 0.0 end
    return clamp(v / 10.0, -1.0, 1.0)
end

local function normalizeOpacity(v)
    if v == nil then return 0.0 end
    return clamp(v / 10.0, 0.0, 1.0)
end

local function normalizeBlend(v, def)
    if v == nil then return def or 0.5 end
    return clamp(v / 100.0, 0.0, 1.0)
end

local function ApplyPedSkin(ped, s)
    if not s or not next(s) then return end

    -- headblend en premier : reset les overlays/face features, donc tout le
    -- reste doit être réappliqué après (même contrainte que skinchanger).
    local mom = tonumber(s.mom) or 0
    local dad = tonumber(s.dad) or 0
    local faceMix = normalizeBlend(tonumber(s.face_md_weight), 0.5)
    local skinMix = normalizeBlend(tonumber(s.skin_md_weight), 0.5)
    SetPedHeadBlendData(ped, mom, dad, 0, mom, dad, 0, faceMix, skinMix, 0.0, false)

    if s.hair_1 ~= nil then
        SetPedComponentVariation(ped, 2, tonumber(s.hair_1) or 0, tonumber(s.hair_2) or 0, 0)
    end
    SetPedHairColor(ped, tonumber(s.hair_color_1) or 0, tonumber(s.hair_color_2) or 0)

    if s.eye_color ~= nil then
        SetPedEyeColor(ped, clamp(tonumber(s.eye_color) or 0, 0, 31), 0, 1)
    end

    for drawField, def in pairs(OverlayMap) do
        local drawVal = s[drawField]
        if drawVal ~= nil then
            drawVal = tonumber(drawVal)
            if drawVal < 0 then drawVal = 255 end
            local opaVal = normalizeOpacity(tonumber(s[def.opa]) or 0)
            SetPedHeadOverlay(ped, def.id, drawVal, opaVal)
            if def.colorType and (s[def.c1] ~= nil or (def.c2 and s[def.c2] ~= nil)) then
                SetPedHeadOverlayColor(ped, def.id, def.colorType, tonumber(s[def.c1]) or 0, tonumber(s[def.c2]) or 0)
            end
        end
    end

    for name, id in pairs(FaceFeatureMap) do
        if s[name] ~= nil then
            SetPedFaceFeature(ped, id, normalizeFaceFeature(tonumber(s[name])))
        end
    end

    for name, def in pairs(ClothesMap) do
        if s[name] ~= nil then
            SetPedComponentVariation(ped, def.cid, tonumber(s[name]), tonumber(s[def.tex]) or 0, 0)
        end
    end

    for name, def in pairs(PropMap) do
        if s[name] ~= nil then
            local variation = tonumber(s[name])
            if variation == -1 then
                ClearPedProp(ped, def.pid)
            else
                SetPedPropIndex(ped, def.pid, variation, tonumber(s[def.tex]) or 0, true)
            end
        end
    end
end

-- ─── Rendu des infos d'un slot pour le tooltip NUI ─────────────────────────
-- Le libellé job/grade est résolu côté serveur (LSLegacy.Jobs, seul registre
-- qui connaît TOUS les jobs, civils compris) et fourni tel quel dans
-- character.jobLabel (module/multichar/server/main.lua, FetchCharacters).
local function BuildSlotPayload(index, character)
    if not character then
        return { index = index, empty = true }
    end

    local street = nil
    if character.coords then
        local s1 = GetStreetNameAtCoord(character.coords.x, character.coords.y, character.coords.z)
        if s1 and s1 ~= 0 then street = GetStreetNameFromHashKey(s1) end
    end

    return {
        index = index,
        empty = false,
        id = character.id,
        name = (character.firstname or "?") .. " " .. (character.lastname or "?"),
        street = street,
        cash = character.cash or 0,
        bankBalance = character.bankBalance,
        jobLabel = character.jobLabel or "Chômeur",
    }
end

-- ─── Nettoyage complet de la scène ──────────────────────────────────────────
local function TeardownScene()
    active = false

    if cam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cam, false)
        cam = nil
    end

    if pinnedInterior then
        UnpinInterior(pinnedInterior)
        pinnedInterior = nil
    end

    for _, s in ipairs(slots) do
        if s.ped and DoesEntityExist(s.ped) then
            DeletePed(s.ped)
        end
    end
    slots = {}

    SendNUIMessage({ action = 'apartment:hide' })
    SetNuiFocus(false, false)

    TriggerServerEvent('multichar:setApartmentBucket', false)
end

-- ─── Boucle de projection écran (survol/clic gérés côté NUI) ───────────────
local function ProjectionLoop()
    CreateThread(function()
        while active do
            local positions = {}
            for _, s in ipairs(slots) do
                -- Le root du ped est la position /e sitchair rabaissée de
                -- SIT_Z_OFFSET (cf. création du ped) : le centre visuel du
                -- buste est légèrement au-dessus de ce root.
                local x, y, z = s.seat.x, s.seat.y, s.seat.z + SIT_Z_OFFSET + 0.35
                local onScreen, sx, sy = GetScreenCoordFromWorldCoord(x, y, z)
                positions[#positions + 1] = { index = s.index, onScreen = onScreen and true or false, x = sx or 0, y = sy or 0 }
            end
            SendNUIMessage({ action = 'apartment:positions', data = positions })
            Wait(0)
        end
    end)
end

-- ─── NUI callbacks ──────────────────────────────────────────────────────────
RegisterNUICallback('apartment:click', function(data, cb)
    local index = tonumber(data.index)
    local s = index and slots[index]
    cb('ok')
    if not s then return end

    CreateThread(function()
        TeardownScene()
        if s.character then
            LSLegacy.Multichar.SelectCharacter(s.character.id)
        else
            LSLegacy.Multichar.SelectCharacter('new')
        end
    end)
end)

-- Suppression déclenchée depuis le bouton du tooltip : le serveur renvoie
-- `multichar:deleted`, déjà routé vers ShowApartment (module/multichar/client/main.lua)
-- pour reconstruire la scène avec le slot libéré.
RegisterNUICallback('apartment:delete', function(data, cb)
    cb('ok')
    TriggerServerEvent('multichar:deleteCharacter', data.characterId)
end)

-- ─── Point d'entrée ─────────────────────────────────────────────────────────
function LSLegacy.Multichar.ShowApartment(characters, maxSlots)
    local cfg = Config.Multichar.Apartment
    local seatCount = math.min(#cfg.Seats, maxSlots)

    -- Si la scène est déjà active (retour après une suppression), on la
    -- reconstruit à zéro plutôt que d'empiler des peds.
    if active then TeardownScene() end

    TriggerServerEvent('multichar:setApartmentBucket', true)
    Wait(200) -- laisse le serveur appliquer le bucket avant qu'on téléporte

    local ped = PlayerPedId()
    DisplayRadar(false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false)
    SetEntityCollision(ped, false, false)
    if LSLegacy.Anticheat then LSLegacy.Anticheat.AllowTeleport() end

    RequestCollisionAtCoord(cfg.Camera.x, cfg.Camera.y, cfg.Camera.z)
    SetEntityCoordsNoOffset(ped, cfg.Camera.x, cfg.Camera.y, cfg.Camera.z, false, false, false, true)
    local timer = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and (GetGameTimer() - timer) < 2500 do Wait(0) end

    -- Force le stream de l'intérieur MLO avant d'afficher quoi que ce soit :
    -- sans ça la pièce peut rester vide (LOD non chargé) le temps que le
    -- moteur la streame naturellement, ce qui laissait apparaître du vide
    -- autour des peds/canapés à l'ouverture de la scène.
    local interiorId = GetInteriorAtCoords(cfg.Camera.x, cfg.Camera.y, cfg.Camera.z)
    if interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        pinnedInterior = interiorId
        local intTimer = GetGameTimer()
        while not IsInteriorReady(interiorId) and (GetGameTimer() - intTimer) < 3000 do Wait(0) end
    end
    RequestCollisionAtCoord(cfg.Camera.x, cfg.Camera.y, cfg.Camera.z)
    local timer2 = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and (GetGameTimer() - timer2) < 1500 do Wait(0) end

    -- Caméra fixe (position/heading fournis, cadrée sur les sièges) : reculée
    -- et légèrement rabaissée par rapport au point capturé via /e sitchair,
    -- qui donnait un cadrage trop haut/trop proche. La pièce étant petite,
    -- un recul demandé "en dur" peut faire ressortir la caméra à travers le
    -- mur du fond (pas de collision sur les caméras scriptées) -> on limite
    -- le recul via un raycast pour ne jamais dépasser le mur/plafond réel.
    local rad = math.rad(cfg.Camera.heading)
    local dirX, dirY = math.sin(rad), -math.cos(rad)
    local camZ = cfg.Camera.z + (cfg.Camera.heightOffset or 0.0)
    local backDist = cfg.Camera.backOffset or 0.0

    if backDist > 0 then
        local targetX, targetY = cfg.Camera.x + dirX * backDist, cfg.Camera.y + dirY * backDist
        local rayHandle = StartShapeTestRay(cfg.Camera.x, cfg.Camera.y, camZ, targetX, targetY, camZ, 1, ped, 0)
        local _, hit, hitCoords = GetShapeTestResult(rayHandle)
        if hit == 1 then
            local hitDist = #(vector2(hitCoords.x - cfg.Camera.x, hitCoords.y - cfg.Camera.y))
            backDist = math.max(0.1, hitDist - 0.25)
        end
    end

    local camX = cfg.Camera.x + dirX * backDist
    local camY = cfg.Camera.y + dirY * backDist

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camX, camY, camZ)
    SetCamRot(cam, 0.0, 0.0, cfg.Camera.heading, 2)
    SetCamFov(cam, 50.0)
    RenderScriptCams(true, false, 0, true, true)

    -- Association slot <-> personnage : `slot` en base = index de siège.
    local bySlot = {}
    for _, c in ipairs(characters) do bySlot[c.slot] = c end

    slots = {}
    local payload = {}
    for i = 1, seatCount do
        local seat = cfg.Seats[i]
        local character = bySlot[i]
        local entry = { index = i, seat = seat, character = character, ped = nil }

        if character then
            local model = (character.skin and tonumber(character.skin.sex) == 1) and `mp_f_freemode_01` or `mp_m_freemode_01`
            RequestModel(model)
            -- Timeout large (au lieu de 3000ms) : à l'écran multichar la
            -- connexion est encore en train de streamer beaucoup d'assets,
            -- un délai trop court laissait parfois passer un CreatePed sur
            -- modèle pas encore chargé -> ped invisible (rapporté en jeu sur
            -- certains comptes). Le modèle freemode finit toujours par
            -- charger, donc on attend simplement plus longtemps.
            local mTimer = GetGameTimer()
            while not HasModelLoaded(model) and (GetGameTimer() - mTimer) < 15000 do Wait(0) end
            if not HasModelLoaded(model) then
                print(('[lslegacy] apartment: modèle %s non chargé après 15s (character %s), ped potentiellement invisible'):format(model, tostring(character.id)))
            end

            -- Les coordonnées capturées via /e sitchair sont celles du joueur
            -- debout au moment du /e (l'émote ne téléporte pas le ped, elle
            -- joue juste l'anim depuis sa position actuelle) -> le ped assis
            -- apparaît trop haut si on le crée pile à cette hauteur (retour
            -- utilisateur en jeu) ; on rabaisse donc au niveau approximatif de
            -- l'assise du canapé.
            local p = CreatePed(4, model, seat.x, seat.y, seat.z + SIT_Z_OFFSET, seat.heading, false, false)
            SetEntityInvincible(p, true)
            SetBlockingOfNonTemporaryEvents(p, true)
            FreezeEntityPosition(p, true)
            ApplyPedSkin(p, character.skin)

            RequestAnimDict(SIT_ANIM.dict)
            local aTimer = GetGameTimer()
            while not HasAnimDictLoaded(SIT_ANIM.dict) and (GetGameTimer() - aTimer) < 2000 do Wait(0) end
            TaskPlayAnim(p, SIT_ANIM.dict, SIT_ANIM.clip, 8.0, -8.0, -1, 1, 0, false, false, false)

            entry.ped = p
        end

        slots[i] = entry
        payload[i] = BuildSlotPayload(i, character)
    end

    active = true
    DoScreenFadeIn(500)

    SendNUIMessage({ action = 'apartment:show', data = { slots = payload } })
    SetNuiFocus(true, true)

    ProjectionLoop()
end
