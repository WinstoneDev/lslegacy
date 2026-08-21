--  MODULE POLICE NATIONALE — Investigation / Preuves (client)
--  Collecte empreintes, ADN, sang, sécurisation scène de crime
--  Ciblage : ox_target (ALT sur un joueur) pour empreintes/ADN

local Investigation = {}
local activeScenes  = {}  -- { [sceneId] = { coords, blip, secured } }

local function Notify(msg, type)
    TriggerEvent(Config.Police.NotifyEvent, '🔬 PTS', msg, 5000, type or 'info')
end

-- Vérifie que le joueur est PTS ou a access aux preuves

local function CanInvestigate()
    if not LSLegacy.MDT.IsLocalLeoOnDuty() then return false end
    return LSLegacy.MDT.HasPermission('police', Police.GetGrade(), 'view_evidence')
end

-- Animation d'investigation

local function InvestigateAnim(duration)
    local dict = 'amb@world_human_cop_idles@male@idle_a'
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do Wait(100); t = t + 1 end
    TaskPlayAnim(PlayerPedId(), dict, 'idle_b', 8.0, -8.0, duration, 49, 0, false, false, false)
    Wait(duration)
    ClearPedTasks(PlayerPedId())
end

--  EMPREINTES DIGITALES

Investigation.CollectFingerprints = function(targetSrc)
    Notify(Lang.Police.inv_collect_fp, 'info')
    InvestigateAnim(4000)
    LSLegacy.SendEventToServer('police:inv:collectFingerprints', { target = targetSrc })
end

LSLegacy.RegisterClientEvent('police:inv:fingerprintsResult', function(data)
    if not data then return end
    if data.ref then
        Notify(string.format(Lang.Police.inv_fp_collected, data.ref), 'success')
    end
end)

LSLegacy.RegisterClientEvent('police:inv:fingerprintsMatch', function(data)
    if not data then return end
    if data.name then
        Notify(string.format(Lang.Police.inv_fp_identified, data.name), 'success')
    else
        Notify(Lang.Police.inv_fp_no_match, 'warning')
    end
end)

--  ADN

Investigation.CollectDNA = function(targetSrc)
    Notify(Lang.Police.inv_collect_dna, 'info')
    InvestigateAnim(5000)
    LSLegacy.SendEventToServer('police:inv:collectDNA', { target = targetSrc })
end

LSLegacy.RegisterClientEvent('police:inv:dnaResult', function(data)
    if not data then return end
    if data.ref then
        Notify(string.format(Lang.Police.inv_dna_collected, data.ref), 'success')
    end
end)

LSLegacy.RegisterClientEvent('police:inv:dnaMatch', function(data)
    if not data then return end
    if data.name then
        Notify(string.format(Lang.Police.inv_dna_identified, data.name), 'success')
    else
        Notify(Lang.Police.inv_dna_no_match, 'warning')
    end
end)

--  TRACES DE SANG (touche F11 — coordonnées actuelles, pas de cible)

Investigation.CollectBlood = function()
    if not CanInvestigate() then
        Notify(Lang.Police.inv_kit_required, 'error') return
    end

    local pos = GetEntityCoords(PlayerPedId())
    Notify(Lang.Police.inv_collect_blood, 'info')
    InvestigateAnim(3500)

    LSLegacy.SendEventToServer('police:inv:collectBlood', {
        x = pos.x, y = pos.y, z = pos.z,
        sceneId = GetNearestSceneId(),
    })
end

RegisterCommand('police_inv_blood', function()
    Investigation.CollectBlood()
end, false)

RegisterKeyMapping('police_inv_blood', 'Analyser une trace de sang (PTS)', 'keyboard', 'F11')

LSLegacy.RegisterClientEvent('police:inv:bloodResult', function(data)
    if not data then return end
    Notify(string.format(Lang.Police.inv_blood_collected, data.ref), 'success')
end)

--  SCÈNE DE CRIME (touche F12 — coordonnées actuelles, pas de cible)

function GetNearestSceneId()
    local pos   = GetEntityCoords(PlayerPedId())
    local range = 20.0
    for sceneId, scene in pairs(activeScenes) do
        if #(pos - scene.coords) < range then return sceneId end
    end
    return nil
end

Investigation.SecureScene = function()
    if not CanInvestigate() then
        Notify(Lang.Police.inv_kit_required, 'error') return
    end
    if not LSLegacy.MDT.HasPermission('police', Police.GetGrade(), 'manage_evidence') then
        Notify(Lang.Police.grade_required, 'error') return
    end

    local pos = GetEntityCoords(PlayerPedId())
    LSLegacy.SendEventToServer('police:inv:createScene', {
        x = pos.x, y = pos.y, z = pos.z,
    })
end

RegisterCommand('police_inv_secure_scene', function()
    if not LSLegacy.MDT.IsLocalLeoOnDuty() then return end
    Investigation.SecureScene()
end, false)

RegisterKeyMapping('police_inv_secure_scene', 'Sécuriser une scène de crime (PTS)', 'keyboard', 'F6')

LSLegacy.RegisterClientEvent('police:inv:sceneCreated', function(data)
    if not data then return end

    local coords = vector3(data.x, data.y, data.z)

    -- Blip scène de crime
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 310)
    SetBlipColour(blip, 49)
    SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Scène de crime #' .. data.sceneId)
    EndTextCommandSetBlipName(blip)

    activeScenes[data.sceneId] = {
        coords   = coords,
        blip     = blip,
        secured  = true,
    }

    Notify(Lang.Police.inv_scene_secured, 'success')

    -- Dessiner le marqueur de scène
    Citizen.CreateThread(function()
        local t = 0
        while activeScenes[data.sceneId] and t < 18000 do -- 30 min
            DrawMarker(
                27,
                coords.x, coords.y, coords.z,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                8.0, 8.0, 1.5,
                220, 50, 50, 60,
                false, true, 2, false, false, false, false
            )
            t = t + 1
            Wait(0)
        end
    end)
end)

LSLegacy.RegisterClientEvent('police:inv:sceneRemoved', function(data)
    if not data then return end
    if activeScenes[data.sceneId] then
        if activeScenes[data.sceneId].blip then
            RemoveBlip(activeScenes[data.sceneId].blip)
        end
        activeScenes[data.sceneId] = nil
    end
end)

--  CIBLAGE OX_TARGET — Empreintes / ADN (touche ALT sur un joueur)

exports.ox_target:addGlobalPlayer({
    {
        name = 'police_inv_fingerprints',
        icon = 'fa-solid fa-fingerprint',
        label = 'Relever empreintes',
        distance = 2.0,
        canInteract = function(entity) return CanInvestigate() and entity ~= PlayerPedId() end,
        onSelect = function(data)
            local targetSrc = GetServerIdFromPed(data.entity)
            if not targetSrc then return end
            Investigation.CollectFingerprints(targetSrc)
        end,
    },
    {
        name = 'police_inv_dna',
        icon = 'fa-solid fa-dna',
        label = 'Prélèvement ADN',
        distance = 2.0,
        canInteract = function(entity) return CanInvestigate() and entity ~= PlayerPedId() end,
        onSelect = function(data)
            local targetSrc = GetServerIdFromPed(data.entity)
            if not targetSrc then return end
            Investigation.CollectDNA(targetSrc)
        end,
    },
})
