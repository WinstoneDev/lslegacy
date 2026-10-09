-- Parcours d'obstacles (formateurs police, CZ001) : sauvegarde/chargement de dispositions de props réutilisables.

LSLegacy.Security.RegisterRateLimit('obstacles:requestCourses', 10)
LSLegacy.Security.RegisterRateLimit('obstacles:requestLoad', 10)
LSLegacy.Security.RegisterRateLimit('obstacles:save', 5)
LSLegacy.Security.RegisterRateLimit('obstacles:deleteCourse', 5)

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS `obstacles_courses` (
        `id`         INT(11)      NOT NULL AUTO_INCREMENT,
        `name`       VARCHAR(100) NOT NULL,
        `job`        VARCHAR(50)  NOT NULL DEFAULT 'police',
        `created_by` VARCHAR(60)  DEFAULT NULL,
        `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uq_obstacles_name_job` (`name`, `job`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]], {})

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS `obstacles_course_props` (
        `id`        INT(11)      NOT NULL AUTO_INCREMENT,
        `course_id` INT(11)      NOT NULL,
        `model`     VARCHAR(100) NOT NULL,
        `pos_x`     DOUBLE       NOT NULL,
        `pos_y`     DOUBLE       NOT NULL,
        `pos_z`     DOUBLE       NOT NULL,
        `rot_x`     DOUBLE       NOT NULL DEFAULT 0,
        `rot_y`     DOUBLE       NOT NULL DEFAULT 0,
        `rot_z`     DOUBLE       NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_ocp_course` (`course_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]], {})

local JOB  = Config.Obstacles.Job
local CODE = Config.Obstacles.TrainingCode

local function Notify(src, msg, t)
    LSLegacy.Events.SendToClient('notify', src, 'Parcours', msg, t or 'info', 5000)
end

-- Revalide job + formation CZ001 depuis la BDD, jamais depuis ce que le client prétend avoir.
local function CheckAccess(src, cb)
    local player = LSLegacy.Players.Get(src)
    if not player or not LSLegacy.Jobs.Is(player, JOB) then
        Notify(src, "Vous n'avez pas accès à ce menu.", 'error')
        return cb(nil)
    end
    local charId = player["boutique-id"]
    MySQL.Async.fetchScalar('SELECT 1 FROM mdt_agent_skills WHERE character_id=@id AND code=@code LIMIT 1', {
        ['@id'] = charId, ['@code'] = CODE,
    }, function(has)
        if not has then
            Notify(src, "Formation " .. CODE .. " requise.", 'error')
            return cb(nil)
        end
        cb(player)
    end)
end

LSLegacy.Events.Register('obstacles:requestCourses', function()
    local src = source
    CheckAccess(src, function(player)
        if not player then return end
        MySQL.Async.fetchAll('SELECT id, name FROM obstacles_courses WHERE job=@job ORDER BY name ASC', {
            ['@job'] = JOB,
        }, function(rows)
            LSLegacy.Events.SendToClient('obstacles:coursesResult', src, rows or {})
        end)
    end)
end)

LSLegacy.Events.Register('obstacles:requestLoad', function(courseId)
    local src = source
    courseId = tonumber(courseId)
    if not courseId then return end
    CheckAccess(src, function(player)
        if not player then return end
        MySQL.Async.fetchAll('SELECT model, pos_x, pos_y, pos_z, rot_x, rot_y, rot_z FROM obstacles_course_props WHERE course_id=@id', {
            ['@id'] = courseId,
        }, function(rows)
            LSLegacy.Events.SendToClient('obstacles:loadResult', src, courseId, rows or {})
        end)
    end)
end)

-- data = { courseId = number|nil, name = string, props = { {model,x,y,z,rx,ry,rz}, ... } }
LSLegacy.Events.Register('obstacles:save', function(data)
    local src = source
    if type(data) ~= 'table' or type(data.name) ~= 'string' then return end
    local name = data.name:sub(1, 100):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then return Notify(src, 'Nom de parcours invalide.', 'error') end

    local props = {}
    if type(data.props) == 'table' then
        for _, p in ipairs(data.props) do
            if type(p) == 'table' and Config.Obstacles.PropByModel[p.model] then
                props[#props + 1] = {
                    model = p.model,
                    x = tonumber(p.x) or 0.0, y = tonumber(p.y) or 0.0, z = tonumber(p.z) or 0.0,
                    rx = tonumber(p.rx) or 0.0, ry = tonumber(p.ry) or 0.0, rz = tonumber(p.rz) or 0.0,
                }
            end
        end
    end
    if #props == 0 then return Notify(src, 'Aucun prop à sauvegarder.', 'error') end

    CheckAccess(src, function(player)
        if not player then return end

        MySQL.Async.execute(
            'INSERT INTO obstacles_courses (name, job, created_by) VALUES (@name, @job, @by) '
            .. 'ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP',
            { ['@name'] = name, ['@job'] = JOB, ['@by'] = player.identifier },
            function()
                MySQL.Async.fetchScalar('SELECT id FROM obstacles_courses WHERE name=@name AND job=@job', {
                    ['@name'] = name, ['@job'] = JOB,
                }, function(courseId)
                    if not courseId then return Notify(src, 'Échec de la sauvegarde.', 'error') end

                    MySQL.Async.execute('DELETE FROM obstacles_course_props WHERE course_id=@id', { ['@id'] = courseId }, function()
                        for _, p in ipairs(props) do
                            MySQL.Async.execute(
                                'INSERT INTO obstacles_course_props (course_id, model, pos_x, pos_y, pos_z, rot_x, rot_y, rot_z) '
                                .. 'VALUES (@course, @model, @x, @y, @z, @rx, @ry, @rz)',
                                {
                                    ['@course'] = courseId, ['@model'] = p.model,
                                    ['@x'] = p.x, ['@y'] = p.y, ['@z'] = p.z,
                                    ['@rx'] = p.rx, ['@ry'] = p.ry, ['@rz'] = p.rz,
                                }
                            )
                        end
                        Notify(src, 'Parcours "' .. name .. '" sauvegardé (' .. #props .. ' props).', 'success')
                        LSLegacy.Events.SendToClient('obstacles:saved', src, courseId, name)
                    end)
                end)
            end
        )
    end)
end)

LSLegacy.Events.Register('obstacles:deleteCourse', function(courseId)
    local src = source
    courseId = tonumber(courseId)
    if not courseId then return end
    CheckAccess(src, function(player)
        if not player then return end
        MySQL.Async.execute('DELETE FROM obstacles_course_props WHERE course_id=@id', { ['@id'] = courseId })
        MySQL.Async.execute('DELETE FROM obstacles_courses WHERE id=@id AND job=@job', { ['@id'] = courseId, ['@job'] = JOB }, function()
            Notify(src, 'Parcours supprimé.', 'success')
            LSLegacy.Events.SendToClient('obstacles:courseDeleted', src, courseId)
        end)
    end)
end)
