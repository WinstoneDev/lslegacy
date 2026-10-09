--  MODULE BLAINE COUNTY SHERIFF'S OFFICE — Configuration principale
--  Framework : LSLegacy (custom)
--
--  Périmètre actuel : identité du métier, station (blip + borne de
--  service) et prise de service. Le vestiaire, l'armurerie et le garage
--  sont volontairement absents : la prise de service se fait depuis le
--  tableau de bord du MDT, et l'équipement suivra dans un second temps.

Config.Sheriff = {}

-- Job rattaché au module
Config.Sheriff.Job = 'sheriff'

-- Station principale (Paleto Bay)
-- Le shérif tient le comté (zone rurale), la police nationale la zone
-- urbaine — répartition calquée sur le modèle county sheriff / city police.
Config.Sheriff.Headquarters = vector3(-448.6, 6012.6, 31.7)
Config.Sheriff.HeadquartersHeading = 315.0

-- Blips carte
Config.Sheriff.Blips = {
    {
        coords = Config.Sheriff.Headquarters,
        sprite = 60,
        color  = 5,      -- tan/or, distinct du bleu police et du rouge EMS
        scale  = 0.9,
        label  = "Sheriff's Station",
        short  = true,
    },
}

-- Notifications
Config.Sheriff.NotifyDuration = 30000

-- Borne de prise de service à la station
-- La prise de service reste aussi disponible depuis le MDT ; les deux
-- chemins appellent la même bascule.
Config.Sheriff.DutyZone = true
