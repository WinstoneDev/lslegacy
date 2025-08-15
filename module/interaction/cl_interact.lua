local interactMenu = {
    opened = false
}

interactMenu.mainMenu = RageUI.CreateMenu("Interact", "Interact Menu")
interactMenu.inventoryMenu = RageUI.CreateSubMenu(interactMenu.mainMenu, "Inventory", "Inventory Menu")
interactMenu.walletMenu = RageUI.CreateSubMenu(interactMenu.mainMenu, "Wallet", "Wallet Menu")
interactMenu.actionItem = RageUI.CreateSubMenu(interactMenu.inventoryMenu, "Inventory", "Inventory Action")

interactMenu.mainMenu.Closed = function()
    interactMenu.opened = false
    RageUI.Visible(interactMenu.mainMenu, false)
end

function interactMenu:OpenMenu()
    if RageUI.GetInMenu() then
        return
    end
    if interactMenu.opened then
        interactMenu.opened = false
        RageUI.Visible(interactMenu.mainMenu, false)
    else
        interactMenu.opened = true
        RageUI.Visible(interactMenu.mainMenu, true)
        CreateThread(function()
            while interactMenu.opened do
                Wait(0)
                RageUI.IsVisible(interactMenu.mainMenu, function()
                    RageUI.Button('Inventaire', nil, {}, true, {}, interactMenu.inventoryMenu)
                    RageUI.Button('Porte-feuille', nil, {}, true, {}, interactMenu.walletMenu)
                end)
                RageUI.IsVisible(interactMenu.inventoryMenu, function()
                    RageUI.Separator('Poids : '..GramsOrKg(MadeInFrance.PlayerData.weight)..' / '..Config.Informations["MaxWeight"]..'KG')
                    for name, item in pairs(MadeInFrance.PlayerData.inventory) do
                        RageUI.Button(item.label..' x'..math.floor(item.count), nil, {}, true, {
                            onSelected = function()
                                interactMenu.Item = item.name
                                interactMenu.Label = item.label
                                Wait(150)
                                RageUI.CloseAll()
                                RageUI.Visible(interactMenu.actionItem, true)
                            end
                        })
                    end
                end)
                RageUI.IsVisible(interactMenu.walletMenu, function()
                end)
                RageUI.IsVisible(interactMenu.actionItem, function()
                    RageUI.Button("Utiliser", nil, {}, true, {
                        onSelected = function()
                            MadeInFrance.SendEventToServer('madeinfrance:useItem', interactMenu.Item, "CARTE 12434")
                            RageUI.GoBack()
                        end
                    })
                    RageUI.Button("Donner", nil, {}, true, {})
                    RageUI.Button("Rename", nil, {}, true, {
                        onSelected = function()
                            local result = MadeInFrance.KeyboardInput("Label", 30)
                            if result ~= nil and #result > 2 then
                                local row = MadeInFrance.KeyboardInput("Montant", 30)
                                if row ~= nil and tonumber(row) then
                                    MadeInFrance.SendEventToServer('madeinfrance:renameItem', interactMenu.Item, interactMenu.Label, result, tonumber(row))
                                    RageUI.GoBack()
                                end
                            end
                        end
                    })
                    RageUI.Button("Jeter", nil, {}, true, {
                        onSelected = function()
                            local result = MadeInFrance.KeyboardInput("Montant", 30)
                            local pPed = PlayerPedId()
                            local pCoords = GetEntityCoords(pPed)
                            local pHeading = GetEntityHeading(pPed)

                            if result ~= nil and tonumber(result) then
                                MadeInFrance.SendEventToServer('madeinfrance:addItemPickup', interactMenu.Item, interactMenu.Label, result, {x = pCoords.x, y = pCoords.y, z = pCoords.z, w = pHeading})
                                RageUI.GoBack()
                            end
                        end
                    })
                end)
            end
        end)
    end
end

Keys.Register("F5", "F5", "Ouvrir InteractMenu", function()
    interactMenu:OpenMenu()
end)

function GramsOrKg(weight)
    if weight >= 1 then
        return math.floor(weight) .. 'KG'
    else
        return math.floor(weight*1000) .. 'G'
    end
end