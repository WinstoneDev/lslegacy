--  MODULE GENDARMERIE NATIONALE — Configuration principale
--  Framework : LSLegacy (custom)
--
--  Périmètre actuel : identité du métier, caserne (blip + borne de
--  service) et prise de service. Le vestiaire, l'armurerie et le garage
--  sont volontairement absents : la prise de service se fait depuis le
--  tableau de bord du MDT, et l'équipement suivra dans un second temps.

Config.Gendarmerie = {}

-- Job rattaché au module
Config.Gendarmerie.Job = 'gendarmerie'

-- Caserne (brigade principale)
-- Poste de Paleto Bay : la gendarmerie tient la zone rurale, la police
-- nationale la zone urbaine — répartition classique en France.
Config.Gendarmerie.Headquarters = vector3(-448.6, 6012.6, 31.7)
Config.Gendarmerie.HeadquartersHeading = 315.0

-- Blips carte
Config.Gendarmerie.Blips = {
    {
        coords = Config.Gendarmerie.Headquarters,
        sprite = 60,
        color  = 2,      -- vert
        scale  = 0.9,
        label  = 'Brigade de Gendarmerie',
        short  = true,
    },
}

-- Notifications
Config.Gendarmerie.NotifyDuration = 30000

-- Borne de prise de service à la caserne
-- La prise de service reste aussi disponible depuis le MDT ; les deux
-- chemins appellent la même bascule.
Config.Gendarmerie.DutyZone = true
