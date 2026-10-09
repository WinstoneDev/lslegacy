--  MODULE POLICE NATIONALE — Armurerie
--  3 PNJ : Armurier (accessoires, libre), Chef de poste (équipement
--  personnel + stock collectif police), Armurier RAID (accessoires +
--  personnel + stock collectif RAID/BRI). Toute la logique d'accès
--  (formation, unité, stock) est revalidée côté serveur.

local function Notify(msg, type)
    TriggerEvent('notify', 'Police Nationale', msg, type or 'info', Config.Police.NotifyDuration or 30000)
end

local function ItemLabel(item)
    local def = Config.Items and Config.Items[item]
    return def and def.label or item
end

-- Quelle(s) arme(s) accepte(nt) ce composant (déduit de Config.WeaponComponents,
-- partagé avec le système d'attache d'accessoires déjà existant côté inventaire).
local function CompatibleWeapons(componentItem)
    local weapons = {}
    for weaponName, list in pairs(Config.WeaponComponents or {}) do
        for _, def in ipairs(list) do
            if def.item == componentItem then weapons[#weapons + 1] = weaponName end
        end
    end
    return weapons
end

local INSTALL_ANIM_DICT = 'mini@repair'
local INSTALL_ANIM_CLIP = 'fixing_a_ped'

local function PlayInstallAnim(pnj)
    local ped = PoliceArmoryPeds and PoliceArmoryPeds[pnj]
    if not ped or not DoesEntityExist(ped) then return end
    RequestAnimDict(INSTALL_ANIM_DICT)
    WaitUntil(function() return HasAnimDictLoaded(INSTALL_ANIM_DICT) end, 2000, 0)
    TaskPlayAnim(ped, INSTALL_ANIM_DICT, INSTALL_ANIM_CLIP, 8.0, -8.0, 3000, 0, 0, false, false, false)
end

local function OpenWeaponPicker(pnj, componentItem)
    local weaponNames = CompatibleWeapons(componentItem)
    local options = {}
    for _, inv in pairs(LSLegacy.PlayerData.inventory or {}) do
        for _, weaponName in ipairs(weaponNames) do
            if inv.name == weaponName then
                options[#options + 1] = {
                    title = inv.label or ItemLabel(weaponName),
                    onSelect = function()
                        PlayInstallAnim(pnj)
                        LSLegacy.Events.SendToServer('police:armory:attachAccessory', {
                            pnj = pnj, componentItem = componentItem,
                            weaponUniqueId = inv.uniqueId, weaponName = weaponName,
                        })
                    end,
                }
            end
        end
    end
    if #options == 0 then
        Notify("Vous n'avez pas d'arme compatible avec cet accessoire.", 'error')
        return
    end
    lib.registerContext({ id = 'armory_weapon_picker', title = 'Choisir l\'arme', options = options })
    lib.showContext('armory_weapon_picker')
end

local PNJ_TITLES = {
    armurier = 'Armurier — Accessoires',
    chef     = 'Chef de poste',
    raid     = 'Armurier RAID',
}

local function BuildMenu(state)
    local options = {}

    for _, item in ipairs(state.accessories or {}) do
        options[#options + 1] = {
            title = ItemLabel(item),
            description = 'Installation directe sur une arme de votre inventaire',
            onSelect = function() OpenWeaponPicker(state.pnj, item) end,
        }
    end

    for _, entry in ipairs(state.personal or {}) do
        if entry.taken then
            options[#options + 1] = {
                title = 'Ranger — ' .. entry.label,
                onSelect = function()
                    LSLegacy.Events.SendToServer('police:armory:personalAction', { pnj = state.pnj, item = entry.item, action = 'deposit' })
                end,
            }
        else
            options[#options + 1] = {
                title = 'Retirer — ' .. entry.label,
                description = (not entry.trained) and 'Formation requise' or nil,
                disabled = not entry.trained,
                onSelect = function()
                    LSLegacy.Events.SendToServer('police:armory:personalAction', { pnj = state.pnj, item = entry.item, action = 'take' })
                end,
            }
        end
    end

    for _, entry in ipairs(state.collective or {}) do
        options[#options + 1] = {
            title = 'Retirer — ' .. entry.label,
            description = ('Stock : %d/%d'):format(entry.stock, entry.maxStock) .. (not entry.trained and ' — Formation requise' or ''),
            disabled = not entry.trained or entry.stock <= 0,
            onSelect = function()
                LSLegacy.Events.SendToServer('police:armory:collectiveAction', { pnj = state.pnj, item = entry.item, action = 'take' })
            end,
        }
        options[#options + 1] = {
            title = 'Déposer — ' .. entry.label,
            onSelect = function()
                LSLegacy.Events.SendToServer('police:armory:collectiveAction', { pnj = state.pnj, item = entry.item, action = 'deposit' })
            end,
        }
    end

    return options
end

LSLegacy.Events.Register('police:armory:state', function(state)
    lib.registerContext({ id = 'armory_menu', title = PNJ_TITLES[state.pnj] or 'Armurerie', options = BuildMenu(state) })
    lib.showContext('armory_menu')
end)
