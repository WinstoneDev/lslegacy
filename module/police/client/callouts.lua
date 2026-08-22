--  MODULE POLICE NATIONALE — Appels 17 / Missions PNJ (client)

local C = Config.Police.Callouts

-- État local

local Registered   = false
local Incoming     = nil     -- appel diffusé, en attente de prise en charge
local Callout      = nil     -- payload de l'appel en cours (agents engagés)
local IsBrain      = false
local StaticPeds   = {}      -- { key = ped }
local StaticBlips  = {}
local TargetedStatics = {}  -- { [key] = entité déjà équipée en ox_target }
local RouteSwitched   = nil -- id d'appel dont l'itinéraire pointe l'hôpital
local Dancing         = {}  -- { [netId] = true } fêtards en train de danser
local RadioSceneDone  = nil -- id d'appel dont la scène de tapage est posée
-- Le raccourci du menu administrateur ne s'active qu'après une première
local AdminMenuUsed   = false
-- Individus protégés le temps d'une rixe : ils s'empoignent sans
local BrawlShield     = {}
local TaserShield     = {}

-- ALLURE DE DÉPLACEMENT
local MoveRate = {}

local function SetMoveRate(entity, rate)
    if not entity or entity == 0 then return end
    if not rate or rate >= 1.0 then
        MoveRate[entity] = nil
        if DoesEntityExist(entity) then SetPedMoveRateOverride(entity, 1.0) end
        return
    end
    MoveRate[entity] = rate
end

CreateThread(function()
    while true do
        local any = false
        for e, r in pairs(MoveRate) do
            if DoesEntityExist(e) then
                any = true
                SetPedMoveRateOverride(e, r)
            else
                MoveRate[e] = nil
            end
        end
        Wait(any and 0 or 500)
    end
end)

-- PROTECTION PARTAGÉE
local Protect = {}

local function SetProtect(entity, source, on)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    local t = Protect[entity]
    if on then
        t = t or {}
        Protect[entity] = t
        t[source] = true
        SetEntityInvincible(entity, true)
    elseif t then
        t[source] = nil
        for _ in pairs(t) do return end   -- une autre source la réclame
        Protect[entity] = nil
        SetEntityInvincible(entity, false)
    end
end
-- Blessés en attente de secours : leur posture ne doit être rompue par
local WoundedPed      = {}
local SceneRetries    = 0   -- tentatives d'ancrage infructueuses (constatation)
local CalloutBlips = {}
local CallerBlipUpgraded = false -- le blip principal a basculé sur le PNJ requérant
local onSceneFor   = nil     -- id du callout déjà signalé "sur place"
local PedBlips     = {}      -- { [netId] = blip }
local BrainState   = {}      -- { [netId] = { fleeing, fleeStart, tired, ... } }
local LastSpeech   = {}      -- { [netId] = GetGameTimer() }
local MeleeHits    = {}      -- { [netId] = { count, last } }
local SoundState   = { alarm = false, thread = false }
MyCrew             = nil     -- équipage courant (id)
MyCrewLbl          = nil     -- libellé affiché

local function Notify(msg, type)
    TriggerEvent('notify', 'Police Nationale', msg, type or 'info', Config.Police.NotifyDuration or 30000)
end

--  FILE D'ENVOI VERS LE SERVEUR

local outQueue = {}
local SEND_SPACING = 350   -- ms entre deux envois

-- Events jamais dédupliqués. Taper deux fois /missionpnj doit bien
local NO_DEDUP = {
    ['police:callouts:command']       = true,
    ['police:callouts:corpseVisible'] = true,
    ['police:callouts:anchorHere']    = true,
    ['police:callouts:anchorSurvey']  = true,
    ['police:callouts:anchorUndo']    = true,
}

local function SendQ(name, data)
    if not NO_DEDUP[name] then
        -- Déduplication : même event sur la même cible déjà en file
        for _, q in ipairs(outQueue) do
            if q.name == name then
                local a = q.data and q.data.netId
                local bb = data and data.netId
                if a == bb then return end
            end
        end
    end
    outQueue[#outQueue + 1] = { name = name, data = data }
end

CreateThread(function()
    while true do
        if #outQueue > 0 then
            local e = table.remove(outQueue, 1)
            LSLegacy.Events.SendToServer(e.name, e.data)
            Wait(SEND_SPACING)
        else
            Wait(100)
        end
    end
end)

-- Missions conjointes : police et gendarmerie s'engagent sur les mêmes
local function IsOnDuty()
    return LSLegacy.MDT.IsLocalLeoOnDuty()
end

--  UTILITAIRES

local function LoadModel(model)
    local hash = (type(model) == 'string') and GetHashKey(model) or model
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(50) t = t + 1 end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function LoadAnim(dict)
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do Wait(50) t = t + 1 end
    return HasAnimDictLoaded(dict)
end

-- Animation jouée sur un PNJ (et non sur le joueur).
function PlayAnimFor2(ped, dict, anim, duration)
    if not ped or not DoesEntityExist(ped) then return end
    if LoadAnim(dict) then
        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration, 0, 0, false, false, false)
    end
    Wait(duration)
end

local function PlayAnimFor(dict, anim, duration)
    if LoadAnim(dict) then
        TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, duration, 49, 0, false, false, false)
    end
    Wait(duration)
    ClearPedTasks(PlayerPedId())
end

--  AMBIANCE DE SCÈNE

local Amb = C.Ambience or {}
local AmbBadDict  = {}  -- dictionnaires confirmés ABSENTS de cette build (permanent)
local AmbSlowDict = {}  -- dictionnaires dont le dernier chargement a expiré (temporaire,
                         -- retenté après un délai — cf. AmbApply pour le pourquoi)
local AmbBadScen = {}   -- scénarios qui n'ont jamais démarré
local AmbGen     = {}   -- dernière pose demandée par entité

local function AmbLog(fmt, ...)
    if Amb.Debug then
        print(('^5[ambiance]^7 ' .. fmt):format(...))
    end
end

-- Nuit au sens des variantes conditionnées : 20 h – 6 h.
local function AmbIsNight()
    local h = GetClockHours()
    return h >= 20 or h < 6
end

-- Y a-t-il un mur juste derrière le PNJ ? Les postures adossées
local function AmbNearWall(entity)
    local ok, hit = pcall(function()
        local pos = GetEntityCoords(entity)
        local fwd = GetEntityForwardVector(entity)
        local h = StartExpensiveSynchronousShapeTestLosProbe(
            pos.x, pos.y, pos.z + 0.6,
            pos.x - fwd.x * 1.1, pos.y - fwd.y * 1.1, pos.z + 0.6,
            1, entity, 4)
        local _, didHit = GetShapeTestResult(h)
        return didHit == 1 or didHit == true
    end)
    return ok and hit or false
end

-- Liste des variantes applicables : la surcharge de mission prime sur
local function AmbList(role, scenarioId)
    local byScen = Amb.byScenario and scenarioId and Amb.byScenario[scenarioId]
    if byScen and byScen[role] and #byScen[role] > 0 then
        return byScen[role], 'mission'
    end
    local def = Amb.roles and Amb.roles[role]
    if def and #def > 0 then return def, 'rôle' end
    return nil, nil
end

-- Tirage pondéré parmi les variantes compatibles avec le contexte.
local function AmbPick(list, ctx, tried)
    local pool, total = {}, 0
    for i, v in ipairs(list) do
        local skip = tried[i]
        if not skip and v.night ~= nil and v.night ~= ctx.night then skip = true end
        if not skip and v.needsWall then
            if ctx.wall == nil then ctx.wall = AmbNearWall(ctx.entity) end
            if not ctx.wall then skip = true end
        end
        if not skip and v.dict then
            if AmbBadDict[v.dict] then
                skip = true
            elseif AmbSlowDict[v.dict] and GetGameTimer() < AmbSlowDict[v.dict] then
                skip = true
            end
        end
        if not skip and v.scenario and AmbBadScen[v.scenario] then skip = true end
        if not skip then
            local w = v.weight or 1
            if w > 0 then
                total = total + w
                pool[#pool + 1] = { i = i, v = v, w = w }
            end
        end
    end
    if total <= 0 then return nil end
    local r, acc = math.random() * total, 0
    for _, e in ipairs(pool) do
        acc = acc + e.w
        if r <= acc then return e.v, e.i end
    end
    local last = pool[#pool]
    return last.v, last.i
end

-- Joue une variante et vérifie qu'elle a réellement démarré.
local function AmbApply(entity, v, gen)
    if v.scenario then
        TaskStartScenarioInPlace(entity, v.scenario, 0, true)
        Wait(300)
        if not DoesEntityExist(entity) then return true end
        -- Une pose plus récente a pris la main : on ne juge pas cette
        if AmbGen[entity] ~= gen then return true end
        if IsPedActiveInScenario(entity) then return true end
        AmbBadScen[v.scenario] = true
        AmbLog('scénario refusé par le moteur : %s', v.scenario)
        return false
    end

    if v.dict and v.anim then
        if not DoesAnimDictExist(v.dict) then
            AmbBadDict[v.dict] = true
            AmbLog('dictionnaire introuvable : %s', v.dict)
            return false
        end
        if not LoadAnim(v.dict) then
            -- Un échec de LoadAnim ne prouve PAS que le dict n'existe
            AmbSlowDict[v.dict] = GetGameTimer() + (Amb.RetryCooldown or 15000)
            AmbLog('dictionnaire non chargé (retry dans %ds) : %s',
                math.floor((Amb.RetryCooldown or 15000) / 1000), v.dict)
            return false
        end
        TaskPlayAnim(entity, v.dict, v.anim, 8.0, -8.0, -1, v.flag or 1, 0, false, false, false)
        Wait(250)
        if not DoesEntityExist(entity) then return true end
        if AmbGen[entity] ~= gen then return true end
        if IsEntityPlayingAnim(entity, v.dict, v.anim, 3) then return true end
        AmbLog('animation non jouée : %s / %s', v.dict, v.anim)
        return false
    end

    return false
end

-- Applique une posture d'ambiance à un PNJ.
local function PlayAmbience(entity, role, opts)
    if not entity or not DoesEntityExist(entity) then return end
    opts = opts or {}
    local scenarioId = opts.scenario or (Callout and Callout.scenarioId)
    local gen = (AmbGen[entity] or 0) + 1
    AmbGen[entity] = gen

    CreateThread(function()
        local list = AmbList(role, scenarioId)
        local placed = false

        if list then
            local ctx = { entity = entity, night = AmbIsNight(), wall = nil }
            local tried = {}
            for _ = 1, 3 do
                if not DoesEntityExist(entity) then return end
                local v, idx = AmbPick(list, ctx, tried)
                if not v then break end
                tried[idx] = true
                if AmbGen[entity] ~= gen then return end
                if AmbApply(entity, v, gen) then
                    AmbLog('%s / %s → %s', tostring(scenarioId), role,
                        v.scenario or (v.dict .. ':' .. v.anim))
                    placed = true
                    break
                end
            end
        end

        if not DoesEntityExist(entity) or AmbGen[entity] ~= gen then return end

        if not placed then
            -- Repli : posture d'attente neutre, puis simple station
            local fb = Amb.Fallback
            if not (fb and AmbApply(entity, fb, gen)) then
                TaskStandStill(entity, -1)
                AmbLog('%s / %s → posture neutre (repli)', tostring(scenarioId), role)
            end
        end

        if opts.keep then SetPedKeepTask(entity, true) end
        if opts.lookAt and DoesEntityExist(opts.lookAt) then
            TaskLookAtEntity(entity, opts.lookAt, -1, 2048, 3)
        end
    end)
end

-- Récupère l'entité locale d'un netId, en attendant qu'elle existe.
local function EntityFromNet(netId, tries)
    tries = tries or 40
    local t = 0
    while t < tries do
        if NetworkDoesNetworkIdExist(netId) then
            local e = NetworkGetEntityFromNetworkId(netId)
            if e and e ~= 0 and DoesEntityExist(e) then return e end
        end
        Wait(100)
        t = t + 1
    end
    return nil
end

-- Les PNJ sont créés par le SERVEUR : sans demander le contrôle réseau,
local function RequestControl(entity, tries)
    if not entity or not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end

    tries = tries or 20
    for _ = 1, tries do
        NetworkRequestControlOfEntity(entity)
        if NetworkHasControlOfEntity(entity) then return true end
        Wait(50)
    end
    return NetworkHasControlOfEntity(entity)
end

-- Tente une posture parmi un mélange de scénarios natifs et/ou
local function TryPostureMix(entity, pool)
    if not entity or not DoesEntityExist(entity) or not pool or #pool == 0 then
        return nil
    end
    local order = {}
    for i = 1, #pool do order[i] = i end
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        order[i], order[j] = order[j], order[i]
    end
    for _, idx in ipairs(order) do
        local e = pool[idx]
        SetPedCanRagdoll(entity, false)
        if e.scenario then
            TaskStartScenarioInPlace(entity, e.scenario, 0, true)
            Wait(350)
            if not DoesEntityExist(entity) then return nil end
            if IsPedActiveInScenario(entity) then return e end
        elseif e.dict and e.clip then
            if DoesAnimDictExist(e.dict) and LoadAnim(e.dict) then
                TaskPlayAnim(entity, e.dict, e.clip, 4.0, -4.0, -1, 1, 0, false, false, false)
                Wait(250)
                if not DoesEntityExist(entity) then return nil end
                if IsEntityPlayingAnim(entity, e.dict, e.clip, 3) then return e end
            end
        end
    end
    return nil
end

-- Déplace un PNJ de mission de façon fiable : contrôle réseau côté
local function ResolveGround(x, y, z)
    -- Sonde courte : cas normal, évite d'accrocher un toit
    local found, gz = GetGroundZFor_3dCoord(x, y, z + 3.0, false)
    if found and math.abs(gz - z) <= C.MaxGroundDelta then return gz, true end

    -- La native piétonne renvoie une position toujours posée au sol
    local ok, safe = GetSafeCoordForPed(x, y, z, true, 16)
    if ok and safe then return safe.z, true end

    -- Sonde haute : rattrape les coordonnées enterrées
    found, gz = GetGroundZFor_3dCoord(x, y, z + 80.0, false)
    if found then return gz, true end

    return z, false
end

local function MovePed(entity, netId, x, y, z, heading)
    RequestControl(entity)
    SetEntityCoordsNoOffset(entity, x, y, z, false, false, false)
    if heading then SetEntityHeading(entity, heading) end
    SendQ('police:callouts:reposition', {
        netId = netId, x = x, y = y, z = z, h = heading,
    })
end

local function PedData(netId)
    if not Callout then return nil end
    for _, p in ipairs(Callout.peds or {}) do
        if p.netId == netId then return p end
    end
    return nil
end

local function PedFromEntity(entity)
    if not Callout or not entity or entity == 0 then return nil, nil end

    -- DoesEntityExist AVANT tout le reste.
    if not DoesEntityExist(entity) then return nil, nil end
    if not NetworkGetEntityIsNetworked(entity) then return nil, nil end

    local ok, netId = pcall(NetworkGetNetworkIdFromEntity, entity)
    if not ok or not netId or netId == 0 then return nil, nil end

    local p = PedData(netId)
    if p then return p, netId end
    return nil, nil
end

local function Speak(entity, netId, kind)
    local list = C.Speech[kind]
    if not list or #list == 0 then return end
    local now = GetGameTimer()
    if LastSpeech[netId] and (now - LastSpeech[netId]) < C.SpeechCooldown then return end
    LastSpeech[netId] = now
    pcall(function()
        PlayPedAmbientSpeechNative(entity, list[math.random(1, #list)], 'SPEECH_PARAMS_FORCE')
    end)
end

--  CONTRÔLE DES MODÈLES AU DÉMARRAGE

CreateThread(function()
    Wait(4000)   -- laisse le jeu finir de charger ses ressources

    local checked, missing = 0, {}

    local function Check(list, origin)
        for _, name in ipairs(list or {}) do
            checked = checked + 1
            local h = GetHashKey(name)
            if not IsModelInCdimage(h) or not IsModelValid(h) then
                missing[#missing + 1] = ('%s (%s)'):format(name, origin)
            end
        end
    end

    for poolName, list in pairs(C.PedPools or {}) do
        Check(list, 'PedPools.' .. poolName)
    end
    for zone, list in pairs(C.ZonePeds or {}) do
        Check(list, 'ZonePeds.' .. zone)
    end
    Check((C.Ambulance or {}).Peds, 'Ambulance.Peds')

    -- Véhicule des secours : une ambulance absente ferait échouer toute
    local ambModel = (C.Ambulance or {}).Model
    if ambModel then
        local h = GetHashKey(ambModel)
        checked = checked + 1
        if not IsModelInCdimage(h) or not IsModelValid(h) then
            missing[#missing + 1] = ('%s (Ambulance.Model)'):format(ambModel)
        end
    end

    if #missing == 0 then
        print(('^2[callouts]^7 %d modèles de PNJ vérifiés, tous disponibles.')
            :format(checked))
    else
        print(('^3[callouts]^7 %d modèles de PNJ sur %d sont INTROUVABLES sur ' ..
            'cette build :'):format(#missing, checked))
        for _, m in ipairs(missing) do print('   ^3•^7 ' .. m) end
        print('^3[callouts]^7 Retirez-les de config_callouts.lua ou ' ..
            'remplacez-les : ils produiraient des PNJ manquants.')
    end

    -- Dictionnaires d'animation déclarés dans C.Ambience. Les variantes
    local dicts, bad = {}, {}
    local function Scan(list, origin)
        for _, v in ipairs(list or {}) do
            if v.dict and not dicts[v.dict] then
                dicts[v.dict] = origin
            end
        end
    end
    for role, list in pairs((C.Ambience and C.Ambience.roles) or {}) do
        Scan(list, 'Ambience.roles.' .. role)
    end
    for sid, roles in pairs((C.Ambience and C.Ambience.byScenario) or {}) do
        for role, list in pairs(roles) do
            Scan(list, ('Ambience.byScenario.%s.%s'):format(sid, role))
        end
    end
    for sex, v in pairs((C.Doorstep and C.Doorstep.Greet) or {}) do
        if v.dict and not dicts[v.dict] then
            dicts[v.dict] = 'Doorstep.Greet.' .. sex
        end
    end
    for sex, v in pairs((C.SceneAmbience and C.SceneAmbience.PointAnim) or {}) do
        if v.dict and not dicts[v.dict] then
            dicts[v.dict] = 'SceneAmbience.PointAnim.' .. sex
        end
    end

    local nDicts = 0
    for dict, origin in pairs(dicts) do
        nDicts = nDicts + 1
        if not DoesAnimDictExist(dict) then
            bad[#bad + 1] = ('%s (%s)'):format(dict, origin)
        end
    end

    if nDicts > 0 then
        if #bad == 0 then
            print(('^2[callouts]^7 %d dictionnaires d\'animation vérifiés, ' ..
                'tous disponibles.'):format(nDicts))
        else
            print(('^3[callouts]^7 %d dictionnaires d\'animation sur %d sont ' ..
                'INTROUVABLES :'):format(#bad, nDicts))
            for _, m in ipairs(bad) do print('   ^3•^7 ' .. m) end
            print('^3[callouts]^7 Ces variantes seront ignorées : les PNJ ' ..
                'prendront une autre posture de la liste.')
        end
    end
end)

--  PNJ D'INTERACTION FIXES (Anna, Mike, Jessie)

local function SpawnStaticNpc(key)
    if StaticPeds[key] and DoesEntityExist(StaticPeds[key]) then return end
    local cfg = C.Npcs[key]
    if not cfg then return end

    -- Filet de sécurité : un PNJ orphelin d'un précédent démarrage de la
    for _, e in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(e) and GetEntityModel(e) == GetHashKey(cfg.model)
           and LSLegacy.Validate.Distance(GetEntityCoords(e), vector3(cfg.coords.x, cfg.coords.y, cfg.coords.z), 2.0) then
            DeleteEntity(e)
        end
    end

    local hash = LoadModel(cfg.model)
    if not hash then
        print('^3[callouts]^7 Modèle PNJ introuvable : ' .. tostring(cfg.model))
        return
    end

    local ped = CreatePed(4, hash, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0,
        cfg.heading + 0.0, false, true)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return end

    -- Sans ce marquage, le jeu supprime le PNJ dès que le joueur
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetEntityCanBeDamaged(ped, false)
    SetPedDiesWhenInjured(ped, false)
    FreezeEntityPosition(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    if cfg.scenario then
        TaskStartScenarioInPlace(ped, cfg.scenario, 0, true)
    end
    StaticPeds[key] = ped

    if cfg.blip then
        local blip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
        SetBlipSprite(blip, cfg.blip.sprite)
        SetBlipColour(blip, cfg.blip.color)
        SetBlipScale(blip, cfg.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(cfg.blip.label)
        EndTextCommandSetBlipName(blip)
        StaticBlips[key] = blip
    end
end

local function RemoveStaticNpc(key)
    if StaticPeds[key] and DoesEntityExist(StaticPeds[key]) then
        pcall(function() exports.ox_target:removeLocalEntity(StaticPeds[key]) end)
        DeleteEntity(StaticPeds[key])
    end
    StaticPeds[key] = nil
    TargetedStatics[key] = nil
    if StaticBlips[key] then RemoveBlip(StaticBlips[key]) StaticBlips[key] = nil end
end

-- Anna est présente en permanence, en service comme hors service : elle
CreateThread(function()
    while true do
        SpawnStaticNpc('register')
        Wait(4000)
    end
end)

--  BLIPS DE MISSION

local function ClearCalloutBlips()
    for _, b in ipairs(CalloutBlips) do
        -- Couper l'itinéraire GPS avant de retirer le blip, sinon la route
        if DoesBlipExist(b) then SetBlipRoute(b, false) RemoveBlip(b) end
    end
    CalloutBlips = {}
    CallerBlipUpgraded = false
    for _, b in pairs(PedBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    PedBlips = {}
end

local function CreateCalloutBlips()
    ClearCalloutBlips()
    if not Callout then return end
    local c = Callout.coords

    -- Repère générique du lieu, avec itinéraire GPS tracé. Provisoire :
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, false)
    pcall(function()
        SetBlipHighDetail(blip, true)
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, 3)
    end)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Intervention — ' .. (Callout.label or 'Appel 17'))
    EndTextCommandSetBlipName(blip)
    CalloutBlips[1] = blip
    -- Pas de cercle de recherche : seule la position du requérant (ou du
end

-- Bascule le blip principal du repère générique vers le PNJ requérant
local function RefreshCallerBlip()
    if not Callout or CallerBlipUpgraded then return end

    local function Upgrade(e)
        local old = CalloutBlips[1]
        if old and DoesBlipExist(old) then SetBlipRoute(old, false) RemoveBlip(old) end

        local blip = AddBlipForEntity(e)
        SetBlipSprite(blip, 280)
        SetBlipColour(blip, 3)
        SetBlipScale(blip, 1.0)
        SetBlipAsShortRange(blip, false)
        pcall(function()
            SetBlipHighDetail(blip, true)
            SetBlipRoute(blip, true)
            SetBlipRouteColour(blip, 3)
        end)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Intervention — ' .. (Callout.label or 'Appel 17'))
        EndTextCommandSetBlipName(blip)
        CalloutBlips[1] = blip
        CallerBlipUpgraded = true
    end

    for _, p in ipairs(Callout.peds or {}) do
        if p.role == 'caller' then
            local e = NetworkDoesNetworkIdExist(p.netId) and NetworkGetEntityFromNetworkId(p.netId) or nil
            if e and e ~= 0 and DoesEntityExist(e) then Upgrade(e) end
            return
        end
    end

    -- Tapage : aucun requérant, le véhicule-sono en tient lieu.
    if Callout.objective == 'radio' and Callout.boomboxNet then
        local e = NetworkDoesNetworkIdExist(Callout.boomboxNet)
            and NetworkGetEntityFromNetworkId(Callout.boomboxNet) or nil
        if e and e ~= 0 and DoesEntityExist(e) then Upgrade(e) end
    end
end

-- Blip sur les suspects menottés, pour ne pas les perdre.
local function RefreshCuffedBlips()
    if not Callout then return end
    for _, p in ipairs(Callout.peds or {}) do
        local shouldHave = (p.state == 'cuffed')
        if shouldHave and not PedBlips[p.netId] then
            local e = NetworkDoesNetworkIdExist(p.netId) and NetworkGetEntityFromNetworkId(p.netId) or nil
            if e and e ~= 0 and DoesEntityExist(e) then
                local b = AddBlipForEntity(e)
                SetBlipSprite(b, 280)
                SetBlipColour(b, 1)
                SetBlipScale(b, 0.7)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName('Individu menotté')
                EndTextCommandSetBlipName(b)
                PedBlips[p.netId] = b
            end
        elseif not shouldHave and PedBlips[p.netId] then
            if DoesBlipExist(PedBlips[p.netId]) then RemoveBlip(PedBlips[p.netId]) end
            PedBlips[p.netId] = nil
        end
    end
end

--  AMBIANCE SONORE

local function EngagedOnCallout()
    if not Callout then return false end
    local me = GetPlayerServerId(PlayerId())
    for _, a in ipairs(Callout.agents or {}) do
        if a.src == me then return true end
    end
    return false
end

-- Véhicule-sono du tapage

local BoomboxTargeted  = nil
local BoomboxSilenced  = false
local BoomboxReady    = nil   -- id d'appel déjà équipé

local function AttachBoomboxTarget(veh)
    if not veh or BoomboxTargeted == veh then return end
    BoomboxTargeted = veh
    exports.ox_target:addLocalEntity(veh, {
        {
            name = 'callout_radio_off', icon = 'fa-solid fa-volume-xmark',
            label = 'Couper la sono', distance = 3.0,
            canInteract = function() return IsOnDuty() and EngagedOnCallout() end,
            onSelect = function()
                StopBoombox()
                SendQ('police:callouts:radioOff', {})
            end,
        },
    })
end

function StopBoombox()
    if not Callout or not Callout.boomboxNet then return end
    local veh = NetworkDoesNetworkIdExist(Callout.boomboxNet)
        and NetworkGetEntityFromNetworkId(Callout.boomboxNet) or nil
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        RequestControl(veh)
        pcall(function()
            SetVehicleRadioLoud(veh, false)
            SetVehicleRadioEnabled(veh, false)
            SetVehicleEngineOn(veh, false, true, true)
        end)
    end
    BoomboxSilenced = true
end

-- Fait danser un fêtard. L'animation tourne tant qu'il n'a pas été

function StartDancing(ped, p)
    if not ped or not DoesEntityExist(ped) then return end
    if Dancing[p.netId] then return end
    Dancing[p.netId] = true

    RequestControl(ped)
    ClearPedTasks(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    -- Tous les fêtards ne dansent pas de la même façon : certains
    PlayAmbience(ped, 'suspect', { scenario = 'tapage' })

    CreateThread(function()
        while Dancing[p.netId] and Callout and DoesEntityExist(ped) do
            Wait(1500)
            local cur = PedData(p.netId)
            -- Le contrôle d'identité (ou la fin de la musique) met fin
            if not cur or cur.identified or BoomboxSilenced
               or cur.state == 'cuffed' or cur.state == 'stunned' then
                Dancing[p.netId] = nil
                if DoesEntityExist(ped) then
                    ClearPedTasks(ped)
                    SetBlockingOfNonTemporaryEvents(ped, true)
                    TaskStandStill(ped, -1)
                end
                return
            end
        end
        Dancing[p.netId] = nil
    end)
end

-- Test rapide en jeu de combos son/soundset pour PLAY_SOUND_FROM_ENTITY,
RegisterCommand('testson', function(source, args)
    local name = args[1]
    local set  = args[2]
    if not name or not set then
        print('^3[testson]^7 usage : /testson NomDuSon NomDuSoundset')
        return
    end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        veh = GetClosestVehicle(GetEntityCoords(ped), 5.0, 0, 70)
    end
    if not veh or veh == 0 then
        print('^1[testson]^7 aucun véhicule à proximité')
        return
    end
    local loaded = RequestScriptAudioBank(set, true)
    print(('^3[testson]^7 chargement banc "%s" — loaded=%s'):format(set, tostring(loaded)))
    local soundId = GetSoundId()
    local ok, err = pcall(function()
        PlaySoundFromEntity(soundId, name, veh, set, false, 0)
    end)
    print(('^2[testson]^7 "%s"/"%s" sur véhicule %s — ok=%s err=%s')
        :format(name, set, tostring(veh), tostring(ok), tostring(err)))
    CreateThread(function()
        Wait(4000)
        ReleaseSoundId(soundId)
    end)
end, false)

-- Maintien de la musique. Exécuté par TOUS les agents engagés : les
local function StartBoombox()
    if not Callout or not Callout.boomboxNet then return end
    if BoomboxReady == Callout.id then return end
    BoomboxReady = Callout.id

    local calloutId = Callout.id
    local netId     = Callout.boomboxNet

    CreateThread(function()
        local veh = nil
        local waited = 0
        while Callout and Callout.id == calloutId do
            if NetworkDoesNetworkIdExist(netId) then
                local e = NetworkGetEntityFromNetworkId(netId)
                if e and e ~= 0 and DoesEntityExist(e) then veh = e break end
            end
            Wait(500)
            waited = waited + 500
            if waited == 5000 then
                print(('^3[boombox]^7 véhicule (netId %s) toujours pas en streaming après 5 s')
                    :format(tostring(netId)))
            end
        end
        if not veh or not Callout or Callout.id ~= calloutId then
            print('^1[boombox]^7 abandon — véhicule introuvable ou intervention terminée')
            return
        end

        print(('^2[boombox]^7 véhicule trouvé (entité %s), radio %s, moteur %s')
            :format(tostring(veh), tostring(Callout.radioStation),
                tostring(GetIsVehicleEngineRunning(veh))))

        AttachBoomboxTarget(veh)

        RequestControl(veh)
        SetVehicleEngineOn(veh, true, true, false)

        -- Abandon définitif du système radio natif (SET_VEHICLE_RADIO_LOUD,
        local soundName = 'boombox_' .. tostring(calloutId)
        local urls      = C.BoomboxSound and C.BoomboxSound.urls or nil
        local url       = urls and #urls > 0 and urls[math.random(1, #urls)] or nil
        if not url or url == '' then
            print('^1[boombox]^7 C.BoomboxSound.urls vide — aucune musique à jouer')
            return
        end
        local volume    = (C.BoomboxSound and C.BoomboxSound.volume) or 0.6
        local maxRange  = (C.BoomboxSound and C.BoomboxSound.range)  or 25.0

        local coords = GetEntityCoords(veh)
        exports.xsound:PlayUrlPos(soundName, url, volume, coords, true)
        exports.xsound:Distance(soundName, maxRange)

        local pass = 0
        while Callout and Callout.id == calloutId and not BoomboxSilenced do
            if DoesEntityExist(veh) then
                pass = pass + 1
                exports.xsound:Position(soundName, GetEntityCoords(veh))
                if pass % 10 == 0 then
                    print(('^2[boombox]^7 passage %d — xsound "%s" contrôle=%s moteur=%s')
                        :format(pass, soundName,
                            tostring(NetworkHasControlOfEntity(veh)),
                            tostring(GetIsVehicleEngineRunning(veh))))
                end
            else
                print('^1[boombox]^7 véhicule disparu en cours de route')
                exports.xsound:Destroy(soundName)
                return
            end
            Wait(1000)
        end
        exports.xsound:Destroy(soundName)
    end)
end

--  MISE EN SCÈNE DU TAPAGE (cerveau uniquement)

local RadioDriverSeated = {}   -- [calloutId] = true une fois CONFIRMÉ au volant

local function LayoutRadioScene()
    if not Callout then return end
    local calloutId = Callout.id
    if not Callout.boomboxNet then return end
    if not NetworkDoesNetworkIdExist(Callout.boomboxNet) then return end

    local veh = NetworkGetEntityFromNetworkId(Callout.boomboxNet)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end

    -- Mise en place du véhicule et de la danse : une seule fois, dès que
    if RadioSceneDone ~= calloutId then
        RadioSceneDone = calloutId
        for k in pairs(RadioDriverSeated) do
            if k ~= calloutId then RadioDriverSeated[k] = nil end
        end

        CreateThread(function()
            -- 1) Véhicule remis d'aplomb, sur ses quatre roues et au niveau
            RequestControl(veh)
            local vc = GetEntityCoords(veh)
            local gz = ResolveGround(vc.x, vc.y, vc.z)
            if math.abs(vc.z - gz) > 0.5 then
                SetEntityCoordsNoOffset(veh, vc.x, vc.y, gz + 1.0, false, false, false)
                Wait(200)
            end
            SetVehicleOnGroundProperly(veh)
            -- Portes laissées déverrouillées : un verrouillage trop tôt
            SetEntityAsMissionEntity(veh, true, true)

            -- 2) La danse des fêtards est gérée plus bas, hors de ce

            -- 3) Le véhicule peut être bousculé pendant la mise en place :
            Wait(4000)
            if Callout and Callout.id == calloutId and DoesEntityExist(veh)
               and not IsVehicleOnAllWheels(veh) then
                RequestControl(veh)
                SetVehicleOnGroundProperly(veh)
            end
        end)
    end

    -- Fêtards qui dansent : tentée par CHAQUE client, à chaque tour de
    for _, p in ipairs(Callout.peds or {}) do
        if p.role == 'suspect' and not p.inCar and not Dancing[p.netId] then
            local ped = EntityFromNet(p.netId, 5)
            if ped and DoesEntityExist(ped) then StartDancing(ped, p) end
        end
    end

    -- Conducteur : une seule tentative pouvait échouer en silence
    if not RadioDriverSeated[calloutId] then
        for _, p in ipairs(Callout.peds or {}) do
            if p.role == 'suspect' and p.inCar then
                local ped = EntityFromNet(p.netId, 20)
                if ped and DoesEntityExist(ped) then
                    if IsPedInVehicle(ped, veh, false) then
                        RadioDriverSeated[calloutId] = true
                        SetBlockingOfNonTemporaryEvents(ped, true)
                        SetVehicleDoorsLocked(veh, 1)
                    elseif RequestControl(ped) then
                        -- Retour au téléportage direct : la marche
                        ClearPedTasks(ped)
                        SetPedIntoVehicle(ped, veh, -1)
                        SetBlockingOfNonTemporaryEvents(ped, true)
                    end
                end
                break
            end
        end
    end
end

local function StopAlarm() SoundState.alarm = false end

-- Alarme de cambriolage / braquage : son ambiant positionnel, sur les
local AlarmReady = nil   -- id d'appel déjà équipé

local function StartAlarm()
    if not Callout or AlarmReady == Callout.id then return end
    AlarmReady = Callout.id
    SoundState.alarm = true

    local calloutId = Callout.id
    local pos = Callout.coords
    local snd = C.AlarmSound or {}
    if not pos then return end

    CreateThread(function()
        local soundId = 0
        while Callout and Callout.id == calloutId and SoundState.alarm do
            soundId = soundId + 1
            pcall(function()
                PlaySoundFromCoord(soundId, snd.name or 'Beep_Red',
                    pos.x, pos.y, pos.z,
                    snd.set or 'DLC_HEIST_HACKING_SNAKE_SOUNDS',
                    false, snd.range or 50.0, false)
            end)
            Wait(1200)
        end
    end)
end

--  CLIENT « CERVEAU » — exécution de l'IA des PNJ

local function NearestEngagedDistance(entity)
    local best = 99999.0
    local mine = GetEntityCoords(entity)
    if not Callout then return best end
    for _, a in ipairs(Callout.agents or {}) do
        local pl = GetPlayerFromServerId(a.src)
        if pl and pl ~= -1 then
            local ped = GetPlayerPed(pl)
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local d = #(GetEntityCoords(ped) - mine)
                if d < best then best = d end
            end
        end
    end
    return best
end

-- Un agent engagé met-il l'arme à l'épaule à proximité de ce PNJ ?
local UNARMED_HASH = GetHashKey('WEAPON_UNARMED')

local function IsAimedAtBy(entity)
    if not Callout then return false end
    local B = C.Brawl or {}
    local mine = GetEntityCoords(entity)
    for _, a in ipairs(Callout.agents or {}) do
        local pl = GetPlayerFromServerId(a.src)
        if pl and pl ~= -1 then
            local ped = GetPlayerPed(pl)
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                if #(GetEntityCoords(ped) - mine) <= (B.AimDist or 18.0) then
                    -- Visée libre (clavier) ou visée verrouillée
                    local aiming = IsPlayerFreeAiming(pl)
                        or IsPlayerTargettingAnything(pl)
                    local drawn = GetSelectedPedWeapon(ped) ~= UNARMED_HASH
                    if aiming and drawn then
                        return true, ped
                    end
                end
            end
        end
    end
    return false
end

local function NearestEngagedPed(entity)
    local best, bestPed = 99999.0, nil
    local mine = GetEntityCoords(entity)
    if not Callout then return nil end
    for _, a in ipairs(Callout.agents or {}) do
        local pl = GetPlayerFromServerId(a.src)
        if pl and pl ~= -1 then
            local ped = GetPlayerPed(pl)
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local d = #(GetEntityCoords(ped) - mine)
                if d < best then best = d bestPed = ped end
            end
        end
    end
    return bestPed, best
end

-- Regroupe les helpers de ciblage « tuerie de masse » sous une seule
local MassThreat = {}

-- Vrai si l'entité est un PNJ ou un joueur déjà comptabilisé dans la
function MassThreat.IsMissionPed(entity)
    if not Callout then return false end
    for _, a in ipairs(Callout.agents or {}) do
        local pl = GetPlayerFromServerId(a.src)
        if pl and pl ~= -1 and GetPlayerPed(pl) == entity then return true end
    end
    for _, o in ipairs(Callout.peds or {}) do
        if NetworkDoesNetworkIdExist(o.netId)
           and NetworkGetEntityFromNetworkId(o.netId) == entity then
            return true
        end
    end
    return false
end

-- Passant du monde (hors mission) le plus proche, dans un rayon donné.
function MassThreat.NearestAmbientPed(entity, maxDist)
    local mine = GetEntityCoords(entity)
    local best, bestPed = maxDist, nil
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= entity and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true)
           and not IsPedAPlayer(ped) and not MassThreat.IsMissionPed(ped) then
            local d = #(GetEntityCoords(ped) - mine)
            if d < best then best = d bestPed = ped end
        end
    end
    return bestPed, best
end

-- Comme NearestEngagedPed, mais considère AUSSI les civils de la scène
local function NearestThreatPed(entity)
    local bestPed, best = NearestEngagedPed(entity)
    local mine = GetEntityCoords(entity)
    if not Callout then return bestPed, best end
    for _, o in ipairs(Callout.peds or {}) do
        if (o.role == 'caller' or o.role == 'bystander' or o.role == 'victim')
           and o.state ~= 'dead' and NetworkDoesNetworkIdExist(o.netId) then
            local oe = NetworkGetEntityFromNetworkId(o.netId)
            if oe and oe ~= 0 and DoesEntityExist(oe) and not IsEntityDead(oe) then
                local d = #(GetEntityCoords(oe) - mine)
                if d < best then best = d bestPed = oe end
            end
        end
    end
    local ap, ad = MassThreat.NearestAmbientPed(entity, math.min(best, 30.0))
    if ap and ad < best then best = ad bestPed = ap end
    return bestPed, best
end

-- Véhicule le plus proche dans un rayon donné, occupé ou non — tuerie
function MassThreat.NearestVehicle(entity, maxDist)
    local mine = GetEntityCoords(entity)
    local best, bestVeh = maxDist, nil
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and not IsEntityDead(veh) then
            local d = #(GetEntityCoords(veh) - mine)
            if d < best then best = d bestVeh = veh end
        end
    end
    return bestVeh, best
end

-- Tir scripté d'un PNJ vers un véhicule : TASK_COMBAT_PED ne cible que
function MassThreat.ShootAtVehicle(shooter, veh)
    if not DoesEntityExist(shooter) or not DoesEntityExist(veh) then return end
    local sc = GetEntityCoords(shooter)
    local vc = GetEntityCoords(veh)
    pcall(function()
        ShootSingleBulletBetweenCoords(
            sc.x, sc.y, sc.z + 1.0,
            vc.x, vc.y, vc.z + 0.4,
            35, false, GetHashKey('WEAPON_PISTOL'), 0,
            true, false, 1.0)
    end)
end

-- Rôles qui doivent se tenir DEHORS, sur le trottoir : un requérant
local OUTDOOR_ROLES = {
    caller = true, bystander = true, victim = true, wanderer = true, suspect = true,
}

-- Cherche un emplacement piéton correct autour d'un point : trottoir de
local function IsIndoors(x, y, z)
    return GetInteriorAtCoords(x + 0.0, y + 0.0, z + 0.0) ~= 0
end

--  VALIDATION DES POSITIONS DE SPAWN

local SP = C.Spawn

-- Journal de rejet. Silencieux tant que C.Spawn.Debug est faux.
local function SpawnLog(reason, x, y, z, extra)
    if not SP.Debug then return end
    print(('^3[spawn]^7 rejet ~ %s ~ (%.1f, %.1f, %.1f)%s')
        :format(reason, x or 0, y or 0, z or 0, extra and (' — ' .. extra) or ''))
end

-- Remonte au serveur un placement qui a dû être dégradé ou qui a
local function ReportSpawnFail(role, reason, x, y, z)
    SendQ('police:callouts:spawnFail', {
        role = role, reason = reason,
        x = x, y = y, z = z,
    })
end

-- 1. SOL

-- Valide le sol sous une candidate.
local function ValidateGround(x, y, refZ)
    local gz, found = ResolveGround(x, y, refZ)

    -- Aucun sol exploitable : le point flotte dans le vide.
    if not found then
        return false, nil, 'sol introuvable'
    end

    -- Toit, passerelle ou sous-sol : le PNJ serait inatteignable.
    if math.abs(gz - refZ) > (SP.MaxLevelDelta or C.MaxGroundDelta) then
        return false, nil, 'niveau incorrect',
            ('écart %.1f m'):format(math.abs(gz - refZ))
    end

    return true, gz, nil
end

-- Le point est-il dans l'eau ? Un PNJ noyé est perdu pour l'agent.
local function IsUnderWater(x, y, z)
    local found, wz = GetWaterHeight(x + 0.0, y + 0.0, z + 0.0)
    if not found then
        found, wz = GetWaterHeightNoWaves(x + 0.0, y + 0.0, z + 0.0)
    end
    if not found or not wz then return false end
    return (wz - z) > (SP.WaterMargin or 0.6)
end

-- 2. SURFACE

-- Nature de la surface : intérieur, eau, chaussée.
local function ValidateSurface(x, y, z, allowRoad)
    -- Un intérieur n'est JAMAIS toléré : le joueur ne peut pas
    if IsIndoors(x, y, z) then
        return false, 'intérieur'
    end

    if IsUnderWater(x, y, z) then
        return false, 'eau'
    end

    -- Chaussée, autoroute, voie rapide. Toléré uniquement si le
    if not allowRoad and IsPointOnRoad(x + 0.0, y + 0.0, z + 0.0, 0) then
        return false, 'chaussée'
    end

    return true, nil
end

-- 3. ENCOMBREMENT

-- Vérifie qu'il y a la place d'y tenir debout : pas de mur, pas de
local function ValidateClearance(x, y, z, ignoreEntity)
    local ok, occupied = pcall(function()
        return IsPositionOccupied(
            x + 0.0, y + 0.0, z + 0.0,
            SP.ClearRadius or 1.2,
            false,                       -- ignorer les morts
            SP.CheckPeds ~= false,
            SP.CheckVehicles ~= false,
            SP.CheckObjects ~= false,
            false,
            ignoreEntity or 0,
            false)
    end)
    if ok and occupied then
        return false, 'position occupée'
    end

    -- Hauteur libre : un point coincé sous un escalier ou dans un
    local head = SP.ClearHeight or 1.9
    local ray = StartExpensiveSynchronousShapeTestLosProbe(
        x + 0.0, y + 0.0, z + 0.3,
        x + 0.0, y + 0.0, z + head,
        1 | 16, ignoreEntity or 0, 7)
    local _, hit = GetShapeTestResult(ray)
    if hit == 1 then
        return false, 'espace insuffisant'
    end

    return true, nil
end

-- 4. NAVIGATION

-- Le PNJ doit pouvoir marcher depuis ce point. On s'appuie sur la
local function SnapToNavmesh(x, y, z)
    local ok, safe = GetSafeCoordForPed(x + 0.0, y + 0.0, z + 0.0, true, 16)
    if not ok or not safe then
        return false, nil, nil, 'hors zone navigable'
    end

    local d = #(vector3(safe.x, safe.y, safe.z) - vector3(x, y, z))

    -- Assez près du maillage : on garde le point d'origine, qui respecte
    if d <= (SP.NavTolerance or 5.0) then
        return true, nil, nil, nil
    end

    -- Un peu plus loin : plutôt que de REJETER la candidate, on la ramène
    if d <= (SP.NavSnapMax or 12.0) then
        return true, safe.x, safe.y, nil
    end

    return false, nil, nil, 'hors maillage piéton',
        ('%.1f m du point valide'):format(d)
end

-- 5. PROXIMITÉ DU JOUEUR

-- Évite de faire apparaître un PNJ sous le nez de l'agent, ou pire
local function ValidatePlayerProximity(x, y, z, minDist, avoidFov)
    local me = GetEntityCoords(PlayerPedId())

    if minDist and minDist > 0 then
        local d = #(vector3(x, y, z) - me)
        if d < minDist then
            return false, 'trop proche du joueur', ('%.1f m'):format(d)
        end
    end

    if avoidFov and IsSphereVisible(x + 0.0, y + 0.0, z + 0.0, SP.FovRadius or 1.5) then
        return false, 'dans le champ de vision'
    end

    return true, nil
end

-- Altitude et centre de RÉFÉRENCE de l'intervention.
local function SceneReference()
    if not Callout or not Callout.coords then return nil end
    local c = Callout.coords

    -- La native piétonne donne un point au sol, hors bâtiment — mais
    local tol = SP.MaxLevelDelta or 6.0
    local ok, safe = GetSafeCoordForPed(c.x + 0.0, c.y + 0.0, c.z + 0.0, true, 16)
    if ok and safe and math.abs(safe.z - c.z) <= tol then
        return vector3(safe.x, safe.y, safe.z)
    end

    local gz, found = ResolveGround(c.x, c.y, c.z)
    if found then return vector3(c.x, c.y, gz) end
    return vector3(c.x, c.y, c.z)
end

-- POINT D'ENTRÉE

-- Cherche une position de spawn valide autour d'un centre.
local function MeasureSceneLevel(center, refZ)
    -- Les échantillons trop éloignés de l'altitude déclarée sont écartés
    local span = SP.MaxRebase or 15.0
    local samples = {}
    for _, r in ipairs({ 4.0, 8.0, 12.0, 18.0, 25.0 }) do
        for i = 0, 7 do
            local a  = (i / 8) * math.pi * 2
            local gz, found = ResolveGround(center.x + math.cos(a) * r,
                                            center.y + math.sin(a) * r, refZ)
            if found and math.abs(gz - refZ) <= span then
                samples[#samples + 1] = gz
            end
        end
    end
    if #samples < 5 then return nil end
    table.sort(samples)
    return samples[math.ceil(#samples / 2)], #samples
end

function FindValidPedSpawnPosition(center, opts)
    opts = opts or {}

    local refZ     = opts.refZ or center.z
    local rMin     = opts.radiusMin or SP.RadiusMin or 2.0
    local rMax     = opts.radiusMax or SP.RadiusMax or 35.0
    local step     = SP.RadiusStep or 2.5
    local rays     = SP.AnglesPerRing or 12
    local maxTry   = opts.attempts or SP.MaxAttempts or 40
    local minDist  = opts.minPlayerDist or SP.MinPlayerDist or 0
    local avoidFov = (opts.avoidFov ~= nil) and opts.avoidFov or SP.AvoidFov

    -- Teste une candidate au travers des quatre validateurs.
    local function Try(x, y, allowRoad, useMinDist, useFov, noNav)
        -- 1. Maillage piéton EN PREMIER : il peut déplacer la candidate,
        if not noNav then
            local okN, nx, ny, whyN, extraN = SnapToNavmesh(x, y, refZ)
            if not okN then SpawnLog(whyN, x, y, refZ, extraN) return nil end
            if nx then x, y = nx, ny end
        end

        -- 2. Sol, sur le point retenu
        local okG, gz, why, extra = ValidateGround(x, y, refZ)
        if not okG then SpawnLog(why, x, y, refZ, extra) return nil end

        local z = gz + (SP.GroundOffset or 1.0)

        local okS, whyS = ValidateSurface(x, y, z, allowRoad)
        if not okS then SpawnLog(whyS, x, y, z) return nil end

        local okC, whyC = ValidateClearance(x, y, z, opts.ignoreEntity)
        if not okC then SpawnLog(whyC, x, y, z) return nil end

        local okP, whyP, extraP = ValidatePlayerProximity(
            x, y, z, useMinDist and minDist or 0, useFov)
        if not okP then SpawnLog(whyP, x, y, z, extraP) return nil end

        return vector3(x, y, z)
    end

    -- Balayage en spirale, du plus près au plus loin.
    local function Sweep(allowRoad, useMinDist, useFov, budget, noNav)
        local tries = 0
        -- Décalage angulaire aléatoire : sans lui, tous les PNJ d'une
        local offset = math.random() * math.pi * 2

        for radius = rMin, rMax, step do
            for i = 0, rays - 1 do
                if tries >= budget then return nil, tries end
                tries = tries + 1

                local ang = offset + (i / rays) * math.pi * 2
                local pos = Try(center.x + math.cos(ang) * radius,
                                center.y + math.sin(ang) * radius,
                                allowRoad, useMinDist, useFov, noNav)
                if pos then return pos, tries end
            end
        end
        return nil, tries
    end

    -- Passe 1 : toutes les contraintes
    local pos = Sweep(opts.allowRoad, true, avoidFov, maxTry)
    if pos then return pos, nil end

    -- RECALAGE DU NIVEAU DE RÉFÉRENCE
    local trueZ, nSamples = MeasureSceneLevel(center, refZ)
    local rebaseNote = nil
    if trueZ and math.abs(trueZ - refZ) > (SP.MaxLevelDelta or 6.0) then
        local before = refZ
        refZ = trueZ
        rebaseNote = ('niveau de config erroné : %.2f déclaré, %.2f mesuré (%d sondes)')
            :format(before, trueZ, nSamples or 0)
        SpawnLog('recalage', center.x, center.y, refZ, rebaseNote)

        pos = Sweep(opts.allowRoad, true, avoidFov, maxTry)
        if pos then return pos, rebaseNote end
    end

    if not SP.AllowFallback then
        return nil, 'aucune position valide'
    end

    -- Repli progressif. L'intérieur et l'eau ne sont jamais relâchés.
    if avoidFov then
        pos = Sweep(opts.allowRoad, true, false, maxTry)
        if pos then
            SpawnLog('repli', center.x, center.y, refZ, 'champ de vision ignoré')
            return pos, 'repli — champ de vision ignoré'
        end
    end

    if minDist > 0 then
        pos = Sweep(opts.allowRoad, false, false, maxTry)
        if pos then
            SpawnLog('repli', center.x, center.y, refZ, 'distance joueur ignorée')
            return pos, 'repli — distance joueur ignorée'
        end
    end

    if not opts.allowRoad then
        pos = Sweep(true, false, false, maxTry)
        if pos then
            SpawnLog('repli', center.x, center.y, refZ, 'chaussée tolérée')
            return pos, 'repli — chaussée tolérée'
        end
    end

    -- Dernier recours : on renonce au maillage piéton. Le sol, l'eau,
    pos = Sweep(true, false, false, maxTry, true)
    if pos then
        SpawnLog('repli', center.x, center.y, refZ, 'maillage piéton ignoré')
        return pos, 'repli — maillage piéton ignoré'
    end

    -- Échec explicite : l'appelant décide quoi faire.
    if SP.Debug then
        print(('^1[spawn]^7 ÉCHEC — aucune position valide autour de ' ..
            '(%.1f, %.1f, %.1f) après %d tentatives par passe')
            :format(center.x, center.y, refZ, maxTry))
    end
    -- L'altitude mesurée est jointe au motif : même en cas d'échec
    local suffix = ''
    if rebaseNote then
        suffix = ' — ' .. rebaseNote
    elseif trueZ then
        suffix = (' — sol mesuré à %.2f'):format(trueZ)
    end
    return nil, 'aucune position valide après ' .. maxTry .. ' tentatives' .. suffix
end

--  POSE D'UN CORPS AU SOL

local function CorpseLog(step, msg)
    if not SP.Debug then return end
    print(('^5[corps]^7 %-22s %s'):format(step, msg))
end

-- Attend que les collisions soient chargées autour d'une position.
local function WaitForCollision(x, y, z, timeout)
    RequestCollisionAtCoord(x + 0.0, y + 0.0, z + 0.0)
    local deadline = GetGameTimer() + (timeout or 6000)
    while GetGameTimer() < deadline do
        RequestCollisionAtCoord(x + 0.0, y + 0.0, z + 0.0)
        local found = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, z + 25.0, false)
        if found then return true end
        Wait(100)
    end
    return false
end

-- Hauteur du corps au-dessus du sol. Sert à détecter la lévitation
local function FloatHeight(ped)
    local ok, h = pcall(GetEntityHeightAboveGround, ped)
    if ok and h then return h end
    local c = GetEntityCoords(ped)
    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 3.0, false)
    if found then return c.z - gz end
    return 0.0
end

-- Masque ou révèle un corps pour TOUS les agents engagés.
local function SetCorpseVisible(corpse, netId, visible)
    if corpse and DoesEntityExist(corpse) then
        SetEntityVisible(corpse, visible, false)
    end
    SendQ('police:callouts:corpseVisible', { netId = netId, visible = visible })
end

-- Pose un corps au sol de façon fiable, dans l'ordre.
local function PlaceCorpseAtGround(corpse, netId, anchor)
    local CFG = SP.Corpse or {}

    CorpseLog('position demandée', ('(%.2f, %.2f, %.2f)')
        :format(anchor.x, anchor.y, anchor.z))

    -- 1. Collisions
    if not WaitForCollision(anchor.x, anchor.y, anchor.z, CFG.CollisionTimeout) then
        CorpseLog('collisions', 'NON chargées après délai — pose risquée')
    else
        CorpseLog('collisions', 'chargées')
    end
    if not DoesEntityExist(corpse) then return false end

    -- 2. Hauteur réelle du sol
    local gz, found = ResolveGround(anchor.x, anchor.y, anchor.z)
    if not found then
        CorpseLog('sol', 'INTROUVABLE à cette position')
        return false
    end
    CorpseLog('hauteur du sol', ('%.2f'):format(gz))

    -- 3. Pose VIVANT, légèrement au-dessus
    RequestControl(corpse)
    FreezeEntityPosition(corpse, false)
    SetEntityCollision(corpse, true, true)
    SetPedCanRagdoll(corpse, true)
    SetBlockingOfNonTemporaryEvents(corpse, true)
    ClearPedTasks(corpse)
    TaskStandStill(corpse, -1)

    -- 0,5 m suffit : trop haut et le corps rebondit ou dérive.
    MovePed(corpse, netId, anchor.x, anchor.y, gz + 0.5, nil)
    Wait(200)

    -- 4. Stabilisation
    local start    = GetGameTimer()
    local minDelay = CFG.SettleMinDelay or 900
    local deadline = start + (CFG.SettleTimeout or 6000)
    local settled  = false

    while GetGameTimer() < deadline do
        Wait(120)
        if not DoesEntityExist(corpse) then return false end
        if (GetGameTimer() - start) >= minDelay then
            local h = FloatHeight(corpse)
            if not IsPedFalling(corpse) and not IsEntityInAir(corpse)
               and h <= (CFG.MaxFloat or 0.40) then
                settled = true
                break
            end
        end
    end
    CorpseLog('stabilisation', settled and
        ('OK après %d ms'):format(GetGameTimer() - start) or 'ÉCHEC (délai dépassé)')

    if not DoesEntityExist(corpse) then return false end

    -- 5. Effondrement puis mort (ragdoll physique)
    if not RequestControl(corpse) then
        CorpseLog('contrôle réseau', 'ÉCHEC avant effondrement — PNJ probablement resté debout')
    end
    SetPedToRagdoll(corpse, 20000, 20000, 0, false, false, false)
    Wait(CFG.RagdollDelay or 500)
    if not DoesEntityExist(corpse) then return false end

    -- Le coup de grâce doit être LE TIR lui-même : un `ApplyDamageToPed`
    SetEntityHealth(corpse, 200)
    if CFG.BloodDecal ~= false and DoesEntityExist(corpse) then
        -- Le corps est encore invisible (chute masquée, cf.
        SetCorpseVisible(corpse, netId, true)
        local bc = GetEntityCoords(corpse)
        -- L'entité "propriétaire" du tir ne doit JAMAIS être le corps
        pcall(function()
            ShootSingleBulletBetweenCoords(
                bc.x, bc.y, bc.z + 2.0,
                bc.x, bc.y, bc.z,
                500, false, GetHashKey('WEAPON_PISTOL'), 0,
                false, false, 1.0)
        end)
    end
    Wait(100)
    if DoesEntityExist(corpse) and not IsPedDeadOrDying(corpse, true) then
        -- Filet de sécurité si le tir n'a pas suffi à achever le PNJ.
        ApplyDamageToPed(corpse, 400, false)
    end

    -- 6. Vérification finale
    Wait(CFG.VerifyDelay or 2000)
    if not DoesEntityExist(corpse) then return false end

    local cc = GetEntityCoords(corpse)
    CorpseLog('position réelle', ('(%.2f, %.2f, %.2f)'):format(cc.x, cc.y, cc.z))

    -- Le sol est resondé depuis l'ANCRAGE, pas depuis le corps : s'il a
    local finalGz = ResolveGround(cc.x, cc.y, anchor.z)
    local delta   = cc.z - finalGz

    if math.abs(delta) > (CFG.MaxFloat or 0.40) then
        CorpseLog('correction', ('écart %.2f m — recalage au sol'):format(delta))
        MovePed(corpse, netId, cc.x, cc.y, finalGz + (CFG.GroundOffset or 0.05), nil)
        Wait(300)
        cc = GetEntityCoords(corpse)
        delta = cc.z - ResolveGround(cc.x, cc.y, anchor.z)
    end

    -- 7. Immobilisation
    FreezeEntityPosition(corpse, true)

    -- 8. Flaque de sang
    if CFG.BloodDecal ~= false then
        pcall(function()
            local bd = CFG.BloodDecal or {}
            AddDecal(2, cc.x, cc.y, cc.z + 0.02, 0.0, 0.0, -1.0, 1.0, 0.0, 0.0,
                bd.size or 1.6, bd.size or 1.6, 1.0, 1.0, 1.0, bd.alpha or 1.0,
                bd.timeout or 999999.0, false, false, false)
        end)
    end

    local ok = math.abs(delta) <= (CFG.MaxFloat or 0.40)
    CorpseLog('vérification', ok
        and ('OK — corps au sol (écart %.2f m)'):format(delta)
        or  ('ÉCHEC — écart résiduel %.2f m'):format(delta))
    return ok
end

--  MISE EN SCÈNE D'UNE CONSTATATION

local SceneLaidOut = nil   -- id de l'appel déjà mis en scène

local function PedEntity(p)
    if not p or not NetworkDoesNetworkIdExist(p.netId) then return nil end
    local e = NetworkGetEntityFromNetworkId(p.netId)
    if e and e ~= 0 and DoesEntityExist(e) then return e end
    return nil
end

local function FaceEntity(ped, target)
    if not ped or not target then return end
    local a, b = GetEntityCoords(ped), GetEntityCoords(target)
    SetEntityHeading(ped, GetHeadingFromVector_2d(b.x - a.x, b.y - a.y))
end

--  ATTENTE DU REQUÉRANT AU SEUIL

local DoorstepRunning = {}   -- { [netId] = true }

local function DoorLog(fmt, ...)
    if C.Doorstep and C.Doorstep.Debug then
        print(('^5[seuil]^7 ' .. fmt):format(...))
    end
end

-- Tirage pondéré d'un comportement, en évitant de rejouer le précédent.
local function PickWait(list, lastId)
    local pool, total = {}, 0
    for _, v in ipairs(list) do
        if v.id ~= lastId then
            local w = v.weight or 1
            if w > 0 then total = total + w pool[#pool + 1] = { v = v, w = w } end
        end
    end
    -- Une seule variante déclarée : on la rejoue plutôt que de ne rien faire.
    if total <= 0 then return list[1] end
    local r, acc = math.random() * total, 0
    for _, e in ipairs(pool) do
        acc = acc + e.w
        if r <= acc then return e.v end
    end
    return pool[#pool].v
end

-- Salut de la main vers l'agent qui approche. Purement décoratif : si
local function WaveAtOfficer(entity)
    local g = C.Doorstep and C.Doorstep.Greet
    if not g then return end
    local v = IsPedMale(entity) and g.male or g.female
    if not v or not v.dict or not v.anim then return end
    if not DoesAnimDictExist(v.dict) then
        DoorLog('geste indisponible : %s', v.dict)
        return
    end
    if not LoadAnim(v.dict) then return end
    -- Durée -1 : le clip joue jusqu'à sa fin RÉELLE plutôt qu'une durée
    TaskPlayAnim(entity, v.dict, v.anim, 4.0, -4.0, -1, 48, 0, false, false, false)
    Wait(250)
    -- DoesAnimDictExist ne valide que le dictionnaire : seul un contrôle
    if not DoesEntityExist(entity) then return end
    if IsEntityPlayingAnim(entity, v.dict, v.anim, 3) then
        DoorLog('salut vers l\'agent : %s / %s', v.dict, v.anim)
    else
        DoorLog('geste introuvable : %s / %s — ignoré', v.dict, v.anim)
    end
end

-- Boucle d'attente. Lancée sur le cerveau uniquement, une seule fois
local function RunDoorstepWait(entity, p)
    local D = C.Doorstep
    if not D or not D.Wait or #D.Wait == 0 then return end
    if not entity or not DoesEntityExist(entity) then return end
    if DoorstepRunning[p.netId] then return end
    DoorstepRunning[p.netId] = true

    local calloutId = Callout and Callout.id
    local anchor    = GetEntityCoords(entity)
    local baseHead  = GetEntityHeading(entity)
    -- Le requérant est dos à sa porte, face à la rue : l'entrée se
    local fwd       = GetEntityForwardVector(entity)
    local doorPos   = vector3(anchor.x - fwd.x * 1.5,
                              anchor.y - fwd.y * 1.5, anchor.z + 1.0)
    local leash     = D.LeashRadius or 2.2
    local notice    = D.NoticeDist or 14.0

    DoorLog('attente lancée — ancre (%.2f, %.2f, %.2f)', anchor.x, anchor.y, anchor.z)

    CreateThread(function()
        local lastId, greeted = nil, false

        -- L'intervention est-elle toujours la nôtre, le requérant est-il
        local function Alive()
            if not IsBrain or not Callout or Callout.id ~= calloutId then return false end
            if not DoesEntityExist(entity) or IsEntityDead(entity) then return false end
            local cur = PedData(p.netId)
            if cur and cur.state and cur.state ~= 'idle' then return false end
            return true
        end

        -- Il ne doit jamais s'éloigner de son entrée.
        local function Leash()
            if LSLegacy.Validate.Distance(GetEntityCoords(entity), anchor, leash) then return end
            DoorLog('rappel vers l\'entrée')
            TaskGoStraightToCoord(entity, anchor.x, anchor.y, anchor.z, 1.0, 6000,
                baseHead, 0.3)
            local t = 0
            while t < 60 and Alive() and not LSLegacy.Validate.Distance(GetEntityCoords(entity), anchor, 0.6) do
                Wait(100) t = t + 1
            end
        end

        while Alive() do
            RequestControl(entity)
            Leash()

            local officer, dist = NearestEngagedPed(entity)

            -- L'agent est là : on cesse d'attendre
            if officer and dist and dist <= notice then
                if not greeted then
                    greeted = true
                    DoorLog('agent repéré à %.1f m — accueil', dist)
                    ClearPedTasks(entity)
                    Wait(200)
                    if not Alive() then break end
                    -- On attend la fin RÉELLE du tour (1500 ms) avant de
                    TaskTurnPedToFaceEntity(entity, officer, 1500)
                    Wait(1600)
                    if not Alive() then break end
                    WaveAtOfficer(entity)
                    -- Marge large : TaskStandStill juste après couperait
                    Wait(3200)
                    if not Alive() then break end
                    -- Posture d'attente disponible : il reste face à
                    TaskStandStill(entity, -1)
                end
                -- Il suit l'agent du regard. On ne le réoriente que si
                if DoesEntityExist(officer) then
                    TaskLookAtEntity(entity, officer, 3000, 2048, 3)
                    local a, b = GetEntityCoords(entity), GetEntityCoords(officer)
                    local want = GetHeadingFromVector_2d(b.x - a.x, b.y - a.y)
                    local diff = math.abs((want - GetEntityHeading(entity) + 180.0) % 360.0 - 180.0)
                    if diff > 35.0 then
                        TaskTurnPedToFaceEntity(entity, officer, 1000)
                    end
                end
                Wait(1500)

            -- Personne en vue : comportement d'attente
            else
                if greeted then
                    -- L'agent est reparti : il reprend son attente.
                    greeted = false
                    DoorLog('agent éloigné — reprise de l\'attente')
                end

                local v = PickWait(D.Wait, lastId)
                lastId  = v.id
                DoorLog('comportement : %s', tostring(v.id))

                ClearPedTasks(entity)
                Wait(150)
                if not Alive() then break end

                if v.pace then
                    -- Quelques pas le long de la façade, puis retour.
                    local side = (math.random(0, 1) == 0) and 1.0 or -1.0
                    local rad  = math.rad(baseHead + 90.0 * side)
                    local d    = 1.2 + math.random() * math.max(0.1, leash - 1.4)
                    local tx   = anchor.x + math.cos(rad) * d
                    local ty   = anchor.y + math.sin(rad) * d
                    TaskGoStraightToCoord(entity, tx, ty, anchor.z, 1.0, 5000, baseHead, 0.2)
                    Wait(2500 + math.random(0, 1500))
                    if not Alive() then break end
                    TaskGoStraightToCoord(entity, anchor.x, anchor.y, anchor.z, 1.0,
                        5000, baseHead, 0.2)
                    Wait(2500)
                    if not Alive() then break end
                    TaskAchieveHeading(entity, baseHead, 1500)

                elseif v.scenario then
                    -- Posture sur place, vérifiée : si le moteur refuse
                    TaskStartScenarioInPlace(entity, v.scenario, 0, true)
                    Wait(400)
                    if not Alive() then break end
                    if not IsPedActiveInScenario(entity) then
                        DoorLog('scénario refusé (%s) — posture neutre', v.scenario)
                        TaskStandStill(entity, -1)
                    end
                else
                    TaskStandStill(entity, -1)
                end

                -- Coups d'œil vers la porte, ou balayage de la rue.
                if v.lookDoor then
                    TaskLookAtCoord(entity, doorPos.x, doorPos.y, doorPos.z,
                        2500, 2048, 3)
                elseif v.scan then
                    local rad = math.rad(baseHead + (math.random(0, 1) == 0 and 60.0 or -60.0))
                    TaskLookAtCoord(entity,
                        anchor.x + math.cos(rad) * 8.0,
                        anchor.y + math.sin(rad) * 8.0,
                        anchor.z + 1.0, 3000, 2048, 3)
                end

                -- Le va-et-vient a déjà pris cinq bonnes secondes : on
                local hold = v.pace and 2500
                    or math.random(D.HoldMin or 7000, D.HoldMax or 14000)
                local slept = 0
                -- Sommeil fractionné : il doit pouvoir remarquer un
                while slept < hold and Alive() do
                    Wait(500)
                    slept = slept + 500
                    local o, dd = NearestEngagedPed(entity)
                    if o and dd and dd <= notice then break end
                end
            end
        end

        DoorstepRunning[p.netId] = nil
        DoorLog('attente terminée')
    end)
end

local function LayoutDeathScene()
    if not Callout or SceneLaidOut == Callout.id then return end

    local corpse, corpseNet = nil, nil
    local corpseAnchored = false
    local caller, callerNet  = nil, nil
    local callerAnchored = false
    local bystanders = {}
    for _, p in ipairs(Callout.peds or {}) do
        local e = PedEntity(p)
        if e then
            if p.role == 'deceased' then
                corpse, corpseNet = e, p.netId
                corpseAnchored = (p.anchored == true)
            elseif p.role == 'caller' then
                caller, callerNet = e, p.netId
                callerAnchored = (p.anchored == true)
            elseif p.role == 'bystander' then
                bystanders[#bystanders + 1] = { ent = e, netId = p.netId }
            end
        end
    end
    if not corpse then return end

    -- 1) Point d'ancrage : un vrai trottoir, jamais la chaussée
    local base = SceneReference()

    -- Même verrou que pour les PNJ : la coordonnée déclarée fait foi.
    local declared = Callout and Callout.coords
    if base and declared and math.abs(base.z - declared.z) > (SP.MaxRebase or 15.0) then
        base = vector3(declared.x, declared.y, declared.z)
    end

    if not base then
        local c = GetEntityCoords(corpse)
        local gz = ResolveGround(c.x, c.y, c.z)
        base = vector3(c.x, c.y, gz)
    end

    local anchor, whyAnchor

    if corpseAnchored then
        -- Position relevée à la main : elle fait foi, la recherche
        local c = GetEntityCoords(corpse)
        anchor = vector3(c.x, c.y, c.z)
        if SP.Debug then
            print('^5[corps]^7 position relevée conservée, aucune recherche')
        end
    else
        anchor, whyAnchor = FindValidPedSpawnPosition(base, {
            radiusMax     = 40.0,
            refZ          = base.z,
            ignoreEntity  = corpse,
            avoidFov      = false,
            minPlayerDist = 0,
        })

        -- Dernier recours avant abandon : le voisinage des points
        if not anchor and Callout.anchorCenter then
            local ac = vector3(Callout.anchorCenter.x + 0.0,
                               Callout.anchorCenter.y + 0.0,
                               Callout.anchorCenter.z + 0.0)
            anchor = FindValidPedSpawnPosition(ac, {
                radiusMin     = 2.5,
                radiusMax     = 14.0,
                refZ          = ac.z,
                ignoreEntity  = corpse,
                avoidFov      = false,
                minPlayerDist = 0,
            })
            if anchor and SP.Debug then
                print('^5[corps]^7 ancrage trouvé au voisinage des positions relevées')
            end
        end
    end

    if not anchor then
        -- Pas d'ancrage exploitable : plutôt que de composer une scène
        SceneRetries = (SceneRetries or 0) + 1
        if SceneRetries == 5 then
            ReportSpawnFail('deceased', 'ancrage de scène introuvable',
                base.x, base.y, base.z)
        end
        if SP.Debug then
            print(('^1[spawn]^7 constatation : ancrage introuvable (%s) — ' ..
                'tentative %d/%d'):format(tostring(whyAnchor), SceneRetries, 5))
        end
        if SceneRetries < 5 then return end

        anchor = vector3(base.x, base.y, base.z + 1.0)
        if SP.Debug then
            print('^3[spawn]^7 constatation : repli sur le point de mission.')
        end
    end
    SceneRetries = 0

    -- 2) Le corps, posé par la séquence dédiée. Le verrou n'est armé
    SceneLaidOut = Callout.id
    local calloutId = Callout.id

    CreateThread(function()
        -- Le corps reste invisible le temps de la chute : les agents
        SetCorpseVisible(corpse, corpseNet, false)

        local ok = PlaceCorpseAtGround(corpse, corpseNet, anchor)
        if not ok and SP.Debug then
            print('^1[corps]^7 pose non concluante — voir le journal ci-dessus.')
        end

        -- Révélation dans TOUS les cas, y compris si la pose a échoué :
        SetCorpseVisible(corpse, corpseNet, true)

        -- Filet : si la scène a changé entre-temps, on ne touche à rien.
        if not Callout or Callout.id ~= calloutId then return end
    end)

    -- 3) Le témoin à 2 m, tourné vers le corps
    if caller then
        local x, y, z, head, spot

        if callerAnchored then
            -- Position relevée à la main : elle fait foi, comme pour le
            local c = GetEntityCoords(caller)
            x, y, z = c.x, c.y, c.z
            head = GetEntityHeading(caller)
            if SP.Debug then
                print('^5[corps]^7 témoin : position relevée conservée, aucune recherche')
            end
        else
            -- Position cherchée en anneau serré autour du corps, validée
            local CFG = SP.Corpse or {}
            spot = FindValidPedSpawnPosition(anchor, {
                radiusMin     = CFG.CallerMinDist or 2.5,
                radiusMax     = CFG.CallerMaxDist or 4.5,
                refZ          = anchor.z,
                ignoreEntity  = caller,
                avoidFov      = false,
                minPlayerDist = 0,
            })
            x = spot and spot.x or (anchor.x + (CFG.CallerMinDist or 2.5))
            y = spot and spot.y or anchor.y
            z = spot and spot.z or (ResolveGround(x, y, anchor.z) + 1.0)
            head = GetHeadingFromVector_2d(anchor.x - x, anchor.y - y)
        end

        MovePed(caller, callerNet, x, y, z, head)

        -- Le témoin doit tenir debout : on le pose au sol et on l'y fixe.
        RequestControl(caller)
        FreezeEntityPosition(caller, false)
        SetEntityCollision(caller, true, true)
        SetBlockingOfNonTemporaryEvents(caller, true)
        if SP.Debug and not callerAnchored then
            print(('^5[corps]^7 %-22s (%.2f, %.2f, %.2f)%s')
                :format('témoin posé', x, y, z, spot and '' or ' [repli]'))
        end
    end

    -- 4) Les badauds en arc de cercle à 3,5 m, espacés d'environ 1 m,
    local n = #bystanders
    if n > 0 then
        local radius   = 3.5
        local spanRad  = math.min(math.pi * 1.4, (n - 1) * (1.0 / radius))
        local startAng = math.random() * math.pi * 2 - spanRad / 2
        for i, b in ipairs(bystanders) do
            local ang = (n == 1) and startAng
                or (startAng + spanRad * ((i - 1) / (n - 1)))
            local x = anchor.x + math.cos(ang) * radius
            local y = anchor.y + math.sin(ang) * radius

            -- Position validée comme les autres : sol, intérieur, eau,
            local spot = FindValidPedSpawnPosition(vector3(x, y, anchor.z), {
                radiusMin     = 0.5,
                radiusMax     = 2.5,
                refZ          = anchor.z,
                ignoreEntity  = b.ent,
                avoidFov      = false,
                minPlayerDist = 0,
            })
            local bz = anchor.z
            if spot then
                x, y, bz = spot.x, spot.y, spot.z
            else
                bz = ResolveGround(x, y, anchor.z) + 1.0
            end

            local head = GetHeadingFromVector_2d(anchor.x - x, anchor.y - y)
            MovePed(b.ent, b.netId, x, y, bz, head)
            ClearPedTasks(b.ent)
            SetBlockingOfNonTemporaryEvents(b.ent, true)
            -- Certains filment, d'autres regardent simplement : un
            PlayAmbience(b.ent, 'bystander', { lookAt = corpse })
        end
    end
end

--  TUERIE DE MASSE — PLUSIEURS CORPS, CHACUN À SA PROPRE POSITION

local MassCorpsesLaidOut = {}   -- [calloutId] = { [netId] = true }

-- `done['inflight:'..netId]` n'empêche les tentatives concurrentes
local Contention = {}   -- regroupe les helpers anti-contention (cf. MassThreat plus haut, même raison)
function Contention.AmClosestAgentTo(coords)
    if not Callout then return true end
    local mine  = #(GetEntityCoords(PlayerPedId()) - coords)
    local mySrc = GetPlayerServerId(PlayerId())
    for _, a in ipairs(Callout.agents or {}) do
        if a.src ~= mySrc then
            local pl = GetPlayerFromServerId(a.src)
            if pl and pl ~= -1 then
                local ped = GetPlayerPed(pl)
                if ped and ped ~= 0 and DoesEntityExist(ped) then
                    local d = #(GetEntityCoords(ped) - coords)
                    if d < mine or (d == mine and a.src < mySrc) then
                        return false
                    end
                end
            end
        end
    end
    return true
end

local function LayoutMassIncidentCorpses()
    if not Callout or not Callout.massIncident then return end
    local calloutId = Callout.id

    local done = MassCorpsesLaidOut[calloutId]
    if not done then
        done = {}
        MassCorpsesLaidOut[calloutId] = done
        -- Ménage : n'accumule pas les suivis des interventions passées.
        for k in pairs(MassCorpsesLaidOut) do
            if k ~= calloutId then MassCorpsesLaidOut[k] = nil end
        end
    end

    for _, p in ipairs(Callout.peds or {}) do
        -- `done` ne se pose qu'une fois la pose RÉUSSIE : un échec
        if p.role == 'deceased' and not done[p.netId] and not done['inflight:' .. p.netId] then
            local e = PedEntity(p)
            if e and Contention.AmClosestAgentTo(GetEntityCoords(e)) then
                done['inflight:' .. p.netId] = true
                local c = GetEntityCoords(e)
                local netId = p.netId
                CreateThread(function()
                    SetCorpseVisible(e, netId, false)
                    local ok = PlaceCorpseAtGround(e, netId, vector3(c.x, c.y, c.z))
                    done['inflight:' .. netId] = nil
                    if ok then
                        done[netId] = true
                    elseif SP.Debug then
                        print(('^1[corps]^7 tuerie de masse : pose non concluante (%d) — nouvelle tentative au tour suivant')
                            :format(netId))
                    end
                    SetCorpseVisible(e, netId, true)
                end)
            end
        end
    end
end

-- Démarche et tenue d'un individu en état d'ivresse.
local function MakeDrunk(entity)
    local D = C.Drunk or {}
    SetPedIsDrunk(entity, true)
    SetPedConfigFlag(entity, 100, true)   -- démarche instable

    for _, set in ipairs(D.Clipsets or {}) do
        RequestAnimSet(set)
        local t = 0
        while not HasAnimSetLoaded(set) and t < 40 do Wait(50) t = t + 1 end
        if HasAnimSetLoaded(set) then
            SetPedMovementClipset(entity, set, 1.0)
            return set
        end
    end
    return nil
end

--  AMBIANCE DE SCÈNE — MOTEUR COMMUN

local SceneRunning = {}   -- { [netId] = true }  boucles actives
local SceneStop    = {}   -- { [netId] = true }  demandes d'arrêt

local function SceneLog(fmt, ...)
    if C.SceneAmbience and C.SceneAmbience.Debug then
        print(('^5[scène]^7 ' .. fmt):format(...))
    end
end

-- Niveau de danger de l'intervention en cours.
local function SceneDanger()
    local S = C.SceneAmbience or {}
    if not Callout then return 1 end
    -- Tuerie de masse : le SEUL scénario dont le danger est DYNAMIQUE
    if Callout.dangerLevel then return Callout.dangerLevel end
    return (S.Danger or {})[Callout.scenarioId] or 1
end

-- Point focal de la scène : ce que les témoins regardent. Le corps, la
local function SceneFocus(self)
    local order = { 'deceased', 'victim', 'animal', 'suspect' }
    for _, want in ipairs(order) do
        for _, o in ipairs((Callout and Callout.peds) or {}) do
            if o.role == want and o.netId ~= self
               and NetworkDoesNetworkIdExist(o.netId) then
                local e = NetworkGetEntityFromNetworkId(o.netId)
                if e and e ~= 0 and DoesEntityExist(e) then
                    return GetEntityCoords(e), e
                end
            end
        end
    end
    for _, net in ipairs({ Callout and Callout.targetVehNet,
                           Callout and Callout.crashVehNet }) do
        if net and NetworkDoesNetworkIdExist(net) then
            local e = NetworkGetEntityFromNetworkId(net)
            if e and e ~= 0 and DoesEntityExist(e) then
                return GetEntityCoords(e), e
            end
        end
    end
    local ref = SceneReference()
    return ref or (Callout and Callout.coords
        and vector3(Callout.coords.x, Callout.coords.y, Callout.coords.z)), nil
end

-- Un autre PNJ à qui parler, pour les comportements de discussion.
local function SceneNeighbour(self, from)
    local best, bd = nil, 12.0
    for _, o in ipairs((Callout and Callout.peds) or {}) do
        if o.netId ~= self and (o.role == 'bystander' or o.role == 'caller')
           and NetworkDoesNetworkIdExist(o.netId) then
            local e = NetworkGetEntityFromNetworkId(o.netId)
            if e and e ~= 0 and DoesEntityExist(e) then
                local d = #(GetEntityCoords(e) - from)
                if d < bd then bd = d best = e end
            end
        end
    end
    return best
end

-- Liste des comportements applicables : surcharge de mission d'abord.
local function SceneList(role)
    local S = C.SceneAmbience or {}
    local byScen = S.byScenario and Callout
        and S.byScenario[Callout.scenarioId]
    if byScen and byScen[role] and #byScen[role] > 0 then return byScen[role] end
    return (S.Roles or {})[role]
end

-- Tirage pondéré, filtré par le niveau de danger et sans répétition.
local function ScenePick(list, danger, lastId)
    local pool, total = {}, 0
    for _, b in ipairs(list) do
        local ok = true
        if b.maxDanger and danger > b.maxDanger then ok = false end
        if b.minDanger and danger < b.minDanger then ok = false end
        if b.id == lastId then ok = false end
        if ok then
            local w = b.weight or 1
            if w > 0 then total = total + w pool[#pool + 1] = { b = b, w = w } end
        end
    end
    if total <= 0 then
        -- Rien de compatible hors du dernier joué : on le rejoue plutôt
        for _, b in ipairs(list) do
            if (not b.maxDanger or danger <= b.maxDanger)
               and (not b.minDanger or danger >= b.minDanger) then return b end
        end
        return nil
    end
    local r, acc = math.random() * total, 0
    for _, e in ipairs(pool) do
        acc = acc + e.w
        if r <= acc then return e.b end
    end
    return pool[#pool].b
end

-- Geste de désignation. Purement décoratif, ignoré si absent.
local function ScenePointAt(entity, focus)
    local cfg = (C.SceneAmbience or {}).PointAnim
    if not cfg then return end
    local v = IsPedMale(entity) and cfg.male or cfg.female
    if not v or not DoesAnimDictExist(v.dict) then return end
    if not LoadAnim(v.dict) then return end
    TaskPlayAnim(entity, v.dict, v.anim, 4.0, -4.0, 2200, 48, 0, false, false, false)
end

-- Exécute un comportement. Chaque `kind` est traité ici et NULLE PART
local function ApplySceneBehaviour(entity, b, ctx)
    local S = C.SceneAmbience or {}
    ClearPedTasks(entity)
    Wait(120)
    if not DoesEntityExist(entity) then return end

    local focus = ctx.focus

    if b.kind == 'scenario' and b.scenario then
        TaskStartScenarioInPlace(entity, b.scenario, 0, true)
        Wait(300)
        if DoesEntityExist(entity) and not IsPedActiveInScenario(entity) then
            TaskStandStill(entity, -1)
        end

    elseif b.kind == 'anim' and b.dict and b.clip then
        -- Dictionnaire/clip personnalisé (émotes du module emotes,
        if DoesAnimDictExist(b.dict) and LoadAnim(b.dict) then
            TaskPlayAnim(entity, b.dict, b.clip, 4.0, -4.0, -1,
                b.loop and 1 or 0, 0, false, false, false)
        else
            TaskStandStill(entity, -1)
        end

    elseif b.kind == 'observe' then
        TaskStartScenarioInPlace(entity, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
        if focus then
            TaskLookAtCoord(entity, focus.x, focus.y, focus.z, 6000, 2048, 3)
        end

    elseif b.kind == 'film' then
        -- WORLD_HUMAN_PAPARAZZI : le PNJ filme/photographie, appareil en
        TaskStartScenarioInPlace(entity, 'WORLD_HUMAN_PAPARAZZI', 0, true)
        if focus then
            TaskLookAtCoord(entity, focus.x, focus.y, focus.z, 8000, 2048, 3)
        end

    elseif b.kind == 'phone' then
        TaskStartScenarioInPlace(entity, 'WORLD_HUMAN_STAND_MOBILE', 0, true)

    elseif b.kind == 'talk' then
        local mate = SceneNeighbour(ctx.netId, GetEntityCoords(entity))
        if mate then
            TaskStartScenarioInPlace(entity, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
            TaskTurnPedToFaceEntity(entity, mate, 1200)
            Wait(1300)
            if DoesEntityExist(entity) then
                TaskLookAtEntity(entity, mate, 6000, 2048, 3)
                ScenePointAt(entity, nil)
            end
        else
            TaskStartScenarioInPlace(entity, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
        end

    elseif b.kind == 'point' then
        TaskStartScenarioInPlace(entity, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
        if focus then
            TaskTurnPedToFaceCoord(entity, focus.x, focus.y, focus.z, 900)
            Wait(1000)
            if DoesEntityExist(entity) then
                ScenePointAt(entity, focus)
                TaskLookAtCoord(entity, focus.x, focus.y, focus.z, 5000, 2048, 3)
            end
        end

    elseif b.kind == 'pace' then
        local side = (math.random(0, 1) == 0) and 1.0 or -1.0
        local rad  = math.rad(ctx.baseHead + 90.0 * side)
        local d    = 1.5 + math.random() * math.max(0.2, (S.LeashRadius or 4.0) - 2.0)
        local tx   = ctx.anchor.x + math.cos(rad) * d
        local ty   = ctx.anchor.y + math.sin(rad) * d
        TaskGoStraightToCoord(entity, tx, ty, ctx.anchor.z, 1.0, 6000, ctx.baseHead, 0.3)
        Wait(3000)
        if DoesEntityExist(entity) then
            TaskGoStraightToCoord(entity, ctx.anchor.x, ctx.anchor.y, ctx.anchor.z,
                1.0, 6000, ctx.baseHead, 0.3)
        end

    elseif b.kind == 'backoff' then
        -- Recul de quelques pas, dos au danger, puis on refait face.
        if focus then
            local pos = GetEntityCoords(entity)
            local dir = pos - focus
            local len = #(dir)
            if len > 0.1 then
                local want = math.min((S.SafeDistance or 12.0) - len, 4.0)
                if want > 0.5 then
                    local nx = pos.x + (dir.x / len) * want
                    local ny = pos.y + (dir.y / len) * want
                    TaskGoStraightToCoord(entity, nx, ny, pos.z, 1.6, 6000, 0.0, 0.5)
                    Wait(2600)
                end
            end
            if DoesEntityExist(entity) then
                TaskTurnPedToFaceCoord(entity, focus.x, focus.y, focus.z, 800)
                TaskStartScenarioInPlace(entity, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
                TaskLookAtCoord(entity, focus.x, focus.y, focus.z, 8000, 2048, 3)
            end
        else
            TaskStandStill(entity, -1)
        end

    elseif b.kind == 'cower' then
        -- Native dédiée : le PNJ se recroqueville sur place, bras levés.
        TaskCower(entity, 20000)

    else
        TaskStandStill(entity, -1)
    end
end

-- Arrête proprement l'ambiance d'un PNJ. Appelée à l'approche d'un
local function StopSceneAmbience(netId, entity, faceEntity)
    SceneStop[netId] = true
    if not entity or not DoesEntityExist(entity) then return end

    -- Un blessé au sol garde sa posture quoi qu'il arrive : lui parler
    if WoundedPed[netId] then return end
    RequestControl(entity)
    ClearPedTasks(entity)
    ClearPedSecondaryTask(entity)
    SetMoveRate(entity, 1.0)
    if faceEntity and DoesEntityExist(faceEntity) then
        TaskTurnPedToFaceEntity(entity, faceEntity, 900)
    end
    TaskStandStill(entity, -1)
end

-- Boucle d'ambiance d'un PNJ. Lancée une seule fois par PNJ, sur le
local function RunSceneAmbience(entity, p)
    local S = C.SceneAmbience or {}
    if not S.Enabled then return end
    if not entity or not DoesEntityExist(entity) then return end
    if SceneRunning[p.netId] then return end

    local list = SceneList(p.role)
    if not list or #list == 0 then return end

    SceneRunning[p.netId] = true
    SceneStop[p.netId]    = nil

    local calloutId = Callout and Callout.id
    local anchor    = GetEntityCoords(entity)
    local baseHead  = GetEntityHeading(entity)
    local leash     = S.LeashRadius or 4.0
    local notice    = S.NoticeDist or 20.0
    local danger    = SceneDanger()

    SceneLog('%s (%s) — danger %d, %d comportements',
        tostring(p.label), tostring(p.role), danger, #list)

    CreateThread(function()
        local lastId, greeted = nil, false

        local function Alive()
            if SceneStop[p.netId] then return false end
            if not IsBrain or not Callout or Callout.id ~= calloutId then return false end
            if not DoesEntityExist(entity) or IsEntityDead(entity) then return false end
            local cur = PedData(p.netId)
            if cur and cur.state and cur.state ~= 'idle'
               and cur.state ~= 'injured' then return false end
            return true
        end

        while Alive() do
            RequestControl(entity)

            -- Laisse : il ne quitte jamais les abords de son poste.
            if not LSLegacy.Validate.Distance(GetEntityCoords(entity), anchor, leash + 1.0) then
                TaskGoStraightToCoord(entity, anchor.x, anchor.y, anchor.z,
                    1.2, 6000, baseHead, 0.4)
                local t = 0
                while t < 50 and Alive()
                      and not LSLegacy.Validate.Distance(GetEntityCoords(entity), anchor, 1.0) do
                    Wait(100) t = t + 1
                end
            end

            local officer, dist = NearestEngagedPed(entity)

            if officer and dist and dist <= notice then
                -- L'agent est là : l'ambiance cesse
                if not greeted then
                    greeted = true
                    SceneLog('%s — agent à %.1f m, ambiance interrompue',
                        tostring(p.label), dist)

                    -- Le requérant (celui qui a appelé) salue de la main
                    if p.role == 'caller' and not WoundedPed[p.netId] then
                        StopSceneAmbience(p.netId, entity, nil)
                        SceneStop[p.netId] = nil   -- la boucle continue de veiller
                        if Alive() and DoesEntityExist(entity) then
                            SceneLog('%s — tour vers l\'agent', tostring(p.label))
                            TaskTurnPedToFaceEntity(entity, officer, 1500)
                            Wait(1600)
                            if Alive() and DoesEntityExist(entity) then
                                WaveAtOfficer(entity)
                                Wait(3200)
                            end
                        end
                    else
                        StopSceneAmbience(p.netId, entity, officer)
                        SceneStop[p.netId] = nil   -- la boucle continue de veiller
                    end
                end
                if DoesEntityExist(officer) then
                    TaskLookAtEntity(entity, officer, 3000, 2048, 3)
                end
                Wait(1500)

            else
                if greeted then
                    greeted = false
                    lastId  = nil
                end

                local b = ScenePick(list, danger, lastId)
                if not b then break end
                lastId = b.id
                SceneLog('%s → %s', tostring(p.label), tostring(b.id))

                ApplySceneBehaviour(entity, b, {
                    focus = select(1, SceneFocus(p.netId)),
                    netId = p.netId, anchor = anchor, baseHead = baseHead,
                })

                local hold = math.random(S.HoldMin or 7000, S.HoldMax or 15000)
                local slept = 0
                while slept < hold and Alive() do
                    Wait(500)
                    slept = slept + 500
                    local o, dd = NearestEngagedPed(entity)
                    if o and dd and dd <= notice then break end
                end
            end
        end

        SceneRunning[p.netId] = nil
        if DoesEntityExist(entity) then
            ClearPedSecondaryTask(entity)
        end
        SceneLog('%s — ambiance terminée', tostring(p.label))
    end)
end

-- Groupe de relation partagé par l'animal et son maître.
local AnimalGroup = nil

local function EnsureAnimalGroup()
    if AnimalGroup then return AnimalGroup end
    local ok, hash = pcall(function()
        local _, h = AddRelationshipGroup('LSL_ANIMAL_OWNER')
        return h
    end)
    if ok and hash then
        AnimalGroup = hash
        -- 0 = compagnons : aucune agressivité entre eux.
        pcall(SetRelationshipBetweenGroups, 0, AnimalGroup, AnimalGroup)
    end
    return AnimalGroup
end

-- Tuerie de masse : sans groupe de relation commun, deux suspects issus
local MassSuspectGroup = nil

local function EnsureMassSuspectGroup()
    if MassSuspectGroup then return MassSuspectGroup end
    local ok, hash = pcall(function()
        local _, h = AddRelationshipGroup('LSL_MASS_SUSPECT')
        return h
    end)
    if ok and hash then
        MassSuspectGroup = hash
        pcall(SetRelationshipBetweenGroups, 0, MassSuspectGroup, MassSuspectGroup)
    end
    return MassSuspectGroup
end

-- Braquage : même mécanique que EnsureMassSuspectGroup — sans groupe de
local HeistCrewGroup = nil

local function EnsureHeistCrewGroup()
    if HeistCrewGroup then return HeistCrewGroup end
    local ok, hash = pcall(function()
        local _, h = AddRelationshipGroup('LSL_HEIST_CREW')
        return h
    end)
    if ok and hash then
        HeistCrewGroup = hash
        pcall(SetRelationshipBetweenGroups, 0, HeistCrewGroup, HeistCrewGroup)
    end
    return HeistCrewGroup
end

-- Posture d'une personne blessée qui attend des secours.
function SetWoundedPosture(entity, p)
    if not entity or not DoesEntityExist(entity) or IsEntityDead(entity) then return end
    if p and p.netId then WoundedPed[p.netId] = true end
    RequestControl(entity)
    ClearPedTasksImmediately(entity)
    SetBlockingOfNonTemporaryEvents(entity, true)
    SetProtect(entity, 'victim', true)
    SetPedCanRagdollFromPlayerImpact(entity, false)
    SetMoveRate(entity, 0.5)

    local applied = TryPostureMix(entity, C.WoundedScenarios or {})
    if applied then
        if p then Speak(entity, p.netId, 'hurt') end
        return applied
    end

    -- Aucune posture acceptée : elle reste au sol, ragdoll entretenu.
    SetPedCanRagdoll(entity, true)
    SetPedToRagdoll(entity, 600000, 600000, 0, false, false, false)
    if p then Speak(entity, p.netId, 'hurt') end
    return nil
end

--  BRAQUAGE DE SUPÉRETTE — MISE EN SCÈNE

local Heist = nil   -- état de la scène en cours

local function HeistLog(fmt, ...)
    if C.Heist and C.Heist.Debug then
        print(('^5[braquage]^7 ' .. fmt):format(...))
    end
end

-- Le scénario tiré au sort pour cette intervention.
local function HeistScene()
    local id = Callout and Callout.heist and Callout.heist.scene
    for _, sc in ipairs((C.Heist or {}).Scenes or {}) do
        if sc.id == id then return sc end
    end
    return ((C.Heist or {}).Scenes or {})[1]
end

-- Postures des civils, par état de scène.
local function HeistCivilPosture(entity, posture)
    if not entity or not DoesEntityExist(entity) then return end
    RequestControl(entity)
    ClearPedTasksImmediately(entity)
    SetBlockingOfNonTemporaryEvents(entity, true)
    SetProtect(entity, 'heist', true)

    -- Postures de peur (crouch/hide/counter/handsup/frozen) : mélange
    local A = C.SceneAmbience and C.SceneAmbience.byScenario
        and C.SceneAmbience.byScenario.braquage_superette
    local fearPool = A and A.bystander

    if posture == 'down' then
        SetPedToRagdoll(entity, 600000, 600000, 0, false, false, false)
    elseif posture == 'crouch' or posture == 'hide' or posture == 'counter'
           or posture == 'handsup' or posture == 'frozen' then
        local applied = fearPool and TryPostureMix(entity, fearPool)
        if not applied then
            -- Repli si le mélange échoue entièrement sur ce PNJ.
            if posture == 'handsup' then
                TaskHandsUp(entity, -1, 0, -1, false)
            else
                TaskCower(entity, 600000)
            end
        end
    elseif posture == 'phone' then
        TaskStartScenarioInPlace(entity, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
    elseif posture == 'leave' then
        TaskStandStill(entity, -1)
    else
        TaskStandStill(entity, -1)
    end
end

-- Le braqueur prend son poste selon le rôle que le scénario lui donne.
local function HeistCrewPosture(entity, job, focus)
    if not entity or not DoesEntityExist(entity) then return end
    RequestControl(entity)
    ClearPedTasks(entity)
    SetBlockingOfNonTemporaryEvents(entity, true)
    SetPedCombatAttributes(entity, 46, true)
    SetPedFleeAttributes(entity, 0, false)

    if job == 'lookout' then
        -- Il surveille l'entrée, arme au poing.
        TaskStartScenarioInPlace(entity, 'WORLD_HUMAN_GUARD_STAND', 0, true)
        if focus then
            TaskLookAtCoord(entity, focus.x, focus.y, focus.z, -1, 2048, 3)
        end
    elseif job == 'looter' then
        -- Il vide la caisse.
        TaskStartScenarioInPlace(entity, 'WORLD_HUMAN_WELDING', 0, true)
        Wait(300)
        if DoesEntityExist(entity) and not IsPedActiveInScenario(entity) then
            TaskStartScenarioInPlace(entity, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
        end
    else
        TaskStartScenarioInPlace(entity, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    end
end

-- Le conducteur attend, moteur allumé, et surveille la rue.
local function HeistDriverIdle(ped, veh)
    if not ped or not DoesEntityExist(ped) then return end
    RequestControl(ped)
    if veh and DoesEntityExist(veh) then
        RequestControl(veh)
        if not IsPedInVehicle(ped, veh, false) then
            SetPedIntoVehicle(ped, veh, -1)
        end
        SetVehicleEngineOn(veh, true, true, false)
        local V = (C.Heist or {}).Vehicle or {}
        if V.Headlights ~= false then
            local h = GetClockHours()
            if h >= 19 or h < 7 then SetVehicleLights(veh, 2) end
        end
    end
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStandStill(ped, -1)
end

-- Décision du CHEF. Les poids de base sont décalés par le scénario
local function HeistDecide(scene)
    local H = C.Heist or {}
    local weights = {}
    for k, v in pairs(H.Reactions or {}) do weights[k] = v end

    for k, v in pairs((scene and scene.reactionShift) or {}) do
        weights[k] = (weights[k] or 0) + v
    end

    local profile = Callout and Callout.heist and Callout.heist.leader
    for _, l in ipairs(H.Leaders or {}) do
        if l.id == profile then
            for k, v in pairs(l.shift or {}) do
                weights[k] = (weights[k] or 0) + v
            end
            break
        end
    end

    local total = 0
    for _, v in pairs(weights) do if v > 0 then total = total + v end end
    if total <= 0 then return 'flee_foot' end

    local r, acc = math.random() * total, 0
    for k, v in pairs(weights) do
        if v > 0 then
            acc = acc + v
            if r <= acc then return k end
        end
    end
    return 'flee_foot'
end

-- Applique le comportement initial d'un PNJ.
local function ApplyInitialTask(p, entity)
    local pos = GetEntityCoords(entity)

    -- Le corps d'une découverte sur la voie publique est dehors ;
    local outdoor = OUTDOOR_ROLES[p.role]
        or (p.role == 'deceased' and Callout and Callout.scenarioIsDeathScene)

    -- Sur une scène de constatation, LayoutDeathScene compose le
    local hasCorpse = false
    for _, o in ipairs((Callout and Callout.peds) or {}) do
        if o.role == 'deceased' then hasCorpse = true break end
    end
    local composed = hasCorpse and
        (p.role == 'caller' or p.role == 'deceased' or p.role == 'bystander')

    -- Un seuil d'habitation est un point relevé à la main, debout devant
    if p.anchored then
        if SP.Debug then
            print(('^5[ancrage]^7 %s (%s) posé sur sa position relevée')
                :format(tostring(p.label), tostring(p.role)))
        end
        composed = true
        outdoor  = false
    end

    if p.role == 'caller' and Callout and Callout.callerAtDoor then
        if SP.Debug then
            print(('^5[seuil]^7 %-22s (%.2f, %.2f, %.2f) — point déclaré conservé')
                :format('requérant posé', pos.x, pos.y, pos.z))
        end
        composed = true
        outdoor  = false
    end

    if composed then
        outdoor = false
    else
        -- Un PNJ apparu dans un intérieur doit être sorti, quel que soit
        if not outdoor and IsIndoors(pos.x, pos.y, pos.z) then outdoor = true end
    end

    if outdoor then
        -- Référence prise sur le POINT DE MISSION. La position actuelle
        local ref  = SceneReference()
        local refZ = ref and ref.z or pos.z

        -- VERROU D'ALTITUDE. La coordonnée déclarée de l'intervention
        local declared = Callout and Callout.coords and Callout.coords.z
        if declared then
            local span = SP.MaxRebase or 15.0
            if math.abs(refZ - declared) > span then
                if SP.Debug then
                    print(('^3[spawn]^7 référence hors limites (%.1f m de ' ..
                        'l\'altitude déclarée) — ramenée à %.2f')
                        :format(math.abs(refZ - declared), declared))
                end
                refZ = declared
                ref  = vector3(Callout.coords.x, Callout.coords.y, declared)
            end
        end

        -- Si le PNJ est manifestement au mauvais étage, on ne cherche
        local center = pos
        if ref and math.abs(pos.z - refZ) > (SP.MaxLevelDelta or 6.0) then
            center = ref
            if SP.Debug then
                print(('^3[spawn]^7 %s (%s) hors niveau (%.1f m) — recherche ' ..
                    'depuis le centre de la scène')
                    :format(p.label or '?', p.role or '?', math.abs(pos.z - refZ)))
            end
        end

        -- Rayon de recherche : un PNJ dont la place est DICTÉE par la
        local tight = nil
        if p.role == 'suspect' then
            if Callout.suspectsAtCaller or Callout.suspectsAtVehicle then
                tight = 3.0
            elseif Callout.suspectCluster then
                tight = 4.0
            end
        elseif p.role == 'caller' and Callout.callerOffset then
            -- Le serveur l'a posé à distance dans une direction tirée au
            tight = 10.0
        elseif p.role == 'victim' and Callout.animalRange then
            -- La personne mordue reste au contact de l'animal : c'est lui
            tight = 5.0
        elseif p.role == 'animal' then
            -- Sans cette contrainte, le chien pouvait apparaître à 35 m
            tight = Callout.animalRange or 5.0
        elseif p.role == 'bystander' then
            tight = 8.0
        end

        -- Chaque rôle a ses contraintes propres. Un requérant doit être
        local opts = {
            radiusMin    = tight and 0.8 or nil,
            radiusMax    = tight or 35.0,
            refZ         = refZ,
            ignoreEntity = entity,
            allowRoad    = (p.role == 'victim'),
            -- Le requérant et les badauds font partie du décor visible :
            avoidFov     = (p.role == 'suspect') and not tight,
            minPlayerDist = (p.role == 'suspect' and not tight)
                and SP.MinPlayerDist or 0,
        }

        local spot, why = FindValidPedSpawnPosition(center, opts)

        -- Dernier recours : le voisinage des points relevés à la main.
        if not spot and Callout.anchorCenter then
            local ac = vector3(Callout.anchorCenter.x + 0.0,
                               Callout.anchorCenter.y + 0.0,
                               Callout.anchorCenter.z + 0.0)
            local around = {}
            for k, v in pairs(opts) do around[k] = v end
            around.radiusMin     = 2.5
            around.radiusMax     = 14.0
            around.refZ          = ac.z
            around.avoidFov      = false
            around.minPlayerDist = 0
            local alt = FindValidPedSpawnPosition(ac, around)
            if alt then
                spot = alt
                why  = 'repli — voisinage des positions relevées'
            end
        end

        -- Les rôles contraints (groupe serré, individus au véhicule,
        if not spot and tight then
            local wider = {}
            for k, v in pairs(opts) do wider[k] = v end
            wider.radiusMax = math.max(tight * 3.0, 15.0)
            wider.avoidFov  = false
            wider.minPlayerDist = 0
            spot, why = FindValidPedSpawnPosition(center, wider)
            if spot then
                why = ('rayon élargi à %.0f m'):format(wider.radiusMax)
            end
        end

        if spot then
            pos = spot
            -- L'orientation déclarée est préservée : elle place le
            MovePed(entity, p.netId, pos.x, pos.y, pos.z, nil)
            -- Position obtenue au prix d'un assouplissement : l'emplacement
            if why then
                ReportSpawnFail(p.role, why, pos.x, pos.y, pos.z)
            end
        else
            ReportSpawnFail(p.role, why or 'aucune position valide',
                center.x, center.y, center.z)
            if SP.Debug then
                print(('^1[spawn]^7 %s (%s) laissé à sa position d\'origine : %s')
                    :format(p.label or '?', p.role or '?', tostring(why)))
            end
        end
    end

    -- Recalage final au sol, en se comparant au niveau de la scène et
    if not composed then
        local sceneRef = SceneReference()
        local probeZ   = sceneRef and sceneRef.z or pos.z
        local gz = ResolveGround(pos.x, pos.y, probeZ)
        if math.abs((gz + 1.0) - pos.z) > 0.5 then
            pos = vector3(pos.x, pos.y, gz + 1.0)
            MovePed(entity, p.netId, pos.x, pos.y, pos.z, nil)
        end
    end

    SetEntityAsMissionEntity(entity, true, true)
    SetPedDropsWeaponsWhenDead(entity, false)
    SetPedCanRagdollFromPlayerImpact(entity, true)
    SetPedSuffersCriticalHits(entity, false)
    SetEntityHealth(entity, 200)

    if p.weapon then
        local wHash = GetHashKey(p.weapon)
        GiveWeaponToPed(entity, wHash, 60, false, true)
        -- GiveWeaponToPed(..., true) la sélectionne, mais un PNJ passif
        SetCurrentPedWeapon(entity, wHash, true)
    end

    -- BRAQUAGE
    if Callout and Callout.heist
       and (p.role == 'suspect' or p.role == 'caller' or p.role == 'bystander') then
        SetBlockingOfNonTemporaryEvents(entity, true)
        if p.role == 'suspect' then
            -- Attributs conservés : la fuite et l'affrontement décidés
            SetPedFleeAttributes(entity, 0, false)
            SetPedCombatAttributes(entity, 46, true)
            SetPedAlertness(entity, 3)
        end
        return
    end

    if p.role == 'caller' then
        SetBlockingOfNonTemporaryEvents(entity, true)
        if Callout and Callout.callerAtDoor then
            -- Il vient de découvrir l'effraction : il guette la rue,
            SetPedCanRagdoll(entity, false)
            FreezeEntityPosition(entity, false)
            SetPedCanPlayAmbientAnims(entity, true)
            TaskStandStill(entity, -1)
            RunDoorstepWait(entity, p)
        else
            PlayAmbience(entity, 'caller')
            -- Le requérant au seuil a déjà sa boucle d'attente dédiée,
            RunSceneAmbience(entity, p)
        end

    elseif p.role == 'deceased' then
        -- Rien ici : le corps est mis en scène par LayoutDeathScene, qui
        SetBlockingOfNonTemporaryEvents(entity, true)
        TaskStandStill(entity, -1)

    elseif p.role == 'victim' then
        SetBlockingOfNonTemporaryEvents(entity, true)
        -- Une victime ne doit jamais mourir de la mise en scène : ses
        SetProtect(entity, 'victim', true)
        SetPedCanRagdollFromPlayerImpact(entity, false)

        if Callout and Callout.victimAssault then
            -- Encore aux prises avec ses agresseurs : debout, elle se
            SetPedCanRagdoll(entity, false)
            TaskStandStill(entity, -1)
            Speak(entity, p.netId, 'hurt')
        else
            -- Ragdoll court le temps de la chute, puis posture stable :
            SetPedToRagdoll(entity, 4000, 4000, 0, false, false, false)
            Speak(entity, p.netId, 'hurt')
            CreateThread(function()
                Wait(4200)
                SetWoundedPosture(entity, p)
            end)
        end

    elseif p.role == 'wanderer' then
        -- Elle erre, mais dans un périmètre restreint : avec un
        SetBlockingOfNonTemporaryEvents(entity, true)
        SetMoveRate(entity, 0.6)
        TaskWanderInArea(entity, pos.x, pos.y, pos.z, 2.0, 3.0, 10.0)

    elseif p.role == 'animal' then
        SetPedFleeAttributes(entity, 0, false)
        SetPedCombatAttributes(entity, 46, true)
        SetPedCombatAttributes(entity, 5, true)
        -- Il ne réagit plus à ce qui l'entoure : sa cible est décidée
        SetBlockingOfNonTemporaryEvents(entity, true)
        local grp = EnsureAnimalGroup()
        if grp then SetPedRelationshipGroupHash(entity, grp) end
        -- Il s'acharne sur la personne mordue. À défaut de victime dans
        local victim = nil
        for _, want in ipairs({ 'victim', 'caller' }) do
            for _, o in ipairs((Callout and Callout.peds) or {}) do
                if o.role == want and NetworkDoesNetworkIdExist(o.netId) then
                    local oe = NetworkGetEntityFromNetworkId(o.netId)
                    if oe and oe ~= 0 and DoesEntityExist(oe) then victim = oe break end
                end
            end
            if victim then break end
        end
        if victim then
            TaskCombatPed(entity, victim, 0, 16)
        else
            local r = (Callout and Callout.animalRange) or 5.0
            TaskWanderInArea(entity, pos.x, pos.y, pos.z, r, 2.0, 5.0)
        end

    elseif p.role == 'bystander' then
        SetBlockingOfNonTemporaryEvents(entity, true)
        -- Les clients d'un braquage sont mis en scène par le braquage
        if Callout and Callout.heist then return end
        PlayAmbience(entity, 'bystander')
        -- Comportement d'ambiance pendant que la police fait route.
        RunSceneAmbience(entity, p)

        -- L'orientation vers un éventuel corps est gérée globalement par

    else -- suspect
        -- Tapage : ce conducteur a été installé au volant DIRECTEMENT
        if p.inCar then
            SetBlockingOfNonTemporaryEvents(entity, true)
            return
        end

        -- Tuerie de masse : plusieurs suspects doivent rester alliés, pas
        if Callout and Callout.massIncident then
            local grp = EnsureMassSuspectGroup()
            if grp then SetPedRelationshipGroupHash(entity, grp) end
        end

        SetPedFleeAttributes(entity, 0, false)
        SetPedCombatAttributes(entity, 46, true)
        SetPedAlertness(entity, 3)

        if p.behavior == 'aggressive' then
            SetBlockingOfNonTemporaryEvents(entity, false)
            -- Tuerie de masse : s'en prend à qui est le plus proche,
            local target = Callout and Callout.massIncident
                and NearestThreatPed(entity) or NearestEngagedPed(entity)
            if target then TaskCombatPed(entity, target, 0, 16) end
            Speak(entity, p.netId, 'combat')
        elseif p.behavior == 'passive' and Callout and Callout.brawl then
            -- Rixe : les individus se battent réellement entre eux tant
            SetBlockingOfNonTemporaryEvents(entity, false)
            SetPedCombatAttributes(entity, 46, true)
            SetPedCombatAttributes(entity, 5, true)
            Speak(entity, p.netId, 'fight')

        elseif p.behavior == 'passive' then
            SetBlockingOfNonTemporaryEvents(entity, true)

            -- Maître d'un animal : il partage le groupe de relation de
            if Callout and Callout.animalRange then
                local grp = EnsureAnimalGroup()
                if grp then SetPedRelationshipGroupHash(entity, grp) end
            end

            -- Ivresse publique : démarche titubante et perte d'équilibre
            if Callout and Callout.drunk then
                CreateThread(function() MakeDrunk(entity) end)
            end

            -- Un individu qui attend n'est pas figé au garde-à-vous :
            PlayAmbience(entity, 'suspect', { keep = p.hidden or nil })
        else -- flee : attend le déclenchement
            SetBlockingOfNonTemporaryEvents(entity, true)

            if p.isDriver and Callout and Callout.driverVehNet
               and NetworkDoesNetworkIdExist(Callout.driverVehNet) then
                -- Le chauffeur (cambriolage, vol de véhicule…) attend
                local car = NetworkGetEntityFromNetworkId(Callout.driverVehNet)
                if car and car ~= 0 and DoesEntityExist(car) then
                    RequestControl(car)
                    SetPedIntoVehicle(entity, car, -1)
                    SetVehicleEngineOn(car, true, true, false)
                else
                    TaskStandStill(entity, -1)
                end

            elseif Callout and Callout.victimAssault then
                -- Ils s'acharnent sur leur victime tant que la police
                local vic = nil
                for _, o in ipairs(Callout.peds or {}) do
                    if o.role == 'victim' and NetworkDoesNetworkIdExist(o.netId) then
                        local ve = NetworkGetEntityFromNetworkId(o.netId)
                        if ve and ve ~= 0 and DoesEntityExist(ve) then vic = ve break end
                    end
                end
                if vic then
                    SetBlockingOfNonTemporaryEvents(entity, false)
                    SetPedCombatAttributes(entity, 46, true)
                    TaskCombatPed(entity, vic, 0, 16)
                else
                    TaskStandStill(entity, -1)
                end

            elseif Callout and Callout.suspectScenario then
                -- Occupés sur le véhicule qu'ils tentent de voler.
                TaskStartScenarioInPlace(entity, Callout.suspectScenario, 0, true)
                Wait(300)
                if DoesEntityExist(entity) and not IsPedActiveInScenario(entity) then
                    PlayAmbience(entity, 'suspect')
                end
            else
                TaskStandStill(entity, -1)
            end
        end
    end
end

local function TriggerFlee(p, entity, st)
    if st.fleeing then return end
    st.fleeing   = true
    st.fleeStart = GetGameTimer()
    st.fleeStage = 1
    st.lastTick  = GetGameTimer()
    -- Départ à pleine vitesse : l'allure sera bridée à l'essoufflement.
    SetMoveRate(entity, 1.0)

    SetBlockingOfNonTemporaryEvents(entity, false)
    Speak(entity, p.netId, 'flee')

    if p.fleeOn == 'bike' and p.bikeNet then
        local bike = NetworkDoesNetworkIdExist(p.bikeNet)
            and NetworkGetEntityFromNetworkId(p.bikeNet) or nil
        if bike and bike ~= 0 and DoesEntityExist(bike)
           and LSLegacy.Validate.Distance(GetEntityCoords(entity), GetEntityCoords(bike), 25.0) then
            TaskEnterVehicle(entity, bike, 10000, -1, 2.0, 1, 0)
            st.onBike = true
            SetTimeout(6000, function()
                if DoesEntityExist(entity) and IsPedInVehicle(entity, bike, false) then
                    TaskVehicleDriveWander(entity, bike, 25.0, 786603)
                end
            end)
            return
        end
    elseif p.fleeOn == 'car' and p.isDriver and Callout and Callout.driverVehNet then
        local car = NetworkDoesNetworkIdExist(Callout.driverVehNet)
            and NetworkGetEntityFromNetworkId(Callout.driverVehNet) or nil
        if car and car ~= 0 and DoesEntityExist(car) then
            SetPedIntoVehicle(entity, car, -1)
            SetVehicleEngineOn(car, true, true, false)
            TaskVehicleDriveWander(entity, car, 30.0, 786603)
            st.onBike = true
            return
        end
    end

    -- Fuite dans le CAP COMMUN de l'appel : tous les individus filent du
    local et = Callout and Callout.escapeTarget
    if et then
        st.fleeTarget = et
        TaskFollowNavMeshToCoord(entity, et.x + 0.0, et.y + 0.0, et.z + 0.0,
            3.0, -1, 2.0, false, 0)
    else
        local target = NearestEngagedPed(entity)
        if target then
            TaskSmartFleePed(entity, target, 500.0, -1, false, false)
        else
            TaskSmartFleeCoord(entity, GetEntityCoords(entity), 500.0, -1, false, false)
        end
    end

    -- Abandon de l'arme en fuite
    if p.weapon and math.random(1, 100) <= C.DropWeaponChance then
        SetTimeout(math.random(1000, 10000), function()
            if not Callout or not DoesEntityExist(entity) then return end
            local cur = PedData(p.netId)
            if not cur or not cur.weapon then return end
            SetPedDropsInventoryWeapon(entity, GetHashKey(cur.weapon), 0.0, 0.0, 0.0, 1)
            RemoveWeaponFromPed(entity, GetHashKey(cur.weapon))
            SendQ('police:callouts:suspectDropWeapon', { netId = p.netId })
        end)
    end
end

-- Les braqueurs ont-ils repéré la police ? Ils doivent la VOIR — ligne
local function HeistSpotted()
    local H = C.Heist or {}
    if not Callout then return false end

    local ref = Heist and Heist.anchor
    if not ref then return false end

    for _, a in ipairs(Callout.agents or {}) do
        local pl = GetPlayerFromServerId(a.src)
        if pl and pl ~= -1 then
            local ped = GetPlayerPed(pl)
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                local pc = GetEntityCoords(ped)
                local d  = #(pc - ref)

                -- Sirène : elle s'entend sans être vue.
                if d <= (H.SirenDist or 60.0) then
                    local veh = GetVehiclePedIsIn(ped, false)
                    if veh and veh ~= 0 and IsVehicleSirenOn(veh) then
                        return true, 'sirène'
                    end
                end

                -- Vue directe, ligne de mire dégagée.
                if d <= (H.SightDist or 35.0) then
                    local ok, clear = pcall(function()
                        local h = StartExpensiveSynchronousShapeTestLosProbe(
                            ref.x, ref.y, ref.z + 1.0,
                            pc.x, pc.y, pc.z + 1.0, 1, 0, 4)
                        local _, hit = GetShapeTestResult(h)
                        return hit ~= 1
                    end)
                    if ok and clear then return true, 'à vue' end
                end
            end
        end
    end
    return false
end

-- Applique la réaction choisie par le chef à TOUT le groupe.
local function HeistApply(reaction)
    local V = (C.Heist or {}).Vehicle or {}
    HeistLog('réaction du groupe : %s', reaction)

    for i, m in ipairs(Heist.crew or {}) do
        local e = PedEntity(m)
        if e then
            RequestControl(e)
            ClearPedTasks(e)
            SetProtect(e, 'heist', false)
            local grp = EnsureHeistCrewGroup()
            if grp then SetPedRelationshipGroupHash(e, grp) end

            if reaction == 'surrender' then
                SetBlockingOfNonTemporaryEvents(e, true)
                TaskHandsUp(e, -1, 0, -1, false)
                SetPedKeepTask(e, true)
                SendQ('police:callouts:suspectSurrender', { netId = m.netId })

            elseif reaction == 'barricade' then
                -- Retranchement : ils restent dans le commerce, à
                SetBlockingOfNonTemporaryEvents(e, false)
                SetPedCombatAttributes(e, 46, true)
                SetPedCombatAttributes(e, 5, false)   -- ne charge pas
                local tgt = NearestEngagedPed(e)
                if tgt then TaskCombatPed(e, tgt, 0, 16) end
                -- Un retranché arme au poing est engagé au combat : sans
                SendQ('police:callouts:suspectCombat',
                    { netId = m.netId, combat = true })

            elseif reaction == 'fight' then
                SetBlockingOfNonTemporaryEvents(e, false)
                SetPedCombatAttributes(e, 46, true)
                SetPedCombatAttributes(e, 5, true)
                local tgt = NearestEngagedPed(e)
                if tgt then TaskCombatPed(e, tgt, 0, 16) end
                Speak(e, m.netId, 'combat')
                SendQ('police:callouts:suspectCombat',
                    { netId = m.netId, combat = true })

            elseif reaction == 'flee_car' then
                -- Repli sur le véhicule : ils embarquent l'un après
                local veh = Heist.veh
                -- Une place fixe par braqueur (au lieu de -2 « n'importe
                local seat = i - 1
                if veh and DoesEntityExist(veh) then
                    SetBlockingOfNonTemporaryEvents(e, false)
                    if m.weapon then
                        SetPedCombatAttributes(e, 46, true)
                        local tgt = NearestEngagedPed(e)
                        if tgt then TaskCombatPed(e, tgt, 0, 16) end
                        Speak(e, m.netId, 'combat')
                        SendQ('police:callouts:suspectCombat',
                            { netId = m.netId, combat = true })
                        local netId = m.netId
                        CreateThread(function()
                            Wait(2500)
                            if not DoesEntityExist(e) or not DoesEntityExist(veh) then return end
                            -- La scène peut avoir changé entre-temps
                            local cur = PedData(netId)
                            if cur and cur.state and cur.state ~= 'idle' then return end
                            RequestControl(e)
                            ClearPedTasks(e)
                            TaskEnterVehicle(e, veh, 20000, seat, 2.0, 1, 0)
                        end)
                    else
                        TaskEnterVehicle(e, veh, 20000, seat, 2.0, 1, 0)
                    end
                else
                    local st = BrainState[m.netId] or {}
                    BrainState[m.netId] = st
                    TriggerFlee(m, e, st)
                end

            else   -- flee_foot
                local st = BrainState[m.netId] or {}
                BrainState[m.netId] = st
                SetBlockingOfNonTemporaryEvents(e, false)
                TriggerFlee(m, e, st)
            end
        end
    end

    -- Le conducteur : il attend que quelqu'un monte, puis démarre.
    if reaction == 'flee_car' and Heist.driver then
        CreateThread(function()
            local de  = PedEntity(Heist.driver)
            local veh = Heist.veh
            if not de or not veh or not DoesEntityExist(veh) then return end

            -- Filet de sécurité : si l'embarquement précoce (cf. la
            if not IsPedInVehicle(de, veh, false) then
                RequestControl(de)
                SetPedIntoVehicle(de, veh, -1)
            end

            local deadline = GetGameTimer() + (V.LeaveDelay or 4000) + 20000
            while GetGameTimer() < deadline do
                Wait(400)
                if not DoesEntityExist(veh) or not DoesEntityExist(de) then return end
                -- La scène peut être nettoyée pendant l'embarquement.
                if not Heist then return end
                local aboard = 0
                for _, m in ipairs(Heist.crew or {}) do
                    local e = PedEntity(m)
                    if e and IsPedInVehicle(e, veh, false) then aboard = aboard + 1 end
                end
                -- Dès qu'un braqueur est à bord, on démarre. Les autres
                if aboard > 0 then
                    Wait(V.LeaveDelay or 4000)
                    break
                end
            end

            if DoesEntityExist(de) and DoesEntityExist(veh) then
                RequestControl(veh)
                TaskVehicleDriveWander(de, veh, V.DriveSpeed or 30.0,
                    V.DriveStyle or 786469)
                HeistLog('le véhicule démarre')
            end
        end)
    end

    -- Les civils reprennent leurs esprits une fois la scène décidée.
    Heist.resolved = true
end

-- Les civils reprennent une vie normale une fois les braqueurs partis
local function HeistCiviliansRecover()
    if not Heist or Heist.recovered then return end
    Heist.recovered = true
    local After = ((C.Heist or {}).Clients or {}).After or {}

    for _, c in ipairs(Heist.civils or {}) do
        local e = PedEntity(c)
        if e then
            RequestControl(e)
            SetProtect(e, 'heist', false)
            ClearPedTasksImmediately(e)
            SetPedCanRagdoll(e, true)
            SetBlockingOfNonTemporaryEvents(e, true)

            local pick, total = nil, 0
            for _, w in pairs(After) do total = total + w end
            local r, acc = math.random() * math.max(1, total), 0
            for k, w in pairs(After) do
                acc = acc + w
                if r <= acc then pick = k break end
            end

            if pick == 'call' or pick == 'phone' then
                TaskStartScenarioInPlace(e, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
            elseif pick == 'leave' then
                local pos = GetEntityCoords(e)
                TaskWanderInArea(e, pos.x, pos.y, pos.z, 8.0, 2.0, 6.0)
            else
                TaskStartScenarioInPlace(e, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
            end
        end
    end

    -- Le caissier appelle la police, puis reste disponible.
    local ce = Heist.cashier and PedEntity(Heist.cashier)
    if ce then
        RequestControl(ce)
        SetProtect(ce, 'heist', false)
        ClearPedTasksImmediately(ce)
        SetBlockingOfNonTemporaryEvents(ce, true)
        TaskStartScenarioInPlace(ce, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
    end
    HeistLog('les civils reprennent une vie normale')
end

-- Met la scène en place, puis surveille l'arrivée de la police.
local function StartHeistScene()
    if not Callout or not Callout.heist then return end
    if not (C.Heist or {}).Enabled then return end
    if Heist and Heist.id == Callout.id then return end

    -- On attend que TOUS les PNJ soient posés. Le placement corrige
    local ready = 0
    for _, p in ipairs(Callout.peds or {}) do
        if not NetworkDoesNetworkIdExist(p.netId) then return end
        local st = BrainState[p.netId]
        if not (st and st.init) then return end
        ready = ready + 1
    end
    if ready == 0 then return end

    local scene = HeistScene()
    Heist = {
        id = Callout.id, scene = scene, crew = {}, civils = {},
        anchor = SceneReference() or vector3(Callout.coords.x,
            Callout.coords.y, Callout.coords.z),
    }

    for _, p in ipairs(Callout.peds or {}) do
        if p.role == 'suspect' then
            if p.heistRole == 'driver' then Heist.driver = p
            else Heist.crew[#Heist.crew + 1] = p end
        elseif p.cashier then Heist.cashier = p
        elseif p.role == 'bystander' then Heist.civils[#Heist.civils + 1] = p
        end
    end

    if Callout.driverVehNet and NetworkDoesNetworkIdExist(Callout.driverVehNet) then
        local v = NetworkGetEntityFromNetworkId(Callout.driverVehNet)
        if v and v ~= 0 and DoesEntityExist(v) then Heist.veh = v end
    end

    HeistLog('scène « %s », chef %s — %d braqueur(s), %d client(s)',
        tostring(scene and scene.id), tostring(Callout.heist.leader),
        #Heist.crew, #Heist.civils)

    -- Groupe de relation commun à toute l'équipe : évite qu'ils se
    do
        local grp = EnsureHeistCrewGroup()
        if grp then
            for _, m in ipairs(Heist.crew) do
                local e = PedEntity(m)
                if e then SetPedRelationshipGroupHash(e, grp) end
            end
            if Heist.driver then
                local de = PedEntity(Heist.driver)
                if de then SetPedRelationshipGroupHash(de, grp) end
            end
        end
    end

    -- 1. État de départ
    local jobs = {}
    for job, n in pairs((scene and scene.roles) or {}) do
        for _ = 1, n do jobs[#jobs + 1] = job end
    end

    for i, m in ipairs(Heist.crew) do
        local e = PedEntity(m)
        if e then
            if scene and scene.boarding then
                -- Scénario « sortie » : ils rejoignent déjà le véhicule.
                if Heist.veh and DoesEntityExist(Heist.veh) then
                    RequestControl(e)
                    SetBlockingOfNonTemporaryEvents(e, false)
                    TaskEnterVehicle(e, Heist.veh, 20000, i - 1, 2.0, 1, 0)
                end
            else
                HeistCrewPosture(e, jobs[i] or 'crew', Heist.anchor)
            end
        end
    end

    if Heist.driver then
        HeistDriverIdle(PedEntity(Heist.driver), Heist.veh)
    end

    local ce = Heist.cashier and PedEntity(Heist.cashier)
    if ce then HeistCivilPosture(ce, (scene and scene.cashier) or 'handsup') end

    local P = ((C.Heist or {}).Clients or {}).Postures or {}
    for _, c in ipairs(Heist.civils) do
        local e = PedEntity(c)
        if e then
            -- La dominante du scénario s'impose une fois sur deux, le
            local posture = scene and scene.clients or 'down'
            if math.random(1, 100) > 50 then
                local total, acc = 0, 0
                for _, w in pairs(P) do total = total + w end
                local r = math.random() * math.max(1, total)
                for k, w in pairs(P) do
                    acc = acc + w
                    if r <= acc then posture = k break end
                end
            end
            HeistCivilPosture(e, posture)
        end
    end

    -- 2. Détection, puis 3. décision
    CreateThread(function()
        local calloutId = Callout.id
        while Callout and Callout.id == calloutId and IsBrain do
            Wait(500)
            -- La fin d'intervention efface Callout ET Heist. Le test de
            if not Heist or not Callout or Callout.id ~= calloutId then return end
            if Heist.decided then break end

            local seen, how = HeistSpotted()
            if seen then
                Heist.decided = true
                HeistLog('police repérée (%s) — le chef décide…', tostring(how))
                Wait((C.Heist or {}).DecideWait or 1200)
                if not Heist or not Callout or Callout.id ~= calloutId then return end
                HeistApply(HeistDecide(Heist.scene))
            end
        end
    end)

    -- Retour à la normale
    CreateThread(function()
        local calloutId = Callout.id
        while Callout and Callout.id == calloutId do
            Wait(1500)
            if not Heist or not Callout or Callout.id ~= calloutId then return end
            if Heist.decided and not Heist.recovered then
                local active = 0
                for _, m in ipairs(Heist.crew) do
                    local cur = PedData(m.netId)
                    if cur and cur.state == 'idle' and not cur.escaped then
                        local e = PedEntity(m)
                        if e and LSLegacy.Validate.Distance(GetEntityCoords(e), Heist.anchor, 60.0) then
                            active = active + 1
                        end
                    end
                end
                if active == 0 then HeistCiviliansRecover() end
            end
        end
    end)
end

local function Surrender(p, entity, st)
    st.surrendered = true
    st.fleeing     = false
    st.fleeStage   = nil
    SetMoveRate(entity, 1.0)
    ClearPedTasks(entity)
    SetBlockingOfNonTemporaryEvents(entity, true)
    TaskHandsUp(entity, -1, 0, -1, false)
    Speak(entity, p.netId, 'surrender')
    SendQ('police:callouts:suspectSurrender', { netId = p.netId })
end

-- Première tâche des PNJ non encore initialisés — tourne chez CHAQUE
CreateThread(function()
    while true do
        Wait(500)
        if Callout then
            for _, p in ipairs(Callout.peds or {}) do
                local st = BrainState[p.netId]
                if not (st and st.init) and NetworkDoesNetworkIdExist(p.netId) then
                    local resolved = (p.state == 'delivered' or p.state == 'dead'
                        or p.state == 'escaped' or p.state == 'cuffed'
                        or p.state == 'dispersed')
                    if not resolved then
                        local entity = NetworkGetEntityFromNetworkId(p.netId)
                        if entity and entity ~= 0 and DoesEntityExist(entity)
                           and RequestControl(entity) then
                            BrainState[p.netId] = BrainState[p.netId] or {}
                            BrainState[p.netId].init = true
                            ApplyInitialTask(p, entity)
                        end
                    end
                end
            end
        end
    end
end)

-- Pose des corps de la tuerie de masse — tourne chez CHAQUE agent
CreateThread(function()
    while true do
        Wait(500)
        if Callout and Callout.massIncident and Callout.objective == 'death' then
            LayoutMassIncidentCorpses()
        end
    end
end)

-- Mise en scène du tapage — tourne chez CHAQUE agent engagé, pas
CreateThread(function()
    while true do
        Wait(500)
        if Callout and Callout.objective == 'radio' then
            LayoutRadioScene()
        end
    end
end)

-- Boucle principale du cerveau.
CreateThread(function()
    while true do
        Wait(500)
        if IsBrain and Callout then
            local now = GetGameTimer()

            -- Constatation : la scène est recomposée d'un bloc, une fois
            if Callout.objective == 'death' then
                if not Callout.massIncident then
                    LayoutDeathScene()
                end
            end

            for _, p in ipairs(Callout.peds or {}) do
                local resolved = (p.state == 'delivered' or p.state == 'dead'
                    or p.state == 'escaped' or p.state == 'cuffed'
                    or p.state == 'dispersed')

                -- MORT D'UN PNJ — détection hors de toute branche.
                if p.state ~= 'dead' and NetworkDoesNetworkIdExist(p.netId) then
                    local de = NetworkGetEntityFromNetworkId(p.netId)
                    if de and de ~= 0 and DoesEntityExist(de) then
                        local st = BrainState[p.netId] or {}
                        BrainState[p.netId] = st
                        if not st.reportedDead and IsPedDeadOrDying(de, true) then
                            st.reportedDead = true
                            local killerSrc = nil
                            local killer = GetPedSourceOfDeath(de)
                            if killer and killer ~= 0 and IsPedAPlayer(killer) then
                                local pl = NetworkGetPlayerIndexFromPed(killer)
                                if pl and pl ~= -1 then
                                    killerSrc = GetPlayerServerId(pl)
                                end
                            end
                            -- L'engagement au combat voyage AVEC le
                            local cause = 0
                            pcall(function() cause = GetPedCauseOfDeath(de) or 0 end)
                            SendQ('police:callouts:suspectDead', {
                                netId = p.netId, killer = killerSrc,
                                cause = cause,
                                combat = st.lastCombat
                                    or IsPedInCombat(de, PlayerPedId())
                                    or IsPedShooting(de) or nil,
                            })
                        end
                    end
                end

                -- FOUILLE : l'arme quitte réellement les mains.
                if p.searched and NetworkDoesNetworkIdExist(p.netId) then
                    local st = BrainState[p.netId] or {}
                    BrainState[p.netId] = st
                    if not st.disarmed then
                        local we = NetworkGetEntityFromNetworkId(p.netId)
                        if we and we ~= 0 and DoesEntityExist(we) then
                            st.disarmed = true
                            RequestControl(we)
                            RemoveAllPedWeapons(we, true)
                            SetCurrentPedWeapon(we, GetHashKey('WEAPON_UNARMED'), true)
                            SetPedDropsWeaponsWhenDead(we, false)
                        end
                    end
                end

                -- Menottage : posture mains dans le dos, appliquée dès le
                if p.state == 'cuffed' and NetworkDoesNetworkIdExist(p.netId) then
                    local st = BrainState[p.netId] or {}
                    BrainState[p.netId] = st
                    if not st.cuffAnim then
                        local ent = NetworkGetEntityFromNetworkId(p.netId)
                        if ent and ent ~= 0 and DoesEntityExist(ent) then
                            st.cuffAnim = true
                            RequestControl(ent)
                            ClearPedTasks(ent)
                            SetBlockingOfNonTemporaryEvents(ent, true)
                            SetMoveRate(ent, 1.0)
                            SetEnableHandcuffs(ent, true)
                            if LoadAnim('mp_arresting') then
                                TaskPlayAnim(ent, 'mp_arresting', 'idle', 8.0, -8.0,
                                    -1, 49, 0, false, false, false)
                                SetPedKeepTask(ent, true)
                            end
                        end
                    end
                end

                -- Victime secourue : elle se relève tranquillement, une
                if p.role == 'victim' and p.state == 'healed'
                   and NetworkDoesNetworkIdExist(p.netId) then
                    local st = BrainState[p.netId] or {}
                    BrainState[p.netId] = st
                    if not st.raised then
                        local ve = NetworkGetEntityFromNetworkId(p.netId)
                        if ve and ve ~= 0 and DoesEntityExist(ve)
                           and not IsEntityDead(ve) then
                            st.raised = true
                            WoundedPed[p.netId] = nil
                            RequestControl(ve)
                            ClearPedTasksImmediately(ve)
                            SetPedCanRagdoll(ve, false)
                            SetBlockingOfNonTemporaryEvents(ve, true)
                            SetMoveRate(ve, 0.7)
                            TaskStandStill(ve, -1)
                            -- Secourue, elle reprend une activité :
                            RunSceneAmbience(ve, p)
                        end
                    end
                end

                -- Individu qu'on vient de faire circuler : il s'éloigne
                if p.state == 'dispersed' and NetworkDoesNetworkIdExist(p.netId) then
                    local st = BrainState[p.netId] or {}
                    BrainState[p.netId] = st
                    if not st.dispersed then
                        st.dispersed = true
                        local ent = NetworkGetEntityFromNetworkId(p.netId)
                        if ent and ent ~= 0 and DoesEntityExist(ent) then
                            RequestControl(ent)
                            ClearPedTasks(ent)
                            SetBlockingOfNonTemporaryEvents(ent, false)
                            SetPedKeepTask(ent, true)
                            TaskWanderStandard(ent, 10.0, 10)
                        end
                    end
                end

                if not resolved and NetworkDoesNetworkIdExist(p.netId) then
                    local entity = NetworkGetEntityFromNetworkId(p.netId)
                    if entity and entity ~= 0 and DoesEntityExist(entity) then

                        BrainState[p.netId] = BrainState[p.netId] or {}
                        local st = BrainState[p.netId]

                        if not st.init then
                            st.init = true
                            ApplyInitialTask(p, entity)
                        end

                        -- Mains en l'air maintenues jusqu'au menottage
                        if st.handsUp and p.state ~= 'cuffed'
                           and (now - (st.handsUpTick or 0)) > 4000 then
                            st.handsUpTick = now
                            TaskHandsUp(entity, -1, 0, -1, false)
                        end

                        -- Victime encore debout, agrippée par ses agresseurs
                        if p.role == 'victim' and Callout.victimAssault
                           and not Callout.animalRange and p.state ~= 'healed'
                           and not st.victimDown then
                            local officer, odist = NearestEngagedPed(entity)
                            if officer and odist
                               and odist < (C.VictimAssaultAggroDist or 10.0) then
                                st.victimDown = true
                                SetPedCanRagdoll(entity, true)
                                SetPedToRagdoll(entity, 4000, 4000, 0, false, false, false)
                                CreateThread(function()
                                    Wait(4200)
                                    SetWoundedPosture(entity, p)
                                end)
                            end
                        end

                        -- Suspect passif qui peut se montrer agressif à
                        if Callout.aggroOnApproachChance and p.role == 'suspect'
                           and p.behavior ~= 'aggressive' and p.state == 'idle'
                           and not st.aggroRolled and not st.handsUp then
                            local officer, odist = NearestEngagedPed(entity)
                            if officer and odist
                               and odist < (Callout.aggroOnApproachDist
                                             or C.AggroApproachDist or 4.0) then
                                st.aggroRolled = true
                                if math.random(1, 100) <= Callout.aggroOnApproachChance then
                                    p.behavior = 'aggressive'
                                    ClearPedTasks(entity)
                                    SetBlockingOfNonTemporaryEvents(entity, false)
                                    SetPedCombatAttributes(entity, 46, true)
                                    SetPedCombatAttributes(entity, 5, true)
                                    SetPedAlertness(entity, 3)
                                    TaskCombatPed(entity, officer, 0, 16)
                                    Speak(entity, p.netId, 'combat')
                                end
                            end
                        end

                        -- Ivresse : perte d'équilibre à intervalles
                        if Callout.drunk and p.role == 'suspect'
                           and p.state == 'idle' and not st.handsUp then
                            local D = C.Drunk or {}
                            if not st.stumbleAt then
                                st.stumbleAt = now + math.random(
                                    D.StumbleMin or 14000, D.StumbleMax or 26000)
                            elseif now >= st.stumbleAt then
                                st.stumbleAt = now + math.random(
                                    D.StumbleMin or 14000, D.StumbleMax or 26000)
                                local ms = D.StumbleTime or 1600
                                -- Type 3 : chute molle, pas la projection
                                SetPedToRagdoll(entity, ms, ms, 3, false, false, false)
                            end
                        end

                        -- Tuerie de masse : un suspect agressif re-choisit
                        if Callout.massIncident and p.role == 'suspect' and p.weapon
                           and (p.behavior == 'aggressive'
                                or (p.behavior == 'flee' and st.fleeing))
                           and p.state == 'idle'
                           and (now - (st.threatTick or 0)) > 4000 then
                            st.threatTick = now
                            local tgt = NearestThreatPed(entity)
                            if tgt and not IsPedInCombat(entity, tgt) then
                                TaskCombatPed(entity, tgt, 0, 16)
                            end
                        end

                        -- Tuerie de masse : « tout ce qui se trouve à
                        if Callout.massIncident and p.role == 'suspect' and p.weapon
                           and p.behavior == 'aggressive' and p.state == 'idle'
                           and (now - (st.vehThreatTick or 0)) > 2000 then
                            st.vehThreatTick = now
                            local veh = MassThreat.NearestVehicle(entity, 20.0)
                            if veh then MassThreat.ShootAtVehicle(entity, veh) end
                        end

                        -- BRAQUAGE : le groupe est piloté par la décision
                        local heistHeld = Callout.heist and p.role == 'suspect'
                            and Heist and Heist.id == Callout.id
                            and not Heist.decided

                        if heistHeld then
                            -- La mise en scène tient le rôle, MAIS un
                            if p.behavior == 'passive' and not st.handsUp
                               and IsAimedAtBy(entity) then
                                st.handsUp     = true
                                st.handsUpTick = now
                                RequestControl(entity)
                                ClearPedTasksImmediately(entity)
                                SetBlockingOfNonTemporaryEvents(entity, true)
                                SetPedKeepTask(entity, true)
                                TaskHandsUp(entity, -1, 0, -1, false)
                                Speak(entity, p.netId, 'surrender')
                                SendQ('police:callouts:suspectSurrender', { netId = p.netId })
                            elseif st.handsUp and (now - (st.handsUpTick or 0)) > 4000 then
                                st.handsUpTick = now
                                TaskHandsUp(entity, -1, 0, -1, false)
                            end

                        elseif p.state == 'stunned' then
                            -- Immobilisé : rien à faire, le timer local le relèvera
                        elseif p.role == 'suspect' and Callout.brawl
                               and p.behavior == 'passive' then
                            -- Rixe : ils s'empoignent entre eux, et cessent
                            local BR   = C.Brawl or {}
                            local dist = NearestEngagedDistance(entity)
                            if st.handsUp then
                                -- Maintien de la posture jusqu'au menottage
                                if (now - (st.handsUpTick or 0)) > 4000 then
                                    st.handsUpTick = now
                                    if not IsEntityPlayingAnim(entity, 'random@arrests@busted',
                                        'idle_a', 3) then
                                        TaskHandsUp(entity, -1, 0, -1, false)
                                    end
                                end
                            elseif st.turned then
                                -- Il a choisi l'affrontement : on entretient
                                if (now - (st.turnTick or 0)) > 5000 then
                                    st.turnTick = now
                                    local tgt = NearestEngagedPed(entity)
                                    if tgt then TaskCombatPed(entity, tgt, 0, 16) end
                                end

                            elseif dist > (BR.NoticeDist or 12.0) then
                                -- Personne en vue : la rixe continue entre eux.
                                st.faced = nil
                                if not st.brawling or (now - (st.brawlTick or 0)) > 6000 then
                                    st.brawling  = true
                                    st.brawlTick = now

                                    -- Adversaires APPARIÉS : sans ça, tous
                                    local mine = GetEntityCoords(entity)
                                    local foe, best = nil, 9999.0
                                    for _, o in ipairs(Callout.peds or {}) do
                                        if o.role == 'suspect' and o.netId ~= p.netId
                                           and o.state ~= 'cuffed' and o.state ~= 'dead'
                                           and o.state ~= 'delivered' and o.state ~= 'stunned'
                                           and NetworkDoesNetworkIdExist(o.netId) then
                                            local oe = NetworkGetEntityFromNetworkId(o.netId)
                                            if oe and oe ~= 0 and DoesEntityExist(oe)
                                               and not IsEntityDead(oe) then
                                                local d = #(GetEntityCoords(oe) - mine)
                                                if d < best then best = d foe = oe end
                                            end
                                        end
                                    end

                                    if foe then
                                        -- Une rixe n'est pas un règlement
                                        SetProtect(entity, 'brawl', true)
                                        SetPedSuffersCriticalHits(entity, false)
                                        BrawlShield[entity] = true
                                        TaskCombatPed(entity, foe, 0, 16)
                                        Speak(entity, p.netId, 'fight')
                                    else
                                        -- Plus personne à affronter : il se
                                        st.brawling = false
                                        ClearPedTasks(entity)
                                        TaskStandStill(entity, -1)
                                    end
                                end

                            else
                                -- Les agents sont là. La bagarre s'arrête,
                                if st.brawling or not st.faced then
                                    st.brawling = false
                                    st.faced    = now
                                    -- Les agents sont là : la protection de
                                    BrawlShield[entity] = nil
                                    SetProtect(entity, 'brawl', false)
                                    ClearPedTasks(entity)
                                    SetBlockingOfNonTemporaryEvents(entity, true)
                                    TaskStandStill(entity, -1)
                                    local tgt = NearestEngagedPed(entity)
                                    if tgt then FaceEntity(entity, tgt) end
                                end

                                -- Le sort de chacun se joue à la mise en
                                local patience = BR.PatienceDelay or 0
                                local aimed = IsAimedAtBy(entity)
                                local waited = patience > 0
                                    and (now - (st.faced or now)) > patience

                                if (C.Brawl or {}).Debug then
                                    print(('^5[rixe]^7 %s — agent à %.1f m, ' ..
                                        'en joue : %s')
                                        :format(tostring(p.label), dist,
                                            tostring(aimed)))
                                end

                                if aimed or waited then
                                    local chance = BR.SurrenderChance or 70
                                    if p.weapon then
                                        chance = chance - (BR.ArmedSurrenderMalus or 25)
                                    end
                                    -- Sans mise en joue, personne ne se
                                    if not aimed then chance = 100 end

                                    if math.random(1, 100) <= chance then
                                        st.handsUp     = true
                                        st.handsUpTick = now
                                        -- ClearPedTasksImmediately : une
                                        RequestControl(entity)
                                        ClearPedTasksImmediately(entity)
                                        SetBlockingOfNonTemporaryEvents(entity, true)
                                        SetPedKeepTask(entity, true)
                                        TaskHandsUp(entity, -1, 0, -1, false)
                                        Speak(entity, p.netId, 'surrender')
                                        SendQ('police:callouts:suspectSurrender',
                                            { netId = p.netId })
                                    else
                                        st.turned  = true
                                        st.turnTick = now
                                        BrawlShield[entity] = nil
                                        SetProtect(entity, 'brawl', false)
                                        ClearPedTasks(entity)
                                        SetBlockingOfNonTemporaryEvents(entity, false)
                                        SetPedCombatAttributes(entity, 46, true)
                                        SetPedCombatAttributes(entity, 5, true)
                                        SetPedAlertness(entity, 3)
                                        local tgt = NearestEngagedPed(entity)
                                        if tgt then TaskCombatPed(entity, tgt, 0, 16) end
                                        Speak(entity, p.netId, 'combat')
                                        SendQ('police:callouts:suspectCombat',
                                            { netId = p.netId, combat = true })
                                    end
                                end
                            end

                        elseif p.role == 'suspect' and not st.surrendered then

                            -- Report de l'état de combat (sert au §arme létale)
                            local inCombat = st.lastCombat or false
                            if not inCombat then
                                inCombat = IsPedShooting(entity)
                                    or IsPedInCombat(entity, PlayerPedId())
                                if not inCombat then
                                    local off = NearestEngagedPed(entity)
                                    if off then
                                        inCombat = IsPedInCombat(entity, off)
                                    end
                                end
                            end
                            -- Une fois l'arme employée contre la police,
                            if inCombat and not st.lastCombat then
                                st.lastCombat = true
                                SendQ('police:callouts:suspectCombat',
                                    { netId = p.netId, combat = true })
                            end

                            local dist = NearestEngagedDistance(entity)

                            -- Déclenchement de la fuite
                            if p.behavior == 'flee' and not st.fleeing then
                                local trigger = (Callout and Callout.fleeTrigger)
                                    or C.FleeTriggerDistance
                                if dist <= trigger then
                                    if Callout.massIncident and p.weapon
                                       and not st.threatBurstDone then
                                        -- Tuerie de masse : avant de fuir,
                                        st.threatBurstDone = true
                                        local tgt = NearestThreatPed(entity)
                                        if tgt then
                                            SetPedCombatAttributes(entity, 46, true)
                                            TaskCombatPed(entity, tgt, 0, 16)
                                            local netId = p.netId
                                            CreateThread(function()
                                                Wait(1800)
                                                local cur = PedData(netId)
                                                local ent2 = NetworkDoesNetworkIdExist(netId)
                                                    and NetworkGetEntityFromNetworkId(netId) or nil
                                                if ent2 and ent2 ~= 0 and DoesEntityExist(ent2)
                                                   and cur and cur.state == 'idle' then
                                                    TriggerFlee(p, ent2, BrainState[netId] or st)
                                                end
                                            end)
                                        else
                                            TriggerFlee(p, entity, st)
                                        end
                                    else
                                        TriggerFlee(p, entity, st)
                                    end
                                end
                            end

                            -- Le trajet vers le cap commun s'est achevé (ou a
                            if st.fleeing and not st.onBike and st.fleeTarget
                               and GetScriptTaskStatus(entity, 0x0521BA60) ~= 1 then
                                st.fleeTarget = nil
                                local tgt = NearestEngagedPed(entity)
                                if tgt then
                                    TaskSmartFleePed(entity, tgt, 500.0, -1, false, false)
                                else
                                    TaskSmartFleeCoord(entity, GetEntityCoords(entity),
                                        500.0, -1, false, false)
                                end
                            end

                            -- Course : sprint limité dans le temps, puis
                            if st.fleeing and not st.onBike then
                                st.lastTick = now
                                local ran = (now - (st.fleeStart or now)) / 1000

                                -- Trois paliers d'épuisement. Le premier
                                local sprint = (Callout and Callout.fleeSprint)
                                    or C.FleeSprintDuration or 15
                                local slowAt = (Callout and Callout.fleeSlowAt)
                                    or C.FleeSlowAt or 18
                                if slowAt <= sprint then slowAt = sprint + 3 end

                                local stage = 1
                                if ran > slowAt then stage = 3
                                elseif ran > sprint then stage = 2 end

                                if stage ~= (st.fleeStage or 1) then
                                    st.fleeStage = stage
                                    local rate = 1.0
                                    if stage == 2 then
                                        rate = C.FleeRateTired or 0.50
                                    elseif stage == 3 then
                                        rate = C.FleeRateExhausted or 0.35
                                    end
                                    SetMoveRate(entity, rate)
                                    if stage == 2 then
                                        Speak(entity, p.netId, 'flee')
                                    end
                                end

                                -- Dès qu'il a ralenti, un agent au contact
                                if stage >= 2
                                   and dist <= (C.FleeSurrenderDist or 10.0) then
                                    Surrender(p, entity, st)
                                end

                                -- Garde-fou : durée de fuite maximale
                                if not st.reportedEscape
                                   and (now - (st.fleeStart or now)) > (C.FleeMaxDuration * 1000) then
                                    st.reportedEscape = true
                                    SendQ('police:callouts:suspectEscaped',
                                        { netId = p.netId })
                                end
                            end

                            -- Échappement par la distance
                            if dist > C.EscapeDistance then
                                st.farSince = st.farSince or now
                                if not st.reportedEscape
                                   and (now - st.farSince) > (C.EscapeDelay * 1000) then
                                    st.reportedEscape = true
                                    SendQ('police:callouts:suspectEscaped',
                                        { netId = p.netId })
                                end
                            else
                                st.farSince = nil
                            end

                        elseif p.role == 'animal' then
                            local officer, odist = NearestEngagedPed(entity)

                            -- Tant qu'aucun agent n'est en vue, la cible
                            if not st.dogTarget
                               and (not odist or odist >= (C.AnimalAggroDist or 10.0))
                               and (now - (st.dogTick or 0)) > 4000 then
                                st.dogTick = now
                                local prey = nil
                                for _, o in ipairs(Callout.peds or {}) do
                                    if o.role == 'victim' and o.state ~= 'healed'
                                       and NetworkDoesNetworkIdExist(o.netId) then
                                        local ve = NetworkGetEntityFromNetworkId(o.netId)
                                        if ve and ve ~= 0 and DoesEntityExist(ve)
                                           and not IsEntityDead(ve) then
                                            prey = ve break
                                        end
                                    end
                                end
                                if prey and not IsPedInCombat(entity, prey) then
                                    ClearPedTasks(entity)
                                    TaskCombatPed(entity, prey, 0, 16)
                                end
                            end

                            -- Dès qu'un agent approche, le chien lâche sa
                            if officer and odist
                               and odist < (C.AnimalAggroDist or 10.0) then
                                if st.dogTarget ~= officer then
                                    st.dogTarget = officer
                                    st.dogTick   = now
                                    ClearPedTasks(entity)
                                    TaskCombatPed(entity, officer, 0, 16)
                                elseif (now - (st.dogTick or 0)) > 4000
                                       and not IsPedInCombat(entity, officer) then
                                    st.dogTick = now
                                    TaskCombatPed(entity, officer, 0, 16)
                                end

                                -- Le chien lâche sa proie. Elle NE SE RELÈVE
                                if not st.victimRaised then
                                    st.victimRaised = true
                                    for _, o in ipairs(Callout.peds or {}) do
                                        if o.role == 'victim' and o.state ~= 'healed'
                                           and NetworkDoesNetworkIdExist(o.netId) then
                                            local ve = NetworkGetEntityFromNetworkId(o.netId)
                                            if ve and ve ~= 0 and DoesEntityExist(ve)
                                               and not IsEntityDead(ve) then
                                                CreateThread(function()
                                                    SetWoundedPosture(ve, o)
                                                end)
                                            end
                                        end
                                    end
                                end
                            end

                            if IsPedDeadOrDying(entity, true) then
                                if not st.reportedDead then
                                    st.reportedDead = true
                                    SendQ('police:callouts:suspectDead', { netId = p.netId })
                                end
                            elseif (now - (st.lastBark or 0)) > math.random(3000, 7000) then
                                st.lastBark = now
                                pcall(function() PlayAnimalVocalization(entity, 6, 'BARK') end)
                            end
                        end
                    end
                end
            end

            -- Braquage : la scène est composée d'un bloc, une seule
            if Callout.heist then
                StartHeistScene()

                -- Le véhicule du chauffeur peut streamer APRÈS la mise
                if Heist and Heist.id == Callout.id and Heist.driver
                   and not Heist.driverBoarded then
                    local de = PedEntity(Heist.driver)
                    local ve = Callout.driverVehNet
                        and NetworkDoesNetworkIdExist(Callout.driverVehNet)
                        and NetworkGetEntityFromNetworkId(Callout.driverVehNet) or nil
                    if de and ve and ve ~= 0 and DoesEntityExist(ve) then
                        if IsPedInVehicle(de, ve, false) then
                            Heist.driverBoarded = true
                        else
                            HeistDriverIdle(de, ve)
                            if IsPedInVehicle(de, ve, false) then
                                Heist.driverBoarded = true
                            end
                        end
                    end
                end
            end
        end
    end
end)

--  MOYENS DE CONTRAINTE NON LÉTAUX

local function NonLethalFor(weaponHash)
    for name, cfg in pairs(C.NonLethal) do
        if GetHashKey(name) == weaponHash then return name, cfg end
    end
    return nil
end

-- Pendant une intervention, les armes de contrainte voient leurs dégâts
local NonLethalScaled = nil

CreateThread(function()
    while true do
        Wait(1000)
        local want = (Callout ~= nil)
        if want ~= NonLethalScaled then
            NonLethalScaled = want
            local scale = want and (C.NonLethalDamageScale or 0.05) or 1.0
            for name in pairs(C.NonLethal or {}) do
                SetWeaponDamageModifier(GetHashKey(name), scale + 0.0)
            end
        end
    end
end)

local function KnockDown(p, entity, duration)
    SendQ('police:callouts:suspectStunned', { netId = p.netId })

    -- L'individu cesse IMMÉDIATEMENT d'être agressif. Sans ça, la
    local st = BrainState[p.netId] or {}
    BrainState[p.netId] = st
    st.turned   = false
    st.brawling = false
    st.fleeing  = false

    RequestControl(entity)
    ClearPedTasksImmediately(entity)
    SetPedToRagdoll(entity, duration * 1000, duration * 1000, 0, false, false, false)

    -- Relève automatique si l'individu n'est pas menotté entre-temps
    SetTimeout(duration * 1000 + 500, function()
        if not Callout or not DoesEntityExist(entity) then return end
        local cur = PedData(p.netId)
        if not cur then return end
        -- On n'exige plus l'état « stunned » : l'accusé de réception du
        if cur.state ~= 'cuffed' and cur.state ~= 'delivered'
           and cur.state ~= 'dead' and cur.state ~= 'escaped' then
            -- Il se relève, mais il ne repart pas : il se rend, mains en
            local st = BrainState[p.netId] or {}
            BrainState[p.netId] = st
            st.fleeing     = false
            st.surrendered = true
            st.turned      = false   -- il renonce aussi à l'affrontement
            st.brawling    = false
            st.handsUp     = true
            st.handsUpTick = GetGameTimer()
            ClearPedTasks(entity)
            SetBlockingOfNonTemporaryEvents(entity, true)
            TaskHandsUp(entity, -1, 0, -1, false)
            Speak(entity, p.netId, 'surrender')
            SendQ('police:callouts:suspectSurrender', { netId = p.netId })
        end
    end)
end

--  TASER — TRAITEMENT ENTIÈREMENT SCRIPTÉ


local function SetTaserShield(on)
    if on then
        for _, p in ipairs((Callout and Callout.peds) or {}) do
            if NetworkDoesNetworkIdExist(p.netId) then
                local e = NetworkGetEntityFromNetworkId(p.netId)
                if e and e ~= 0 and DoesEntityExist(e) and not TaserShield[e] then
                    TaserShield[e] = true
                    SetProtect(e, 'taser', true)
                end
            end
        end
    else
        for e in pairs(TaserShield) do
            SetProtect(e, 'taser', false)
        end
        TaserShield = {}
    end
end

-- Cible visée. La visée libre donne l'entité directement ; à défaut on
local function TaserTarget()
    local ok, ent = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if ok and ent and ent ~= 0 and DoesEntityExist(ent) then return ent end

    local cam  = GetGameplayCamCoord()
    local rot  = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local f = math.abs(math.cos(rx))
    local dir = vector3(-math.sin(rz) * f, math.cos(rz) * f, math.sin(rx))

    local okS, hit = pcall(function()
        local h = StartExpensiveSynchronousShapeTestLosProbe(
            cam.x, cam.y, cam.z,
            cam.x + dir.x * 40.0, cam.y + dir.y * 40.0, cam.z + dir.z * 40.0,
            12, PlayerPedId(), 4)
        local _, didHit, _, _, entity = GetShapeTestResult(h)
        if didHit == 1 or didHit == true then return entity end
        return nil
    end)
    if okS and hit and hit ~= 0 and DoesEntityExist(hit) then return hit end
    return nil
end

CreateThread(function()
    local shielded, shooting = false, false
    while true do
        local holding = false

        if Callout then
            local me = PlayerPedId()
            local wname, cfg = NonLethalFor(GetSelectedPedWeapon(me))
            holding = (wname == 'WEAPON_STUNGUN')

            if holding ~= shielded then
                shielded = holding
                SetTaserShield(shielded)
            elseif holding then
                -- Rafraîchissement continu : le bouclier n'était posé
                SetTaserShield(true)
            end

            if holding then
                if IsPedShooting(me) then
                    -- Un seul déclenchement par tir, pas un par frame.
                    if not shooting then
                        shooting = true
                        local ent = TaserTarget()
                        if ent then
                            local p = PedFromEntity(ent)
                            if p and p.role ~= 'caller' and p.role ~= 'deceased'
                               and p.state ~= 'cuffed' and p.state ~= 'delivered'
                               and p.state ~= 'dead' and p.state ~= 'stunned' then
                                KnockDown(p, ent, (cfg and cfg.duration) or 6)
                            end
                        end
                    end
                else
                    shooting = false
                end
            end
        elseif shielded then
            shielded = false
            SetTaserShield(false)
        end

        Wait(holding and 0 or 400)
    end
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    if not Callout then return end

    local victim  = args[1]
    local attacker = args[2]
    if not victim or not DoesEntityExist(victim) then return end
    if attacker ~= PlayerPedId() then return end

    local p, netId = PedFromEntity(victim)
    if not p or p.role == 'caller' or p.role == 'deceased' then return end

    local weaponHash = GetSelectedPedWeapon(PlayerPedId())
    local wname, cfg = NonLethalFor(weaponHash)
    if not wname then return end

    -- Le taser est géré par le thread dédié ci-dessus, pas ici : la
    if wname == 'WEAPON_STUNGUN' then return end

    -- Plancher de PV : impossible de tuer sous les coups ou au taser
    if GetEntityHealth(victim) < C.NonLethalHealthFloor then
        SetEntityHealth(victim, C.NonLethalHealthFloor)
    end
    ClearPedBloodDamage(victim)

    local now = GetGameTimer()
    MeleeHits[netId] = MeleeHits[netId] or { count = 0, last = 0 }
    local mh = MeleeHits[netId]
    if (now - mh.last) > (C.MeleeHitResetDelay * 1000) then mh.count = 0 end
    mh.last  = now
    mh.count = mh.count + 1

    if mh.count >= (cfg.hits or 1) then
        mh.count = 0
        KnockDown(p, victim, cfg.duration or 6)
    end
end)

-- Fait descendre un PNJ d'un véhicule, de façon fiable.
local function UnloadFromVehicle(occupant, veh)
    if not occupant or not DoesEntityExist(occupant) then return false end
    RequestControl(occupant)
    ClearPedTasks(occupant)
    TaskLeaveVehicle(occupant, veh, 0)

    CreateThread(function()
        local t = 0
        while t < 30 do
            Wait(100) t = t + 1
            if not DoesEntityExist(occupant) then return end
            if not IsPedInAnyVehicle(occupant, false) then return end
        end
        -- Toujours dedans après trois secondes : on l'extrait de force.
        if DoesEntityExist(occupant) and IsPedInAnyVehicle(occupant, false) then
            RequestControl(occupant)
            ClearPedTasksImmediately(occupant)
            if DoesEntityExist(veh) then
                local c = GetOffsetFromEntityInWorldCoords(veh, -2.2, 0.0, 0.0)
                SetEntityCoordsNoOffset(occupant, c.x, c.y, c.z, false, false, false)
            end
        end
    end)
    return true
end

--  INTERACTIONS OX_TARGET SUR LES PNJ DE MISSION

local function TargetPed(entity, roles, predicate)
    if not IsOnDuty() or not EngagedOnCallout() then return false end
    local p = PedFromEntity(entity)
    if not p then return false end
    if roles and not roles[p.role] then return false end

    -- Un mort ne se menotte pas, ne se fouille pas, ne répond pas.
    if p.state == 'dead' and not (roles and roles.dead) then return false end

    if predicate and not predicate(p) then return false end
    return true
end

-- Levée de corps

local BodyBags = {}   -- props créés, retirés au nettoyage

function BagBody(entity, p)
    if not entity or not DoesEntityExist(entity) then return end

    -- Quand les secours sont dépêchés, ce sont EUX qui emportent le
    if (C.Ambulance or {}).Enabled then
        Notify('Décès constaté. Les secours sont prévenus pour la levée de corps.',
            'success')
        return
    end

    -- Premier prop valide de la liste : les builds n'embarquent pas
    local hash = nil
    for _, name in ipairs(C.BodyBagProps or {}) do
        local h = GetHashKey(name)
        if IsModelInCdimage(h) and IsModelValid(h) then
            hash = LoadModel(name)
            if hash then break end
        end
    end

    Notify('Levée de corps en cours…', 'info')
    PlayAnimFor('amb@medic@standing@kneel@base', 'base', C.BodyBagDuration)

    if not DoesEntityExist(entity) then return end
    local c = GetEntityCoords(entity)
    local h = GetEntityHeading(entity)

    -- Le corps disparaît immédiatement en local — l'agent voit le
    SetEntityVisible(entity, false, false)
    SetEntityCollision(entity, false, false)

    if hash then
        local bag = CreateObject(hash, c.x, c.y, c.z - 0.9, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        if bag and bag ~= 0 then
            SetEntityHeading(bag, h)
            PlaceObjectOnGroundProperly(bag)
            FreezeEntityPosition(bag, true)
            BodyBags[#BodyBags + 1] = bag
        end
        Notify('Corps placé sous housse. Levée de corps effectuée.', 'success')
    else
        -- Aucune housse sur cette build : le corps est évacué quand même.
        Notify('Corps évacué. Levée de corps effectuée.', 'success')
    end
end

local function ClearBodyBags()
    for _, o in ipairs(BodyBags) do
        if DoesEntityExist(o) then DeleteEntity(o) end
    end
    BodyBags = {}
end

-- Véhicules de service

local PoliceVehicleHashes = nil

local function BuildPoliceVehicleSet()
    PoliceVehicleHashes = {}
    -- Déduit de la liste du garage police, toutes catégories confondues
    for _, category in pairs(Config.Police.Vehicles or {}) do
        if type(category) == 'table' then
            for _, v in ipairs(category) do
                if v and v.model then
                    PoliceVehicleHashes[GetHashKey(v.model)] = true
                end
            end
        end
    end
    for _, model in ipairs(C.ExtraPoliceVehicles or {}) do
        PoliceVehicleHashes[GetHashKey(model)] = true
    end
end

local function IsPoliceVehicle(veh)
    if not veh or veh == 0 then return false end
    if not DoesEntityExist(veh) then return false end
    -- ox_target interroge parfois une entité qui n'est plus un véhicule
    if not IsEntityAVehicle(veh) then return false end
    if not PoliceVehicleHashes then BuildPoliceVehicleSet() end

    -- GetEntityModel plante sur une entité en cours de destruction :
    local ok, model = pcall(GetEntityModel, veh)
    if not ok or not model then return false end
    return PoliceVehicleHashes[model] == true
end

-- Première place ARRIÈRE libre d'un véhicule (droite, puis gauche).
function FreeRearSeat(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local maxPass = GetVehicleMaxNumberOfPassengers(veh)
    for _, seat in ipairs(C.TransportSeats) do
        if maxPass >= (seat + 1) and IsVehicleSeatFree(veh, seat) then
            return seat
        end
    end
    return nil
end

-- Véhicule de police le plus proche du joueur, dans le rayon configuré.
local function NearestPoliceVehicle()
    local me = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, C.TransportSearchRange

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if IsPoliceVehicle(veh) and FreeRearSeat(veh) then
            local d = #(GetEntityCoords(veh) - me)
            if d < bestDist then best, bestDist = veh, d end
        end
    end
    return best
end

-- Accompagnement d'une personne à protéger (pas un suspect)

Escorting = nil   -- entité actuellement accompagnée

function StartEscort(entity, p)
    if Escorting then return end
    Escorting = entity
    ClearPedTasksImmediately(entity)
    SetBlockingOfNonTemporaryEvents(entity, true)
    -- Un individu menotté garde la posture pendant le trajet
    if p and p.state == 'cuffed' and LoadAnim('mp_arresting') then
        TaskPlayAnim(entity, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0,
            false, false, false)
    end
    AttachEntityToEntity(entity, PlayerPedId(), 11816, 0.34, 0.44, 0.0,
        0.0, 0.0, 0.0, false, false, false, false, 2, true)
    Notify('Vous accompagnez ' .. (p.label or 'la personne') .. '.', 'info')
end

function StopEscort()
    if not Escorting then return end
    local e = Escorting
    Escorting = nil
    if DoesEntityExist(e) then
        DetachEntity(e, true, false)
        ClearPedTasks(e)
        TaskStandStill(e, -1)
    end
end

-- Sécurité : on lâche automatiquement si la personne monte en véhicule,
CreateThread(function()
    while true do
        Wait(1000)
        if Escorting then
            if not DoesEntityExist(Escorting) or not Callout
               or IsPedInAnyVehicle(Escorting, false) then
                StopEscort()
            end
        end
    end
end)

exports.ox_target:addGlobalPed({
    {
        name = 'callout_statement', icon = 'fa-solid fa-comments',
        label = 'Recueillir le témoignage', distance = 2.5,
        -- Le requérant se recueille comme partout ailleurs ; sur une
        canInteract = function(e)
            return TargetPed(e, { caller = true, bystander = true }, function(p)
                return p.role == 'caller' or p.witness == true
            end)
        end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            if not p then return end
            -- Le PNJ range son téléphone et se tourne vers l'agent avant
            StopSceneAmbience(p.netId, data.entity, PlayerPedId())
            PlayAnimFor('amb@world_human_cop_idles@male@idle_a', 'idle_b', 3000)
            -- Le témoignage ne CLÔT la mission que sur une constatation de
            SendQ('police:callouts:objectiveDone', { kind = 'statement', netId = p.netId })
            TriggerEvent('police:callouts:witnessStatement', p)
        end,
    },
    {
        name = 'callout_identify', icon = 'fa-solid fa-id-card',
        label = 'Contrôler l\'identité', distance = 2.0,
        canInteract = function(e)
            -- Une victime se laisse toujours identifier ; un mis en cause
            return TargetPed(e, { suspect = true, victim = true }, function(p)
                if p.identified then return false end
                if p.role == 'victim' then return true end
                return p.state == 'cuffed' or p.state == 'stunned'
                    or p.behavior == 'passive'
            end)
        end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            if not p then return end
            StopSceneAmbience(p.netId, data.entity, PlayerPedId())
            PlayAnimFor('amb@world_human_cop_idles@male@idle_a', 'idle_b', 2500)
            SendQ('police:callouts:suspectIdentify', { netId = p.netId })
        end,
    },
    {
        -- Personne armée uniquement (cf. sc.weaponPermit) : le permis
        name = 'callout_weapon_permit', icon = 'fa-solid fa-file-shield',
        label = 'Contrôler le permis de port d\'arme', distance = 2.0,
        canInteract = function(e)
            return TargetPed(e, { suspect = true }, function(p)
                return p.permitValid ~= nil
            end)
        end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            if not p then return end
            StopSceneAmbience(p.netId, data.entity, PlayerPedId())
            PlayAnimFor('amb@world_human_cop_idles@male@idle_a', 'idle_b', 2500)
            if p.permitValid then
                Notify('Permis de port d\'arme valide.', 'success')
            else
                Notify('Aucun permis valide présenté.', 'error')
            end
        end,
    },
    {
        name = 'callout_move_along', icon = 'fa-solid fa-person-walking-arrow-right',
        label = 'Laisser repartir', distance = 2.0,
        canInteract = function(e)
            -- Disponible sur tous les scénarios, sauf refus explicite.
            if not Callout or not Callout.moveAlong then return false end
            return TargetPed(e, { suspect = true }, function(p)
                if p.weapon then return false end
                return p.behavior == 'passive' and p.state == 'idle'
            end)
        end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            if not p then return end
            PlayAnimFor('amb@world_human_cop_idles@male@idle_a', 'idle_b', 2000)
            SendQ('police:callouts:moveAlong', { netId = p.netId })
        end,
    },
    {
        name = 'callout_cuff', icon = 'fa-solid fa-handcuffs',
        label = 'Menotter', distance = 2.0,
        canInteract = function(e)
            return TargetPed(e, { suspect = true, wanderer = true }, function(p)
                return p.state ~= 'cuffed' and p.state ~= 'delivered'
                    and (p.state == 'stunned' or p.behavior == 'passive')
            end)
        end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            if not p then return end
            local dict = 'mp_arresting'
            if LoadAnim(dict) then
                TaskPlayAnim(PlayerPedId(), dict, 'a_uncuff', 8.0, -8.0,
                    Config.Police.Actions.cuffDuration, 49, 0, false, false, false)
            end
            Wait(Config.Police.Actions.cuffDuration)
            ClearPedTasks(PlayerPedId())
            SendQ('police:callouts:suspectCuffed', { netId = p.netId })
        end,
    },
    {
        name = 'callout_victim_statement', icon = 'fa-solid fa-comments',
        label = 'Recueillir son témoignage', distance = 2.0,
        canInteract = function(e)
            return TargetPed(e, { victim = true }, function(p)
                return not p.interrogated
            end)
        end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            if not p then return end
            -- Pas de StopSceneAmbience ici : une victime au sol garde sa
            PlayAnimFor('amb@world_human_cop_idles@male@idle_a', 'idle_b', 3000)
            SendQ('police:callouts:victimStatement', { netId = p.netId })
        end,
    },
    {
        name = 'callout_interrogate', icon = 'fa-solid fa-comment-dots',
        label = 'Entendre l\'individu sur les faits', distance = 2.0,
        canInteract = function(e)
            if not Callout or not Callout.canInterrogate then return false end
            return TargetPed(e, { suspect = true }, function(p)
                if p.interrogated then return false end
                if p.behavior ~= 'passive' then return false end
                return p.state == 'idle' or p.state == 'cuffed'
                    or p.state == 'stunned'
            end)
        end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            if not p then return end
            StopSceneAmbience(p.netId, data.entity, PlayerPedId())
            PlayAnimFor('amb@world_human_cop_idles@male@idle_a', 'idle_b', 3000)
            SendQ('police:callouts:interrogate', { netId = p.netId })
        end,
    },
    {
        name = 'callout_search', icon = 'fa-solid fa-hands',
        label = 'Fouiller', distance = 2.0,
        canInteract = function(e)
            -- Un suspect abattu garde son rôle `suspect` (seule une
            return TargetPed(e, { suspect = true, dead = true }, function(p)
                -- La fouille ne réclame plus le menottage : un individu
                if p.searched then return false end
                if p.state == 'dead' then return true end
                if p.state == 'cuffed' or p.state == 'stunned' then return true end
                if p.state ~= 'idle' then return false end
                return p.behavior == 'passive'
            end)
        end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            if not p then return end
            PlayAnimFor('amb@world_human_cop_idles@male@idle_a', 'idle_b',
                Config.Police.Actions.searchDuration)
            if p.state == 'dead' and DoesEntityExist(data.entity) then
                RemoveAllPedWeapons(data.entity, true)
            end
            SendQ('police:callouts:suspectSearched', { netId = p.netId })
        end,
    },
    {
        name = 'callout_pickup_weapon', icon = 'fa-solid fa-gun',
        label = 'Ramasser l\'arme', distance = 2.5,
        canInteract = function(e)
            return TargetPed(e, { suspect = true }, function(p) return p.droppedWeapon ~= nil end)
        end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            if not p then return end
            SendQ('police:callouts:pickupWeapon', { netId = p.netId })
        end,
    },
    {
        name = 'callout_escort', icon = 'fa-solid fa-hands-holding-child',
        label = 'Faire suivre', distance = 2.0,
        canInteract = function(e)
            -- Personne errante, mais aussi tout individu maîtrisé : sans
            return TargetPed(e, { wanderer = true, suspect = true }, function(p)
                if Escorting then return false end
                if p.state == 'delivered' then return false end
                if p.role == 'wanderer' then return true end
                return p.state == 'cuffed' or p.state == 'stunned'
            end)
        end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            if not p then return end
            StartEscort(data.entity, p)
        end,
    },
    {
        name = 'callout_unescort', icon = 'fa-solid fa-hand',
        label = 'Cesser de faire suivre', distance = 3.0,
        canInteract = function(e)
            return TargetPed(e, { wanderer = true, suspect = true },
                function() return Escorting ~= nil end)
        end,
        onSelect = function() StopEscort() end,
    },
    {
        name = 'callout_into_vehicle', icon = 'fa-solid fa-car-side',
        label = 'Embarquer à l\'arrière', distance = 2.5,
        canInteract = function(e)
            local ok = TargetPed(e, { suspect = true, wanderer = true }, function(p)
                -- La personne errante monte sans être menottée
                if p.role == 'wanderer' then return p.state ~= 'delivered' end
                return p.state == 'cuffed' or p.state == 'stunned'
            end)
            -- L'option ne s'affiche que si un véhicule de service est là
            return ok and NearestPoliceVehicle() ~= nil
        end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            if not p then return end
            local ped = data.entity

            local veh = NearestPoliceVehicle()
            if not veh then
                Notify('Aucun véhicule de service à proximité.', 'error')
                return
            end

            -- Places arrière uniquement : droite d'abord, puis gauche.
            local seat = FreeRearSeat(veh)
            if not seat then
                Notify('Les places arrière sont déjà occupées.', 'error')
                return
            end

            TaskEnterVehicle(ped, veh, 10000, seat, 1.5, 1, 0)
            -- Repli si la tâche échoue ou traîne (portière bloquée, etc.)
            SetTimeout(10500, function()
                if DoesEntityExist(ped) and DoesEntityExist(veh)
                   and not IsPedInVehicle(ped, veh, false) then
                    if IsVehicleSeatFree(veh, seat) then
                        SetPedIntoVehicle(ped, veh, seat)
                    end
                end
            end)
        end,
    },
    {
        name = 'callout_out_vehicle', icon = 'fa-solid fa-person-walking',
        label = 'Faire sortir du véhicule', distance = 3.5,
        canInteract = function(e)
            return TargetPed(e, { suspect = true, wanderer = true }, function(p)
                local ent = NetworkDoesNetworkIdExist(p.netId)
                    and NetworkGetEntityFromNetworkId(p.netId) or nil
                return ent and ent ~= 0 and IsPedInAnyVehicle(ent, false)
            end)
        end,
        onSelect = function(data)
            UnloadFromVehicle(data.entity, GetVehiclePedIsIn(data.entity, false))
        end,
    },
    {
        name = 'callout_first_aid', icon = 'fa-solid fa-kit-medical',
        label = 'Prodiguer les premiers soins', distance = 2.0,
        canInteract = function(e)
            return TargetPed(e, { victim = true }, function(p) return p.state ~= 'healed' end)
        end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            if not p then return end
            -- On ne touche PAS à la posture du blessé ici : l'arrêt de
            PlayAnimFor('amb@medic@standing@kneel@base', 'base', C.FirstAidDuration)
            SendQ('police:callouts:firstAid', { netId = p.netId })
        end,
    },
    {
        name = 'callout_constat', icon = 'fa-solid fa-clipboard-check',
        label = 'Constater le décès', distance = 2.0,
        canInteract = function(e)
            -- Tout corps se constate, quel que soit le rôle qu'occupait
            return TargetPed(e, {
                deceased = true, suspect = true, victim = true,
                wanderer = true, dead = true,
            }, function(p)
                if p.constated then return false end
                return p.role == 'deceased' or p.state == 'dead'
            end)
        end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            PlayAnimFor('amb@medic@standing@kneel@base', 'base', 5000)
            SendQ('police:callouts:objectiveDone',
                { kind = 'death', netId = p and p.netId or nil })
            if p then BagBody(data.entity, p) end
        end,
    },
    {
        name = 'callout_ask_radio', icon = 'fa-solid fa-volume-xmark',
        label = 'Demander de couper la musique', distance = 2.5,
        canInteract = function(e)
            if not Callout or Callout.objective ~= 'radio' then return false end
            if Callout.radioOff then return false end
            return TargetPed(e, { suspect = true })
        end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            if not p then return end
            SendQ('police:callouts:askRadioOff', { netId = p.netId })
        end,
    },
    {
        name = 'callout_animal_dead', icon = 'fa-solid fa-clipboard-check',
        label = 'Constater la mort de l\'animal', distance = 2.5,
        canInteract = function(e)
            -- `dead = true` est indispensable : TargetPed bloque par
            return TargetPed(e, { animal = true, dead = true }, function(p)
                return p.state == 'dead'
            end)
        end,
        onSelect = function()
            PlayAnimFor('amb@medic@standing@kneel@base', 'base', 4000)
            SendQ('police:callouts:objectiveDone', { kind = 'animal' })
        end,
    },
    {
        name = 'callout_dismiss', icon = 'fa-solid fa-hand',
        label = 'Faire circuler', distance = 3.0,
        canInteract = function(e) return TargetPed(e, { bystander = true }) end,
        onSelect = function(data)
            local p = PedFromEntity(data.entity)
            if not p then return end
            TaskWanderStandard(data.entity, 10.0, 10)
            SendQ('police:callouts:dismissBystander', { netId = p.netId })
        end,
    },
})

--  EMBARQUEMENT DEPUIS LE VÉHICULE

-- Personne actuellement transportable : celle qu'on escorte, sinon le
local function PersonToLoad()
    if not Callout then return nil end

    if Escorting and DoesEntityExist(Escorting) then
        local p = PedFromEntity(Escorting)
        if p then return Escorting, p end
    end

    local me = GetEntityCoords(PlayerPedId())
    local bestEnt, bestData, bestDist = nil, nil, 5.0
    for _, p in ipairs(Callout.peds or {}) do
        local ok = (p.role == 'wanderer' and p.state ~= 'delivered')
            or ((p.role == 'suspect') and (p.state == 'cuffed' or p.state == 'stunned'))
        if ok and NetworkDoesNetworkIdExist(p.netId) then
            local e = NetworkGetEntityFromNetworkId(p.netId)
            if e and e ~= 0 and DoesEntityExist(e) and not IsPedInAnyVehicle(e, false) then
                local d = #(GetEntityCoords(e) - me)
                if d < bestDist then bestEnt, bestData, bestDist = e, p, d end
            end
        end
    end
    return bestEnt, bestData
end

local function LoadIntoVehicle(veh, ped, p)
    local seat = FreeRearSeat(veh)
    if not seat then
        Notify('Les places arrière sont déjà occupées.', 'error')
        return
    end

    StopEscort()
    TaskEnterVehicle(ped, veh, 10000, seat, 1.5, 1, 0)
    Notify((p.label or 'L\'individu') .. ' embarque à l\'arrière.', 'success')

    SetTimeout(10500, function()
        if DoesEntityExist(ped) and DoesEntityExist(veh)
           and not IsPedInVehicle(ped, veh, false) then
            if IsVehicleSeatFree(veh, seat) then
                SetPedIntoVehicle(ped, veh, seat)
            end
        end
    end)
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'callout_load_vehicle', icon = 'fa-solid fa-car-side',
        label = 'Installer la personne à l\'arrière', distance = 3.5,
        canInteract = function(entity)
            if not IsOnDuty() or not EngagedOnCallout() then return false end
            if not IsPoliceVehicle(entity) then return false end
            if not FreeRearSeat(entity) then return false end
            return PersonToLoad() ~= nil
        end,
        onSelect = function(data)
            local ped, p = PersonToLoad()
            if not ped or not p then
                Notify('Personne à installer à proximité.', 'error')
                return
            end
            LoadIntoVehicle(data.entity, ped, p)
        end,
    },
    {
        name = 'callout_unload_vehicle', icon = 'fa-solid fa-person-walking',
        label = 'Faire sortir la personne', distance = 3.5,
        canInteract = function(entity)
            if not IsOnDuty() or not EngagedOnCallout() then return false end
            if not IsPoliceVehicle(entity) then return false end
            for _, seat in ipairs(C.TransportSeats) do
                local occupant = GetPedInVehicleSeat(entity, seat)
                if occupant and occupant ~= 0 and PedFromEntity(occupant) then return true end
            end
            return false
        end,
        onSelect = function(data)
            for _, seat in ipairs(C.TransportSeats) do
                local occupant = GetPedInVehicleSeat(data.entity, seat)
                if occupant and occupant ~= 0 and PedFromEntity(occupant) then
                    UnloadFromVehicle(occupant, data.entity)
                    return
                end
            end
        end,
    },
})

-- Anna, Mike, Jessie : entités locales, ciblage par entité
CreateThread(function()
    while true do
        Wait(2000)
        if StaticPeds['register'] and DoesEntityExist(StaticPeds['register'])
           and not StaticPeds['register_targeted'] then
            exports.ox_target:addLocalEntity(StaticPeds['register'], {
                {
                    name = 'callout_register', icon = 'fa-solid fa-clipboard-list',
                    label = 'Mission Police Secours', distance = 2.0,
                    canInteract = function() return IsOnDuty() end,
                    onSelect = function()
                        if Registered then
                            -- Déjà inscrit : la même interaction fait sortir
                            SendQ('police:callouts:register', {})
                        else
                            SendQ('police:callouts:askCrews', {})
                        end
                    end,
                },
            })
            StaticPeds['register_targeted'] = true
        end
    end
end)

local function AttachCustodyTarget(key, label, isHospital)
    local ped = StaticPeds[key]
    if not ped or not DoesEntityExist(ped) then return end
    -- Déjà équipé pour cette entité : ne pas réenregistrer l'option
    if TargetedStatics[key] == ped then return end
    TargetedStatics[key] = ped

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'callout_deliver_' .. key, icon = 'fa-solid fa-building-shield',
            label = label, distance = 3.0,
            canInteract = function() return IsOnDuty() and EngagedOnCallout() end,
            onSelect = function()
                if not Callout then return end
                -- Liste des individus présentables à proximité
                local options = {}
                local npcCoords = C.Npcs[key].coords
                for _, p in ipairs(Callout.peds or {}) do
                    local wanted = isHospital and (p.role == 'wanderer') or (p.role == 'suspect')
                    local okState = isHospital or (p.state == 'cuffed')
                    if wanted and okState and NetworkDoesNetworkIdExist(p.netId) then
                        local e = NetworkGetEntityFromNetworkId(p.netId)
                        if e and e ~= 0 and DoesEntityExist(e)
                           and #(GetEntityCoords(e) - npcCoords) <= C.CustodyRadius then
                            options[#options + 1] = {
                                title = p.label,
                                description = p.weapon and 'Porte encore une arme !' or 'Fouillé(e)',
                                icon = 'user-lock',
                                onSelect = function()
                                    SendQ('police:callouts:suspectDelivered',
                                        { netId = p.netId })
                                end,
                            }
                        end
                    end
                end
                if #options == 0 then
                    Notify('Aucun individu à présenter à proximité.', 'error')
                    return
                end
                lib.registerContext({ id = 'callout_deliver', title = label, options = options })
                lib.showContext('callout_deliver')
            end,
        },
    })
end

-- Le véhicule-sono du tapage
CreateThread(function()
    while true do
        Wait(2000)
        if StaticPeds['register'] and DoesEntityExist(StaticPeds['register'])
           and not StaticPeds['register_targeted'] then
            exports.ox_target:addLocalEntity(StaticPeds['register'], {
                {
                    name = 'callout_register', icon = 'fa-solid fa-clipboard-list',
                    label = 'Mission Police Secours', distance = 2.0,
                    canInteract = function() return IsOnDuty() end,
                    onSelect = function()
                        if Registered then
                            -- Déjà inscrit : la même interaction fait sortir
                            SendQ('police:callouts:register', {})
                        else
                            SendQ('police:callouts:askCrews', {})
                        end
                    end,
                },
            })
            StaticPeds['register_targeted'] = true
        end
    end
end)

--  SIGNALEMENT DU REQUÉRANT (faillible)

-- Le signalement est construit UNE SEULE FOIS par le serveur à la
AddEventHandler('police:callouts:witnessStatement', function(caller)
    if not Callout then return end

    local who = caller.label or 'Le requérant'

    -- Témoin nommé (tuerie de masse) : sa PROPRE déposition, distincte
    local lines = (caller.witness and caller.statementLines) or Callout.statementLines
    local text  = Callout.statement

    if not text or text == '' then
        text = 'Je n\'ai pas vu grand-chose, désolé.'
    end

    -- Pas de fenêtre à fermer : elle prenait le focus et interrompait
    local first = (lines and lines[1]) or text
    local more  = lines and #lines > 1

    Notify(who .. ' : « ' .. first .. ' »' ..
        (more and '\nSignalement complet dans la fiche d\'intervention.' or ''),
        'info')
end)

--  HUD D'INTERVENTION — HAUT GAUCHE, NON BLOQUANT

local Prompt = nil   -- invite Y/N en cours

local HUD_X   = 0.010   -- marge gauche
local HUD_Y   = 0.018   -- marge haute
local HUD_W   = 0.380   -- largeur du panneau
local HUD_LH  = 0.026   -- hauteur d'une ligne
local HUD_WRAP = 52     -- caractères VISIBLES tenant sur une ligne

-- Longueur en CARACTÈRES et non en octets. Sans ça, chaque accent
local function ULen(str)
    if utf8 and utf8.len then
        local ok, n = pcall(utf8.len, str)
        if ok and n then return n end
    end
    return #str
end

-- Découpe une ligne en segments qui tiennent dans la largeur du panneau.
local function WrapLine(text, width)
    local out = {}
    if not text or text == '' then return { '' } end
    if ULen(text) <= width then return { text } end

    local chunk = ''
    for word in string.gmatch(text, '%S+') do
        local candidate = (chunk == '') and word or (chunk .. ' ' .. word)
        if ULen(candidate) > width and chunk ~= '' then
            out[#out + 1] = chunk
            chunk = word
        else
            chunk = candidate
        end
    end
    if chunk ~= '' then out[#out + 1] = chunk end
    return out
end

-- AddTextComponentString tronque au-delà de ~99 octets : les phrases
local function AddLongText(text)
    local LIMIT = 90
    if #text <= LIMIT then
        AddTextComponentSubstringPlayerName(text)
        return
    end

    local chunk = ''
    for word in string.gmatch(text, '%S+') do
        if #chunk + #word + 1 > LIMIT then
            AddTextComponentSubstringPlayerName(chunk)
            chunk = word
        else
            chunk = (chunk == '') and word or (chunk .. ' ' .. word)
        end
    end
    if chunk ~= '' then AddTextComponentSubstringPlayerName(chunk) end
end

local function HudLine(y, text, scale, r, g, b, a)
    SetTextFont(4)
    SetTextScale(scale, scale)
    -- Le retour à la ligne est confié au jeu : aucun texte ne déborde
    SetTextWrap(HUD_X + 0.010, HUD_X + HUD_W - 0.010)
    SetTextColour(r, g, b, a)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 205)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry('STRING')
    AddLongText(text)
    DrawText(HUD_X + 0.010, y)
end

-- Construit les lignes du panneau selon l'état courant.
local function BuildHudLines()
    local lines = {}

    if Prompt then
        local left = math.max(0, math.ceil((Prompt.expiresAt - GetGameTimer()) / 1000))
        lines[#lines + 1] = { t = '~y~APPEL RADIO~s~  (' .. left .. 's)', s = 0.34 }
        lines[#lines + 1] = { t = '~w~' .. (Prompt.title or ''), s = 0.30 }
        for _, l in ipairs(Prompt.body or {}) do
            lines[#lines + 1] = { t = '~w~' .. l, s = 0.27 }
        end
        lines[#lines + 1] = { t = '~g~[Y]~s~ Prendre    ~r~[N]~s~ Refuser', s = 0.29 }
        return lines
    end

    if not Callout then return nil end

    -- Panneau permanent pendant l'intervention
    lines[#lines + 1] = { t = '~b~INTERVENTION~s~' ..
        (MyCrewLbl and ('  ~c~' .. MyCrewLbl) or ''), s = 0.33 }
    lines[#lines + 1] = { t = '~w~' .. (Callout.label or 'Appel'), s = 0.30 }
    lines[#lines + 1] = { t = '~c~' .. (Callout.street or Callout.zoneLabel or ''), s = 0.27 }

    -- Objectif ou décompte des individus
    local obj = Callout.objective
    if Callout.falseAlarm then
        lines[#lines + 1] = { t = '~y~Interroger le requérant', s = 0.28 }
    elseif obj == 'statement' then
        lines[#lines + 1] = { t = '~y~Prendre la déposition', s = 0.28 }
    elseif obj == 'death' and Callout.massIncident then
        -- Tuerie de masse : trois fronts distincts, chacun avec son
        local pending, cuffed, killed = 0, 0, 0
        for _, p in ipairs(Callout.peds or {}) do
            if p.role == 'suspect' then
                if p.state == 'dead' then killed = killed + 1
                elseif p.state == 'cuffed' or p.state == 'stunned'
                    or p.state == 'delivered' then cuffed = cuffed + 1
                elseif p.state ~= 'escaped' then pending = pending + 1 end
            end
        end
        if pending > 0 then
            lines[#lines + 1] = { t = ('~y~%d individu(s) à neutraliser'):format(pending), s = 0.28 }
        end
        if killed > 0 or cuffed > 0 then
            lines[#lines + 1] = { t = ('~g~%d tué(s)~s~  ·  ~g~%d capturé(s)'):format(killed, cuffed), s = 0.27 }
        end

        local deadLeft = math.max(0, (Callout.deadTotal or 0) - (Callout.deadConstated or 0))
        local aidLeft  = math.max(0, (Callout.aidTotal or 0) - (Callout.aidGiven or 0))
        if aidLeft > 0 then
            lines[#lines + 1] = { t = ('~r~%d blessé(s) à soigner'):format(aidLeft), s = 0.28 }
        end
        if deadLeft > 0 then
            lines[#lines + 1] = { t = ('~r~%d corps à constater'):format(deadLeft), s = 0.28 }
        end
        if pending == 0 and aidLeft == 0 and deadLeft == 0 then
            lines[#lines + 1] = { t = '~g~Scène sécurisée', s = 0.28 }
        end

    elseif obj == 'death' then
        lines[#lines + 1] = { t = '~y~Constater le décès', s = 0.28 }
    elseif obj == 'hospital' then
        lines[#lines + 1] = { t = '~y~Conduire la personne à l\'hôpital', s = 0.28 }
    elseif obj == 'radio' then
        lines[#lines + 1] = { t = '~y~Faire cesser la nuisance sonore', s = 0.28 }
    elseif obj == 'animal' then
        lines[#lines + 1] = { t = '~y~Neutraliser l\'animal puis constater sa mort', s = 0.28 }
        -- Le maître répond de la divagation : l'objectif animalier ne
        if Callout.requireSuspects then
            local pending, cuffed = 0, 0
            for _, p in ipairs(Callout.peds or {}) do
                if p.role == 'suspect' then
                    if p.state == 'cuffed' or p.state == 'stunned' then
                        cuffed = cuffed + 1
                    elseif p.state ~= 'delivered' and p.state ~= 'dead'
                       and p.state ~= 'escaped' then pending = pending + 1 end
                end
            end
            lines[#lines + 1] = { t = ('~y~%d maître à interpeller~s~  ·  ~g~%d maîtrisé(s)')
                :format(pending, cuffed), s = 0.28 }
        end
    else
        local pending, cuffed = 0, 0
        for _, p in ipairs(Callout.peds or {}) do
            if p.role == 'suspect' then
                if p.state == 'cuffed' or p.state == 'stunned' then cuffed = cuffed + 1
                elseif p.state ~= 'delivered' and p.state ~= 'dead'
                   and p.state ~= 'escaped' then pending = pending + 1 end
            end
        end
        lines[#lines + 1] = { t = ('~y~%d à interpeller~s~  ·  ~g~%d maîtrisé(s)'):format(
            pending, cuffed), s = 0.28 }
    end

    -- Rappel du raccourci : sans lui, personne ne sait que les renforts
    lines[#lines + 1] = { t = ('~c~Renforts : ~w~%s'):format(C.BackupKey or 'H'),
        s = 0.26 }

    -- Décès survenu en cours d'intervention : tant qu'il n'est pas
    if Callout.extraDeath and not Callout.deathConstated then
        lines[#lines + 1] = { t = '~r~Constater le décès de la victime', s = 0.28 }
    end

    -- Signalement du requérant : une fois recueilli, il reste affiché
    if Callout.statementTaken and Callout.statementLines then
        lines[#lines + 1] = { t = '~c~── Déposition ──', s = 0.27 }
        for _, l in ipairs(Callout.statementLines) do
            lines[#lines + 1] = { t = '~w~' .. l, s = 0.27 }
        end
    end

    -- Témoins nommés (tuerie de masse) : chacun garde sa PROPRE
    for _, p in ipairs(Callout.peds or {}) do
        if p.witness and p.heard and p.statementLines then
            lines[#lines + 1] = { t = ('~c~── %s ──'):format(p.label or 'Témoin'), s = 0.27 }
            for _, l in ipairs(p.statementLines) do
                lines[#lines + 1] = { t = '~w~' .. l, s = 0.27 }
            end
        end
    end

    -- Déposition du mis en cause, une fois entendu.
    if Callout.ownerStatement then
        lines[#lines + 1] = { t = ('~c~── %s ──')
            :format(Callout.ownerLabel or 'Mis en cause'), s = 0.27 }
        lines[#lines + 1] = { t = '~w~' .. Callout.ownerStatement, s = 0.27 }
    end

    return lines
end

CreateThread(function()
    while true do
        local lines = BuildHudLines()
        if lines then
            Wait(0)
            -- Chaque ligne est pré-découpée à la largeur du panneau : la
            local rows = {}
            for _, l in ipairs(lines) do
                -- Les codes couleur (~y~, ~w~…) ne comptent pas dans la
                local prefix, body = l.t:match('^(~%a~)(.*)$')
                prefix = prefix or ''
                body   = body or l.t
                for i, seg in ipairs(WrapLine(body, HUD_WRAP)) do
                    -- La continuation garde la couleur de sa ligne :
                    rows[#rows + 1] = { t = prefix .. seg, s = l.s }
                end
            end

            local h = HUD_LH * #rows + 0.020
            DrawRect(HUD_X + HUD_W / 2, HUD_Y + h / 2, HUD_W, h, 0, 0, 0, 175)

            local y = HUD_Y + 0.008
            for _, r in ipairs(rows) do
                HudLine(y, r.t, r.s, 255, 255, 255, 235)
                y = y + HUD_LH
            end
        else
            Wait(300)
        end
    end
end)

local function ClearPrompt()
    if Prompt and Prompt.blip and DoesBlipExist(Prompt.blip) then
        RemoveBlip(Prompt.blip)
    end
    Prompt = nil
end

-- Découpe un texte en phrases : une longue annonce ne tient pas sur une
local function SplitSentences(text)
    local out = {}
    if not text or text == '' then return out end
    for part in string.gmatch(text, '[^%.!?]+[%.!?]?') do
        local t = part:match('^%s*(.-)%s*$')
        if t and t ~= '' then out[#out + 1] = t end
    end
    if #out == 0 then out[1] = text end
    return out
end

-- `duration` en secondes. Doit couvrir toute la durée pendant laquelle
local function ShowPrompt(title, body, coords, onAccept, onRefuse, duration, opts)
    ClearPrompt()

    local blip = nil
    if coords then
        blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 60)
        SetBlipColour(blip, 5)
        SetBlipScale(blip, 1.0)
        SetBlipAsShortRange(blip, false)
        SetBlipFlashes(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Appel — ' .. title)
        EndTextCommandSetBlipName(blip)
    end

    Prompt = {
        title     = title,
        body      = body,
        calloutId = opts and opts.calloutId or nil,
        onAccept  = onAccept,
        onRefuse  = onRefuse,
        expiresAt = GetGameTimer() + ((duration or C.PromptDuration) * 1000),
        blip      = blip,
    }
end

-- Saisie : raccourcis nommés

local function AcceptPrompt()
    if not Prompt then return end
    local accept = Prompt.onAccept
    ClearPrompt()
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    if accept then accept() end
end

local function RefusePrompt()
    if not Prompt then return end
    local refuse   = Prompt.onRefuse
    local title    = Prompt.title
    local refuseId = Prompt.calloutId
    ClearPrompt()

    -- Le serveur doit savoir : si tous les équipages libres refusent,
    if refuseId then
        SendQ('police:callouts:refuse', { id = refuseId })
    end
    PlaySoundFrontend(-1, 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    Notify('Appel refusé : ' .. (title or 'intervention') .. '.', 'info')
    if refuse then refuse() end
end

RegisterCommand('callout_accept', AcceptPrompt, false)
RegisterCommand('callout_refuse', RefusePrompt, false)

RegisterKeyMapping('callout_accept', 'Missions PNJ — prendre l\'appel',
    'keyboard', C.PromptAcceptKey or 'Y')
RegisterKeyMapping('callout_refuse', 'Missions PNJ — refuser l\'appel',
    'keyboard', C.PromptRefuseKey or 'N')

-- Expiration de l'invite
CreateThread(function()
    while true do
        Wait(250)
        if Prompt and GetGameTimer() > Prompt.expiresAt then
            local refuse = Prompt.onRefuse
            ClearPrompt()
            if refuse then refuse() end
        end
    end
end)

--  RÉCEPTION DES ÉVÉNEMENTS SERVEUR

LSLegacy.Events.Register('police:callouts:registerState', function(state, crewId, crewLabel)
    Registered = state == true
    MyCrew     = state and crewId or nil
    MyCrewLbl  = state and crewLabel or nil
    if not state then ClearPrompt() end
end)

LSLegacy.Events.Register('police:callouts:incoming', function(data)
    Incoming = data
    Notify(data.message, 'info')
    PlaySoundFrontend(-1, 'Menu_Accept', 'Phone_SoundSet_Default', true)

    local body = { data.zoneLabel or '' }
    for _, l in ipairs(SplitSentences(data.message)) do body[#body + 1] = l end

    ShowPrompt(
        data.label or 'Appel 17',
        body,
        data.coords,
        function()
            if Incoming and Incoming.id == data.id then
                SendQ('police:callouts:accept', { id = data.id })
            end
        end,
        nil,
        data.timeout or C.PromptDuration,
        { calloutId = data.id }
    )
end)

LSLegacy.Events.Register('police:callouts:cancelled', function(data)
    if Incoming and data and Incoming.id == data.id then Incoming = nil end
    ClearPrompt()
    if data and data.taken then return end
    Notify(C.Dispatch.unpicked, 'warning')
end)

LSLegacy.Events.Register('police:callouts:backupRequested', function(data)
    Notify(data.message, 'warning')
    PlaySoundFrontend(-1, 'Menu_Accept', 'Phone_SoundSet_Default', true)
    -- Un refus de renfort ne classe pas l'appel : l'équipage engagé
    ShowPrompt('Renfort demandé', SplitSentences(data.message), data.coords, function()
        SendQ('police:callouts:acceptBackup', { id = data.id })
    end, nil, C.BackupTimeout)
end)

--  MENU D'ADMINISTRATION (/missionpnjadmin)

local function AdminAction(action, value)
    SendQ('police:callouts:adminAction', { action = action, value = value })
end

LSLegacy.Events.Register('police:callouts:adminMenuData', function(data)
    if not data then return end

    -- Dès la première ouverture, la touche L rouvre le menu sans passer
    if not AdminMenuUsed then
        AdminMenuUsed = true
        print('^2[missionpnjadmin]^7 Menu ouvert — appuyez désormais sur ^2L^7 ' ..
            'pour le rouvrir sans repasser par la console.')
    end

    local options = {}

    -- État courant et bascules générales
    options[#options + 1] = {
        title = 'Missions PNJ : ' .. (data.enabled and 'ACTIVES' or 'SUSPENDUES'),
        description = 'Activer ou suspendre le déclenchement automatique',
        icon = data.enabled and 'toggle-on' or 'toggle-off',
        onSelect = function() AdminAction('toggleEnabled') end,
    }
    options[#options + 1] = {
        title = 'Mode test : ' .. (data.testMode
            and ('ACTIF (' .. (data.testStaff or '?') .. ' agents simulés)') or 'INACTIF'),
        description = data.testMode
            and 'Effectif simulé — cliquer pour désactiver'
            or 'Choisir un effectif simulé (2 à 12) puis activer',
        icon = 'flask',
        onSelect = function()
            -- Déjà actif : un clic désactive directement, pas besoin de
            if data.testMode then
                AdminAction('toggleTest', C.TestModeDefaultStaff)
                return
            end
            local staffOptions = {}
            for n = 2, 12 do
                staffOptions[#staffOptions + 1] = {
                    title = ('%d agents simulés'):format(n),
                    icon = 'users',
                    onSelect = function() AdminAction('toggleTest', n) end,
                }
            end
            lib.registerContext({
                id = 'callout_admin_test_staff',
                title = 'Effectif simulé (mode test)',
                menu = 'callout_admin',
                options = staffOptions,
            })
            lib.showContext('callout_admin_test_staff')
        end,
    }

    local actives = data.actives or {}
    options[#options + 1] = {
        title = ('Interventions : %d / %d'):format(#actives, data.maxActive or 1),
        description = ('%d équipage(s) occupé(s) — une intervention par équipage')
            :format(data.crews or 0),
        icon = 'list-check',
        disabled = true,
    }

    for _, a in ipairs(actives) do
        options[#options + 1] = {
            title = 'Clôturer #' .. a.id .. ' : ' .. a.label,
            description = (a.zone or '') .. ' — ' .. (a.state or '?') ..
                (a.crew and (' — équipage ' .. a.crew) or ' — non prise en charge'),
            icon = 'circle-xmark',
            onSelect = function() AdminAction('end', a.id) end,
        }
    end

    -- Nombre de scénarios par palier, pour l'entrée de tirage au sort.
    local tierCount = {}
    for _, sc in ipairs(data.scenarios or {}) do
        local t = sc.minAgents or 1
        tierCount[t] = (tierCount[t] or 0) + 1
    end

    -- Liste des scénarios, triés par palier
    local lastTier = nil
    for _, sc in ipairs(data.scenarios or {}) do
        if sc.minAgents ~= lastTier then
            lastTier = sc.minAgents
            local tier = sc.minAgents
            local n = tierCount[tier] or 0
            -- L'en-tête de palier n'est plus décoratif : elle lance une
            options[#options + 1] = {
                title = ('── Palier %d agent(s) ──'):format(tier),
                description = ('Lancer une mission au hasard parmi les %d du palier')
                    :format(n),
                icon = 'dice',
                disabled = (#actives >= (data.maxActive or 1)),
                onSelect = function() AdminAction('forceTier', tier) end,
            }
        end
        local hours = sc.hours
            and (sc.hours.from .. 'h → ' .. sc.hours.to .. 'h') or '24h/24'
        local full = #actives >= (data.maxActive or 1)
        options[#options + 1] = {
            title = sc.label,
            description = 'Horaires : ' .. hours .. '  ·  poids ' .. sc.weight ..
                (full and '  ·  plafond d\'interventions atteint' or ''),
            icon = 'play',
            disabled = full,
            onSelect = function() AdminAction('force', sc.id) end,
        }
    end

    lib.registerContext({
        id      = 'callout_admin',
        title   = 'Missions PNJ — Administration',
        options = options,
    })
    lib.showContext('callout_admin')
end)

--  CHOIX DE L'ÉQUIPAGE (Police Secours)

LSLegacy.Events.Register('police:callouts:crewState', function(data)
    if not data or not data.crews then return end

    local options = {}
    for _, c in ipairs(data.crews) do
        local full = c.count >= c.max
        options[#options + 1] = {
            title       = c.label,
            description = ('%d / %d agents%s'):format(c.count, c.max,
                full and ' — complet' or ''),
            icon        = full and 'user-slash' or 'users',
            disabled    = full,
            onSelect    = function()
                SendQ('police:callouts:register', { crew = c.id })
            end,
        }
    end

    lib.registerContext({
        id      = 'callout_crews',
        title   = 'Mission Police Secours',
        options = options,
    })
    lib.showContext('callout_crews')
end)

LSLegacy.Events.Register('police:callouts:sync', function(payload)
    -- On compare l'IDENTIFIANT de l'appel, pas le simple fait que
    local first = (Callout == nil) or (Callout.id ~= payload.id)
    if first and Callout then
        -- Ménage de la mission précédente restée en mémoire
        ClearCalloutBlips()
        StopAlarm()
        StopBoombox()
    end
    if first then
        BoomboxSilenced = false
        BoomboxTargeted = nil
    end

    Callout = payload
    Incoming = nil
    -- L'équipage est engagé d'un bloc : l'invite Y/N des coéquipiers
    ClearPrompt()

    if first then
        CreateCalloutBlips()
        SpawnStaticNpc('custody')
        AttachCustodyTarget('custody', 'Présenter l\'individu', false)
        if payload.hospitalNpc then
            SpawnStaticNpc('hospital')
            AttachCustodyTarget('hospital', 'Confier la personne à l\'hôpital', true)
        end
        if payload.sound == 'boombox' then StartBoombox() end
        if payload.sound == 'alarm' then StartAlarm() end
    end
    RefreshCuffedBlips()
    RefreshCallerBlip()
end)

LSLegacy.Events.Register('police:callouts:brainAssigned', function(id)
    if Callout and Callout.id == id then
        IsBrain = true
        BrainState = {}
    end
end)

-- Tapage : l'individu désigné se dirige vers la voiture, coupe la sono
LSLegacy.Events.Register('police:callouts:radioWalk', function(data)
    if not data or not data.netId or not Callout then return end

    CreateThread(function()
        -- Attente réelle des entités : au moment de la demande, le
        local ped = EntityFromNet(data.netId, 60)
        local veh = nil
        if Callout and Callout.boomboxNet then
            veh = EntityFromNet(Callout.boomboxNet, 60)
        end

        if not ped then
            Notify('L\'individu est introuvable.', 'error')
            return
        end

        RequestControl(ped)
        ClearPedTasks(ped)
        SetBlockingOfNonTemporaryEvents(ped, true)

        if veh then
            -- Déjà au volant : il coupe sans se déplacer.
            if IsPedInVehicle(ped, veh, false) then
                Notify('L\'individu coupe la sono.', 'info')
                Wait(1500)
            else
                Notify('L\'individu se dirige vers le véhicule.', 'info')
                local v = GetEntityCoords(veh)
                TaskFollowNavMeshToCoord(ped, v.x, v.y, v.z, 1.5, -1, 1.5, false, 0)

                local timeout = GetGameTimer() + 30000
                while GetGameTimer() < timeout do
                    Wait(300)
                    if not DoesEntityExist(ped) or not DoesEntityExist(veh) then break end
                    if LSLegacy.Validate.Distance(GetEntityCoords(ped), GetEntityCoords(veh), 2.5) then break end
                end

                if DoesEntityExist(ped) and DoesEntityExist(veh) then
                    TaskTurnPedToFaceEntity(ped, veh, 1200)
                    Wait(1200)
                    PlayAnimFor2(ped, 'anim@heists@ornate_bank@grab_cash', 'intro', 2200)
                end
            end

            StopBoombox()

            -- S'il était au volant, il descend une fois la sono coupée
            if DoesEntityExist(ped) and IsPedInVehicle(ped, veh, false) then
                TaskLeaveVehicle(ped, veh, 0)
                Wait(2000)
            end
        else
            StopBoombox()
        end

        if DoesEntityExist(ped) then
            TaskStandStill(ped, -1)
            Speak(ped, data.netId, 'greet')
        end

        Notify('« C\'est bon, je coupe. Ça ne se reproduira plus. »', 'success')
        SendQ('police:callouts:objectiveDone', { kind = 'radio' })
    end)
end)

-- Prise en charge hospitalière : la personne et l'infirmière entrent
LSLegacy.Events.Register('police:callouts:hospitalIntake', function(data)
    if not data or not data.netId then return end

    StopEscort()

    local cfg = C.Npcs.hospital
    local dest = cfg and cfg.walkTo
    if not dest then return end

    CreateThread(function()
        local person = EntityFromNet(data.netId, 20)
        local nurse  = StaticPeds['hospital']

        if person and DoesEntityExist(person) then
            DetachEntity(person, true, false)
            ClearPedTasks(person)
            SetBlockingOfNonTemporaryEvents(person, true)
            SetMoveRate(person, 0.8)
            TaskFollowNavMeshToCoord(person, dest.x, dest.y, dest.z, 1.0, -1, 1.0, false, 0)
        end

        if nurse and DoesEntityExist(nurse) then
            FreezeEntityPosition(nurse, false)
            ClearPedTasks(nurse)
            SetBlockingOfNonTemporaryEvents(nurse, true)
            TaskFollowNavMeshToCoord(nurse, dest.x, dest.y, dest.z, 1.0, -1, 1.0, false, 0)
        end

        Notify('La personne est prise en charge par le service hospitalier.', 'success')

        -- Une fois à l'entrée, les deux entrent : plus besoin d'eux.
        local timeout = GetGameTimer() + 60000
        while GetGameTimer() < timeout do
            Wait(1000)
            local arrived = false
            if person and DoesEntityExist(person) then
                if LSLegacy.Validate.Distance(GetEntityCoords(person), dest, 2.5) then arrived = true end
            else
                arrived = true
            end
            if arrived then break end
        end

        if person and DoesEntityExist(person) then SetEntityVisible(person, false, false) end
        if nurse and DoesEntityExist(nurse) then RemoveStaticNpc('hospital') end
    end)
end)

-- Fin de mission : les figurants s'en vont d'eux-mêmes plutôt que de
LSLegacy.Events.Register('police:callouts:releaseScene', function(list)
    for _, item in ipairs(list or {}) do
        -- Coupe toute boucle d'ambiance encore active pour ce PNJ.
        SceneStop[item.netId] = true
        if NetworkDoesNetworkIdExist(item.netId) then
            local e = NetworkGetEntityFromNetworkId(item.netId)
            if e and e ~= 0 and DoesEntityExist(e) then
                if item.role == 'deceased' then
                    -- Un corps ne repart pas : on le laisse en place.
                elseif item.stay then
                    -- Tapage : la fête est finie, mais personne ne
                    ClearPedTasks(e)
                    SetBlockingOfNonTemporaryEvents(e, true)
                    TaskStandStill(e, -1)
                elseif item.role == 'suspect' or item.role == 'animal' then
                    -- Les individus non résolus (laissés libres, mission
                    ClearPedTasks(e)
                    SetBlockingOfNonTemporaryEvents(e, false)
                    TaskWanderStandard(e, 10.0, 10)
                else
                    -- Requérant, témoins, badauds : ils vaquent
                    ClearPedTasks(e)
                    SetBlockingOfNonTemporaryEvents(e, false)
                    FreezeEntityPosition(e, false)
                    TaskWanderStandard(e, 10.0, 10)
                end
                SetPedKeepTask(e, true)
            end
        end
    end
end)

LSLegacy.Events.Register('police:callouts:ended', function(data)
    StopEscort()
    -- La housse reste en place le temps que le serveur nettoie la scène,
    SetTimeout(C.CleanupDelay * 1000, ClearBodyBags)
    StopAlarm()
    StopBoombox()
    ClearCalloutBlips()
    ClearPrompt()
    -- Mike et Jessie restent le temps du nettoyage : Jessie est en train
    SetTimeout(C.CleanupDelay * 1000, function()
        RemoveStaticNpc('custody')
        RemoveStaticNpc('hospital')
    end)
    Callout      = nil
    Incoming     = nil
    IsBrain       = false
    SceneLaidOut   = nil
    SceneRetries   = 0
    RouteSwitched  = nil
    RadioSceneDone = nil
    RadioDriverSeated = {}
    onSceneFor     = nil
    MassCorpsesLaidOut = {}
    Dancing       = {}
    AmbGen        = {}
    DoorstepRunning = {}
    -- Les boucles d'ambiance encore actives s'arrêtent d'elles-mêmes au
    for netId in pairs(SceneRunning) do SceneStop[netId] = true end
    SceneRunning = {}
    for e in pairs(Protect) do
        if DoesEntityExist(e) then SetEntityInvincible(e, false) end
    end
    for e in pairs(MoveRate) do
        if DoesEntityExist(e) then SetPedMoveRateOverride(e, 1.0) end
    end
    Heist       = nil
    MoveRate    = {}
    Protect     = {}
    BrawlShield = {}
    TaserShield = {}
    WoundedPed  = {}
    BrainState = {}
    MeleeHits  = {}
    LastSpeech = {}
end)

-- Masquage du corps piloté par le cerveau pendant sa mise en scène.
LSLegacy.Events.Register('police:callouts:corpseVisible', function(data)
    if not data or not data.netId then return end
    if not NetworkDoesNetworkIdExist(data.netId) then return end
    local e = NetworkGetEntityFromNetworkId(data.netId)
    if not e or e == 0 or not DoesEntityExist(e) then return end

    local visible = data.visible and true or false
    SetEntityVisible(e, visible, false)

    if not visible then
        SetTimeout(20000, function()
            if DoesEntityExist(e) and not IsEntityVisible(e) then
                SetEntityVisible(e, true, false)
            end
        end)
    end
end)

--  LEVÉE DE CORPS PAR LES SECOURS

local function AmbEntity(netId, tries)
    local t = 0
    while t < (tries or 60) do
        if NetworkDoesNetworkIdExist(netId) then
            local e = NetworkGetEntityFromNetworkId(netId)
            if e and e ~= 0 and DoesEntityExist(e) then return e end
        end
        Wait(100) t = t + 1
    end
    return nil
end

-- Diagnostic de la levée de corps, renvoyé par le serveur.
LSLegacy.Events.Register('police:callouts:ambulanceDebug', function(msg)
    print('^3[ambulance]^7 ' .. tostring(msg))
end)

LSLegacy.Events.Register('police:callouts:ambulance', function(data)
    if not data then return end
    print(('^2[ambulance]^7 Événement reçu — convoi #%s, meneur ici : %s')
        :format(tostring(data.id), tostring(data.driver)))
    if not data.driver then return end
    local A = C.Ambulance or {}

    CreateThread(function()
        print('^2[ambulance]^7 Convoi #' .. tostring(data.id) ..
            ' reçu — en attente des entités…')
        local veh = AmbEntity(data.vehNet)
        if not veh then
            print('^1[ambulance]^7 Véhicule jamais reçu — séquence abandonnée.')
            return
        end

        local crew = {}
        for _, netId in ipairs(data.crew or {}) do
            local e = AmbEntity(netId, 20)
            if e then crew[#crew + 1] = e end
        end
        if #crew == 0 then
            print('^1[ambulance]^7 Aucun brancardier reçu — séquence abandonnée.')
            return
        end
        print(('^2[ambulance]^7 %d brancardier(s) en place, départ vers la scène.')
            :format(#crew))

        -- Le point de mission n'est qu'une approximation : le corps a été
        local target = vector3(data.target.x + 0.0, data.target.y + 0.0,
            data.target.z + 0.0)
        local body = nil
        for _, netId in ipairs(data.corpses or {}) do
            local e = AmbEntity(netId, 10)
            if e then
                body = e
                target = GetEntityCoords(e)
                break
            end
        end
        print(('^2[ambulance]^7 Cible : (%.1f, %.1f, %.1f)%s')
            :format(target.x, target.y, target.z,
                body and ' — position du corps' or ' — point de mission'))

        RequestControl(veh)
        for _, ped in ipairs(crew) do
            RequestControl(ped)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetEntityInvincible(ped, true)
            SetPedCanRagdollFromPlayerImpact(ped, false)
        end

        -- Repositionnement sur la chaussée : le serveur ne sait pas où
        local vc = GetEntityCoords(veh)
        local okNode, found, nodePos, nodeHead = pcall(
            GetClosestVehicleNodeWithHeading,
            vc.x + 0.0, vc.y + 0.0, vc.z + 0.0, 1, 3.0, 0)
        if okNode and found and nodePos then
            SetEntityCoordsNoOffset(veh, nodePos.x, nodePos.y, nodePos.z + 1.0,
                false, false, false)
            SetEntityHeading(veh, (nodeHead or 0.0) + 0.0)
            print('^2[ambulance]^7 Ambulance recalée sur la chaussée.')
        else
            print('^3[ambulance]^7 Aucun nœud routier proche — départ depuis ' ..
                'le point d\'apparition.')
        end
        SetVehicleEngineOn(veh, true, true, false)
        SetVehicleOnGroundProperly(veh)

        -- Véhicule prioritaire : la circulation doit s'écarter, et le
        SetVehicleHasMutedSirens(veh, false)
        SetVehicleSiren(veh, true)

        -- Embarquement : native CLIENT, elle ne pouvait pas être faite
        for i, ped in ipairs(crew) do
            if DoesEntityExist(ped) then
                SetPedIntoVehicle(ped, veh, (i == 1) and -1 or (i - 2))
                SetDriverAbility(ped, 1.0)
                SetDriverAggressiveness(ped, 1.0)
                SetPedKeepTask(ped, true)
            end
        end
        Wait(300)
        if not IsPedInVehicle(crew[1], veh, false) then
            SetPedIntoVehicle(crew[1], veh, -1)
        end
        if A.Siren ~= false then
            SetVehicleSiren(veh, true)
            SetVehicleHasMutedSirens(veh, false)
        end

        -- Trajet
        local stopAt, bestD = target, 9999.0
        for nth = 1, 6 do
            local okN, foundN, nodeP = pcall(GetNthClosestVehicleNode,
                target.x, target.y, target.z, nth, 1, 3.0, 0)
            if okN and foundN and nodeP then
                local d = #(vector3(nodeP.x, nodeP.y, nodeP.z) - target)
                if d < bestD then
                    bestD  = d
                    stopAt = vector3(nodeP.x, nodeP.y, nodeP.z)
                end
            end
        end
        if bestD < 9999.0 then
            print(('^2[ambulance]^7 Meilleur accès routier : %.1f m du corps.')
                :format(bestD))
        else
            print('^3[ambulance]^7 Aucun accès routier trouvé — trajet direct.')
        end

        TaskVehicleDriveToCoordLongrange(crew[1], veh, stopAt.x, stopAt.y, stopAt.z,
            A.DriveSpeed or 26.0, A.DriveStyle or 786469, A.ArriveDist or 6.0)

        local deadline  = GetGameTimer() + (A.ApproachTimeout or 45000)
        local lastPos   = GetEntityCoords(veh)
        local stuck, swerves = 0, 0
        local stuckTicks = math.max(2, math.floor((A.StuckDelay or 4000) / 500))

        while GetGameTimer() < deadline do
            Wait(500)
            if not DoesEntityExist(veh) then return end
            local vp = GetEntityCoords(veh)

            if #(vp - stopAt) <= ((A.ArriveDist or 6.0) + 4.0) then break end

            if #(vp - lastPos) < 1.0 then
                stuck = stuck + 1
            else
                stuck = 0
            end
            lastPos = vp

            if stuck >= stuckTicks then
                stuck = 0
                swerves = swerves + 1

                if swerves <= (A.StuckSwerve or 2) then
                    -- Tentative de dépassement : on force un écart puis
                    print(('^3[ambulance]^7 Circulation bloquée — écart %d.')
                        :format(swerves))
                    TaskVehicleTempAction(crew[1], veh,
                        (swerves % 2 == 1) and 11 or 10, 1800)   -- gauche / droite
                    Wait(1900)
                    if not DoesEntityExist(veh) then return end
                    TaskVehicleDriveToCoordLongrange(crew[1], veh,
                        stopAt.x, stopAt.y, stopAt.z,
                        A.DriveSpeed or 26.0, A.DriveStyle or 786469,
                        A.ArriveDist or 6.0)

                elseif A.StuckReposition ~= false then
                    -- Dernier recours : on la rapproche de la scène sur
                    print('^3[ambulance]^7 Toujours bloquée — repositionnement ' ..
                        'au plus près de l\'intervention.')
                    local okR, foundR, posR, headR = pcall(
                        GetClosestVehicleNodeWithHeading,
                        stopAt.x, stopAt.y, stopAt.z, 1, 3.0, 0)
                    if okR and foundR and posR then
                        RequestControl(veh)
                        SetEntityCoordsNoOffset(veh, posR.x, posR.y, posR.z + 1.0,
                            false, false, false)
                        SetEntityHeading(veh, (headR or 0.0) + 0.0)
                        SetVehicleOnGroundProperly(veh)
                    end
                    break
                else
                    print('^3[ambulance]^7 Véhicule bloqué — descente sur place.')
                    break
                end
            end
        end

        if not DoesEntityExist(veh) then return end

        -- Approche finale
        local restant = #(GetEntityCoords(veh) - target)
        local okM, vehModel = pcall(GetEntityModel, veh)
        if not okM then vehModel = 0 end
        if restant > (A.FinalApproach or 18.0) then
            print(('^3[ambulance]^7 Encore %.1f m — approche directe.')
                :format(restant))
            TaskVehicleDriveToCoord(crew[1], veh, target.x, target.y, target.z,
                12.0, 0, vehModel, 786469, 8.0, true)

            local finEnd = GetGameTimer() + 12000
            local prev = GetEntityCoords(veh)
            while GetGameTimer() < finEnd do
                Wait(400)
                if not DoesEntityExist(veh) then return end
                local vp = GetEntityCoords(veh)
                if LSLegacy.Validate.Distance(vp, target, 10.0) then break end
                if LSLegacy.Validate.Distance(vp, prev, 0.6) then break end   -- ne progresse plus
                prev = vp
            end
        end

        TaskVehicleTempAction(crew[1], veh, 6, 2000)   -- freinage
        Wait(1200)
        SetVehicleSiren(veh, false)
        print(('^2[ambulance]^7 Ambulance arrêtée à %.1f m du corps.')
            :format(#(GetEntityCoords(veh) - target)))

        -- Descente et prise en charge
        for _, ped in ipairs(crew) do
            if DoesEntityExist(ped) then TaskLeaveVehicle(ped, veh, 0) end
        end
        Wait(2500)

        -- Marche jusqu'au corps. TaskGoStraightToCoord va en LIGNE DROITE
        local spots = {}
        for i = 1, #crew do
            local a = (i - 1) * (math.pi * 2 / math.max(1, #crew)) + math.pi * 0.25
            spots[i] = vector3(target.x + math.cos(a) * 1.1,
                               target.y + math.sin(a) * 1.1, target.z)
        end

        for i, ped in ipairs(crew) do
            if DoesEntityExist(ped) then
                ClearPedTasks(ped)
                TaskFollowNavMeshToCoord(ped, spots[i].x, spots[i].y, spots[i].z,
                    1.2, (A.WalkTimeout or 25000), 1.0, false, 0)
            end
        end

        -- On attend que TOUS soient arrivés, pas le premier : sinon le
        local reach   = A.ReachDist or 2.5
        local walkEnd = GetGameTimer() + (A.WalkTimeout or 25000)
        while GetGameTimer() < walkEnd do
            Wait(400)
            local arrived, alive = 0, 0
            for i, ped in ipairs(crew) do
                if DoesEntityExist(ped) then
                    alive = alive + 1
                    if #(GetEntityCoords(ped) - spots[i]) <= reach then
                        arrived = arrived + 1
                    end
                end
            end
            if alive == 0 then return end
            if arrived >= alive then break end
        end

        -- Les retardataires sont replacés : mieux vaut un léger recalage
        for i, ped in ipairs(crew) do
            if DoesEntityExist(ped) then
                local d = #(GetEntityCoords(ped) - spots[i])
                if d > reach then
                    print(('^3[ambulance]^7 Brancardier %d encore à %.1f m — recalage.')
                        :format(i, d))
                    RequestControl(ped)
                    ClearPedTasksImmediately(ped)
                    SetEntityCoordsNoOffset(ped, spots[i].x, spots[i].y,
                        spots[i].z, false, false, false)
                end
            end
        end
        print('^2[ambulance]^7 Équipage au complet auprès du corps.')

        -- Tous se tournent vers le corps, PUIS l'animation démarre —
        for _, ped in ipairs(crew) do
            if DoesEntityExist(ped) then
                TaskTurnPedToFaceCoord(ped, target.x, target.y, target.z, 800)
            end
        end
        Wait(900)

        for _, ped in ipairs(crew) do
            if DoesEntityExist(ped) and LoadAnim('amb@medic@standing@kneel@base') then
                TaskPlayAnim(ped, 'amb@medic@standing@kneel@base', 'base',
                    4.0, -4.0, -1, 1, 0, false, false, false)
            end
        end
        Wait(A.WorkDelay or 6000)

        -- Le corps part avec eux.
        print('^2[ambulance]^7 Corps pris en charge.')
        SendQ('police:callouts:ambulanceLoaded', { id = data.id })

        -- Remontée et départ
        for _, ped in ipairs(crew) do
            if DoesEntityExist(ped) and DoesEntityExist(veh) then
                ClearPedTasks(ped)
                TaskEnterVehicle(ped, veh, 15000, -2, 1.5, 1, 0)
            end
        end
        Wait(A.BoardDelay or 6000)

        if DoesEntityExist(veh) and DoesEntityExist(crew[1]) then
            if not IsPedInVehicle(crew[1], veh, false) then
                SetPedIntoVehicle(crew[1], veh, -1)
            end
            TaskVehicleDriveWander(crew[1], veh, A.DriveSpeed or 26.0,
                A.DriveStyle or 786469)
        end
    end)
end)

-- Déposition du mis en cause, recueillie sur place.
LSLegacy.Events.Register('police:callouts:ownerStatement', function(data)
    if not data or not data.text then return end
    Notify((data.label or 'L\'individu') .. ' : « ' .. data.text .. ' »', 'info')
end)

LSLegacy.Events.Register('police:callouts:searchResult', function(data)
    if not data then return end
    if not data.items or #data.items == 0 then
        Notify('Fouille de ' .. (data.label or 'l\'individu') .. ' : rien à signaler.', 'info')
        return
    end
    local options = {}
    for _, it in ipairs(data.items) do
        options[#options + 1] = { title = it, description = 'Saisi et placé sous scellés',
                                  icon = 'box-archive', disabled = true }
    end
    lib.registerContext({
        id = 'callout_search',
        title = 'Fouille — ' .. (data.label or 'Individu'),
        options = options,
    })
    lib.showContext('callout_search')
    Notify('Objets confisqués : ' .. table.concat(data.items, ', '), 'success')
end)

--  NOM DE RUE RÉEL

local streetSentFor = nil

CreateThread(function()
    while true do
        Wait(3000)
        if IsBrain and Callout and Callout.coords and streetSentFor ~= Callout.id then
            local c = Callout.coords
            local s1, s2 = GetStreetNameAtCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
            local n1 = s1 and GetStreetNameFromHashKey(s1) or nil
            local n2 = (s2 and s2 ~= 0) and GetStreetNameFromHashKey(s2) or nil
            if n1 and n1 ~= '' then
                streetSentFor = Callout.id
                local street = (n2 and n2 ~= '')
                    and ("à l'angle de " .. n1 .. ' et de ' .. n2) or n1
                SendQ('police:callouts:reportStreet', { street = street })
            end
        end
    end
end)

--  COMMANDES CLIENT ET STATUTS RADIO

RegisterCommand('statut', function()
    if not Callout then Notify('Vous n\'êtes engagé sur aucune intervention.', 'error') return end
    lib.registerContext({
        id = 'callout_status',
        title = 'Statut radio' .. (MyCrewLbl and (' — ' .. MyCrewLbl) or ''),
        options = {
            { title = 'Disponible',   icon = 'circle-check',
              onSelect = function() SendQ('police:callouts:setStatus', { status = 'available' }) end },
            { title = 'En route',     icon = 'car',
              onSelect = function() SendQ('police:callouts:setStatus', { status = 'enroute' }) end },
            { title = 'Sur place',    icon = 'location-dot',
              onSelect = function() SendQ('police:callouts:setStatus', { status = 'onscene' }) end },
            { title = 'Indisponible', icon = 'circle-xmark',
              onSelect = function() SendQ('police:callouts:setStatus', { status = 'unavailable' }) end },
            { title = '── Demander des renforts ──', icon = 'tower-broadcast',
              onSelect = function() SendQ('police:callouts:requestBackup') end },
            { title = 'Quitter l\'intervention', icon = 'right-from-bracket',
              onSelect = function() SendQ('police:callouts:leave') end },
        },
    })
    lib.showContext('callout_status')
end, false)

--  COMMANDES UTILISABLES EN F8

local IsAdminCached = false

LSLegacy.Events.Register('police:callouts:adminState', function(state)
    IsAdminCached = state == true
end)

-- On interroge le serveur au démarrage puis périodiquement : le niveau
CreateThread(function()
    while true do
        Wait(30000)
        SendQ('police:callouts:askAdmin', {})
        Wait(270000)
    end
end)

-- `adminOnly` : la commande ne fait rien pour un non-admin, sans même
local function RelayCommand(name, adminOnly)
    RegisterCommand(name, function(_, args)
        if adminOnly and not IsAdminCached then
            Notify('Commande réservée à l\'administration.', 'error')
            return
        end
        SendQ('police:callouts:command', { cmd = name, args = args or {} })
    end, false)
end

-- Appel de renfort : accessible directement, sans passer par le menu
RegisterCommand('pnjdebug', function()
    print('^2[pnjdebug]^7 ═══ ÉTAT DU CIBLAGE ═══')
    print(('^2[pnjdebug]^7 en service   : %s'):format(tostring(IsOnDuty())))
    print(('^2[pnjdebug]^7 inscrit      : %s'):format(tostring(Registered)))
    print(('^2[pnjdebug]^7 intervention : %s'):format(
        Callout and (tostring(Callout.scenarioId) .. ' #' .. tostring(Callout.id)) or 'aucune'))

    if not Callout then
        print('^1[pnjdebug]^7 Aucune intervention : aucune option ne peut apparaître.')
        Notify('Diagnostic dans la console F8.', 'info')
        return
    end

    print(('^2[pnjdebug]^7 engagé       : %s   cerveau : %s')
        :format(tostring(EngagedOnCallout()), tostring(IsBrain)))
    print(('^2[pnjdebug]^7 objectif     : %s   témoignage pris : %s')
        :format(tostring(Callout.objective), tostring(Callout.statementTaken)))

    local me = GetEntityCoords(PlayerPedId())
    print('^2[pnjdebug]^7 netId | rôle | état | existe | réseau | dist | modèle')
    for _, p in ipairs(Callout.peds or {}) do
        local exists, networked, dist = false, false, -1.0
        if NetworkDoesNetworkIdExist(p.netId) then
            local e = NetworkGetEntityFromNetworkId(p.netId)
            if e and e ~= 0 and DoesEntityExist(e) then
                exists    = true
                networked = NetworkGetEntityIsNetworked(e)
                dist      = #(GetEntityCoords(e) - me)
            end
        end
        print(('^2[pnjdebug]^7 %6s | %-9s | %-9s | %-5s | %-5s | %5.1f | %s')
            :format(tostring(p.netId), tostring(p.role), tostring(p.state),
                tostring(exists), tostring(networked), dist, tostring(p.label)))
    end
    Notify('Diagnostic dans la console F8.', 'info')
end, false)

TriggerEvent('chat:addSuggestion', '/pnjdebug',
    'Diagnostiquer le ciblage des PNJ de l\'intervention en cours')

-- Signalement manuel d'un PNJ mal placé
RegisterCommand('signalpnj', function()
    if not Callout then
        print('^1[signalpnj]^7 Vous n\'êtes engagé sur aucune intervention.')
        Notify('Vous n\'êtes engagé sur aucune intervention.', 'error')
        return
    end
    print('^3[signalpnj]^7 Signalement envoyé au serveur, en attente de ' ..
        'confirmation…')
    SendQ('police:callouts:reportSpawn', {})
end, false)

-- Confirmation du serveur : le PNJ a bien été enregistré au registre.
LSLegacy.Events.Register('police:callouts:spawnReported', function(data)
    if not data then return end
    print('^2[signalpnj]^7 ═══ PNJ SIGNALÉ ═══')
    print(('^2[signalpnj]^7 scénario  : %s'):format(tostring(data.scenario)))
    print(('^2[signalpnj]^7 lieu      : %s'):format(tostring(data.zone)))
    print(('^2[signalpnj]^7 rôle      : %s   (à %.1f m de vous)')
        :format(tostring(data.role), tonumber(data.dist) or 0))
    print(('^2[signalpnj]^7 position  : vector3(%.2f, %.2f, %.2f)')
        :format(data.x or 0, data.y or 0, data.z or 0))
    print('^2[signalpnj]^7 Enregistré au registre — visible avec /spawnstats.')
end)

TriggerEvent('chat:addSuggestion', '/signalpnj',
    'Signaler un PNJ mal placé (mur, toit, sous la carte)')

-- Relevé d'une position de PNJ
local ANCHOR_VEHICLE_ROLE = {
    vehicule = true, ['véhicule'] = true, voiture = true, vehicle = true,
}

-- Mode repérage
local Survey = nil   -- { key, label, scenario, x, y, z, points }

-- Couleurs des marqueurs de repérage
local SURVEY_COLOUR = {
    caller    = {  60, 200,  80 },   -- vert    : le requérant
    suspect   = { 230,  60,  50 },   -- rouge   : les individus
    chief     = { 230,  60,  50 },
    crew      = { 230,  60,  50 },
    driver    = { 230,  60,  50 },
    victim    = { 240, 150,  30 },   -- orange  : la victime
    vehicle   = {  60, 140, 255 },   -- bleu    : les véhicules
    animal    = { 240, 220,  60 },   -- jaune   : le chien
    bystander = { 170,  90, 220 },   -- violet  : les badauds
    deceased  = {  25,  25,  25 },   -- noir    : la personne décédée
    wanderer  = { 255, 120, 190 },   -- rose    : la personne perdue
}
local SURVEY_DEFAULT = { 200, 200, 200 }

-- Hauteur du marqueur sous la position relevée, et son diamètre.
local SURVEY_DROP = { vehicle = 0.45 }
local SURVEY_SIZE = { vehicle = 1.8 }

-- Relevés effectués pendant cette session, pas encore intégrés au
local SurveyDraft = {}   -- { [clé|scénario] = { {role, x, y, z}, ... } }

-- Positions déjà intégrées pour l'emplacement et le scénario repérés.
local function SurveyPoints(key, scenarioId)
    local out = {}
    local set = C.SceneAnchors and C.SceneAnchors[key]
    if not set then return out end

    local function push(role, v, kind)
        if v == nil then return end
        if v.w ~= nil then
            out[#out + 1] = { role = role, x = v.x, y = v.y, z = v.z, kind = kind }
            return
        end
        for _, pt in ipairs(v) do
            if pt and pt.w ~= nil then
                out[#out + 1] = { role = role, x = pt.x, y = pt.y, z = pt.z, kind = kind }
            end
        end
    end

    local seen = {}
    local scoped = scenarioId and set[scenarioId] or nil
    if scoped then
        for role, v in pairs(scoped) do
            seen[role] = true
            push(role, v, 'scene')
        end
    end
    for role, v in pairs(set) do
        -- Une clé portant un nom de scénario est une surcharge, pas un
        if not Config.Police.Scenarios[role] and not seen[role] then
            push(role, v, 'generic')
        end
    end
    return out
end

RegisterCommand('pnjrepere', function(_, args)
    local sc = args and args[1]
    SendQ('police:callouts:anchorSurvey', { scenario = sc and tostring(sc) or '' })
end, false)

-- Repères de travail sur la carte
local PnjBlips   = {}
local PnjBlipSet = nil

local function ClearPnjBlips()
    for _, b in ipairs(PnjBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    PnjBlips   = {}
    PnjBlipSet = nil
end

-- État des relevés d'un emplacement pour un scénario donné.
local function AnchorState(key, scenarioId)
    local set = C.SceneAnchors and C.SceneAnchors[key]
    -- Scénario sans mise en scène à faire : l'emplacement est acquis,
    local free = scenarioId and C.NoAnchorNeeded
        and C.NoAnchorNeeded[scenarioId] or false
    if not set then return free and 'validated' or 'none', 0 end

    local function Count(t)
        if type(t) ~= 'table' then return 0 end
        if t.w ~= nil then return 1 end
        local n = 0
        for _, v in pairs(t) do n = n + Count(v) end
        return n
    end

    if scenarioId and set[scenarioId] then
        return 'scoped', Count(set[scenarioId])
    end

    local n = 0
    for role, v in pairs(set) do
        -- Les clés qui portent un nom de scénario appartiennent à une
        if not Config.Police.Scenarios[role] then n = n + Count(v) end
    end
    if n > 0 then return 'generic', n end
    return free and 'validated' or 'none', 0
end

-- Ce scénario peut-il tomber sur cet emplacement ?
local function ScenarioAllows(loc, scenarioId, sc, key)
    if not scenarioId or not sc then return true end

    if loc.only then
        for _, id in ipairs(loc.only) do
            if id == scenarioId then return true end
        end
        return false
    end
    if loc.exclude then
        for _, id in ipairs(loc.exclude) do
            if id == scenarioId then return false end
        end
    end

    local anchored = key and C.SceneAnchors and C.SceneAnchors[key] ~= nil
    if not anchored and loc.zone then
        if sc.excludeZones then
            for _, z in ipairs(sc.excludeZones) do
                if z == loc.zone then return false end
            end
        end
        if sc.onlyZones then
            local ok = false
            for _, z in ipairs(sc.onlyZones) do
                if z == loc.zone then ok = true break end
            end
            if not ok then return false end
        end
    end
    return true
end

local PNJ_BLIP_STYLE = {
    scoped    = { colour = 2, label = 'mise en scène complète' },
    validated = { colour = 2, label = 'validé, rien à mettre en scène' },
    generic   = { colour = 5, label = 'positions génériques' },
    none      = { colour = 1, label = 'aucun relevé' },
}

RegisterCommand('pnjblips', function(_, args)
    local arg = args and args[1] and tostring(args[1]):lower() or nil

    if not arg or arg == 'off' or arg == 'stop' then
        if #PnjBlips > 0 then
            print(('^2[repères]^7 %d repère(s) effacé(s).'):format(#PnjBlips))
            ClearPnjBlips()
        else
            print('^3[repères]^7 Usage : /pnjblips <scénario|catégorie>')
            print('^3[repères]^7 Exemples : /pnjblips cambriolage, ' ..
                '/pnjblips trafic_stup, /pnjblips shop')
        end
        return
    end

    -- Second appel sur le même ensemble : on efface.
    if PnjBlipSet == arg then
        print(('^2[repères]^7 %d repère(s) effacé(s).'):format(#PnjBlips))
        ClearPnjBlips()
        return
    end
    ClearPnjBlips()

    local sc = Config.Police.Scenarios[arg]
    local category    = sc and sc.locations or (C.Locations[arg] and arg) or nil
    local scenarioId  = sc and arg or nil

    if not category or not C.Locations[category] then
        print('^1[repères]^7 Inconnu. Scénarios disponibles :')
        local ids = {}
        for id in pairs(Config.Police.Scenarios) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do
            local s2 = Config.Police.Scenarios[id]
            print(('^1[repères]^7   %-24s → %s'):format(id, tostring(s2.locations)))
        end
        return
    end

    local tally = { scoped = 0, validated = 0, generic = 0, none = 0 }
    local skipped = {}
    print(('^2[repères]^7 ═══ %s ═══'):format(
        sc and (sc.label or arg) or ('catégorie ' .. category)))

    for i, loc in ipairs(C.Locations[category]) do
        local key = category .. ':' .. i

        -- Emplacement interdit à ce scénario : aucun repère. Il est
        if not ScenarioAllows(loc, scenarioId, sc, key) then
            skipped[#skipped + 1] = ('%s — %s'):format(key, tostring(loc.label))
            goto continue
        end

        do
        local state, n = AnchorState(key, scenarioId)
        tally[state] = tally[state] + 1
        local style = PNJ_BLIP_STYLE[state]

        local v = loc.coords
        local b = AddBlipForCoord(v.x, v.y, v.z)
        SetBlipSprite(b, 1)
        SetBlipColour(b, style.colour)
        SetBlipScale(b, 0.85)
        SetBlipAsShortRange(b, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(
            ('%s — %s (%s)'):format(key, tostring(loc.label), style.label))
        EndTextCommandSetBlipName(b)
        PnjBlips[#PnjBlips + 1] = b

        local mark = ((state == 'scoped' or state == 'validated') and '^2vert  ')
            or (state == 'generic' and '^3jaune ') or '^1rouge '
        print(('%s^7 %-16s %-28s %2d position(s)')
            :format(mark, key, tostring(loc.label), n))
        end
        ::continue::
    end

    if #skipped > 0 then
        print(('^8[repères]^7 %d emplacement(s) exclu(s) de ce scénario, ' ..
            'sans repère :'):format(#skipped))
        for _, l in ipairs(skipped) do print('^8[repères]^7   ' .. l) end
    end

    PnjBlipSet = arg
    print(('^2[repères]^7 %d emplacement(s) — ^2%d complet(s)^7, ' ..
        '^2%d validé(s)^7, ^3%d générique(s)^7, ^1%d sans relevé^7.')
        :format(#PnjBlips, tally.scoped, tally.validated,
            tally.generic, tally.none))
    print('^2[repères]^7 /pnjblips ' .. arg .. ' à nouveau pour les effacer.')
    Notify(('%d emplacements affichés sur la carte.'):format(#PnjBlips), 'success')
end, false)

TriggerEvent('chat:addSuggestion', '/pnjblips',
    'Afficher sur la carte les lieux d\'un scénario (2ᵉ appel : effacer)', {
        { name = 'scénario', help = 'cambriolage, braquage_superette, trafic_stup, … ou une catégorie' },
    })

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then ClearPnjBlips() end
end)

TriggerEvent('chat:addSuggestion', '/pnjrepere',
    'Repérer un lieu sans intervention (sans argument : arrêt)', {
        { name = 'scénario', help = 'braquage_superette, vol_etalage, … — vide pour arrêter' },
    })

LSLegacy.Events.Register('police:callouts:anchorSurveyState', function(data)
    if not data or not data.active then
        Survey = nil
        if data and data.tooFar then
            print('^1[repérage]^7 ═══ TROP LOIN ═══')
            print(('^1[repérage]^7 Emplacement déclaré le plus proche : %s [%s]')
                :format(tostring(data.label), tostring(data.key)))
            print(('^1[repérage]^7 Il est à %.0f m de vous — un point GPS y mène.')
                :format(tonumber(data.dist) or 0))
            print('^1[repérage]^7 Rapprochez-vous, ou signalez qu\'il manque un ' ..
                'emplacement ici.')
            if data.x then SetNewWaypoint(data.x + 0.0, data.y + 0.0) end
        elseif data and data.list then
            print('^3[repérage]^7 Scénarios disponibles :')
            for _, id in ipairs(data.list) do
                print('^3[repérage]^7   ' .. tostring(id))
            end
        else
            print('^2[repérage]^7 Repérage terminé.')
        end
        return
    end

    Survey = {
        key = data.key, label = data.label, scenario = data.scenario,
        x = data.x, y = data.y, z = data.z,
    }
    Survey.points = SurveyPoints(data.key, data.scenario)
    print('^2[repérage]^7 ═══ REPÉRAGE ACTIF ═══')
    print(('^2[repérage]^7 scénario : %s (%s)')
        :format(tostring(data.scenarioLabel), tostring(data.scenario)))
    print(('^2[repérage]^7 lieu     : %s  [%s] à %.0f m')
        :format(tostring(data.label), tostring(data.key), tonumber(data.dist) or 0))
    print('^2[repérage]^7 Un repère blanc marque le centre de la scène.')
    if #Survey.points > 0 then
        local byRole = {}
        for _, pt in ipairs(Survey.points) do
            byRole[pt.role] = (byRole[pt.role] or 0) + 1
        end
        local parts = {}
        for role, n in pairs(byRole) do
            parts[#parts + 1] = ('%s ×%d'):format(role, n)
        end
        table.sort(parts)
        print(('^2[repérage]^7 %d position(s) déjà relevée(s) : %s')
            :format(#Survey.points, table.concat(parts, ', ')))
        print('^2[repérage]^7 Elles sont marquées au sol, une couleur par rôle.')
    else
        print('^3[repérage]^7 Aucune position relevée ici pour ce scénario.')
    end
    print('^2[repérage]^7 /pnjposition <rôle> pour relever, /pnjrepere pour arrêter.')

    -- Point de passage : les emplacements sont désignés par un index,
    if data.x then SetNewWaypoint(data.x + 0.0, data.y + 0.0) end
end)

-- Repères au sol pendant le repérage : le centre de la scène, puis une
CreateThread(function()
    while true do
        if Survey and Survey.x then
            -- Centre de la scène : blanc, pour ne pas le confondre avec
            DrawMarker(1, Survey.x, Survey.y, Survey.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 0.6,
                255, 255, 255, 110, false, false, 2, false, nil, nil, false)

            for _, pt in ipairs(Survey.points or {}) do
                local c    = SURVEY_COLOUR[pt.role] or SURVEY_DEFAULT
                local drop = SURVEY_DROP[pt.role] or 0.95
                local size = SURVEY_SIZE[pt.role] or 0.7
                DrawMarker(1, pt.x, pt.y, pt.z - drop,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, 0.35,
                    c[1], c[2], c[3], 170, false, false, 2, false, nil, nil, false)
            end

            local draft = SurveyDraft[Survey.key .. '|' .. tostring(Survey.scenario)]
            for _, pt in ipairs(draft or {}) do
                local c = SURVEY_COLOUR[pt.role] or SURVEY_DEFAULT
                -- Cône pointe en bas, bien visible au-dessus du sol. Il
                DrawMarker(0, pt.x, pt.y, pt.z + 1.3,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5,
                    c[1], c[2], c[3], 200, false, false, 2, false, nil, nil, false)
            end

            Wait(0)
        else
            Wait(1000)
        end
    end
end)

RegisterCommand('pnjposition', function(_, args)
    local role = args and args[1]
    if not role then
        print('^1[ancrage]^7 Usage : /pnjposition <rôle>')
        print('^1[ancrage]^7   celui qui appelle : requerant, vigile, ' ..
            'caissier, temoin, proprietaire, voisin, commercant')
        print('^1[ancrage]^7   mis en cause     : individu, voleur, ' ..
            'dealer, maitre, ivrogne')
        print('^1[ancrage]^7   personne errante : errant, perdu, ' ..
            'desoriente, personne_agee')
        print('^1[ancrage]^7   autres           : victime, badaud, client, ' ..
            'passant, corps, chien')
        print('^1[ancrage]^7   braquage         : chef, conducteur, ' ..
            'braqueur, vehicule')
        print('^1[ancrage]^7 Les noms anglais d\'origine restent acceptés ' ..
            '(caller, suspect, wanderer…).')
        Notify('Précisez le rôle : /pnjposition requerant', 'error')
        return
    end
    if not Callout and not Survey then
        print('^1[ancrage]^7 Aucune intervention et aucun repérage en cours.')
        print('^1[ancrage]^7 Lancez /pnjrepere <scénario> — par exemple ' ..
            '/pnjrepere braquage_superette.')
        Notify('Lancez /pnjrepere <scénario> d\'abord.', 'error')
        return
    end

    role = tostring(role):lower()
    local payload = { role = role }

    -- Pour un véhicule, on relève le véhicule occupé plutôt que le
    if ANCHOR_VEHICLE_ROLE[role] then
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and DoesEntityExist(veh) then
            local vc = GetEntityCoords(veh)
            payload.vx, payload.vy = vc.x, vc.y
            payload.vz, payload.vh = vc.z, GetEntityHeading(veh)
        else
            print('^3[ancrage]^7 Aucun véhicule occupé : c\'est votre ' ..
                'position et votre orientation qui sont relevées.')
        end
    end

    SendQ('police:callouts:anchorHere', payload)
end, false)

-- Annulation du dernier point relevé. Sans argument, le plus récent
RegisterCommand('pnjannule', function(_, args)
    local role = args and args[1]
    if not Callout and not Survey then
        print('^1[ancrage]^7 Aucune intervention et aucun repérage en cours.')
        Notify('Aucun repérage en cours.', 'error')
        return
    end
    SendQ('police:callouts:anchorUndo', { role = role and tostring(role):lower() or '' })
end, false)

TriggerEvent('chat:addSuggestion', '/pnjannule',
    'Annuler le dernier point relevé (facultatif : un rôle)', {
        { name = 'rôle', help = 'vide pour le dernier point, ou requerant, individu, vehicule…' },
    })

LSLegacy.Events.Register('police:callouts:anchorUndone', function(data)
    if not data then return end

    -- Les marques au sol sont reconstruites depuis la liste renvoyée :
    local k = tostring(data.key) .. '|' .. tostring(data.scenario)
    local list = {}
    for _, pt in ipairs(data.points or {}) do
        list[#list + 1] = { role = tostring(pt.role), x = pt.x, y = pt.y, z = pt.z }
    end
    SurveyDraft[k] = (#list > 0) and list or nil

    print(('^3[ancrage]^7 Dernier « %s » annulé — %d point(s) restant(s) ' ..
        'sur %s.'):format(tostring(data.role), #list, tostring(data.key)))
    if data.x then
        print(('^3[ancrage]^7   position retirée : vector4(%.2f, %.2f, %.2f)')
            :format(data.x, data.y, data.z or 0))
    end
end)

TriggerEvent('chat:addSuggestion', '/pnjposition',
    'Relever la position correcte d\'un PNJ pour ce lieu', {
        { name = 'rôle', help = 'requerant, vigile, caissier, individu, voleur, victime, badaud, corps, chien, errant, chef, conducteur, braqueur, vehicule' },
    })

-- Rôle refusé : on restitue la liste entière, pas un extrait.
LSLegacy.Events.Register('police:callouts:anchorRoles', function(data)
    if not data then return end
    print(('^1[ancrage]^7 « %s » n\'est pas un rôle connu.')
        :format(tostring(data.given)))
    print('^3[ancrage]^7 ═══ NOMS ACCEPTÉS ═══')
    for _, l in ipairs(data.lines or {}) do
        print('^3[ancrage]^7 ' .. l)
    end
end)

LSLegacy.Events.Register('police:callouts:anchorSaved', function(data)
    if not data then return end

    -- Mémorisé pour l'affichage au sol : le relevé apparaît aussitôt,
    if data.key and data.x then
        local k = data.key .. '|' .. tostring(data.scenario)
        SurveyDraft[k] = SurveyDraft[k] or {}
        local list = SurveyDraft[k]
        list[#list + 1] = {
            role = tostring(data.role), x = data.x, y = data.y, z = data.z,
        }
    end

    print(('^2[ancrage]^7 %s n°%d relevé sur %s (%s)')
        :format(tostring(data.role), tonumber(data.index) or 1,
            tostring(data.label), tostring(data.key)))
    print(('^2[ancrage]^7   vector4(%.2f, %.2f, %.2f, %.1f)')
        :format(data.x or 0, data.y or 0, data.z or 0, data.h or 0))
    print('^2[ancrage]^7 /pnjpositions pour obtenir le bloc complet.')
end)

LSLegacy.Events.Register('police:callouts:anchorDump', function(data)
    if data and data.cleared then
        -- Le brouillon serveur est vidé : les marques de session aussi,
        SurveyDraft = {}
        print('^2[ancrage]^7 Positions relevées effacées.')
        return
    end
    local lines = (data and data.lines) or {}
    if #lines == 0 then
        print('^2[ancrage]^7 Aucune position relevée.')
        return
    end
    print('^2[ancrage]^7 ═══ À COLLER DANS C.SceneAnchors ═══')
    print('C.SceneAnchors = {')
    for _, l in ipairs(lines) do print(l) end
    print('}')
    print('^2[ancrage]^7 ═══════════════════════════════════')
end)

-- Signalement d'un EMPLACEMENT entier
RegisterCommand('signallieu', function()
    if not Callout then
        print('^1[signallieu]^7 Vous n\'êtes engagé sur aucune intervention.')
        Notify('Vous n\'êtes engagé sur aucune intervention.', 'error')
        return
    end
    print('^3[signallieu]^7 Signalement envoyé, en attente du détail…')
    SendQ('police:callouts:reportLocation', {})
end, false)

-- Registre des placements ratés, renvoyé par le serveur.
LSLegacy.Events.Register('police:callouts:spawnStats', function(data)
    local rows = (data and data.rows) or {}

    if data and data.cleared then
        print('^2[spawnstats]^7 Registre vidé.')
        return
    end

    if #rows == 0 then
        print('^2[spawnstats]^7 Aucun placement raté enregistré depuis le ' ..
            'démarrage du serveur.')
        return
    end

    print(('^2[spawnstats]^7 ═══ %d ÉCHEC(S) · %d REPLI(S) ═══')
        :format(tonumber(data.hard) or 0, tonumber(data.soft) or 0))
    print('^2[spawnstats]^7 Un REPLI est un placement réussi au prix d\'un ' ..
        'assouplissement : sans gravité.')
    print('^2[spawnstats]^7 occ. | src  | scénario | lieu | rôle | motif')

    local separated = false
    for _, e in ipairs(rows) do
        -- Trait de séparation entre les vrais échecs et les replis.
        if e.degraded and not separated then
            separated = true
            print('^2[spawnstats]^7 ── replis (placement réussi) ──')
        end
        print(('^2[spawnstats]^7 %4d | %-4s | %s | %s | %s | %s')
            :format(tonumber(e.count) or 0, e.manual and 'MAN' or 'auto',
                tostring(e.scenario), tostring(e.zone),
                tostring(e.role), tostring(e.reason)))
        print(('^2[spawnstats]^7        vector3(%.2f, %.2f, %.2f)%s')
            :format(e.x or 0, e.y or 0, e.z or 0,
                e.first and ('   du %s au %s'):format(e.first, e.last or e.first) or ''))
    end
    print('^2[spawnstats]^7 ═══ ' .. #rows .. ' emplacement(s) ═══')
    print('^2[spawnstats]^7 Registre conservé entre les redémarrages. ' ..
        'Videz-le avec /spawnstatsreset une fois traité.')
end)

-- Signalement d'un SCÉNARIO inadapté au lieu
RegisterCommand('signalscenario', function()
    if not Callout then
        print('^1[signalscenario]^7 Vous n\'êtes engagé sur aucune intervention.')
        Notify('Vous n\'êtes engagé sur aucune intervention.', 'error')
        return
    end
    print('^3[signalscenario]^7 Signalement envoyé, en attente du détail…')
    SendQ('police:callouts:reportMismatch', {})
end, false)

TriggerEvent('chat:addSuggestion', '/signalscenario',
    'Signaler un type d\'intervention inadapté à ce lieu (le lieu reste bon)')

LSLegacy.Events.Register('police:callouts:mismatchReported', function(data)
    if not data then return end
    print('^3[signalscenario]^7 ═══════════ À TRANSMETTRE ═══════════')
    print(('^3[signalscenario]^7 scénario inadapté : %s'):format(tostring(data.scenario)))
    print(('^3[signalscenario]^7 emplacement       : C.Locations.%s  index %d  (%s)')
        :format(tostring(data.category), tonumber(data.index) or 0,
            tostring(data.label)))
    print('^3[signalscenario]^7 LIGNE CONCERNÉE (à conserver, à restreindre) :')
    print(tostring(data.line))
    print(('^3[signalscenario]^7 Correction : exclude = { \'%s\' } sur cette entrée.')
        :format(tostring(data.scenario)))
    print('^3[signalscenario]^7 ══════════════════════════════════════')
end)

TriggerEvent('chat:addSuggestion', '/signallieu',
    'Signaler TOUTE l\'intervention : emplacement à supprimer')

-- Rapport complet renvoyé par le serveur, prêt à être transmis.
LSLegacy.Events.Register('police:callouts:locationReported', function(data)
    if not data then return end
    print('^1[signallieu]^7 ═══════════ À TRANSMETTRE ═══════════')
    print(('^1[signallieu]^7 scénario  : %s'):format(tostring(data.scenario)))
    print(('^1[signallieu]^7 emplacement : C.Locations.%s  index %d  (%s)')
        :format(tostring(data.category), tonumber(data.index) or 0,
            tostring(data.label)))
    print('^1[signallieu]^7 LIGNE À SUPPRIMER :')
    print(tostring(data.line))
    print('^1[signallieu]^7 État des PNJ :')
    for _, e in ipairs(data.peds or {}) do
        if e.exists then
            print(('^1[signallieu]^7   %-9s %-9s Δz %+.2f m   à %.1f m de vous')
                :format(tostring(e.role), tostring(e.state),
                    tonumber(e.dz) or 0, tonumber(e.dist) or 0))
        else
            print(('^1[signallieu]^7   %-9s %-9s ENTITÉ ABSENTE')
                :format(tostring(e.role), tostring(e.state)))
        end
    end
    print('^1[signallieu]^7 ══════════════════════════════════════')
end)

-- Capture d'un emplacement de mission
RegisterCommand('lieu', function(_, args)
    local cat = args and args[1]
    local known = { street = true, residential = true, shop = true,
        dealpoint = true, nightlife = true, parking = true, doorstep = true }
    if not cat or not known[cat] then
        Notify('Usage : /lieu <street|residential|shop|dealpoint|nightlife|parking|doorstep>',
            'error')
        return
    end

    local ped  = PlayerPedId()
    local c    = GetEntityCoords(ped)
    local h    = GetEntityHeading(ped)
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z)) or '?'

    print(('^2[lieu]^7 Ligne à copier dans C.Locations.%s :'):format(cat))
    print(("        { coords = vector4(%.2f, %.2f, %.2f, %.1f), label = '%s', zone = 'downtown' },")
        :format(c.x, c.y, c.z, h, zone))
    print('^2[lieu]^7 Ajustez `zone` : affluent, downtown, urban, ' ..
        'residential, beach, industrial, park.')
    Notify('Emplacement capturé — la ligne est dans la console F8.', 'success')
end, false)

TriggerEvent('chat:addSuggestion', '/lieu',
    'Capturer un emplacement de mission', {
        { name = 'catégorie', help = 'street, residential, shop, dealpoint, nightlife, parking' },
    })

RegisterCommand('doorstep', function()
    local ped = PlayerPedId()
    local c   = GetEntityCoords(ped)
    local h   = GetEntityHeading(ped)
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z)) or '?'

    local line = ("        { coords = vector4(%.2f, %.2f, %.2f, %.1f), " ..
        "label = '%s', zone = 'residential' },"):format(c.x, c.y, c.z, h, zone)

    print('^2[seuil]^7 Ligne à copier dans C.Locations.doorstep :')
    print(line)
    print('^2[seuil]^7 Ajustez `zone` selon le quartier : affluent ' ..
        '(collines, Richman), urban (sud de Los Santos), beach, ' ..
        'residential par défaut.')
    Notify('Seuil capturé — la ligne est dans la console F8.', 'success')
end, false)

TriggerEvent('chat:addSuggestion', '/doorstep',
    'Capturer un seuil d\'habitation pour les constatations d\'effraction')

RegisterCommand('lacher', function()
    if not Escorting then
        Notify('Vous n\'accompagnez personne.', 'error')
        return
    end
    StopEscort()
    Notify('Vous cessez d\'accompagner la personne.', 'info')
end, false)

RegisterCommand('renfort', function()
    if not Callout then
        Notify('Vous n\'êtes engagé sur aucune intervention.', 'error')
        return
    end
    SendQ('police:callouts:requestBackup', {})
end, false)

-- Raccourci de demande de renfort
local lastBackupKey = 0

RegisterCommand('police_backup', function()
    if not Callout then return end

    -- Garde local : évite d'empiler des demandes dans la file d'envoi
    local now = GetGameTimer()
    if (now - lastBackupKey) < 2000 then return end
    lastBackupKey = now

    SendQ('police:callouts:requestBackup', {})
end, false)

RegisterKeyMapping('police_backup', 'Missions PNJ — demander des renforts',
    'keyboard', C.BackupKey or 'H')

RelayCommand('missionpnj')                 -- ouverte à tout policier
RelayCommand('missionpnjadmin', true)
RelayCommand('callout',         true)
RelayCommand('callouts',        true)

-- Raccourci du menu administrateur
RegisterCommand('police_admin_menu', function()
    if not IsAdminCached then return end
    if not AdminMenuUsed then
        Notify('Ouvrez d\'abord le menu avec /missionpnjadmin.', 'error')
        return
    end
    SendQ('police:callouts:command', { cmd = 'missionpnjadmin', args = {} })
end, false)

RegisterKeyMapping('police_admin_menu', 'Missions PNJ — menu administrateur',
    'keyboard', 'L')

TriggerEvent('chat:addSuggestion', '/missionpnj', 'Rejoindre ou quitter Police Secours (missions PNJ)')
TriggerEvent('chat:addSuggestion', '/statut', 'Statut radio sur l\'intervention en cours')
TriggerEvent('chat:addSuggestion', '/renfort', 'Demander des renforts sur l\'intervention en cours')
TriggerEvent('chat:addSuggestion', '/lacher', 'Cesser d\'accompagner l\'individu qui vous suit')
TriggerEvent('chat:addSuggestion', '/callout', 'Forcer / inspecter / clôturer un appel (admin)')
TriggerEvent('chat:addSuggestion', '/callouts', 'Activer ou désactiver les missions PNJ (admin)')

--  BASCULE D'ITINÉRAIRE — PERSONNE ERRANTE

CreateThread(function()
    while true do
        Wait(1500)
        if Callout and Callout.objective == 'hospital' then
            -- La personne est-elle à bord d'un véhicule ?
            local aboard = false
            for _, p in ipairs(Callout.peds or {}) do
                if p.role == 'wanderer' and p.state ~= 'delivered'
                   and NetworkDoesNetworkIdExist(p.netId) then
                    local e = NetworkGetEntityFromNetworkId(p.netId)
                    if e and e ~= 0 and DoesEntityExist(e)
                       and IsPedInAnyVehicle(e, false) then
                        aboard = true
                    end
                    break
                end
            end

            if aboard then
                -- Réappliqué en continu : les chiens de garde recréent
                for _, b in ipairs(CalloutBlips) do
                    if DoesBlipExist(b) then pcall(SetBlipRoute, b, false) end
                end
                local hb = StaticBlips['hospital']
                if hb and DoesBlipExist(hb) then
                    pcall(function()
                        SetBlipRoute(hb, true)
                        SetBlipRouteColour(hb, 2)
                    end)
                end
                if RouteSwitched ~= Callout.id then
                    RouteSwitched = Callout.id
                    Notify('Direction l\'hôpital — itinéraire mis à jour.', 'info')
                end

            elseif not aboard and RouteSwitched == Callout.id then
                -- Elle est ressortie du véhicule : on remet le cap sur
                RouteSwitched = nil
                local hb = StaticBlips['hospital']
                if hb and DoesBlipExist(hb) then pcall(SetBlipRoute, hb, false) end
                if CalloutBlips[1] and DoesBlipExist(CalloutBlips[1]) then
                    pcall(function()
                        SetBlipRoute(CalloutBlips[1], true)
                        SetBlipRouteColour(CalloutBlips[1], 3)
                    end)
                end
            end
        end
    end
end)

-- Chien de garde des PNJ fixes : tant qu'une intervention tourne, Mike
CreateThread(function()
    while true do
        Wait(5000)
        if Callout then
            if not StaticPeds['custody'] or not DoesEntityExist(StaticPeds['custody']) then
                StaticPeds['custody'] = nil
                TargetedStatics['custody'] = nil
                SpawnStaticNpc('custody')
                AttachCustodyTarget('custody', 'Présenter l\'individu', false)
            end
            if Callout.hospitalNpc then
                if not StaticPeds['hospital'] or not DoesEntityExist(StaticPeds['hospital']) then
                    StaticPeds['hospital'] = nil
                    TargetedStatics['hospital'] = nil
                    SpawnStaticNpc('hospital')
                    AttachCustodyTarget('hospital', 'Confier la personne à l\'hôpital', true)
                end
            end
        end
    end
end)

-- Chien de garde des blips : si une mission est active sans blip (event
CreateThread(function()
    while true do
        Wait(3000)
        if Callout and Callout.coords then
            local alive = false
            for _, b in ipairs(CalloutBlips) do
                if DoesBlipExist(b) then alive = true break end
            end
            if not alive then
                print('^3[callouts]^7 Blips absents pour l\'appel actif — recréation.')
                CreateCalloutBlips()
            end
            -- Relance l'upgrade vers le PNJ requérant : couvre le cas où
            RefreshCallerBlip()
        end
    end
end)

-- Détection automatique de l'arrivée sur zone (temps de réponse).
local onSceneFor = nil
CreateThread(function()
    while true do
        Wait(2000)
        if Callout and Callout.coords and onSceneFor ~= Callout.id then
            local d = #(GetEntityCoords(PlayerPedId())
                - vector3(Callout.coords.x, Callout.coords.y, Callout.coords.z))
            if d <= (Callout.searchRadius or 100.0) then
                onSceneFor = Callout.id
                SendQ('police:callouts:setStatus', { status = 'onscene' })
            end
        end
    end
end)

-- Rapport de l'heure in-game au serveur (il n'a pas d'horloge)
CreateThread(function()
    while true do
        Wait(60000)
        if IsOnDuty() then
            SendQ('police:callouts:reportHour', GetClockHours())
        end
    end
end)

--  MODE DEBUG

CreateThread(function()
    while true do
        Wait(0)
        if Callout and Callout.debug then
            local c = Callout.coords
            DrawMarker(1, c.x, c.y, c.z - 1.0, 0, 0, 0, 0, 0, 0,
                (Callout.searchRadius or 100.0) * 2, (Callout.searchRadius or 100.0) * 2, 1.0,
                0, 150, 255, 60, false, false, 2, false, nil, nil, false)

            for _, p in ipairs(Callout.peds or {}) do
                if NetworkDoesNetworkIdExist(p.netId) then
                    local e = NetworkGetEntityFromNetworkId(p.netId)
                    if e and e ~= 0 and DoesEntityExist(e) then
                        local pos = GetEntityCoords(e)
                        local st  = BrainState[p.netId] or {}
                        local txt = ('%s | %s/%s%s'):format(
                            p.label or '?', p.role or '?', p.state or '?',
                            p.weapon and (' | ' .. p.weapon) or '')
                        if st.fleeing then
                            local lbl = ({ 'sprint', 'essoufflé', 'à bout' })
                                [st.fleeStage or 1] or 'sprint'
                            txt = txt .. ('\nfuite %.0fs | %s'):format(
                                (GetGameTimer() - (st.fleeStart or GetGameTimer())) / 1000,
                                lbl)
                        end
                        SetTextScale(0.28, 0.28)
                        SetTextFont(4)
                        SetTextColour(255, 255, 255, 215)
                        SetTextCentre(true)
                        SetTextEntry('STRING')
                        AddTextComponentString(txt)
                        SetDrawOrigin(pos.x, pos.y, pos.z + 1.1, 0)
                        DrawText(0.0, 0.0)
                        ClearDrawOrigin()
                    end
                end
            end
        else
            Wait(500)
        end
    end
end)

--  PONT NUI — onglet MDT « Interventions »

local pending = {}
local reqSeq  = 0

LSLegacy.Events.Register('mdtco:queryResult', function(payload)
    if not payload or not payload.reqId then return end
    local cb = pending[payload.reqId]
    if not cb then return end
    pending[payload.reqId] = nil
    cb(payload.result)
end)

local function coQuery(action, data, cb)
    reqSeq = reqSeq + 1
    local id = reqSeq
    pending[id] = cb
    LSLegacy.Events.SendToServer('mdtco:query', { reqId = id, action = action, data = data })
    SetTimeout(15000, function()
        if pending[id] then pending[id] = nil cb(false) end
    end)
end

local function readCallback(nuiName, action)
    RegisterNUICallback(nuiName, function(data, cb)
        coQuery(action, type(data) == 'table' and data or {}, function(res)
            cb(res == nil and false or res)
        end)
    end)
end

readCallback('mdtco:getHistory',    'getHistory')
readCallback('mdtco:getStats',      'getStats')
readCallback('mdtco:getSummary',    'getSummary')
readCallback('mdtco:deleteCallout', 'deleteCallout')
readCallback('mdtco:resetStats',    'resetStats')
readCallback('mdtco:saveReport',    'saveReport')
readCallback('mdtco:closeCase',     'closeCase')

--  NETTOYAGE

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for key in pairs(StaticPeds) do
        if type(StaticPeds[key]) == 'number' and DoesEntityExist(StaticPeds[key]) then
            DeleteEntity(StaticPeds[key])
        end
    end
    for _, b in pairs(StaticBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    ClearCalloutBlips()
    StopAlarm()
end)
