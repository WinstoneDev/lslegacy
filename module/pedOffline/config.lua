pedOfflineCfg = pedOfflineCfg or {}
pedOfflineCfg.lang     = "fr"
pedOfflineCfg.langs    = {}

pedOfflineCfg.purgeDay     = 7       -- jours avant suppression definitive du ped (BDD + memoire) et avant qu'il ne soit plus recharge au demarrage
pedOfflineCfg.pedSpawnDist = 25.0    -- distance de spawn/despawn du ped

pedOfflineCfg.testCommand = {
    name  = "pedtest",
    group = 3,   -- groupe 3 = admin dans LSLegacy (0=user, 3=admin, 4=superadmin)
}

-- Animations jouées sur le ped endormi (choix aléatoire)
pedOfflineCfg.sleepAnimation = {
    { dict = "amb@world_human_bum_slumped@male@laying_on_left_side@idle_a", anim = "idle_b", flags = 1 },
}

pedOfflineCfg.carryAnimation = {
    player1 = {
        dict  = "missfinale_c2mcs_1",
        anim  = "fin_c2_mcs_1_camman",
        flags = 49,
    },
    player2 = {
        dict  = "nm",
        anim  = "firemans_carry",
        flags = 33,
    },
    -- { boneIndex, x, y, z, rx, ry, rz }
    attach = { 0, 0.20, 0.15, 0.63, 0.5, 0.5, 5.0 },
}

pedOfflineCfg.debug = false
