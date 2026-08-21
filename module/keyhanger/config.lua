-- Porte-clés mural physique & interactif : maisons, appartements, garages, entreprises, factions, postes de police... Clés accrochées physiquement (props visibles en direct), récupérables et partageables. Config partagée client + serveur.

KeyHanger = KeyHanger or {}
KeyHanger.Config = {}

local C = KeyHanger.Config

C.Debug              = true           -- logs + tuning des offsets de slots (gizmo de debug)
C.Locale             = "fr"            -- langue (voir languages/)
C.Item               = "vehicle_key"   -- nom de l'item "clé de véhicule" (défini dans shared/config.lua)

-- Comportement de l'item "clé de véhicule" lorsqu'il est utilisé depuis l'inventaire.
C.Key = {
    useDistance   = 12.0,    -- distance max pour verrouiller/déverrouiller un véhicule avec la clé
    toggleEngine  = false,   -- true = un appui démarre/coupe aussi le moteur si on est au volant
    honkOnLock     = true,   -- petit klaxon + appel de phares au verrouillage (immersion)
    -- Commande de test pour se créer une clé du véhicule le plus proche.
    -- (En production les clés viennent normalement de l'achat/concession via l'export giveVehicleKey)
    createCommand = {
        enabled = true,
        name    = "creercle",
        group   = 3,         -- 0=user, 3=admin, 4=superadmin (mettre 0 pour autoriser tout le monde)
    },
}

C.Placement = {
    command      = "porteclefs",  -- /porteclefs : ouvre le mode placement
    group        = 3,             -- groupe staff minimum requis
    maxDistance  = 6.0,           -- portée du raycast de placement sur le mur
    snapToWall   = true,          -- colle automatiquement le support au mur visé (orientation normale)
    rotateStep   = 2.0,           -- pas de rotation manuelle (degrés)
    heightStep   = 0.02,          -- pas d'ajustement vertical (mètres)
    forwardStep  = 0.02,          -- pas d'ajustement profondeur (mètres)
}

-- Distance d'apparition des supports + clés autour du joueur.
C.Render = {
    spawnDistance = 40.0,   -- distance à laquelle les props apparaissent
    lod           = true,   -- masque les clés (garde le support) au-delà de keyLodDistance
    keyLodDistance = 18.0,  -- distance d'affichage des clés individuelles
}

-- Chaque support est adossé à un DataStore (comme un coffre de véhicule) ; les clés y sont déposées/récupérées via l'inventaire.
C.Storage = {
    maxWeight    = 2.0,    -- capacité du support en KG (clé ≈ 0.05 KG → ~40 clés)
    syncInterval = 1500,   -- ms : filet de sécurité pour resynchroniser les props
    onlyKeys     = true,   -- n'autorise QUE les clés de véhicule dans le support
}

-- Props natifs GTA V par défaut (fonctionnent sans stream). Pour un modèle custom : déposez le .ydr/.ytd dans module/keyhanger/stream/ et ajoutez-le ici (voir stream/README_PROPS.md).
-- Modèles vérifiés existants dans GTA V de base.
C.Boards = {
    ["board_cork"] = {
        label = "Liège",
        model = "prop_cork_board",          -- panneau de liège mural
        slots = "grid_5x2",
    },
    ["board_wood"] = {
        label = "Bois clair",
        model = "prop_muster_wboard_01",    -- planche en bois murale
        slots = "grid_4x2",                  -- disposition de slots (voir C.SlotLayouts)
    },
    ["board_dark"] = {
        label = "Bois foncé",
        model = "prop_muster_wboard_02",    -- planche en bois (variante)
        slots = "grid_6x3",
    },
    -- Exemple de support custom (décommenter après avoir stream le modèle) :
    -- ["board_custom"] = { label = "Porte-clés custom", model = "lslegacy_keyhanger", slots = "grid_4x2" },
}
C.DefaultBoard = "board_cork"

-- Pool de modèles de clés natifs ; le choix par clé est déterministe (basé sur la plaque) pour rester cohérent entre clients.
C.KeyProps = {
    "prop_cs_keys_01",   -- trousseau de clés (hash 403319434)
    "prop_cuff_keys_01", -- petites clés
}

-- Rotation appliquée aux clés accrochées (pour qu'elles "pendent" joliment).
-- {pitch, roll} en degrés ; le yaw suit l'orientation du support.
C.KeyRotation = { pitch = 12.0, roll = 0.0 }

-- Position de chaque clé relative au support : x = latéral (droite +), y = profondeur (avant +), z = vertical (haut +), en mètres. Réglez finement avec C.Debug = true (gizmo affichant les index de slot).
local function buildGrid(cols, rows, opt)
    opt = opt or {}
    local startX  = opt.startX  or -((cols - 1) * (opt.stepX or 0.11)) / 2
    local startZ  = opt.startZ  or ((rows - 1) * (opt.stepZ or 0.13)) / 2
    local stepX   = opt.stepX   or 0.11
    local stepZ   = opt.stepZ   or 0.13
    local depth   = opt.depth   or 0.05
    local slots = {}
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            slots[#slots + 1] = {
                x = startX + c * stepX,
                y = depth,
                z = startZ - r * stepZ,
            }
        end
    end
    return slots
end

C.SlotLayouts = {
    grid_4x2 = buildGrid(4, 2, { stepX = 0.12, stepZ = 0.16, depth = 0.06, startZ = 0.10 }),
    grid_5x2 = buildGrid(5, 2, { stepX = 0.11, stepZ = 0.16, depth = 0.04, startZ = 0.12 }),
    grid_6x3 = buildGrid(6, 3, { stepX = 0.10, stepZ = 0.14, depth = 0.05, startZ = 0.16 }),
}

-- Qui peut accrocher / récupérer des clés sur le support :
--    personal : le propriétaire (identifier) + liste de partage
--    job      : tous les membres d'un métier (owner_id = nom du job)
--    faction  : tous les membres d'une faction (owner_id = nom de faction)
--    shared   : propriétaire + liste de partage explicite
--    public   : tout le monde
C.AccessTypes = {
    { value = "personal", label = "Personnel" },
    { value = "job",      label = "Métier" },
    { value = "faction",  label = "Faction" },
    { value = "shared",   label = "Partagé" },
    { value = "public",   label = "Public" },
}

-- Grade minimum d'un métier/faction pour GÉRER le support (placer/partager/retirer).
-- 0 = n'importe quel membre. Les clés restent accrochables/récupérables par tous les membres.
C.ManageGrade = 0

C.Target = {
    distance = 2.5,                 -- distance max pour afficher l'interaction
    radius   = 1.3,                 -- rayon de la zone de ciblage (autour du support)
    zOffset  = 0.0,                 -- décalage vertical du centre de la zone
    icon     = "fa-solid fa-key",
}

C.Anim = {
    dict = "anim@am_hold_up@male",
    name = "shoplift_high",
    time = 900,
}

--- Retourne la table de définition d'un support à partir de sa clé de modèle.
function KeyHanger.GetBoardDef(boardKey)
    return C.Boards[boardKey] or C.Boards[C.DefaultBoard]
end

--- Retourne la liste de slots (positions relatives) pour une définition de support.
function KeyHanger.GetSlots(boardKey)
    local def = KeyHanger.GetBoardDef(boardKey)
    return C.SlotLayouts[def.slots] or C.SlotLayouts.grid_4x2
end

--- Nombre maximum de clés pour un support.
function KeyHanger.GetMaxSlots(boardKey)
    return #KeyHanger.GetSlots(boardKey)
end

--- Choix déterministe d'un prop de clé en fonction de la plaque (cohérent multi-clients).
function KeyHanger.PickKeyProp(plate)
    if not plate or plate == "" then return C.KeyProps[1] end
    local sum = 0
    for i = 1, #plate do sum = sum + string.byte(plate, i) end
    return C.KeyProps[(sum % #C.KeyProps) + 1]
end
