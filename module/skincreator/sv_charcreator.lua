LSLegacy.RegisterServerEvent("SetBucket", function(number)
    local _src = source
    SetPlayerRoutingBucket(_src, number)
end)

LSLegacy.RegisterServerEvent('saveskin', function(skin)
    local _src = source
    local player = LSLegacy.GetPlayerFromId(_src)
    MySQL.Async.execute('UPDATE players SET skin = @skin WHERE id = @id', {
        ['@skin'] = json.encode(skin),
        ['@id'] = player.id
    })
end)

LSLegacy.RegisterServerEvent("SetIdentity", function(NDF, Prenom, DDN, Sexe, Taille, LDN)
    local _src = source
    local infos = {
        NDF = NDF,
        Prenom = Prenom,
        DDN = DDN,
        Sexe = Sexe,
        Taille = Taille,
        LDN = LDN
    }
    local player = LSLegacy.GetPlayerFromId(_src)
    MySQL.Async.execute("UPDATE players SET characterInfos = @characterInfos WHERE id = @id", {
        ["@id"] = player.id,
        ["@characterInfos"] = json.encode(infos)
    })

    player.characterInfos = infos
end)