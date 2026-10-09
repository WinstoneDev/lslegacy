-- Comportement custom des armes non-létales (LBD 40, Lanceur Cougar,
-- Gazeuse, grenades lacrymogène/fumigène). Toutes ces armes viennent du
-- pack tiers Commods (resources/[Autres]/non_letale) : par défaut elles
-- n'ont aucun comportement scripté (dégâts/effets natifs GTA). Ce module
-- ajoute la couche de gameplay demandée par-dessus.

Config.NonLethal = {

    LBD = {
        weapon = 'WEAPON_LBD',

        damageBody = 5,
        damageHead = 10,

        bodyRagdollMs = 400,   -- corps touché : déséquilibre bref
        headRagdollMs = 1000,  -- tête touchée : chute plus marquée
        headStunMs    = 3000,  -- + sprint/saut bloqués après la chute
    },

    Cougar = {
        weapon = 'WEAPON_LGCOUGAR',

        -- Munition actuellement chargée (choisie en jeu, clic droit sur
        -- l'arme dans l'inventaire) : consomme l'item correspondant, 1 par
        -- tir, et applique la même zone d'effet que la grenade lancée à la
        -- main (Config.NonLethal.Zones ci-dessous).
        AmmoTypes = {
            gaz      = { item = 'weapon_bzgas',        label = 'Grenade lacrymogène', zone = 'gaz' },
            fumigene = { item = 'weapon_smokegrenade', label = 'Grenade fumigène',    zone = 'fumigene' },
        },

        -- Portée de l'estimation d'impact (tir en arc approximé par un
        -- tir tendu jusqu'à cette distance, cf. client/cougar.lua).
        MaxRange = 40.0,
    },

    Gazeuse = {
        weapon = 'WEAPON_GAZEUSE',

        maxCharges    = 100,  -- non rechargeable : la gazeuse est retournée au dépôt une fois à 0
        chargePerTick = 1,
        tickMs        = 250,  -- 1 charge / 250ms tant que le jet est maintenu (~10s d'autonomie cumulée)

        radius        = 3.0,
        duration      = 10000,
        damagePerTick = 1,
        damageTickMs  = 2500,
    },

    -- Zones d'effet des grenades lancées à la main ET du Cougar (qui
    -- réutilise le même effet que la grenade correspondante).
    Zones = {
        gaz = {
            radius        = 6.0,
            duration      = 20000,
            damagePerTick = 1,
            damageTickMs  = 2500,
        },
        fumigene = {
            radius   = 6.0,
            duration = 28000,
            -- Pas de dégâts : purement visuel (fumée dense).
        },
    },

    -- Munition d'entrainement (item unique `ammo_training`, commun aux 6
    -- armes ci-dessous) : dégâts neutralisés tant qu'elle est chargée dans
    -- l'arme (effet visuel/sonore du tir natif conservé), + réaction légère
    -- côté victime en cas d'impact. Rechargée/déchargée via le système
    -- standard Config.AmmoForWeapon, tracée sur l'item arme via
    -- data.ammoType (cf. inventory/server/main.lua, event `removeAmmo`).
    TrainingAmmo = {
        ammoItem  = 'ammo_training',
        weapons   = {
            'weapon_combatpistol',       -- Sig Sauer P 2022
            'weapon_smg',                -- HK UMP9
            'weapon_specialcarbine',     -- HK G36C
            'weapon_specialcarbine_mk2', -- HK G36C Mk II
            'weapon_combatshotgun',      -- Benelli M4
            'weapon_heavysniper',        -- Sako TRG 42
            'weapon_pumpshotgun',        -- Remington 870
        },
        ragdollMs       = 350,  -- petite réaction côté victime touchée
        damageThreshold = 5,    -- ne réagit que si le coup encaissé est faible (munition training)
    },
}
