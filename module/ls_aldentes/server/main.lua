-- ls_aldentes (serveur) — socle : registre d'items, service, sécurité, logs.
--
-- Ordre de vérification appliqué à CHAQUE event venant du client
-- (même ordre que celui documenté dans lslegacy/DEVELOPMENT.md) :
--   RateLimit -> Player -> Job -> Grade -> Service -> Distance -> Arguments -> Action

ALD = ALD or {}

local Core = exports['lslegacy']

-- ── Journalisation ───────────────────────────────────────────────────────
function ALD.Log(message)
    if ALDConfig.Logs.console then
        print(('[%s] %s'):format(ALDConfig.JobLabel, message))
    end
    local webhook = GetConvar(ALDConfig.Logs.convar, '')
    if webhook ~= '' then
        PerformHttpRequest(webhook, function() end, 'POST', json.encode({
            username = ALDConfig.JobLabel,
            embeds = { { title = ALDConfig.JobLabel, description = message, color = 16744192 } },
        }), { ['Content-Type'] = 'application/json' })
    end
end

function ALD.Dbg(message)
    if ALDConfig.Debug then print(('[%s][debug] %s'):format(ALDConfig.Prefix, message)) end
end

function ALD.Notify(src, message, kind)
    TriggerClientEvent('brutal_notify:SendAlert', src, ALDConfig.JobLabel, message, 5000, kind or 'info')
end

-- ── Enregistrement des items dans le registre du framework ───────────────
-- module/foodapi/server/main.lua est chargé avant ce fichier dans
-- lslegacy/fxmanifest.lua : les exports sont garantis déclarés, appel direct.
CreateThread(function()
    local count = Core:registerItems(ALDConfig.Items)
    ALD.Dbg(('%s item(s) enregistrés côté serveur'):format(tostring(count)))

    -- Les frigos/congélateurs professionnels figent la péremption des plats.
    for storageId, storage in pairs(ALDConfig.Storages) do
        if storage.enabled and storage.cold then
            Core:registerColdStorage('^' .. ALD.DataStoreName('storage', storageId) .. '$', storage.cold)
        end
    end

    -- Sans ceci, 'aldentes' n'existe pour aucune fonction du Core
    -- (LSLegacy.Jobs.DoesJobExist, /setjob, sélecteur job de l'adminmenu) —
    -- voir module/foodapi/server/main.lua pour le pourquoi.
    Core:registerJob(ALDConfig.Job, {
        label = ALDConfig.JobLabel,
        grades = {
            [0] = { label = 'Stagiaire' },
            [1] = { label = 'Cuisinier' },
            [2] = { label = 'Cuisinier Confirmé' },
            [3] = { label = 'Responsable de Salle' },
            [4] = { label = 'Gérant' },
        },
    })
end)

-- ── Sécurité ─────────────────────────────────────────────────────────────
ALD.Sec = {}

local buckets = {}   -- [src] = { count = n, resetAt = ms }

---Allow — limitation de fréquence par joueur. Un dépassement est ignoré et
---journalisé : on ne kick pas, un faux positif coûterait plus cher qu'un spam.
---@param src number
---@param action string
---@return boolean
function ALD.Sec.Allow(src, action)
    local now = GetGameTimer()
    local bucket = buckets[src]
    if not bucket or now > bucket.resetAt then
        buckets[src] = { count = 1, resetAt = now + ALDConfig.Security.rateWindow }
        return true
    end
    bucket.count = bucket.count + 1
    if bucket.count > ALDConfig.Security.rateMaxActions then
        ALD.Dbg(('rate limit dépassé par %s sur %s'):format(src, action))
        return false
    end
    return true
end

AddEventHandler('playerDropped', function()
    local src = source
    buckets[src] = nil
    ALD.Duty[src] = nil
end)

---Player — instantané joueur du framework, ou nil.
function ALD.Sec.Player(src)
    return Core:getPlayerInfo(src)
end

---Employee — job + grade. Renvoie l'instantané joueur ou nil.
function ALD.Sec.Employee(src, minGrade)
    local player = Core:getPlayerInfo(src)
    if not player then return nil end
    if player.job ~= ALDConfig.Job then
        ALD.Dbg(('refus job : %s a le job %s'):format(src, tostring(player.job)))
        return nil
    end
    if (player.grade or 0) < (minGrade or ALDConfig.MinGrade) then
        ALD.Dbg(('refus grade : %s a le grade %s'):format(src, tostring(player.grade)))
        return nil
    end
    return player
end

---NearCoords — distance serveur entre le joueur et un point de la config.
function ALD.Sec.NearCoords(src, coords, maxDistance)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pedCoords = GetEntityCoords(ped)
    local dist = #(pedCoords - coords)
    if dist > (maxDistance or ALDConfig.Security.maxDistance) then
        ALD.Dbg(('refus distance : %s à %.1fm du point'):format(src, dist))
        return false
    end
    return true
end

-- ── Service ──────────────────────────────────────────────────────────────
-- En mémoire uniquement : le service ne survit pas à un redémarrage serveur,
-- et aucune table SQL n'est nécessaire pour ce restaurant.
ALD.Duty = {}

function ALD.IsOnDuty(src)
    if not ALDConfig.Duty.required then return true end
    return ALD.Duty[src] == true
end

---CanWork — job + grade + service + distance. Point d'entrée unique des
---handlers d'events métier.
---@return table|nil player
function ALD.CanWork(src, minGrade, coords, maxDistance)
    local player = ALD.Sec.Employee(src, minGrade)
    if not player then
        ALD.Notify(src, "Vous n'appartenez pas à cette entreprise.", 'error')
        return nil
    end
    if not ALD.IsOnDuty(src) then
        ALD.Notify(src, "Vous devez être en service pour utiliser cet équipement.", 'error')
        return nil
    end
    if coords and not ALD.Sec.NearCoords(src, coords, maxDistance) then
        ALD.Notify(src, "Vous êtes trop loin de ce poste.", 'error')
        return nil
    end
    return player
end

RegisterNetEvent(ALDConfig.Prefix .. ':duty:toggle', function()
    local src = source
    if not ALD.Sec.Allow(src, 'duty') then return end

    local player = ALD.Sec.Employee(src)
    if not player then
        ALD.Notify(src, "Vous n'appartenez pas à cette entreprise.", 'error')
        return
    end
    if not ALD.Sec.NearCoords(src, ALDConfig.Duty.coords, ALDConfig.Duty.distance + 2.0) then
        ALD.Notify(src, "Vous êtes trop loin de la pointeuse.", 'error')
        return
    end

    local newState = not ALD.Duty[src]
    ALD.Duty[src] = newState or nil
    TriggerClientEvent(ALDConfig.Prefix .. ':duty:sync', src, newState)
    ALD.Notify(src, newState and "Vous avez pris votre service." or "Vous avez terminé votre service.",
        newState and 'success' or 'info')
    ALD.Log(('%s (%s) %s'):format(player.name or 'Joueur', src, newState and 'a pris son service' or 'a terminé son service'))
end)

-- Le client peut redemander son état (reconnexion, restart de la ressource).
RegisterNetEvent(ALDConfig.Prefix .. ':duty:request', function()
    local src = source
    if not ALD.Sec.Allow(src, 'duty:request') then return end
    TriggerClientEvent(ALDConfig.Prefix .. ':duty:sync', src, ALD.Duty[src] == true)
end)
