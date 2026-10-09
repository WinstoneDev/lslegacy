-- DEBUG UNIQUEMENT : pour vérifier/compléter Config.Atelier.Tuning.Paints
-- avec des ids fiables (voir bug id 88/111 mal étiquetés, corrigé en
-- reprenant Config.Concessionnaire.Colors). Aucun lien avec la facturation
-- atelier — s'applique sur n'importe quel véhicule (dans lequel on est, ou
-- le plus proche), sans besoin du job.
--
-- Usage (console F8) :
--   /paintcolor <id>   applique directement cet id (0-159)
--   /paintcolor next   id + 1
--   /paintcolor prev   id - 1
--   /paintcolor slot   bascule primaire / secondaire

local debugColorId = 0
local debugSlot    = 'primary'

local function GetTargetVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false)
    end
    local coords = GetEntityCoords(ped)
    local veh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 70)
    return veh ~= 0 and veh or nil
end

local function ApplyDebugColor()
    local veh = GetTargetVehicle()
    if not veh then
        print('[PaintDebug] Aucun véhicule à proximité / dans lequel vous êtes.')
        return
    end

    SetVehicleModKit(veh, 0)
    if debugSlot == 'primary' then
        SetVehicleModColor_1(veh, 0, debugColorId, 0)
    else
        SetVehicleModColor_2(veh, 0, debugColorId)
    end

    print(('[PaintDebug] slot=%s id=%d — notez le nom que vous observez, puis /paintcolor next'):format(debugSlot, debugColorId))
end

RegisterCommand('paintcolor', function(_, args)
    local sub = args[1]

    if sub == 'next' then
        debugColorId = debugColorId + 1
    elseif sub == 'prev' then
        debugColorId = math.max(0, debugColorId - 1)
    elseif sub == 'slot' then
        debugSlot = (debugSlot == 'primary') and 'secondary' or 'primary'
        print('[PaintDebug] slot = ' .. debugSlot)
        return
    elseif tonumber(sub) then
        debugColorId = math.floor(tonumber(sub))
    else
        print('[PaintDebug] Usage: /paintcolor <id> | next | prev | slot')
        return
    end

    ApplyDebugColor()
end, false)
