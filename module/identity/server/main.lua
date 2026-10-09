LSLegacy.RegisterZone('Pièce d\'identité', vector3(-1093.411, -809.2663, 19.2816), function(source)
    local player = LSLegacy.Players.Get(source)
    local identity = LSLegacy.Inventory.GetInventoryItem(player, 'idcard')
    if identity == nil then
        LSLegacy.Inventory.AddItemInInventory(player, 'idcard', 1, player.characterInfos.Prenom.." "..player.characterInfos.NDF, nil, player.characterInfos)
        LSLegacy.Events.SendToClient('notify', source,  nil, '1 '..player.characterInfos.Prenom.." "..player.characterInfos.NDF..' ont été ajouté(s) à votre inventaire.', 'success')
    else
        LSLegacy.Events.SendToClient('notify', source, nil, 'Vous avez déjà une pièce d\'identité.', 'error')
    end
end, 10.0, false, {
    markerType = 25,
    markerColor = {r = 0, g = 125, b = 255, a = 255},
    markerSize = {x = 1.0, y = 1.0, z = 1.0},
    markerPos = vector3(-1093.411, -809.2663, 19.2816)
}, true, {
    blipSprite = 1,
    blipColor = 1,
    blipScale = 0.7,
    blipName = "Pièce d\'identité"
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

LSLegacy.RegisterUsableItem("idcard", function(data)
    LSLegacy.Events.SendToClient('useIdCard', source, data)
end)