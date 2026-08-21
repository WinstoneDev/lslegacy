local crouchClipset = "move_ped_crouched"
local crouched = false

local function setCrouched(ped, state)
    crouched = state
    if state then
        RequestClipSet(crouchClipset)
        while not HasClipSetLoaded(crouchClipset) do Wait(0) end
        SetPedMovementClipset(ped, crouchClipset, 0.25)
        SetPedMoveRateOverride(ped, 0.7)
    else
        ResetPedMovementClipset(ped, 0.25)
        SetPedMoveRateOverride(ped, 1.0)
    end
end

RegisterCommand('lslegacy_crouch', function()
    -- Le menu émotes (module/emotes) réutilise la touche X pour annuler une
    -- animation en cours : si une émote est active, X l'annule au lieu
    -- d'accroupir le joueur.
    if LSLegacy.Emotes and LSLegacy.Emotes.HasActiveAnimation and LSLegacy.Emotes.HasActiveAnimation() then
        LSLegacy.Emotes.CancelActiveAnimation()
        return
    end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) or not IsPedOnFoot(ped) then return end
    setCrouched(ped, not crouched)
end, false)

RegisterKeyMapping('lslegacy_crouch', "S'accroupir", 'keyboard', 'X')

CreateThread(function()
    while true do
        if crouched then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) or not IsPedOnFoot(ped) then
                setCrouched(ped, false)
            else
                DisableControlAction(0, 21, true) -- sprint
                DisableControlAction(0, 22, true) -- jump
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)
