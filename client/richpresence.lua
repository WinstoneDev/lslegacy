local CountPlayers = nil

LSLegacy.Events.Register('receiveNumberPlayers', function(number)
    CountPlayers = number
end)

Citizen.CreateThread(function()
    Wait(30000)
    LSLegacy.Events.SendToServer('updateNumberPlayer')
	while true do
        local time = 20000
        if CountPlayers ~= nil then
            LSLegacy.Events.SendToServer('updateNumberPlayer')
            SetDiscordAppId(Config.DiscordStatus["ID"])
            SetDiscordRichPresenceAsset(Config.DiscordStatus["LargeIcon"])
            SetDiscordRichPresenceAssetText(Config.DiscordStatus["LargeIconText"])
            SetDiscordRichPresenceAssetSmall(Config.DiscordStatus["SmallIcon"])
            SetDiscordRichPresenceAssetSmallText(Config.DiscordStatus["SmallIconText"])
            SetDiscordRichPresenceAction(0, "Discord", Config.Informations["Discord"])
            SetDiscordRichPresenceAction(1, "Se connecter", "fivem://connect/161.97.103.156:30120")
            SetRichPresence("LSLegacy RP\n"..GetPlayerName(PlayerId()) .. " - ".. CountPlayers .. "/64")
        end
        Wait(time)
	end
end)