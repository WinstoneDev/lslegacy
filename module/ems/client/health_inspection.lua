--  HEALTH INSPECTION — Pont NUI client (EMS)
--
--  Outil de terrain (pas un onglet MDT) : ouvert en ciblant un patient
--  via ox_target (ems_bag, cf. client/actions.lua). NUI autonome,
--  4ᵉ iframe du shell (module/creatorperso/html/ui.html), préfixe `hi:`.
--
--  Même principe que le pont MDT médical (mdt_medical.lua), mais
--  indépendant : lectures → requête/réponse tokenisée (hi:poll →
--  ems:hiPoll → ems:hiPollResult), écritures → events tokenisés
--  (ems:hiUseItem → ems:hiUseItemResult).

local function Notify(msg, type)
    TriggerEvent('notify', 'Emergency Medical Services', msg, type or 'info', 5000)
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

local function OpenHI(payload)
    if hiOpen then return end
    hiOpen   = true
    hiTarget = payload.target
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'hi:open', data = payload })
end

local function CloseHI()
    if not hiOpen then return end
    hiOpen   = false
    hiTarget = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hi:hide' })
end

-- Appelée depuis client/actions.lua (cible ox_target ems_bag), après
-- vérification du cooldown 'bag'.
function EMS.OpenHealthInspection(targetSrc)
    LSLegacy.Events.SendToServer('ems:hiOpen', { target = targetSrc })
end

LSLegacy.Events.Register('ems:hiOpenResult', function(payload)
    if type(payload) ~= 'table' or not payload.success then return end
    OpenHI(payload)
end)

RegisterNUICallback('hi:close', function(_, cb)
    CloseHI()
    cb('ok')
end)

-- Branchement du moniteur cardiaque : geste RP requis avant que le rythme
-- cardiaque ne s'affiche dans la NUI (cohérence — le patient doit d'abord
-- être équipé des électrodes).
RegisterNUICallback('hi:attachMonitor', function(_, cb)
    PlayAnim('amb@medic@standing@kneel@base', 'base', Config.EMS.Actions.monitorAttachDuration, 49)
    cb('ok')
end)

--  Écriture : utiliser un item de la trousse sur un membre

RegisterNUICallback('hi:useItem', function(data, cb)
    if type(data) == 'table' and hiTarget then
        LSLegacy.Events.SendToServer('ems:hiUseItem', {
            target = hiTarget,
            part   = data.part,
            item   = data.item,
        })
    end
    cb('ok') -- la réponse arrive de façon asynchrone via ems:hiUseItemResult
end)

LSLegacy.Events.Register('ems:hiUseItemResult', function(payload)
    if type(payload) ~= 'table' then return end
    SendNUIMessage({ action = 'hi:useItemResult', data = payload })

    if payload.success then
        Notify(string.format(Lang.EMS.bag_item_used, payload.label), 'success')
    elseif payload.reason == 'wrong_treatment' then
        Notify(Lang.EMS.bag_wrong_treatment, 'error')
    elseif payload.reason == 'full_health' then
        Notify(Lang.EMS.bag_already_full_health, 'warning')
    elseif payload.reason == 'missing_item' then
        Notify(string.format(Lang.EMS.bag_item_missing, payload.item or '?'), 'error')
    end
end)

--  Lecture : rafraîchissement léger (mannequin + moniteur cardiaque)

local pendingPolls, pollCounter = {}, 0

LSLegacy.Events.Register('ems:hiPollResult', function(payload)
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
    LSLegacy.Events.SendToServer('ems:hiPoll', { reqId = reqId, target = hiTarget })
    Citizen.SetTimeout(15000, function()
        if pendingPolls[reqId] then
            pendingPolls[reqId] = nil
            cb(false)
        end
    end)
end)

--  Filet de sécurité : ne jamais laisser le focus NUI bloqué

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and hiOpen then CloseHI() end
end)
