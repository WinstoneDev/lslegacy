-- =====================================================================
--  UTILITY KEYHANGER — Mode placement (admin)
--  Choix du support/accès puis aperçu temps réel avec accroche au mur
--  (raycast), rotation, hauteur et profondeur réglables.
-- =====================================================================

local C = KeyHanger.Config

local placing   = false
local previewObj = nil

-- Paramètres choisis avant placement
local cfg = {
    boardKey   = C.DefaultBoard,
    ownerType  = "personal",
    ownerId    = "",
    label      = "",
}

-- Index pour les menus liste
local boardKeys = {}
for k in pairs(C.Boards) do boardKeys[#boardKeys + 1] = k end
table.sort(boardKeys)

-- ---------------------------------------------------------------------
--  HELPERS
-- ---------------------------------------------------------------------

local function rotToDir(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function headingFromNormal(nx, ny)
    -- Oriente le support pour qu'il "regarde" vers la pièce (le long de la normale).
    local len = math.sqrt(nx * nx + ny * ny)
    if len < 0.001 then return GetEntityHeading(PlayerPedId()) end
    return math.deg(math.atan(-nx / len, ny / len))
end

local function destroyPreview()
    if previewObj and DoesEntityExist(previewObj) then DeleteEntity(previewObj) end
    previewObj = nil
end

-- ---------------------------------------------------------------------
--  APERÇU & VALIDATION
-- ---------------------------------------------------------------------

local function runPreview()
    placing = true
    local model = KeyHanger.GetBoardDef(cfg.boardKey).model
    local hash = KeyHanger.LoadModel(model)
    if not hash then
        placing = false
        return LSLegacy.ShowNotification(KeyHanger.L('title'), KeyHanger.L('placement_blocked'), 'error')
    end
    previewObj = CreateObjectNoOffset(hash, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(previewObj, 180, false)
    SetEntityCollision(previewObj, false, false)
    FreezeEntityPosition(previewObj, true)
    SetModelAsNoLongerNeeded(hash)

    local yawOffset    = 0.0
    local heightOffset = 0.0
    local depthOffset  = 0.0

    LSLegacy.ShowNotification(KeyHanger.L('title'), KeyHanger.L('placement_start'), 'info')

    CreateThread(function()
        while placing do
            Wait(0)

            -- Aide à l'écran
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(KeyHanger.L('placement_help'))
            EndTextCommandDisplayHelp(0, false, true, -1)

            -- Désactive les contrôles gênants
            DisableControlAction(0, 24, true)   -- attaque
            DisableControlAction(0, 25, true)   -- visée
            DisableControlAction(0, 14, true)   -- molette bas
            DisableControlAction(0, 15, true)   -- molette haut
            DisableControlAction(0, 16, true)
            DisableControlAction(0, 17, true)
            DisableControlAction(0, 140, true)  -- coup léger (mains nues)
            DisableControlAction(0, 141, true)  -- coup lourd
            DisableControlAction(0, 142, true)  -- coup alternatif
            DisableControlAction(0, 143, true)  -- esquive
            DisableControlAction(0, 257, true)  -- attaque 2
            DisableControlAction(0, 263, true)  -- mêlée 1
            DisableControlAction(0, 264, true)  -- mêlée 2

            -- Raycast depuis la caméra (poll jusqu'à obtention du résultat)
            local cam = GetGameplayCamCoord()
            local dir = rotToDir(GetGameplayCamRot(2))
            local dest = cam + dir * C.Placement.maxDistance
            local ray = StartShapeTestLosProbe(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 1 + 16, PlayerPedId(), 4)
            local retval, hit, endCoords, normal
            local tries = 0
            repeat
                retval, hit, endCoords, normal = GetShapeTestResult(ray)
                if retval == 1 then Wait(0) end
                tries = tries + 1
            until retval ~= 1 or tries > 8
            local didHit = (retval ~= 1) and (hit == true or hit == 1)

            local px, py, pz, heading
            if didHit and C.Placement.snapToWall then
                heading = headingFromNormal(normal.x, normal.y) + yawOffset
                -- léger décollement du mur le long de la normale + réglages
                local nlen = math.sqrt(normal.x * normal.x + normal.y * normal.y)
                local fx = (nlen > 0.001) and (normal.x / nlen) or 0.0
                local fy = (nlen > 0.001) and (normal.y / nlen) or 0.0
                px = endCoords.x + fx * (0.02 + depthOffset)
                py = endCoords.y + fy * (0.02 + depthOffset)
                pz = endCoords.z + heightOffset
            else
                -- placement libre devant le joueur
                local fwd = cam + dir * 1.6
                heading = GetEntityHeading(PlayerPedId()) + 180.0 + yawOffset
                px, py, pz = fwd.x, fwd.y, fwd.z + heightOffset
            end

            SetEntityCoords(previewObj, px, py, pz, false, false, false, false)
            SetEntityHeading(previewObj, heading % 360.0)

            -- Couleur indicative (vert = OK)
            SetEntityDrawOutline(previewObj, true)
            SetEntityDrawOutlineColor(80, 220, 120, 200)

            -- Molette : rotation ; SHIFT+molette : hauteur ; ALT+molette : profondeur
            local up   = IsDisabledControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 17)
            local down = IsDisabledControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 16)
            if up or down then
                local sign = up and 1 or -1
                if IsControlPressed(0, 21) then          -- LSHIFT -> hauteur
                    heightOffset = heightOffset + sign * C.Placement.heightStep
                elseif IsControlPressed(0, 19) then      -- LALT -> profondeur
                    depthOffset = depthOffset + sign * C.Placement.forwardStep
                else                                      -- rotation
                    yawOffset = yawOffset + sign * C.Placement.rotateStep
                end
            end

            -- Validation
            if IsControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 24) then -- Entrée / clic gauche
                placing = false
                destroyPreview()

                -- Demande le nom du support
                local label = LSLegacy.KeyboardInput(KeyHanger.L('placement_label_input'), 48)
                cfg.label = (label and label ~= "") and label or KeyHanger.GetBoardDef(cfg.boardKey).label

                -- Métier/Faction : demande l'identifiant
                if cfg.ownerType == "job" or cfg.ownerType == "faction" then
                    local owner = LSLegacy.KeyboardInput(KeyHanger.L('placement_owner_input'), 32)
                    cfg.ownerId = owner or ""
                end

                LSLegacy.SendEventToServer('keyhanger:create', {
                    board     = cfg.boardKey,
                    ownerType = cfg.ownerType,
                    ownerId   = cfg.ownerId,
                    label     = cfg.label,
                    coords    = { x = px, y = py, z = pz },
                    heading   = heading % 360.0,
                })
                break
            end

            -- Annulation
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) then -- Retour / Échap
                placing = false
                destroyPreview()
                LSLegacy.ShowNotification(KeyHanger.L('title'), KeyHanger.L('placement_cancelled'), 'error')
                break
            end
        end
    end)
end

-- ---------------------------------------------------------------------
--  MENU DE PRÉ-CONFIGURATION (type de support + accès)
-- ---------------------------------------------------------------------

local PMenu = RageUI.CreateMenu("Porte-clés", "Installation d'un porte-clés")
PMenu:DisplayGlare(true)

local boardIndex  = 1
local accessIndex = 1

local function boardLabels()
    local t = {}
    for _, k in ipairs(boardKeys) do t[#t + 1] = C.Boards[k].label end
    return t
end
local function accessLabels()
    local t = {}
    for _, a in ipairs(C.AccessTypes) do t[#t + 1] = a.label end
    return t
end

local function openPMenu()
    if RageUI.GetInMenu() then RageUI.CloseAll() end
    RageUI.Visible(PMenu, true)
    CreateThread(function()
        while RageUI.Visible(PMenu) do
            Wait(0)
            RageUI.IsVisible(PMenu, function()
                RageUI.Separator("↓ Nouveau porte-clés ↓")
                RageUI.List(KeyHanger.L('placement_choose_board'), boardLabels(), boardIndex, nil, {}, true, {
                    onListChange = function(Index) boardIndex = Index end,
                })
                RageUI.List(KeyHanger.L('placement_access_input'), accessLabels(), accessIndex, nil, {}, true, {
                    onListChange = function(Index) accessIndex = Index end,
                })
                RageUI.Line()
                RageUI.Button("Placer le support", "Passe en mode aperçu pour viser un mur", { RightLabel = "→" }, true, {
                    onSelected = function()
                        cfg.boardKey  = boardKeys[boardIndex]
                        cfg.ownerType = C.AccessTypes[accessIndex].value
                        RageUI.CloseAll()
                        runPreview()
                    end,
                })
            end)
        end
    end)
end

-- ---------------------------------------------------------------------
--  ENTRÉE : déclenchée par la commande serveur
-- ---------------------------------------------------------------------

LSLegacy.RegisterClientEvent('keyhanger:placement:start', function()
    if placing then return end
    openPMenu()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    destroyPreview()
end)
