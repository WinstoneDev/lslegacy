-- Supprime la population ambiante d'aéronefs vanilla (route + air) et masque les props de
-- servitude statiques (ymaps) autour de LSIA, pour ne garder que le trafic scripté ATC.

local C = Config.ATC
if not C.Enabled then return end

local suppressedHashes = {}
local suppressedSet = {}
for _, model in ipairs(C.SuppressedAmbientModels) do
    local h = joaat(model)
    suppressedHashes[#suppressedHashes + 1] = h
    suppressedSet[h] = true
end

local hiddenHashes = {}
for _, model in ipairs(C.HiddenProps) do hiddenHashes[joaat(model)] = true end

local center = C.Tower.cam

local function SuppressAmbient()
    for _, h in ipairs(suppressedHashes) do SetVehicleModelIsSuppressed(h, true) end
end

-- Réassertion périodique défensive (d'autres scripts/le jeu peuvent réinitialiser le flag).
CreateThread(function()
    while true do
        SuppressAmbient()
        Wait(120000)
    end
end)

-- Props statiques : pas de suppression au spawn possible (ymap), on masque + désactive la
-- collision de ce qui est actuellement streamé dans le rayon de l'aéroport.
CreateThread(function()
    while true do
        Wait(2000)
        local pos = GetEntityCoords(PlayerPedId())
        if #(vector2(pos.x, pos.y) - vector2(center.x, center.y)) < C.PropHideRadius then
            for _, obj in ipairs(GetGamePool('CObject')) do
                if hiddenHashes[GetEntityModel(obj)] and IsEntityVisible(obj) then
                    SetEntityVisible(obj, false, false)
                    SetEntityCollision(obj, false, false)
                end
            end
        end
    end
end)

-- Aéronefs ambiants déjà présents (générateurs de véhicules ymap chargés avant ce script, ou spawnés
-- avant que SuppressAmbient() ait eu le temps d'agir) : SetVehicleModelIsSuppressed bloque seulement
-- les FUTURS spawns, donc on balaie et supprime activement ceux qui traînent encore. Les avions ATC
-- scriptés (même modèle) sont épargnés via le statebag 'lsiaAtc' posé à leur création.
CreateThread(function()
    while true do
        Wait(5000)
        local pos = GetEntityCoords(PlayerPedId())
        if #(vector2(pos.x, pos.y) - vector2(center.x, center.y)) < C.PropHideRadius then
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if suppressedSet[GetEntityModel(veh)] and not Entity(veh).state.lsiaAtc
                    and GetPedInVehicleSeat(veh, -1) == 0 then
                    NetworkRequestControlOfEntity(veh)
                    SetEntityAsMissionEntity(veh, true, true)
                    DeleteEntity(veh)
                end
            end
        end
    end
end)
