--  MODULE POLICE NATIONALE — DIALOGUES CONTEXTUELS DES REQUÉRANTS
--
--  Un requérant ne dit pas la même chose selon QUI il est et OÙ il se
--  trouve. Un ouvrier de zone industrielle ne « sort pas de chez lui »,
--  un promeneur de parc ne « travaille pas ici », un touriste ne fait
--  pas de ronde de surveillance.
--
-- SÉLECTION EN TROIS TEMPS
--    1. LIEU     déduit de la catégorie d'emplacement et de la zone
--    2. PROFIL   tiré parmi ceux qui sont PLAUSIBLES dans ce lieu
--    3. PHRASE   tirée parmi celles écrites pour (mission, lieu, profil)
--
--  Le profil étant contraint par le lieu, aucune phrase incompatible ne
--  peut être atteinte : il n'existe pas d'« employé du magasin » dans
--  une rue, ni de « vigile » dans un parc.
--
-- STRUCTURE
--    Lines[mission][lieu][profil] = { variantes }
--    Lines[mission][lieu]['*']    = variantes valables pour tout profil
--    Lines[mission]['*'][profil]  = variantes valables partout
--    Lines[mission]['*']['*']     = repli propre à la mission
--    Fallback                     = repli neutre, sans aucun détail
--
--  La recherche descend cette liste dans l'ordre et s'arrête au premier
--  ensemble non vide. Le repli neutre n'invente jamais de domicile, de
--  travail ni de lien avec la victime.
--
-- AJOUTER DU CONTENU
--    · une variante  : une ligne dans la liste concernée ;
--    · un profil     : l'ajouter à ProfilesByPlace du lieu voulu, puis
--                      écrire ses phrases ;
--    · un lieu       : l'ajouter à PlaceByCategory ou PlaceByZone, lui
--                      donner une entrée dans ProfilesByPlace ;
--    · une mission   : une entrée dans Lines avec au minimum ['*']['*'].
--  Aucune modification de code n'est nécessaire dans les trois cas.

Config              = Config or {}
Config.Police       = Config.Police or {}
Config.Police.Dialogues = {}

local D = Config.Police.Dialogues

-- TYPES DE LIEU
-- La catégorie d'emplacement prime : un magasin reste un magasin quelle
-- que soit la zone qui l'entoure.
D.PlaceByCategory = {
    shop      = 'magasin',
    nightlife = 'bar',
    parking   = 'parking',
    doorstep  = 'habitation',
}

-- À défaut, le type de lieu découle de la population de la zone.
D.PlaceByZone = {
    industrial  = 'industriel',
    park        = 'parc',
    beach       = 'plage',
    residential = 'residentiel',
    affluent    = 'residentiel',
    urban       = 'urbain',
    downtown    = 'centre',
    rural       = 'rural',
    desert      = 'rural',
}

D.PlaceFallback = 'urbain'

-- PROFILS PLAUSIBLES PAR LIEU
-- C'est ici que se joue la cohérence : un profil absent de cette liste
-- ne peut JAMAIS être tiré dans ce lieu.
D.ProfilesByPlace = {
    habitation  = { 'proprietaire', 'habitant' },
    residentiel = { 'habitant', 'passant', 'promeneur' },
    urbain      = { 'passant', 'habitant', 'employe' },
    centre      = { 'passant', 'employe', 'client' },
    industriel  = { 'ouvrier', 'employe', 'chauffeur', 'vigile' },
    parc        = { 'promeneur', 'joggeur', 'passant' },
    plage       = { 'promeneur', 'touriste', 'passant' },
    parking     = { 'automobiliste', 'passant', 'employe' },
    magasin     = { 'employe', 'client', 'commercant', 'vigile' },
    bar         = { 'fetard', 'client', 'vigile' },
    rural       = { 'habitant', 'passant', 'chauffeur' },
}

-- PROFILS IMPOSÉS
-- Certains scénarios désignent explicitement leur requérant : le vigile
-- d'un vol à l'étalage, le propriétaire d'un logement cambriolé. Le
-- profil est alors imposé, sans tirage.
D.ProfileByScenario = {
    constatation_effraction = 'proprietaire',
    cambriolage             = 'habitant',
    vol_etalage             = 'vigile',
    tapage                  = 'habitant',
}

-- Le pool de PNJ d'origine peut lui aussi trancher.
D.ProfileByPool = {
    residents = 'habitant',
    guards    = 'vigile',
    clubbers  = 'fetard',
}

-- REPLI NEUTRE
-- Aucune mention de domicile, de travail ni de lien avec les personnes
-- impliquées : ces phrases sont valables partout, pour n'importe qui.
D.Fallback = {
    "J'ai vu ce qui se passait et j'ai appelé tout de suite.",
    "Je n'ai pas voulu rester sans rien faire, j'ai composé le 17.",
    "C'est moi qui vous ai appelés. Je vous attendais.",
    "J'ai préféré prévenir la police, ça n'avait pas l'air normal.",
}

D.Lines = {}
local L = D.Lines

--  CONSTATATION DE VOL PAR EFFRACTION
--  Le requérant est chez lui, devant sa porte forcée.
L.constatation_effraction = {
    habitation = {
        proprietaire = {
            "On a forcé ma porte pendant que j'étais sorti. Je n'ai touché à rien, je vous attendais.",
            "Je rentre du travail et tout est retourné. La serrure a sauté, ils sont passés par là.",
            "Ma voisine m'a prévenu, la porte était grande ouverte. Je n'ose pas trop regarder ce qui manque.",
            "Ils ont fracturé pendant la journée. Il y a des traces sur le montant, venez voir.",
            "J'ai trouvé la porte entrebâillée en rentrant. Je ne suis pas entré, j'ai appelé depuis le palier.",
        },
        habitant = {
            "C'est chez moi. La serrure est arrachée, je n'ai touché à rien depuis.",
            "J'habite ici. En rentrant, la porte ne fermait plus, elle avait été forcée.",
        },
    },
    ['*'] = {
        ['*'] = {
            "La porte a été forcée. Je n'ai rien déplacé en attendant votre arrivée.",
            "Il y a eu une effraction. J'ai préféré vous attendre dehors.",
        },
    },
}

--  DÉCOUVERTE DE CORPS SUR LA VOIE PUBLIQUE
L.decouverte_corps = {
    residentiel = {
        habitant = {
            "Je sortais de chez moi et il était étendu là. Je ne l'avais jamais vu dans le quartier.",
            "J'ai vu quelque chose depuis ma fenêtre. En descendant, j'ai compris que c'était grave.",
            "Je rentrais chez moi quand je l'ai trouvé sur le trottoir. Je n'ai touché à rien.",
        },
        promeneur = {
            "Je promenais mon chien quand je l'ai vu par terre. J'ai cru qu'il dormait, puis j'ai compris.",
        },
        passant = {
            "Je passais dans la rue et je l'ai trouvé comme ça. J'ai appelé tout de suite.",
        },
    },
    industriel = {
        ouvrier = {
            "On travaillait dans le bâtiment voisin quand un collègue l'a repéré en sortant.",
            "Je terminais mon poste. En traversant pour rejoindre le parking, je l'ai vu au sol.",
        },
        employe = {
            "Je finissais mon service quand j'ai remarqué quelque chose d'anormal près des entrepôts.",
            "Je suis sorti prendre l'air derrière le bâtiment et je l'ai découvert là.",
        },
        chauffeur = {
            "Je venais faire une livraison quand j'ai aperçu la scène. Je n'ai pas bougé le camion.",
            "Je manœuvrais pour me garer et je l'ai vu dans mon rétroviseur, allongé.",
        },
        vigile = {
            "Je faisais ma ronde quand je l'ai découvert près du portail. J'ai sécurisé les abords.",
            "Ma tournée de nuit passe par là. Il n'y était pas au tour précédent.",
        },
    },
    parc = {
        promeneur = {
            "Je promenais mon chien quand je l'ai vu par terre. J'ai cru qu'il dormait, puis j'ai compris.",
            "Je faisais le tour de l'allée comme tous les matins et il était étendu là.",
        },
        joggeur = {
            "Je faisais mon parcours habituel quand j'ai vu ce qui se passait. Je me suis arrêté net.",
            "Je courais sur le sentier, je l'ai dépassé puis j'ai fait demi-tour : il ne bougeait pas.",
        },
        passant = {
            "Je traversais le parc et je l'ai trouvé comme ça. Je n'ai touché à rien.",
        },
    },
    plage = {
        promeneur = {
            "Je marchais le long du front de mer quand je l'ai aperçu, immobile.",
            "Il y a du monde ici d'habitude, mais personne ne s'arrêtait. J'ai fini par comprendre.",
        },
        touriste = {
            "Je ne suis pas d'ici, je me promenais. J'ai vu cette personne au sol et j'ai cherché de l'aide.",
        },
        passant = {
            "Je passais par là et je l'ai trouvé étendu. J'ai appelé immédiatement.",
        },
    },
    centre = {
        passant = {
            "Je passais là et je l'ai trouvé comme ça. Je n'ai touché à rien, j'ai appelé tout de suite.",
            "Ça fait un moment qu'il est là, personne ne s'arrêtait. J'ai fini par composer le 17.",
        },
        employe = {
            "Je sortais du bureau pour ma pause quand je l'ai vu sur le trottoir.",
            "Je fermais la boutique et il était déjà là. Il n'a pas bougé depuis.",
        },
        client = {
            "Je sortais faire une course et je suis tombé dessus. Je n'ai pas osé m'approcher.",
        },
    },
    urbain = {
        passant = {
            "J'ai voulu lui parler, il ne réagissait plus du tout. Je n'ai pas su quoi faire d'autre.",
            "Je remontais la rue et il était étendu là. J'ai appelé sans réfléchir.",
        },
        habitant = {
            "J'habite juste au-dessus. Je suis descendu quand j'ai vu qu'il ne se relevait pas.",
        },
        employe = {
            "Je prenais mon service quand je l'ai remarqué en arrivant.",
        },
    },
    ['*'] = {
        ['*'] = {
            "Je l'ai trouvé comme ça. Je n'ai touché à rien, j'ai appelé tout de suite.",
            "Il ne réagissait plus du tout. Je n'ai pas su quoi faire d'autre.",
        },
    },
}

--  PERSONNE ERRANTE
L.personne_errante = {
    residentiel = {
        habitant = {
            "Elle tourne dans le quartier depuis ce matin. Elle ne sait plus où elle habite.",
            "Je la vois passer devant chez moi pour la troisième fois. Elle a l'air complètement perdue.",
        },
        promeneur = {
            "Elle m'a demandé son chemin, puis me l'a redemandé cinq minutes après.",
        },
        passant = {
            "Elle ne se souvient ni de son adresse ni de son nom. Je n'ai pas voulu la laisser seule.",
        },
    },
    industriel = {
        ouvrier = {
            "Elle s'est retrouvée entre les camions. Ce n'est pas un endroit pour se promener.",
            "On l'a vue déambuler entre les hangars. On l'a mise à l'écart en attendant.",
        },
        vigile = {
            "Elle a franchi le portail sans s'en rendre compte. Elle ne sait pas où elle est.",
        },
        chauffeur = {
            "J'ai failli ne pas la voir en manœuvrant. Elle marchait au milieu de la voie.",
        },
        employe = {
            "Elle est entrée dans la zone de livraison. Elle semble complètement désorientée.",
        },
    },
    parc = {
        promeneur = {
            "Ça fait une heure qu'elle marche sans savoir où aller. Elle a l'air désorientée.",
            "Elle s'est assise, s'est relevée, et a recommencé à tourner. Je n'ai pas osé partir.",
        },
        joggeur = {
            "Je la croise à chaque tour depuis une heure. Elle ne sait plus où elle est.",
        },
        passant = {
            "Elle m'a demandé trois fois le même chemin en dix minutes. Je crois qu'elle est perdue.",
        },
    },
    plage = {
        promeneur = {
            "Elle marche pieds nus depuis un moment sans savoir où elle va.",
        },
        touriste = {
            "Je ne connais pas la ville, mais je vois bien qu'elle est perdue. Elle ne répond pas vraiment.",
        },
        passant = {
            "Elle est là depuis un long moment, elle ne sait plus où elle habite.",
        },
    },
    centre = {
        passant = {
            "Cette personne tourne en rond depuis un long moment. Elle ne sait plus où elle habite.",
            "Elle m'a demandé trois fois le même chemin en dix minutes. Je crois qu'elle est perdue.",
        },
        employe = {
            "Elle est entrée deux fois dans la boutique sans rien demander. Elle semble perdue.",
        },
        client = {
            "Je l'ai vue errer devant les vitrines. Elle ne se souvient de rien.",
        },
    },
    urbain = {
        passant = {
            "Ça fait une heure qu'elle marche dans la rue sans savoir où aller. Elle a l'air désorientée.",
            "Elle ne se souvient ni de son adresse ni de son nom. Je n'ai pas voulu la laisser seule.",
        },
        habitant = {
            "Elle est passée devant l'immeuble plusieurs fois. Personne ne la connaît ici.",
        },
        employe = {
            "Elle stationne devant l'entrée depuis ce matin. Elle ne sait pas répondre aux questions.",
        },
    },
    ['*'] = {
        ['*'] = {
            "Cette personne ne sait plus où elle habite. Je n'ai pas voulu la laisser seule.",
            "Elle est désorientée depuis un moment. J'ai préféré vous appeler.",
        },
    },
}

--  RACOLAGE SUR LA VOIE PUBLIQUE
L.racolage = {
    urbain = {
        passant = {
            "On se fait aborder à chaque fois qu'on remonte cette rue.",
            "Il y a du passage toute la nuit, les voitures s'arrêtent sans arrêt.",
        },
        habitant = {
            "Ça se passe juste sous nos fenêtres, on n'ose plus sortir le soir.",
            "Les allées et venues durent jusqu'au matin. On ne dort plus.",
        },
        employe = {
            "Ça se passe devant le local, les clients n'osent plus venir le soir.",
        },
    },
    residentiel = {
        habitant = {
            "Ça se passe devant chez nous tous les soirs, on n'ose plus sortir.",
            "On a des enfants dans l'immeuble, ça ne peut plus durer.",
            "Les voitures s'arrêtent sous nos fenêtres toute la nuit.",
        },
        passant = {
            "On m'a abordé trois fois en remontant la rue. C'est constant ici.",
        },
        promeneur = {
            "Je ne peux plus faire le tour du pâté de maisons sans être interpellé.",
        },
    },
    industriel = {
        ouvrier = {
            "Ça se passe juste devant l'entrée du site, à chaque prise de poste de nuit.",
            "Les gars de l'équipe du soir se font aborder en sortant. Ça devient pénible.",
        },
        vigile = {
            "Je les vois s'installer devant le portail dès la tombée de la nuit.",
        },
        chauffeur = {
            "Je fais une pause ici toutes les nuits, on vient taper à la vitre du camion.",
        },
        employe = {
            "Ça se passe sur le parking de l'entreprise. Les collègues n'osent plus sortir seuls.",
        },
    },
    plage = {
        promeneur = {
            "Le front de mer est devenu invivable le soir, on nous aborde en permanence.",
        },
        touriste = {
            "On nous a abordés plusieurs fois en marchant. Ce n'est pas très agréable.",
        },
        passant = {
            "Il y a du passage toute la nuit dans ce coin. Les riverains se plaignent.",
        },
    },
    centre = {
        passant = {
            "Les clients se garent en double file, il y a du passage toute la nuit.",
            "On se fait aborder à chaque fois qu'on remonte cette rue.",
        },
        employe = {
            "Ça se passe juste devant la boutique. Les clients n'osent plus venir le soir.",
        },
        client = {
            "Je sortais d'un établissement et j'ai été abordé plusieurs fois de suite.",
        },
    },
    ['*'] = {
        ['*'] = {
            "Il y a du passage toute la nuit ici, ça ne peut plus durer.",
            "On se fait aborder en permanence dans cette rue.",
        },
    },
}

--  VOL À L'ARRACHÉ
L.vol_arrache = {
    urbain = {
        passant = {
            "Ils ont arraché le sac de cette personne et sont partis en courant.",
            "Tout s'est passé en quelques secondes, elle est tombée en essayant de résister.",
        },
        habitant = {
            "J'ai entendu crier en bas de l'immeuble, ils avaient déjà filé avec le sac.",
        },
        employe = {
            "J'ai vu la scène depuis l'entrée, ils ont attrapé le sac et détalé.",
        },
    },
    residentiel = {
        habitant = {
            "Ils ont arraché le sac d'une dame juste devant l'immeuble et sont partis en courant.",
            "J'ai entendu crier depuis mon balcon, le temps que je descende ils avaient filé.",
        },
        passant = {
            "Ça s'est passé devant moi, ils ont bousculé la personne et attrapé son sac.",
        },
        promeneur = {
            "Je promenais mon chien, ils sont passés en courant avec le sac à la main.",
        },
    },
    industriel = {
        ouvrier = {
            "Un collègue s'est fait arracher son sac en rejoignant sa voiture après le poste.",
        },
        employe = {
            "Ça s'est passé sur le chemin entre le bâtiment et le parking.",
        },
        vigile = {
            "J'ai vu la scène depuis mon poste. Ils sont partis par l'arrière du site.",
        },
        chauffeur = {
            "Je déchargeais quand j'ai vu quelqu'un se faire arracher son téléphone.",
        },
    },
    parc = {
        promeneur = {
            "Ils sont arrivés par derrière, ont arraché le sac et ont coupé par les allées.",
        },
        joggeur = {
            "Je courais quand j'ai vu la scène. Ils ont détalé vers la sortie.",
        },
        passant = {
            "Ça s'est passé sous mes yeux, la personne est tombée en essayant de retenir son sac.",
        },
    },
    plage = {
        promeneur = {
            "Ils ont profité de la foule sur la promenade pour arracher le sac.",
        },
        touriste = {
            "On m'a arraché mon sac en pleine promenade. Je n'ai rien pu faire.",
        },
        passant = {
            "Ils ont attrapé le sac et sont partis en courant vers la plage.",
        },
    },
    centre = {
        passant = {
            "Ils ont arraché le sac de cette personne et sont partis en courant.",
            "Ça s'est passé en pleine rue, tout le monde a vu mais personne n'a réagi.",
        },
        employe = {
            "Je tenais la porte de la boutique quand j'ai vu la scène juste devant.",
        },
        client = {
            "Je sortais du magasin quand ils ont bousculé quelqu'un pour prendre son sac.",
        },
    },
    ['*'] = {
        ['*'] = {
            "Ils ont arraché le sac et sont partis en courant. Tout s'est passé très vite.",
            "La personne s'est fait bousculer puis dépouiller sous nos yeux.",
        },
    },
}

--  BAGARRE DE RUE
L.bagarre_rue = {
    urbain = {
        passant = {
            "Ils se battent en pleine rue, ça a commencé par une insulte.",
            "Ça dure depuis plusieurs minutes, personne n'ose s'interposer.",
        },
        habitant = {
            "J'ai entendu les cris depuis chez moi. Ils sont plusieurs à se battre en bas.",
        },
        employe = {
            "Ça se passe juste devant l'entrée, j'ai préféré rester à l'intérieur.",
        },
    },
    residentiel = {
        habitant = {
            "Ça a commencé par des cris sous les fenêtres, maintenant ils en viennent aux mains.",
            "J'ai entendu du bruit et je suis descendu : ils se battent devant l'immeuble.",
        },
        passant = {
            "Ils se sont pris à partie en pleine rue, personne n'arrive à les séparer.",
        },
        promeneur = {
            "J'ai fait demi-tour avec le chien, ça tourne vraiment mal entre eux.",
        },
    },
    industriel = {
        ouvrier = {
            "Ça a dégénéré entre deux gars à la sortie du poste. On n'a pas réussi à les calmer.",
            "On a entendu du bruit depuis l'atelier et on les a trouvés en train de se battre dehors.",
        },
        vigile = {
            "Je faisais ma ronde quand ça a éclaté près du portail. Je ne peux pas intervenir seul.",
        },
        employe = {
            "Ça se passe devant l'entrée du site, ils sont plusieurs et ça monte.",
        },
        chauffeur = {
            "J'attendais pour décharger quand la bagarre a éclaté devant mon camion.",
        },
    },
    plage = {
        promeneur = {
            "Ça a démarré sur la promenade, ils se battent devant tout le monde.",
        },
        touriste = {
            "Il y a des enfants partout ici et ils se battent au milieu.",
        },
        passant = {
            "Ils en sont venus aux mains sur le front de mer, ça ne s'arrête pas.",
        },
    },
    parc = {
        promeneur = {
            "Ça a dégénéré près des bancs, ils se frappent devant les familles.",
        },
        joggeur = {
            "Je suis passé à côté en courant, ils étaient déjà au sol à se battre.",
        },
        passant = {
            "Personne n'ose s'approcher, ils sont plusieurs à se battre.",
        },
    },
    centre = {
        passant = {
            "Ils se battent en pleine rue, ça a commencé par une insulte.",
            "Ça fait plusieurs minutes que ça dure, personne n'ose intervenir.",
        },
        employe = {
            "Ils se battent juste devant la vitrine, j'ai peur qu'elle y passe.",
        },
        client = {
            "Je sortais d'une boutique quand la bagarre a éclaté à côté de moi.",
        },
    },
    ['*'] = {
        ['*'] = {
            "Ils en sont venus aux mains, personne n'arrive à les séparer.",
            "Ça se bagarre depuis plusieurs minutes, ça ne se calme pas.",
        },
    },
}

--  VOL DE VÉHICULE EN COURS  (parkings)
L.vol_vehicule = {
    parking = {
        automobiliste = {
            "Je revenais à ma voiture quand je les ai vus s'acharner sur celle d'à côté.",
            "Ils sont en train de forcer une portière, deux rangées plus loin.",
            "J'ai entendu l'alarme se déclencher et je les ai vus autour du véhicule.",
        },
        passant = {
            "Ils tournent autour des voitures depuis un moment, là ils en ont ouvert une.",
        },
        employe = {
            "Je surveille les allées et venées depuis l'entrée : ils forcent un véhicule au fond.",
        },
    },
    industriel = {
        vigile = {
            "Ma ronde passe par le parking du site, ils sont en train de forcer un véhicule.",
        },
        ouvrier = {
            "On sortait du poste et on les a vus sur la voiture d'un collègue.",
        },
        employe = {
            "C'est le parking de l'entreprise, ils s'en prennent aux véhicules du personnel.",
        },
        chauffeur = {
            "Je m'étais garé pour une pause, ils s'attaquent aux voitures juste à côté.",
        },
    },
    ['*'] = {
        ['*'] = {
            "Ils sont en train de forcer un véhicule, là, maintenant.",
            "Ils s'acharnent sur une voiture depuis plusieurs minutes.",
        },
    },
}

--  TRAFIC DE STUPÉFIANTS
L.trafic_stup = {
    residentiel = {
        habitant = {
            "Il y a un va-et-vient permanent au pied de l'immeuble, ça dure depuis des semaines.",
            "Les gens montent, redescendent au bout de deux minutes. On sait tous ce qui se passe.",
        },
        passant = {
            "On m'a proposé quelque chose en passant. Ils ne se cachent même plus.",
        },
        promeneur = {
            "Je change de trottoir tous les jours à cause d'eux.",
        },
    },
    industriel = {
        ouvrier = {
            "Ils se sont installés derrière les hangars. On les voit à chaque changement d'équipe.",
        },
        vigile = {
            "Je les repère à chaque ronde derrière le bâtiment. Ils filent dès qu'ils me voient.",
        },
        chauffeur = {
            "Je fais mes pauses ici, il y a un défilé de voitures qui n'a rien à faire là.",
        },
        employe = {
            "Ça se passe à l'arrière du site, là où il n'y a pas de caméras.",
        },
    },
    plage = {
        promeneur = {
            "Ils se sont installés derrière les cabines, il y a un passage incessant.",
        },
        touriste = {
            "On nous a abordés deux fois sur la promenade pour nous vendre quelque chose.",
        },
        passant = {
            "Ils font ça au vu de tout le monde sur le front de mer.",
        },
    },
    centre = {
        passant = {
            "Il y a un va-et-vient constant à cet endroit, ça n'a rien de normal.",
        },
        employe = {
            "Ça se passe juste à côté de l'entrée, ça fait fuir la clientèle.",
        },
        client = {
            "J'ai vu un échange en sortant, c'était assez clair.",
        },
    },
    urbain = {
        passant = {
            "Les gens s'arrêtent deux secondes et repartent. Toute la journée, tous les jours.",
        },
        habitant = {
            "Ça se passe sous nos fenêtres. On n'ose plus rien dire.",
        },
        employe = {
            "Ils sont installés devant le local, ça bloque l'accès aux clients.",
        },
    },
    ['*'] = {
        ['*'] = {
            "Il y a un va-et-vient permanent à cet endroit, ça n'a rien de normal.",
            "Les échanges se font au vu de tout le monde. Ça dure depuis trop longtemps.",
        },
    },
}

--  PERSONNE ARMÉE
L.personne_armee = {
    urbain = {
        passant = {
            "Cette personne est armée en pleine rue. Les gens s'écartent sur son passage.",
            "Il ne cache même pas son arme, il remonte la rue tranquillement.",
        },
        habitant = {
            "Je l'ai vu depuis la fenêtre, il est armé et il traîne en bas de l'immeuble.",
        },
        employe = {
            "J'ai fermé la porte du local, il est armé et il tourne juste devant.",
        },
    },
    residentiel = {
        habitant = {
            "Il y a quelqu'un d'armé en bas de l'immeuble. Personne n'ose sortir.",
            "Je l'ai vu depuis la fenêtre, il a une arme à la main. J'ai fait rentrer les enfants.",
        },
        passant = {
            "Cette personne est armée et marche dans la rue comme si de rien n'était.",
        },
        promeneur = {
            "J'ai fait demi-tour immédiatement, il a sorti quelque chose de sa veste.",
        },
    },
    industriel = {
        vigile = {
            "Je faisais ma ronde quand j'ai vu cette personne armée près du portail.",
            "Il rôde autour du site avec une arme. J'ai bouclé les accès.",
        },
        ouvrier = {
            "On a arrêté le travail, il y a un type armé qui traîne devant l'atelier.",
        },
        employe = {
            "On a confiné le personnel à l'intérieur, la personne est armée dehors.",
        },
        chauffeur = {
            "Je ne suis pas descendu du camion, il a une arme sur lui.",
        },
    },
    plage = {
        promeneur = {
            "Il y a un homme armé sur la promenade, les gens s'écartent sur son passage.",
        },
        touriste = {
            "On a tout de suite quitté la plage, cette personne est armée.",
        },
        passant = {
            "Il ne cache même pas son arme, il y a du monde partout ici.",
        },
    },
    centre = {
        passant = {
            "Cette personne est armée en pleine rue. Les gens s'écartent sur son passage.",
        },
        employe = {
            "J'ai baissé le rideau, il y a quelqu'un d'armé juste devant.",
        },
        client = {
            "Je suis resté à l'intérieur, il est armé et il tourne dehors.",
        },
    },
    ['*'] = {
        ['*'] = {
            "Cette personne est armée. Les gens s'écartent sur son passage.",
            "Il y a quelqu'un d'armé ici. Je me suis mis à l'abri avant d'appeler.",
        },
    },
}

--  DÉLIT DE FUITE
L.delit_fuite = {
    urbain = {
        passant = {
            "Il a percuté puis il a continué sa route sans s'arrêter.",
            "Le choc a été violent, il n'a même pas ralenti.",
        },
        habitant = {
            "J'ai entendu le choc depuis chez moi, il était déjà loin quand je suis descendu.",
        },
        employe = {
            "J'ai vu l'accident depuis l'entrée, le conducteur a pris la fuite aussitôt.",
        },
    },
    plage = {
        promeneur = {
            "Il roulait trop vite sur le front de mer, il a percuté et il a filé.",
        },
        touriste = {
            "J'ai vu la voiture heurter puis repartir immédiatement.",
        },
        passant = {
            "Il ne s'est pas arrêté, il a accéléré après le choc.",
        },
    },
    residentiel = {
        habitant = {
            "J'ai entendu le choc depuis chez moi. Le conducteur est reparti sans s'arrêter.",
            "Il a percuté un véhicule en stationnement devant l'immeuble et il a filé.",
        },
        passant = {
            "Il a heurté quelqu'un et il est reparti sans même ralentir.",
        },
        promeneur = {
            "J'ai tout vu, il n'a pas freiné une seconde après le choc.",
        },
    },
    industriel = {
        chauffeur = {
            "Il m'a touché en manœuvrant et il est reparti sans descendre.",
            "J'ai vu la scène depuis ma cabine, il ne s'est pas arrêté.",
        },
        ouvrier = {
            "Ça s'est passé devant l'entrée du site, il a percuté et il a filé.",
        },
        vigile = {
            "J'ai le numéro partiel sur ma vidéo, il est reparti immédiatement.",
        },
        employe = {
            "Il a heurté un véhicule du parc et il ne s'est pas arrêté.",
        },
    },
    parking = {
        automobiliste = {
            "Il a embouti ma voiture en reculant et il est parti sans laisser de mot.",
            "J'ai vu le choc depuis l'autre allée, il n'est même pas descendu.",
        },
        passant = {
            "Il a heurté un véhicule en manœuvrant et il a quitté le parking aussitôt.",
        },
        employe = {
            "Ça s'est passé à l'entrée du parking, il a percuté puis il a accéléré.",
        },
    },
    centre = {
        passant = {
            "Il a renversé quelqu'un et il a continué sa route sans s'arrêter.",
            "Le choc a été violent, il n'a pas ralenti une seconde.",
        },
        employe = {
            "J'ai vu la scène depuis la vitrine, le conducteur a pris la fuite.",
        },
        client = {
            "Je traversais quand ça s'est produit, il est reparti immédiatement.",
        },
    },
    ['*'] = {
        ['*'] = {
            "Le conducteur ne s'est pas arrêté après le choc.",
            "Il a percuté puis il a pris la fuite sans descendre du véhicule.",
        },
    },
}

--  IVRESSE PUBLIQUE  (sortie de bar)
L.ipm = {
    bar = {
        fetard = {
            "Il ne tient plus debout, on l'a sorti mais il refuse de rentrer chez lui.",
            "Il est dans cet état depuis une heure, il commence à embêter tout le monde.",
            "On a essayé de lui appeler un taxi, il ne veut rien entendre.",
        },
        vigile = {
            "Je l'ai refusé à l'entrée, il est resté planté là et il ne tient plus debout.",
            "Je l'ai sorti de l'établissement, il ne veut pas quitter les lieux.",
        },
        client = {
            "Il est tombé deux fois devant l'entrée. Il faut quelqu'un pour s'en occuper.",
        },
    },
    ['*'] = {
        ['*'] = {
            "Cette personne ne tient plus debout et refuse de rentrer.",
            "Elle est dans un état d'ivresse avancé, elle ne peut pas rester là.",
        },
    },
}

--  VOL À L'ÉTALAGE  (le requérant est le vigile)
L.vol_etalage = {
    magasin = {
        vigile = {
            "Je surveillais les caméras quand j'ai repéré le suspect. Je l'ai retenu à la sortie.",
            "Je l'ai vu dissimuler la marchandise dans sa veste avant de franchir les caisses.",
            "Il a passé les portiques sans payer, je l'ai intercepté juste après.",
        },
        employe = {
            "Je travaillais en rayon quand j'ai vu la personne prendre l'article et le glisser dans son sac.",
            "Je réapprovisionnais quand je l'ai surpris. Il n'a rien voulu entendre.",
        },
        commercant = {
            "C'est mon commerce. Je l'ai vu faire depuis la caisse, il n'a pas payé.",
            "Ça fait la troisième fois cette semaine. Cette fois je l'ai retenu.",
        },
        client = {
            "J'ai vu la personne glisser des articles dans son manteau. J'ai prévenu le personnel.",
        },
    },
    ['*'] = {
        ['*'] = {
            "La personne a pris de la marchandise sans la payer. Je l'ai retenue sur place.",
            "J'ai constaté le vol et je l'ai empêché de partir en attendant votre arrivée.",
        },
    },
}

--  CHIEN DANGEREUX
L.chien_dangereux = {
    -- Une personne a été mordue et se trouve au sol : toutes les
    -- formulations doivent en rendre compte. Le requérant n'est pas la
    -- victime, il a assisté à la scène.
    urbain = {
        habitant = {
            "Le chien a mordu quelqu'un et le maître n'arrive pas à le rappeler.",
            "Il s'est jeté sur un passant, la personne est à terre, elle saigne.",
        },
        passant = {
            "L'animal a chargé sans prévenir, la personne n'a pas pu l'éviter.",
            "Il a mordu quelqu'un devant moi. Le maître le regarde faire.",
        },
        employe = {
            "Il a attaqué une personne devant l'entrée, elle ne se relève pas.",
        },
    },
    centre = {
        passant = {
            "Un chien vient de mordre quelqu'un en pleine rue, la victime est au sol.",
        },
        employe = {
            "L'animal a mordu une personne devant la boutique, son maître est là.",
        },
        client = {
            "Il s'est jeté sur quelqu'un juste devant moi. La personne est blessée.",
        },
    },
    residentiel = {
        habitant = {
            "Ce chien n'est pas tenu et il vient de mordre quelqu'un dans la rue.",
            "Le maître ne le maîtrise pas du tout, il s'est jeté sur une personne.",
            "Il a attaqué un passant devant l'immeuble. La victime est restée au sol.",
        },
        passant = {
            "L'animal a chargé une personne sans prévenir. Son maître n'a rien pu faire.",
        },
        promeneur = {
            "Il s'en est pris à quelqu'un devant moi, je n'ai pas pu m'interposer.",
        },
    },
    parc = {
        promeneur = {
            "Il est lâché sans laisse et il vient de mordre une personne.",
            "L'animal a chargé quelqu'un au milieu des familles. La victime est à terre.",
        },
        joggeur = {
            "Je courais quand il s'est jeté sur une personne devant moi.",
        },
        passant = {
            "L'animal est incontrôlable, il a mordu quelqu'un et il y a des enfants ici.",
        },
    },
    plage = {
        promeneur = {
            "Il a mordu une personne sur la promenade, le maître ne le tient pas.",
        },
        touriste = {
            "Ce chien a attaqué quelqu'un, la personne est blessée au sol.",
        },
        passant = {
            "L'animal n'est pas tenu et il vient de s'en prendre à un passant.",
        },
    },
    industriel = {
        vigile = {
            "Le chien a mordu un livreur près du portail, son maître est sur place.",
        },
        ouvrier = {
            "Il a foncé sur un collègue, la personne est à terre.",
        },
        chauffeur = {
            "Il a mordu quelqu'un pendant que je déchargeais, je suis resté dans la cabine.",
        },
        employe = {
            "L'animal a attaqué une personne devant le bâtiment.",
        },
    },
    ['*'] = {
        ['*'] = {
            "Ce chien a mordu quelqu'un et son maître ne le maîtrise pas.",
            "L'animal a chargé une personne, elle est restée au sol.",
        },
    },
}

--  CAMBRIOLAGE RÉSIDENTIEL  (en cours)
L.cambriolage = {
    urbain = {
        habitant = {
            "Ils sont entrés dans l'appartement du dessous, les occupants sont absents.",
            "J'ai vu des inconnus forcer la porte du palier. Ils sont peut-être encore dedans.",
        },
        passant = {
            "J'ai vu plusieurs personnes escalader et entrer par une fenêtre.",
        },
        employe = {
            "Des individus sont entrés dans le logement voisin, ce n'est pas chez eux.",
        },
    },
    centre = {
        habitant = {
            "Ils sont entrés chez les voisins par la cour intérieure.",
        },
        passant = {
            "J'ai vu des personnes forcer une porte et entrer. Ça n'avait rien de normal.",
        },
        employe = {
            "Je fermais le local quand je les ai vus entrer par effraction à côté.",
        },
        client = {
            "J'ai vu des individus entrer par une fenêtre en passant.",
        },
    },
    residentiel = {
        habitant = {
            "Il y a du monde à l'intérieur, ce n'est pas chez eux. Je les ai vus entrer par l'arrière.",
            "Les voisins sont absents et j'ai vu de la lumière bouger à l'étage.",
            "Ils ont forcé une fenêtre côté jardin. Ils sont encore dedans, je crois.",
        },
        passant = {
            "J'ai vu plusieurs personnes escalader et entrer. Ça n'avait pas l'air normal.",
        },
        promeneur = {
            "Je passais avec le chien quand je les ai vus forcer la porte de derrière.",
        },
    },
    ['*'] = {
        ['*'] = {
            "Des individus se sont introduits dans le logement. Ils y sont peut-être encore.",
            "Ils sont entrés par effraction. Je n'ai pas bougé, j'ai appelé tout de suite.",
        },
    },
}

--  BRAQUAGE DE SUPÉRETTE
L.braquage_superette = {
    magasin = {
        employe = {
            "Ils sont entrés armés et ont exigé la caisse. Je me suis mis à terre.",
            "J'étais en caisse quand ils sont arrivés. Ils ont tout vidé et menacé le gérant.",
        },
        commercant = {
            "C'est ma boutique. Ils ont braqué la caisse et menacé tout le monde.",
            "Ils m'ont mis en joue derrière le comptoir. Ils ont pris la recette.",
        },
        client = {
            "Je faisais mes courses quand ils sont entrés armés. On s'est tous couchés.",
            "J'étais dans le rayon du fond, je les ai entendus crier et menacer la caissière.",
        },
        vigile = {
            "Ils sont passés devant moi armés. Je n'ai pas pu intervenir, il y avait des clients.",
        },
    },
    ['*'] = {
        ['*'] = {
            "Ils sont entrés armés et ont exigé la caisse.",
            "Le commerce vient d'être braqué. Tout le monde s'est mis à terre.",
        },
    },
}

--  TAPAGE  (riverain excédé, sono sur un parking)
L.tapage = {
    parking = {
        habitant = {
            "Ils ont installé une sono sur le parking, ça fait trois heures que ça dure.",
            "On entend la musique jusque dans les chambres, il y a des enfants qui dorment.",
            "J'ai demandé gentiment de baisser, ils m'ont ri au nez.",
        },
        automobiliste = {
            "Impossible de récupérer ma voiture, ils occupent toute l'allée avec leur musique.",
        },
        passant = {
            "On s'entend à peine parler dans la rue tellement c'est fort.",
        },
        employe = {
            "Ça se passe sur le parking, on ne peut plus travailler avec ce volume.",
        },
    },
    residentiel = {
        habitant = {
            "La musique vient de dehors et elle traverse les murs. Ça dure depuis ce soir.",
            "Tout l'immeuble est réveillé. Personne n'ose descendre leur parler.",
        },
        passant = {
            "On entend la sono à deux rues d'ici.",
        },
    },
    ['*'] = {
        ['*'] = {
            "La musique est beaucoup trop forte et ça dure depuis des heures.",
            "Le volume est insupportable, plus personne ne peut dormir.",
        },
    },
}

--  RIXE EN SOIRÉE
L.rixe_soiree = {
    bar = {
        fetard = {
            "Ça a dégénéré à la sortie, ils sont une dizaine à se battre.",
            "Une dispute à l'intérieur a fini dehors. Maintenant tout le monde s'y met.",
            "Ils sont sortis pour régler ça et ça a tourné à la bagarre générale.",
        },
        vigile = {
            "J'ai fait évacuer, mais ça continue dehors. On est trop peu pour les séparer.",
            "J'ai sorti deux clients, ça s'est envenimé sur le parvis avec les autres.",
        },
        client = {
            "Je suis resté à l'écart, ils se battent devant l'entrée depuis dix minutes.",
        },
    },
    ['*'] = {
        ['*'] = {
            "Ils sont plusieurs à se battre, personne n'arrive à les séparer.",
            "La bagarre a éclaté il y a quelques minutes et ça ne se calme pas.",
        },
    },
}

--  AUDITION DES MIS EN CAUSE
--
--  Un individu entendu sur les faits ne dit pas la vérité par défaut :
--  il nie, il se justifie, il provoque, ou il se tait. C'est ce qu'on
--  appelle ici son ATTITUDE.
--
-- CHOIX DE L'ATTITUDE
--  Tirée selon son COMPORTEMENT dans la mission (passif, fuyard,
--  agressif) et son état : un individu menotté baisse d'un ton, un
--  individu qui vient de charger la police reste sur la défensive.
--
-- CHOIX DE LA PHRASE
--  Même descente que pour les requérants :
--    Lines[mission][lieu][attitude] → [mission]['*'][attitude]
--    → repli neutre
--
-- ATTITUDES
--    nie       il conteste les faits
--    justifie  il reconnaît la scène mais la retourne à son avantage
--    provoque  il défie les agents
--    avoue     il reconnaît, rare
--    silence   il refuse de répondre

-- Poids des attitudes selon le comportement de l'individu.
D.SuspectStances = {
    passive    = { nie = 4, justifie = 4, avoue = 2, silence = 1 },
    flee       = { nie = 4, justifie = 3, silence = 2, provoque = 1 },
    aggressive = { provoque = 4, silence = 3, nie = 2 },
}

-- Un individu maîtrisé se calme : ces poids remplacent les précédents
-- dès qu'il est menotté ou neutralisé.
D.SuspectStancesCuffed = {
    nie = 4, justifie = 4, silence = 2, avoue = 2, provoque = 1,
}

-- Repli neutre : valable pour n'importe quel individu, n'importe où.
D.SuspectFallback = {
    nie      = { "Je n'ai rien fait, vous vous trompez de personne.",
                 "J'étais là par hasard, c'est tout." },
    justifie = { "Ce n'est pas ce que vous croyez, laissez-moi vous expliquer.",
                 "Il y a un malentendu, j'allais partir de toute façon." },
    provoque = { "Vous n'avez rien contre moi. Rien du tout.",
                 "Faites ce que vous avez à faire, je connais mes droits." },
    avoue    = { "Bon… d'accord. C'est moi. Je ne vais pas mentir.",
                 "Oui, c'est moi. Je n'aurais pas dû." },
    silence  = { "Je ne dirai rien sans avocat.",
                 "Je n'ai rien à vous dire." },
}

D.SuspectLines = {}
local SL = D.SuspectLines

SL.racolage = {
    ['*'] = {
        nie      = { "J'attends quelqu'un, c'est interdit d'attendre maintenant ?",
                     "Je prends l'air. Il n'y a pas de loi contre ça." },
        justifie = { "Je discutais, rien de plus. Les gens parlent, dans la rue.",
                     "Je ne demande rien à personne, ce sont eux qui s'arrêtent." },
        provoque = { "Vous n'avez qu'à verbaliser les voitures, pas moi.",
                     "C'est toujours sur nous que ça tombe." },
        avoue    = { "Il faut bien vivre. Je ne fais de mal à personne." },
        silence  = { "Je n'ai rien à déclarer." },
    },
}

SL.vol_arrache = {
    ['*'] = {
        nie      = { "Quel sac ? Je courais parce que je suis en retard.",
                     "Vous confondez, je n'ai touché à personne." },
        justifie = { "Elle m'est rentrée dedans, j'ai voulu la rattraper.",
                     "J'ai trouvé le sac par terre, j'allais le rapporter." },
        provoque = { "Prouvez-le. Vous n'avez rien vu du tout.",
                     "Tout le monde court dans cette rue, arrêtez-les aussi." },
        avoue    = { "J'avais besoin d'argent. Ça s'est fait comme ça." },
        silence  = { "Je ne réponds pas." },
    },
}

SL.bagarre_rue = {
    ['*'] = {
        nie      = { "Je me défendais, c'est lui qui a commencé.",
                     "On discutait fort, ce n'est pas une bagarre." },
        justifie = { "Il m'a insulté devant tout le monde, j'ai réagi.",
                     "Ça fait des semaines qu'il me cherche, ça devait sortir." },
        provoque = { "Vous arrivez maintenant ? Fallait venir plus tôt.",
                     "Séparez-nous et laissez-nous tranquilles." },
        avoue    = { "J'ai frappé le premier, oui. J'ai perdu mon calme." },
        silence  = { "Demandez-lui à lui." },
    },
    bar = {
        nie      = { "On sortait de l'établissement, il y a eu une bousculade.",
                     "C'est la foule, personne ne s'est battu." },
        justifie = { "Il a renversé mon verre et il ne s'est même pas excusé." },
        provoque = { "Le videur peut vous le dire, ce n'est pas moi." },
        silence  = { "Je ne dirai rien ici." },
    },
}

SL.rixe_soiree = {
    ['*'] = {
        nie      = { "Je passais, j'ai été pris dans la foule.",
                     "Je n'ai frappé personne, regardez mes mains." },
        justifie = { "Ils s'en sont pris à mon groupe, on s'est défendus.",
                     "Ça a dégénéré tout seul, personne ne voulait ça." },
        provoque = { "Il y a trente personnes ici, pourquoi moi ?",
                     "Vous allez tous nous embarquer, peut-être ?" },
        avoue    = { "Oui, j'étais dedans. J'avais trop bu." },
        silence  = { "Je ne parle pas." },
    },
}

SL.vol_vehicule = {
    ['*'] = {
        nie      = { "C'est la voiture d'un ami, j'avais oublié mes clés.",
                     "Je regardais si elle était fermée, c'est tout." },
        justifie = { "On m'a demandé de la déplacer, je rendais service.",
                     "Elle était déjà ouverte quand je suis arrivé." },
        provoque = { "Elle est encore là, non ? Il n'y a pas de vol.",
                     "Vous m'accusez sans preuve." },
        avoue    = { "Je voulais la prendre, oui. Je n'ai pas réussi." },
        silence  = { "Sans avocat, je ne dis rien." },
    },
}

SL.trafic_stup = {
    ['*'] = {
        nie      = { "Je discute avec des gens du quartier, c'est tout.",
                     "Rien sur moi, vous pouvez regarder." },
        justifie = { "Ce sont des connaissances, on se croise, on parle.",
                     "J'attends quelqu'un depuis une heure, c'est long." },
        provoque = { "Vous êtes là tous les jours, vous n'avez jamais rien trouvé.",
                     "Fouillez-moi, on verra bien." },
        avoue    = { "C'est pour ma consommation, rien d'autre." },
        silence  = { "Je connais la procédure, je me tais." },
    },
    industriel = {
        nie      = { "Je fais une pause, l'entrepôt est juste derrière.",
                     "Je travaille dans le coin, je ne fais que passer." },
        justifie = { "On se retrouve ici après le poste, c'est tranquille." },
        provoque = { "Il n'y a personne ici, à qui je vendrais quoi ?" },
        silence  = { "Je n'ai rien à dire." },
    },
}

SL.personne_armee = {
    ['*'] = {
        nie      = { "Ce n'est pas une arme, regardez mieux.",
                     "Je ne menaçais personne, je marchais." },
        justifie = { "Je me sens en danger dans ce quartier, c'est pour me protéger.",
                     "Je la rapportais à un ami, elle n'est même pas chargée." },
        provoque = { "J'ai le droit de me défendre. Vous n'êtes jamais là.",
                     "Baissez la vôtre d'abord." },
        avoue    = { "Oui, je la porte. Je sais que je n'aurais pas dû." },
        silence  = { "Je ne réponds à aucune question." },
    },
}

SL.delit_fuite = {
    ['*'] = {
        nie      = { "Je n'ai rien senti, je ne savais pas qu'il y avait un choc.",
                     "Ce n'était pas moi au volant." },
        justifie = { "J'ai paniqué, je suis parti chercher de l'aide.",
                     "Je n'avais pas mes papiers, j'ai eu peur." },
        provoque = { "La voiture est là, personne n'est mort.",
                     "Vous n'avez aucun témoin." },
        avoue    = { "J'ai pris peur et je suis parti. C'est ma faute." },
        silence  = { "Je veux un avocat." },
    },
}

SL.ipm = {
    ['*'] = {
        nie      = { "Je n'ai bu qu'un verre… peut-être deux.",
                     "Je tiens debout, regardez." },
        justifie = { "C'était l'anniversaire d'un ami, ça arrive une fois par an.",
                     "J'attends un taxi, je ne conduis pas." },
        provoque = { "Je ne dérange personne. Laissez-moi tranquille.",
                     "Vous n'avez rien de mieux à faire ?" },
        avoue    = { "J'ai trop bu, je le sais. Je rentre." },
        silence  = { "Hmm… non. Rien." },
    },
}

SL.vol_etalage = {
    ['*'] = {
        nie      = { "J'allais payer, le vigile m'a arrêté avant.",
                     "Ce sont mes affaires, je les avais en entrant." },
        justifie = { "J'ai oublié que je l'avais dans la poche, ça arrive.",
                     "Il y avait la queue, je voulais revenir." },
        provoque = { "Pour trois articles, vous appelez la police ?",
                     "Votre vigile me colle depuis que je suis entré." },
        avoue    = { "Oui, je l'ai pris. Je n'avais pas de quoi payer." },
        silence  = { "Je ne dirai rien." },
    },
}

SL.cambriolage = {
    ['*'] = {
        nie      = { "Je me suis trompé de maison, je cherchais un ami.",
                     "La porte était déjà ouverte quand je suis passé." },
        justifie = { "On m'a demandé de récupérer des affaires, je ne savais pas.",
                     "Je voulais juste voir s'il y avait quelqu'un de blessé." },
        provoque = { "Je n'ai rien sur moi. Vous allez me relâcher.",
                     "Il n'y a pas de plaignant, pas de plainte." },
        avoue    = { "On est entrés, oui. On n'a rien pris encore." },
        silence  = { "Rien à déclarer." },
    },
}

SL.braquage_superette = {
    ['*'] = {
        nie      = { "Je faisais mes courses comme tout le monde.",
                     "Vous vous trompez, ce n'est pas moi." },
        justifie = { "Je n'ai menacé personne, l'arme n'était même pas chargée.",
                     "J'ai des dettes, je n'avais pas le choix." },
        provoque = { "Vous avez la caisse, vous avez tout. On en reste là.",
                     "Personne n'est blessé, calmez-vous." },
        avoue    = { "C'est moi. J'assume, arrêtez-moi." },
        silence  = { "Avocat. C'est tout ce que j'ai à dire." },
    },
}

SL.tapage = {
    ['*'] = {
        nie      = { "La musique n'est pas si forte, on s'entend parler.",
                     "Ce n'est pas nous, ça vient d'à côté." },
        justifie = { "On fête quelque chose, on allait bientôt arrêter.",
                     "Il est à peine minuit, on n'est pas en pleine nuit." },
        provoque = { "Personne ne s'est plaint à nous directement.",
                     "On coupe et vous partez, ça vous va ?" },
        avoue    = { "D'accord, on baisse. On ne s'est pas rendu compte." },
        silence  = { "Parlez à quelqu'un d'autre." },
    },
}

SL.chien_dangereux = {
    ['*'] = {
        nie      = { "Il n'a jamais mordu personne, il a dû jouer.",
                     "Ce n'est pas mon chien, je le promenais pour un voisin." },
        justifie = { "La laisse a cédé, je n'ai rien pu faire.",
                     "Il est nerveux depuis quelques semaines, j'aurais dû le tenir plus court.",
                     "Je le tenais, mais il a tiré d'un coup et le collier a lâché." },
        provoque = { "Les gens n'ont qu'à ne pas s'approcher.",
                     "Vous allez me le prendre pour un accident ?" },
        avoue    = { "C'est ma faute. Je n'aurais jamais dû le lâcher." },
        silence  = { "Je ne dirai rien de plus." },
    },
}


--  TÉMOIGNAGE DES VICTIMES
--
--  Une victime ne témoigne pas comme un requérant : elle a subi les
--  faits, elle en parle à la première personne, et son état s'entend
--  dans ce qu'elle dit.
--
-- SÉLECTION
--    Lines[mission][lieu] → Lines[mission]['*'] → repli neutre
--
--  Chaque entrée porte deux clés : `blesse` tant qu'elle est au sol,
--  `soigne` une fois les premiers secours prodigués.

D.VictimFallback = {
    blesse = {
        "Ça s'est passé si vite… je n'ai pas eu le temps de réagir.",
        "J'ai mal, mais ça va aller. Occupez-vous d'eux d'abord.",
        "Je n'arrive pas à me lever. Tout s'est enchaîné très vite.",
    },
    soigne = {
        "Merci. Ça va mieux. Je peux vous raconter ce qui s'est passé.",
        "Je m'en remettrai. Prenez ma déposition, je préfère en finir.",
    },
}

D.VictimLines = {}
local VL = D.VictimLines

VL.vol_arrache = {
    ['*'] = {
        blesse = {
            "Ils m'ont attrapée par-derrière, j'ai basculé en essayant de retenir mon sac.",
            "Je n'ai rien vu venir. Le temps de me relever, ils avaient disparu.",
            "Je me suis accrochée à la lanière, c'est là qu'ils m'ont poussée.",
        },
        soigne = {
            "Ils étaient au moins deux. Ils m'ont bousculée et ils ont arraché mon sac.",
            "J'avais mon téléphone à la main, ils me l'ont pris de force.",
        },
    },
    centre = {
        blesse = {
            "Il y avait du monde partout, personne n'a bougé. J'ai été projetée au sol.",
        },
        soigne = {
            "Je sortais d'une boutique quand ils m'ont fondu dessus.",
        },
    },
    plage = {
        blesse = {
            "Je marchais sur la promenade, ils sont arrivés par-derrière.",
        },
        soigne = {
            "Ils ont profité de la foule. Mon sac contenait mes papiers.",
        },
    },
    residentiel = {
        blesse = {
            "J'étais à deux pas de chez moi. Ils m'ont poussée contre le mur.",
        },
        soigne = {
            "Je rentrais chez moi, ils m'attendaient à l'angle de la rue.",
        },
    },
}

VL.delit_fuite = {
    ['*'] = {
        blesse = {
            "La voiture m'a percutée et elle n'a pas ralenti. Je n'ai pas vu la plaque.",
            "J'ai entendu le moteur accélérer, puis plus rien. Je me suis réveillée au sol.",
            "Il roulait vite. Il ne s'est même pas arrêté pour voir si j'étais vivante.",
        },
        soigne = {
            "Le conducteur est descendu, il m'a regardée, puis il est reparti en courant.",
            "C'était une voiture claire. Il a pris la fuite immédiatement après le choc.",
        },
    },
    centre = {
        blesse = {
            "Je traversais au passage piéton. Il a grillé le feu.",
        },
        soigne = {
            "Il y avait des témoins partout, quelqu'un a dû voir la plaque.",
        },
    },
    industriel = {
        blesse = {
            "Je sortais du site, il ne m'a pas vue en manœuvrant.",
        },
        soigne = {
            "Il a reculé sans regarder, puis il est reparti sans descendre.",
        },
    },
}

VL.chien_dangereux = {
    ['*'] = {
        blesse = {
            "Il m'a sauté dessus sans prévenir. Je n'ai pas pu me dégager.",
            "J'ai essayé de le repousser, il m'a mordue au bras. Personne ne le tenait.",
            "Le maître criait mais l'animal ne l'écoutait pas du tout.",
        },
        soigne = {
            "Ce chien n'était pas tenu. Son maître était là et n'a rien fait.",
            "Il m'a mordue puis il est reparti vers son maître comme si de rien n'était.",
        },
    },
    residentiel = {
        blesse = {
            "Je marchais tranquillement dans la rue quand il a chargé.",
        },
        soigne = {
            "Tout le quartier connaît ce chien. Ce n'est pas la première fois.",
        },
    },
    parc = {
        blesse = {
            "Il était lâché sans laisse au milieu des familles. Il m'a foncé dessus.",
        },
        soigne = {
            "Il y avait des enfants à quelques mètres. Ça aurait pu être bien pire.",
        },
    },
    industriel = {
        blesse = {
            "Je faisais ma livraison, il m'a attaquée en descendant du camion.",
        },
        soigne = {
            "L'animal traîne autour du site depuis des jours, tout le monde le sait.",
        },
    },
}

--  TUERIE DE MASSE — DÉPOSITIONS DES TÉMOINS CLÉS
--
--  Ce ne sont PAS des profils socio-professionnels (habitant, employé…)
--  mais des profils de CONNAISSANCE : ce que ce témoin précis a
--  réellement pu voir ou entendre, décidé une fois côté serveur
--  (server/callouts.lua, BuildWitnessStatement) puis cherché ici via le
--  même moteur (PickIntro) que la déposition du requérant.
--
--  RÈGLE : un témoin ne dit QUE ce que son profil autorise.
--    vu_suspect        — a vu le suspect (uniquement si présent à
--                         l'arrivée du témoin) : peut décrire, jamais
--                         de détails sur un éventuel véhicule qu'il n'a
--                         pas forcément remarqué.
--    vu_vehicule        — a vu le véhicule et sa direction, mais rien
--                         sur le visage du suspect (trop loin, de dos).
--    entendu_seulement  — seulement les coups de feu : aucune
--                         description, ni suspect ni véhicule.
--    cherche_proche      — préoccupé par un proche, pas un témoin de la
--                         scène à proprement parler.
--
--  '*' (valable partout) : le contenu ne dépend pas du type de
--  quartier, contrairement aux dépositions du requérant.
L.tuerie_masse = {
    ['*'] = {
        vu_suspect = {
            "Je l'ai vu, il était juste là. Je ne suis pas près d'oublier son visage.",
            "Il était encore là il y a un instant, je le voyais parfaitement.",
            "Je l'ai regardé droit dans les yeux avant de courir. Il n'avait pas l'air de viser qui que ce soit en particulier.",
        },
        vu_vehicule = {
            "Il est parti dans une voiture sombre, en direction de la route principale.",
            "J'ai vu la voiture démarrer en trombe, mais je n'ai pas retenu la plaque.",
            "Une berline garée là est repartie tout de suite après les coups de feu.",
        },
        entendu_seulement = {
            "J'étais dans le bâtiment voisin, j'ai seulement entendu les coups.",
            "Je n'ai rien vu, juste les tirs, plusieurs d'affilée. Ça venait de par là.",
            "Je n'étais pas sur place, on m'a juste dit qu'il y avait eu des coups de feu.",
        },
        cherche_proche = {
            "Je cherche mon frère, je ne le trouve plus. Il était juste à côté de moi.",
            "Ma collègue n'est pas avec moi, je ne sais pas où elle est passée.",
            "On s'est perdus de vue en courant. Je n'arrive pas à la joindre.",
        },
    },
}

return Config.Police.Dialogues
