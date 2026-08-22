Atelier = Atelier or {}
Atelier.OnDuty    = false
Atelier.CompanyId = nil
Atelier.Grade     = 0
Atelier.InUniform = false

local function Notify(msg, type)
    TriggerEvent(Config.Atelier.NotifyEvent, 'Atelier', msg, 5000, type or 'info')
end

-- Utilitaires

-- Entreprise du joueur d'après son job local (purement pour l'affichage
-- des menus : le serveur revalide systématiquement job/grade/entreprise).
local function GetLocalCompany()
    local job = LSLegacy.PlayerData and LSLegacy.PlayerData.job
    if not job then return nil end
    for id, company in pairs(Config.Atelier.Companies) do
        if company.job == job then return id, company end
    end
    return nil
end

local function IsEmployeeOf(companyId)
    local id = GetLocalCompany()
    return id == companyId
end

local function GetGrade()
    return tonumber(LSLegacy.PlayerData.job_grade) or 0
end

function Atelier.IsOnDuty() return Atelier.OnDuty end
function Atelier.GetCompanyId() return Atelier.CompanyId end
function Atelier.GetGrade() return Atelier.Grade end

-- Blips (visibles de tous, publics)

local function CreateBlips()
    for _, company in pairs(Config.Atelier.Companies) do
        for _, b in ipairs(company.blips or {}) do
            local blip = AddBlipForCoord(company.headquarters.x, company.headquarters.y, company.headquarters.z)
            SetBlipSprite(blip, b.sprite)
            SetBlipColour(blip, b.color)
            SetBlipScale(blip, b.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(b.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end

-- Prise de service

local pendingDutyToggle = false

local function ToggleDuty(companyId)
    if not IsEmployeeOf(companyId) then Notify("Vous ne faites pas partie de cette entreprise.", 'error') return end
    if pendingDutyToggle then return end
    pendingDutyToggle = true

    if Atelier.OnDuty then
        LSLegacy.Events.SendToServer('atelier:offDuty')
    else
        LSLegacy.Events.SendToServer('atelier:onDuty')
    end
end

-- Le flag local ne bascule QU'À la confirmation serveur, pour éviter une désynchronisation en cas de refus.
LSLegacy.Events.Register('atelier:dutyResult', function(data)
    pendingDutyToggle = false
    if not data or not data.success then return end

    Atelier.OnDuty = data.onDuty
    if data.onDuty then
        Atelier.CompanyId = data.companyId
        Atelier.Grade     = data.grade
        Notify('Prise de service enregistrée.', 'success')
    else
        Notify('Fin de service enregistrée.', 'info')
        Atelier.CompanyId = nil
    end
end)

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

local function OpenClothingMenu(companyId, company)
    if not Atelier.OnDuty or Atelier.CompanyId ~= companyId then
        Notify("Vous devez être en service pour accéder au vestiaire.", 'error')
        return
    end

    local options = {
        {
            title = 'Tenue civile',
            description = 'Restaurer la tenue personnelle',
            icon = 'fa-solid fa-shirt',
            onSelect = function()
                TriggerEvent('skinchanger:loadSkin', LSLegacy.PlayerData.skin)
                Atelier.InUniform = false
                Notify('Tenue civile restaurée.', 'success')
            end,
        },
    }

    for _, outfit in ipairs(company.outfits) do
        local available = Atelier.Grade >= outfit.grade
        options[#options + 1] = {
            title = outfit.label,
            description = available and ('Grade ' .. outfit.grade .. '+') or ('Grade ' .. outfit.grade .. '+ requis'),
            icon = 'fa-solid fa-shirt',
            disabled = not available,
            onSelect = function()
                ApplyOutfit(outfit)
                Atelier.InUniform = true
                Notify('Tenue appliquée : ' .. outfit.label, 'success')
            end,
        }
    end

    lib.registerContext({ id = 'atelier_clothing_' .. companyId, title = company.label .. ' — Vestiaire', options = options })
    lib.showContext('atelier_clothing_' .. companyId)
end

-- Garage (dépanneuses)

local function OpenGarageMenu(companyId, company)
    if not Atelier.OnDuty or Atelier.CompanyId ~= companyId then
        Notify("Vous devez être en service pour accéder au garage.", 'error')
        return
    end

    local options = {}
    for category, vehicles in pairs(company.vehicles or {}) do
        for _, veh in ipairs(vehicles) do
            local available = Atelier.Grade >= veh.grade
            options[#options + 1] = {
                title = veh.label,
                description = available and string.upper(veh.model) or ('Grade ' .. veh.grade .. '+ requis'),
                icon = 'fa-solid fa-truck-pickup',
                disabled = not available,
                onSelect = function()
                    LSLegacy.Events.SendToServer('atelier:spawnVehicle', { model = veh.model, category = category, grade = veh.grade })
                end,
            }
        end
    end

    lib.registerContext({ id = 'atelier_garage_' .. companyId, title = company.label .. ' — Garage', options = options })
    lib.showContext('atelier_garage_' .. companyId)
end

LSLegacy.Events.Register('atelier:spawnVehicleClient', function(data)
    if not data or not data.model then return end
    local coords  = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    local hash    = GetHashKey(data.model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(100) t = t + 1 end
    if not HasModelLoaded(hash) then
        Notify('Modèle introuvable : ' .. data.model, 'error')
        return
    end
    local spawnX = coords.x + math.sin(math.rad(-heading)) * 5.0
    local spawnY = coords.y + math.cos(math.rad(-heading)) * 5.0
    local veh = CreateVehicle(hash, spawnX, spawnY, coords.z, heading, true, false)
    SetVehicleNumberPlateText(veh, 'ATELIER')
    SetPedIntoVehicle(PlayerPedId(), veh, -1)
    SetModelAsNoLongerNeeded(hash)
    Notify('Véhicule sorti.', 'success')
end)

-- Zones ox_target — une par entreprise

for companyId, company in pairs(Config.Atelier.Companies) do
    exports.ox_target:addBoxZone({
        coords   = company.headquarters,
        size     = vector3(2.0, 2.0, 2.0),
        rotation = company.headquartersHeading,
        debug    = false,
        options  = {
            {
                name = 'atelier_duty_' .. companyId,
                icon = 'fa-solid fa-right-from-bracket',
                label = 'Prise / Fin de service',
                distance = 2.5,
                canInteract = function() return IsEmployeeOf(companyId) end,
                onSelect = function() ToggleDuty(companyId) end,
            },
        },
    })

    exports.ox_target:addBoxZone({
        coords   = company.clothingCoords,
        size     = vector3(1.5, 1.5, 2.0),
        rotation = company.headquartersHeading,
        debug    = false,
        options  = {
            {
                name = 'atelier_clothing_' .. companyId,
                icon = 'fa-solid fa-shirt',
                label = 'Vestiaire',
                distance = 2.0,
                canInteract = function() return IsEmployeeOf(companyId) end,
                onSelect = function() OpenClothingMenu(companyId, company) end,
            },
        },
    })

    exports.ox_target:addBoxZone({
        coords   = company.garageCoords,
        size     = vector3(2.0, 2.0, 2.0),
        rotation = company.headquartersHeading,
        debug    = false,
        options  = {
            {
                name = 'atelier_garage_' .. companyId,
                icon = 'fa-solid fa-truck-pickup',
                label = 'Garage',
                distance = 2.0,
                canInteract = function() return IsEmployeeOf(companyId) end,
                onSelect = function() OpenGarageMenu(companyId, company) end,
            },
        },
    })
end

-- Init

Citizen.CreateThread(function()
    Wait(2000)
    CreateBlips()
end)
