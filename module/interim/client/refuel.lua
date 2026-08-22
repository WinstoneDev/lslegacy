-- Remplissage citerne (pos4) + stations essence, via lib.progressBar (ox_lib).
-- NB : ShowTankPoint est exposée sur la table partagée Interim plutôt que sur un second RegisterClientEvent, car ce wrapper n'exécute que le premier handler enregistré pour un nom d'event donné — main.lua et vehicles.lua appellent Interim.ShowTankPoint directement.

local CFG = Config.Interim
Interim = Interim or {}

local tankBlip = nil

local function Notify(msg, t)
    TriggerEvent(CFG.NotifyEvent, 'Intérimaire', msg, 5000, t or 'info')
end

-- a.prop est optionnel : présent (jerrican station) -> attaché en main ;
-- absent (tanker pos4) -> anim seule, sans rien dans les mains.
local function DoProgressWithAnim(label, duration, a)
    local ped = PlayerPedId()
    return lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = a.dict, clip = a.clip },
        prop = a.prop and {
            model = a.prop,
            bone = GetEntityBoneIndexByName(ped, a.boneName),
            pos = vector3(a.offset.x, a.offset.y, a.offset.z),
            rot = vector3(a.rotation.x, a.rotation.y, a.rotation.z),
        } or nil,
    })
end

local function DoFillProgress(label, duration)
    return DoProgressWithAnim(label, duration or CFG.Anim.duration, CFG.Anim)
end

-- Marche jusqu'à l'entité remorque elle-même (exposée par vehicles.lua) plutôt qu'un point fixe : la remorque bouge avec le joueur, sa position doit être lue en temps réel.
local function WalkToTanker()
    local trailer = Interim.GetTrailerEntity and Interim.GetTrailerEntity()
    if not trailer or not DoesEntityExist(trailer) then return end

    local ped = PlayerPedId()
    local target = GetOffsetFromEntityInWorldCoords(trailer, 0.0, -4.5, 0.0) -- à VÉRIFIER/AJUSTER visuellement
    local heading = GetEntityHeading(trailer)

    if #(GetEntityCoords(ped) - target) > 0.3 then
        TaskGoStraightToCoord(ped, target.x, target.y, target.z, 1.0, 3000, heading, 0.15)
        local elapsed = 0
        while elapsed < 3000 and #(GetEntityCoords(ped) - target) > 0.3 do
            Wait(100)
            elapsed = elapsed + 100
        end
        ClearPedTasks(ped)
    end
    SetEntityHeading(ped, heading)
end

local function DoTankFillProgress(label, duration)
    WalkToTanker()
    return DoProgressWithAnim(label, duration, CFG.TankPoint.anim)
end

function Interim.ShowTankPoint(show)
    if show then
        if tankBlip then return end
        local c = CFG.TankPoint.coords
        tankBlip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(tankBlip, CFG.TankPoint.blip.sprite)
        SetBlipColour(tankBlip, CFG.TankPoint.blip.color)
        SetBlipScale(tankBlip, CFG.TankPoint.blip.scale)
        SetBlipAsShortRange(tankBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(CFG.TankPoint.blip.label)
        EndTextCommandSetBlipName(tankBlip)
        SetNewWaypoint(c.x, c.y)
    elseif tankBlip then
        RemoveBlip(tankBlip)
        tankBlip = nil
    end
end

-- Blips des stations essence, affichés dès que la citerne du camion contient de l'essence.
local stationBlips = {}

function Interim.ShowStationBlips(show)
    if show then
        if next(stationBlips) then return end
        for _, s in ipairs(CFG.Stations) do
            local b = AddBlipForCoord(s.coords.x, s.coords.y, s.coords.z)
            SetBlipSprite(b, 361)
            SetBlipColour(b, 3)
            SetBlipScale(b, 0.7)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(s.label)
            EndTextCommandSetBlipName(b)
            stationBlips[s.id] = b
        end
    else
        for _, b in pairs(stationBlips) do RemoveBlip(b) end
        stationBlips = {}
    end
end

-- Zone de remplissage de la citerne (pos4)
local tp = CFG.TankPoint.coords
exports.ox_target:addBoxZone({
    coords = vector3(tp.x, tp.y, tp.z),
    size = vector3(2.0, 2.0, 2.0),
    rotation = tp.w,
    debug = false,
    options = {
        {
            name = 'interim_fill_tank',
            icon = 'fa-solid fa-gas-pump',
            label = 'Remplir la citerne',
            distance = CFG.Actions.interactionRange,
            canInteract = function()
                return Interim.OnDuty and Interim.Attached and Interim.TrailerFuel < Interim.Capacity
            end,
            onSelect = function()
                local d = CFG.TankFillDuration
                local duration = math.random(d.min, d.max)
                if not DoTankFillProgress('Remplissage de la citerne...', duration) then return end
                LSLegacy.Events.SendToServer('interim:requestFillTank')
            end,
        },
    },
})

-- Stations essence : marker + prompt gérés par le système de zones serveur (canInteractFunc + dynamicFunc dans module/interim/server/main.lua), le serveur prévient le client quand il entre dans le rayon d'une zone.
LSLegacy.Events.Register('interim:playStationFillAnim', function(data)
    if not data then return end
    if DoFillProgress(('Remplissage de %s...'):format(data.label), data.duration) then
        LSLegacy.Events.SendToServer('interim:stationFillComplete', { stationId = data.stationId })
    end
end)
