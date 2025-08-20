local CountPlayers = nil

LSLegacy.RegisterClientEvent('receiveNumberPlayers', function(number)
    CountPlayers = number
end)

Citizen.CreateThread(function()
    Wait(30000)
    LSLegacy.SendEventToServer('updateNumberPlayer')
	while true do
        local time = 20000
        if CountPlayers ~= nil then
            LSLegacy.SendEventToServer('updateNumberPlayer')
            SetDiscordAppId(Config.DiscordStatus["ID"])
            SetDiscordRichPresenceAsset(Config.DiscordStatus["LargeIcon"])
            SetDiscordRichPresenceAssetText(Config.DiscordStatus["LargeIconText"])
            SetDiscordRichPresenceAssetSmall(Config.DiscordStatus["SmallIcon"])
            SetDiscordRichPresenceAssetSmallText(Config.DiscordStatus["SmallIconText"])
            SetDiscordRichPresenceAction(0, "Discord", Config.Informations["Discord"])
            SetDiscordRichPresenceAction(1, "Se connecter", "fivem://connect/")
            SetRichPresence("LSLegacy RP\n"..GetPlayerName(PlayerId()) .. " - ".. CountPlayers .. "/64")
        end
        Wait(time)
	end
end)