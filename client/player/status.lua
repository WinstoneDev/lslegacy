LSLegacy.Status = {}
LSLegacy.Status.Displayed = true

LSLegacy.Status.DrawStatusBar = function(x, y, width, height, value, color)
    value = tonumber(value) or 0
    if value < 0 then value = 0 elseif value > 100 then value = 100 end
    DrawRect(x, y, width, height, 40, 40, 40, 180)
    local filledWidth = (width * (value / 100))
    DrawRect(x - (width - filledWidth) / 2, y, filledWidth, height, color[1], color[2], color[3], 220)
end

CreateThread(function()
    Wait(5000)
    while true do
        time = 1000
        if LSLegacy.Status.Displayed then
            time = 0
            local safezone = GetSafeZoneSize()

            local baseX = 0.038
            local baseY = 1.0 - ((1.0 - safezone) * 0.5) - 0.205

            local barWidth, barHeight = 0.043, 0.010
            local spacing = 0.045

            LSLegacy.Status.DrawStatusBar(baseX, baseY, barWidth, barHeight, LSLegacy.PlayerData.status.hunger, {0, 100, 0})
            LSLegacy.Status.DrawStatusBar(baseX + spacing, baseY, barWidth, barHeight, LSLegacy.PlayerData.status.thirst, {0, 110, 255})
            LSLegacy.Status.DrawStatusBar(baseX + spacing * 2, baseY, barWidth, barHeight, LSLegacy.PlayerData.status.stamina, {180, 0, 255})
        end
        Wait(time)
    end
end)