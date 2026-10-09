-- ls_aldentes (client) — toutes les zones ox_target de la ressource.
-- Elles sont construites depuis config/config.lua : aucune coordonnée en dur ici.
--
-- Zones retirées : toutes les coordonnées de config/config.lua (pointeuse,
-- stations, stockages, plateaux, caisse) étaient des placeholders inventés,
-- jamais calibrés en jeu. En attendant les vraies positions (fournies par
-- l'utilisateur, resto par resto), aucune zone n'est créée ici pour éviter
-- des points d'interaction à des emplacements incorrects.
--
-- Une fois les coordonnées réelles connues, réintroduire ici les blocs
-- oxTarget:addBoxZone(...) pour ALDConfig.Duty, ALDConfig.Stations, ALDConfig.Storages,
-- ALDConfig.Trays.list et ALDConfig.Cash (voir ls_kebabking/client/target.lua pour
-- le patron à suivre).

local oxTarget = exports.ox_target
