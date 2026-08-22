local CFG = Config.Fourriere
local spawnedPed = nil

local function Notify(msg, t)
    TriggerEvent('notify', 'Fourrière', msg, t or 'info', 5000)
end

local function modelLabel(hash)
    local name = GetDisplayNameFromVehicleModel(hash + 0)
    if name and name ~= '' and name ~= 'CARNOTFOUND' then
        local lbl = GetLabelText(name)
        if lbl and lbl ~= '' and lbl ~= 'NULL' then return lbl end
        return name
    end
    return 'Véhicule'
end

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
            name = 'fourriere_retrieve',
            icon = 'fa-solid fa-car-burst',
            label = 'Récupérer un véhicule',
            distance = 2.5,
            onSelect = function() LSLegacy.Events.SendToServer('fourriere:requestList') end,
        },
    })
end

local function CreateBlip()
    if not CFG.Blip.enabled then return end
    local c = CFG.Ped.coords
    local b = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(b, CFG.Blip.sprite)
    SetBlipColour(b, CFG.Blip.color)
    SetBlipScale(b, CFG.Blip.scale)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(CFG.Blip.label)
    EndTextCommandSetBlipName(b)
end

LSLegacy.Events.Register('fourriere:list', function(rows)
    rows = rows or {}
    if #rows == 0 then
        Notify("Vous n'avez aucun véhicule en fourrière.", 'info')
        return
    end
    local options = {}
    for _, v in ipairs(rows) do
        local name = modelLabel(math.floor(tonumber(v.model) or 0))
        local fee = math.floor(tonumber(v.fee) or 0)
        local remaining = math.floor(tonumber(v.remaining_sec) or 0)
        local locked = remaining > 0
        options[#options + 1] = {
            title = ('%s — %s'):format(name, v.plate),
            description = locked
                and ('Motif : %s  |  Récupérable dans %d min'):format(v.reason or '—', math.ceil(remaining / 60))
                or  ('Motif : %s  |  Taxe : %d $'):format(v.reason or '—', fee),
            icon = locked and 'lock' or 'car',
            disabled = locked,
            onSelect = function()
                LSLegacy.Events.SendToServer('fourriere:retrieve', { plate = v.plate })
            end,
        }
    end
    lib.registerContext({ id = 'fourriere_list', title = 'Véhicules en fourrière', options = options })
    lib.showContext('fourriere_list')
end)

LSLegacy.Events.Register('fourriere:removeVehicle', function(data)
    local plate = data and data.plate
    if not plate then return end
    local function norm(p) return (tostring(p or ''):gsub('%s+', '')):upper() end
    local target = norm(plate)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and norm(GetVehicleNumberPlateText(veh)) == target then
            local ct = 0
            while not NetworkHasControlOfEntity(veh) and ct < 20 do
                NetworkRequestControlOfEntity(veh); Wait(10); ct = ct + 1
            end
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
            break
        end
    end
end)

-- Respawn géré côté serveur (LSLegacy.AP.SpawnPersistedRow) : aucun spawn client ici.
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
