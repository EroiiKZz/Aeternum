# Icônes des mods Aeternum

```
icons/
  svg/           les dessins, un fichier par icône. C'est ici qu'on modifie.
  png/arrondi/   les icônes finales, tuile à coins arrondis
  png/carre/     les icônes finales, tuile à angles droits
  ancien/        l'ancienne charte or et turquoise (glyphes, script, README)
  render.py      fabrique les PNG à partir des SVG, et les copie dans les mods
```

Aucun PNG n'est retouché à la main : on modifie un SVG, puis on régénère.

```
python render.py                  # refait png/arrondi et png/carre, ne touche à aucun mod
python render.py lucarne vernis   # seulement ces icônes
python render.py --mods carre     # copie png/carre dans les mods (ou --mods arrondi)
```

Dépendance : `pip install resvg-py` (seulement pour refaire les PNG, pas pour `--mods`).

Les mods embarquent aujourd'hui la version **carrée**.

## Charte

- **128 × 128 px, RGBA**, formes vectorielles plates rendues avec anti-aliasing. Pas de pixel art, pas de dégradé, pas de bruit.
- **Tuile** posée par `render.py` et jamais redessinée dans un glyphe : fond `ink` uni, sans contour. Deux formes, `arrondi` (rayon 26) et `carre` (angles droits). Le glyphe est le même dans les deux.
- **Glyphe** dans `svg/<nom>.svg`, en viewBox 128, dans la zone 12 à 116. Les couleurs s'écrivent en jetons `{lime}`, `{dim}`… et sont résolues depuis `PALETTE` dans `render.py`.
- **Palette** : `lime` porte la forme principale, `fg` (blanc) marque un seul détail, celui qu'on doit voir en premier, `dim` (lime éteint) sert aux éléments secondaires, `panel` aux fonds internes, `ink` aux découpes dans une forme pleine.
- **Traits** : 7 px, bouts et angles arrondis. Les pointillés font 5 px (`stroke-dasharray="1 9"`).
- **Quand un trait `dim` rejoint un trait `lime`** : le `dim` est écrit avant (donc dessous), avec `stroke-linecap="butt"`, et s'arrête sur l'axe du trait `lime`. Rien ne doit dépasser.
- Lisible à **32 px** (taille ModMenu) : pas plus de trois ou quatre éléments.

## Icônes

| Nom | Mod | Sujet |
|---|---|---|
| `aeternum` | parent ModMenu, copié dans chaque mod | « A » taillé comme une branche d'étoile, barré par l'arc d'orbite |
| `arpenteur` | Arpenteur | viseur rond et marqueur du joueur |
| `mapweave` | MapWeave | carte pliée, deux joueurs reliés |
| `lisiere` | Lisière | un sapin plein, un sapin en pointillé au-delà |
| `chestradar` | Lookup | radar et objet repéré |
| `lucarne` | Lucarne | grille d'emplacements |
| `vitrine` | Vitrine | infobulle d'objet |
| `mercuriale` | Mercuriale | étiquette de prix |
| `vernis` | Vernis | pinceau et éclat |
| `parloir` | Parloir | deux bulles de discussion |
| `tallyboard` | TallyBoard | liste de joueurs et ping |
| `tieredbars` | ArmorHUD | cœur découpé en paliers |
| `cerne` | Cerne | cube au contour épais |
| `silhouette` | Silhouette | buste mi-plein mi-contour |
| `standskins` | StandSkins | tête sur un porte-armure |
| `shaderarmor` | ShaderArmor | plastron mi-plein mi-contour |
| `coursier` | Coursier | colis qui file |
| `carnet` | Carnet | carnet et cases cochées |
| `vikingbridge` | VikingBridge | pont suspendu |

Un nouveau mod : ajouter `svg/<id>.svg`, une entrée dans `TARGETS` et le chemin de son `aeternum/icon.png` dans la liste du parent.

## Ancienne charte

`ancien/` garde tout ce qu'il faut pour refaire les icônes or et turquoise : les glyphes, le `render.py` et le README d'époque. Astrolabe (plus maintenu) et Inspect Classic (`pack.png`, pas redessiné) n'existent que là, leurs icônes en place n'ont pas été touchées.
