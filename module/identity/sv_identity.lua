MadeInFrance.RegisterZone('Récupération de pièce d\'identité', vector3(-1093.411, -809.2663, 19.2816), function(source)
    local player = MadeInFrance.GetPlayerFromId(source)
    local identity = MadeInFrance.Inventory.GetInventoryItem(player, 'idcard')
    if identity == nil then
        MadeInFrance.Inventory.AddItemInInventory(player, 'idcard', 1, player.characterInfos.Prenom.." "..player.characterInfos.NDF, nil, player.characterInfos)
        MadeInFrance.SendEventToClient('madeinfrance:notify', source,  '1 '..player.characterInfos.Prenom.." "..player.characterInfos.NDF..' ont été ~g~ajouté(s)~s~ à votre inventaire.')
    else
        MadeInFrance.SendEventToClient('madeinfrance:notify', source, 'Vous avez ~r~déjà~s~ une pièce d\'identité.')
    end
end, 10.0, false, {
    markerType = 25,
    markerColor = {r = 0, g = 125, b = 255, a = 255},
    markerSize = {x = 1.0, y = 1.0, z = 1.0},
    markerPos = vector3(-1093.411, -809.2663, 19.2816)
}, false, {
    blipSprite = 1,
    blipColor = 1,
    blipScale = 0.7,
    blipName = "Récupération de pièce d\'identité"
}, true, {
    drawNotificationDistance = 1.7,
    notificationMessage = "Appuyez sur ~INPUT_CONTEXT~ pour récupérer votre pièce d'identité",
}, true, {
    coords = vector4(-1092.842, -809.9628, 18.27598, 28.8649),
    pedName = "Sadam",
    pedModel = "s_m_y_sheriff_01",
    drawDistName = 5.0,
    scenario = {
        anim = "WORLD_HUMAN_CLIPBOARD"
    }
})

MadeInFrance.RegisterUsableItem("idcard", function(data)
    MadeInFrance.SendEventToClient('madeinfrance:useIdCard', source, data)
end)