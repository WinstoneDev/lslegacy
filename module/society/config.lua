--  MODULE SOCIETY — économie d'entreprise : compte bancaire de job, carte
--  entreprise, factures, onglet MDT « Entreprise ».
Config.Society = {
    -- Chef = grade le plus élevé du job, sauf surcharge (grade minimum)
    BossGrades = {
        -- ['police'] = 7,
    },
    InvoiceMaxAmount = 100000,
    InvoiceMaxReason = 120,
    -- Webhook Discord (convar lslegacy_webhook_society)
    Webhook = GetConvar('lslegacy_webhook_society', ''),
}
