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

local function DisableMDTControls()
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

local function OpenMDT(payload)
    if mdtOpen then return end
    mdtOpen = true
    SetNuiFocus(true, true)
    DisableMDTControls()
    SendNUIMessage({ action = 'mdt:open', data = payload })
end

local function CloseMDT()
    if not mdtOpen then return end
    mdtOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'mdt:hide' })
end

-- Serveur → client : ouverture pilotée par la tablette
LSLegacy.Events.Register('mdt:open', function(payload)
    if type(payload) ~= 'table' then return end
    OpenMDT(payload)
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
    CloseMDT()
    cb('ok')
end)

--  NUI callbacks — LECTURES (pont requête/réponse)
--  NUI fetch → MdtQuery → SendEventToServer('mdt:query') → serveur →
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

local function MdtQuery(action, data, cb)
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

local function ReadCallback(nuiName, action)
    RegisterNUICallback(nuiName, function(data, cb)
        MdtQuery(action, type(data) == 'table' and data or {}, function(res)
            cb(res == nil and false or res)
        end)
    end)
end

ReadCallback('mdt:searchCitizens',       'searchCitizens')
ReadCallback('mdt:getCitizen',           'getCitizen')
ReadCallback('mdt:searchVehicles',       'searchVehicles')
ReadCallback('mdt:getVehicle',           'getVehicle')
ReadCallback('mdt:getReports',           'getReports')
ReadCallback('mdt:getReport',            'getReport')
ReadCallback('mdt:getWarrants',          'getWarrants')
ReadCallback('mdt:getCustodyHistory',    'getCustodyHistory')
ReadCallback('mdt:getEvidence',          'getEvidence')
ReadCallback('mdt:searchWeapons',        'searchWeapons')
ReadCallback('mdt:getWeapon',            'getWeapon')
ReadCallback('mdt:getPersonWeapons',     'getPersonWeapons')
ReadCallback('mdt:getReportWeapons',     'getReportWeapons')
ReadCallback('mdt:getRoster',            'getRoster')
ReadCallback('mdt:getLaws',              'getLaws')
ReadCallback('mdt:getTrainings',         'getTrainings')
ReadCallback('mdt:getTrainingSignups',   'getTrainingSignups')
ReadCallback('mdt:getAgentFile',         'getAgentFile')
ReadCallback('mdt:getDashboard',         'getDashboard')
ReadCallback('mdt:getInterventionReports','getInterventionReports')
ReadCallback('mdt:getInterventionReport', 'getInterventionReport')
ReadCallback('mdt:getCaseLinks',          'getCaseLinks')
ReadCallback('mdt:getReportLinks',         'getReportLinks')

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

local function WriteCallback(name)
    RegisterNUICallback(name, function(data, cb)
        LSLegacy.Events.SendToServer(name, data)
        cb('ok')
    end)
end

WriteCallback('mdt:createFine')
WriteCallback('mdt:toggleFinePaid')
WriteCallback('mdt:deleteFine')
WriteCallback('mdt:addCriminalRecord')
WriteCallback('mdt:deleteCriminalRecord')
WriteCallback('mdt:createReport')
WriteCallback('mdt:updateReport')
WriteCallback('mdt:deleteReport')
WriteCallback('mdt:createInterventionReport')
WriteCallback('mdt:updateInterventionReport')
WriteCallback('mdt:deleteInterventionReport')
WriteCallback('mdt:linkCaseItem')
WriteCallback('mdt:unlinkCaseItem')
WriteCallback('mdt:linkReportItem')
WriteCallback('mdt:unlinkReportItem')
WriteCallback('mdt:createWarrant')
WriteCallback('mdt:setVehicleWanted')
WriteCallback('mdt:setVehicleLocation')
WriteCallback('mdt:updateWarrant')
WriteCallback('mdt:deleteWarrant')
WriteCallback('mdt:createCustody')
WriteCallback('mdt:addEvidence')
WriteCallback('mdt:registerWeapon')
WriteCallback('mdt:updateWeapon')
WriteCallback('mdt:deleteWeapon')
WriteCallback('mdt:seizeWeapon')
WriteCallback('mdt:linkWeaponPerson')
WriteCallback('mdt:unlinkWeaponPerson')
WriteCallback('mdt:linkWeaponReport')
WriteCallback('mdt:unlinkWeaponReport')
WriteCallback('mdt:createLaw')
WriteCallback('mdt:updateLaw')
WriteCallback('mdt:deleteLaw')
WriteCallback('mdt:createTraining')
WriteCallback('mdt:updateTraining')
WriteCallback('mdt:deleteTraining')
WriteCallback('mdt:signupTraining')
WriteCallback('mdt:unsignupTraining')
WriteCallback('mdt:removeSignup')
WriteCallback('mdt:validateSignup')
WriteCallback('mdt:deleteCustody')
WriteCallback('mdt:linkPersonWeapon')
WriteCallback('mdt:updateEvidence')
WriteCallback('mdt:linkReportEvidence')
WriteCallback('mdt:unlinkReportEvidence')
WriteCallback('mdt:saveAgentMeta')
WriteCallback('mdt:saveCareer')
WriteCallback('mdt:addAssignment')
WriteCallback('mdt:updateAssignment')
WriteCallback('mdt:deleteAssignment')
WriteCallback('mdt:addCommendation')
WriteCallback('mdt:deleteCommendation')
WriteCallback('mdt:addSkill')
WriteCallback('mdt:deleteSkill')
WriteCallback('mdt:updateSkillDate')

-- Fermeture forcée si la ressource s'arrête (évite de rester focus NUI)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and mdtOpen then
        SetNuiFocus(false, false)
    end
end)
