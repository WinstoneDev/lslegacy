---
name: lslegacy-lot-full-migration
description: "Règle de workflow pour le refactor LSLegacy par lots : chaque lot qui change une API Core doit migrer TOUS les modules impactés, pas seulement quelques-uns en exemple."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0b363b15-5033-41c1-bd82-af0ad3ea4ddb
  modified: 2026-08-22T14:50:19.216Z
---

Dans le refactor LSLegacy par lots ([[lslegacy-refactor-progress]]), dès qu'un lot introduit ou renomme une API Core (ex. `LSLegacy.Security.RegisterRateLimit`, `LSLegacy.Players.*`, `LSLegacy.Callbacks.*`), TOUS les modules qui utilisaient l'ancien pattern doivent être migrés dans ce même lot — pas seulement "quelques modules représentatifs" laissés comme exemple à généraliser plus tard.

**Why:** sur LOT 8, LOT 9 et LOT 10, une migration partielle ("commence par quelques modules représentatifs" / "migre progressivement") a systématiquement laissé des modules sur l'ancien pattern, obligeant l'utilisateur à redemander explicitement un lot de rattrapage (LOT 8bis, puis LOT 10bis, puis une passe supplémentaire de renommage) et à repréciser lui-même "je veux plus en voir un seul dans X". L'utilisateur a fini par demander une règle permanente pour ne plus avoir à le redire à chaque fois.
Récidive en LOT 14 : j'ai justifié à tort de ne PAS migrer les nouveaux namespaces `Events`/`Utils`/`Factions` en invoquant "c'est purement additif, rien n'est cassé" et la consigne (spécifique à ce lot) de ne pas faire de "déplacement massif sans bénéfice concret". Cette consigne portait sur les DÉPLACEMENTS DE FICHIERS, pas sur la migration des appelants d'une API renommée — je l'ai mal généralisée. L'utilisateur a dû le signaler explicitement une deuxième fois avant que je corrige (voir [[lslegacy-refactor-progress]], détail LOT 14). "Additif donc pas obligé de migrer" n'est PAS une exception valable à cette règle.

**How to apply:** quand un futur lot ajoute/renomme une fonction Core destinée à remplacer un pattern existant utilisé dans les modules :
1. Identifier TOUS les fichiers `module/*` (et `server/*` si pertinent) utilisant l'ancien pattern, par grep exhaustif sur tout le repo (pas un échantillon).
2. Migrer tous ces fichiers dans le même lot, en un seul commit, avant de considérer le lot terminé.
3. Ne garder l'ancienne API que comme alias de compatibilité (elle continue de fonctionner), pas comme excuse pour repousser la migration des appelants existants.
4. Si l'énoncé du lot dit explicitement "commence par quelques modules" ou "migration progressive", le confirmer avec l'utilisateur avant de limiter le scope — sinon migrer exhaustivement par défaut.
