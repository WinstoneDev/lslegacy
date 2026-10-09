-- ls_burgershot (serveur) — fabrication.
-- Le client envoie uniquement stationId + recipeId. Tout le reste (item
-- produit, quantité, ingrédients consommés) est relu dans config/recipes.lua.

local Core = exports['lslegacy']

-- Cadence de fabrication : un joueur légitime met `duration` ms par recette
-- (progressbar). On exige au moins 85 % de ce temps entre deux fabrications,
-- ce qui neutralise un client qui déclencherait l'event en boucle.
local nextCraftAt = {}

AddEventHandler('playerDropped', function()
    nextCraftAt[source] = nil
end)

RegisterNetEvent(BSConfig.Prefix .. ':craft', function(stationId, recipeId)
    local src = source

    -- 1. Fréquence
    if not BS.Sec.Allow(src, 'craft') then return end

    -- 2. Arguments
    if type(stationId) ~= 'string' or type(recipeId) ~= 'string' then return end

    local station = BS.GetStation(stationId)
    local recipe  = BS.GetRecipe(recipeId)
    if not station or not recipe then
        BS.Dbg(('recette ou station inconnue : %s / %s'):format(tostring(stationId), tostring(recipeId)))
        return
    end
    -- 3. La recette doit appartenir à la station ciblée
    if recipe.station ~= BS.RecipeStationId(stationId) then
        BS.Dbg(('recette %s demandée depuis la mauvaise station (%s)'):format(recipeId, stationId))
        return
    end
    if station.type ~= 'craft' then return end

    -- 4. Joueur, job, grade, service, distance
    local player = BS.CanWork(src, recipe.minGrade or station.minGrade, station.coords,
        (station.distance or 2.0) + BSConfig.Security.maxDistance)
    if not player then return end

    -- 5. Cadence par recette
    local now = GetGameTimer()
    if nextCraftAt[src] and now < nextCraftAt[src] then
        BS.Dbg(('cadence de fabrication non respectée par %s'):format(src))
        return
    end
    nextCraftAt[src] = now + math.floor((recipe.duration or 4000) * 0.85)

    -- 6. Transaction atomique côté framework (vérifie ingrédients + poids)
    local take, give = {}, {}
    for _, ing in ipairs(recipe.ingredients or {}) do
        take[#take + 1] = { item = ing.item, count = ing.count }
    end
    for _, res in ipairs(recipe.results or {}) do
        give[#give + 1] = { item = res.item, count = res.count }
    end

    local result = Core:craftTransaction(src, take, give) or {}
    if not result.ok then
        local reason = result.reason
        if reason == 'weight' then
            BS.Notify(src, "Vous ne pouvez pas porter davantage.", 'error')
        elseif reason == 'missing' then
            BS.Notify(src, "Il vous manque des ingrédients.", 'error')
        else
            BS.Dbg(('transaction refusée (%s) pour %s'):format(tostring(reason), recipeId))
        end
        return
    end

    -- 7. Retour joueur + log
    local produced = {}
    for _, res in ipairs(recipe.results or {}) do
        produced[#produced + 1] = ('%s x%d'):format(BS.ItemLabel(res.item), res.count)
    end
    BS.Notify(src, table.concat(produced, ', '), 'success')
    BS.Log(('%s (%s) a préparé %s'):format(player.name or 'Joueur', src, table.concat(produced, ', ')))
end)
