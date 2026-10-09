-- Outil de relevé ATC : persiste les points relevés en jeu dans un JSON lisible hors jeu.

local CFG = Config.ATC.Survey
local RES = GetCurrentResourceName()
local points = {}

LSLegacy.Security.RegisterRateLimit('atc:survey:load', 10)
LSLegacy.Security.RegisterRateLimit('atc:survey:sync', 60)

local function IsAdmin(src)
    local p = LSLegacy.Players.Get(src)
    return p and LSLegacy.Permissions.Has(p, 2)
end

local function Load()
    local raw = LoadResourceFile(RES, CFG.File)
    if not raw or raw == '' then return end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then points = data end
end

local function Save()
    SaveResourceFile(RES, CFG.File, json.encode(points), -1)
end

local ALLOWED = {}
for _, t in ipairs(CFG.Types) do ALLOWED[t.id] = true end

local function Sanitize(list)
    local out = {}
    for i, pt in ipairs(list) do
        if i > CFG.MaxPoints then break end
        if type(pt) == 'table' and ALLOWED[pt.type] and tonumber(pt.x) and tonumber(pt.y) and tonumber(pt.z) then
            out[#out + 1] = {
                type = pt.type,
                id = tostring(pt.id or ''):sub(1, 32),
                group = tostring(pt.group or ''):sub(1, 32),
                note = tostring(pt.note or ''):sub(1, 64),
                x = tonumber(pt.x), y = tonumber(pt.y), z = tonumber(pt.z),
                h = tonumber(pt.h) or 0.0,
            }
        end
    end
    return out
end

LSLegacy.Events.Register('atc:survey:load', function()
    local src = source
    if not IsAdmin(src) then return end
    Load() -- le fichier peut avoir été édité hors jeu
    LSLegacy.Events.SendToClient('atc:survey:data', src, points)
end)

-- Le client envoie la liste complète après chaque modification (volume faible, évite les états divergents).
LSLegacy.Events.Register('atc:survey:sync', function(list)
    local src = source
    if not IsAdmin(src) or type(list) ~= 'table' then return end
    points = Sanitize(list)
    Save()
end)

LSLegacy.RegisterCommand('atcsurvey', 2, function(xPlayer)
    LSLegacy.Events.SendToClient('atcsurvey:openMenu', xPlayer.source)
end, { help = "Ouvrir l'outil de relevé ATC (LSIA)", validate = false }, false)

Load()
