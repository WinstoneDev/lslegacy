-- Calibration en jeu (gizmo admin) : réécrit l'offset (x, y, z, heading) d'une place
-- directement dans data/models.lua, sans toucher au reste du fichier.
local FILE = 'module/sit/data/models.lua'
local RES  = GetCurrentResourceName()

local function IsAdmin(player)
    return player and LSLegacy.Permissions.Has(player, 2)
end

local function Clamp(n, min, max)
    if n < min then return min end
    if n > max then return max end
    return n
end

LSLegacy.Security.RegisterRateLimit('sit:saveSeat', 20)
LSLegacy.Callbacks.RegisterServer('sit:saveSeat', function(source, cb, name, seatIndex, x, y, z, heading)
    local player = LSLegacy.GetPlayerFromId(source)
    if not IsAdmin(player) then return cb(false) end

    if type(name) ~= 'string' or not name:match('^[%w_]+$') then return cb(false) end
    seatIndex = tonumber(seatIndex)
    x, y, z, heading = tonumber(x), tonumber(y), tonumber(z), tonumber(heading)
    if not (seatIndex and x and y and z and heading) then return cb(false) end

    x, y, z = Clamp(x, -10.0, 10.0), Clamp(y, -10.0, 10.0), Clamp(z, -5.0, 5.0)
    heading = heading % 360.0

    local hash = GetHashKey(name)
    local model = Sit.Models[hash]
    if not model or not model.seats[seatIndex] then return cb(false) end

    local raw = LoadResourceFile(RES, FILE)
    if not raw then return cb(false) end

    local header = ('[`%s`] = {\n'):format(name)
    local blockStart, headerEnd = raw:find(header, 1, true)
    if not blockStart then return cb(false) end

    local depth, pos, blockEnd = 1, headerEnd + 1, nil
    while pos <= #raw do
        local c = raw:sub(pos, pos)
        if c == '{' then
            depth = depth + 1
        elseif c == '}' then
            depth = depth - 1
            if depth == 0 then blockEnd = pos; break end
        end
        pos = pos + 1
    end
    if not blockEnd then return cb(false) end

    local block = raw:sub(blockStart, blockEnd)
    local seatPattern = '%[' .. seatIndex .. '%] = vec4%([^%)]+%)'
    if not block:find(seatPattern) then return cb(false) end

    local newSeat = ('[%d] = vec4(%.3f, %.3f, %.3f, %.1f)'):format(seatIndex, x, y, z, heading)
    local newBlock = block:gsub(seatPattern, newSeat, 1)

    local newRaw = raw:sub(1, blockStart - 1) .. newBlock .. raw:sub(blockEnd + 1)
    SaveResourceFile(RES, FILE, newRaw, -1)

    -- Reflète en mémoire pour un retour immédiat sans restart du module.
    model.seats[seatIndex] = vec4(x, y, z, heading)

    cb(true)
end)
