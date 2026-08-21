-- Repris de rpemotes-reborn (client/NoIdleCam.lua), traduit en français. Persiste via KVP (survit déco/reco).
-- KVP : 0 = jamais touché (défaut du jeu), 1 = désactivée, 2 = activée — distingue "jamais réglé" d'un simple booléen.

RegisterCommand('idlecamoff', function()
    DisableIdleCamera(true)
    SetPedCanPlayAmbientAnims(PlayerPedId(), false)
    SetResourceKvpInt("lslegacy_emotes_idlecam", 1)
    LSLegacy.ShowNotification("LSLegacy", "Caméra idle désactivée.", 'info')
end, false)

RegisterCommand('idlecamon', function()
    DisableIdleCamera(false)
    SetPedCanPlayAmbientAnims(PlayerPedId(), true)
    SetResourceKvpInt("lslegacy_emotes_idlecam", 2)
    LSLegacy.ShowNotification("LSLegacy", "Caméra idle activée.", 'info')
end, false)

CreateThread(function()
    TriggerEvent("chat:addSuggestion", "/idlecamon", "Réactive la caméra idle")
    TriggerEvent("chat:addSuggestion", "/idlecamoff", "Désactive la caméra idle")

    local saved = GetResourceKvpInt("lslegacy_emotes_idlecam")
    if saved == 0 then return end
    DisableIdleCamera(saved == 1)
end)
