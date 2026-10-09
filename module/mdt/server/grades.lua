-- MDT — GESTION DES GRADES (serveur, atelier uniquement)
-- Onglet réservé aux départements atelier (Red's Tunershop, Benny's) : édite
-- les permissions par grade normalement figées dans module/atelier/config/
-- companies.lua, sans passer par un redémarrage/edit de fichier.

LSLegacy.Security.RegisterRateLimit('mdtgrades:query', 20)
LSLegacy.Security.RegisterRateLimit('mdtgrades:set', 60) -- grille de checkboxes : plusieurs togglés en rafale par un admin

-- companyId de l'entreprise atelier du département MDT du joueur, ou nil si
-- son département n'est pas un atelier (réutilise dep.parts, déjà déclaré
-- pour l'onglet « Commande de pièces »).
local function GradesCtx(src)
    local player = LSLegacy.Players.Get(src)
    if not player then return nil end
    local depName = LSLegacy.MDT.GetDepartmentForJob(player.job)
    if not depName then return nil end
    local dep = LSLegacy.MDT.GetDepartment(depName)
    if not dep or not dep.parts or not dep.parts.companyId then return nil end
    return dep.parts.companyId
end

LSLegacy.Events.Register('mdtgrades:query', function(payload)
    local src = source
    local companyId = GradesCtx(src)
    local reply = function(res)
        LSLegacy.Events.SendToClient('mdtgrades:queryResult', src, { reqId = type(payload) == 'table' and payload.reqId or nil, result = res })
    end
    if not companyId or not HasPermission(src, 'manage_boutique') then return reply(false) end
    reply(LSLegacy.Atelier.GetGradeGrid(companyId))
end)

LSLegacy.Events.Register('mdtgrades:set', function(data)
    local src = source
    local companyId = GradesCtx(src)
    if not companyId or not HasPermission(src, 'manage_boutique') then return end
    if type(data) ~= 'table' or not data.grade or not data.permission then return end
    LSLegacy.Atelier.SetGradePermission(companyId, data.grade, data.permission, data.enabled == true)
end)
