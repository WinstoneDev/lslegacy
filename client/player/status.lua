MadeInFrance.Status = {}

MadeInFrance.Status.DrawStatusBar = function(x, y, width, height, value, color)
    DrawRect(x, y, width, height, 40, 40, 40, 180)
    local filledWidth = (width * (value / 100))
    DrawRect(x - (width - filledWidth) / 2, y, filledWidth, height, color[1], color[2], color[3], 220)
end

CreateThread(function()
    Wait(500)
    while true do
        local baseX, baseY = 0.015, 0.80
        local barWidth, barHeight = 0.12, 0.015
        local spacing = 0.020
        MadeInFrance.Status.DrawStatusBar(baseX, baseY, barWidth, barHeight, MadeInFrance.PlayerData.status.hunger, {255, 165, 0})
        MadeInFrance.Status.DrawStatusBar(baseX, baseY - spacing, barWidth, barHeight, MadeInFrance.PlayerData.status.thirst, {0, 136, 255})
        MadeInFrance.Status.DrawStatusBar(baseX, baseY - spacing * 2, barWidth, barHeight, MadeInFrance.PlayerData.status.stamina, {180, 0, 255})
        Wait(0)
    end
end)