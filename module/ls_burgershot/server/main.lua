-- ls_burgershot (serveur) — socle : registre d'items, service, sécurité, logs.
--
-- Ordre de vérification appliqué à CHAQUE event venant du client
-- (même ordre que celui documenté dans lslegacy/DEVELOPMENT.md) :
--   RateLimit -> Player -> Job -> Grade -> Service -> Distance -> Arguments -> Action

BS = BS or {}

local Core = exports['lslegacy']

-- ── Journalisation ───────────────────────────────────────────────────────
function BS.Log(message)
    if BSConfig.Logs.console then
        print(('[%s] %s'):format(BSConfig.JobLabel, message))
    end
    local webhook = GetConvar(BSConfig.Logs.convar, '')
    if webhook ~= '' then
        PerformHttpRequest(webhook, function() end, 'POST', json.encode({
            username = BSConfig.JobLabel,
            embeds = { { title = BSConfig.JobLabel, description = message, color = 16744192 } },
        }), { ['Content-Type'] = 'application/json' })
    end
end

function BS.Dbg(message)
    if BSConfig.Debug then print(('[%s][debug] %s'):format(BSConfig.Prefix, message)) end
end

function BS.Notify(src, message, kind)
    TriggerClientEvent('brutal_notify:SendAlert', src, BSConfig.JobLabel, message, 5000, kind or 'info')
end

-- ── Enregistrement des items dans le registre du framework ───────────────
-- module/foodapi/server/main.lua est chargé avant ce fichier dans
-- lslegacy/fxmanifest.lua : les exports sont garantis déclarés, appel direct.
CreateThread(function()
    local count = Core:registerItems(BSConfig.Items)
    BS.Dbg(('%s item(s) enregistrés côté serveur'):format(tostring(count)))

    -- Les frigos/congélateurs professionnels figent la péremption des plats.
    for storageId, storage in pairs(BSConfig.Storages) do
        if storage.enabled and storage.cold then
            Core:registerColdStorage('^' .. BS.DataStoreName('storage', storageId) .. '$', storage.cold)
        end
    end

    -- Sans ceci, 'burgershot' n'existe pour aucune fonction du Core
    -- (LSLegacy.Jobs.DoesJobExist, /setjob, sélecteur job de l'adminmenu) —
    -- voir module/foodapi/server/main.lua pour le pourquoi.
    Core:registerJob(BSConfig.Job, {
        label = BSConfig.JobLabel,
        grades = {
            [0] = { label = 'Stagiaire' },
            [1] = { label = 'Cuisinier' },
            [2] = { label = 'Cuisinier Confirmé' },
            [3] = { label = 'Responsable de Salle' },
            [4] = { label = 'Gérant' },
        },
    })

    -- Permet à l'onglet Effectifs/Tableau de bord du MDT de savoir qui est
    -- en service, via l'export isOnDuty_<job>(src) exposé plus bas.
    Core:registerDutyChecker(BSConfig.Job)
end)

-- ── Sécurité ─────────────────────────────────────────────────────────────
BS.Sec = {}

local buckets = {}   -- [src] = { count = n, resetAt = ms }

---Allow — limitation de fréquence par joueur. Un dépassement est ignoré et
---journalisé : on ne kick pas, un faux positif coûterait plus cher qu'un spam.
---@param src number
---@param action string
---@return boolean
function BS.Sec.Allow(src, action)
    local now = GetGameTimer()
    local bucket = buckets[src]
    if not bucket or now > bucket.resetAt then
        buckets[src] = { count = 1, resetAt = now + BSConfig.Security.rateWindow }
        return true
    end
    bucket.count = bucket.count + 1
    if bucket.count > BSConfig.Security.rateMaxActions then
        BS.Dbg(('rate limit dépassé par %s sur %s'):format(src, action))
        return false
    end
    return true
end

AddEventHandler('playerDropped', function()
    local src = source
    buckets[src] = nil
    BS.Duty[src] = nil
end)

---Player — instantané joueur du framework, ou nil.
function BS.Sec.Player(src)
    return Core:getPlayerInfo(src)
end

---Employee — job + grade. Renvoie l'instantané joueur ou nil.
function BS.Sec.Employee(src, minGrade)
    local player = Core:getPlayerInfo(src)
    if not player then return nil end
    if player.job ~= BSConfig.Job then
        BS.Dbg(('refus job : %s a le job %s'):format(src, tostring(player.job)))
        return nil
    end
    if (player.grade or 0) < (minGrade or BSConfig.MinGrade) then
        BS.Dbg(('refus grade : %s a le grade %s'):format(src, tostring(player.grade)))
        return nil
    end
    return player
end

---NearCoords — distance serveur entre le joueur et un point de la config.
function BS.Sec.NearCoords(src, coords, maxDistance)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pedCoords = GetEntityCoords(ped)
    local dist = #(pedCoords - coords)
    if dist > (maxDistance or BSConfig.Security.maxDistance) then
        BS.Dbg(('refus distance : %s à %.1fm du point'):format(src, dist))
        return false
    end
    return true
end

-- ── Service ──────────────────────────────────────────────────────────────
-- En mémoire uniquement : le service ne survit pas à un redémarrage serveur,
-- et aucune table SQL n'est nécessaire pour ce restaurant.
BS.Duty = {}

function BS.IsOnDuty(src)
    if not BSConfig.Duty.required then return true end
    return BS.Duty[src] == true
end

-- Interrogé par module/mdt (onglet Effectifs/Tableau de bord) via
-- foodapi/registerDutyChecker — jamais appelé directement par le Core.
-- SUFFIXÉ PAR LE JOB : ls_kebabking déclare le même export dans la même
-- ressource lslegacy — sans suffixe le second écraserait le premier.
exports('isOnDuty_' .. BSConfig.Job, function(src)
    return BS.IsOnDuty(tonumber(src))
end)

---CanWork — job + grade + service + distance. Point d'entrée unique des
---handlers d'events métier.
---@return table|nil player
function BS.CanWork(src, minGrade, coords, maxDistance)
    local player = BS.Sec.Employee(src, minGrade)
    if not player then
        BS.Notify(src, "Vous n'appartenez pas à cette entreprise.", 'error')
        return nil
    end
    if not BS.IsOnDuty(src) then
        BS.Notify(src, "Vous devez être en service pour utiliser cet équipement.", 'error')
        return nil
    end
    if coords and not BS.Sec.NearCoords(src, coords, maxDistance) then
        BS.Notify(src, "Vous êtes trop loin de ce poste.", 'error')
        return nil
    end
    return player
end

-- Déclenché depuis le tableau de bord MDT (mdt:toggleDuty), pas de zone
-- physique : aucune vérification de distance ici, seulement job + fréquence.
RegisterNetEvent(BSConfig.Prefix .. ':duty:toggle', function()
    local src = source
    if not BS.Sec.Allow(src, 'duty') then return end

    local player = BS.Sec.Employee(src)
    if not player then
        BS.Notify(src, "Vous n'appartenez pas à cette entreprise.", 'error')
        return
    end

    local newState = not BS.Duty[src]
    BS.Duty[src] = newState or nil
    TriggerClientEvent(BSConfig.Prefix .. ':duty:sync', src, newState)
    BS.Notify(src, newState and "Vous avez pris votre service." or "Vous avez terminé votre service.",
        newState and 'success' or 'info')
    BS.Log(('%s (%s) %s'):format(player.name or 'Joueur', src, newState and 'a pris son service' or 'a terminé son service'))
end)

-- Le client peut redemander son état (reconnexion, restart de la ressource).
RegisterNetEvent(BSConfig.Prefix .. ':duty:request', function()
    local src = source
    if not BS.Sec.Allow(src, 'duty:request') then return end
    TriggerClientEvent(BSConfig.Prefix .. ':duty:sync', src, BS.Duty[src] == true)
end)
