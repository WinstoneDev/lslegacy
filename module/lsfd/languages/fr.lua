--  MODULE LSFD — Strings français

Lang = Lang or {}

Lang.LSFD = {
    -- Notifications générales
    not_lsfd           = 'Vous ne faites pas partie du LSFD.',
    duty_on                = 'Prise de service enregistrée.',
    duty_off                = 'Fin de service enregistrée.',
    already_on_duty         = 'Vous êtes déjà en service.',
    already_off_duty        = 'Vous n\'êtes pas en service.',
    grade_required           = 'Votre grade est insuffisant pour effectuer cette action.',
    no_target                 = 'Aucune victime à portée.',
    action_cooldown            = 'Attendez avant de répéter cette action.',

    -- Prise de service / tenue
    take_duty             = 'Prendre le service',
    end_duty                = 'Terminer le service',
    clothing                 = 'Vestiaire',

    -- Véhicules
    no_vehicle_access       = 'Votre grade ne vous autorise pas ce véhicule.',

    -- Actions
    action_extinguish         = 'Éteindre un incendie',
    action_rescue              = 'Désincarcérer',
    extinguish_start            = 'Extinction en cours...',
    extinguish_done              = 'Incendie maîtrisé.',
    extinguish_none                = 'Aucun feu à proximité.',
    rescue_start                    = 'Désincarcération en cours...',
    rescue_done                      = 'Victime extraite et stabilisée.',
    rescued_by                        = 'Vous avez été désincarcéré(e) et secouru(e).',
}
