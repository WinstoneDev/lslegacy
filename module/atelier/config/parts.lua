--  MODULE ATELIER — Catalogue des pièces
--  Les items eux-mêmes (label, poids, prop) sont déclarés dans
--  shared/config.lua → Config.Items (système d'inventaire LSLegacy,
--  jamais dupliqué ici). Cette table ne fait que dire à QUOI sert
--  chaque pièce pour le métier atelier : quel(s) composant(s) elle
--  répare, si elle se porte en main, son prix.
--
--  `repairs` liste les id de composants (voir shared/components.lua)
--  qu'une pose de cette pièce peut réparer. Pour les pièces génériques
--  (portière/aile/pneu, qui existent en plusieurs exemplaires sur le
--  véhicule), le mécano choisit le composant précis au moment de la pose.

Config.Atelier.Parts = {
    -- Carrosserie (portées en main)
    piece_capot             = { repairs = { 'capot' },                                                carried = true, price = 150 },
    piece_pare_choc_avant   = { repairs = { 'pare_choc_avant' },                                       carried = true, price = 120 },
    piece_pare_choc_arriere = { repairs = { 'pare_choc_arriere' },                                      carried = true, price = 120 },
    piece_portiere           = { repairs = { 'portiere_avg', 'portiere_avd', 'portiere_arg', 'portiere_ard' }, carried = true, price = 200 },
    piece_aile                = { repairs = { 'aile_avg', 'aile_avd' },                                   carried = true, price = 140 },
    piece_bas_caisse            = { repairs = { 'bas_caisse' },                                            carried = true, price = 160 },
    piece_coffre                  = { repairs = { 'coffre' },                                                carried = true, price = 160 },
    piece_vitre                     = { repairs = { 'vitres' },                                                carried = true, price = 90 },
    piece_phare                       = { repairs = { 'phares' },                                                carried = true, price = 70 },

    -- Mécanique / pneus (consommées directement depuis l'inventaire, non portées)
    piece_pneu               = { repairs = { 'pneu_avg', 'pneu_avd', 'pneu_arg', 'pneu_ard' }, carried = false, price = 80 },
    piece_moteur               = { repairs = { 'moteur' },       carried = false, price = 250 },
    piece_freins                 = { repairs = { 'freins' },       carried = false, price = 150 },
    piece_transmission             = { repairs = { 'transmission' }, carried = false, price = 220 },
    piece_suspension                  = { repairs = { 'suspension' },   carried = false, price = 180 },
    piece_embrayage                     = { repairs = { 'embrayage' },    carried = false, price = 170 },
    piece_radiateur                       = { repairs = { 'radiateur' },    carried = false, price = 140 },
}

-- Poids maximal du stock de chaque garage (DataStore atelier_<company>).
Config.Atelier.StashMaxWeight = 2000.0

-- Main d'œuvre facturée au client, en plus du prix de la pièce.
Config.Atelier.LaborPrices = {
    mechanical = 250,
    tyres      = 60,
    body       = 100,
}

