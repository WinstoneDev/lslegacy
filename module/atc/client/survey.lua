-- Outil de relevé ATC (RageUI) : enregistre position + cap du joueur, typé et nommé, avec rendu 3D des points.
-- Nœuds de taxiway numérotés automatiquement dans le groupe courant (A -> A1, A2...). Touche rapide : INSERT.

local CFG = Config.ATC.Survey
local S = { opened = false, points = {}, typeIndex = 1, group = 'A', runway = '', note = '' }

local function Notify(msg, t) TriggerEvent('notify', 'Relevé ATC', msg, t or 'info', 4000) end

local function TypeLabels()
    local out = {}
    for i, t in ipairs(CFG.Types) do out[i] = t.label end
    return out
end
local function CurrentType() return CFG.Types[S.typeIndex].id end

local function Sync() LSLegacy.Events.SendToServer('atc:survey:sync', S.points) end

local function NextIndexInGroup(group)
    local n = 0
    for _, pt in ipairs(S.points) do
        if pt.type == 'taxiway' and pt.group == group then n = n + 1 end
    end
    return n + 1
end

local function AddPoint()
    if #S.points >= CFG.MaxPoints then return Notify('Limite de points atteinte', 'error') end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then h = GetEntityHeading(veh) end
    local t = CurrentType()
    local id
    if t == 'taxiway' then
        id = S.group .. NextIndexInGroup(S.group)
    else
        id = LSLegacy.KeyboardInput('Identifiant du point (ex : HP_D1, EXIT_12R_1, C3)', 32)
        if not id or id == '' then return end
    end
    S.points[#S.points + 1] = {
        type = t, id = id, group = S.group, note = S.note,
        x = c.x, y = c.y, z = c.z, h = h,
    }
    Sync()
    Notify(('%s enregistré (%.1f, %.1f, %.1f / %.0f°)'):format(id, c.x, c.y, c.z, h), 'success')
end

local function RemoveLast()
    if #S.points == 0 then return end
    local pt = table.remove(S.points)
    Sync()
    Notify(pt.id .. ' supprimé', 'info')
end

local function RemoveAt(i)
    local pt = table.remove(S.points, i)
    if pt then Sync(); Notify(pt.id .. ' supprimé', 'info') end
end

-- Libellé à échelle fixe, ignoré hors écran ou sous les pieds du joueur (le helper Core explose à courte distance).
local function DrawLabel(p, text)
    local onScreen, sx, sy = World3dToScreen2d(p.x, p.y, p.z + 0.6)
    if not onScreen then return end
    local d = #(GetGameplayCamCoords() - p)
    if d < 1.5 then return end
    local scale = math.max(0.22, math.min(0.45, 8.0 / d))
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(sx, sy)
end

-- Rendu : marker + libellé, trait entre nœuds consécutifs d'un même taxiway.
CreateThread(function()
    while true do
        local sleep = 1000
        if S.opened and #S.points > 0 then
            sleep = 0
            local pos = GetEntityCoords(PlayerPedId())
            local lastOfGroup = {}
            for _, pt in ipairs(S.points) do
                local p = vector3(pt.x, pt.y, pt.z)
                if #(pos - p) < CFG.DrawDistance then
                    local r, g, b = 255, 255, 255
                    if pt.type == 'taxiway' then r, g, b = 255, 210, 0
                    elseif pt.type == 'holding' then r, g, b = 255, 60, 60
                    elseif pt.type == 'exit' then r, g, b = 60, 200, 255
                    elseif pt.type == 'stand' then r, g, b = 60, 255, 120
                    elseif pt.type == 'intersection' then r, g, b = 255, 140, 0 end
                    DrawMarker(28, p.x, p.y, p.z - 0.8, 0, 0, 0, 0, 0, 0, 0.4, 0.4, 0.4, r, g, b, 160, false, false, 2, false, nil, nil, false)
                    DrawLabel(p, pt.id)
                    if pt.type == 'taxiway' then
                        local prev = lastOfGroup[pt.group]
                        if prev then DrawLine(prev.x, prev.y, prev.z - 0.6, p.x, p.y, p.z - 0.6, 255, 210, 0, 200) end
                    end
                end
                if pt.type == 'taxiway' then lastOfGroup[pt.group] = pt end
            end
        end
        Wait(sleep)
    end
end)

-- Menus
local mainMenu = RageUI.CreateMenu('Relevé ATC', 'LSIA — collecte de points')
local listMenu = RageUI.CreateSubMenu(mainMenu, 'Relevé ATC', 'Points relevés')
mainMenu.Closed = function() S.opened = false end

local function RenderMain()
    RageUI.Separator(('↓ %d point(s) ↓'):format(#S.points))
    RageUI.List('Type', TypeLabels(), S.typeIndex, 'Nature du point à relever.', {}, true, {
        onListChange = function(i) S.typeIndex = i end,
    })
    RageUI.Button('Taxiway / groupe : ' .. S.group, 'Lettre du taxiway courant ; les nœuds sont numérotés automatiquement.', { RightLabel = '→' }, true, {
        onSelected = function()
            local r = LSLegacy.KeyboardInput('Lettre ou nom du taxiway', 8)
            if r and r ~= '' then S.group = r:upper() end
        end,
    })
    RageUI.Button('Remarque : ' .. (S.note ~= '' and S.note or 'aucune'), 'Ajoutée à chaque point relevé (ex : piste concernée, sens unique).', { RightLabel = '→' }, true, {
        onSelected = function() S.note = LSLegacy.KeyboardInput('Remarque', 64) or '' end,
    })
    RageUI.Separator('')
    RageUI.Button('~g~Relever un point ici', 'Position + cap du joueur (ou du véhicule). Touche INSERT hors menu.', {}, true, { onSelected = AddPoint })
    RageUI.Button('~r~Supprimer le dernier point', nil, {}, #S.points > 0, { onSelected = RemoveLast })
    RageUI.Button('Points relevés', nil, { RightLabel = '→' }, #S.points > 0, {}, listMenu)
    RageUI.Separator('')
    RageUI.Button('Fichier : ' .. CFG.File, 'Sauvegarde automatique côté serveur à chaque modification.', {}, false, {})
end

local function RenderList()
    for i = #S.points, 1, -1 do
        local pt = S.points[i]
        RageUI.Button(('%s [%s]'):format(pt.id, pt.type), ('%.1f, %.1f, %.1f / %.0f°%s'):format(pt.x, pt.y, pt.z, pt.h, pt.note ~= '' and (' — ' .. pt.note) or ''), { RightLabel = 'TP / ⌫' }, true, {
            onSelected = function() SetEntityCoords(PlayerPedId(), pt.x, pt.y, pt.z, false, false, false, false) end,
            onActive = function()
                if IsControlJustPressed(0, 194) then RemoveAt(i) end -- Backspace
            end,
        })
    end
end

local function Open()
    if S.opened then return end
    S.opened = true
    LSLegacy.Events.SendToServer('atc:survey:load')
    RageUI.Visible(mainMenu, true)
    CreateThread(function()
        while S.opened do
            RageUI.IsVisible(mainMenu, RenderMain)
            RageUI.IsVisible(listMenu, RenderList)
            Wait(0)
        end
    end)
end

LSLegacy.Events.Register('atcsurvey:openMenu', Open)
LSLegacy.Events.Register('atc:survey:data', function(list)
    if type(list) == 'table' then S.points = list end
end)

RegisterCommand('atcsurvey_add', function()
    if S.opened then AddPoint() end
end, false)
RegisterKeyMapping('atcsurvey_add', 'Relever un point (Relevé ATC)', 'keyboard', 'INSERT')
