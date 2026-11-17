# Icônes des mods Aeternum

Source unique des icônes ModMenu des onze mods. Aucun PNG n'est retouché à la main : on modifie un SVG ici, puis on régénère.

```
python render.py              # écrit les 22 PNG dans les mods
python render.py lucarne      # un seul mod
python render.py --preview    # rendu dans preview/, rien n'est écrit dans les mods
```

Dépendance : `pip install resvg-py`.

## Charte

- **128 × 128 px, RGBA**, formes vectorielles plates rendues avec anti-aliasing. Pas de pixel art, pas de dégradé, pas de bruit.
- **Cadre commun**, posé par `render.py` et jamais redessiné dans un glyphe : tuile `background` arrondie (rayon 18), contour `border` de 3 px, filet d'accent de 4 px en haut à gauche, comme les panneaux des écrans.
- **Glyphe** dans `glyphs/<nom>.svg`, en viewBox 128, dans la zone 18 à 110. Les couleurs s'écrivent en jetons `{accent}`, `{secondary}`… et sont résolues depuis `PALETTE` dans `render.py`.
- **Palette** : l'or (`accent`, `accent_light`, `accent_dark`) porte la forme principale, le turquoise (`secondary`, `secondary_dark`) sert de touche, `text` et `muted` servent aux lignes de texte suggérées, `surface` et `border` aux fonds internes.
- Lisible à **32 px** (taille ModMenu) : traits de 2,5 px minimum, pas plus de trois ou quatre éléments.

## Glyphes

| Nom | Mod | Sujet |
|---|---|---|
| `aeternum` | parent ModMenu, copié dans les 11 mods | « A » et soulignement turquoise |
| `tieredbars` | ArmorHUD | cœur découpé en paliers |
| `chestradar` | Lookup | radar et coffre repéré |
| `lucarne` | Lucarne | grille d'emplacements |
| `astrolabe` | MenuRework | astrolabe |
| `parloir` | Parloir | deux bulles de discussion |
| `shaderarmor` | ShaderArmor | plastron mi-shader mi-uni |
| `silhouette` | Silhouette | buste mi-plein mi-pointillé |
| `standskins` | StandSkins | tête sur un porte-armure |
| `tallyboard` | TallyBoard | liste de joueurs et ping |
| `vikingbridge` | VikingBridge | pont entre deux piles |
| `vitrine` | Vitrine | infobulle d'objet |
| `mercuriale` | Mercuriale | étiquette de prix |
| `coursier` | Coursier | colis livré (flèche) |
| `inspectclassic` | InspectClassic (pack de ressources, `pack.png`) | pioche et flèche de rotation |

Un nouveau mod : ajouter `glyphs/<id>.svg`, une entrée dans `TARGETS` et le chemin de son `aeternum/icon.png` dans la liste du parent.
