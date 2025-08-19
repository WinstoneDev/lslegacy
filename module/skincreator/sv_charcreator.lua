MadeInFrance.RegisterServerEvent("SetBucket", function(number)
    local _src = source
    SetPlayerRoutingBucket(_src, number)
end)

MadeInFrance.RegisterServerEvent('saveskin', function(skin)
    local _src = source
    local player = MadeInFrance.GetPlayerFromId(_src)
    MySQL.Async.execute('UPDATE players SET skin = @skin WHERE id = @id', {
        ['@skin'] = json.encode(skin),
        ['@id'] = player.id
    })
end)

MadeInFrance.RegisterServerEvent("SetIdentity", function(NDF, Prenom, DDN, Sexe, Taille, LDN)
    local _src = source
    local infos = {
        NDF = NDF,
        Prenom = Prenom,
        DDN = DDN,
        Sexe = Sexe,
        Taille = Taille,
        LDN = LDN
    }
    local player = MadeInFrance.GetPlayerFromId(_src)
    MySQL.Async.execute("UPDATE players SET characterInfos = @characterInfos WHERE id = @id", {
        ["@id"] = player.id,
        ["@characterInfos"] = json.encode(infos)
    })

    player.characterInfos = infos

    if MadeInFrance.Inventory.CanCarryItem(player, 'food_burger', 5) then
        MadeInFrance.Inventory.AddItemInInventory(player, "food_burger", 5, 'BurgerShot MaxiBeef')
    end
    if MadeInFrance.Inventory.CanCarryItem(player, 'food_sprunk', 5) then
        MadeInFrance.Inventory.AddItemInInventory(player, "food_sprunk", 5, 'Sprunk 33cl')
    end
end)