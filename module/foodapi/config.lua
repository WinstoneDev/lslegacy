-- module/foodapi — Pont générique entre le Core LSLegacy et les ressources
-- externes de restauration (ls_burgershot, ls_aldentes, ls_kebabking, ...).
--
-- Ce module ne contient AUCUNE logique métier de restaurant : il expose
-- seulement (1) une API publique par exports, utilisable depuis une autre
-- ressource sans manipuler les tables joueur du Core, et (2) le moteur de
-- péremption générique des aliments.
--
-- Pourquoi des exports plutôt que exports['lslegacy']:getSharedObject() :
-- un objet joueur qui traverse la frontière d'une ressource est recopié
-- (msgpack) — muter cette copie ne modifie rien côté serveur et perd la
-- métatable (player:MarkDirty). Les exports ci-dessous prennent donc
-- uniquement des valeurs primitives et exécutent la mutation ici.

Config.FoodAPI = {
    Debug = false,

    Perishable = {
        Enabled = true,

        -- Budget de fraîcheur d'un plat, en secondes, consommé à la vitesse
        -- du mode de stockage courant (voir Modes). 5h à l'air libre.
        DefaultShelfLife = 5 * 3600,

        -- Durée de vie équivalente dans un frigo domestique. Sert uniquement
        -- à calculer le taux du mode 'home' (DefaultShelfLife / ColdShelfLife).
        ColdShelfLife = 48 * 3600,

        -- Vitesse de consommation du budget selon l'endroit où se trouve l'item.
        --   ambient = sur soi, au sol, sur un plateau  -> 1s de budget par seconde
        --   home    = frigo d'un logement joueur       -> ralenti (48h au total)
        --   pro     = frigo/congélateur professionnel  -> figé, aucune péremption
        Modes = {
            ambient = 1.0,
            home    = (5 * 3600) / (48 * 3600),
            pro     = 0.0,
        },

        -- Un DataStore est reconnu comme stockage froid par son `type`...
        ColdStorageTypes = {
            ['fridge']       = 'home',
            ['home_fridge']  = 'home',
            ['pro_fridge']   = 'pro',
        },

        -- ...ou par un motif Lua sur son `name` (les ressources restaurants
        -- enregistrent les leurs au démarrage via registerColdStorage).
        ColdStoragePatterns = {
            ['^home_fridge_'] = 'home',
            ['^frigo_']       = 'home',
        },
    },
}
