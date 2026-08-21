--  MODULE MÉCANICIEN — Strings français

Lang = Lang or {}

Lang.Mecanicien = {
    not_mecanicien        = "Vous ne faites pas partie de l'atelier.",
    duty_on                = 'Prise de service enregistrée.',
    duty_off                = 'Fin de service enregistrée.',
    already_on_duty          = 'Vous êtes déjà en service.',
    already_off_duty          = "Vous n'êtes pas en service.",
    action_cooldown            = 'Attendez avant de répéter cette action.',
    no_vehicle_access            = 'Votre grade ne vous autorise pas ce véhicule.',
    vehicle_spawned                = 'Véhicule sorti.',

    -- Diagnostic
    diagnose_title       = 'Diagnostic véhicule',
    diagnose_engine_ok    = 'Moteur : bon état',
    diagnose_engine_bad     = 'Moteur : endommagé',
    diagnose_body_ok          = 'Carrosserie : bon état',
    diagnose_body_bad           = 'Carrosserie : endommagée',
    diagnose_tyres_ok             = 'Pneus : bon état',
    diagnose_tyres_bad               = '%d pneu(x) à changer',

    -- Réparation
    no_client_vehicle      = 'Aucun client à proximité du véhicule.',
    repair_engine_start      = 'Réparation moteur en cours...',
    repair_engine_done         = 'Moteur réparé.',
    repair_engine_failed         = 'Réparation ratée, réessayez.',
    repair_engine_not_needed       = "Ce moteur n'a pas besoin de réparation.",
    change_tyre_no_item              = "Vous n'avez plus de pneu en stock.",
    change_tyre_none_burst              = 'Aucun pneu crevé sur ce véhicule.',
    change_tyre_done                      = 'Pneu changé.',
    change_tyre_failed                       = 'Changement raté, réessayez.',

    -- Pièces / dépôt (stock du garage — jamais facturé au mécanicien)
    depot_title           = 'Dépôt de pièces',
    depot_buy                = 'Prendre (stock du garage)',
    depot_out_of_stock          = 'Rupture de stock pour cette pièce.',
    depot_already_holding         = 'Vous portez déjà une pièce, posez-la avant.',
    depot_part_bought                = 'Pièce récupérée du stock : %s.',
    grade_required                      = 'Votre grade est insuffisant pour effectuer cette action.',
    drop_part                            = 'Vous lâchez la pièce.',
    install_prompt                          = '[E] Poser : %s',
    install_start                              = 'Installation en cours...',
    install_done                                  = 'Pièce installée.',
    install_failed                                   = "Installation ratée, retentez l'appui sur E.",
    install_no_part                                     = "Vous ne tenez aucune pièce.",
    install_wrong_repair                                   = "Cette pièce ne correspond pas à une réparation nécessaire ici (RP libre, posée quand même).",

    -- Tuning
    tuning_title           = 'Tuning — LS Customs',
    tuning_colors            = 'Couleur',
    tuning_wheels             = 'Jantes',
    tuning_performance          = 'Performance',
    tuning_applied                = 'Modification appliquée : %s.',
    tuning_no_money                  = "Le client n'a pas les fonds nécessaires (%d$).",

    -- Remorquage
    tow_attach_start        = 'Accrochage du véhicule...',
    tow_attached               = 'Véhicule accroché à la dépanneuse.',
    tow_detached                  = 'Véhicule détaché.',
    tow_no_target                    = 'Aucun véhicule à accrocher.',
    tow_not_in_truck                    = "Vous n'êtes pas dans une dépanneuse.",
    tow_too_far                            = 'Garez la dépanneuse plus près du véhicule.',
}
