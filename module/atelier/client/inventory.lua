
Atelier.HeldPart = nil   -- nom de l'item actuellement porté en main (ou nil)
Atelier.HeldProp = nil

local function Notify(msg, type)
    TriggerEvent(Config.Atelier.NotifyEvent, 'Atelier', msg, 5000, type or 'info')
end

local function CanUseDepot(companyId)
    return Atelier.IsOnDuty() and Atelier.GetCompanyId() == companyId
end

-- Pièce portée en main

local function AttachHeldPart(itemName)
    local part = Config.Atelier.Parts[itemName]
    if not part or not part.carried then return end

    if Atelier.HeldProp and DoesEntityExist(Atelier.HeldProp) then
        DeleteEntity(Atelier.HeldProp)
    end

    local itemDef = Config.Items[itemName]
    if not itemDef or not itemDef.props then return end

    local ped  = PlayerPedId()
    local hash = GetHashKey(itemDef.props)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(100) t = t + 1 end
    if not HasModelLoaded(hash) then return end

    local prop = CreateObject(hash, GetEntityCoords(ped), true, true, true)
    local bone = GetEntityBoneIndexByName(ped, Config.Atelier.PartHandBone)
    local off  = Config.Atelier.PartHandOffset
    local rot  = Config.Atelier.PartHandRot
    AttachEntityToEntity(prop, ped, bone, off.x, off.y, off.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)

    Atelier.HeldPart = itemName
    Atelier.HeldProp = prop
end

local function DropHeldPart(silent)
    if Atelier.HeldProp and DoesEntityExist(Atelier.HeldProp) then
        DeleteEntity(Atelier.HeldProp)
    end
    Atelier.HeldPart = nil
    Atelier.HeldProp = nil
    LSLegacy.Events.SendToServer('atelier:dropPart')
    if not silent then Notify('Pièce restituée au dépôt.', 'info') end
end

RegisterCommand('atelier_drop_part', function()
    if not Atelier.HeldPart then return end
    DropHeldPart()
end, false)
RegisterKeyMapping('atelier_drop_part', 'Lâcher la pièce portée (Atelier)', 'keyboard', 'G')

function Atelier.GetHeldPart() return Atelier.HeldPart end
function Atelier.ClearHeldPartSilent()
    if Atelier.HeldProp and DoesEntityExist(Atelier.HeldProp) then DeleteEntity(Atelier.HeldProp) end
    Atelier.HeldPart = nil
    Atelier.HeldProp = nil
end

-- Consommée par le module réparation/carrosserie après une pose validée :
-- ne restitue PAS au stock (la pièce a déjà été consommée côté serveur).
LSLegacy.Events.Register('atelier:partInstalled', function()
    Atelier.ClearHeldPartSilent()
end)

-- Dépôt de pièces

local pendingCompany = nil

local function OpenPartsDepot(companyId)
    if not CanUseDepot(companyId) then Notify(Lang.Atelier.not_on_duty, 'error') return end
    if Atelier.HeldPart then Notify(Lang.Atelier.depot_already_holding, 'error') return end
    pendingCompany = companyId
    LSLegacy.Events.SendToServer('atelier:requestStock')
end

LSLegacy.Events.Register('atelier:stockResult', function(stock)
    stock = stock or {}
    local companyId = pendingCompany
    local options = {}

    for itemName, part in pairs(Config.Atelier.Parts) do
        local qty       = stock[itemName] or 0
        local available = qty > 0
        local label     = Config.Items[itemName] and Config.Items[itemName].label or itemName
        options[#options + 1] = {
            title = label .. (available and (' (x' .. qty .. ')') or ' — Rupture de stock'),
            description = available and Lang.Atelier.depot_buy or Lang.Atelier.depot_out_of_stock,
            icon = part.carried and 'fa-solid fa-hand-holding' or 'fa-solid fa-circle-dot',
            disabled = not available,
            onSelect = function()
                LSLegacy.Events.SendToServer('atelier:takePart', { item = itemName })
            end,
        }
    end

    if LSLegacy.Atelier.HasPermission(companyId, Atelier.GetGrade(), 'manage_stock') then
        options[#options + 1] = {
            title = 'Remplir le stock à la main',
            description = "Après achat chez le grossiste (RP)",
            icon = 'fa-solid fa-truck-ramp-box',
            onSelect = function()
                local fillOptions = {}
                for itemName in pairs(Config.Atelier.Parts) do
                    local label = Config.Items[itemName] and Config.Items[itemName].label or itemName
                    fillOptions[#fillOptions + 1] = {
                        title = label .. ' (x' .. (stock[itemName] or 0) .. ')',
                        description = 'Ajouter une quantité au stock',
                        icon = 'fa-solid fa-box-open',
                        onSelect = function()
                            local qtyStr = LSLegacy.KeyboardInput('Quantité à ajouter au stock', 4)
                            local qty    = tonumber(qtyStr)
                            if not qty or qty <= 0 then return end
                            LSLegacy.Events.SendToServer('atelier:restockStock', { item = itemName, amount = math.floor(qty) })
                        end,
                    }
                end
                lib.registerContext({ id = 'atelier_depot_fill', title = 'Remplir le stock', menu = 'atelier_depot', options = fillOptions })
                lib.showContext('atelier_depot_fill')
            end,
        }
    end

    lib.registerContext({ id = 'atelier_depot', title = Lang.Atelier.depot_title, options = options })
    lib.showContext('atelier_depot')
end)

LSLegacy.Events.Register('atelier:restockResult', function(data)
    if not data then return end
    if data.success then
        local label = Config.Items[data.item] and Config.Items[data.item].label or data.item
        Notify(string.format('%s ajouté(s) au stock : %s.', tostring(data.amount), label), 'success')
    end
end)

LSLegacy.Events.Register('atelier:partTaken', function(data)
    if not data then return end
    local label = Config.Items[data.item] and Config.Items[data.item].label or data.item
    Notify(string.format(Lang.Atelier.depot_part_bought, label), 'success')
    if data.carried then
        AttachHeldPart(data.item)
    else
        Atelier.HeldPart = data.item  -- réservé, consommé silencieusement à la pose (pneu, pièce moteur…)
    end
end)

-- Boucle de proximité (pose d'une pièce portée en main, touche E)

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

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local heldPart = Atelier.HeldPart
        local part     = heldPart and Config.Atelier.Parts[heldPart]

        if heldPart and part and part.carried and Atelier.IsOnDuty() then
            local range = Config.Atelier.Actions.installRange
            local veh   = GetClosestVehicle(range)

            if veh then
                sleep = 0
                local label = Config.Items[heldPart] and Config.Items[heldPart].label or heldPart
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('~b~[E]~w~ Poser ' .. label .. ' — ~b~[G]~w~ Lâcher')
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustReleased(0, 38) then -- E
                    TriggerEvent('atelier:requestInstallPart', veh, heldPart)
                end
            end
        end

        Wait(sleep)
    end
end)

-- Zone ox_target (dépôt) — une par entreprise

for companyId, company in pairs(Config.Atelier.Companies) do
    exports.ox_target:addBoxZone({
        coords   = company.partsDepotCoords,
        size     = vector3(1.5, 1.5, 2.0),
        rotation = company.headquartersHeading,
        debug    = false,
        options  = {
            {
                name = 'atelier_depot_' .. companyId,
                icon = 'fa-solid fa-boxes-stacked',
                label = 'Dépôt de pièces',
                distance = 2.0,
                canInteract = function() return CanUseDepot(companyId) end,
                onSelect = function() OpenPartsDepot(companyId) end,
            },
        },
    })
end
