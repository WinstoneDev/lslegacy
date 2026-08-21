# Props personnalisés — Utility Keyhanger

Le module fonctionne **immédiatement** avec des props natifs GTA V (aucun stream
nécessaire). Ce dossier permet d'ajouter vos **propres modèles** de support mural
et/ou de clés.

> ⚠️ Les modèles 3D GTA (`.ydr`, `.ytd`, `.ymt`…) sont des fichiers **binaires**
> que l'on crée avec **Blender + Sollumz** ou **3DS Max + GIMS**, puis que l'on
> exporte/empaquette avec **CodeWalker**. Ils ne peuvent pas être générés en
> texte — c'est une étape d'infographie à réaliser dans ces outils.

## 1. Déposer le modèle

Placez vos fichiers ici, par exemple :

```
module/keyhanger/stream/
 ├─ lslegacy_keyhanger.ydr      (le support mural)
 ├─ lslegacy_keyhanger.ytd      (ses textures)
 ├─ lslegacy_key_01.ydr         (un trousseau custom)
 └─ lslegacy_key_01.ytd
```

FiveM stream **automatiquement** tout dossier nommé `stream/` (et ses
sous-dossiers) de la ressource — rien à déclarer dans `fxmanifest.lua`.

## 2. Déclarer le support dans la config

`module/keyhanger/config.lua` :

```lua
C.Boards["board_custom"] = {
    label = "Porte-clés custom",
    model = "lslegacy_keyhanger",   -- = nom du .ydr (sans extension)
    slots = "grid_4x2",             -- disposition existante ou la vôtre
}
C.DefaultBoard = "board_custom"     -- (optionnel) en faire le défaut
```

## 3. (Option) Ajouter vos clés au pool

```lua
C.KeyProps = {
    "lslegacy_key_01",
    "lslegacy_key_02",
    -- … vous pouvez retirer les props natifs si vous le souhaitez
}
```

## 4. Régler la position des clés sur le support

Chaque modèle a sa propre échelle/origine. Activez le debug puis ajustez :

```lua
C.Debug = true   -- trace un contour sur le support pour visualiser
```

Modifiez les offsets de la disposition utilisée dans `C.SlotLayouts`
(`x` latéral, `y` profondeur/avant, `z` vertical, en mètres). Vous pouvez créer
une disposition dédiée :

```lua
C.SlotLayouts.custom_board = {
    { x = -0.15, y = 0.04, z = 0.10 },
    { x =  0.00, y = 0.04, z = 0.10 },
    { x =  0.15, y = 0.04, z = 0.10 },
    -- …
}
-- puis dans C.Boards : slots = "custom_board"
```

## Astuce — pas de modeleur sous la main ?

Les props natifs suffisent pour un rendu propre et immersif. Modèles **vérifiés
existants** dans GTA V de base :

- **Support** : `prop_cork_board` (liège), `prop_muster_wboard_01` /
  `prop_muster_wboard_02` (planches bois), `prop_b_board_blank`.
- **Clés** : `prop_cs_keys_01` (trousseau), `prop_cuff_keys_01`.

Vérifiez l'existence d'un prop sur <https://gta-objects.xyz/objects/NOM_DU_PROP>
(une page valide = le prop existe).
