-- Indexée sur (character_id, company) : un personnage ne peut être employé que d'une seule
-- entreprise à la fois, mais la clé composite prépare le terrain pour un futur changement d'employeur.
local rateLimits = {
    ['atelier:onDuty'] = 10, ['atelier:offDuty'] = 10,
    ['atelier:requestDiagnostic'] = 20, ['atelier:requestStock'] = 20, ['atelier:takePart'] = 15,
    ['atelier:dropPart'] = 20, ['atelier:restockStock'] = 15, ['atelier:repairComponent'] = 15,
    ['atelier:requestInvoice'] = 15, ['atelier:finalizeInvoice'] = 10, ['atelier:requestTuningCheckout'] = 20,
    ['atelier:reportUsage'] = 6,
}
for eventName, limit in pairs(rateLimits) do
    LSLegacy.Security.RegisterRateLimit(eventName, limit)
end

MySQL.Async.execute([[
    CREATE TABLE IF NOT EXISTS atelier_agents (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        character_id  INT          NOT NULL,
        company       VARCHAR(20)  NOT NULL,
        identifier    VARCHAR(60)  NOT NULL,
        name          VARCHAR(100) NOT NULL DEFAULT '',
        on_duty       TINYINT(1)   NOT NULL DEFAULT 0,
        duty_since    DATETIME     DEFAULT NULL,
        last_seen     DATETIME     DEFAULT NULL,
        UNIQUE KEY uq_atelier_agents_char_company (character_id, company),
        KEY idx_atelier_agents_identifier (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]], {})

-- PRISE DE SERVICE

LSLegacy.Events.Register('atelier:onDuty', function()
    local src = source
    local companyId = LSLegacy.Atelier.GetCompany(src)
    if not companyId then return end

    local grade  = LSLegacy.Atelier.GetGrade(src)
    local charId = LSLegacy.Atelier.GetCharacterId(src)
    local p      = LSLegacy.Atelier.GetPlayer(src)
    local ident  = p and p.identifier or nil
    local name   = GetPlayerName(src) or 'Mécanicien'

    if not charId or not ident then return end

    LSLegacy.Atelier.Agents[src] = { onDuty = true, companyId = companyId, grade = grade, name = name }

    MySQL.Async.execute(
        'INSERT INTO atelier_agents (character_id, company, identifier, name, on_duty, duty_since, last_seen) ' ..
        'VALUES (@charId, @company, @id, @name, 1, NOW(), NOW()) ' ..
        'ON DUPLICATE KEY UPDATE identifier=@id, name=@name, on_duty=1, duty_since=NOW(), last_seen=NOW()',
        { ['@charId'] = charId, ['@company'] = companyId, ['@id'] = ident, ['@name'] = name }
    )

    LSLegacy.Events.SendToClient('atelier:dutyResult', src, { success = true, onDuty = true, companyId = companyId, grade = grade })
end)

LSLegacy.Events.Register('atelier:offDuty', function()
    local src = source
    local agent = LSLegacy.Atelier.Agents[src]
    if not agent then return end

    local charId = LSLegacy.Atelier.GetCharacterId(src)
    if charId then
        MySQL.Async.execute(
            'UPDATE atelier_agents SET on_duty=0, last_seen=NOW() WHERE character_id=@id AND company=@company',
            { ['@id'] = charId, ['@company'] = agent.companyId }
        )
    end
    LSLegacy.Atelier.Agents[src] = nil

    LSLegacy.Events.SendToClient('atelier:dutyResult', src, { success = true, onDuty = false })
end)

-- Nettoyage à la déconnexion

AddEventHandler('playerDropped', function()
    local src = source
    local agent = LSLegacy.Atelier.Agents[src]
    if not agent then return end

    local charId = LSLegacy.Atelier.GetCharacterId(src)
    if charId then
        MySQL.Async.execute(
            'UPDATE atelier_agents SET on_duty=0, last_seen=NOW() WHERE character_id=@id AND company=@company',
            { ['@id'] = charId, ['@company'] = agent.companyId }
        )
    end
    LSLegacy.Atelier.Agents[src] = nil
end)
