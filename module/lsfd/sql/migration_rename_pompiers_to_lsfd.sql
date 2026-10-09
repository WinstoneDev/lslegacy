-- Migration : renommage du métier "pompiers" en "lsfd" (Los Santos Fire Department)
-- À exécuter UNE SEULE FOIS sur une base existante, après mise à jour du code.
-- Sans cette migration, les joueurs déjà employés comme pompiers repassent
-- "Chômeur" (job introuvable) et l'historique de service (pompiers_agents) est perdu.

RENAME TABLE `pompiers_agents` TO `lsfd_agents`;

UPDATE `players` SET `job` = 'lsfd' WHERE `job` = 'pompiers';
