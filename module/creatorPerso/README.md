# CreatorPerso - Créateur de Personnage Moderne

## 📋 Description

Module de création de personnage moderne avec interface web (HTML/CSS/JS) pour le framework WinFrame. Le personnage reste visible et centré au milieu de l'écran ; les contrôles sont regroupés dans des panneaux flottants et compacts tout autour de lui (sidebar de catégories à gauche, options à droite, rotation/validation en bas), façon boutique de vêtements.

## ✨ Caractéristiques

### Interface Utilisateur
- **Personnage centré** : aucun panneau opaque ne recouvre le centre de l'écran, tout l'habillage est flottant et périphérique
- **Sidebar de catégories** (gauche) : icônes compactes pour naviguer entre les onglets
- **Panneau d'options** (droite) : carte flottante à hauteur limitée avec défilement interne, sliders en grille 2 colonnes pour rester compact
- **Barre du bas** : rotation du personnage + Confirmer/Réinitialiser, réduite à l'essentiel
- **4 onglets de configuration** :
  - Apparence (cheveux, barbe, sourcils, yeux)
  - Héritage (parents, ressemblance, teint de peau)
  - Visage (traits fins : nez, pommettes, mâchoire, menton, etc.)
  - Maquillage (maquillage, rouge à lèvres, teint, rides, taches)
  - Identité (prénom, nom, date de naissance, lieu de naissance)

### Fonctionnalités
- ✅ Sélection du sexe (Homme/Femme)
- ✅ Gestion des cheveux (style + couleur)
- ✅ Barbe et pilosité corporelle
- ✅ Sourcils et cils
- ✅ Couleur des yeux
- ✅ Maquillage et rouge à lèvres
- ✅ Données d'identité personnelle
- ✅ Rotation du personnage (flèches, boutons)
- ✅ Aperçu en temps réel

> ℹ️ **Vêtements** : ce module ne gère plus l'habillage. Le personnage reçoit une tenue de base via un item d'inventaire au moment du spawn, après la création.

### Contrôles
| Contrôle | Action |
|----------|--------|
| **Flèches ← →** (barre du bas) | Rotation rapide |
| **Onglets** (sidebar gauche) | Basculer entre sections |

## 📁 Structure des Fichiers

```
module/creatorPerso/
├── client/
│   ├── main.lua               # Logique client (Lua)
│   └── camera.lua             # Caméras / scaleform (board d'identité, zoom)
├── server/
│   └── main.lua                # Logique serveur (Lua) + validation
└── html/
    ├── ui.html                 # Interface HTML
    ├── css/
    │   └── ui.css               # Styles CSS (panneaux flottants)
    └── js/
        └── ui.js                 # Logique JavaScript
```

## 🚀 Utilisation

### Ouvrir le Créateur

```lua
-- Déclencher l'événement client
TriggerEvent('CreatePerso')

-- Ou depuis le serveur
TriggerClientEvent('CreatePerso', playerId)
```

### Fermer le Créateur

```lua
TriggerEvent('closeCreatorPerso')
```

### Données Sauvegardées

#### Skin Data
- Tous les paramètres d'apparence (cheveux, barbe, maquillage, etc.)
- Stocké en base de données (table `players`, colonne `skin`)
- Validé côté serveur contre une whitelist stricte de propriétés/plages (voir `server/main.lua`)

#### Identity Data
```lua
{
    NDF = "Nom",                    -- Nom de famille
    Prenom = "Prénom",              -- Prénom
    DDN = "01/01/1990",             -- Date de naissance (DD/MM/YYYY)
    Sexe = "M",                     -- Sexe ("M" ou "F")
    Taille = 180,                   -- Taille en cm
    LDN = "Los Santos"              -- Lieu de naissance
}
```

## 🔧 Événements Serveur

### `SetBucket`
Isole le joueur dans un routing bucket dédié pendant la création. Le client envoie uniquement `true` (entrée) / `false` (sortie) ; le serveur calcule lui-même un bucket unique dérivé du server id (`10000 + source`), pour éviter toute collision entre joueurs et empêcher un client de choisir arbitrairement le bucket.

### `saveskin`
Sauvegarde les données de skin en base de données, après validation stricte (clés whitelistées, types numériques, plages de valeurs).

### `SetIdentity`
Sauvegarde les données d'identité du personnage, après validation (longueurs, caractères interdits, format de date, sexe, taille).

## 🎨 Personnalisation du Design

### Couleurs Principales
- Accent bleu: `#3498db`
- Fond des panneaux flottants: `rgba(6, 6, 14, 0.9-0.94)`
- Texte blanc: `#ffffff`

### Fichiers CSS
- `html/css/ui.css` - Tous les styles

## 📝 Intégration avec le Framework

Le module s'intègre complètement avec le framework WinFrame :

1. **Namespace LSLegacy** - Utilise `LSLegacy.CreatorPerso`
2. **Système d'événements** - Utilise `LSLegacy.RegisterClientEvent` / `LSLegacy.RegisterServerEvent`
3. **Sécurité** - Tokens, rate limiting (`LSLegacy.RateLimit`) et validation stricte des payloads côté serveur
4. **Base de données** - Sauvegarde via MySQL
5. **NUI** - Communication bidirectionnelle Lua ↔ JavaScript

## 🐛 Débogage

### Logs Console
Le module log les actions importantes :
```javascript
[Creator] Initialized
[Creator] <action> <data>
```

### Logs Serveur
```
Successfully saved skin for player: <playerId>
Identité définie pour le joueur: <playerId> - <firstName> <lastName>
```

## ⚙️ Configuration

### Points d'Intégration
- **Intérieur** : Coordonnées de mugshot (v_mugshot)
- **Animations** : Animation d'intro depuis le dictionnaire d'animation
- **Caméra** : Positions et rotations préconfigurées dans `client/camera.lua`
- **Bucket** : dérivé du server id du joueur (voir `server/main.lua`)

## 📦 Dépendances

- **Framework WinFrame** (core)
- **mysql-async** (base de données)
- **skinchanger** (local event pour les skins)

## 🔐 Sécurité

- ✅ Validation serveur stricte des données de skin (whitelist de propriétés + bornes numériques)
- ✅ Validation serveur stricte de l'identité (longueurs, caractères interdits, format de date, sexe, taille)
- ✅ Tokens d'authentification (LSLegacy)
- ✅ Rate limiting par événement (`LSLegacy.RateLimit`)
- ✅ Bucket isolé pendant la création, calculé côté serveur (pas de collision possible, le client ne choisit pas son bucket)
- ✅ Vérification identité (prénom + nom obligatoires)

## 🎯 Prochaines Améliorations Possibles

- [ ] Sauvegarde de plusieurs preset de personnages
- [ ] Galerie de cheveux/barbes avec images
- [ ] Randomization complète
- [ ] Import/export de personnages
- [ ] Preview des animations
- [ ] Animation de transition plus smooth

## 📧 Support

Pour toute question ou bug, contactez le développeur via Discord.

---

**Dernière mise à jour**: 14/08/2026
**Version**: 2.0.0
**Statut**: Stable ✅
