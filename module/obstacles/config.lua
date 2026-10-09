Config.Obstacles = Config.Obstacles or {}

-- Job + formation requis pour ouvrir /parcours (voir module/mdt/config.lua, Config.MDT.TrainingCodes.CZ001)
Config.Obstacles.Job          = 'police'
Config.Obstacles.TrainingCode = 'CZ001'

-- Réglages du mode placement (le prop suit le point visé à la souris)
Config.Obstacles.Placement = {
    maxDistance = 15.0, -- portée max du raycast de visée
    heightStep  = 0.05, -- molette + LALT : hauteur au-dessus du point visé
    rotateStep  = 2.0,  -- molette : rotation, +MAJ : inclinaison, flèches gauche/droite (+LCTRL) : roll
}

-- Label = Nom affiché dans le menu / Model = nom du prop GTA (https://forge.plebmasters.de/objects)
Config.Obstacles.Props = {
    { Label = "Barriere Police", Model = "prop_barrier_work05" },
    { Label = "Caisse de Transport Haute", Model = "prop_box_wood06a" },
    { Label = "Caisse de Transport PM", Model = "prop_box_wood03a" },
    { Label = "Cible Bleu", Model = "prop_target_blue" },
    { Label = "Cible Couleur", Model = "prop_target_comp_metal" },
    { Label = "Cible Humaine", Model = "prop_ped_gib_01" },
    { Label = "Cible Jaune", Model = "prop_target_bull_b" },
    { Label = "Cible Rouge", Model = "prop_target_red" },
    { Label = "Cible Silhouette", Model = "prop_range_target_01" },
    { Label = "Cible x3", Model = "prop_range_target_02" },
    { Label = "Cône de balisage", Model = "prop_mp_cone_02" },
    { Label = "Corps 1", Model = "xm_prop_x17_corpse_01" },
    { Label = "Corps 2", Model = "xm_prop_x17_corpse_02" },
    { Label = "Corps 3", Model = "xm_prop_x17_corpse_03" },
    { Label = "Herse", Model = "p_ld_stinger_s" },
    { Label = "Mannequin", Model = "prop_dummy_01" },
    { Label = "Mur Beton PM", Model = "prop_fragtest_cnst_10" },
    { Label = "Palette", Model = "p_pallet_02a_s" },
    { Label = "Palette 2", Model = "prop_pallet_01a" },
    { Label = "Palette Bois + Sable Droite", Model = "prop_offroad_bale02" },
    { Label = "Palette Bois + Sable Gauche", Model = "prop_offroad_bale03" },
    { Label = "Palissade Bois 3", Model = "prop_ld_balcfnc_02b" },
    { Label = "Palissade Bois MM", Model = "prop_fncwood_16b" },
    { Label = "Palissade Bois PM", Model = "prop_fncwood_16c" },
    { Label = "Palissade Metal 1", Model = "prop_fnccorgm_03a" },
    { Label = "Palissade Metal 10", Model = "prop_fnccorgm_04a" },
    { Label = "Palissade Metal 2", Model = "prop_fnccorgm_02d" },
    { Label = "Palissade Metal 3", Model = "prop_fnccorgm_03" },
    { Label = "Palissade Metal 4", Model = "prop_fnccorgm_02a" },
    { Label = "Palissade Metal 5", Model = "prop_fnccorgm_03c" },
    { Label = "Palissade Metal 6", Model = "prop_fnccorgm_01b" },
    { Label = "Palissade Metal 7", Model = "prop_fnccorgm_02c" },
    { Label = "Palissade Metal 8", Model = "prop_fnccorgm_02e" },
    { Label = "Palissade Metal 9", Model = "prop_fnccorgm_02b" },
    { Label = "Planche Bois", Model = "prop_ld_crate_lid_01" },
    { Label = "Plaque Bois Debout", Model = "prop_cons_plyboard_01" },
    { Label = "Sac de Sable", Model = "prop_mb_sandblock_02" },
    { Label = "Sac de Sable 2", Model = "prop_mb_sandblock_03" },
}

-- Index modèle -> label, pour valider côté serveur qu'un prop envoyé par le client vient bien du catalogue.
Config.Obstacles.PropByModel = {}
for _, p in ipairs(Config.Obstacles.Props) do
    Config.Obstacles.PropByModel[p.Model] = p.Label
end
