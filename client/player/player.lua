local playerLoaded = false
LSLegacy.PlayerData = {}

LSLegacy.Events.Register('lslegacy:initPlayer', function(data)
    Config.Development.Print("[client] InitPlayer reçu, id=" .. tostring(data and data.id) .. " slot=" .. tostring(data and data.slot))
    LSLegacy.PlayerData = data
    playerLoaded = true
    local savedHealth = tonumber(data.health)
    if savedHealth and savedHealth > 101 then
        CreateThread(function()
            Wait(1500)
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and not IsEntityDead(ped) then
                SetEntityHealth(ped, math.min(savedHealth, 200))
            end
        end)
    end
end)

LSLegacy.Events.Register('lslegacy:updatePlayer', function(data)
    LSLegacy.PlayerData = data
end)

LSLegacy.Events.Register('lslegacy:updateServerPlayer', function()
    local data = LSLegacy.PlayerData
    LSLegacy.Events.SendToServer('lslegacy:receiveUpdateServerPlayer', data)
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
        if playerLoaded then
            LSLegacy.Events.TriggerLocal('skinchanger:getSkin', function(skin)
                LSLegacy.PlayerData.skin = skin
            end)
       end
       Wait(10000)
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
        DisablePoliceReports()
        SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
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
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)

            if GetPedInVehicleSeat(veh, -1) == ped and DoesVehicleHaveWeapons(veh) then
                SetPedCanSwitchWeapon(ped, true)
                Wait(0)
                goto continue
            end
        end

        HudWeaponWheelIgnoreSelection()
        SetPedCanSwitchWeapon(ped, false)
        HideHudComponentThisFrame(19)
        HideHudComponentThisFrame(20)

        ::continue::
        Wait(0)
    end
end)

LSLegacy.Events.Register('debug', function()
   ExecuteCommand('p1')
   Wait(1000)
   ExecuteCommand('p2')
end)