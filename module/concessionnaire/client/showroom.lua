-- ═══════════════════════════════════════════════════════════════════
--  CONCESSIONNAIRE — Showroom (client)
--  Catalogue + recherche, aperçu caméra + stats, couleur, plaque perso,
--  essai (test-drive), revente. Chargé dans le contexte lslegacy.
-- ═══════════════════════════════════════════════════════════════════

local C = Config.Concessionnaire

local function Notify(msg, type)
    TriggerEvent(C.NotifyEvent, 'Concessionnaire', msg, 5000, type or 'info')
end

-- Retire les espaces de tête ET de fin (le jeu centre les plaques courtes)
local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
local function clamp(v) return math.max(0, math.min(100, math.floor(v + 0.5))) end

-- Sélection en cours (véhicule affiché en aperçu)
local sel = nil   -- { model, label, price, primary, secondary, plate, stats, back }

-- ── Prévisualisation : véhicule + caméra orbitale ────────────────────

local previewVeh    = nil
local previewCam    = nil
local previewActive = false

local function ClearPreview()
    previewActive = false
    if previewCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(previewCam, false)
        previewCam = nil
    end
    if previewVeh and DoesEntityExist(previewVeh) then
        DeleteEntity(previewVeh)
    end
    previewVeh = nil
    FreezeEntityPosition(PlayerPedId(), false)
end
Concessionnaire.ClearPreview = ClearPreview

local function ComputeStats(veh, hash)
    local kmh = GetVehicleEstimatedMaxSpeed(veh) * 3.6
    return {
        speed    = clamp(kmh / 300.0 * 100.0),
        speedKmh = math.floor(kmh + 0.5),
        accel    = clamp((GetVehicleModelAcceleration(hash) or 0.0) / 0.5 * 100.0),
        braking  = clamp((GetVehicleModelMaxBraking(hash) or 0.0) / 1.2 * 100.0),
    }
end

local function ShowPreview(model)
    ClearPreview()
    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then return end

    local p = C.Preview
    previewVeh = CreateVehicle(hash, p.coords.x, p.coords.y, p.coords.z, p.heading, false, false)
    SetEntityAsMissionEntity(previewVeh, true, true)
    SetVehicleOnGroundProperly(previewVeh)
    FreezeEntityPosition(previewVeh, true)
    SetVehicleDoorsLocked(previewVeh, 2)
    if sel then
        if sel.painted then
            SetVehicleColours(previewVeh, sel.primary, sel.secondary)
        elseif sel.baseP then                          -- couleur d'origine (occasion)
            SetVehicleColours(previewVeh, sel.baseP, sel.baseS)
        end
        sel.stats = ComputeStats(previewVeh, hash)
    end
    SetModelAsNoLongerNeeded(hash)

    -- Caméra orbitale
    previewActive = true
    local center = p.coords
    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, false, 0, true, true)
    FreezeEntityPosition(PlayerPedId(), true)

    Citizen.CreateThread(function()
        local angle = 0.0
        local closedTicks = 0
        while previewActive and previewCam do
            angle = (angle + 0.4) % 360.0
            local rad = math.rad(angle)
            SetCamCoord(previewCam,
                center.x + math.cos(rad) * 5.5,
                center.y + math.sin(rad) * 5.5,
                center.z + 1.3)
            PointCamAtCoord(previewCam, center.x, center.y, center.z + 0.2)

            -- Garde-fou : si plus aucun menu concess n'est ouvert (ESC dans
            -- un sous-menu), libérer la caméra pour ne pas rester bloqué.
            if lib.getOpenContextMenu then
                local open = lib.getOpenContextMenu()
                if not open or type(open) ~= 'string' or open:sub(1, 8) ~= 'concess_' then
                    closedTicks = closedTicks + 1
                    if closedTicks >= 10 then   -- ~200 ms sans menu
                        ClearPreview()
                        break
                    end
                else
                    closedTicks = 0
                end
            end
            Wait(20)
        end
    end)
end

-- ── Couleur (menus primaire / secondaire) ────────────────────────────

local function ApplyPreviewColor()
    if previewVeh and DoesEntityExist(previewVeh) then
        SetVehicleColours(previewVeh, sel.primary, sel.secondary)
    end
end

local function OpenColorMenu(which)
    local options = {}
    for _, col in ipairs(C.Colors) do
        options[#options + 1] = {
            title = col.label,
            icon = 'fa-solid fa-palette',
            onSelect = function()
                if which == 'primary' then sel.primary = col.id else sel.secondary = col.id end
                sel.painted = true              -- repeindre = payant
                ApplyPreviewColor()
                Concessionnaire.OpenVehicle()   -- retour à la fiche
            end,
        }
    end
    lib.registerContext({
        id = 'concess_color',
        title = (which == 'primary') and Lang.Concessionnaire.color_primary or Lang.Concessionnaire.color_secondary,
        menu = 'concess_vehicle',
        options = options,
    })
    lib.showContext('concess_color')
end

-- ── Plaque personnalisée (saisie) ────────────────────────────────────

local function AskCustomPlate()
    local input = lib.inputDialog(Lang.Concessionnaire.custom_plate_title, {
        {
            type = 'input',
            label = Lang.Concessionnaire.custom_plate_label,
            description = string.format(Lang.Concessionnaire.custom_plate_desc, C.CustomPlate.price, C.CustomPlate.maxLength),
            max = C.CustomPlate.maxLength,
        },
    })
    if input and input[1] and trim(input[1]) ~= '' then
        -- Cap à 8 (max GTA) + nettoyage A-Z 0-9
        local p = string.upper(trim(input[1])):gsub('[^A-Z0-9 ]', ''):sub(1, 8)
        sel.plate = (p ~= '') and p or nil
    else
        sel.plate = nil
    end
    Concessionnaire.OpenVehicle()
end

-- ── Paiement ─────────────────────────────────────────────────────────

-- Concessionnaire = carte bancaire uniquement (TPE via le menu de paiement
-- partagé, ouvert côté serveur une fois le prix revérifié).
local function SendBuy()
    local paint = sel.painted or false
    ClearPreview()
    lib.hideContext()
    if sel.occasionId then
        LSLegacy.SendEventToServer('concessionnaire:buyOccasion', {
            id        = sel.occasionId,
            paint     = paint,
            primary   = paint and sel.primary or nil,
            secondary = paint and sel.secondary or nil,
            plate     = sel.plate,
        })
    else
        LSLegacy.SendEventToServer('concessionnaire:buy', {
            model     = sel.model,
            paint     = paint,
            primary   = paint and sel.primary or nil,
            secondary = paint and sel.secondary or nil,
            plate     = sel.plate,   -- nil = plaque aléatoire
        })
    end
end

-- ── Fiche véhicule (aperçu + stats + options + achat) ────────────────

function Concessionnaire.OpenVehicle()
    local isOccasion = sel.occasionId ~= nil
    local st = sel.stats or { speed = 0, speedKmh = 0, accel = 0, braking = 0 }
    -- Occasion : achat tel quel, aucune modification (ni peinture ni plaque)
    local paintExtra = (not isOccasion and sel.painted) and C.PaintPrice or 0
    local plateExtra = (not isOccasion and sel.plate and C.CustomPlate.enabled) and C.CustomPlate.price or 0
    local total = sel.price + paintExtra + plateExtra

    local paintDesc = sel.painted
        and string.format(Lang.Concessionnaire.paint_applied, C.PaintPrice)
        or  Lang.Concessionnaire.paint_original

    local options = {
        { title = Lang.Concessionnaire.stat_speed, icon = 'fa-solid fa-gauge-high',
          progress = st.speed, colorScheme = 'red', description = st.speedKmh .. ' km/h' },
        { title = Lang.Concessionnaire.stat_accel, icon = 'fa-solid fa-forward',
          progress = st.accel, colorScheme = 'orange' },
        { title = Lang.Concessionnaire.stat_braking, icon = 'fa-solid fa-hand',
          progress = st.braking, colorScheme = 'blue' },
    }

    -- Peinture + plaque perso : véhicules NEUFS uniquement
    if not isOccasion then
        options[#options + 1] = { title = Lang.Concessionnaire.color_choose,
            description = paintDesc, icon = 'fa-solid fa-palette', arrow = true,
            onSelect = function() OpenColorMenu('primary') end }
        options[#options + 1] = { title = Lang.Concessionnaire.color_choose_2,
            description = paintDesc, icon = 'fa-solid fa-palette', arrow = true,
            onSelect = function() OpenColorMenu('secondary') end }
        if C.CustomPlate.enabled then
            options[#options + 1] = {
                title = Lang.Concessionnaire.custom_plate_menu,
                description = sel.plate and ('« ' .. sel.plate .. ' »  (+' .. C.CustomPlate.price .. ' $)') or Lang.Concessionnaire.custom_plate_none,
                icon = 'fa-solid fa-id-card', arrow = true,
                onSelect = AskCustomPlate,
            }
        end
    end

    if C.TestDrive.enabled then
        options[#options + 1] = {
            title = Lang.Concessionnaire.test_drive, icon = 'fa-solid fa-road',
            onSelect = function() Concessionnaire.StartTestDrive(sel.model) end,
        }
    end

    options[#options + 1] = {
        title = string.format(Lang.Concessionnaire.buy, total),
        icon = 'fa-solid fa-cart-shopping',
        onSelect = SendBuy,
    }

    lib.registerContext({
        id = 'concess_vehicle',
        title = sel.label,
        menu = sel.back,
        onExit = ClearPreview,
        options = options,
    })
    lib.showContext('concess_vehicle')
end

local function SelectVehicle(veh, backId)
    sel = { model = veh.model, label = veh.label, price = veh.price,
            primary = 0, secondary = 0, painted = false, baseP = nil, baseS = nil,
            plate = nil, stats = {}, back = backId, occasionId = nil }
    ShowPreview(veh.model)
    Concessionnaire.OpenVehicle()
end

-- Sélection d'une occasion (prix + couleur d'origine gratuite)
local function SelectOccasion(occ)
    local c1, c2 = tonumber(occ.color1) or 0, tonumber(occ.color2) or 0
    sel = { model = occ.model, label = occ.label .. Lang.Concessionnaire.occasion_tag,
            price = occ.price, primary = c1, secondary = c2, painted = false,
            baseP = c1, baseS = c2, plate = nil, stats = {}, back = 'concess_occasions',
            occasionId = occ.id }
    ShowPreview(occ.model)
    Concessionnaire.OpenVehicle()
end

-- ── Catégories + liste ───────────────────────────────────────────────

local function OpenCategory(catIndex)
    local cat = C.Catalog[catIndex]
    local options = {}
    for _, veh in ipairs(cat.vehicles) do
        options[#options + 1] = {
            title = veh.label, description = veh.price .. ' $',
            icon = 'fa-solid fa-car', arrow = true,
            onSelect = function() SelectVehicle(veh, 'concess_cat_' .. catIndex) end,
        }
    end
    lib.registerContext({ id = 'concess_cat_' .. catIndex, title = cat.category, menu = 'concess_catalog', options = options })
    lib.showContext('concess_cat_' .. catIndex)
end

-- ── Recherche / filtre par budget ────────────────────────────────────

local function OpenSearch()
    local input = lib.inputDialog(Lang.Concessionnaire.search_title, {
        { type = 'input',  label = Lang.Concessionnaire.search_name, required = false },
        { type = 'number', label = Lang.Concessionnaire.search_budget, required = false, min = 0 },
    })
    if not input then Concessionnaire.OpenCatalog() return end

    local query  = string.lower(trim(input[1]))
    local budget = tonumber(input[2])

    local results = {}
    for i, cat in ipairs(C.Catalog) do
        for _, veh in ipairs(cat.vehicles) do
            local okName   = (query == '') or string.find(string.lower(veh.label), query, 1, true) ~= nil
            local okBudget = (not budget) or veh.price <= budget
            if okName and okBudget then
                results[#results + 1] = {
                    title = veh.label, description = veh.price .. ' $ — ' .. cat.category,
                    icon = 'fa-solid fa-car', arrow = true,
                    onSelect = function() SelectVehicle(veh, 'concess_search') end,
                }
            end
        end
    end

    if #results == 0 then
        results[1] = { title = Lang.Concessionnaire.search_none, icon = 'fa-solid fa-ban', disabled = true }
    end

    lib.registerContext({ id = 'concess_search', title = Lang.Concessionnaire.search_results, menu = 'concess_catalog', options = results })
    lib.showContext('concess_search')
end

-- ── Catalogue racine ─────────────────────────────────────────────────

function Concessionnaire.OpenCatalog()
    local options = {
        { title = Lang.Concessionnaire.search_menu, description = Lang.Concessionnaire.search_hint,
          icon = 'fa-solid fa-magnifying-glass', arrow = true, onSelect = OpenSearch },
    }
    for i, cat in ipairs(C.Catalog) do
        options[#options + 1] = {
            title = cat.category, description = #cat.vehicles .. ' véhicule(s)',
            icon = 'fa-solid fa-list', arrow = true,
            onSelect = function() OpenCategory(i) end,
        }
    end
    lib.registerContext({ id = 'concess_catalog', title = Lang.Concessionnaire.catalog_title, options = options, onExit = ClearPreview })
    lib.showContext('concess_catalog')
end

-- ── Marché de l'occasion ─────────────────────────────────────────────

function Concessionnaire.OpenOccasions()
    if not C.Occasion.enabled then return end
    LSLegacy.SendEventToServer('concessionnaire:getOccasions')   -- réponse : concessionnaire:occasionsList
end

LSLegacy.RegisterClientEvent('concessionnaire:occasionsList', function(list)
    local options = {}
    if not list or #list == 0 then
        options[1] = { title = Lang.Concessionnaire.occasion_none, icon = 'fa-solid fa-ban', disabled = true }
    else
        for _, occ in ipairs(list) do
            options[#options + 1] = {
                title = occ.label,
                description = occ.price .. ' $ — occasion',
                icon = 'fa-solid fa-car-side', arrow = true,
                onSelect = function() SelectOccasion(occ) end,
            }
        end
    end
    lib.registerContext({ id = 'concess_occasions', title = Lang.Concessionnaire.occasion_title, options = options, onExit = ClearPreview })
    lib.showContext('concess_occasions')
end)

-- ── Essai (test-drive) ───────────────────────────────────────────────

local testVeh    = nil
local testActive = false

local function ClearTestDrive()
    testActive = false
    if testVeh and DoesEntityExist(testVeh) then
        DeleteEntity(testVeh)
    end
    testVeh = nil
end
Concessionnaire.ClearTestDrive = ClearTestDrive

local function EndTestDrive(reason)
    if not testActive and not testVeh then return end
    ClearTestDrive()
    local s = C.Seller.coords
    SetEntityCoords(PlayerPedId(), s.x + 2.0, s.y, s.z, false, false, false, false)
    Notify(reason or Lang.Concessionnaire.test_ended, 'info')
end
Concessionnaire.EndTestDrive = EndTestDrive

function Concessionnaire.StartTestDrive(model)
    if not C.TestDrive.enabled then return end
    if testActive then Notify(Lang.Concessionnaire.test_already, 'error') return end

    ClearPreview()
    lib.hideContext()

    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then Notify('Modèle introuvable.', 'error') return end

    local sp = C.TestDrive.spawn
    testVeh = CreateVehicle(hash, sp.x, sp.y, sp.z, sp.w, true, false)
    SetVehicleOnGroundProperly(testVeh)
    SetEntityAsMissionEntity(testVeh, true, true)
    SetVehicleNumberPlateText(testVeh, 'ESSAI')
    SetVehicleFuelLevel(testVeh, 100.0)
    TaskWarpPedIntoVehicle(PlayerPedId(), testVeh, -1)
    SetModelAsNoLongerNeeded(hash)

    testActive = true
    local endTime = GetGameTimer() + C.TestDrive.duration * 1000
    Notify(string.format(Lang.Concessionnaire.test_started, C.TestDrive.duration), 'success')

    Citizen.CreateThread(function()
        while testActive do
            local now  = GetGameTimer()
            local left = math.max(0, math.ceil((endTime - now) / 1000))
            if now >= endTime then EndTestDrive(Lang.Concessionnaire.test_timeout) break end

            local pos = GetEntityCoords(PlayerPedId())
            if #(pos - C.TestDrive.boundaryCenter) > C.TestDrive.boundaryRadius then
                EndTestDrive(Lang.Concessionnaire.test_outofbounds) break
            end

            -- Timer à l'écran
            SetTextFont(4)
            SetTextScale(0.5, 0.5)
            SetTextColour(255, 255, 255, 255)
            SetTextOutline()
            SetTextCentre(true)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(string.format(Lang.Concessionnaire.test_timer, math.floor(left / 60), left % 60))
            EndTextCommandDisplayText(0.5, 0.9)
            Wait(0)
        end
    end)
end

RegisterCommand('concess_test_stop', function()
    if testActive then EndTestDrive(Lang.Concessionnaire.test_stopped) end
end, false)
RegisterKeyMapping('concess_test_stop', 'Arrêter l\'essai (Concessionnaire)', 'keyboard', 'X')

-- ── Revente ──────────────────────────────────────────────────────────

function Concessionnaire.OpenResale()
    if not C.Resale.enabled then return end
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then Notify(Lang.Concessionnaire.resale_need_vehicle, 'error') return end

    local plate = trim(GetVehicleNumberPlateText(veh))
    Citizen.CreateThread(function()
        local confirm = lib.alertDialog({
            header   = Lang.Concessionnaire.resale_confirm_title,
            content  = string.format(Lang.Concessionnaire.resale_confirm_body, plate, math.floor(C.Resale.rate * 100)),
            centered = true,
            cancel   = true,
        })
        if confirm == 'confirm' then
            LSLegacy.SendEventToServer('concessionnaire:sell', { plate = plate })
        end
    end)
end
