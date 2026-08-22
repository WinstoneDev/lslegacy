-- Adapté de rpemotes-reborn (github.com/alberttheprince/rpemotes-reborn) : données extraites de son
-- catalogue officiel, débarrassées de tout contenu adulte, traduites en français. Volontairement exclus :
-- Pointer du doigt / Ragdoll / Lever les mains / S'accroupir, déjà liés à leurs propres touches (B/U/X).

local Emotes = {
    currentId = nil, -- id de l'émote en cours (nil si aucune)
    prop = nil,      -- handle de l'accessoire attaché, le cas échéant
    byId = {},
}

local Categories = {
    { key = "emotes", name = "Émotes", desc = "Gestes et réactions", data = EmotesData.emotes },
    { key = "dances", name = "Danses", desc = "Trémoussez-vous", data = EmotesData.dances },
    { key = "props",  name = "Objets", desc = "Émotes avec accessoire", data = EmotesData.props },
    { key = "animals", name = "Émotes animaux", desc = "Nécessite d'être un animal compatible", data = EmotesData.animals },
}

for _, category in ipairs(Categories) do
    for _, item in ipairs(category.data) do
        Emotes.byId[item.id] = item
    end
end

-- Chargement des ressources

local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end
    return HasAnimDictLoaded(dict)
end

local function LoadPropModel(model)
    local hash = GetHashKey(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

-- Démarrage / arrêt

local function StopEmote()
    local ped = PlayerPedId()
    if Emotes.prop and DoesEntityExist(Emotes.prop) then
        DeleteEntity(Emotes.prop)
    end
    Emotes.prop = nil
    if Emotes.currentId then
        ClearPedTasksImmediately(ped)
        LocalPlayer.state:set('lslegacy_emotes_ptfx', nil, true)
    end
    Emotes.currentId = nil
end

local function StartEmote(item)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) or not IsPedOnFoot(ped) then
        LSLegacy.ShowNotification("Emotes", "Impossible de faire cette animation dans cet état.", "error")
        return
    end

    StopEmote()
    Emotes.currentId = item.id

    if item.scenario then
        TaskStartScenarioInPlace(ped, item.scenario, 0, true)
        return
    end

    if not LoadAnimDict(item.dict) then
        Emotes.currentId = nil
        return
    end

    TaskPlayAnim(ped, item.dict, item.clip, 8.0, -8.0, -1, item.loop and 1 or 0, 0, false, false, false)
    RemoveAnimDict(item.dict)

    if item.prop then
        local hash = LoadPropModel(item.prop)
        if hash then
            local coords = GetEntityCoords(ped)
            local obj = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, false)
            local p = item.placement
            AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, item.propBone), p[1], p[2], p[3], p[4], p[5], p[6], true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(hash)
            Emotes.prop = obj
        end
    end

    if item.ptfxAsset then
        LocalPlayer.state:set('lslegacy_emotes_ptfx', {
            asset = item.ptfxAsset, name = item.ptfxName,
            offset = item.ptfxOffset, rot = item.ptfxRot,
            bone = item.ptfxBone, scale = item.ptfxScale,
        }, true)
    end
end

-- PTFX partagés — visibles par tout le monde via statebag répliqué (fumée, feu, feux d'artifice…)

local PtfxHandles = {} -- [serverId] = handle de particule en cours

local function StopPtfxFor(serverId)
    if PtfxHandles[serverId] then
        StopParticleFxLooped(PtfxHandles[serverId], false)
        PtfxHandles[serverId] = nil
    end
end

AddStateBagChangeHandler('lslegacy_emotes_ptfx', '', function(bagName, _key, value)
    local serverIdStr = bagName:match('^player:(%d+)$')
    if not serverIdStr then return end
    local serverId = tonumber(serverIdStr)

    StopPtfxFor(serverId)
    if not value then return end

    local player = GetPlayerFromServerId(serverId)
    if not player or player == -1 then return end
    local ped = GetPlayerPed(player)
    if not DoesEntityExist(ped) then return end

    RequestNamedPtfxAsset(value.asset)
    local timeout = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(value.asset) and GetGameTimer() < timeout do Wait(0) end
    if not HasNamedPtfxAssetLoaded(value.asset) then return end

    UseParticleFxAssetNextCall(value.asset)
    local off = value.offset or { 0.0, 0.0, 0.0 }
    local rot = value.rot or { 0.0, 0.0, 0.0 }
    local bone = value.bone and GetPedBoneIndex(ped, value.bone) or GetEntityBoneIndexByName(ped, "VFX")
    PtfxHandles[serverId] = StartParticleFxLoopedOnEntityBone(
        value.name, ped, off[1], off[2], off[3], rot[1], rot[2], rot[3],
        bone, value.scale or 1.0, false, false, false)
    RemoveNamedPtfxAsset(value.asset)
end)

-- Émotes animaux — nécessitent que le ped soit déjà un modèle compatible (pas de système "devenir animal" ici).

local AnimalGroupModels = {
    dog_big   = { `a_c_rottweiler`, `a_c_shepherd`, `a_c_retriever`, `a_c_husky` },
    dog_small = { `a_c_pug` },
    cat       = { `a_c_cat_01` },
    coyote    = { `a_c_coyote` },
}

local function IsAnimalCompatible(item)
    if not item.animalGroup then return true end
    local models = AnimalGroupModels[item.animalGroup]
    if not models then return true end
    local currentModel = GetEntityModel(PlayerPedId())
    for _, model in ipairs(models) do
        if currentModel == model then return true end
    end
    return false
end

local function StartAnimalEmote(item)
    if not IsAnimalCompatible(item) then
        LSLegacy.ShowNotification("Emotes", "Vous devez être un animal compatible pour faire cette animation.", "error")
        return
    end
    StartEmote(item)
end

-- Surveillance : coupe l'émote si le joueur monte en véhicule, meurt, ou si
-- un geste ponctuel (non bouclé) est arrivé à sa fin naturelle.
CreateThread(function()
    while true do
        if Emotes.currentId then
            Wait(0)
            local ped = PlayerPedId()
            local item = Emotes.byId[Emotes.currentId]

            if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) then
                StopEmote()
            elseif item and not item.loop and item.dict and not IsEntityPlayingAnim(ped, item.dict, item.clip, 3) then
                Emotes.currentId = nil
            end
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        StopEmote()
        for serverId in pairs(PtfxHandles) do
            StopPtfxFor(serverId)
        end
    end
end)

-- Styles de marche — persistants via KVP (survit déco/reco sur ce PC)

local Walks = { current = nil, byId = {} }
for _, w in ipairs(EmotesData.walks) do Walks.byId[w.id] = w end

local function ApplyWalk(item, persist)
    local ped = PlayerPedId()
    RequestClipSet(item.anim)
    local timeout = GetGameTimer() + 3000
    while not HasClipSetLoaded(item.anim) and GetGameTimer() < timeout do Wait(0) end
    if not HasClipSetLoaded(item.anim) then return end
    SetPedMovementClipset(ped, item.anim, 0.25)
    Walks.current = item.id
    if persist then SetResourceKvp("lslegacy_emotes_walk", item.id) end
end

local function ResetWalk()
    ResetPedMovementClipset(PlayerPedId(), 0.0)
    Walks.current = nil
    DeleteResourceKvp("lslegacy_emotes_walk")
end

CreateThread(function()
    Wait(2000)
    local saved = GetResourceKvpString("lslegacy_emotes_walk")
    if saved and Walks.byId[saved] then
        ApplyWalk(Walks.byId[saved], false)
    end
end)

-- Expressions du visage — persistantes via KVP

local Expressions = { current = nil, byId = {} }
for _, e in ipairs(EmotesData.expressions) do Expressions.byId[e.id] = e end

local function ApplyExpression(item, persist)
    SetFacialIdleAnimOverride(PlayerPedId(), item.anim, 0)
    Expressions.current = item.id
    if persist then SetResourceKvp("lslegacy_emotes_expression", item.id) end
end

local function ResetExpression()
    ClearFacialIdleAnimOverride(PlayerPedId())
    Expressions.current = nil
    DeleteResourceKvp("lslegacy_emotes_expression")
end

CreateThread(function()
    Wait(2000)
    local saved = GetResourceKvpString("lslegacy_emotes_expression")
    if saved and Expressions.byId[saved] then
        ApplyExpression(Expressions.byId[saved], false)
    end
end)

-- Émotes synchronisées à 2 joueurs. Proximité (3m) + confirmation par la cible : Y = accepter, L = refuser (10s).

local Shared = { byId = {}, partner = nil, active = nil, awaitingResponse = false }
for _, s in ipairs(EmotesData.shared) do Shared.byId[s.id] = s end

local function GetClosestPlayer(maxDistance)
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local closest, closestDist = nil, maxDistance
    for _, p in ipairs(GetActivePlayers()) do
        local otherPed = GetPlayerPed(p)
        if otherPed ~= myPed then
            local dist = #(myCoords - GetEntityCoords(otherPed))
            if dist < closestDist then
                closest, closestDist = p, dist
            end
        end
    end
    return closest
end

local function StopShared()
    local ped = PlayerPedId()
    if Shared.active then
        ClearPedTasksImmediately(ped)
    end
    Shared.partner, Shared.active = nil, nil
end

local function CancelSharedByUser()
    if Shared.partner then
        LSLegacy.Events.SendToServer('lslegacy_emotes:cancelShared', Shared.partner)
    end
    StopShared()
end

local function RequestSharedEmote(item)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) or not IsPedOnFoot(ped) then
        LSLegacy.ShowNotification("Emotes", "Impossible de faire cette animation dans cet état.", "error")
        return
    end

    local closest = GetClosestPlayer(3.0)
    if not closest then
        LSLegacy.ShowNotification("Emotes", "Personne n'est assez proche.", "error")
        return
    end

    LSLegacy.Events.SendToServer('lslegacy_emotes:requestShared', GetPlayerServerId(closest), item.id)
    LSLegacy.ShowNotification("Emotes", ("Demande envoyée à %s (%s)."):format(GetPlayerName(closest), item.label), 'info')
end

local function PlaySharedLocal(emoteId, otherServerId)
    local item = Shared.byId[emoteId]
    if not item then return end
    local ped = PlayerPedId()
    local otherPlayer = GetPlayerFromServerId(otherServerId)
    local otherPed = otherPlayer and otherPlayer ~= -1 and GetPlayerPed(otherPlayer) or nil

    StopShared()
    Shared.partner = otherServerId
    Shared.active  = emoteId

    if not LoadAnimDict(item.dict) then
        Shared.active = nil
        return
    end

    TaskPlayAnim(ped, item.dict, item.clip, 8.0, -8.0, -1, item.loop and 1 or 0, 0, false, false, false)
    RemoveAnimDict(item.dict)

    if otherPed and DoesEntityExist(otherPed) then
        if item.attachTo then
            local p, r = item.pos, item.rot
            AttachEntityToEntity(ped, otherPed, GetPedBoneIndex(otherPed, item.bone or -1),
                p[1], p[2], p[3], r[1], r[2], r[3], false, false, false, true, 1, true)
        elseif item.syncFront or item.syncSide then
            local coords = GetOffsetFromEntityInWorldCoords(otherPed, item.syncSide or 0.0, item.syncFront or 0.0, 0.0)
            SetEntityHeading(ped, GetEntityHeading(otherPed) + 180.0)
            SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z)
        end
    end
end

LSLegacy.Events.Register('lslegacy_emotes:clientPlayShared', function(emoteId, otherServerId)
    PlaySharedLocal(emoteId, otherServerId)
end)

LSLegacy.Events.Register('lslegacy_emotes:clientPlaySharedTarget', function(emoteId, otherServerId)
    PlaySharedLocal(emoteId, otherServerId)
end)

LSLegacy.Events.Register('lslegacy_emotes:clientCancelShared', function(otherServerId)
    if Shared.partner and Shared.partner == otherServerId then
        StopShared()
    end
end)

LSLegacy.Events.Register('lslegacy_emotes:clientRequestShared', function(emoteId, requesterServerId)
    if Shared.awaitingResponse then return end
    local item = Shared.byId[emoteId]
    if not item then return end

    Shared.awaitingResponse = true
    LSLegacy.ShowNotification("Emotes à deux", ("%s vous propose « %s ». Y pour accepter, L pour refuser."):format(GetPlayerName(GetPlayerFromServerId(requesterServerId)) or "Un joueur", item.label), 'info', 10000)

    CreateThread(function()
        local timeout = GetGameTimer() + 10000
        while Shared.awaitingResponse and GetGameTimer() < timeout do
            Wait(0)
            if IsControlJustPressed(1, 246) then -- Y
                Shared.awaitingResponse = false
                LSLegacy.Events.SendToServer('lslegacy_emotes:confirmShared', requesterServerId, emoteId, item.target)
            elseif IsControlJustPressed(1, 182) then -- L
                Shared.awaitingResponse = false
                LSLegacy.ShowNotification("Emotes", "Émote refusée.", 'info')
            end
        end
        Shared.awaitingResponse = false
    end)
end)

-- Surveillance : coupe l'émote partagée si un des deux joueurs monte en
-- véhicule, meurt, se déconnecte, ou si le partenaire n'existe plus.
CreateThread(function()
    while true do
        if Shared.active then
            Wait(0)
            local ped = PlayerPedId()
            local otherPlayer = Shared.partner and GetPlayerFromServerId(Shared.partner)
            if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped)
                or not otherPlayer or otherPlayer == -1 then
                CancelSharedByUser()
            end
        else
            Wait(500)
        end
    end
end)

-- Annulation externe (touche X du menu crouch) + API exposée

LSLegacy.Emotes = LSLegacy.Emotes or {}

LSLegacy.Emotes.HasActiveAnimation = function()
    return Emotes.currentId ~= nil or Shared.active ~= nil
end

LSLegacy.Emotes.CancelActiveAnimation = function()
    if Emotes.currentId then StopEmote() end
    if Shared.active then CancelSharedByUser() end
end

-- Changement de personnage (multichar) : on coupe tout avant que le ped
-- ne soit détruit/recréé, pour ne pas laisser un accessoire orphelin.
AddEventHandler('multichar:init', function()
    LSLegacy.Emotes.CancelActiveAnimation()
end)

-- Normalisation des accents pour le tri alphabétique
local ACCENT_TO_BASE = {
    ["\195\128"] = "A", ["\195\130"] = "A", ["\195\132"] = "A", -- À Â Ä
    ["\195\135"] = "C",                                          -- Ç
    ["\195\136"] = "E", ["\195\137"] = "E", ["\195\138"] = "E", ["\195\139"] = "E", -- È É Ê Ë
    ["\195\142"] = "I", ["\195\143"] = "I",                     -- Î Ï
    ["\195\148"] = "O",                                          -- Ô
    ["\195\153"] = "U", ["\195\155"] = "U", ["\195\156"] = "U", -- Ù Û Ü
}

local function SortedData(data)
    local sorted = {}
    for _, item in ipairs(data) do table.insert(sorted, item) end
    table.sort(sorted, function(a, b)
        local la, lb = a.label:upper(), b.label:upper()
        for acc, base in pairs(ACCENT_TO_BASE) do
            la = la:gsub(acc, base)
            lb = lb:gsub(acc, base)
        end
        return la < lb
    end)
    return sorted
end

-- Favoris — sauvegardés par personnage (players.`boutique-id`), pas par compte

local Favorites = { keys = {} }

local function FavoriteKey(category, item)
    return category.key .. ":" .. item.id
end

local FavoritesCategory -- déclaré plus bas, une fois toutes les catégories connues

local function RebuildFavoritesData()
    if not FavoritesCategory then return end
    local list = {}
    for _, category in ipairs(Categories) do
        if category ~= FavoritesCategory then
            for _, item in ipairs(category.data) do
                if Favorites.keys[FavoriteKey(category, item)] then
                    list[#list + 1] = { id = FavoriteKey(category, item), label = item.label, __cat = category, __item = item }
                end
            end
        end
    end
    FavoritesCategory.data = list
    FavoritesCategory.sortedData = SortedData(list)
end

local function IsFavorite(category, item)
    return Favorites.keys[FavoriteKey(category, item)] == true
end

local function ToggleFavorite(category, item)
    local key = FavoriteKey(category, item)
    local nowFavorite = not Favorites.keys[key]
    Favorites.keys[key] = nowFavorite or nil
    LSLegacy.Events.SendToServer('lslegacy_emotes:toggleFavorite', key)
    RebuildFavoritesData()
    LSLegacy.ShowNotification("Emotes", (nowFavorite and "Ajouté aux favoris : " or "Retiré des favoris : ") .. item.label, 'info')
end

LSLegacy.Events.Register('lslegacy_emotes:clientSetFavorites', function(keys)
    Favorites.keys = {}
    for _, key in ipairs(keys) do
        Favorites.keys[key] = true
    end
    RebuildFavoritesData()
end)

-- Redemande les favoris à chaque fois que le personnage actif change
-- (connexion initiale et changement de personnage via multichar).
CreateThread(function()
    local lastCharacterId = nil
    while true do
        Wait(1000)
        local characterId = LSLegacy.PlayerData and LSLegacy.PlayerData["boutique-id"]
        if characterId and characterId ~= lastCharacterId then
            lastCharacterId = characterId
            LSLegacy.Events.SendToServer('lslegacy_emotes:getFavorites')
        end
    end
end)

-- Commande /e <id> — jouer une émote directement par son identifiant

RegisterCommand('e', function(_source, args)
    local id = args[1]
    if not id then
        LSLegacy.ShowNotification("Emotes", "Utilisation : /e id_emote", "error")
        return
    end

    local item = Emotes.byId[id]
    if item then
        StartEmote(item)
        return
    end

    item = Walks.byId[id]
    if item then
        ApplyWalk(item, true)
        return
    end

    item = Expressions.byId[id]
    if item then
        ApplyExpression(item, true)
        return
    end

    item = Shared.byId[id]
    if item then
        RequestSharedEmote(item)
        return
    end

    LSLegacy.ShowNotification("Emotes", ("'%s' n'est pas un identifiant d'émote valide."):format(id), "error")
end, false)

-- Menu RageUI — Principal > Catégorie > Liste

EmotesMenu = {
    opened    = false,
    rendering = false,
}

EmotesMenu.mainMenu = RageUI.CreateMenu("Émotes", "Sélectionnez une catégorie")
EmotesMenu.mainMenu.Display.Header = true

-- Comportement par défaut des catégories emotes/dances/props/animals
for _, category in ipairs(Categories) do
    category.onSelect = category.onSelect or function(item) StartEmote(item) end
    category.isActive = category.isActive or function(item) return Emotes.currentId == item.id end
end

-- Les émotes animaux passent par une vérification de modèle avant de jouer
for _, category in ipairs(Categories) do
    if category.key == "animals" then
        category.onSelect = function(item) StartAnimalEmote(item) end
    end
end

table.insert(Categories, {
    key = "walks", name = "Styles de marche", desc = "Change ta démarche",
    data = EmotesData.walks,
    onSelect    = function(item) ApplyWalk(item, true) end,
    isActive    = function(item) return Walks.current == item.id end,
    onReset     = ResetWalk,
    resetLabel  = "Réinitialiser la démarche",
    resetActive = function() return Walks.current ~= nil end,
})

table.insert(Categories, {
    key = "expressions", name = "Expressions", desc = "Change ton humeur",
    data = EmotesData.expressions,
    onSelect    = function(item) ApplyExpression(item, true) end,
    isActive    = function(item) return Expressions.current == item.id end,
    onReset     = ResetExpression,
    resetLabel  = "Réinitialiser l'expression",
    resetActive = function() return Expressions.current ~= nil end,
})

table.insert(Categories, {
    key = "shared", name = "Émotes à deux", desc = "Avec le joueur le plus proche (3m)",
    data = EmotesData.shared,
    onSelect    = function(item) RequestSharedEmote(item) end,
    isActive    = function(item) return Shared.active == item.id end,
    onReset     = CancelSharedByUser,
    resetLabel  = "Annuler l'émote partagée",
    resetActive = function() return Shared.active ~= nil end,
})

FavoritesCategory = {
    key = "favorites", name = "Favoris", desc = "Vos émotes favorites (touche F4 pour en ajouter/retirer)",
    data = {},
    onSelect = function(wrapper) wrapper.__cat.onSelect(wrapper.__item) end,
    isActive = function(wrapper) return wrapper.__cat.isActive(wrapper.__item) end,
}
table.insert(Categories, 1, FavoritesCategory)
RebuildFavoritesData()

-- Création des sous-menus et tri des données une seule fois au chargement
for _, category in ipairs(Categories) do
    category.catMenu    = RageUI.CreateSubMenu(EmotesMenu.mainMenu, category.name, category.desc)
    category.catMenu:AcceptFilter(true)
    category.sortedData = SortedData(category.data)
end

EmotesMenu.mainMenu.Closed = function()
    EmotesMenu.opened = false
end

-- Catégorie actuellement affichée + décalage d'index (bouton reset/Line),
-- utilisés par la touche F4 pour retrouver l'item actuellement survolé.
local CurrentlyVisibleCategory = nil

function EmotesMenu:Toggle()
    if EmotesMenu.opened then
        EmotesMenu.opened = false
        RageUI.CloseAll()
        return
    end

    EmotesMenu.opened = true
    RageUI.Visible(EmotesMenu.mainMenu, true)

    if EmotesMenu.rendering then return end
    EmotesMenu.rendering = true

    CreateThread(function()
        while EmotesMenu.rendering do
            Wait(0)
            CurrentlyVisibleCategory = nil

            -- Menu principal
            RageUI.IsVisible(EmotesMenu.mainMenu, function()
                if Emotes.currentId then
                    local item = Emotes.byId[Emotes.currentId]
                    RageUI.Button("Arrêter l'animation", nil, {
                        RightLabel = item and item.label or "En cours",
                    }, true, {
                        onSelected = function() StopEmote() end,
                    })
                    RageUI.Line()
                end
                for _, category in ipairs(Categories) do
                    RageUI.Button(category.name, category.desc, { RightLabel = "→" }, true, {}, category.catMenu)
                end
            end)

            -- Sous-menus des catégories
            for _, category in ipairs(Categories) do
                RageUI.IsVisible(category.catMenu, function()
                    CurrentlyVisibleCategory = category
                    -- Reflète exactement ce que RageUI va compter comme "options"
                    -- (le filtre AcceptFilter peut faire disparaître des boutons),
                    -- pour que F4 retrouve toujours le bon item à l'Index affiché.
                    local visible = {}

                    if category.onReset and category.resetActive() then
                        if isAcceptByFiltre(category.resetLabel) then
                            table.insert(visible, "__RESET__")
                        end
                        RageUI.Button(category.resetLabel, nil, {}, true, {
                            onSelected = function() category.onReset() end,
                        })
                        RageUI.Line()
                        table.insert(visible, "__LINE__") -- RageUI.Line() compte toujours un slot
                    end

                    for _, item in ipairs(category.sortedData) do
                        local realCat, realItem = category, item
                        if category.key == "favorites" then
                            realCat, realItem = item.__cat, item.__item
                        end
                        local star = IsFavorite(realCat, realItem) and "* " or ""
                        if isAcceptByFiltre(star .. item.label) then
                            table.insert(visible, item)
                        end
                        RageUI.Button(star .. item.label, "/e " .. realItem.id, {
                            RightLabel = category.isActive(item) and "En cours" or nil,
                        }, true, {
                            onSelected = function() category.onSelect(item) end,
                        })
                    end

                    category.currentVisible = visible
                end)
            end

            if not RageUI.GetInMenu() then
                EmotesMenu.rendering = false
                EmotesMenu.opened    = false
            end
        end
    end)
end

Keys.Register("F3", "F3", "Ouvrir le menu des émotes", function()
    EmotesMenu:Toggle()
end)

-- F4 : ajoute/retire des favoris l'émote actuellement survolée dans la liste
-- (currentVisible reflète l'effet du filtre RageUI, donc l'Index affiché
-- correspond toujours au bon item même quand la liste est filtrée).
RegisterCommand('lslegacy_emotes_favorite', function()
    if not EmotesMenu.opened or not CurrentlyVisibleCategory then return end
    local category = CurrentlyVisibleCategory
    local visible = category.currentVisible
    if not visible then return end

    local entry = visible[category.catMenu.Index]
    if entry == nil or entry == "__RESET__" or entry == "__LINE__" then return end

    if category.key == "favorites" then
        ToggleFavorite(entry.__cat, entry.__item)
    else
        ToggleFavorite(category, entry)
    end
end, false)

RegisterKeyMapping('lslegacy_emotes_favorite', 'Ajouter/retirer des favoris (menu émotes)', 'keyboard', 'F4')