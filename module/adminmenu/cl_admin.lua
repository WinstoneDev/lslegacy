local AdminMenu = {
    AllPlayers = nil
}

MadeInFrance.RegisterClientEvent('AdminServerPlayers', function(table)
    AdminMenu.AllPlayers = table
end)

AdminMenu.mainMenu = RageUI.CreateMenu("Administration", "Administration")
AdminMenu.subMenu = RageUI.CreateSubMenu(AdminMenu.mainMenu, "Administration", "Administration")
AdminMenu.subMenu2 = RageUI.CreateSubMenu(AdminMenu.mainMenu, "Administration", "Administration")
AdminMenu.subMenu3 = RageUI.CreateSubMenu(AdminMenu.mainMenu, "Administration", "Administration")

AdminMenu.mainMenu.Closed = function()
    AdminMenu.opened = false
    AdminMenu.AllPlayers = nil
    RageUI.Visible(AdminMenu.mainMenu, false)
end

AdminMenu.subMenu:AcceptFilter(true)

function AdminMenu:OpenMenu()
    if RageUI.GetInMenu() then
        return
    end
    if AdminMenu.opened then
        AdminMenu.opened = false
        RageUI.Visible(AdminMenu.mainMenu, false)
    else
        AdminMenu.opened = true
        RageUI.Visible(AdminMenu.mainMenu, true)
        MadeInFrance.SendEventToServer('AdminServerPlayers')
        Wait(250)
        while AdminMenu.AllPlayers == nil do Wait(5) end
        CreateThread(function()
            while AdminMenu.opened do
                RageUI.IsVisible(AdminMenu.mainMenu, function()
                    RageUI.Button('Liste des joueurs', nil, {}, true, {}, AdminMenu.subMenu)
                end)
                RageUI.IsVisible(AdminMenu.subMenu, function()
                    for k, v in pairs(AdminMenu.AllPlayers) do
                        RageUI.Button("("..v.source..") - "..v.characterInfos.Prenom.." "..v.characterInfos.NDF, nil, {}, true, {
                            onSelected = function()
                                IdSelected = v.source
                                IdPersonnage = v.id
                                NameSelected = v.characterInfos.Prenom.." "..v.characterInfos.NDF
                                LieuNaissance = v.LDN
                                DateDeNaissance = v.DDN
                                RageUI.ResetFiltre()
                            end
                        }, AdminMenu.subMenu2)
                    end
                end)
                RageUI.IsVisible(AdminMenu.subMenu2, function()
                    if IdSelected and NameSelected then
                        RageUI.Button("~r~(" .. IdSelected .. ") - " .. NameSelected, nil, {}, true, {})
                    end
                    RageUI.Button("Envoyer un message privé", nil, {}, true, {
                        onSelected = function()
                            local msg = MadeInFrance.KeyboardInput('Message', 120)
                            if msg ~= nil then
                                MadeInFrance.SendEventToServer('MessageAdmin', IdSelected, msg)
                            end
                        end
                    })
                    RageUI.Button("Se téléporter sur le joueur", nil, {}, true, {
                        onSelected = function()
                            MadeInFrance.SendEventToServer('TeleportPlayers', 'tp', IdSelected)
                        end
                    })
                    RageUI.Button("Téléporter le joueur sur vous", nil, {}, true, {
                        onSelected = function()
                            MadeInFrance.SendEventToServer('TeleportPlayers', 'bring', IdSelected)
                        end
                    })
                    RageUI.Button("Réanimer", nil, {RightBadge = RageUI.BadgeStyle.Heart}, true, {})
                    RageUI.Button("Heal le joueur", nil, {RightBadge = RageUI.BadgeStyle.Heart}, true, {})
                end)
                Wait(0)
            end
        end)
    end
end

Keys.Register("F2", "F2", "Ouvrir le menu Admin", function()
    AdminMenu:OpenMenu()
end)