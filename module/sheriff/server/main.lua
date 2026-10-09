--  MODULE BLAINE COUNTY SHERIFF'S OFFICE — Serveur principal
--  Création de la table SQL, gestion de la prise de service.
--  SÉCURITÉ : le job et le grade sont toujours relus depuis
--  LSLegacy.ServerPlayers, jamais depuis le client.

LSLegacy.Security.RegisterRateLimit('sheriff:onDuty', 10)
LSLegacy.Security.RegisterRateLimit('sheriff:offDuty', 10)

local Deputies = {}   -- { [source] = { onDuty, grade, name } }

-- Helpers sécurité

local function GetPlayer(src)
    return LSLegacy.Players.Get(src)
end

local function IsSheriffAgent(src)
    local p = GetPlayer(src)
    return LSLegacy.Jobs.Is(p, Config.Sheriff.Job)
end

local function GetGrade(src)
    local p = GetPlayer(src)
    return p and (tonumber(LSLegacy.Jobs.GetGrade(p)) or 0) or 0
end

local function GetName(src)
    local p = GetPlayer(src)
    if p and p.characterInfos then
        return ((p.characterInfos.Prenom or '') .. ' ' .. (p.characterInfos.NDF or ''))
    end
    return GetPlayerName(src) or 'Deputy'
end

local function GetIdentifier(src)
    local p = GetPlayer(src)
    return p and p.identifier or nil
end

-- Clé "personnage" (players.id) : identifier seul ne suffit plus depuis le
-- multicharacter, plusieurs personnages d'un même compte partagent le
-- même identifier.
local function GetCharacterId(src)
    local p = GetPlayer(src)
    return p and p["boutique-id"] or nil
end

-- Création de la table SQL

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS sheriff_deputies (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        identifier    VARCHAR(60)  NOT NULL,
        character_id  INT          DEFAULT NULL,
        name          VARCHAR(100) NOT NULL DEFAULT '',
        unit          VARCHAR(60)  DEFAULT NULL,
        on_duty       TINYINT(1)   NOT NULL DEFAULT 0,
        duty_since    DATETIME     DEFAULT NULL,
        last_seen     DATETIME     DEFAULT NULL,
        UNIQUE KEY uq_sd_character (character_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- Redémarrage serveur : personne n'est réellement en service, on remet la
-- table à plat pour ne pas laisser d'agents fantômes dans les effectifs.
MySQL.Async.execute('UPDATE sheriff_deputies SET on_duty=0', {})

-- PRISE DE SERVICE

LSLegacy.Events.Register('sheriff:onDuty', function()
    local src = source
    if not IsSheriffAgent(src) then return end

    local grade  = GetGrade(src)
    local ident  = GetIdentifier(src)
    local charId = GetCharacterId(src)
    local name   = GetName(src)

    -- L'unité vient de l'affectation active gérée par la hiérarchie dans le
    -- MDT (fiche agent), à défaut Patrol Deputies (unité de base).
    MySQL.Async.fetchScalar(
        "SELECT code FROM mdt_agent_assignments WHERE character_id=@id AND end_date='' ORDER BY id DESC LIMIT 1",
        { ['@id'] = charId },
        function(unitCode)
            local unit = unitCode or 'patrol'

            Deputies[src] = { onDuty = true, grade = grade, name = name, unit = unit }

            -- Statebag autoritaire, lisible par n'importe quelle ressource (même
            -- convention que `policeOnDuty`).
            Player(src).state:set('sheriffOnDuty', true, true)

            MySQL.Async.execute(
                'INSERT INTO sheriff_deputies (identifier, character_id, name, unit, on_duty, duty_since, last_seen) ' ..
                'VALUES (@id, @charId, @name, @unit, 1, NOW(), NOW()) ' ..
                'ON DUPLICATE KEY UPDATE identifier=@id, name=@name, unit=@unit, on_duty=1, duty_since=NOW(), last_seen=NOW()',
                { ['@id'] = ident, ['@charId'] = charId, ['@name'] = name, ['@unit'] = unit }
            )

            TriggerClientEvent('sheriff:onDutyResult', src, { unit = unit })
        end
    )
end)

LSLegacy.Events.Register('sheriff:offDuty', function()
    local src = source
    if not Deputies[src] then return end

    Player(src).state:set('sheriffOnDuty', false, true)

    MySQL.Async.execute(
        'UPDATE sheriff_deputies SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
        { ['@id'] = GetCharacterId(src) }
    )
    Deputies[src] = nil
end)

-- État exposé aux autres modules

function GetDeputies() return Deputies end

-- Nom attendu par le registre DUTY_CHECKERS du cœur MDT (effectifs,
-- tableau de bord).
function IsDeputyOnDuty(src)
    return Deputies[src] ~= nil and Deputies[src].onDuty == true
end

function IsSheriffJob(src) return IsSheriffAgent(src) == true end

-- Nettoyage à la déconnexion
AddEventHandler('playerDropped', function()
    local src = source
    if Deputies[src] then
        MySQL.Async.execute(
            'UPDATE sheriff_deputies SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
            { ['@id'] = GetCharacterId(src) }
        )
        Deputies[src] = nil
    end
end)
