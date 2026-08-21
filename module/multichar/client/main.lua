-- Mêmes contraintes que server/main.lua : ces events tournent avant que le
-- système de jetons LSLegacy (SendEventToServer) n'existe, donc on reste sur
-- RegisterNetEvent/TriggerServerEvent bruts, exactement comme `registerPlayer`.

LSLegacy.Multichar = {
    resolved = false,
    initReceived = false,
}

local function RenderCharacter(c)
    return {
        id = c.id,
        slot = c.slot,
        firstname = c.firstname,
        lastname = c.lastname,
    }
end

RegisterNetEvent('multichar:init')
AddEventHandler('multichar:init', function(characters, maxSlots)
    Config.Development.Print(("[multichar] init reçu : %d perso(s), maxSlots=%s"):format(#characters, tostring(maxSlots)))
    LSLegacy.Multichar.initReceived = true

    if maxSlots <= 1 and #characters <= 1 then
        local chosen = characters[1] and characters[1].id or nil
        Config.Development.Print("[multichar] fast-path -> registerPlayer(" .. tostring(chosen) .. ")")
        TriggerServerEvent('registerPlayer', chosen)
        LSLegacy.Multichar.resolved = true
        return
    end

    Config.Development.Print("[multichar] affichage de l'écran de sélection")
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    -- L'écran reste faded-out (noir) depuis la connexion : c'est normalement
    -- spawnPlayer qui lève ce fade, mais il ne s'exécute qu'APRÈS la
    -- sélection dans ce flux. Sans ça, la scène s'affiche bien mais reste
    -- invisible derrière le noir.
    if IsScreenFadedOut() then
        DoScreenFadeIn(500)
        local fadeTimer = GetGameTimer()
        while not IsScreenFadedIn() and (GetGameTimer() - fadeTimer) < 5000 do
            Wait(0)
        end
        Config.Development.Print("[multichar] fade-in " .. (IsScreenFadedIn() and "confirmé" or "non confirmé après 5s"))
    end

    if Config.Multichar.Apartment and Config.Multichar.Apartment.Enabled and LSLegacy.Multichar.ShowApartment then
        LSLegacy.Multichar.ShowApartment(characters, maxSlots)
        return
    end

    local rendered = {}
    for i = 1, #characters do rendered[i] = RenderCharacter(characters[i]) end

    SendNUIMessage({
        action = 'multichar:show',
        data = { characters = rendered, maxSlots = maxSlots }
    })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('multichar:deleted')
AddEventHandler('multichar:deleted', function(characters, maxSlots)
    if Config.Multichar.Apartment and Config.Multichar.Apartment.Enabled and LSLegacy.Multichar.ShowApartment then
        LSLegacy.Multichar.ShowApartment(characters, maxSlots)
        return
    end

    local rendered = {}
    for i = 1, #characters do rendered[i] = RenderCharacter(characters[i]) end

    SendNUIMessage({
        action = 'multichar:show',
        data = { characters = rendered, maxSlots = maxSlots }
    })
end)

-- Extrait pour être appelable aussi bien depuis le NUI carte-liste que depuis
-- la scène appartement (clic sur un ped/siège) sans dupliquer le fade-out.
function LSLegacy.Multichar.SelectCharacter(characterId)
    Config.Development.Print("[multichar] sélection -> registerPlayer(" .. tostring(characterId) .. ")")
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'multichar:hide' })

    -- Refade au noir : sinon la téléportation vers la position sauvegardée
    -- du personnage (faite par spawnPlayer juste après) serait visible.
    DoScreenFadeOut(500)
    Wait(600)

    TriggerServerEvent('registerPlayer', characterId)
    LSLegacy.Multichar.resolved = true
end

RegisterNUICallback('multichar:select', function(data, cb)
    LSLegacy.Multichar.SelectCharacter(data.characterId)
    cb('ok')
end)

RegisterNUICallback('multichar:delete', function(data, cb)
    TriggerServerEvent('multichar:deleteCharacter', data.characterId)
    cb('ok')
end)

-- Retente l'envoi si le serveur ne répond pas (paquet perdu, requête DB
-- bloquée sous charge...) au lieu de laisser le joueur bloqué indéfiniment
-- sur un écran noir sans le moindre message d'erreur.
function LSLegacy.Multichar.RequestSelection()
    Config.Development.Print("[multichar] RequestSelection: début")
    LSLegacy.Multichar.resolved     = false
    LSLegacy.Multichar.initReceived = false

    local attempts = 0
    while not LSLegacy.Multichar.initReceived and attempts < 12 do
        attempts = attempts + 1
        Config.Development.Print("[multichar] requestSlots, tentative " .. attempts)
        TriggerServerEvent('multichar:requestSlots')
        local waited = 0
        while not LSLegacy.Multichar.initReceived and waited < 5000 do
            Wait(100)
            waited = waited + 100
        end
    end

    if not LSLegacy.Multichar.initReceived then
        Config.Development.Print("[multichar] AUCUNE réponse serveur après " .. attempts .. " tentatives, on continue d'attendre passivement")
    end

    while not LSLegacy.Multichar.resolved do Wait(10) end
    Config.Development.Print("[multichar] RequestSelection: résolu")
end

-- ─── Retour à la sélection en cours de session (commande/menu admin) ──────
-- Le serveur a déjà sauvegardé et libéré le personnage actuel avant d'envoyer
-- cet event (module/multichar/server/main.lua, LSLegacy.Multichar.ReturnToSelection).
-- On refait exactement le même flux que la connexion initiale : pas de
-- logique de spawn dupliquée entre les deux cas.
RegisterNetEvent('multichar:forceReselect')
AddEventHandler('multichar:forceReselect', function()
    Config.Development.Print("[multichar] forceReselect reçu")
    DoScreenFadeOut(500)
    Wait(600)
    DisplayRadar(false)
    FreezeEntityPosition(PlayerPedId(), true)
    SetEntityVisible(PlayerPedId(), false)

    LSLegacy.PlayerData = {}
    LSLegacy.Multichar.resolved = false

    LSLegacy.Player.RunLoginFlow()
end)
