--  MODULE POLICE NATIONALE — Appels 17 / Missions PNJ (serveur)

local C = Config.Police.Callouts

-- État global

local Registered  = {}      -- { [src] = { name, ident, grade, crew } }
-- Plusieurs interventions peuvent tourner en parallèle : autant que
local Callouts    = {}      -- { [id] = callout }
local AgentCall   = {}      -- { [src] = calloutId } — agent → intervention
local LocationCd  = {}      -- { ['cat:index'] = os.time() de dernière utilisation }
local LastScenario = nil
local CurrentHour = nil     -- heure in-game rapportée par les clients
local HourWarned  = false
local TestMode    = { active = false, staff = 0, admin = nil }
local CalloutSeq  = 0

--  TABLES SQL

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS police_callouts (
        id                 INT AUTO_INCREMENT PRIMARY KEY,
        scenario_id        VARCHAR(60)  NOT NULL,
        label              VARCHAR(120) NOT NULL,
        coords             VARCHAR(80)  NOT NULL,
        zone               VARCHAR(80)  DEFAULT NULL,
        status             ENUM('cancelled','success','failed') NOT NULL,
        false_alarm        TINYINT(1) DEFAULT 0,
        agents_registered  INT DEFAULT 0,
        suspects_total     INT DEFAULT 0,
        suspects_delivered INT DEFAULT 0,
        suspects_killed    INT DEFAULT 0,
        suspects_escaped   INT DEFAULT 0,
        suspects_json      TEXT DEFAULT NULL,
        response_time      INT DEFAULT NULL,
        -- Pôle qui a mené l'intervention (estampille d'origine dans le MDT).
        department         VARCHAR(50) NOT NULL DEFAULT 'police',
        started_at         DATETIME DEFAULT CURRENT_TIMESTAMP,
        ended_at           DATETIME DEFAULT NULL,
        KEY idx_pc_status (status),
        KEY idx_pc_started (started_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- Colonnes ajoutées après coup (rapport et classement du dossier).
local CalloutColumns = {
    police_callouts = {
        { 'report',     'TEXT DEFAULT NULL' },
        { 'report_by',  'VARCHAR(120) DEFAULT NULL' },
        { 'report_at',  'DATETIME DEFAULT NULL' },
        { 'closed',     'TINYINT(1) NOT NULL DEFAULT 0' },
        { 'closed_by',  'VARCHAR(120) DEFAULT NULL' },
        { 'closed_at',  'DATETIME DEFAULT NULL' },
        -- Pôle ayant mené l'intervention : estampille d'origine du MDT.
        { 'department', "VARCHAR(50) NOT NULL DEFAULT 'police'" },
    },
    police_callout_agents = {
        -- Une mission conjointe mêle policiers et gendarmes : chaque ligne
        { 'department', "VARCHAR(50) NOT NULL DEFAULT 'police'" },
    },
}

CreateThread(function()
    Wait(2000)   -- laisse la création des tables se terminer
    for tableName, columns in pairs(CalloutColumns) do
        for _, col in ipairs(columns) do
            MySQL.Async.fetchScalar(
                'SELECT COUNT(*) FROM information_schema.COLUMNS ' ..
                'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @t AND COLUMN_NAME = @c',
                { ['@t'] = tableName, ['@c'] = col[1] },
                function(n)
                    if tonumber(n or 0) > 0 then return end
                    MySQL.Async.execute(
                        ('ALTER TABLE %s ADD COLUMN `%s` %s'):format(tableName, col[1], col[2]),
                        {},
                        function()
                            print(('^2[callouts]^7 Colonne %s.%s ajoutée.')
                                :format(tableName, col[1]))
                        end
                    )
                end
            )
        end
    end
end)

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS police_callout_agents (
        id          INT AUTO_INCREMENT PRIMARY KEY,
        callout_id  INT          NOT NULL,
        identifier  VARCHAR(60)  NOT NULL,
        character_id INT         DEFAULT NULL,
        name        VARCHAR(120) NOT NULL,
        grade       INT DEFAULT 0,
        department  VARCHAR(50) NOT NULL DEFAULT 'police',
        is_leader   TINYINT(1) DEFAULT 0,
        cuffed      INT DEFAULT 0,
        delivered   INT DEFAULT 0,
        killed      INT DEFAULT 0,
        misconduct  INT DEFAULT 0,
        reward      INT DEFAULT 0,
        KEY idx_pca_callout (callout_id),
        KEY idx_pca_ident (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

--  HELPERS

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Police Nationale', msg, t or 'info', Config.Police.NotifyDuration or 30000)
end

local function NotifyAll(list, msg, t)
    for src in pairs(list) do Notify(src, msg, t) end
end

local function NotifyRegistered(msg, t)
    for src in pairs(Registered) do Notify(src, msg, t) end
end

-- L'intervention sur laquelle un agent est engagé, ou nil.
local function CalloutOf(src)
    local id = AgentCall[src]
    return id and Callouts[id] or nil
end

local function NotifyEngaged(co, msg, t)
    if not co then return end
    for src in pairs(co.agents) do Notify(src, msg, t) end
end

-- Un équipage est occupé dès qu'il est engagé sur une intervention.
local function IsCrewBusy(crewId)
    if not crewId then return false end
    for _, co in pairs(Callouts) do
        if co.crew == crewId then return true end
    end
    return false
end

-- Nombre d'équipages comptant au moins un agent inscrit. C'est lui qui
local function StaffedCrews()
    local seen, n = {}, 0
    for _, r in pairs(Registered) do
        if r.crew and not seen[r.crew] then
            seen[r.crew] = true
            n = n + 1
        end
    end
    return n
end

-- Nombre d'interventions actuellement en cours.
local function ActiveCount()
    local n = 0
    for _ in pairs(Callouts) do n = n + 1 end
    return n
end

local function Dbg(...)
    if not C.Debug then return end
    print('^5[callouts]^7 ' .. table.concat({ ... }, ' '))
end

-- Effectif pris en compte : réel, ou simulé en mode test.
local function GetStaffCount()
    if TestMode.active then return TestMode.staff end
    local n = 0
    for _ in pairs(Registered) do n = n + 1 end
    return n
end

local function IsEngaged(src)
    return AgentCall[src] ~= nil and Callouts[AgentCall[src]] ~= nil
end

-- Tirage pondéré dans une table { clef = poids }
local function WeightedPick(tbl)
    local total = 0
    for _, w in pairs(tbl) do total = total + w end
    if total <= 0 then return nil end
    local r = math.random() * total
    local acc = 0
    for k, w in pairs(tbl) do
        acc = acc + w
        if r <= acc then return k end
    end
    return nil
end

local function PickOne(list)
    if not list or #list == 0 then return nil end
    return list[math.random(1, #list)]
end

-- Tirage pondéré dans une LISTE d'entrées portant un champ `weight`.
local function WeightedEntry(list)
    if type(list) ~= 'table' or #list == 0 then return nil end
    local total = 0
    for _, e in ipairs(list) do total = total + (e.weight or 1) end
    if total <= 0 then return list[1] end
    local r, acc = math.random() * total, 0
    for _, e in ipairs(list) do
        acc = acc + (e.weight or 1)
        if r <= acc then return e end
    end
    return list[#list]
end

--  IDENTITÉS

-- Déduit le genre depuis le préfixe du modèle GTA (a_m_ / a_f_ …).
local function GenderFromModel(model)
    if type(model) ~= 'string' then return nil end
    local m = string.lower(model)
    if string.match(m, '^%a_m_') then return 'male' end
    if string.match(m, '^%a_f_') then return 'female' end
    return nil
end

local usedNames = {}

local function GenerateIdentity(model, poolName)
    local origins = C.PedPoolOrigins[poolName] or C.DefaultOrigins
    local origin  = WeightedPick(origins) or 'anglo'
    local bank    = C.Names[origin] or C.Names.anglo

    local gender = GenderFromModel(model)
    if not gender then gender = (math.random(1, 2) == 1) and 'male' or 'female' end

    for _ = 1, 12 do
        local first = PickOne(bank[gender]) or 'John'
        local last  = PickOne(bank.last) or 'Doe'
        local key   = first .. '|' .. last
        if not usedNames[key] then
            usedNames[key] = true
            return { firstname = first, lastname = last }
        end
    end
    return { firstname = PickOne(bank[gender]) or 'John', lastname = PickOne(bank.last) or 'Doe' }
end

-- Libellé affiché d'un PNJ selon son état d'identification.
local function PedLabel(p)
    if p.identified and p.identity then
        return p.identity.firstname .. ' ' .. p.identity.lastname
    end
    return p.label or 'Individu'
end

--  ÉLIGIBILITÉ DES SCÉNARIOS

-- Fenêtre horaire ouverte ? (gère le passage par minuit)
local function HoursOpen(hours)
    if not hours then return true end
    if not CurrentHour then
        if not HourWarned then
            HourWarned = true
            print('^3[callouts]^7 Heure in-game indisponible — le filtre horaire est ignoré.')
        end
        return true
    end
    local h = CurrentHour
    if hours.from <= hours.to then
        return h >= hours.from and h < hours.to
    end
    return h >= hours.from or h < hours.to
end

local function EligibleScenarios(staff, ignoreFilters)
    local out = {}
    for id, sc in pairs(Config.Police.Scenarios) do
        local ok = true
        if not ignoreFilters then
            if (sc.minAgents or 1) > staff then ok = false end
            if ok and not HoursOpen(sc.hours) then ok = false end
            if ok and LastScenario == id then ok = false end
        end
        if ok then out[id] = sc.weight or 1 end
    end
    return out
end

--  EMPLACEMENTS

local function AnyCivilianNear(coords, radius)
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        if src and not Registered[src] then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 then
                local pc = GetEntityCoords(ped)
                if LSLegacy.Validate.Distance(pc, coords, radius) then return true end
            end
        end
    end
    return false
end

-- Un emplacement convient-il à ce scénario ?
local function LocationAllows(loc, scenarioId, sc, key)
    if not scenarioId then return true end

    -- UN EMPLACEMENT ANCRÉ ÉCHAPPE AUX EXCLUSIONS DE ZONE.
    local anchored = key and C.SceneAnchors and C.SceneAnchors[key] ~= nil

    -- Filtre par TYPE DE ZONE, déclaré sur le scénario. Plus souple que
    if not anchored and sc and sc.excludeZones and loc.zone then
        for _, z in ipairs(sc.excludeZones) do
            if z == loc.zone then return false end
        end
    end
    if not anchored and sc and sc.onlyZones and loc.zone then
        local ok = false
        for _, z in ipairs(sc.onlyZones) do
            if z == loc.zone then ok = true break end
        end
        if not ok then return false end
    end

    if loc.only then
        for _, id in ipairs(loc.only) do
            if id == scenarioId then return true end
        end
        return false
    end

    if loc.exclude then
        for _, id in ipairs(loc.exclude) do
            if id == scenarioId then return false end
        end
    end
    return true
end

local function PickLocation(category, scenarioId)
    local list = C.Locations[category]
    if not list or #list == 0 then return nil end
    local sc = scenarioId and Config.Police.Scenarios[scenarioId] or nil

    local now  = os.time()
    local pool = {}
    for i, loc in ipairs(list) do
        local key = category .. ':' .. i
        if LocationAllows(loc, scenarioId, sc, key)
           and (now - (LocationCd[key] or 0)) >= C.LocationCooldown then
            local v = loc.coords
            if not AnyCivilianNear(vector3(v.x, v.y, v.z), C.MinPlayerDistance) then
                pool[#pool + 1] = { loc = loc, index = i, key = key }
            end
        end
    end
    if #pool == 0 then return nil end
    return pool[math.random(1, #pool)]
end

--  COMPOSITION D'UN APPEL

-- Tire un comportement selon les pourcentages du scénario.
local function RollBehavior(b)
    local r = math.random(1, 100)
    local passive    = b.passive or 0
    local flee       = b.flee or 0
    if r <= passive then return 'passive' end
    if r <= passive + flee then return 'flee' end
    return 'aggressive'
end

-- Construit la liste des PNJ à créer (sans les créer).
local function ResolvePedPool(poolName, zone)
    if C.ZoneSubstitutedPools and C.ZoneSubstitutedPools[poolName] then
        local zoned = C.ZonePeds and C.ZonePeds[zone]
        if zoned and #zoned > 0 then
            return zoned, 'zone:' .. tostring(zone)
        end
        -- Zone inconnue ou liste vide : on retombe sur la zone de repli
        local fb = C.ZonePeds and C.ZonePeds[C.ZoneFallback]
        if fb and #fb > 0 then
            return fb, 'zone:' .. tostring(C.ZoneFallback) .. ' (repli)'
        end
    end

    local pool = C.PedPools[poolName]
    if pool and #pool > 0 then return pool, 'rôle:' .. tostring(poolName) end
    return { C.FallbackPed }, 'repli global'
end

local function BuildRoster(sc, staff, falseAlarm, zone, massVariant)
    local roster = {}
    usedNames = {}

    -- Évite de retrouver trois fois le même visage sur une même scène.
    local usedModels = {}

    local function add(role, poolName, extra)
        local pool, origin = ResolvePedPool(poolName, zone)

        -- Tirage anti-répétition : on cherche un modèle non encore
        local model
        for _ = 1, 8 do
            model = PickOne(pool)
            if model and not usedModels[model] then break end
        end
        if model then usedModels[model] = true end

        Dbg('modèle', tostring(model), '←', origin, 'pour', role)
        local entry = {
            role     = role,
            pool     = poolName,
            model    = model,
            state    = 'idle',
            identity = (role ~= 'animal') and GenerateIdentity(model, poolName) or nil,
            -- La victime n'est pas identifiée d'office : c'est à l'agent
            identified = (role ~= 'suspect' and role ~= 'victim'),
            items    = {},
        }
        if extra then for k, v in pairs(extra) do entry[k] = v end end
        roster[#roster + 1] = entry
        return entry
    end

    -- Le requérant, toujours présent — sauf le tapage : personne
    if sc.objective ~= 'radio' then
        add('caller', sc.caller or 'witnesses')
    end

    -- Badauds : décoratifs, hors de tout plafond et de toute statistique.
    local function addBystanders()
        -- Scénario explicitement sans attroupement (scène privée, ou
        if sc.bystanders == false then return end
        -- Une fausse alerte n'attroupe personne : il ne se passe rien.
        if falseAlarm then return end
        if not C.BystanderLocations[sc.locations] then return end
        -- Réglages par mission (sc.bystanderChance/Min/Max), sinon repli
        local chance = sc.bystanderChance or C.BystanderChance or 100
        local bMin   = sc.bystandersMin   or C.BystandersMin   or 0
        local bMax   = sc.bystandersMax   or C.BystandersMax   or bMin
        if math.random(1, 100) > chance then return end
        for _ = 1, math.random(bMin, bMax) do
            add('bystander', 'witnesses')
        end
    end

    if falseAlarm then addBystanders() return roster end

    -- Scénarios à objectif : PNJ dédiés, aucun suspect
    if sc.objective == 'statement' then
        addBystanders()
        return roster
    elseif sc.objective == 'death' then
        if sc.massIncident and C.MassShooting and C.MassShooting.Enabled and massVariant then
            local v = massVariant

            -- Décision unique pour toute la scène, conservée sur le
            roster.massIncident = {
                id = v.id, label = v.label,
                suspectState = v.suspectState,
                vehicleState = v.vehicle,
                panicLevel   = v.panicStart or 3,
            }

            -- Morts : le nombre exact qui devra être constaté
            local deathCount = math.random(v.deaths.min or 0, v.deaths.max or 0)
            for _ = 1, deathCount do
                add('deceased', 'deceased')
            end
            roster.massIncident.deadTotal = deathCount

            -- Blessés / victimes indemnes, postures variées
            local V = C.MassShooting.Victims or {}
            local woundedCount = math.random(v.wounded.min or 0, v.wounded.max or 0)
            local aidTotal = 0
            for _ = 1, woundedCount do
                local posture = WeightedPick(V.Postures or {}) or 'injured_down'
                local needsAid = (posture == 'injured_down' or posture == 'injured_mobile')
                if needsAid then aidTotal = aidTotal + 1 end
                if posture == 'injured_down' then
                    add('victim', 'victims', { state = 'injured', posture = posture, requiresAid = needsAid })
                else
                    add('victim', 'victims', { state = 'idle', posture = posture, requiresAid = needsAid })
                end
            end
            roster.massIncident.aidTotal = aidTotal

            -- Témoins clés : profil de connaissance plausible
            local W = C.MassShooting.Witnesses or {}
            local allowed = {}
            for profile, weight in pairs(W.Profiles or {}) do
                if profile == 'vu_suspect' and v.suspectState ~= 'present' then
                    -- exclu : personne n'a pu voir un suspect déjà parti
                elseif profile == 'vu_vehicule' and (not v.vehicle or v.vehicle == 'none') then
                    -- exclu : aucun véhicule dans cette variante
                else
                    allowed[profile] = weight
                end
            end
            local witnessCount = math.random(v.witnesses.min or 2, v.witnesses.max or 3)
            for _ = 1, witnessCount do
                local profile = WeightedPick(allowed) or 'entendu_seulement'
                add('bystander', 'witnesses', { witness = true, witnessProfile = profile })
            end

            -- Suspect, selon l'état décidé pour cette variante
            local suspectCount = 0
            if v.suspectState == 'present' or v.suspectState == 'barricaded' then
                suspectCount = (math.random(1, 100) <= 40) and 2 or 1
            end

            for _ = 1, suspectCount do
                if v.suspectState == 'present' then
                    local behavior = RollBehavior(sc.behaviors or {})
                    local e = add('suspect', sc.pedPool or 'unstable', { behavior = behavior })
                    if sc.weapons and sc.weapons.mode == 'perSuspect'
                       and math.random(1, 100) <= (sc.weapons.chance or 100) then
                        e.weapon = PickOne(sc.weapons.pool)
                    end
                    if behavior == 'passive' and (sc.hideChance or 0) > 0 then
                        e.hidden = math.random(1, 100) <= sc.hideChance
                    end
                    if behavior == 'flee' and sc.fleeOn then
                        e.fleeOn = PickOne(sc.fleeOn) or 'foot'
                    end
                elseif v.suspectState == 'barricaded' then
                    -- Retranché : ne sort pas, ne fuit pas. Une reddition
                    local e = add('suspect', sc.pedPool or 'unstable', {
                        behavior = 'passive', hidden = true,
                    })
                    if sc.weapons and sc.weapons.mode == 'perSuspect'
                       and math.random(1, 100) <= (sc.weapons.chance or 100) then
                        e.weapon = PickOne(sc.weapons.pool)
                    end
                end
            end
            -- 'fled' et 'neutralized' : aucun suspect actif créé, la

            addBystanders()
            return roster
        end

        add('deceased', sc.pedPool or 'deceased')
        addBystanders()
        return roster
    elseif sc.objective == 'hospital' then
        add('wanderer', sc.pedPool or 'elderly')
        addBystanders()
        return roster
    end

    -- Nombre de suspects, plafonné par l'effectif — sauf plancher.
    local n = math.random(sc.suspects.min or 1, sc.suspects.max or 1)
    n = math.max(0, math.min(n, staff))
    if sc.minSuspects and n < sc.minSuspects then n = sc.minSuspects end

    -- Le chien dangereux : 1 animal agressif + 1 maître passif, et la
    if sc.animal then
        add('animal', 'animals', { behavior = 'aggressive', state = 'idle' })
        add('suspect', sc.pedPool or 'residents', { behavior = 'passive', hidden = false })
        if sc.mauledVictim then
            add('victim', 'victims', { state = 'injured' })
        end
        addBystanders()
        return roster
    end

    local suspects = {}
    for _ = 1, n do
        local poolName = sc.pedPool or 'street_crime'
        if sc.pedPoolExtra and math.random(1, 2) == 2 then poolName = sc.pedPoolExtra end
        local behavior = RollBehavior(sc.behaviors or {})
        local e = add('suspect', poolName, { behavior = behavior })


        -- Un passif peut se planquer, selon le scénario
        if behavior == 'passive' and (sc.hideChance or 0) > 0 then
            e.hidden = math.random(1, 100) <= sc.hideChance
        end

        -- Mode de fuite
        if behavior == 'flee' and sc.fleeOn then
            e.fleeOn = PickOne(sc.fleeOn) or 'foot'
        end

        -- Mémoire de l'arme portée : elle sera effacée de l'individu à
        e.weaponInitial = e.weapon

        -- Butin. `lootAlways` le rend systématique : un vigile ne retient
        if sc.loot and #sc.loot > 0 then
            local guaranteed = sc.lootAlways == true
            if guaranteed or math.random(1, 100) <= 60 then
                local want = math.random(math.max(1, sc.lootMin or 1), math.max(1, sc.lootMax or 1))
                local pool = {}
                for _, it in ipairs(sc.loot) do pool[#pool + 1] = it end
                for _ = 1, math.min(want, #pool) do
                    local i = math.random(1, #pool)
                    e.items[#e.items + 1] = pool[i]
                    table.remove(pool, i)
                end
            end
        end

        suspects[#suspects + 1] = e
    end

    -- Armement
    local w = sc.weapons or { mode = 'none' }
    if w.mode == 'perSuspect' then
        for _, e in ipairs(suspects) do
            if math.random(1, 100) <= (w.chance or 50) then
                e.weapon = PickOne(w.pool)
            end
        end
    elseif w.mode == 'perGroup' and #suspects > 0 then
        local count = math.random(w.min or 1, math.max(w.min or 1, w.max or (w.min or 1)))
        count = math.min(count, #suspects)
        local pickedIdx = {}
        while #pickedIdx < count do
            local i = math.random(1, #suspects)
            local dup = false
            for _, v in ipairs(pickedIdx) do if v == i then dup = true break end end
            if not dup then pickedIdx[#pickedIdx + 1] = i end
        end
        for _, i in ipairs(pickedIdx) do
            suspects[i].weapon = PickOne(w.pool)
        end
    end

    -- Permis de port d'arme : décidé une fois à la création, 20 % de
    if sc.weaponPermit then
        for _, e in ipairs(suspects) do
            if e.weapon == 'WEAPON_PISTOL' then
                e.permitValid = math.random(1, 100) <= 20
            end
        end
    end

    -- Complice au volant : un suspect de plus, toujours fuyard en voiture.
    if sc.driver and not sc.heist and (#suspects + 1) <= staff then
        add('suspect', sc.pedPool or 'gang', { behavior = 'flee', fleeOn = 'car', isDriver = true })
    end

    addBystanders()

    -- BRAQUAGE : distribution des rôles et mise en scène
    if sc.heist and C.Heist and C.Heist.Enabled then
        -- Scénario tiré au sort : il décide de l'état de départ de
        local scene = WeightedEntry(C.Heist.Scenes)
        local chief = WeightedEntry(C.Heist.Leaders)
        roster.heist = {
            scene  = scene and scene.id or 'en_cours',
            leader = chief and chief.id or 'calme',
        }

        -- Rôles : un chef, un conducteur, le reste en exécutants. Le
        local n = 0
        for _, e in ipairs(roster) do
            if e.role == 'suspect' then
                n = n + 1
                if n == 1 then
                    e.heistRole = 'chief'
                    e.isDriver  = nil
                    e.fleeOn    = 'foot'
                    e.label     = 'Chef de l\'équipe'
                elseif n == 2 then
                    e.heistRole = 'driver'
                    e.isDriver  = true
                    e.fleeOn    = 'car'
                    e.label     = 'Conducteur'
                else
                    e.heistRole = 'crew'
                    -- Un exécutant ne conduit pas : sans ça, un suspect
                    e.isDriver  = nil
                    e.fleeOn    = 'foot'
                end
                -- Aucune décision individuelle : le chef tranche pour
                e.behavior = 'passive'
            end
        end

        -- Le caissier est le requérant : il reste sur place, vivant.
        for _, e in ipairs(roster) do
            if e.role == 'caller' then e.cashier = true end
        end

        -- Clients présents dans le commerce.
        local nc = math.random(C.Heist.Clients.Min or 0, C.Heist.Clients.Max or 5)
        for _ = 1, nc do
            add('bystander', 'witnesses', { client = true })
        end
    end

    -- Personne mordue par l'animal, déjà au sol à l'arrivée
    if sc.mauledVictim then
        add('victim', 'victims', { state = 'injured' })
    end

    -- Victime blessée du délit de fuite
    if sc.crash then
        local ct = PickOne(C.CrashTypes) or C.CrashTypes[1]
        roster.crashType = ct
        if ct.victim then
            add('victim', 'victims', { state = 'injured' })
        end
    end

    return roster
end

--  NUMÉROTATION DES INDIVIDUS NON IDENTIFIÉS

-- Direction cardinale d'un point vers un autre, en clair.
local function BearingLabel(from, to)
    local dx, dy = to.x - from.x, to.y - from.y
    if math.abs(dx) < 0.1 and math.abs(dy) < 0.1 then return C.Directions[1] end
    -- 0° = nord, sens horaire
    local ang = math.deg(math.atan(dx, dy)) % 360
    local idx = math.floor((ang + 22.5) / 45) % 8 + 1
    return C.Directions[idx]
end

-- Construit le témoignage du requérant UNE SEULE FOIS, à la création de

-- Type de lieu : la catégorie d'emplacement prime sur la zone. Un
local function ResolvePlace(callout)
    local D = Config.Police.Dialogues
    if not D then return 'urbain' end

    local category = tostring(callout.location.key or ''):match('^(.-):')
    local byCat = category and D.PlaceByCategory[category]
    if byCat then return byCat, category end

    local zone = callout.zone or callout.location.loc.zone
    return (zone and D.PlaceByZone[zone]) or D.PlaceFallback or 'urbain', category
end

-- Profil du requérant. Trois sources, par ordre de priorité :
local function ResolveProfile(callout, caller, place)
    local D = Config.Police.Dialogues
    if not D then return 'passant' end

    local forced = D.ProfileByScenario[callout.scenarioId]
    if forced then return forced, 'scénario' end

    local byPool = caller and caller.pool and D.ProfileByPool[caller.pool]
    if byPool then
        -- Encore faut-il que ce profil ait un sens ici : un « habitant »
        local allowed = D.ProfilesByPlace[place] or {}
        for _, p in ipairs(allowed) do
            if p == byPool then return byPool, 'pool' end
        end
    end

    local pool = D.ProfilesByPlace[place]
    if pool and #pool > 0 then
        return pool[math.random(1, #pool)], 'lieu'
    end
    return 'passant', 'défaut'
end

-- Phrase d'ouverture compatible avec le contexte.
local function PickIntro(callout, ctx)
    local D = Config.Police.Dialogues
    if not D or not D.Lines then return nil end

    local mission = D.Lines[callout.scenarioId]
    if mission then
        local order = {
            mission[ctx.place] and mission[ctx.place][ctx.profile],
            mission[ctx.place] and mission[ctx.place]['*'],
            mission['*'] and mission['*'][ctx.profile],
            mission['*'] and mission['*']['*'],
        }
        for i, list in ipairs(order) do
            if type(list) == 'table' and #list > 0 then
                ctx.depth = i
                return list[math.random(1, #list)]
            end
        end
    end

    -- Repli neutre : aucune mention de domicile, de travail ni de lien
    ctx.depth = 5
    local fb = D.Fallback
    if type(fb) == 'table' and #fb > 0 then return fb[math.random(1, #fb)] end
    return nil
end

-- Contexte complet du requérant, calculé une seule fois à la création
local function BuildDialogueContext(callout)
    local caller
    for _, p in pairs(callout.peds) do
        if p.role == 'caller' then caller = p break end
    end

    local place, category = ResolvePlace(callout)
    local profile, from   = ResolveProfile(callout, caller, place)

    local victim, suspects = nil, 0
    for _, p in pairs(callout.peds) do
        if p.role == 'suspect' then suspects = suspects + 1
        elseif p.role == 'victim' or p.role == 'deceased'
            or p.role == 'wanderer' or p.role == 'animal' then
            victim = p.role
        end
    end

    local ctx = {
        mission      = callout.scenarioId,
        place        = place,
        category     = category,
        zone         = callout.zone or callout.location.loc.zone,
        profile      = profile,
        profileFrom  = from,
        pool         = caller and caller.pool or nil,
        victimType   = victim,
        suspectCount = suspects,
        objective    = callout.scenario.objective,
        falseAlarm   = callout.falseAlarm or false,
    }

    callout.dialogue = ctx
    if C.Debug then
        print(('^5[dialogue]^7 %s | lieu=%s (%s/%s) | profil=%s (%s)')
            :format(tostring(ctx.mission), tostring(ctx.place),
                tostring(ctx.category), tostring(ctx.zone),
                tostring(ctx.profile), tostring(ctx.profileFrom)))
    end
    return ctx
end

-- Déposition d'un témoin nommé (tuerie de masse), distincte de celle du
local function BuildWitnessStatement(callout, p)
    local place = ResolvePlace(callout)
    local line = PickIntro(callout, { place = place, profile = p.witnessProfile })
    p.statementLines = { line or 'Je n\'ai pas vu grand-chose, désolé.' }
end

-- Parcourt le roster à la recherche des témoins marqués et remplit leur
local function BuildWitnessStatements(callout)
    for _, p in pairs(callout.peds) do
        if p.witness and p.witnessProfile then
            BuildWitnessStatement(callout, p)
        end
    end
end

function BuildStatement(callout)
    if callout.falseAlarm then
        BuildDialogueContext(callout)
        callout.statement = PickOne(C.FalseAlarmLines)
        callout.statementLines = { callout.statement }
        return
    end

    local base = callout.location.loc.coords
    local suspects = {}
    for _, p in pairs(callout.peds) do
        if p.role == 'suspect' then suspects[#suspects + 1] = p end
    end

    -- Phrase d'ouverture CONTEXTUELLE : elle dépend du type de lieu et
    local ctx   = BuildDialogueContext(callout)
    local intro = PickIntro(callout, ctx)

    -- Filet : si aucune phrase contextuelle n'existe (mission ajoutée
    if not intro then
        intro = callout.scenario.statementIntro
        if type(intro) == 'table' then intro = PickOne(intro) end
    end

    -- Scénario animalier : le « suspect » est le maître, l'individu à
    if #suspects == 0 or callout.scenario.animal then
        callout.statementLines = { intro or 'Je vous attendais, merci d\'être venus.' }
        callout.statement      = callout.statementLines[1]
        return
    end

    -- Direction de fuite COMMUNE : tous les individus sont partis du
    local groupDir = BearingLabel(base, callout.escapeTarget or base)
    for _, p in ipairs(suspects) do
        p.direction = groupDir
    end
    callout.groupDirection = groupDir

    local parts = {}
    if intro then parts[#parts + 1] = intro end

    -- La direction n'a de sens que si les individus sont RÉELLEMENT
    local fleeing = 0
    for _, p in ipairs(suspects) do
        if p.behavior == 'flee' then fleeing = fleeing + 1 end
    end
    local canFlee = fleeing > 0 and not callout.scenario.suspectsAtCaller

    -- Pas de direction de fuite annoncée : le témoin dit qui est parti
    if #suspects == 1 then
        parts[#parts + 1] = canFlee
            and 'Il n\'y avait qu\'un individu, il est parti en courant.'
            or  'Il n\'y avait qu\'un individu, il est encore sur place.'
    elseif not canFlee then
        parts[#parts + 1] = ('Ils sont %d et ils sont toujours là.'):format(#suspects)
    elseif fleeing >= #suspects then
        parts[#parts + 1] = ('Ils étaient %d et sont tous partis en courant.')
            :format(#suspects)
    else
        -- Cas mixte : certains ont filé, d'autres non. Le témoin le dit.
        parts[#parts + 1] = ('Ils étaient %d, %d %s parti%s, le reste est sur place.')
            :format(#suspects, fleeing, (fleeing > 1) and 'sont' or 'est',
                (fleeing > 1) and 's' or '')
    end

    -- Pas de description vestimentaire : elle ne pourrait pas coller au
    local armed = {}
    for _, p in ipairs(suspects) do
        if p.weapon then
            local d = C.WeaponDescriptions[p.weapon] or C.WeaponFallback
            armed[d] = (armed[d] or 0) + 1
        end
    end

    local armedParts = {}
    for desc, n in pairs(armed) do
        armedParts[#armedParts + 1] = (n > 1) and (n .. ' avaient ' .. desc)
                                              or ('un avait ' .. desc)
    end
    if #armedParts > 0 then
        parts[#parts + 1] = 'Faites attention : ' ..
            table.concat(armedParts, ', et ') .. ' !'
    end

    -- `parts` sert de découpage prêt à l'affichage (une phrase par ligne),
    callout.statementLines = parts
    callout.statement      = table.concat(parts, ' ')
end

local function AssignLabels(peds, suspectLabel)
    local i = 0
    for _, p in pairs(peds) do
        if p.role == 'suspect' then
            -- La mise en scène nomme parfois elle-même ses rôles — le
            if p.label then
                -- déjà nommé, on n'y touche pas
            else
                i = i + 1
                -- Certains scénarios nomment leur mis en cause : le maître
                p.label = suspectLabel or ('Individu n°' .. i)
            end
        elseif p.role == 'animal' then
            p.label = 'Chien'
        elseif p.role == 'deceased' then
            p.label = 'Personne décédée'
        elseif p.role == 'victim' then
            p.label = 'Victime'
        end
    end
end

--  CRÉATION DES ENTITÉS

local function SpawnEntities(callout, roster, groundPoints)
    local base = callout.location.loc.coords
    local peds = {}

    -- ANCRAGES : niveau générique, plus surcharge par scénario.
    local anchorSet = C.SceneAnchors and C.SceneAnchors[callout.location.key]
    local anchorScoped = anchorSet and anchorSet[callout.scenarioId] or nil

    -- Position relevée pour ce rôle : surcharge de scénario d'abord.
    local function AnchorFor(role)
        if anchorScoped and anchorScoped[role] then return anchorScoped[role] end
        if anchorSet and anchorSet[role] then return anchorSet[role] end
        return nil
    end

    -- Positions d'individus, tous rôles de relevé confondus.
    local mergedSuspect = nil
    local function SuspectAnchors()
        if mergedSuspect ~= nil then return mergedSuspect end

        local direct = AnchorFor('suspect')
        if direct then mergedSuspect = direct return direct end

        local list = {}
        for _, role in ipairs({ 'chief', 'crew' }) do
            local a = AnchorFor(role)
            if a then
                if a.w ~= nil then
                    list[#list + 1] = a
                else
                    for _, v in ipairs(a) do list[#list + 1] = v end
                end
            end
        end
        mergedSuspect = (#list > 0) and list or false
        return mergedSuspect
    end

    -- Un braqueur a un rôle plus précis que « suspect » : chef,
    local function AnchorForEntry(entry)
        if entry.heistRole then
            local a = AnchorFor(entry.heistRole)
            if a then return a, entry.heistRole end
        end

        -- Un conducteur reste un conducteur, braquage ou non : le
        if entry.isDriver then
            local a = AnchorFor('driver')
            if a then return a, 'driver' end
        end

        if entry.role == 'suspect' and not roster.heist then
            local a = SuspectAnchors()
            if a then return a, 'suspect' end
        end

        return AnchorFor(entry.role), entry.role
    end

    -- Le barycentre FUSIONNE les deux niveaux : une surcharge de mission
    local anchors = nil
    if anchorSet then
        anchors = {}
        for role, a in pairs(anchorSet) do
            if Config.Police.Scenarios[role] == nil then anchors[role] = a end
        end
        for role, a in pairs(anchorScoped or {}) do anchors[role] = a end
    end

    -- CENTRE DE SECOURS DÉDUIT DES ANCRAGES.
    if anchors then
        local sx, sy, sz, n = 0.0, 0.0, 0.0, 0
        for role, a in pairs(anchors) do
            -- Une sous-table de scénario n'est pas une position.
            if Config.Police.Scenarios[role] == nil then
                local pts = (a.w ~= nil) and { a } or a
                for _, pt in ipairs(pts) do
                    if pt.x then
                        sx, sy, sz, n = sx + pt.x, sy + pt.y, sz + pt.z, n + 1
                    end
                end
            end
        end
        if n > 0 then
            callout.anchorCenter = { x = sx / n, y = sy / n, z = sz / n }
        end
    end

    -- Cap de fuite unique pour toute l'intervention : c'est lui qui rend
    callout.escapeAngle = math.random() * math.pi * 2
    local ex, ey = math.sin(callout.escapeAngle), math.cos(callout.escapeAngle)
    callout.escapeTarget = {
        x = base.x + ex * C.FleeTargetDst,
        y = base.y + ey * C.FleeTargetDst,
        z = base.z,
    }

    -- Emplacements des véhicules décidés dès maintenant : les suspects
    callout.targetVehiclePos = { x = base.x + 4.0, y = base.y + 1.0, z = base.z }
    -- Même décalage que dans SpawnVehicles : les individus doivent
    callout.crashPos = { x = base.x + 3.0, y = base.y + 0.0, z = base.z }
    callout.boomboxPos       = { x = base.x, y = base.y, z = base.z }
    callout.radioStation     = PickOne(C.RadioStations)
    local gOff = callout.scenario.getawayOffset
    if gOff then
        -- Véhicule de fuite garé à l'écart du commerce, dans l'axe de
        callout.getawayPos = {
            x = base.x + ex * gOff,
            y = base.y + ey * gOff,
            z = base.z,
        }
    end

    -- Emplacement de véhicule relevé à la main : il remplace le calcul
    do
        local aSet    = C.SceneAnchors and C.SceneAnchors[callout.location.key]
        local aScoped = aSet and aSet[callout.scenarioId] or nil
        local va = (aScoped and aScoped.vehicle) or (aSet and aSet.vehicle) or nil
        if type(va) == 'table' and va[1] and type(va[1]) ~= 'number' then
            va = va[1]
        end
        if va and va.x then
            local vp = { x = va.x, y = va.y, z = va.z }
            if callout.getawayPos then callout.getawayPos = vp end
            if callout.scenario.targetVehicle then callout.targetVehiclePos = vp end
            if callout.scenario.crash then callout.crashPos = vp end
            if callout.scenario.objective == 'radio' then callout.boomboxPos = vp end
        end
    end

    -- Scène de constatation : le corps est posé au point de référence et
    local hasCorpse = false
    for _, e in ipairs(roster) do
        if e.role == 'deceased' then hasCorpse = true break end
    end

    -- Ancrages relevés à la main pour cet emplacement précis. Ils
    local anchorUsed = {}

    for idx, entry in ipairs(roster) do
        local pos, heading

        local fixed = nil
        local roleAnchor, roleName = AnchorForEntry(entry)
        if roleAnchor then
            local a = roleAnchor
            if type(a) == 'vector4' or a.w ~= nil then
                -- Un seul point : réservé au premier PNJ de ce rôle.
                if not anchorUsed[roleName] then
                    anchorUsed[roleName] = true
                    fixed = a
                end
            else
                -- Liste : un point par PNJ, dans l'ordre. Si elle est
                local n = (anchorUsed[roleName] or 0) + 1
                anchorUsed[roleName] = n
                fixed = a[n]
                if not fixed and #a > 0 then
                    local seed = a[math.random(1, #a)]
                    local ang  = math.random() * math.pi * 2
                    local d    = 1.2 + math.random() * 0.8
                    fixed = vector4(
                        seed.x + math.cos(ang) * d,
                        seed.y + math.sin(ang) * d,
                        seed.z, seed.w or 0.0)
                end
            end
        end

        if fixed then
            pos     = vector3(fixed.x, fixed.y, fixed.z)
            heading = fixed.w or 0.0
            entry.anchored = true

        elseif entry.role == 'deceased' then
            pos     = vector3(base.x, base.y, base.z)
            heading = base.w

        elseif entry.role == 'caller' and hasCorpse then
            -- Témoin resté sur place, tourné vers le corps : c'est lui
            local ang = math.random() * math.pi * 2
            local d   = callout.scenario.callerToCorpse or 2.0
            pos = vector3(base.x + math.cos(ang) * d,
                          base.y + math.sin(ang) * d, base.z)
            heading = math.deg(math.atan(base.x - pos.x, base.y - pos.y))

        elseif entry.role == 'caller' and callout.scenario.callerAtDoor then
            -- Seuil d'habitation : position et orientation déclarées,
            pos     = vector3(base.x, base.y, base.z)
            heading = base.w

        elseif entry.role == 'caller' and callout.scenario.callerOffset then
            -- Le requérant observe à distance (riverain qui se plaint)
            local ang = math.random() * math.pi * 2
            local d   = callout.scenario.callerOffset
            pos = vector3(base.x + math.cos(ang) * d, base.y + math.sin(ang) * d, base.z)
            heading = math.deg(math.atan(base.x - pos.x, base.y - pos.y))

        elseif entry.role == 'animal' then
            -- L'animal tourne autour de son maître, pas à l'autre bout
            local ang = math.random() * math.pi * 2
            local d   = (callout.scenario.animalRange or 5.0) * 0.6
            pos = vector3(base.x + math.cos(ang) * d, base.y + math.sin(ang) * d, base.z)
            heading = math.random(0, 359) + 0.0

        elseif entry.role == 'caller' or entry.role == 'victim' then
            pos     = vector3(base.x, base.y, base.z)
            heading = base.w
        elseif entry.role == 'bystander' then
            -- Attroupement serré autour de la scène. Sur une constatation,
            local ang = math.random() * math.pi * 2
            local dst = 3.0 + math.random() * 2.0
            pos = vector3(base.x + math.cos(ang) * dst, base.y + math.sin(ang) * dst, base.z)
            heading = math.deg(math.atan(base.x - pos.x, base.y - pos.y))

        elseif entry.role == 'suspect' and callout.scenario.suspectsAtCaller then
            -- Individu retenu ou immobile au contact du requérant.
            local ang = math.random() * math.pi * 2
            local sac = callout.scenario.suspectsAtCaller
            local dst = (type(sac) == 'number') and sac or C.SuspectsAtCallerRange
            pos = vector3(base.x + math.cos(ang) * dst, base.y + math.sin(ang) * dst, base.z)
            heading = base.w

        elseif entry.role == 'suspect' and callout.scenario.suspectsAtVehicle then
            -- Ils sont en train de forcer le véhicule : ils se tiennent
            local ang = math.random() * math.pi * 2
            local d   = callout.scenario.suspectsAtVehicle
            local tv  = (callout.scenario.objective == 'radio' and callout.boomboxPos)
                or (callout.scenario.crash and callout.crashPos)
                or callout.targetVehiclePos or base
            pos = vector3(tv.x + math.cos(ang) * d, tv.y + math.sin(ang) * d, base.z)
            heading = math.deg(math.atan(tv.x - pos.x, tv.y - pos.y))

        elseif entry.role == 'suspect' and callout.scenario.suspectCluster then
            -- Groupe serré : ils se tiennent ensemble au même endroit.
            local spacing = callout.scenario.suspectCluster
            local n = (callout._clusterIndex or 0)
            callout._clusterIndex = n + 1
            local ang = (n * 2.4)   -- écartement en spirale, sans superposition
            local d   = spacing * (n == 0 and 0 or 1) * (1 + n * 0.35)
            pos = vector3(base.x + math.cos(ang) * d, base.y + math.sin(ang) * d, base.z)
            heading = base.w

        elseif entry.role == 'suspect' then
            -- Tous les individus sont partis du même côté : on les répartit
            local half = math.rad(C.FleeConeDeg) / 2
            local ang  = callout.escapeAngle + (math.random() * 2 - 1) * half
            local dst  = math.random(15, math.floor(C.SpawnRadius))
            pos = vector3(base.x + math.sin(ang) * dst, base.y + math.cos(ang) * dst, base.z)
            heading = math.deg(ang)
        elseif entry.role == 'wanderer' then
            -- La personne à assister reste au contact de la requérante :
            local ang = math.random() * math.pi * 2
            pos = vector3(base.x + math.cos(ang) * 2.0,
                          base.y + math.sin(ang) * 2.0, base.z)
            heading = math.random(0, 359) + 0.0
        else
            local ang = math.random() * math.pi * 2
            local dst = math.random(15, math.floor(C.SpawnRadius))
            pos = vector3(base.x + math.cos(ang) * dst, base.y + math.sin(ang) * dst, base.z)
            heading = math.random(0, 359) + 0.0
        end

        local ped = CreatePed(4, entry.model, pos.x, pos.y, pos.z, heading, true, true)
        if ped and ped ~= 0 then
            -- Anti-despawn : les entités serveur sont soumises au culling
            pcall(function()
                SetEntityDistanceCullingRadius(ped, C.EscapeDistance + 100.0)
            end)
            local netId = NetworkGetNetworkIdFromEntity(ped)
            entry.netId  = netId
            entry.entity = ped
            entry.spawn  = { x = pos.x, y = pos.y, z = pos.z, h = heading }
            entry.meleeHits   = 0
            peds[netId] = entry
        else
            print('^1[callouts]^7 Échec de création du ped ' .. tostring(entry.model))
        end
    end

    callout.peds = peds
    callout.heist = roster.heist
    callout.massIncident = roster.massIncident
    if callout.massIncident then
        callout.dangerLevel = callout.massIncident.panicLevel
        callout.deadTotal     = callout.massIncident.deadTotal or 0
        callout.deadConstated = 0
        callout.aidTotal      = callout.massIncident.aidTotal or 0
        callout.aidGiven      = 0
    end
    AssignLabels(peds, callout.scenario.suspectLabel)
    BuildStatement(callout)
    BuildWitnessStatements(callout)
end

local function SpawnVehicles(callout, sc)
    callout.vehicles = {}
    -- Fausse alerte : rien ne s'est produit, aucun véhicule n'a de sens
    if callout.falseAlarm then return end
    local base = callout.location.loc.coords

    -- Emplacements relevés à la main (/pnjposition vehicule). Comme pour
    local anchorSet    = C.SceneAnchors and C.SceneAnchors[callout.location.key]
    local anchorScoped = anchorSet and anchorSet[callout.scenarioId] or nil
    local vehAnchors   = (anchorScoped and anchorScoped.vehicle)
        or (anchorSet and anchorSet.vehicle) or nil
    local vehUsed = 0

    -- Prochain emplacement de véhicule relevé, ou nil s'il n'y en a plus.
    local function NextVehicleAnchor()
        if not vehAnchors then return nil end
        if type(vehAnchors) == 'table' and vehAnchors[1] and type(vehAnchors[1]) ~= 'number' then
            vehUsed = vehUsed + 1
            return vehAnchors[vehUsed]
        end
        if vehUsed > 0 then return nil end
        vehUsed = 1
        return vehAnchors
    end

    -- Création d'un véhicule de décor.
    local function spawn(poolName, offsetX, offsetY, damaged, anchored)
        local model = PickOne(C.Vehicles[poolName])
        if not model then return nil end

        local px, py = base.x + offsetX, base.y + offsetY
        local pz, ph = base.z + 1.0, base.w + 0.0
        if anchored then
            local a = NextVehicleAnchor()
            if a then
                px, py, pz, ph = a.x, a.y, a.z + 1.0, a.w or a.h or ph
            end
        end

        local ok, netId = pcall(function()
            local hash = GetHashKey(model)
            -- `CreateVehicle` est un native CÔTÉ CLIENT — FXServer le
            local vtype = poolName:find('bike') and 'bike' or 'automobile'
            local veh = CreateVehicleServerSetter(hash, vtype, px, py, pz, ph)
            if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end

            -- Créé légèrement au-dessus du sol théorique : un véhicule
            pcall(function()
                SetEntityDistanceCullingRadius(veh, C.EscapeDistance + 100.0)
            end)
            local id = NetworkGetNetworkIdFromEntity(veh)
            callout.vehicles[#callout.vehicles + 1] = {
                netId = id, entity = veh, kind = poolName, damaged = damaged,
            }
            return id
        end)

        if not ok then
            print('^1[callouts]^7 Échec de création du véhicule ' .. tostring(model) ..
                ' (' .. tostring(poolName) .. ') : ' .. tostring(netId))
            return nil
        end
        return netId
    end

    if sc.objective == 'radio' then
        local b = callout.boomboxPos or { x = base.x + 3.0, y = base.y + 2.0 }
        -- `anchored = true` : passe par le même relevé `vehicle` que les
        callout.boomboxNet = spawn('boombox_car', b.x - base.x, b.y - base.y, false, true)
    end
    if sc.targetVehicle then
        local tv = callout.targetVehiclePos or { x = base.x + 4.0, y = base.y + 1.0 }
        -- Voiture ou deux-roues : forcer un seul type rendait toutes les
        local pool = (math.random(1, 100) <= (C.TargetBikeChance or 30))
            and 'target_bike' or 'target_car'
        callout.targetVehNet = spawn(pool, tv.x - base.x, tv.y - base.y, false, true)
    end
    if sc.crash and callout.crashType then
        callout.crashVehNet = spawn('crashed_car', 3.0, 0.0, true, true)
        if callout.crashType.second then
            -- Le second véhicule d'une collision consomme lui aussi un
            spawn(callout.crashType.second, 6.0, 1.5, true, true)
        end
    end
    if sc.driver then
        local g = callout.getawayPos
        if g then
            callout.driverVehNet = spawn('flee_car', g.x - base.x, g.y - base.y, false, true)
        else
            callout.driverVehNet = spawn('flee_car', -5.0, 3.0, false, true)
        end
    end

    -- Tuerie de masse, variante « menace déjà neutralisée » : le
    if callout.massIncident and callout.massIncident.vehicleState == 'abandoned' then
        callout.suspectVehNet = spawn('mass_incident_car', -6.0, 2.0, false, true)
    end

    -- Sur un tapage, un fêtard tient le volant : c'est lui qui rend la
    if sc.objective == 'radio' and callout.boomboxNet then
        local pool = {}
        for _, p in pairs(callout.peds) do
            if p.role == 'suspect' then pool[#pool + 1] = p end
        end
        if #pool > 0 then
            local driver = pool[math.random(1, #pool)]
            driver.inCar = true
            local car = NetworkGetEntityFromNetworkId(callout.boomboxNet)
            if car and car ~= 0 and DoesEntityExist(car) and driver.entity
               and DoesEntityExist(driver.entity) then
                SetPedIntoVehicle(driver.entity, car, -1)
            end
        end
    end

    -- Deux-roues pour les fuyards concernés
    local i = 0
    for _, p in pairs(callout.peds) do
        if p.behavior == 'flee' and p.fleeOn == 'bike' then
            i = i + 1
            p.bikeNet = spawn('flee_bike', 8.0 + i * 2.5, -3.0, false)
        end
    end
end

-- Fin de mission : les PNJ ne s'évaporent pas sous les yeux des agents.
local function ReleaseScene(callout)
    if not callout then return end

    -- Sur un tapage, la fête est finie mais personne ne s'enfuit :
    local stay = (callout.scenario.objective == 'radio')
    -- Certains requérants n'ont aucune raison de partir : le
    local callerStays = callout.scenario.callerStays == true

    local netIds = {}
    for netId, p in pairs(callout.peds or {}) do
        if p.entity and DoesEntityExist(p.entity)
           and p.state ~= 'delivered' and p.state ~= 'escaped' then
            netIds[#netIds + 1] = {
                netId = netId, role = p.role,
                stay = stay or (callerStays and p.role == 'caller'),
            }
        end
    end

    -- Le client fait repartir les figurants à pied
    for src in pairs(callout.agents or {}) do
        TriggerClientEvent('police:callouts:releaseScene', src, netIds)
    end
end

local function DeleteAllEntities(callout)
    if not callout then return end
    for _, p in pairs(callout.peds or {}) do
        if p.entity and DoesEntityExist(p.entity) then DeleteEntity(p.entity) end
    end
    for _, v in ipairs(callout.vehicles or {}) do
        if v.entity and DoesEntityExist(v.entity) then DeleteEntity(v.entity) end
    end
    for _, o in ipairs(callout.droppedWeapons or {}) do
        if o.entity and DoesEntityExist(o.entity) then DeleteEntity(o.entity) end
    end
end

--  SYNCHRONISATION VERS LES CLIENTS

local function BuildPayload(co)
    if not co then return nil end
    local sc = co.scenario

    local peds = {}
    for netId, p in pairs(co.peds) do
        peds[#peds + 1] = {
            netId    = netId,
            role     = p.role,
            behavior = p.behavior,
            state    = p.state,
            weapon   = p.weapon,
            hidden   = p.hidden,
            anchored = p.anchored,
            fleeOn   = p.fleeOn,
            isDriver = p.isDriver,
            heistRole = p.heistRole,
            cashier   = p.cashier,
            client    = p.client,
            label    = PedLabel(p),
            identified = p.identified,
            items    = p.items,
            bikeNet  = p.bikeNet,
            direction = p.direction,
            droppedWeapon = p.droppedWeapon,
            searched = p.searched,
            inCar    = p.inCar,
            -- Tuerie de masse : témoin nommé (déposition propre) et
            witness       = p.witness,
            statementLines = p.statementLines,
            heard         = p.heard,
            constated     = p.constated,
            posture       = p.posture,
            -- Personne armée : validité du permis de port d'arme,
            permitValid   = p.permitValid,
        }
    end

    local agents = {}
    for src, a in pairs(co.agents) do
        agents[#agents + 1] = {
            src = src, name = a.name, grade = a.grade,
            leader = (src == co.leader), status = a.status,
            crew = Registered[src] and Registered[src].crew or nil,
        }
    end

    local v = co.location.loc.coords
    return {
        id         = co.id,
        scenarioId = co.scenarioId,
        label      = sc.label,
        objective  = sc.objective,
        falseAlarm = co.falseAlarm,
        coords     = { x = v.x, y = v.y, z = v.z, w = v.w },
        zoneLabel  = co.location.loc.label,
        street     = co.street,
        statement      = co.statement,
        statementLines = co.statementLines,
        statementTaken = co.statementTaken,
        radioOff       = co.radioOff,
        escapeTarget   = co.escapeTarget,
        scenarioIsDeathScene = (co.scenarioId == 'decouverte_corps'),
        -- Repère de secours pour la recherche de position (cf. ancrages).
        anchorCenter = co.anchorCenter,
        -- Tuerie de masse : niveau de danger DYNAMIQUE de cette
        massIncident  = co.massIncident and true or nil,
        dangerLevel   = co.dangerLevel,
        deadTotal     = co.deadTotal,
        deadConstated = co.deadConstated,
        aidTotal      = co.aidTotal,
        aidGiven      = co.aidGiven,
        searchRadius = C.SearchRadius,
        peds       = peds,
        agents     = agents,
        brain      = co.brain,
        leader     = co.leader,
        boomboxNet = co.boomboxNet,
        crashVehNet = co.crashVehNet,
        targetVehNet = co.targetVehNet,
        driverVehNet = co.driverVehNet,
        sound      = sc.sound,
        radioStation = co.radioStation,
        fleeTrigger = sc.fleeTrigger,
        -- Endurance propre au scénario : certains individus tiennent
        fleeSprint  = sc.fleeSprint,
        fleeSlowAt  = sc.fleeSlowAt,
        -- Le relâchement est offert partout, sauf refus explicite.
        moveAlong  = (sc.moveAlong ~= false),
        brawl      = sc.brawl,
        drunk      = sc.drunk,
        victimAssault   = sc.victimAssault,
        suspectScenario = sc.suspectScenario,
        animalRange = sc.animalRange,
        requireSuspects = sc.requireSuspects,
        extraDeath      = co.extraDeath,
        deathConstated  = co.deathConstated,
        canInterrogate  = true,
        ownerStatement  = co.ownerStatement,
        ownerLabel      = co.ownerLabel,
        -- Contraintes de composition : indiquent au client si un PNJ
        heist             = co.heist,
        suspectsAtCaller  = sc.suspectsAtCaller,
        suspectsAtVehicle = sc.suspectsAtVehicle,
        suspectCluster    = sc.suspectCluster,
        callerOffset      = sc.callerOffset,
        callerStays       = sc.callerStays,
        callerAtDoor      = sc.callerAtDoor,
        custodyNpc = 'custody',
        hospitalNpc = (sc.objective == 'hospital') and 'hospital' or nil,
        debug      = C.Debug,
    }
end

local function SyncEngaged(co)
    if not co then return end
    local payload = BuildPayload(co)
    for src in pairs(co.agents) do
        TriggerClientEvent('police:callouts:sync', src, payload)
    end
end

--  DÉSIGNATION DU CLIENT « CERVEAU »

local function AssignBrain(co, preferred)
    if not co then return end
    local chosen = nil
    if preferred and co.agents[preferred] then
        chosen = preferred
    else
        for src in pairs(co.agents) do chosen = src break end
    end
    if chosen ~= co.brain then
        co.brain = chosen
        if chosen then
            TriggerClientEvent('police:callouts:brainAssigned', chosen, co.id)
            Dbg('cerveau =', tostring(chosen))
        end
    end
end

--  RÉSOLUTION ET PRIMES

local function CountSuspects(callout)
    local total, delivered, killed, escaped, pending, dispersed = 0, 0, 0, 0, 0, 0
    if not callout then
        return total, delivered, killed, escaped, pending, dispersed
    end
    for _, p in pairs(callout.peds) do
        if p.role == 'suspect' then
            total = total + 1
            if p.state == 'delivered' then delivered = delivered + 1
            elseif p.state == 'dead' then killed = killed + 1
            elseif p.state == 'escaped' then escaped = escaped + 1
            -- Individu qu'on a fait circuler : la situation est réglée,
            elseif p.state == 'dispersed' then dispersed = dispersed + 1
            else pending = pending + 1 end
        end
    end
    return total, delivered, killed, escaped, pending, dispersed
end

-- Désignation administrative d'une arme pour la fiche d'intervention.
local function WeaponLabel(w)
    if not w then return nil end
    return (C.WeaponLabels and C.WeaponLabels[w]) or w
end

local function SuspectsJson(callout)
    local list = {}
    for _, p in pairs(callout.peds) do
        if p.role ~= 'bystander' then
            local identified = p.identified and p.state ~= 'escaped'
            -- L'arme est effacée de l'individu à la fouille ou quand il
            local carried = p.weapon or p.weaponInitial or p.droppedWeapon

            local seized = {}
            for _, it in ipairs(p.seized or {}) do
                seized[#seized + 1] = (C.WeaponLabels and C.WeaponLabels[it]) or it
            end

            list[#list + 1] = {
                firstname = identified and p.identity and p.identity.firstname or nil,
                lastname  = identified and p.identity and p.identity.lastname or nil,
                label     = (not identified) and (p.label or 'Individu non identifié') or nil,
                role      = p.role,
                weapon    = WeaponLabel(carried),
                seized    = (#seized > 0) and seized or nil,
                killedBy  = p.killedBy,
                releasedBy = p.releasedBy,
                killReason = p.killReason,
                -- Déposition recueillie sur place auprès du mis en cause.
                declaration = p.statement,
                stance      = p.stance,
                -- L'animal neutralisé puis constaté rejoint la même
                outcome   = (p.role == 'suspect' or p.role == 'wanderer')
                    and p.state
                    or ((p.role == 'deceased') and 'morgue')
                    or ((p.role == 'animal') and (callout.objectiveDone
                        and 'morgue' or p.state) or nil),
            }
        end
    end
    return json.encode(list)
end

local function PersistCallout(callout, status, cb)
    local total, delivered, killed, escaped = CountSuspects(callout)
    local v = callout.location.loc.coords

    MySQL.Async.insert(
        'INSERT INTO police_callouts (scenario_id, label, coords, zone, status, false_alarm, ' ..
        'agents_registered, suspects_total, suspects_delivered, suspects_killed, suspects_escaped, ' ..
        'suspects_json, response_time, department, started_at, ended_at) ' ..
        'VALUES (@sid, @label, @coords, @zone, @status, @fa, @staff, @tot, @del, @kil, @esc, @json, @rt, ' ..
        '@dep, FROM_UNIXTIME(@started), NOW())',
        {
            ['@sid']    = callout.scenarioId,
            ['@label']  = callout.scenario.label,
            ['@coords'] = string.format('%.1f, %.1f, %.1f', v.x, v.y, v.z),
            ['@zone']   = callout.street or callout.location.loc.label,
            ['@status'] = status,
            ['@fa']     = callout.falseAlarm and 1 or 0,
            ['@staff']  = callout.staff or 0,
            ['@tot']    = total,
            ['@del']    = delivered,
            ['@kil']    = killed,
            ['@esc']    = escaped,
            ['@json']   = callout.peds and SuspectsJson(callout) or nil,
            ['@rt']     = callout.responseTime,
            -- Le dossier est versé au pôle du chef d'équipage ; à défaut
            ['@dep']    = (callout.leader and GetMdtDepartment(callout.leader)) or 'police',
            ['@started']= callout.createdAt,
        },
        function(insertId)
            if cb then cb(insertId) end
        end
    )
end

local function PersistAgents(callout, calloutId)
    for src, a in pairs(callout.agents) do
        local p = GetPlayer(src)
        MySQL.Async.execute(
            'INSERT INTO police_callout_agents (callout_id, identifier, character_id, name, grade, department, is_leader, ' ..
            'cuffed, delivered, killed, misconduct, reward) ' ..
            'VALUES (@cid, @ident, @charId, @name, @grade, @dep, @leader, @cuffed, @del, @kil, @mis, @rew)',
            {
                ['@cid']    = calloutId,
                ['@ident']  = a.ident or 'unknown',
                ['@charId'] = p and p["boutique-id"] or nil,
                ['@name']   = a.name or 'Agent',
                ['@grade']  = a.grade or 0,
                ['@dep']    = GetMdtDepartment(src) or 'police',
                ['@leader'] = (src == callout.leader) and 1 or 0,
                ['@cuffed'] = a.cuffed or 0,
                ['@del']    = a.delivered or 0,
                ['@kil']    = a.killed or 0,
                ['@mis']    = a.misconduct or 0,
                ['@rew']    = a.reward or 0,
            }
        )
    end
end

-- Calcule et verse les primes. Retourne un résumé texte.
local function PayRewards(co, success)
    if not success then
        for _, a in pairs(co.agents) do a.reward = 0 end
        return 'Aucune prime (intervention non résolue).'
    end

    local base = co.falseAlarm and C.FalseAlarmReward or (co.scenario.reward or 0)
    if co.converted then
        local dc = Config.Police.Scenarios['decouverte_corps']
        base = dc and dc.reward or base
    end

    -- Prise en charge des victimes. Rien n'est obligatoire : l'agent
    local carePenalty, careMissed = 0.0, {}
    local CP = C.CarePenalty or {}
    for _, p in pairs(co.peds) do
        if p.role == 'victim' then
            if p.state ~= 'healed' then
                carePenalty = carePenalty + (CP.NotHealed or 0.25)
                careMissed[#careMissed + 1] = 'victime non secourue'
            end
            if not p.identified then
                carePenalty = carePenalty + (CP.NotIdentified or 0.10)
                careMissed[#careMissed + 1] = 'identité non relevée'
            end
        end
    end
    if carePenalty > (CP.Max or 0.50) then carePenalty = CP.Max or 0.50 end
    co.carePenalty = carePenalty
    co.careMissed  = careMissed

    -- Malus d'équipe cumulés
    local teamPenalty = 0.0
    teamPenalty = teamPenalty + math.min(
        (co.armedDeliveries or 0) * C.ArmedDeliveryPenalty, C.ArmedDeliveryMaxPenalty)
    teamPenalty = teamPenalty + math.min(
        (co.misconducts or 0) * C.MisconductTeamPenalty, C.MisconductTeamMaxPenalty)
    teamPenalty = teamPenalty + carePenalty
    if teamPenalty > 0.95 then teamPenalty = 0.95 end

    local teamAmount = math.floor(base * (1.0 - teamPenalty))
    if teamAmount < 0 then teamAmount = 0 end

    for src, a in pairs(co.agents) do
        local amount = teamAmount
        if (a.misconduct or 0) > 0 then amount = 0 end
        a.reward = amount

        if amount > 0 then
            local player = LSLegacy.Players.Get(src)
            if player then
                LSLegacy.Bank.PaySalary(player, amount, 'Prime d\'intervention')
                Notify(src, 'Intervention terminée — prime de ' .. amount .. ' $.', 'success')
            end
        elseif (a.misconduct or 0) > 0 then
            Notify(src, 'Bavure constatée — aucune prime pour cette intervention.', 'error')
        else
            Notify(src, 'Intervention terminée — aucune prime.', 'warning')
        end
    end

    local txt = 'Prime : ' .. teamAmount .. ' $'
    if teamPenalty > 0 then
        txt = txt .. string.format(' (malus %d %%)', math.floor(teamPenalty * 100))
    end
    if #careMissed > 0 then
        txt = txt .. ' — ' .. table.concat(careMissed, ', ')
    end
    return txt
end

local EndCallout   -- forward declaration
local MaybeFinishMassIncident   -- forward declaration

-- Résumé radio de fin d'intervention, adapté au type de mission.
local function EndSummary(co, success)
    if not co then return 'situation normalisée' end

    if not success then
        local _, _, _, escaped = CountSuspects(co)
        if escaped > 0 then
            return escaped .. ' individu(s) en fuite, intervention négative'
        end
        return 'intervention négative'
    end

    if co.falseAlarm then
        return 'fausse alerte, rien à signaler'
    end

    local obj = co.scenario.objective
    if co.converted then
        return 'décès constaté, individu abattu par un tiers'
    elseif obj == 'statement' then
        return 'constatations effectuées, déposition prise'
    elseif obj == 'death' then
        return 'décès constaté, levée de corps à organiser'
    elseif obj == 'hospital' then
        return 'personne prise en charge par les services hospitaliers'
    elseif obj == 'radio' then
        return 'nuisance sonore stoppée, situation normalisée'
    end

    local _, delivered, killed, escaped, _, dispersed = CountSuspects(co)
    local parts = {}
    if delivered > 0 then parts[#parts + 1] = delivered .. ' individu(s) interpellé(s)' end
    if dispersed > 0 then parts[#parts + 1] = dispersed .. ' laissé(s) libre(s)' end
    if killed    > 0 then parts[#parts + 1] = killed    .. ' neutralisé(s)' end
    if escaped   > 0 then parts[#parts + 1] = escaped   .. ' en fuite' end
    if #parts == 0 then parts[1] = 'situation normalisée' end
    return table.concat(parts, ', ')
end

EndCallout = function(co, status)
    if not co then return end
    local callout = co
    local success = (status == 'success')

    local rewardTxt = 'Appel classé sans suite.'
    if callout.state == 'active' then
        rewardTxt = PayRewards(co, success)
    end

    -- Message radio de clôture
    if callout.state == 'active' then
        NotifyEngaged(co, string.format(C.Dispatch.ended, EndSummary(co, success)),
            success and 'success' or 'warning')
        NotifyEngaged(co, 'Intervention terminée — n\'oubliez pas de rédiger votre rapport.', 'info')
    end

    -- Log Discord
    local total, delivered, killed, escaped = CountSuspects(co)
    local agentNames = {}
    for _, a in pairs(callout.agents) do agentNames[#agentNames + 1] = a.name end

    local statusLabel = (status == 'success' and 'Réussite')
        or (status == 'cancelled' and 'Classé sans suite') or 'Échec'

    LogDiscord('Intervention — ' .. callout.scenario.label,
        '**Statut :** ' .. statusLabel .. '\n' ..
        '**Lieu :** ' .. (callout.street or callout.location.loc.label) .. '\n' ..
        (callout.falseAlarm and '**Fausse alerte**\n' or '') ..
        (callout.converted and '**Requalifié en constatation de décès**\n' or '') ..
        '**Bilan :** ' .. delivered .. ' interpellé(s), ' .. killed .. ' neutralisé(s), ' ..
        escaped .. ' en fuite (sur ' .. total .. ')\n' ..
        '**Agents :** ' .. (#agentNames > 0 and table.concat(agentNames, ', ') or 'aucun') .. '\n' ..
        '**' .. rewardTxt .. '**',
        success and 3066993 or 15158332)

    -- Persistance
    if callout.state ~= 'pending' or status == 'cancelled' then
        PersistCallout(callout, status, function(insertId)
            if insertId then PersistAgents(callout, insertId) end
        end)
    end

    -- Sortie de scène : les figurants repartent, la suppression effective
    ReleaseScene(callout)
    for src in pairs(callout.agents) do
        TriggerClientEvent('police:callouts:ended', src, { id = callout.id, status = status })
        AgentCall[src] = nil          -- l'agent redevient disponible
    end
    SetTimeout(C.CleanupDelay * 1000, function()
        DeleteAllEntities(callout)
    end)
    if callout.location then
        LocationCd[callout.location.key] = os.time()
    end

    -- L'intervention sort du registre : son équipage peut en reprendre une
    Callouts[callout.id] = nil
    Dbg('appel terminé :', callout.id, status)
end

-- Tuerie de masse : fait redescendre le niveau de danger DYNAMIQUE de
local function MaybeDeescalate(co)
    if not co or not co.massIncident or not co.dangerLevel then return end
    if co.deescalated or co.state ~= 'active' then return end

    local total, _, _, _, pending = CountSuspects(co)
    local suspectHandled = (total == 0) or (pending == 0)
    if not suspectHandled then return end

    -- Sans suspect à traiter (variantes B/D/E), on attend un geste
    if total == 0 and not ((co.deadConstated or 0) > 0 or co.statementTaken) then
        return
    end

    co.deescalated = true
    co.dangerLevel = math.max(2, co.dangerLevel - 2)
    Dbg('tuerie de masse : désescalade →', co.dangerLevel)
    SyncEngaged(co)
end

-- Vérifie si l'appel est résolu (à appeler après chaque changement d'état).
local function CheckResolution(co)
    if not co or co.state ~= 'active' then return end
    MaybeDeescalate(co)
    local sc = co.scenario

    -- Un corps sur les lieux bloque la clôture tant qu'il n'a pas été
    if co.extraDeath and not co.deathConstated and not sc.multiDeath then return end

    -- Scénarios à objectif (constatations, hôpital, sono) + fausses alertes
    if co.falseAlarm or sc.objective then
        if not co.objectiveDone then return end

        -- Certains scénarios à objectif comportent en plus un mis en
        if sc.requireSuspects and not co.falseAlarm then
            local total, _, _, escaped, pending = CountSuspects(co)
            if total > 0 then
                if pending > 0 then return end
                if escaped > 0 then EndCallout(co, 'failed') return end
            end
        end

        EndCallout(co, 'success')
        return
    end

    local total, _, _, escaped, pending = CountSuspects(co)
    if total == 0 then
        if co.objectiveDone then EndCallout(co, 'success') end
        return
    end
    if pending > 0 then return end

    if escaped > 0 then
        EndCallout(co, 'failed')
    else
        EndCallout(co, 'success')
    end
end

-- Bascule en constatation de décès quand des tiers ont tué tous les suspects.
local function MaybeConvertToDeathScene(co)
    if not co or co.state ~= 'active' then return end
    if co.converted or co.scenario.objective then return end

    local total, delivered, killed, escaped, pending, dispersed = CountSuspects(co)
    if total == 0 or pending > 0 or escaped > 0 or delivered > 0 then return end
    -- Un individu déjà pris en charge par la police : la scène n'est plus
    if dispersed > 0 then return end
    if killed == 0 then return end

    -- Tous les suspects sont morts : y a-t-il eu au moins un tir de tiers ?
    if not co.civilianKills or co.civilianKills < killed then return end

    co.converted     = true
    co.objectiveDone = false
    co.scenario      = Config.Police.Scenarios['decouverte_corps'] or co.scenario
    for _, p in pairs(co.peds) do
        if p.role == 'suspect' and p.state == 'dead' then p.role = 'deceased' end
    end
    NotifyEngaged(co, 'L\'individu a été abattu par un tiers — procédez aux constatations.', 'warning')
    SyncEngaged(co)
end

--  DIFFUSION D'UN APPEL

local function DispatchMessage(sc, location, overrideDispatch)
    local line = PickOne(overrideDispatch) or PickOne(sc.dispatch) or (sc.label .. ' signalé %s.')
    local where = 'secteur ' .. (location.loc.label or 'inconnu')
    return C.Dispatch.prefix .. ' — ' .. string.format(line, where)
end

local function CreateCallout(scenarioId, forced)
    local sc = Config.Police.Scenarios[scenarioId]
    if not sc then return false, 'Scénario inconnu.' end

    local picked = PickLocation(sc.locations, scenarioId)
    if not picked then return false, 'Aucun emplacement disponible pour ce scénario.' end

    local staff = GetStaffCount()
    if forced and staff < 1 then staff = C.TestModeDefaultStaff end

    local falseAlarm = false
    if sc.allowFalseAlarm ~= false and math.random(1, 100) <= C.FalseAlarmChance then
        falseAlarm = true
    end

    CalloutSeq = CalloutSeq + 1
    local co = {
        id         = CalloutSeq,
        scenarioId = scenarioId,
        scenario   = sc,
        location   = { loc = picked.loc, index = picked.index, key = picked.key, category = sc.locations },
        -- Zone du quartier : déclarée sur l'emplacement, sinon déduite
        zone       = picked.loc.zone
            or (C.ZoneByCategory and C.ZoneByCategory[sc.locations])
            or C.ZoneFallback,
        falseAlarm = falseAlarm,
        state      = 'pending',
        createdAt  = os.time(),
        staff      = staff,
        agents     = {},
        peds       = {},
        vehicles   = {},
        droppedWeapons = {},
        misconducts    = 0,
        armedDeliveries = 0,
        civilianKills   = 0,
        backup          = { at = 0, by = nil },
    }

    -- TUERIE DE MASSE : la variante (A-E) est tirée UNE fois ici, à la
    if sc.massIncident and C.MassShooting and C.MassShooting.Enabled then
        co.massVariant = WeightedEntry(C.MassShooting.Scenarios)
    end

    Callouts[co.id] = co
    LastScenario = scenarioId

    local msg = DispatchMessage(sc, co.location, co.massVariant and co.massVariant.dispatch)
    local v   = picked.loc.coords

    -- Diffusion aux seuls agents dont l'ÉQUIPAGE est libre : un équipage
    for src in pairs(Registered) do
        if not IsCrewBusy(Registered[src].crew) then
        TriggerClientEvent('police:callouts:incoming', src, {
            id = co.id, scenarioId = scenarioId, label = sc.label,
            zoneLabel = picked.loc.label, message = msg,
            -- Coordonnées envoyées dès la diffusion : le blip apparaît
            coords = { x = v.x, y = v.y, z = v.z },
            timeout = C.AcceptTimeout,
        })
        end
    end

    Dbg('appel diffusé :', scenarioId, picked.loc.label, '[' .. co.zone .. ']', falseAlarm and '(fausse alerte)' or '')

    -- Expiration si personne n'accepte.
    local myId = co.id
    SetTimeout(C.AcceptTimeout * 1000, function()
        local pendingCo = Callouts[myId]
        if not pendingCo or pendingCo.state ~= 'pending' then return end

        -- L'annulation n'était diffusée QUE lorsqu'un équipage prenait
        for other in pairs(Registered) do
            TriggerClientEvent('police:callouts:cancelled', other, { id = myId })
        end

        EndCallout(pendingCo, 'cancelled')
    end)

    return true
end

--  SCHEDULER

CreateThread(function()
    while true do
        Wait(C.Interval * 1000)
        -- En mode test, plus rien ne tombe tout seul : l'admin lance les
        local blocked = TestMode.active and C.TestModeStopsScheduler
        -- Autant d'interventions simultanées que d'équipages occupés :
        local maxActive = math.max(1, math.min(StaffedCrews(), #C.Crews))
        if C.Enabled and not blocked and ActiveCount() < maxActive then
            local staff = GetStaffCount()
            if staff >= 1 then
                local pool = EligibleScenarios(staff, false)
                local pick = WeightedPick(pool)
                if pick then
                    local ok, err = CreateCallout(pick, false)
                    if not ok then Dbg('tirage ignoré :', tostring(err)) end
                else
                    Dbg('aucun scénario éligible')
                end
            end
        end
    end
end)

-- Garde-fou global : timeout de mission
CreateThread(function()
    while true do
        Wait(5000)
        for _, co in pairs(Callouts) do
            if co.state == 'active'
               and (os.time() - (co.takenAt or co.createdAt))
                   > (co.scenario.timeout or C.MissionTimeout) then
                NotifyEngaged(co,
                    'Intervention non résolue dans les délais — clôture automatique.', 'error')
                EndCallout(co, 'failed')
            end
        end
    end
end)

-- Vérification périodique de l'existence des entités (anti-despawn)
CreateThread(function()
    while true do
        Wait(15000)
        for _, co in pairs(Callouts) do
            local changed = false
            if co.state == 'active' then
            for _, p in pairs(co.peds) do
                if p.role == 'suspect' and p.state ~= 'delivered' and p.state ~= 'dead'
                   and p.state ~= 'escaped' then
                    if not p.entity or not DoesEntityExist(p.entity) then
                        p.state = 'escaped'
                        changed = true
                        Dbg('entité disparue → escaped', tostring(p.netId))
                    end
                end
            end
            end
            if changed then SyncEngaged(co) CheckResolution(co) end
        end
    end
end)

--  ENREGISTREMENT AU GROUPE D'INTERVENTION

-- Effectif d'un équipage donné.
local function CrewCount(crewId)
    local n = 0
    for _, r in pairs(Registered) do
        if r.crew == crewId then n = n + 1 end
    end
    return n
end

-- Liste des sources engagées dans le même équipage qu'un agent.
local function CrewMembers(crewId)
    local out = {}
    for src, r in pairs(Registered) do
        if r.crew == crewId and IsLawEnforcementOnDuty(src) then
            out[#out + 1] = src
        end
    end
    return out
end

local function CrewLabel(crewId)
    for _, c in ipairs(C.Crews) do
        if c.id == crewId then return c.label end
    end
    return 'Équipage'
end

-- Envoie au client l'état des équipages (effectifs, places restantes).
local function SendCrewState(src)
    local crews = {}
    for _, c in ipairs(C.Crews) do
        crews[#crews + 1] = {
            id = c.id, label = c.label,
            count = CrewCount(c.id), max = C.CrewMaxSize,
        }
    end
    TriggerClientEvent('police:callouts:crewState', src, {
        crews = crews,
        current = Registered[src] and Registered[src].crew or nil,
    })
end

local function DoRegister(src, crewId)
    -- Missions conjointes : police et gendarmerie s'engagent indifféremment
    if not IsLawEnforcement(src) then
        Notify(src, "Réservé aux forces de l'ordre.", 'error')
        return
    end
    if not IsLawEnforcementOnDuty(src) then
        Notify(src, 'Vous devez être en service pour rejoindre Police Secours.', 'error')
        return
    end

    if Registered[src] then
        -- Désinscription : quitte aussi l'appel en cours
        local co = CalloutOf(src)
        if co then
            co.agents[src] = nil
            AgentCall[src] = nil
            Notify(src, 'Vous quittez l\'intervention en cours — prime perdue.', 'warning')
            TriggerClientEvent('police:callouts:ended', src, { id = co.id, status = 'left' })
            local remaining = 0
            for _ in pairs(co.agents) do remaining = remaining + 1 end
            if remaining == 0 then
                EndCallout(co, 'failed')
            else
                if co.brain == src then AssignBrain(co, nil) end
                if co.leader == src then co.leader = co.brain end
                SyncEngaged(co)
            end
        end
        Registered[src] = nil
        if TestMode.active and TestMode.admin == src then
            TestMode.active = false
            TestMode.admin  = nil
            print('^2[callouts]^7 Mode test désactivé (administrateur désinscrit).')
            LogDiscord('Missions PNJ — mode test', 'Désactivé automatiquement.', 15105570)
        end
        Notify(src, 'Vous quittez Police Secours.', 'info')
        TriggerClientEvent('police:callouts:registerState', src, false)
        return
    end

    local p = GetPlayer(src)
    -- Inscription : un équipage est obligatoire
    if not crewId then
        SendCrewState(src)
        return
    end

    local valid = false
    for _, c in ipairs(C.Crews) do if c.id == crewId then valid = true end end
    if not valid then
        Notify(src, 'Équipage inconnu.', 'error')
        return
    end
    if CrewCount(crewId) >= C.CrewMaxSize then
        Notify(src, CrewLabel(crewId) .. ' est complet (' .. C.CrewMaxSize .. ' agents).', 'error')
        SendCrewState(src)
        return
    end

    Registered[src] = {
        name  = GetName(src),
        ident = GetIdentifier(src),
        grade = GetGrade(src),
        crew  = crewId,
    }
    Notify(src, 'Vous rejoignez ' .. CrewLabel(crewId) ..
        ' (' .. CrewCount(crewId) .. '/' .. C.CrewMaxSize .. ') — Police Secours.', 'success')
    TriggerClientEvent('police:callouts:registerState', src, true, crewId, CrewLabel(crewId))

    -- Les autres membres de l'équipage sont prévenus
    for _, other in ipairs(CrewMembers(crewId)) do
        if other ~= src then
            Notify(other, (Registered[src].name or 'Un agent') ..
                ' rejoint votre équipage.', 'info')
        end
    end
end

-- Le client demande la liste des équipages (clic sur Anna)
LSLegacy.Events.Register('police:callouts:askCrews', function()
    local src = source
    if not IsLawEnforcementOnDuty(src) then
        Notify(src, "Vous devez être en service dans une force de l'ordre.", 'error')
        return
    end
    SendCrewState(src)
end)

LSLegacy.Events.Register('police:callouts:register', function(data)
    DoRegister(source, data and data.crew or nil)
end)

-- Désinscription automatique en fin de service.
AddEventHandler('police:callouts:officerOffDuty', function(src)
    if not src or not Registered[src] then return end

    local co = CalloutOf(src)
    if co then
        co.agents[src] = nil
        AgentCall[src] = nil
        TriggerClientEvent('police:callouts:ended', src, { id = co.id, status = 'left' })
        local remaining = 0
        for _ in pairs(co.agents) do remaining = remaining + 1 end
        if remaining == 0 then
            EndCallout(co, 'failed')
        else
            if co.brain == src then AssignBrain(co, nil) end
            if co.leader == src then co.leader = co.brain end
            SyncEngaged(co)
        end
    end

    Registered[src] = nil
    TriggerClientEvent('police:callouts:registerState', src, false)

    if TestMode.active and TestMode.admin == src then
        TestMode.active = false
        TestMode.admin  = nil
        print('^2[callouts]^7 Mode test désactivé (fin de service de l\'administrateur).')
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if not Registered[src] then return end

    local co = CalloutOf(src)
    if co then
        co.agents[src] = nil
        AgentCall[src] = nil
        local remaining = 0
        for _ in pairs(co.agents) do remaining = remaining + 1 end
        if remaining == 0 then
            EndCallout(co, 'failed')
        else
            if co.brain == src then AssignBrain(co, nil) end
            if co.leader == src then co.leader = co.brain end
            SyncEngaged(co)
        end
    end
    Registered[src] = nil

    if TestMode.active and TestMode.admin == src then
        TestMode.active = false
        TestMode.admin  = nil
        print('^2[callouts]^7 Mode test désactivé (administrateur déconnecté).')
    end
end)

--  PRISE EN CHARGE ET RENFORTS

local function AddAgent(co, src, asLeader)
    co.agents[src] = {
        name  = Registered[src] and Registered[src].name or GetName(src),
        ident = Registered[src] and Registered[src].ident or GetIdentifier(src),
        grade = GetGrade(src),
        status = 'enroute',
        cuffed = 0, delivered = 0, killed = 0, misconduct = 0, reward = 0,
        joinedAt = os.time(),
    }
    AgentCall[src] = co.id
    if asLeader then co.leader = src end
end

LSLegacy.Events.Register('police:callouts:accept', function(data)
    local src = source
    if not Registered[src] or not IsLawEnforcementOnDuty(src) then return end
    if not data then return end

    local co = Callouts[tonumber(data.id) or 0]
    if not co then return end
    if co.state ~= 'pending' then
        Notify(src, 'Cet appel a déjà été pris en charge.', 'error')
        return
    end
    if IsEngaged(src) then
        Notify(src, 'Vous êtes déjà engagé sur une intervention.', 'error')
        return
    end
    -- Un équipage déjà sur le terrain ne peut pas en prendre une seconde
    if IsCrewBusy(Registered[src].crew) then
        Notify(src, 'Votre équipage est déjà engagé sur une intervention.', 'error')
        return
    end

    co.state   = 'active'
    co.takenAt = os.time()
    AddAgent(co, src, true)

    -- L'équipage entier est engagé d'un bloc : un seul membre accepte,
    local crew = Registered[src] and Registered[src].crew or nil
    co.crew = crew
    if crew then
        for _, mate in ipairs(CrewMembers(crew)) do
            if mate ~= src and not co.agents[mate] and not IsEngaged(mate) then
                AddAgent(co, mate, false)
                Notify(mate, 'Votre équipage prend un appel — ' ..
                    co.scenario.label .. '.', 'info')
            end
        end
    end

    -- Création immédiate de la scène. Aucun appel bloquant vers un client :
    local sc     = co.scenario
    local roster = BuildRoster(sc, co.staff, co.falseAlarm, co.zone, co.massVariant)
    co.crashType = roster.crashType

    -- La mise en scène ne doit JAMAIS empêcher la synchronisation :
    local okE, errE = pcall(SpawnEntities, co, roster, nil)
    if not okE then
        print('^1[callouts]^7 Erreur lors du spawn des PNJ : ' .. tostring(errE))
    end
    local okV, errV = pcall(SpawnVehicles, co, sc)
    if not okV then
        print('^1[callouts]^7 Erreur lors du spawn des véhicules : ' .. tostring(errV))
    end

    -- Le pcall ci-dessus évite qu'une erreur de mise en scène prive les
    local nPeds = 0
    for _ in pairs(co.peds or {}) do nPeds = nPeds + 1 end
    if nPeds == 0 and #roster > 0 then
        print(('^1[callouts]^7 ANOMALIE : aucun PNJ créé pour %s (%d attendus). ' ..
            'Voir l\'erreur de spawn ci-dessus.'):format(tostring(co.scenarioId), #roster))
        NotifyEngaged(co, 'Anomalie technique : aucun PNJ n\'a pu être créé sur ' ..
            'cette intervention. Signalez-le à l\'administration.', 'error')
    end

    Notify(src, C.Dispatch.taken, 'success')
    SyncEngaged(co)
    AssignBrain(co, src)

    -- Les autres enregistrés savent que cet appel est pris
    for other in pairs(Registered) do
        if not co.agents[other] then
            TriggerClientEvent('police:callouts:cancelled', other, { id = co.id, taken = true })
        end
    end
    Dbg('appel', co.id, 'pris en charge par', tostring(src), 'équipage', tostring(crew))
end)

-- Le cerveau remonte le nom de rue réel une fois sur place (non bloquant)
LSLegacy.Events.Register('police:callouts:reposition', function(data)
    local src = source
    local co = CalloutOf(src)
    if not co or not data or not data.netId then return end
    -- Comme les events voisins (corpseVisible, reportStreet…) : seul le
    if src ~= co.brain then return end

    local p = co.peds[tonumber(data.netId)]
    if not p or not p.entity or not DoesEntityExist(p.entity) then return end

    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if not x or not y or not z then return end

    -- Garde-fou : on n'accepte qu'un recalage local, jamais un
    local base = co.location.loc.coords
    if not LSLegacy.Validate.Distance(vector3(x, y, z), vector3(base.x, base.y, base.z), C.SearchRadius + 50.0) then
        return
    end

    SetEntityCoords(p.entity, x, y, z, false, false, false, false)
    if data.h then SetEntityHeading(p.entity, tonumber(data.h) + 0.0) end
    p.spawn = { x = x, y = y, z = z, h = data.h or 0.0 }
end)

-- Relais de visibilité du corps. Le cerveau masque le cadavre pendant
LSLegacy.Events.Register('police:callouts:corpseVisible', function(data)
    local src = source
    local co = CalloutOf(src)
    if not co or not data or not data.netId then return end
    if src ~= co.brain then return end

    local netId = tonumber(data.netId)
    local p = co.peds[netId]
    if not p or p.role ~= 'deceased' then return end

    for agent in pairs(co.agents) do
        if agent ~= src then
            TriggerClientEvent('police:callouts:corpseVisible', agent, {
                netId = netId, visible = data.visible and true or false,
            })
        end
    end
end)

LSLegacy.Events.Register('police:callouts:reportStreet', function(data)
    local src = source
    local co = CalloutOf(src)
    if not co or co.brain ~= src then return end
    if co.street or not data or type(data.street) ~= 'string' then return end
    co.street = data.street
end)

-- Refus explicite d'un appel. Sans ce retour, un appel décliné restait
LSLegacy.Events.Register('police:callouts:refuse', function(data)
    local src = source
    if not Registered[src] or not data then return end

    local co = Callouts[tonumber(data.id) or 0]
    if not co or co.state ~= 'pending' then return end

    co.refused = co.refused or {}
    co.refused[src] = true

    -- Tous les équipages libres ont-ils décliné ?
    local waiting = 0
    for other in pairs(Registered) do
        if not IsCrewBusy(Registered[other].crew) and not co.refused[other] then
            waiting = waiting + 1
        end
    end

    Dbg('refus de', tostring(src), 'sur l\'appel', co.id, '— en attente :', waiting)

    if waiting == 0 then
        NotifyRegistered('Appel décliné par toutes les unités disponibles — ' ..
            'classé sans suite.', 'warning')
        EndCallout(co, 'cancelled')
    end
end)

LSLegacy.Events.Register('police:callouts:leave', function()
    local src = source
    local co = CalloutOf(src)
    if not co then return end

    co.agents[src] = nil
    AgentCall[src] = nil
    Notify(src, 'Vous quittez l\'intervention — prime perdue.', 'warning')
    TriggerClientEvent('police:callouts:ended', src, { id = co.id, status = 'left' })

    local remaining = 0
    for _ in pairs(co.agents) do remaining = remaining + 1 end
    if remaining == 0 then
        EndCallout(co, 'failed')
    else
        if co.brain == src then AssignBrain(co, nil) end
        if co.leader == src then co.leader = co.brain end
        SyncEngaged(co)
    end
end)

LSLegacy.Events.Register('police:callouts:requestBackup', function()
    local src = source
    local co = CalloutOf(src)
    if not co or co.state ~= 'active' then return end

    local now = os.time()
    co.backup = co.backup or { at = 0 }
    if (now - (co.backup.at or 0)) < C.BackupCooldown then
        Notify(src, 'Demande de renfort déjà émise récemment.', 'error')
        return
    end
    co.backup = { at = now, by = src }

    local n = 0
    for _ in pairs(co.agents) do n = n + 1 end
    local msg = string.format(C.Dispatch.backup, co.street or co.location.loc.label, n)

    local v = co.location.loc.coords
    -- Seuls les équipages LIBRES peuvent venir en renfort
    for other in pairs(Registered) do
        if not IsEngaged(other) and not IsCrewBusy(Registered[other].crew) then
            TriggerClientEvent('police:callouts:backupRequested', other, {
                id = co.id, label = co.scenario.label,
                zoneLabel = co.location.loc.label, message = msg, agents = n,
                -- Sans coordonnées, le renfort n'a aucun blip pour se rendre
                coords = { x = v.x, y = v.y, z = v.z },
            })
        end
    end
    NotifyEngaged(co, 'Demande de renfort transmise au central.', 'info')
end)

LSLegacy.Events.Register('police:callouts:acceptBackup', function(data)
    local src = source
    if not Registered[src] or not IsLawEnforcementOnDuty(src) then return end
    if not data then return end
    local co = Callouts[tonumber(data.id) or 0]
    if not co or co.state ~= 'active' then return end
    if IsEngaged(src) or IsCrewBusy(Registered[src].crew) then
        Notify(src, 'Votre équipage est déjà engagé.', 'error')
        return
    end
    if (os.time() - ((co.backup and co.backup.at) or 0)) > C.BackupTimeout then
        Notify(src, 'La demande de renfort a expiré.', 'error')
        return
    end

    AddAgent(co, src, false)
    Notify(src, 'Vous rejoignez l\'intervention en renfort.', 'success')
    NotifyEngaged(co, (co.agents[src].name or 'Un agent') .. ' arrive en renfort.', 'info')

    -- Le renfort engage également tout l'équipage du volontaire
    local crew = Registered[src] and Registered[src].crew or nil
    if crew then
        for _, mate in ipairs(CrewMembers(crew)) do
            if mate ~= src and not co.agents[mate] and not IsEngaged(mate) then
                AddAgent(co, mate, false)
                Notify(mate, 'Votre équipage part en renfort.', 'info')
            end
        end
    end
    SyncEngaged(co)
end)

LSLegacy.Events.Register('police:callouts:setStatus', function(data)
    local src = source
    local co = CalloutOf(src)
    if not co or not data or not data.status then return end
    local allowed = { available = true, enroute = true, onscene = true, unavailable = true }
    if not allowed[data.status] then return end
    co.agents[src].status = data.status

    -- Temps de réponse : premier agent arrivé sur zone
    if data.status == 'onscene' and not co.responseTime then
        co.responseTime = os.time() - co.createdAt
    end
    SyncEngaged(co)
end)

--  ÉVÉNEMENTS SUR LES PNJ

-- Récupère un PNJ de l'intervention de l'agent, avec les validations.
local function GetPed(src, data)
    local co = CalloutOf(src)
    if not co or co.state ~= 'active' then return nil, nil end
    if not data or not data.netId then return nil, nil end
    return co.peds[tonumber(data.netId)], co
end

-- Distance réelle entre un agent et un PNJ (contrôle serveur).
local function AgentNear(src, ped, radius)
    if not ped or not ped.entity or not DoesEntityExist(ped.entity) then return false end
    local a = GetEntityCoords(GetPlayerPed(src))
    local b = GetEntityCoords(ped.entity)
    return LSLegacy.Validate.Distance(a, b, radius or 5.0)
end

LSLegacy.Events.Register('police:callouts:suspectStunned', function(data)
    local src = source
    local p, co = GetPed(src, data)
    if not p or p.role == 'caller' then return end
    if p.state == 'cuffed' or p.state == 'delivered' or p.state == 'dead' then return end
    if not AgentNear(src, p, 30.0) then return end

    p.state = 'stunned'
    SyncEngaged(co)
end)

LSLegacy.Events.Register('police:callouts:suspectCuffed', function(data)
    local src = source
    local p, co = GetPed(src, data)
    if not p or (p.role ~= 'suspect' and p.role ~= 'wanderer') then return end
    if p.state == 'cuffed' or p.state == 'delivered' or p.state == 'dead' then return end
    if not AgentNear(src, p, 4.0) then return end

    p.state = 'cuffed'
    co.agents[src].cuffed = (co.agents[src].cuffed or 0) + 1
    NotifyEngaged(co, PedLabel(p) .. ' a été menotté(e).', 'success')
    SyncEngaged(co)
end)

LSLegacy.Events.Register('police:callouts:suspectIdentify', function(data)
    local src = source
    local p, co = GetPed(src, data)
    if not p or p.identified then return end
    if not AgentNear(src, p, 4.0) then return end
    -- Une victime se laisse toujours identifier ; un mis en cause doit
    if p.role ~= 'victim'
       and not (p.state == 'cuffed' or p.state == 'stunned' or p.behavior == 'passive') then
        Notify(src, 'Impossible de contrôler cet individu dans cet état.', 'error')
        return
    end

    p.identified = true
    Notify(src, 'Identité relevée : ' .. PedLabel(p) .. '.', 'success')
    SyncEngaged(co)
end)

-- Faire circuler un individu. Alternative à l'interpellation sur les
LSLegacy.Events.Register('police:callouts:moveAlong', function(data)
    local src = source
    local p, co = GetPed(src, data)
    if not p or p.role ~= 'suspect' then return end
    -- Ouvert à TOUS les scénarios : décider qu'il n'y a pas matière à
    if co.scenario.moveAlong == false then return end
    if not AgentNear(src, p, 4.0) then return end

    -- On ne relâche pas quelqu'un qui a encore une arme sur lui.
    if p.weapon then
        Notify(src, 'Impossible : ' .. PedLabel(p) ..
            ' est toujours porteur d\'une arme.', 'error')
        return
    end

    -- On ne fait pas circuler quelqu'un de menotté, blessé ou déjà parti.
    if p.state ~= 'idle' then
        Notify(src, 'Impossible dans l\'état actuel de l\'individu.', 'error')
        return
    end
    if p.behavior ~= 'passive' then
        Notify(src, 'L\'individu n\'est pas en état de coopérer.', 'error')
        return
    end

    p.state = 'dispersed'
    p.releasedBy = co.agents[src] and co.agents[src].name or nil
    Notify(src, PedLabel(p) .. ' est laissé(e) libre et quitte les lieux.', 'success')
    SyncEngaged(co)
    CheckResolution(co)
end)

-- Audition du mis en cause. Certains scénarios prévoient que l'individu
local function PickStance(p)
    local D = Config.Police.Dialogues
    if not D then return 'nie' end

    local weights
    if p.state == 'cuffed' or p.state == 'stunned' then
        weights = D.SuspectStancesCuffed
    else
        weights = (D.SuspectStances or {})[p.behavior or 'passive']
    end
    if not weights then return 'nie' end

    local total = 0
    for _, w in pairs(weights) do total = total + w end
    if total <= 0 then return 'nie' end

    local r, acc = math.random() * total, 0
    for stance, w in pairs(weights) do
        acc = acc + w
        if r <= acc then return stance end
    end
    return 'nie'
end

-- Phrase de défense, choisie comme celles des requérants : mission,
local function PickSuspectLine(co, stance)
    local D = Config.Police.Dialogues
    if not D then return nil end

    local place = (co.dialogue and co.dialogue.place) or '*'
    local mission = (D.SuspectLines or {})[co.scenarioId]

    if mission then
        local order = {
            mission[place] and mission[place][stance],
            mission['*'] and mission['*'][stance],
        }
        for _, list in ipairs(order) do
            if type(list) == 'table' and #list > 0 then
                return list[math.random(1, #list)]
            end
        end
    end

    local fb = (D.SuspectFallback or {})[stance]
    if type(fb) == 'table' and #fb > 0 then return fb[math.random(1, #fb)] end
    return nil
end

-- Témoignage d'une victime, choisi comme celui des requérants :
local function PickVictimLine(co, healed)
    local D = Config.Police.Dialogues
    if not D then return nil end

    local key   = healed and 'soigne' or 'blesse'
    local place = (co.dialogue and co.dialogue.place) or '*'
    local mission = (D.VictimLines or {})[co.scenarioId]

    if mission then
        for _, blk in ipairs({ mission[place], mission['*'] }) do
            if type(blk) == 'table' then
                local list = blk[key] or blk[healed and 'blesse' or 'soigne']
                if type(list) == 'table' and #list > 0 then
                    return list[math.random(1, #list)]
                end
            end
        end
    end

    local fb = (D.VictimFallback or {})[key]
    if type(fb) == 'table' and #fb > 0 then return fb[math.random(1, #fb)] end
    return nil
end

-- Recueil du témoignage d'une victime.
LSLegacy.Events.Register('police:callouts:victimStatement', function(data)
    local src = source
    local p, co = GetPed(src, data)
    if not p or p.role ~= 'victim' then return end
    if not AgentNear(src, p, 4.0) then return end

    -- Tiré une seule fois puis conservé, comme pour les autres
    if not p.statement then
        p.statement = PickVictimLine(co, p.state == 'healed')
        if not p.statement then return end
    end
    p.interrogated = true

    TriggerClientEvent('police:callouts:ownerStatement', src, {
        label = PedLabel(p), text = p.statement,
    })
    SyncEngaged(co)
end)

LSLegacy.Events.Register('police:callouts:interrogate', function(data)
    local src = source
    local p, co = GetPed(src, data)
    if not p or p.role ~= 'suspect' then return end
    if not AgentNear(src, p, 4.0) then return end

    -- Il faut qu'il soit en état de répondre.
    if p.state ~= 'idle' and p.state ~= 'cuffed' and p.state ~= 'stunned' then
        Notify(src, 'L\'individu n\'est pas en état de répondre.', 'error')
        return
    end
    if p.behavior ~= 'passive' then
        Notify(src, 'L\'individu refuse de répondre.', 'error')
        return
    end

    -- Tirée UNE SEULE FOIS puis conservée : deux auditions du même
    if not p.statement then
        -- Les scénarios peuvent imposer leurs propres réponses ; sinon
        local forced = co.scenario.ownerStatement
        if forced and #forced > 0 then
            p.statement = PickOne(forced)
            p.stance    = 'justifie'
        else
            p.stance    = PickStance(p)
            p.statement = PickSuspectLine(co, p.stance)
        end
        if not p.statement then return end

        co.ownerStatement = p.statement
        co.ownerLabel     = PedLabel(p)
    end
    p.interrogated = true

    TriggerClientEvent('police:callouts:ownerStatement', src, {
        label = PedLabel(p), text = p.statement,
    })
    SyncEngaged(co)
end)

LSLegacy.Events.Register('police:callouts:suspectSearched', function(data)
    local src = source
    local p, co = GetPed(src, data)
    if not p or p.role ~= 'suspect' then return end
    if p.searched then
        Notify(src, 'Cet individu a déjà été fouillé.', 'error')
        return
    end

    -- Un individu maîtrisé se fouille toujours ; un individu coopératif
    local ok = p.state == 'dead'
        or p.state == 'cuffed' or p.state == 'stunned'
        or (p.state == 'idle' and p.behavior == 'passive')
    if not ok then
        Notify(src, 'L\'individu doit être maîtrisé ou coopératif avant la fouille.',
            'error')
        return
    end
    if not AgentNear(src, p, 4.0) then return end

    local seized = {}
    if p.weapon then seized[#seized + 1] = p.weapon end
    for _, it in ipairs(p.items or {}) do seized[#seized + 1] = it end

    -- Ce que l'agent lit à l'écran doit être une désignation, pas un
    local seizedLabels = {}
    for _, it in ipairs(seized) do seizedLabels[#seizedLabels + 1] = WeaponLabel(it) end

    -- Confiscation : les objets ne rejoignent JAMAIS l'inventaire de l'agent
    p.weapon = nil
    p.items  = {}
    p.searched = true

    -- Saisies rattachées à l'individu ET au bilan de l'intervention :
    p.seized = p.seized or {}
    co.seized = co.seized or {}
    for _, s in ipairs(seized) do
        p.seized[#p.seized + 1]   = s
        co.seized[#co.seized + 1] = s
    end

    TriggerClientEvent('police:callouts:searchResult', src, {
        label = PedLabel(p), items = seizedLabels,
    })
    SyncEngaged(co)
end)

LSLegacy.Events.Register('police:callouts:suspectDropWeapon', function(data)
    local src = source
    local co = CalloutOf(src)
    if not co or co.brain ~= src then return end
    local p = co.peds[tonumber(data and data.netId or 0)]
    if not p or not p.weapon then return end

    p.droppedWeapon = p.weapon
    p.weapon = nil
    NotifyEngaged(co, PedLabel(p) .. ' a jeté son arme en fuyant.', 'warning')
    SyncEngaged(co)
end)

LSLegacy.Events.Register('police:callouts:pickupWeapon', function(data)
    local src = source
    local p, co = GetPed(src, data)
    if not p or not p.droppedWeapon then return end

    co.seized = co.seized or {}
    co.seized[#co.seized + 1] = p.droppedWeapon
    p.seized = p.seized or {}
    p.seized[#p.seized + 1] = p.droppedWeapon
    Notify(src, 'Arme récupérée : ' .. WeaponLabel(p.droppedWeapon) ..
        ' (placée sous scellés).', 'success')
    p.droppedWeapon = nil
    SyncEngaged(co)
end)

-- Causes de décès qui ne peuvent JAMAIS constituer une bavure : les
local NonLethalCause = nil
local function IsNonLethalCause(hash)
    if not hash or hash == 0 then return false end
    if not NonLethalCause then
        NonLethalCause = {}
        for name in pairs(C.NonLethal or {}) do
            NonLethalCause[GetHashKey(name)] = true
        end
        NonLethalCause[GetHashKey('WEAPON_FALL')] = true
    end
    return NonLethalCause[hash] == true
end

LSLegacy.Events.Register('police:callouts:suspectDead', function(data)
    local src = source
    local co = CalloutOf(src)
    if not co or co.state ~= 'active' then return end
    if not data or not data.netId then return end
    local p = co.peds[tonumber(data.netId)]
    if not p or p.state == 'dead' then return end

    -- L'état AVANT la mort décide de la légitimité du tir. Il faut le
    local prevState = p.state
    p.state = 'dead'

    if p.role == 'animal' then
        SyncEngaged(co) CheckResolution(co) return
    end

    -- Une victime qui succombe devient une constatation de décès à part
    if p.role == 'victim' then
        p.role  = 'deceased'
        p.label = 'Personne décédée'
        co.extraDeath = true

        -- Tuerie de masse : cette victime comptait dans `aidTotal` au
        if co.scenario.multiDeath and p.requiresAid and prevState ~= 'healed' then
            co.aidTotal = math.max(0, (co.aidTotal or 0) - 1)
            p.requiresAid = nil
        end
        if co.scenario.multiDeath then
            co.deadTotal = (co.deadTotal or 0) + 1
            MaybeFinishMassIncident(co, src)
        end

        NotifyEngaged(co, 'La victime a succombé — constatation de décès à ' ..
            'effectuer.', 'error')
        SyncEngaged(co)
        return
    end

    if p.role ~= 'suspect' then SyncEngaged(co) return end

    p.identified = true  -- on a le corps

    -- État de combat transmis avec le décès : il peut arriver avant le
    if data.combat == true then p.combat = true end

    local killer = tonumber(data.killer or 0)
    -- L'engagement doit être vérifié sur CETTE intervention précisément :
    if not killer or not co.agents[killer] then
        -- Tué par un tiers : ni réussite ni bavure
        co.civilianKills = (co.civilianKills or 0) + 1
        co.extraDeath = true
        NotifyEngaged(co, PedLabel(p) .. ' a été abattu(e) par un tiers.', 'warning')
        SyncEngaged(co)
        MaybeConvertToDeathScene(co)
        CheckResolution(co)
        return
    end

    co.agents[killer].killed = (co.agents[killer].killed or 0) + 1

    -- Un corps reste sur les lieux : il devra être constaté et évacué,
    co.extraDeath = true

    -- Auteur du tir, conservé pour la fiche d'intervention : avec
    p.killedBy = co.agents[killer].name or 'Agent'

    -- MOYEN NON LÉTAL : hors du champ de la bavure.
    if IsNonLethalCause(tonumber(data.cause or 0)) then
        p.killReason = 'décès consécutif à un moyen non létal'
        NotifyEngaged(co, PedLabel(p) .. ' est décédé(e) des suites de sa ' ..
            'mise à terre. Aucun usage de l\'arme létale.', 'warning')
        SyncEngaged(co)
        MaybeConvertToDeathScene(co)
        CheckResolution(co)
        return
    end

    -- Usage de l'arme létale : légitime UNIQUEMENT si l'individu était
    local legitimate = (p.weapon ~= nil)
        and (prevState ~= 'cuffed')
        and (p.combat == true)

    if not legitimate then
        local reason = 'suspect non menaçant'
        if prevState == 'cuffed' then reason = 'suspect menotté'
        elseif prevState == 'stunned' then reason = 'suspect au sol'
        elseif p.surrendered then reason = 'suspect qui se rendait'
        elseif p.behavior == 'flee' then reason = 'suspect en fuite'
        elseif not p.weapon then reason = 'suspect désarmé'
        elseif p.behavior == 'passive' then reason = 'suspect passif' end
        p.killReason = reason

        co.agents[killer].misconduct = (co.agents[killer].misconduct or 0) + 1
        co.misconducts = (co.misconducts or 0) + 1

        Notify(killer, 'Bavure constatée : ' .. reason .. '. Rapport IGPN transmis.', 'error')
        NotifyEngaged(co, 'Usage de l\'arme létale hors cadre — l\'intervention est entachée.', 'error')

        local engaged = {}
        for _, a in pairs(co.agents) do engaged[#engaged + 1] = a.name end
        LogDiscord('IGPN — Usage de l\'arme létale',
            '**Intervention :** ' .. co.scenario.label .. '\n' ..
            '**Lieu :** ' .. (co.street or co.location.loc.label) .. '\n' ..
            '**Agent responsable :** ' .. (co.agents[killer].name or '?') .. '\n' ..
            '**Individu :** ' .. PedLabel(p) .. '\n' ..
            '**Motif :** ' .. reason .. '\n' ..
            '**Agents engagés :** ' .. table.concat(engaged, ', '),
            15158332)
    end

    SyncEngaged(co)
    CheckResolution(co)
end)

LSLegacy.Events.Register('police:callouts:suspectCombat', function(data)
    local src = source
    local co = CalloutOf(src)
    if not co or co.brain ~= src then return end
    local p = co.peds[tonumber(data and data.netId or 0)]
    if not p then return end
    p.combat = (data.combat == true)
end)

LSLegacy.Events.Register('police:callouts:suspectSurrender', function(data)
    local src = source
    local co = CalloutOf(src)
    if not co or co.brain ~= src then return end
    local p = co.peds[tonumber(data and data.netId or 0)]
    if not p or p.role ~= 'suspect' then return end

    p.behavior   = 'passive'
    p.combat     = false
    p.state      = 'idle'
    p.surrendered = true
    -- Bulle désactivée par défaut : la formule « à bout de souffle » ne
    if C.SurrenderNotice then
        NotifyEngaged(co, PedLabel(p) .. ' se rend.', 'info')
    end
    SyncEngaged(co)
end)

LSLegacy.Events.Register('police:callouts:suspectEscaped', function(data)
    local src = source
    local co = CalloutOf(src)
    if not co or co.brain ~= src then return end
    local p = co.peds[tonumber(data and data.netId or 0)]
    if not p or p.role ~= 'suspect' then return end
    if p.state == 'delivered' or p.state == 'dead' or p.state == 'escaped' then return end

    p.state = 'escaped'
    p.identified = false          -- un fuyard n'est jamais identifié
    p.identity = nil
    if p.entity and DoesEntityExist(p.entity) then DeleteEntity(p.entity) end

    NotifyEngaged(co, 'Un individu a pris la fuite.', 'error')
    SyncEngaged(co)
    CheckResolution(co)
end)

LSLegacy.Events.Register('police:callouts:suspectDelivered', function(data)
    local src = source
    local p, co = GetPed(src, data)
    if not p then return end
    if p.state ~= 'cuffed' and not (p.role == 'wanderer') then
        Notify(src, 'L\'individu doit être menotté.', 'error')
        return
    end

    -- Contrôle de distance au bon PNJ d'accueil
    local npc = (p.role == 'wanderer') and C.Npcs.hospital or C.Npcs.custody
    if not p.entity or not DoesEntityExist(p.entity) then return end
    local pc = GetEntityCoords(p.entity)
    if not LSLegacy.Validate.Distance(pc, npc.coords, C.CustodyRadius) then
        Notify(src, 'Vous devez présenter l\'individu sur place.', 'error')
        return
    end
    if not LSLegacy.Validate.Distance(GetEntityCoords(GetPlayerPed(src)), npc.coords, C.CustodyRadius + 5.0) then return end

    -- Contrôle d'armement à l'arrivée
    if p.role == 'suspect' and (p.weapon ~= nil) then
        co.armedDeliveries = (co.armedDeliveries or 0) + 1
        NotifyEngaged(co, 'Un individu a été présenté au poste encore armé — prime réduite.', 'error')
    end

    p.state = 'delivered'
    co.agents[src].delivered = (co.agents[src].delivered or 0) + 1

    if p.role == 'wanderer' then
        -- Elle entre dans l'hôpital avant d'être retirée : la faire
        local ent = p.entity
        SetTimeout(C.CleanupDelay * 1000, function()
            if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
        end)
    elseif p.entity and DoesEntityExist(p.entity) then
        DeleteEntity(p.entity)
    end

    if p.role == 'wanderer' then
        co.objectiveDone = true
        Notify(src, PedLabel(p) .. ' a été confié(e) à l\'hôpital.', 'success')
        -- La personne n'est pas escamotée : elle entre dans
        for asrc in pairs(co.agents) do
            TriggerClientEvent('police:callouts:hospitalIntake', asrc, {
                netId = tonumber(data.netId),
            })
        end
    else
        Notify(src, PedLabel(p) .. ' a été présenté(e) au poste.', 'success')
    end

    SyncEngaged(co)
    CheckResolution(co)
end)

-- Levée de corps. Le constat de décès clôt l'intervention dans la
local function RemoveBodies(co)
    if not co then return end
    local delay = (C.BodyBagDuration or 6000) + 1000
    local n = 0

    for _, p in pairs(co.peds) do
        -- Tout corps présent sur les lieux, quel qu'ait été son rôle.
        if p.entity and (p.role == 'deceased' or p.state == 'dead') then
            local e = p.entity
            p.entity = nil       -- plus rien d'autre ne manipulera le corps
            -- L'état « dead » d'un individu abattu est CONSERVÉ : il
            if p.role == 'deceased' then p.state = 'removed' end
            n = n + 1
            SetTimeout(delay, function()
                if DoesEntityExist(e) then DeleteEntity(e) end
            end)
        end
    end

    if n > 0 then SyncEngaged(co) end
end

-- Évacuation de la dépouille de l'animal, une fois sa mort constatée.
local function RemoveAnimals(co)
    if not co then return end
    local delay = (C.BodyBagDuration or 6000) + 1000
    local n = 0

    for _, p in pairs(co.peds) do
        if p.role == 'animal' and p.entity then
            local e = p.entity
            p.entity = nil
            p.state  = 'removed'
            n = n + 1
            SetTimeout(delay, function()
                if DoesEntityExist(e) then DeleteEntity(e) end
            end)
        end
    end

    if n > 0 then SyncEngaged(co) end
end

--  LEVÉE DE CORPS PAR LES SECOURS

local Ambulances = {}   -- { [id] = { entities = {...}, corpses = {...} } }
local AmbulanceSeq = 0

-- Suppression du convoi et des corps encore présents.
local function ClearAmbulance(id)
    local amb = Ambulances[id]
    if not amb then return end
    Ambulances[id] = nil

    for _, e in ipairs(amb.corpses or {}) do
        if DoesEntityExist(e) then DeleteEntity(e) end
    end
    for _, e in ipairs(amb.entities or {}) do
        if DoesEntityExist(e) then DeleteEntity(e) end
    end
end

-- Retire les corps pris en charge par les brancardiers.
LSLegacy.Events.Register('police:callouts:ambulanceLoaded', function(data)
    local id = data and tonumber(data.id)
    local amb = id and Ambulances[id]
    if not amb or amb.loaded then return end
    amb.loaded = true

    for _, e in ipairs(amb.corpses or {}) do
        if DoesEntityExist(e) then DeleteEntity(e) end
    end
    amb.corpses = {}
end)

-- Dépêche une ambulance sur la scène. Retourne false si elle n'a pas pu
local function AmbLog(src, fmt, ...)
    local msg = select('#', ...) > 0 and fmt:format(...) or fmt
    print('^3[ambulance]^7 ' .. msg)
    if src and src ~= 0 then
        TriggerClientEvent('police:callouts:ambulanceDebug', src, msg)
    end
end

local function DispatchAmbulance(co, src)
    local A = C.Ambulance or {}
    if not A.Enabled then
        AmbLog(src, 'Désactivée (C.Ambulance.Enabled = %s) — levée de corps directe.',
            tostring(A.Enabled))
        return false
    end

    -- Corps à prendre en charge. On ne les DÉTACHE PAS encore du
    local corpses, netIds, entries = {}, {}, {}
    for _, p in pairs(co.peds) do
        if p.entity and DoesEntityExist(p.entity)
           and (p.role == 'deceased' or p.state == 'dead') then
            corpses[#corpses + 1] = p.entity
            local okId, cid = pcall(NetworkGetNetworkIdFromEntity, p.entity)
            netIds[#netIds + 1]   = (okId and cid) or 0
            entries[#entries + 1] = p
        end
    end
    if #corpses == 0 then
        -- Diagnostic : sans corps rattaché, il n'y a rien à venir
        local seen = {}
        for _, p in pairs(co.peds) do
            seen[#seen + 1] = ('%s(entité=%s)')
                :format(tostring(p.role),
                    p.entity and tostring(DoesEntityExist(p.entity)) or 'nil')
        end
        AmbLog(src, 'Aucun corps à prendre en charge — PNJ présents : %s',
            (#seen > 0 and table.concat(seen, ', ') or 'aucun'))
        return false
    end
    AmbLog(src, '%d corps identifié(s), création du convoi…', #corpses)

    local base = co.location.loc.coords
    local ang  = math.random() * math.pi * 2
    local dist = A.SpawnDist or 110.0
    local sx   = base.x + math.cos(ang) * dist
    local sy   = base.y + math.sin(ang) * dist

    -- Création pas à pas. Chaque entité est vérifiée AVANT qu'on lui
    local function NetIdOf(entity)
        if not entity or entity == 0 then return nil end
        if not DoesEntityExist(entity) then return nil end
        local okN, id = pcall(NetworkGetNetworkIdFromEntity, entity)
        if okN and id and id ~= 0 then return id end
        return nil
    end

    local function Settle(entity)
        for _ = 1, 20 do
            if entity and entity ~= 0 and DoesEntityExist(entity) then
                local id = NetIdOf(entity)
                if id then return id end
            end
            Wait(50)
        end
        return nil
    end

    -- Appelée DIRECTEMENT, sans pcall : elle contient des Wait, et
    local function Build()
        local veh = CreateVehicle(GetHashKey(A.Model or 'ambulance'),
            sx, sy, base.z + 1.0, math.deg(ang) + 180.0, true, true)
        local vehNet = Settle(veh)
        if not vehNet then
            AmbLog(src, 'Véhicule « %s » non enregistré sur le réseau.',
                tostring(A.Model))
            if veh and veh ~= 0 and DoesEntityExist(veh) then DeleteEntity(veh) end
            return nil
        end
        pcall(SetEntityDistanceCullingRadius, veh, 500.0)

        local entities, crew = { veh }, {}
        local models = A.Peds or { 's_m_m_paramedic_01' }
        for i = 1, math.max(1, A.Crew or 2) do
            local model = models[((i - 1) % #models) + 1]
            local ped = CreatePed(4, GetHashKey(model),
                sx + (i * 1.5), sy, base.z + 1.0, 0.0, true, true)
            local netId = Settle(ped)
            if netId then
                pcall(SetEntityDistanceCullingRadius, ped, 500.0)
                entities[#entities + 1] = ped
                crew[#crew + 1] = netId
            else
                AmbLog(src, 'Brancardier « %s » non enregistré — ignoré.',
                    tostring(model))
                if ped and ped ~= 0 and DoesEntityExist(ped) then DeleteEntity(ped) end
            end
        end

        if #crew == 0 then
            AmbLog(src, 'Aucun brancardier valide — modèles essayés : %s',
                table.concat(models, ', '))
            for _, e in ipairs(entities) do
                if DoesEntityExist(e) then DeleteEntity(e) end
            end
            return nil
        end

        AmbulanceSeq = AmbulanceSeq + 1
        local id = AmbulanceSeq
        Ambulances[id] = { entities = entities, corpses = corpses }
        SetTimeout(((A.Cleanup or 45) + 60) * 1000, function() ClearAmbulance(id) end)

        return {
            id = id, vehNet = vehNet, crew = crew, corpses = netIds,
            target = { x = base.x, y = base.y, z = base.z },
        }
    end

    local payload = Build()

    if not payload then
        -- Le motif précis a déjà été journalisé par Build().
        AmbLog(src, 'Convoi non constitué — levée de corps directe.')
        return false
    end

    -- Convoi en place : les corps passent sous la responsabilité de
    for _, p in ipairs(entries) do
        p.entity = nil
        if p.role == 'deceased' then p.state = 'removed' end
    end
    AmbLog(src, 'Convoi #%d prêt — %d corps, %d brancardier(s).',
        payload.id, #corpses, #payload.crew)

    -- Le meneur est l'agent qui a constaté : la scène est chargée chez
    local sent = 0
    for agent in pairs(co.agents) do
        sent = sent + 1
        TriggerClientEvent('police:callouts:ambulance', agent, {
            id = payload.id, vehNet = payload.vehNet, crew = payload.crew,
            corpses = payload.corpses, target = payload.target,
            driver = (agent == src),
        })
    end
    AmbLog(src, 'Convoi annoncé à %d agent(s), meneur = %s.', sent, tostring(src))
    return true
end

-- Tuerie de masse : clôture dès que corps constatés ET premiers soins
MaybeFinishMassIncident = function(co, src)
    local bodiesDone = (co.deadConstated or 0) >= (co.deadTotal or 0)
    local aidDone     = (co.aidGiven or 0) >= (co.aidTotal or 0)
    if bodiesDone and aidDone and not co.objectiveDone then
        co.objectiveDone = true
        if DispatchAmbulance(co, src) then
            NotifyEngaged(co, 'Tous les corps sont constatés — une ambulance ' ..
                'est en route pour la levée.', 'info')
        else
            RemoveBodies(co)
        end
    end
end

LSLegacy.Events.Register('police:callouts:objectiveDone', function(data)
    local src = source
    local co = CalloutOf(src)
    if not co or co.state ~= 'active' then return end
    if co.objectiveDone then return end

    local kind = data and data.kind or nil
    local obj  = co.scenario.objective

    -- DIAGNOSTIC : dit à l'agent quelle branche est empruntée. Sans ça,
    if (C.Ambulance or {}).Debug then
        TriggerClientEvent('police:callouts:ambulanceDebug', src,
            ('objectiveDone reçu — objectif=%s, kind=%s, fausse alerte=%s')
                :format(tostring(obj), tostring(kind), tostring(co.falseAlarm)))
    end

    -- Dès qu'un agent a recueilli le témoignage, le signalement reste
    if kind == 'statement' and not co.statementTaken then
        co.statementTaken = true
        SyncEngaged(co)
    end

    -- Tuerie de masse (ou toute mission à témoins nommés) : chaque
    if kind == 'statement' then
        local netId = tonumber(data and data.netId)
        local wp = netId and co.peds[netId]
        if wp and wp.witness and not wp.heard then
            wp.heard = true
            SyncEngaged(co)
        end
    end

    -- Décès survenu EN PLUS de l'objectif de la mission : on le constate,
    if kind == 'death' and co.extraDeath and not co.deathConstated
       and co.scenario.objective ~= 'death' then
        co.deathConstated = true
        Notify(src, 'Décès de la victime constaté.', 'success')
        if DispatchAmbulance(co, src) then
            NotifyEngaged(co, 'Une ambulance est en route pour la levée de corps.',
                'info')
        else
            RemoveBodies(co)
        end
        SyncEngaged(co)
        CheckResolution(co)
        return
    end

    -- Une fausse alerte se clôt en interrogeant le requérant, quel que
    if co.falseAlarm then
        if kind ~= 'statement' then return end
        co.objectiveDone = true
        Notify(src, 'Fausse alerte confirmée. Retour en patrouille.', 'info')

    -- Sinon, seule l'interaction ATTENDUE par le scénario le clôt.
    elseif obj == 'statement' and kind == 'statement' then
        co.objectiveDone = true
        Notify(src, 'Déposition prise, constatations effectuées.', 'success')

    elseif obj == 'death' and kind == 'death' and co.scenario.multiDeath then
        -- Tuerie de masse : CHAQUE corps se constate à part. L'ambulance
        local netId = tonumber(data and data.netId)
        local p = netId and co.peds[netId]
        if not p or p.role ~= 'deceased' or p.constated then
            return  -- corps déjà constaté ou requête invalide : ignoré
        end
        p.constated = true
        co.deadConstated = (co.deadConstated or 0) + 1
        Notify(src, ('Décès constaté (%d/%d).')
            :format(co.deadConstated, co.deadTotal or co.deadConstated), 'success')
        SyncEngaged(co)

        if co.deadConstated >= (co.deadTotal or 0)
           and (co.aidGiven or 0) < (co.aidTotal or 0) then
            NotifyEngaged(co, 'Tous les corps sont constatés — il reste des blessés ' ..
                'à prendre en charge.', 'warning')
        end
        MaybeFinishMassIncident(co, src)
        CheckResolution(co)
        return

    elseif obj == 'death' and kind == 'death' then
        co.objectiveDone = true
        Notify(src, 'Décès constaté.', 'success')

        -- Les secours viennent chercher le corps. En cas d'échec de
        if DispatchAmbulance(co, src) then
            NotifyEngaged(co, 'Une ambulance est en route pour la levée de corps.',
                'info')
        else
            RemoveBodies(co)
        end

    elseif obj == 'radio' and kind == 'radio' then
        co.objectiveDone = true
        co.radioOff      = true
        Notify(src, 'La nuisance sonore a cessé.', 'success')

    elseif obj == 'animal' and kind == 'animal' then
        -- Un chien ne s'interpelle pas : l'intervention se clôt sur la
        co.objectiveDone = true
        Notify(src, 'Mort de l\'animal constatée.', 'success')
        RemoveAnimals(co)

    else
        -- Simple prise de témoignage : aucune incidence sur la résolution
        return
    end

    SyncEngaged(co)
    CheckResolution(co)
end)

LSLegacy.Events.Register('police:callouts:firstAid', function(data)
    local src = source
    local p, co = GetPed(src, data)
    if not p or p.role ~= 'victim' or p.state == 'healed' then return end
    if not AgentNear(src, p, 4.0) then return end

    p.state = 'healed'
    co.victimHealed = true
    Notify(src, 'Premiers soins prodigués à ' .. PedLabel(p) .. '.', 'success')

    -- Tuerie de masse : les premiers soins sont une condition de
    if p.requiresAid then
        co.aidGiven = (co.aidGiven or 0) + 1
        if co.scenario.multiDeath then
            MaybeFinishMassIncident(co, src)
        end
    end

    SyncEngaged(co)
    CheckResolution(co)
end)

-- Tapage : on demande à un fêtard de couper la musique. Il s'exécute,
LSLegacy.Events.Register('police:callouts:askRadioOff', function(data)
    local src = source
    local p, co = GetPed(src, data)
    if not p or p.role ~= 'suspect' then return end
    if co.scenario.objective ~= 'radio' then return end
    if co.radioAsked then
        Notify(src, 'La demande a déjà été faite.', 'error')
        return
    end
    if not AgentNear(src, p, 5.0) then return end

    co.radioAsked = true
    NotifyEngaged(co, PedLabel(p) .. ' accepte de couper la musique.', 'info')

    for asrc in pairs(co.agents) do
        TriggerClientEvent('police:callouts:radioWalk', asrc, { netId = tonumber(data.netId) })
    end
end)

LSLegacy.Events.Register('police:callouts:radioOff', function()
    local src = source
    local co = CalloutOf(src)
    if not co or co.state ~= 'active' then return end
    if co.scenario.objective ~= 'radio' then return end

    co.objectiveDone = true
    co.radioOff      = true
    NotifyEngaged(co, 'La sono a été coupée.', 'success')
    SyncEngaged(co)
    CheckResolution(co)
end)

LSLegacy.Events.Register('police:callouts:dismissBystander', function(data)
    local src = source
    local p, co = GetPed(src, data)
    if not p or p.role ~= 'bystander' then return end
    p.state = 'leaving'
    SyncEngaged(co)
end)

-- Le client rapporte l'heure in-game (le serveur n'a pas d'horloge)
LSLegacy.Events.Register('police:callouts:reportHour', function(hour)
    local h = tonumber(hour)
    if h and h >= 0 and h <= 23 then CurrentHour = math.floor(h) end
end)

--  COMMANDES

-- Contrôle admin — le framework ne se base PAS sur les ACE FiveM mais sur
local ADMIN_MIN_LEVEL = 3

local function GetStaffLevel(src)
    return LSLegacy.Permissions.GetLevel(GetPlayer(src))
end

local function IsAdmin(src)
    if src == 0 then return true end   -- console
    return LSLegacy.Permissions.Has(GetPlayer(src), ADMIN_MIN_LEVEL)
end

-- Refus explicite : une commande qui ne répond rien est indébogable.
local function DenyAdmin(src)
    if src == 0 then return end
    Notify(src, 'Commande réservée à l\'administration (niveau ' ..
        (Config.StaffGroups and Config.StaffGroups[ADMIN_MIN_LEVEL] or 'admin') ..
        ' minimum). Votre niveau : ' ..
        (Config.StaffGroups and Config.StaffGroups[GetStaffLevel(src)] or '?') .. '.', 'error')
end

-- Suggestions de chat : elles servent aussi de vérification visuelle que
local function Suggest(cmd, help, args)
    TriggerClientEvent('chat:addSuggestion', -1, '/' .. cmd, help, args or {})
end

AddEventHandler('playerJoining', function()
    local src = source
    Wait(3000)
    TriggerClientEvent('chat:addSuggestion', src, '/missionpnj',
        'Rejoindre ou quitter Police Secours (missions PNJ)')
    TriggerClientEvent('chat:addSuggestion', src, '/statut',
        'Statut radio et renforts sur l\'intervention en cours')
end)

Suggest('missionpnj', 'Rejoindre ou quitter Police Secours (missions PNJ)')
Suggest('missionpnjadmin', 'Mode test des missions PNJ (admin)',
    { { name = 'effectif', help = 'Effectif simulé (défaut 8)' } })
Suggest('callout', 'Forcer / inspecter / clôturer un appel (admin)',
    { { name = 'action', help = '<scenario_id> | status | end' } })
Suggest('callouts', 'Activer ou désactiver les missions PNJ (admin)',
    { { name = 'etat', help = 'on | off' } })

-- Relais depuis la console client (F8)
local RunCommand   -- forward declaration, défini après les commandes

-- Le client demande s'il a le droit d'utiliser les commandes admin, pour
LSLegacy.Events.Register('police:callouts:askAdmin', function()
    local src = source
    TriggerClientEvent('police:callouts:adminState', src, IsAdmin(src))
end)

LSLegacy.Events.Register('police:callouts:command', function(data)
    local src = source
    if not data or type(data.cmd) ~= 'string' then return end
    local args = {}
    if type(data.args) == 'table' then
        for i, v in ipairs(data.args) do args[i] = tostring(v) end
    end
    RunCommand(src, data.cmd, args)
end)

RegisterCommand('missionpnj', function(source)
    if source == 0 then
        print('[callouts] /missionpnj ne peut pas être utilisée depuis la console.')
        return
    end
    DoRegister(source)
end, false)

RegisterCommand('missionPNJ', function(source)
    if source == 0 then return end
    DoRegister(source)
end, false)

-- Active ou désactive le mode test (effectif simulé).
local function SetTestMode(src, enable, staff)
    if enable then
        staff = tonumber(staff) or C.TestModeDefaultStaff
        if staff < 1 then staff = C.TestModeDefaultStaff end

        TestMode.active = true
        TestMode.staff  = staff
        TestMode.admin  = src
        -- Inscription directe dans le premier équipage : le mode test ne
        if not Registered[src] then
            DoRegister(src, C.Crews[1] and C.Crews[1].id or 'alpha')
        end

        Notify(src, 'Mode test actif — effectif simulé : ' .. staff .. ' agents. ' ..
            (C.TestModeStopsScheduler
                and 'Aucun appel automatique : lancez les missions depuis le menu.'
                or ''), 'success')
        print(('^3[callouts]^7 Mode test ACTIF — effectif simulé : %d (par %s).')
            :format(staff, GetName(src)))
        LogDiscord('Missions PNJ — mode test',
            'Activé par ' .. GetName(src) .. ' — effectif simulé : ' .. staff, 15105570)

        CreateThread(function()
            while TestMode.active and TestMode.admin == src do
                Wait(180000)
                if TestMode.active and TestMode.admin == src then
                    Notify(src, 'Rappel : le mode test des missions PNJ est toujours actif.',
                        'warning')
                end
            end
        end)
    else
        TestMode.active = false
        TestMode.admin  = nil
        print('^2[callouts]^7 Mode test désactivé par ' .. GetName(src) .. '.')
        LogDiscord('Missions PNJ — mode test', 'Désactivé par ' .. GetName(src), 15105570)
        Notify(src, 'Mode test désactivé — les appels automatiques reprennent.', 'info')
    end
end

-- Envoie au client de quoi construire le menu d'administration.
local function SendAdminMenu(src)
    local list = {}
    for id, sc in pairs(Config.Police.Scenarios) do
        list[#list + 1] = {
            id        = id,
            label     = sc.label,
            minAgents = sc.minAgents or 1,
            hours     = sc.hours,
            weight    = sc.weight or 1,
            objective = sc.objective,
        }
    end
    table.sort(list, function(a, b)
        if a.minAgents ~= b.minAgents then return a.minAgents < b.minAgents end
        return a.label < b.label
    end)

    TriggerClientEvent('police:callouts:adminMenuData', src, {
        scenarios = list,
        enabled   = C.Enabled,
        testMode  = TestMode.active,
        testStaff = TestMode.staff,
        actives   = (function()
            local list = {}
            for _, co in pairs(Callouts) do
                list[#list + 1] = {
                    id    = co.id,
                    label = co.scenario.label,
                    zone  = co.street or co.location.loc.label,
                    state = co.state,
                    crew  = co.crew,
                }
            end
            table.sort(list, function(a, b) return a.id < b.id end)
            return list
        end)(),
        maxActive = math.max(1, math.min(StaffedCrews(), #C.Crews)),
        crews     = StaffedCrews(),
    })
end

local function CmdMissionPnjAdmin(source, args)
    if source == 0 then
        print('[callouts] /missionpnjadmin est une commande en jeu.')
        return
    end
    local src = source
    if not IsAdmin(src) then DenyAdmin(src) return end
    if not IsLawEnforcementOnDuty(src) then
        Notify(src, 'Attribuez-vous le job police ou gendarmerie et prenez votre service via le menu admin ' ..
            'avant d\'utiliser les outils de test.', 'error')
        return
    end

    -- Un argument numérique conserve l'ancien comportement direct
    local n = tonumber(args and args[1] or nil)
    if n then SetTestMode(src, true, n) return end

    SendAdminMenu(src)
end

local function CmdCallouts(source, args)
    local src = source
    if not IsAdmin(src) then DenyAdmin(src) return end
    local arg = (args and args[1] or ''):lower()

    if arg == 'on' then
        C.Enabled = true
        if src ~= 0 then Notify(src, 'Missions PNJ activées.', 'success') else print('[callouts] activées') end
        -- Bascule d'administration : elle ne concerne que celui qui la
        print('^2[callouts]^7 Missions PNJ activées.')
    elseif arg == 'off' then
        C.Enabled = false
        if src ~= 0 then Notify(src, 'Missions PNJ désactivées (l\'appel en cours se termine normalement).', 'warning')
        else print('[callouts] désactivées') end
        print('^3[callouts]^7 Missions PNJ suspendues.')
    else
        local msg = 'Missions PNJ : ' .. (C.Enabled and 'ACTIVES' or 'DÉSACTIVÉES') ..
            ' — usage : /callouts on|off'
        if src ~= 0 then Notify(src, msg, 'info') else print(msg) end
    end
end

local function CmdCallout(source, args)
    local src = source
    if not IsAdmin(src) then DenyAdmin(src) return end

    local sub = (args and args[1] or ''):lower()

    local function out(msg)
        if src ~= 0 then Notify(src, msg, 'info') else print(msg) end
    end

    if sub == '' then
        local lines = {}
        for id, sc in pairs(Config.Police.Scenarios) do
            local h = sc.hours and (sc.hours.from .. 'h-' .. sc.hours.to .. 'h') or '24h/24'
            lines[#lines + 1] = id .. ' (palier ' .. (sc.minAgents or 1) .. ', ' .. h .. ')'
        end
        table.sort(lines)
        out('Scénarios : ' .. table.concat(lines, ' | '))
        out('Usage : /callout <id> | /callout status | /callout end')
        return
    end

    if sub == 'status' then
        if ActiveCount() == 0 then out('Aucun appel en cours.') return end
        out(('%d intervention(s) en cours · %d équipage(s) occupé(s) · plafond %d'):format(
            ActiveCount(), StaffedCrews(), math.max(1, math.min(StaffedCrews(), #C.Crews))))
        for _, co in pairs(Callouts) do
        out(('Appel #%d — %s (%s) — état : %s — équipage : %s'):format(
            co.id, co.scenario.label, co.location.loc.label, co.state,
            tostring(co.crew or 'aucun')))
        for a, info in pairs(co.agents) do
            out((' • agent %s [%s] — menottés %d, livrés %d, abattus %d, bavures %d'):format(
                info.name, info.status or '?', info.cuffed or 0, info.delivered or 0,
                info.killed or 0, info.misconduct or 0))
        end
        for netId, p in pairs(co.peds) do
            local d = '?'
            if p.entity and DoesEntityExist(p.entity) then
                local best = 99999.0
                for asrc in pairs(co.agents) do
                    local dd = #(GetEntityCoords(GetPlayerPed(asrc)) - GetEntityCoords(p.entity))
                    if dd < best then best = dd end
                end
                d = string.format('%.0fm', best)
            end
            out((' • #%s %s [%s] %s%s — %s'):format(
                netId, PedLabel(p), p.role, p.state, p.weapon and (' armé:' .. p.weapon) or '', d))
        end
        end
        return
    end

    if sub == 'end' then
        if ActiveCount() == 0 then out('Aucun appel en cours.') return end
        local ids = {}
        for id in pairs(Callouts) do ids[#ids + 1] = id end
        for _, id in ipairs(ids) do
            if Callouts[id] then
                out('Clôture forcée de l\'appel #' .. id)
                EndCallout(Callouts[id], 'failed')
            end
        end
        return
    end

    -- Forçage d'un scénario : contourne horaires, paliers et interrupteur
    if not Config.Police.Scenarios[sub] then
        out('Scénario inconnu : ' .. sub)
        return
    end
    local maxActive = math.max(1, math.min(StaffedCrews(), #C.Crews))
    if ActiveCount() >= maxActive then
        out(('Plafond atteint : %d intervention(s) pour %d équipage(s) occupé(s).')
            :format(ActiveCount(), StaffedCrews()))
        return
    end
    local ok, err = CreateCallout(sub, true)
    out(ok and ('Appel forcé : ' .. sub) or ('Échec : ' .. tostring(err)))
end


--  REGISTRE DES PLACEMENTS RATÉS

local SpawnFails = {}   -- { [clé] = { scenario, zone, reason, count, x, y, z, manual } }

-- Le registre SURVIT aux redémarrages : les signalements s'accumulent
local SPAWN_FAILS_FILE = 'module/police/spawnfails.json'
local spawnFailsDirty  = false

local function SpawnFailKey(scenarioId, zone, reason)
    return (scenarioId or '?') .. '|' .. (zone or '?') .. '|' .. (reason or '?')
end

local function SaveSpawnFails()
    local ok, encoded = pcall(json.encode, SpawnFails)
    if not ok then
        print('^1[spawn]^7 Registre non sérialisable : ' .. tostring(encoded))
        return
    end
    SaveResourceFile(GetCurrentResourceName(), SPAWN_FAILS_FILE, encoded, -1)
end

local function LoadSpawnFails()
    local raw = LoadResourceFile(GetCurrentResourceName(), SPAWN_FAILS_FILE)
    if not raw or raw == '' then return end
    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        print('^3[spawn]^7 Registre illisible — reparti à vide.')
        return
    end
    SpawnFails = decoded

    local n = 0
    for _ in pairs(SpawnFails) do n = n + 1 end
    if n > 0 then
        print(('^2[spawn]^7 Registre des placements ratés rechargé : %d emplacement(s). ' ..
            'Consultable avec /spawnstats.'):format(n))
    end
end

-- Écriture différée : un signalement peut en déclencher plusieurs
CreateThread(function()
    LoadSpawnFails()
    while true do
        Wait(5000)
        if spawnFailsDirty then
            spawnFailsDirty = false
            SaveSpawnFails()
        end
    end
end)

-- Sauvegarde immédiate à l'arrêt : sans elle, les signalements des cinq
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and spawnFailsDirty then
        SaveSpawnFails()
    end
end)

-- Un motif commençant par « repli » décrit un placement RÉUSSI, obtenu
local function IsDegraded(reason)
    return tostring(reason):match('^repli') ~= nil
        or tostring(reason):match('^rayon élargi') ~= nil
end

local function RecordSpawnFail(scenarioId, zone, reason, x, y, z, manual, role)
    local key = SpawnFailKey(scenarioId, zone, reason)
    local e = SpawnFails[key]
    local now = os.date('%Y-%m-%d %H:%M')
    if e then
        e.count = e.count + 1
        e.x, e.y, e.z = x or e.x, y or e.y, z or e.z
        e.role = role or e.role
        e.last = now
    else
        e = { scenario = scenarioId, zone = zone, reason = reason,
              count = 1, x = x, y = y, z = z, manual = manual, role = role,
              first = now, last = now }
        SpawnFails[key] = e
    end
    spawnFailsDirty = true

    print(('^3[spawn]^7 %s | %s | %s | %s | (%.1f, %.1f, %.1f) | %d occurrence(s)')
        :format(manual and 'SIGNALÉ' or 'auto', tostring(scenarioId),
            tostring(zone), tostring(reason), x or 0, y or 0, z or 0, e.count))
end

-- Client → serveur : le validateur n'a pas trouvé de position correcte.
LSLegacy.Events.Register('police:callouts:spawnFail', function(data)
    local src = source
    local co = CalloutOf(src)
    if not co or not data then return end
    RecordSpawnFail(co.scenarioId, co.location.loc.label,
        tostring(data.reason or 'inconnu'),
        tonumber(data.x), tonumber(data.y), tonumber(data.z),
        false, tostring(data.role or '?'))
end)

-- Signalement manuel par un agent : le PNJ le plus proche est enregistré
LSLegacy.Events.Register('police:callouts:reportSpawn', function()
    local src = source
    local co = CalloutOf(src)
    if not co then
        Notify(src, 'Vous n\'êtes engagé sur aucune intervention.', 'error')
        return
    end

    local a = GetEntityCoords(GetPlayerPed(src))
    local best, bestD, bestRole = nil, 9999.0, nil
    for _, p in pairs(co.peds) do
        if p.entity and DoesEntityExist(p.entity) then
            local b = GetEntityCoords(p.entity)
            local d = #(a - b)
            if d < bestD then best, bestD, bestRole = b, d, p.role end
        end
    end

    if not best then
        Notify(src, 'Aucun PNJ de mission à proximité.', 'error')
        return
    end

    RecordSpawnFail(co.scenarioId, co.location.loc.label,
        'signalé par un agent', best.x, best.y, best.z, true, bestRole)
    Notify(src, ('PNJ signalé (%s, à %.1f m). Lieu : %s.')
        :format(bestRole or '?', bestD, co.location.loc.label or '?'), 'success')

    -- Accusé de réception détaillé dans la console de l'agent : c'est là
    TriggerClientEvent('police:callouts:spawnReported', src, {
        scenario = co.scenarioId,
        zone     = co.location.loc.label,
        role     = bestRole,
        dist     = bestD,
        x = best.x, y = best.y, z = best.z,
    })
end)

-- Signalement d'une intervention ENTIÈRE. Complémentaire de
LSLegacy.Events.Register('police:callouts:reportLocation', function()
    local src = source
    local co = CalloutOf(src)
    if not co then
        Notify(src, 'Vous n\'êtes engagé sur aucune intervention.', 'error')
        return
    end

    local loc  = co.location.loc
    local v    = loc.coords
    local cat  = tostring(co.location.key or ''):match('^(.-):') or '?'
    local idx  = co.location.index or 0

    -- État de chaque PNJ, pour que le rapport se suffise à lui-même.
    local peds, agent = {}, GetEntityCoords(GetPlayerPed(src))
    for netId, p in pairs(co.peds) do
        local e = { netId = netId, role = p.role, state = p.state }
        if p.entity and DoesEntityExist(p.entity) then
            local c = GetEntityCoords(p.entity)
            e.exists = true
            e.x, e.y, e.z = c.x, c.y, c.z
            e.dz   = c.z - v.z
            e.dist = #(c - agent)
        else
            e.exists = false
        end
        peds[#peds + 1] = e
    end

    local line = ("        { coords = vector4(%.2f, %.2f, %.2f, %.1f), label = '%s', zone = '%s' },")
        :format(v.x, v.y, v.z, v.w or 0.0, tostring(loc.label or '?'),
            tostring(loc.zone or 'downtown'))

    RecordSpawnFail(co.scenarioId, loc.label, 'LIEU signalé (intervention entière)',
        v.x, v.y, v.z, true, 'lieu')

    -- Trace serveur : conservée dans les logs après redémarrage.
    print('^1[signallieu]^7 ═══ EMPLACEMENT MIS EN CAUSE ═══')
    print(('^1[signallieu]^7 scénario %s | C.Locations.%s index %d | %s')
        :format(tostring(co.scenarioId), cat, idx, tostring(loc.label)))
    print('^1[signallieu]^7 ' .. line)
    for _, e in ipairs(peds) do
        print(('^1[signallieu]^7   %-9s %-9s %s')
            :format(tostring(e.role), tostring(e.state),
                e.exists and ('Δz %+.2f m  dist %.1f m'):format(e.dz, e.dist)
                or 'ENTITÉ ABSENTE'))
    end

    Notify(src, 'Emplacement signalé — détail dans votre console F8.', 'success')
    TriggerClientEvent('police:callouts:locationReported', src, {
        scenario = co.scenarioId, category = cat, index = idx,
        label = loc.label, line = line, peds = peds,
    })
end)

-- Signalement d'une INADÉQUATION scénario / emplacement.
LSLegacy.Events.Register('police:callouts:reportMismatch', function()
    local src = source
    local co = CalloutOf(src)
    if not co then
        Notify(src, 'Vous n\'êtes engagé sur aucune intervention.', 'error')
        return
    end

    local loc = co.location.loc
    local v   = loc.coords
    local cat = tostring(co.location.key or ''):match('^(.-):') or '?'
    local idx = co.location.index or 0

    RecordSpawnFail(co.scenarioId, loc.label,
        'SCÉNARIO inadapté à ce lieu', v.x, v.y, v.z, true, 'inadéquation')

    print('^3[signalscenario]^7 ═══ SCÉNARIO INADAPTÉ ═══')
    print(('^3[signalscenario]^7 %s ne convient pas à C.Locations.%s index %d (%s)')
        :format(tostring(co.scenarioId), cat, idx, tostring(loc.label)))

    Notify(src, 'Inadéquation signalée — détail dans votre console F8.', 'success')
    TriggerClientEvent('police:callouts:mismatchReported', src, {
        scenario = co.scenarioId, category = cat, index = idx,
        label = loc.label,
        line = ("        { coords = vector4(%.2f, %.2f, %.2f, %.1f), label = '%s', zone = '%s' },")
            :format(v.x, v.y, v.z, v.w or 0.0, tostring(loc.label or '?'),
                tostring(loc.zone or 'downtown')),
    })
end)

-- Contrôle des ancrages au démarrage
CreateThread(function()
    Wait(3000)
    local checked, bad = 0, 0

    for key, roles in pairs(C.SceneAnchors or {}) do
        local cat, idx = key:match('^(%w+):(%d+)$')
        idx = tonumber(idx)
        local entry = cat and idx and C.Locations[cat] and C.Locations[cat][idx]

        if not entry then
            bad = bad + 1
            print(('^1[ancrage]^7 « %s » ne correspond à aucun emplacement — ' ..
                'ancrage ignoré.'):format(key))
        else
            local v = entry.coords

            -- Un niveau peut contenir des positions ou une surcharge de
            local function Check(role, a, prefix)
                if type(a) ~= 'table' then return end
                if a.w ~= nil then a = { a } end
                if a[1] == nil then
                    for r2, a2 in pairs(a) do Check(r2, a2, role .. '/') end
                    return
                end
                for _, pt in ipairs(a) do
                    checked = checked + 1
                    local d = #(vector3(pt.x, pt.y, pt.z) - vector3(v.x, v.y, v.z))
                    if d > 120.0 then
                        bad = bad + 1
                        print(('^1[ancrage]^7 « %s » / %s%s : %.0f m de %s — ' ..
                            'index probablement décalé.')
                            :format(key, prefix, role, d, tostring(entry.label)))
                    end
                end
            end

            for role, a in pairs(roles) do Check(role, a, '') end
        end
    end

    if checked > 0 then
        if bad == 0 then
            print(('^2[ancrage]^7 %d position(s) relevée(s) vérifiée(s), ' ..
                'toutes cohérentes.'):format(checked))
        else
            print(('^3[ancrage]^7 %d anomalie(s) sur %d position(s) — ' ..
                'relevez-les à nouveau avec /pnjposition.'):format(bad, checked))
        end
    end
end)

--  RELEVÉ D'ANCRAGES DE SCÈNE

local SCENE_ANCHOR_FILE = 'module/police/sceneanchors.json'
local SceneAnchorDraft  = {}   -- { [clé] = { role = { {x,y,z,h,seq}, ... } } }
local anchorsDirty      = false

-- Numéro d'ordre attribué à chaque relevé. Il survit au redémarrage
local AnchorSeq = 0

-- Rôles relevables. Les alias français évitent d'avoir à retenir les
local ANCHOR_ROLES = {
    caller = true, deceased = true, victim = true, suspect = true,
    bystander = true, animal = true, wanderer = true,
    -- Braquage : les trois rôles se distinguent, et le véhicule de
    chief = true, driver = true, crew = true, vehicle = true,
}

-- Noms acceptés pour un rôle. Le requérant change de métier selon la
local ANCHOR_NAMES = {
    caller = {
        'requerant', 'requérant', 'appelant', 'plaignant', 'temoin', 'témoin',
        'caissier', 'caissiere', 'caissière', 'vigile', 'securite', 'sécurité',
        'agent_securite', 'gardien', 'proprietaire', 'propriétaire', 'proprio',
        'voisin', 'voisine', 'commercant', 'commerçant', 'patron',
    },
    -- Le mis en cause, quelle que soit la mission : voleur d'un vol à
    suspect = {
        'individu', 'suspect', 'voleur', 'voleuse', 'mis_en_cause', 'mec',
        'dealer', 'vendeur', 'maitre', 'maître', 'proprietaire_chien',
        'ivrogne', 'alcoolise', 'alcoolisé', 'ivresse', 'ivre',
        'ebriete', 'ébriété', 'soulard', 'fetard', 'fêtard', 'pochtron',
    },
    victim = { 'victime', 'blesse', 'blessé', 'blessee', 'blessée' },
    bystander = {
        'badaud', 'client', 'cliente', 'passant', 'passante', 'curieux',
        'spectateur', 'temoin_scene', 'foule',
    },
    deceased = { 'corps', 'cadavre', 'decede', 'décédé', 'mort', 'defunt', 'défunt' },
    -- La personne errante est une personne âgée désorientée qu'on
    wanderer = {
        'errant', 'errante', 'perdu', 'perdue',
        'desoriente', 'désorienté', 'desorientee', 'désorientée',
        'personne_errante', 'personne_agee', 'personne_âgée', 'vagabond', 'sdf',
        'wanderer', 'wonderer',
    },
    animal  = { 'chien', 'animal', 'chienne', 'clebs' },
    chief   = { 'chef', 'leader', 'meneur', 'chief' },
    driver  = { 'conducteur', 'chauffeur', 'volant', 'driver' },
    crew    = { 'braqueur', 'equipier', 'équipier', 'executant', 'exécutant',
                'complice', 'crew' },
    vehicle = { 'vehicule', 'véhicule', 'voiture', 'bagnole', 'caisse',
                'van', 'vehicle' },
}

local ANCHOR_ALIAS = {}
for role, names in pairs(ANCHOR_NAMES) do
    ANCHOR_ALIAS[role] = role          -- l'identifiant interne reste valable
    for _, n in ipairs(names) do ANCHOR_ALIAS[n] = role end
end

local function SaveAnchors()
    local ok, encoded = pcall(json.encode, SceneAnchorDraft)
    if ok then
        SaveResourceFile(GetCurrentResourceName(), SCENE_ANCHOR_FILE, encoded, -1)
    end
end

CreateThread(function()
    local raw = LoadResourceFile(GetCurrentResourceName(), SCENE_ANCHOR_FILE)
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            SceneAnchorDraft = decoded
            -- Relevés d'avant la numérotation : on leur en attribue une
            for _, roles in pairs(SceneAnchorDraft) do
                for _, list in pairs(roles) do
                    for _, e in ipairs(list) do
                        if type(e.seq) == 'number' then
                            if e.seq > AnchorSeq then AnchorSeq = e.seq end
                        else
                            AnchorSeq = AnchorSeq + 1
                            e.seq = AnchorSeq
                        end
                    end
                end
            end
            local n = 0
            for _ in pairs(SceneAnchorDraft) do n = n + 1 end
            if n > 0 then
                print(('^2[ancrage]^7 %d emplacement(s) avec positions relevées. ' ..
                    'Consultables avec /pnjpositions.'):format(n))
            end
        end
    end
    while true do
        Wait(5000)
        if anchorsDirty then anchorsDirty = false SaveAnchors() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and anchorsDirty then SaveAnchors() end
end)

-- Mode repérage
local AnchorSurvey = {}   -- { [src] = { key, label, scenarioId } }

-- Emplacement déclaré le plus proche d'un point, toutes catégories ou
local function NearestLocation(pos, category)
    local bestKey, bestLoc, bestDist = nil, nil, math.huge
    for cat, list in pairs(C.Locations or {}) do
        if not category or cat == category then
            for i, loc in ipairs(list) do
                local v = loc.coords
                local d = #(vector3(v.x, v.y, v.z) - pos)
                if d < bestDist then
                    bestDist = d
                    bestLoc  = loc
                    bestKey  = cat .. ':' .. i
                end
            end
        end
    end
    return bestKey, bestLoc, bestDist
end

LSLegacy.Events.Register('police:callouts:anchorSurvey', function(data)
    local src = source
    if not IsAdmin(src) then DenyAdmin(src) return end

    local scenarioId = tostring(data and data.scenario or ''):lower()

    if scenarioId == '' or scenarioId == 'off' or scenarioId == 'stop' then
        AnchorSurvey[src] = nil
        Notify(src, 'Repérage terminé.', 'info')
        TriggerClientEvent('police:callouts:anchorSurveyState', src, { active = false })
        return
    end

    local sc = Config.Police.Scenarios[scenarioId]
    if not sc then
        local ids = {}
        for id in pairs(Config.Police.Scenarios) do ids[#ids + 1] = id end
        table.sort(ids)
        Notify(src, 'Scénario inconnu — liste dans votre console F8.', 'error')
        TriggerClientEvent('police:callouts:anchorSurveyState', src, {
            active = false, list = ids,
        })
        return
    end

    -- On se limite à la catégorie d'emplacements du scénario : une
    local ped = GetPlayerPed(src)
    local pos = GetEntityCoords(ped)
    local key, loc, dist = NearestLocation(pos, sc.locations)

    if not key then
        Notify(src, ('Aucun emplacement de type « %s » n\'est déclaré.')
            :format(tostring(sc.locations)), 'error')
        return
    end

    -- REFUS AU-DELÀ D'UNE CERTAINE DISTANCE.
    if dist > C.SurveyMaxDist then
        Notify(src, ('Emplacement le plus proche : %s, à %.0f m. Trop loin ' ..
            '— rapprochez-vous ou aucun lieu n\'est déclaré ici.')
            :format(loc.label or key, dist), 'error')
        TriggerClientEvent('police:callouts:anchorSurveyState', src, {
            active = false, tooFar = true, dist = dist,
            label = loc.label, key = key,
            x = loc.coords.x, y = loc.coords.y, z = loc.coords.z,
        })
        return
    end

    AnchorSurvey[src] = {
        key = key, label = loc.label, scenarioId = scenarioId,
    }
    Notify(src, ('Repérage : %s — %s (%.0f m).')
        :format(sc.label or scenarioId, loc.label or key, dist), 'success')
    TriggerClientEvent('police:callouts:anchorSurveyState', src, {
        active = true, key = key, label = loc.label,
        scenario = scenarioId, scenarioLabel = sc.label, dist = dist,
        x = loc.coords.x, y = loc.coords.y, z = loc.coords.z,
    })
end)

AddEventHandler('playerDropped', function()
    AnchorSurvey[source] = nil
end)

-- Relevé d'une position pour un rôle, sur l'emplacement en cours.
LSLegacy.Events.Register('police:callouts:anchorHere', function(data)
    local src = source
    -- Même garde que /pnjrepere (anchorSurvey) : sans elle, n'importe
    if not IsAdmin(src) then DenyAdmin(src) return end
    local co = CalloutOf(src)
    local sv = AnchorSurvey[src]

    -- Le repérage prime : s'il est actif, c'est lui qu'on renseigne,
    if not co and not sv then
        Notify(src, 'Aucune intervention et aucun repérage en cours — ' ..
            'lancez /pnjrepere <scénario>.', 'error')
        return
    end

    local role = tostring(data and data.role or ''):lower()
    role = ANCHOR_ALIAS[role] or role
    if not ANCHOR_ROLES[role] then
        -- Liste complète en console plutôt qu'un rappel tronqué : c'est
        local lines = {}
        for r, names in pairs(ANCHOR_NAMES) do
            lines[#lines + 1] = ('%-10s %s'):format(r, table.concat(names, ', '))
        end
        table.sort(lines)
        Notify(src, 'Rôle inconnu — liste complète dans votre console F8.', 'error')
        TriggerClientEvent('police:callouts:anchorRoles', src, {
            given = tostring(data and data.role or ''), lines = lines,
        })
        return
    end

    local ped = GetPlayerPed(src)
    local c   = GetEntityCoords(ped)
    local h   = GetEntityHeading(ped)
    local key        = sv and sv.key        or co.location.key
    local scenarioId = sv and sv.scenarioId or co.scenarioId
    local label      = sv and sv.label      or co.location.loc.label

    -- Position relevée depuis un véhicule occupé : on la retient si
    if role == 'vehicle' and data.vx then
        local vx, vy, vz = tonumber(data.vx), tonumber(data.vy), tonumber(data.vz)
        if vx and vy and vz then
            local d = #(vector3(vx, vy, vz) - c)
            if d <= 15.0 then
                c = vector3(vx, vy, vz)
                h = tonumber(data.vh) or h
            end
        end
    end

    AnchorSeq = AnchorSeq + 1
    SceneAnchorDraft[key] = SceneAnchorDraft[key] or {}
    local list = SceneAnchorDraft[key][role] or {}
    list[#list + 1] = {
        x = c.x, y = c.y, z = c.z, h = h,
        scenario = scenarioId, label = label, seq = AnchorSeq,
    }
    SceneAnchorDraft[key][role] = list
    anchorsDirty = true

    Notify(src, ('Position n°%d relevée pour « %s » sur %s.')
        :format(#list, role, label or key), 'success')
    TriggerClientEvent('police:callouts:anchorSaved', src, {
        key = key, role = role, index = #list,
        x = c.x, y = c.y, z = c.z, h = h,
        label = label, scenario = scenarioId,
        survey = sv ~= nil,
    })
end)

-- Annulation du dernier relevé.
LSLegacy.Events.Register('police:callouts:anchorUndo', function(data)
    local src = source
    if not IsAdmin(src) then DenyAdmin(src) return end
    local co = CalloutOf(src)
    local sv = AnchorSurvey[src]

    if not co and not sv then
        Notify(src, 'Aucune intervention et aucun repérage en cours.', 'error')
        return
    end

    local key        = sv and sv.key        or co.location.key
    local scenarioId = sv and sv.scenarioId or co.scenarioId

    local role = tostring(data and data.role or ''):lower()
    if role == '' then
        role = nil
    else
        role = ANCHOR_ALIAS[role] or role
        if not ANCHOR_ROLES[role] then
            Notify(src, 'Rôle inconnu.', 'error')
            return
        end
    end

    local set = SceneAnchorDraft[key]
    if not set then
        Notify(src, 'Aucun relevé à annuler sur cet emplacement.', 'error')
        return
    end

    -- Le plus récent, tous rôles confondus ou dans le rôle demandé, et
    local bestRole, bestIdx, bestSeq = nil, nil, -1
    for r, list in pairs(set) do
        if not role or r == role then
            for i, e in ipairs(list) do
                if e.scenario == scenarioId and (e.seq or 0) > bestSeq then
                    bestSeq  = e.seq or 0
                    bestRole = r
                    bestIdx  = i
                end
            end
        end
    end

    if not bestRole then
        Notify(src, role
            and ('Aucun relevé « ' .. role .. ' » à annuler ici.')
            or 'Aucun relevé à annuler ici.', 'error')
        return
    end

    local removed = table.remove(set[bestRole], bestIdx)
    if #set[bestRole] == 0 then set[bestRole] = nil end
    local empty = true
    for _ in pairs(set) do empty = false break end
    if empty then SceneAnchorDraft[key] = nil end
    anchorsDirty = true

    -- Points restants de cet emplacement pour ce scénario : le client
    local left = {}
    for r, list in pairs(SceneAnchorDraft[key] or {}) do
        for _, e in ipairs(list) do
            if e.scenario == scenarioId then
                left[#left + 1] = { role = r, x = e.x, y = e.y, z = e.z }
            end
        end
    end

    Notify(src, ('Relevé « %s » annulé — %d point(s) restant(s) ici.')
        :format(bestRole, #left), 'success')
    TriggerClientEvent('police:callouts:anchorUndone', src, {
        key = key, scenario = scenarioId, role = bestRole,
        x = removed and removed.x, y = removed and removed.y,
        z = removed and removed.z,
        points = left,
    })
end)

-- Restitution : bloc Lua prêt à coller dans C.SceneAnchors.
local function CmdAnchorList(src)
    if not IsAdmin(src) then DenyAdmin(src) return end

    local keys = {}
    for k in pairs(SceneAnchorDraft) do keys[#keys + 1] = k end
    table.sort(keys)

    if #keys == 0 then
        Notify(src, 'Aucune position relevée.', 'info')
        if src ~= 0 then
            TriggerClientEvent('police:callouts:anchorDump', src, { lines = {} })
        end
        return
    end

    local out = {}
    for _, key in ipairs(keys) do
        local roles = SceneAnchorDraft[key]

        -- Regroupement par SCÉNARIO : un même emplacement se met en
        local byScenario, label = {}, nil
        for role, list in pairs(roles) do
            for _, e in ipairs(list) do
                label = label or e.label
                local sc = e.scenario or '?'
                byScenario[sc] = byScenario[sc] or {}
                byScenario[sc][role] = byScenario[sc][role] or {}
                local t = byScenario[sc][role]
                t[#t + 1] = e
            end
        end

        out[#out + 1] = ('    -- %s'):format(tostring(label))
        out[#out + 1] = ("    ['%s'] = {"):format(key)

        local scen = {}
        for sc in pairs(byScenario) do scen[#scen + 1] = sc end
        table.sort(scen)

        for _, sc in ipairs(scen) do
            out[#out + 1] = ('        %s = {'):format(sc)
            for role, list in pairs(byScenario[sc]) do
                if #list == 1 then
                    local e = list[1]
                    out[#out + 1] = ('            %s = vector4(%.2f, %.2f, %.2f, %.1f),')
                        :format(role, e.x, e.y, e.z, e.h)
                else
                    out[#out + 1] = ('            %s = {'):format(role)
                    for _, e in ipairs(list) do
                        out[#out + 1] = ('                vector4(%.2f, %.2f, %.2f, %.1f),')
                            :format(e.x, e.y, e.z, e.h)
                    end
                    out[#out + 1] = '            },'
                end
            end
            out[#out + 1] = '        },'
        end
        out[#out + 1] = '    },'
    end

    for _, l in ipairs(out) do print('^2[ancrage]^7 ' .. l) end
    Notify(src, #keys .. ' emplacement(s) — bloc dans votre console F8.', 'info')
    if src ~= 0 then
        TriggerClientEvent('police:callouts:anchorDump', src, { lines = out })
    end
end

RegisterCommand('pnjpositions', function(source) CmdAnchorList(source) end, false)

RegisterCommand('pnjpositionsreset', function(source)
    if not IsAdmin(source) then DenyAdmin(source) return end
    SceneAnchorDraft = {}
    anchorsDirty = false
    SaveAnchors()
    Notify(source, 'Positions relevées effacées.', 'success')
    if source ~= 0 then
        TriggerClientEvent('police:callouts:anchorDump', source,
            { lines = {}, cleared = true })
    end
end, false)

-- Classement des emplacements à corriger.
local function CmdSpawnStats(src)
    if not IsAdmin(src) then DenyAdmin(src) return end

    -- Les échecs d'abord, les replis ensuite : c'est sur les premiers
    local list = {}
    for _, e in pairs(SpawnFails) do
        e.degraded = IsDegraded(e.reason)
        list[#list + 1] = e
    end
    table.sort(list, function(a, b)
        if a.degraded ~= b.degraded then return not a.degraded end
        return a.count > b.count
    end)

    local hard, soft = 0, 0
    for _, e in ipairs(list) do
        if e.degraded then soft = soft + 1 else hard = hard + 1 end
    end

    -- Console SERVEUR : trace persistante dans les logs.
    if #list == 0 then
        print('^2[spawn]^7 Aucun placement raté enregistré depuis le démarrage.')
    else
        print('^2[spawn]^7 ═══ PLACEMENTS RATÉS ═══')
        for _, e in ipairs(list) do
            print(('^2[spawn]^7 %4d | %s | %s | %s | %s | %s | vector3(%.2f, %.2f, %.2f)')
                :format(e.count, e.manual and 'MAN' or 'auto',
                    tostring(e.scenario), tostring(e.zone), tostring(e.role),
                    tostring(e.reason), e.x or 0, e.y or 0, e.z or 0))
        end
    end

    -- Console du JOUEUR : c'est là qu'il regarde. Une commande serveur
    if src ~= 0 then
        TriggerClientEvent('police:callouts:spawnStats', src,
            { rows = list, hard = hard, soft = soft })
    end

    Notify(src, (#list == 0)
        and 'Aucun placement raté enregistré.'
        or ('%d échec(s) et %d repli(s) — détail dans votre console F8.')
            :format(hard, soft), 'info')
end

RegisterCommand('spawnstats', function(source) CmdSpawnStats(source) end, false)

-- Remise à zéro du registre.
RegisterCommand('spawnstatsreset', function(source)
    if not IsAdmin(source) then DenyAdmin(source) return end
    SpawnFails = {}
    spawnFailsDirty = false
    SaveSpawnFails()
    Notify(source, 'Registre des placements ratés vidé.', 'success')
    print('^2[spawn]^7 Registre vidé (fichier compris).')
    if source ~= 0 then
        TriggerClientEvent('police:callouts:spawnStats', source,
            { rows = {}, cleared = true })
    end
end, false)

RegisterCommand('missionpnjadmin', CmdMissionPnjAdmin, false)
RegisterCommand('callouts',        CmdCallouts,        false)
RegisterCommand('callout',         CmdCallout,         false)

-- Actions du menu d'administration
LSLegacy.Events.Register('police:callouts:adminAction', function(data)
    local src = source
    if not IsAdmin(src) then DenyAdmin(src) return end
    if not data or not data.action then return end

    if data.action == 'force' then
        if not Config.Police.Scenarios[data.value] then
            Notify(src, 'Scénario inconnu.', 'error')
            return
        end
        local maxActive = math.max(1, math.min(StaffedCrews(), #C.Crews))
        if ActiveCount() >= maxActive then
            Notify(src, ('Plafond atteint : %d intervention(s) pour %d équipage(s).')
                :format(ActiveCount(), StaffedCrews()), 'error')
            return
        end
        -- Sans agent enregistré, l'appel ne serait diffusé à personne.
        if not Registered[src] then
            DoRegister(src, C.Crews[1] and C.Crews[1].id or 'alpha')
        end
        local ok, err = CreateCallout(data.value, true)
        Notify(src, ok and ('Appel forcé : ' .. Config.Police.Scenarios[data.value].label)
            or ('Échec : ' .. tostring(err)), ok and 'success' or 'error')

    elseif data.action == 'forceTier' then
        -- Tirage au sort parmi les scénarios du palier demandé. Comme
        local tier = tonumber(data.value)
        if not tier then Notify(src, 'Palier inconnu.', 'error') return end

        local pool = {}
        for id, sc in pairs(Config.Police.Scenarios) do
            if (sc.minAgents or 1) == tier then pool[#pool + 1] = id end
        end
        if #pool == 0 then
            Notify(src, 'Aucun scénario pour le palier ' .. tier .. '.', 'error')
            return
        end

        local maxActive = math.max(1, math.min(StaffedCrews(), #C.Crews))
        if ActiveCount() >= maxActive then
            Notify(src, ('Plafond atteint : %d intervention(s) pour %d équipage(s).')
                :format(ActiveCount(), StaffedCrews()), 'error')
            return
        end
        if not Registered[src] then
            DoRegister(src, C.Crews[1] and C.Crews[1].id or 'alpha')
        end

        local pick = pool[math.random(1, #pool)]
        local ok, err = CreateCallout(pick, true)
        Notify(src, ok and ('Palier %d — appel tiré au sort : %s')
            :format(tier, Config.Police.Scenarios[pick].label)
            or ('Échec : ' .. tostring(err)), ok and 'success' or 'error')

    elseif data.action == 'end' then
        if ActiveCount() == 0 then Notify(src, 'Aucun appel en cours.', 'error') return end
        -- Un identifiant précis peut être visé, sinon on clôture tout
        local target = tonumber(data.value)
        if target and Callouts[target] then
            Notify(src, 'Clôture forcée de l\'appel #' .. target .. '.', 'warning')
            EndCallout(Callouts[target], 'failed')
        else
            local ids = {}
            for id in pairs(Callouts) do ids[#ids + 1] = id end
            for _, id in ipairs(ids) do
                if Callouts[id] then EndCallout(Callouts[id], 'failed') end
            end
            Notify(src, 'Toutes les interventions ont été clôturées.', 'warning')
        end

    elseif data.action == 'toggleTest' then
        SetTestMode(src, not TestMode.active, data.value)

    elseif data.action == 'toggleEnabled' then
        C.Enabled = not C.Enabled
        Notify(src, 'Missions PNJ ' .. (C.Enabled and 'activées.' or 'suspendues.'),
            C.Enabled and 'success' or 'warning')
        print(('^2[callouts]^7 Missions PNJ %s par %s.')
            :format(C.Enabled and 'activées' or 'suspendues', GetName(src)))

    elseif data.action == 'refresh' then
        SendAdminMenu(src)
        return
    end

    SendAdminMenu(src)
end)

-- Aiguillage du relais client (F8) vers le bon handler
RunCommand = function(src, cmd, args)
    if cmd == 'missionpnj' then
        DoRegister(src)
    elseif cmd == 'missionpnjadmin' then
        CmdMissionPnjAdmin(src, args)
    elseif cmd == 'callouts' then
        CmdCallouts(src, args)
    elseif cmd == 'callout' then
        CmdCallout(src, args)
    end
end

--  PONT MDT — onglet « Interventions »

local MdtQueries = {}

local MDT_PAGE_SIZE = 15

-- Portée de lecture de l'historique pour le demandeur : par défaut police
local function CalloutScope(src, column)
    local dep = GetMdtDepartment(src) or 'police'
    return LSLegacy.MDT.ScopeClause(dep, 'police_callouts', column)
end

MdtQueries.getHistory = function(src, data, cb)
    local page   = math.max(1, tonumber(data and data.page or 1) or 1)
    local offset = (page - 1) * MDT_PAGE_SIZE

    -- On demande une ligne de plus que la page : sa présence indique
    MySQL.Async.fetchAll(
        'SELECT c.*, ' ..
        '(SELECT GROUP_CONCAT(a.name SEPARATOR ", ") FROM police_callout_agents a ' ..
        ' WHERE a.callout_id = c.id) AS agents, ' ..
        -- Bavures cumulées de l'équipage : une intervention entachée est
        '(SELECT COALESCE(SUM(a.misconduct), 0) FROM police_callout_agents a ' ..
        ' WHERE a.callout_id = c.id) AS misconducts ' ..
        'FROM police_callouts c WHERE ' .. CalloutScope(src, 'c.department') ..
        ' ORDER BY c.started_at DESC LIMIT @limit OFFSET @offset',
        { ['@limit'] = MDT_PAGE_SIZE + 1, ['@offset'] = offset },
        function(rows)
            rows = rows or {}
            local hasMore = #rows > MDT_PAGE_SIZE
            if hasMore then table.remove(rows, #rows) end
            cb({ rows = rows, page = page, hasMore = hasMore,
                 canManage = HasPermission(src, 'admin_mdt') })
        end
    )
end

-- Nom d'affichage pour signer rapport et classement. GetName est le
local function AgentName(src)
    local ok, n = pcall(GetName, src)
    if ok and n and n ~= '' then return n end
    return 'Agent'
end

-- Rédaction ou modification du rapport d'intervention. Ouvert à tout
MdtQueries.saveReport = function(src, data, cb)
    local id   = tonumber(data and data.id or 0)
    local text = tostring(data and data.text or '')
    if id <= 0 then cb(false) return end

    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then cb({ ok = false, reason = 'Le rapport est vide.' }) return end
    if #text > 5000 then text = text:sub(1, 5000) end

    MySQL.Async.fetchAll('SELECT closed FROM police_callouts WHERE id = @id',
        { ['@id'] = id }, function(rows)
            local row = rows and rows[1]
            if not row then cb({ ok = false, reason = 'Dossier introuvable.' }) return end
            if tonumber(row.closed or 0) == 1 then
                cb({ ok = false, reason = 'Dossier classé : le rapport n\'est plus modifiable.' })
                return
            end

            MySQL.Async.execute(
                'UPDATE police_callouts SET report = @r, report_by = @by, ' ..
                'report_at = NOW() WHERE id = @id',
                { ['@r'] = text, ['@by'] = AgentName(src), ['@id'] = id },
                function() cb({ ok = true }) end
            )
        end)
end

-- Classement de l'affaire — réservé au commissaire (admin_mdt).
MdtQueries.closeCase = function(src, data, cb)
    if not HasPermission(src, 'admin_mdt') then
        cb({ ok = false, reason = 'Réservé au commissaire.' })
        return
    end
    local id = tonumber(data and data.id or 0)
    if id <= 0 then cb(false) return end

    MySQL.Async.fetchAll('SELECT report, closed FROM police_callouts WHERE id = @id',
        { ['@id'] = id }, function(rows)
            local row = rows and rows[1]
            if not row then cb({ ok = false, reason = 'Dossier introuvable.' }) return end
            if tonumber(row.closed or 0) == 1 then
                cb({ ok = false, reason = 'Affaire déjà classée.' })
                return
            end
            if not row.report or row.report == '' then
                cb({ ok = false, reason = 'Aucun rapport rédigé : impossible de classer.' })
                return
            end

            MySQL.Async.execute(
                'UPDATE police_callouts SET closed = 1, closed_by = @by, ' ..
                'closed_at = NOW() WHERE id = @id',
                { ['@by'] = AgentName(src), ['@id'] = id },
                function() cb({ ok = true }) end
            )
        end)
end

-- Suppression d'une intervention — réservée au commissaire (admin_mdt).
MdtQueries.deleteCallout = function(src, data, cb)
    if not HasPermission(src, 'admin_mdt') then cb(false) return end
    local id = tonumber(data and data.id or 0)
    if not id or id <= 0 then cb(false) return end

    MySQL.Async.execute('DELETE FROM police_callout_agents WHERE callout_id = @id',
        { ['@id'] = id }, function()
        MySQL.Async.execute('DELETE FROM police_callouts WHERE id = @id',
            { ['@id'] = id }, function()
            LogDiscord('Interventions — suppression',
                '**' .. GetName(src) .. '** a supprimé l\'intervention #' .. id, 15105570)
            cb(true)
        end)
    end)
end

-- Réinitialisation complète des compteurs — commissaire uniquement.
MdtQueries.resetStats = function(src, data, cb)
    if not HasPermission(src, 'admin_mdt') then cb(false) return end

    MySQL.Async.execute('DELETE FROM police_callout_agents', {}, function()
        MySQL.Async.execute('DELETE FROM police_callouts', {}, function()
            LogDiscord('Interventions — réinitialisation',
                '**' .. GetName(src) .. '** a réinitialisé l\'historique et ' ..
                'les statistiques des interventions.', 15158332)
            cb(true)
        end)
    end)
end

MdtQueries.getStats = function(src, data, cb)
    MySQL.Async.fetchAll(
        'SELECT a.identifier, a.name, MAX(a.grade) AS grade, ' ..
        -- MAX() sur le pôle : un agent n'en change pas en pratique, mais
        'MAX(a.department) AS department, ' ..
        'COUNT(*) AS interventions, SUM(a.cuffed) AS cuffed, SUM(a.delivered) AS delivered, ' ..
        'SUM(a.killed) AS killed, SUM(a.misconduct) AS misconduct, ' ..
        'SUM(CASE WHEN c.status = "success" THEN 1 ELSE 0 END) AS successes ' ..
        'FROM police_callout_agents a ' ..
        'JOIN police_callouts c ON c.id = a.callout_id ' ..
        'WHERE ' .. CalloutScope(src, 'c.department') .. ' ' ..
        'GROUP BY a.identifier, a.name ORDER BY interventions DESC LIMIT 50',
        {},
        function(rows) cb(rows or {}) end
    )
end

MdtQueries.getSummary = function(src, data, cb)
    MySQL.Async.fetchAll(
        'SELECT AVG(response_time) AS avg_response, COUNT(*) AS total, ' ..
        'SUM(CASE WHEN status = "success" THEN 1 ELSE 0 END) AS successes ' ..
        'FROM police_callouts WHERE ' .. CalloutScope(src) ..
        ' AND started_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)',
        {},
        function(rows) cb(rows and rows[1] or {}) end
    )
end

LSLegacy.Events.Register('mdtco:query', function(data)
    local src = source
    if not data or not data.action or not data.reqId then return end
    if not IsLawEnforcement(src) then return end
    if not HasPermission(src, 'view_callouts') then
        LSLegacy.Events.SendToClient('mdtco:queryResult', src, { reqId = data.reqId, result = false })
        return
    end

    local handler = MdtQueries[data.action]
    if not handler then
        LSLegacy.Events.SendToClient('mdtco:queryResult', src, { reqId = data.reqId, result = false })
        return
    end

    handler(src, data.data or {}, function(res)
        LSLegacy.Events.SendToClient('mdtco:queryResult', src, { reqId = data.reqId, result = res })
    end)
end)

--  NETTOYAGE À L'ARRÊT DE LA RESSOURCE

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, co in pairs(Callouts) do DeleteAllEntities(co) end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Callouts   = {}
    AgentCall  = {}
    Registered = {}
end)

--  EXPOSITION (autres modules / debug)

-- Interventions en cours (lecture seule pour les autres modules).
function GetActiveCallouts() return Callouts end
function GetActiveCallout(src) return src and CalloutOf(src) or nil end
function GetCalloutRegistry() return Registered end
