-- Supprime périodiquement les peds animaux listés en config dès qu'ils apparaissent (population ambiante du jeu).

local suppressedHashes = {}
local hasSuppressed    = false
for _, modelName in ipairs(Config.Wildlife.SuppressedModels) do
    suppressedHashes[GetHashKey(modelName)] = true
    hasSuppressed = true
end

CreateThread(function()
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
