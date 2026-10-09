-- Menu RageUI de spawn des véhicules Gabz installés sur le serveur.
-- Passe par /car (server/commands.lua), qui gère déjà la permission (niveau 3).

local Categories = {}
local CategoryOrder = { "Civil", "Police", "EMS", "Pompiers", "Taxi" }
local CategoryByKey = {}

for _, key in ipairs(CategoryOrder) do
    local cat = { key = key, items = {} }
    Categories[#Categories + 1] = cat
    CategoryByKey[key] = cat
end

for _, veh in ipairs(GabzVehicles) do
    local cat = CategoryByKey[veh.category]
    if cat then
        table.insert(cat.items, veh)
    end
end

for _, cat in ipairs(Categories) do
    table.sort(cat.items, function(a, b) return a.label < b.label end)
end

local GabzMenu = {
    opened = false,
    rendering = false,
}

GabzMenu.mainMenu = RageUI.CreateMenu("Véhicules Gabz", "Sélectionnez une catégorie")
GabzMenu.mainMenu.Display.Header = true

for _, cat in ipairs(Categories) do
    cat.subMenu = RageUI.CreateSubMenu(GabzMenu.mainMenu, cat.key, #cat.items .. " véhicule(s)")
    cat.subMenu:AcceptFilter(true)
end

GabzMenu.mainMenu.Closed = function()
    GabzMenu.opened = false
end

function GabzMenu:Toggle()
    if GabzMenu.opened then
        GabzMenu.opened = false
        RageUI.CloseAll()
        return
    end

    GabzMenu.opened = true
    RageUI.Visible(GabzMenu.mainMenu, true)

    if GabzMenu.rendering then return end
    GabzMenu.rendering = true

    CreateThread(function()
        while GabzMenu.rendering do
            Wait(0)

            RageUI.IsVisible(GabzMenu.mainMenu, function()
                for _, cat in ipairs(Categories) do
                    RageUI.Button(cat.key, #cat.items .. " véhicule(s)", { RightLabel = "→" }, true, {}, cat.subMenu)
                end
            end)

            for _, cat in ipairs(Categories) do
                RageUI.IsVisible(cat.subMenu, function()
                    for _, veh in ipairs(cat.items) do
                        RageUI.Button(veh.label, veh.model, {}, true, {
                            onSelected = function()
                                ExecuteCommand("car " .. veh.model)
                            end,
                        })
                    end
                end)
            end

            if not RageUI.GetInMenu() then
                GabzMenu.rendering = false
                GabzMenu.opened = false
            end
        end
    end)
end

RegisterCommand("gabz", function()
    GabzMenu:Toggle()
end, false)
