-- ═══════════════════════════════════════════════════════════════════
--  MODULE LTD — Client principal
--  Gestion : prise/fin de service, tenue, blips — DEUX MAGASINS
--  INDÉPENDANTS (Grove Street / Grapeseed), aucune donnée partagée.
--  Interactions : ox_target (zones) + ox_lib (menus)
-- ═══════════════════════════════════════════════════════════════════

LTD = LTD or {}
LTD.OnDuty    = false
LTD.StoreId   = nil   -- magasin sur lequel le joueur est en service
LTD.Grade     = 0
LTD.InUniform = false

local function Notify(msg, type)
    TriggerEvent(Config.LTD.NotifyEvent, 'LTD', msg, 5000, type or 'info')
end

-- ── Utilitaires ────────────────────────────────────────────────────

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

-- ── Blips ───────────────────────────────────────────────────────────

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

-- ── Prise de service (par magasin) ───────────────────────────────────

local function GoOnDuty(storeId)
    if LTD.OnDuty then Notify(Lang.LTD.already_on_duty, 'error') return end
    LTD.OnDuty  = true
    LTD.StoreId = storeId
    LTD.Grade   = GetGrade()

    LSLegacy.SendEventToServer('ltd:onDuty', { storeId = storeId })
    Notify(Lang.LTD.duty_on, 'success')
    TriggerEvent('ltd:dutyChanged', true)
end

local function GoOffDuty()
    if not LTD.OnDuty then Notify(Lang.LTD.already_off_duty, 'error') return end
    if LTD.InUniform then
        Notify('Changez de tenue au vestiaire avant de quitter le service.', 'error')
        return
    end
    LTD.OnDuty  = false
    LTD.StoreId = nil

    LSLegacy.SendEventToServer('ltd:offDuty')
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

-- ── Tenue ──────────────────────────────────────────────────────────

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
    if not LTD.OnDuty then Notify(Lang.LTD.not_employee, 'error') return end

    local options = {
        {
            title = 'Tenue civile',
            description = 'Restaurer la tenue personnelle',
            icon = 'fa-solid fa-shirt',
            onSelect = function()
                TriggerEvent('skinchanger:loadSkin', LSLegacy.PlayerData.skin)
                LTD.InUniform = false
                Notify('Tenue civile restaurée.', 'success')
            end,
        },
    }

    for _, outfit in ipairs(Config.LTD.Outfits) do
        local available = LTD.Grade >= outfit.grade
        options[#options + 1] = {
            title = outfit.label,
            description = available and ('Grade ' .. outfit.grade .. '+') or ('Grade ' .. outfit.grade .. '+ requis'),
            icon = 'fa-solid fa-shirt',
            disabled = not available,
            onSelect = function()
                ApplyOutfit(outfit)
                LTD.InUniform = true
                Notify('Tenue appliquée : ' .. outfit.label, 'success')
            end,
        }
    end

    lib.registerContext({ id = 'ltd_clothing', title = 'LTD — Vestiaire', options = options })
    lib.showContext('ltd_clothing')
end

-- ── Zones ox_target (une par magasin) ─────────────────────────────────

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

    exports.ox_target:addBoxZone({
        coords   = store.clothingCoords,
        size     = vector3(1.5, 1.5, 2.0),
        rotation = store.headquartersHeading,
        debug    = false,
        options  = {
            {
                name = 'ltd_clothing_' .. store.id,
                icon = 'fa-solid fa-shirt',
                label = 'Vestiaire',
                distance = 2.0,
                canInteract = function() return IsEmployee() end,
                onSelect = OpenClothingMenu,
            },
        },
    })
end

-- ── Init ─────────────────────────────────────────────────────────────

Citizen.CreateThread(function()
    Wait(2000)
    CreateBlips() -- magasins visibles pour tous (commerce public)
end)

-- Exporter l'état pour les autres sous-modules
function LTD.IsOnDuty() return LTD.OnDuty end
function LTD.GetStoreId() return LTD.StoreId end
function LTD.GetGrade() return LTD.Grade end
function LTD.GetStore(storeId) return GetStore(storeId) end
