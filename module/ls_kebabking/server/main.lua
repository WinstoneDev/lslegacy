-- ls_kebabking (serveur) — socle : registre d'items, service, sécurité, logs.
--
-- Ordre de vérification appliqué à CHAQUE event venant du client
-- (même ordre que celui documenté dans lslegacy/DEVELOPMENT.md) :
--   RateLimit -> Player -> Job -> Grade -> Service -> Distance -> Arguments -> Action

KK = KK or {}

local Core = exports['lslegacy']

-- ── Journalisation ───────────────────────────────────────────────────────
function KK.Log(message)
    if KKConfig.Logs.console then
        print(('[%s] %s'):format(KKConfig.JobLabel, message))
    end
    local webhook = GetConvar(KKConfig.Logs.convar, '')
    if webhook ~= '' then
        PerformHttpRequest(webhook, function() end, 'POST', json.encode({
            username = KKConfig.JobLabel,
            embeds = { { title = KKConfig.JobLabel, description = message, color = 16744192 } },
        }), { ['Content-Type'] = 'application/json' })
    end
end

function KK.Dbg(message)
    if KKConfig.Debug then print(('[%s][debug] %s'):format(KKConfig.Prefix, message)) end
end

function KK.Notify(src, message, kind)
    TriggerClientEvent('brutal_notify:SendAlert', src, KKConfig.JobLabel, message, 5000, kind or 'info')
end

-- ── Enregistrement des items/du job dans le registre du framework ────────
-- module/foodapi/server/main.lua est chargé avant ce fichier dans
-- lslegacy/fxmanifest.lua : les exports sont garantis déclarés, appel direct.
CreateThread(function()
    local count = Core:registerItems(KKConfig.Items)
    KK.Dbg(('%s item(s) enregistrés côté serveur'):format(tostring(count)))

    -- Les frigos/congélateurs professionnels figent la péremption des plats.
    for storageId, storage in pairs(KKConfig.Storages) do
        if storage.enabled and storage.cold then
            Core:registerColdStorage('^' .. KK.DataStoreName('storage', storageId) .. '$', storage.cold)
        end
    end

    -- Sans ceci, 'kebabking' n'existe pour aucune fonction du Core
    -- (LSLegacy.Jobs.DoesJobExist, /setjob, sélecteur job de l'adminmenu) —
    -- voir module/foodapi/server/main.lua pour le pourquoi. Les libellés de
    -- grade doivent rester alignés avec module/ls_kebabking/config_mdt.lua
    -- (onglet Organisation du MDT).
    Core:registerJob(KKConfig.Job, {
        label = KKConfig.JobLabel,
        grades = {
            [0] = { label = 'Stagiaire' },
            [1] = { label = 'Cuisinier' },
            [2] = { label = 'Cuisinier Confirmé' },
            [3] = { label = 'Responsable de Salle' },
            [4] = { label = 'Gérant' },
        },
    })

    -- Permet à l'onglet Effectifs/Tableau de bord du MDT de savoir qui est
    -- en service, via l'export isOnDuty(src) exposé plus bas.
    Core:registerDutyChecker(KKConfig.Job)
end)

-- ── Sécurité ─────────────────────────────────────────────────────────────
KK.Sec = {}

local buckets = {}   -- [src] = { count = n, resetAt = ms }

---Allow — limitation de fréquence par joueur. Un dépassement est ignoré et
---journalisé : on ne kick pas, un faux positif coûterait plus cher qu'un spam.
---@param src number
---@param action string
---@return boolean
function KK.Sec.Allow(src, action)
    local now = GetGameTimer()
    local bucket = buckets[src]
    if not bucket or now > bucket.resetAt then
        buckets[src] = { count = 1, resetAt = now + KKConfig.Security.rateWindow }
        return true
    end
    bucket.count = bucket.count + 1
    if bucket.count > KKConfig.Security.rateMaxActions then
        KK.Dbg(('rate limit dépassé par %s sur %s'):format(src, action))
        return false
    end
    return true
end

AddEventHandler('playerDropped', function()
    local src = source
    buckets[src] = nil
    KK.Duty[src] = nil
end)

---Player — instantané joueur du framework, ou nil.
function KK.Sec.Player(src)
    return Core:getPlayerInfo(src)
end

---Employee — job + grade. Renvoie l'instantané joueur ou nil.
function KK.Sec.Employee(src, minGrade)
    local player = Core:getPlayerInfo(src)
    if not player then return nil end
    if player.job ~= KKConfig.Job then
        KK.Dbg(('refus job : %s a le job %s'):format(src, tostring(player.job)))
        return nil
    end
    if (player.grade or 0) < (minGrade or KKConfig.MinGrade) then
        KK.Dbg(('refus grade : %s a le grade %s'):format(src, tostring(player.grade)))
        return nil
    end
    return player
end

---NearCoords — distance serveur entre le joueur et un point de la config.
function KK.Sec.NearCoords(src, coords, maxDistance)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pedCoords = GetEntityCoords(ped)
    local dist = #(pedCoords - coords)
    if dist > (maxDistance or KKConfig.Security.maxDistance) then
        KK.Dbg(('refus distance : %s à %.1fm du point'):format(src, dist))
        return false
    end
    return true
end

-- ── Service ──────────────────────────────────────────────────────────────
-- En mémoire uniquement : le service ne survit pas à un redémarrage serveur,
-- et aucune table SQL n'est nécessaire pour ce restaurant. Prise/fin de
-- service se fait depuis le tableau de bord du MDT (tablette), pas via une
-- zone physique — voir client/main.lua (LSLegacy.MDT.DutyToggles) et
-- module/ls_kebabking/config_mdt.lua.
KK.Duty = {}

-- ── Broche ───────────────────────────────────────────────────────────────
-- Une fois posée (spit_place), la broche est un état partagé de la station
-- 'spit' — pas un item d'inventaire, pas propre à qui l'a posée : n'importe
-- quel employé en service peut venir la couper (spit_cut). En mémoire
-- uniquement, comme KK.Duty. Voir server/craft.lua.
KK.Spit = { mounted = false, remaining = 0 }

function KK.IsOnDuty(src)
    return KK.Duty[src] == true
end

-- Interrogé par module/mdt (onglet Effectifs/Tableau de bord) via
-- foodapi/registerDutyChecker — jamais appelé directement par le Core.
-- SUFFIXÉ PAR LE JOB : ls_burgershot déclare le même export dans la même
-- ressource lslegacy — sans suffixe le second écraserait le premier.
exports('isOnDuty_' .. KKConfig.Job, function(src)
    return KK.IsOnDuty(tonumber(src))
end)

---CanWork — job + grade + service + distance. Point d'entrée unique des
---handlers d'events métier.
---@return table|nil player
function KK.CanWork(src, minGrade, coords, maxDistance)
    local player = KK.Sec.Employee(src, minGrade)
    if not player then
        KK.Notify(src, "Vous n'appartenez pas à cette entreprise.", 'error')
        return nil
    end
    if not KK.IsOnDuty(src) then
        KK.Notify(src, "Vous devez être en service pour utiliser cet équipement.", 'error')
        return nil
    end
    if coords and not KK.Sec.NearCoords(src, coords, maxDistance) then
        KK.Notify(src, "Vous êtes trop loin de ce poste.", 'error')
        return nil
    end
    return player
end

-- Déclenché depuis le tableau de bord MDT (mdt:toggleDuty), pas de zone
-- physique : aucune vérification de distance ici, seulement job + fréquence.
RegisterNetEvent(KKConfig.Prefix .. ':duty:toggle', function()
    local src = source
    if not KK.Sec.Allow(src, 'duty') then return end

    local player = KK.Sec.Employee(src)
    if not player then
        KK.Notify(src, "Vous n'appartenez pas à cette entreprise.", 'error')
        return
    end

    local newState = not KK.Duty[src]
    KK.Duty[src] = newState or nil
    TriggerClientEvent(KKConfig.Prefix .. ':duty:sync', src, newState)
    KK.Notify(src, newState and "Vous avez pris votre service." or "Vous avez terminé votre service.",
        newState and 'success' or 'info')
    KK.Log(('%s (%s) %s'):format(player.name or 'Joueur', src, newState and 'a pris son service' or 'a terminé son service'))
end)

-- Le client peut redemander son état (reconnexion, restart de la ressource).
RegisterNetEvent(KKConfig.Prefix .. ':duty:request', function()
    local src = source
    if not KK.Sec.Allow(src, 'duty:request') then return end
    TriggerClientEvent(KKConfig.Prefix .. ':duty:sync', src, KK.Duty[src] == true)
end)
