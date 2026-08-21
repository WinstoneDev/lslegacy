--  MODULE MÉCANICIEN — Pose de pièce portée en main (client)
--  Touche E (proximité véhicule), volontairement hors ox_target :
--  action liée à l'état "tient une pièce en main", pas un ciblage classique.

local function Notify(msg, type)
    TriggerEvent(Config.Mecanicien.NotifyEvent, 'Mécanicien', msg, 5000, type or 'info')
end

local function PlayAnim(dict, anim, duration, flag)
    flag = flag or 49
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do Wait(100); t = t + 1 end
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, duration, flag, 0, false, false, false)
    Wait(duration)
    ClearPedTasks(PlayerPedId())
end

local function GetClosestVehicle(range)
    local ped     = PlayerPedId()
    local pos     = GetEntityCoords(ped)
    local closest, closestDist = nil, range

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local dist = #(pos - GetEntityCoords(veh))
        if dist < closestDist then
            closestDist = dist
            closest     = veh
        end
    end
    return closest
end

local installing = false

local function InstallPart(veh, itemName)
    if installing then return end
    installing = true

    Notify(Lang.Mecanicien.install_start, 'info')
    PlayAnim('mini@repair', 'fixing_a_ped', 3000, 49)

    Mecanicien.RunMinigame(function(hits, rounds, success)
        installing = false
        if not success then
            Notify(Lang.Mecanicien.install_failed, 'error')
            return
        end

        LSLegacy.SendEventToServer('mecanicien:installPart', {
            vehNet = NetworkGetNetworkIdFromEntity(veh),
            item   = itemName,
        })
    end)
end

LSLegacy.RegisterClientEvent('mecanicien:installResult', function(data)
    if not data then return end
    if data.success then
        Notify(Lang.Mecanicien.install_done, 'success')
        Mecanicien.ClearHeldPart()
    end
end)

-- Boucle de proximité (active uniquement si une pièce est en main)

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local heldPart = Mecanicien.GetHeldPart and Mecanicien.GetHeldPart()

        if heldPart and Mecanicien.IsOnDuty() then
            local range = Config.Mecanicien.Actions.installRange
            local veh   = GetClosestVehicle(range)

            if veh then
                sleep = 0
                local part = Config.Mecanicien.Parts[heldPart]
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(string.format(Lang.Mecanicien.install_prompt, part and part.label or heldPart))
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustReleased(0, 38) then -- E
                    InstallPart(veh, heldPart)
                end
            end
        end

        Wait(sleep)
    end
end)
