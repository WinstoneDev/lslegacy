-- ls_aldentes (client) — état local, service, blip, animations, debug.
-- Le client n'est jamais autoritatif : tout ce qui est ici sert à l'affichage
-- et au confort. Chaque action est revalidée côté serveur.

ALD = ALD or {}
ALD.Client = {
    job     = nil,
    grade   = 0,
    onDuty  = false,
    busy    = false,   -- une action (progressbar) est en cours
}

-- ── Notifications ────────────────────────────────────────────────────────
function ALD.Notify(message, kind, title)
    TriggerEvent('brutal_notify:SendAlert', title or ALDConfig.JobLabel, message, 5000, kind or 'info')
end

function ALD.Dbg(message)
    if ALDConfig.Debug then print(('[%s] %s'):format(ALDConfig.Prefix, message)) end
end

-- ── Cache des données joueur ─────────────────────────────────────────────
local function ApplyPlayerData(data)
    if type(data) ~= 'table' then return end
    local previousJob = ALD.Client.job
    ALD.Client.job   = data.job
    ALD.Client.grade = tonumber(data.job_grade) or 0
    if previousJob == ALDConfig.Job and data.job ~= ALDConfig.Job then
        -- Changement de métier : plus de service possible côté client non plus.
        ALD.Client.onDuty = false
    end
end

CreateThread(function()
    -- Les items doivent rejoindre le registre client (libellés, poids,
    -- consommation) avant que l'inventaire ne soit ouvert. module/foodapi
    -- charge avant ce fichier dans lslegacy/fxmanifest.lua : appel direct.
    exports['lslegacy']:registerItems(ALDConfig.Items)

    while true do
        if exports['lslegacy']:isLoaded() then
            ApplyPlayerData(exports['lslegacy']:getPlayerData())
            -- Un restart de la ressource ne doit pas faire croire au joueur
            -- qu'il est hors service alors que le serveur le sait en service.
            TriggerServerEvent(ALDConfig.Prefix .. ':duty:request')
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
function ALD.IsEmployee(minGrade)
    if ALD.Client.job ~= ALDConfig.Job then return false end
    return ALD.Client.grade >= (minGrade or ALDConfig.MinGrade)
end

function ALD.CanUseStation(minGrade)
    if not ALD.IsEmployee(minGrade) then return false end
    if ALDConfig.Duty.required and not ALD.Client.onDuty then return false end
    return true
end

-- ── Service ──────────────────────────────────────────────────────────────
RegisterNetEvent(ALDConfig.Prefix .. ':duty:sync', function(onDuty)
    ALD.Client.onDuty = onDuty and true or false
    ALD.Dbg('service = ' .. tostring(ALD.Client.onDuty))
end)

function ALD.ToggleDuty()
    TriggerServerEvent(ALDConfig.Prefix .. ':duty:toggle')
end

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
        ALD.Dbg('modèle de prop introuvable : ' .. tostring(propCfg.model))
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
function ALD.PlayCraftAnim(animKey, label, duration)
    local anim = animKey and ALDConfig.Anims[animKey] or nil

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
    if not ALDConfig.Blip.enabled then return end
    local blip = AddBlipForCoord(ALDConfig.Blip.coords.x, ALDConfig.Blip.coords.y, ALDConfig.Blip.coords.z)
    SetBlipSprite(blip, ALDConfig.Blip.sprite)
    SetBlipColour(blip, ALDConfig.Blip.color)
    SetBlipScale(blip, ALDConfig.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(ALDConfig.Blip.label)
    EndTextCommandSetBlipName(blip)
end)

-- ── Debug / calibrage des coordonnées ────────────────────────────────────
-- Les positions du MLO ne peuvent pas être devinées hors du jeu : ces deux
-- commandes servent à les relever puis à les recopier dans config/config.lua.
CreateThread(function()
    if not ALDConfig.Debug then return end

    RegisterCommand('ald_coords', function()
        local c = GetEntityCoords(PlayerPedId())
        local h = GetEntityHeading(PlayerPedId())
        local line = ('coords = vec3(%.2f, %.2f, %.2f), rotation = %.1f'):format(c.x, c.y, c.z, h)
        print(('[%s] %s'):format(ALDConfig.Prefix, line))
        lib.setClipboard(line)
        ALD.Notify('Coordonnées copiées dans le presse-papier.', 'success')
    end, false)

    RegisterCommand('ald_stations', function()
        for id, station in pairs(ALDConfig.Stations) do
            print(('[%s] station %s -> %s'):format(ALDConfig.Prefix, id, tostring(station.coords)))
        end
        for id, storage in pairs(ALDConfig.Storages) do
            print(('[%s] stockage %s -> %s (actif: %s)'):format(ALDConfig.Prefix, id, tostring(storage.coords), tostring(storage.enabled)))
        end
        ALD.Notify(('Job détecté : %s (grade %d) — service : %s'):format(
            tostring(ALD.Client.job), ALD.Client.grade, tostring(ALD.Client.onDuty)), 'info')
    end, false)

    -- Marqueurs au sol sur chaque point configuré, uniquement à proximité.
    CreateThread(function()
        local points = {}
        for id, s in pairs(ALDConfig.Stations) do points[#points + 1] = { c = s.coords, r = 255, g = 140, b = 0, id = id } end
        for id, s in pairs(ALDConfig.Storages) do
            if s.enabled then points[#points + 1] = { c = s.coords, r = 0, g = 160, b = 255, id = id } end
        end
        if ALDConfig.Trays.enabled then
            for _, t in ipairs(ALDConfig.Trays.list) do points[#points + 1] = { c = t.coords, r = 0, g = 220, b = 120, id = 'tray' .. t.id } end
        end
        if ALDConfig.Cash.enabled then points[#points + 1] = { c = ALDConfig.Cash.coords, r = 255, g = 60, b = 60, id = 'caisse' } end
        points[#points + 1] = { c = ALDConfig.Duty.coords, r = 255, g = 255, b = 0, id = 'pointeuse' }

        while ALDConfig.Debug do
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
