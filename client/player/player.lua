MadeInFrance.PlayerData = {}

MadeInFrance.RegisterClientEvent('InitPlayer', function(data)
    MadeInFrance.PlayerData = data
end)

MadeInFrance.RegisterClientEvent('UpdatePlayer', function(data)
    MadeInFrance.PlayerData = data
end)

MadeInFrance.RegisterClientEvent('UpdateServerPlayer', function()
    local data = MadeInFrance.PlayerData
    MadeInFrance.SendEventToServer('ReceiveUpdateServerPlayer', data)
end)

function GetPlayerInventoryItems()
    return MadeInFrance.PlayerData.inventory or {}
end

function GetPlayerInventoryWeight()
    return MadeInFrance.PlayerData.weight or 0
end

function GetOriginalLabel(item)
    if Config.Items[item] then
        return Config.Items[item].label
    else
        return nil
    end
end

Citizen.CreateThread( function()
    while true do
        TriggerEvent('skinchanger:getSkin', function(skin)
            MadeInFrance.PlayerData.skin = skin
        end)
       Wait(60000)
    end
end)

Citizen.CreateThread( function()
    for a = 1, 15 do
        EnableDispatchService(a, false)
    end
    while true do
        playerPed = PlayerPedId()
        playerLocalisation = GetEntityCoords(playerPed)
        ClearAreaOfCops(playerLocalisation.x, playerLocalisation.y, playerLocalisation.z, 400.0)
        SetMaxWantedLevel(0)
        ClearPlayerWantedLevel(PlayerId())
        SetPoliceIgnorePlayer(PlayerId(), true)
        SetRelationshipBetweenGroups(1, GetHashKey("AMBIENT_GANG_LOST"), GetHashKey("PLAYER"))
        SetRelationshipBetweenGroups(1, GetHashKey("AMBIENT_GANG_MEXICAN"), GetHashKey("PLAYER"))
        SetRelationshipBetweenGroups(1, GetHashKey("AMBIENT_GANG_FAMILY"), GetHashKey("PLAYER"))
        SetRelationshipBetweenGroups(1, GetHashKey("AMBIENT_GANG_BALLAS"), GetHashKey("PLAYER"))
        SetRelationshipBetweenGroups(1, GetHashKey("AMBIENT_GANG_MARABUNTE"), GetHashKey("PLAYER"))
        SetRelationshipBetweenGroups(1, GetHashKey("AMBIENT_GANG_CULT"), GetHashKey("PLAYER"))
        SetRelationshipBetweenGroups(1, GetHashKey("COP"), GetHashKey("PLAYER"))
        SetRelationshipBetweenGroups(1, GetHashKey("SECURITY_GUARD"), GetHashKey("PLAYER"))
        DisablePlayerVehicleRewards(PlayerId()) 
        DisableControlAction(0, 199, true) 
        SetPedSuffersCriticalHits(PlayerPedId(), false) 
        SetWeaponDamageModifier(GetHashKey("WEAPON_UNARMED"), 0.5)
        InvalidateIdleCam()
        SetPedHelmet(PlayerPedId(), false) 
        HideHudComponentThisFrame(19)
        HideHudComponentThisFrame(20)
        BlockWeaponWheelThisFrame()
        SetPedCanSwitchWeapon(PlayerPedId(), false)
        DisablePoliceReports()
        if IsPedInAnyVehicle(PlayerPedId(), false) then
            if GetPedInVehicleSeat(GetVehiclePedIsIn(PlayerPedId(), false), 0) == PlayerPedId() then
                if GetIsTaskActive(PlayerPedId(), 165) then
                    SetPedIntoVehicle(PlayerPedId(), GetVehiclePedIsIn(PlayerPedId(), false), 0)
                end
            end
        end
        Wait(100)
    end
end)

Citizen.CreateThread(function()
    while true do
        HideHudComponentThisFrame(14)
        Wait(0)
    end
end)

MadeInFrance.RegisterClientEvent('debug', function()
   ExecuteCommand('p1')
   Wait(1000)
   ExecuteCommand('p2')
end)