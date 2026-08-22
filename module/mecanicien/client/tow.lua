--  MODULE MÉCANICIEN — Remorquage (client)
--  Attache simple (AttachEntityToEntity), pas de chaîne visuelle.
--  Ciblage : ox_target (ALT sur le véhicule en panne)

local cooldowns = {}

local function Notify(msg, type)
    TriggerEvent('notify', 'Mécanicien', msg, type or 'info', 5000)
end

local function HasCooldown(action)
    if not cooldowns[action] then return false end
    return (GetGameTimer() - cooldowns[action]) < (Config.Mecanicien.Actions.cooldowns[action] or 3000)
end

local function SetCooldown(action)
    cooldowns[action] = GetGameTimer()
end

local TOW_MODELS = {}
for _, veh in ipairs(Config.Mecanicien.Vehicles.tow or {}) do
    TOW_MODELS[GetHashKey(veh.model)] = true
end

local function GetTowTruckUnderPlayer()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end -- doit être conducteur
    if not TOW_MODELS[GetEntityModel(veh)] then return nil end
    return veh
end

-- Suivi local des attaches (évite de dépendre d'une native non vérifiée)
local attachedVehicles = {}

local function Attach(targetVeh, towTruck)
    if HasCooldown('tow') then Notify(Lang.Mecanicien.action_cooldown, 'error') return end

    local dist = #(GetEntityCoords(targetVeh) - GetEntityCoords(towTruck))
    if dist > 8.0 then Notify(Lang.Mecanicien.tow_too_far, 'error') return end

    SetCooldown('tow')
    Notify(Lang.Mecanicien.tow_attach_start, 'info')

    FreezeEntityPosition(targetVeh, false)
    AttachEntityToEntity(targetVeh, towTruck, 0,
        0.0, -5.5, 1.2,
        0.0, 0.0, 0.0,
        true, true, false, false, 2, true)

    attachedVehicles[targetVeh] = towTruck
    Notify(Lang.Mecanicien.tow_attached, 'success')
end

local function Detach(targetVeh)
    DetachEntity(targetVeh, true, true)
    attachedVehicles[targetVeh] = nil
    Notify(Lang.Mecanicien.tow_detached, 'info')
end

-- Nettoyage si le véhicule attaché est détruit/déchargé
Citizen.CreateThread(function()
    while true do
        Wait(5000)
        for veh in pairs(attachedVehicles) do
            if not DoesEntityExist(veh) then attachedVehicles[veh] = nil end
        end
    end
end)

--  CIBLAGE OX_TARGET — Accrocher / Détacher

exports.ox_target:addGlobalVehicle({
    {
        name = 'mecanicien_tow_attach',
        icon = 'fa-solid fa-link',
        label = 'Accrocher à la dépanneuse',
        distance = 5.0,
        canInteract = function(entity)
            return Mecanicien.IsOnDuty() and not attachedVehicles[entity] and GetTowTruckUnderPlayer() ~= nil
        end,
        onSelect = function(data)
            local towTruck = GetTowTruckUnderPlayer()
            if not towTruck then Notify(Lang.Mecanicien.tow_not_in_truck, 'error') return end
            Attach(data.entity, towTruck)
        end,
    },
    {
        name = 'mecanicien_tow_detach',
        icon = 'fa-solid fa-link-slash',
        label = 'Détacher de la dépanneuse',
        distance = 5.0,
        canInteract = function(entity)
            return Mecanicien.IsOnDuty() and attachedVehicles[entity] ~= nil
        end,
        onSelect = function(data)
            Detach(data.entity)
        end,
    },
})
