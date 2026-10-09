-- Mode placement : le prop suit le point visé (raycast caméra/souris), la molette le fait pivoter.

local C = Config.Obstacles.Placement

Obstacles = Obstacles or {}
local placing = false

local function LoadModel(model)
    local hash = GetHashKey(model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 200 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function CamDirection()
    local rot = GetGameplayCamRot(2)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

-- entity=nil -> crée un nouveau prop réseauté ; entity fourni -> le déplace (modification/duplication déjà spawnée).
-- onConfirm(entity, coords, rotation) est appelé à la validation, onCancel() à l'annulation.
function Obstacles.RunPlacement(model, entity, onConfirm, onCancel)
    if placing then return end
    placing = true

    local ped = PlayerPedId()
    local ownEntity = false
    if not entity then
        local hash = LoadModel(model)
        if not hash then
            placing = false
            if onCancel then onCancel() end
            return
        end
        local fwd = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.0, 0.0)
        entity = CreateObject(hash, fwd.x, fwd.y, fwd.z, true, true, false)
        SetModelAsNoLongerNeeded(hash)
        ownEntity = true
    end
    FreezeEntityPosition(entity, true)
    SetEntityCollision(entity, false, false)
    SetEntityAlpha(entity, 200, false)

    local yaw   = GetEntityRotation(entity, 2).z
    local pitch, roll = 0.0, 0.0
    local heightOffset = 0.0

    LSLegacy.ShowNotification('Parcours', "Visez avec la souris pour positionner | Molette: rotation | +MAJ: inclinaison | +ALT: hauteur | Clic gauche: valider | Clic droit: annuler", 'info', 6000)

    CreateThread(function()
        while placing do
            Wait(0)

            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName("Clic gauche: valider   Clic droit: annuler")
            EndTextCommandDisplayHelp(0, false, true, -1)

            DisableControlAction(0, 24, true)   -- attaque (lu ensuite via IsDisabledControlJustPressed pour valider)
            DisableControlAction(0, 25, true)   -- visée (lu ensuite via IsDisabledControlJustPressed pour annuler)
            DisableControlAction(0, 140, true)  -- coup léger (mains nues)
            DisableControlAction(0, 141, true)  -- coup lourd
            DisableControlAction(0, 142, true)  -- coup alternatif
            DisableControlAction(0, 143, true)  -- esquive
            DisableControlAction(0, 257, true)  -- attaque 2
            DisableControlAction(0, 263, true)  -- mêlée 1
            DisableControlAction(0, 264, true)  -- mêlée 2
            DisableControlAction(0, 14, true) -- molette bas
            DisableControlAction(0, 15, true) -- molette haut
            DisableControlAction(0, 16, true)
            DisableControlAction(0, 17, true)

            -- Raycast caméra -> point visé par la souris
            local cam = GetGameplayCamCoord()
            local dir = CamDirection()
            local dest = cam + dir * C.maxDistance
            local ray = StartShapeTestLosProbe(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 1 + 16 + 256, entity, 4)
            local retval, hit, endCoords = GetShapeTestResult(ray)
            local tries = 0
            while retval == 1 and tries < 8 do
                Wait(0)
                retval, hit, endCoords = GetShapeTestResult(ray)
                tries = tries + 1
            end
            local didHit = (retval ~= 1) and (hit == true or hit == 1)
            local target = didHit and endCoords or (cam + dir * 3.0)

            -- Molette : rotation (yaw), +MAJ inclinaison (pitch), +ALT hauteur au-dessus du point visé
            local up   = IsDisabledControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 17)
            local down = IsDisabledControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 16)
            if up or down then
                local sign = up and 1 or -1
                if IsControlPressed(0, 21) then          -- LSHIFT -> inclinaison
                    pitch = pitch + sign * C.rotateStep
                elseif IsControlPressed(0, 19) then      -- LALT -> hauteur
                    heightOffset = heightOffset + sign * C.heightStep
                else                                      -- rotation
                    yaw = yaw + sign * C.rotateStep
                end
            end

            local ctrl = IsControlPressed(0, 36) -- LCTRL
            if IsDisabledControlJustPressed(0, 174) then -- flèche gauche
                if ctrl then roll = roll - C.rotateStep else yaw = yaw - C.rotateStep end
            elseif IsDisabledControlJustPressed(0, 175) then -- flèche droite
                if ctrl then roll = roll + C.rotateStep else yaw = yaw + C.rotateStep end
            end

            SetEntityCoords(entity, target.x, target.y, target.z + heightOffset, false, false, false, false)
            SetEntityRotation(entity, pitch, roll, yaw % 360.0, 2, true)
            SetEntityDrawOutline(entity, true)
            SetEntityDrawOutlineColor(didHit and 80 or 220, didHit and 220 or 80, 120, 200)

            if IsDisabledControlJustPressed(0, 24) then -- clic gauche
                placing = false
                SetEntityDrawOutline(entity, false)
                SetEntityAlpha(entity, 255, false)
                SetEntityCollision(entity, true, true)
                local coords = GetEntityCoords(entity)
                onConfirm(entity, coords, { x = pitch, y = roll, z = yaw % 360.0 })
                break
            end

            if IsDisabledControlJustPressed(0, 25) then -- clic droit
                placing = false
                if ownEntity then DeleteEntity(entity) end
                LSLegacy.ShowNotification('Parcours', 'Placement annulé.', 'error')
                if onCancel then onCancel() end
                break
            end
        end
    end)
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then placing = false end
end)
