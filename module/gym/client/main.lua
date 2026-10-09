-- Salle de sport : ox_target sur chaque machine -> validation serveur
-- (job pour la salle police, abonnement pour la salle publique) -> boucle
-- de répétitions (lib.progressBar) qui alimente lslegacy:skillsAddXP,
-- identique au reste du système de compétences (aucune modif de skills.lua).

local CFG = Config.Gym

local function Notify(msg, t)
    TriggerEvent('notify', 'Salle de sport', msg, t or 'info', 5000)
end

-- ── PNJ d'abonnement (salle publique) ────────────────────────────────

local function SpawnSubscriptionNpc()
    local npc = CFG.Public.Npc
    local hash = GetHashKey(npc.model)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do Wait(10); t = t + 1 end
    if not HasModelLoaded(hash) then return end

    local ped = CreatePed(4, hash, npc.coords.x, npc.coords.y, npc.coords.z - 1.0, npc.heading, false, true)
    SetEntityAsMissionEntity(ped, true, true) -- non-networked : sans ça, GTA le supprime comme un ped ambiant quand le joueur s'éloigne
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(hash)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'gym_subscribe',
            icon = 'fa-solid fa-dumbbell',
            label = "S'abonner à la salle de sport",
            distance = 2.5,
            onSelect = function()
                LSLegacy.Events.SendToServer('gym:requestSubscription')
            end,
        },
    })
end

CreateThread(function()
    Wait(1000)
    SpawnSubscriptionNpc()
end)

-- ── Boucle d'entraînement ─────────────────────────────────────────────

local training = false

-- Marche jusqu'à la machine plutôt qu'un téléport (plus réaliste), reprend
-- le pattern de module/interim/client/refuel.lua (WalkToTanker).
local function WalkToMachine(coords, heading)
    local ped = cache.ped
    if not LSLegacy.Validate.Distance(GetEntityCoords(ped), coords, 0.3) then
        TaskGoStraightToCoord(ped, coords.x, coords.y, coords.z, 1.0, 5000, heading, 0.15)
        local elapsed = 0
        while elapsed < 5000 and training and not LSLegacy.Validate.Distance(GetEntityCoords(ped), coords, 0.3) do
            Wait(100)
            elapsed = elapsed + 100
        end
        ClearPedTasks(ped)
    end
    -- Recalage exact une fois arrivé : la marche approche la machine mais ne
    -- garantit pas l'alignement pixel-perfect attendu par le prop/l'anim.
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, heading)
end

local function RunTraining(machineType, coords, heading)
    if training then return end
    training = true

    local typeCfg = CFG.MachineTypes[machineType]
    local a = typeCfg.anim
    local prop = typeCfg.prop

    WalkToMachine(coords, heading or GetEntityHeading(cache.ped))
    if not training then return end

    while training do
        if #(GetEntityCoords(cache.ped) - coords) > (CFG.InteractRange + 1.0) then
            break
        end

        local propArg = nil
        if prop then
            propArg = {
                model = prop.model,
                bone = prop.bone,
                pos = prop.offset,
                rot = prop.rotation,
            }
        end

        local success = lib.progressBar({
            duration = CFG.RepDuration,
            label = 'Entraînement : ' .. typeCfg.label,
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = a.scenario and { scenario = a.scenario } or { dict = a.dict, clip = a.clip, flag = a.flag },
            prop = propArg,
        })

        if not success then break end

        LSLegacy.Events.SendToServer('lslegacy:skillsAddXP', typeCfg.skill)
    end

    training = false
end

LSLegacy.Events.Register('gym:trainingAuthorized', function(machineType, coords, heading)
    RunTraining(machineType, coords, heading)
end)

LSLegacy.Events.Register('gym:trainingDenied', function(reason)
    Notify(reason or 'Accès refusé.', 'error')
end)

LSLegacy.Events.Register('gym:subscriptionResult', function(data)
    if data and data.success then
        Notify(('Abonnement actif jusqu\'au %s.'):format(data.expiresAt), 'success')
    else
        Notify((data and data.reason) or 'Abonnement refusé.', 'error')
    end
end)

-- ── Zones ox_target sur les machines ─────────────────────────────────

local function AddMachineZones(salle, machines)
    for i, m in ipairs(machines) do
        local typeCfg = CFG.MachineTypes[m.type]
        if typeCfg then
            exports.ox_target:addBoxZone({
                coords   = m.coords,
                size     = vector3(1.2, 1.2, 2.0),
                rotation = m.heading,
                debug    = false,
                drawSprite = true,
                options  = {
                    {
                        name = ('gym_train_%s_%d'):format(salle, i),
                        icon = 'fa-solid fa-dumbbell',
                        label = "S'entraîner : " .. typeCfg.label,
                        distance = CFG.InteractRange,
                        canInteract = function() return not training end,
                        onSelect = function()
                            LSLegacy.Events.SendToServer('gym:startTraining', salle, i)
                        end,
                    },
                },
            })
        end
    end
end

AddMachineZones('public', CFG.Public.Machines)
AddMachineZones('police', CFG.Police.Machines)

-- ── Vestiaires : casiers personnels ───────────────────────────────────
-- Un seul DataStore par joueur (gym_locker_<identifiant>) : dépôt et retrait
-- possibles depuis n'importe quel casier de sa salle (homme ou femme).

local function IsMale()
    local ci = LSLegacy.PlayerData.characterInfos
    return ci and ci.Sexe == 'M'
end

local function IsFemale()
    local ci = LSLegacy.PlayerData.characterInfos
    return ci and ci.Sexe == 'F'
end

local LockerRestrictions = { male = IsMale, female = IsFemale }
local allLockerCoords = {}

-- La restriction est vérifiée dans onSelect (avec notif) plutôt que dans
-- canInteract : un canInteract qui rend false rend l'option invisible/grisée
-- sans aucun retour visuel, ce qui ressemble à un bouton mort si le champ
-- characterInfos.Sexe n'est pas encore chargé côté client à ce moment-là.
for _, room in ipairs(CFG.Lockers.Rooms or {}) do
    local canUse = LockerRestrictions[room.restrict]
    local deniedMsg = room.restrict == 'male' and 'Casier réservé aux hommes.' or 'Casier réservé aux femmes.'
    for _, locker in ipairs(room.Coords or {}) do
        allLockerCoords[#allLockerCoords + 1] = { coords = locker.coords, markerColor = room.markerColor }
        exports.ox_target:addBoxZone({
            coords   = locker.coords,
            size     = vector3(1.5, 1.5, 2.0),
            rotation = locker.heading,
            debug    = false,
            drawSprite = true,
            options  = {
                {
                    name = 'gym_locker',
                    icon = 'fa-solid fa-box-archive',
                    label = 'Casier personnel',
                    distance = CFG.InteractRange,
                    onSelect = function()
                        if canUse and not canUse() then
                            Notify(deniedMsg, 'error')
                            return
                        end
                        LSLegacy.Events.SendToServer('gym:openLocker')
                    end,
                },
            },
        })
    end
end

CreateThread(function()
    while true do
        local sleep = 800
        local pcoords = GetEntityCoords(cache.ped)
        for _, locker in ipairs(allLockerCoords) do
            if #(pcoords - locker.coords) < 15.0 then
                sleep = 0
                local mc = locker.markerColor
                DrawMarker(1,
                    locker.coords.x, locker.coords.y, locker.coords.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.6, 0.6, 0.4,
                    mc.r, mc.g, mc.b, mc.a,
                    false, false, 2, false, nil, nil, false)
            end
        end
        Wait(sleep)
    end
end)
