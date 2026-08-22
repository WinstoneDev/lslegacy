--  MDT — Client (ouverture/fermeture NUI + pont NUI ↔ serveur)
--
--  • Le serveur pilote l'ouverture (event 'mdt:open' avec le payload :
--    permissions, onglets, services…). Aucune donnée sensible n'est
--    décidée côté client.
--  • Lectures NUI  → pont requête/réponse via events tokenisés
--    (mdt:query → mdt:queryResult), plutôt que LSLegacy.Callbacks.
--  • Écritures NUI → LSLegacy.Events.SendToServer (events tokenisés).

local mdtOpen = false

--  Ouverture / fermeture

local function disableMDTControls()
    Citizen.CreateThread(function()
        while mdtOpen do
            DisableControlAction(0, 1, true)   -- look LR
            DisableControlAction(0, 2, true)   -- look UD
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)  -- aim
            DisableControlAction(0, 47, true)  -- weapon
            DisableControlAction(0, 58, true)  -- weapon
            DisableControlAction(0, 263, true) -- melee
            DisableControlAction(0, 264, true)
            DisableControlAction(0, 257, true)
            Wait(0)
        end
    end)
end

local function openMDT(payload)
    if mdtOpen then return end
    mdtOpen = true
    SetNuiFocus(true, true)
    disableMDTControls()
    SendNUIMessage({ action = 'mdt:open', data = payload })
end

local function closeMDT()
    if not mdtOpen then return end
    mdtOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'mdt:hide' })
end

-- Serveur → client : ouverture pilotée par la tablette
LSLegacy.Events.Register('mdt:open', function(payload)
    if type(payload) ~= 'table' then return end
    openMDT(payload)
end)

-- Serveur → client : résultat d'une écriture (notif + refresh éventuel)
LSLegacy.Events.Register('mdt:result', function(payload)
    if type(payload) ~= 'table' then return end
    if payload.message then
        TriggerEvent('brutal_notify:SendAlert', 'MDT', payload.message, 4000, payload.ok and 'success' or 'error')
    end
    if mdtOpen and payload.refresh then
        SendNUIMessage({ action = 'mdt:refresh', refresh = payload.refresh, ok = payload.ok })
    end
end)

--  NUI callbacks — fermeture

RegisterNUICallback('mdt:close', function(_, cb)
    closeMDT()
    cb('ok')
end)

--  NUI callbacks — LECTURES (pont requête/réponse)
--  NUI fetch → mdtQuery → SendEventToServer('mdt:query') → serveur →
--  SendEventToClient('mdt:queryResult') → on résout le fetch via cb().

local pendingQueries = {}
local queryCounter = 0

LSLegacy.Events.Register('mdt:queryResult', function(payload)
    if type(payload) ~= 'table' then return end
    local cb = pendingQueries[payload.reqId]
    if cb then
        pendingQueries[payload.reqId] = nil
        cb(payload.result)
    end
end)

local function mdtQuery(action, data, cb)
    queryCounter = queryCounter + 1
    local reqId = queryCounter
    pendingQueries[reqId] = cb
    LSLegacy.Events.SendToServer('mdt:query', { reqId = reqId, action = action, data = data })
    -- filet de sécurité : si pas de réponse en 15 s, on débloque le fetch
    Citizen.SetTimeout(15000, function()
        if pendingQueries[reqId] then
            pendingQueries[reqId] = nil
            cb(false)
        end
    end)
end

local function readCallback(nuiName, action)
    RegisterNUICallback(nuiName, function(data, cb)
        mdtQuery(action, type(data) == 'table' and data or {}, function(res)
            cb(res == nil and false or res)
        end)
    end)
end

readCallback('mdt:searchCitizens',       'searchCitizens')
readCallback('mdt:getCitizen',           'getCitizen')
readCallback('mdt:searchVehicles',       'searchVehicles')
readCallback('mdt:getVehicle',           'getVehicle')
readCallback('mdt:getReports',           'getReports')
readCallback('mdt:getReport',            'getReport')
readCallback('mdt:getWarrants',          'getWarrants')
readCallback('mdt:getCustodyHistory',    'getCustodyHistory')
readCallback('mdt:getEvidence',          'getEvidence')
readCallback('mdt:searchWeapons',        'searchWeapons')
readCallback('mdt:getWeapon',            'getWeapon')
readCallback('mdt:getPersonWeapons',     'getPersonWeapons')
readCallback('mdt:getReportWeapons',     'getReportWeapons')
readCallback('mdt:getRoster',            'getRoster')
readCallback('mdt:getLaws',              'getLaws')
readCallback('mdt:getTrainings',         'getTrainings')
readCallback('mdt:getTrainingSignups',   'getTrainingSignups')
readCallback('mdt:getAgentFile',         'getAgentFile')
readCallback('mdt:getDashboard',         'getDashboard')
readCallback('mdt:getInterventionReports','getInterventionReports')
readCallback('mdt:getInterventionReport', 'getInterventionReport')
readCallback('mdt:getCaseLinks',          'getCaseLinks')
readCallback('mdt:getReportLinks',         'getReportLinks')

--  NUI callback — PRISE / FIN DE SERVICE depuis le tableau de bord
--
--  Purement local : on appelle la bascule que le module métier a publiée
--  dans LSLegacy.MDT.DutyToggles (police, gendarmerie…). C'est elle qui
--  porte la vérification du job, les notifications et l'event serveur —
--  la borne de la caserne et le MDT empruntent donc le même chemin.

RegisterNUICallback('mdt:toggleDuty', function(_, cb)
    local job = LSLegacy.PlayerData and LSLegacy.PlayerData.job
    local entry = job and (LSLegacy.MDT.DutyToggles or {})[job]
    if not entry or type(entry.toggle) ~= 'function' then
        return cb({ ok = false })
    end
    entry.toggle()
    cb({ ok = true, onDuty = type(entry.isOnDuty) == 'function' and entry.isOnDuty() or nil })
end)

--  NUI callbacks — ÉCRITURES (event tokenisé ; le serveur répond via
--  'mdt:result' qui déclenche notif + refresh)

local function writeCallback(name)
    RegisterNUICallback(name, function(data, cb)
        LSLegacy.Events.SendToServer(name, data)
        cb('ok')
    end)
end

writeCallback('mdt:createFine')
writeCallback('mdt:toggleFinePaid')
writeCallback('mdt:deleteFine')
writeCallback('mdt:addCriminalRecord')
writeCallback('mdt:deleteCriminalRecord')
writeCallback('mdt:createReport')
writeCallback('mdt:updateReport')
writeCallback('mdt:deleteReport')
writeCallback('mdt:createInterventionReport')
writeCallback('mdt:updateInterventionReport')
writeCallback('mdt:deleteInterventionReport')
writeCallback('mdt:linkCaseItem')
writeCallback('mdt:unlinkCaseItem')
writeCallback('mdt:linkReportItem')
writeCallback('mdt:unlinkReportItem')
writeCallback('mdt:createWarrant')
writeCallback('mdt:setVehicleWanted')
writeCallback('mdt:setVehicleLocation')
writeCallback('mdt:updateWarrant')
writeCallback('mdt:deleteWarrant')
writeCallback('mdt:createCustody')
writeCallback('mdt:addEvidence')
writeCallback('mdt:registerWeapon')
writeCallback('mdt:updateWeapon')
writeCallback('mdt:deleteWeapon')
writeCallback('mdt:seizeWeapon')
writeCallback('mdt:linkWeaponPerson')
writeCallback('mdt:unlinkWeaponPerson')
writeCallback('mdt:linkWeaponReport')
writeCallback('mdt:unlinkWeaponReport')
writeCallback('mdt:createLaw')
writeCallback('mdt:updateLaw')
writeCallback('mdt:deleteLaw')
writeCallback('mdt:createTraining')
writeCallback('mdt:updateTraining')
writeCallback('mdt:deleteTraining')
writeCallback('mdt:signupTraining')
writeCallback('mdt:unsignupTraining')
writeCallback('mdt:removeSignup')
writeCallback('mdt:validateSignup')
writeCallback('mdt:deleteCustody')
writeCallback('mdt:linkPersonWeapon')
writeCallback('mdt:updateEvidence')
writeCallback('mdt:linkReportEvidence')
writeCallback('mdt:unlinkReportEvidence')
writeCallback('mdt:saveAgentMeta')
writeCallback('mdt:saveCareer')
writeCallback('mdt:addAssignment')
writeCallback('mdt:updateAssignment')
writeCallback('mdt:deleteAssignment')
writeCallback('mdt:addCommendation')
writeCallback('mdt:deleteCommendation')
writeCallback('mdt:addSkill')
writeCallback('mdt:deleteSkill')
writeCallback('mdt:updateSkillDate')

-- Fermeture forcée si la ressource s'arrête (évite de rester focus NUI)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and mdtOpen then
        SetNuiFocus(false, false)
    end
end)
