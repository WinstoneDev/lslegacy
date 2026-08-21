-- ════════════════════════════════════════════════════════════════════════════
-- STABILITÉ DES VÉHICULES TERRESTRES — Module persistent_vehicles
-- Auteur   : LSLegacy Framework
--
-- Comportement :
--   • Supprime le contrôle aérien (rotation du véhicule en plein vol via le
--     volant) sur les voitures, motos et autres véhicules terrestres.
--   • Empêche de retourner un véhicule terrestre lorsqu'il est sur le toit
--     en désactivant les commandes qui permettent de le "balancer".
--
-- Les bateaux, hélicoptères et avions sont exclus (Config.VehicleStability
-- .ExcludedClasses) car ils ont légitimement besoin de ces commandes en vol.
-- ════════════════════════════════════════════════════════════════════════════

-- Commandes (cf. https://docs.fivem.net/docs/game-references/controls/)
local CONTROL_VEH_MOVE_LR   = 59  -- INPUT_VEH_MOVE_LR   (volant gauche/droite)
local CONTROL_VEH_MOVE_UD   = 60  -- INPUT_VEH_MOVE_UD   (volant haut/bas)
local CONTROL_VEH_ACCELERATE = 71 -- INPUT_VEH_ACCELERATE
local CONTROL_VEH_BRAKE      = 72 -- INPUT_VEH_BRAKE

-- ─────────────────────────────────────────────────────────────────────────────
-- HELPER : le véhicule fait-il partie des classes concernées ?
--
-- GetVehicleClass(vehicle) → entier de classe (14=Bateaux, 15=Hélicoptères,
-- 16=Avions…). Tout le reste est considéré "terrestre" pour ce système.
-- ─────────────────────────────────────────────────────────────────────────────
local function isLandVehicle(veh)
    local class = GetVehicleClass(veh)
    for _, excluded in ipairs(Config.VehicleStability.ExcludedClasses) do
        if class == excluded then return false end
    end
    return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- HELPER : le véhicule est-il sur le toit ?
--
-- GetOffsetFromEntityInWorldCoords(veh, 0, 0, 1) renvoie la position monde du
-- point situé 1 unité au-dessus du véhicule dans son repère local : la
-- différence avec sa position donne le vecteur "haut" normalisé.
-- Si sa composante Z est fortement négative, le toit pointe vers le sol.
-- ─────────────────────────────────────────────────────────────────────────────
local function isUpsideDown(veh)
    local pos   = GetEntityCoords(veh)
    local upOff = GetOffsetFromEntityInWorldCoords(veh, 0.0, 0.0, 1.0)
    local upZ   = upOff.z - pos.z
    return upZ < Config.VehicleStability.UpsideDownThreshold
end

-- ─────────────────────────────────────────────────────────────────────────────
-- BOUCLE PRINCIPALE
--
-- DisableControlAction(group, control, disable) doit être rappelé chaque frame
-- pour rester actif : on ne reste donc en wait=0 que lorsque le joueur conduit
-- effectivement un véhicule terrestre éligible.
-- ─────────────────────────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        local wait = 500

        if Config.VehicleStability.Enabled then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            local isDriver = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped

            if isDriver and isLandVehicle(veh) then
                wait = 0

                -- Contrôle aérien : bloque la rotation du véhicule en plein vol
                if IsEntityInAir(veh) then
                    DisableControlAction(0, CONTROL_VEH_MOVE_LR, true)
                    DisableControlAction(0, CONTROL_VEH_MOVE_UD, true)
                end

                -- Anti-retournement : bloque les commandes utilisées pour
                -- "balancer" le véhicule et le remettre sur ses roues
                if isUpsideDown(veh) then
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
