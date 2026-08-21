--  MODULE SAMU — Strings français

Lang = Lang or {}

Lang.SAMU = {
    -- Notifications générales
    not_samu             = 'Vous ne faites pas partie du SAMU.',
    duty_on              = 'Prise de service enregistrée.',
    duty_off             = 'Fin de service enregistrée.',
    already_on_duty      = 'Vous êtes déjà en service.',
    already_off_duty     = 'Vous n\'êtes pas en service.',
    grade_required       = 'Votre grade est insuffisant pour effectuer cette action.',
    no_target            = 'Aucun patient à portée.',
    action_cooldown      = 'Attendez avant de répéter cette action.',

    -- Prise de service / tenue
    take_duty             = 'Prendre le service',
    end_duty               = 'Terminer le service',
    clothing                = 'Vestiaire',

    -- Véhicules
    no_vehicle_access      = 'Votre grade ne vous autorise pas ce véhicule.',
    vehicle_spawned        = 'Véhicule sorti.',

    -- Soins
    action_revive            = 'Réanimer',
    revive_start              = 'Réanimation en cours...',
    revive_done                = 'Patient stabilisé et réanimé.',
    revived_by                  = 'Vous avez été réanimé(e) par les secours.',
    not_unconscious               = 'Cette personne n\'est pas en détresse vitale.',

    -- Trousse de soins (contextuelle selon la blessure)
    action_bag                  = 'Trousse de Soins',
    bag_title                    = 'Trousse de Soins',
    bag_diagnosing                = 'Diagnostic en cours...',
    bag_empty                      = 'Aucun soin compatible disponible dans votre trousse.',
    bag_use                         = 'Utiliser depuis la trousse',
    bag_item_used                    = '%s appliqué.',
    bag_item_missing                  = 'Vous n\'avez plus de %s.',
    bag_target_unconscious             = 'Patient inconscient — utilisez Réanimer d\'abord.',
    bag_already_full_health             = 'Le patient n\'a pas besoin de soins.',

    -- Réassort
    restock_done                 = 'Trousse de soins réapprovisionnée.',
    restock_cooldown              = 'Réassort déjà effectué récemment.',

    -- Appel patient (hook depuis le système blessures)
    patient_call_received          = 'Appel détresse vitale reçu — Voir GPS.',
}
