--  MODULE MÉCANICIEN — Actions de réparation / tuning (serveur)
--  Validation stricte : job/grade depuis ServerPlayers, jamais client

local function GetPlayer(src)   return LSLegacy.Players.Get(src) end
local function IsMecanicien(src) return LSLegacy.Jobs.Is(GetPlayer(src), Config.Mecanicien.Job) end

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Mécanicien', msg, t or 'info', 5000)
end

-- token -> { onSuccess, onFail } — la suite (réparation/pose) n'est
-- appliquée qu'une fois le paiement (espèces ou TPE) confirmé côté serveur.
local PendingBills = {}

LSLegacy.Bank.RegisterPaymentResultHandler('mecanicien', function(token, success)
    local pending = PendingBills[token]
    if not pending then return end
    PendingBills[token] = nil
    if success then
        if pending.onSuccess then pending.onSuccess() end
    else
        if pending.onFail then pending.onFail() end
    end
end)

local function BillCustomer(customerSrc, amount, message, onSuccess, onFail)
    local customer = GetPlayer(customerSrc)
    if not customer then
        if onFail then onFail() end
        return
    end
    local token = ('meca_%d_%d'):format(customerSrc, math.random(100000, 999999))
    PendingBills[token] = { onSuccess = onSuccess, onFail = onFail }
    Citizen.SetTimeout(120000, function() PendingBills[token] = nil end)
    LSLegacy.Bank.OpenPaymentMenu(customerSrc, message, amount, { meta = { type = 'mecanicien', refId = token } })
end

--  RÉPARATION MOTEUR

LSLegacy.Events.Register('mecanicien:repairEngine', function(data)
    local src = source
    if not IsMecanicien(src) or not IsMecanicienOnDuty(src) then return end
    if not data or not data.vehNet or not data.customer then return end

    local veh = NetworkGetEntityFromNetworkId(data.vehNet)
    if not DoesEntityExist(veh) then return end

    local price = Config.Mecanicien.LaborPrices.engine
    BillCustomer(data.customer, price, 'Réparation moteur', function()
        if not DoesEntityExist(veh) then
            TriggerClientEvent('mecanicien:repairResult', src, { success = false })
            return
        end
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleUndriveable(veh, false)
        TriggerClientEvent('mecanicien:repairResult', src, { success = true })
        Notify(data.customer, string.format('Réparation moteur facturée : %d$', price), 'info')
    end, function()
        TriggerClientEvent('mecanicien:repairResult', src, { success = false })
        Notify(data.customer, 'Paiement refusé, réparation annulée.', 'error')
    end)
end)

--  CHANGEMENT DE PNEU (consomme piece_pneu pris gratuitement au stock
--  du garage — jamais facturé au mécanicien, seul le client paie)

LSLegacy.Events.Register('mecanicien:changeTyre', function(data)
    local src = source
    if not IsMecanicien(src) or not IsMecanicienOnDuty(src) then return end
    if not data or not data.vehNet or data.wheel == nil or not data.customer then return end

    local mecano = GetPlayer(src)
    local owned  = LSLegacy.Inventory.GetInventoryItem(mecano, 'piece_pneu')
    if not owned or owned.count <= 0 then
        TriggerClientEvent('mecanicien:tyreResult', src, { success = false })
        return
    end

    local veh = NetworkGetEntityFromNetworkId(data.vehNet)
    if not DoesEntityExist(veh) then return end

    local pneuPrice = Config.Mecanicien.Parts.piece_pneu and Config.Mecanicien.Parts.piece_pneu.price or 0
    local price      = pneuPrice + Config.Mecanicien.LaborPrices.tyre
    BillCustomer(data.customer, price, 'Changement de pneu', function()
        local owned2 = LSLegacy.Inventory.GetInventoryItem(mecano, 'piece_pneu')
        if not owned2 or owned2.count <= 0 or not DoesEntityExist(veh) then
            TriggerClientEvent('mecanicien:tyreResult', src, { success = false })
            return
        end
        LSLegacy.Inventory.RemoveItemInInventory(mecano, 'piece_pneu', 1)
        SetVehicleTyreFixed(veh, data.wheel)
        TriggerClientEvent('mecanicien:tyreResult', src, { success = true })
        Notify(data.customer, string.format('Changement de pneu facturé : %d$', price), 'info')
    end, function()
        TriggerClientEvent('mecanicien:tyreResult', src, { success = false })
        Notify(data.customer, 'Fonds insuffisants pour le changement de pneu.', 'error')
    end)
end)

--  TUNING — facturé au client présent dans le véhicule

LSLegacy.Events.Register('mecanicien:requestTuning', function(data)
    local src = source
    if not IsMecanicien(src) or not IsMecanicienOnDuty(src) then return end
    if not data or not data.customer or not data.price or not data.kind then return end

    BillCustomer(data.customer, data.price, 'Tuning - ' .. tostring(data.kind), function()
        TriggerClientEvent('mecanicien:tuningResult', src, { success = true, kind = data.kind })
        Notify(data.customer, string.format('Tuning facturé : %s — %d$', data.kind, data.price), 'info')
    end, function()
        TriggerClientEvent('mecanicien:tuningResult', src, { success = false, price = data.price })
    end)
end)
