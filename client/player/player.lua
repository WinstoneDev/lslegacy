Offline.PlayerData = {}

Offline.RegisterClientEvent('InitPlayer', function(data)
    Offline.PlayerData = data
end)

Offline.RegisterClientEvent('UpdatePlayer', function(data)
    Offline.PlayerData = data
end)

function GetPlayerInventoryItems()
    return Offline.PlayerData.inventory or {}
end

function GetPlayerInventoryWeight()
    return Offline.PlayerData.weight or 0
end

function GetOriginalLabel(item)
    if Config.Items[item] then
        return Config.Items[item].label
    else
        return nil
    end
end

CreateThread( function()
    while true do
       Citizen.Wait(0)
        RestorePlayerStamina(PlayerId(), 1.0)
        SetEntityProofs(PlayerPedId(), false, true, true, true, false, false, false, false)
        DisablePlayerVehicleRewards(PlayerId()) -- Pas de drop d'arme véhicule
        DisableControlAction(0, 199, true) -- Pas la Map sur P
        SetPedSuffersCriticalHits(PlayerPedId(), false) -- Pas de NoHeadShot
        SetWeaponDamageModifier(GetHashKey("WEAPON_UNARMED"), 0.5) -- Dégat cout de poing
        InvalidateIdleCam() -- Disable cinématique AFK
        SetPedHelmet(PlayerPedId(), false) -- Pas de casque auto sur les moto
        HideHudComponentThisFrame(19)
        HideHudComponentThisFrame(20)
        BlockWeaponWheelThisFrame()
        SetPedCanSwitchWeapon(PlayerPedId(), false)
        for a = 1, 15 do
            EnableDispatchService(a, false) -- Pas de dispatch
        end
        DisablePoliceReports() -- Disable Police Call
        if IsPedInAnyVehicle(GetPlayerPed(-1), false) then
            if GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), 0) == GetPlayerPed(-1) then
                if GetIsTaskActive(GetPlayerPed(-1), 165) then
                    SetPedIntoVehicle(GetPlayerPed(-1), GetVehiclePedIsIn(GetPlayerPed(-1), false), 0)
                end
            end
        end
    end
end)