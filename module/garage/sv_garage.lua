LSLegacy.RegisterCommand('garageCreator', 2, function(xPlayer, args, showError)
    local source = xPlayer.source
    LSLegacy.SendEventToClient('garageCreator:openMenu', source)
end, false, {
    help = "Ouvrir le menu de création de garages",
    validate = true,
    arguments = {
        { name = "player", validate = true, help = "Id du joueur", type = "player" },
    },
})

LSLegacy.Callbacks.RegisterServer('garageCreator:getPlayerName', function(source, cb, id)
    local xPlayer = LSLegacy.Players.Get(id)
    if xPlayer then
        cb(xPlayer.characterInfos.Prenom.." "..xPlayer.characterInfos.Nom)
    else
        cb(nil)
    end
end)