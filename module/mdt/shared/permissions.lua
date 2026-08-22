--  MDT — Permissions & résolution de département (partagé client/serveur)
--
--  Ce fichier est déclaré DANS client_scripts ET server_scripts (pas en
--  shared_scripts) : il a besoin de la table globale `LSLegacy`, qui est
--  (ré)initialisée par client/function.lua et server/function.lua APRÈS
--  les shared_scripts. Le code ci-dessous est pur (lecture de Config),
--  donc identique et sûr dans les deux contextes.
--
--  RÈGLE D'OR (sécurité) : côté serveur, toujours résoudre job/grade
--  depuis LSLegacy.Players.Get(src) — jamais depuis le client.

LSLegacy = LSLegacy or {}
LSLegacy.MDT = LSLegacy.MDT or {}

-- Récupère la table d'un département par son nom.
function LSLegacy.MDT.GetDepartment(depName)
    if not depName then return nil end
    local deps = Config.MDT and Config.MDT.Departments
    return deps and deps[depName] or nil
end

-- Un département est-il déclaré actif ?
function LSLegacy.MDT.IsDepartmentActive(depName)
    if not depName or not Config.MDT or not Config.MDT.ActiveDepartments then return false end
    for _, d in ipairs(Config.MDT.ActiveDepartments) do
        if d == depName then return true end
    end
    return false
end

-- Trouve le département ACTIF rattaché à un job donné.
-- @return string|nil depName
-- @return table|nil dep
function LSLegacy.MDT.GetDepartmentForJob(job)
    if not job or not Config.MDT or not Config.MDT.Departments then return nil end
    for _, depName in ipairs(Config.MDT.ActiveDepartments or {}) do
        local dep = Config.MDT.Departments[depName]
        if dep and dep.jobs then
            for _, j in ipairs(dep.jobs) do
                if j == job then return depName, dep end
            end
        end
    end
    return nil
end

-- Le job peut-il ouvrir le MDT ?
function LSLegacy.MDT.CanOpen(job)
    return LSLegacy.MDT.GetDepartmentForJob(job) ~= nil
end

-- Libellé court d'un département, pour l'estampille d'origine sur une
-- pièce de dossier (« PN », « GN »). Repli sur le nom brut.
function LSLegacy.MDT.GetDepartmentShort(depName)
    local dep = LSLegacy.MDT.GetDepartment(depName)
    return (dep and dep.short) or depName or '?'
end

-- Sphère de données d'un département : la liste des départements qui
-- partagent sa base. Un département sans sphère est seul dans la sienne.
-- @return table liste de noms de départements (contient toujours depName)
function LSLegacy.MDT.GetDataGroup(depName)
    if not depName then return {} end
    for _, group in ipairs((Config.MDT and Config.MDT.DataGroups) or {}) do
        for _, d in ipairs(group.departments or {}) do
            if d == depName then
                -- On ne renvoie que les départements ACTIFS : un département
                -- désactivé ne doit pas élargir silencieusement une lecture.
                local out = {}
                for _, m in ipairs(group.departments) do
                    if LSLegacy.MDT.IsDepartmentActive(m) then out[#out + 1] = m end
                end
                return out
            end
        end
    end
    return { depName }
end

-- Départements dont `depName` peut LIRE les enregistrements d'une table.
-- Une table non déclarée dans Config.MDT.SharedTables reste étanche.
-- @param tableName string nom de la table SQL
-- @return table liste de noms de départements
function LSLegacy.MDT.GetReadScope(depName, tableName)
    if not depName then return {} end
    local shared = (Config.MDT and Config.MDT.SharedTables) or {}
    if shared[tableName] ~= true then return { depName } end
    return LSLegacy.MDT.GetDataGroup(depName)
end

-- Clause SQL de portée de lecture pour une table de la base commune.
---
-- Les noms de départements viennent exclusivement de la config, jamais du
-- client, et chaque nom est filtré en [%w_] : l'interpolation est donc
-- sûre. On ne peut pas passer par un paramètre nommé, le driver mysql
-- n'expansant pas une liste dans un `IN`.
-- @param tableName string table SQL concernée
-- @param column string|nil colonne à tester (défaut : `department`)
function LSLegacy.MDT.ScopeClause(depName, tableName, column)
    local parts = {}
    for _, d in ipairs(LSLegacy.MDT.GetReadScope(depName, tableName)) do
        local clean = tostring(d):gsub('[^%w_]', '')
        if clean ~= '' then parts[#parts + 1] = "'" .. clean .. "'" end
    end
    -- Aucun département résolu : on renvoie une clause qui ne matche rien
    -- plutôt qu'une clause absente, qui ouvrirait toute la table.
    if #parts == 0 then parts[1] = "''" end
    return (column or 'department') .. ' IN (' .. table.concat(parts, ',') .. ')'
end

-- Le métier appartient-il aux forces de l'ordre ?
-- Critère : son département partage la base de la police. Ajouter un pôle
-- à Config.MDT.DataGroups suffit donc à l'y inclure, sans toucher au code.
function LSLegacy.MDT.IsInLawEnforcement(job)
    local depName = LSLegacy.MDT.GetDepartmentForJob(job)
    if not depName then return false end
    for _, d in ipairs(LSLegacy.MDT.GetDataGroup('police')) do
        if d == depName then return true end
    end
    return false
end

-- Registre des bascules de prise de service, alimenté côté CLIENT par
-- chaque module métier (police, gendarmerie…), indexé par job. Le cœur
-- MDT s'en sert pour le bouton du tableau de bord sans dépendre d'un
-- module particulier.
LSLegacy.MDT.DutyToggles = LSLegacy.MDT.DutyToggles or {}

-- CLIENT — le joueur local est-il en service dans une force de l'ordre ?
-- Sert de garde aux actions de terrain (menottage, escorte, relevés) :
-- elles sont ouvertes à la police comme à la gendarmerie.
function LSLegacy.MDT.IsLocalLeoOnDuty()
    local job = LSLegacy.PlayerData and LSLegacy.PlayerData.job
    if not job or not LSLegacy.MDT.IsInLawEnforcement(job) then return false end
    local entry = LSLegacy.MDT.DutyToggles[job]
    return (entry and type(entry.isOnDuty) == 'function' and entry.isOnDuty()) == true
end

-- Données d'un grade d'un département.
function LSLegacy.MDT.GetRankData(depName, grade)
    local dep = LSLegacy.MDT.GetDepartment(depName)
    if not dep or not dep.grades then return nil end
    return dep.grades[tonumber(grade) or 0]
end

-- Label d'un grade (avec repli).
function LSLegacy.MDT.GetGradeLabel(depName, grade)
    local rank = LSLegacy.MDT.GetRankData(depName, grade)
    return rank and rank.label or 'Inconnu'
end

-- Ensemble CUMULÉ des permissions pour un grade (cumule les grants de 0 → grade).
-- @return table set { [permission]=true }
function LSLegacy.MDT.GetPermissions(depName, grade)
    local dep = LSLegacy.MDT.GetDepartment(depName)
    local perms = {}
    if not dep or not dep.grades then return perms end
    grade = tonumber(grade) or 0
    for g = 0, grade do
        local rank = dep.grades[g]
        if rank and rank.grants then
            for _, p in ipairs(rank.grants) do
                perms[p] = true
            end
        end
    end
    return perms
end

-- Le grade possède-t-il une permission ? (admin_mdt accorde tout)
function LSLegacy.MDT.HasPermission(depName, grade, perm)
    if not perm then return true end
    local perms = LSLegacy.MDT.GetPermissions(depName, grade)
    if perms.admin_mdt then return true end
    return perms[perm] == true
end

-- Liste ordonnée des onglets visibles pour un grade (filtrés par permission).
function LSLegacy.MDT.GetVisibleTabs(depName, grade)
    local dep = LSLegacy.MDT.GetDepartment(depName)
    local result = {}
    if not dep or not Config.MDT then return result end
    local enabled = {}
    for _, t in ipairs(dep.tabs or {}) do enabled[t] = true end
    for _, tab in ipairs(Config.MDT.Tabs or {}) do
        if enabled[tab.id] then
            if not tab.permission or LSLegacy.MDT.HasPermission(depName, grade, tab.permission) then
                result[#result + 1] = { id = tab.id, label = tab.label, icon = tab.icon }
            end
        end
    end
    return result
end
