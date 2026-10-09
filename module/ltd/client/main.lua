-- Prise/fin de service, tenue, blips — deux magasins indépendants (Grove Street / Grapeseed), aucune donnée partagée.

LTD = LTD or {}
LTD.OnDuty    = false
LTD.StoreId   = nil   -- magasin sur lequel le joueur est en service
LTD.Grade     = 0

local function Notify(msg, type)
    TriggerEvent('notify', 'LTD', msg, type or 'info', 5000)
end

local function IsEmployee()
    return LSLegacy.PlayerData.job == Config.LTD.Job
end

local function GetGrade()
    return tonumber(LSLegacy.PlayerData.job_grade) or 0
end

local function GetStore(storeId)
    for _, s in ipairs(Config.LTD.Stores) do
        if s.id == storeId then return s end
    end
    return nil
end

local function CreateBlips()
    for _, s in ipairs(Config.LTD.Stores) do
        local blip = AddBlipForCoord(s.headquarters.x, s.headquarters.y, s.headquarters.z)
        SetBlipSprite(blip, s.blipSprite)
        SetBlipColour(blip, s.blipColor)
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(s.label)
        EndTextCommandSetBlipName(blip)
    end
end

local function GoOnDuty(storeId)
    if LTD.OnDuty then Notify(Lang.LTD.already_on_duty, 'error') return end
    LTD.OnDuty  = true
    LTD.StoreId = storeId
    LTD.Grade   = GetGrade()

    LSLegacy.Events.SendToServer('ltd:onDuty', { storeId = storeId })
    Notify(Lang.LTD.duty_on, 'success')
    TriggerEvent('ltd:dutyChanged', true)
end

local function GoOffDuty()
    if not LTD.OnDuty then Notify(Lang.LTD.already_off_duty, 'error') return end
    LTD.OnDuty  = false
    LTD.StoreId = nil

    LSLegacy.Events.SendToServer('ltd:offDuty')
    Notify(Lang.LTD.duty_off, 'info')
    TriggerEvent('ltd:dutyChanged', false)
end

local function ToggleDuty(storeId)
    if not IsEmployee() then Notify(Lang.LTD.not_employee, 'error') return end
    if LTD.OnDuty then
        GoOffDuty()
    else
        GoOnDuty(storeId)
    end
end

for _, store in ipairs(Config.LTD.Stores) do
    exports.ox_target:addBoxZone({
        coords   = store.headquarters,
        size     = vector3(2.0, 2.0, 2.0),
        rotation = store.headquartersHeading,
        debug    = false,
        options  = {
            {
                name = 'ltd_duty_' .. store.id,
                icon = 'fa-solid fa-right-from-bracket',
                label = 'Prise / Fin de service — ' .. store.label,
                distance = 2.5,
                canInteract = function() return IsEmployee() end,
                onSelect = function() ToggleDuty(store.id) end,
            },
        },
    })
end

Citizen.CreateThread(function()
    Wait(2000)
    CreateBlips() -- magasins visibles pour tous (commerce public)
end)

function LTD.IsOnDuty() return LTD.OnDuty end
function LTD.GetStoreId() return LTD.StoreId end
function LTD.GetGrade() return LTD.Grade end
function LTD.GetStore(storeId) return GetStore(storeId) end
