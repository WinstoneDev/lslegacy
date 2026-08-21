KeyHanger = KeyHanger or {}
KeyHanger.Locales = KeyHanger.Locales or {}

KeyHanger.Locales.fr = {
    -- Notifications (titre)
    title                = "Porte-clés",

    -- Cibles ox_target
    target_open          = "Ouvrir le porte-clés",
    target_manage        = "Gérer le porte-clés",
    container_label      = "Porte-clés — %s",          -- en-tête du coffre
    container_unavailable= "Porte-clés indisponible",

    -- Menu principal
    menu_title           = "Porte-clés — %s",          -- %s = label du support
    menu_subtitle        = "%d/%d clé(s) accrochée(s)", -- accrochées/max
    menu_hang            = "Accrocher une clé",
    menu_hang_desc       = "Suspendre une clé de véhicule de votre inventaire",
    menu_retrieve        = "Récupérer une clé",
    menu_retrieve_desc   = "Reprendre une clé accrochée sur le support",
    menu_manage          = "Gérer le support",
    menu_manage_desc     = "Partages, renommage, retrait du support",

    -- Accrocher
    hang_title           = "Choisir une clé à accrocher",
    hang_none            = "Vous n'avez aucune clé de véhicule sur vous",
    hang_entry           = "%s",                        -- %s = label de la clé
    hang_entry_desc      = "Plaque : %s • %s",          -- plaque, modèle
    hang_success         = "Clé « %s » accrochée sur le porte-clés",
    hang_full            = "Le porte-clés est plein",
    hang_no_item         = "Vous n'avez pas cette clé",

    -- Récupérer
    retrieve_title       = "Clés accrochées",
    retrieve_none        = "Aucune clé n'est accrochée ici",
    retrieve_entry_desc  = "Plaque : %s • Accrochée par %s",
    retrieve_success     = "Vous avez récupéré la clé « %s »",
    retrieve_taken       = "Cette clé n'est plus disponible",

    -- Gestion / partage
    manage_title         = "Gestion du porte-clés",
    manage_rename        = "Renommer le support",
    manage_rename_desc   = "Nom affiché : %s",
    manage_rename_input  = "Nouveau nom du porte-clés",
    manage_share         = "Partager l'accès",
    manage_share_desc    = "Autoriser une personne proche à utiliser ce support",
    manage_shares        = "Personnes autorisées (%d)",
    manage_shares_desc   = "Voir / retirer les partages",
    manage_remove        = "Retirer le porte-clés du mur",
    manage_remove_desc   = "Décroche le support (videz-le d'abord)",
    manage_remove_notEmpty = "Videz le porte-clés avant de le retirer",
    manage_remove_confirm= "Confirmer le retrait du support ?",
    manage_no_perm       = "Vous n'avez pas la permission de gérer ce support",

    share_added          = "%s peut désormais utiliser ce porte-clés",
    share_removed        = "Partage retiré : %s",
    share_none_nearby    = "Aucun joueur à proximité",
    share_self           = "Vous ne pouvez pas vous partager à vous-même",
    share_already        = "Cette personne a déjà accès",
    share_remove_entry   = "Retirer : %s",

    -- Placement
    placement_start      = "Mode placement : clic gauche valider, molette tourner, ALT hauteur, ESC annuler",
    placement_help       = "[Souris] Viser un mur  •  [Molette] Rotation  •  [ALT+Molette] Hauteur  •  [G] Profondeur  •  [Entrée] Valider  •  [Clic droit] Annuler",
    placement_choose_board = "Type de support",
    placement_label_input  = "Nom du porte-clés",
    placement_access_input = "Type d'accès",
    placement_owner_input  = "Métier/Faction (laisser vide si personnel)",
    placement_created    = "Porte-clés installé",
    placement_cancelled  = "Placement annulé",
    placement_blocked    = "Impossible de placer ici",

    -- Accès refusé
    access_denied        = "Vous n'avez pas accès à ce porte-clés",

    -- Item clé
    key_created          = "Clé créée pour le véhicule %s (%s)",
    key_no_vehicle       = "Aucun véhicule à proximité",
    key_locked           = "Véhicule verrouillé",
    key_unlocked         = "Véhicule déverrouillé",
    key_too_far          = "Le véhicule correspondant est trop loin",
    key_label            = "Clé — %s",                  -- %s = plaque
}

--- Récupère une chaîne localisée formatée.
function KeyHanger.L(key, ...)
    local loc = KeyHanger.Locales[KeyHanger.Config.Locale] or KeyHanger.Locales.fr
    local str = loc[key] or key
    if select("#", ...) > 0 then
        return string.format(str, ...)
    end
    return str
end
