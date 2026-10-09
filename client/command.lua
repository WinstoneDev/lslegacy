-- tpm : reçoit l'ordre du serveur (RegisterCommand client supprimé pour sécurité)
LSLegacy.Events.Register('admin:doTpm', function()
    if LSLegacy.Anticheat then LSLegacy.Anticheat.AllowTeleport() end
    local entity = PlayerPedId()
    local blipFound = false
    local blipIterator = GetBlipInfoIdIterator()
    local blip = GetFirstBlipInfoId(8)
    local cx, cy, cz = 0.0, 0.0, 0.0

    if IsPedInAnyVehicle(entity, false) then
        entity = GetVehiclePedIsUsing(entity)
    end

    while DoesBlipExist(blip) do
        if GetBlipInfoIdType(blip) == 4 then
            cx, cy, cz = table.unpack(Citizen.InvokeNative(0xFA7C7F0AADF25D09, blip, Citizen.ReturnResultAnyway(), Citizen.ResultAsVector()))
            blipFound = true
            break
        end
        blip = GetNextBlipInfoId(blipIterator)
        Wait(0)
    end

    if blipFound then
        local groundFound = false
        local yaw = GetEntityHeading(entity)

        for i = 0, 1000, 1 do
            SetEntityCoordsNoOffset(entity, cx, cy, ToFloat(i), false, false, false)
            SetEntityRotation(entity, 0, 0, 0, 0, 0)
            SetEntityHeading(entity, yaw)
            SetGameplayCamRelativeHeading(0)
            Wait(0)
            if GetGroundZFor_3dCoord(cx, cy, ToFloat(i), cz, false) then
                cz = ToFloat(i)
                groundFound = true
                break
            end
        end
        if not groundFound then cz = -300.0 end

        SetEntityCoordsNoOffset(entity, cx, cy, cz, false, false, true)
        SetGameplayCamRelativeHeading(0)
        if IsPedSittingInAnyVehicle(PlayerPedId()) then
            if GetPedInVehicleSeat(GetVehiclePedIsUsing(PlayerPedId()), -1) == PlayerPedId() then
                SetVehicleOnGroundProperly(GetVehiclePedIsUsing(PlayerPedId()))
            end
        end
    end
end)

-- pos : affiche les coordonnées reçues du serveur
LSLegacy.Events.Register('admin:showPos', function(x, y, z, h)
    Config.Development.Print(vector3(x, y, z))
    Config.Development.Print(h)
end)

-- /me : bulle de texte au-dessus de la tête, uniquement reçue des joueurs à moins de 10m (filtré serveur)
local meBubbles = {}

LSLegacy.Events.Register('me:show', function(serverId, text)
    meBubbles[serverId] = {text = text, expires = GetGameTimer() + 15000}
end)

CreateThread(function()
    while true do
        local hasBubble = false
        local now = GetGameTimer()
        for serverId, bubble in pairs(meBubbles) do
            if now >= bubble.expires then
                meBubbles[serverId] = nil
            else
                local targetPlayer = GetPlayerFromServerId(serverId)
                if targetPlayer ~= -1 then
                    local ped = GetPlayerPed(targetPlayer)
                    if DoesEntityExist(ped) then
                        local coords = GetEntityCoords(ped)
                        LSLegacy.DrawText3D(coords.x, coords.y, coords.z + 0.8, bubble.text, 10.0)
                        hasBubble = true
                    end
                end
            end
        end
        Wait(hasBubble and 0 or 500)
    end
end)
