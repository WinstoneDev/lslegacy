local Clothes = {
    TableChapeau = {},
    TableLunettes = {},
    TableOreilles = {},
    TablePantalon = {},
    TableShoes = {},
    TableSacs = {},
    LastSkin = {},
    Variations = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30},
}

function Clothes:loadLastSkin()
    TriggerEvent('skinchanger:loadSkin', Clothes.LastSkin) 
end

Clothes.mainMenu = RageUI.CreateMenu("", " ")
Clothes.subMenu = RageUI.CreateSubMenu(Clothes.mainMenu, "", " ")
Clothes.subMenu2 = RageUI.CreateSubMenu(Clothes.mainMenu, "", " ")
Clothes.subMenu3 = RageUI.CreateSubMenu(Clothes.mainMenu, "", " ")
Clothes.subMenu4 = RageUI.CreateSubMenu(Clothes.mainMenu, "", " ")
Clothes.subMenu5 = RageUI.CreateSubMenu(Clothes.mainMenu, "", " ")
Clothes.subMenu6 = RageUI.CreateSubMenu(Clothes.mainMenu, "", " ")
Clothes.subMenu7 = RageUI.CreateSubMenu(Clothes.mainMenu, "", " ")
Clothes.subMenu8 = RageUI.CreateSubMenu(Clothes.subMenu2, "", " ")
Clothes.subMenu9 = RageUI.CreateSubMenu(Clothes.subMenu2, "", " ")
Clothes.subMenu10 = RageUI.CreateSubMenu(Clothes.subMenu2, "", " ")
Clothes.subMenu11 = RageUI.CreateSubMenu(Clothes.subMenu2, "", " ")
Clothes.subMenu12 = RageUI.CreateSubMenu(Clothes.subMenu2, "", " ")
Clothes.subMenu13 = RageUI.CreateSubMenu(Clothes.subMenu2, "", " ")

Clothes.mainMenu:DisplayGlare(false)
Clothes.subMenu:DisplayGlare(false)
Clothes.subMenu2:DisplayGlare(false)
Clothes.subMenu3:DisplayGlare(false)
Clothes.subMenu4:DisplayGlare(false)
Clothes.subMenu5:DisplayGlare(false)
Clothes.subMenu6:DisplayGlare(false)
Clothes.subMenu7:DisplayGlare(false)
Clothes.subMenu:AcceptFilter(true)
Clothes.subMenu2:AcceptFilter(true)
Clothes.subMenu3:AcceptFilter(true)
Clothes.subMenu4:AcceptFilter(true)
Clothes.subMenu5:AcceptFilter(true)
Clothes.subMenu6:AcceptFilter(true)
Clothes.subMenu7:AcceptFilter(true)
Clothes.subMenu8:AcceptFilter(true)
Clothes.subMenu9:AcceptFilter(true)
Clothes.subMenu10:AcceptFilter(true)
Clothes.subMenu11:AcceptFilter(true)
Clothes.subMenu12:AcceptFilter(true)
Clothes.subMenu13:AcceptFilter(true)

Clothes.mainMenu.Closed = function()
    Clothes.opened = false
    RageUI.Visible(Clothes.mainMenu, false)
    Clothes:loadLastSkin()
end

function Clothes:OpenMenu(header)
    if RageUI.GetInMenu() then
        return
    end
    if Clothes.opened then
        Clothes.opened = false
        RageUI.Visible(Clothes.mainMenu, false)
    else
        Clothes.mainMenu:SetSpriteBanner(header, header)
        Clothes.subMenu:SetSpriteBanner(header, header)
        Clothes.subMenu2:SetSpriteBanner(header, header)
        Clothes.subMenu3:SetSpriteBanner(header, header)
        Clothes.subMenu4:SetSpriteBanner(header, header)
        Clothes.subMenu5:SetSpriteBanner(header, header)
        Clothes.subMenu6:SetSpriteBanner(header, header)
        Clothes.subMenu7:SetSpriteBanner(header, header)
        Clothes.subMenu8:SetSpriteBanner(header, header)
        Clothes.subMenu9:SetSpriteBanner(header, header)
        Clothes.subMenu10:SetSpriteBanner(header, header)
        Clothes.subMenu11:SetSpriteBanner(header, header)
        Clothes.subMenu12:SetSpriteBanner(header, header)
        Clothes.subMenu13:SetSpriteBanner(header, header)
        Clothes.opened = true
        RageUI.Visible(Clothes.mainMenu, true)
        MadeInFrance.TriggerLocalEvent('skinchanger:getSkin', function(skin)
            Clothes.LastSkin = skin
        end)
        MadeInFrance.TriggerLocalEvent('skinchanger:getData', function(components, max)
            maxVals = {}
            maxVals["tshirt_1"] = max.tshirt_1
            maxVals["torso_1"] = max.torso_1
            maxVals["pants_1"] = max.pants_1
            maxVals["shoes_1"] = max.shoes_1
            maxVals["helmet_1"] = max.helmet_1
            maxVals["glasses_1"] = max.glasses_1
            maxVals["ears_1"] = max.ears_1
            maxVals["bags_1"] = max.bags_1
            maxVals["gloves_1"] = max.arms
            maxVals["watches_1"] = max.watches_1
            maxVals["bracelets_1"] = max.bracelets_1
            maxVals["chain_1"] = max.chain_1
            maxVals["decals_1"] = max.decals_1

            for i = 0, max.tshirt_1, 1 do
                Clothes.TablePantalon[i] = 1
            end
            for i = 0, max.shoes_1, 1 do
                Clothes.TableShoes[i] = 1
            end
            for i = 0, max.bags_1, 1 do
                Clothes.TableSacs[i] = 1
            end
            for i = 0, max.helmet_1, 1 do
                Clothes.TableChapeau[i] = 1
            end
            for i = 0, max.glasses_1, 1 do
                Clothes.TableLunettes[i] = 1
            end
            for i = 0, max.ears_1, 1 do
                Clothes.TableOreilles[i] = 1
            end
        end)
        Wait(550)
        CreateThread(function()
            while Clothes.opened do
                RageUI.IsVisible(Clothes.mainMenu, function()
                    RageUI.Button('Hauts', nil, {}, true, {}, Clothes.subMenu)
                    RageUI.Button('Accessoires', nil, {}, true, {}, Clothes.subMenu2)
                    RageUI.Button('Pantalons', nil, {}, true, {}, Clothes.subMenu3)
                    RageUI.Button('Chaussures', nil, {}, true, {}, Clothes.subMenu4)
                    RageUI.Button('Sacs', nil, {}, true, {}, Clothes.subMenu5)
                    RageUI.Button('Badge', nil, {}, true, {}, Clothes.subMenu6)
                    RageUI.Button('Objets', nil, {}, true, {}, Clothes.subMenu7)
                end)
                RageUI.IsVisible(Clothes.subMenu, function()

                end)
                RageUI.IsVisible(Clothes.subMenu2, function()
                    RageUI.Button('Chapeaux', nil, {}, true, {}, Clothes.subMenu8)
                    RageUI.Button('Lunettes', nil, {}, true, {}, Clothes.subMenu9)
                    RageUI.Button('Boucles d\'oreilles', nil, {}, true, {}, Clothes.subMenu10)
                    RageUI.Button('Montres', nil, {}, true, {}, Clothes.subMenu11)
                    RageUI.Button('Bracelets', nil, {}, true, {}, Clothes.subMenu12)
                    RageUI.Button('Chaînes', nil, {}, true, {}, Clothes.subMenu13)
                end)
                RageUI.IsVisible(Clothes.subMenu3, function()
                    for i = 0, maxVals['pants_1'], 1 do          
                        RageUI.List("Pantalon #"..i, Clothes.Variations, Clothes.TablePantalon[i], nil, { RightLabel = "~g~30$"}, true, {
                            onListChange = function(Index)
                                Clothes.TablePantalon[i] = Index
                                MadeInFrance.TriggerLocalEvent('skinchanger:change', 'pants_2', Clothes.TablePantalon[i] - 1)
                            end,
                            onSelected = function()
                                local message = 'Achat d\'un pantalon '..i
                                MadeInFrance.SendEventToServer('attemptToPayMenu', message, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        MadeInFrance.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            MadeInFrance.SendEventToServer('AddClothesInInventory', 'pants', 'Pantalon '..i, {skin.pants_1, skin.pants_2})
                                        end)
                                    end,
                                    onFailed = function()
                                        RageUI.CloseAll()
                                        Clothes.opened = true
                                        RageUI.Visible(Clothes.mainMenu, true)
                                    end
                                }
                            end,
                            onActive = function()
                                MadeInFrance.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.pants_1) ~= tonumber(i) then
                                        MadeInFrance.TriggerLocalEvent('skinchanger:change', 'pants_1', i)
                                    end
                                end)
                            end,
                        })
                    end
                end)
                RageUI.IsVisible(Clothes.subMenu4, function()
                    for i = 0, maxVals['shoes_1'], 1 do          
                        RageUI.List("Chaussures #"..i, Clothes.Variations, Clothes.TableShoes[i], nil, {RightLabel = "~g~30$"}, true, {
                            onListChange = function(Index)
                                Clothes.TableShoes[i] = Index
                                MadeInFrance.TriggerLocalEvent('skinchanger:change', 'shoes_2', Clothes.TableShoes[i] - 1)
                            end,
                            onSelected = function()
                                local message = 'Achat d\'une paire de chaussures '..i
                                MadeInFrance.SendEventToServer('attemptToPayMenu', message, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        MadeInFrance.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            MadeInFrance.SendEventToServer('AddClothesInInventory', 'shoes', 'Chaussure '..i, {skin.shoes_1, skin.shoes_2})
                                        end)
                                    end,
                                    onFailed = function()
                                        RageUI.CloseAll()
                                        Clothes.opened = true
                                        RageUI.Visible(Clothes.mainMenu, true)
                                    end
                                }
                            end,
                            onActive = function()
                                MadeInFrance.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.shoes_1) ~= tonumber(i) then
                                        MadeInFrance.TriggerLocalEvent('skinchanger:change', 'shoes_1', i)
                                    end
                                end)
                            end,
                        })
                    end
                end)
                RageUI.IsVisible(Clothes.subMenu5, function()
                    for i = 0, maxVals['bags_1'], 1 do          
                        RageUI.List("Sacs #"..i, Clothes.Variations, Clothes.TableSacs[i], nil, {RightLabel = "~g~30$"}, true, {
                            onListChange = function(Index)
                                Clothes.TableSacs[i] = Index
                                MadeInFrance.TriggerLocalEvent('skinchanger:change', 'bags_2', Clothes.TableSacs[i] - 1)
                            end,
                            onSelected = function()
                                local message = 'Achat d\'un sac '..i
                                MadeInFrance.SendEventToServer('attemptToPayMenu', message, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        MadeInFrance.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            MadeInFrance.SendEventToServer('AddClothesInInventory', 'bag', 'Sac '..i, {skin.bags_1, skin.bags_2})
                                        end)
                                    end,
                                    onFailed = function()
                                        RageUI.CloseAll()
                                        Clothes.opened = true
                                        RageUI.Visible(Clothes.mainMenu, true)
                                    end
                                }
                            end,
                            onActive = function()
                                MadeInFrance.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.bags_1) ~= tonumber(i) then
                                        MadeInFrance.TriggerLocalEvent('skinchanger:change', 'bags_1', i)
                                    end
                                end)
                            end,
                        })
                    end
                end)
                RageUI.IsVisible(Clothes.subMenu8, function()
                    for i = 0, maxVals['helmet_1'], 1 do
                        RageUI.List("Chapeau #"..i, Clothes.Variations, Clothes.TableChapeau[i], nil, {RightLabel = "~g~30$"}, true, {
                            onListChange = function(Index)
                                Clothes.TableChapeau[i] = Index
                                MadeInFrance.TriggerLocalEvent('skinchanger:change', 'helmet_2', Clothes.TableChapeau[i] - 1)
                            end,
                            onSelected = function()
                                local message = 'Achat d\'un chapeau '..i
                                MadeInFrance.SendEventToServer('attemptToPayMenu', message, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        MadeInFrance.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            MadeInFrance.SendEventToServer('AddClothesInInventory', 'helmet', 'Chapeau '..i, {skin.helmet_1, skin.helmet_2})
                                        end)
                                    end,
                                    onFailed = function()
                                        RageUI.CloseAll()
                                        Clothes.opened = true
                                        RageUI.Visible(Clothes.mainMenu, true)
                                    end
                                }
                            end,
                            onActive = function()
                                MadeInFrance.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.helmet_1) ~= tonumber(i) then
                                        MadeInFrance.TriggerLocalEvent('skinchanger:change', 'helmet_1', i)
                                    end
                                end)
                            end,
                        })
                    end
                end)
                RageUI.IsVisible(Clothes.subMenu9, function()
                    for i = 0, maxVals['glasses_1'], 1 do
                        RageUI.List("Lunettes #"..i, Clothes.Variations, Clothes.TableLunettes[i], nil, {RightLabel = "~g~30$"}, true, {
                            onListChange = function(Index)
                                Clothes.TableLunettes[i] = Index
                                MadeInFrance.TriggerLocalEvent('skinchanger:change', 'glasses_2', Clothes.TableLunettes[i] - 1)
                            end,
                            onSelected = function()
                                local message = 'Achat d\'une paire de lunettes '..i
                                MadeInFrance.SendEventToServer('attemptToPayMenu', message, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        MadeInFrance.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            MadeInFrance.SendEventToServer('AddClothesInInventory', 'glasses', 'Lunettes '..i, {skin.glasses_1, skin.glasses_2})
                                        end)
                                    end,
                                    onFailed = function()
                                        RageUI.CloseAll()
                                        Clothes.opened = true
                                        RageUI.Visible(Clothes.mainMenu, true)
                                    end
                                }
                            end,
                            onActive = function()
                                MadeInFrance.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.glasses_1) ~= tonumber(i) then
                                        MadeInFrance.TriggerLocalEvent('skinchanger:change', 'glasses_1', i)
                                    end
                                end)
                            end,
                        })
                    end
                end)
                RageUI.IsVisible(Clothes.subMenu10, function()
                    for i = 0, maxVals['ears_1'], 1 do
                        RageUI.List("Oreillette #"..i, Clothes.Variations, Clothes.TableOreilles[i], nil, {RightLabel = "~g~30$"}, true, {
                            onListChange = function(Index)
                                Clothes.TableOreilles[i] = Index
                                MadeInFrance.TriggerLocalEvent('skinchanger:change', 'ears_2', Clothes.TableOreilles[i] - 1)
                            end,
                            onSelected = function()
                                local message = 'Achat d\'une Oreillette '..i
                                MadeInFrance.SendEventToServer('attemptToPayMenu', message, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        MadeInFrance.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            MadeInFrance.SendEventToServer('AddClothesInInventory', 'ears', 'Oreillette '..i, {skin.ears_1, skin.ears_2})
                                        end)
                                    end,
                                    onFailed = function()
                                        RageUI.CloseAll()
                                        Clothes.opened = true
                                        RageUI.Visible(Clothes.mainMenu, true)
                                    end
                                }
                            end,
                            onActive = function()
                                MadeInFrance.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.ears_1) ~= tonumber(i) then
                                        MadeInFrance.TriggerLocalEvent('skinchanger:change', 'ears_1', i)
                                    end
                                end)
                            end,
                        })
                    end
                end)
                Wait(0)
            end
        end)
    end
end

MadeInFrance.RegisterClientEvent('openClothMenu', function(header, type)
    if type == "Cloth" then
        Clothes:OpenMenu(header)
    end
end)