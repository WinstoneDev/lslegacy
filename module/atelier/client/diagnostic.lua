-- Écran de diagnostic en lecture seule, aucune réparation déclenchée ici.

local cooldowns = {}

local function Notify(msg, type)
    TriggerEvent('notify', 'Atelier', msg, type or 'info', 5000)
end

local function HasCooldown(action)
    if not cooldowns[action] then return false end
    return (GetGameTimer() - cooldowns[action]) < (Config.Atelier.Actions.cooldowns[action] or 3000)
end

local function SetCooldown(action)
    cooldowns[action] = GetGameTimer()
end

local function CanInteract()
    return Atelier.IsOnDuty() and LSLegacy.Atelier.HasPermission(Atelier.GetCompanyId(), Atelier.GetGrade(), 'diagnostic')
end

local CATEGORY_LABELS = {
    mechanical = 'Mécanique',
    tyres      = 'Pneus',
    body       = 'Carrosserie',
}

local function StateIcon(pct)
    if pct >= 70 then return 'fa-solid fa-circle-check', 'success' end
    if pct >= 40 then return 'fa-solid fa-triangle-exclamation', 'warning' end
    return 'fa-solid fa-circle-xmark', 'error'
end

local function ShowReport(data)
    local options = {}
    for _, category in ipairs({ 'mechanical', 'tyres', 'body' }) do
        local components  = LSLegacy.Atelier.Components[category]
        local values       = data.components[category] or {}
        options[#options + 1] = { title = '— ' .. CATEGORY_LABELS[category] .. ' —', disabled = true }
        for id, def in pairs(components) do
            local pct = values[id] or 0
            local icon = StateIcon(pct)
            options[#options + 1] = {
                title = def.label,
                description = pct .. ' %',
                icon = icon,
                disabled = true,
            }
        end
    end

    lib.registerContext({ id = 'atelier_diagnostic_report', title = Lang.Atelier.diagnose_title, options = options })
    lib.showContext('atelier_diagnostic_report')
end

LSLegacy.Events.Register('atelier:diagnosticResult', function(data)
    if not data then return end
    ShowReport(data)
end)

-- GetTyreHealth et IsVehicleDoorDamaged n'existent que côté client (crash "attempt
-- to call a nil value" côté serveur) : ces relevés sont donc pris ici et envoyés au
-- serveur, qui ne s'en sert qu'en dégradation (ReconcileVehicleState ne fait jamais
-- remonter un %). GetTyreHealth mesure l'usure, pas l'éclatement : un pneu crevé
-- (IsVehicleTyreBurst) peut rester à 1000/1000 de santé, d'où le forçage à 0 ici.
local function Diagnose(veh)
    if HasCooldown('diagnose') then Notify(Lang.Atelier.action_cooldown, 'error') return end
    SetCooldown('diagnose')
    Notify('Analyse en cours...', 'info')
    local tyres = {}
    for _, def in pairs(LSLegacy.Atelier.Components.tyres) do
        if IsVehicleTyreBurst(veh, def.wheelIndex, false) then
            tyres[def.wheelIndex] = 0.0
        else
            tyres[def.wheelIndex] = GetTyreHealth(veh, def.wheelIndex)
        end
    end
    local doorsBroken = {}
    for _, def in pairs(LSLegacy.Atelier.Components.body) do
        if def.doorIndex then
            doorsBroken[def.doorIndex] = IsVehicleDoorDamaged(veh, def.doorIndex)
        end
    end

    -- Déformation par zone (mêmes points que la restauration AP) : dégrade les
    -- pièces de carrosserie non observables nativement selon l'endroit et la
    -- force de l'impact — cf. server/vehicles.lua -> ReconcileVehicleState.
    local deformation = {}
    for _, zone in ipairs(LSLegacy.Atelier.DeformationZones) do
        local deform = GetVehicleDeformationAtPos(veh, vector3(zone.offset.x, zone.offset.y, zone.offset.z))
        local intensity = #(deform) * 5
        if intensity > 0.01 then
            deformation[zone.id] = intensity
        end
    end

    LSLegacy.Events.SendToServer('atelier:requestDiagnostic', {
        vehNet = NetworkGetNetworkIdFromEntity(veh), tyres = tyres, doorsBroken = doorsBroken, deformation = deformation,
    })
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'atelier_diagnose', icon = 'fa-solid fa-magnifying-glass', label = 'Diagnostiquer',
        distance = 3.0, canInteract = CanInteract,
        onSelect = function(data) Diagnose(data.entity) end,
    },
})
