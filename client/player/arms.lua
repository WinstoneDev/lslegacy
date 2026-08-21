local armsDict = "random@mugging3"
local armsClip = "handsup_standing_base"
local armsUp = false

local function startArms(ped)
    RequestAnimDict(armsDict)
    while not HasAnimDictLoaded(armsDict) do Wait(0) end
    SetPedCurrentWeaponVisible(ped, false, true, true, true)
    TaskPlayAnim(ped, armsDict, armsClip, 8.0, -8.0, -1, 49, 0, false, false, false)
    RemoveAnimDict(armsDict)
end

local function stopArms(ped)
    if IsEntityPlayingAnim(ped, armsDict, armsClip, 3) then
        StopAnimTask(ped, armsDict, armsClip, -4.0)
    end
    if not IsPedInAnyVehicle(ped, false) then
        SetPedCurrentWeaponVisible(ped, true, true, true, true)
    end
end

RegisterCommand('+lslegacy_arms', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) or not IsPedOnFoot(ped) then return end
    armsUp = true
    startArms(ped)
end, false)

RegisterCommand('-lslegacy_arms', function()
    if not armsUp then return end
    armsUp = false
    stopArms(PlayerPedId())
end, false)

RegisterKeyMapping('+lslegacy_arms', 'Lever les mains', 'keyboard', 'U')

CreateThread(function()
    while true do
        if armsUp then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) or not IsPedOnFoot(ped) then
                armsUp = false
                stopArms(ped)
            else
                DisableControlAction(0, 24, true) -- attack
                DisableControlAction(0, 25, true) -- aim
                DisableControlAction(0, 47, true) -- weapon wheel
                DisableControlAction(0, 58, true) -- weapon wheel (alt)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)
