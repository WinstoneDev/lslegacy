-- =====================================================================
--  MODULE SIT — "S'asseoir n'importe où"
--  Module LSLegacy (Bastien MAGAN) — port du fonctionnement réel de
--  mnr_sitanywhere (github.com/Monarch-Devs/mnr_sitanywhere, client MIT)
--  adapté à ce framework (ox_target, ox_lib, callbacks propres).
--
--  Principe (repris tel quel du script original, PAS de "sit anywhere"
--  générique sur n'importe quel prop) :
--   - Seuls les modèles listés dans data/models.lua affichent l'option
--     ox_target "S'asseoir" (target.addModel, liste fermée).
--   - Chaque modèle définit 1+ places assises avec un offset LOCAL
--     (x, y, z, heading) relatif à l'objet, obtenu en calibrant chaque
--     prop en jeu (siège de banc, chaise, canapé...).
--   - La position/heading du joueur est calculée en tournant cet offset
--     par le heading RÉEL de l'objet (et pas celui du joueur), donc le
--     joueur est toujours assis dans le bon axe, quelle que soit la
--     rotation de l'objet dans le monde.
--   - L'assise joue une vraie scenario GTA native (PROP_HUMAN_SEAT_*),
--     pas une anim bricolée : c'est ce qui donne une pose correcte et
--     stable sans flotter/s'enfoncer.
-- =====================================================================

Sit = Sit or {}
Sit.Config = {}

local C = Sit.Config

C.Key      = "X"     -- touche pour se relever (keybind ox_lib, remappable)
C.Distance = 3.0      -- distance de ciblage ox_target sur les modèles supportés
