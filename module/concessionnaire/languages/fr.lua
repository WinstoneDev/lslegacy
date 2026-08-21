-- ═══════════════════════════════════════════════════════════════════
--  CONCESSIONNAIRE — Strings français
-- ═══════════════════════════════════════════════════════════════════

Lang = Lang or {}

Lang.Concessionnaire = {
    -- Interaction
    browse_catalog   = 'Parcourir le catalogue',
    occasion_option  = 'Véhicules d\'occasion',
    resale_option    = 'Revendre mon véhicule',
    catalog_title    = 'Concessionnaire',
    catalog_subtitle = 'Choisissez une catégorie',
    back             = 'Retour',

    -- Occasion
    occasion_title   = 'Véhicules d\'occasion',
    occasion_none    = 'Aucun véhicule d\'occasion disponible.',
    occasion_tag     = ' (Occasion)',
    occasion_gone    = 'Ce véhicule d\'occasion vient d\'être vendu.',

    -- Fiche véhicule
    buy              = 'Acheter — %s $',
    stat_speed       = 'Vitesse max',
    stat_accel       = 'Accélération',
    stat_braking     = 'Freinage',

    -- Couleur
    color_choose     = 'Couleur principale',
    color_choose_2   = 'Couleur secondaire',
    color_primary    = 'Couleur principale',
    color_secondary  = 'Couleur secondaire',
    paint_original   = 'Couleur d\'origine (gratuite)',
    paint_applied    = 'Peinture personnalisée (+%s $)',

    -- Plaque personnalisée
    custom_plate_menu  = 'Plaque personnalisée',
    custom_plate_none  = 'Plaque aléatoire (par défaut)',
    custom_plate_title = 'Plaque personnalisée',
    custom_plate_label = 'Texte de la plaque',
    custom_plate_desc  = 'Surcoût : %s $ · %s caractères max',
    plate_taken        = 'Cette plaque est déjà utilisée.',

    -- Paiement
    choose_payment   = 'Moyen de paiement',
    pay_cash         = 'Argent liquide',
    pay_bank         = 'Compte courant',

    -- Recherche
    search_menu      = 'Rechercher / filtrer',
    search_hint      = 'Par nom ou budget',
    search_title     = 'Recherche',
    search_name      = 'Nom du véhicule (optionnel)',
    search_budget    = 'Budget max $ (optionnel)',
    search_results   = 'Résultats',
    search_none      = 'Aucun véhicule correspondant.',

    -- Essai
    test_drive       = 'Essayer (test-drive)',
    test_started     = 'Essai démarré — %d secondes. [X] pour arrêter.',
    test_timer       = 'Essai — %02d:%02d',
    test_timeout     = 'Fin de l\'essai (temps écoulé).',
    test_outofbounds = 'Essai interrompu : hors zone autorisée.',
    test_stopped     = 'Essai arrêté.',
    test_ended       = 'Essai terminé.',
    test_already     = 'Un essai est déjà en cours.',

    -- Résultats achat
    bought           = 'Vous avez acheté : %s. Votre véhicule vous attend à la livraison.',
    not_enough_cash  = 'Vous n\'avez pas assez d\'argent liquide.',
    not_enough_bank  = 'Fonds insuffisants sur votre compte courant.',
    purchase_failed  = 'La transaction a échoué.',
    invalid_vehicle  = 'Ce véhicule n\'est pas disponible.',
    delivered        = 'Votre véhicule a été livré.',

    -- Revente
    resale_need_vehicle  = 'Montez dans le véhicule à revendre.',
    resale_confirm_title = 'Revente au concessionnaire',
    resale_confirm_body  = 'Revendre le véhicule %s pour %d %% de sa valeur catalogue ?',
    resale_done          = 'Véhicule revendu — %d $ crédités.',
    resale_failed        = 'La revente a échoué.',
    resale_not_owner     = 'Vous n\'êtes pas propriétaire de ce véhicule.',
    resale_not_catalog   = 'Ce véhicule ne peut pas être repris ici.',
}
