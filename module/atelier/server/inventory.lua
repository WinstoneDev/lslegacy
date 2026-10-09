-- Un DataStore LSLegacy par entreprise, exposé comme un vrai second inventaire
-- (coffre du module inventory/, drag&drop) plutôt qu'un menu ox_lib : le stock
-- réel des pièces vit dans ce DataStore, et les pièces prises atterrissent
-- normalement dans l'inventaire du mécano (comme n'importe quel autre item).
--
-- Les pièces "carried" (carrosserie) se tiennent en main via un item usable
-- classique (LSLegacy.RegisterUsableItem, cf. plus bas) : purement cosmétique,
-- la pièce reste un item normal tant qu'elle n'est pas posée. La consommation
-- réelle a lieu à la pose (server/repairs.lua), qui pioche directement dans
-- l'inventaire du mécano — il n'y a donc plus de "réservation" à gérer ici.

local function StashName(companyId)
    local company = Config.Atelier.Companies[companyId]
    return company and company.stashName or nil
end

-- companyId indexé par nom de DataStore, pour la garde d'accès ci-dessous.
local CompanyByStash = {}
for companyId, company in pairs(Config.Atelier.Companies) do
    if company.stashName then CompanyByStash[company.stashName] = companyId end
end

-- Chargement paresseux à dessein : LSLegacy.DataStores se charge en async au démarrage,
-- un enregistrement tenté trop tôt écraserait un stock déjà persisté (même pattern que
-- module/keyhanger/server/main.lua).
local function EnsureStash(companyId)
    local name = StashName(companyId)
    if not name then return nil end
    local ds = LSLegacy.DataStores[name]
    if not ds then
        LSLegacy.DataStore.RegisterDataStore(name, {
            inventory = {}, name = name, type = 'atelier_stock',
            money = 0, dirty = 0, maxWeight = Config.Atelier.StashMaxWeight,
        })
        ds = LSLegacy.DataStores[name]
    else
        if type(ds.inventory) ~= 'table' then ds.inventory = json.decode(ds.inventory) or {} end
        ds.maxWeight = Config.Atelier.StashMaxWeight
    end
    return ds
end

-- Exposée pour server/tuning.lua : le solde `money` de ce même stash sert de
-- caisse "société" pour le panier de tuning (option de paiement entreprise).
-- Exposée aussi pour module/mdt/server/parts.lua (livraison des commandes).
LSLegacy.Atelier.GetStash = EnsureStash

-- Garde d'accès générique : les stashes atelier_* deviennent un coffre normal
-- (module inventory/), ouvert uniquement au mécano de LA MÊME entreprise ET
-- physiquement près du dépôt — même logique que le coffre de voiture
-- (inventory/server/main.lua -> trunk_<plaque>, proximité au véhicule plutôt
-- qu'un statut "en service" qui peut avoir expiré/changé entre l'ouverture du
-- coffre et un put/take individuel).
local function IsNearDepot(src, companyId)
    local company = Config.Atelier.Companies[companyId]
    if not company or not company.partsDepotCoords then return false end
    local ped = GetPlayerPed(src)
    if not DoesEntityExist(ped) then return false end
    return LSLegacy.Validate.Distance(company.partsDepotCoords, GetEntityCoords(ped), 5.0)
end

local prevGuard = LSLegacy.DataStoreGuard
LSLegacy.DataStoreGuard = function(src, name, action, item)
    local companyId = CompanyByStash[name]
    if companyId then
        if item ~= nil and not Config.Atelier.Parts[item] then return false end
        if LSLegacy.Atelier.GetCompany(src) ~= companyId then return false end
        return IsNearDepot(src, companyId)
    end
    if prevGuard then return prevGuard(src, name, action, item) end
    return true
end

-- Ouverture du dépôt (coffre) — le client ne connaît pas le nom du DataStore,
-- il demande juste l'ouverture, le serveur résout l'entreprise du mécano.
LSLegacy.Events.Register('atelier:openDepot', function()
    local src = source
    local ok, companyId = LSLegacy.Atelier.CanAct(src)
    if not ok then
        LSLegacy.Atelier.Notify(src, Lang.Atelier.not_on_duty, 'error')
        return
    end

    local ds = EnsureStash(companyId)
    if not ds then return end

    -- Le client ne reçoit LSLegacy.DataStores qu'au fil des mutations ; on le
    -- resynchronise explicitement avant d'ouvrir le coffre (même pattern que
    -- module/foodapi/server/main.lua -> exports('syncDataStores', ...)).
    LSLegacy.Events.SendToClient('lslegacy:updateDatastore', src, LSLegacy.DataStores)
    LSLegacy.Events.SendToClient('atelier:openContainer', src, ds.name, Lang.Atelier.depot_title, ds.maxWeight)
end)

-- Pièces "carried" (carrosserie) : tenues en main via un item usable classique.
-- Purement visuel — la pièce reste dans l'inventaire tant qu'elle n'est pas
-- posée (server/repairs.lua la consomme réellement à la pose).
for itemName, part in pairs(Config.Atelier.Parts) do
    if part.carried then
        LSLegacy.RegisterUsableItem(itemName, function()
            local src = source
            local ok = LSLegacy.Atelier.CanAct(src)
            if not ok then
                LSLegacy.Atelier.Notify(src, Lang.Atelier.not_on_duty, 'error')
                return
            end
            LSLegacy.Events.SendToClient('atelier:partTaken', src, { item = itemName, carried = true })
        end)
    end
end

