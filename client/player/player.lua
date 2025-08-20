LSLegacy.PlayerData = {}

LSLegacy.RegisterClientEvent('InitPlayer', function(data)
    LSLegacy.PlayerData = data
end)

LSLegacy.RegisterClientEvent('UpdatePlayer', function(data)
    LSLegacy.PlayerData = data
end)

LSLegacy.RegisterClientEvent('UpdateServerPlayer', function()
    local data = LSLegacy.PlayerData
    LSLegacy.SendEventToServer('ReceiveUpdateServerPlayer', data)
end)

function GetPlayerInventoryItems()
    return LSLegacy.PlayerData.inventory or {}
end

function GetPlayerInventoryWeight()
    return LSLegacy.PlayerData.weight or 0
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
            LSLegacy.PlayerData.skin = skin
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

CreateThread(function()
    local groups = {
        "AMBIENT_GANG_LOST",
        "AMBIENT_GANG_MEXICAN",
        "AMBIENT_GANG_FAMILY",
        "AMBIENT_GANG_BALLAS",
        "AMBIENT_GANG_MARABUNTE",
        "AMBIENT_GANG_CULT",
        "COP",
        "SECURITY_GUARD",
        "AGGRESSIVE_ANIMAL",
        "WILD_ANIMAL"
    }

    for _, group in ipairs(groups) do
        SetRelationshipBetweenGroups(1, GetHashKey(group), GetHashKey("PLAYER"))
    end
end)

Citizen.CreateThread(function()
    while true do
        HideHudComponentThisFrame(14)
        Wait(0)
    end
end)

LSLegacy.RegisterClientEvent('debug', function()
   ExecuteCommand('p1')
   Wait(1000)
   ExecuteCommand('p2')
end)