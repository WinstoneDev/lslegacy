local pointDict = "anim@mp_point"
local pointing = false

local function startPointing(ped)
    RequestAnimDict(pointDict)
    while not HasAnimDictLoaded(pointDict) do Wait(0) end
    SetPedCurrentWeaponVisible(ped, false, true, true, true)
    SetPedConfigFlag(ped, 36, true)
    Citizen.InvokeNative(0x2D537BA194896636, ped, "task_mp_pointing", 0.5, 0, pointDict, 24)
    RemoveAnimDict(pointDict)
end

local function stopPointing(ped)
    Citizen.InvokeNative(0xD01015C7316AE176, ped, "Stop")
    if not IsPedInjured(ped) then
        ClearPedSecondaryTask(ped)
    end
    if not IsPedInAnyVehicle(ped, false) then
        SetPedCurrentWeaponVisible(ped, true, true, true, true)
    end
    SetPedConfigFlag(ped, 36, false)
end

RegisterCommand('+lslegacy_point', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) or not IsPedOnFoot(ped) then
        return
    end
    pointing = true
    startPointing(ped)
end, false)

RegisterCommand('-lslegacy_point', function()
    if not pointing then return end
    pointing = false
    stopPointing(PlayerPedId())
end, false)

RegisterKeyMapping('+lslegacy_point', 'Pointer du doigt', 'keyboard', 'B')

CreateThread(function()
    while true do
        if pointing then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) or not IsPedOnFoot(ped) then
                pointing = false
                stopPointing(ped)
            else
                DisableControlAction(0, 24, true) -- attack
                DisableControlAction(0, 25, true) -- aim

                local camPitch = GetGameplayCamRelativePitch()
                if camPitch < -70.0 then
                    camPitch = -70.0
                elseif camPitch > 42.0 then
                    camPitch = 42.0
                end
                camPitch = (camPitch + 70.0) / 112.0

                local camHeading = GetGameplayCamRelativeHeading()
                if camHeading < -180.0 then
                    camHeading = -180.0
                elseif camHeading > 180.0 then
                    camHeading = 180.0
                end
                local cosCamHeading = math.cos(math.rad(camHeading))
                local sinCamHeading = math.sin(math.rad(camHeading))
                local normHeading = (camHeading + 180.0) / 360.0

                local coords = GetOffsetFromEntityInWorldCoords(ped,
                    (cosCamHeading * -0.2) - (sinCamHeading * (0.4 * normHeading + 0.3)),
                    (sinCamHeading * -0.2) + (cosCamHeading * (0.4 * normHeading + 0.3)),
                    0.6)
                local ray = StartShapeTestRay(coords.x, coords.y, coords.z - 0.2, coords.x, coords.y, coords.z + 0.2, 1, ped, 7)
                local _, blocked = GetShapeTestResult(ray)

                Citizen.InvokeNative(0xD5BB4025AE449A4E, ped, "Pitch", camPitch)
                Citizen.InvokeNative(0xD5BB4025AE449A4E, ped, "Heading", normHeading * -1.0 + 1.0)
                Citizen.InvokeNative(0xB0A6CFD2C69C1088, ped, "isBlocked", blocked)
                Citizen.InvokeNative(0xB0A6CFD2C69C1088, ped, "isFirstPerson", GetFollowPedCamViewMode() == 4)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)
