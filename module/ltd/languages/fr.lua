--  MODULE LTD — Strings français

Lang = Lang or {}

Lang.LTD = {
    not_employee          = "Vous ne faites pas partie du personnel LTD.",
    duty_on                = 'Prise de service enregistrée.',
    duty_off                = 'Fin de service enregistrée.',
    already_on_duty          = 'Vous êtes déjà en service.',
    already_off_duty          = "Vous n'êtes pas en service.",
    action_cooldown            = 'Attendez avant de répéter cette action.',
    grade_required               = 'Votre grade est insuffisant pour effectuer cette action.',

    -- Caisse
    register_title          = 'Caisse LTD',
    sell_no_stock              = 'Article en rupture de stock.',
    sell_no_client                = 'Aucun client à proximité de la caisse.',
    sell_no_money                    = "Le client n'a pas les fonds nécessaires.",
    sell_done                          = 'Vente effectuée : %s (%d$).',
    sold_to_you                           = 'Vous avez acheté : %s (%d$).',

    -- Réassort
    restock_title             = 'Réserve LTD',
    restock_done                = "Rayon réapprovisionné : %s (+%d).",
    restock_empty_reserve          = "Stock de réserve insuffisant pour réapprovisionner.",
    fill_title                        = 'Remplir la réserve à la main',
    fill_added                          = '%d ajouté(s) à la réserve : %s.',

    -- Vol / alarme
    theft_title                = 'Voler un article',
    theft_done                   = "Vous avez subtilisé : %s.",
    theft_none_available             = 'Aucun article disponible à voler.',
    alarm_triggered                    = 'Alarme silencieuse déclenchée — la police a été alertée.',
    alarm_received                       = '🚨 Vol signalé dans un magasin LTD — voir GPS.',
    theft_alert_employee                    = '⚠ Vol constaté en rayon !',
}
