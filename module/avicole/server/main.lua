-- Transporteur Avicole : docks -> usine (décharger/charger) -> grossiste (décharger) -> docks.
-- Le métier (choix/service) est géré par le module farm (FarmMetier) ; ce module ne gère que le camion et la livraison.

local rateLimits = {
    ['avicole:startDuty'] = 10, ['avicole:rigSpawned'] = 15, ['avicole:requestUsineState'] = 10,
    ['avicole:talkUsinePed'] = 15, ['avicole:talkGrossistePed'] = 15,
    ['avicole:requestUnloadRaw'] = 15, ['avicole:requestLoadPrepared'] = 15, ['avicole:requestUnloadGrossiste'] = 15,
    ['avicole:completeAction'] = 15,
    ['avicole:endDelivery'] = 10, ['avicole:continue'] = 10, ['avicole:stopService'] = 10,
    ['avicole:prep:startDuty'] = 10, ['avicole:prep:stopDuty'] = 10,
    ['avicole:prep:requestAction'] = 20, ['avicole:prep:completeAction'] = 20,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local CFG = Config.Avicole

Avicole = Avicole or {}
Avicole.Sessions = Avicole.Sessions or {}
Avicole.PrepSessions = Avicole.PrepSessions or {}

local function GetPlayer(src) return LSLegacy.Players.Get(src) end

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Transporteur Avicole', msg, t or 'info', 5000)
end

local function NewSession()
    return {
        unlockedUnloadRaw = false, deliveredRaw = false,
        unlockedLoad = false, loadedPrepared = false,
        unlockedGrossisteUnload = false, deliveredGrossiste = false,
    }
end

local function ResetDelivery(session)
    session.unlockedUnloadRaw = false; session.deliveredRaw = false
    session.unlockedLoad = false; session.loadedPrepared = false
    session.unlockedGrossisteUnload = false; session.deliveredGrossiste = false
end

local function CurrentUsinePed()
    local hour = LSLegacy.Weather.GetTime()
    hour = hour or 12
    if hour >= CFG.Usine.dayStart and hour < CFG.Usine.dayEnd then return CFG.Usine.day end
    return CFG.Usine.night
end

local function SendUsineState(src)
    local p = CurrentUsinePed()
    TriggerClientEvent('avicole:usineState', src, { model = p.model, name = p.name })
end

local function NoSessionRefusal(src, player)
    Notify(src, FarmMetier.Refusal(player, 'transporteur_avicole') or 'Vous devez prendre votre service auprès de Earl Hickey.', 'error')
end

LSLegacy.Events.Register('avicole:startDuty', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    if Avicole.Sessions[src] then
        return Notify(src, 'Vous êtes déjà en service.', 'error')
    end
    if not FarmMetier.CanStart(player, 'transporteur_avicole') then
        return Notify(src, FarmMetier.Refusal(player, 'transporteur_avicole') or 'Vous êtes déjà en service.', 'error')
    end

    Avicole.Sessions[src] = NewSession()
    TriggerClientEvent('avicole:spawnTruck', src, {
        model   = CFG.Truck.model,
        coords  = { x = CFG.Truck.coords.x, y = CFG.Truck.coords.y, z = CFG.Truck.coords.z },
        heading = CFG.Truck.coords.w,
    })
end)

LSLegacy.Events.Register('avicole:rigSpawned', function(data)
    local src = source
    local player = GetPlayer(src)
    local session = Avicole.Sessions[src]
    if not player or not session or not data then return end
    session.truckNetId = data.truckNetId
    FarmMetier.StartService(src)
    SendUsineState(src)
    Notify(src, 'Camion récupéré. Direction l\'usine du Nord.', 'success')
end)

LSLegacy.Events.Register('avicole:requestUsineState', function()
    local src = source
    SendUsineState(src)
end)

LSLegacy.Events.Register('avicole:talkUsinePed', function()
    local src = source
    local player = GetPlayer(src)
    local session = Avicole.Sessions[src]
    if not player then return end
    if not session then return NoSessionRefusal(src, player) end

    if not session.deliveredRaw then
        if session.unlockedUnloadRaw then
            return Notify(src, 'Déchargez le camion.', 'info')
        end
        session.unlockedUnloadRaw = true
        return Notify(src, 'Vous pouvez décharger le camion.', 'success')
    elseif not session.loadedPrepared then
        if session.unlockedLoad then
            return Notify(src, 'Chargez le camion avec les poulets préparés.', 'info')
        end
        session.unlockedLoad = true
        return Notify(src, 'Vous pouvez charger le camion avec les poulets préparés.', 'success')
    else
        return Notify(src, 'Direction le grossiste.', 'info')
    end
end)

LSLegacy.Events.Register('avicole:talkGrossistePed', function()
    local src = source
    local player = GetPlayer(src)
    local session = Avicole.Sessions[src]
    if not player then return end
    if not session then return NoSessionRefusal(src, player) end

    if not session.loadedPrepared then
        return Notify(src, 'Vous n\'avez rien à livrer pour le moment.', 'error')
    end
    if session.deliveredGrossiste then
        return Notify(src, 'Livraison déjà déchargée. Retournez voir Earl Hickey.', 'info')
    end
    if session.unlockedGrossisteUnload then
        return Notify(src, 'Déchargez le camion.', 'info')
    end
    session.unlockedGrossisteUnload = true
    Notify(src, 'Vous pouvez décharger le camion.', 'success')
end)

LSLegacy.Events.Register('avicole:requestUnloadRaw', function()
    local src = source
    local session = Avicole.Sessions[src]
    if not session then return Notify(src, 'Vous n\'êtes pas en service.', 'error') end
    if not session.unlockedUnloadRaw or session.deliveredRaw then
        return Notify(src, 'Rien à décharger pour le moment.', 'error')
    end
    TriggerClientEvent('avicole:playAction', src, { duration = CFG.ActionDuration, label = 'Déchargement de la cargaison', complete = 'unload_raw' })
end)

LSLegacy.Events.Register('avicole:requestLoadPrepared', function()
    local src = source
    local session = Avicole.Sessions[src]
    if not session then return Notify(src, 'Vous n\'êtes pas en service.', 'error') end
    if not session.unlockedLoad or session.loadedPrepared then
        return Notify(src, 'Rien à charger pour le moment.', 'error')
    end
    TriggerClientEvent('avicole:playAction', src, { duration = CFG.ActionDuration, label = 'Chargement des poulets préparés', complete = 'load_prepared' })
end)

LSLegacy.Events.Register('avicole:requestUnloadGrossiste', function()
    local src = source
    local session = Avicole.Sessions[src]
    if not session then return Notify(src, 'Vous n\'êtes pas en service.', 'error') end
    if not session.unlockedGrossisteUnload or session.deliveredGrossiste then
        return Notify(src, 'Rien à décharger pour le moment.', 'error')
    end
    TriggerClientEvent('avicole:playAction', src, { duration = CFG.ActionDuration, label = 'Déchargement chez le grossiste', complete = 'unload_grossiste' })
end)

LSLegacy.Events.Register('avicole:completeAction', function(data)
    local src = source
    local session = Avicole.Sessions[src]
    if not session or not data then return end

    if data.complete == 'unload_raw' and session.unlockedUnloadRaw and not session.deliveredRaw then
        session.deliveredRaw = true
        session.unlockedUnloadRaw = false
        Notify(src, 'Cargaison déchargée. Retournez voir le responsable de l\'usine pour charger les poulets préparés.', 'success')
    elseif data.complete == 'load_prepared' and session.unlockedLoad and not session.loadedPrepared then
        session.loadedPrepared = true
        session.unlockedLoad = false
        Notify(src, 'Camion chargé. Direction le grossiste.', 'success')
    elseif data.complete == 'unload_grossiste' and session.unlockedGrossisteUnload and not session.deliveredGrossiste then
        session.deliveredGrossiste = true
        session.unlockedGrossisteUnload = false
        Notify(src, 'Livraison déchargée. Retournez voir Earl Hickey aux docks.', 'success')
    end
end)

LSLegacy.Events.Register('avicole:endDelivery', function()
    local src = source
    local player = GetPlayer(src)
    local session = Avicole.Sessions[src]
    if not player then return end
    if not session then return NoSessionRefusal(src, player) end
    if not session.deliveredGrossiste then
        return Notify(src, 'Vous n\'avez pas encore terminé la livraison.', 'error')
    end
    LSLegacy.Bank.PaySalary(player, CFG.Payment, 'Salaire - Livraison avicole')
    Notify(src, ('Livraison payée : +%d$.'):format(CFG.Payment), 'success')
    ResetDelivery(session)
    TriggerClientEvent('avicole:askContinue', src)
end)

LSLegacy.Events.Register('avicole:continue', function()
    local src = source
    if not Avicole.Sessions[src] then return end
    Notify(src, 'Direction l\'usine du Nord pour une nouvelle livraison.', 'info')
end)

LSLegacy.Events.Register('avicole:stopService', function()
    local src = source
    if not Avicole.Sessions[src] then return end
    Avicole.Sessions[src] = nil
    TriggerClientEvent('avicole:despawnRig', src)
end)

-- ── Préparateur Avicole : boucle point1 (plumer) -> point2 (découper) ────
local PREP = CFG.Prep

local function WeightedPick(options)
    local total = 0
    for _, o in ipairs(options) do total = total + o.weight end
    local roll = math.random(1, total)
    local acc = 0
    for _, o in ipairs(options) do
        acc = acc + o.weight
        if roll <= acc then return o.amount end
    end
    return options[1].amount
end

local function AvicoleChainActive()
    for _ in pairs(Avicole.Sessions) do return true end
    return false
end

local function PrepPayment()
    if math.random() < PREP.Payment.badCutChance then
        return PREP.Payment.badCutAmount, true, false
    end
    local boosted = AvicoleChainActive()
    local table_ = boosted and PREP.Payment.boosted or PREP.Payment.normal
    return WeightedPick(table_), false, boosted
end

LSLegacy.Events.Register('avicole:prep:startDuty', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    if Avicole.PrepSessions[src] then
        return Notify(src, 'Vous êtes déjà en service.', 'error')
    end
    if not FarmMetier.CanStart(player, 'preparateur_avicole') then
        return Notify(src, FarmMetier.Refusal(player, 'preparateur_avicole') or 'Vous êtes déjà en service.', 'error')
    end
    Avicole.PrepSessions[src] = { step = 1 }
    FarmMetier.StartService(src)
    Notify(src, 'Direction le point de plumage.', 'success')
end)

LSLegacy.Events.Register('avicole:prep:stopDuty', function()
    local src = source
    Avicole.PrepSessions[src] = nil
end)

LSLegacy.Events.Register('avicole:prep:requestAction', function(point)
    local src = source
    local session = Avicole.PrepSessions[src]
    if not session then return Notify(src, "Vous n'êtes pas en service.", 'error') end
    if session.step ~= point then
        return Notify(src, session.step == 1
            and "Allez d'abord plumer le poulet au 1er point."
            or "Allez d'abord découper le poulet au 2e point.", 'error')
    end
    local label = point == 1 and 'Plumage du poulet' or 'Découpe du poulet'
    TriggerClientEvent('avicole:prep:playAction', src, { duration = PREP.ActionDuration, label = label, point = point })
end)

LSLegacy.Events.Register('avicole:prep:completeAction', function(point)
    local src = source
    local player = GetPlayer(src)
    local session = Avicole.PrepSessions[src]
    if not player or not session or session.step ~= point then return end

    if point == 1 then
        session.step = 2
        Notify(src, 'Direction le point de découpe.', 'success')
    else
        session.step = 1
        local amount, badCut, boosted = PrepPayment()
        LSLegacy.Bank.PaySalary(player, amount, 'Salaire - Préparation avicole')
        if badCut then
            Notify(src, ('Mauvaise découpe... +%d$.'):format(amount), 'error')
        elseif boosted then
            Notify(src, ('La chaîne tourne à plein régime ! Boucle terminée : +%d$.'):format(amount), 'success')
        else
            Notify(src, ('Boucle terminée : +%d$.'):format(amount), 'success')
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Avicole.Sessions[src] = nil
    Avicole.PrepSessions[src] = nil
end)
