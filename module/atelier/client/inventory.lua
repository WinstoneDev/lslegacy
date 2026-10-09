
Atelier.HeldPart = nil   -- nom de l'item actuellement tenu en main (cosmétique, cf. usable item)
Atelier.HeldProp = nil

local function Notify(msg, type)
    TriggerEvent('notify', 'Atelier', msg, type or 'info', 5000)
end

local function CanUseDepot(companyId)
    return Atelier.IsOnDuty() and Atelier.GetCompanyId() == companyId
end

-- Pièce portée en main (cosmétique)

-- Pose "portage à deux mains" (cf. Config.Atelier.PartHandAnimDict) : sans
-- anim, le prop reste juste accroché à la main, figé, quelle que soit sa taille.
local function StopHeldPartAnim()
    local ped = PlayerPedId()
    if IsEntityPlayingAnim(ped, Config.Atelier.PartHandAnimDict, Config.Atelier.PartHandAnimClip, 3) then
        StopAnimTask(ped, Config.Atelier.PartHandAnimDict, Config.Atelier.PartHandAnimClip, 4.0)
    end
end

local function AttachHeldPart(itemName)
    local part = Config.Atelier.Parts[itemName]
    if not part or not part.carried then return end

    if Atelier.HeldProp and DoesEntityExist(Atelier.HeldProp) then
        DeleteEntity(Atelier.HeldProp)
    end

    -- La pièce est considérée "en main" (débloque la pose [E]/ALT) même si le
    -- prop visuel ne charge pas (nom invalide, modèle manquant) : le cosmétique
    -- ne doit jamais bloquer la mécanique de jeu.
    Atelier.HeldPart = itemName
    Atelier.HeldProp = nil

    local ped = PlayerPedId()
    local dict = Config.Atelier.PartHandAnimDict
    RequestAnimDict(dict)
    local ta = 0
    while not HasAnimDictLoaded(dict) and ta < 100 do Wait(0) ta = ta + 1 end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, Config.Atelier.PartHandAnimClip, 8.0, -8.0, -1, 49, 0, false, false, false)
        RemoveAnimDict(dict)
    end

    local itemDef = Config.Items[itemName]
    if not itemDef or not itemDef.props then return end

    local hash = GetHashKey(itemDef.props)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(100) t = t + 1 end
    if not HasModelLoaded(hash) then return end
    if Atelier.HeldPart ~= itemName then return end -- rangée/remplacée pendant le chargement

    local prop = CreateObject(hash, GetEntityCoords(ped), true, true, true)
    local bone = GetEntityBoneIndexByName(ped, Config.Atelier.PartHandBone)
    local off = Config.Atelier.PartHandOffset
    local rot = Config.Atelier.PartHandRot
    AttachEntityToEntity(prop, ped, bone, off.x, off.y, off.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)

    Atelier.HeldProp = prop
end

-- Range la pièce (touche X) : purement visuel, elle reste dans l'inventaire
-- (ce n'est plus une réservation à restituer, juste un item qu'on repose).
local function DropHeldPart(silent)
    if Atelier.HeldProp and DoesEntityExist(Atelier.HeldProp) then
        DeleteEntity(Atelier.HeldProp)
    end
    StopHeldPartAnim()
    Atelier.HeldPart = nil
    Atelier.HeldProp = nil
    if not silent then Notify('Pièce rangée.', 'info') end
end

-- Pas de RegisterKeyMapping séparé sur X ici : deux commandes liées à la même
-- touche via RegisterKeyMapping ne se déclenchent pas de façon fiable en même
-- temps côté FiveM. C'est client/player/crouch.lua (propriétaire de la touche
-- X) qui appelle Atelier.DropHeldPart() directement quand une pièce est tenue.
function Atelier.GetHeldPart() return Atelier.HeldPart end
function Atelier.DropHeldPart() DropHeldPart() end
function Atelier.ClearHeldPartSilent()
    if Atelier.HeldProp and DoesEntityExist(Atelier.HeldProp) then DeleteEntity(Atelier.HeldProp) end
    StopHeldPartAnim()
    Atelier.HeldPart = nil
    Atelier.HeldProp = nil
end

-- Consommée par le module réparation/carrosserie après une pose validée :
-- l'item a déjà été retiré de l'inventaire côté serveur.
LSLegacy.Events.Register('atelier:partInstalled', function()
    Atelier.ClearHeldPartSilent()
end)

-- Prise en main d'une pièce "carried" (item usable classique, cf.
-- server/inventory.lua -> LSLegacy.RegisterUsableItem) : purement cosmétique.
LSLegacy.Events.Register('atelier:partTaken', function(data)
    if not data or not data.carried then return end
    AttachHeldPart(data.item)
end)

-- Dépôt de pièces — vrai second inventaire (coffre du module inventory/)

local function OpenPartsDepot(companyId)
    if not CanUseDepot(companyId) then Notify(Lang.Atelier.not_on_duty, 'error') return end
    LSLegacy.Events.SendToServer('atelier:openDepot')
end

LSLegacy.Events.Register('atelier:openContainer', function(name, label, maxWeight)
    TriggerEvent('inventory:openContainer', name, label, maxWeight)
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
            sleep = 0
            local label = Config.Items[heldPart] and Config.Items[heldPart].label or heldPart

            -- Le [E] "Poser" ne s'affiche que pour les pièces sans ciblage ALT
            -- (useTarget) et un véhicule à proximité ; [X] "Ranger" est lui
            -- toujours disponible tant que la pièce est tenue.
            local veh = (not part.useTarget) and GetClosestVehicle(Config.Atelier.Actions.installRange) or nil

            BeginTextCommandDisplayHelp('STRING')
            if veh then
                AddTextComponentSubstringPlayerName('~b~[E]~w~ Poser ' .. label .. ' — ~b~[X]~w~ Ranger')
            else
                AddTextComponentSubstringPlayerName('~b~[X]~w~ Ranger ' .. label)
            end
            EndTextCommandDisplayHelp(0, false, true, -1)

            if veh and IsControlJustReleased(0, 38) then -- E
                TriggerEvent('atelier:requestInstallPart', veh, heldPart)
            end
        end

        Wait(sleep)
    end
end)

-- Zone ox_target (dépôt) — une par entreprise

-- Le stock ne se remplit plus "à la main" (ox_lib) : c'est un vrai second
-- inventaire, donc réapprovisionné soit en y déposant des pièces achetées au
-- grossiste (drag&drop, comme un coffre de voiture), soit via la commande de
-- pièces MDT (module/mdt/server/parts.lua, livrée directement dans ce stash).
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
