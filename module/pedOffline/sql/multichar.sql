-- =============================================================
--  pedOffline — migration multicharacter
--  À exécuter une seule fois. Faire un dump de sauvegarde avant.
-- =============================================================

-- La clé des peds endormis (`citizenid`) passe de "identifier" à
-- "identifier#slot" (ex: "license:abcd...#2") pour que se reconnecter avec
-- un autre personnage du même compte ne supprime plus / n'écrase plus le
-- ped endormi laissé par le premier. `varchar(50)` était trop juste pour
-- le suffixe "#slot" (license: + 40 car. = 48, quasi plein).
ALTER TABLE `exit_sleeping` MODIFY COLUMN `citizenid` VARCHAR(70) NOT NULL;

-- Aucune donnée existante n'est réécrite : les peds déjà endormis au moment
-- de la migration restent indexés sous l'ancien format (identifier seul) et
-- ne seront pas automatiquement supprimés à la reconnexion de leur
-- personnage — ils resteront simplement sur place jusqu'à la purge
-- automatique (Config pedOfflineCfg.purgeDay, module/pedOffline/config.lua).
