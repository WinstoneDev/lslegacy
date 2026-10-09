-- ls_kebabking (serveur) — fabrication.
-- Le client envoie stationId + recipeId (+ un choix de sauce). Tout le reste
-- (item produit, quantité, ingrédients consommés) est relu dans
-- config/recipes.lua, et le choix de sauce est validé contre la liste
-- blanche KKConfig.SauceChoices.

local Core = exports['lslegacy']

-- Cadence : un joueur légitime met `duration` ms par recette (progressbar).
-- On exige au moins 85 % de ce temps entre deux fabrications.
local nextCraftAt = {}

AddEventHandler('playerDropped', function()
    nextCraftAt[source] = nil
end)

-- ── Broche : cas spéciaux, hors transaction ingrédients -> résultats ─────
-- spit_mount (station 'spit_build') fabrique l'item kebab_spit normalement,
-- via la transaction générique plus bas (comme les pots de sauce : `unique`
-- + `data.uses`). spit_place et spit_cut (station 'spit') sont des cas
-- spéciaux : poser la broche retire l'item de l'inventaire et fait de la
-- broche un état PARTAGÉ de la station (KK.Spit, server/main.lua) — plus
-- personnel à qui l'a posée, n'importe quel employé en service peut ensuite
-- venir couper.
local function HandleSpitPlace(src, recipe)
    if KK.Spit.mounted then
        KK.Notify(src, "Une broche est déjà posée : videz-la avant d'en poser une autre.", 'error')
        return
    end

    -- Objet live du Core (pas l'instantané léger de KK.Sec.Employee) : il
    -- faut lire le `.inventory` réel, comme server/pots.lua.
    local player = LSLegacy.Players.Get(src)
    if not player then return end

    local inventory = player.inventory or {}
    local idx, entry
    for k, it in pairs(inventory) do
        if it.name == 'kebab_spit' then idx, entry = k, it break end
    end
    if not entry then
        KK.Notify(src, "Vous n'avez pas de broche montée sur vous.", 'error')
        return
    end
    local uses = (entry.data and entry.data.uses) or 0
    if uses <= 0 then
        KK.Notify(src, "Cette broche est vide.", 'error')
        return
    end

    table.remove(inventory, idx)
    player.inventory = inventory
    player:MarkDirty('inventory')
    player.weight = LSLegacy.Inventory.GetInventoryWeight(player.inventory)
    LSLegacy.Events.SendToClient('lslegacy:updatePlayer', src, player)

    KK.Spit.mounted   = true
    KK.Spit.remaining = uses

    KK.Notify(src, ('Broche posée sur le tournebroche (%d utilisations).'):format(uses), 'success')
    KK.Log(('%s (%s) a posé la broche (%d utilisations)'):format(player.name or 'Joueur', src, uses))
end

local function HandleSpitCut(src, player, recipe)
    if not KK.Spit.mounted or KK.Spit.remaining <= 0 then
        KK.Notify(src, "Il n'y a pas de broche posée avec de la viande dessus.", 'error')
        return
    end

    local give = {}
    for _, res in ipairs(recipe.results or {}) do
        give[#give + 1] = { item = res.item, count = res.count }
    end

    local result = Core:craftTransaction(src, {}, give) or {}
    if not result.ok then
        if result.reason == 'weight' then
            KK.Notify(src, "Vous ne pouvez pas porter davantage.", 'error')
        end
        return
    end

    KK.Spit.remaining = KK.Spit.remaining - 1
    if KK.Spit.remaining <= 0 then
        KK.Spit.mounted = false
        KK.Notify(src, "Viande de veau cuite x2 — la broche est vide, il faut en poser une nouvelle.", 'success')
    else
        KK.Notify(src, ('Viande de veau cuite x2 (reste %d)'):format(KK.Spit.remaining), 'success')
    end
    KK.Log(('%s (%s) a coupé la broche (reste %d)'):format(player.name or 'Joueur', src, KK.Spit.remaining))
end

---ValidateSauce — renvoie l'item de sauce validé, ou nil.
local function ValidateSauce(recipe, choice)
    local opt = recipe.options and recipe.options.sauce
    if not opt then return nil, true end                  -- recette sans option : OK
    if type(choice) ~= 'table' then return nil, false end
    local sauce = choice.sauce
    if type(sauce) ~= 'string' then return nil, false end
    for _, allowed in ipairs(KKConfig.SauceChoices) do
        if allowed == sauce then return sauce, true end
    end
    return nil, false
end

RegisterNetEvent(KKConfig.Prefix .. ':craft', function(stationId, recipeId, choice)
    local src = source

    -- 1. Fréquence
    if not KK.Sec.Allow(src, 'craft') then return end

    -- 2. Arguments
    if type(stationId) ~= 'string' or type(recipeId) ~= 'string' then return end

    local station = KK.GetStation(stationId)
    local recipe  = KK.GetRecipe(recipeId)
    if not station or not recipe then
        KK.Dbg(('recette ou station inconnue : %s / %s'):format(tostring(stationId), tostring(recipeId)))
        return
    end
    -- 3. La recette doit appartenir à la station ciblée (ou à celle dont
    -- cette station partage l'offre, ex. un second poste d'assemblage).
    if recipe.station ~= KK.RecipeStationId(stationId) then
        KK.Dbg(('recette %s demandée depuis la mauvaise station (%s)'):format(recipeId, stationId))
        return
    end
    if station.type ~= 'craft' then return end

    -- 4. Option (sauce) : liste blanche uniquement
    local sauce, sauceOk = ValidateSauce(recipe, choice)
    if not sauceOk then
        KK.Dbg(('choix de sauce invalide de %s sur %s'):format(src, recipeId))
        return
    end

    -- 5. Joueur, job, grade, service, distance
    local player = KK.CanWork(src, recipe.minGrade or station.minGrade, station.coords,
        (station.distance or 2.0) + KKConfig.Security.maxDistance)
    if not player then return end

    -- 6. Cadence par recette
    local now = GetGameTimer()
    if nextCraftAt[src] and now < nextCraftAt[src] then
        KK.Dbg(('cadence de fabrication non respectée par %s'):format(src))
        return
    end
    nextCraftAt[src] = now + math.floor((recipe.duration or 4000) * 0.85)

    -- 7. Cas spéciaux broche (voir plus haut). spit_mount, lui, passe par
    -- la transaction générique juste en dessous (comme un pot de sauce).
    if recipeId == 'spit_place' then
        HandleSpitPlace(src, recipe)
        return
    elseif recipeId == 'spit_cut' then
        HandleSpitCut(src, player, recipe)
        return
    end

    -- 8. Transaction atomique côté framework (vérifie ingrédients + poids)
    local take, give = {}, {}
    for _, ing in ipairs(recipe.ingredients or {}) do
        take[#take + 1] = { item = ing.item, count = ing.count }
    end
    if sauce then
        take[#take + 1] = { item = sauce, count = (recipe.options.sauce.count or 1) }
    end
    for _, res in ipairs(recipe.results or {}) do
        local entry = { item = res.item, count = res.count }
        if sauce then
            -- Le libellé porte la sauce choisie ; l'item reste le même
            -- (même image, même valeur nutritive).
            entry.label = ('%s (%s)'):format(KK.ItemLabel(res.item), KK.ItemLabel(sauce))
            entry.data  = { option = { sauce = sauce } }
        elseif res.data and res.data.uses then
            -- Pot de sauce : chaque instance emporte SA PROPRE table de
            -- compteur (jamais celle de la recette, sous peine de partager
            -- le nombre d'utilisations entre tous les pots fabriqués).
            entry.data  = { uses = res.data.uses }
            entry.label = ('%s (%d utilisations)'):format(KK.ItemLabel(res.item), res.data.uses)
        end
        give[#give + 1] = entry
    end

    local result = Core:craftTransaction(src, take, give) or {}
    if not result.ok then
        local reason = result.reason
        if reason == 'weight' then
            KK.Notify(src, "Vous ne pouvez pas porter davantage.", 'error')
        elseif reason == 'missing' then
            KK.Notify(src, "Il vous manque des ingrédients.", 'error')
        else
            KK.Dbg(('transaction refusée (%s) pour %s'):format(tostring(reason), recipeId))
        end
        return
    end

    -- 9. Retour joueur + log
    local produced = {}
    for _, res in ipairs(recipe.results or {}) do
        produced[#produced + 1] = ('%s x%d'):format(KK.ItemLabel(res.item), res.count)
    end
    local suffix = sauce and (' — ' .. KK.ItemLabel(sauce)) or ''
    KK.Notify(src, table.concat(produced, ', ') .. suffix, 'success')
    KK.Log(('%s (%s) a préparé %s%s'):format(player.name or 'Joueur', src, table.concat(produced, ', '), suffix))
end)
