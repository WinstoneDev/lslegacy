-- Permissions de grade Atelier éditables en jeu (onglet MDT « Permissions »),
-- au lieu d'être figées dans module/atelier/config/companies.lua. Un override
-- DB par (entreprise, grade, permission) vient se substituer aux grants
-- statiques de ce grade ; tant qu'aucun override n'existe pour un grade, son
-- comportement reste celui du fichier de config (amorçage à la 1ère lecture).

LSLegacy.Atelier.GradeOverrides = LSLegacy.Atelier.GradeOverrides or {}

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS atelier_grade_permissions (
        company_id VARCHAR(32) NOT NULL,
        grade      TINYINT UNSIGNED NOT NULL,
        permission VARCHAR(32) NOT NULL,
        PRIMARY KEY (company_id, grade, permission)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- Ordre stable pour l'onglet MDT (voir companies.lua pour le détail de chacune).
LSLegacy.Atelier.PermissionList = {
    'diagnostic', 'repair_mechanical', 'repair_bodywork', 'maintenance',
    'performance', 'customization', 'billing', 'manage_stock',
    'manage_employees', 'manage_company',
}

local function LoadCompany(companyId, company)
    local rows = MySQL.Sync.fetchAll('SELECT grade, permission FROM atelier_grade_permissions WHERE company_id = ?', { companyId })
    if #rows == 0 then
        for grade, rank in pairs(company.grades or {}) do
            for _, perm in ipairs(rank.grants or {}) do
                MySQL.Sync.execute('INSERT IGNORE INTO atelier_grade_permissions (company_id, grade, permission) VALUES (?, ?, ?)', { companyId, grade, perm })
            end
        end
        rows = MySQL.Sync.fetchAll('SELECT grade, permission FROM atelier_grade_permissions WHERE company_id = ?', { companyId })
    end

    local grants = {}
    for _, row in ipairs(rows) do
        local g = tonumber(row.grade)
        grants[g] = grants[g] or {}
        grants[g][row.permission] = true
    end
    LSLegacy.Atelier.GradeOverrides[companyId] = grants
end

CreateThread(function()
    for companyId, company in pairs(Config.Atelier.Companies or {}) do
        LoadCompany(companyId, company)
    end
end)

-- Grille complète (labels + permissions actives par grade) d'une entreprise,
-- pour l'onglet MDT « Permissions ».
function LSLegacy.Atelier.GetGradeGrid(companyId)
    local company = Config.Atelier.Companies[companyId]
    if not company then return nil end
    local overrides = LSLegacy.Atelier.GradeOverrides[companyId] or {}
    local grades = {}
    for grade, rank in pairs(company.grades or {}) do
        grades[#grades + 1] = { grade = grade, label = rank.label, grants = overrides[grade] or {} }
    end
    table.sort(grades, function(a, b) return a.grade < b.grade end)
    return { grades = grades, permissions = LSLegacy.Atelier.PermissionList }
end

-- Active/désactive une permission pour un grade d'une entreprise.
function LSLegacy.Atelier.SetGradePermission(companyId, grade, perm, enabled)
    local company = Config.Atelier.Companies[companyId]
    grade = tonumber(grade)
    if not company or not grade or not company.grades[grade] then return false end

    local valid = false
    for _, p in ipairs(LSLegacy.Atelier.PermissionList) do
        if p == perm then valid = true break end
    end
    if not valid then return false end

    LSLegacy.Atelier.GradeOverrides[companyId] = LSLegacy.Atelier.GradeOverrides[companyId] or {}
    LSLegacy.Atelier.GradeOverrides[companyId][grade] = LSLegacy.Atelier.GradeOverrides[companyId][grade] or {}

    if enabled then
        LSLegacy.Atelier.GradeOverrides[companyId][grade][perm] = true
        MySQL.Async.execute('INSERT IGNORE INTO atelier_grade_permissions (company_id, grade, permission) VALUES (?, ?, ?)', { companyId, grade, perm })
    else
        LSLegacy.Atelier.GradeOverrides[companyId][grade][perm] = nil
        MySQL.Async.execute('DELETE FROM atelier_grade_permissions WHERE company_id = ? AND grade = ? AND permission = ?', { companyId, grade, perm })
    end
    return true
end
