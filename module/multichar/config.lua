Config.Multichar = {
    -- Coupe-circuit global : false = comportement identique à avant (1 seul
    -- personnage par compte, aucun écran de sélection).
    Enabled = true,

    -- Nombre de slots pour un compte normal. 1 = pas d'écran de sélection
    -- affiché (fast-path identique à l'ancien flux registerPlayer direct).
    SlotsDefault = 1,

    -- Nombre de slots pour les comptes listés dans AdminIdentifiers.
    SlotsAdmin = 3,

    -- Comptes qui reçoivent SlotsAdmin au lieu de SlotsDefault. Indépendant
    -- du grade en jeu (`players.group`), qui est stocké par personnage et
    -- n'existe donc pas encore tant qu'aucun personnage n'a été choisi.
    AdminIdentifiers = {
        "license:a32f25553f22215bd8f6bc3402b039dcf8c5386d",
        "license:8c37ade65b7a288c6fc44b680c13b7bca8c1b190",
        "license:1d812779bc0c11c89818b05c07f08cec84968374"
    },

    -- ─── Instance "salon" de sélection de personnage ──────────────────────
    -- Remplace l'écran carte-liste par une scène 3D : un appartement instancié
    -- (routing bucket dédié) où chaque slot de personnage est représenté par
    -- un ped assis portant son skin. Survoler un ped affiche ses infos via
    -- NUI, cliquer dessus le sélectionne (identique à un clic sur la carte).
    Apartment = {
        Enabled = true,

        -- Offset additionné au server id pour dériver un bucket unique par
        -- joueur (même principe que module/creatorPerso, offset différent
        -- pour ne jamais entrer en collision avec lui).
        BucketOffset = 20000,

        -- Position/heading de la caméra fixe de la scène.
        Camera = { x = -141.507690, y = -601.635193, z = 169.166992, heading = 266.45669555664, heightOffset = -0.18, backOffset = 2.0 },

        -- Un siège par slot (dans l'ordre des slots). Capturées avec
        -- `/e sitchair` : le ped est posé exactement à ces coordonnées avec
        -- ce heading, tête ~1.6 au-dessus du sol pour la projection écran.
        Seats = {
            { x = -138.421982, y = -600.804382, z = 167.599976, heading = 124.72441101074 },
            { x = -137.604401, y = -601.661560, z = 167.599976, heading = 79.370079040527 },
            { x = -138.474731, y = -602.518677, z = 167.599976, heading = 34.015747070312 },
        },
    },
}
