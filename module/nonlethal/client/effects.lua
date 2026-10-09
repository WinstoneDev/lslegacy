-- Zones d'effet répliquées (gaz lacrymogène / fumée) : le serveur diffuse
-- coords + rayon + durée + dégâts à tout le monde (nonlethal:zoneSpawned),
-- chaque client gère ensuite localement sa propre exposition (flou d'écran
-- + perte de PV) — y compris le joueur qui a lancé/tiré la grenade.

LSLegacy.NonLethal = LSLegacy.NonLethal or {}

local ActiveZones = {}
local zoneSeq = 0

local BLUR_FX = 'DeathFailOut' -- vision qui se brouille, sans le fondu rouge de mort associé

local function PtfxAssetFor(kind)
    if kind == 'fumigene' then
        return 'core', 'ent_amb_smoke_forest'
    end
    return 'scr_agencyheistb', 'scr_gas_canister_smoke' -- rendu gris/verdâtre, déjà utilisé par GTA pour un nuage de gaz
end

local function SpawnCloudPtfx(coords, radius, durationMs, kind)
    local dict, name = PtfxAssetFor(kind)
    RequestNamedPtfxAsset(dict)
    local t = 0
    while not HasNamedPtfxAssetLoaded(dict) and t < 50 do Wait(100); t = t + 1 end
    if not HasNamedPtfxAssetLoaded(dict) then return end

    UseParticleFxAssetNextCall(dict)
    local scale = math.max(1.0, radius / 2.0)
    local fx = StartParticleFxLoopedAtCoord(name, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, scale, false, false, false, false)

    SetTimeout(durationMs, function()
        if fx and DoesParticleFxLoopedExist(fx) then
            StopParticleFxLooped(fx, false)
        end
    end)
end

-- Nombre de zones qui exposent actuellement le joueur (flou tant que > 0).
local exposedCount = 0

local function SetBlur(on)
    if on then
        if not IsAnimpostfxRunning(BLUR_FX) then AnimpostfxPlay(BLUR_FX, 0, true) end
    else
        if IsAnimpostfxRunning(BLUR_FX) then AnimpostfxStop(BLUR_FX) end
    end
end

local function RunZone(zone)
    local id = zone.id
    ActiveZones[id] = zone
    SpawnCloudPtfx(zone.coords, zone.radius, zone.duration, zone.kind)

    local endTime   = GetGameTimer() + zone.duration
    local wasInside = false
    local lastDamageTick = 0

    while GetGameTimer() < endTime do
        Wait(250)
        local ped = PlayerPedId()
        if not DoesEntityExist(ped) or IsEntityDead(ped) then break end

        local inside = #(GetEntityCoords(ped) - zone.coords) <= zone.radius

        if inside and not wasInside then
            exposedCount = exposedCount + 1
            SetBlur(true)
        elseif not inside and wasInside then
            exposedCount = math.max(0, exposedCount - 1)
            if exposedCount == 0 then SetBlur(false) end
        end
        wasInside = inside

        if inside and zone.damagePerTick and zone.damagePerTick > 0 then
            local now = GetGameTimer()
            if (now - lastDamageTick) >= zone.damageTickMs then
                lastDamageTick = now
                local health = GetEntityHealth(ped)
                SetEntityHealth(ped, math.max(101, health - zone.damagePerTick))
            end
        end
    end

    if wasInside then
        exposedCount = math.max(0, exposedCount - 1)
        if exposedCount == 0 then SetBlur(false) end
    end
    ActiveZones[id] = nil
end

LSLegacy.Events.Register('nonlethal:zoneSpawned', function(data)
    if not data or not data.coords then return end
    zoneSeq = zoneSeq + 1
    CreateThread(function()
        RunZone({
            id            = zoneSeq,
            kind          = data.kind,
            coords        = vector3(data.coords.x, data.coords.y, data.coords.z),
            radius        = data.radius,
            duration      = data.duration,
            damagePerTick = data.damagePerTick,
            damageTickMs  = data.damageTickMs,
        })
    end)
end)

-- Utilisé par cougar.lua / gazeuse.lua / grenades.lua pour demander une zone
-- au point visé : le serveur revalide la config (kind whitelisté) et
-- rediffuse à tout le monde, cf. server/main.lua.
function LSLegacy.NonLethal.RequestZone(kind, coords)
    LSLegacy.Events.SendToServer('nonlethal:createZone', {
        kind   = kind,
        coords = { x = coords.x, y = coords.y, z = coords.z },
    })
end

-- Point visé (tir tendu approximé), partagé par cougar.lua (tir) et
-- grenades.lua (lancer à la main) — mutualisé pour ne pas dupliquer le
-- raycast caméra déjà utilisé ailleurs (TaserTarget, callouts.lua).
function LSLegacy.NonLethal.AimImpactPoint(maxRange)
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local f = math.abs(math.cos(rx))
    local dir = vector3(-math.sin(rz) * f, math.cos(rz) * f, math.sin(rx))
    local dest = cam + dir * maxRange

    local ok, coords = pcall(function()
        local h = StartExpensiveSynchronousShapeTestLosProbe(
            cam.x, cam.y, cam.z, dest.x, dest.y, dest.z,
            -1, PlayerPedId(), 4)
        local _, didHit, hitCoords = GetShapeTestResult(h)
        if didHit == 1 or didHit == true then return hitCoords end
        return dest
    end)
    if ok and coords then return coords end
    return dest
end
