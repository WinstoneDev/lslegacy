-- Bloque le contrôle aérien et le "balancement" anti-retournement sur les véhicules terrestres ; bateaux/hélicos/avions exclus (Config.VehicleStability.ExcludedClasses).

-- Commandes (cf. https://docs.fivem.net/docs/game-references/controls/)
local CONTROL_VEH_MOVE_LR   = 59  -- INPUT_VEH_MOVE_LR   (volant gauche/droite)
local CONTROL_VEH_MOVE_UD   = 60  -- INPUT_VEH_MOVE_UD   (volant haut/bas)
local CONTROL_VEH_ACCELERATE = 71 -- INPUT_VEH_ACCELERATE
local CONTROL_VEH_BRAKE      = 72 -- INPUT_VEH_BRAKE

local function IsLandVehicle(veh)
    local class = GetVehicleClass(veh)
    for _, excluded in ipairs(Config.VehicleStability.ExcludedClasses) do
        if class == excluded then return false end
    end
    return true
end

-- Vecteur "haut" normalisé du véhicule ; Z fortement négatif = toit vers le sol.
local function IsUpsideDown(veh)
    local pos   = GetEntityCoords(veh)
    local upOff = GetOffsetFromEntityInWorldCoords(veh, 0.0, 0.0, 1.0)
    local upZ   = upOff.z - pos.z
    return upZ < Config.VehicleStability.UpsideDownThreshold
end

-- DisableControlAction doit être rappelé chaque frame pour rester actif.
CreateThread(function()
    while true do
        local wait = 500

        if Config.VehicleStability.Enabled then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            local isDriver = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped

            if isDriver and IsLandVehicle(veh) then
                wait = 0

                if IsEntityInAir(veh) then
                    DisableControlAction(0, CONTROL_VEH_MOVE_LR, true)
                    DisableControlAction(0, CONTROL_VEH_MOVE_UD, true)
                end

                if IsUpsideDown(veh) then
                    DisableControlAction(0, CONTROL_VEH_MOVE_LR, true)
                    DisableControlAction(0, CONTROL_VEH_MOVE_UD, true)
                    DisableControlAction(0, CONTROL_VEH_ACCELERATE, true)
                    DisableControlAction(0, CONTROL_VEH_BRAKE, true)
                end
            end
        end

        Wait(wait)
    end
end)
