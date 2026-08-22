---@class LSLegacy.Validate
--- Primitives de validation serveur réutilisables. Le client est toujours
--- considéré hostile : ces fonctions ne font jamais confiance à une valeur
--- reçue telle quelle, elles la vérifient et renvoient soit une valeur saine,
--- soit nil/false.
LSLegacy.Validate = {}

---Number — vérifie/convertit une valeur en nombre fini, avec bornes optionnelles.
---@type function
---@param value any
---@param opts table|nil {min = number, max = number}
---@return number|nil
---@public
LSLegacy.Validate.Number = function(value, opts)
    local n = tonumber(value)
    if n == nil or n ~= n or n == math.huge or n == -math.huge then return nil end
    opts = opts or {}
    if opts.min ~= nil and n < opts.min then return nil end
    if opts.max ~= nil and n > opts.max then return nil end
    return n
end

---PositiveInteger — entier strictement positif (ou >= 0 si opts.allowZero).
---@type function
---@param value any
---@param opts table|nil {allowZero = boolean, max = number}
---@return number|nil
---@public
LSLegacy.Validate.PositiveInteger = function(value, opts)
    opts = opts or {}
    local n = LSLegacy.Validate.Number(value, {min = opts.allowZero and 0 or 1, max = opts.max})
    if n == nil then return nil end
    if n ~= math.floor(n) then return nil end
    return n
end

---Player — résout un source en joueur serveur réel (jamais un table client).
---@type function
---@param source any
---@return table|nil
---@public
LSLegacy.Validate.Player = function(source)
    local id = tonumber(source)
    if id == nil then return nil end
    return LSLegacy.GetPlayerFromId(id)
end

---Target — résout une cible distincte de la source (sauf opts.allowSelf).
---@type function
---@param source any
---@param targetId any
---@param opts table|nil {allowSelf = boolean}
---@return table|nil
---@public
LSLegacy.Validate.Target = function(source, targetId, opts)
    opts = opts or {}
    local target = LSLegacy.Validate.Player(targetId)
    if target == nil then return nil end
    if not opts.allowSelf and tostring(target.source) == tostring(source) then return nil end
    return target
end

---Distance — vrai si deux coordonnées vector3 sont à portée.
---@type function
---@param coordsA vector3
---@param coordsB vector3
---@param maxDistance number
---@return boolean
---@public
LSLegacy.Validate.Distance = function(coordsA, coordsB, maxDistance)
    if coordsA == nil or coordsB == nil or maxDistance == nil then return false end
    return #(coordsA - coordsB) <= maxDistance
end

---Job — vrai si le joueur a un des jobs attendus (et un grade suffisant).
---@type function
---@param player table
---@param jobs string|table
---@param minGrade number|nil
---@return boolean
---@public
LSLegacy.Validate.Job = function(player, jobs, minGrade)
    if player == nil then return false end
    local list = type(jobs) == "table" and jobs or {jobs}
    for _, job in pairs(list) do
        if player.job == job then
            if minGrade == nil or (player.job_grade or 0) >= minGrade then
                return true
            end
        end
    end
    return false
end

---Permission — vrai si le groupe staff du joueur atteint le seuil minimum.
---@type function
---@param player table
---@param minGroup number
---@return boolean
---@public
LSLegacy.Validate.Permission = function(player, minGroup)
    if player == nil or minGroup == nil then return false end
    return (player.group or 0) >= minGroup
end

---Item — renvoie la définition Config.Items de l'item si elle existe.
---@type function
---@param itemName any
---@return table|nil
---@public
LSLegacy.Validate.Item = function(itemName)
    if type(itemName) ~= "string" then return nil end
    return Config.Items[itemName]
end

---Vehicle — renvoie l'entity si elle existe réellement et est un véhicule.
---@type function
---@param entity any
---@return number|nil
---@public
LSLegacy.Validate.Vehicle = function(entity)
    entity = tonumber(entity)
    if entity == nil or entity == 0 then return nil end
    if not DoesEntityExist(entity) then return nil end
    if GetEntityType(entity) ~= 2 then return nil end
    return entity
end

---DataStore — renvoie le datastore réel du Core s'il existe (par son nom).
---@type function
---@param name any
---@return table|nil
---@public
LSLegacy.Validate.DataStore = function(name)
    if type(name) ~= "string" then return nil end
    return LSLegacy.DataStores[name]
end
