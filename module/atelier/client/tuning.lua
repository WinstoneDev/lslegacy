-- Postes de tuning (touche E, comme demandé — pas de zone ox_target ici).
-- Un poste = un point fixe où le mécano, véhicule à proximité, ouvre la
-- page NUI dédiée (performance + esthétique + services). Les mods GTA sont
-- appliqués immédiatement à titre d'aperçu (natifs véhicule, syncés
-- nativement par FiveM) ; le panier ne facture qu'à la confirmation, et les
-- services (nettoyage/réparation) ne sont exécutés qu'après paiement validé
-- côté serveur (permission + facturation, cf. server/tuning.lua).

local tuningOpen  = false
local tuningVeh   = nil
local tuningVehNet = nil

-- Caméra libre autour du véhicule pendant le tuning (glisser-tourner + molette).
local tuningCam   = nil
local camHeading  = 0.0
local camPitch    = -15.0
local camDist     = 5.0

local function Notify(msg, type)
    TriggerEvent('notify', 'Atelier', msg, type or 'info', 5000)
end

local function FindNearestVehicle(coords, maxDist)
    local closest, closestDist = nil, maxDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local dist = #(coords - GetEntityCoords(veh))
        if dist < closestDist then
            closest     = veh
            closestDist = dist
        end
    end
    return closest
end

-- État courant du véhicule (pour préremplir la NUI)

-- GetModTextLabel/GetLabelText résolvent le vrai nom GTA de chaque palier
-- (ex: "Aileron Course" plutôt que "Niveau 2") — seule la carrosserie en a
-- besoin (Performance garde des paliers génériques, sans nom particulier).
local function GetLevelCategoryState(veh, categories, withNames)
    local out = {}
    for _, cat in ipairs(categories) do
        local level    = GetVehicleMod(veh, cat.modType)
        local maxLevel = GetNumVehicleMods(veh, cat.modType)
        local entry = { level = level, maxLevel = maxLevel }

        if withNames and maxLevel > 0 then
            local names = {}
            for lvl = 0, maxLevel - 1 do
                local label = GetModTextLabel(veh, cat.modType, lvl)
                local text  = label and label ~= '' and GetLabelText(label) or nil
                names[lvl + 1] = (text and text ~= '' and text ~= 'NULL') and text or ('Niv.' .. (lvl + 1))
            end
            entry.names = names
        end

        out[cat.id] = entry
    end
    return out
end

-- Extras (id 1-14) : seuls ceux qui existent réellement sur ce modèle
-- (DoesExtraExist) sont renvoyés — couvre nativement les extras propres aux
-- véhicules addon Gabz sans avoir à les lister modèle par modèle.
local function GetExtrasState(veh)
    local out = {}
    for i = 1, 14 do
        if DoesExtraExist(veh, i) then
            out[tostring(i)] = IsVehicleExtraTurnedOn(veh, i) == 1
        end
    end
    return out
end

local function GetVehicleTuningState(veh)
    local r, g, b = table.unpack(GetVehicleNeonLightsColour and { GetVehicleNeonLightsColour(veh) } or { 255, 0, 0 })

    -- SetVehicleModColor_1/_2 (natifs Los Santos Customs) plutôt que
    -- SetVehicleColours : gère la finition (normale/métallisée/mate/...) en
    -- plus de la couleur, et coexiste avec la couleur "cercle chromatique"
    -- (SetVehicleCustomPrimaryColour/_Secondary) via GetIsVehicle*ColourCustom.
    local paintType1, colorPrimary   = GetVehicleModColor_1(veh)
    local paintType2, colorSecondary = GetVehicleModColor_2(veh)
    local customPrimaryR, customPrimaryG, customPrimaryB       = GetVehicleCustomPrimaryColour(veh)
    local customSecondaryR, customSecondaryG, customSecondaryB = GetVehicleCustomSecondaryColour(veh)

    -- Certains véhicules addon (dont les customs EMS/police type gbemssteed)
    -- n'implémentent pas leurs livrées via le système classique
    -- (GET_VEHICLE_LIVERY_COUNT lit vehicles.meta) mais via le système de mods
    -- Los Santos Customs (mod type 48 = MOD_LIVERY_MODIFIER) : on retombe
    -- dessus si le système classique n'en trouve aucune.
    local livery, liveryCount = GetVehicleLivery(veh), GetVehicleLiveryCount(veh)
    if liveryCount <= 0 then
        local modCount = GetNumVehicleMods(veh, 48)
        if modCount > 0 then
            livery, liveryCount = GetVehicleMod(veh, 48), modCount
        end
    end

    return {
        performance = GetLevelCategoryState(veh, Config.Atelier.Tuning.Performance, false),
        bodykit     = GetLevelCategoryState(veh, Config.Atelier.Tuning.Bodykit, true),
        turboOn     = IsToggleModOn(veh, Config.Atelier.Tuning.Turbo.modType),
        wheelType   = GetVehicleWheelType(veh),
        wheelIndex  = GetVehicleMod(veh, 23),
        tint        = GetVehicleWindowTint(veh),
        livery      = livery,
        liveryCount = liveryCount,
        paint = {
            primary   = { type = paintType1, color = colorPrimary, custom = GetIsVehiclePrimaryColourCustom(veh) == true,
                          r = customPrimaryR, g = customPrimaryG, b = customPrimaryB },
            secondary = { type = paintType2, color = colorSecondary, custom = GetIsVehicleSecondaryColourCustom(veh) == true,
                          r = customSecondaryR, g = customSecondaryG, b = customSecondaryB },
        },
        neon = {
            front = IsVehicleNeonLightEnabled(veh, 0),
            back  = IsVehicleNeonLightEnabled(veh, 1),
            left  = IsVehicleNeonLightEnabled(veh, 2),
            right = IsVehicleNeonLightEnabled(veh, 3),
            r = r, g = g, b = b,
        },
        extras = GetExtrasState(veh),
    }
end

-- Mêmes 5 points d'échantillonnage que la restauration AP (persistentvehicles/
-- client/main.lua) — cohérence avec la seule autre partie du code qui manipule
-- déjà la déformation visuelle.
local DeformOffsets = {
    { x = 0.0,  y = 2.0,  z = 0.5 }, -- avant
    { x = 0.0,  y = -2.0, z = 0.5 }, -- arrière
    { x = 0.0,  y = 0.0,  z = 1.2 }, -- toit
    { x = -1.0, y = 0.0,  z = 0.5 }, -- gauche
    { x = 1.0,  y = 0.0,  z = 0.5 }, -- droite
}

-- Poser un mod (SetVehicleMod / SetVehicleModKit / ToggleVehicleMod...) répare
-- gratuitement le moteur, la carrosserie ET les cabosses visibles côté natif
-- GTA (effet de bord du jeu) — or `moteur`/`carrosserie_generale` sont
-- justement les deux composants calés sur GetVehicleEngineHealth/
-- GetVehicleBodyHealth (cf. shared/components.lua). On capture donc l'état
-- (santé + déformation visuelle) avant chaque appel natif et on le restaure
-- juste après, pour qu'installer une custom ne dispense jamais d'une
-- réparation payante — ni visuellement, ni sur les stats.
-- SetVehicleMod (et consorts) remet aussi le niveau de carburant natif à 100
-- (même effet de bord que sur santé moteur/carrosserie ci-dessus) : capturé
-- et restauré comme le reste pour ne jamais faire le plein gratuitement.
local function RestoreFuelLevel(veh, fuelLevel)
    if _G.SetSyncedFuelLevel then
        SetSyncedFuelLevel(veh, fuelLevel)
    else
        SetVehicleFuelLevel(veh, fuelLevel)
    end
end

local function PreserveDamage(veh, fn)
    if not veh or not DoesEntityExist(veh) then fn() return end

    -- Sans le contrôle réseau de l'entité, les natifs SetVehicle* posés par un
    -- client qui n'est qu'à côté du véhicule (pas dedans) ne se propagent pas
    -- forcément aux autres joueurs — cf. RepairVehicleFull/CleanVehicle plus bas.
    NetworkRequestControlOfEntity(veh)

    local engineHealth = GetVehicleEngineHealth(veh)
    local bodyHealth   = GetVehicleBodyHealth(veh)
    local dirtLevel    = GetVehicleDirtLevel(veh)
    local fuelLevel    = GetVehicleFuelLevel(veh)
    local burst = {}
    for i = 0, 5 do burst[i] = IsVehicleTyreBurst(veh, i, false) end

    local deformations = {}
    for _, offset in ipairs(DeformOffsets) do
        local deform = GetVehicleDeformationAtPos(veh, vector3(offset.x, offset.y, offset.z))
        local intensity = #(deform) * 5
        if intensity > 0.01 then
            deformations[#deformations + 1] = { offset = offset, intensity = intensity }
        end
    end

    fn()

    SetVehicleEngineHealth(veh, engineHealth)
    SetVehicleBodyHealth(veh, bodyHealth)
    SetVehicleDirtLevel(veh, dirtLevel)
    RestoreFuelLevel(veh, fuelLevel)
    for i = 0, 5 do
        if burst[i] then SetVehicleTyreBurst(veh, i, true, 1000.0) end
    end
    for _, d in ipairs(deformations) do
        SetVehicleDamage(veh, d.offset.x, d.offset.y, d.offset.z, d.intensity * 1000.0, 100.0, true)
    end
end

-- Nettoyage / réparation express — exécutés seulement après paiement validé.
-- Ici on VEUT que la réparation soit visible de tous : on prend le contrôle
-- réseau du véhicule avant d'agir pour que ça se propage correctement.

local function CleanVehicle(veh)
    NetworkRequestControlOfEntity(veh)
    SetVehicleDirtLevel(veh, 0.0)
end

-- Caméra libre

local function UpdateTuningCameraPosition()
    if not tuningCam or not tuningVeh then return end
    local vehCoords  = GetEntityCoords(tuningVeh) + vector3(0.0, 0.0, 0.9)
    local radHeading = math.rad(camHeading)
    local radPitch   = math.rad(camPitch)
    local flat       = math.cos(radPitch) * camDist
    local offset     = vector3(
        math.sin(radHeading) * flat,
        -math.cos(radHeading) * flat,
        math.sin(-radPitch) * camDist
    )
    local camCoords = vehCoords + offset
    SetCamCoord(tuningCam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(tuningCam, vehCoords.x, vehCoords.y, vehCoords.z)
end

local function StartTuningCamera(veh)
    local vehCoords    = GetEntityCoords(veh)
    local playerCoords = GetEntityCoords(PlayerPedId())
    camHeading = GetHeadingFromVector_2d(playerCoords.x - vehCoords.x, playerCoords.y - vehCoords.y)
    camPitch   = -15.0
    camDist    = 5.0

    tuningCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', vehCoords.x, vehCoords.y, vehCoords.z + 1.0, 0.0, 0.0, 0.0, 50.0, false, 0)
    SetCamActive(tuningCam, true)
    RenderScriptCams(true, false, 0, true, true)
    UpdateTuningCameraPosition()

    FreezeEntityPosition(PlayerPedId(), true)
    DisplayRadar(false)
end

local function StopTuningCamera()
    if tuningCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(tuningCam, false)
        tuningCam = nil
    end
    FreezeEntityPosition(PlayerPedId(), false)
    DisplayRadar(true)
end

-- Ouverture / fermeture NUI

local function CloseTuningNUI()
    if not tuningOpen then return end
    tuningOpen   = false
    tuningVeh    = nil
    tuningVehNet = nil
    StopTuningCamera()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'tuning:hide' })
end

local function OpenTuningNUI(veh)
    if tuningOpen then return end
    tuningOpen   = true
    tuningVeh    = veh
    tuningVehNet = NetworkGetNetworkIdFromEntity(veh)

    PreserveDamage(veh, function() SetVehicleModKit(veh, 0) end)
    StartTuningCamera(veh)

    local company = Config.Atelier.Companies[Atelier.CompanyId]

    SetNuiFocus(true, true)
    SendNUIMessage({
        action           = 'tuning:open',
        companyLabel     = company and company.label or 'Atelier',
        companyColor     = company and company.color or '#8b1a1a',
        catalog          = {
            performance = Config.Atelier.Tuning.Performance,
            bodykit     = Config.Atelier.Tuning.Bodykit,
            turbo       = Config.Atelier.Tuning.Turbo,
            services    = Config.Atelier.Tuning.Services,
            wheelTypes  = Config.Atelier.Tuning.WheelTypes,
            wheelPrice  = Config.Atelier.Tuning.WheelPrice,
            paintTypes  = Config.Atelier.Tuning.PaintTypes,
            paints      = Config.Atelier.Tuning.Paints,
            paintPrice  = Config.Atelier.Tuning.PaintPrice,
            customPaintPrice = Config.Atelier.Tuning.CustomPaintPrice,
            neonColors  = Config.Atelier.Tuning.NeonColors,
            neonPrice   = Config.Atelier.Tuning.NeonPrice,
            tints       = Config.Atelier.Tuning.Tints,
            tintPrice   = Config.Atelier.Tuning.TintPrice,
            liveryPrice = Config.Atelier.Tuning.LiveryPrice,
            extraPrice  = Config.Atelier.Tuning.ExtraPrice,
        },
        state            = GetVehicleTuningState(veh),
        canPerformance   = LSLegacy.Atelier.HasPermission(Atelier.CompanyId, Atelier.Grade, 'performance'),
        canCustomization = LSLegacy.Atelier.HasPermission(Atelier.CompanyId, Atelier.Grade, 'customization'),
        canMaintenance   = LSLegacy.Atelier.HasPermission(Atelier.CompanyId, Atelier.Grade, 'maintenance'),
    })
end

RegisterNUICallback('tuning:close', function(_, cb)
    CloseTuningNUI()
    cb('ok')
end)

-- Aperçus visuels immédiats (aucune facturation ici — le panier facture tout
-- d'un coup à la confirmation, cf. 'tuning:checkout' plus bas). Réutilisées
-- telles quelles par le panier pour annuler un choix (on rappelle le même
-- callback avec la valeur d'origine).

RegisterNUICallback('tuning:applyPerformance', function(data, cb)
    local veh = tuningVeh
    if veh and data.modType and data.level then
        PreserveDamage(veh, function() SetVehicleMod(veh, data.modType, data.level, false) end)
    end
    cb('ok')
end)

RegisterNUICallback('tuning:applyBodykit', function(data, cb)
    local veh = tuningVeh
    if veh and data.modType and data.level then
        PreserveDamage(veh, function() SetVehicleMod(veh, data.modType, data.level, false) end)
    end
    cb('ok')
end)

RegisterNUICallback('tuning:applyTurbo', function(data, cb)
    local veh = tuningVeh
    if veh then
        PreserveDamage(veh, function() ToggleVehicleMod(veh, Config.Atelier.Tuning.Turbo.modType, data.enabled == true) end)
    end
    cb('ok')
end)

RegisterNUICallback('tuning:previewWheelType', function(data, cb)
    local veh = tuningVeh
    if not veh or not data.typeId then cb({ count = 0 }) return end
    PreserveDamage(veh, function() SetVehicleWheelType(veh, data.typeId) end)
    cb({ count = GetNumVehicleMods(veh, 23) })
end)

RegisterNUICallback('tuning:applyWheelIndex', function(data, cb)
    local veh = tuningVeh
    if veh and data.index then
        PreserveDamage(veh, function() SetVehicleMod(veh, 23, data.index, false) end)
    end
    cb('ok')
end)

-- Peinture "palette" : type de finition + couleur native, natifs Los Santos
-- Customs (SetVehicleModColor_1/_2). Repasse aussi en mode palette si le
-- véhicule avait une couleur "cercle chromatique" active sur ce côté.
RegisterNUICallback('tuning:applyPaint', function(data, cb)
    local veh = tuningVeh
    if veh and data.slot and data.paintType and data.colorId then
        PreserveDamage(veh, function()
            if data.slot == 'primary' then
                ClearVehicleCustomPrimaryColour(veh)
                SetVehicleModColor_1(veh, data.paintType, data.colorId, 0)
            else
                ClearVehicleCustomSecondaryColour(veh)
                SetVehicleModColor_2(veh, data.paintType, data.colorId)
            end
        end)
    end
    cb('ok')
end)

-- Peinture "cercle chromatique" : couleur RGB précise, hors palette (option payante).
RegisterNUICallback('tuning:applyCustomPaint', function(data, cb)
    local veh = tuningVeh
    if veh and data.slot and data.r and data.g and data.b then
        PreserveDamage(veh, function()
            if data.slot == 'primary' then
                SetVehicleCustomPrimaryColour(veh, data.r, data.g, data.b)
            else
                SetVehicleCustomSecondaryColour(veh, data.r, data.g, data.b)
            end
        end)
    end
    cb('ok')
end)

RegisterNUICallback('tuning:applyNeon', function(data, cb)
    local veh = tuningVeh
    if veh and data.positions then
        SetVehicleNeonLightEnabled(veh, 0, data.positions.front == true)
        SetVehicleNeonLightEnabled(veh, 1, data.positions.back == true)
        SetVehicleNeonLightEnabled(veh, 2, data.positions.left == true)
        SetVehicleNeonLightEnabled(veh, 3, data.positions.right == true)
        if data.color then
            SetVehicleNeonLightsColour(veh, data.color.r, data.color.g, data.color.b)
        end
    end
    cb('ok')
end)

RegisterNUICallback('tuning:applyTint', function(data, cb)
    local veh = tuningVeh
    if veh and data.id then
        SetVehicleWindowTint(veh, data.id)
    end
    cb('ok')
end)

-- Motifs / livrées (SetVehicleLivery) — comme pour la carrosserie, on préserve
-- l'état de dégâts pour ne pas offrir une réparation gratuite via ce mod.
RegisterNUICallback('tuning:applyLivery', function(data, cb)
    local veh = tuningVeh
    if veh and data.index then
        -- Même bascule classique/mods qu'à la lecture (GetVehicleTuningState) :
        -- le véhicule n'a de vraies livrées que dans l'un des deux systèmes.
        if GetVehicleLiveryCount(veh) <= 0 and GetNumVehicleMods(veh, 48) > 0 then
            PreserveDamage(veh, function() SetVehicleMod(veh, 48, data.index, false) end)
        else
            PreserveDamage(veh, function() SetVehicleLivery(veh, data.index) end)
        end
    end
    cb('ok')
end)

RegisterNUICallback('tuning:applyExtra', function(data, cb)
    local veh = tuningVeh
    if veh and data.index then
        SetVehicleExtra(veh, data.index, data.enabled == true and 0 or 1) -- 0 = activé, 1 = désactivé
    end
    cb('ok')
end)

-- Caméra libre : glisser pour tourner, molette pour zoomer.

RegisterNUICallback('tuning:cameraOrbit', function(data, cb)
    if tuningCam and data then
        camHeading = (camHeading + (tonumber(data.dx) or 0.0)) % 360.0
        camPitch   = math.max(-80.0, math.min(40.0, camPitch + (tonumber(data.dy) or 0.0)))
        UpdateTuningCameraPosition()
    end
    cb('ok')
end)

RegisterNUICallback('tuning:cameraZoom', function(data, cb)
    if tuningCam and data then
        camDist = math.max(2.0, math.min(10.0, camDist + (tonumber(data.delta) or 0.0)))
        UpdateTuningCameraPosition()
    end
    cb('ok')
end)

-- Panier : un seul envoi serveur pour tout facturer, puis exécution locale
-- des services (nettoyage/réparation) uniquement si le paiement est validé.

RegisterNUICallback('tuning:checkout', function(data, cb)
    if tuningVehNet and data and type(data.items) == 'table' and #data.items > 0 then
        -- Le mécano n'est jamais assis dans le véhicule qu'il tune, donc le
        -- rapport périodique de persistentvehicles (qui n'émet que pour le
        -- conducteur) ne voit jamais les mods posés en aperçu. On force ce
        -- rapport ici, AVANT la demande de facturation, pour que la sauvegarde
        -- forcée déclenchée côté serveur juste après reflète bien l'état actuel.
        if tuningVeh and LSLegacy.AP and LSLegacy.AP.ReportVehicleStatus then
            LSLegacy.AP.ReportVehicleStatus(tuningVeh)
        end

        LSLegacy.Events.SendToServer('atelier:requestTuningCheckout', {
            vehNet          = tuningVehNet,
            items           = data.items,
            paymentMode     = data.paymentMode,
            discountPercent = data.discountPercent,
        })
    end
    cb('ok')
end)

LSLegacy.Events.Register('atelier:tuningCheckoutResult', function(data)
    if not data then return end

    if data.success then
        if tuningVeh and type(data.items) == 'table' then
            for _, item in ipairs(data.items) do
                if item.action == 'clean' then
                    CleanVehicle(tuningVeh)
                end
            end
        end

        -- La sauvegarde forcée elle-même est déclenchée côté serveur (server/tuning.lua),
        -- juste après validation du paiement — inutile de la redéclencher ici.

        Notify('Prestations ajoutées à la facture du client.', 'success')
    else
        Notify("Impossible de facturer ces prestations.", 'error')
    end

    SendNUIMessage({ action = 'tuning:checkoutDone', success = data.success == true })
end)

-- Boucle de présence sur les postes de tuning (E — IsControlJustPressed(0, 51))

CreateThread(function()
    while true do
        local sleep = 500
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for companyId, points in pairs(Config.Atelier.Tuning.Points) do
            if Atelier.CompanyId == companyId then
                for _, point in ipairs(points) do
                    local dist = #(coords - point)
                    if dist < Config.Atelier.Tuning.InteractDistance then
                        sleep = 0

                        if not tuningOpen and Atelier.OnDuty then
                            LSLegacy.DisplayInteract('Tuning')

                            if IsControlJustPressed(0, 51) then -- E
                                local veh = FindNearestVehicle(coords, Config.Atelier.Tuning.VehicleSearchRadius)
                                if veh then
                                    OpenTuningNUI(veh)
                                else
                                    Notify('Aucun véhicule à proximité.', 'error')
                                end
                            end
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        CloseTuningNUI()
    end
end)
