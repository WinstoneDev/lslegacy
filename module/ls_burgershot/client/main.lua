-- ls_burgershot (client) — état local, service, blip, animations, debug.
-- Le client n'est jamais autoritatif : tout ce qui est ici sert à l'affichage
-- et au confort. Chaque action est revalidée côté serveur.

BS = BS or {}
BS.Client = {
    job     = nil,
    grade   = 0,
    onDuty  = false,
    busy    = false,   -- une action (progressbar) est en cours
}

-- ── Notifications ────────────────────────────────────────────────────────
function BS.Notify(message, kind, title)
    TriggerEvent('brutal_notify:SendAlert', title or BSConfig.JobLabel, message, 5000, kind or 'info')
end

function BS.Dbg(message)
    if BSConfig.Debug then print(('[%s] %s'):format(BSConfig.Prefix, message)) end
end

-- ── Cache des données joueur ─────────────────────────────────────────────
local function ApplyPlayerData(data)
    if type(data) ~= 'table' then return end
    local previousJob = BS.Client.job
    BS.Client.job   = data.job
    BS.Client.grade = tonumber(data.job_grade) or 0
    if previousJob == BSConfig.Job and data.job ~= BSConfig.Job then
        -- Changement de métier : plus de service possible côté client non plus.
        BS.Client.onDuty = false
    end
    if BS.RefreshZones then BS.RefreshZones() end
end

CreateThread(function()
    -- Les items doivent rejoindre le registre client (libellés, poids,
    -- consommation) avant que l'inventaire ne soit ouvert. module/foodapi
    -- charge avant ce fichier dans lslegacy/fxmanifest.lua : appel direct.
    exports['lslegacy']:registerItems(BSConfig.Items)

    while true do
        if exports['lslegacy']:isLoaded() then
            ApplyPlayerData(exports['lslegacy']:getPlayerData())
            -- Un restart de la ressource ne doit pas faire croire au joueur
            -- qu'il est hors service alors que le serveur le sait en service.
            TriggerServerEvent(BSConfig.Prefix .. ':duty:request')
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
function BS.IsEmployee(minGrade)
    if BS.Client.job ~= BSConfig.Job then return false end
    return BS.Client.grade >= (minGrade or BSConfig.MinGrade)
end

function BS.CanUseStation(minGrade)
    if not BS.IsEmployee(minGrade) then return false end
    if BSConfig.Duty.required and not BS.Client.onDuty then return false end
    return true
end

-- ── Service ──────────────────────────────────────────────────────────────
RegisterNetEvent(BSConfig.Prefix .. ':duty:sync', function(onDuty)
    BS.Client.onDuty = onDuty and true or false
    BS.Dbg('service = ' .. tostring(BS.Client.onDuty))
    if BS.RefreshZones then BS.RefreshZones() end
end)

function BS.ToggleDuty()
    TriggerServerEvent(BSConfig.Prefix .. ':duty:toggle')
end

-- Prise/fin de service depuis le tableau de bord du MDT (tablette), pas de
-- zone physique. Le bouton du MDT (module/mdt) appelle ces deux exports par
-- leur nom, après qu'on se soit enregistré via registerClientDuty
-- (module/foodapi) — même mécanisme que ls_kebabking/client/main.lua.
-- SUFFIXÉS PAR LE JOB : ls_kebabking déclare les mêmes noms d'export dans
-- la même ressource lslegacy — sans suffixe le second écraserait le premier.
exports('toggleDuty_' .. BSConfig.Job, function() BS.ToggleDuty() end)
exports('isOnDuty_' .. BSConfig.Job, function() return BS.Client.onDuty end)

CreateThread(function()
    exports['lslegacy']:registerClientDuty(BSConfig.Job)
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
        BS.Dbg('modèle de prop introuvable : ' .. tostring(propCfg.model))
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
function BS.PlayCraftAnim(animKey, label, duration)
    local anim = animKey and BSConfig.Anims[animKey] or nil

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
    if not BSConfig.Blip.enabled then return end
    local blip = AddBlipForCoord(BSConfig.Blip.coords.x, BSConfig.Blip.coords.y, BSConfig.Blip.coords.z)
    SetBlipSprite(blip, BSConfig.Blip.sprite)
    SetBlipColour(blip, BSConfig.Blip.color)
    SetBlipScale(blip, BSConfig.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(BSConfig.Blip.label)
    EndTextCommandSetBlipName(blip)
end)

-- ── Debug / calibrage des coordonnées ────────────────────────────────────
-- Les positions du MLO ne peuvent pas être devinées hors du jeu : ces deux
-- commandes servent à les relever puis à les recopier dans config/config.lua.
CreateThread(function()
    if not BSConfig.Debug then return end

    RegisterCommand('bs_coords', function()
        local c = GetEntityCoords(PlayerPedId())
        local h = GetEntityHeading(PlayerPedId())
        local line = ('coords = vec3(%.2f, %.2f, %.2f), rotation = %.1f'):format(c.x, c.y, c.z, h)
        print(('[%s] %s'):format(BSConfig.Prefix, line))
        lib.setClipboard(line)
        BS.Notify('Coordonnées copiées dans le presse-papier.', 'success')
    end, false)

    RegisterCommand('bs_stations', function()
        for id, station in pairs(BSConfig.Stations) do
            print(('[%s] station %s -> %s'):format(BSConfig.Prefix, id, tostring(station.coords)))
        end
        for id, storage in pairs(BSConfig.Storages) do
            print(('[%s] stockage %s -> %s (actif: %s)'):format(BSConfig.Prefix, id, tostring(storage.coords), tostring(storage.enabled)))
        end
        BS.Notify(('Job détecté : %s (grade %d) — service : %s'):format(
            tostring(BS.Client.job), BS.Client.grade, tostring(BS.Client.onDuty)), 'info')
    end, false)

    -- Marqueurs au sol sur chaque point configuré, uniquement à proximité.
    CreateThread(function()
        local points = {}
        for id, s in pairs(BSConfig.Stations) do points[#points + 1] = { c = s.coords, r = 255, g = 140, b = 0, id = id } end
        for id, s in pairs(BSConfig.Storages) do
            if s.enabled then points[#points + 1] = { c = s.coords, r = 0, g = 160, b = 255, id = id } end
        end
        if BSConfig.Trays.enabled then
            for _, t in ipairs(BSConfig.Trays.list) do points[#points + 1] = { c = t.coords, r = 0, g = 220, b = 120, id = 'tray' .. t.id } end
        end
        if BSConfig.Cash.enabled then points[#points + 1] = { c = BSConfig.Cash.coords, r = 255, g = 60, b = 60, id = 'caisse' } end

        while BSConfig.Debug do
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
