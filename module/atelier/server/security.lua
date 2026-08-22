-- Toute la logique métier s'appuie exclusivement sur ces fonctions : jamais de job/grade/entreprise lu depuis le client.

LSLegacy.Atelier = LSLegacy.Atelier or {}

-- { [source] = { onDuty, companyId, grade, name } } — alimenté par server/main.lua
LSLegacy.Atelier.Agents = LSLegacy.Atelier.Agents or {}

function LSLegacy.Atelier.GetPlayer(src)
    return LSLegacy.Players.Get(src)
end

-- Renvoie (companyId, company) si le job du joueur appartient à l'atelier, sinon nil.
function LSLegacy.Atelier.GetCompany(src)
    local p = LSLegacy.Atelier.GetPlayer(src)
    if not p then return nil end
    return LSLegacy.Atelier.GetCompanyForJob(p.job)
end

function LSLegacy.Atelier.GetGrade(src)
    local p = LSLegacy.Atelier.GetPlayer(src)
    return p and (tonumber(p.job_grade) or 0) or 0
end

function LSLegacy.Atelier.GetCharacterId(src)
    local p = LSLegacy.Atelier.GetPlayer(src)
    return p and p["boutique-id"] or nil
end

function LSLegacy.Atelier.IsEmployee(src)
    return LSLegacy.Atelier.GetCompany(src) ~= nil
end

function LSLegacy.Atelier.IsOnDuty(src)
    local agent = LSLegacy.Atelier.Agents[src]
    return agent ~= nil and agent.onDuty == true
end

-- Vérifie que src a la permission demandée dans SON entreprise.
function LSLegacy.Atelier.HasPerm(src, perm)
    local companyId = LSLegacy.Atelier.GetCompany(src)
    if not companyId then return false end
    return LSLegacy.Atelier.HasPermission(companyId, LSLegacy.Atelier.GetGrade(src), perm)
end

-- Garde complète pour une action professionnelle : employé + en service + permission.
-- @return boolean ok
-- @return string|nil companyId
function LSLegacy.Atelier.CanAct(src, perm)
    local companyId = LSLegacy.Atelier.GetCompany(src)
    if not companyId then return false, nil end
    if not LSLegacy.Atelier.IsOnDuty(src) then return false, companyId end
    if perm and not LSLegacy.Atelier.HasPermission(companyId, LSLegacy.Atelier.GetGrade(src), perm) then
        return false, companyId
    end
    return true, companyId
end

function LSLegacy.Atelier.Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Atelier', msg, t or 'info', 5000)
end
