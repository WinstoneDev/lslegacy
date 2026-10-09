--  MODULE POLICE NATIONALE — Client principal
--  Gestion : prise/fin de service, tenue, armurerie, blips
--  Interactions : ox_target (zones) + ox_lib (menus)

Police = Police or {}
Police.OnDuty    = false
Police.Service   = nil
Police.Unit      = nil
Police.Grade     = 0

local function Notify(msg, type)
    TriggerEvent('notify', 'Police Nationale', msg, type or 'info', Config.Police.NotifyDuration or 30000)
end

-- Utilitaires

local function IsPolice()
    return LSLegacy.PlayerData.job == Config.Police.Job
end

local function GetGrade()
    return tonumber(LSLegacy.PlayerData.job_grade) or 0
end

local function GetGradeLabel()
    local dep = Config.MDT and Config.MDT.Departments and Config.MDT.Departments.police
    if not dep then return 'Agent' end
    local g = dep.grades[GetGrade()]
    return g and g.label or 'Agent'
end

local function GetFullName()
    local ci = LSLegacy.PlayerData.characterInfos
    if ci then
        return (ci.Prenom or '') .. ' ' .. (ci.NDF or '')
    end
    return 'Agent'
end

-- Blips

local function CreateBlips()
    for _, b in ipairs(Config.Police.Blips or {}) do
        local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
        SetBlipSprite(blip, b.sprite)
        SetBlipColour(blip, b.color)
        SetBlipScale(blip, b.scale)
        SetBlipAsShortRange(blip, b.short)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(b.label)
        EndTextCommandSetBlipName(blip)
    end
end

-- Armurerie

local function GiveWeapons(grade)
    -- Cherche les armes du grade le plus proche (descend par paliers)
    local weapons = nil
    for g = grade, 0, -1 do
        if Config.Police.Weapons[g] then
            weapons = Config.Police.Weapons[g]
            break
        end
    end
    if not weapons then return end
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    for _, w in ipairs(weapons) do
        GiveWeaponToPed(ped, GetHashKey(w.weapon), w.ammo, false, false)
    end
end

-- Prise de service

local function GoOnDuty()
    if Police.OnDuty then Notify(Lang.Police.already_on_duty, 'error') return end
    Police.OnDuty  = true
    Police.Service = nil
    Police.Unit    = nil
    Police.Grade   = GetGrade()

    GiveWeapons(Police.Grade)

    LSLegacy.Events.SendToServer('police:onDuty', { service = nil, unit = nil })
    Notify(Lang.Police.duty_on, 'success')
    TriggerEvent('police:dutyChanged', true)
end

-- L'unité réelle (affectation active gérée par la hiérarchie) est résolue
-- côté serveur ; on la reçoit ici pour affichage (HUD, radio...).
LSLegacy.Events.Register('police:onDutyResult', function(data)
    if not data then return end
    Police.Unit = data.unit
end)

local function GoOffDuty()
    if not Police.OnDuty then Notify(Lang.Police.already_off_duty, 'error') return end
    Police.OnDuty  = false
    Police.Service = nil
    Police.Unit    = nil

    RemoveAllPedWeapons(PlayerPedId(), true)
    LSLegacy.Events.SendToServer('police:offDuty')
    Notify(Lang.Police.duty_off, 'info')
    TriggerEvent('police:dutyChanged', false)
end

-- Menu prise de service

local function ToggleDuty()
    if not IsPolice() then Notify(Lang.Police.not_police, 'error') return end
    if Police.OnDuty then
        GoOffDuty()
    else
        GoOnDuty()
    end
end

-- Zones ox_target (Commissariat)
-- Prise/fin de service : gérée via le MDT (Police.ToggleDuty), plus de point physique dédié.

exports.ox_target:addBoxZone({
    coords   = Config.Police.ArmoryCoords,
    size     = vector3(3.0, 3.0, 3.0),
    rotation = Config.Police.HeadquartersHeading,
    debug    = false,
    drawSprite = true,
    options  = {
        {
            name = 'police_armory',
            icon = 'fa-solid fa-gun',
            label = 'Armurerie',
            distance = 2.0,
            canInteract = function() return IsPolice() end,
            onSelect = function()
                if not Police.OnDuty then Notify(Lang.Police.not_police, 'error') return end
                GiveWeapons(Police.Grade)
                Notify('Armurerie rechargée.', 'success')
            end,
        },
    },
})

exports.ox_target:addBoxZone({
    coords   = Config.Police.LockerCoords,
    size     = vector3(3.0, 3.0, 3.0),
    rotation = Config.Police.HeadquartersHeading,
    debug    = false,
    drawSprite = true,
    options  = {
        {
            name = 'police_locker',
            icon = 'fa-solid fa-box-archive',
            label = 'Casier personnel',
            distance = 2.0,
            canInteract = function() return IsPolice() end,
            onSelect = function() LSLegacy.Events.SendToServer('police:openLocker') end,
        },
    },
})

-- Coffre à preuves (Pôle Judiciaire) : stockage partagé, pas personnel.
exports.ox_target:addBoxZone({
    coords   = Config.Police.EvidenceLocker.coords,
    size     = vector3(3.0, 3.0, 3.0),
    rotation = Config.Police.EvidenceLocker.heading,
    debug    = false,
    drawSprite = true,
    options  = {
        {
            name = 'police_evidence_locker',
            icon = 'fa-solid fa-box-archive',
            label = 'Coffre à preuves',
            distance = 2.0,
            canInteract = function() return IsPolice() end,
            onSelect = function() LSLegacy.Events.SendToServer('police:openEvidenceLocker') end,
        },
    },
})

-- Postes d'analyse des preuves (Pôle Judiciaire) : coordonnées réservées
-- dans Config.Police.EvidenceAnalysisStations, pas d'interaction tant que
-- les items preuve n'existent pas.

-- Salles de casiers dédiées (accès restreint par sexe ou unité RAID/BRI)
local function IsRaidOrBri()
    return Police.Unit == 'raid' or Police.Unit == 'bri'
end

local LockerRestrictions = {
    female  = function() return LSLegacy.PlayerData.characterInfos and LSLegacy.PlayerData.characterInfos.Sexe == 'F' end,
    male    = function() return LSLegacy.PlayerData.characterInfos and LSLegacy.PlayerData.characterInfos.Sexe == 'M' end,
    raidbri = IsRaidOrBri,
}

for _, room in ipairs(Config.Police.LockerRooms or {}) do
    local canUse = LockerRestrictions[room.restrict]
    exports.ox_target:addBoxZone({
        coords   = room.coords,
        size     = vector3(3.0, 3.0, 3.0),
        rotation = room.heading,
        debug    = false,
        drawSprite = true,
        options  = {
            {
                name = 'police_locker_room',
                icon = 'fa-solid fa-box-archive',
                label = 'Casier personnel',
                distance = 2.0,
                canInteract = function() return IsPolice() and canUse and canUse() end,
                onSelect = function() LSLegacy.Events.SendToServer('police:openLocker') end,
            },
        },
    })
end

-- PNJ du nouveau commissariat — Armurier/Chef de poste/Armurier RAID ouvrent
-- le menu d'armurerie (module/police/client/armory.lua) ; Cafétéria décoratif.

-- Le budget de 1s (100×10ms) utilisé avant était trop court quand le
-- streaming est chargé (spawn du joueur, plusieurs modèles demandés à la
-- suite) : RequestModel n'avait pas fini, HasModelLoaded restait false et le
-- PNJ était silencieusement abandonné — d'où des PNJ absents de façon
-- aléatoire. Budget élargi à 10s + SetEntityAsMissionEntity pour éviter que
-- le moteur ne le nettoie ensuite comme une entité ambiante.
local function SpawnPoliceNpc(npc, options)
    local model = npc.models[math.random(#npc.models)]
    local hash = GetHashKey(model)
    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(50) end
    if not HasModelLoaded(hash) then
        Config.Development.Print(("PNJ police : modèle %s non chargé, abandon."):format(model))
        return
    end

    local ped = CreatePed(4, hash, npc.coords.x, npc.coords.y, npc.coords.z - 1.0, npc.heading, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(hash)

    if options then
        exports.ox_target:addLocalEntity(ped, options)
    end

    return ped
end

-- Handles exposés en globales (et non en local) pour que armory.lua, dans un
-- autre fichier du même resource, puisse y jouer l'animation d'installation.
PoliceArmoryPeds = {}

CreateThread(function()
    Wait(1000)
    PoliceArmoryPeds.armurier = SpawnPoliceNpc(Config.Police.ArmorerNpc, {
        {
            name = 'police_armory_armurier', icon = 'fa-solid fa-screwdriver-wrench', label = 'Accessoires',
            distance = 2.0,
            onSelect = function() LSLegacy.Events.SendToServer('police:armory:open', { pnj = 'armurier' }) end,
        },
    })
    SpawnPoliceNpc(Config.Police.StationChiefNpc, {
        {
            name = 'police_armory_chef', icon = 'fa-solid fa-vault', label = 'Armurerie',
            distance = 4.0, -- PNJ derrière un bas-flanc, portée augmentée
            onSelect = function() LSLegacy.Events.SendToServer('police:armory:open', { pnj = 'chef' }) end,
        },
    })
    PoliceArmoryPeds.raid = SpawnPoliceNpc(Config.Police.RaidArmorerNpc, {
        {
            name = 'police_armory_raid', icon = 'fa-solid fa-vault', label = 'Armurerie RAID',
            distance = 2.0,
            onSelect = function() LSLegacy.Events.SendToServer('police:armory:open', { pnj = 'raid' }) end,
        },
    })
    SpawnPoliceNpc(Config.Police.CafeteriaNpc)
end)

-- Events serveur → client


-- Init

Citizen.CreateThread(function()
    Wait(2000)
    CreateBlips()
end)

-- Exporter l'état pour les autres sous-modules
function Police.IsOnDuty() return Police.OnDuty end
function Police.GetService() return Police.Service end
function Police.GetUnit() return Police.Unit end
function Police.GetGrade() return Police.Grade end
function Police.GetName() return GetFullName() end
function Police.ToggleDuty() ToggleDuty() end

-- Prise de service depuis le tableau de bord du MDT. On s'enregistre dans
-- le registre du cœur MDT plutôt que de lui faire connaître ce module :
-- la borne du commissariat et le MDT appellent exactement la même bascule.
LSLegacy.MDT = LSLegacy.MDT or {}
LSLegacy.MDT.DutyToggles = LSLegacy.MDT.DutyToggles or {}
LSLegacy.MDT.DutyToggles['police'] = {
    toggle   = ToggleDuty,
    isOnDuty = function() return Police.OnDuty end,
}

--  STATISTIQUES D'AGENT — /policestats [id] (ouvert à toute force de l'ordre en service ;
--  consulter un autre agent nécessite le grade manage_personnel, vérifié côté serveur)

RegisterCommand('policestats', function(_, args)
    if not LSLegacy.MDT.IsLocalLeoOnDuty() then
        Notify('Vous devez être en service.', 'error')
        return
    end
    LSLegacy.Events.SendToServer('police:getStats', { target = tonumber(args[1]) })
end, false)

LSLegacy.Events.Register('police:statsResult', function(data)
    if not data then return end

    local hours   = math.floor(data.dutySeconds / 3600)
    local minutes = math.floor((data.dutySeconds % 3600) / 60)

    local content = string.format(
        '**Interpellations**\n- GAV posées : %d\n- Incarcérations : %d\n\n' ..
        '**Verbalisation**\n- Amendes : %d (%d$ au total)\n\n' ..
        '**Terrain**\n- Fouilles / palpations : %d\n- Prélèvements PTS : %d\n\n' ..
        '**Service**\n- Temps cumulé : %dh%02dmin',
        data.custodyCount, data.prisonCount,
        data.finesCount, data.finesAmount,
        data.searchesCount, data.evidenceCount,
        hours, minutes
    )

    lib.alertDialog({
        header   = 'Statistiques — ' .. data.name,
        content  = content,
        centered = true,
    })
end)
