-- module/grossiste — Helpers partagés client/serveur.

GR = GR or {}

---GetCatalogEntry
---@param item string
---@return table|nil
function GR.GetCatalogEntry(item)
    if type(item) ~= 'string' then return nil end
    return GRConfig.CatalogByItem[item]
end

---ItemLabel — libellé d'un item. Le catalogue répète son propre `label`
---(voir config/catalog.lua) : le client n'a jamais chargé le registre
---d'items du module propriétaire pour les items définis ailleurs.
---@param item string
---@return string
function GR.ItemLabel(item)
    local def = GRConfig.Items[item]
    if def then return def.label end
    local entry = GR.GetCatalogEntry(item)
    return (entry and entry.label) or item
end
