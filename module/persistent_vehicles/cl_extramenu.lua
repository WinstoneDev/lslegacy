local ExtrasMenu = {
    opened = false,
    mainMenu = nil,
    currentVeh = 0
}

ExtrasMenu.mainMenu = RageUI.CreateMenu("Extras", "Gestion des extras du véhicule")
ExtrasMenu.mainMenu.Display.Header = true

ExtrasMenu.mainMenu.Closed = function()
    ExtrasMenu.opened = false
    ExtrasMenu.currentVeh = 0
end

function ExtrasMenu:OpenMenu()
    if RageUI.GetInMenu() then
        return
    end

    if ExtrasMenu.opened then
        ExtrasMenu.opened = false
        ExtrasMenu.mainMenu:Close()
    else
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle == 0 then
            LSLegacy.ShowNotification(nil, "Vous devez être dans un véhicule pour accéder à ce menu.", "error")
            return
        end
        
        ExtrasMenu.opened = true
        ExtrasMenu.currentVeh = vehicle
        RageUI.Visible(ExtrasMenu.mainMenu, true)

        Citizen.CreateThread(function()
            while ExtrasMenu.opened do
                RageUI.IsVisible(ExtrasMenu.mainMenu, function()
                    
                    for i = 0, 20 do
                        if DoesExtraExist(ExtrasMenu.currentVeh, i) then
                            
                            local isExtraOn = IsVehicleExtraTurnedOn(ExtrasMenu.currentVeh, i)
                            RageUI.Button("Extra N°" .. i, nil, {
                                RightLabel = isExtraOn and "~g~Activé" or "~r~Désactivé"
                            }, true, {
                                onSelected = function()
                                    local newState = nil
                                    if isExtraOn == 1 then
                                        newState = 1
                                    elseif isExtraOn == false then
                                        newState = 0
                                    end
                                    SetVehicleExtra(ExtrasMenu.currentVeh, i, newState)
                                end
                            })
                        end
                    end

                end)
                Wait(0)
            end
        end)
    end
end

Keys.Register("F5", "F5", "Ouvrir le menu des extras du véhicule", function()
    ExtrasMenu:OpenMenu()
end)