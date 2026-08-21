-- ═══════════════════════════════════════════════════════════════════
--  MODULE WILDLIFE — Client
--  Supprime périodiquement les peds animaux listés en config dès qu'ils
--  apparaissent (population ambiante du jeu, gérée côté client).
-- ═══════════════════════════════════════════════════════════════════

local suppressedHashes = {}
local hasSuppressed    = false
for _, modelName in ipairs(Config.Wildlife.SuppressedModels) do
    suppressedHashes[GetHashKey(modelName)] = true
    hasSuppressed = true
end

CreateThread(function()
    -- Aucune espèce à supprimer : inutile de parcourir tout le pool de peds
    -- toutes les 2 s pour rien.
    if not hasSuppressed then return end

    while true do
        Wait(Config.Wildlife.ScanInterval)

        for _, ped in ipairs(GetGamePool('CPed')) do
            if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                if suppressedHashes[GetEntityModel(ped)] then
                    SetEntityAsMissionEntity(ped, true, true)
                    DeletePed(ped)
                end
            end
        end
    end
end)
