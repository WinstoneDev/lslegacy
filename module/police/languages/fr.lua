--  MODULE POLICE NATIONALE — Strings français

Lang = Lang or {}

Lang.Police = {
    -- Notifications générales
    not_police          = 'Vous ne faites pas partie de la Police Nationale.',
    duty_on             = 'Prise de service enregistrée.',
    duty_off            = 'Fin de service enregistrée.',
    already_on_duty     = 'Vous êtes déjà en service.',
    already_off_duty    = 'Vous n\'êtes pas en service.',
    grade_required      = 'Votre grade est insuffisant pour effectuer cette action.',
    unit_required       = 'Vous n\'êtes pas affecté à l\'unité requise.',
    no_target           = 'Aucune cible à portée.',
    too_far             = 'Trop loin de la cible.',
    action_cooldown     = 'Attendez avant de répéter cette action.',
    action_cancelled    = 'Action annulée.',
    action_blocked      = 'Action impossible en ce moment.',

    -- Prise de service / tenue
    choose_service      = 'Choisissez votre service',
    choose_unit         = 'Choisissez votre unité',
    take_duty           = 'Prendre le service',
    end_duty            = 'Terminer le service',
    armory              = 'Armurerie',
    clothing            = 'Vestiaire',

    -- Véhicules
    garage_title        = 'Garage Police',
    no_vehicle_access   = 'Votre grade ne vous autorise pas ce véhicule.',
    vehicle_spawned     = 'Véhicule sorti.',

    -- Actions policières
    action_cuff         = 'Menotter',
    action_uncuff       = 'Démenotter',
    action_search       = 'Fouiller',
    action_palpation    = 'Palpation de sécurité',
    action_id_check     = 'Contrôle d\'identité',
    action_license      = 'Vérifier le permis',
    action_escort_start = 'Escorter',
    action_escort_stop  = 'Arrêter l\'escorte',
    action_put_in_veh   = 'Mettre dans le véhicule',
    action_get_out_veh  = 'Sortir du véhicule',
    action_fine         = 'Donner une amende',
    action_seize        = 'Saisir un objet',
    action_custody      = 'Placer en garde à vue',

    cuffed              = 'Vous avez été menotté(e).',
    uncuffed            = 'Vous avez été démenotté(e).',
    cuffed_other        = '%s a été menotté(e).',
    uncuffed_other      = '%s a été démenotté(e).',
    already_cuffed      = 'Cette personne est déjà menottée.',
    not_cuffed          = 'Cette personne n\'est pas menottée.',

    search_start        = 'Fouille en cours...',
    search_result       = 'Fouille terminée — Objets trouvés : %s',
    search_empty        = 'Fouille terminée — Rien de suspect.',
    palpation_start     = 'Palpation de sécurité...',
    palpation_armed     = '⚠ ALERTE — L\'individu a quelque chose sur lui.',
    palpation_clean     = 'Palpation terminée — Aucune arme détectée.',

    id_check_start      = 'Contrôle d\'identité...',
    id_result           = 'Identité : %s | Naissance : %s | Taille : %scm',
    no_id               = 'Individu non identifié — Aucun document.',
    license_check_start = 'Vérification du permis...',
    license_valid       = 'Permis valide — Titulaire : %s',
    license_invalid     = '⚠ Permis non valide ou absent.',
    no_vehicle_nearby   = 'Aucun véhicule à proximité.',

    escort_start        = 'Vous escortez %s.',
    escort_stop         = 'Escorte terminée.',
    escorted_by         = 'Vous êtes escorté(e) par un agent.',
    put_in_veh          = '%s a été placé(e) dans le véhicule.',
    got_out_veh         = '%s a été sorti(e) du véhicule.',
    no_police_veh       = 'Aucun véhicule de police à proximité.',

    seize_item          = 'Objet saisi : %s (%d)',
    seize_nothing       = 'L\'individu ne possède pas cet objet.',
    fine_sent           = 'Amende de %s$ créée.',

    -- Radio
    radio_title         = 'Radio Police',
    radio_on            = '📡 Radio activée — Canal %s (%s)',
    radio_off           = 'Radio désactivée.',
    radio_channel_set   = 'Canal radio : %s (%s)',
    radio_talk          = '[Radio] %s : %s',
    radio_no_channel    = 'Aucun canal sélectionné.',
    radio_key_hint      = 'Maintenez [CAPS LOCK] pour parler',

    -- Garde à vue
    custody_placed      = 'Placé(e) en garde à vue.',
    custody_released    = 'Votre GAV est terminé, un agent a été prévenu.',
    custody_duration    = 'Durée restante : %s',
    custody_reason      = 'Motif : %s',

    -- Prison
    prison_sent         = 'Incarcéré(e) à Bolingbroke — Durée : %s minutes.',
    prison_released     = 'Vous avez purgé votre peine. Vous êtes libre.',
    prison_time_left    = 'Peine restante : %d min %ds',

    -- Investigation / Preuves
    inv_collect_fp      = 'Collecte d\'empreintes...',
    inv_fp_collected    = 'Empreintes relevées — Réf. %s',
    inv_fp_identified   = '✔ Empreintes identifiées : %s',
    inv_fp_no_match     = 'Aucune correspondance dans la base.',
    inv_collect_dna     = 'Prélèvement ADN...',
    inv_dna_collected   = 'Échantillon ADN prélevé — Réf. %s',
    inv_dna_identified  = '✔ ADN identifié : %s',
    inv_dna_no_match    = 'Aucune correspondance ADN.',
    inv_collect_blood   = 'Analyse de sang...',
    inv_blood_collected = 'Trace de sang analysée — Réf. %s',
    inv_scene_secured   = 'Scène de crime sécurisée.',
    inv_evidence_stored = 'Preuve enregistrée dans le MDT.',
    inv_kit_required    = 'Vous avez besoin d\'un kit d\'investigation.',
    inv_too_far_scene   = 'Trop loin de la scène de crime.',
}
