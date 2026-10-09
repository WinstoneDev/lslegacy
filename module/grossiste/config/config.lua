-- module/grossiste — Config générale.
--
-- Grossiste = 2 PNJ (achat / vente), stock illimité, prix fixes, ouvert à
-- n'importe quel joueur. Pas de job dédié pour l'instant.

GRConfig = {}

GRConfig.Debug = false
GRConfig.Prefix = 'grossiste'

-- ── PNJ ──────────────────────────────────────────────────────────────────
-- Achats : Lawrence Blevins (ci-dessous). Reprise/vente : Janet Vance
-- (voir Config.Avicole.Grossiste) — rachète toutes les ressources, pas
-- seulement la livraison avicole.
GRConfig.Seller = {
    -- Le joueur ACHÈTE au grossiste (ce PNJ vend).
    label = "Grossiste — Achats", name = 'Lawrence Blevins', model = 'mp_m_shopkeep_01',
    coords = vec3(2747.591309, 3469.107666, 55.666626), heading = 252.28346252441,
}

GRConfig.Blip = {
    enabled = true, coords = vec3(2747.591309, 3469.107666, 55.666626),
    sprite = 273, color = 5, scale = 0.8, label = "Grossiste",
}

-- ── Sécurité serveur ─────────────────────────────────────────────────────
GRConfig.Security = { maxDistance = 4.0, rateWindow = 15000, rateMaxActions = 30 }

-- ── Comptes entreprise ───────────────────────────────────────────────────
-- Coffres DataStore existants des métiers déjà en place (voir server/cash.lua
-- de chaque resto : `<Prefix>_safe`). Un joueur dont le job figure ici peut
-- payer ses achats depuis ce coffre, et sa revente y est déposée AUTOMATIQUEMENT
-- (jamais en poche), libellée "Vente grossiste".
GRConfig.CompanySafes = {
    kebabking  = 'ls_kebabking_safe',
    burgershot = 'ls_burgershot_safe',
    aldentes   = 'ls_aldentes_safe',
}
