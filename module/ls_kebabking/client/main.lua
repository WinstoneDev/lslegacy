-- ls_kebabking (client) — état local, service, blip, animations, debug.
-- Le client n'est jamais autoritatif : tout ce qui est ici sert à l'affichage
-- et au confort. Chaque action est revalidée côté serveur.

KK = KK or {}
KK.Client = {
    job     = nil,
    grade   = 0,
    onDuty  = false,
    busy    = false,   -- une action (progressbar) est en cours
}

-- ── Notifications ────────────────────────────────────────────────────────
function KK.Notify(message, kind, title)
    TriggerEvent('brutal_notify:SendAlert', title or KKConfig.JobLabel, message, 5000, kind or 'info')
end

function KK.Dbg(message)
    if KKConfig.Debug then print(('[%s] %s'):format(KKConfig.Prefix, message)) end
end

-- ── Cache des données joueur ─────────────────────────────────────────────
local function ApplyPlayerData(data)
    if type(data) ~= 'table' then return end
    local previousJob = KK.Client.job
    KK.Client.job   = data.job
    KK.Client.grade = tonumber(data.job_grade) or 0
    if previousJob == KKConfig.Job and data.job ~= KKConfig.Job then
        -- Changement de métier : plus de service possible côté client non plus.
        KK.Client.onDuty = false
    end
    if KK.RefreshZones then KK.RefreshZones() end
end

CreateThread(function()
    -- Les items doivent rejoindre le registre client (libellés, poids,
    -- consommation) avant que l'inventaire ne soit ouvert. module/foodapi
    -- charge avant ce fichier dans lslegacy/fxmanifest.lua : appel direct.
    exports['lslegacy']:registerItems(KKConfig.Items)

    while true do
        if exports['lslegacy']:isLoaded() then
            ApplyPlayerData(exports['lslegacy']:getPlayerData())
            -- Un restart de la ressource ne doit pas faire croire au joueur
            -- qu'il est hors service alors que le serveur le sait en service.
            TriggerServerEvent(KKConfig.Prefix .. ':duty:request')
            break
        end
        Wait(500)
    end
end)

-- Le Core repousse le joueur complet à chaque mutation : on s'en sert pour
-- garder job/grade à jour sans interroger l'export en boucle.
RegisterNetEvent('lslegacy:updatePlayer', ApplyPlayerData)
RegisterNetEvent('lslegacy:initPlayer', ApplyPlayerData)

-- ── Droits d'accès (affichage uniquement) ────────────────────────────────
function KK.IsEmployee(minGrade)
    if KK.Client.job ~= KKConfig.Job then return false end
    return KK.Client.grade >= (minGrade or KKConfig.MinGrade)
end

function KK.CanUseStation(minGrade)
    if not KK.IsEmployee(minGrade) then return false end
    if not KK.Client.onDuty then return false end
    return true
end

-- ── Service ──────────────────────────────────────────────────────────────
-- Prise/fin de service depuis le tableau de bord du MDT (tablette), pas de
-- zone physique — voir l'enregistrement LSLegacy.MDT.DutyToggles plus bas.
RegisterNetEvent(KKConfig.Prefix .. ':duty:sync', function(onDuty)
    KK.Client.onDuty = onDuty and true or false
    KK.Dbg('service = ' .. tostring(KK.Client.onDuty))
    if KK.RefreshZones then KK.RefreshZones() end
end)

function KK.ToggleDuty()
    TriggerServerEvent(KKConfig.Prefix .. ':duty:toggle')
end

-- Le bouton "Prise de service" du MDT (module/mdt) appelle ces deux exports
-- par leur nom, après qu'on se soit enregistré via registerClientDuty
-- (module/foodapi) — mécanisme conservé après la fusion dans lslegacy pour
-- rester générique (foodapi sert aussi de pont pour d'éventuelles vraies
-- ressources externes) ; fonctionne tel quel : un export peut s'appeler
-- lui-même au sein de la même ressource.
-- SUFFIXÉS PAR LE JOB : ls_burgershot déclare les mêmes noms d'export dans
-- la même ressource lslegacy — sans suffixe le second écraserait le premier.
exports('toggleDuty_' .. KKConfig.Job, function() KK.ToggleDuty() end)
exports('isOnDuty_' .. KKConfig.Job, function() return KK.Client.onDuty end)

CreateThread(function()
    exports['lslegacy']:registerClientDuty(KKConfig.Job)
end)

-- ── Animations + props ───────────────────────────────────────────────────
local heldProp = nil

local function ClearHeldProp()
    if heldProp and DoesEntityExist(heldProp) then DeleteEntity(heldProp) end
    heldProp = nil
end

local function AttachProp(propCfg)
    if not propCfg or not propCfg.model then return end
    local model = joaat(propCfg.model)
    RequestModel(model)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(model) then
        -- Prop indisponible : l'action continue sans, jamais de blocage.
        KK.Dbg('modèle de prop introuvable : ' .. tostring(propCfg.model))
        return
    end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    heldProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    AttachEntityToEntity(heldProp, ped, GetPedBoneIndex(ped, propCfg.bone or 28422),
        propCfg.pos.x, propCfg.pos.y, propCfg.pos.z,
        propCfg.rot.x, propCfg.rot.y, propCfg.rot.z,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
end

---PlayCraftAnim — joue l'animation d'une action et affiche la progressbar
---ox_lib. Renvoie true si le joueur est allé au bout.
---@param animKey string|nil
---@param label string
---@param duration number
---@return boolean
function KK.PlayCraftAnim(animKey, label, duration)
    local anim = animKey and KKConfig.Anims[animKey] or nil

    if anim and anim.dict then
        RequestAnimDict(anim.dict)
        local timeout = GetGameTimer() + 3000
        while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < timeout do Wait(10) end
    end
    if anim and anim.prop then AttachProp(anim.prop) end

    local ok = lib.progressCircle({
        duration    = duration,
        label       = label,
        position    = 'bottom',
        useWhileDead = false,
        canCancel   = true,
        disable     = { car = true, move = true, combat = true },
        anim        = (anim and anim.dict) and { dict = anim.dict, clip = anim.clip, flag = anim.flag or 49 } or nil,
    })

    ClearHeldProp()
    ClearPedTasks(PlayerPedId())
    return ok
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then ClearHeldProp() end
end)

-- ── Blip ─────────────────────────────────────────────────────────────────
CreateThread(function()
    if not KKConfig.Blip.enabled then return end
    local blip = AddBlipForCoord(KKConfig.Blip.coords.x, KKConfig.Blip.coords.y, KKConfig.Blip.coords.z)
    SetBlipSprite(blip, KKConfig.Blip.sprite)
    SetBlipColour(blip, KKConfig.Blip.color)
    SetBlipScale(blip, KKConfig.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(KKConfig.Blip.label)
    EndTextCommandSetBlipName(blip)
end)

-- ── Debug / calibrage des coordonnées ────────────────────────────────────
-- Les positions du MLO ne peuvent pas être devinées hors du jeu : ces deux
-- commandes servent à les relever puis à les recopier dans config/config.lua.
CreateThread(function()
    if not KKConfig.Debug then return end

    RegisterCommand('kk_coords', function()
        local c = GetEntityCoords(PlayerPedId())
        local h = GetEntityHeading(PlayerPedId())
        local line = ('coords = vec3(%.2f, %.2f, %.2f), rotation = %.1f'):format(c.x, c.y, c.z, h)
        print(('[%s] %s'):format(KKConfig.Prefix, line))
        lib.setClipboard(line)
        KK.Notify('Coordonnées copiées dans le presse-papier.', 'success')
    end, false)

    RegisterCommand('kk_stations', function()
        for id, station in pairs(KKConfig.Stations) do
            print(('[%s] station %s -> %s'):format(KKConfig.Prefix, id, tostring(station.coords)))
        end
        for id, storage in pairs(KKConfig.Storages) do
            print(('[%s] stockage %s -> %s (actif: %s)'):format(KKConfig.Prefix, id, tostring(storage.coords), tostring(storage.enabled)))
        end
        KK.Notify(('Job détecté : %s (grade %d) — service : %s'):format(
            tostring(KK.Client.job), KK.Client.grade, tostring(KK.Client.onDuty)), 'info')
    end, false)

    -- Marqueurs au sol sur chaque point configuré, uniquement à proximité.
    CreateThread(function()
        local points = {}
        for id, s in pairs(KKConfig.Stations) do points[#points + 1] = { c = s.coords, r = 255, g = 140, b = 0, id = id } end
        for id, s in pairs(KKConfig.Storages) do
            if s.enabled then points[#points + 1] = { c = s.coords, r = 0, g = 160, b = 255, id = id } end
        end
        if KKConfig.Trays.enabled then
            for _, t in ipairs(KKConfig.Trays.list) do points[#points + 1] = { c = t.coords, r = 0, g = 220, b = 120, id = 'tray' .. t.id } end
        end
        if KKConfig.Cash.enabled then points[#points + 1] = { c = KKConfig.Cash.coords, r = 255, g = 60, b = 60, id = 'caisse' } end

        while KKConfig.Debug do
            local ped = GetEntityCoords(PlayerPedId())
            local sleep = 1000
            for _, p in ipairs(points) do
                if #(ped - p.c) < 20.0 then
                    sleep = 0
                    DrawMarker(28, p.c.x, p.c.y, p.c.z, 0, 0, 0, 0, 0, 0, 0.18, 0.18, 0.18,
                        p.r, p.g, p.b, 120, false, false, 0, true, nil, nil, false)
                end
            end
            Wait(sleep)
        end
    end)
end)
