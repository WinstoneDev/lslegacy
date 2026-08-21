Lang = Lang or {}

Lang.Atelier = {
    not_employee          = "Vous ne faites pas partie de cette entreprise.",
    not_on_duty            = "Vous devez être en service pour cette action.",
    duty_on                 = 'Prise de service enregistrée.',
    duty_off                  = 'Fin de service enregistrée.',
    action_cooldown             = 'Attendez avant de répéter cette action.',
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
    repair_start      = 'Réparation en cours...',
    repair_done         = 'Réparation terminée.',
    repair_failed         = 'Réparation ratée, réessayez.',
    repair_not_needed  = "Cet élément n'a pas besoin de réparation.",

    -- Pièces / stock
    depot_title           = 'Dépôt de pièces',
    depot_out_of_stock      = 'Rupture de stock pour cette pièce.',
    depot_part_bought         = '%s récupéré(e) au dépôt.',
    depot_already_holding       = 'Vous portez déjà une pièce, déposez-la avant.',
    depot_buy                     = 'Prendre au dépôt',
    grade_required                  = 'Votre grade ne vous autorise pas cette action.',

    -- Tuning
    tuning_title      = 'Tuning',
    tuning_colors       = 'Peinture',
    tuning_wheels         = 'Jantes',
    tuning_performance      = 'Performance',
    tuning_applied            = 'Tuning appliqué : %s.',
    tuning_no_money             = 'Paiement refusé (%d$).',

    -- Facturation
    invoice_created  = 'Facture créée : %d$.',
    invoice_paid       = 'Facture réglée.',
    invoice_refused      = 'Paiement refusé.',
}
