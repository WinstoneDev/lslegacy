-- module/foodapi (serveur) — API publique + moteur de péremption.
-- Voir module/foodapi/config.lua pour le pourquoi de ce module.

local C = Config.FoodAPI
local P = C.Perishable

local function Dbg(msg)
    if C.Debug then print(('[foodapi] %s'):format(msg)) end
end

-- ─────────────────────────────────────────────────────────────────────────
--  Péremption
-- ─────────────────────────────────────────────────────────────────────────
-- Un item périssable porte, dans sa métadonnée d'instance :
--   data.fresh = { b = budget de fraîcheur restant (s), t = os.time() du
--                  dernier changement d'état, r = vitesse de consommation }
-- Budget restant à l'instant T : b - (T - t) * r   (borné à 0)
-- Temps réel restant affiché    : budget / r       (infini si r == 0)
--
-- Conséquences voulues :
--   - un plat sorti du frigo pro repart avec le budget qu'il avait en entrant ;
--   - un plat déposé dans un frigo domestique voit son budget se consommer
--     ~9,6x moins vite (5h -> 48h), sans jamais être remis à zéro ;
--   - un plat déjà à 0 au moment où il est rangé au frigo est périmé, point.

LSLegacy.Perishable = LSLegacy.Perishable or {}
LSLegacy.Perishable.Items = LSLegacy.Perishable.Items or {}
LSLegacy.Perishable.ColdStorages = LSLegacy.Perishable.ColdStorages or {}

for pattern, mode in pairs(P.ColdStoragePatterns) do
    LSLegacy.Perishable.ColdStorages[pattern] = mode
end

---RegisterColdStorage — déclare qu'un DataStore dont le nom correspond à ce
---motif Lua conserve les aliments (mode 'pro' = figé, 'home' = ralenti).
---@param pattern string
---@param mode string
LSLegacy.Perishable.RegisterColdStorage = function(pattern, mode)
    if type(pattern) ~= "string" then return end
    if not P.Modes[mode] then return end
    LSLegacy.Perishable.ColdStorages[pattern] = mode
    Dbg(('cold storage: %s -> %s'):format(pattern, mode))
end

---ModeForDataStore — mode de conservation d'un DataStore (nom puis type).
---@param name string
---@param dsType string|nil
---@return string
LSLegacy.Perishable.ModeForDataStore = function(name, dsType)
    if type(name) == "string" then
        for pattern, mode in pairs(LSLegacy.Perishable.ColdStorages) do
            if name:match(pattern) then return mode end
        end
    end
    if dsType and P.ColdStorageTypes[dsType] then
        return P.ColdStorageTypes[dsType]
    end
    return 'ambient'
end

---IsPerishable
---@param item string
---@return boolean
LSLegacy.Perishable.Is = function(item)
    return P.Enabled and LSLegacy.Perishable.Items[item] ~= nil
end

---ShelfLife — budget total d'un item, en secondes.
LSLegacy.Perishable.ShelfLife = function(item)
    local def = LSLegacy.Perishable.Items[item]
    return (def and def.shelfLife) or P.DefaultShelfLife
end

---Budget — budget de fraîcheur restant (secondes), borné à [0, total].
---@param fresh table|nil
---@param item string
---@return number
LSLegacy.Perishable.Budget = function(fresh, item)
    if type(fresh) ~= "table" then return LSLegacy.Perishable.ShelfLife(item) end
    local b = tonumber(fresh.b) or 0
    local t = tonumber(fresh.t) or os.time()
    local r = tonumber(fresh.r) or 1.0
    local left = b - ((os.time() - t) * r)
    if left < 0 then left = 0 end
    return left
end

---Stamp — repositionne la métadonnée de fraîcheur pour un nouveau mode de
---stockage. Renvoie la table `data` (créée si besoin) prête à être stockée.
---@param item string
---@param data table|nil
---@param mode string
---@return table|nil
LSLegacy.Perishable.Stamp = function(item, data, mode)
    if not LSLegacy.Perishable.Is(item) then return data end
    local rate = P.Modes[mode] or P.Modes.ambient
    data = data or {}
    data.fresh = {
        b = LSLegacy.Perishable.Budget(data.fresh, item),
        t = os.time(),
        r = rate,
    }
    return data
end

---IsExpired
---@param item string
---@param data table|nil
---@return boolean
LSLegacy.Perishable.IsExpired = function(item, data)
    if not LSLegacy.Perishable.Is(item) then return false end
    return LSLegacy.Perishable.Budget(data and data.fresh, item) <= 0
end

---RemainingSeconds — temps réel restant avant péremption dans le mode
---courant. -1 = conservation illimitée (frigo professionnel).
LSLegacy.Perishable.RemainingSeconds = function(item, data)
    if not LSLegacy.Perishable.Is(item) then return -1 end
    local fresh = data and data.fresh
    local rate = (type(fresh) == "table" and tonumber(fresh.r)) or P.Modes.ambient
    if not rate or rate <= 0 then return -1 end
    return LSLegacy.Perishable.Budget(fresh, item) / rate
end

-- ─────────────────────────────────────────────────────────────────────────
--  Enregistrement d'items depuis une ressource externe
-- ─────────────────────────────────────────────────────────────────────────
-- Une ressource restaurant déclare ses propres items ; ils rejoignent le
-- registre du Core (Config.Items / InsertItems / NeedsItems) au démarrage.
-- Arrêter la ressource retire ses items du registre : c'est voulu.

LSLegacy.Food = LSLegacy.Food or {}
LSLegacy.Food.Owners = LSLegacy.Food.Owners or {}   -- [resource] = { itemName, ... }

---RegisterItems
---@param owner string      ressource propriétaire (pour le retrait à l'arrêt)
---@param items table       [name] = { label, weight, props, unique, needs, perishable }
LSLegacy.Food.RegisterItems = function(owner, items)
    if type(items) ~= "table" then return 0 end
    local n = 0
    LSLegacy.Food.Owners[owner] = LSLegacy.Food.Owners[owner] or {}

    for name, def in pairs(items) do
        if type(name) == "string" and type(def) == "table" and def.label then
            Config.Items[name] = {
                label  = def.label,
                weight = tonumber(def.weight) or 0.1,
                props  = def.props,
            }

            if def.unique or def.perishable or def.needs then
                Config.InsertItems[name] = true
            end

            if def.needs then
                Config.NeedsItems[name] = {
                    hunger  = def.needs.hunger  or 0,
                    thirst  = def.needs.thirst  or 0,
                    stamina = def.needs.stamina or 0,
                    anim    = def.needs.anim    or 'eating',
                    portion = def.needs.portion or 25,
                }
                -- Même comportement que module/needs, mais avec un refus net
                -- si l'aliment est périmé (le Core ne connaît pas la fraîcheur).
                LSLegacy.RegisterUsableItem(name, function(_clientData, uniqueId)
                    local src = source
                    local player = LSLegacy.Players.Get(src)
                    if not player then return end

                    -- Ne jamais faire confiance au `data` envoyé par le client :
                    -- on relit l'instance authoritative dans l'inventaire serveur.
                    local entry
                    for _, it in pairs(player.inventory or {}) do
                        if it.name == name and (uniqueId == nil or it.uniqueId == uniqueId) then
                            entry = it
                            break
                        end
                    end
                    if not entry then return end

                    if LSLegacy.Perishable.IsExpired(name, entry.data) then
                        TriggerClientEvent('brutal_notify:SendAlert', src, 'Nourriture',
                            ('%s est périmé, impossible de le consommer.'):format(entry.label or name), 5000, 'error')
                        return
                    end

                    entry.data = entry.data or {}
                    if entry.data.durability == nil then entry.data.durability = 100 end
                    LSLegacy.Events.SendToClient('useNeed', src, name, entry.data, entry.uniqueId)
                end)
            end

            if def.perishable then
                LSLegacy.Perishable.Items[name] = {
                    shelfLife = tonumber(def.shelfLife) or P.DefaultShelfLife,
                }
            end

            LSLegacy.Food.Owners[owner][#LSLegacy.Food.Owners[owner] + 1] = name
            n = n + 1
        end
    end

    Dbg(('%s a enregistré %d item(s)'):format(tostring(owner), n))
    return n
end

-- ─────────────────────────────────────────────────────────────────────────
--  Enregistrement d'un job depuis une ressource externe
-- ─────────────────────────────────────────────────────────────────────────
-- LSLegacy.AvailableJobs (server/player/jobs.lua) est une table statique du
-- Core : sans ceci, un job comme 'kebabking' n'existe nulle part pour
-- LSLegacy.Jobs.DoesJobExist, /setjob ou le sélecteur de job de l'adminmenu,
-- même si des ressources externes l'utilisent déjà en interne (comparaison
-- de chaînes sur player.job). Même principe que RegisterItems : la mutation
-- s'exécute ICI, dans l'environnement du Core, jamais dans celui de
-- l'appelant.

LSLegacy.Food.JobOwners = LSLegacy.Food.JobOwners or {}   -- [jobKey] = resource

---RegisterJob
---@param owner string
---@param jobKey string
---@param jobDef table  { label = string, grades = { [0] = {label=...}, ... } }
---@return boolean
LSLegacy.Food.RegisterJob = function(owner, jobKey, jobDef)
    if type(jobKey) ~= "string" or type(jobDef) ~= "table" or type(jobDef.label) ~= "string" then
        return false
    end
    if LSLegacy.AvailableJobs[jobKey] then
        Dbg(('job déjà enregistré, ignoré : %s (%s)'):format(jobKey, owner))
        return false
    end
    LSLegacy.AvailableJobs[jobKey] = { label = jobDef.label, grades = jobDef.grades or { [0] = { label = jobDef.label } } }
    LSLegacy.Food.JobOwners[jobKey] = owner
    Dbg(('job enregistré : %s (%s)'):format(jobKey, owner))
    return true
end

-- ─────────────────────────────────────────────────────────────────────────
--  Vérification de service pour un job externe (module/mdt)
-- ─────────────────────────────────────────────────────────────────────────
-- module/mdt/server/main.lua (onglet Effectifs/Tableau de bord) sait
-- vérifier le service des jobs internes au Core via un appel de fonction
-- globale (_G[nom]) — impossible pour un job qui vit dans une ressource
-- externe, dont les globales ne traversent pas la frontière de ressource.
-- On route donc plutôt vers l'export `isOnDuty_<job>(src)`, SUFFIXÉ PAR LE
-- JOB, que la ressource externe doit exposer elle-même — voir la note dans
-- foodapi/client/main.lua : sans ce suffixe, ls_burgershot et ls_kebabking
-- (qui tournent tous deux dans la ressource lslegacy) se marcheraient dessus.

local externalDutyCheckers = {}   -- [jobKey] = resource

---IsExternalJobOnDuty — appelée par module/mdt, jamais directement par une
---ressource externe.
---@param src number
---@param job string
---@return boolean
LSLegacy.IsExternalJobOnDuty = function(src, job)
    local resource = job and externalDutyCheckers[job]
    if not resource or GetResourceState(resource) ~= 'started' then return false end
    local ok, result = pcall(function() return exports[resource]['isOnDuty_' .. job](src) end)
    return ok and result == true
end

AddEventHandler('onResourceStop', function(resource)
    local owned = LSLegacy.Food.Owners[resource]
    if owned then
        for _, name in ipairs(owned) do
            Config.Items[name] = nil
            Config.InsertItems[name] = nil
            Config.NeedsItems[name] = nil
            LSLegacy.Perishable.Items[name] = nil
            LSLegacy.Inventory.ActionItems[name] = nil
        end
        LSLegacy.Food.Owners[resource] = nil
        Dbg(('items de %s retirés du registre'):format(resource))
    end

    for jobKey, owner in pairs(LSLegacy.Food.JobOwners) do
        if owner == resource then
            LSLegacy.AvailableJobs[jobKey] = nil
            LSLegacy.Food.JobOwners[jobKey] = nil
            Dbg(('job %s retiré du registre (%s arrêtée)'):format(jobKey, resource))
        end
    end

    for jobKey, owner in pairs(externalDutyCheckers) do
        if owner == resource then externalDutyCheckers[jobKey] = nil end
    end
end)

-- ─────────────────────────────────────────────────────────────────────────
--  Exports — tout passe par des valeurs primitives (voir en-tête config.lua)
-- ─────────────────────────────────────────────────────────────────────────

exports('registerItems', function(items)
    local owner = GetInvokingResource() or 'lslegacy'
    return LSLegacy.Food.RegisterItems(owner, items)
end)

exports('registerColdStorage', function(pattern, mode)
    LSLegacy.Perishable.RegisterColdStorage(pattern, mode)
end)

exports('registerJob', function(jobKey, jobDef)
    local owner = GetInvokingResource() or 'lslegacy'
    return LSLegacy.Food.RegisterJob(owner, jobKey, jobDef)
end)

-- La ressource appelante doit exposer son propre export `isOnDuty(src)`.
exports('registerDutyChecker', function(job)
    if type(job) ~= "string" then return false end
    externalDutyCheckers[job] = GetInvokingResource() or 'lslegacy'
    Dbg(('duty checker externe enregistré : %s'):format(job))
    return true
end)

-- Instantané non mutable des infos joueur utiles à un job.
exports('getPlayerInfo', function(src)
    local player = LSLegacy.Players.Get(src)
    if not player then return nil end
    return {
        source    = player.source,
        charId    = player["boutique-id"],
        name      = player.name or GetPlayerName(src),
        job       = player.job,
        grade     = player.job_grade,
        cash      = player.cash,
        weight    = player.weight,
        maxWeight = Config.Informations["MaxWeight"],
    }
end)

exports('hasJob', function(src, job, minGrade)
    local player = LSLegacy.Players.Get(src)
    if not player then return false end
    return LSLegacy.Validate.Job(player, job, minGrade) and true or false
end)

exports('getInventory', function(src)
    local player = LSLegacy.Players.Get(src)
    if not player then return {} end
    local list = {}
    for _, it in pairs(player.inventory or {}) do
        list[#list + 1] = {
            name = it.name, label = it.label, count = it.count,
            uniqueId = it.uniqueId, data = it.data,
        }
    end
    return list
end)

exports('getItemCount', function(src, item)
    local player = LSLegacy.Players.Get(src)
    if not player then return 0 end
    local entry = LSLegacy.Inventory.GetInventoryItem(player, item)
    return entry and entry.count or 0
end)

exports('canCarry', function(src, item, count)
    local player = LSLegacy.Players.Get(src)
    if not player then return false end
    return LSLegacy.Inventory.CanCarryItem(player, item, count or 1) and true or false
end)

exports('addItem', function(src, item, count, data, label)
    local player = LSLegacy.Players.Get(src)
    if not player then return false end
    if not LSLegacy.Inventory.DoesItemExists(item) then return false end
    count = LSLegacy.Validate.PositiveInteger(count) or 1
    if not LSLegacy.Inventory.CanCarryItem(player, item, count) then return false end
    LSLegacy.Inventory.AddItemInInventory(player, item, count, label, nil, data)
    return true
end)

exports('removeItem', function(src, item, count)
    local player = LSLegacy.Players.Get(src)
    if not player then return false end
    count = LSLegacy.Validate.PositiveInteger(count) or 1
    local entry = LSLegacy.Inventory.GetInventoryItem(player, item)
    if not entry or entry.count < count then return false end
    LSLegacy.Inventory.RemoveItemInInventory(player, item, count)
    return true
end)

-- Liste des manques pour un besoin { {item=..., count=...}, ... }
exports('missingItems', function(src, requirements)
    local player = LSLegacy.Players.Get(src)
    if not player then return nil end
    local missing = {}
    for _, req in ipairs(requirements or {}) do
        local entry = LSLegacy.Inventory.GetInventoryItem(player, req.item)
        local have = entry and entry.count or 0
        local need = tonumber(req.count) or 1
        if have < need then
            missing[#missing + 1] = { item = req.item, need = need, have = have }
        end
    end
    return missing
end)

-- Transaction atomique de fabrication : vérifie tout, puis retire et donne.
-- take  = { {item=..., count=...}, ... }
-- give  = { {item=..., count=..., label=..., data=...}, ... }
-- Renvoie une TABLE { ok = boolean, reason = string|nil } — et pas deux
-- valeurs de retour, dont la propagation à travers un export n'est pas
-- garantie selon la version du runtime.
-- reason : 'missing' | 'weight' | 'player' | 'item'
exports('craftTransaction', function(src, take, give)
    local player = LSLegacy.Players.Get(src)
    if not player then return { ok = false, reason = 'player' } end

    for _, req in ipairs(take or {}) do
        if not LSLegacy.Inventory.DoesItemExists(req.item) then return { ok = false, reason = 'item' } end
        local entry = LSLegacy.Inventory.GetInventoryItem(player, req.item)
        if not entry or entry.count < (tonumber(req.count) or 1) then return { ok = false, reason = 'missing' } end
    end

    for _, res in ipairs(give or {}) do
        if not LSLegacy.Inventory.DoesItemExists(res.item) then return { ok = false, reason = 'item' } end
    end

    -- Poids : on estime le solde net après retrait des ingrédients.
    local freed = 0
    for _, req in ipairs(take or {}) do
        local def = Config.Items[req.item]
        if def then freed = freed + def.weight * (tonumber(req.count) or 1) end
    end
    local added = 0
    for _, res in ipairs(give or {}) do
        local def = Config.Items[res.item]
        if def then added = added + def.weight * (tonumber(res.count) or 1) end
    end
    if math.floor((player.weight or 0) - freed + added) > Config.Informations["MaxWeight"] then
        return { ok = false, reason = 'weight' }
    end

    for _, req in ipairs(take or {}) do
        LSLegacy.Inventory.RemoveItemInInventory(player, req.item, tonumber(req.count) or 1)
    end
    for _, res in ipairs(give or {}) do
        LSLegacy.Inventory.AddItemInInventory(player, res.item, tonumber(res.count) or 1, res.label, nil, res.data)
    end
    return { ok = true }
end)

exports('notify', function(src, title, message, kind, time)
    TriggerClientEvent('brutal_notify:SendAlert', src, title, message, time or 5000, kind or 'info')
end)

-- DataStores (réserves, frigos, plateaux) — création paresseuse comme
-- module/atelier : ne jamais écraser un stock déjà persisté.
exports('ensureDataStore', function(name, dsType, maxWeight)
    if type(name) ~= "string" then return false end
    local ds = LSLegacy.DataStores[name]
    if not ds then
        LSLegacy.DataStore.RegisterDataStore(name, {
            name = name, type = dsType or 'stash', inventory = {},
            money = 0, dirty = 0, maxWeight = tonumber(maxWeight) or 100,
        })
    else
        if type(ds.inventory) ~= 'table' then ds.inventory = json.decode(ds.inventory) or {} end
        ds.maxWeight = tonumber(maxWeight) or ds.maxWeight
        ds.type = dsType or ds.type
    end
    return true
end)

-- Le client ne reçoit LSLegacy.DataStores qu'au fil des mutations ; on le
-- resynchronise explicitement avant d'ouvrir un conteneur.
exports('syncDataStores', function(src)
    LSLegacy.Events.SendToClient('lslegacy:updateDatastore', src, LSLegacy.DataStores)
end)

exports('dataStoreItemCount', function(name, item)
    local ds = LSLegacy.DataStore.GetDataStore(name)
    if not ds then return 0 end
    local entry = LSLegacy.DataStore.GetInventoryItem(ds, item)
    return entry and entry.count or 0
end)

-- Poids actuel d'un DataStore — pour valider un LOT de plusieurs items en
-- une fois (ex. achat de stock) avant de débiter de l'argent : sommer les
-- poids côté appelant (qui connaît déjà Config.Items) et comparer à
-- (maxWeight - dataStoreWeight) évite le calcul incorrect qu'aurait un
-- CanStoreItem() appelé item par item (chaque appel ignorerait le poids
-- des autres items du même lot pas encore ajoutés).
exports('dataStoreWeight', function(name)
    local ds = LSLegacy.DataStore.GetDataStore(name)
    if not ds then return 0 end
    return LSLegacy.DataStore.GetInventoryWeight(ds.inventory) or 0
end)

exports('addDataStoreItem', function(name, item, count, data, label)
    local ds = LSLegacy.DataStore.GetDataStore(name)
    if not ds then return false end
    if not LSLegacy.Inventory.DoesItemExists(item) then return false end
    if not LSLegacy.DataStore.CanStoreItem(ds, item, count or 1) then return false end
    LSLegacy.DataStore.AddItemInInventory(ds, item, count or 1, label, nil, data)
    return true
end)

exports('removeDataStoreItem', function(name, item, count)
    local ds = LSLegacy.DataStore.GetDataStore(name)
    if not ds then return false end
    local entry = LSLegacy.DataStore.GetInventoryItem(ds, item)
    if not entry or entry.count < (count or 1) then return false end
    LSLegacy.DataStore.RemoveItemInInventory(ds, item, count or 1)
    return true
end)

exports('getDataStoreMoney', function(name)
    local ds = LSLegacy.DataStore.GetDataStore(name)
    if not ds then return 0 end
    return LSLegacy.DataStore.GetMoney(ds)
end)

exports('addDataStoreMoney', function(name, amount)
    local ds = LSLegacy.DataStore.GetDataStore(name)
    if not ds then return false end
    return LSLegacy.DataStore.AddMoney(ds, amount) and true or false
end)

exports('removeDataStoreMoney', function(name, amount)
    local ds = LSLegacy.DataStore.GetDataStore(name)
    if not ds then return false end
    return LSLegacy.DataStore.RemoveMoney(ds, amount) and true or false
end)

-- Facturation : réutilise le menu de paiement du module bank. Le résultat
-- revient à la ressource appelante par un event serveur local.
local registeredKinds = {}

exports('openPaymentMenu', function(target, message, price, kind, refId)
    if not LSLegacy.Bank or not LSLegacy.Bank.OpenPaymentMenu then return false end
    kind = tostring(kind or 'foodapi')

    if not registeredKinds[kind] then
        registeredKinds[kind] = true
        LSLegacy.Bank.RegisterPaymentResultHandler(kind, function(ref, success)
            TriggerEvent('lslegacy:foodapi:paymentResult', kind, ref, success)
        end)
    end

    return LSLegacy.Bank.OpenPaymentMenu(target, message, price, {
        meta = { type = kind, refId = refId },
    }) and true or false
end)

-- Garde d'accès aux conteneurs d'une ressource externe.
-- La ressource enregistre un motif de nom de DataStore + une fonction de
-- contrôle ; foodapi se charge de l'enchaînement avec LSLegacy.DataStoreGuard
-- et du retrait automatique si la ressource s'arrête (sans quoi la référence
-- de fonction resterait dans la chaîne et lèverait une erreur à chaque accès).
local containerGuards = {}   -- [pattern] = { resource = ..., fn = ... }

local previousGuard = LSLegacy.DataStoreGuard
LSLegacy.DataStoreGuard = function(src, name, action, item)
    if type(name) == "string" then
        for pattern, guard in pairs(containerGuards) do
            if name:match(pattern) then
                local ok, allowed = pcall(guard.fn, src, name, action, item)
                if not ok then
                    Dbg(('garde conteneur %s en erreur : %s'):format(pattern, tostring(allowed)))
                    return false
                end
                return allowed and true or false
            end
        end
    end
    if previousGuard then return previousGuard(src, name, action, item) end
    return true
end

exports('registerContainerGuard', function(pattern, fn)
    if type(pattern) ~= "string" or type(fn) ~= "function" then return false end
    containerGuards[pattern] = { resource = GetInvokingResource() or 'lslegacy', fn = fn }
    Dbg(('garde conteneur enregistrée : %s'):format(pattern))
    return true
end)

AddEventHandler('onResourceStop', function(resource)
    for pattern, guard in pairs(containerGuards) do
        if guard.resource == resource then containerGuards[pattern] = nil end
    end
end)

exports('isExpired', function(item, data)
    return LSLegacy.Perishable.IsExpired(item, data)
end)

exports('freshnessSeconds', function(item, data)
    return LSLegacy.Perishable.RemainingSeconds(item, data)
end)
