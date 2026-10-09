Atelier = Atelier or {}
Atelier.OnDuty    = false
Atelier.CompanyId = nil
Atelier.Grade     = 0

local function Notify(msg, type)
    TriggerEvent('notify', 'Atelier', msg, type or 'info', 5000)
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

-- Prise de service depuis le tableau de bord du MDT (pas de zone physique au
-- QG : chaque entreprise a son propre département MDT, cf. config_mdt.lua).
-- On s'enregistre dans le registre du cœur MDT plutôt que de lui faire
-- connaître ce module — même pattern que police/sheriff.
LSLegacy.MDT = LSLegacy.MDT or {}
LSLegacy.MDT.DutyToggles = LSLegacy.MDT.DutyToggles or {}
for companyId, company in pairs(Config.Atelier.Companies) do
    LSLegacy.MDT.DutyToggles[company.job] = {
        toggle   = function() ToggleDuty(companyId) end,
        isOnDuty = function() return Atelier.OnDuty and Atelier.CompanyId == companyId end,
    }
end

-- Init

Citizen.CreateThread(function()
    Wait(2000)
    CreateBlips()
end)
