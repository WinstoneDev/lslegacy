--  MODULE MÉCANICIEN — Actions (client)
--  Diagnostic / Réparation moteur / Pneus / Tuning
--  Ciblage : ox_target (ALT sur un véhicule) — Menus : ox_lib (context)

local cooldowns = {}

local function Notify(msg, type)
    TriggerEvent(Config.Mecanicien.NotifyEvent, 'Mécanicien', msg, 5000, type or 'info')
end

local function HasCooldown(action)
    if not cooldowns[action] then return false end
    return (GetGameTimer() - cooldowns[action]) < (Config.Mecanicien.Actions.cooldowns[action] or 3000)
end

local function SetCooldown(action)
    cooldowns[action] = GetGameTimer()
end

local function PlayAnim(dict, anim, duration, flag)
    flag = flag or 49
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do Wait(100); t = t + 1 end
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, duration, flag, 0, false, false, false)
    Wait(duration)
    ClearPedTasks(PlayerPedId())
end

-- Le client facturé est le joueur le plus proche du véhicule (hors mécanicien lui-même)
local function GetClosestPlayerServerId(coords, range)
    range = range or Config.Mecanicien.Actions.interactionRange
    local closest, closestDist = nil, range

    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local dist = #(coords - GetEntityCoords(GetPlayerPed(pid)))
            if dist < closestDist then
                closestDist = dist
                closest      = pid
            end
        end
    end
    if not closest then return nil end
    return GetPlayerServerId(closest)
end

local function GetNearestCustomerServerId(veh)
    return GetClosestPlayerServerId(GetEntityCoords(veh))
end

--  DIAGNOSTIC

local function Diagnose(veh)
    if HasCooldown('diagnose') then Notify(Lang.Mecanicien.action_cooldown, 'error') return end
    SetCooldown('diagnose')

    local engineHealth = GetVehicleEngineHealth(veh)
    local bodyHealth    = GetVehicleBodyHealth(veh)
    local burstCount    = 0
    for i = 0, 5 do
        if IsVehicleTyreBurst(veh, i, false) then burstCount = burstCount + 1 end
    end

    local th = Config.Mecanicien.Thresholds
    Notify(Lang.Mecanicien.diagnose_title, 'info')
    Notify(engineHealth < th.EngineDamaged and Lang.Mecanicien.diagnose_engine_bad or Lang.Mecanicien.diagnose_engine_ok,
        engineHealth < th.EngineDamaged and 'error' or 'success')
    Notify(bodyHealth < th.BodyDamaged and Lang.Mecanicien.diagnose_body_bad or Lang.Mecanicien.diagnose_body_ok,
        bodyHealth < th.BodyDamaged and 'error' or 'success')
    if burstCount > 0 then
        Notify(string.format(Lang.Mecanicien.diagnose_tyres_bad, burstCount), 'error')
    else
        Notify(Lang.Mecanicien.diagnose_tyres_ok, 'success')
    end
end

--  RÉPARATION MOTEUR (minijeu, sans pièce, main d'œuvre facturée)

local function RepairEngine(veh)
    if HasCooldown('repair') then Notify(Lang.Mecanicien.action_cooldown, 'error') return end

    local customerSrc = GetNearestCustomerServerId(veh)
    if not customerSrc then Notify(Lang.Mecanicien.no_client_vehicle, 'error') return end

    if GetVehicleEngineHealth(veh) >= Config.Mecanicien.Thresholds.EngineDamaged then
        Notify(Lang.Mecanicien.repair_engine_not_needed, 'warning')
        return
    end

    SetCooldown('repair')
    Notify(Lang.Mecanicien.repair_engine_start, 'info')
    PlayAnim('mini@repair', 'fixing_a_ped', 3000, 49)

    Mecanicien.RunMinigame(function(hits, rounds, success)
        if not success then
            Notify(Lang.Mecanicien.repair_engine_failed, 'error')
            return
        end
        LSLegacy.SendEventToServer('mecanicien:repairEngine', {
            vehNet = NetworkGetNetworkIdFromEntity(veh),
            customer = customerSrc,
        })
    end)
end

--  CHANGEMENT DE PNEU (consomme piece_pneu, minijeu)

local function ChangeTyre(veh)
    if HasCooldown('repair') then Notify(Lang.Mecanicien.action_cooldown, 'error') return end

    local customerSrc = GetNearestCustomerServerId(veh)
    if not customerSrc then Notify(Lang.Mecanicien.no_client_vehicle, 'error') return end

    local burstWheel = nil
    for i = 0, 5 do
        if IsVehicleTyreBurst(veh, i, false) then burstWheel = i break end
    end
    if not burstWheel then Notify(Lang.Mecanicien.change_tyre_none_burst, 'warning') return end

    SetCooldown('repair')
    Notify(Lang.Mecanicien.repair_engine_start, 'info')
    PlayAnim('mini@repair', 'fixing_a_ped', 3000, 49)

    Mecanicien.RunMinigame(function(hits, rounds, success)
        if not success then
            Notify(Lang.Mecanicien.change_tyre_failed, 'error')
            return
        end
        LSLegacy.SendEventToServer('mecanicien:changeTyre', {
            vehNet   = NetworkGetNetworkIdFromEntity(veh),
            wheel    = burstWheel,
            customer = customerSrc,
        })
    end)
end

LSLegacy.RegisterClientEvent('mecanicien:repairResult', function(data)
    if not data then return end
    if data.success then
        Notify(Lang.Mecanicien.repair_engine_done, 'success')
    else
        Notify(Lang.Mecanicien.change_tyre_no_item, 'error')
    end
end)

LSLegacy.RegisterClientEvent('mecanicien:tyreResult', function(data)
    if not data then return end
    if data.success then
        Notify(Lang.Mecanicien.change_tyre_done, 'success')
    else
        Notify(Lang.Mecanicien.change_tyre_no_item, 'error')
    end
end)

--  TUNING (LS Customs simplifié — facturé au client présent)

local function ApplyColor(veh, colorId)
    SetVehicleColours(veh, colorId, colorId)
end

local function ApplyWheelType(veh, wheelType)
    SetVehicleWheelType(veh, wheelType)
    SetVehicleMod(veh, 23, 0, false) -- jantes par défaut du type sélectionné
end

local function ApplyPerformance(veh)
    for _, modType in ipairs({ 11, 12, 13, 15, 16 }) do -- moteur, frein, transmission, suspension, turbo
        local max = GetNumVehicleMods(veh, modType) - 1
        if max >= 0 then SetVehicleMod(veh, modType, max, false) end
    end
    ToggleVehicleMod(veh, 18, true) -- turbo visuel
end

local function OpenTuningMenu(veh)
    local customerSrc = GetNearestCustomerServerId(veh)
    if not customerSrc then Notify(Lang.Mecanicien.no_client_vehicle, 'error') return end

    local vehNet = NetworkGetNetworkIdFromEntity(veh)
    local prices = Config.Mecanicien.LaborPrices.tuning

    local options = {
        {
            title = Lang.Mecanicien.tuning_colors,
            description = prices.color .. '$',
            icon = 'fa-solid fa-palette',
            onSelect = function()
                local colorOptions = {}
                for _, c in ipairs(Config.Mecanicien.Tuning.colors) do
                    colorOptions[#colorOptions + 1] = {
                        title = c.label,
                        onSelect = function()
                            LSLegacy.SendEventToServer('mecanicien:requestTuning', {
                                vehNet = vehNet, customer = customerSrc, kind = 'color', price = prices.color,
                            })
                            ApplyColor(veh, c.id)
                        end,
                    }
                end
                lib.registerContext({ id = 'mecanicien_tuning_color', title = Lang.Mecanicien.tuning_colors, menu = 'mecanicien_tuning', options = colorOptions })
                lib.showContext('mecanicien_tuning_color')
            end,
        },
        {
            title = Lang.Mecanicien.tuning_wheels,
            description = prices.wheels .. '$',
            icon = 'fa-solid fa-circle-dot',
            onSelect = function()
                local wheelOptions = {}
                for _, w in ipairs(Config.Mecanicien.Tuning.wheelTypes) do
                    wheelOptions[#wheelOptions + 1] = {
                        title = w.label,
                        onSelect = function()
                            LSLegacy.SendEventToServer('mecanicien:requestTuning', {
                                vehNet = vehNet, customer = customerSrc, kind = 'wheels', price = prices.wheels,
                            })
                            ApplyWheelType(veh, w.id)
                        end,
                    }
                end
                lib.registerContext({ id = 'mecanicien_tuning_wheels', title = Lang.Mecanicien.tuning_wheels, menu = 'mecanicien_tuning', options = wheelOptions })
                lib.showContext('mecanicien_tuning_wheels')
            end,
        },
        {
            title = Lang.Mecanicien.tuning_performance,
            description = prices.performance .. '$',
            icon = 'fa-solid fa-gauge-high',
            onSelect = function()
                LSLegacy.SendEventToServer('mecanicien:requestTuning', {
                    vehNet = vehNet, customer = customerSrc, kind = 'performance', price = prices.performance,
                })
                ApplyPerformance(veh)
            end,
        },
    }

    lib.registerContext({ id = 'mecanicien_tuning', title = Lang.Mecanicien.tuning_title, options = options })
    lib.showContext('mecanicien_tuning')
end

LSLegacy.RegisterClientEvent('mecanicien:tuningResult', function(data)
    if not data then return end
    if data.success then
        Notify(string.format(Lang.Mecanicien.tuning_applied, data.kind), 'success')
    else
        Notify(string.format(Lang.Mecanicien.tuning_no_money, data.price or 0), 'error')
    end
end)

--  CIBLAGE OX_TARGET — Touche ALT sur un véhicule

local function CanInteract()
    return Mecanicien.IsOnDuty()
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'mecanicien_diagnose', icon = 'fa-solid fa-magnifying-glass', label = 'Diagnostiquer',
        distance = 3.0, canInteract = CanInteract,
        onSelect = function(data) Diagnose(data.entity) end,
    },
    {
        name = 'mecanicien_repair_engine', icon = 'fa-solid fa-screwdriver-wrench', label = 'Réparer le moteur',
        distance = 3.0, canInteract = CanInteract,
        onSelect = function(data) RepairEngine(data.entity) end,
    },
    {
        name = 'mecanicien_change_tyre', icon = 'fa-solid fa-circle-dot', label = 'Changer un pneu',
        distance = 3.0, canInteract = CanInteract,
        onSelect = function(data) ChangeTyre(data.entity) end,
    },
    {
        name = 'mecanicien_tuning', icon = 'fa-solid fa-palette', label = Lang.Mecanicien.tuning_title,
        distance = 3.0, canInteract = CanInteract,
        onSelect = function(data) OpenTuningMenu(data.entity) end,
    },
})
