-- Roulade de combat — source: JellyJamm/disablecombatroll
-- https://github.com/JellyJamm/disablecombatroll
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsPedArmed(GetPlayerPed(-1), 4 | 2) and IsControlPressed(0, 25) then
            DisableControlAction(0, 22, true)
        end
    end
end)

-- Anti-strafe — source: TGIANN/tgiann-anti-strafe
-- https://github.com/TGIANN/tgiann-anti-strafe
local pressAmount = 0
local keys = { 30, 31 }

local function breakStrafe(key, time)
    CreateThread(function()
        local finishTime = GetGameTimer() + time
        while finishTime > GetGameTimer() do
            SetControlNormal(0, key, 1.0)
            Wait(0)
        end
    end)
end

CreateThread(function()
    while true do
        Wait(1000)
        if pressAmount > 4 then
            local key = IsControlJustPressed(0, 30) and 30 or 31
            breakStrafe(key, 250)
        end
        pressAmount = 0
    end
end)

CreateThread(function()
    while true do
        local time = 1000
        local playerPed = PlayerPedId()
        if IsPlayerFreeAiming(PlayerId()) and not IsPedInAnyVehicle(playerPed) then
            time = 0
            for i = 1, #keys do
                if IsControlJustPressed(0, keys[i]) then
                    pressAmount = pressAmount + 1
                end
            end
        end
        Wait(time)
    end
end)

-- Coups de crosse — désactivés à courte distance d'un joueur en visant
local CLOSE_RANGE = 3.0

local function IsNearAnyPlayer(ped, radius)
    local coords = GetEntityCoords(ped)
    for _, playerId in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= ped and DoesEntityExist(targetPed) and not IsEntityDead(targetPed) then
            if #(coords - GetEntityCoords(targetPed)) <= radius then
                return true
            end
        end
    end
    return false
end

CreateThread(function()
    while true do
        local wait = 500
        local ped = PlayerPedId()

        if IsPedArmed(ped, 6) and IsPlayerFreeAiming(PlayerId()) and IsNearAnyPlayer(ped, CLOSE_RANGE) then
            wait = 0
            DisableControlAction(1, 140, true) -- Coup de crosse
            DisableControlAction(1, 141, true) -- Coup latéral gauche
            DisableControlAction(1, 142, true) -- Coup latéral droit
        end

        Wait(wait)
    end
end)
