-- Écran de diagnostic en lecture seule, aucune réparation déclenchée ici.

local cooldowns = {}

local function Notify(msg, type)
    TriggerEvent(Config.Atelier.NotifyEvent, 'Atelier', msg, 5000, type or 'info')
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

LSLegacy.RegisterClientEvent('atelier:diagnosticResult', function(data)
    if not data then return end
    ShowReport(data)
end)

local function Diagnose(veh)
    if HasCooldown('diagnose') then Notify(Lang.Atelier.action_cooldown, 'error') return end
    SetCooldown('diagnose')
    LSLegacy.SendEventToServer('atelier:requestDiagnostic', { vehNet = NetworkGetNetworkIdFromEntity(veh) })
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'atelier_diagnose', icon = 'fa-solid fa-magnifying-glass', label = 'Diagnostiquer',
        distance = 3.0, canInteract = CanInteract,
        onSelect = function(data) Diagnose(data.entity) end,
    },
})
