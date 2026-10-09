--  MODULE POLICE NATIONALE — Appels 17 / Missions PNJ
--  Catalogue des 18 scénarios.
--
--  CHAMPS
--    minAgents       agents ENREGISTRÉS requis pour que le scénario tombe
--    hours           { from, to } fenêtre in-game (nil = 24h/24)
--    weight          pondération relative parmi les scénarios ÉLIGIBLES
--    suspects        { min, max } — toujours plafonné par l'effectif
--    behaviors       % par individu, tirés indépendamment (total 100)
--    fleeOn          'foot' | 'bike' | 'car'
--    weapons.mode    'none' | 'perSuspect' | 'perGroup'
--    weapons.min     (perGroup) nombre minimum d'armés dans le groupe
--    hideChance      % qu'un suspect PASSIF se planque
--    objective       nil = interpellation ; sinon résolution particulière
--    driver          complice au volant, compte comme un suspect
--    loot            libellés d'affichage — jamais des items réels

Config                  = Config                  or {}
Config.Police           = Config.Police           or {}
Config.Police.Scenarios = {}

local S = Config.Police.Scenarios

--  PALIER 1 — dès 1 agent enregistré (missions sans danger)

S['constatation_effraction'] = {
    id = 'constatation_effraction',
    bystanders = false,
    statementIntro = {
        "On a forcé ma porte pendant que j'étais sorti. Je n'ai touché à rien, je vous attendais.",
        "Je rentre du travail et tout est retourné. La serrure a sauté, ils sont passés par là.",
        "Ma voisine m'a prévenu, la porte était grande ouverte. Je n'ose pas trop regarder ce qui manque.",
        "Ils ont fracturé pendant la journée. Il y a des traces sur le montant, venez voir.",
    },
    label = 'Constatation de vol par effraction',
    weight = 10, minAgents = 1, hours = nil,
    dispatch = {
        "Constatation de vol par effraction %s. Le propriétaire attend sur place.",
        "Un particulier signale un cambriolage %s, les auteurs ont quitté les lieux.",
        "Demande de constatation après effraction %s. Le requérant est présent.",
    },
    suspects = { min = 0, max = 0 },
    behaviors = { passive = 100, flee = 0, aggressive = 0 },
    weapons = { mode = 'none' },
    objective = 'statement',
    -- Le propriétaire ne quitte pas son domicile après la déposition :
    -- il attend que les agents s'en aillent.
    callerStays = true,
    -- Le requérant se tient devant sa porte, dos à l'entrée, tourné vers
    -- la rue. Sa position ne doit être ajustée qu'à la marge.
    callerAtDoor = true,
    caller = 'residents',
    pedPool = 'residents',
    hideChance = 0,
    reward = 200,
    -- Emplacements dédiés : points placés à la main devant de vraies
    -- entrées de logement (cf. C.Locations.doorstep).
    locations = 'doorstep',
    allowFalseAlarm = false,
}

S['decouverte_corps'] = {
    id = 'decouverte_corps',
    statementIntro = {
        "Je passais là et je l'ai trouvé comme ça. Je n'ai touché à rien, j'ai appelé tout de suite.",
        "Je promenais mon chien quand je l'ai vu par terre. J'ai cru qu'il dormait, puis j'ai compris.",
        "Ça fait un moment qu'il est là, personne ne s'arrêtait. J'ai fini par composer le 17.",
        "J'ai voulu lui parler, il ne réagissait plus du tout. Je n'ai pas su quoi faire d'autre.",
        -- Neutre géographiquement : la précédente version ("je sortais de
        -- chez moi") n'avait aucun sens sur les points 'street' classés
        -- industriels (Cypress Flats, Banning, Popular Street), où il n'y
        -- a structurellement pas de logements.
        "Je marchais par ici et il était étendu là. Je ne l'avais jamais vu dans le coin.",
    },
    label = 'Découverte de corps sur la voie publique',
    weight = 6, minAgents = 1, hours = nil,
    dispatch = {
        "Découverte de corps sur la voie publique %s. Un témoin est resté sur place.",
        "Un passant signale une personne sans vie %s.",
        "Corps découvert %s, demande de constatation.",
    },
    suspects = { min = 0, max = 0 },
    behaviors = { passive = 100, flee = 0, aggressive = 0 },
    weapons = { mode = 'none' },
    objective = 'death',
    caller = 'witnesses',
    pedPool = 'deceased',
    callerToCorpse = 2.0,
    hideChance = 0,
    reward = 250,
    locations = 'street',
    allowFalseAlarm = false,
    -- Identification du corps + prévenir un proche avant de clore.
    familyContact = true,
    autopsy = true,
    -- Le timeout global (20 min) suffit rarement : identifier, analyser,
    -- attendre les secours, PUIS traverser la carte pour prévenir un
    -- proche prend largement plus de temps qu'une constatation classique.
    timeout = 2400,
}

S['personne_errante'] = {
    id = 'personne_errante',
    bystanders = false,
    statementIntro = {
        "Cette personne tourne en rond depuis un long moment. Elle ne sait plus où elle habite.",
        "Elle m'a demandé trois fois le même chemin en dix minutes. Je crois qu'elle est perdue.",
        "Ça fait une heure qu'elle marche dans la rue sans savoir où aller. Elle a l'air désorientée.",
        "Elle ne se souvient ni de son adresse ni de son nom. Je n'ai pas voulu la laisser seule.",
    },
    label = 'Personne errante',
    weight = 8, minAgents = 1, hours = nil,
    dispatch = {
        "Personne désorientée signalée %s. Elle erre depuis un moment selon le requérant.",
        "Un riverain signale une personne âgée perdue %s.",
        "Demande d'assistance %s pour une personne visiblement désorientée.",
    },
    suspects = { min = 0, max = 0 },
    behaviors = { passive = 100, flee = 0, aggressive = 0 },
    weapons = { mode = 'none' },
    objective = 'hospital',
    caller = 'witnesses',
    pedPool = 'elderly',
    hideChance = 0,
    reward = 250,
    -- Voie publique : dans un quartier pavillonnaire, la scène tombait
    -- régulièrement à l'intérieur de maisons inaccessibles.
    locations = 'street',
    allowFalseAlarm = false,
    -- Une fois identifiée et déposée à l'hôpital, un proche doit être
    -- prévenu avant de clore la mission.
    familyContact = true,
    -- Cf. decouverte_corps : trajet jusqu'à l'hôpital PUIS jusqu'au
    -- proche à prévenir, le timeout global (20 min) est trop court.
    timeout = 2400,
}

S['racolage'] = {
    id = 'racolage',
    bystanders = false,
    statementIntro = {
        "Ça se passe devant chez nous tous les soirs, on n'ose plus sortir.",
        "Les clients se garent en double file, il y a du passage toute la nuit.",
        "On a des enfants dans l'immeuble, ça ne peut plus durer.",
    },
    label = 'Racolage sur la voie publique',
    weight = 8, minAgents = 1, hours = { from = 21, to = 5 },
    dispatch = {
        "Racolage sur la voie publique signalé %s.",
        "Plaintes de riverains %s pour racolage.",
        "Un commerçant signale du racolage devant son établissement %s.",
    },
    suspects = { min = 2, max = 3 },
    behaviors = { passive = 99, flee = 1, aggressive = 0 },
    fleeOn = { 'foot' },
    weapons = { mode = 'none' },
    hideChance = 0,
    -- Le texte décrit un riverain excédé ("chez nous", "des enfants dans
    -- l'immeuble"), pas un passant générique.
    caller = 'residents',
    pedPool = 'hookers',
    -- Elles se tiennent ensemble sur le trottoir ; la riveraine qui a
    -- appelé observe de plus loin.
    suspectCluster = 2.0,
    callerOffset   = 5.0,
    reward = 350,
    -- Fouille : de quoi trouver quelque chose sans que ce soit systématique.
    loot = { 'Argent liquide', 'Boîte de préservatifs', 'Sachet de stupéfiants' },
    lootMin = 1,
    lootMax = 2,
    locations = 'street',
    allowFalseAlarm = true,
    falseAlarmIntro = {
        "Finalement c'est juste une amie qui m'attendait, désolée du dérangement.",
        "Elles sont reparties d'elles-mêmes, il n'y a plus personne devant chez nous.",
        "Je crois avoir mal interprété la situation, excusez-moi de vous avoir dérangés.",
    },
}

--  PALIER 2 — à partir de 2 agents enregistrés

S['vol_arrache'] = {
    id = 'vol_arrache',
    statementIntro = {
        "On vient de m'arracher mon sac, ça s'est passé en quelques secondes.",
        "Il m'a bousculée et il est parti avec mon téléphone. Je n'ai rien pu faire.",
        "Ils sont arrivés par-derrière, j'ai à peine eu le temps de crier.",
    },
    label = "Vol à l'arraché",
    weight = 12, minAgents = 2, hours = nil,
    dispatch = {
        "Vol à l'arraché signalé %s. La requérante attend sur place.",
        "Appel d'une passante %s, son sac vient de lui être arraché.",
        "Vol avec violence %s, l'auteur serait encore dans le secteur.",
    },
    suspects = { min = 1, max = 2 },
    -- Ils sont AU CONTACT de leur victime jusqu'à l'arrivée
    -- des agents : les disperser à trente mètres vidait la scène de son
    -- sens et les envoyait dans le décor.
    suspectCluster = 2.0,
    behaviors = { passive = 0, flee = 99, aggressive = 1 },
    fleeOn = { 'foot', 'bike' },
    weapons = { mode = 'perSuspect', max = 1, chance = 50, pool = { 'WEAPON_KNIFE' } },
    loot = { 'Sac à main volé', 'Téléphone dérobé' },
    hideChance = 0,
    caller = 'witnesses',
    pedPool = 'street_crime',
    -- La victime est encore aux prises avec ses agresseurs à l'arrivée.
    mauledVictim  = true,
    victimAssault = true,
    -- Elle doit être secourue : ce n'est pas qu'une mise en scène de
    -- l'agression, l'assistance fait partie de l'intervention.
    requireAid = true,
    -- Les soins ne suffisent pas à clore le dossier : il faut aussi son
    -- identité et sa déposition (cf. CheckResolution, server/callouts.lua).
    requireVictimReport = true,
    reward = 450,
    locations = 'street',
    allowFalseAlarm = true,
    falseAlarmIntro = {
        "Finalement j'ai juste fait tomber mon sac, personne ne me l'a arraché.",
        "Je viens de le retrouver dans ma poche, fausse alerte, désolée du dérangement.",
        "Ce n'était pas un vol, on s'est juste bousculés en se croisant sur le trottoir.",
    },
}

S['bagarre_rue'] = {
    id = 'bagarre_rue',
    statementIntro = {
        "Ils se battent depuis plusieurs minutes, personne n'arrive à les séparer.",
        "Ça a commencé pour une histoire de place de parking, et ça a dégénéré.",
        "J'ai essayé de m'interposer mais ils sont trop nombreux.",
    },
    label = 'Bagarre de rue',
    weight = 10, minAgents = 2, hours = nil,
    dispatch = {
        "Rixe sur la voie publique %s. Plusieurs individus impliqués.",
        "Bagarre signalée %s, un témoin demande une intervention rapide.",
        "Altercation violente %s entre plusieurs personnes.",
    },
    suspects = { min = 2, max = 4 },
    -- Une bagarre à une personne n'est pas une bagarre : ce plancher
    -- l'emporte sur le plafonnement par l'effectif.
    minSuspects = 2,
    -- Aucune fuite : une bagarre se règle sur place. Les protagonistes
    -- sont trop occupés entre eux pour détaler, et leur sort se décide
    -- à l'arrivée des agents (cf. C.Brawl dans config_callouts.lua).
    behaviors = { passive = 100, flee = 0, aggressive = 0 },
    weapons = { mode = 'perGroup', min = 1, max = 1, pool = { 'WEAPON_KNIFE', 'WEAPON_BAT' } },
    hideChance = 0,
    caller = 'witnesses',
    pedPool = 'brawlers',
    -- Ils s'empoignent au même endroit, pas dispersés dans le quartier.
    suspectCluster = 2.5,
    -- Le témoin observe à distance : il a appelé, il ne s'interpose pas.
    callerOffset   = 8.0,
    brawl = true,
    sound = 'fight',
    reward = 500,
    locations = 'street',
    allowFalseAlarm = true,
    falseAlarmIntro = {
        "Ils se sont réconciliés et sont repartis chacun de leur côté.",
        "Ce n'était qu'une discussion animée, pas vraiment une bagarre en fait.",
        "Ils ont fini par se calmer tout seuls avant votre arrivée.",
    },
}

S['vol_vehicule'] = {
    id = 'vol_vehicule',
    bystanders = false,
    statementIntro = {
        "Ils étaient en train de forcer la portière, j'ai crié et ils ont détalé.",
        "J'ai entendu l'alarme, je suis descendu et je les ai vus autour de ma voiture.",
        "Il avait la tête sous le volant, je crois qu'il essayait de la démarrer.",
    },
    label = 'Vol de véhicule en cours',
    weight = 10, minAgents = 2, hours = nil,
    dispatch = {
        "Vol de véhicule en cours %s. Le propriétaire assiste à la scène.",
        "Tentative de vol de véhicule signalée %s.",
        "Un riverain signale des individus en train de forcer un véhicule %s.",
    },
    suspects = { min = 1, max = 2 },
    -- Ils sont tous occupés sur le véhicule et détalent ensemble.
    behaviors = { passive = 0, flee = 100, aggressive = 0 },
    -- À pied : ils abandonnent le véhicule qu'ils tentaient de voler.
    fleeOn = { 'foot' },
    weapons = { mode = 'perSuspect', max = 1, chance = 40, pool = { 'WEAPON_KNIFE' } },
    loot = { 'Tournevis', 'Décodeur de clé' },
    lootAlways = true,
    hideChance = 0,
    caller = 'witnesses',
    pedPool = 'street_crime',
    targetVehicle = true,
    suspectsAtVehicle = 2.0,
    -- Penchés sur le véhicule jusqu'à l'arrivée des agents.
    suspectScenario = 'WORLD_HUMAN_VEHICLE_MECHANIC',
    reward = 450,
    locations = 'parking',
    allowFalseAlarm = true,
    falseAlarmIntro = {
        "En fait c'est le propriétaire, il avait juste perdu ses clés.",
        "C'était un dépanneur venu réparer la voiture, pas un voleur.",
        "Fausse alerte, c'est mon mari qui essayait d'ouvrir sa propre portière.",
    },
}

S['trafic_stup'] = {
    id = 'trafic_stup',
    bystanders = false,
    statementIntro = {
        "Il y a des allées et venues toute la journée, ça n'arrête pas.",
        "Les gens s'arrêtent deux minutes, échangent quelque chose et repartent.",
        "On voit toujours les mêmes têtes ici, ça dure depuis des semaines.",
    },
    label = 'Trafic de stupéfiants',
    weight = 8, minAgents = 2, hours = { from = 14, to = 4 },
    dispatch = {
        "Trafic de stupéfiants signalé %s. Deux individus sur place.",
        "Un riverain signale un point de deal actif %s.",
        "Va-et-vient suspect %s, probable transaction de stupéfiants.",
    },
    suspects = { min = 2, max = 2 },
    -- Le point de deal est le centre de la scène : les
    -- individus s'y tiennent, ils ne sont pas éparpillés dans le quartier.
    suspectCluster = 2.5,
    behaviors = { passive = 10, flee = 90, aggressive = 0 },
    fleeOn = { 'foot' },
    -- Sprint initial standard, mais ils tiennent plus longtemps avant de
    -- vraiment s'essouffler, et ralentissent moins fort une fois fatigués.
    fleeSlowAt = 40,
    fleeRateTired = 0.70,
    weapons = { mode = 'none' },
    -- Pas systématique : certains n'ont rien sur eux, d'autres juste
    -- l'un ou l'autre, parfois les deux.
    loot = { 'Sachet de stupéfiants', 'Liasse de billets' },
    lootMin = 1,
    lootMax = 2,
    -- En fuite, celui qui a du stup sur lui peut s'en débarrasser en
    -- le jetant au sol — à retrouver là où il est tombé.
    stashDrop = true,
    hideChance = 0,
    caller = 'witnesses',
    pedPool = 'dealers',
    reward = 450,
    locations = 'dealpoint',
    allowFalseAlarm = true,
    falseAlarmIntro = {
        "En regardant mieux, ce ne sont que des voisins qui discutent.",
        "Ils échangeaient juste des cigarettes, rien d'illégal en fait.",
        "Je crois avoir mal jugé la situation, désolé du dérangement.",
    },
}

S['personne_armee'] = {
    id = 'personne_armee',
    statementIntro = {
        "Il agitait quelque chose dans la main en menaçant les gens, j'ai eu peur.",
        "Il a sorti son arme devant tout le monde, les passants se sont sauvés.",
        "Il parle tout seul et il est armé. Personne n'ose l'approcher.",
    },
    label = 'Personne armée',
    weight = 6, minAgents = 2, hours = nil,
    dispatch = {
        "Individu armé signalé %s. Prudence à l'approche.",
        "Un témoin signale une personne munie d'une arme blanche %s.",
        "Individu menaçant et armé %s, intervention demandée.",
    },
    suspects = { min = 1, max = 1 },
    -- L'individu armé est là où on l'a signalé, pas à
    -- trente mètres dans une direction tirée au hasard.
    suspectCluster = 2.0,
    behaviors = { passive = 50, flee = 0, aggressive = 50 },
    fleeOn = { 'foot' },
    weapons = { mode = 'perSuspect', max = 1, chance = 100,
                pool = { 'WEAPON_KNIFE', 'WEAPON_PISTOL' } },
    hideChance = 30,
    -- Contrôlable via l'option dédiée (« Contrôler le permis de port
    -- d'arme ») : 20 % de chances qu'il soit valide, décidé une fois.
    weaponPermit = true,
    caller = 'witnesses',
    pedPool = 'unstable',
    reward = 550,
    locations = 'street',
    allowFalseAlarm = true,
    falseAlarmIntro = {
        "En fait c'était une perceuse, pas une arme, désolé de vous avoir fait peur.",
        "C'était un jouet, je m'en rends compte maintenant.",
        "Il a rangé l'objet et s'est calmé, ce n'était peut-être rien du tout.",
    },
    -- Un attroupement de badauds près d'un individu armé et potentiellement
    -- agressif n'est pas crédible (des passants s'éloigneraient plutôt),
    -- cohérent avec les autres scénarios dangereux (cambriolage, tuerie de
    -- masse).
    bystanders = false,
}

S['delit_fuite'] = {
    id = 'delit_fuite',
    -- Scène fixe : une voiture (le suspect) renverse un piéton (la
    -- victime). Le conducteur descend mais ne porte pas secours — il
    -- reste près du véhicule accidenté et ne prend la fuite À PIED qu'à
    -- l'arrivée des agents (cf. suspectsAtVehicle/fleeTrigger). Les textes
    -- ci-dessous doivent rester cohérents avec ça : jamais de "il n'a
    -- même pas ralenti" ou "il a filé aussitôt" (ça, c'est un délit de
    -- fuite classique où le conducteur ne s'arrête jamais).
    statementIntro = {
        "La voiture a percuté un piéton, le conducteur est descendu mais il n'a rien fait pour l'aider — il est resté planté à côté du véhicule.",
        "Il a heurté quelqu'un et il est sorti de la voiture, mais il n'a pas porté secours. Il attendait juste là, à côté de la carcasse.",
        "Le choc a été violent. Le conducteur est descendu, hébété, il n'a pas bougé de la voiture jusqu'à ce qu'il vous voie arriver.",
    },
    label = 'Accident voie Publique',
    weight = 8, minAgents = 2, hours = nil,
    dispatch = {
        "Accident avec piéton renversé %s. Le conducteur serait resté sur place, sans porter secours.",
        "Collision signalée %s, un piéton a été percuté par un véhicule.",
        "Accident de la circulation %s, un piéton blessé au sol, le conducteur n'a pas porté assistance.",
    },
    suspects = { min = 1, max = 2 },
    behaviors = { passive = 10, flee = 90, aggressive = 0 },
    fleeOn = { 'foot' },
    weapons = { mode = 'none' },
    hideChance = 0,
    -- Le conducteur est resté près de son véhicule et ne détale qu'à
    -- l'arrivée des agents, comme sur un vol de véhicule en cours.
    suspectsAtVehicle = 2.5,
    caller = 'witnesses',
    pedPool = 'street_crime',
    crash = true,
    -- Le blessé de la collision doit être secouru, pas seulement le
    -- fuyard interpellé.
    requireAid = true,
    -- La victime doit aussi être identifiée et entendue sur les faits
    -- avant de clore — les soins seuls ne suffisent pas à constituer
    -- le dossier.
    requireVictimReport = true,
    -- L'enlèvement du véhicule accidenté n'est plus une condition de
    -- clôture : l'agent peut valider la mission sans avoir appelé la
    -- fourrière (rester géré manuellement, hors mission).
    reward = 500,
    locations = 'street',
    allowFalseAlarm = true,
    falseAlarmIntro = {
        "Finalement la voiture ne l'a pas touché, il a juste trébuché tout seul en voulant l'éviter.",
        "Ils se sont un peu accrochés mais il n'y a pas de blessé, plus de peur que de mal.",
        "Fausse alerte, il n'y a pas eu de choc — juste une grosse frayeur pour les deux.",
    },
}

S['ipm'] = {
    id = 'ipm',
    bystanders = false,
    statementIntro = {
        "Il ne tient plus debout, il gêne tout le monde depuis un moment.",
        "Il est tombé deux fois devant l'entrée. On n'arrive pas à le raisonner.",
        "Il a trop bu, il insulte les clients qui sortent.",
    },
    label = 'Ivresse publique manifeste',
    weight = 8, minAgents = 2, hours = { from = 22, to = 6 },
    dispatch = {
        "Ivresse publique manifeste signalée %s.",
        "Individu en état d'ébriété avancé %s, gêne la voie publique.",
        "Un établissement signale une personne alcoolisée à l'extérieur %s.",
    },
    suspects = { min = 1, max = 1 },
    behaviors = { passive = 100, flee = 0, aggressive = 0 },
    weapons = { mode = 'none' },
    -- Pas systématique : parfois juste la bouteille, parfois aussi (ou
    -- seulement) des stupéfiants.
    loot = { 'Bouteille entamée', 'Sachet de stupéfiants' },
    lootMax = 2,
    hideChance = 0,
    suspectsAtCaller = 3.0,
    -- Le texte ("il insulte les clients qui sortent") est le point de vue
    -- d'un vigile/employé observant depuis l'établissement, pas celui
    -- d'un client parmi d'autres.
    caller = 'guards',
    -- Le vigile/employé décrit comme observant depuis l'établissement ne
    -- quitte pas son poste une fois la mission finie (cf. vol_etalage).
    callerStays = true,
    pedPool = 'unstable',
    drunk = true,
    -- 20 % de chance qu'il se montre agressif quand un agent s'approche
    -- pour l'interpeller (cf. C.AggroApproachDist), plutôt que de
    -- rester docile à chaque fois.
    aggroOnApproachChance = 20,
    reward = 300,
    locations = 'nightlife',
    allowFalseAlarm = true,
    falseAlarmIntro = {
        "Il vient de se relever tout seul, ce n'était peut-être qu'un malaise.",
        "Il a dessoûlé d'un coup, en fait il tenait très bien debout.",
        "Je crois que j'ai exagéré, il n'était pas si ivre que ça.",
    },
    -- Taux d'alcoolémie consigné au rapport, pour appuyer l'interpellation.
    breathalyzer = true,
    -- Dépistage de stupéfiants : positif/négatif, avec les substances
    -- détectées consignées au rapport si positif.
    drugTest = true,
}

S['vol_etalage'] = {
    id = 'vol_etalage',
    bystanders = false,
    statementIntro = {
        "Je l'ai intercepté à la sortie, il avait dissimulé de la marchandise. Je le retiens.",
        "Les caméras l'ont filmé en train de remplir son sac. Il n'a pas nié.",
        "Il a passé les caisses sans rien payer, je l'ai rattrapé sur le parking.",
    },
    label = "Vol à l'étalage",
    weight = 10, minAgents = 2, hours = { from = 9, to = 20 },
    dispatch = {
        "Vol à l'étalage %s. Le vigile retient l'individu sur place.",
        "Un commerçant signale un vol dans son établissement %s.",
        "Interpellation d'un voleur par la sécurité %s, demande de prise en charge.",
    },
    suspects = { min = 1, max = 2 },
    behaviors = { passive = 100, flee = 0, aggressive = 0 },
    fleeOn = { 'foot' },
    weapons = { mode = 'none' },
    -- Le vigile ne retient pas quelqu'un les mains vides : la fouille
    -- doit TOUJOURS donner quelque chose.
    loot = { 'Marchandise volée', 'Bouteille dissimulée', 'Vêtement non payé',
             'Parfum dissimulé', 'Boîtier de jeu vidéo', 'Cartouche de cigarettes' },
    lootAlways = true,
    lootMax = 2,
    hideChance = 0,
    -- Le requérant est le vigile du magasin : costume sombre, oreillette.
    caller = 'guards',
    pedPool = 'street_crime',
    -- Le vigile retient déjà l'individu : les suspects apparaissent
    -- juste à côté de lui, pas dispersés dans la zone de recherche.
    suspectsAtCaller = true,
    reward = 350,
    locations = 'shop',
    allowFalseAlarm = true,
    falseAlarmIntro = {
        "Finalement il avait payé, j'ai mal regardé le ticket de caisse.",
        "Je me suis trompé de personne, ce n'est pas lui qui volait.",
        "Il a réglé les articles juste après, fausse alerte de ma part.",
    },
    -- Le vigile ne quitte pas son poste une fois la mission finie : ça
    -- n'aurait aucun sens qu'il parte du magasin qu'il surveille.
    callerStays = true,
    -- « Proposer de payer les articles » (une fois identité + fouille
    -- faites) : chance qu'il règle sur place plutôt que d'être interpellé.
    -- S'il refuse, l'agent garde le choix de l'interpeller ou de quand
    -- même le laisser repartir (cf. callout_move_along, inchangé).
    payOff = true,
    payOffChance = 55,
    payOffLines = {
        accept = {
            "D'accord, je vais payer, j'ai de quoi régler.",
            "Très bien, prenez, ça couvre les articles.",
            "Bon, d'accord. Je ne veux pas d'histoires.",
        },
        refuse = {
            "Je n'ai pas les moyens de payer ça.",
            "Non, débrouillez-vous, je ne paierai rien.",
            "Hors de question, faites ce que vous voulez.",
        },
    },
}

S['chien_dangereux'] = {
    id = 'chien_dangereux',
    bystanders = false,
    statementIntro = {
        "Le chien n'est pas tenu, il a déjà foncé sur quelqu'un.",
        "Il a mordu quelqu'un tout à l'heure, le maître ne le contrôle plus du tout.",
        "L'animal est complètement déchaîné, plus personne n'ose passer par là.",
    },
    label = 'Chien dangereux en divagation',
    weight = 5, minAgents = 2, hours = { from = 8, to = 20 },
    dispatch = {
        "Chien dangereux en divagation %s. Le maître serait sur place.",
        "Un riverain signale un chien agressif non tenu %s.",
        "Animal dangereux signalé %s, des passants menacés.",
    },
    suspects = { min = 1, max = 1 },
    behaviors = { passive = 100, flee = 0, aggressive = 0 },
    weapons = { mode = 'none' },
    hideChance = 0,
    caller = 'witnesses',
    pedPool = 'residents',
    animal = true,
    animalRange = 5.0,
    -- Le maître se tient PRÈS de son chien. Sans ce regroupement, il
    -- tombait dans le placement par défaut — dispersé de 15 à 35 m dans
    -- une direction tirée au hasard — et se retrouvait au bas d'un talus
    -- ou de l'autre côté d'une clôture, à Vinewood Hills notamment.
    suspectCluster = 3.0,
    -- Une personne est aux prises avec le chien à l'arrivée des agents.
    -- Elle est DEBOUT tant qu'il s'acharne — sinon l'attaque ne se voit
    -- pas — et ne s'effondre qu'au moment où il se détourne vers eux.
    mauledVictim  = true,
    victimAssault = true,
    -- Le riverain qui a appelé observe de loin, mais pas trop : sur une
    -- rue étroite, quatorze mètres dans une direction tirée au hasard
    -- l'envoyaient dans un jardin ou en contrebas.
    callerOffset = 9.0,
    -- Pas de chien errant dans les villas de colline : terrain en pente,
    -- allées privées, aucun trottoir — et cela n'aurait aucun sens.
    excludeZones = { 'affluent' },
    -- L'animal ne se menotte pas : il est neutralisé, puis sa mort est
    -- constatée. Mais son maître, lui, répond de sa divagation : il doit
    -- être interpellé pour que l'intervention soit résolue.
    objective = 'animal',
    requireSuspects = true,
    -- La victime mordue doit être soignée ET entendue avant la clôture,
    -- pas seulement le maître interpellé (cf. CheckResolution).
    requireAid = true,
    requireVictimReport = true,
    suspectLabel = 'Maître de l\'animal',
    -- Le maître peut être entendu sur les faits : sa déposition
    -- s'ajoute à celle du requérant sur la fiche d'intervention.
    ownerStatement = {
        "Il n'a jamais fait ça avant, je vous jure. Il a filé dès que j'ai ouvert la porte.",
        "La laisse a cédé, je n'ai rien pu faire. Je l'ai appelé, il ne m'écoutait plus.",
        "Je le sortais comme d'habitude, il s'est jeté sur cette personne d'un coup.",
        "Il est nerveux depuis quelques semaines. J'aurais dû le tenir plus court.",
        "Je le tenais, mais il a tiré d'un coup et le collier a lâché.",
    },
    sound = 'bark',
    reward = 450,
    locations = 'residential',
    allowFalseAlarm = true,
    falseAlarmIntro = {
        "Le chien s'est calmé, en fait il jouait avec un enfant du quartier.",
        "Ce n'était pas de l'agressivité, il avait juste eu peur d'un bruit.",
        "Le maître l'a rattrapé, il est redevenu très calme depuis.",
    },
}

--  PALIER 3 — à partir de 3 agents enregistrés

S['cambriolage'] = {
    id = 'cambriolage',
    bystanders = false,
    statementIntro = {
        "J'ai entendu du bruit chez le voisin, ils sont entrés par l'arrière.",
        "La vitre a été brisée, j'ai vu des ombres passer devant la fenêtre.",
        "Les propriétaires sont en déplacement, il ne devrait y avoir personne à l'intérieur.",
    },
    label = 'Cambriolage résidentiel',
    weight = 7, minAgents = 3, hours = { from = 9, to = 17 },
    dispatch = {
        "Cambriolage en cours %s. Plusieurs individus, au moins un serait armé.",
        "Un voisin signale une effraction en cours %s.",
        "Intrusion signalée dans une habitation %s, les auteurs sont à l'intérieur.",
    },
    -- Chef + 2 braqueurs à l'intérieur, plus le chauffeur ajouté plus
    -- bas : 4 au total, la capacité d'une seule voiture d'évasion.
    suspects = { min = 3, max = 3 },
    -- Ils opèrent sur le logement, groupés.
    suspectCluster = 3.0,
    behaviors = { passive = 0, flee = 75, aggressive = 25 },
    fleeOn = { 'foot' },
    -- Tous armés, couteau ou pistolet.
    weapons = { mode = 'perSuspect', max = 1, chance = 100,
                pool = { 'WEAPON_KNIFE', 'WEAPON_PISTOL' } },
    -- Avant le déclenchement de la fuite, ils fouillent la maison au
    -- lieu de rester figés — mais pas tous de la même façon : cf. la
    -- liste d'ambiance dédiée (C.Ambience.byScenario.cambriolage.suspect).
    loot = { 'Bijoux dérobés', 'Liasse de billets', 'Montre de valeur' },
    -- Pas de planque : la fuite ou l'agression se déclenche directement
    -- une fois la police repérée.
    hideChance = 0,
    caller = 'residents',
    pedPool = 'gang',
    driver = true,
    reward = 900,
    locations = 'residential',
    allowFalseAlarm = true,
    falseAlarmIntro = {
        "C'était le propriétaire qui rentrait plus tôt que prévu, fausse alerte.",
        "En fait c'est un artisan qui intervenait pour une réparation.",
        "Les ombres que j'ai vues, c'était juste la famille qui déménageait des cartons.",
    },
}

S['braquage_superette'] = {
    id = 'braquage_superette',
    statementIntro = {
        "Ils sont entrés armés et ont vidé la caisse, tout le monde s'est jeté au sol.",
        "L'un d'eux tenait le vendeur en joue pendant que les autres raflaient tout.",
        "Ça a duré moins d'une minute, ils étaient organisés.",
    },
    label = 'Braquage de supérette',
    weight = 5, minAgents = 3, hours = { from = 18, to = 2 },
    dispatch = {
        "Braquage en cours %s. Plusieurs individus armés. Prudence maximale.",
        "Alarme braquage déclenchée %s, auteurs armés à l'intérieur.",
        "Vol à main armée %s, un véhicule attendrait à proximité.",
    },
    suspects = { min = 2, max = 4 },
    -- Un braquage à un seul individu n'est pas un braquage : il faut au
    -- minimum un chef et un conducteur, sinon la distribution des rôles
    -- n'a personne à qui s'appliquer et la mise en scène ne se voit pas.
    minSuspects = 3,
    -- Ils sont dans le commerce ou juste devant.
    suspectCluster = 2.5,
    behaviors = { passive = 5, flee = 80, aggressive = 15 },
    fleeOn = { 'foot', 'car' },
    -- Tous armés, couteau ou pistolet.
    weapons = { mode = 'perSuspect', max = 1, chance = 100,
                pool = { 'WEAPON_KNIFE', 'WEAPON_PISTOL' } },
    loot = { 'Caisse du commerce', 'Liasse de billets', 'Cartouches de cigarettes' },
    hideChance = 0,
    -- Le requérant EST le caissier (cf. e.cashier = true dans
    -- BuildRoster) : autant qu'il en ait le skin.
    caller = 'cashiers',
    pedPool = 'gang',
    driver = true,
    getawayOffset = 16.0,
    -- Mise en scène dynamique : scénario, rôles et réaction de groupe
    -- décidés à la création (cf. C.Heist dans config_callouts.lua).
    heist = true,
    reward = 1200,
    locations = 'shop',
    allowFalseAlarm = true,
    falseAlarmIntro = {
        "Fausse alerte, c'était un client pressé qui bousculait tout le monde.",
        "En fait c'était un tournage pour une vidéo, personne n'était armé.",
        "Le vendeur a mal interprété une blague entre clients.",
    },
    -- C.Heist.Clients peuple déjà la scène de civils cohérents (clients
    -- au sol/planqués) : les badauds génériques feraient doubler la
    -- population civile sur un simple point de vente.
    bystanders = false,
}

S['rodeo_urbain'] = {
    id = 'rodeo_urbain',
    bystanders = false,
    statementIntro = {
        "Ça fait des tours en moto-cross depuis un moment, ça pétarade, impossible de dormir.",
        "Ils font n'importe quoi avec leurs motos, des roues arrière en pleine rue, c'est dangereux.",
        "Ça roule à toute vitesse en faisant des figures, ça va finir par blesser quelqu'un.",
    },
    label = 'Rodéo urbain',
    weight = 6, minAgents = 3, hours = nil,
    dispatch = {
        "Rodéo urbain signalé %s. Plusieurs motos impliquées.",
        "Rassemblement de motos-cross %s, nuisances et mise en danger des riverains.",
        "Rodéo motorisé %s, plaintes pour le bruit et la vitesse.",
    },
    suspects = { min = 2, max = 5 },
    -- Un rodéo à un seul motard n'en est pas un.
    minSuspects = 2,
    -- Ils tournent ensemble sur la zone, pas dispersés dans le quartier.
    suspectCluster = 6.0,
    behaviors = { passive = 0, flee = 100, aggressive = 0 },
    fleeOn = { 'bike' },
    -- Chaque suspect est déjà en selle de sa propre moto-cross dès le
    -- début de la scène (cf. SpawnVehicles/BuildRoster, server/callouts.lua)
    -- — contrairement au fleeOn='bike' générique où la moto n'est qu'une
    -- roue de secours abandonnée à proximité.
    suspectsOnBike = true,
    helmetMissingChance = 40,
    plateMissingChance  = 25,
    stolenBikeChance     = 25,
    -- Chance qu'un fuyard chute pendant la course-poursuite : passe alors
    -- par le même circuit blessé/soigné que les autres scénarios (cf.
    -- police:callouts:suspectWounded, D.WoundDescriptions.rodeo_urbain).
    fallChance = 15,
    weapons = { mode = 'none' },
    hideChance = 0,
    -- Pas de requérant en scène (comme tapage) : simple appel de
    -- riverains, aucun témoin PNJ ni section dédiée dans le PV.
    noCaller = true,
    pedPool = 'bikers',
    reward = 550,
    -- Espace ouvert nécessaire pour rouler (parking, terrain dégagé).
    locations = 'parking',
    allowFalseAlarm = true,
    falseAlarmIntro = {
        "Ils sont repartis d'eux-mêmes avant votre arrivée, plus personne sur place.",
        "Finalement ce n'étaient que des motos garées, personne ne roulait dessus.",
        "Fausse alerte, ce n'était qu'un attroupement sans aucune moto en mouvement.",
    },
}

--  PALIER 4 — à partir de 6 agents enregistrés (scénarios de foule)

S['tapage'] = {
    id = 'tapage',
    bystanders = false,
    statementIntro = {
        "Ça dure depuis des heures, c'est la sono d'une voiture. On ne peut plus dormir.",
        "On leur a demandé de baisser trois fois, ils remettent le son juste après.",
        "Les vitres tremblent chez moi tellement c'est fort.",
    },
    label = 'Tapage',
    weight = 8, minAgents = 6, hours = { from = 20, to = 4 },
    dispatch = {
        "Tapage nocturne signalé %s. Musique très forte, nombreuses plaintes.",
        "Plusieurs riverains signalent un rassemblement bruyant %s.",
        "Nuisances sonores %s, sono d'un véhicule mise en cause.",
    },
    suspects = { min = 5, max = 8 },
    behaviors = { passive = 99, flee = 0, aggressive = 1 },
    weapons = { mode = 'none' },
    objective = 'radio',
    -- Si un ou plusieurs fêtards sont interpellés, la mission n'aboutit
    -- qu'une fois présentés au poste — sans ça, couper la musique
    -- clôturait la mission immédiatement même avec quelqu'un encore
    -- menotté dans le véhicule.
    requireDeliverCuffed = true,
    hideChance = 0,
    noCaller = true,
    pedPool = 'clubbers',
    -- Ils font la fête AUTOUR de la voiture-sono, pas dispersés dans
    -- tout le quartier.
    suspectsAtVehicle = 2.0,
    -- Ambiance de fête : WORLD_HUMAN_PARTYING ne s'anime pas correctement
    -- hors boîte de nuit (le ped reste figé même si IsPedActiveInScenario
    -- le déclare actif) — on passe directement par le pool de danses dédié
    -- (cf. C.Ambience.byScenario.tapage.suspect, config_callouts.lua) via
    -- PlayAmbience, qui fonctionne lui en extérieur.
    -- Le riverain qui se plaint observe de loin, il ne fait pas la fête.
    callerOffset = 12.0,
    sound = 'boombox',
    -- Relevé de 400 à 600 : la mobilisation requise (minAgents=6, palier
    -- le plus haut avec rixe_soiree/tuerie_masse) n'était pas reflétée —
    -- moins rémunérateur que des scénarios à 2 agents (bagarre_rue 500,
    -- personne_armee 550).
    reward = 600,
    -- Parking : espace ouvert et accessible. En résidentiel, la voiture
    -- se retrouvait régulièrement encastrée dans un bâtiment.
    locations = 'parking',
    -- Le véhicule-sono EST la mission : sans lui (fausse alerte), il n'y
    -- a plus rien à constater ni personne à qui demander de baisser le
    -- son. Contrairement aux autres scénarios, une fausse alerte ici ne
    -- laisse aucune scène cohérente.
    allowFalseAlarm = false,
}

S['rixe_soiree'] = {
    id = 'rixe_soiree',
    statementIntro = {
        "Ça a dégénéré à la sortie, la sécurité est débordée.",
        "Une bagarre a éclaté sur le trottoir, ça continue de plus belle.",
        "Ils se sont pris à partie dans la file, et tout le monde s'y est mis.",
    },
    label = 'Rixe en soirée',
    weight = 6, minAgents = 6, hours = { from = 22, to = 6 },
    dispatch = {
        "Rixe devant un établissement de nuit %s. Nombreux individus impliqués.",
        "Bagarre générale signalée %s, la sécurité est débordée.",
        "Violences en réunion %s, intervention urgente demandée.",
    },
    suspects = { min = 5, max = 8 },
    -- Une rixe se tient en un point, comme une bagarre de rue.
    suspectCluster = 3.0,
    -- Une rixe suppose un attroupement : même à effectif réduit, on ne
    -- descend pas en dessous de trois protagonistes.
    minSuspects = 3,
    behaviors = { passive = 75, flee = 0, aggressive = 25 },
    weapons = { mode = 'none' },
    hideChance = 0,
    caller = 'witnesses',
    pedPool = 'clubbers',
    pedPoolExtra = 'brawlers',
    brawl = true,
    -- Le témoin observe la rixe à distance, comme pour bagarre_rue
    -- (callerOffset = 8.0) — sans quoi il pouvait être placé au milieu
    -- de l'attroupement, plus dense ici (5-8 individus).
    callerOffset = 10.0,
    sound = 'fight',
    reward = 800,
    locations = 'nightlife',
    allowFalseAlarm = true,
    falseAlarmIntro = {
        "Ils se sont réconciliés à l'intérieur, tout est rentré dans l'ordre.",
        "La sécurité a géré la situation avant que ça ne dégénère vraiment.",
        "Ce n'était qu'une discussion animée entre amis, rien de plus.",
    },
}

--  TUERIE DE MASSE — mise en scène pilotée par C.MassShooting
--
--  Un seul scénario ici : les 5 variantes (suspect présent / en fuite /
--  retranché / neutralisé / infos incomplètes) sont tirées à la
--  création de l'appel dans C.MassShooting.Scenarios (config_callouts.
--  lua), pas codées en dur. `massIncident` et `multiDeath` sont les
--  deux drapeaux qui font bifurquer BuildRoster et la constatation de
--  décès vers leurs branches dédiées (server/callouts.lua).
S['tuerie_masse'] = {
    id = 'tuerie_masse',
    massIncident = true,
    multiDeath   = true,
    statementIntro = {
        "C'est arrivé d'un coup, je ne comprends pas encore ce qui s'est passé.",
        "Il y a eu des coups de feu, j'ai vu des gens tomber et j'ai couru.",
        "Je n'ai presque rien vu, juste entendu les tirs et les cris.",
    },
    label = 'Tuerie de masse',
    -- Événement rare et grave : poids faible, effectif minimum élevé.
    weight = 2, minAgents = 8, hours = nil,
    -- Jusqu'à 6 corps à constater, plusieurs blessés à soigner, des
    -- témoins à entendre et un suspect à traiter : les 20 minutes du
    -- timeout global (C.MissionTimeout) suffisent rarement, ce qui
    -- clôturait la mission en échec même après un tir parfaitement
    -- légitime sur le suspect (aucune bavure, mais l'horloge globale
    -- avait tranché avant que le reste de la scène ne soit traité).
    timeout = 2700,
    -- Repli générique si C.MassShooting ne fournit pas de dispatch pour
    -- la variante tirée (garde-fou, ne devrait pas arriver en pratique).
    dispatch = {
        "Situation violente signalée %s, plusieurs victimes potentielles.",
    },
    -- Pris en charge intégralement par la branche massIncident de
    -- BuildRoster : aucun suspect générique ne doit être ajouté par le
    -- chemin normal.
    suspects = { min = 0, max = 0 },
    -- Comportement du suspect quand C.MassShooting le déclare `present` :
    -- très majoritairement en affrontement, arme automatique — c'est
    -- une tuerie de masse en cours, pas une simple menace armée.
    behaviors = { flee = 15, aggressive = 85 },
    fleeOn = { 'car' },
    driver = true,
    weapons = { mode = 'perSuspect', max = 1, chance = 100,
                pool = { 'WEAPON_SMG', 'WEAPON_ASSAULTRIFLE', 'WEAPON_MICROSMG' } },
    hideChance = 20,
    caller = 'witnesses',
    pedPool = 'unstable',
    objective = 'death',
    -- Un suspect encore présent (variantes A/C) doit être traité —
    -- interpellé, abattu ou parti en fuite constatée — avant que la
    -- seule constatation des corps ne puisse clore l'intervention.
    -- Sans effet quand aucun suspect n'a été créé (variantes B/D/E).
    requireSuspects = true,
    reward = 1800,
    locations = 'street',
    allowFalseAlarm = false,
    -- Le système dédié C.MassShooting.Witnesses peuple déjà la scène de
    -- témoins cohérents : les badauds génériques feraient apparaître des
    -- civils en plus, en pleine zone de danger actif.
    bystanders = false,
}
