local crouchClipset = "move_ped_crouched"
local crouched = false

local function SetCrouched(ped, state)
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
    -- X est réutilisé par d'autres actions (annuler une émote, se relever
    -- assis, annuler une action de callout, annuler une progress bar
    -- ox_lib) : on leur laisse la priorité plutôt que de crouch.
    if LSLegacy.Emotes and LSLegacy.Emotes.HasActiveAnimation and LSLegacy.Emotes.HasActiveAnimation() then
        LSLegacy.Emotes.CancelActiveAnimation()
        return
    end
    if LSLegacy.Sit and LSLegacy.Sit.IsSitting and LSLegacy.Sit.IsSitting() then return end
    if LSLegacy.Needs and LSLegacy.Needs.IsEating and LSLegacy.Needs.IsEating() then return end
    if Atelier and Atelier.GetHeldPart and Atelier.GetHeldPart() then
        Atelier.DropHeldPart()
        return
    end
    if ActionBusy then return end
    if lib and lib.progressActive and lib.progressActive() then return end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) or not IsPedOnFoot(ped) then return end
    SetCrouched(ped, not crouched)
end, false)

RegisterKeyMapping('lslegacy_crouch', "S'accroupir", 'keyboard', 'X')

CreateThread(function()
    while true do
        if crouched then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) or not IsPedOnFoot(ped) then
                SetCrouched(ped, false)
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
