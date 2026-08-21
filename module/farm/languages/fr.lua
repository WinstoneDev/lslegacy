-- ═══════════════════════════════════════════════════════════════════
--  MODULE FARM — Strings français
-- ═══════════════════════════════════════════════════════════════════

Lang = Lang or {}

Lang.Farm = {
    missing_tool      = "Il vous faut l'outil adéquat pour cette récolte : %s.",
    tool_not_equipped = 'Vous devez avoir %s en main pour récolter.',
    node_cooldown     = 'Ce point de récolte est épuisé, revenez plus tard.',
    gather_start      = 'Récolte en cours...',
    gather_success    = 'Récolte réussie : %d %s obtenu(s).',
    gather_failed     = 'Récolte ratée, réessayez.',

    process_missing_raw = 'Il vous faut au moins %d %s pour lancer un traitement.',
    process_start        = 'Traitement en cours...',
    process_success       = 'Traitement réussi : %d %s produit(s).',
    process_failed          = 'Traitement raté, réessayez.',

    sell_nothing_to_sell = "Vous n'avez rien à vendre ici.",
    sell_done            = 'Vente effectuée : %s pour %d$.',
}
