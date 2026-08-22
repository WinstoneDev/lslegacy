--  HEALTH INSPECTION — Pont NUI client (SAMU)
--
--  Outil de terrain (pas un onglet MDT) : ouvert en ciblant un patient
--  via ox_target (samu_bag, cf. client/actions.lua). NUI autonome,
--  4ᵉ iframe du shell (module/creatorPerso/html/ui.html), préfixe `hi:`.
--
--  Même principe que le pont MDT médical (mdt_medical.lua), mais
--  indépendant : lectures → requête/réponse tokenisée (hi:poll →
--  samu:hi:poll → samu:hi:pollResult), écritures → events tokenisés
--  (samu:hi:useItem → samu:hi:useItemResult).

local function Notify(msg, type)
    TriggerEvent(Config.SAMU.NotifyEvent, 'SAMU', msg, 5000, type or 'info')
end

local function PlayAnim(dict, anim, duration, flag)
    flag = flag or 49
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do
        Wait(100); t = t + 1
    end
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, duration, flag, 0, false, false, false)
    Wait(duration)
    ClearPedTasks(PlayerPedId())
end

local hiOpen   = false
local hiTarget = nil

--  Ouverture / fermeture

local function openHI(payload)
    if hiOpen then return end
    hiOpen   = true
    hiTarget = payload.target
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'hi:open', data = payload })
end

local function closeHI()
    if not hiOpen then return end
    hiOpen   = false
    hiTarget = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hi:hide' })
end

-- Appelée depuis client/actions.lua (cible ox_target samu_bag), après
-- vérification du cooldown 'bag'.
function SAMU.OpenHealthInspection(targetSrc)
    LSLegacy.Events.SendToServer('samu:hi:open', { target = targetSrc })
end

LSLegacy.Events.Register('samu:hi:openResult', function(payload)
    if type(payload) ~= 'table' or not payload.success then return end
    openHI(payload)
end)

RegisterNUICallback('hi:close', function(_, cb)
    closeHI()
    cb('ok')
end)

-- Branchement du moniteur cardiaque : geste RP requis avant que le rythme
-- cardiaque ne s'affiche dans la NUI (cohérence — le patient doit d'abord
-- être équipé des électrodes).
RegisterNUICallback('hi:attachMonitor', function(_, cb)
    PlayAnim('amb@medic@standing@kneel@base', 'base', Config.SAMU.Actions.monitorAttachDuration, 49)
    cb('ok')
end)

--  Écriture : utiliser un item de la trousse sur un membre

RegisterNUICallback('hi:useItem', function(data, cb)
    if type(data) == 'table' and hiTarget then
        LSLegacy.Events.SendToServer('samu:hi:useItem', {
            target = hiTarget,
            part   = data.part,
            item   = data.item,
        })
    end
    cb('ok') -- la réponse arrive de façon asynchrone via samu:hi:useItemResult
end)

LSLegacy.Events.Register('samu:hi:useItemResult', function(payload)
    if type(payload) ~= 'table' then return end
    SendNUIMessage({ action = 'hi:useItemResult', data = payload })

    if payload.success then
        Notify(string.format(Lang.SAMU.bag_item_used, payload.label), 'success')
    elseif payload.reason == 'unconscious' then
        Notify(Lang.SAMU.bag_target_unconscious, 'error')
    elseif payload.reason == 'full_health' then
        Notify(Lang.SAMU.bag_already_full_health, 'warning')
    elseif payload.reason == 'missing_item' then
        Notify(string.format(Lang.SAMU.bag_item_missing, payload.item or '?'), 'error')
    end
end)

--  Lecture : rafraîchissement léger (mannequin + moniteur cardiaque)

local pendingPolls, pollCounter = {}, 0

LSLegacy.Events.Register('samu:hi:pollResult', function(payload)
    if type(payload) ~= 'table' then return end
    local cb = pendingPolls[payload.reqId]
    if cb then
        pendingPolls[payload.reqId] = nil
        cb(payload.result)
    end
end)

RegisterNUICallback('hi:poll', function(_, cb)
    if not hiTarget then cb(false) return end
    pollCounter = pollCounter + 1
    local reqId = pollCounter
    pendingPolls[reqId] = function(res) cb(res == nil and false or res) end
    LSLegacy.Events.SendToServer('samu:hi:poll', { reqId = reqId, target = hiTarget })
    Citizen.SetTimeout(15000, function()
        if pendingPolls[reqId] then
            pendingPolls[reqId] = nil
            cb(false)
        end
    end)
end)

--  Filet de sécurité : ne jamais laisser le focus NUI bloqué

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and hiOpen then closeHI() end
end)
