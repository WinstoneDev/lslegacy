-- ls_aldentes (client) — menus de fabrication.
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
                item = ing.item, label = ALD.ItemLabel(ing.item), need = ing.count, have = have,
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
            label = ALD.ItemLabel(ing.item),
            value = ('%d / %d'):format(have, ing.count),
        }
    end
    for _, res in ipairs(recipe.results or {}) do
        meta[#meta + 1] = { label = 'Donne', value = ('%s x%d'):format(ALD.ItemLabel(res.item), res.count) }
    end
    return meta
end

---StartCraft — vérifie localement (confort), joue l'animation, puis demande
---la fabrication au serveur qui refait TOUTES les vérifications.
function ALD.StartCraft(stationId, recipeId)
    if ALD.Client.busy then return end
    local recipe = ALD.GetRecipe(recipeId)
    local station = ALD.GetStation(stationId)
    if not recipe or not station or recipe.station ~= stationId then return end

    if not ALD.CanUseStation(recipe.minGrade or station.minGrade) then
        ALD.Notify(ALDConfig.Duty.required and "Vous devez être en service pour utiliser cet équipement."
                  or "Vous n'avez pas accès à cet équipement.", 'error')
        return
    end

    local missing = MissingIngredients(recipe, GetInventoryCounts())
    if #missing > 0 then
        local lines = {}
        for _, m in ipairs(missing) do
            lines[#lines + 1] = ('%s x%d'):format(m.label, m.need - m.have)
        end
        ALD.Notify('Ingrédients manquants :\n' .. table.concat(lines, '\n'), 'error')
        return
    end

    ALD.Client.busy = true
    local ok = ALD.PlayCraftAnim(recipe.anim, recipe.label .. '...', recipe.duration or 4000)
    ALD.Client.busy = false

    if not ok then
        ALD.Notify('Action annulée.', 'error')
        return
    end

    TriggerServerEvent(ALDConfig.Prefix .. ':craft', stationId, recipeId)
end

---OpenStation — menu ox_lib des recettes d'une station.
function ALD.OpenStation(stationId)
    local station = ALD.GetStation(stationId)
    if not station then return end

    if not ALD.CanUseStation(station.minGrade) then
        ALD.Notify(ALDConfig.Duty.required and "Vous devez être en service pour utiliser cet équipement."
                  or "Vous n'avez pas accès à cet équipement.", 'error')
        return
    end

    local counts  = GetInventoryCounts()
    local options = {}

    for _, entry in ipairs(ALD.RecipesForStation(stationId)) do
        local recipe  = entry.recipe
        local missing = MissingIngredients(recipe, counts)
        options[#options + 1] = {
            title       = recipe.label,
            description = #missing > 0 and 'Ingrédients manquants' or 'Prêt à préparer',
            icon        = #missing > 0 and 'circle-xmark' or 'circle-check',
            iconColor   = #missing > 0 and '#e5544b' or '#6fcf6f',
            metadata    = BuildMetadata(recipe, counts),
            onSelect    = function() ALD.StartCraft(stationId, entry.id) end,
        }
    end

    if #options == 0 then
        ALD.Notify('Aucune recette disponible sur ce poste.', 'error')
        return
    end

    lib.registerContext({
        id      = ALDConfig.Prefix .. '_station_' .. stationId,
        title   = ('%s — %s'):format(ALDConfig.JobLabel, station.label),
        options = options,
    })
    lib.showContext(ALDConfig.Prefix .. '_station_' .. stationId)
end
