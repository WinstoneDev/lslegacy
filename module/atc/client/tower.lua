-- Poste tour ATC : marqueur d'entrée, caméra fixe orientable à la souris, interface radar/strips (NUI).

local C = Config.ATC
local inTower = false
local cam = nil
-- Deux vues, chacune avec sa propre position et son propre cap souris (fenêtres différentes de la tour) :
-- radar = poste NUI, exterior = vue dégagée sur le tarmac (bascule TAB, cf. EnterTower/ApplyCamView).
local camState = {
    radar = { heading = C.Tower.heading, pitch = 0.0 },
    exterior = { heading = C.Tower.headingExterior or C.Tower.heading, pitch = 0.0 },
}

local function IsController()
    local pd = LSLegacy.PlayerData
    return pd and pd.job == C.Job and (tonumber(pd.job_grade) or 0) >= C.MinGrade
end

local function HelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- Données statiques (graphe/stands/pistes) envoyées une fois à l'ouverture : la NUI ne peut pas
-- lire Config directement, tout passe par postMessage.
local CATEGORY_ORDER = { commercial = 1, business = 2, heli = 3 }

local function InitData()
    local nodes, edges = {}, {}
    for id, n in pairs(Config.ATC.Graph.nodes) do
        nodes[id] = { x = n.x, y = n.y, type = n.type }
    end
    for _, e in ipairs(Config.ATC.Graph.edges) do
        -- Table purement positionnelle (pas de clé nommée) : un champ `kind=` mélangé aux index 1/2
        -- fait basculer l'encodage JSON de SendNUIMessage en objet ({"1":...}) au lieu d'un tableau,
        -- ce qui cassait totalement le rendu du radar (e[0]/e[1] valaient undefined côté NUI).
        edges[#edges + 1] = { e[1], e[2], e.kind }
    end
    local stands = {}
    for _, s in ipairs(C.Stands) do
        stands[#stands + 1] = { id = s.id, x = s.coords.x, y = s.coords.y, category = s.category }
    end
    local runways = {}
    for id, q in pairs(C.Qfu) do
        runways[id] = { x = q.threshold.x, y = q.threshold.y, heading = q.heading }
    end
    -- Triée (commercial > affaires > héli) pour que le modèle sélectionné par défaut dans la NUI
    -- soit toujours commercial, et donc que la liste de stands par défaut montre les C1-C10.
    local aircraft = {}
    for model, ac in pairs(C.Aircraft) do
        aircraft[#aircraft + 1] = { model = model, label = ac.label, category = ac.category }
    end
    table.sort(aircraft, function(a, b)
        local oa, ob = CATEGORY_ORDER[a.category] or 9, CATEGORY_ORDER[b.category] or 9
        if oa ~= ob then return oa < ob end
        return a.model < b.model
    end)
    local runwayConfigs = {}
    for _, cfg in ipairs(C.RunwayConfigs) do runwayConfigs[#runwayConfigs + 1] = cfg.id end
    -- Points d'attente sélectionnables au taxi (NUI) : id + piste physique protégée + libellé court.
    local holdingPoints = {}
    for id, n in pairs(Config.ATC.Graph.nodes) do
        if n.type == 'holding' then
            holdingPoints[#holdingPoints + 1] = { id = id, protects = n.protects, label = id:gsub('^HP_', ''):gsub('_%d+[LR]?$', '') }
        end
    end
    local qfuRunway = {}
    for qfu, q in pairs(C.Qfu) do qfuRunway[qfu] = q.runway end
    return {
        nodes = nodes, edges = edges, stands = stands, runways = runways, aircraft = aircraft,
        exclusions = C.StandExclusions, runwayConfigs = runwayConfigs,
        holdingPoints = holdingPoints, qfuRunway = qfuRunway,
    }
end

local radarView = true -- true = écran radar (NUI visible) ; false = vue extérieure (NUI masqué, caméra déplacée)

-- Repositionne la caméra sur la vue active (position + cap/pitch propres à cette vue).
local function ApplyCamView()
    local pos = radarView and C.Tower.cam or (C.Tower.camExterior or C.Tower.cam)
    local st = radarView and camState.radar or camState.exterior
    SetCamCoord(cam, pos.x, pos.y, pos.z)
    SetCamRot(cam, st.pitch, 0.0, st.heading, 2)
end

local function LeaveTower()
    if not inTower then return end
    inTower = false
    ATC.RadarActive = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'atc:hide' })
    RenderScriptCams(false, false, 0, true, false)
    if cam then DestroyCam(cam, false); cam = nil end
    DisplayRadar(true)
    FreezeEntityPosition(PlayerPedId(), false)
    LSLegacy.Events.SendToServer('atc:tower:leave')
end

local function EnterTower()
    if inTower then return end
    inTower = true
    radarView = true
    camState.radar.heading, camState.radar.pitch = C.Tower.heading, 0.0
    camState.exterior.heading, camState.exterior.pitch = C.Tower.headingExterior or C.Tower.heading, 0.0
    FreezeEntityPosition(PlayerPedId(), true)
    DisplayRadar(false)
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    ApplyCamView()
    SetCamFov(cam, C.Tower.fov)
    RenderScriptCams(true, false, 0, true, false)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true) -- la souris reste lisible côté jeu pour orienter la caméra en gardant les clics NUI
    SendNUIMessage({ action = 'atc:open', data = InitData() })
    ATC.RadarActive = true
    LSLegacy.Events.SendToServer('atc:tower:enter')
end

-- Bascule écran radar / vue extérieure (vitre de la tour) : ne cache/affiche que le canvas radar,
-- la caméra 3D tourne déjà en continu derrière quel que soit le mode.
RegisterKeyMapping('atc_toggleview', 'ATC : basculer vue radar / vue extérieure', 'keyboard', 'TAB')
RegisterCommand('atc_toggleview', function()
    if not inTower then return end
    radarView = not radarView
    ApplyCamView()
    SendNUIMessage({ action = 'atc:view', radar = radarView })
end, false)

-- ── Marqueur d'entrée ────────────────────────────────────────────
CreateThread(function()
    while true do
        local sleep = 500
        if not inTower then
            local pos = GetEntityCoords(PlayerPedId())
            local dist = #(pos - C.Entry.coords)
            if dist < C.Entry.drawDistance and IsController() then
                sleep = 0
                local m = C.Entry.marker
                DrawMarker(m.type, C.Entry.coords.x, C.Entry.coords.y, C.Entry.coords.z - 0.9, 0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0, m.size.x, m.size.y, m.size.z, m.color.r, m.color.g, m.color.b, m.color.a,
                    false, true, 2, false, nil, nil, false)
                if dist < C.Entry.radius then
                    HelpText('Appuyez sur ~INPUT_CONTEXT~ pour prendre le poste ATC')
                    if IsControlJustReleased(0, 38) then EnterTower() end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ── Caméra : rotation à la souris (clic gauche maintenu) ────────
CreateThread(function()
    while true do
        local time = 1000
        if inTower then
            time = 0
            HideHudAndRadarThisFrame()
            DisablePlayerFiring(PlayerPedId(), true)
            DisableControlAction(0, 24, true)  -- attaque / clic gauche (usage caméra, pas de tir)
            DisableControlAction(0, 25, true)  -- visée
            DisableControlAction(0, 37, true)  -- roue des armes
            if IsControlPressed(0, 24) then
                local dx = GetDisabledControlNormal(0, 1)
                local dy = GetDisabledControlNormal(0, 2)
                local st = radarView and camState.radar or camState.exterior
                st.heading = (st.heading - dx * 200.0 * C.Tower.mouseSensitivity + 360.0) % 360.0
                st.pitch = math.max(C.Tower.pitchMin, math.min(C.Tower.pitchMax, st.pitch - dy * 200.0 * C.Tower.mouseSensitivity))
                SetCamRot(cam, st.pitch, 0.0, st.heading, 2)
            end
        end
        Wait(time)
    end
end)

-- ── NUI ⇄ serveur ────────────────────────────────────────────────
RegisterNUICallback('atc:close', function(_, cb) LeaveTower(); cb('ok') end)

RegisterNUICallback('atc:clearance', function(data, cb)
    LSLegacy.Events.SendToServer('atc:clearance', data.id, data.clearance, data.arg)
    cb('ok')
end)

RegisterNUICallback('atc:spawnDeparture', function(data, cb)
    LSLegacy.Events.SendToServer('atc:nui:spawnDeparture', data.stand, data.model)
    cb('ok')
end)

RegisterNUICallback('atc:spawnArrival', function(data, cb)
    LSLegacy.Events.SendToServer('atc:nui:spawnArrival', data.model)
    cb('ok')
end)

RegisterNUICallback('atc:delete', function(data, cb)
    LSLegacy.Events.SendToServer('atc:nui:delete', data.id)
    cb('ok')
end)

RegisterNUICallback('atc:setRunwayConfig', function(data, cb)
    LSLegacy.Events.SendToServer('atc:nui:setRunwayConfig', data.id)
    cb('ok')
end)

RegisterNUICallback('atc:setDynamicSpawn', function(data, cb)
    LSLegacy.Events.SendToServer('atc:nui:setDynamicSpawn', data.enabled)
    cb('ok')
end)

LSLegacy.Events.Register('atc:tower:state', function(list, metar, cfg, dynSpawn)
    SendNUIMessage({ action = 'atc:state', flights = list, metar = metar, config = cfg, dynamicSpawn = dynSpawn })
end)

LSLegacy.Events.Register('atc:flight:removed', function(id)
    SendNUIMessage({ action = 'atc:removeFlight', id = id })
end)

LSLegacy.Events.Register('atc:metar:update', function(metar, cfg)
    SendNUIMessage({ action = 'atc:metar', metar = metar, config = cfg })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if inTower then LeaveTower() end
end)

CreateThread(function()
    while true do
        Wait(10000)
        SetPedModelIsSuppressed(1644266841, true)
    end
end)
