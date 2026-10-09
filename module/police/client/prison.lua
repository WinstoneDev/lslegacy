LSLegacy.Events.Register('police:teleportToCustody', function(data)
    if not data then return end

    Citizen.CreateThread(function()
        local endTime  = GetGameTimer() + data.duration * 60 * 1000
        local label    = '🔒 Garde à vue — 00:00 — ' .. (data.reason or '?')
        local nextTick = 0

        while GetGameTimer() < endTime do
            local now = GetGameTimer()

            if now >= nextTick then
                local remaining = math.max(0, endTime - now)
                local mins      = math.floor(remaining / 60000)
                local secs      = math.floor((remaining % 60000) / 1000)
                label    = string.format('🔒 Garde à vue — %02d:%02d — %s', mins, secs, data.reason or '?')
                nextTick = now + 1000
            end

            SetTextFont(0)
            SetTextScale(0.35, 0.35)
            SetTextColour(220, 50, 50, 255)
            SetTextCentre(true)
            SetTextOutline()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(label)
            EndTextCommandDisplayText(0.5, 0.08)
            Wait(0)
        end
    end)
end)

LSLegacy.Events.Register('police:releasedFromCustody', function()
    TriggerEvent('notify', 'Police Nationale', Lang.Police.custody_released, 'success', Config.Police.NotifyDuration or 30000)
end)

-- Prison client
LSLegacy.Events.Register('police:sendToPrison', function(data)
    if not data then return end
    if LSLegacy.Anticheat then LSLegacy.Anticheat.AllowTeleport() end
    SetEntityCoords(PlayerPedId(), data.x, data.y, data.z, false, false, false, false)
    SetEntityHeading(PlayerPedId(), data.h or 270.0)

    Citizen.CreateThread(function()
        local endTime  = GetGameTimer() + data.duration * 60 * 1000
        local pzone    = vector3(data.x, data.y, data.z)
        local label    = '⛓ Bolingbroke — 00:00 restant(s)'
        local nextTick = 0

        while GetGameTimer() < endTime do
            local now = GetGameTimer()

            if now >= nextTick then
                local remaining = math.max(0, endTime - now)
                local mins      = math.floor(remaining / 60000)
                local secs      = math.floor((remaining % 60000) / 1000)
                label    = string.format('⛓ Bolingbroke — %02d:%02d restant(s)', mins, secs)
                nextTick = now + 1000

                local pos = GetEntityCoords(PlayerPedId())
                if not LSLegacy.Validate.Distance(pos, pzone, 200.0) then
                    if LSLegacy.Anticheat then LSLegacy.Anticheat.AllowTeleport() end
                    SetEntityCoords(PlayerPedId(), data.x, data.y, data.z, false, false, false, false)
                end
            end

            SetTextFont(0)
            SetTextScale(0.35, 0.35)
            SetTextColour(200, 50, 50, 255)
            SetTextCentre(true)
            SetTextOutline()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(label)
            EndTextCommandDisplayText(0.5, 0.08)
            Wait(0)
        end
    end)
end)

LSLegacy.Events.Register('police:releasedFromPrison', function()
    if LSLegacy.Anticheat then LSLegacy.Anticheat.AllowTeleport() end
    SetEntityCoords(PlayerPedId(), 1849.4, 2634.8, 45.7, false, false, false, false)
    TriggerEvent('notify', 'Prison', Lang.Police.prison_released, 'success', 8000)
end)