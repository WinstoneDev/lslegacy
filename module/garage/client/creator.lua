--  MODULE GARAGE — Créateur RageUI (/garageCreator, groupe 2)
--  Création/édition : nom, type, propriétaire, points, places (fantôme orientable).
local C = Config.Garage
local mainMenu, formMenu   -- créés plus bas, référencés par les helpers

local function Notify(msg, t) TriggerEvent('notify', 'Garage Creator', msg, t or 'info', 5000) end

local function NewForm()
    return {
        id = nil, name = '', type = 'exterior', owner_type = 'personal',
        owner_id = nil, owner_name = nil, entrance = nil, heavy_entrance = nil, exit_spawn = nil,
        interior_spawn = nil, interior_exit = nil, slots = {}, blip = true, interior = nil,
    }
end

local Creator = {
    opened = false,
    form = NewForm(),
    typeIndex = 1, ownerIndex = 1, slotTypeIndex = 1,
    owners = { jobs = {}, factions = {} },
    ownerListIndex = 1,
    selected = nil,       -- garage sélectionné dans la liste
    confirmDelete = false,
    placing = false,
    inside = false,       -- dans l'instance de travail (bucket créateur)
    outsidePos = nil,     -- position à restaurer en sortant de l'instance
}

local function HereWithHeading()
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    return { x = p.x, y = p.y, z = p.z, h = GetEntityHeading(ped) }
end

local function Fmt(pt)
    if not pt then return 'non défini' end
    return ('%.1f, %.1f, %.1f'):format(pt.x, pt.y, pt.z)
end

local function TypeLabels()
    local t = {}
    for i, v in ipairs(C.GarageTypes) do t[i] = v.label end
    return t
end
local function OwnerLabels()
    local t = {}
    for i, v in ipairs(C.OwnerTypes) do t[i] = v.label end
    return t
end
local function SlotTypeLabels()
    local t = {}
    for i, v in ipairs(C.SlotTypes) do t[i] = v.label end
    return t
end

local function LoadForm(g)
    local f = NewForm()
    f.id = g.id; f.name = g.name; f.type = g.type; f.owner_type = g.owner_type
    f.owner_id = g.owner_id; f.owner_name = g.owner_name
    f.entrance = g.entrance; f.heavy_entrance = g.heavy_entrance; f.exit_spawn = g.exit_spawn
    f.interior_spawn = g.interior_spawn; f.interior_exit = g.interior_exit
    f.interior = g.interior
    f.slots = {}
    for i, s in ipairs(g.slots or {}) do f.slots[i] = { x = s.x, y = s.y, z = s.z, h = s.h, type = s.type } end
    f.blip = g.blip ~= false
    Creator.form = f
    for i, v in ipairs(C.GarageTypes) do if v.id == f.type then Creator.typeIndex = i end end
    for i, v in ipairs(C.OwnerTypes) do if v.id == f.owner_type then Creator.ownerIndex = i end end
end

local function InteriorLabel(id)
    local d = id and C.InteriorDef(id)
    return d and d.label or 'aucun'
end

local function Fade(coords, heading)
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(10) end
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    if heading then SetEntityHeading(ped, heading + 0.0) end
    Wait(400)
    DoScreenFadeIn(400)
end

-- ── Instance de travail : entrer / sortir d'un intérieur pendant la création ──
local function EnterCreatorInstance(coords, interiorId)
    if not Creator.inside then
        Creator.outsidePos = HereWithHeading()
        LSLegacy.Events.SendToServer('garage:creatorInstance', true)
        Creator.inside = true
    end
    if interiorId and not Garage.LoadInterior(interiorId) then
        Notify("Intérieur introuvable à ces coordonnées (IPL non chargé ?).", 'error')
    end
    Fade(coords, coords.h)
end

local function LeaveCreatorInstance()
    if not Creator.inside then return end
    Creator.inside = false
    LSLegacy.Events.SendToServer('garage:creatorInstance', false)
    local back = Creator.outsidePos or Creator.form.entrance
    Creator.outsidePos = nil
    if back then Fade(back, back.h) end
end

-- Prévisualisation d'un intérieur : caméra orbitale, E = choisir, Retour = annuler.
local function PreviewInterior(def)
    if Creator.placing then return end
    Creator.placing = true
    RageUI.CloseAll()
    local wasInside = Creator.inside
    local center = def.coords
    EnterCreatorInstance({ x = center.x, y = center.y, z = center.z, h = def.heading or 0.0 }, def.id)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)

    local yaw, pitch, radius = (def.heading or 0.0) + 90.0, 20.0, 9.0
    local look = vector3(center.x, center.y, center.z + 1.2)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 55.0)
    RenderScriptCams(true, true, 500, true, true)
    local chosen = false
    while true do
        Wait(0)
        DisableAllControlActions(0)
        EnableControlAction(0, 1, true) EnableControlAction(0, 2, true)
        yaw = yaw - GetDisabledControlNormal(0, 1) * C.CamSensitivity.yaw
        pitch = math.max(-10.0, math.min(70.0, pitch + GetDisabledControlNormal(0, 2) * C.CamSensitivity.pitch))
        if IsDisabledControlPressed(0, 241) then radius = math.max(2.0, radius - 0.3) end
        if IsDisabledControlPressed(0, 242) then radius = math.min(40.0, radius + 0.3) end
        local ry, rp = math.rad(yaw), math.rad(pitch)
        SetCamCoord(cam, look.x + radius * math.cos(rp) * math.cos(ry), look.y + radius * math.cos(rp) * math.sin(ry), look.z + radius * math.sin(rp))
        PointCamAtCoord(cam, look.x, look.y, look.z)
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName(('%s ~n~Souris : tourner  Molette : zoom ~n~~INPUT_CONTEXT~ : choisir cet intérieur ~n~~INPUT_CELLPHONE_CANCEL~ : annuler'):format(def.label))
        EndTextCommandDisplayHelp(0, false, false, -1)
        if IsDisabledControlJustReleased(0, 38) then chosen = true break end
        if IsDisabledControlJustReleased(0, 177) or IsDisabledControlJustReleased(0, 200) then break end
    end
    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(cam, false)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)

    if chosen then
        Creator.form.interior = def.id
        Notify(('Intérieur choisi : %s. Placez le spawn piéton, la sortie et les places.'):format(def.label), 'success')
    elseif not wasInside then
        LeaveCreatorInstance()
    end
    RageUI.Visible(formMenu, true)
    Creator.placing = false
end

-- ── Placement d'une place : véhicule fantôme orientable ───────────
local function PlaceSlot(slotType)
    if Creator.placing then return end
    Creator.placing = true
    local def = nil
    for _, s in ipairs(C.SlotTypes) do if s.id == slotType then def = s end end
    def = def or C.SlotTypes[1]
    local hash = GetHashKey(def.preview)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(50); t = t + 1 end
    if not HasModelLoaded(hash) then Creator.placing = false; return Notify('Modèle fantôme introuvable.', 'error') end

    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local ghost = CreateVehicle(hash, p.x, p.y, p.z, GetEntityHeading(ped), false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAlpha(ghost, 130, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    SetEntityInvincible(ghost, true)
    SetVehicleDoorsLocked(ghost, 2)

    local heading = GetEntityHeading(ped)
    local dist = 4.5
    local result = nil
    RageUI.CloseAll()

    while true do
        Wait(0)
        ped = PlayerPedId()
        p = GetEntityCoords(ped)
        local ph = GetEntityHeading(ped)
        local rad = math.rad(ph)
        local x = p.x - math.sin(rad) * dist
        local y = p.y + math.cos(rad) * dist
        local ok, gz = GetGroundZFor_3dCoord(x, y, p.z + 1.0, false)
        local z = ok and gz or p.z
        SetEntityCoordsNoOffset(ghost, x, y, z, false, false, false)
        SetEntityHeading(ghost, heading)

        DisableControlAction(0, 174, true) DisableControlAction(0, 175, true)
        DisableControlAction(0, 172, true) DisableControlAction(0, 173, true)
        if IsDisabledControlPressed(0, 174) then heading = (heading + 1.5) % 360 end   -- ←
        if IsDisabledControlPressed(0, 175) then heading = (heading - 1.5) % 360 end   -- →
        if IsDisabledControlPressed(0, 172) then dist = math.min(15.0, dist + 0.08) end -- ↑
        if IsDisabledControlPressed(0, 173) then dist = math.max(1.5, dist - 0.08) end  -- ↓

        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName(('Place %s ~n~~INPUT_CELLPHONE_LEFT~ ~INPUT_CELLPHONE_RIGHT~ : orientation (%d°) ~n~~INPUT_CELLPHONE_UP~ ~INPUT_CELLPHONE_DOWN~ : distance ~n~~INPUT_CONTEXT~ : valider  ~INPUT_CELLPHONE_CANCEL~ : annuler'):format(def.label, math.floor(heading)))
        EndTextCommandDisplayHelp(0, false, false, -1)

        if IsControlJustReleased(0, 38) then
            result = { x = x, y = y, z = z, h = heading, type = def.id }
            break
        end
        if IsControlJustReleased(0, 177) then break end
    end

    DeleteEntity(ghost)
    if result then
        Creator.form.slots[#Creator.form.slots + 1] = result
        Notify(('Place %d ajoutée (%s).'):format(#Creator.form.slots, def.label), 'success')
    end
    return result
end

-- Affichage des places du formulaire pendant l'édition
CreateThread(function()
    while true do
        local sleep = 1000
        if Creator.opened and #Creator.form.slots > 0 then
            sleep = 0
            local pos = GetEntityCoords(PlayerPedId())
            for i, s in ipairs(Creator.form.slots) do
                if #(pos - vector3(s.x, s.y, s.z)) < 60.0 then
                    DrawMarker(1, s.x, s.y, s.z - 0.5, 0, 0, 0, 0, 0, s.h or 0.0, 2.2, 4.5, 0.3, 40, 200, 90, 90, false, true, 2, false, nil, nil, false)
                    LSLegacy.DrawText3D(s.x, s.y, s.z + 0.8, ('Place %d (%s)'):format(i, s.type), 60.0)
                end
            end
            for _, key in ipairs({ 'entrance', 'heavy_entrance', 'exit_spawn', 'interior_spawn', 'interior_exit' }) do
                local pt = Creator.form[key]
                if pt and #(pos - vector3(pt.x, pt.y, pt.z)) < 60.0 then
                    LSLegacy.DrawText3D(pt.x, pt.y, pt.z + 0.5, key, 60.0)
                end
            end
        end
        Wait(sleep)
    end
end)

-- ── Menus ──────────────────────────────────────────────────────────
mainMenu   = RageUI.CreateMenu('Garage Creator', 'Création de garages')
formMenu   = RageUI.CreateSubMenu(mainMenu, 'Garage Creator', 'Formulaire')
local iplMenu    = RageUI.CreateSubMenu(formMenu, 'Garage Creator', 'Intérieurs IPL')
local ownerMenu  = RageUI.CreateSubMenu(formMenu, 'Garage Creator', 'Propriétaire')
local slotsMenu  = RageUI.CreateSubMenu(formMenu, 'Garage Creator', 'Places')
local listMenu   = RageUI.CreateSubMenu(mainMenu, 'Garage Creator', 'Garages existants')
local manageMenu = RageUI.CreateSubMenu(listMenu, 'Garage Creator', 'Gestion')
mainMenu:DisplayGlare(true)
mainMenu.Closed = function() if not Creator.placing then Creator.opened = false end end

local function Submit()
    local f = Creator.form
    local payload = {
        name = f.name, type = f.type, owner_type = f.owner_type, owner_id = f.owner_id, owner_name = f.owner_name,
        entrance = f.entrance, heavy_entrance = f.heavy_entrance, exit_spawn = f.exit_spawn, interior_spawn = f.interior_spawn, interior_exit = f.interior_exit,
        slots = f.slots, blip = f.blip, interior = f.interior,
    }
    if f.id then
        LSLegacy.Events.SendToServer('garage:update', f.id, payload)
    else
        LSLegacy.Events.SendToServer('garage:create', payload)
    end
end

local function PickNearbyPlayer()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local best, bestD = nil, 3.0
    for _, pid in ipairs(GetActivePlayers()) do
        local p = GetPlayerPed(pid)
        if p ~= ped then
            local d = #(pos - GetEntityCoords(p))
            if d < bestD then best, bestD = pid, d end
        end
    end
    return best and GetPlayerServerId(best) or GetPlayerServerId(PlayerId())
end

local function RenderForm()
    local f = Creator.form
    RageUI.Separator(f.id and ('Modification du garage #' .. f.id) or 'Nouveau garage')
    RageUI.Button('Nom : ' .. (f.name ~= '' and f.name or 'à définir'), nil, { RightLabel = '→' }, true, {
        onSelected = function()
            local r = LSLegacy.KeyboardInput('Nom du garage', 60)
            if r and r ~= '' then f.name = r end
        end,
    })
    RageUI.List('Type', TypeLabels(), Creator.typeIndex, nil, {}, true, {
        onListChange = function(i) Creator.typeIndex = i; f.type = C.GarageTypes[i].id end,
    })
    if f.type == 'interior' then
        RageUI.Button('Intérieur IPL : ' .. InteriorLabel(f.interior), 'Liste des intérieurs avec prévisualisation caméra.', { RightLabel = '→' }, true, {}, iplMenu)
        if Creator.inside then
            RageUI.Button("~o~Revenir à l'extérieur", "Retour à votre position d'avant l'entrée.", {}, true, {
                onSelected = LeaveCreatorInstance,
            })
        else
            local def = f.interior and C.InteriorDef(f.interior)
            local target = f.interior_spawn or (def and { x = def.coords.x, y = def.coords.y, z = def.coords.z, h = def.heading })
            RageUI.Button("~b~Aller dans l'intérieur", 'Instance privée pour placer markers et places.', {}, target ~= nil, {
                onSelected = function() EnterCreatorInstance(target, f.interior) end,
            })
        end
    end
    RageUI.List('Propriétaire', OwnerLabels(), Creator.ownerIndex, nil, {}, true, {
        onListChange = function(i)
            Creator.ownerIndex = i; f.owner_type = C.OwnerTypes[i].id
            f.owner_id = nil; f.owner_name = nil
        end,
    })
    if f.owner_type == 'personal' then
        RageUI.Button('Joueur : ' .. (f.owner_name or 'aucun'), 'Joueur le plus proche (3 m), sinon vous-même.', { RightLabel = '→' }, true, {
            onSelected = function()
                LSLegacy.Callbacks.TriggerServer('garage:getPlayerInfo', function(info)
                    if info then f.owner_id = tostring(info.charId); f.owner_name = info.name
                    else Notify('Joueur introuvable.', 'error') end
                end, PickNearbyPlayer())
            end,
        })
    elseif f.owner_type == 'job' or f.owner_type == 'faction' then
        RageUI.Button((f.owner_type == 'job' and 'Entreprise : ' or 'Organisation : ') .. (f.owner_name or 'aucune'), nil, { RightLabel = '→' }, true, {}, ownerMenu)
    end
    RageUI.Separator('↓ Points ↓')
    RageUI.Button("Entrée (marker) : " .. Fmt(f.entrance), 'Rangement / entrée à pied. Définit aussi le heading.', { RightLabel = 'Définir ici' }, true, {
        onSelected = function() f.entrance = HereWithHeading() end,
    })
    RageUI.Button("Entrée poids lourd : " .. Fmt(f.heavy_entrance), "Marker alternatif utilisé à la place de l'entrée standard quand le joueur conduit un poids lourd (place 'Poids lourd').", { RightLabel = 'Définir ici' }, true, {
        onSelected = function() f.heavy_entrance = HereWithHeading() end,
    })
    if f.type == 'interior' then
        RageUI.Button('Sortie véhicule (extérieur) : ' .. Fmt(f.exit_spawn), 'Où apparaît un véhicule sorti du garage.', { RightLabel = 'Définir ici' }, true, {
            onSelected = function() f.exit_spawn = HereWithHeading() end,
        })
        RageUI.Button('Spawn piéton (intérieur) : ' .. Fmt(f.interior_spawn), "Où arrive le joueur dans l'instance.", { RightLabel = 'Définir ici' }, true, {
            onSelected = function() f.interior_spawn = HereWithHeading() end,
        })
        RageUI.Button('Sortie piéton (intérieur) : ' .. Fmt(f.interior_exit), "Marker pour quitter l'instance.", { RightLabel = 'Définir ici' }, true, {
            onSelected = function() f.interior_exit = HereWithHeading() end,
        })
    end
    RageUI.Button(('Places : %d'):format(#f.slots), 'Ajouter / retirer des places.', { RightLabel = '→' }, true, {}, slotsMenu)
    RageUI.Checkbox('Blip sur la carte', nil, f.blip, {}, {
        onChecked = function() f.blip = true end, onUnChecked = function() f.blip = false end,
    })
    RageUI.Separator('')
    RageUI.Button(f.id and '~g~Enregistrer les modifications' or '~g~Créer le garage', nil, {}, true, {
        onSelected = function() Submit() end,
    })
end

local function RenderIpl()
    local f = Creator.form
    RageUI.Separator('Sélectionner = prévisualiser')
    for _, d in ipairs(C.Interiors) do
        RageUI.Button(d.label, Fmt(d.coords), { RightLabel = f.interior == d.id and '✔' or '' }, true, {
            onSelected = function() PreviewInterior(d) end,
        })
    end
end

local function RenderOwner()
    local f = Creator.form
    local list = f.owner_type == 'job' and Creator.owners.jobs or Creator.owners.factions
    if #list == 0 then RageUI.Separator('Aucune entrée') end
    for _, o in ipairs(list) do
        RageUI.Button(o.label, o.id, { RightLabel = f.owner_id == o.id and '✔' or '' }, true, {
            onSelected = function() f.owner_id = o.id; f.owner_name = o.label; RageUI.GoBack() end,
        })
    end
end

local function RenderSlots()
    local f = Creator.form
    RageUI.List('Type de place', SlotTypeLabels(), Creator.slotTypeIndex, nil, {}, true, {
        onListChange = function(i) Creator.slotTypeIndex = i end,
    })
    RageUI.Button('~b~Placer une place', 'Fantôme orientable : flèches, E pour valider.', {}, true, {
        onSelected = function()
            local st = C.SlotTypes[Creator.slotTypeIndex].id
            CreateThread(function()
                PlaceSlot(st)
                RageUI.Visible(slotsMenu, true)
                Wait(100)
                Creator.placing = false
            end)
        end,
    })
    RageUI.Button('Téléporter à la dernière place', nil, {}, #f.slots > 0, {
        onSelected = function()
            local s = f.slots[#f.slots]
            if s then SetEntityCoords(PlayerPedId(), s.x + 2.0, s.y, s.z) end
        end,
    })
    RageUI.Button('~r~Supprimer la dernière place', nil, {}, #f.slots > 0, {
        onSelected = function() table.remove(f.slots) end,
    })
    RageUI.Separator(('↓ %d place(s) ↓'):format(#f.slots))
    for i, s in ipairs(f.slots) do
        RageUI.Button(('Place %d - %s'):format(i, s.type), Fmt(s), { RightLabel = 'Supprimer' }, true, {
            onSelected = function() table.remove(f.slots, i) end,
        })
    end
end

local function RenderList()
    if #Garage.list == 0 then RageUI.Separator('Aucun garage') end
    for _, g in ipairs(Garage.list) do
        RageUI.Button(('#%d %s'):format(g.id, g.name), ('%s / %s%s - %d places'):format(g.type, g.owner_type, g.owner_name and (' : ' .. g.owner_name) or '', #(g.slots or {})), { RightLabel = '→' }, true, {
            onSelected = function() Creator.selected = g; Creator.confirmDelete = false end,
        }, manageMenu)
    end
end

local function RenderManage()
    local g = Creator.selected
    if not g then RageUI.Separator('Aucun garage sélectionné') return end
    RageUI.Separator(('#%d %s'):format(g.id, g.name))
    RageUI.Button("Téléporter à l'entrée", nil, {}, true, {
        onSelected = function() SetEntityCoords(PlayerPedId(), g.entrance.x, g.entrance.y, g.entrance.z) end,
    })
    if g.type == 'interior' and g.interior_spawn then
        RageUI.Button(Creator.inside and "~o~Revenir à l'extérieur" or "Téléporter à l'intérieur (instance créateur)", 'Utile pour replacer les places.', {}, true, {
            onSelected = function()
                if Creator.inside then LeaveCreatorInstance() else EnterCreatorInstance(g.interior_spawn, g.interior) end
            end,
        })
    end
    RageUI.Button('Modifier', nil, { RightLabel = '→' }, true, {
        onSelected = function() LoadForm(g) end,
    }, formMenu)
    if g.owner_type == 'job' then
        RageUI.Button('Ajouter un véhicule de flotte', 'Modèle spawn devant le garage, immatriculé au nom de l\'entreprise.', {}, true, {
            onSelected = function()
                local m = LSLegacy.KeyboardInput('Modèle du véhicule (spawn name)', 40)
                if m and m ~= '' then LSLegacy.Events.SendToServer('garage:addFleetVehicle', g.id, m) end
            end,
        })
    end
    if g.owner_type == 'personal' then
        RageUI.Button('Donner une clé de garage', 'Au joueur le plus proche (3 m), sinon vous-même.', {}, true, {
            onSelected = function() LSLegacy.Events.SendToServer('garage:giveKey', g.id, PickNearbyPlayer()) end,
        })
    end
    RageUI.Button(Creator.confirmDelete and '~r~Confirmer la suppression' or '~r~Supprimer', 'Les véhicules rangés sont libérés à l\'entrée.', {}, true, {
        onSelected = function()
            if Creator.confirmDelete then
                LSLegacy.Events.SendToServer('garage:delete', g.id)
                Creator.selected = nil; Creator.confirmDelete = false
                RageUI.GoBack()
            else
                Creator.confirmDelete = true
            end
        end,
    })
end

local function Open()
    if Creator.opened then
        Creator.opened = false
        RageUI.CloseAll()
        return
    end
    if RageUI.GetInMenu() then RageUI.CloseAll() end
    Creator.opened = true
    LSLegacy.Callbacks.TriggerServer('garage:getOwners', function(o) if o then Creator.owners = o end end)
    RageUI.Visible(mainMenu, true)
    CreateThread(function()
        while Creator.opened do
            RageUI.IsVisible(mainMenu, function()
                RageUI.Separator('↓ Création de garages ↓')
                RageUI.Button('Créer un garage', nil, { RightLabel = '→' }, true, {
                    onSelected = function() Creator.form = NewForm(); Creator.typeIndex = 1; Creator.ownerIndex = 1 end,
                }, formMenu)
                RageUI.Button(('Garages existants (%d)'):format(#Garage.list), nil, { RightLabel = '→' }, true, {}, listMenu)
            end)
            RageUI.IsVisible(formMenu, RenderForm)
            RageUI.IsVisible(iplMenu, RenderIpl)
            RageUI.IsVisible(ownerMenu, RenderOwner)
            RageUI.IsVisible(slotsMenu, RenderSlots)
            RageUI.IsVisible(listMenu, RenderList)
            RageUI.IsVisible(manageMenu, RenderManage)
            if not RageUI.GetInMenu() and not Creator.placing then Creator.opened = false end
            Wait(0)
        end
        if Creator.inside then LeaveCreatorInstance() end
    end)
end

LSLegacy.Events.Register('garageCreator:openMenu', Open)
