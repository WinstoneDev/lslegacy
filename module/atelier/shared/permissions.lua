--  MODULE ATELIER — Permissions & résolution d'entreprise
--  (partagé client/serveur, même convention que module/mdt/shared/permissions.lua)
--
--  RÈGLE D'OR (sécurité) : côté serveur, toujours résoudre job/grade
--  depuis LSLegacy.GetPlayerFromId(src) — jamais depuis le client.

LSLegacy = LSLegacy or {}
LSLegacy.Atelier = LSLegacy.Atelier or {}

-- Trouve l'entreprise (config) rattachée à un job donné.
-- @param job string
-- @return string|nil companyId
-- @return table|nil company
function LSLegacy.Atelier.GetCompanyForJob(job)
    if not job or not Config.Atelier or not Config.Atelier.Companies then return nil end
    for id, company in pairs(Config.Atelier.Companies) do
        if company.job == job then return id, company end
    end
    return nil
end

-- Le job appartient-il à une entreprise de l'atelier ?
function LSLegacy.Atelier.IsAtelierJob(job)
    return LSLegacy.Atelier.GetCompanyForJob(job) ~= nil
end

-- Ensemble CUMULÉ des permissions pour un grade d'une entreprise.
-- @return table set { [permission]=true }
function LSLegacy.Atelier.GetPermissions(companyId, grade)
    local company = Config.Atelier.Companies[companyId]
    local perms = {}
    if not company or not company.grades then return perms end
    grade = tonumber(grade) or 0
    for g = 0, grade do
        local rank = company.grades[g]
        if rank and rank.grants then
            for _, p in ipairs(rank.grants) do
                perms[p] = true
            end
        end
    end
    return perms
end

-- Le grade possède-t-il une permission ? (manage_company accorde tout)
function LSLegacy.Atelier.HasPermission(companyId, grade, perm)
    if not perm then return true end
    local perms = LSLegacy.Atelier.GetPermissions(companyId, grade)
    if perms.manage_company then return true end
    return perms[perm] == true
end

-- Libellé d'un grade.
function LSLegacy.Atelier.GetGradeLabel(companyId, grade)
    local company = Config.Atelier.Companies[companyId]
    local rank = company and company.grades and company.grades[tonumber(grade) or 0]
    return rank and rank.label or 'Inconnu'
end
