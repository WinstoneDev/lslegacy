-- ls_burgershot (client) — menus de fabrication.
-- Le menu n'est qu'un affichage : il envoie au serveur un stationId + un
-- recipeId, jamais l'item ni la quantité produite.

local function GetInventoryCounts()
    local counts = {}
    local data = exports['lslegacy']:getPlayerData()
    for _, item in pairs((data and data.inventory) or {}) do
        counts[item.name] = (counts[item.name] or 0) + (item.count or 0)
    end
    return counts
end

---MissingIngredients — { { item, label, need, have }, ... }
local function MissingIngredients(recipe, counts)
    local missing = {}
    for _, ing in ipairs(recipe.ingredients or {}) do
        local have = counts[ing.item] or 0
        if have < ing.count then
            missing[#missing + 1] = {
                item = ing.item, label = BS.ItemLabel(ing.item), need = ing.count, have = have,
            }
        end
    end
    return missing
end

local function BuildMetadata(recipe, counts)
    local meta = {}
    for _, ing in ipairs(recipe.ingredients or {}) do
        local have = counts[ing.item] or 0
        meta[#meta + 1] = {
            label = BS.ItemLabel(ing.item),
            value = ('%d / %d'):format(have, ing.count),
        }
    end
    for _, res in ipairs(recipe.results or {}) do
        meta[#meta + 1] = { label = 'Donne', value = ('%s x%d'):format(BS.ItemLabel(res.item), res.count) }
    end
    return meta
end

---StartCraft — vérifie localement (confort), joue l'animation, puis demande
---la fabrication au serveur qui refait TOUTES les vérifications.
function BS.StartCraft(stationId, recipeId)
    if BS.Client.busy then return end
    local recipe = BS.GetRecipe(recipeId)
    local station = BS.GetStation(stationId)
    if not recipe or not station or recipe.station ~= BS.RecipeStationId(stationId) then return end

    if not BS.CanUseStation(recipe.minGrade or station.minGrade) then
        BS.Notify(BSConfig.Duty.required and "Vous devez être en service pour utiliser cet équipement."
                  or "Vous n'avez pas accès à cet équipement.", 'error')
        return
    end

    local missing = MissingIngredients(recipe, GetInventoryCounts())
    if #missing > 0 then
        local lines = {}
        for _, m in ipairs(missing) do
            lines[#lines + 1] = ('%s x%d'):format(m.label, m.need - m.have)
        end
        BS.Notify('Ingrédients manquants :\n' .. table.concat(lines, '\n'), 'error')
        return
    end

    BS.Client.busy = true
    local ok = BS.PlayCraftAnim(recipe.anim, recipe.label .. '...', recipe.duration or 4000)
    BS.Client.busy = false

    if not ok then
        BS.Notify('Action annulée.', 'error')
        return
    end

    TriggerServerEvent(BSConfig.Prefix .. ':craft', stationId, recipeId)
end

---OpenStation — menu ox_lib des recettes d'une station.
function BS.OpenStation(stationId)
    local station = BS.GetStation(stationId)
    if not station then return end

    if not BS.CanUseStation(station.minGrade) then
        BS.Notify(BSConfig.Duty.required and "Vous devez être en service pour utiliser cet équipement."
                  or "Vous n'avez pas accès à cet équipement.", 'error')
        return
    end

    local counts  = GetInventoryCounts()
    local options = {}

    for _, entry in ipairs(BS.RecipesForStation(stationId)) do
        local recipe  = entry.recipe
        local missing = MissingIngredients(recipe, counts)
        options[#options + 1] = {
            title       = recipe.label,
            description = #missing > 0 and 'Ingrédients manquants' or 'Prêt à préparer',
            icon        = #missing > 0 and 'circle-xmark' or 'circle-check',
            iconColor   = #missing > 0 and '#e5544b' or '#6fcf6f',
            metadata    = BuildMetadata(recipe, counts),
            onSelect    = function() BS.StartCraft(stationId, entry.id) end,
        }
    end

    if #options == 0 then
        BS.Notify('Aucune recette disponible sur ce poste.', 'error')
        return
    end

    lib.registerContext({
        id      = BSConfig.Prefix .. '_station_' .. stationId,
        title   = ('%s — %s'):format(BSConfig.JobLabel, station.label),
        options = options,
    })
    lib.showContext(BSConfig.Prefix .. '_station_' .. stationId)
end
