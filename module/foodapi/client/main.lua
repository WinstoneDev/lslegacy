-- module/foodapi (client) — miroir du registre d'items et lecture de la
-- fraîcheur. Le client n'est jamais autoritatif : ces tables servent
-- uniquement à l'affichage (inventaire NUI, module/needs, poids).

local C = Config.FoodAPI
local P = C.Perishable

LSLegacy.Food = LSLegacy.Food or {}
LSLegacy.Food.Owners = LSLegacy.Food.Owners or {}

LSLegacy.Perishable = LSLegacy.Perishable or {}
LSLegacy.Perishable.Items = LSLegacy.Perishable.Items or {}

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
            end
            if def.perishable then
                LSLegacy.Perishable.Items[name] = { shelfLife = tonumber(def.shelfLife) or P.DefaultShelfLife }
            end
            LSLegacy.Food.Owners[owner][#LSLegacy.Food.Owners[owner] + 1] = name
            n = n + 1
        end
    end
    if C.Debug then print(('[foodapi] %s: %d item(s) côté client'):format(tostring(owner), n)) end
    return n
end

AddEventHandler('onClientResourceStop', function(resource)
    local owned = LSLegacy.Food.Owners[resource]
    if not owned then return end
    for _, name in ipairs(owned) do
        Config.Items[name] = nil
        Config.InsertItems[name] = nil
        Config.NeedsItems[name] = nil
        LSLegacy.Perishable.Items[name] = nil
    end
    LSLegacy.Food.Owners[resource] = nil
end)

---Budget restant (secondes) — même formule que côté serveur, avec l'heure
---UTC du client (GetCloudTimeAsInt) pour éviter l'horloge locale décalée.
local function Budget(fresh, item)
    if type(fresh) ~= "table" then return nil end
    local b = tonumber(fresh.b) or 0
    local t = tonumber(fresh.t) or 0
    local r = tonumber(fresh.r) or 1.0
    local left = b - ((GetCloudTimeAsInt() - t) * r)
    if left < 0 then left = 0 end
    return left, r
end

---RemainingSeconds — temps réel restant, -1 si conservation illimitée,
---nil si l'item n'est pas périssable.
LSLegacy.Perishable.RemainingSeconds = function(item, data)
    local fresh = data and data.fresh
    if type(fresh) ~= "table" then return nil end
    local left, rate = Budget(fresh, item)
    if not rate or rate <= 0 then return -1 end
    return left / rate
end

LSLegacy.Perishable.IsExpired = function(item, data)
    local remaining = LSLegacy.Perishable.RemainingSeconds(item, data)
    return remaining ~= nil and remaining >= 0 and remaining <= 0
end

exports('registerItems', function(items)
    local owner = GetInvokingResource() or 'lslegacy'
    return LSLegacy.Food.RegisterItems(owner, items)
end)

exports('freshnessSeconds', function(item, data)
    return LSLegacy.Perishable.RemainingSeconds(item, data)
end)

-- ─────────────────────────────────────────────────────────────────────────
--  Bascule de service MDT pour un job d'une ressource externe
-- ─────────────────────────────────────────────────────────────────────────
-- LSLegacy.MDT.DutyToggles (module/mdt) attend des FONCTIONS Lua par job —
-- ça marche pour les modules internes (atelier, police…) qui tournent dans
-- le même environnement que mdt, mais une fonction d'une ressource externe
-- ne peut pas être stockée telle quelle : les exports ne garantissent le
-- passage fiable que de valeurs primitives, jamais de closures rappelables
-- plus tard. On stocke donc seulement le NOM de la ressource, et
-- module/mdt/client/main.lua appelle exports[resource]['toggleDuty_'..job]()/
-- ['isOnDuty_'..job]() par son nom au moment du clic — la ressource externe
-- doit exposer ces deux exports elle-même, SUFFIXÉS PAR LE JOB (voir
-- ls_kebabking/client/main.lua). Le suffixe est indispensable : ls_burgershot,
-- ls_aldentes et ls_kebabking tournent tous les trois DANS la ressource
-- lslegacy elle-même (fusion) — GetInvokingResource() y vaut donc toujours
-- nil/'lslegacy' pour chacun, et un export nommé pareil pour deux jobs
-- écraserait silencieusement le premier (c'est exactement ce qui s'est
-- produit avant ce correctif : le bouton "service" de Burger Shot appelait
-- en réalité le toggle de Kebab King).

local externalDutyResources = {}   -- [job] = resource

exports('registerClientDuty', function(job)
    if type(job) ~= "string" then return false end
    externalDutyResources[job] = GetInvokingResource() or 'lslegacy'
    return true
end)

LSLegacy.MDT = LSLegacy.MDT or {}

---ExternalToggleDuty — déclenche la bascule côté ressource externe.
---@param job string
---@return boolean ok
LSLegacy.MDT.ExternalToggleDuty = function(job)
    local resource = job and externalDutyResources[job]
    if not resource or GetResourceState(resource) ~= 'started' then return false end
    return pcall(function() exports[resource]['toggleDuty_' .. job]() end)
end

---ExternalIsOnDuty
---@param job string
---@return boolean|nil
LSLegacy.MDT.ExternalIsOnDuty = function(job)
    local resource = job and externalDutyResources[job]
    if not resource or GetResourceState(resource) ~= 'started' then return nil end
    local ok, result = pcall(function() return exports[resource]['isOnDuty_' .. job]() end)
    if not ok then return nil end
    return result == true
end

AddEventHandler('onClientResourceStop', function(resource)
    for job, owner in pairs(externalDutyResources) do
        if owner == resource then externalDutyResources[job] = nil end
    end
end)
