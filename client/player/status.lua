MadeInFrance.Status = {}
MadeInFrance.Status.Displayed = true

MadeInFrance.Status.DrawStatusBar = function(x, y, width, height, value, color)
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
        if MadeInFrance.Status.Displayed then
            time = 0
            local safezone = GetSafeZoneSize()

            local baseX = 0.038
            local baseY = 1.0 - ((1.0 - safezone) * 0.5) - 0.205

            local barWidth, barHeight = 0.043, 0.010
            local spacing = 0.045

            MadeInFrance.Status.DrawStatusBar(baseX, baseY, barWidth, barHeight, MadeInFrance.PlayerData.status.hunger, {0, 100, 0})
            MadeInFrance.Status.DrawStatusBar(baseX + spacing, baseY, barWidth, barHeight, MadeInFrance.PlayerData.status.thirst, {0, 110, 255})
            MadeInFrance.Status.DrawStatusBar(baseX + spacing * 2, baseY, barWidth, barHeight, MadeInFrance.PlayerData.status.stamina, {180, 0, 255})
        end
        Wait(time)
    end
end)