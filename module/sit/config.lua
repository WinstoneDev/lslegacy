-- Port de mnr_sitanywhere (github.com/Monarch-Devs/mnr_sitanywhere, MIT) adapté à LSLegacy (ox_target, ox_lib).
-- Liste fermée : seuls les modèles de data/models.lua affichent l'option "S'asseoir".

Sit = Sit or {}
Sit.Config = {}

local C = Sit.Config

C.Key      = "X"     -- touche pour se relever (keybind ox_lib, remappable)
C.Distance = 3.0      -- distance de ciblage ox_target sur les modèles supportés
