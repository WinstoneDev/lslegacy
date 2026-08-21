--   MENU ADMIN  –  LSLegacy  (NUI)

local AM = {
    opened              = false,
    AllPlayers          = nil,
    -- Joueur sélectionné
    IdSelected   = nil,
    NameSelected = nil,
    SelectedData = nil,
    -- Warns
    WarnsList    = {},
    -- Stats tickets
    AvgProcessingTime = nil,
    -- Tickets
    OpenTickets   = {},
    TakenTickets  = {},
    ClosedTickets = {},
    -- Flags de navigation / flow
    EcoSelect               = false,
    PendingNavPlayerActions = false,
    PendingInventoryReopen  = false,
    -- Outils
    Tools = {
        godmode   = false,
        invisible = false,
        showIds   = false,
        showCoords= false,
        blips     = false,
    },
    PlayerBlips = {},
    -- Snapshot serveur (id, coords, noms) pour showIds/blips — compatible OneSync Infinity
    PlayersSnapshot = {},
    Tracking        = false,
    -- Prise de service staff (gate NoClip + ciblage rapide ox_target)
    OnDuty      = false,
    OnlineStaff = {},
    -- Changement job/faction (menu Économie)
    Jobs     = nil,
    Factions = nil,
    -- Horloge in-game (indépendant du cycle météo dynamique)
    TimeFrozen = false,
}

-- Abonnement au suivi joueurs (showIds / blips)
-- N'active la diffusion serveur que si l'un des deux outils est utilisé, pour
-- ne pas balancer une snapshot de tous les joueurs toutes les secondes pour rien.
local function AM_SyncTracking()
    local needed = AM.Tools.showIds or AM.Tools.blips
    if needed ~= AM.Tracking then
        AM.Tracking = needed
        LSLegacy.SendEventToServer('admin:trackPlayers', needed)
        if not needed then AM.PlayersSnapshot = {} end
    end
end

-- Formatage de date MySQL → DD/MM/YYYY HH:MM
local function FormatDate(val)
    if not val then return '?' end
    -- String "YYYY-MM-DD HH:MM:SS" (mysql-async)
    local s = tostring(val)
    local y, mo, d, h, mi = s:match('(%d%d%d%d)-(%d%d)-(%d%d) (%d%d):(%d%d)')
    if y then return d .. '/' .. mo .. '/' .. y .. ' ' .. h .. ':' .. mi end
    -- Nombre : timestamp Unix en ms (oxmysql) → calcul Lua pur (os.date n'existe pas client-side)
    local ts = tonumber(val)
    if ts then
        local t  = math.floor(ts > 1e10 and ts / 1000 or ts) + 7200  -- UTC → UTC+2
        local hh = math.floor((t % 86400) / 3600)
        local mm = math.floor((t % 3600)  / 60)
        local days = math.floor(t / 86400)
        local yr = 1970
        while true do
            local diy = (yr % 4 == 0 and (yr % 100 ~= 0 or yr % 400 == 0)) and 366 or 365
            if days < diy then break end
            days = days - diy
            yr   = yr + 1
        end
        local mths = {31,28,31,30,31,30,31,31,30,31,30,31}
        if yr % 4 == 0 and (yr % 100 ~= 0 or yr % 400 == 0) then mths[2] = 29 end
        local mth = 1
        for i = 1, 12 do
            if days < mths[i] then mth = i; break end
            days = days - mths[i]
        end
        return string.format('%02d/%02d/%04d %02d:%02d', days + 1, mth, yr, hh, mm)
    end
    return s
end

-- Niveau de permission local
local function GetMyLevel()
    if not LSLegacy.PlayerData or not LSLegacy.PlayerData.group then return 0 end
    for k, v in pairs(Config.StaffGroups) do
        if v == LSLegacy.PlayerData.group then return k end
    end
    return 0
end

-- Données statiques
local TimePresets = {
    { label = "Nuit          (00h)", h = 0,  m = 0 },
    { label = "Aube          (06h)", h = 6,  m = 0 },
    { label = "Matin         (08h)", h = 8,  m = 0 },
    { label = "Midi          (12h)", h = 12, m = 0 },
    { label = "Après-midi    (15h)", h = 15, m = 0 },
    { label = "Soir          (18h)", h = 18, m = 0 },
    { label = "Nuit tombante (21h)", h = 21, m = 0 },
}

-- Listes Give item / Give arme (construites une fois depuis Config.Items)
local GiveItemList = {}
local GiveWeaponList = {}
for name, data in pairs(Config.Items) do
    if name:find('^weapon_') then
        local ammoEntry = Config.AmmoForWeapon[name]
        local ammoNames = type(ammoEntry) == 'table' and ammoEntry or (ammoEntry and { ammoEntry } or {})
        local ammoLabels = {}
        for _, ammoName in ipairs(ammoNames) do
            local ammoItem = Config.Items[ammoName]
            if ammoItem then ammoLabels[#ammoLabels + 1] = ammoItem.label end
        end
        GiveWeaponList[#GiveWeaponList + 1] = {
            name  = name,
            label = data.label,
            desc  = #ammoLabels > 0 and ("Munitions compatibles : " .. table.concat(ammoLabels, ", ")) or "Pas de munitions (arme blanche / usage unique)",
        }
    else
        GiveItemList[#GiveItemList + 1] = { name = name, label = data.label }
    end
end
table.sort(GiveItemList,   function(a, b) return a.label < b.label end)
table.sort(GiveWeaponList, function(a, b) return a.label < b.label end)

-- DrawText HUD
local function DrawTextAdmin(msg, font, size, posx, posy)
    SetTextFont(font)
    SetTextProportional(0)
    SetTextScale(size, size)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextEntry("STRING")
    AddTextComponentString(msg or "null")
    DrawText(posx, posy)
end

-- Petits helpers de diffusion d'état vers la NUI
local function AM_PushSelected()
    SendNUIMessage({ action = 'admin:state', key = 'selected', data = { id = AM.IdSelected, name = AM.NameSelected, data = AM.SelectedData } })
end
local function AM_PushTools()
    SendNUIMessage({ action = 'admin:state', key = 'tools', data = AM.Tools })
end
local function AM_PushDuty()
    SendNUIMessage({ action = 'admin:state', key = 'duty', data = AM.OnDuty })
end
local function AM_PushTickets()
    SendNUIMessage({ action = 'admin:state', key = 'tickets', data = {
        open = AM.OpenTickets, taken = AM.TakenTickets, closed = AM.ClosedTickets, avg = AM.AvgProcessingTime,
    } })
end

-- Fermeture forcée de la NUI
function AM:HideAllMenus()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'admin:hide' })
end

-- Ouverture du menu
function AM:OpenMenu()
    if AM.opened then
        AM.opened = false
        AM:HideAllMenus()
        return
    end

    if GetMyLevel() < 1 then
        LSLegacy.ShowNotification("Administration", "Vous n'avez pas les permissions.", "error")
        return
    end

    -- Nettoyer tout état résiduel avant d'ouvrir (évite double rendu après spectate/inventaire)
    AM:HideAllMenus()
    AM.opened = true

    local openTo = nil
    if AM.PendingNavPlayerActions then
        AM.PendingNavPlayerActions = false
        openTo = 'playerActions'
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'admin:open',
        data = {
            lvl          = GetMyLevel(),
            duty         = AM.OnDuty,
            tools        = AM.Tools,
            inSpec       = Administration.InSpec,
            giveItems    = GiveItemList,
            giveWeapons  = GiveWeaponList,
            timePresets  = TimePresets,
            timeFrozen   = AM.TimeFrozen,
            openTo       = openTo,
            selected     = { id = AM.IdSelected, name = AM.NameSelected, data = AM.SelectedData },
        }
    })
end

--   ACTIONS NUI  (remplace les anciens onSelected/onChecked RageUI)

local Actions = {}

-- Entrée d'onglet (mêmes effets de bord que les anciens boutons du menu principal)
Actions.enterPlayers = function()
    LSLegacy.SendEventToServer('AdminServerPlayers')
    AM.WarnsList = {}
    return { ok = true }
end

Actions.enterTickets = function()
    AM.OpenTickets, AM.TakenTickets, AM.ClosedTickets, AM.AvgProcessingTime = {}, {}, {}, nil
    LSLegacy.SendEventToServer('admin:getTickets', '')
    LSLegacy.SendEventToServer('admin:getTicketStats')
    return { ok = true }
end

Actions.enterStaffOnline = function()
    LSLegacy.SendEventToServer('admin:getOnlineStaff')
    return { ok = true }
end

-- Sélection joueur
Actions.selectPlayer = function(data)
    local source = tonumber(data.source)
    if not source or not AM.AllPlayers then return { error = 'Joueur introuvable.' } end
    local found = nil
    for _, v in pairs(AM.AllPlayers) do
        if v.source == source then found = v break end
    end
    if not found then return { error = 'Joueur introuvable.' } end

    AM.IdSelected   = source
    AM.NameSelected = found.characterInfos and (found.characterInfos.Prenom .. ' ' .. found.characterInfos.NDF) or ('Joueur ' .. source)
    AM.SelectedData = found
    AM.WarnsList    = {}
    LSLegacy.SendEventToServer('admin:getWarns', source)
    LSLegacy.SendEventToServer('admin:getBankInfo', source)

    local nav = 'playerActions'
    if AM.EcoSelect then
        AM.EcoSelect = false
        nav = 'economy'
    end
    return { ok = true, nav = nav, selected = { id = AM.IdSelected, name = AM.NameSelected, data = AM.SelectedData } }
end

-- Informations / actions joueur
Actions.logIdentifiers = function()
    if GetMyLevel() < 3 or not AM.IdSelected then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:logIdentifiers', AM.IdSelected)
    return { ok = true }
end

Actions.viewInventory = function()
    if GetMyLevel() < 2 or not AM.IdSelected then return { error = 'Action refusée.' } end
    AM.PendingInventoryReopen = true
    AM.opened = false
    AM:HideAllMenus()
    LSLegacy.SendEventToServer('admin:getPlayerInventory', AM.IdSelected)
    return { ok = true }
end

Actions.tpToPlayer = function()
    if GetMyLevel() < 2 or not AM.IdSelected then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('TeleportPlayers', 'tp', AM.IdSelected)
    LSLegacy.ShowNotification("Administration", "Téléportation vers le joueur.", "success")
    return { ok = true }
end

Actions.bringPlayer = function()
    if GetMyLevel() < 2 or not AM.IdSelected then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('TeleportPlayers', 'bring', AM.IdSelected)
    LSLegacy.ShowNotification("Administration", "Joueur téléporté vers vous.", "success")
    return { ok = true }
end

Actions.freezePlayer = function(data)
    if GetMyLevel() < 2 or not AM.IdSelected then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:freeze', AM.IdSelected, not not data.state)
    return { ok = true }
end

Actions.spectatePlayer = function()
    if GetMyLevel() < 1 or not AM.IdSelected then return { error = 'Action refusée.' } end
    local targetId = AM.IdSelected
    AM.opened = false
    AM:HideAllMenus()
    Citizen.CreateThread(function()
        Wait(200)
        for _, player in ipairs(GetActivePlayers()) do
            if GetPlayerServerId(player) == targetId then
                if not Administration.InSpec then
                    Administration:Spectate()
                    Wait(100)
                end
                Administration:StartSpectate({ id = player, pos = GetEntityCoords(GetPlayerPed(player)) })
                return
            end
        end
        LSLegacy.ShowNotification("Administration", "Joueur hors de portée ou déconnecté.", "error")
    end)
    return { ok = true }
end

Actions.healPlayer = function()
    if GetMyLevel() < 2 or not AM.IdSelected then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:heal', AM.IdSelected)
    return { ok = true }
end

Actions.revivePlayer = function()
    if GetMyLevel() < 2 or not AM.IdSelected then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:revive', AM.IdSelected)
    return { ok = true }
end

Actions.resetNeeds = function()
    if GetMyLevel() < 2 or not AM.IdSelected then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:resetNeeds', AM.IdSelected)
    LSLegacy.ShowNotification("Administration", "Besoins réinitialisés.", "success")
    return { ok = true }
end

Actions.resetSkin = function()
    if GetMyLevel() < 3 or not AM.IdSelected then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:resetSkin', AM.IdSelected)
    return { ok = true }
end

-- Véhicule joueur
Actions.repairVehicle = function()
    if GetMyLevel() < 3 or not AM.IdSelected then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:repairVehicle', AM.IdSelected)
    return { ok = true }
end

Actions.deletePlayerVehicle = function()
    if GetMyLevel() < 3 or not AM.IdSelected then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:deletePlayerVehicle', AM.IdSelected)
    return { ok = true }
end

Actions.spawnVehicleForPlayer = function(data)
    if GetMyLevel() < 3 or not AM.IdSelected then return { error = 'Action refusée.' } end
    local model = tostring(data.model or '')
    if model == '' then return { error = 'Modèle invalide.' } end
    LSLegacy.SendEventToServer('admin:spawnVehicleForPlayer', AM.IdSelected, model)
    AM.opened = false
    AM:HideAllMenus()
    return { ok = true }
end

-- Sanctions
Actions.warnPlayer = function(data)
    if GetMyLevel() < 2 or not AM.IdSelected then return { error = 'Action refusée.' } end
    local reason = tostring(data.reason or '')
    if reason == '' then return { error = 'Raison requise.' } end
    LSLegacy.SendEventToServer('admin:warn', AM.IdSelected, reason)
    LSLegacy.ShowNotification("Sanction", "Warn envoyé.", "success")
    LSLegacy.SendEventToServer('admin:getWarns', AM.IdSelected)
    return { ok = true }
end

Actions.deleteWarn = function(data)
    if GetMyLevel() < 4 or not AM.IdSelected then return { error = 'Action refusée.' } end
    local warnId = tonumber(data.warnId)
    if not warnId then return { error = 'Warn invalide.' } end
    LSLegacy.SendEventToServer('admin:deleteWarn', warnId, AM.IdSelected)
    LSLegacy.ShowNotification("Sanctions", "Warn #" .. tostring(warnId) .. " supprimé.", "success")
    return { ok = true }
end

Actions.kickPlayer = function(data)
    if GetMyLevel() < 2 or not AM.IdSelected then return { error = 'Action refusée.' } end
    local reason = tostring(data.reason or '')
    if reason == '' then return { error = 'Raison requise.' } end
    LSLegacy.SendEventToServer('admin:kick', AM.IdSelected, reason)
    return { ok = true }
end

Actions.tempbanPlayer = function(data)
    if GetMyLevel() < 3 or not AM.IdSelected then return { error = 'Action refusée.' } end
    local hours  = tonumber(data.hours)
    local reason = tostring(data.reason or '')
    if not hours or reason == '' then return { error = 'Durée/raison invalide.' } end
    LSLegacy.SendEventToServer('admin:tempban', AM.IdSelected, hours, reason)
    LSLegacy.ShowNotification("Sanction", "Tempban appliqué.", "success")
    return { ok = true }
end

Actions.permabanPlayer = function(data)
    if GetMyLevel() < 4 or not AM.IdSelected then return { error = 'Action refusée.' } end
    local reason = tostring(data.reason or '')
    if reason == '' then return { error = 'Raison requise.' } end
    LSLegacy.SendEventToServer('admin:permaban', AM.IdSelected, reason)
    LSLegacy.ShowNotification("Sanction", "Ban permanent appliqué.", "success")
    return { ok = true }
end

Actions.screenshotPlayer = function()
    if GetMyLevel() < 2 or not AM.IdSelected then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:screenshot', AM.IdSelected)
    LSLegacy.ShowNotification("Administration", "Screenshot en cours...", "info")
    return { ok = true }
end

-- Tickets
Actions.openTickets = function(data)
    local status = tostring(data.status or '')
    local minLvl = (status == 'closed') and 2 or 1
    if GetMyLevel() < minLvl then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:getTickets', status)
    return { ok = true }
end

Actions.takeTicket = function(data)
    local ticketId = tonumber(data.ticketId)
    if GetMyLevel() < 1 or not ticketId then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:takeTicket', ticketId)
    return { ok = true }
end

Actions.closeTicket = function(data)
    local ticketId = tonumber(data.ticketId)
    if GetMyLevel() < 1 or not ticketId then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:closeTicket', ticketId)
    return { ok = true }
end

Actions.tpToTicket = function(data)
    local ticketId = tonumber(data.ticketId)
    if GetMyLevel() < 1 or not ticketId then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:tpToTicket', ticketId)
    return { ok = true }
end

Actions.bringTicketPlayer = function(data)
    local ticketId = tonumber(data.ticketId)
    if GetMyLevel() < 1 or not ticketId then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:bringTicketPlayer', ticketId)
    return { ok = true }
end

Actions.messageTicketPlayer = function(data)
    local playerId = tonumber(data.playerId)
    if GetMyLevel() < 1 or not playerId then return { error = 'Action refusée.' } end
    local msg = tostring(data.msg or '')
    if msg == '' then return { error = 'Message requis.' } end
    LSLegacy.SendEventToServer('MessageAdmin', playerId, msg)
    return { ok = true }
end

-- Véhicules (admin)
Actions.spawnVehicle = function(data)
    if GetMyLevel() < 3 then return { error = 'Action refusée.' } end
    local model = tostring(data.model or '')
    if model == '' then return { error = 'Modèle invalide.' } end
    LSLegacy.SendEventToServer('admin:spawnVehicle', model)
    AM.opened = false
    AM:HideAllMenus()
    return { ok = true }
end

Actions.deleteVehiclesZone = function(data)
    local radius = tonumber(data.radius) or 0
    local needLvl = radius >= 150 and 4 or 3
    if GetMyLevel() < needLvl then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:deleteVehiclesInZone', radius)
    return { ok = true }
end

-- Monde / Serveur
-- L'heure est déléguée à codem-dynamicweather (exports:setTime), seule
-- ressource qui pilote réellement l'horloge en jeu sur ce serveur — le
-- serveur envoie ensuite la confirmation/erreur (ex. ressource arrêtée).
Actions.setTime = function(data)
    if GetMyLevel() < 2 then return { error = 'Action refusée.' } end
    local h = tonumber(data.h) or 0
    local m = tonumber(data.m) or 0
    LSLegacy.SendEventToServer('admin:setWorldTime', h, m)
    return { ok = true }
end

-- Indépendant de la météo dynamique (/weathercycle) : gèle/dégèle
-- uniquement l'horloge in-game, sur sa valeur courante.
Actions.toggleTimeFrozen = function(data)
    if GetMyLevel() < 2 then return { error = 'Action refusée.' } end
    local state = not not data.state
    AM.TimeFrozen = state
    LSLegacy.SendEventToServer('admin:setTimeFrozen', state)
    SendNUIMessage({ action = 'admin:state', key = 'timeFrozen', data = AM.TimeFrozen })
    return { ok = true }
end

-- Économie
-- Messages d'erreur détaillés (au lieu d'un "Action refusée" générique) pour
-- pouvoir diagnostiquer immédiatement pourquoi une action Économie est
-- bloquée : niveau insuffisant ou cible manquante.
local function AM_EconGate()
    if GetMyLevel() < 4 then return { error = 'Niveau insuffisant (superadmin/dev requis).' } end
    if not AM.IdSelected then return { error = 'Aucune cible sélectionnée.' } end
    return nil
end

Actions.ecoSelectTarget = function()
    AM.EcoSelect = true
    LSLegacy.SendEventToServer('AdminServerPlayers')
    return { ok = true }
end

Actions.giveMoney = function(data)
    local gate = AM_EconGate()
    if gate then return gate end
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then return { error = 'Montant invalide.' } end
    LSLegacy.SendEventToServer('admin:giveMoney', AM.IdSelected, amount, not not data.bank)
    return { ok = true }
end

Actions.removeMoney = function(data)
    local gate = AM_EconGate()
    if gate then return gate end
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then return { error = 'Montant invalide.' } end
    LSLegacy.SendEventToServer('admin:removeMoney', AM.IdSelected, amount, not not data.bank)
    return { ok = true }
end

Actions.giveItem = function(data)
    local gate = AM_EconGate()
    if gate then return gate end
    local name = tostring(data.name or '')
    local qty  = tonumber(data.qty)
    if name == '' or not qty or qty <= 0 then return { error = 'Item/quantité invalide.' } end
    LSLegacy.SendEventToServer('admin:giveItem', AM.IdSelected, name, qty)
    return { ok = true }
end

Actions.giveWeapon = function(data)
    local gate = AM_EconGate()
    if gate then return gate end
    local name = tostring(data.name or '')
    if name == '' then return { error = 'Arme invalide.' } end
    LSLegacy.SendEventToServer('admin:giveWeapon', AM.IdSelected, name, tonumber(data.ammo) or 50)
    return { ok = true }
end

Actions.loadJobsFactions = function()
    local gate = AM_EconGate()
    if gate then return gate end
    LSLegacy.SendEventToServer('admin:getJobsFactions')
    return { ok = true }
end

Actions.setPlayerJob = function(data)
    local gate = AM_EconGate()
    if gate then return gate end
    local jobKey   = tostring(data.jobKey or '')
    local gradeKey = tonumber(data.gradeKey)
    if jobKey == '' or not gradeKey then return { error = 'Job/grade invalide.' } end
    LSLegacy.SendEventToServer('admin:setPlayerJob', AM.IdSelected, jobKey, gradeKey)
    return { ok = true }
end

Actions.setPlayerFaction = function(data)
    local gate = AM_EconGate()
    if gate then return gate end
    local factionKey = tostring(data.factionKey or '')
    local gradeKey    = tonumber(data.gradeKey)
    if factionKey == '' or not gradeKey then return { error = 'Faction/grade invalide.' } end
    LSLegacy.SendEventToServer('admin:setPlayerFaction', AM.IdSelected, factionKey, gradeKey)
    return { ok = true }
end

-- Outils Staff
Actions.toggleDuty = function(data)
    if GetMyLevel() < 1 then return { error = 'Action refusée.' } end
    local state = not not data.state
    AM.OnDuty = state
    LSLegacy.SendEventToServer('admin:setDuty', state)

    if state then
        LSLegacy.ShowNotification("Administration", "Vous êtes en service (staff).", "success")
    else
        LSLegacy.ShowNotification("Administration", "Fin de service (staff).", "warning")
        -- Coupe tous les outils actifs en quittant le service (évite de laisser
        -- godmode/invisible/etc actifs par erreur en pleine session RP)
        if Administration.InSpec then Administration:Spectate() end
        if AM.Tools.invisible then
            AM.Tools.invisible = false
            SetEntityVisible(PlayerPedId(), true, true)
            SetLocalPlayerVisibleLocally(true)
        end
        if AM.Tools.godmode then
            AM.Tools.godmode = false
            LSLegacy.SendEventToServer('admin:setGodmode', false)
        end
        AM.Tools.showIds    = false
        AM.Tools.showCoords = false
        if AM.Tools.blips then
            AM.Tools.blips = false
            for _, blip in pairs(AM.PlayerBlips) do
                if DoesBlipExist(blip) then RemoveBlip(blip) end
            end
            AM.PlayerBlips = {}
        end
        AM_SyncTracking()
    end

    AM_PushDuty()
    AM_PushTools()
    SendNUIMessage({ action = 'admin:state', key = 'inSpec', data = Administration.InSpec })
    return { ok = true }
end

Actions.toggleNoclip = function(data)
    if GetMyLevel() < 1 or not AM.OnDuty then return { error = 'Action refusée.' } end
    if data.state then
        AM.opened = false
        AM:HideAllMenus()
        Administration:Spectate()
    else
        if Administration.InSpec then Administration:Spectate() end
    end
    return { ok = true }
end

Actions.toggleInvisible = function(data)
    if GetMyLevel() < 2 or not AM.OnDuty then return { error = 'Action refusée.' } end
    local state = not not data.state
    AM.Tools.invisible = state
    SetEntityVisible(PlayerPedId(), not state, not state)
    SetLocalPlayerVisibleLocally(not state)
    AM_PushTools()
    return { ok = true }
end

Actions.toggleGodmode = function(data)
    if GetMyLevel() < 3 or not AM.OnDuty then return { error = 'Action refusée.' } end
    local state = not not data.state
    AM.Tools.godmode = state
    LSLegacy.SendEventToServer('admin:setGodmode', state)
    LSLegacy.ShowNotification("Outils", state and "Godmode activé." or "Godmode désactivé.", state and "success" or "warning")
    AM_PushTools()
    return { ok = true }
end

Actions.toggleShowIds = function(data)
    if GetMyLevel() < 1 or not AM.OnDuty then return { error = 'Action refusée.' } end
    AM.Tools.showIds = not not data.state
    AM_SyncTracking()
    AM_PushTools()
    return { ok = true }
end

Actions.toggleShowCoords = function(data)
    if GetMyLevel() < 1 or not AM.OnDuty then return { error = 'Action refusée.' } end
    AM.Tools.showCoords = not not data.state
    AM_PushTools()
    return { ok = true }
end

Actions.toggleBlips = function(data)
    if GetMyLevel() < 2 or not AM.OnDuty then return { error = 'Action refusée.' } end
    local state = not not data.state
    AM.Tools.blips = state
    AM_SyncTracking()
    if not state then
        for _, blip in pairs(AM.PlayerBlips) do
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
        AM.PlayerBlips = {}
    end
    AM_PushTools()
    return { ok = true }
end

Actions.tpMarker = function()
    if GetMyLevel() < 2 or not AM.OnDuty then return { error = 'Action refusée.' } end
    AM.opened = false
    AM:HideAllMenus()
    Citizen.CreateThread(function()
        Wait(200)
        Administration:TeleporteToPoint()
    end)
    return { ok = true }
end

Actions.showMyPos = function()
    if GetMyLevel() < 1 or not AM.OnDuty then return { error = 'Action refusée.' } end
    LSLegacy.SendEventToServer('admin:pos')
    return { ok = true }
end

Actions.returnToCharSelect = function()
    if GetMyLevel() < 1 then return { error = 'Action refusée.' } end
    AM.opened = false
    AM:HideAllMenus()
    LSLegacy.SendEventToServer('admin:multichar:returnToSelection')
    return { ok = true }
end

--   CALLBACKS NUI

RegisterNUICallback('admin:close', function(data, cb)
    AM.opened       = false
    AM.AllPlayers   = nil
    AM.IdSelected   = nil
    AM.NameSelected = nil
    AM.SelectedData = nil
    AM:HideAllMenus()
    cb('ok')
end)

RegisterNUICallback('admin:action', function(data, cb)
    local handler = data and Actions[data.type]
    if not handler then cb({ error = 'Action inconnue.' }) return end
    local ok, result = pcall(handler, data)
    if ok then
        cb(result or { ok = true })
    else
        cb({ error = 'Erreur interne.' })
    end
end)

--   SYSTÈME SPECTATE / NOCLIP  (conservé de l'original)

Administration = {
    InSpec       = false,
    SpeedNoclip  = 1,
    Cam          = nil,
    CamCalculate = nil,
    CamTarget    = {},
    Scalform     = nil,
}

Administration.DetailsScalform = {
    speed          = { control = 178, label = "Vitesse"          },
    spectateplayer = { control = 24,  label = "Spectate joueur"  },
    gotopos        = { control = 51,  label = "Venir ici"        },
    sprint         = { control = 21,  label = "Rapide"           },
    slow           = { control = 36,  label = "Lent"             },
}

Administration.DetailsInSpec = {
    exit     = { control = 45, label = "Quitter"     },
    openmenu = { control = 51, label = "Menu joueur" },
}

function SetScaleformParams(scaleform, data)
    data = data or {}
    for _, v in pairs(data) do
        PushScaleformMovieFunction(scaleform, v.name)
        if v.param then
            for _, par in pairs(v.param) do
                if math.type(par) == "integer"     then PushScaleformMovieFunctionParameterInt(par)
                elseif type(par) == "boolean"      then PushScaleformMovieFunctionParameterBool(par)
                elseif math.type(par) == "float"   then PushScaleformMovieFunctionParameterFloat(par)
                elseif type(par) == "string"       then PushScaleformMovieFunctionParameterString(par)
                end
            end
        end
        if v.func then v.func() end
        PopScaleformMovieFunctionVoid()
    end
end

function CreateScaleform(name, data)
    if not name or string.len(name) <= 0 then return end
    local scaleform = RequestScaleformMovie(name)
    while not HasScaleformMovieLoaded(scaleform) do Wait(0) end
    SetScaleformParams(scaleform, data)
    return scaleform
end

function Administration:ActiveScalform(inSpec)
    local dataSlots = {
        { name = "CLEAR_ALL",           param = {} },
        { name = "TOGGLE_MOUSE_BUTTONS", param = { 0 } },
        { name = "CREATE_CONTAINER",     param = {} },
    }
    local dataId = 0
    local src = inSpec and Administration.DetailsInSpec or Administration.DetailsScalform
    for _, v in pairs(src) do
        dataSlots[#dataSlots + 1] = {
            name  = "SET_DATA_SLOT",
            param = { dataId, GetControlInstructionalButton(2, v.control, 0), v.label }
        }
        dataId = dataId + 1
    end
    dataSlots[#dataSlots + 1] = { name = "DRAW_INSTRUCTIONAL_BUTTONS", param = { -1 } }
    return dataSlots
end

function Administration:ControlInCam()
    local p10, p11   = IsControlPressed(1, 10), IsControlPressed(1, 11)
    local pSprint, pSlow = IsControlPressed(1, Administration.DetailsScalform.sprint.control),
                           IsControlPressed(1, Administration.DetailsScalform.slow.control)
    if p10 or p11 then
        Administration.SpeedNoclip = math.max(0, math.min(100, Administration.SpeedNoclip + (p10 and 0.01 or -0.01)))
    end
    if Administration.CamCalculate == nil then
        if pSprint then     Administration.CamCalculate = Administration.SpeedNoclip * 2.0
        elseif pSlow then   Administration.CamCalculate = Administration.SpeedNoclip * 0.1 end
    elseif not pSprint and not pSlow then
        Administration.CamCalculate = nil
    end
    if IsControlJustPressed(0, Administration.DetailsScalform.speed.control) then
        DisplayOnscreenKeyboard(false, "FMMC_KEY_TIP8", "", Administration.SpeedNoclip, "", "", "", 5)
        while UpdateOnscreenKeyboard() == 0 do
            Wait(10)
            if UpdateOnscreenKeyboard() == 1 and GetOnscreenKeyboardResult() and #GetOnscreenKeyboardResult() >= 1 then
                Administration.SpeedNoclip = tonumber(GetOnscreenKeyboardResult()) or 1.0
                break
            end
        end
    end
end

function Administration:ManageCam()
    local p32, p33, p35, p34 = IsControlPressed(1,32), IsControlPressed(1,33), IsControlPressed(1,35), IsControlPressed(1,34)
    local g220, g221 = GetDisabledControlNormal(0, 220), GetDisabledControlNormal(0, 221)
    if g220 ~= 0.0 or g221 ~= 0.0 then
        local cRot = GetCamRot(Administration.Cam, 2)
        SetCamRot(Administration.Cam, cRot.x + g221 * -10.0, 0.0, cRot.z + g220 * -10.0, 2)
        SetEntityHeading(PlayerPedId(), cRot.z + g220 * -10.0)
    end
    if p32 or p33 or p35 or p34 then
        local rightVec, forwardVec = GetCamMatrix(Administration.Cam)
        local cPos = GetCamCoord(Administration.Cam)
            + ((p32 and forwardVec or p33 and -forwardVec or vector3(0,0,0))
            +  (p35 and rightVec   or p34 and -rightVec   or vector3(0,0,0)))
            * (Administration.CamCalculate or Administration.SpeedNoclip)
        SetCamCoord(Administration.Cam, cPos)
        SetFocusPosAndVel(cPos)
    end
end

function Administration:StartSpectate(player)
    Administration.CamTarget            = player
    Administration.CamTarget.PedHandle = GetPlayerPed(player.id)
    if not DoesEntityExist(Administration.CamTarget.PedHandle) then
        LSLegacy.ShowNotification("Administration", "Vous êtes trop loin de la cible.", "error")
        return
    end
    NetworkSetInSpectatorMode(1, Administration.CamTarget.PedHandle)
    SetCamActive(Administration.Cam, false)
    RenderScriptCams(false, false, 0, false, false)
    SetScaleformParams(Administration.Scalform, Administration:ActiveScalform(true))
    ClearFocus()
    LSLegacy.SendEventToServer('AdminServerPlayers')
end

function Administration:StartSpectateList(ped)
    Administration.CamTarget.PedHandle = ped
    NetworkSetInSpectatorMode(1, ped)
    SetCamActive(Administration.Cam, false)
    RenderScriptCams(false, false, 0, false, false)
    SetScaleformParams(Administration.Scalform, Administration:ActiveScalform(true))
    ClearFocus()
end

function Administration:ExitSpectate()
    local pPed = PlayerPedId()
    if DoesEntityExist(Administration.CamTarget.PedHandle) then
        SetCamCoord(Administration.Cam, GetEntityCoords(Administration.CamTarget.PedHandle))
    end
    NetworkSetInSpectatorMode(0, pPed)
    SetCamActive(Administration.Cam, true)
    RenderScriptCams(true, false, 0, true, true)
    Administration.CamTarget = {}
    SetScaleformParams(Administration.Scalform, Administration:ActiveScalform(false))
end

-- Appuyé sur E en mode spectate : ouvrir le menu sur ce joueur
function Administration:ScalformSpectate()
    if IsControlJustPressed(0, Administration.DetailsInSpec.exit.control) then
        Administration:ExitSpectate()
        LSLegacy.SendEventToServer('AdminServerPlayers')
    end
    if IsControlJustPressed(0, Administration.DetailsInSpec.openmenu.control) then
        local serverId = Administration.CamTarget.id and GetPlayerServerId(Administration.CamTarget.id) or 0
        if serverId > 0 then
            -- Pré-remplir les données du joueur spectated
            AM.IdSelected   = serverId
            AM.NameSelected = 'Joueur ' .. serverId
            AM.SelectedData = nil
            if AM.AllPlayers then
                for _, v in pairs(AM.AllPlayers) do
                    if v.source == serverId then
                        AM.SelectedData = v
                        AM.NameSelected = v.characterInfos and (v.characterInfos.Prenom .. ' ' .. v.characterInfos.NDF) or AM.NameSelected
                        break
                    end
                end
            end

            Wait(200)
            AM.PendingNavPlayerActions = true
            AM:OpenMenu()
        end
    end
    if Administration.CamTarget.id and DoesEntityExist(GetPlayerPed(Administration.CamTarget.id)) then
        SetFocusPosAndVel(GetEntityCoords(GetPlayerPed(Administration.CamTarget.id)))
    end
end

function Administration:SpecAndPos()
    if not Administration.CamTarget.id and IsControlJustPressed(0, Administration.DetailsScalform.spectateplayer.control) then
        local qTable   = {}
        local CamCoords = GetCamCoord(Administration.Cam)
        local pId      = PlayerId()
        for _, v in pairs(GetActivePlayers()) do
            local vPed  = GetPlayerPed(v)
            local vPos  = GetEntityCoords(vPed)
            local vDist = GetDistanceBetweenCoords(vPos, CamCoords)
            if v ~= pId and vPed and vDist <= 20 and (not qTable.pos or GetDistanceBetweenCoords(qTable.pos, CamCoords) > vDist) then
                qTable = { id = v, pos = vPos }
            end
        end
        if qTable and qTable.id then
            Administration:StartSpectate(qTable)
        end
    end
    local camActive = GetCamCoord(Administration.Cam)
    SetEntityCoords(GetPlayerPed(-1), camActive)
    if IsControlJustPressed(1, Administration.DetailsScalform.gotopos.control) then
        Administration:Spectate(camActive)
    end
end

function Administration:RenderCam()
    if not NetworkIsInSpectatorMode() then
        Administration:ControlInCam()
        Administration:ManageCam()
        Administration:SpecAndPos()
    else
        Administration:ScalformSpectate()
    end
    if Administration.Scalform then
        DrawScaleformMovieFullscreen(Administration.Scalform, 255, 255, 255, 255, 0)
    end
end

function Administration:CreateCam()
    Administration.Cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamActive(Administration.Cam, true)
    RenderScriptCams(true, false, 0, true, true)
    Administration.Scalform = CreateScaleform("INSTRUCTIONAL_BUTTONS", Administration:ActiveScalform(false))
end

function Administration:DestroyCam()
    DestroyCam(Administration.Cam)
    RenderScriptCams(false, false, 0, false, false)
    ClearFocus()
    SetScaleformMovieAsNoLongerNeeded(Administration.Scalform)
    if NetworkIsInSpectatorMode() then
        NetworkSetInSpectatorMode(false, Administration.CamTarget.id and GetPlayerPed(Administration.CamTarget.id) or 0)
    end
    Administration.Scalform = nil
    Administration.Cam      = nil
    Administration.CamTarget = {}
end

function Administration:TeleportCoords(vector, ped)
    if not vector then return end
    ped = ped or PlayerPedId()
    local x, y, z = vector.x, vector.y, vector.z + 0.98

    RequestCollisionAtCoord(x, y, z)
    NewLoadSceneStart(x, y, z, x, y, z, 50.0, 0)

    local timer = GetGameTimer()
    while not IsNewLoadSceneLoaded() do
        if GetGameTimer() - timer > 3500 then break end
        Wait(0)
    end

    SetEntityCoordsNoOffset(ped, x, y, z)

    timer = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) do
        if GetGameTimer() - timer > 3500 then break end
        Wait(0)
    end

    local retval, groundZ = GetGroundZCoordWithOffsets(x, y, z)
    timer = GetGameTimer()
    while not retval do
        z      = z + 5.0
        retval, groundZ = GetGroundZCoordWithOffsets(x, y, z)
        Wait(0)
        if GetGameTimer() - timer > 3500 then break end
    end

    SetEntityCoordsNoOffset(ped, x, y, retval and groundZ or z)
    NewLoadSceneStop()
    return true
end

function Administration:TeleporteToPoint(ped)
    local pPed  = ped or PlayerPedId()
    local bInfo = GetFirstBlipInfoId(8)
    if not bInfo or bInfo == 0 then return end
    local entity  = IsPedInAnyVehicle(pPed, false) and GetVehiclePedIsIn(pPed, false) or pPed
    local bCoords = GetBlipInfoIdCoord(bInfo)
    Administration:TeleportCoords(bCoords, entity)
end

function Administration:Spectate(pPos)
    local pPed = PlayerPedId()
    Administration.InSpec = not Administration.InSpec
    Wait(0)
    if not Administration.InSpec then
        Administration:DestroyCam()
        SetEntityVisible(pPed, true, true)
        SetEntityInvincible(pPed, false)
        SetEntityCollision(pPed, true, true)
        FreezeEntityPosition(pPed, false)
        if pPos then SetEntityCoords(pPed, pPos.x, pPos.y, pPos.z) end
    else
        Administration:CreateCam()
        SetEntityVisible(pPed, false, false)
        SetEntityInvincible(pPed, true)
        SetEntityCollision(pPed, false, false)
        FreezeEntityPosition(pPed, true)
        SetCamCoord(Administration.Cam, GetEntityCoords(pPed))
        Citizen.CreateThread(function()
            while Administration.InSpec do
                Wait(0)
                Administration:RenderCam()
            end
        end)
    end
    SendNUIMessage({ action = 'admin:state', key = 'inSpec', data = Administration.InSpec })
end

--   EVENTS REÇUS DU SERVEUR

LSLegacy.RegisterClientEvent('AdminServerPlayers', function(data)
    AM.AllPlayers = data
    SendNUIMessage({ action = 'admin:state', key = 'players', data = data })
end)

LSLegacy.RegisterClientEvent('admin:playersSnapshot', function(snapshot)
    AM.PlayersSnapshot = snapshot or {}
end)

LSLegacy.RegisterClientEvent('admin:onlineStaffList', function(list)
    AM.OnlineStaff = list or {}
    SendNUIMessage({ action = 'admin:state', key = 'onlineStaff', data = AM.OnlineStaff })
end)

LSLegacy.RegisterClientEvent('admin:jobsFactionsList', function(data)
    AM.Jobs     = (data and data.jobs) or {}
    AM.Factions = (data and data.factions) or {}
    SendNUIMessage({ action = 'admin:state', key = 'jobsFactions', data = { jobs = AM.Jobs, factions = AM.Factions } })
end)

LSLegacy.RegisterClientEvent('admin:receiveWarns', function(warns)
    AM.WarnsList = warns or {}
    SendNUIMessage({ action = 'admin:state', key = 'warns', data = AM.WarnsList })
end)

LSLegacy.RegisterClientEvent('admin:bankInfo', function(info)
    SendNUIMessage({ action = 'admin:state', key = 'bankInfo', data = info or { hasAccount = false, balance = 0 } })
end)

LSLegacy.RegisterClientEvent('admin:receiveTicketStats', function(avgSeconds)
    if not avgSeconds or avgSeconds <= 0 then
        AM.AvgProcessingTime = 'Aucun'
    else
        local s = math.floor(avgSeconds)
        if s < 60 then
            AM.AvgProcessingTime = s .. 's'
        elseif s < 3600 then
            AM.AvgProcessingTime = math.floor(s / 60) .. 'min'
        else
            local h  = math.floor(s / 3600)
            local mn = math.floor((s % 3600) / 60)
            AM.AvgProcessingTime = mn > 0 and (h .. 'h ' .. mn .. 'min') or (h .. 'h')
        end
    end
    AM_PushTickets()
end)

LSLegacy.RegisterClientEvent('admin:receiveTickets', function(tickets)
    AM.OpenTickets   = {}
    AM.TakenTickets  = {}
    AM.ClosedTickets = {}
    for _, t in ipairs(tickets or {}) do
        if     t.status == 'open'   then table.insert(AM.OpenTickets,   t)
        elseif t.status == 'taken'  then table.insert(AM.TakenTickets,  t)
        elseif t.status == 'closed' then table.insert(AM.ClosedTickets, t) end
    end
    AM_PushTickets()
end)

LSLegacy.RegisterClientEvent('admin:receiveInventory', function(inventory, characterInfos, cash, dirty)
    TriggerEvent('inventory:viewExternal', inventory, characterInfos, cash or 0, dirty or 0)
end)

-- Retour au menu admin après fermeture de l'inventaire en lecture seule
AddEventHandler('admin:inventoryViewClosed', function()
    if AM.PendingInventoryReopen then
        AM.PendingInventoryReopen = false
        Citizen.SetTimeout(100, function()
            AM:OpenMenu()
        end)
    end
end)

LSLegacy.RegisterClientEvent('admin:applyGodmode', function(state)
    SetEntityInvincible(PlayerPedId(), state)
end)

-- Freeze "logiciel" (pas de FreezeEntityPosition)
-- FreezeEntityPosition sort le ped de la simulation physique, ce qui le rend
-- invisible aux raycasts (ox_target inclus) même avec SetEntityCollision
-- réaffirmé ensuite — l'admin qui freeze quelqu'un ne pouvait plus le
-- re-cibler pour unfreeze. On simule le freeze en repositionnant le ped à ses
-- coords/heading chaque frame : la collision et la physique restent actives,
-- donc le ped reste ciblable en permanence.
local AM_FreezeActive       = false
local AM_FreezeThreadAlive  = false
local AM_FreezePin          = { coords = nil, heading = nil }

LSLegacy.RegisterClientEvent('admin:setFreeze', function(state)
    if state then
        local ped = PlayerPedId()
        AM_FreezePin.coords  = GetEntityCoords(ped)
        AM_FreezePin.heading = GetEntityHeading(ped)
        AM_FreezeActive = true

        if not AM_FreezeThreadAlive then
            AM_FreezeThreadAlive = true
            Citizen.CreateThread(function()
                while AM_FreezeActive do
                    local p = PlayerPedId()
                    SetEntityCoords(p, AM_FreezePin.coords.x, AM_FreezePin.coords.y, AM_FreezePin.coords.z, false, false, false, false)
                    SetEntityHeading(p, AM_FreezePin.heading)
                    SetEntityVelocity(p, 0.0, 0.0, 0.0)
                    DisableControlAction(0, 30, true) -- MoveLeftRight
                    DisableControlAction(0, 31, true) -- MoveUpDown
                    DisableControlAction(0, 21, true) -- Sprint
                    DisableControlAction(0, 22, true) -- Jump
                    Wait(0)
                end
                AM_FreezeThreadAlive = false
            end)
        end
    else
        AM_FreezeActive = false
    end
end)

LSLegacy.RegisterClientEvent('admin:revive', function()
    local ped    = PlayerPedId()
    local coords = GetEntityCoords(ped)
    -- NetworkResurrectLocalPlayer attend x, y, z séparés — passer un vector3 décale tous les params
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, true, false)
    Wait(0)
    SetEntityHealth(ped, 200)
end)

LSLegacy.RegisterClientEvent('admin:doRepairVehicle', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        local fuel = GetVehicleFuelLevel(veh)
        SetVehicleFuelLevel(veh, fuel)
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleUndriveable(veh, false)
        WashDecalsFromVehicle(veh, 1.0)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
    end
end)

-- Suppression visuelle des véhicules non-persistants restants (trafic NPC, etc.)
-- Les véhicules AP ont déjà été supprimés côté serveur via AP.DeleteVehicle
LSLegacy.RegisterClientEvent('admin:doDeleteVehiclesInZone', function(radius)
    local myCoords = GetEntityCoords(PlayerPedId())
    local count    = 0

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if GetDistanceBetweenCoords(myCoords, GetEntityCoords(veh), true) <= radius then
            DeleteEntity(veh)
            count = count + 1
        end
    end

    LSLegacy.ShowNotification("Véhicules", count .. " véhicule(s) supprimé(s).", "success")
end)

--   THREADS DE FOND

-- Nom affiché au-dessus de la tête (IDs)
-- Nom/prénom RP + nom Steam + indicateur texte (pas de glyphe unicode type
-- "●" : la police GTA ne le connaît pas et affiche un tofu/carré vide à la
-- place — cf. capture d'écran). pma-voice s'appuie sur le lien voix natif,
-- donc NetworkIsPlayerTalking reste fiable même si le ped n'est pas streamé.
local function AM_PlayerLabel(entry, handle)
    local talking = handle and handle ~= -1 and NetworkIsPlayerTalking(handle)
    local label = 'ID: ' .. entry.id
    if entry.rpName then label = label .. ' - ' .. entry.rpName end
    if entry.steamName then label = label .. ' ~y~(' .. entry.steamName .. ')~w~' end
    if talking then label = label .. ' ~g~[parle]~w~' end
    return label
end

-- HUD coords + IDs (snapshot serveur = position de secours pour les peds non
-- streamés, mais dès que le ped local existe on suit sa position à chaque
-- frame pour un texte bien collé/fluide au-dessus de la tête — la snapshot
-- ne rafraîchit qu'1x/s, insuffisant pour du tracking visuel proche).
Citizen.CreateThread(function()
    local myServerId = nil
    while true do
        if AM.Tools.showCoords then
            local c = GetEntityCoords(PlayerPedId())
            local h = GetEntityHeading(PlayerPedId())
            DrawTextAdmin(string.format("X:%.2f  Y:%.2f  Z:%.2f  H:%.1f", c.x, c.y, c.z, h), 0, 0.32, 0.005, 0.96)
        end
        if AM.Tools.showIds then
            myServerId = myServerId or GetPlayerServerId(PlayerId())
            local myCoords = GetEntityCoords(PlayerPedId())
            for _, entry in ipairs(AM.PlayersSnapshot) do
                do
                    -- Affiché aussi pour soi-même (entry.id == myServerId) : permet à
                    -- l'admin de vérifier visuellement le rendu sans dépendre d'un
                    -- autre joueur connecté à proximité.
                    local x, y, z = entry.x, entry.y, entry.z
                    local handle  = GetPlayerFromServerId(entry.id)
                    if handle ~= -1 then
                        local ped = GetPlayerPed(handle)
                        if DoesEntityExist(ped) then
                            local c = GetEntityCoords(ped)
                            x, y, z = c.x, c.y, c.z
                        end
                    end
                    -- Culling simple (distance au carré) pour éviter de dessiner tout le serveur chaque frame
                    local dx, dy, dz = x - myCoords.x, y - myCoords.y, z - myCoords.z
                    if (dx * dx + dy * dy + dz * dz) < (100.0 * 100.0) then
                        LSLegacy.DrawText3D(x, y, z + 1.1, AM_PlayerLabel(entry, handle), 10)
                    end
                end
            end
        end
        Wait(0)
    end
end)

-- Blips joueurs (1s tick, aligné sur la fréquence de la snapshot serveur)
-- AddBlipForCoord/SetBlipCoords plutôt que AddBlipForEntity : fonctionne même
-- si le ped du joueur n'est pas streamé côté client (OneSync Infinity).
Citizen.CreateThread(function()
    local myServerId = nil
    while true do
        if AM.Tools.blips then
            myServerId = myServerId or GetPlayerServerId(PlayerId())
            local active = {}
            for _, entry in ipairs(AM.PlayersSnapshot) do
                do
                    -- Affiché aussi pour soi-même (entry.id == myServerId) : permet de
                    -- vérifier visuellement le rendu même seul sur le serveur, comme
                    -- pour l'affichage des IDs au-dessus de la tête.
                    active[entry.id] = true
                    local blip = AM.PlayerBlips[entry.id]
                    if not blip then
                        blip = AddBlipForCoord(entry.x, entry.y, entry.z)
                        SetBlipSprite(blip, 1)
                        SetBlipColour(blip, entry.id == myServerId and 2 or 3)
                        SetBlipScale(blip, 0.8)
                        SetBlipAsShortRange(blip, false)
                        AM.PlayerBlips[entry.id] = blip
                    else
                        SetBlipCoords(blip, entry.x, entry.y, entry.z)
                    end
                    local name = entry.rpName and (entry.rpName .. ' (' .. entry.steamName .. ')') or entry.steamName
                    BeginTextCommandSetBlipName("STRING")
                    AddTextComponentString(name .. " #" .. entry.id .. (entry.id == myServerId and ' (vous)' or ''))
                    EndTextCommandSetBlipName(blip)
                end
            end
            for sid, blip in pairs(AM.PlayerBlips) do
                if not active[sid] then
                    if DoesBlipExist(blip) then RemoveBlip(blip) end
                    AM.PlayerBlips[sid] = nil
                end
            end
        end
        Wait(1000)
    end
end)

--   OX_TARGET — Ciblage rapide sur les joueurs (sans ouvrir le menu)
--   N'apparaît qu'en service (AM.OnDuty) — cf. prise de service staff.

local function AM_GetServerIdFromPed(ped)
    local playerIndex = NetworkGetPlayerIndexFromPed(ped)
    if not playerIndex then return nil end
    return GetPlayerServerId(playerIndex)
end

local function AM_CanTarget(minLevel)
    return function(entity)
        return AM.OnDuty and GetMyLevel() >= minLevel and entity ~= PlayerPedId()
    end
end

-- Ouvre directement la fiche/actions du joueur ciblé (même flux que le retour de spectate)
local function AM_OpenPlayerActionsFor(targetId)
    -- Ne PAS mettre AM.opened = true ici : AM:OpenMenu() le fait déjà, et le
    -- voir déjà à true lui fait croire que le menu est ouvert → il le
    -- referme aussitôt (toggle) au lieu de l'ouvrir. C'est ce qui rendait
    -- "Ouvrir la fiche" muet depuis ox_target.
    AM:HideAllMenus()
    LSLegacy.SendEventToServer('AdminServerPlayers')

    local timeout = GetGameTimer()
    while AM.AllPlayers == nil do
        if GetGameTimer() - timeout > 3000 then break end
        Wait(5)
    end

    AM.IdSelected   = targetId
    AM.NameSelected = 'Joueur ' .. targetId
    AM.SelectedData = nil
    if AM.AllPlayers then
        for _, v in pairs(AM.AllPlayers) do
            if v.source == targetId then
                AM.SelectedData = v
                AM.NameSelected = v.characterInfos and (v.characterInfos.Prenom .. ' ' .. v.characterInfos.NDF) or AM.NameSelected
                break
            end
        end
    end
    AM.WarnsList = {}
    LSLegacy.SendEventToServer('admin:getWarns', targetId)
    LSLegacy.SendEventToServer('admin:getBankInfo', targetId)

    AM.PendingNavPlayerActions = true
    AM:OpenMenu()
end

exports.ox_target:addGlobalPlayer({
    {
        name = 'admin_target_info', icon = 'fa-solid fa-id-card', label = 'Admin : Ouvrir la fiche',
        distance = 100, canInteract = AM_CanTarget(1),
        onSelect = function(data)
            local sid = AM_GetServerIdFromPed(data.entity)
            if sid then AM_OpenPlayerActionsFor(sid) end
        end,
    },
    {
        name = 'admin_target_message', icon = 'fa-solid fa-comment', label = 'Admin : Message rapide',
        distance = 100, canInteract = AM_CanTarget(1),
        onSelect = function(data)
            local sid = AM_GetServerIdFromPed(data.entity)
            if not sid then return end
            local msg = LSLegacy.KeyboardInput('Message', 100)
            if msg and msg ~= '' then LSLegacy.SendEventToServer('MessageAdmin', sid, msg) end
        end,
    },
    {
        name = 'admin_target_heal', icon = 'fa-solid fa-heart', label = 'Admin : Soigner',
        distance = 100, canInteract = AM_CanTarget(2),
        onSelect = function(data)
            local sid = AM_GetServerIdFromPed(data.entity)
            if sid then LSLegacy.SendEventToServer('admin:heal', sid) end
        end,
    },
    {
        name = 'admin_target_revive', icon = 'fa-solid fa-heart-pulse', label = 'Admin : Réanimer',
        distance = 100, canInteract = AM_CanTarget(2),
        onSelect = function(data)
            local sid = AM_GetServerIdFromPed(data.entity)
            if sid then LSLegacy.SendEventToServer('admin:revive', sid) end
        end,
    },
    {
        name = 'admin_target_freeze', icon = 'fa-solid fa-snowflake', label = 'Admin : Freeze',
        distance = 100, canInteract = AM_CanTarget(2),
        onSelect = function(data)
            local sid = AM_GetServerIdFromPed(data.entity)
            if sid then LSLegacy.SendEventToServer('admin:freeze', sid, true) end
        end,
    },
    {
        name = 'admin_target_unfreeze', icon = 'fa-solid fa-fire', label = 'Admin : Unfreeze',
        distance = 100, canInteract = AM_CanTarget(2),
        onSelect = function(data)
            local sid = AM_GetServerIdFromPed(data.entity)
            if sid then LSLegacy.SendEventToServer('admin:freeze', sid, false) end
        end,
    },
    {
        name = 'admin_target_bring', icon = 'fa-solid fa-hand', label = 'Admin : Téléporter à moi',
        distance = 100, canInteract = AM_CanTarget(2),
        onSelect = function(data)
            local sid = AM_GetServerIdFromPed(data.entity)
            if sid then LSLegacy.SendEventToServer('TeleportPlayers', 'bring', sid) end
        end,
    },
    {
        name = 'admin_target_goto', icon = 'fa-solid fa-person-walking', label = 'Admin : Me téléporter à lui',
        distance = 100, canInteract = AM_CanTarget(2),
        onSelect = function(data)
            local sid = AM_GetServerIdFromPed(data.entity)
            if sid then LSLegacy.SendEventToServer('TeleportPlayers', 'tp', sid) end
        end,
    },
    {
        name = 'admin_target_spectate', icon = 'fa-solid fa-eye', label = 'Admin : Spectate',
        distance = 100, canInteract = AM_CanTarget(1),
        onSelect = function(data)
            local playerIndex = NetworkGetPlayerIndexFromPed(data.entity)
            if playerIndex and playerIndex ~= -1 then
                AM.opened = false
                AM:HideAllMenus()
                Administration:StartSpectate({ id = playerIndex, pos = GetEntityCoords(data.entity) })
            end
        end,
    },
    {
        name = 'admin_target_warn', icon = 'fa-solid fa-triangle-exclamation', label = 'Admin : Avertir',
        distance = 100, canInteract = AM_CanTarget(2),
        onSelect = function(data)
            local sid = AM_GetServerIdFromPed(data.entity)
            if not sid then return end
            local reason = LSLegacy.KeyboardInput('Raison de l\'avertissement', 100)
            if reason and reason ~= '' then LSLegacy.SendEventToServer('admin:warn', sid, reason) end
        end,
    },
    {
        name = 'admin_target_kick', icon = 'fa-solid fa-user-slash', label = 'Admin : Kick',
        distance = 100, canInteract = AM_CanTarget(2),
        onSelect = function(data)
            local sid = AM_GetServerIdFromPed(data.entity)
            if not sid then return end
            local reason = LSLegacy.KeyboardInput('Raison du kick', 100)
            if reason and reason ~= '' then LSLegacy.SendEventToServer('admin:kick', sid, reason) end
        end,
    },
})

--   OX_TARGET — Ciblage rapide sur les objets/props
--   N'apparaît qu'en service (AM.OnDuty) — cf. prise de service staff.

exports.ox_target:addGlobalObject({
    {
        name = 'admin_target_propname', icon = 'fa-solid fa-cube', label = 'Admin : Nom du prop (F8)',
        distance = 100, canInteract = AM_CanTarget(2),
        onSelect = function(data)
            local entity = data.entity
            local model  = GetEntityModel(entity)
            local name   = GetEntityArchetypeName(entity) or ('hash:' .. model)
            print(('[admin] Prop ciblé : %s (model hash: %s) — coords: %s'):format(name, model, GetEntityCoords(entity)))
        end,
    },
})

--   TOUCHES

Keys.Register("F2", "F2", "Ouvrir le menu Admin", function()
    AM:OpenMenu()
end)

Keys.Register("O", "O", "Mode NoClip / Spectate", function()
    if GetMyLevel() < 1 or not AM.OnDuty then
        LSLegacy.ShowNotification("Administration", "Vous devez être en service (staff) pour utiliser le NoClip.", "error")
        return
    end
    Administration:Spectate()
    LSLegacy.SendEventToServer('AdminServerPlayers')
end)

--   ANTI-INJECTOR

Citizen.CreateThread(function()
    currentCount = GetNumResources()
    while true do
        if currentCount ~= GetNumResources() then
            LSLegacy.SendEventToServer("DropInjectorDetected")
        end
        Wait(0)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if AM.Tracking then LSLegacy.SendEventToServer('admin:trackPlayers', false) end
    for _, blip in pairs(AM.PlayerBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)
