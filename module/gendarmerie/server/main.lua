--  MODULE GENDARMERIE NATIONALE — Serveur principal
--  Création de la table SQL, gestion de la prise de service.
--  SÉCURITÉ : le job et le grade sont toujours relus depuis
--  LSLegacy.ServerPlayers, jamais depuis le client.

LSLegacy.Security.RegisterRateLimit('gendarmerie:onDuty', 10)
LSLegacy.Security.RegisterRateLimit('gendarmerie:offDuty', 10)

local Gendarmes = {}   -- { [source] = { onDuty, grade, name } }

-- Helpers sécurité

local function GetPlayerGN(src)
    return LSLegacy.ServerPlayers[src]
end

local function IsGendarmeAgent(src)
    local p = GetPlayerGN(src)
    return p and p.job == Config.Gendarmerie.Job
end

local function GetGradeGN(src)
    local p = GetPlayerGN(src)
    return p and (tonumber(p.job_grade) or 0) or 0
end

local function GetNameGN(src)
    local p = GetPlayerGN(src)
    if p and p.characterInfos then
        return ((p.characterInfos.Prenom or '') .. ' ' .. (p.characterInfos.NDF or ''))
    end
    return GetPlayerName(src) or 'Gendarme'
end

local function GetIdentifierGN(src)
    local p = GetPlayerGN(src)
    return p and p.identifier or nil
end

-- Clé "personnage" (players.id) : identifier seul ne suffit plus depuis le
-- multicharacter, plusieurs personnages d'un même compte partagent le
-- même identifier.
local function GetCharacterIdGN(src)
    local p = GetPlayerGN(src)
    return p and p["boutique-id"] or nil
end

-- Création de la table SQL

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS gendarmerie_officers (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        identifier    VARCHAR(60)  NOT NULL,
        character_id  INT          DEFAULT NULL,
        name          VARCHAR(100) NOT NULL DEFAULT '',
        unit          VARCHAR(60)  DEFAULT NULL,
        on_duty       TINYINT(1)   NOT NULL DEFAULT 0,
        duty_since    DATETIME     DEFAULT NULL,
        last_seen     DATETIME     DEFAULT NULL,
        UNIQUE KEY uq_go_character (character_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- Redémarrage serveur : personne n'est réellement en service, on remet la
-- table à plat pour ne pas laisser d'agents fantômes dans les effectifs.
MySQL.Async.execute('UPDATE gendarmerie_officers SET on_duty=0', {})

-- PRISE DE SERVICE

LSLegacy.RegisterServerEvent('gendarmerie:onDuty', function()
    local src = source
    if not IsGendarmeAgent(src) then return end

    local grade  = GetGradeGN(src)
    local ident  = GetIdentifierGN(src)
    local charId = GetCharacterIdGN(src)
    local name   = GetNameGN(src)

    Gendarmes[src] = { onDuty = true, grade = grade, name = name }

    -- Statebag autoritaire, lisible par n'importe quelle ressource (même
    -- convention que `policeOnDuty`).
    Player(src).state:set('gendarmerieOnDuty', true, true)

    MySQL.Async.execute(
        'INSERT INTO gendarmerie_officers (identifier, character_id, name, on_duty, duty_since, last_seen) ' ..
        'VALUES (@id, @charId, @name, 1, NOW(), NOW()) ' ..
        'ON DUPLICATE KEY UPDATE identifier=@id, name=@name, on_duty=1, duty_since=NOW(), last_seen=NOW()',
        { ['@id'] = ident, ['@charId'] = charId, ['@name'] = name }
    )
end)

LSLegacy.RegisterServerEvent('gendarmerie:offDuty', function()
    local src = source
    if not Gendarmes[src] then return end

    Player(src).state:set('gendarmerieOnDuty', false, true)

    MySQL.Async.execute(
        'UPDATE gendarmerie_officers SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
        { ['@id'] = GetCharacterIdGN(src) }
    )
    Gendarmes[src] = nil
end)

-- État exposé aux autres modules

function GetGendarmes() return Gendarmes end

-- Nom attendu par le registre DUTY_CHECKERS du cœur MDT (effectifs,
-- tableau de bord).
function IsGendarmeOnDuty(src)
    return Gendarmes[src] ~= nil and Gendarmes[src].onDuty == true
end

function IsGendarmeJob(src) return IsGendarmeAgent(src) == true end

-- Nettoyage à la déconnexion
AddEventHandler('playerDropped', function()
    local src = source
    if Gendarmes[src] then
        MySQL.Async.execute(
            'UPDATE gendarmerie_officers SET on_duty=0, last_seen=NOW() WHERE character_id=@id',
            { ['@id'] = GetCharacterIdGN(src) }
        )
        Gendarmes[src] = nil
    end
end)
