--  MDT MÉDICAL (SAMU) — Pont NUI client
--
--  Autonome : ne réutilise NI le pont du MDT police, NI ses events.
--  Même principe cependant (repris volontairement) :
--    • lectures  → requête/réponse tokenisée
--                  (mdtmed:query → mdtmed:queryResult)
--    • écritures → LSLegacy.Events.SendToServer (events tokenisés)
--
--  La NUI est celle du MDT (même page HTML) : les callbacks enregistrés
--  ici cohabitent avec ceux de module/mdt/client/main.lua sans conflit,
--  les noms étant préfixés `mdtmed:`.
--
--  Les positions des ambulanciers ne sont PAS remontées par le client :
--  le serveur les lit directement (GetEntityCoords sur le ped du
--  joueur), ce qui évite un flux périodique et toute falsification.

local pendingQueries = {}
local queryCounter   = 0

LSLegacy.Events.Register('mdtmed:queryResult', function(payload)
    if type(payload) ~= 'table' then return end
    local cb = pendingQueries[payload.reqId]
    if cb then
        pendingQueries[payload.reqId] = nil
        cb(payload.result)
    end
end)

local function MedQuery(action, data, cb)
    queryCounter = queryCounter + 1
    local reqId = queryCounter
    pendingQueries[reqId] = cb
    LSLegacy.Events.SendToServer('mdtmed:query', { reqId = reqId, action = action, data = data })
    -- Filet de sécurité : on débloque le fetch si le serveur ne répond pas.
    Citizen.SetTimeout(15000, function()
        if pendingQueries[reqId] then
            pendingQueries[reqId] = nil
            cb(false)
        end
    end)
end

-- Callback de LECTURE : la NUI reçoit la réponse du serveur.
local function ReadCallback(nuiName, action)
    RegisterNUICallback(nuiName, function(data, cb)
        MedQuery(action, type(data) == 'table' and data or {}, function(res)
            cb(res == nil and false or res)
        end)
    end)
end

ReadCallback('mdtmed:getMedConfig',   'getMedConfig')
ReadCallback('mdtmed:searchPatients', 'searchPatients')
ReadCallback('mdtmed:getPatient',     'getPatient')
ReadCallback('mdtmed:getTreatments',  'getTreatments')
ReadCallback('mdtmed:getDashboard',   'getDashboard')
ReadCallback('mdtmed:getDispatch',    'getDispatch')
ReadCallback('mdtmed:getCallHistory', 'getCallHistory')
ReadCallback('mdtmed:getDocs',        'getDocs')

-- Callback d'ÉCRITURE : le serveur répond via 'mdt:result' (notif +
-- refresh ciblé), géré par le client du MDT — rien à dupliquer ici.
local function WriteCallback(name)
    RegisterNUICallback(name, function(data, cb)
        LSLegacy.Events.SendToServer(name, data)
        cb('ok')
    end)
end

WriteCallback('mdtmed:saveRecord')
WriteCallback('mdtmed:addEntry')
WriteCallback('mdtmed:deleteEntry')
WriteCallback('mdtmed:addTreatment')
WriteCallback('mdtmed:setTreatmentStatus')
WriteCallback('mdtmed:assignCall')
WriteCallback('mdtmed:closeCall')
WriteCallback('mdtmed:saveDoc')
WriteCallback('mdtmed:deleteDoc')
WriteCallback('mdtmed:postBoard')
WriteCallback('mdtmed:removeBoard')

-- Prise / fin de service depuis le dashboard
-- Purement local : on réutilise SAMU.ToggleDuty() (client/main.lua), qui
-- porte la vérification du métier, les notifications et l'event
-- `samu:dutyChanged`. C'est ce même appel qui prévient le serveur.
RegisterNUICallback('mdtmed:toggleDuty', function(_, cb)
    if type(SAMU) == 'table' and type(SAMU.ToggleDuty) == 'function' then
        SAMU.ToggleDuty()
        cb({ ok = true, onDuty = SAMU.IsOnDuty() })
    else
        cb({ ok = false })
    end
end)

-- Pointer un appel sur le GPS depuis le dispatch
-- Action purement locale (pose un waypoint), donc traitée côté client
-- sans aller-retour serveur.
RegisterNUICallback('mdtmed:setWaypoint', function(data, cb)
    if type(data) == 'table' and tonumber(data.x) and tonumber(data.y) then
        SetNewWaypoint(tonumber(data.x) + 0.0, tonumber(data.y) + 0.0)
    end
    cb('ok')
end)
