--  MODULE SAMU — Client principal
--  Gestion : prise/fin de service, tenue, garage, blips
--  Interactions : ox_target (zones + ciblage joueur) + ox_lib (menus)

SAMU = SAMU or {}
SAMU.OnDuty    = false
SAMU.Grade     = 0
SAMU.InUniform = false

local function Notify(msg, type)
    TriggerEvent('notify', 'SAMU', msg, type or 'info', 5000)
end

-- Utilitaires

local function IsSamu()
    return LSLegacy.PlayerData.job == Config.SAMU.Job
end

local function GetGrade()
    return tonumber(LSLegacy.PlayerData.job_grade) or 0
end

local function GetFullName()
    local ci = LSLegacy.PlayerData.characterInfos
    if ci then
        return (ci.Prenom or '') .. ' ' .. (ci.NDF or '')
    end
    return 'Secouriste'
end

-- Blips

local function CreateBlips()
    for _, b in ipairs(Config.SAMU.Blips or {}) do
        local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
        SetBlipSprite(blip, b.sprite)
        SetBlipColour(blip, b.color)
        SetBlipScale(blip, b.scale)
        SetBlipAsShortRange(blip, b.short)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(b.label)
        EndTextCommandSetBlipName(blip)
    end
end

-- Blip garage : rouge quand le joueur est en véhicule (à ranger), vert à pied
local garageBlip = nil

local function UpdateGarageBlipColour()
    if not garageBlip then return end
    local inVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
    SetBlipColour(garageBlip, inVehicle and 1 or 2)
end

local function CreateGarageBlip()
    if garageBlip then return end
    local c = Config.SAMU.GarageBlipCoords
    garageBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(garageBlip, 68)
    SetBlipScale(garageBlip, 0.9)
    SetBlipAsShortRange(garageBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Garage')
    EndTextCommandSetBlipName(garageBlip)
    UpdateGarageBlipColour()

    Citizen.CreateThread(function()
        while garageBlip do
            UpdateGarageBlipColour()
            Wait(1000)
        end
    end)
end

-- Prise de service

local function GoOnDuty()
    if SAMU.OnDuty then Notify(Lang.SAMU.already_on_duty, 'error') return end
    SAMU.OnDuty = true
    SAMU.Grade  = GetGrade()

    LSLegacy.Events.SendToServer('samu:onDuty')
    Notify(Lang.SAMU.duty_on, 'success')
    TriggerEvent('samu:dutyChanged', true)
end

local function GoOffDuty()
    if not SAMU.OnDuty then Notify(Lang.SAMU.already_off_duty, 'error') return end
    -- Pas de blocage sur la tenue : quitter le service en tenue est permis.
    -- `SAMU.InUniform` reste suivi (le vestiaire s'en sert pour savoir quoi
    -- proposer), il ne conditionne simplement plus la fin de service.
    SAMU.OnDuty = false

    LSLegacy.Events.SendToServer('samu:offDuty')
    Notify(Lang.SAMU.duty_off, 'info')
    TriggerEvent('samu:dutyChanged', false)
end

local function ToggleDuty()
    if not IsSamu() then Notify(Lang.SAMU.not_samu, 'error') return end
    if SAMU.OnDuty then
        GoOffDuty()
    else
        GoOnDuty()
    end
end

-- Tenue

local function ApplyOutfit(outfit)
    local ped    = PlayerPedId()
    local isMale = GetEntityModel(ped) == GetHashKey('mp_m_freemode_01')
    local t      = isMale and outfit.male or outfit.female
    SetPedComponentVariation(ped, 3, t.torso_1,  t.torso_2,  2)
    SetPedComponentVariation(ped, 4, t.pants_1,  t.pants_2,  2)
    SetPedComponentVariation(ped, 6, t.shoes_1,  t.shoes_2,  2)
    SetPedComponentVariation(ped, 8, t.tshirt_1, t.tshirt_2, 2)
    SetPedPropIndex(ped, 0, t.helmet_1, t.helmet_2, false)
end

local function OpenClothingMenu()
    if not SAMU.OnDuty then Notify(Lang.SAMU.not_samu, 'error') return end

    local options = {
        {
            title = 'Tenue civile',
            description = 'Restaurer la tenue personnelle',
            icon = 'fa-solid fa-shirt',
            onSelect = function()
                TriggerEvent('skinchanger:loadSkin', LSLegacy.PlayerData.skin)
                SAMU.InUniform = false
                Notify('Tenue civile restaurée.', 'success')
            end,
        },
    }

    for _, outfit in ipairs(Config.SAMU.Outfits) do
        local available = SAMU.Grade >= outfit.grade
        options[#options + 1] = {
            title = outfit.label,
            description = available and ('Grade ' .. outfit.grade .. '+') or ('Grade ' .. outfit.grade .. '+ requis'),
            icon = 'fa-solid fa-kit-medical',
            disabled = not available,
            onSelect = function()
                ApplyOutfit(outfit)
                SAMU.InUniform = true
                Notify('Tenue appliquée : ' .. outfit.label, 'success')
            end,
        }
    end

    lib.registerContext({ id = 'samu_clothing', title = 'SAMU — Vestiaire', options = options })
    lib.showContext('samu_clothing')
end

-- Garage

local function OpenGarageMenu()
    if not SAMU.OnDuty then Notify(Lang.SAMU.not_samu, 'error') return end

    local options = {}
    for category, vehicles in pairs(Config.SAMU.Vehicles) do
        for _, veh in ipairs(vehicles) do
            local available = SAMU.Grade >= veh.grade
            options[#options + 1] = {
                title = veh.label,
                description = available and string.upper(veh.model) or ('Grade ' .. veh.grade .. '+ requis'),
                icon = 'fa-solid fa-truck-medical',
                disabled = not available,
                onSelect = function()
                    LSLegacy.Events.SendToServer('samu:spawnVehicle', {
                        model    = veh.model,
                        category = category,
                        grade    = veh.grade,
                    })
                    Notify(Lang.SAMU.vehicle_spawned, 'success')
                end,
            }
        end
    end

    lib.registerContext({ id = 'samu_garage', title = 'SAMU — Garage', options = options })
    lib.showContext('samu_garage')
end

local function StoreVehicle()
    if not SAMU.OnDuty then Notify(Lang.SAMU.not_samu, 'error') return end
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        Notify('Vous devez être dans le véhicule à ranger.', 'error')
        return
    end
    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        Notify('Vous devez être au volant pour ranger le véhicule.', 'error')
        return
    end
    local model = GetEntityModel(veh)
    local isAmbulance = false
    for _, entry in ipairs(Config.SAMU.Vehicles.ambulance) do
        if model == GetHashKey(entry.model) then
            isAmbulance = true
            break
        end
    end
    if not isAmbulance then
        Notify('Seules les ambulances peuvent être rangées ici.', 'error')
        return
    end
    TaskLeaveVehicle(ped, veh, 0)
    Wait(1500)
    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
    Notify('Véhicule rangé.', 'success')
end

-- Réassort trousse de soins

local function RequestRestock()
    if not SAMU.OnDuty then Notify(Lang.SAMU.not_samu, 'error') return end
    LSLegacy.Events.SendToServer('samu:restock')
end

-- Zones ox_target (Centre Médical)
-- Prise/fin de service désormais uniquement via le dashboard MDT
-- (mdtmed:toggleDuty → SAMU.ToggleDuty()), pas de zone physique dédiée.

exports.ox_target:addBoxZone({
    coords   = Config.SAMU.ClothingCoords,
    size     = vector3(3.0, 3.0, 3.0),
    rotation = Config.SAMU.ClothingHeading,
    debug    = false,
    drawSprite = true,
    options  = {
        {
            name = 'samu_clothing',
            icon = 'fa-solid fa-shirt',
            label = 'Vestiaire',
            distance = 2.0,
            canInteract = function() return IsSamu() end,
            onSelect = OpenClothingMenu,
        },
    },
})

exports.ox_target:addBoxZone({
    coords   = Config.SAMU.GarageCoords,
    size     = vector3(3.0, 3.0, 3.0),
    rotation = Config.SAMU.GarageHeading,
    debug    = false,
    drawSprite = true,
    options  = {
        {
            name = 'samu_garage',
            icon = 'fa-solid fa-truck-medical',
            label = 'Garage',
            distance = 2.0,
            canInteract = function() return IsSamu() and not IsPedInAnyVehicle(PlayerPedId(), false) end,
            onSelect = OpenGarageMenu,
        },
        {
            name = 'samu_garage_store',
            icon = 'fa-solid fa-warehouse',
            label = 'Ranger le véhicule',
            distance = 3.0,
            canInteract = function() return IsSamu() and IsPedInAnyVehicle(PlayerPedId(), false) end,
            onSelect = StoreVehicle,
        },
    },
})

exports.ox_target:addBoxZone({
    coords   = Config.SAMU.RestockCoords,
    size     = vector3(3.0, 3.0, 3.0),
    rotation = Config.SAMU.RestockHeading,
    debug    = false,
    drawSprite = true,
    options  = {
        {
            name = 'samu_restock',
            icon = 'fa-solid fa-box-medical',
            label = 'Réassort trousse de soins',
            distance = 2.0,
            canInteract = function() return IsSamu() end,
            onSelect = RequestRestock,
        },
    },
})

-- Events serveur → client

LSLegacy.Events.Register('samu:spawnVehicleClient', function(data)
    if not data or not data.model then return end
    local coords  = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    local hash    = GetHashKey(data.model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do
        Wait(100)
        t = t + 1
    end
    if not HasModelLoaded(hash) then
        Notify('Modèle introuvable : ' .. data.model, 'error')
        return
    end
    local spawnX = coords.x + math.sin(math.rad(-heading)) * 5.0
    local spawnY = coords.y + math.cos(math.rad(-heading)) * 5.0
    local veh = CreateVehicle(hash, spawnX, spawnY, coords.z, heading, true, false)
    SetVehicleNumberPlateText(veh, 'SAMU')
    SetPedIntoVehicle(PlayerPedId(), veh, -1)
    SetModelAsNoLongerNeeded(hash)
end)

-- Notification d'appel patient (détresse vitale) reçue du serveur
LSLegacy.Events.Register('samu:patientCallReceived', function(data)
    if not data or not data.coords then return end
    Notify(Lang.SAMU.patient_call_received, 'error')
    SetNewWaypoint(data.coords.x, data.coords.y)
end)

-- Init

-- Le serveur répond à `samu:requestDutyState` (et peut pousser l'état à tout
-- moment) : c'est lui qui fait autorité sur la prise de service, le flag
-- client n'en est qu'un cache — remis à false à chaque rechargement de script.
LSLegacy.Events.Register('samu:setDutyState', function(state)
    local onDuty = state == true
    if onDuty == SAMU.OnDuty then return end
    SAMU.OnDuty = onDuty
    if onDuty then SAMU.Grade = GetGrade() end
    TriggerEvent('samu:dutyChanged', onDuty)
end)

Citizen.CreateThread(function()
    -- Attendre que les données du personnage soient réellement chargées :
    -- un simple Wait(2000) laissait IsSamu() renvoyer false quand le
    -- chargement traînait, et le garage/l'état de service ne s'initialisaient
    -- alors jamais.
    local timeout = GetGameTimer() + 60000
    while not (LSLegacy.PlayerData and LSLegacy.PlayerData.job) and GetGameTimer() < timeout do
        Wait(500)
    end

    -- Blip de l'hôpital visible pour tous les joueurs (pas seulement le job SAMU)
    CreateBlips()
    if not IsSamu() then return end
    CreateGarageBlip()
    -- Récupérer l'état de service réel (cf. samu:setDutyState ci-dessus)
    LSLegacy.Events.SendToServer('samu:requestDutyState')
end)

-- Exporter l'état pour les autres sous-modules
function SAMU.IsOnDuty() return SAMU.OnDuty end
function SAMU.GetGrade() return SAMU.Grade end
function SAMU.GetName() return GetFullName() end

-- Bascule de service, exposée pour le bouton du dashboard du MDT médical
-- (client/mdt_medical.lua). On expose la fonction existante plutôt que d'en
-- réécrire une : elle porte déjà la vérification du métier, les
-- notifications et l'event `samu:dutyChanged` dont dépendent les autres
-- sous-modules.
function SAMU.ToggleDuty() ToggleDuty() end
