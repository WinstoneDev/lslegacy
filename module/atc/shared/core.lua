-- Noyau ATC partagé : états de vol, clairances, transitions autorisées, graphe + A*, géométrie.

ATC = ATC or {}

ATC.State = {
    PARKED = 'PARKED', PUSHBACK = 'PUSHBACK', TAXI = 'TAXI', HOLD_SHORT = 'HOLD_SHORT',
    LINE_UP = 'LINE_UP', LINED_UP = 'LINED_UP', TAKEOFF = 'TAKEOFF', CLIMB = 'CLIMB', DEPARTED = 'DEPARTED',
    APPROACH = 'APPROACH', FINAL = 'FINAL', LANDING = 'LANDING', ROLLOUT = 'ROLLOUT', VACATING = 'VACATING',
    TAXI_IN = 'TAXI_IN', PARKING = 'PARKING', DESPAWN = 'DESPAWN',
}

ATC.Clearance = {
    PUSHBACK = 'PUSHBACK', TAXI = 'TAXI', CROSS = 'CROSS', LINE_UP = 'LINE_UP',
    TAKEOFF = 'TAKEOFF', LAND = 'LAND', GO_AROUND = 'GO_AROUND',
    CONTINUE_APPROACH = 'CONTINUE_APPROACH', HOLD = 'HOLD',
}

-- Clairances acceptées selon l'état courant (validé serveur, filtré NUI).
ATC.Allowed = {
    -- TAKEOFF depuis PARKED : uniquement les hélicoptères (décollage vertical direct, cf. Clear() côté serveur).
    PARKED     = { PUSHBACK = true, TAXI = true, TAKEOFF = true },
    PUSHBACK   = { TAXI = true, HOLD = true },
    TAXI       = { TAXI = true, HOLD = true },
    HOLD_SHORT = { TAXI = true, CROSS = true, LINE_UP = true, TAKEOFF = true },
    LINED_UP   = { TAKEOFF = true },
    -- Approche figee jusqu'a CONTINUE_APPROACH (le pilote annonce l'ILS et attend), puis descente
    -- normale ; LAND ne devient possible qu'en FINAL (~4 NM, cf. FINAL_DIST cote client).
    APPROACH   = { CONTINUE_APPROACH = true },
    FINAL      = { LAND = true, GO_AROUND = true },
    VACATING   = { TAXI = true },
    TAXI_IN    = { TAXI = true },
}

-- ── Géométrie ────────────────────────────────────────────────────
ATC.Geo = {}

function ATC.Geo.HeadingToDir(h)
    local r = math.rad(h)
    return -math.sin(r), math.cos(r)
end

function ATC.Geo.DirToHeading(dx, dy)
    return (math.deg(math.atan(-dx, dy)) + 360.0) % 360.0
end

function ATC.Geo.AngleDiff(a, b)
    local d = (b - a + 540.0) % 360.0 - 180.0
    return d
end

function ATC.Geo.Dist2D(ax, ay, bx, by)
    return math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
end

-- ── Graphe ───────────────────────────────────────────────────────
ATC.Graph = { nodes = nil, adj = nil }

local function BuildAdjacency()
    local G = Config.ATC.Graph
    ATC.Graph.nodes = G.nodes
    local adj = {}
    for _, e in ipairs(G.edges) do
        adj[e[1]] = adj[e[1]] or {}
        adj[e[2]] = adj[e[2]] or {}
        adj[e[1]][#adj[e[1]] + 1] = { to = e[2], kind = e.kind, len = e.len }
        adj[e[2]][#adj[e[2]] + 1] = { to = e[1], kind = e.kind, len = e.len }
    end
    ATC.Graph.adj = adj
end

function ATC.Graph.Node(id)
    if not ATC.Graph.nodes then BuildAdjacency() end
    return ATC.Graph.nodes[id]
end

function ATC.Graph.Neighbors(id)
    if not ATC.Graph.adj then BuildAdjacency() end
    return ATC.Graph.adj[id] or {}
end

-- Nœud le plus proche d'une position (optionnellement filtré par type).
function ATC.Graph.Nearest(x, y, typeFilter, maxDist)
    if not ATC.Graph.nodes then BuildAdjacency() end
    local best, bestD = nil, maxDist or 1e9
    for id, n in pairs(ATC.Graph.nodes) do
        if not typeFilter or n.type == typeFilter then
            local d = ATC.Geo.Dist2D(x, y, n.x, n.y)
            if d < bestD then best, bestD = id, d end
        end
    end
    return best, bestD
end

-- A* (Dijkstra + heuristique euclidienne). opts.runwayPenalty multiplie le coût des arêtes piste,
-- opts.avoid = { [nodeId] = true } exclut des nœuds.
function ATC.Graph.Path(from, to, opts)
    if not ATC.Graph.adj then BuildAdjacency() end
    opts = opts or {}
    local penalty = opts.runwayPenalty or 6.0
    local nodes = ATC.Graph.nodes
    if not nodes[from] or not nodes[to] then return nil end
    local target = nodes[to]
    local g, prev, closed = { [from] = 0.0 }, {}, {}
    local open = { from }
    local function h(id) return ATC.Geo.Dist2D(nodes[id].x, nodes[id].y, target.x, target.y) end
    while #open > 0 do
        local bi, bf = 1, g[open[1]] + h(open[1])
        for i = 2, #open do
            local f = g[open[i]] + h(open[i])
            if f < bf then bi, bf = i, f end
        end
        local u = table.remove(open, bi)
        if u == to then break end
        if not closed[u] then
            closed[u] = true
            for _, e in ipairs(ATC.Graph.adj[u] or {}) do
                if not closed[e.to] and not (opts.avoid and opts.avoid[e.to]) then
                    local w = e.len * (e.kind == 'runway' and penalty or 1.0)
                    local ng = g[u] + w
                    if not g[e.to] or ng < g[e.to] then
                        g[e.to] = ng
                        prev[e.to] = u
                        open[#open + 1] = e.to
                    end
                end
            end
        end
    end
    if not g[to] then return nil end
    local path = { to }
    while path[#path] ~= from do path[#path + 1] = prev[path[#path]] end
    local out = {}
    for i = #path, 1, -1 do out[#out + 1] = path[i] end
    return out, g[to]
end

-- Premier point d'attente rencontré sur un chemin (hors nœud de départ) protégeant une piste.
function ATC.Graph.FirstHoldingIndex(path, startIndex)
    for i = (startIndex or 2), #path do
        local n = ATC.Graph.Node(path[i])
        if n and n.type == 'holding' then return i end
    end
    return nil
end

-- ── Pistes ───────────────────────────────────────────────────────
function ATC.QfuHeading(qfu)
    local q = Config.ATC.Qfu[qfu]
    return q and q.heading or 0.0
end

function ATC.RunwayOfQfu(qfu)
    local q = Config.ATC.Qfu[qfu]
    return q and q.runway or nil
end

function ATC.RunwayConfig(id)
    for _, c in ipairs(Config.ATC.RunwayConfigs) do
        if c.id == id then return c end
    end
    return Config.ATC.RunwayConfigs[1]
end

-- Nœud piste (RWY_*) associé à un point d'attente : voisin de type exit, sinon nil.
function ATC.RunwayNodeForHolding(hpId)
    for _, e in ipairs(ATC.Graph.Neighbors(hpId)) do
        local n = ATC.Graph.Node(e.to)
        if n and n.type == 'exit' then return e.to end
    end
    return nil
end
