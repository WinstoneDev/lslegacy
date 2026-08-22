LSLegacy.Status = {}
LSLegacy.Status.Displayed = true

LSLegacy.Events.Register("LSLegacy:status:applyHPDrain", function(hpLoss)
    local ped    = PlayerPedId()
    local health = GetEntityHealth(ped)
    SetEntityHealth(ped, math.max(100, health - hpLoss))
end)

LSLegacy.Status.DrawStatusBar = function(x, y, width, height, value, color)
    value = tonumber(value) or 0
    if value < 0 then value = 0 elseif value > 100 then value = 100 end
    DrawRect(x, y, width, height, 40, 40, 40, 180)
    local filledWidth = width * (value / 100)
    if filledWidth > 0 then
        DrawRect(x - (width - filledWidth) / 2, y, filledWidth, height, color[1], color[2], color[3], 220)
    end
end

CreateThread(function()
    Wait(5000)
    while true do
        if not Config.Status.DisplayEnabled then return end
        local waitTime = 1000
        if LSLegacy.Status.Displayed then
            waitTime = 0
            local safezone = GetSafeZoneSize()
            local szOff    = (1.0 - safezone) * 0.5

            -- Ancré sur la minimap (bord gauche + largeur totale suivent la safe zone)
            local mmLeft    = 0.008 + szOff * 0.7
            local mmWidth   = 0.130
            local barHeight = 0.010
            local barY      = 1.0 - szOff - 0.205
            local gap       = 0.002

            local stats = Config.UseStamina and {
                { LSLegacy.PlayerData.status.hunger,  { 0, 130,   0 } },
                { LSLegacy.PlayerData.status.thirst,  { 0, 110, 255 } },
                { LSLegacy.PlayerData.status.stamina, { 180, 0, 255 } },
            } or {
                { LSLegacy.PlayerData.status.hunger,  { 0, 130,   0 } },
                { LSLegacy.PlayerData.status.thirst,  { 0, 110, 255 } },
            }

            local n        = #stats
            local barWidth = (mmWidth - gap * (n - 1)) / n

            for i, stat in ipairs(stats) do
                local cx = mmLeft + barWidth / 2 + (i - 1) * (barWidth + gap)
                LSLegacy.Status.DrawStatusBar(cx, barY, barWidth, barHeight, stat[1], stat[2])
            end
        end
        Wait(waitTime)
    end
end)
