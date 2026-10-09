-- Porter (/porter) : transporter un autre joueur, synchronisé entre les deux
-- clients via le serveur. Ciblage : ox_target (ALT sur un joueur) ou commande directe.

local CARRIER_ANIM = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flags = 49 }
local CARRIED_ANIM  = { dict = 'nm',                 anim = 'firemans_carry',      flags = 33 }
-- { boneIndex, x, y, z, rx, ry, rz } — identique à pedOfflineCfg.carryAnimation.attach
local ATTACH = { 0, 0.20, 0.15, 0.63, 0.5, 0.5, 5.0 }

local function Notify(msg, type)
    LSLegacy.ShowNotification('Porter', msg, type or 'info')
end

local function GetServerIdFromPed(ped)
    local playerIndex = NetworkGetPlayerIndexFromPed(ped)
    if not playerIndex then return nil end
    return GetPlayerServerId(playerIndex)
end

local function PlayAnim(entity, dict, anim, blendIn, blendOut, duration, flags)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do Wait(100) end
    end
    TaskPlayAnim(entity, dict, anim, blendIn or 8.0, blendOut or 8.0, duration or -1, flags or 0, 0, false, false, false)
end

-- État local : soit je porte quelqu'un, soit je suis porté(e)

local role       = nil -- 'carrier' | 'carried' | nil
local partnerSrc = nil

LSLegacy.IsCarrying     = false
LSLegacy.IsBeingCarried = false

local function IsBusy()
    return role ~= nil
end

local function StopCarry()
    if not role then return end
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if role == 'carried' then
        DetachEntity(ped, true, false)
    end
    role, partnerSrc = nil, nil
    LSLegacy.IsCarrying, LSLegacy.IsBeingCarried = false, false
end

local function CancelCarry()
    if not role then return end
    LSLegacy.Events.SendToServer('lslegacy_carry:cancel')
    StopCarry()
end

local function PlayCarrier(carriedSrc)
    local ped = PlayerPedId()
    PlayAnim(ped, CARRIER_ANIM.dict, CARRIER_ANIM.anim, 8.0, 8.0, -1, CARRIER_ANIM.flags)
    role, partnerSrc = 'carrier', carriedSrc
    LSLegacy.IsCarrying = true
end

local function PlayCarried(carrierSrc)
    local ped           = PlayerPedId()
    local carrierPlayer = GetPlayerFromServerId(carrierSrc)
    local carrierPed    = carrierPlayer ~= -1 and GetPlayerPed(carrierPlayer)
    if not carrierPed or carrierPed == 0 or not DoesEntityExist(carrierPed) then return end

    PlayAnim(ped, CARRIED_ANIM.dict, CARRIED_ANIM.anim, 8.0, 8.0, -1, CARRIED_ANIM.flags)
    AttachEntityToEntity(ped, carrierPed, ATTACH[1], ATTACH[2], ATTACH[3], ATTACH[4],
        ATTACH[5], ATTACH[6], ATTACH[7], false, false, false, false, 2, false)
    role, partnerSrc = 'carried', carrierSrc
    LSLegacy.IsBeingCarried = true
end

LSLegacy.Events.Register('lslegacy_carry:clientStart', function(carrierSrc, carriedSrc)
    local mySrc = GetPlayerServerId(PlayerId())
    if mySrc == carrierSrc then
        PlayCarrier(carriedSrc)
    elseif mySrc == carriedSrc then
        PlayCarried(carrierSrc)
    end
end)

LSLegacy.Events.Register('lslegacy_carry:clientStop', function()
    StopCarry()
end)

-- [X] pour arrêter de porter (côté porteur uniquement), + coupure auto si
-- l'un des deux monte en véhicule, meurt, ou si le partenaire disparaît.
CreateThread(function()
    while true do
        if role then
            Wait(0)
            local ped           = PlayerPedId()
            local partnerPlayer = partnerSrc and GetPlayerFromServerId(partnerSrc)

            if IsEntityDead(ped) or (role == 'carrier' and IsPedInAnyVehicle(ped, false))
                or not partnerPlayer or partnerPlayer == -1 then
                CancelCarry()
            elseif role == 'carrier' then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('[X] Arrêter de porter')
                EndTextCommandDisplayHelp(0, false, false, -1)

                if IsControlJustReleased(0, 73) then -- X
                    CancelCarry()
                end
            end
        else
            Wait(500)
        end
    end
end)

local function CanStartCarry()
    local ped = PlayerPedId()
    if IsBusy() then return false, 'Vous êtes déjà occupé(e).' end
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) or not IsPedOnFoot(ped) then
        return false, 'Impossible dans cet état.'
    end
    return true
end

local function StartCarry(targetPed)
    local ok, reason = CanStartCarry()
    if not ok then Notify(reason, 'error') return end

    if not DoesEntityExist(targetPed) or targetPed == PlayerPedId() then return end

    if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(targetPed)) > Config.Carry.range then
        Notify('Trop loin.', 'error')
        return
    end

    local targetSrc = GetServerIdFromPed(targetPed)
    if not targetSrc then return end

    LSLegacy.Events.SendToServer('lslegacy_carry:request', targetSrc)
end

RegisterCommand('porter', function()
    if IsBusy() then
        CancelCarry()
        return
    end

    local target = LSLegacy.GetClosestPlayer(true, Config.Carry.range)
    if not target then Notify("Personne n'est assez proche.", 'error') return end

    StartCarry(target)
end, false)

-- Demande de portage : la cible (consciente) doit accepter

LSLegacy.Events.Register('lslegacy_carry:clientRequest', function(requesterServerId)
    local requesterName = GetPlayerName(GetPlayerFromServerId(requesterServerId)) or 'Un joueur'
    Notify(('%s souhaite vous porter. Y pour accepter, L pour refuser.'):format(requesterName), 'info')

    CreateThread(function()
        local timeout = GetGameTimer() + 10000
        while GetGameTimer() < timeout do
            Wait(0)
            if IsControlJustPressed(1, 246) then -- Y
                LSLegacy.Events.SendToServer('lslegacy_carry:confirm', requesterServerId)
                return
            elseif IsControlJustPressed(1, 182) then -- L
                return
            end
        end
    end)
end)

-- Ciblage ox_target

exports.ox_target:addGlobalPlayer({
    {
        name = 'lslegacy_carry',
        icon = 'fa-solid fa-people-carry-box',
        label = 'Porter',
        distance = Config.Carry.range,
        canInteract = function(entity)
            return entity ~= PlayerPedId() and not IsBusy()
                and not LSLegacy.IsHostageTaker and not LSLegacy.IsHostage
        end,
        onSelect = function(data) StartCarry(data.entity) end,
    },
})
