-- ls_burgershot — Helpers partagés client/serveur.
-- Aucune logique réseau ici : uniquement de la lecture de configuration.

BS = BS or {}

---GetRecipe
---@param recipeId string
---@return table|nil
function BS.GetRecipe(recipeId)
    if type(recipeId) ~= 'string' then return nil end
    return BSConfig.Recipes[recipeId]
end

---GetStation
---@param stationId string
---@return table|nil
function BS.GetStation(stationId)
    if type(stationId) ~= 'string' then return nil end
    return BSConfig.Stations[stationId]
end

---RecipeStationId — station dont les recettes sont utilisées (alias
---sharesRecipesWith : plusieurs points physiques, une seule offre).
---@param stationId string
---@return string
function BS.RecipeStationId(stationId)
    local station = BS.GetStation(stationId)
    return (station and station.sharesRecipesWith) or stationId
end

---RecipesForStation — recettes d'une station, triées par libellé pour que
---l'ordre du menu ne dépende pas de l'ordre d'itération d'une table Lua.
---@param stationId string
---@return table  { { id = ..., recipe = ... }, ... }
function BS.RecipesForStation(stationId)
    local list = {}
    local recipeStation = BS.RecipeStationId(stationId)
    for id, recipe in pairs(BSConfig.Recipes) do
        if recipe.station == recipeStation then
            list[#list + 1] = { id = id, recipe = recipe }
        end
    end
    table.sort(list, function(a, b) return a.recipe.label < b.recipe.label end)
    return list
end

---ItemLabel — libellé d'un item défini par cette ressource.
---@param item string
---@return string
function BS.ItemLabel(item)
    local def = BSConfig.Items[item]
    return (def and def.label) or item
end

---GetTray
---@param trayId number
---@return table|nil
function BS.GetTray(trayId)
    if not BSConfig.Trays.enabled then return nil end
    for _, tray in ipairs(BSConfig.Trays.list) do
        if tray.id == trayId then return tray end
    end
    return nil
end

---DataStoreName — nom du DataStore d'un stockage ou d'un plateau.
---Préfixé par BSConfig.Prefix : c'est ce préfixe que la garde d'accès serveur
---utilise pour n'autoriser QUE les conteneurs de ce restaurant.
---@param kind string  'storage' | 'tray'
---@param id any
---@return string
function BS.DataStoreName(kind, id)
    return ('%s_%s_%s'):format(BSConfig.Prefix, kind, tostring(id))
end
