-- ─────────────────────────────────────────────────────────────────────────────
-- Menu de gestion véhicule — ox_lib radial menu
--
-- Extras/Portes/Vitres/Moteur/Feux de détresse sont ajoutés directement dans
-- le menu circulaire global d'ox_lib quand le joueur est dans un véhicule, et
-- retirés à la sortie. F5 simule la touche du menu radial (ox_lib n'expose pas
-- d'API pour ouvrir un menu précis, seulement sa commande de toggle interne),
-- ce qui ouvre/ferme directement ce menu.
--
-- Les sous-menus (Portes, Vitres, Extras) sont enregistrés une fois à l'entrée
-- dans le véhicule, puis reconstruits après chaque action pour refléter le
-- nouvel état — un rafraîchissement en continu provoquerait un clignotement du
-- menu (ox_lib ferme/rouvre le radial à chaque lib.registerRadial/addRadialItem
-- sur le menu affiché), donc on ne le fait que sur interaction du joueur.
-- ─────────────────────────────────────────────────────────────────────────────

local VehicleMenu = {
    currentVeh = 0,
    isDriver = nil,
    hazards = {}, -- [vehicle] = true/false, feux de détresse forcés par le menu
    windows = {}  -- [vehicle] = { [windowIndex] = true (ouverte) / false (fermée) }
}

local DoorLabels = {
    [0] = "Porte avant gauche",
    [1] = "Porte avant droite",
    [2] = "Porte arrière gauche",
    [3] = "Porte arrière droite",
    [4] = "Capot",
    [5] = "Coffre",
    [6] = "Porte N°6",
    [7] = "Porte N°7"
}

local WindowLabels = {
    [0] = "Vitre avant gauche",
    [1] = "Vitre avant droite",
    [2] = "Vitre arrière gauche",
    [3] = "Vitre arrière droite"
}

local refreshTopLevel, refreshDoors, refreshWindows, refreshExtras, refreshSeats

local TopLevelIds = { 'vehiclemenu_extras_link', 'vehiclemenu_doors_link', 'vehiclemenu_windows_link', 'vehiclemenu_engine', 'vehiclemenu_hazards', 'vehiclemenu_seats_link' }
local PassengerTopLevelIds = { 'vehiclemenu_seat_driver' }
for i = 0, 7 do PassengerTopLevelIds[#PassengerTopLevelIds + 1] = 'vehiclemenu_seat_' .. i end

-- ─── Changer de place — conducteur (sous-menu) et passager (racine) ───────
-- Place le joueur directement dans le siège visé (SetPedIntoVehicle), sans
-- animation de sortie/entrée : on ne quitte jamais le véhicule.

local SeatLabels = {
    [0] = 'Passager avant',
    [1] = 'Passager arrière gauche',
    [2] = 'Passager arrière droite',
}

local function seatLabel(index)
    return SeatLabels[index] or ('Passager arrière (place N°' .. (index + 1) .. ')')
end

local function changeSeat(vehicle, seat)
    -- La place peut avoir été prise par un autre joueur entre l'affichage du
    -- menu et le clic : on revérifie ici plutôt que de se fier à la liste
    -- construite au moment de l'ouverture.
    if not IsVehicleSeatFree(vehicle, seat) then
        LSLegacy.ShowNotification(nil, "Cette place est déjà occupée.", "error")
        refreshSeats(vehicle)
        return
    end

    SetPedIntoVehicle(PlayerPedId(), vehicle, seat)
    VehicleMenu.isDriver = GetPedInVehicleSeat(vehicle, -1) == PlayerPedId()
    refreshTopLevel(vehicle)
    refreshSeats(vehicle)
end

local function buildSeatItems(vehicle)
    local items = {}

    if IsVehicleSeatFree(vehicle, -1) then
        items[#items + 1] = {
            id = 'vehiclemenu_seat_driver',
            icon = 'fa-solid fa-car-side',
            label = 'Conducteur (avant)',
            onSelect = function() changeSeat(vehicle, -1) end
        }
    end

    local seatAmount = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))

    for i = 0, seatAmount - 1 do
        if IsVehicleSeatFree(vehicle, i) then
            items[#items + 1] = {
                id = 'vehiclemenu_seat_' .. i,
                icon = 'fa-solid fa-chair',
                label = seatLabel(i),
                onSelect = function() changeSeat(vehicle, i) end
            }
        end
    end

    return items
end

refreshSeats = function(vehicle)
    lib.registerRadial({ id = 'vehiclemenu_seats', items = buildSeatItems(vehicle) })
end

-- ─── Racine (items ajoutés directement au menu radial global) ─────────────

local function buildTopLevelItems(vehicle)
    if GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then
        return buildSeatItems(vehicle)
    end

    local engineOn = GetIsVehicleEngineRunning(vehicle)
    local hazardOn = VehicleMenu.hazards[vehicle] or false

    return {
        { id = 'vehiclemenu_extras_link', icon = 'fa-solid fa-toolbox', label = 'Extras', menu = 'vehiclemenu_extras' },
        { id = 'vehiclemenu_doors_link', icon = 'fa-solid fa-door-open', label = 'Portes', menu = 'vehiclemenu_doors' },
        { id = 'vehiclemenu_windows_link', icon = 'fa-solid fa-window-maximize', label = 'Vitres', menu = 'vehiclemenu_windows' },
        { id = 'vehiclemenu_seats_link', icon = 'fa-solid fa-chair', label = 'Changer de place', menu = 'vehiclemenu_seats' },
        {
            id = 'vehiclemenu_engine',
            icon = 'fa-solid fa-power-off',
            label = engineOn and 'Moteur (démarré)' or 'Moteur (arrêté)',
            keepOpen = true,
            onSelect = function()
                SetVehicleEngineOn(vehicle, not engineOn, false, true)
                refreshTopLevel(vehicle)
            end
        },
        {
            id = 'vehiclemenu_hazards',
            icon = 'fa-solid fa-triangle-exclamation',
            label = hazardOn and 'Feux de détresse (activés)' or 'Feux de détresse (désactivés)',
            keepOpen = true,
            onSelect = function()
                VehicleMenu.hazards[vehicle] = not hazardOn
                if hazardOn then
                    SetVehicleIndicatorLights(vehicle, 1, false)
                    SetVehicleIndicatorLights(vehicle, 0, false)
                end
                refreshTopLevel(vehicle)
            end
        }
    }
end

refreshTopLevel = function(vehicle)
    -- addRadialItem met à jour par id mais ne retire pas ceux qui ne sont
    -- plus pertinents (ex: passage conducteur <-> passager) : on nettoie
    -- explicitement l'autre jeu d'ids avant d'ajouter les items actuels.
    local isDriver = GetPedInVehicleSeat(vehicle, -1) == PlayerPedId()
    local staleIds = isDriver and PassengerTopLevelIds or TopLevelIds

    for i = 1, #staleIds do
        lib.removeRadialItem(staleIds[i])
    end

    lib.addRadialItem(buildTopLevelItems(vehicle))
end

-- ─── Portes ─────────────────────────────────────────────────────────────────

local function buildDoorItems(vehicle)
    local items = {
        {
            id = 'vehiclemenu_doors_open_all',
            icon = 'fa-solid fa-door-open',
            label = 'Tout ouvrir',
            keepOpen = true,
            onSelect = function()
                for i = 0, 7 do
                    if GetIsDoorValid(vehicle, i) then
                        SetVehicleDoorOpen(vehicle, i, false, false)
                    end
                end
                refreshDoors(vehicle)
            end
        },
        {
            id = 'vehiclemenu_doors_close_all',
            icon = 'fa-solid fa-door-closed',
            label = 'Tout fermer',
            keepOpen = true,
            onSelect = function()
                for i = 0, 7 do
                    if GetIsDoorValid(vehicle, i) then
                        SetVehicleDoorShut(vehicle, i, false)
                    end
                end
                refreshDoors(vehicle)
            end
        }
    }

    for i = 0, 7 do
        if GetIsDoorValid(vehicle, i) then
            local isOpen = GetVehicleDoorAngleRatio(vehicle, i) > 0.05
            local label = DoorLabels[i] or ("Porte N°" .. i)

            items[#items + 1] = {
                id = 'vehiclemenu_door_' .. i,
                icon = isOpen and 'fa-solid fa-door-open' or 'fa-solid fa-door-closed',
                label = label .. (isOpen and ' (ouverte)' or ' (fermée)'),
                keepOpen = true,
                onSelect = function()
                    if isOpen then
                        SetVehicleDoorShut(vehicle, i, false)
                    else
                        SetVehicleDoorOpen(vehicle, i, false, false)
                    end
                    refreshDoors(vehicle)
                end
            }
        end
    end

    return items
end

refreshDoors = function(vehicle)
    lib.registerRadial({ id = 'vehiclemenu_doors', items = buildDoorItems(vehicle) })
end

-- ─── Vitres ─────────────────────────────────────────────────────────────────

local function buildWindowItems(vehicle)
    if not VehicleMenu.windows[vehicle] then
        VehicleMenu.windows[vehicle] = {}
    end
    local state = VehicleMenu.windows[vehicle]

    local items = {
        {
            id = 'vehiclemenu_windows_open_all',
            icon = 'fa-solid fa-window-maximize',
            label = 'Tout ouvrir',
            keepOpen = true,
            onSelect = function()
                for i = 0, 3 do
                    RollDownWindow(vehicle, i)
                    state[i] = true
                end
                refreshWindows(vehicle)
            end
        },
        {
            id = 'vehiclemenu_windows_close_all',
            icon = 'fa-solid fa-window-minimize',
            label = 'Tout fermer',
            keepOpen = true,
            onSelect = function()
                for i = 0, 3 do
                    RollUpWindow(vehicle, i)
                    state[i] = false
                end
                refreshWindows(vehicle)
            end
        }
    }

    for i = 0, 3 do
        local isOpen = state[i] or false

        items[#items + 1] = {
            id = 'vehiclemenu_window_' .. i,
            icon = isOpen and 'fa-solid fa-window-maximize' or 'fa-solid fa-window-minimize',
            label = WindowLabels[i] .. (isOpen and ' (ouverte)' or ' (fermée)'),
            keepOpen = true,
            onSelect = function()
                if isOpen then
                    RollUpWindow(vehicle, i)
                else
                    RollDownWindow(vehicle, i)
                end
                state[i] = not isOpen
                refreshWindows(vehicle)
            end
        }
    end

    return items
end

refreshWindows = function(vehicle)
    lib.registerRadial({ id = 'vehiclemenu_windows', items = buildWindowItems(vehicle) })
end

-- ─── Extras ─────────────────────────────────────────────────────────────────

local function buildExtraItems(vehicle)
    local items = {}

    for i = 0, 20 do
        if DoesExtraExist(vehicle, i) then
            local isExtraOn = IsVehicleExtraTurnedOn(vehicle, i)

            items[#items + 1] = {
                id = 'vehiclemenu_extra_' .. i,
                icon = isExtraOn and 'fa-solid fa-toggle-on' or 'fa-solid fa-toggle-off',
                label = 'Extra N°' .. i .. (isExtraOn and ' (activé)' or ' (désactivé)'),
                keepOpen = true,
                onSelect = function()
                    local newState = nil
                    if isExtraOn == 1 then
                        newState = false
                    elseif isExtraOn == false then
                        newState = true
                    end
                    LSLegacy.SetVehicleExtra_PreserveDamage(vehicle, i, newState)
                    refreshExtras(vehicle)
                end
            }
        end
    end

    return items
end

refreshExtras = function(vehicle)
    lib.registerRadial({ id = 'vehiclemenu_extras', items = buildExtraItems(vehicle) })
end

-- ─── Enregistrement initial des sous-menus ─────────────────────────────────

lib.registerRadial({ id = 'vehiclemenu_doors', items = {} })
lib.registerRadial({ id = 'vehiclemenu_windows', items = {} })
lib.registerRadial({ id = 'vehiclemenu_extras', items = {} })
lib.registerRadial({ id = 'vehiclemenu_seats', items = {} })

-- ─── Ajout/retrait des items globaux selon la présence dans un véhicule ───

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 then
            local isDriver = GetPedInVehicleSeat(vehicle, -1) == ped

            if VehicleMenu.currentVeh ~= vehicle or VehicleMenu.isDriver ~= isDriver then
                VehicleMenu.currentVeh = vehicle
                VehicleMenu.isDriver   = isDriver

                refreshDoors(vehicle)
                refreshWindows(vehicle)
                refreshExtras(vehicle)
                refreshSeats(vehicle)
                refreshTopLevel(vehicle)
            end
        elseif VehicleMenu.currentVeh ~= 0 then
            VehicleMenu.currentVeh = 0
            VehicleMenu.isDriver   = nil
            for i = 1, #TopLevelIds do
                lib.removeRadialItem(TopLevelIds[i])
            end
            for i = 1, #PassengerTopLevelIds do
                lib.removeRadialItem(PassengerTopLevelIds[i])
            end
        end

        Wait(500)
    end
end)

-- ─── Touche F5 : simule la commande de toggle du menu radial ox_lib ───────
-- (ox_lib n'expose pas d'API publique pour ouvrir un menu radial précis, donc
-- on déclenche directement la commande liée à sa touche par défaut, ce qui
-- ouvre/ferme le menu global — lequel ne contient que nos items pendant que
-- le joueur est dans un véhicule.)

Keys.Register("F5", "F5", "Ouvrir le menu de gestion du véhicule", function()
    -- La liste des places libres peut avoir changé depuis la dernière
    -- ouverture (autre joueur monté/descendu) : on la rafraîchit juste
    -- avant l'ouverture plutôt qu'en continu, pour éviter le clignotement
    -- du menu affiché (cf. commentaire en tête de fichier).
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle ~= 0 then
        if VehicleMenu.isDriver then
            refreshSeats(vehicle)
        else
            refreshTopLevel(vehicle)
        end
    end

    ExecuteCommand('+ox_lib-radial')
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Feux de détresse — SET_VEHICLE_INDICATOR_LIGHTS doit être réappliqué tant
-- que le clignotant n'a pas de logique moteur derrière, sinon le jeu peut le
-- réinitialiser (changement de siège, IA, etc.)
-- ─────────────────────────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        local any = false
        for veh, active in pairs(VehicleMenu.hazards) do
            if not DoesEntityExist(veh) then
                VehicleMenu.hazards[veh] = nil
            elseif active then
                any = true
                SetVehicleIndicatorLights(veh, 1, true)
                SetVehicleIndicatorLights(veh, 0, true)
            end
        end
        for veh, _ in pairs(VehicleMenu.windows) do
            if not DoesEntityExist(veh) then
                VehicleMenu.windows[veh] = nil
            end
        end
        Wait(any and 500 or 2000)
    end
end)
