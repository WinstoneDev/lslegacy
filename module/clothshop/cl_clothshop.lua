local Clothes = {
    TableChapeau = {},
    TableLunettes = {},
    TableOreilles = {},
    TablePantalon = {},
    TableShoes = {},
    TableSacs = {},
    TableMasques = {},
    TableTshirt = {},
    TableTorse = {},
    TableBras = {},
    TableMontres = {},
    TableBracelets = {},
    TableChaines = {},
    TableBadges = {},
    LastSkin = {},
    Variations = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30},
}

function Clothes:loadLastSkin()
    TriggerEvent('skinchanger:loadSkin', Clothes.LastSkin) 
end

-- Menus principaux
Clothes.mainMenu = RageUI.CreateMenu("", "Magasin de vêtements")
Clothes.MasksMenu = RageUI.CreateMenu("", "Magasin de masques")

-- Sous-menus principaux
Clothes.subMenu = RageUI.CreateSubMenu(Clothes.mainMenu, "", " ") -- Hauts
Clothes.subMenu2 = RageUI.CreateSubMenu(Clothes.mainMenu, "", " ") -- Accessoires
Clothes.subMenu3 = RageUI.CreateSubMenu(Clothes.mainMenu, "", " ") -- Pantalons
Clothes.subMenu4 = RageUI.CreateSubMenu(Clothes.mainMenu, "", " ") -- Chaussures
Clothes.subMenu5 = RageUI.CreateSubMenu(Clothes.mainMenu, "", " ") -- Sacs
Clothes.subMenu6 = RageUI.CreateSubMenu(Clothes.mainMenu, "", " ") -- Badge

-- Sous-menus pour "Hauts"
Clothes.subMenuTshirt = RageUI.CreateSubMenu(Clothes.subMenu, "", " ")
Clothes.subMenuTorse = RageUI.CreateSubMenu(Clothes.subMenu, "", " ")
Clothes.subMenuBras = RageUI.CreateSubMenu(Clothes.subMenu, "", " ")

-- Sous-menus pour "Accessoires"
Clothes.subMenu8 = RageUI.CreateSubMenu(Clothes.subMenu2, "", " ") -- Chapeaux
Clothes.subMenu9 = RageUI.CreateSubMenu(Clothes.subMenu2, "", " ") -- Lunettes
Clothes.subMenu10 = RageUI.CreateSubMenu(Clothes.subMenu2, "", " ") -- Boucles d'oreilles
Clothes.subMenu11 = RageUI.CreateSubMenu(Clothes.subMenu2, "", " ") -- Montres
Clothes.subMenu12 = RageUI.CreateSubMenu(Clothes.subMenu2, "", " ") -- Bracelets
Clothes.subMenu13 = RageUI.CreateSubMenu(Clothes.subMenu2, "", " ") -- Chaînes

-- Configuration des menus
local menus = {
    Clothes.mainMenu, Clothes.MasksMenu, Clothes.subMenu, Clothes.subMenu2, Clothes.subMenu3, Clothes.subMenu4, Clothes.subMenu5,
    Clothes.subMenu6, Clothes.subMenuTshirt, Clothes.subMenuTorse, Clothes.subMenuBras, Clothes.subMenu8, Clothes.subMenu9,
    Clothes.subMenu10, Clothes.subMenu11, Clothes.subMenu12, Clothes.subMenu13
}

for _, menu in ipairs(menus) do
    menu:DisplayGlare(false)
    menu:AcceptFilter(true)
end

Clothes.mainMenu.Closed = function()
    Clothes.opened = false
    RageUI.Visible(Clothes.mainMenu, false)
    Clothes:loadLastSkin()
end

Clothes.MasksMenu.Closed = function()
    Clothes.opened = false
    RageUI.Visible(Clothes.MasksMenu, false)
    Clothes:loadLastSkin()
end

function Clothes:OpenMenu(header)
    if RageUI.GetInMenu() then return end
    if Clothes.opened then
        Clothes.opened = false
        RageUI.Visible(Clothes.mainMenu, false)
    else
        for _, menu in ipairs(menus) do
            menu:SetSpriteBanner(header, header)
        end
        Clothes.opened = true
        RageUI.Visible(Clothes.mainMenu, true)
        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
            Clothes.LastSkin = skin
        end)
        LSLegacy.TriggerLocalEvent('skinchanger:getData', function(components, max)
            maxVals = {
                tshirt_1 = max.tshirt_1,
                torso_1 = max.torso_1,
                pants_1 = max.pants_1,
                shoes_1 = max.shoes_1,
                helmet_1 = max.helmet_1,
                glasses_1 = max.glasses_1,
                ears_1 = max.ears_1,
                bags_1 = max.bags_1,
                arms = max.arms,
                watches_1 = max.watches_1,
                bracelets_1 = max.bracelets_1,
                chain_1 = max.chain_1,
                decals_1 = max.decals_1
            }

            local tablesToInit = {
                {max = max.tshirt_1, table = Clothes.TableTshirt},
                {max = max.torso_1, table = Clothes.TableTorse},
                {max = max.arms, table = Clothes.TableBras},
                {max = max.pants_1, table = Clothes.TablePantalon},
                {max = max.shoes_1, table = Clothes.TableShoes},
                {max = max.bags_1, table = Clothes.TableSacs},
                {max = max.helmet_1, table = Clothes.TableChapeau},
                {max = max.glasses_1, table = Clothes.TableLunettes},
                {max = max.ears_1, table = Clothes.TableOreilles},
                {max = max.watches_1, table = Clothes.TableMontres},
                {max = max.bracelets_1, table = Clothes.TableBracelets},
                {max = max.chain_1, table = Clothes.TableChaines},
                {max = max.decals_1, table = Clothes.TableBadges},
            }

            for _, v in ipairs(tablesToInit) do
                for i = 0, v.max, 1 do
                    v.table[i] = 1
                end
            end
        end)
        Wait(550)
        Citizen.CreateThread(function()
            while Clothes.opened do
                RageUI.IsVisible(Clothes.mainMenu, function()
                    RageUI.Button('Hauts', nil, {}, true, {}, Clothes.subMenu)
                    RageUI.Button('Pantalons', nil, {}, true, {}, Clothes.subMenu3)
                    RageUI.Button('Chaussures', nil, {}, true, {}, Clothes.subMenu4)
                    RageUI.Button('Accessoires', nil, {}, true, {}, Clothes.subMenu2)
                    RageUI.Button('Sacs', nil, {}, true, {}, Clothes.subMenu5)
                    RageUI.Button('Badge', nil, {}, true, {}, Clothes.subMenu6)
                end)

                RageUI.IsVisible(Clothes.subMenu, function()
                    RageUI.Button('T-Shirts', nil, {}, true, {}, Clothes.subMenuTshirt)
                    RageUI.Button('Torses / Vestes', nil, {}, true, {}, Clothes.subMenuTorse)
                    RageUI.Button('Bras / Gants', nil, {}, true, {}, Clothes.subMenuBras)
                end)

                RageUI.IsVisible(Clothes.subMenuTshirt, function()
                    for i = 0, maxVals['tshirt_1'], 1 do          
                        RageUI.List("T-shirt #"..i, Clothes.Variations, Clothes.TableTshirt[i], nil, { RightLabel = "~g~30$"}, true, {
                            onListChange = function(Index)
                                Clothes.TableTshirt[i] = Index
                                LSLegacy.TriggerLocalEvent('skinchanger:change', 'tshirt_2', Clothes.TableTshirt[i] - 1)
                            end,
                            onSelected = function()
                                LSLegacy.SendEventToServer('attemptToPayMenu', 'Achat d\'un t-shirt '..i, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            LSLegacy.SendEventToServer('AddClothesInInventory', 'tshirt', 'T-shirt '..i, {skin.tshirt_1, skin.tshirt_2})
                                        end)
                                    end
                                }
                            end,
                            onActive = function()
                                LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.tshirt_1) ~= tonumber(i) then
                                        LSLegacy.TriggerLocalEvent('skinchanger:change', 'tshirt_1', i)
                                    end
                                end)
                            end,
                        })
                    end
                end)

                RageUI.IsVisible(Clothes.subMenuTorse, function()
                    for i = 0, maxVals['torso_1'], 1 do          
                        RageUI.List("Torse #"..i, Clothes.Variations, Clothes.TableTorse[i], nil, { RightLabel = "~g~30$"}, true, {
                            onListChange = function(Index)
                                Clothes.TableTorse[i] = Index
                                LSLegacy.TriggerLocalEvent('skinchanger:change', 'torso_2', Clothes.TableTorse[i] - 1)
                            end,
                            onSelected = function()
                                LSLegacy.SendEventToServer('attemptToPayMenu', 'Achat d\'un torse '..i, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            LSLegacy.SendEventToServer('AddClothesInInventory', 'torso', 'Torse '..i, {skin.torso_1, skin.torso_2})
                                        end)
                                    end
                                }
                            end,
                            onActive = function()
                                LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.torso_1) ~= tonumber(i) then
                                        LSLegacy.TriggerLocalEvent('skinchanger:change', 'torso_1', i)
                                    end
                                end)
                            end,
                        })
                    end
                end)

                RageUI.IsVisible(Clothes.subMenuBras, function()
                    for i = 0, maxVals['arms'], 1 do          
                        RageUI.List("Bras #"..i, Clothes.Variations, Clothes.TableBras[i], nil, { RightLabel = "~g~30$"}, true, {
                            onListChange = function(Index)
                                Clothes.TableBras[i] = Index
                                -- Note: Arms usually don't have a texture component (_2), but we keep the logic for consistency if needed.
                            end,
                            onSelected = function()
                                LSLegacy.SendEventToServer('attemptToPayMenu', 'Achat de bras '..i, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            LSLegacy.SendEventToServer('AddClothesInInventory', 'arms', 'Gants/Bras '..i, {skin.arms, 0}) -- 0 for texture
                                        end)
                                    end
                                }
                            end,
                            onActive = function()
                                LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.arms) ~= tonumber(i) then
                                        LSLegacy.TriggerLocalEvent('skinchanger:change', 'arms', i)
                                    end
                                end)
                            end,
                        })
                    end
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
                                LSLegacy.TriggerLocalEvent('skinchanger:change', 'pants_2', Clothes.TablePantalon[i] - 1)
                            end,
                            onSelected = function()
                                LSLegacy.SendEventToServer('attemptToPayMenu', 'Achat d\'un pantalon '..i, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            LSLegacy.SendEventToServer('AddClothesInInventory', 'pants', 'Pantalon '..i, {skin.pants_1, skin.pants_2})
                                        end)
                                    end
                                }
                            end,
                            onActive = function()
                                LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.pants_1) ~= tonumber(i) then
                                        LSLegacy.TriggerLocalEvent('skinchanger:change', 'pants_1', i)
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
                                LSLegacy.TriggerLocalEvent('skinchanger:change', 'shoes_2', Clothes.TableShoes[i] - 1)
                            end,
                            onSelected = function()
                                LSLegacy.SendEventToServer('attemptToPayMenu', 'Achat d\'une paire de chaussures '..i, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            LSLegacy.SendEventToServer('AddClothesInInventory', 'shoes', 'Chaussure '..i, {skin.shoes_1, skin.shoes_2})
                                        end)
                                    end
                                }
                            end,
                            onActive = function()
                                LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.shoes_1) ~= tonumber(i) then
                                        LSLegacy.TriggerLocalEvent('skinchanger:change', 'shoes_1', i)
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
                                LSLegacy.TriggerLocalEvent('skinchanger:change', 'bags_2', Clothes.TableSacs[i] - 1)
                            end,
                            onSelected = function()
                                LSLegacy.SendEventToServer('attemptToPayMenu', 'Achat d\'un sac '..i, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            LSLegacy.SendEventToServer('AddClothesInInventory', 'bags', 'Sac '..i, {skin.bags_1, skin.bags_2})
                                        end)
                                    end
                                }
                            end,
                            onActive = function()
                                LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.bags_1) ~= tonumber(i) then
                                        LSLegacy.TriggerLocalEvent('skinchanger:change', 'bags_1', i)
                                    end
                                end)
                            end,
                        })
                    end
                end)

                RageUI.IsVisible(Clothes.subMenu6, function()
                    for i = 0, maxVals['decals_1'], 1 do          
                        RageUI.List("Badge #"..i, Clothes.Variations, Clothes.TableBadges[i], nil, { RightLabel = "~g~30$"}, true, {
                            onListChange = function(Index)
                                Clothes.TableBadges[i] = Index
                                LSLegacy.TriggerLocalEvent('skinchanger:change', 'decals_2', Clothes.TableBadges[i] - 1)
                            end,
                            onSelected = function()
                                LSLegacy.SendEventToServer('attemptToPayMenu', 'Achat d\'un badge '..i, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            LSLegacy.SendEventToServer('AddClothesInInventory', 'decals', 'Badge '..i, {skin.decals_1, skin.decals_2})
                                        end)
                                    end
                                }
                            end,
                            onActive = function()
                                LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.decals_1) ~= tonumber(i) then
                                        LSLegacy.TriggerLocalEvent('skinchanger:change', 'decals_1', i)
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
                                LSLegacy.TriggerLocalEvent('skinchanger:change', 'helmet_2', Clothes.TableChapeau[i] - 1)
                            end,
                            onSelected = function()
                                LSLegacy.SendEventToServer('attemptToPayMenu', 'Achat d\'un chapeau '..i, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            LSLegacy.SendEventToServer('AddClothesInInventory', 'helmet', 'Chapeau '..i, {skin.helmet_1, skin.helmet_2})
                                        end)
                                    end
                                }
                            end,
                            onActive = function()
                                LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.helmet_1) ~= tonumber(i) then
                                        LSLegacy.TriggerLocalEvent('skinchanger:change', 'helmet_1', i)
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
                                LSLegacy.TriggerLocalEvent('skinchanger:change', 'glasses_2', Clothes.TableLunettes[i] - 1)
                            end,
                            onSelected = function()
                                LSLegacy.SendEventToServer('attemptToPayMenu', 'Achat d\'une paire de lunettes '..i, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            LSLegacy.SendEventToServer('AddClothesInInventory', 'glasses', 'Lunettes '..i, {skin.glasses_1, skin.glasses_2})
                                        end)
                                    end
                                }
                            end,
                            onActive = function()
                                LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.glasses_1) ~= tonumber(i) then
                                        LSLegacy.TriggerLocalEvent('skinchanger:change', 'glasses_1', i)
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
                                LSLegacy.TriggerLocalEvent('skinchanger:change', 'ears_2', Clothes.TableOreilles[i] - 1)
                            end,
                            onSelected = function()
                                LSLegacy.SendEventToServer('attemptToPayMenu', 'Achat d\'une Oreillette '..i, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            LSLegacy.SendEventToServer('AddClothesInInventory', 'ears', 'Oreillette '..i, {skin.ears_1, skin.ears_2})
                                        end)
                                    end
                                }
                            end,
                            onActive = function()
                                LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.ears_1) ~= tonumber(i) then
                                        LSLegacy.TriggerLocalEvent('skinchanger:change', 'ears_1', i)
                                    end
                                end)
                            end,
                        })
                    end
                end)

                RageUI.IsVisible(Clothes.subMenu11, function()
                    for i = 0, maxVals['watches_1'], 1 do
                        RageUI.List("Montre #"..i, Clothes.Variations, Clothes.TableMontres[i], nil, {RightLabel = "~g~30$"}, true, {
                            onListChange = function(Index)
                                Clothes.TableMontres[i] = Index
                                LSLegacy.TriggerLocalEvent('skinchanger:change', 'watches_2', Clothes.TableMontres[i] - 1)
                            end,
                            onSelected = function()
                                LSLegacy.SendEventToServer('attemptToPayMenu', 'Achat d\'une montre '..i, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            LSLegacy.SendEventToServer('AddClothesInInventory', 'watches', 'Montre '..i, {skin.watches_1, skin.watches_2})
                                        end)
                                    end
                                }
                            end,
                            onActive = function()
                                LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.watches_1) ~= tonumber(i) then
                                        LSLegacy.TriggerLocalEvent('skinchanger:change', 'watches_1', i)
                                    end
                                end)
                            end,
                        })
                    end
                end)

                RageUI.IsVisible(Clothes.subMenu12, function()
                    for i = 0, maxVals['bracelets_1'], 1 do
                        RageUI.List("Bracelet #"..i, Clothes.Variations, Clothes.TableBracelets[i], nil, {RightLabel = "~g~30$"}, true, {
                            onListChange = function(Index)
                                Clothes.TableBracelets[i] = Index
                                LSLegacy.TriggerLocalEvent('skinchanger:change', 'bracelets_2', Clothes.TableBracelets[i] - 1)
                            end,
                            onSelected = function()
                                LSLegacy.SendEventToServer('attemptToPayMenu', 'Achat d\'un bracelet '..i, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            LSLegacy.SendEventToServer('AddClothesInInventory', 'bracelet', 'Bracelet '..i, {skin.bracelets_1, skin.bracelets_2})
                                        end)
                                    end
                                }
                            end,
                            onActive = function()
                                LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.bracelets_1) ~= tonumber(i) then
                                        LSLegacy.TriggerLocalEvent('skinchanger:change', 'bracelets_1', i)
                                    end
                                end)
                            end,
                        })
                    end
                end)

                RageUI.IsVisible(Clothes.subMenu13, function()
                    for i = 0, maxVals['chain_1'], 1 do
                        RageUI.List("Chaîne #"..i, Clothes.Variations, Clothes.TableChaines[i], nil, {RightLabel = "~g~30$"}, true, {
                            onListChange = function(Index)
                                Clothes.TableChaines[i] = Index
                                LSLegacy.TriggerLocalEvent('skinchanger:change', 'chain_2', Clothes.TableChaines[i] - 1)
                            end,
                            onSelected = function()
                                LSLegacy.SendEventToServer('attemptToPayMenu', 'Achat d\'une chaîne '..i, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            LSLegacy.SendEventToServer('AddClothesInInventory', 'chain', 'Chaîne '..i, {skin.chain_1, skin.chain_2})
                                        end)
                                    end
                                }
                            end,
                            onActive = function()
                                LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.chain_1) ~= tonumber(i) then
                                        LSLegacy.TriggerLocalEvent('skinchanger:change', 'chain_1', i)
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

function Clothes:OpenMaskMenu(header)
    if RageUI.GetInMenu() then return end
    if Clothes.opened then
        Clothes.opened = false
        RageUI.Visible(Clothes.MasksMenu, false)
    else
        Clothes.MasksMenu:SetSpriteBanner(header, header)
        Clothes.opened = true
        RageUI.Visible(Clothes.MasksMenu, true)
        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
            Clothes.LastSkin = skin
        end)
        LSLegacy.TriggerLocalEvent('skinchanger:getData', function(components, max)
            maxVals = { mask_1 = max.mask_1 }
            for i = 0, max.mask_1, 1 do
                Clothes.TableMasques[i] = 1
            end
        end)
        Wait(550)
        Citizen.CreateThread(function()
            while Clothes.opened do
                RageUI.IsVisible(Clothes.MasksMenu, function()
                    for i = 0, maxVals['mask_1'], 1 do
                        RageUI.List("Masque #"..i, Clothes.Variations, Clothes.TableMasques[i], nil, {RightLabel = "~g~30$"}, true, {
                            onListChange = function(Index)
                                Clothes.TableMasques[i] = Index
                                LSLegacy.TriggerLocalEvent('skinchanger:change', 'mask_2', Clothes.TableMasques[i] - 1)
                            end,
                            onSelected = function()
                                LSLegacy.SendEventToServer('attemptToPayMenu', 'Achat d\'un masque '..i, 30)
                                paymentMenu.actions = {
                                    onSucess = function()
                                        LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                            LSLegacy.SendEventToServer('AddClothesInInventory', 'mask', 'Masque '..i, {skin.mask_1, skin.mask_2})
                                        end)
                                    end
                                }
                            end,
                            onActive = function()
                                LSLegacy.TriggerLocalEvent('skinchanger:getSkin', function(skin)
                                    if tonumber(skin.mask_1) ~= tonumber(i) then
                                        LSLegacy.TriggerLocalEvent('skinchanger:change', 'mask_1', i)
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

LSLegacy.RegisterClientEvent('openClothMenu', function(header, type)
    if type == "Cloth" then
        Clothes:OpenMenu(header)
    elseif type == "Mask" then
        Clothes:OpenMaskMenu(header)
    end
end)