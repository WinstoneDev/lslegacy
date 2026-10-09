-- ls_kebabking — Helpers partagés client/serveur.
-- Aucune logique réseau ici : uniquement de la lecture de configuration.

KK = KK or {}

---GetRecipe
---@param recipeId string
---@return table|nil
function KK.GetRecipe(recipeId)
    if type(recipeId) ~= 'string' then return nil end
    return KKConfig.Recipes[recipeId]
end

---GetStation
---@param stationId string
---@return table|nil
function KK.GetStation(stationId)
    if type(stationId) ~= 'string' then return nil end
    return KKConfig.Stations[stationId]
end

---RecipeStationId — station logique servant à filtrer/valider les recettes.
---Une station peut porter `sharesRecipesWith = 'autreStationId'` : c'est le
---cas d'un second poste physique identique (ex. 'assembly2' à côté
---d'assembly'), qui ne redéfinit aucune recette, juste un second
---emplacement offrant les mêmes que la station qu'il référence.
---@param stationId string
---@return string
function KK.RecipeStationId(stationId)
    local station = KK.GetStation(stationId)
    return (station and station.sharesRecipesWith) or stationId
end

---RecipesForStation — recettes d'une station, triées par libellé pour que
---l'ordre du menu ne dépende pas de l'ordre d'itération d'une table Lua.
---@param stationId string
---@return table  { { id = ..., recipe = ... }, ... }
function KK.RecipesForStation(stationId)
    local recipeStationId = KK.RecipeStationId(stationId)
    local list = {}
    for id, recipe in pairs(KKConfig.Recipes) do
        if recipe.station == recipeStationId then
            list[#list + 1] = { id = id, recipe = recipe }
        end
    end
    table.sort(list, function(a, b) return a.recipe.label < b.recipe.label end)
    return list
end

---ItemLabel — libellé d'un item défini par cette ressource.
---@param item string
---@return string
function KK.ItemLabel(item)
    local def = KKConfig.Items[item]
    return (def and def.label) or item
end

---GetTray
---@param trayId number
---@return table|nil
function KK.GetTray(trayId)
    if not KKConfig.Trays.enabled then return nil end
    for _, tray in ipairs(KKConfig.Trays.list) do
        if tray.id == trayId then return tray end
    end
    return nil
end

---DataStoreName — nom du DataStore d'un stockage ou d'un plateau.
---Préfixé par KKConfig.Prefix : c'est ce préfixe que la garde d'accès serveur
---utilise pour n'autoriser QUE les conteneurs de ce restaurant.
---@param kind string  'storage' | 'tray'
---@param id any
---@return string
function KK.DataStoreName(kind, id)
    return ('%s_%s_%s'):format(KKConfig.Prefix, kind, tostring(id))
end
