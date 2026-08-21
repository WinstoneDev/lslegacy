-- ════════════════════════════════════════════════════════════════════
--  POMPE À ESSENCE PUBLIQUE — Client
--  Blips rouges (grand public) sur les mêmes positions que les blips bleus
--  du job intérimaire (Config.Interim.Stations) — chacun voit la couleur
--  correspondant à son usage : bleu = ravitaillement pompiste, rouge =
--  achat d'essence pour son véhicule.
--
--  Flux 100% event-driven (pas de callback synchrone, cassé dans ce
--  projet) : StartFuelPurchase envoie pompe:requestFill et attend
--  pompe:fillAuthorized (serveur = source de vérité, vérifie argent + stock
--  station AVANT toute délivrance) avant de démarrer la progress bar.
-- ════════════════════════════════════════════════════════════════════

local CFG = Config.Pompe

local function Notify(msg, t)
    TriggerEvent(CFG.NotifyEvent, 'Station essence', msg, 5000, t or 'info')
end

local function DrawCenteredText(text, x, y, scale, font, r, g, b, a)
    SetTextFont(font or 4)
    SetTextScale(0.0, scale or 0.4)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    SetTextCentre(true)
    SetTextDropShadow()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

CreateThread(function()
    Wait(1000)
    for _, s in ipairs(Config.Interim.Stations) do
        local b = AddBlipForCoord(s.coords.x, s.coords.y, s.coords.z)
        SetBlipSprite(b, 361)
        SetBlipColour(b, 1) -- rouge : station essence pour le grand public
        SetBlipScale(b, 0.7)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(s.label)
        EndTextCommandSetBlipName(b)
    end
end)

-- Pattern repris d'ox_fuel (overextended/ox_fuel, client/init.lua) : on
-- retient en priorité le DERNIER véhicule dans lequel le joueur est monté
-- (pas d'ambiguïté avec un véhicule garé à proximité). En secours (lastVehicle
-- jamais capturé : rejoint en cours de session, resource redémarrée après
-- être descendu, etc.), on retombe sur un scan du véhicule le plus proche.
local lastVehicle = nil

lib.onCache('seat', function(seat)
    if cache.vehicle then
        lastVehicle = cache.vehicle
    end
end)

local function GetTargetVehicle()
    local pedCoords = GetEntityCoords(cache.ped)

    if lastVehicle and DoesEntityExist(lastVehicle)
        and #(GetEntityCoords(lastVehicle) - pedCoords) <= CFG.VehicleMaxDistance
    then
        return lastVehicle
    end

    local closest, closestDist = nil, CFG.VehicleMaxDistance
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) then
            local d = #(GetEntityCoords(veh) - pedCoords)
            if d < closestDist then
                closest, closestDist = veh, d
            end
        end
    end
    return closest
end

local function FindNearestStation(coords)
    local closest, closestDist = nil, CFG.StationSearchRadius
    for _, s in ipairs(Config.Interim.Stations) do
        local d = #(vector3(s.coords.x, s.coords.y, s.coords.z) - coords)
        if d < closestDist then
            closest, closestDist = s, d
        end
    end
    return closest
end

-- ── Séquence de plein (une fois le serveur ayant autorisé une quantité) ──
local function RunFillSequence(vehicle, currentLiters, capacity, station, maxDeliverable)
    local duration = math.max(1000, math.floor(CFG.FillDuration * (maxDeliverable / capacity)))

    -- Affichage temps réel (initial / ajouté / prix) pendant que
    -- lib.progressBar bloque le thread principal — thread parallèle qui se
    -- cale sur le même minutage, arrêté dès que la progress bar se termine
    -- (complétée ou annulée via [X]).
    local filling = true
    local litersAdded = 0.0

    CreateThread(function()
        local startTime = GetGameTimer()
        while filling do
            local progress = math.min(1.0, (GetGameTimer() - startTime) / duration)
            litersAdded = maxDeliverable * progress
            SetVehicleFuelLevel(vehicle, ((currentLiters + litersAdded) / capacity) * 100.0)

            local price = litersAdded * CFG.PricePerLiter
            -- Positionné bien au-dessus de la zone de la progress bar
            -- d'ox_lib (bas d'écran) pour ne jamais se chevaucher.
            DrawRect(0.5, 0.74, 0.26, 0.085, 0, 0, 0, 160)
            DrawCenteredText(('Réservoir initial : ~b~%d L~s~'):format(currentLiters), 0.5, 0.71, 0.35)
            DrawCenteredText(('Ajouté : ~g~+%d L~s~'):format(math.floor(litersAdded)), 0.5, 0.733, 0.35)
            DrawCenteredText(('Prix : ~y~%.2f $~s~'):format(price), 0.5, 0.756, 0.35)

            if progress >= 1.0 then break end
            Wait(0)
        end
    end)

    local a = CFG.Anim
    lib.progressBar({
        duration = duration,
        label = 'Ravitaillement en cours...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = a.dict, clip = a.clip },
        prop = {
            model = a.prop,
            bone = a.bone,
            pos = vector3(a.offset.x, a.offset.y, a.offset.z),
            rot = vector3(a.rotation.x, a.rotation.y, a.rotation.z),
            rotOrder = a.rotOrder,
        },
    })

    filling = false
    Wait(50) -- laisse le thread d'affichage lire litersAdded une dernière fois avant de couper

    local finalLiters = math.floor(litersAdded)
    if finalLiters <= 0 then return end

    SetVehicleFuelLevel(vehicle, ((currentLiters + finalLiters) / capacity) * 100.0)

    LSLegacy.SendEventToServer('pompe:payFuel', {
        stationId = station.id,
        liters = finalLiters,
    })
end

-- ── Demande de plein en cours (une seule à la fois) ──────────────────────
local pendingFill = nil

LSLegacy.RegisterClientEvent('pompe:fillAuthorized', function(data)
    if not pendingFill or not data or pendingFill.station.id ~= data.stationId then return end
    local req = pendingFill
    pendingFill = nil
    RunFillSequence(req.vehicle, req.currentLiters, req.capacity, req.station, tonumber(data.maxDeliverable) or 0)
end)

local function StartFuelPurchase(pumpEntity)
    local pumpCoords = GetEntityCoords(pumpEntity)

    local vehicle = GetTargetVehicle()
    if not vehicle then
        return Notify('Aucun véhicule à proximité.', 'error')
    end
    if not DoesVehicleUseFuel(vehicle) then
        return Notify("Ce véhicule n'a pas de réservoir à essence.", 'error')
    end

    local station = FindNearestStation(pumpCoords)
    if not station then
        return Notify('Aucune station essence à proximité.', 'error')
    end

    local class = GetVehicleClass(vehicle)
    local capacity = Config.FuelConsumption.TankCapacityByClass[class] or 60
    if capacity <= 0 then
        return Notify("Ce véhicule n'a pas de réservoir à essence.", 'error')
    end

    local currentLiters = math.floor((GetVehicleFuelLevel(vehicle) / 100.0) * capacity)
    if currentLiters >= capacity then
        return Notify('Réservoir déjà plein.', 'error')
    end

    pendingFill = { vehicle = vehicle, currentLiters = currentLiters, capacity = capacity, station = station }
    LSLegacy.SendEventToServer('pompe:requestFill', {
        stationId = station.id,
        currentLiters = currentLiters,
        capacity = capacity,
    })
end

-- Hash calculé explicitement via la native GetHashKey plutôt que de laisser
-- ox_target convertir les strings lui-même (sa fonction joaat() interne peut
-- diverger de la native sur certains noms) — évite un mismatch silencieux.
local pumpModelHashes = {}
for i, modelName in ipairs(CFG.PumpModels) do
    pumpModelHashes[i] = GetHashKey(modelName)
end

exports.ox_target:addModel(pumpModelHashes, {
    {
        name = 'pompe_fill_vehicle',
        icon = 'fa-solid fa-gas-pump',
        label = 'Faire le plein',
        distance = CFG.Actions.interactionRange,
        canInteract = function()
            if cache.vehicle or (lib.progressActive and lib.progressActive()) then return false end
            return GetTargetVehicle() ~= nil
        end,
        onSelect = function(data)
            StartFuelPurchase(data.entity)
        end,
    },
})
