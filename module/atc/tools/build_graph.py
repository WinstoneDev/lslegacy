#!/usr/bin/env python3
"""Génère module/atc/config/lsia_graph.lua depuis data/survey.json + stands/pistes.
Relancer après chaque modification du relevé. Sortie : nodes (id, coords, type, runway, protects), edges (a, b, kind, len)."""
import json, math, re, os, sys

ROOT = os.path.join(os.path.dirname(__file__), '..')
SURVEY = os.path.join(ROOT, 'data', 'survey.json')
OUT = os.path.join(ROOT, 'config', 'lsia_graph.lua')

RUNWAYS = {  # piste physique -> (seuil A, seuil B)
    '12L/30R': ((-1543.516479, -2829.428467, 13.946533), (-960.065918, -3166.061523, 13.929688)),
    '12R/30L': ((-1625.327515, -2976.633057, 13.929688), (-1036.918701, -3315.230713, 13.929688)),
    '03/21':   ((-1643.973633, -2743.331787, 13.963379), (-1369.054932, -2267.604492, 13.963379)),
}
STANDS = {
    'C1': (-1356.606567, -2712.145020, 13.929688), 'C2': (-1480.298950, -2724.197754, 13.929688),
    'C3': (-1277.432983, -2755.635254, 13.929688), 'C4': (-1448.993408, -2658.197754, 13.929688),
    'C5': (-1410.843994, -2594.479004, 13.929688), 'C6': (-1380.039551, -2527.331787, 13.929688),
    'C7': (-1172.637329, -2573.894531, 13.929688), 'C8': (-1255.687866, -2537.340576, 13.929688),
    'C9': (-1193.340698, -2609.709961, 13.929688), 'C10': (-1263.402222, -2550.210938, 13.929688),
    'B1': (-1115.261597, -2943.046143, 14.536255), 'B2': (-1153.081299, -2922.105469, 14.536255),
    'B3': (-1190.901123, -2901.059326, 13.929688), 'B4': (-1229.604370, -2877.204346, 13.929688),
    'B5': (-1266.738403, -2859.177979, 13.929688),
    'H1': (-1178.373657, -2845.780273, 13.929688), 'H2': (-1146.026367, -2864.518799, 13.929688),
    'H3': (-1112.465942, -2883.731934, 13.929688),
}
STAND_ACCESS = {'B1': 'D13', 'B2': 'D11', 'B3': 'D9', 'B4': 'D8', 'B5': 'D7'}
MANUAL_LINKS = [('D1', 'E1')]
JOIN_RADIUS = 15.0      # raccord automatique début/fin de groupe -> nœuds étrangers proches
HP_TAXI_RADIUS = 40.0   # point d'attente -> nœud taxiway le plus proche
STAND_RADIUS = 30.0

def dist(a, b): return math.hypot(a['x'] - b['x'], a['y'] - b['y'])

def axis(rw):
    (ax, ay, _), (bx, by, _) = RUNWAYS[rw]
    L = math.hypot(bx - ax, by - ay)
    return (ax, ay), ((bx - ax) / L, (by - ay) / L), L

def proj(p, rw):
    (ax, ay), (ux, uy), L = axis(rw)
    rx, ry = p['x'] - ax, p['y'] - ay
    return rx * ux + ry * uy, rx * (-uy) + ry * ux

def runway_of(p, tol=3.0):
    for rw in RUNWAYS:
        a, c = proj(p, rw)
        if abs(c) <= tol and -120 <= a <= axis(rw)[2] + 120: return rw
    return None

def nearest_runway(p):
    return min(RUNWAYS, key=lambda rw: abs(proj(p, rw)[1]))

def token(pid):
    m = re.match(r'^(HP|RWY)_(.+)$', pid)
    if not m: return None
    rest = m.group(2)
    rest = re.sub(r'_(03|21|12L|12R|30L|30R)$', '', rest)
    return rest

pts = json.load(open(SURVEY))
nodes = {}
for p in pts:
    if p['id'] in nodes: sys.exit('id en double : ' + p['id'])
    n = dict(id=p['id'], x=p['x'], y=p['y'], z=p['z'], h=p['h'], type=p['type'], group=p['group'], note=p.get('note', ''))
    nodes[p['id']] = n

# Nœuds stands / hélipads
for sid, (x, y, z) in STANDS.items():
    nodes['STAND_' + sid] = dict(id='STAND_' + sid, x=x, y=y, z=z, h=0.0, type='stand', group='STAND', note=sid)

edges = {}
def link(a, b, kind='taxi'):
    if a == b or a not in nodes or b not in nodes: return
    key = tuple(sorted((a, b)))
    if key in edges: return
    edges[key] = dict(a=key[0], b=key[1], kind=kind, len=dist(nodes[a], nodes[b]))

def taxi_nodes(): return [n for n in nodes.values() if n['type'] == 'taxiway']

# 1. chaînage des nœuds taxiway consécutifs d'un même groupe (ordre du relevé)
groups = {}
for p in pts:
    if p['type'] == 'taxiway': groups.setdefault(p['group'], []).append(p['id'])
for g, ids in groups.items():
    for a, b in zip(ids, ids[1:]): link(a, b)

# 2. "Depuis X" -> raccord explicite du premier nœud du groupe (ou du HP)
for p in pts:
    m = re.match(r'^Depuis\s+([A-Za-z]+\d*)\b', p.get('note', ''))
    if not m: continue
    src = m.group(1)
    if src in nodes and dist(nodes[src], nodes[p['id']]) <= 60:
        first = groups.get(p['group'], [p['id']])[0] if p['type'] == 'taxiway' else p['id']
        if p['id'] == first: link(src, p['id'])

# 3. raccord automatique début/fin de groupe avec les nœuds étrangers proches
for g, ids in groups.items():
    for pid in (ids[0], ids[-1]):
        for n in nodes.values():
            if n['group'] != g and n['type'] in ('taxiway',) and dist(n, nodes[pid]) <= JOIN_RADIUS:
                link(pid, n['id'])

for a, b in MANUAL_LINKS: link(a, b)

# 4. points d'attente : -> nœud taxiway le plus proche, -> RWY_ du même token ; piste protégée
for n in list(nodes.values()):
    if n['type'] != 'holding': continue
    tok = token(n['id'])
    cand = [t for t in taxi_nodes() if dist(t, n) <= HP_TAXI_RADIUS]
    if cand:
        best = min(cand, key=lambda t: dist(t, n))
        link(n['id'], best['id'])
    for m in nodes.values():
        if m['type'] == 'exit' and token(m['id']) == tok: link(n['id'], m['id'])
    n['protects'] = nearest_runway(n)
    on = runway_of(n)
    if on: n['runway'] = on  # HP posé sur l'axe (A21) : nœud piste aussi

# 5. nœuds piste : chaînage le long de l'axe
for rw in RUNWAYS:
    on_rw = [n for n in nodes.values() if n['type'] in ('exit', 'holding') and runway_of(n) == rw]
    for n in on_rw:
        n['runway'] = rw
        n['along'] = round(proj(n, rw)[0], 2)
    on_rw.sort(key=lambda n: n['along'])
    for a, b in zip(on_rw, on_rw[1:]): link(a['id'], b['id'], 'runway')

# 6. connecteurs N : chaînage par distance à l'axe 12L (HP -> milieu -> HP -> bord)
for k in range(1, 7, 2):
    toks = {'N%d' % k, 'N%d' % (k + 1)}
    chain = [n for n in nodes.values() if (n['group'] in toks and n['type'] == 'taxiway') or (token(n['id']) in toks)]
    chain.sort(key=lambda n: proj(n, '12L/30R')[1], reverse=True)
    for a, b in zip(chain, chain[1:]):
        link(a['id'], b['id'], 'runway' if (a['type'] == 'exit' or b['type'] == 'exit') else 'taxi')

# 7. stands : nœud d'accès explicite ou nœud de ligne de stand le plus proche
for sid in STANDS:
    nid = 'STAND_' + sid
    if sid in STAND_ACCESS: link(nid, STAND_ACCESS[sid]); continue
    if sid.startswith('H'): continue
    cand = [t for t in taxi_nodes() if dist(t, nodes[nid]) <= STAND_RADIUS]
    if not cand: print('AVERTISSEMENT stand sans accès :', sid); continue
    best = min(cand, key=lambda t: dist(t, nodes[nid]))
    for t in cand:
        if t['group'] == best['group'] and dist(t, nodes[nid]) <= 30.0: link(nid, t['id'])

# Rapport connectivité
adj = {}
for e in edges.values():
    adj.setdefault(e['a'], []).append(e['b']); adj.setdefault(e['b'], []).append(e['a'])
def bfs(s):
    seen, st = {s}, [s]
    while st:
        u = st.pop()
        for v in adj.get(u, []):
            if v not in seen: seen.add(v); st.append(v)
    return seen
comp = bfs('D1')
isolated = [n for n in nodes if n not in comp and not n.startswith('STAND_H')]
print('nœuds %d, arêtes %d, composante D1 : %d, hors composante : %s' % (len(nodes), len(edges), len(comp), isolated or 'aucun'))

def lua_str(s): return "'" + s.replace("'", "\\'") + "'"
with open(OUT, 'w') as f:
    f.write("-- GÉNÉRÉ par tools/build_graph.py depuis data/survey.json : ne pas éditer à la main.\n")
    f.write("-- kind : taxi | runway. runway : nœud posé sur l'axe de cette piste (along = distance depuis le seuil A).\n")
    f.write("-- protects : piste devant laquelle un point d'attente retient l'avion.\n\n")
    f.write("Config = Config or {}\nConfig.ATC = Config.ATC or {}\n\nConfig.ATC.Graph = {\n    nodes = {\n")
    for n in sorted(nodes.values(), key=lambda n: n['id']):
        extra = ''
        if n.get('runway'): extra += ", runway = %s, along = %.2f" % (lua_str(n['runway']), n.get('along', 0.0))
        if n.get('protects'): extra += ", protects = %s" % lua_str(n['protects'])
        if n['type'] == 'stand': extra += ", stand = %s" % lua_str(n['note'])
        f.write("        [%s] = { x = %.4f, y = %.4f, z = %.4f, h = %.2f, type = %s, group = %s%s },\n" % (
            lua_str(n['id']), n['x'], n['y'], n['z'], n['h'], lua_str(n['type']), lua_str(n['group']), extra))
    f.write("    },\n    edges = {\n")
    for e in sorted(edges.values(), key=lambda e: (e['a'], e['b'])):
        f.write("        { %s, %s, kind = %s, len = %.2f },\n" % (lua_str(e['a']), lua_str(e['b']), lua_str(e['kind']), e['len']))
    f.write("    },\n}\n")
print('écrit', OUT)
