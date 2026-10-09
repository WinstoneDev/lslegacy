-- Pilote cinématique des avions IA (client contrôleur). Aucune physique : position/cap interpolés
-- le long des nœuds du graphe, la piste et la montée sont calculées depuis le QFU en service.

local C = Config.ATC
local S = ATC.State
local drivers = {}   -- flightId -> driver
local towerPos = C.Tower.cam

local ACCEL, DECEL, YAW_RATE = 1.2, 1.6, 22.0     -- m/s², m/s², °/s au sol
local TO_ACCEL, CLIMB_PITCH = 3.8, 12.0
local GEAR_UP_ALT = 25.0

-- Approche classique : mise en ligne droite à 10 NM du seuil, axe et descente déjà établis.
local APPROACH_DIST = 18520.0   -- 10 NM
local FINAL_DIST = 7408.0       -- 4 NM : annonce "en finale" + LAND devient possible sous cette distance
local GLIDE_TAN = math.tan(math.rad(3.0))

-- speaker : 'ATC' (contrôleur, vert, commence toujours par l'indicatif) ou 'PILOT' (jaune ; commence
-- par l'indicatif pour une annonce/nouvelle demande, finit par l'indicatif pour une réponse/lecture).
local function Radio(text, speaker)
    speaker = speaker or 'PILOT'
    TriggerEvent('notify', 'RADIO', text, speaker == 'ATC' and 'info' or 'warning')
    if ATC.RadarActive then SendNUIMessage({ action = 'atc:radio', text = text, speaker = speaker }) end
end

local function Report(d, state, node)
    d.state = state
    LSLegacy.Events.SendToServer('atc:flight:state', d.id, state, node)
end

local function StandById(id)
    for _, s in ipairs(C.Stands) do if s.id == id then return s end end
end

local function NodePos(id)
    local n = ATC.Graph.Node(id)
    return n and vector3(n.x, n.y, n.z) or nil
end

-- Polyline depuis une liste d'ids (ou de vecteurs).
local function BuildPolyline(items)
    local pts, total = {}, 0.0
    for i, it in ipairs(items) do
        local p = type(it) == 'string' and NodePos(it) or it
        if p then
            pts[#pts + 1] = { pos = p, id = type(it) == 'string' and it or nil, s = total }
            if #pts > 1 then
                local prev = pts[#pts - 1]
                total = total + #(vector2(p.x, p.y) - vector2(prev.pos.x, prev.pos.y))
                pts[#pts].s = total
            end
        end
    end
    return pts, total
end

-- Point et direction à l'abscisse s sur la polyline.
local function Sample(pts, s)
    for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        if s <= b.s or i == #pts - 1 then
            local seg = b.s - a.s
            local t = seg > 0 and math.max(0.0, math.min(1.0, (s - a.s) / seg)) or 1.0
            local p = a.pos + (b.pos - a.pos) * t
            local dx, dy = b.pos.x - a.pos.x, b.pos.y - a.pos.y
            return p, dx, dy, i
        end
    end
    local last = pts[#pts]
    return last.pos, 0.0, 0.0, #pts
end

-- Vitesse maximale admise à l'abscisse s : fin de trajet + freinage avant virages.
local function SpeedLimit(d, s)
    local limit = d.cruise
    local remaining = d.total - s
    limit = math.min(limit, math.sqrt(2.0 * DECEL * math.max(0.0, remaining)))
    for i = 2, #d.pts - 1 do
        local ahead = d.pts[i].s - s
        if ahead > -2.0 and ahead < 60.0 then
            local a, b, c = d.pts[i - 1].pos, d.pts[i].pos, d.pts[i + 1].pos
            local h1 = ATC.Geo.DirToHeading(b.x - a.x, b.y - a.y)
            local h2 = ATC.Geo.DirToHeading(c.x - b.x, c.y - b.y)
            local turn = math.abs(ATC.Geo.AngleDiff(h1, h2))
            if turn > 8.0 then
                local vCorner = math.max(2.5, d.cruise * (1.0 - math.min(turn, 110.0) / 130.0))
                limit = math.min(limit, math.sqrt(vCorner * vCorner + 2.0 * DECEL * math.max(0.0, ahead)))
            end
        end
    end
    return math.max(limit, 0.0)
end

local function SafeDelete(veh)
    if not DoesEntityExist(veh) then return end
    if not NetworkHasControlOfEntity(veh) then
        NetworkRequestControlOfEntity(veh)
        local t = GetGameTimer()
        while not NetworkHasControlOfEntity(veh) and GetGameTimer() - t < 1000 do Wait(0) end
    end
    if DoesEntityExist(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteEntity(veh)
    end
end

local function Place(d, pos, heading, pitch)
    SetEntityCoordsNoOffset(d.veh, pos.x, pos.y, pos.z + d.zOffset, false, false, false)
    if pitch then SetEntityRotation(d.veh, pitch, 0.0, heading, 2, true) else SetEntityHeading(d.veh, heading) end
end

local function SetPath(d, ids, mode, stopShort)
    local items = {}
    local first = type(ids[1]) == 'string' and NodePos(ids[1]) or ids[1]
    local cur = GetEntityCoords(d.veh) - vector3(0, 0, d.zOffset)
    if first and #(vector2(cur.x, cur.y) - vector2(first.x, first.y)) > 1.0 then items[1] = vector3(cur.x, cur.y, first.z) end
    for _, it in ipairs(ids) do items[#items + 1] = it end
    d.pts, d.total = BuildPolyline(items)
    -- Arrêt avec le nez avant la ligne (position = centre de l'avion).
    if stopShort then d.total = math.max(0.0, d.total - stopShort) end
    d.s = 0.0
    d.mode = mode
    d.pathIds = ids
    d.reverse = mode == 'pushback'
end

-- ── Ordres ───────────────────────────────────────────────────────
-- Pushback : recule le long de l'itinéraire de roulage réel (garanti sur du vrai revêtement) jusqu'au
-- point de recul propre au stand (Config.ATC.PushbackTargets), puis oriente le nez dans le sens
-- demandé le long du taxiway d'arrivée (le virage final du tractage).
local function PushbackTarget(d)
    local t = C.PushbackTargets[d.stand]
    if not t then return nil end
    return t.node and t or t[d.runway]
end

-- Voisin du même groupe de taxiway dont le numéro est immédiatement inférieur ('desc') ou supérieur ('asc').
local function ChainNeighbor(nodeId, dir)
    local n = ATC.Graph.Node(nodeId)
    local num = n and tonumber(nodeId:match('%d+$'))
    if not num then return nil end
    local want = dir == 'asc' and (num + 1) or (num - 1)
    for _, e in ipairs(ATC.Graph.Neighbors(nodeId)) do
        local nb = ATC.Graph.Node(e.to)
        if nb and nb.group == n.group and tonumber(e.to:match('%d+$')) == want then return e.to end
    end
    return nil
end

local function OrderPushback(d)
    d.pendingHoldNode = nil
    local t = PushbackTarget(d)
    if not t then return Radio(d.callsign .. ', unable pushback') end
    local route
    if t.via then
        local r1 = ATC.Graph.Path(d.node, t.via)
        local r2 = r1 and ATC.Graph.Path(t.via, t.node)
        if not r1 or not r2 then return Radio(d.callsign .. ', unable pushback, no route') end
        route = r1
        for i = 2, #r2 do route[#route + 1] = r2[i] end
    else
        route = ATC.Graph.Path(d.node, t.node)
    end
    if not route or #route < 2 then return Radio(d.callsign .. ', unable pushback, no route') end
    local nx, ny = ATC.Geo.HeadingToDir(d.heading)
    local cur = GetEntityCoords(d.veh)
    local a1 = ATC.Graph.Node(route[2])
    if (a1.x - cur.x) * nx + (a1.y - cur.y) * ny > -1.0 then
        return Radio(d.callsign .. ', unable pushback, no stand line')
    end
    local chain = {}
    for i = 1, #route do chain[i] = route[i] end
    -- Virage final : un point virtuel décalé côté voisin cible amorce la rotation visuelle du nez ;
    -- le cap exact est de toute façon réappliqué explicitement à l'arrêt (d.pushFinalHeading) pour
    -- ne pas dépendre d'un rattrapage progressif qui peut rester court sur un virage proche de 180°.
    local nb = ChainNeighbor(t.node, t.dir)
    d.pushFinalHeading = nil
    if nb then
        local tp, np = ATC.Graph.Node(t.node), ATC.Graph.Node(nb)
        local dx, dy = tp.x - np.x, tp.y - np.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            chain[#chain] = vector3(tp.x - dx / len * 3.0, tp.y - dy / len * 3.0, tp.z)
            chain[#chain + 1] = vector3(tp.x, tp.y, tp.z)
            d.pushFinalHeading = ATC.Geo.DirToHeading(np.x - tp.x, np.y - tp.y)
        end
    end
    d.pushJunction = t.node
    SetPath(d, chain, 'pushback')
    d.speed = 0.0
    d.cruise = 6.0
    Report(d, S.PUSHBACK, d.node)
    Radio(('%s, pushback approved, face runway %s'):format(d.callsign, d.runway), 'ATC')
end

-- Hélicoptères : pas de réseau de taxiway vers les hélistations (H1-H3), trajet direct au sol
-- entre la position courante et le stand cible (bypass A*).
local function OrderHeliTaxi(d, target)
    local standId = target and target:match('^STAND_(.+)$')
    local stand = standId and StandById(standId)
    if not stand then return Radio(d.callsign .. ', unable, no taxi target') end
    SetPath(d, { d.pos, vector3(stand.coords.x, stand.coords.y, stand.coords.z) }, 'helipark')
    d.speed = 0.0
    d.cruise = (C.Aircraft[d.model].taxiSpeed or 15) / 3.6
    d.node = nil
    Report(d, S.TAXI, nil)
    Radio(('%s, taxi to helipad %s'):format(d.callsign, standId), 'ATC')
end

-- Nombre d'avions déjà arrêtés à ce nœud (point d'attente) ou en route vers lui : la file se fait à la
-- queue leu leu, chaque nouvel arrivant est arrêté plus tôt le long du même taxiway (pas superposé).
local QUEUE_GAP = 14.0
local function QueuedAhead(nodeId, exceptId)
    local n = 0
    for id, o in pairs(drivers) do
        if id ~= exceptId and (o.node == nodeId and o.mode == 'idle' or o.pendingHoldNode == nodeId) then
            n = n + 1
        end
    end
    return n
end

local function OrderTaxi(d, target)
    -- Sans cible explicite (NUI, départ) : ligne up de la piste en service.
    target = target or (C.Qfu[d.runway] and C.Qfu[d.runway].lineupNode)
    if not target then return Radio(d.callsign .. ', unable, no taxi target') end
    if C.Aircraft[d.model].heli then return OrderHeliTaxi(d, target) end
    d.pendingHoldNode = nil
    local from = d.node
    local path = ATC.Graph.Path(from, target, { runwayPenalty = 6.0 })
    if not path or #path < 2 then return Radio(d.callsign .. ', unable, no taxi route to ' .. tostring(target)) end
    -- Arrêt au premier point d'attente rencontré (hors départ), la suite attend une nouvelle clairance.
    local hp = ATC.Graph.FirstHoldingIndex(path, 2)
    d.fullPath = path
    d.stopIndex = hp or #path
    local ids = {}
    for i = 1, d.stopIndex do ids[i] = path[i] end
    local endNode = ATC.Graph.Node(ids[#ids])
    local stopShort
    if endNode.type == 'holding' then
        local queue = QueuedAhead(ids[#ids], d.id)
        stopShort = d.length * 0.5 + 4.0 + queue * QUEUE_GAP
        d.pendingHoldNode = ids[#ids]
    end
    SetPath(d, ids, 'taxi', stopShort)
    d.speed = 0.0
    d.cruise = (C.Aircraft[d.model].taxiSpeed or 20) / 3.6
    d.taxiTarget = target
    Report(d, S.TAXI, d.node)
    local hpName = hp and path[hp]:gsub('^HP_', ''):gsub('_%d+[LR]?$', '') or target
    Radio(('%s, taxi to holding point %s, runway %s'):format(d.callsign, hpName, d.runway), 'ATC')
end

local function OrderCross(d)
    if not d.fullPath or d.stopIndex >= #d.fullPath then return Radio(d.callsign .. ', unable cross') end
    d.pendingHoldNode = nil
    local nextHp = ATC.Graph.FirstHoldingIndex(d.fullPath, d.stopIndex + 1)
    local newStop = nextHp or #d.fullPath
    local ids = {}
    for i = d.stopIndex, newStop do ids[#ids + 1] = d.fullPath[i] end
    d.stopIndex = newStop
    local endNode = ATC.Graph.Node(ids[#ids])
    local stopShort
    if endNode.type == 'holding' then
        local queue = QueuedAhead(ids[#ids], d.id)
        stopShort = d.length * 0.5 + 4.0 + queue * QUEUE_GAP
        d.pendingHoldNode = ids[#ids]
    end
    SetPath(d, ids, 'taxi', stopShort)
    d.speed = 0.0
    d.cruise = (C.Aircraft[d.model].taxiSpeed or 20) / 3.6
    Report(d, S.TAXI, d.node)
    Radio(('Crossing runway, %s'):format(d.callsign), 'PILOT')
end

local function OrderLineUp(d)
    d.pendingHoldNode = nil
    local rwyNode = ATC.RunwayNodeForHolding(d.node)
    if not rwyNode then return Radio(d.callsign .. ', unable line up from here') end
    local qh = ATC.QfuHeading(d.runway)
    local dx, dy = ATC.Geo.HeadingToDir(qh)
    local p = NodePos(rwyNode)
    local ahead = vector3(p.x + dx * 30.0, p.y + dy * 30.0, p.z)
    SetPath(d, { d.node, rwyNode, ahead }, 'lineup')
    d.speed = 0.0
    d.cruise = 6.0
    d.rwyNode = rwyNode
    Report(d, S.LINE_UP, d.node)
    Radio(('Lining up runway %s, %s'):format(d.runway, d.callsign), 'PILOT')
end

local function OrderTakeoff(d)
    d.mode = 'takeoff'
    d.speed = math.max(d.speed, 0.0)
    d.heading = ATC.QfuHeading(d.runway)
    d.pos = GetEntityCoords(d.veh) - vector3(0, 0, d.zOffset)
    d.groundZ = d.pos.z
    d.climbing = false
    Report(d, S.TAKEOFF, d.node)
    Radio(('%s, cleared for takeoff runway %s'):format(d.callsign, d.runway), 'ATC')
end

-- ── Boucle de mouvement ──────────────────────────────────────────
local function TickGround(d, dt)
    if d.held then
        if d.speed > 0.0 then d.speed = math.max(0.0, d.speed - DECEL * dt) end
        return
    end
    local limit = SpeedLimit(d, d.s)
    if d.speed < limit then d.speed = math.min(limit, d.speed + ACCEL * dt)
    else d.speed = math.max(limit, d.speed - DECEL * dt) end
    d.s = math.min(d.total, d.s + d.speed * dt)
    local p, dx, dy, segIdx = Sample(d.pts, d.s)
    local targetH = d.heading
    if dx ~= 0.0 or dy ~= 0.0 then
        targetH = ATC.Geo.DirToHeading(dx, dy)
        if d.reverse then targetH = (targetH + 180.0) % 360.0 end
    end
    local diff = ATC.Geo.AngleDiff(d.heading, targetH)
    local maxStep = YAW_RATE * dt * math.max(0.35, math.min(1.0, d.speed / 4.0))
    d.heading = (d.heading + math.max(-maxStep, math.min(maxStep, diff)) + 360.0) % 360.0
    d.pos = p
    Place(d, p, d.heading)
    -- Nœud courant = dernier nœud franchi.
    local reached = d.pts[segIdx]
    if reached and reached.id and reached.id ~= d.node and (d.s >= reached.s) then d.node = reached.id end
    if d.s >= d.total - 0.05 and d.speed < 0.3 then
        d.speed = 0.0
        local last = d.pts[#d.pts]
        if last.id then d.node = last.id end
        if d.mode == 'pushback' then
            d.mode = 'idle'; d.reverse = false
            d.node = d.pushJunction or d.node
            if d.pushFinalHeading then
                d.heading = d.pushFinalHeading
                Place(d, d.pos, d.heading)
            end
            Report(d, S.PUSHBACK, d.node) -- reste en PUSHBACK jusqu'à la clairance taxi
        elseif d.mode == 'taxi' then
            d.mode = 'idle'
            d.pendingHoldNode = nil -- arrivé : compte désormais via node+idle dans QueuedAhead
            local n = ATC.Graph.Node(d.node)
            if n and n.type == 'stand' then
                Report(d, S.PARKING, d.node)
                Radio(('%s, at the gate, thank you'):format(d.callsign))
                SetTimeout(15000, function()
                    if drivers[d.id] == d and d.mode == 'idle' then
                        d.mode = 'despawn'
                        Report(d, S.DESPAWN, nil)
                    end
                end)
            elseif n and n.type == 'holding' then
                Report(d, S.HOLD_SHORT, d.node)
                Radio(('%s, holding short runway %s'):format(d.callsign, d.runway))
            else
                Report(d, S.HOLD_SHORT, d.node)
            end
        elseif d.mode == 'rollout' then
            d.mode = 'idle'
            Report(d, S.VACATING, d.node)
            Radio(('%s, runway vacated, contact ground'):format(d.callsign))
        elseif d.mode == 'helipark' then
            d.mode = 'idle'
            Report(d, S.PARKING, d.node)
            Radio(('%s, on the pad, thank you'):format(d.callsign))
            SetTimeout(15000, function()
                if drivers[d.id] == d and d.mode == 'idle' then
                    d.mode = 'despawn'
                    Report(d, S.DESPAWN, nil)
                end
            end)
        elseif d.mode == 'lineup' then
            d.mode = 'idle'
            d.node = d.rwyNode
            Report(d, S.LINED_UP, d.node)
            Radio(('%s, lined up runway %s, ready for departure'):format(d.callsign, d.runway))
        end
    end
end

local function TickTakeoff(d, dt)
    local ac = C.Aircraft[d.model]
    local dx, dy = ATC.Geo.HeadingToDir(d.heading)
    local rotate = (ac.rotateSpeed or 220) / 3.6
    local vmax = ((ac.approachSpeed or 240) * 1.3) / 3.6
    d.speed = math.min(vmax, d.speed + TO_ACCEL * dt)
    local z, pitch = d.groundZ, 0.0
    if not d.climbing and d.speed >= rotate then
        d.climbing = true
        Report(d, S.CLIMB, nil)
    end
    if d.climbing then
        d.alt = (d.alt or 0.0) + (ac.climbRate or 10) * dt
        z = d.groundZ + d.alt
        pitch = CLIMB_PITCH
        if not d.gearUp and d.alt > GEAR_UP_ALT then
            d.gearUp = true
            ControlLandingGear(d.veh, 1)
        end
    end
    d.pos = vector3(d.pos.x + dx * d.speed * dt, d.pos.y + dy * d.speed * dt, z)
    Place(d, d.pos, d.heading, pitch)
    if #(vector2(d.pos.x, d.pos.y) - vector2(towerPos.x, towerPos.y)) > C.SimulationRadius then
        d.mode = 'despawn'
        Report(d, S.DESPAWN, nil)
        Radio(('%s leaving the zone, contact departure, good day'):format(d.callsign))
    end
end

-- Premier point d'entrée d'un taxiway/piste appartenant à un groupe donné (le nœud le plus proche
-- du seuil, dans le sens d'atterrissage) : sert à choisir la sortie de piste après le toucher.
local function PickExit(q)
    ATC.Graph.Node(q.lineupNode) -- s'assure que le graphe est construit
    local dx, dy = ATC.Geo.HeadingToDir(q.heading)
    local best, bestProj
    for id, n in pairs(ATC.Graph.nodes) do
        if n.type == 'exit' and n.runway == q.runway and id ~= q.lineupNode then
            local proj = (n.x - q.threshold.x) * dx + (n.y - q.threshold.y) * dy
            if proj > 300.0 and (not bestProj or proj < bestProj) then best, bestProj = id, proj end
        end
    end
    return best
end

local function OrderGoAround(d)
    local q = Config.ATC.Qfu[d.runway]
    d.mode = 'takeoff'
    d.groundZ = q.threshold.z
    d.alt = math.max(0.0, d.pos.z - d.groundZ)
    d.climbing = d.alt > 0.5
    d.gearUp = false
    Report(d, S.CLIMB, nil)
    Radio(('%s, going around'):format(d.callsign), 'PILOT')
end

-- Lève le gel de l'approche : le pilote a annoncé l'ILS/l'axe en arrivant, le contrôleur
-- l'autorise à poursuivre. L'avion ne bouge pas tant que cette clairance n'a pas été donnée.
local function OrderContinueApproach(d)
    d.holding = false
    Radio(('%s, continue approach runway %s'):format(d.callsign, d.runway), 'ATC')
end

local function OrderLand(d)
    d.landClear = true
    Report(d, S.LANDING, d.node)
    Radio(('%s, cleared to land runway %s'):format(d.callsign, d.runway), 'ATC')
end

local function TickApproach(d, dt)
    if d.holding then return end
    local q = Config.ATC.Qfu[d.runway]
    local ac = C.Aircraft[d.model]
    local dx, dy = ATC.Geo.HeadingToDir(q.heading)
    d.pos = vector3(d.pos.x + dx * d.speed * dt, d.pos.y + dy * d.speed * dt, d.pos.z)
    local remaining = (q.threshold.x - d.pos.x) * dx + (q.threshold.y - d.pos.y) * dy
    local vTarget = (d.state == S.LANDING and ac.touchdownSpeed or ac.approachSpeed or 240) / 3.6
    d.speed = d.speed + (vTarget - d.speed) * math.min(1.0, dt * 0.25)
    local alt = math.max(0.0, remaining) * GLIDE_TAN
    d.pos = vector3(d.pos.x, d.pos.y, q.threshold.z + alt)
    Place(d, d.pos, d.heading, alt > 0.5 and -3.0 or 0.0)
    if d.state == S.APPROACH and remaining < FINAL_DIST then
        Report(d, S.FINAL, nil)
        Radio(('%s established, runway %s in sight'):format(d.callsign, d.runway))
    end
    if remaining <= 0.0 then
        if not d.landClear then return OrderGoAround(d) end
        d.pos = vector3(d.pos.x, d.pos.y, q.threshold.z)
        local exitNode = PickExit(q)
        local route = exitNode and ATC.Graph.Path(q.lineupNode, exitNode, { runwayPenalty = 1.0 })
        d.node = q.lineupNode
        SetPath(d, (route and #route >= 2) and route or { q.lineupNode, exitNode or q.lineupNode }, 'rollout')
        d.cruise = (ac.touchdownSpeed or 200) / 3.6
        Report(d, S.ROLLOUT, d.node)
        Radio(('%s, runway vacated shortly, contact ground when clear'):format(d.callsign))
    end
end

CreateThread(function()
    while true do
        local active = false
        local dt = GetFrameTime()
        for id, d in pairs(drivers) do
            if d.mode == 'despawn' then
                SafeDelete(d.veh)
                drivers[id] = nil
            elseif not DoesEntityExist(d.veh) then
                drivers[id] = nil
            elseif d.mode == 'takeoff' then
                active = true; TickTakeoff(d, dt)
            elseif d.mode == 'approach' then
                active = true; TickApproach(d, dt)
            elseif d.mode == 'taxi' or d.mode == 'pushback' or d.mode == 'lineup' or d.mode == 'rollout' or d.mode == 'helipark' then
                active = true; TickGround(d, dt)
            end
        end
        Wait(active and 0 or 250)
    end
end)

-- ── Spawn / ordres serveur ───────────────────────────────────────
LSLegacy.Events.Register('atc:flight:spawn', function(f, stand)
    local model = joaat(f.model)
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) and GetGameTimer() - t < 10000 do Wait(50) end
    if not HasModelLoaded(model) then return Radio('Model load failed: ' .. f.model) end
    local dx, dy = ATC.Geo.HeadingToDir(stand.heading)
    local off = stand.spawnOffsetY or 0.0
    local x, y, z = stand.coords.x + dx * off, stand.coords.y + dy * off, stand.coords.z
    local mn, mx = GetModelDimensions(model)
    local length = mx.y - mn.y
    local veh = CreateVehicle(model, x, y, z, stand.heading, true, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityAsMissionEntity(veh, true, true)
    Entity(veh).state:set('lsiaAtc', true, true)
    SetVehicleOnGroundProperly(veh)
    Wait(100)
    local zOffset = GetEntityCoords(veh).z - z
    FreezeEntityPosition(veh, true)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleLights(veh, 2)
    if f.model == 'jet' then SetVehicleLivery(veh, math.random(0, math.max(0, GetVehicleLiveryCount(veh) - 1))) end
    drivers[f.id] = {
        id = f.id, callsign = f.callsign, model = f.model, kind = f.kind, runway = f.runway, veh = veh,
        node = f.node, state = f.state, mode = 'idle', speed = 0.0, heading = stand.heading,
        pos = vector3(x, y, z), zOffset = zOffset, cruise = 0.0, length = length, stand = stand.id,
    }
    LSLegacy.Events.SendToServer('atc:flight:spawned', f.id, NetworkGetNetworkIdFromEntity(veh))
    Radio(('%s, %s, stand %s, request clearance'):format(f.callsign, C.Aircraft[f.model].label, stand.id))
end)

-- Arrivée : mise en ligne droite à 10 NM du seuil (+ décalage par arrivée déjà en approche sur la même
-- piste, cf. ArrivalSpacing/queue) alignée et descendant déjà sur l'axe (approche classique).
LSLegacy.Events.Register('atc:flight:spawnArrival', function(f, queue)
    local model = joaat(f.model)
    RequestModel(model)
    local t = GetGameTimer()
    while not HasModelLoaded(model) and GetGameTimer() - t < 10000 do Wait(50) end
    if not HasModelLoaded(model) then return Radio('Model load failed: ' .. f.model) end
    local q = Config.ATC.Qfu[f.runway]
    local ac = C.Aircraft[f.model]
    local dx, dy = ATC.Geo.HeadingToDir(q.heading)
    local dist = APPROACH_DIST + (queue or 0) * C.ArrivalSpacing
    local x, y = q.threshold.x - dx * dist, q.threshold.y - dy * dist
    local z = q.threshold.z + dist * GLIDE_TAN
    local mn, mx = GetModelDimensions(model)
    local length = mx.y - mn.y
    local veh = CreateVehicle(model, x, y, z, q.heading, true, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityAsMissionEntity(veh, true, true)
    Entity(veh).state:set('lsiaAtc', true, true)
    FreezeEntityPosition(veh, true)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleLights(veh, 2)
    if f.model == 'jet' then SetVehicleLivery(veh, math.random(0, math.max(0, GetVehicleLiveryCount(veh) - 1))) end
    drivers[f.id] = {
        id = f.id, callsign = f.callsign, model = f.model, kind = f.kind, runway = f.runway, veh = veh,
        node = nil, state = f.state, mode = 'approach', speed = (ac.approachSpeed or 240) / 3.6,
        heading = q.heading, pos = vector3(x, y, z), zOffset = 0.0, cruise = 0.0, length = length,
        holding = true,
    }
    LSLegacy.Events.SendToServer('atc:flight:spawned', f.id, NetworkGetNetworkIdFromEntity(veh))
    Radio(('%s, %s, 10 miles, request approach runway %s'):format(f.callsign, ac.label, f.runway))
end)

LSLegacy.Events.Register('atc:flight:order', function(id, clearance, arg)
    local d = drivers[id]
    if not d then return end
    if clearance == 'PUSHBACK' then OrderPushback(d)
    elseif clearance == 'TAXI' then OrderTaxi(d, arg)
    elseif clearance == 'CROSS' then OrderCross(d)
    elseif clearance == 'LINE_UP' then OrderLineUp(d)
    elseif clearance == 'TAKEOFF' then
        if C.Aircraft[d.model].heli then OrderTakeoff(d)
        elseif d.state ~= S.LINED_UP then OrderLineUp(d); d.pendingTakeoff = true
        else OrderTakeoff(d) end
    elseif clearance == 'LAND' then OrderLand(d)
    elseif clearance == 'GO_AROUND' then OrderGoAround(d)
    elseif clearance == 'CONTINUE_APPROACH' then OrderContinueApproach(d)
    elseif clearance == 'HOLD' then
        d.held = not d.held
        Radio((d.held and '%s, hold position' or '%s, continue taxi'):format(d.callsign), 'ATC')
    end
end)

-- Décollage donné au point d'attente : alignement puis roulage sans nouvel ordre.
CreateThread(function()
    while true do
        Wait(200)
        for _, d in pairs(drivers) do
            if d.pendingTakeoff and d.state == S.LINED_UP and d.mode == 'idle' then
                d.pendingTakeoff = nil
                OrderTakeoff(d)
            end
        end
    end
end)

LSLegacy.Events.Register('atc:flight:delete', function(id)
    local d = drivers[id]
    if d then SafeDelete(d.veh) end
    drivers[id] = nil
end)

-- ── Radar (NUI tour) ─────────────────────────────────────────────
-- Le contrôleur du poste tour est le même client qui fait voler les avions : positions/caps lus
-- directement depuis `drivers` et poussés à la NUI en local, aucun aller-retour serveur.
ATC.RadarActive = false

LSLegacy.Events.Register('atc:flight:update', function(f)
    if ATC.RadarActive then SendNUIMessage({ action = 'atc:flight', flight = f }) end
end)

CreateThread(function()
    while true do
        Wait(300)
        if ATC.RadarActive then
            local snapshot = {}
            for id, d in pairs(drivers) do
                snapshot[#snapshot + 1] = {
                    id = id, x = d.pos.x, y = d.pos.y, heading = d.heading, state = d.state,
                }
            end
            SendNUIMessage({ action = 'atc:radar', flights = snapshot })
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, d in pairs(drivers) do SafeDelete(d.veh) end
end)
