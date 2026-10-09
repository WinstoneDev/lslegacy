local CFG = Config.Fourriere

local function CanImpound()
    if not (LSLegacy and LSLegacy.PlayerData and LSLegacy.PlayerData.job == CFG.Job) then return false end
    if CFG.RequireOnDuty and LocalPlayer.state.policeOnDuty ~= true then return false end
    return true
end

-- La dépanneuse doit pouvoir accrocher un véhicule à l'arrêt et vide —
-- pré-filtrage client, revérifié côté serveur avant tout dispatch.
local function CanTow(entity)
    if GetEntitySpeed(entity) > 0.5 then return false end
    if GetPedInVehicleSeat(entity, -1) ~= 0 then return false end
    if GetVehicleNumberOfPassengers(entity) > 0 then return false end
    return true
end

local function OpenImpound(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    local plate = (GetVehicleNumberPlateText(entity) or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local netId = NetworkGetNetworkIdFromEntity(entity)

    local options = {}
    for _, r in ipairs(CFG.Reasons) do
        local fee = r.fee or CFG.BaseFee
        local dur = r.duration or CFG.BaseDuration
        options[#options + 1] = {
            title = r.label,
            description = ('Taxe : %d $  ·  Immobilisation : %d min'):format(fee, dur),
            icon = 'gavel',
            onSelect = function()
                print(('^3[towtruck]^7 Demande envoyée — netId=%s plate=%s'):format(tostring(netId), tostring(plate)))
                LSLegacy.Events.SendToServer('fourriere:towtruck:call', { netId = netId, plate = plate, reason = r.label })
            end,
        }
    end
    if CFG.AllowCustom then
        options[#options + 1] = {
            title = 'Motif personnalisé',
            description = 'Saisir manuellement le motif, le tarif et la durée',
            icon = 'pen',
            onSelect = function()
                local input = lib.inputDialog(('Fourrière — %s'):format(plate), {
                    { type = 'input',  label = 'Motif',                    required = true, max = 100 },
                    { type = 'number', label = 'Tarif ($)',                required = true, min = 0, default = CFG.BaseFee },
                    { type = 'number', label = "Durée d'immobilisation (min)", required = true, min = 0, default = CFG.BaseDuration },
                })
                if not input then return end
                print(('^3[towtruck]^7 Demande envoyée (motif perso) — netId=%s plate=%s'):format(tostring(netId), tostring(plate)))
                LSLegacy.Events.SendToServer('fourriere:towtruck:call', {
                    netId = netId, plate = plate, custom = true,
                    reason = input[1], fee = input[2], duration = input[3],
                })
            end,
        }
    end
    lib.registerContext({ id = 'fourriere_impound', title = ('Fourrière — %s'):format(plate), options = options })
    lib.showContext('fourriere_impound')
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'fourriere_impound',
        icon = 'fa-solid fa-truck-ramp-box',
        label = 'Mettre en fourrière',
        distance = 3.0,
        canInteract = function(entity)
            return CanImpound() and entity and entity ~= 0 and CanTow(entity)
        end,
        onSelect = function(data)
            OpenImpound(data.entity)
        end,
    },
})
