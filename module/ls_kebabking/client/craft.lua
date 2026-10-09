-- ls_kebabking (client) — menus de fabrication, avec choix de la sauce à
-- l'assemblage. Le menu n'est qu'un affichage : il envoie au serveur un
-- stationId + un recipeId (+ le choix de sauce), jamais l'item produit.

local function GetInventoryCounts()
    local counts = {}
    local data = exports['lslegacy']:getPlayerData()
    for _, item in pairs((data and data.inventory) or {}) do
        counts[item.name] = (counts[item.name] or 0) + (item.count or 0)
    end
    return counts
end

---SauceRequirement — sauce choisie transformée en ligne d'ingrédient.
local function SauceRequirement(recipe, choice)
    local opt = recipe.options and recipe.options.sauce
    if not opt or not choice or not choice.sauce then return nil end
    return { item = choice.sauce, count = opt.count or 1 }
end

---MissingIngredients — { { item, label, need, have }, ... }
local function MissingIngredients(recipe, counts, choice)
    local missing = {}
    local requirements = {}
    for _, ing in ipairs(recipe.ingredients or {}) do requirements[#requirements + 1] = ing end
    local sauce = SauceRequirement(recipe, choice)
    if sauce then requirements[#requirements + 1] = sauce end

    for _, ing in ipairs(requirements) do
        local have = counts[ing.item] or 0
        if have < ing.count then
            missing[#missing + 1] = {
                item = ing.item, label = KK.ItemLabel(ing.item), need = ing.count, have = have,
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
            label = KK.ItemLabel(ing.item),
            value = ('%d / %d'):format(have, ing.count),
        }
    end
    if recipe.options and recipe.options.sauce then
        meta[#meta + 1] = { label = 'Sauce', value = 'au choix' }
    end
    for _, res in ipairs(recipe.results or {}) do
        meta[#meta + 1] = { label = 'Donne', value = ('%s x%d'):format(KK.ItemLabel(res.item), res.count) }
    end
    return meta
end

---StartCraft — vérifie localement (confort), joue l'animation, puis demande
---la fabrication au serveur qui refait TOUTES les vérifications.
function KK.StartCraft(stationId, recipeId, choice)
    if KK.Client.busy then return end
    local recipe = KK.GetRecipe(recipeId)
    local station = KK.GetStation(stationId)
    if not recipe or not station or recipe.station ~= KK.RecipeStationId(stationId) then return end

    if not KK.CanUseStation(recipe.minGrade or station.minGrade) then
        if not KK.IsEmployee(recipe.minGrade or station.minGrade) then
            KK.Notify("Vous n'avez pas accès à cet équipement.", 'error')
        else
            KK.Notify("Vous devez être en service pour utiliser cet équipement (tablette MDT).", 'error')
        end
        return
    end

    -- Une recette à option exige un choix valide avant même de commencer.
    if recipe.options and recipe.options.sauce then
        local valid = false
        for _, sauce in ipairs(KKConfig.SauceChoices) do
            if choice and choice.sauce == sauce then valid = true break end
        end
        if not valid then
            KK.Notify("Choisissez une sauce.", 'error')
            return
        end
    end

    local missing = MissingIngredients(recipe, GetInventoryCounts(), choice)
    if #missing > 0 then
        local lines = {}
        for _, m in ipairs(missing) do
            lines[#lines + 1] = ('%s x%d'):format(m.label, m.need - m.have)
        end
        KK.Notify('Ingrédients manquants :\n' .. table.concat(lines, '\n'), 'error')
        return
    end

    KK.Client.busy = true
    local ok = KK.PlayCraftAnim(recipe.anim, recipe.label .. '...', recipe.duration or 4000)
    KK.Client.busy = false

    if not ok then
        KK.Notify('Action annulée.', 'error')
        return
    end

    TriggerServerEvent(KKConfig.Prefix .. ':craft', stationId, recipeId, choice)
end

---OpenSauceMenu — deuxième écran : le client choisit sa sauce au montage.
function KK.OpenSauceMenu(stationId, recipeId)
    local recipe = KK.GetRecipe(recipeId)
    if not recipe then return end

    local counts  = GetInventoryCounts()
    local needed  = (recipe.options and recipe.options.sauce and recipe.options.sauce.count) or 1
    local options = {}

    for _, sauce in ipairs(KKConfig.SauceChoices) do
        local have = counts[sauce] or 0
        options[#options + 1] = {
            title       = KK.ItemLabel(sauce),
            description = ('En stock : %d / %d'):format(have, needed),
            icon        = have >= needed and 'circle-check' or 'circle-xmark',
            iconColor   = have >= needed and '#6fcf6f' or '#e5544b',
            onSelect    = function() KK.StartCraft(stationId, recipeId, { sauce = sauce }) end,
        }
    end

    lib.registerContext({
        id      = KKConfig.Prefix .. '_sauce_' .. recipeId,
        title   = recipe.label .. ' — sauce',
        menu    = KKConfig.Prefix .. '_station_' .. stationId,
        options = options,
    })
    lib.showContext(KKConfig.Prefix .. '_sauce_' .. recipeId)
end

---OpenStation — menu ox_lib des recettes d'une station.
function KK.OpenStation(stationId)
    local station = KK.GetStation(stationId)
    if not station then return end

    if not KK.CanUseStation(station.minGrade) then
        if not KK.IsEmployee(station.minGrade) then
            KK.Notify("Vous n'avez pas accès à cet équipement.", 'error')
        else
            KK.Notify("Vous devez être en service pour utiliser cet équipement (tablette MDT).", 'error')
        end
        return
    end

    local counts  = GetInventoryCounts()
    local options = {}

    for _, entry in ipairs(KK.RecipesForStation(stationId)) do
        local recipe   = entry.recipe
        local hasSauce = recipe.options ~= nil and recipe.options.sauce ~= nil
        -- Sans choix de sauce encore fait, on n'évalue que les ingrédients fixes.
        local missing  = MissingIngredients(recipe, counts, nil)
        options[#options + 1] = {
            title       = recipe.label,
            description = #missing > 0 and 'Ingrédients manquants'
                          or (hasSauce and 'Choisir la sauce' or 'Prêt à préparer'),
            icon        = #missing > 0 and 'circle-xmark' or (hasSauce and 'droplet' or 'circle-check'),
            iconColor   = #missing > 0 and '#e5544b' or '#6fcf6f',
            metadata    = BuildMetadata(recipe, counts),
            onSelect    = function()
                if hasSauce then
                    KK.OpenSauceMenu(stationId, entry.id)
                else
                    KK.StartCraft(stationId, entry.id, nil)
                end
            end,
        }
    end

    if #options == 0 then
        KK.Notify('Aucune recette disponible sur ce poste.', 'error')
        return
    end

    lib.registerContext({
        id      = KKConfig.Prefix .. '_station_' .. stationId,
        title   = ('%s — %s'):format(KKConfig.JobLabel, station.label),
        options = options,
    })
    lib.showContext(KKConfig.Prefix .. '_station_' .. stationId)
end
