--  MODULE GARAGE — Fenêtre flottante au-dessus des véhicules garés + mode showroom
local C = Config.Garage
local hudShown = false
local showroomActive = false

local function Trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
local function Pct(v) return math.floor(math.max(0, math.min(100, (v or 0) / 10)) + 0.5) end

local function ModLevel(veh, modType)
    local max = GetNumVehicleMods(veh, modType)
    local cur = GetVehicleMod(veh, modType) + 1
    return cur, max
end

local function Stats(veh)
    local st = Garage.vehicles[veh] or {}
    local fuel = Entity(veh).state.fuelLevel or 0
    local eng, engMax = ModLevel(veh, 11)
    local brk, brkMax = ModLevel(veh, 12)
    local trs, trsMax = ModLevel(veh, 13)
    local sus, susMax = ModLevel(veh, 15)
    local arm, armMax = ModLevel(veh, 16)
    return {
        name = Garage.ModelLabel(GetEntityModel(veh)),
        plate = Trim(GetVehicleNumberPlateText(veh)),
        slot = st.slot,
        engine = Pct(GetVehicleEngineHealth(veh)),
        body = Pct(GetVehicleBodyHealth(veh)),
        fuel = math.floor((fuel or 0) + 0.5),
        mods = {
            { label = 'Moteur', cur = eng, max = engMax },
            { label = 'Freins', cur = brk, max = brkMax },
            { label = 'Transmission', cur = trs, max = trsMax },
            { label = 'Suspension', cur = sus, max = susMax },
            { label = 'Blindage', cur = arm, max = armMax },
        },
        turbo = IsToggleModOn(veh, 18),
        dirt = math.floor(GetVehicleDirtLevel(veh) / 15 * 100 + 0.5),
    }
end

CreateThread(function()
    while true do
        local sleep = 500
        if next(Garage.vehicles) and not showroomActive then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local cands = {}
            for veh in pairs(Garage.vehicles) do
                if DoesEntityExist(veh) then
                    local d = #(pos - GetEntityCoords(veh))
                    if d < C.HudDistance then cands[#cands + 1] = { veh = veh, d = d } end
                end
            end
            if #cands > 0 then
                sleep = 0
                table.sort(cands, function(a, b) return a.d < b.d end)
                local items = {}
                for i = 1, math.min(#cands, C.HudMaxVehicles) do
                    local veh = cands[i].veh
                    local vpos = GetEntityCoords(veh)
                    local _, max = GetModelDimensions(GetEntityModel(veh))
                    local ok, sx, sy = GetScreenCoordFromWorldCoord(vpos.x, vpos.y, vpos.z + max.z + 0.4)
                    if ok then
                        local s = Stats(veh)
                        s.id = veh; s.x = sx; s.y = sy; s.scale = math.max(0.8, 1.0 - cands[i].d / C.HudDistance * 0.3)
                        items[#items + 1] = s
                    end
                end
                SendNUIMessage({ action = 'garage:hud', items = items })
                hudShown = #items > 0
            elseif hudShown then
                SendNUIMessage({ action = 'garage:hud', items = {} })
                hudShown = false
            end
        elseif hudShown then
            SendNUIMessage({ action = 'garage:hud', items = {} })
            hudShown = false
        end
        Wait(sleep)
    end
end)

-- ── Showroom : caméra orbitale + fiche détaillée ──────────────────
function Garage.Showroom(veh)
    if showroomActive or not DoesEntityExist(veh) then return end
    showroomActive = true
    SendNUIMessage({ action = 'garage:hud', items = {} })
    hudShown = false

    local min, max = GetModelDimensions(GetEntityModel(veh))
    local radius = math.max(4.0, #(max - min) * 0.9)
    local center = GetEntityCoords(veh) + vector3(0, 0, (max.z - min.z) * 0.35)
    local yaw, pitch = GetEntityHeading(veh) + 135.0, 12.0
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 45.0)
    RenderScriptCams(true, true, 600, true, true)
    SendNUIMessage({ action = 'garage:showroom', show = true, stats = Stats(veh) })

    local lastStats = GetGameTimer()
    while showroomActive and DoesEntityExist(veh) and Garage.vehicles[veh] do
        DisableAllControlActions(0)
        EnableControlAction(0, 1, true)
        EnableControlAction(0, 2, true)
        local dx = GetDisabledControlNormal(0, 1)
        local dy = GetDisabledControlNormal(0, 2)
        yaw = yaw - dx * C.CamSensitivity.yaw
        pitch = math.max(-5.0, math.min(60.0, pitch + dy * C.CamSensitivity.pitch))
        if IsDisabledControlPressed(0, 241) then radius = math.max(2.5, radius - 0.25) end
        if IsDisabledControlPressed(0, 242) then radius = math.min(15.0, radius + 0.25) end
        local ry, rp = math.rad(yaw), math.rad(pitch)
        local cx = center.x + radius * math.cos(rp) * math.cos(ry)
        local cy = center.y + radius * math.cos(rp) * math.sin(ry)
        local cz = center.z + radius * math.sin(rp)
        SetCamCoord(cam, cx, cy, cz)
        PointCamAtCoord(cam, center.x, center.y, center.z)
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName('Souris : tourner ~n~Molette : zoom ~n~~INPUT_CELLPHONE_CANCEL~ : quitter')
        EndTextCommandDisplayHelp(0, false, false, -1)
        if IsDisabledControlJustReleased(0, 177) or IsDisabledControlJustReleased(0, 200) then break end
        if GetGameTimer() - lastStats > 1000 then
            lastStats = GetGameTimer()
            SendNUIMessage({ action = 'garage:showroom', show = true, stats = Stats(veh) })
        end
        Wait(0)
    end

    SendNUIMessage({ action = 'garage:showroom', show = false })
    RenderScriptCams(false, true, 600, true, true)
    DestroyCam(cam, false)
    showroomActive = false
end
