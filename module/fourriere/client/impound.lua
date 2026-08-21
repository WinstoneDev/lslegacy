local CFG = Config.Fourriere

local function canImpound()
    if not (LSLegacy and LSLegacy.PlayerData and LSLegacy.PlayerData.job == CFG.Job) then return false end
    if CFG.RequireOnDuty and LocalPlayer.state.policeOnDuty ~= true then return false end
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
                LSLegacy.SendEventToServer('fourriere:impound', { netId = netId, plate = plate, reason = r.label })
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
                LSLegacy.SendEventToServer('fourriere:impound', {
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
            return canImpound() and entity and entity ~= 0
        end,
        onSelect = function(data)
            OpenImpound(data.entity)
        end,
    },
})
