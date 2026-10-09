-- ═══════════════════════════════════════════════════════════════════
--  LOCATION DE VÉHICULES — Client principal
--  PNJ agence + catalogue (ox_lib)
-- ═══════════════════════════════════════════════════════════════════

Location = Location or {}

local spawnedPeds = {}

local function Notify(msg, t)
    TriggerEvent('notify', 'Location de véhicules', msg, t or 'info', 5000)
end
Location.Notify = Notify

local function SpawnPed(cfg, options)
    local hash = GetHashKey(cfg.model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then return end

    local ped = CreatePed(4, hash, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.heading, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(hash)

    spawnedPeds[#spawnedPeds + 1] = ped
    exports.ox_target:addLocalEntity(ped, options)
    return ped
end

local function OpenCatalog()
    local options = {}
    for _, v in ipairs(Config.Location.Vehicles) do
        options[#options + 1] = {
            title = v.label,
            description = ('%d $ / heure'):format(v.pricePerHour),
            icon = 'fa-solid fa-car',
            onSelect = function() Location.AskDuration(v) end,
        }
    end
    lib.registerContext({ id = 'location_catalog', title = 'Location de véhicules', options = options })
    lib.showContext('location_catalog')
end

function Location.AskDuration(entry)
    local input = lib.inputDialog(entry.label, {
        {
            type = 'number', label = "Nombre d'heures",
            description = ('%d $ / heure — max %d h'):format(entry.pricePerHour, Config.Location.MaxHours),
            required = true, min = 1, max = Config.Location.MaxHours, default = 1,
        },
    })
    if not input or not input[1] then return end
    local hours = math.floor(tonumber(input[1]) or 0)
    if hours < 1 then return end
    LSLegacy.Events.SendToServer('location:requestRent', { model = entry.model, hours = hours })
end

Citizen.CreateThread(function()
    Wait(1000)
    local ped  = Config.Location.Agency.Ped
    local blip = Config.Location.Agency.Blip

    local b = AddBlipForCoord(blip.coords.x, blip.coords.y, blip.coords.z)
    SetBlipSprite(b, blip.sprite)
    SetBlipColour(b, blip.color)
    SetBlipScale(b, blip.scale)
    SetBlipAsShortRange(b, blip.short)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(blip.label)
    EndTextCommandSetBlipName(b)

    SpawnPed(ped, {
        {
            name = 'location_browse',
            icon = 'fa-solid fa-car-side',
            label = 'Louer un véhicule',
            distance = 2.5,
            onSelect = function() OpenCatalog() end,
        },
    })
end)

AddEventHandler('onResourceStop', function(res)
    if GetCurrentResourceName() ~= res then return end
    for _, ped in ipairs(spawnedPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)
