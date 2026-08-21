--  MODULE ATELIER — Référentiel des composants (partagé client/serveur)
--  Un composant = un pourcentage d'état (0-100), persisté dans
--  atelier_vehicles.components (voir server/vehicles.lua).
--
--  Trois catégories :
--    mechanical → dérivée en continu de GetVehicleEngineHealth (native)
--    tyres      → dérivée en continu de GetTyreHealth (native, par roue)
--    body       → PAS toutes observables nativement (capot/ailes/pare-
--                 chocs/bas de caisse/phares/vitres n'ont pas d'état GTA
--                 individuel) : notre table est ici la SEULE source de
--                 vérité, modifiée uniquement par nos interventions.
--                 `carrosserie_generale` seule est recalée sur
--                 GetVehicleBodyHealth (native), les autres non.

LSLegacy = LSLegacy or {}
LSLegacy.Atelier = LSLegacy.Atelier or {}

LSLegacy.Atelier.Components = {
    mechanical = {
        moteur       = { label = 'Moteur',       gta = true  },
        freins       = { label = 'Freins',       gta = false },
        transmission = { label = 'Transmission', gta = false },
        suspension   = { label = 'Suspension',   gta = false },
        embrayage    = { label = 'Embrayage',    gta = false },
        radiateur    = { label = 'Radiateur',    gta = false },
    },
    tyres = {
        pneu_avg = { label = 'Pneu avant gauche',  wheelIndex = 0 },
        pneu_avd = { label = 'Pneu avant droit',   wheelIndex = 1 },
        pneu_arg = { label = 'Pneu arrière gauche', wheelIndex = 4 },
        pneu_ard = { label = 'Pneu arrière droit', wheelIndex = 5 },
    },
    body = {
        carrosserie_generale = { label = 'Carrosserie générale', gta = true },
        capot                = { label = 'Capot',                gta = false },
        portiere_avg         = { label = 'Portière avant gauche',  gta = false, doorIndex = 0 },
        portiere_avd         = { label = 'Portière avant droite',  gta = false, doorIndex = 1 },
        portiere_arg         = { label = 'Portière arrière gauche', gta = false, doorIndex = 2 },
        portiere_ard         = { label = 'Portière arrière droite', gta = false, doorIndex = 3 },
        aile_avg             = { label = 'Aile avant gauche',    gta = false },
        aile_avd             = { label = 'Aile avant droite',    gta = false },
        pare_choc_avant      = { label = 'Pare-chocs avant',     gta = false },
        pare_choc_arriere    = { label = 'Pare-chocs arrière',   gta = false },
        bas_caisse           = { label = 'Bas de caisse',        gta = false },
        coffre               = { label = 'Coffre / hayon',       gta = false, doorIndex = 5 },
        vitres               = { label = 'Vitres',               gta = false },
        phares               = { label = 'Phares',               gta = false },
    },
}

-- Renvoie l'état par défaut (100% partout) pour un véhicule jamais rencontré.
function LSLegacy.Atelier.DefaultComponentState()
    local state = {}
    for category, components in pairs(LSLegacy.Atelier.Components) do
        state[category] = {}
        for id in pairs(components) do
            state[category][id] = 100
        end
    end
    return state
end

-- Recherche un composant par son id, quelle que soit sa catégorie.
-- @return string|nil category
-- @return table|nil def
function LSLegacy.Atelier.FindComponent(componentId)
    for category, components in pairs(LSLegacy.Atelier.Components) do
        if components[componentId] then return category, components[componentId] end
    end
    return nil, nil
end
