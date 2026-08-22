-- Interim.* est l'état partagé lu par vehicles.lua et refuel.lua (canInteract des zones ox_target), mis à jour par interim:syncState.

local CFG = Config.Interim

Interim = Interim or {}
Interim.OnDuty      = false
Interim.Attached    = false
Interim.TrailerFuel = 0
Interim.Capacity    = CFG.Economy.trailerCapacity

local function Notify(msg, t)
    TriggerEvent('notify', 'Intérimaire', msg, t or 'info', 5000)
end

local spawnedPed = nil

local function SpawnPed()
    local c = CFG.Ped
    local hash = GetHashKey(c.model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then return end

    spawnedPed = CreatePed(4, hash, c.coords.x, c.coords.y, c.coords.z - 1.0, c.heading, false, true)
    SetEntityInvincible(spawnedPed, true)
    SetBlockingOfNonTemporaryEvents(spawnedPed, true)
    FreezeEntityPosition(spawnedPed, true)
    SetModelAsNoLongerNeeded(hash)

    exports.ox_target:addLocalEntity(spawnedPed, {
        {
            name = 'interim_start_duty',
            icon = 'fa-solid fa-right-to-bracket',
            label = 'Prendre le service (intérimaire)',
            distance = CFG.Actions.interactionRange,
            canInteract = function() return not Interim.OnDuty end,
            onSelect = function() LSLegacy.Events.SendToServer('interim:startDuty') end,
        },
        {
            name = 'interim_end_duty',
            icon = 'fa-solid fa-right-from-bracket',
            label = 'Terminer le service',
            distance = CFG.Actions.interactionRange,
            canInteract = function() return Interim.OnDuty end,
            onSelect = function() LSLegacy.Events.SendToServer('interim:endDuty') end,
        },
    })
end

local function CreateBlip()
    local c = CFG.Ped.coords
    local b = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(b, 318)
    SetBlipColour(b, 5)
    SetBlipScale(b, 0.8)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Intérim — Essence')
    EndTextCommandSetBlipName(b)
end

-- État envoyé par le serveur (source de vérité). NB : un seul LSLegacy.Events.Register par nom d'event est exécuté dans le resource — c'est ici que syncState est réellement traité, et on délègue l'affichage du blip citerne à Interim.ShowTankPoint (posé par refuel.lua) pour éviter un second enregistrement mort.
LSLegacy.Events.Register('interim:syncState', function(data)
    if not data then return end
    Interim.OnDuty      = data.onDuty and true or false
    Interim.Attached    = data.attached and true or false
    Interim.TrailerFuel = tonumber(data.trailerFuel) or 0
    Interim.Capacity    = tonumber(data.capacity) or Interim.Capacity
    if Interim.ShowTankPoint then Interim.ShowTankPoint(Interim.Attached) end
    if Interim.ShowStationBlips and not Interim.DevForceStationBlips then
        Interim.ShowStationBlips(Interim.TrailerFuel > 0)
    end
end)

local function DrawCenteredText(text, x, y, scale, font, r, g, b, a)
    SetTextFont(font or 4)
    SetTextScale(0.0, scale or 0.5)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    SetTextCentre(true)
    SetTextDropShadow()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- HUD permanent (coin bas-droit) affichant le niveau de la citerne tant que
-- le joueur est en service.
CreateThread(function()
    while true do
        local wait = 500
        if Interim.OnDuty then
            wait = 0
            DrawRect(0.90, 0.945, 0.17, 0.05, 0, 0, 0, 140)
            DrawCenteredText(('~b~Citerne~s~ : %d / %d L'):format(Interim.TrailerFuel, Interim.Capacity),
                0.90, 0.928, 0.35, 4, 255, 255, 255, 220)
        end
        Wait(wait)
    end
end)

CreateThread(function()
    Wait(1000)
    SpawnPed()
    CreateBlip()
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and spawnedPed and DoesEntityExist(spawnedPed) then
        DeleteEntity(spawnedPed)
    end
end)
