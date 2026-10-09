-- Menu formateur /parcours : pose de props (parcours d'obstacles), ciblage ox_target (supprimer/dupliquer/modifier), sauvegarde/chargement réutilisable en BDD.

local oxTarget = exports.ox_target

-- Session en cours : props actuellement affichés depuis l'ouverture du menu (nouveaux ou chargés d'un parcours existant).
local Session = { courseId = nil, name = nil }
local PropData = {} -- [entity] = { model = string }

local function AddPropTarget(entity, model)
    PropData[entity] = { model = model }
    oxTarget:addLocalEntity(entity, {
        {
            name = 'obstacles_delete',
            icon = 'fa-solid fa-trash',
            label = 'Supprimer',
            distance = 3.0,
            onSelect = function() Obstacles.RemoveProp(entity) end,
        },
        {
            name = 'obstacles_duplicate',
            icon = 'fa-solid fa-copy',
            label = 'Dupliquer',
            distance = 3.0,
            onSelect = function() Obstacles.DuplicateProp(entity) end,
        },
        {
            name = 'obstacles_modify',
            icon = 'fa-solid fa-arrows-up-down-left-right',
            label = 'Modifier',
            distance = 3.0,
            onSelect = function() Obstacles.ModifyProp(entity) end,
        },
    })
end

function Obstacles.RemoveProp(entity)
    if not DoesEntityExist(entity) then return end
    NetworkRequestControlOfEntity(entity)
    local t = 0
    while not NetworkHasControlOfEntity(entity) and t < 50 do Wait(10); t = t + 1 end
    PropData[entity] = nil
    DeleteEntity(entity)
end

function Obstacles.DuplicateProp(entity)
    local data = PropData[entity]
    if not data then return end
    Obstacles.RunPlacement(data.model, nil, function(newEntity, coords, rot)
        AddPropTarget(newEntity, data.model)
        Obstacles.OpenMainMenu()
    end, function() Obstacles.OpenMainMenu() end)
end

function Obstacles.ModifyProp(entity)
    local data = PropData[entity]
    if not data then return end
    local originalCoords = GetEntityCoords(entity)
    local originalRot = GetEntityRotation(entity, 2)
    oxTarget:removeLocalEntity(entity)
    NetworkRequestControlOfEntity(entity)
    Obstacles.RunPlacement(data.model, entity, function(movedEntity, coords, rot)
        AddPropTarget(movedEntity, data.model)
        Obstacles.OpenMainMenu()
    end, function()
        SetEntityCoords(entity, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, false)
        SetEntityRotation(entity, originalRot.x, originalRot.y, originalRot.z, 2, true)
        AddPropTarget(entity, data.model)
        Obstacles.OpenMainMenu()
    end)
end

local function RemoveAllDisplayedProps()
    for entity in pairs(PropData) do
        if DoesEntityExist(entity) then
            NetworkRequestControlOfEntity(entity)
            DeleteEntity(entity)
        end
    end
    PropData = {}
    Session.courseId = nil
    Session.name = nil
end

-- ── Menus ox_lib ─────────────────────────────────────────────────────

local function OpenCatalogMenu()
    local options = {}
    for _, p in ipairs(Config.Obstacles.Props) do
        options[#options + 1] = {
            title = p.Label,
            icon = 'fa-solid fa-cube',
            onSelect = function()
                Obstacles.RunPlacement(p.Model, nil, function(entity)
                    AddPropTarget(entity, p.Model)
                    Obstacles.OpenMainMenu()
                end, function() Obstacles.OpenMainMenu() end)
            end,
        }
    end
    lib.registerContext({ id = 'obstacles_catalog', title = 'Ajouter un prop', menu = 'obstacles_main', options = options })
    lib.showContext('obstacles_catalog')
end

local function DoSave()
    local count = 0
    for _ in pairs(PropData) do count = count + 1 end
    if count == 0 then
        return LSLegacy.ShowNotification('Parcours', 'Aucun prop à sauvegarder.', 'error')
    end
    local input = lib.inputDialog('Sauvegarder le parcours', {
        { type = 'input', label = 'Nom du parcours', default = Session.name or '', required = true, max = 100 },
    })
    if not input or not input[1] or input[1] == '' then return end

    local props = {}
    for entity, data in pairs(PropData) do
        if DoesEntityExist(entity) then
            local coords = GetEntityCoords(entity)
            local rot = GetEntityRotation(entity, 2)
            props[#props + 1] = { model = data.model, x = coords.x, y = coords.y, z = coords.z, rx = rot.x, ry = rot.y, rz = rot.z }
        end
    end
    Session.name = input[1]
    LSLegacy.Events.SendToServer('obstacles:save', { name = Session.name, courseId = Session.courseId, props = props })
end

local function OpenLoadMenu()
    LSLegacy.Events.SendToServer('obstacles:requestCourses')
end

local function OpenManageMenu()
    LSLegacy.Events.SendToServer('obstacles:requestCourses')
    Obstacles.ManageMode = true
end

function Obstacles.OpenMainMenu()
    local options = {
        {
            title = 'Ajouter un prop',
            icon = 'fa-solid fa-plus',
            onSelect = OpenCatalogMenu,
        },
        {
            title = 'Charger un parcours',
            icon = 'fa-solid fa-folder-open',
            onSelect = function() Obstacles.ManageMode = false; OpenLoadMenu() end,
        },
        {
            title = 'Terminer et sauvegarder',
            icon = 'fa-solid fa-floppy-disk',
            onSelect = DoSave,
        },
        {
            title = 'Retirer les props affichés',
            icon = 'fa-solid fa-eraser',
            description = 'Dépop les props du monde (le parcours reste sauvegardé)',
            onSelect = RemoveAllDisplayedProps,
        },
        {
            title = 'Gérer les parcours',
            icon = 'fa-solid fa-trash-can',
            description = 'Supprimer définitivement un parcours sauvegardé',
            onSelect = OpenManageMenu,
        },
    }
    lib.registerContext({ id = 'obstacles_main', title = 'Parcours d\'obstacles', options = options })
    lib.showContext('obstacles_main')
end

LSLegacy.Events.Register('obstacles:coursesResult', function(courses)
    local manage = Obstacles.ManageMode
    local options = {}
    for _, c in ipairs(courses) do
        if manage then
            options[#options + 1] = {
                title = c.name,
                icon = 'fa-solid fa-trash',
                onSelect = function()
                    local ok = lib.alertDialog({ header = 'Supprimer "' .. c.name .. '" ?', content = 'Suppression définitive.', centered = true, cancel = true })
                    if ok == 'confirm' then
                        LSLegacy.Events.SendToServer('obstacles:deleteCourse', c.id)
                    end
                end,
            }
        else
            options[#options + 1] = {
                title = c.name,
                icon = 'fa-solid fa-folder',
                onSelect = function()
                    LSLegacy.Events.SendToServer('obstacles:requestLoad', c.id)
                end,
            }
        end
    end
    if #options == 0 then
        options[1] = { title = 'Aucun parcours sauvegardé', disabled = true }
    end
    lib.registerContext({ id = 'obstacles_courses', title = manage and 'Gérer les parcours' or 'Charger un parcours', menu = 'obstacles_main', options = options })
    lib.showContext('obstacles_courses')
end)

LSLegacy.Events.Register('obstacles:loadResult', function(courseId, rows)
    RemoveAllDisplayedProps()
    Session.courseId = courseId

    for _, r in ipairs(rows) do
        local hash = GetHashKey(r.model)
        RequestModel(hash)
        local t = 0
        while not HasModelLoaded(hash) and t < 200 do Wait(10); t = t + 1 end
        if HasModelLoaded(hash) then
            local entity = CreateObject(hash, r.pos_x, r.pos_y, r.pos_z, true, true, false)
            SetEntityRotation(entity, r.rot_x, r.rot_y, r.rot_z, 2, true)
            FreezeEntityPosition(entity, true)
            SetModelAsNoLongerNeeded(hash)
            AddPropTarget(entity, r.model)
        end
    end
    LSLegacy.ShowNotification('Parcours', ('Parcours chargé (%d props).'):format(#rows), 'success')
end)

LSLegacy.Events.Register('obstacles:saved', function(courseId, name)
    Session.courseId = courseId
    Session.name = name
end)

LSLegacy.Events.Register('obstacles:courseDeleted', function(courseId)
    if Session.courseId == courseId then
        Session.courseId = nil
        Session.name = nil
    end
end)

RegisterCommand('parcours', function()
    Obstacles.OpenMainMenu()
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for entity in pairs(PropData) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
end)
