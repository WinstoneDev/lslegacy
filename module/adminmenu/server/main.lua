local rateLimits = {
    ['admin:serverPlayers'] = 25, ['admin:message'] = 15, ['admin:teleportPlayers'] = 25,
    ['admin:tpm'] = 30, ['admin:pos'] = 30, ['admin:freeze'] = 10, ['admin:heal'] = 10,
    ['admin:revive'] = 10, ['admin:resetNeeds'] = 10, ['admin:resetSkin'] = 5,
    ['admin:kick'] = 5, ['admin:tempban'] = 5, ['admin:permaban'] = 3, ['admin:warn'] = 10,
    ['admin:getWarns'] = 15, ['admin:screenshot'] = 5, ['admin:repairVehicle'] = 10,
    ['admin:deletePlayerVehicle'] = 10, ['admin:spawnVehicleForPlayer'] = 8,
    ['admin:spawnVehicle'] = 8, ['admin:deleteVehiclesInZone'] = 8, ['admin:giveMoney'] = 10,
    ['admin:removeMoney'] = 10, ['admin:giveItem'] = 10, ['admin:removeItem'] = 10,
    ['admin:giveWeapon'] = 10, ['admin:getPlayerInventory'] = 15, ['admin:getTickets'] = 15,
    ['admin:takeTicket'] = 10, ['admin:closeTicket'] = 10, ['admin:createTicket'] = 8,
    ['admin:tpToTicket'] = 10, ['admin:bringTicketPlayer'] = 10, ['admin:setGodmode'] = 10,
    ['admin:cleanVehicleDB'] = 10, ['admin:deleteWarn'] = 10,
    ['admin:multichar:returnToSelection'] = 5, ['admin:logIdentifiers'] = 5,
    ['admin:getTicketStats'] = 20, ['admin:setWorldTime'] = 15,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

local Admin = {}

local Webhooks = {
    screenshots = GetConvar('lslegacy_webhook_admin_screenshots', ''),
    logs        = GetConvar('lslegacy_webhook_admin_logs', ''),
}
-- Clé API imgbb (gratuite sur https://imgbb.com) — nécessaire pour l'upload de screenshots
local ImgbbKey = GetConvar('lslegacy_imgbb_key', '')

-- Init tables BDD
MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS admin_warns (
        id               INT AUTO_INCREMENT PRIMARY KEY,
        player_identifier VARCHAR(100) NOT NULL,
        player_name      VARCHAR(255),
        staff_identifier  VARCHAR(100) NOT NULL,
        staff_name        VARCHAR(255),
        reason            TEXT,
        created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS support_tickets (
        id               INT AUTO_INCREMENT PRIMARY KEY,
        player_id        INT NOT NULL,
        player_name      VARCHAR(255),
        player_identifier VARCHAR(100),
        subject          TEXT,
        status           ENUM('open','taken','closed') DEFAULT 'open',
        assigned_to      INT DEFAULT NULL,
        assigned_name    VARCHAR(255) DEFAULT NULL,
        created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        closed_at        TIMESTAMP NULL
    )
]], {})

-- Helpers

Admin.GetLevel = function(player)
    return LSLegacy.Permissions.GetLevel(player)
end

Admin.CanDo = function(source, minLevel)
    local player = LSLegacy.Players.Get(source)
    return player and LSLegacy.Permissions.Has(player, minLevel)
end

Admin.GetIdentifier = function(source)
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.sub(id, 1, 6) == 'steam:'   then return id end
        if string.sub(id, 1, 8) == 'license:' then return id end
    end
    return 'src:' .. tostring(source)
end

Admin.CharName = function(player)
    if player and player.characterInfos then
        return player.characterInfos.Prenom .. ' ' .. player.characterInfos.NDF
    end
    return tostring(player and player.source or '?')
end

-- Discord

Admin.DiscordSend = function(webhook, title, description, color, fields)
    local body = json.encode({
        embeds = {{
            title       = title,
            description = description,
            color       = color or 7506394,
            fields      = fields or {},
            footer      = { text = 'LSLegacy Admin • ' .. os.date('%d/%m/%Y %H:%M:%S') }
        }}
    })
    PerformHttpRequest(webhook, function() end, 'POST', body, { ['Content-Type'] = 'application/json' })
end

local LogColors = {
    sanctions   = 15158332,
    economy     = 3447003,
    vehicles    = 10181046,
    staff       = 16776960,
    connections = 5763719,
    weather     = 1752220,
}

Admin.Log = function(category, staff, action, target, extra)
    local staffStr  = staff  and (Admin.CharName(staff)  .. ' (ID: ' .. tostring(staff.source)  .. ')') or 'Console'
    local targetStr = target and (Admin.CharName(target) .. ' (ID: ' .. tostring(target.source) .. ')') or nil
    local desc = extra or ''
    if targetStr then desc = '**Cible :** ' .. targetStr .. (desc ~= '' and '\n' .. desc or '') end

    Admin.DiscordSend(
        Webhooks.logs,
        '[' .. string.upper(category) .. '] ' .. action,
        desc,
        LogColors[category] or 7506394,
        { { name = 'Staff', value = staffStr, inline = true },
          { name = 'Date',  value = os.date('%d/%m/%Y %H:%M:%S'), inline = true } }
    )
end

-- Joueurs

LSLegacy.Events.Register('admin:serverPlayers', function()
    local _source = source
    if not Admin.CanDo(_source, 1) then return end

    -- Copie superficielle : ajoute les labels job/faction lisibles sans polluer
    -- la table LSLegacy.ServerPlayers vivante (utilisée partout ailleurs).
    local snapshot = {}
    for src, pdat in pairs(LSLegacy.Players.GetAll()) do
        local copy = {}
        for k, v in pairs(pdat) do copy[k] = v end
        copy.jobLabel          = LSLegacy.Jobs.GetJobLabel(pdat.job)
        copy.jobGradeLabel     = LSLegacy.Jobs.GetJobGradeLabel(pdat.job, pdat.job_grade)
        copy.factionLabel      = LSLegacy.Factions.GetLabel(pdat.faction)
        copy.factionGradeLabel = LSLegacy.Factions.GetGradeLabel(pdat.faction, pdat.faction_grade)
        snapshot[src] = copy
    end

    LSLegacy.Events.SendToClient('admin:serverPlayers', _source, snapshot)
end)

-- Jobs / Factions (fiche joueur + changement depuis le menu Économie)

LSLegacy.Events.Register('admin:getJobsFactions', function()
    local _source = source
    if not Admin.CanDo(_source, 1) then return end
    LSLegacy.Events.SendToClient('admin:jobsFactionsList', _source, {
        jobs     = LSLegacy.Jobs.GetAvailableJobs(),
        factions = LSLegacy.Factions.GetAvailable(),
    })
end)

LSLegacy.Events.Register('admin:setPlayerJob', function(target, job, grade)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end
    local tp = LSLegacy.Players.Get(target)
    if not tp then return end
    if not LSLegacy.Jobs.DoesJobExist(job) or not LSLegacy.Jobs.DoesJobGradeExist(job, grade) then return end

    LSLegacy.Jobs.SetJob(tp, job)
    LSLegacy.Jobs.SetJobGrade(tp, grade)
    LSLegacy.Events.SendToClient('notify', target, nil, 'Votre métier a été mis à jour en ' .. LSLegacy.Jobs.GetJobLabel(job) .. ' - ' .. LSLegacy.Jobs.GetJobGradeLabel(job, grade) .. '.', 'success')

    Admin.Log('staff', LSLegacy.Players.Get(_source),
        'Changement de job → ' .. LSLegacy.Jobs.GetJobLabel(job) .. ' (' .. LSLegacy.Jobs.GetJobGradeLabel(job, grade) .. ')', tp)
end)

LSLegacy.Events.Register('admin:setPlayerFaction', function(target, faction, grade)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end
    local tp = LSLegacy.Players.Get(target)
    if not tp then return end
    if not LSLegacy.Factions.Exists(faction) or not LSLegacy.Factions.GradeExists(faction, grade) then return end

    LSLegacy.Factions.Set(tp, faction)
    LSLegacy.Factions.SetGrade(tp, grade)
    LSLegacy.Events.SendToClient('notify', target, nil, 'Votre faction a été mise à jour en ' .. LSLegacy.Factions.GetLabel(faction) .. ' - ' .. LSLegacy.Factions.GetGradeLabel(faction, grade) .. '.', 'success')

    Admin.Log('staff', LSLegacy.Players.Get(_source),
        'Changement de faction → ' .. LSLegacy.Factions.GetLabel(faction) .. ' (' .. LSLegacy.Factions.GetGradeLabel(faction, grade) .. ')', tp)
end)

-- Suivi joueurs (blips / IDs) — OneSync Infinity
-- GetActivePlayers()/GetPlayerPed() côté client ne renvoient que les peds
-- streamés dans le scope du client, ce qui casse les blips/nametags admin en
-- OneSync Infinity (grosse distance de vue / beaucoup de joueurs). Le serveur
-- a toujours accès à GetPlayerPed(src) pour tout le monde, indépendamment du
-- scope réseau : c'est donc lui qui calcule les positions et les diffuse aux
-- admins abonnés.
Admin.Tracking = {}

LSLegacy.Events.Register('admin:trackPlayers', function(state)
    local _source = source
    if not Admin.CanDo(_source, 1) then return end
    if state then
        Admin.Tracking[_source] = true
    else
        Admin.Tracking[_source] = nil
    end
end)

AddEventHandler('playerDropped', function()
    Admin.Tracking[source]      = nil
    Admin.OnDutyStaff[source]   = nil
end)

-- Prise de service staff
-- Évite qu'un membre du staff connecté déclenche des outils admin (NoClip,
-- ciblage rapide ox_target) par mégarde en pleine session RP : les outils
-- sensibles exigent d'être explicitement "en service".
Admin.OnDutyStaff = {}

LSLegacy.Events.Register('admin:setDuty', function(state)
    local _source = source
    if not Admin.CanDo(_source, 1) then return end
    Admin.OnDutyStaff[_source] = state and true or nil
    Admin.Log('staff', LSLegacy.Players.Get(_source), state and 'Prise de service' or 'Fin de service')
end)

LSLegacy.Events.Register('admin:getOnlineStaff', function()
    local _source = source
    if not Admin.CanDo(_source, 1) then return end

    local list = {}
    for src, pdat in pairs(LSLegacy.Players.GetAll()) do
        local lvl = Admin.GetLevel(pdat)
        if lvl >= 1 then
            local rpName = pdat.characterInfos
                and (tostring(pdat.characterInfos.Prenom) .. ' ' .. tostring(pdat.characterInfos.NDF))
                or nil
            list[#list + 1] = {
                id        = src,
                rpName    = rpName,
                steamName = pdat.name,
                group     = pdat.group,
                level     = lvl,
                onDuty    = Admin.OnDutyStaff[src] == true,
            }
        end
    end
    table.sort(list, function(a, b)
        if a.onDuty ~= b.onDuty then return a.onDuty end
        return a.level > b.level
    end)

    LSLegacy.Events.SendToClient('admin:onlineStaffList', _source, list)
end)

CreateThread(function()
    while true do
        Wait(1000)
        local hasSubscribers = next(Admin.Tracking) ~= nil
        if hasSubscribers then
            local snapshot = {}
            for _, sid in ipairs(GetPlayers()) do
                local ped = GetPlayerPed(sid)
                if ped ~= 0 then
                    local c    = GetEntityCoords(ped)
                    local pdat = LSLegacy.Players.Get(tonumber(sid))
                    local rpName = pdat and pdat.characterInfos
                        and (tostring(pdat.characterInfos.Prenom) .. ' ' .. tostring(pdat.characterInfos.NDF))
                        or nil
                    snapshot[#snapshot + 1] = {
                        id        = tonumber(sid),
                        x = c.x, y = c.y, z = c.z,
                        rpName    = rpName,
                        steamName = (pdat and pdat.name) or GetPlayerName(sid),
                    }
                end
            end
            for adminSrc in pairs(Admin.Tracking) do
                LSLegacy.Events.SendToClient('admin:playersSnapshot', adminSrc, snapshot)
            end
        end
    end
end)

LSLegacy.Events.Register('admin:message', function(target, msg)
    local _source = source
    if not Admin.CanDo(_source, 1) then return end
    if not LSLegacy.Players.Get(target) then return end
    LSLegacy.Events.SendToClient('notify', target, 'Administration', msg, 'warning')
end)

LSLegacy.Events.Register('admin:teleportPlayers', function(tpType, target)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end
    if not LSLegacy.Players.Get(target) then return end

    if tpType == 'tp' then
        local coords = GetEntityCoords(GetPlayerPed(target))
        SetEntityCoords(GetPlayerPed(_source), coords.x, coords.y, coords.z)
    elseif tpType == 'bring' then
        local coords = GetEntityCoords(GetPlayerPed(_source))
        SetEntityCoords(GetPlayerPed(target), coords.x, coords.y + 1.5, coords.z)
    end
end)

-- tpm → client fait la téléportation (blip)
LSLegacy.Events.Register('admin:tpm', function()
    local _source = source
    LSLegacy.Events.SendToClient('admin:doTpm', _source)
end)

-- pos → retourne les coords au client
LSLegacy.Events.Register('admin:pos', function()
    local _source = source
    local coords  = LSLegacy.GetEntityCoords(_source)
    local heading = GetEntityHeading(GetPlayerPed(_source))
    LSLegacy.Events.SendToClient('admin:showPos', _source, coords.x, coords.y, coords.z, heading)
end)

-- Monde / Serveur — Heure
-- L'horloge en jeu est pilotée par module/weather/server/time.lua (natives
-- SetClockTime/SetClockDate, pas codem-dynamicweather : voir Config.HandleTime
-- false côté codem-dynamicweather). LSLegacy.Weather.SetTime recale juste le
-- point de départ du cycle jour/nuit dynamique — celui-ci continue ensuite
-- normalement dessus, il n'est jamais interrompu par un changement manuel.
LSLegacy.Events.Register('admin:setWorldTime', function(h, mnt)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end

    h   = math.floor(tonumber(h) or 0) % 24
    mnt = math.floor(tonumber(mnt) or 0) % 60

    if not LSLegacy.Weather then
        LSLegacy.Events.SendToClient('notify', _source, 'Administration', "Le module météo n'est pas chargé.", 'error')
        return
    end

    LSLegacy.Weather.SetTime(h, mnt)

    LSLegacy.Events.SendToClient('notify', _source, 'Serveur', 'Heure : ' .. h .. 'h' .. string.format('%02d', mnt), 'success')
    Admin.Log('weather', LSLegacy.Players.Get(_source), 'Heure : ' .. h .. 'h' .. string.format('%02d', mnt))
end)

-- Indépendant de /weathercycle (qui ne contrôle que la météo dynamique) :
-- ceci gèle/dégèle l'horloge in-game sur sa valeur courante. Le serveur
-- continue de la repousser à tout le monde toutes les Config.Weather.TimeTickMs
-- même gelée, pour compenser la dérive naturelle du moteur GTA côté client.
LSLegacy.Events.Register('admin:setTimeFrozen', function(state)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end

    if not LSLegacy.Weather then
        LSLegacy.Events.SendToClient('notify', _source, 'Administration', "Le module météo n'est pas chargé.", 'error')
        return
    end

    state = not not state
    LSLegacy.Weather.SetTimeFrozen(state)

    LSLegacy.Events.SendToClient('notify', _source, 'Serveur', state and 'Horloge gelée.' or 'Horloge relancée.', 'success')
    Admin.Log('weather', LSLegacy.Players.Get(_source), state and 'Horloge gelée' or 'Horloge relancée')
end)

-- Outils Staff

LSLegacy.Events.Register('admin:freeze', function(target, state)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end
    local tp = LSLegacy.Players.Get(target)
    if not tp then return end

    LSLegacy.Events.SendToClient('admin:setFreeze', target, state)
    LSLegacy.Events.SendToClient('notify', target, 'Administration', state and 'Vous avez été freeze.' or 'Vous avez été unfreeze.', 'warning')

    Admin.Log('staff', LSLegacy.Players.Get(_source), (state and 'Freeze' or 'Unfreeze') .. ' joueur', tp)
end)

LSLegacy.Events.Register('admin:heal', function(target)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end
    local tp = LSLegacy.Players.Get(target)
    if not tp then return end

    -- ClearState envoie lslegacy:injury:adminRevive au client
    -- qui gère SetEntityHealth(200) + SetPedArmour(100) + reset KO/coma
    if LSLegacy.Injury then LSLegacy.Injury.ClearState(target) end
    LSLegacy.Events.SendToClient('notify', target, 'Administration', 'Vous avez été soigné.', 'success')

    Admin.Log('staff', LSLegacy.Players.Get(_source), 'Heal joueur', tp)
end)

LSLegacy.Events.Register('admin:revive', function(target)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end
    local tp = LSLegacy.Players.Get(target)
    if not tp then return end

    -- ClearState envoie lslegacy:injury:adminRevive (health + armure + reset état)
    -- admin:revive gère la résurrection GTA si le ped est mort
    if LSLegacy.Injury then LSLegacy.Injury.ClearState(target) end
    LSLegacy.Events.SendToClient('admin:revive', target)
    LSLegacy.Events.SendToClient('notify', target, 'Administration', 'Vous avez été réanimé.', 'success')

    Admin.Log('staff', LSLegacy.Players.Get(_source), 'Revive joueur', tp)
end)

LSLegacy.Events.Register('admin:resetNeeds', function(target)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end
    local tp = LSLegacy.Players.Get(target)
    if not tp then return end

    LSLegacy.Status.SetHunger(tp, 100)
    LSLegacy.Status.SetThirst(tp, 100)
    if Config.UseStamina then LSLegacy.Status.SetStamina(tp, 100) end
    LSLegacy.Events.SendToClient('lslegacy:updatePlayer', target, LSLegacy.Players.Get(target))
    LSLegacy.Events.SendToClient('notify', target, 'Administration', 'Votre faim et soif ont été réinitialisées.', 'success')

    Admin.Log('staff', LSLegacy.Players.Get(_source), 'Reset besoins joueur', tp)
end)

LSLegacy.Events.Register('admin:resetSkin', function(target)
    local _source = source
    if not Admin.CanDo(_source, 3) then return end
    local tp = LSLegacy.Players.Get(target)
    if not tp then return end

    LSLegacy.Events.SendToClient('CreatePerso', target)
    Admin.Log('staff', LSLegacy.Players.Get(_source), 'Reset skin joueur', tp)
end)

LSLegacy.Events.Register('admin:setGodmode', function(state)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end
    -- SetEntityInvincible est client-side uniquement
    LSLegacy.Events.SendToClient('admin:applyGodmode', _source, state)
end)

-- Warns

LSLegacy.Events.Register('admin:getWarns', function(target)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end

    local identifier = Admin.GetIdentifier(target)
    MySQL.Async.fetchAll(
        'SELECT * FROM admin_warns WHERE player_identifier = @id ORDER BY created_at DESC LIMIT 20',
        { ['@id'] = identifier },
        function(rows)
            LSLegacy.Events.SendToClient('admin:receiveWarns', _source, rows or {})
        end
    )
end)

LSLegacy.Events.Register('admin:warn', function(target, reason)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end
    local staff = LSLegacy.Players.Get(_source)
    local tp    = LSLegacy.Players.Get(target)
    if not tp or not staff then return end

    MySQL.Async.execute(
        'INSERT INTO admin_warns (player_identifier, player_name, staff_identifier, staff_name, reason) VALUES (@pi, @pn, @si, @sn, @r)',
        {
            ['@pi'] = Admin.GetIdentifier(target),
            ['@pn'] = Admin.CharName(tp),
            ['@si'] = Admin.GetIdentifier(_source),
            ['@sn'] = Admin.CharName(staff),
            ['@r']  = reason
        }
    )
    LSLegacy.Events.SendToClient('notify', target, 'Administration', 'Avertissement : ' .. reason, 'error')
    Admin.Log('sanctions', staff, 'Warn - ' .. reason, tp)
end)

-- Sanctions

LSLegacy.Events.Register('admin:kick', function(target, reason)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end
    local staff = LSLegacy.Players.Get(_source)
    local tp    = LSLegacy.Players.Get(target)
    if not tp or not staff then return end

    DropPlayer(target, 'Kick - ' .. reason .. ' (par ' .. Admin.CharName(staff) .. ')')
    Admin.Log('sanctions', staff, 'Kick - ' .. reason, tp)
end)

LSLegacy.Events.Register('admin:tempban', function(target, hours, reason)
    local _source = source
    if not Admin.CanDo(_source, 3) then return end
    local staff = LSLegacy.Players.Get(_source)
    local tp    = LSLegacy.Players.Get(target)
    if not tp or not staff then return end

    Shared.Anticheat.BanPlayer(tp, hours, reason, staff.source)
    Admin.Log('sanctions', staff, 'Tempban ' .. tostring(hours) .. 'h - ' .. reason, tp)
end)

LSLegacy.Events.Register('admin:permaban', function(target, reason)
    local _source = source
    if not Admin.CanDo(_source, 4) then return end
    local staff = LSLegacy.Players.Get(_source)
    local tp    = LSLegacy.Players.Get(target)
    if not tp or not staff then return end

    Shared.Anticheat.BanPlayer(tp, 0, reason, staff.source)
    Admin.Log('sanctions', staff, 'Ban permanent - ' .. reason, tp)
end)

-- Screenshot
-- PerformHttpRequest ne gère pas fiablement le binaire (octets nuls dans les JPEG).
-- On passe par imgbb (base64 → URL) puis on poste l'URL dans un embed Discord.

LSLegacy.Events.Register('admin:screenshot', function(target)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end
    local staff = LSLegacy.Players.Get(_source)
    local tp    = LSLegacy.Players.Get(target)
    if not tp or not staff then return end

    if not exports['screenshot-basic'] then
        LSLegacy.Events.SendToClient('notify', _source, 'Administration', 'Ressource screenshot-basic manquante.', 'error')
        return
    end

    exports['screenshot-basic']:requestClientScreenshot(target, { encoding = 'jpg', quality = 0.85 }, function(err, encoded)
        if err or not encoded then
            LSLegacy.Events.SendToClient('notify', _source, 'Administration', 'Échec du screenshot.', 'error')
            return
        end

        local b64 = encoded:match('base64,(.+)$')
        if not b64 then
            LSLegacy.Events.SendToClient('notify', _source, 'Administration', 'Format screenshot invalide.', 'error')
            return
        end

        -- URL-encode les caractères spéciaux du base64 pour form-urlencoded
        local b64Encoded = b64:gsub('+', '%%2B'):gsub('/', '%%2F'):gsub('=', '%%3D')

        -- 1) Upload sur imgbb (texte pur, pas de binaire)
        PerformHttpRequest(
            'https://api.imgbb.com/1/upload?key=' .. ImgbbKey,
            function(imgStatus, imgBody)
                if imgStatus ~= 200 then
                    LSLegacy.Events.SendToClient('notify', _source, 'Administration', 'Erreur imgbb (' .. tostring(imgStatus) .. ').', 'error')
                    return
                end
                local imgData = json.decode(imgBody)
                if not imgData or not imgData.data or not imgData.data.url then
                    LSLegacy.Events.SendToClient('notify', _source, 'Administration', 'Réponse imgbb invalide.', 'error')
                    return
                end

                local targetName = Admin.CharName(tp)   .. ' (ID: ' .. tostring(target)  .. ')'
                local staffName  = Admin.CharName(staff) .. ' (ID: ' .. tostring(_source) .. ')'

                -- 2) Post l'URL dans un embed Discord
                PerformHttpRequest(Webhooks.screenshots, function() end, 'POST',
                    json.encode({
                        embeds = {{
                            title       = 'Screenshot joueur',
                            description = 'De **' .. targetName .. '** par **' .. staffName .. '**',
                            image       = { url = imgData.data.url },
                            color       = LogColors.staff,
                            footer      = { text = 'LSLegacy Admin • ' .. os.date('%d/%m/%Y %H:%M:%S') },
                        }}
                    }),
                    { ['Content-Type'] = 'application/json' }
                )
                LSLegacy.Events.SendToClient('notify', _source, 'Administration', 'Screenshot envoyé.', 'success')
            end,
            'POST', 'image=' .. b64Encoded,
            { ['Content-Type'] = 'application/x-www-form-urlencoded' }
        )
    end)

    Admin.Log('staff', staff, 'Screenshot', tp)
end)

-- Véhicules joueur

LSLegacy.Events.Register('admin:repairVehicle', function(target)
    local _source = source
    if not Admin.CanDo(_source, 3) then return end
    local staff = LSLegacy.Players.Get(_source)
    local tp    = LSLegacy.Players.Get(target)
    if not tp then return end

    LSLegacy.Events.SendToClient('admin:doRepairVehicle', target)
    Admin.Log('vehicles', staff, 'Repair véhicule joueur', tp)
end)

LSLegacy.Events.Register('admin:deletePlayerVehicle', function(target)
    local _source = source
    if not Admin.CanDo(_source, 3) then return end
    local staff = LSLegacy.Players.Get(_source)
    local tp    = LSLegacy.Players.Get(target)
    if not tp then return end

    -- Envoyer ap:findAndDeleteVehicle au client cible : il supprime son véhicule + nettoyage BDD
    LSLegacy.Events.SendToClient('ap:findAndDeleteVehicle', target)
    Admin.Log('vehicles', staff, 'Delete véhicule joueur', tp)
end)

LSLegacy.Events.Register('admin:spawnVehicleForPlayer', function(target, model)
    local _source = source
    if not Admin.CanDo(_source, 3) then return end
    local staff = LSLegacy.Players.Get(_source)
    local tp    = LSLegacy.Players.Get(target)
    if not tp then return end

    local pos     = GetEntityCoords(GetPlayerPed(target))
    local heading = GetEntityHeading(GetPlayerPed(target))
    LSLegacy.AP.SpawnPersistentVehicle(model, pos, heading + 5.0, target)
    LSLegacy.Events.SendToClient('notify', target, 'Administration', 'Véhicule ' .. model .. ' spawné pour vous.', 'success')
    Admin.Log('vehicles', staff, 'Spawn véhicule ' .. model .. ' pour joueur', tp)
end)

-- Véhicules zone

LSLegacy.Events.Register('admin:deleteVehiclesInZone', function(radius)
    local _source = source
    if not Admin.CanDo(_source, 3) then return end
    local staff      = LSLegacy.Players.Get(_source)
    local adminCoords = GetEntityCoords(GetPlayerPed(_source))
    local r          = tonumber(radius) or 50.0

    -- Supprimer les véhicules persistants via AP.DeleteVehicle (retire de Active + DELETE en BDD)
    -- On collecte d'abord pour ne pas modifier AP.Active pendant l'itération
    local toDelete = {}
    for plate, data in pairs(LSLegacy.AP.Active) do
        if data.entity and DoesEntityExist(data.entity) then
            local vc = GetEntityCoords(data.entity)
            if LSLegacy.Validate.Distance(adminCoords, vc, r) then
                toDelete[#toDelete + 1] = { plate = plate, entity = data.entity }
            end
        end
    end
    for _, d in ipairs(toDelete) do
        LSLegacy.AP.DeleteVehicle(d.plate, d.entity)
    end

    -- Laisser le client supprimer les véhicules non-persistants restants (trafic, etc.)
    LSLegacy.Events.SendToClient('admin:doDeleteVehiclesInZone', _source, r)
    Admin.Log('vehicles', staff, 'Delete véhicules zone ' .. tostring(r) .. 'm (' .. #toDelete .. ' AP)', nil)
end)

LSLegacy.Events.Register('admin:spawnVehicle', function(model)
    local _source = source
    if not Admin.CanDo(_source, 3) then return end
    local staff = LSLegacy.Players.Get(_source)
    if not staff then return end

    local pos     = GetEntityCoords(GetPlayerPed(_source))
    local heading = GetEntityHeading(GetPlayerPed(_source))
    LSLegacy.AP.SpawnPersistentVehicle(model, pos, heading + 5.0, _source)
    LSLegacy.Events.SendToClient('notify', _source, 'Administration', 'Véhicule ' .. model .. ' spawné.', 'success')
    Admin.Log('vehicles', staff, 'Spawn véhicule ' .. model, nil)
end)

-- Suppression BDD batch (appelé après DeleteEntity côté client)
LSLegacy.Events.Register('admin:cleanVehicleDB', function(plates)
    local _source = source
    if not Admin.CanDo(_source, 3) then return end
    for _, plate in ipairs(plates or {}) do
        MySQL.Async.execute('UPDATE ap_vehicles SET deleted = 1 WHERE plate = @p', { ['@p'] = plate })
    end
end)

-- Économie

LSLegacy.Events.Register('admin:giveMoney', function(target, amount, bank)
    local _source = source
    if not Admin.CanDo(_source, 4) then return end
    local staff = LSLegacy.Players.Get(_source)
    local tp    = LSLegacy.Players.Get(target)
    if not tp or not staff then return end

    amount = math.abs(tonumber(amount) or 0)
    if bank then
        local ok = exports[GetCurrentResourceName()]:addBankMoneyByCharacterId(tp["boutique-id"], amount)
        if not ok then
            LSLegacy.Events.SendToClient('notify', _source, 'Administration', "Ce joueur n'a pas de compte courant.", 'error')
            return
        end
        LSLegacy.Events.SendToClient('notify', target, 'Économie', 'Reçu ' .. amount .. '$ sur votre compte courant.', 'success')
    else
        LSLegacy.Money.AddPlayerMoney(tp, amount)
        LSLegacy.Events.SendToClient('notify', target, 'Économie', 'Reçu ' .. amount .. '$.', 'success')
    end
    Admin.Log('economy', staff, 'Give ' .. (bank and 'compte courant' or 'cash') .. ' ' .. amount .. '$', tp)
end)

LSLegacy.Events.Register('admin:removeMoney', function(target, amount, bank)
    local _source = source
    if not Admin.CanDo(_source, 4) then return end
    local staff = LSLegacy.Players.Get(_source)
    local tp    = LSLegacy.Players.Get(target)
    if not tp or not staff then return end

    amount = math.abs(tonumber(amount) or 0)
    if bank then
        local info = exports[GetCurrentResourceName()]:getCompteCourantInfoByCharacterId(tp["boutique-id"])
        if not info or not info.hasAccount then
            LSLegacy.Events.SendToClient('notify', _source, 'Administration', "Ce joueur n'a pas de compte courant.", 'error')
            return
        end
        local ok = exports[GetCurrentResourceName()]:removeBankMoneyByCharacterId(tp["boutique-id"], amount)
        if not ok then
            LSLegacy.Events.SendToClient('notify', _source, 'Administration', 'Solde du compte courant insuffisant.', 'error')
            return
        end
        LSLegacy.Events.SendToClient('notify', target, 'Économie', amount .. '$ retirés de votre compte courant.', 'warning')
    else
        LSLegacy.Money.RemovePlayerMoney(tp, amount)
        LSLegacy.Events.SendToClient('notify', target, 'Économie', amount .. '$ retirés.', 'warning')
    end
    Admin.Log('economy', staff, 'Remove ' .. (bank and 'compte courant' or 'cash') .. ' ' .. amount .. '$', tp)
end)

-- Compte courant d'un joueur (affiché dans la fiche joueur)
LSLegacy.Events.Register('admin:getBankInfo', function(target)
    local _source = source
    if not Admin.CanDo(_source, 1) then return end
    local tp = LSLegacy.Players.Get(target)
    if not tp then return end
    local info = exports[GetCurrentResourceName()]:getCompteCourantInfoByCharacterId(tp["boutique-id"])
    LSLegacy.Events.SendToClient('admin:bankInfo', _source, info)
end)

LSLegacy.Events.Register('admin:giveItem', function(target, item, qty)
    local _source = source
    if not Admin.CanDo(_source, 4) then return end
    local staff = LSLegacy.Players.Get(_source)
    local tp    = LSLegacy.Players.Get(target)
    if not tp or not staff or not item then return end

    qty = math.max(1, tonumber(qty) or 1)

    if LSLegacy.Inventory.CanCarryItem(tp, item, qty) then
        local data = nil
        if string.match(item, 'weapon_') then
            data = { ammo = 0, components = {}, serialNumber = LSLegacy.GenerateNumeroDeSerie() }
        elseif string.match(item, 'food_') then
            data = { durability = 100 }
        end
        LSLegacy.Inventory.AddItemInInventory(tp, item, qty, nil, nil, data)
        LSLegacy.Events.SendToClient('notify', target, 'Économie', 'Reçu ' .. qty .. 'x ' .. item .. '.', 'success')
        Admin.Log('economy', staff, 'Give item ' .. qty .. 'x ' .. item, tp)
    else
        LSLegacy.Events.SendToClient('notify', _source, 'Économie', 'Inventaire joueur plein.', 'error')
    end
end)

LSLegacy.Events.Register('admin:giveWeapon', function(target, weapon, ammo)
    local _source = source
    if not Admin.CanDo(_source, 4) then return end
    local staff = LSLegacy.Players.Get(_source)
    local tp    = LSLegacy.Players.Get(target)
    if not tp or not staff or not weapon then return end

    if LSLegacy.Inventory.CanCarryItem(tp, weapon, 1) then
        local data = { ammo = tonumber(ammo) or 50, components = {}, serialNumber = LSLegacy.GenerateNumeroDeSerie() }
        LSLegacy.Inventory.AddItemInInventory(tp, weapon, 1, nil, nil, data)
        LSLegacy.Events.SendToClient('notify', target, 'Économie', 'Reçu ' .. weapon .. '.', 'success')
        Admin.Log('economy', staff, 'Give weapon ' .. weapon, tp)
    else
        LSLegacy.Events.SendToClient('notify', _source, 'Économie', 'Inventaire joueur plein.', 'error')
    end
end)

-- Inventaire joueur (consultation)

LSLegacy.Events.Register('admin:getPlayerInventory', function(target)
    local _source = source
    if not Admin.CanDo(_source, 2) then return end
    local tp = LSLegacy.Players.Get(target)
    if not tp then return end
    LSLegacy.Events.SendToClient('admin:receiveInventory', _source, tp.inventory or {}, tp.characterInfos, tp.cash or 0, tp.dirty or 0)
end)

LSLegacy.Events.Register('admin:logIdentifiers', function(target)
    local _source = source
    if not Admin.CanDo(_source, 3) then return end
    local staff = LSLegacy.Players.Get(_source)
    local tp    = LSLegacy.Players.Get(target)
    if not tp then return end

    local ids = {}
    for _, id in ipairs(GetPlayerIdentifiers(target)) do
        ids[#ids + 1] = id
    end

    Admin.DiscordSend(
        Webhooks.logs,
        '[STAFF] Identifiers joueur',
        '**Joueur :** ' .. Admin.CharName(tp) .. ' (ID: ' .. tostring(target) .. ')\n'
            .. '**Identifiers :**\n```\n' .. table.concat(ids, '\n') .. '\n```',
        LogColors.staff,
        { { name = 'Staff', value = Admin.CharName(staff) .. ' (ID: ' .. tostring(_source) .. ')', inline = true },
          { name = 'Date',  value = os.date('%d/%m/%Y %H:%M:%S'), inline = true } }
    )
    LSLegacy.Events.SendToClient('notify', _source, 'Administration', 'Identifiers envoyés sur Discord.', 'success')
end)

-- Tickets

LSLegacy.Events.Register('admin:getTicketStats', function()
    local _source = source
    if not Admin.CanDo(_source, 1) then return end

    MySQL.Async.fetchScalar(
        [[SELECT AVG(TIMESTAMPDIFF(SECOND, created_at, closed_at))
          FROM support_tickets
          WHERE status = 'closed'
            AND closed_at IS NOT NULL
            AND DATE(closed_at) = CURDATE()]],
        {},
        function(avg)
            LSLegacy.Events.SendToClient('admin:receiveTicketStats', _source, tonumber(avg) or 0)
        end
    )
end)

LSLegacy.Events.Register('admin:getTickets', function(status)
    local _source = source
    if not Admin.CanDo(_source, 1) then return end

    local query  = 'SELECT * FROM support_tickets'
    local params = {}
    if status and status ~= '' then
        query            = query .. ' WHERE status = @s'
        params['@s']     = status
    end
    query = query .. ' ORDER BY created_at DESC LIMIT 50'

    MySQL.Async.fetchAll(query, params, function(rows)
        LSLegacy.Events.SendToClient('admin:receiveTickets', _source, rows or {})
    end)
end)

LSLegacy.Events.Register('admin:takeTicket', function(ticketId)
    local _source = source
    if not Admin.CanDo(_source, 1) then return end
    local staff = LSLegacy.Players.Get(_source)
    if not staff then return end

    MySQL.Async.execute(
        'UPDATE support_tickets SET status = \'taken\', assigned_to = @s, assigned_name = @n WHERE id = @id AND status = \'open\'',
        { ['@s'] = _source, ['@n'] = Admin.CharName(staff), ['@id'] = ticketId },
        function()
            LSLegacy.Events.SendToClient('notify', _source, 'Tickets', 'Ticket pris en charge.', 'success')
        end
    )
end)

LSLegacy.Events.Register('admin:closeTicket', function(ticketId)
    local _source = source
    if not Admin.CanDo(_source, 1) then return end
    local staff = LSLegacy.Players.Get(_source)

    MySQL.Async.execute(
        'UPDATE support_tickets SET status = \'closed\', closed_at = NOW() WHERE id = @id',
        { ['@id'] = ticketId },
        function()
            LSLegacy.Events.SendToClient('notify', _source, 'Tickets', 'Ticket fermé.', 'success')
        end
    )
    Admin.Log('staff', staff, 'Ticket fermé #' .. tostring(ticketId), nil)
end)

LSLegacy.Events.Register('admin:tpToTicket', function(ticketId)
    local _source = source
    if not Admin.CanDo(_source, 1) then return end

    MySQL.Async.fetchScalar(
        'SELECT player_id FROM support_tickets WHERE id = @id',
        { ['@id'] = ticketId },
        function(playerId)
            if playerId and GetPlayerPed(playerId) then
                local coords = GetEntityCoords(GetPlayerPed(playerId))
                SetEntityCoords(GetPlayerPed(_source), coords.x, coords.y, coords.z)
            end
        end
    )
end)

LSLegacy.Events.Register('admin:bringTicketPlayer', function(ticketId)
    local _source = source
    if not Admin.CanDo(_source, 1) then return end

    MySQL.Async.fetchScalar(
        'SELECT player_id FROM support_tickets WHERE id = @id',
        { ['@id'] = ticketId },
        function(playerId)
            if playerId and LSLegacy.Players.Get(playerId) then
                local coords = GetEntityCoords(GetPlayerPed(_source))
                SetEntityCoords(GetPlayerPed(playerId), coords.x, coords.y + 1.5, coords.z)
            end
        end
    )
end)

-- Suppression warn (superadmin)

LSLegacy.Events.Register('admin:deleteWarn', function(warnId, target)
    local _source = source
    if not Admin.CanDo(_source, 4) then return end
    local staff = LSLegacy.Players.Get(_source)

    MySQL.Async.execute('DELETE FROM admin_warns WHERE id = @id', { ['@id'] = warnId },
        function()
            -- Rafraîchir la liste des warns côté admin
            local identifier = Admin.GetIdentifier(target)
            MySQL.Async.fetchAll(
                'SELECT * FROM admin_warns WHERE player_identifier = @id ORDER BY created_at DESC LIMIT 20',
                { ['@id'] = identifier },
                function(rows)
                    LSLegacy.Events.SendToClient('admin:receiveWarns', _source, rows or {})
                end
            )
        end
    )
    Admin.Log('sanctions', staff, 'Suppression warn #' .. tostring(warnId), LSLegacy.Players.Get(target))
end)

-- Création ticket (depuis joueur)
LSLegacy.Events.Register('admin:createTicket', function(subject)
    local _source = source
    local player  = LSLegacy.Players.Get(_source)
    if not player then return end

    MySQL.Async.execute(
        'INSERT INTO support_tickets (player_id, player_name, player_identifier, subject) VALUES (@pid, @pn, @pi, @s)',
        {
            ['@pid'] = _source,
            ['@pn']  = Admin.CharName(player),
            ['@pi']  = Admin.GetIdentifier(_source),
            ['@s']   = subject
        },
        function()
            LSLegacy.Events.SendToClient('notify', _source, 'Support', 'Ticket créé, le staff va vous répondre.', 'success')
            -- Notifier le staff en ligne
            for src, p in pairs(LSLegacy.Players.GetAll()) do
                if Admin.GetLevel(p) >= 1 then
                    LSLegacy.Events.SendToClient('notify', src, '🎫 Ticket', Admin.CharName(player) .. ' : ' .. subject, 'warning')
                end
            end
        end
    )
end)



LSLegacy.RegisterCommand('report', 0, function(player, args, showError, rawCommand)
    if not player or not player.source then return end
    local _source = player.source
    local text = ""
    sm = LSLegacy.StringSplit(rawCommand, " ")
    for i = 2, #sm do
        text = text ..sm[i].. " " 
    end
    if not text or text == '' then
        LSLegacy.Events.SendToClient('notify', _source, 'Support', 'Usage : /report raison', 'error')
        return
    end

    local p = LSLegacy.Players.Get(_source)
    if not p then return end

    MySQL.Async.execute(
        'INSERT INTO support_tickets (player_id, player_name, player_identifier, subject) VALUES (@pid, @pn, @pi, @s)',
        {
            ['@pid'] = _source,
            ['@pn']  = Admin.CharName(p),
            ['@pi']  = Admin.GetIdentifier(_source),
            ['@s']   = text
        },
        function()
            LSLegacy.Events.SendToClient('notify', _source, 'Support', 'Ticket créé. Le staff va vous répondre.', 'success')
            for src, sp in pairs(LSLegacy.Players.GetAll()) do
                if Admin.GetLevel(sp) >= 1 then
                    LSLegacy.Events.SendToClient('notify', src, '🎫 Ticket', Admin.CharName(p) .. ' : ' .. text, 'warning')
                end
            end
        end
    )
end,
{
    help = 'Ouvrir un ticket staff',
    arguments = { { name = 'raison', help = 'Motif du ticket', type = 'string' } }
}, false)