-- ls_aldentes — Helpers partagés client/serveur.
-- Aucune logique réseau ici : uniquement de la lecture de configuration.

ALD = ALD or {}

---GetRecipe
---@param recipeId string
---@return table|nil
function ALD.GetRecipe(recipeId)
    if type(recipeId) ~= 'string' then return nil end
    return ALDConfig.Recipes[recipeId]
end

---GetStation
---@param stationId string
---@return table|nil
function ALD.GetStation(stationId)
    if type(stationId) ~= 'string' then return nil end
    return ALDConfig.Stations[stationId]
end

---RecipesForStation — recettes d'une station, triées par libellé pour que
---l'ordre du menu ne dépende pas de l'ordre d'itération d'une table Lua.
---@param stationId string
---@return table  { { id = ..., recipe = ... }, ... }
function ALD.RecipesForStation(stationId)
    local list = {}
    for id, recipe in pairs(ALDConfig.Recipes) do
        if recipe.station == stationId then
            list[#list + 1] = { id = id, recipe = recipe }
        end
    end
    table.sort(list, function(a, b) return a.recipe.label < b.recipe.label end)
    return list
end

---ItemLabel — libellé d'un item défini par cette ressource.
---@param item string
---@return string
function ALD.ItemLabel(item)
    local def = ALDConfig.Items[item]
    return (def and def.label) or item
end

---GetTray
---@param trayId number
---@return table|nil
function ALD.GetTray(trayId)
    if not ALDConfig.Trays.enabled then return nil end
    for _, tray in ipairs(ALDConfig.Trays.list) do
        if tray.id == trayId then return tray end
    end
    return nil
end

---DataStoreName — nom du DataStore d'un stockage ou d'un plateau.
---Préfixé par ALDConfig.Prefix : c'est ce préfixe que la garde d'accès serveur
---utilise pour n'autoriser QUE les conteneurs de ce restaurant.
---@param kind string  'storage' | 'tray'
---@param id any
---@return string
function ALD.DataStoreName(kind, id)
    return ('%s_%s_%s'):format(ALDConfig.Prefix, kind, tostring(id))
end
