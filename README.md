# LS Legacy

Framework FiveM standalone (aucune dépendance à ESX ou QBCore) pour serveur de roleplay francophone, développé par **Winstone**. Il couvre le socle habituel d'un serveur RP (personnages, inventaire, banque, véhicules, besoins vitaux) ainsi qu'un ensemble de jobs et de systèmes annexes (police, gendarmerie, SAMU, pompiers, mécanique, commerces, transports...).

## Sommaire

- [Installation](#installation)
- [Configuration requise (webhooks & clés)](#configuration-requise-webhooks--clés)
- [Modules](#modules)
- [Dépendances externes](#dépendances-externes)
- [Crédits](#crédits)
- [Licence](#licence)

## Installation

### Prérequis

- Un serveur FiveM fonctionnel (artifact récent).
- MySQL / MariaDB.
- Les ressources suivantes, à installer **avant** `lslegacy` dans votre `server.cfg` :
  - [`ox_lib`](https://github.com/overextended/ox_lib)
  - [`oxmysql`](https://github.com/overextended/oxmysql)
  - `xsound`
  - `ox_target`
  - `screenshot-basic` (captures d'écran utilisées par l'anticheat et le menu admin)
  - `codem-dynamicweather` (piloté automatiquement par `module/weather`)

### Étapes

1. Placez le dossier `lslegacy` dans `resources/`.
2. Importez `winframe_database.sql` dans votre base de données.
3. Dans `server.cfg` :
   ```
   ensure ox_lib
   ensure oxmysql
   ensure xsound
   ensure ox_target
   ensure screenshot-basic
   ensure codem-dynamicweather
   ensure lslegacy
   ```
4. Renseignez votre chaîne de connexion MySQL (`set mysql_connection_string "..."`) avant de démarrer `oxmysql`.
5. (Optionnel) Configurez les webhooks et clés API — voir section suivante.
6. Démarrez le serveur.

## Configuration requise (webhooks & clés)

Pour des raisons de sécurité, aucun webhook Discord ni clé API n'est codé en dur dans le framework : ils sont lus depuis des convars à définir dans votre `server.cfg` (fichier qui, lui, n'est jamais versionné). Toutes sont optionnelles — un webhook non défini désactive simplement le log correspondant.

```
set lslegacy_webhook_anticheat "https://discord.com/api/webhooks/..."
set lslegacy_webhook_anticheat_ocr "https://discord.com/api/webhooks/..."
set lslegacy_webhook_admin_screenshots "https://discord.com/api/webhooks/..."
set lslegacy_webhook_admin_logs "https://discord.com/api/webhooks/..."
set lslegacy_webhook_mdt "https://discord.com/api/webhooks/..."
set lslegacy_webhook_boutique "https://discord.com/api/webhooks/..."
set lslegacy_imgbb_key "votre_clé_imgbb"
set lslegacy_anticheat_password "un_mot_de_passe"
```

`lslegacy_imgbb_key` s'obtient gratuitement sur [imgbb.com](https://imgbb.com) et sert à héberger les captures d'écran envoyées par le menu admin.

## Modules

Le framework est organisé en un socle central (`client/`, `server/`, `shared/`, `inventory/`) et des modules indépendants sous `module/`, chacun activé ou non dans `fxmanifest.lua` :

| Module | Description |
|---|---|
| `adminmenu` | Menu d'administration (téléport, gestion joueurs, sanctions, tickets support) |
| `atelier` | Système de mécanique multi-entreprises (diagnostic, pièces, interventions, facturation) — remplace `mecanicien` |
| `bank` | Banque (comptes, livrets, cartes, distributeurs) |
| `clothshop` | Boutique de vêtements avec aperçu 3D |
| `concessionnaire` | Concession automobile |
| `creatorPerso` | Création de personnage (identité, apparence, hérédité) |
| `emotes` | Menu d'émotes (gestes, danses, objets, animaux) |
| `farm` | Activités de récolte libres (bûcheron, mineur, pêcheur, agriculteur, chasseur) |
| `fourriere` | Fourrière de véhicules |
| `garage` | Garages et stockage de véhicules |
| `gendarmerie` | Job Gendarmerie Nationale |
| `identity` | Carte d'identité |
| `interim` | Job libre de ravitaillement des stations-service |
| `keyhanger` | Porte-clés muraux interactifs |
| `ltd` | Magasins LTD |
| `mdt` | Terminal MDT générique, mutualisé entre police, gendarmerie, SAMU et pompiers |
| `metro` | Métro et rames ambiantes |
| `multichar` | Sélection de personnages et appartements |
| `needs` | Faim et soif |
| `pedOffline` | PNJ représentant un joueur déconnecté |
| `persistent_vehicles` | Persistance des véhicules (état, dégâts, stabilité) |
| `police` | Job Police Nationale (actions, radio, enquêtes, prison, callouts) |
| `pompe` | Pompes à essence publiques |
| `pompiers` | Job Sapeurs-Pompiers |
| `samu` | Job SAMU (soins, volet médical du MDT) |
| `sit` | S'asseoir sur des props compatibles |
| `weather` | Météo dynamique par zone |
| `wildlife` | Gestion du spawn de la faune ambiante |

`module/mecanicien` reste présent sur disque mais n'est plus chargé (remplacé par `atelier`).

## Dépendances externes

Non fournies dans ce dépôt, à installer séparément (voir [Installation](#installation)) : `ox_lib`, `oxmysql`, `xsound`, `ox_target`, `screenshot-basic`, `codem-dynamicweather`.

## Crédits

LS Legacy intègre du code adapté et des assets créés par d'autres membres de la communauté FiveM :

- **RageUI** — bibliothèque de menu, par Dylan Malandain (Manason)
- **[rpemotes-reborn](https://github.com/alberttheprince/rpemotes-reborn)** — base du module `emotes` (animations, traduit en français)
- **[CutScene](https://github.com/Doublox/CutScene)** par Doublox — base de la cinématique d'introduction (`module/creatorPerso`)
- **[disablecombatroll](https://github.com/JellyJamm/disablecombatroll)** par JellyJamm
- **[tgiann-anti-strafe](https://github.com/TGIANN/tgiann-anti-strafe)** par TGIANN
- **[mnr_sitanywhere](https://github.com/Monarch-Devs/mnr_sitanywhere)** (MIT) par Monarch-Devs — base du module `sit`
- **XNL-FiveM-Trains-U3** par VenomXNL — approche adaptée pour le module `metro`
- Animations et props personnalisés du dossier `stream/` — packs communautaires de nombreux créateurs (voir les noms de dossiers sous `stream/[Custom Emotes]/` et `stream/[Props]/`)
- [Adaptive Cards](https://adaptivecards.io) — format des écrans de connexion (`server/deferallsCards.lua`)

Un grand merci à tous ces créateurs dont le travail a permis de construire ce framework.

## Licence

Distribué sous licence **CC BY-NC 4.0** (attribution obligatoire, usage commercial interdit sans accord de l'auteur). Voir [LICENSE.md](LICENSE.md).

**Auteur : Winstone**
