"""Rendu des icônes des mods.

    python render.py                  refait png/arrondi et png/carre (ne touche à aucun mod)
    python render.py lucarne vernis   seulement ces icônes
    python render.py --mods carre     copie png/carre dans les mods (ou --mods arrondi)
"""
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MODS = ROOT.parent.parent
SVG = ROOT / "svg"
PNG = ROOT / "png"
SIZE = 128

# Charte Nexsarum : tuile encre, glyphe lime
PALETTE = {
    "ink": "#0B0D0E",
    "panel": "#1B2226",
    "lime": "#D8FF63",
    "dim": "#7D9440",
    "fg": "#F2F4F5",
}

# Les deux formes de tuile : même glyphe, seul le cadre change
SHAPES = {
    "arrondi": '<rect width="128" height="128" rx="26" fill="{ink}"/>',
    "carre": '<rect width="128" height="128" fill="{ink}"/>',
}

# Où va chaque icône dans les mods
TARGETS = {
    "aeternum": [
        f"{mod}/src/main/resources/assets/aeternum/icon.png"
        for mod in (
            "Arpenteur", "ArmorHUD", "Carnet", "Cerne", "Coursier", "Lisiere", "Lookup", "Lucarne", "Mercuriale", "Parloir",
            "ShaderArmor", "Silhouette", "StandSkins", "TallyBoard", "Vernis", "VikingBridge", "Vitrine",
        )
    ],
    "vernis": ["Vernis/src/main/resources/assets/vernis/icon.png"],
    "arpenteur": ["Arpenteur/src/main/resources/assets/arpenteur/icon.png"],
    "lisiere": ["Lisiere/src/main/resources/assets/lisiere/icon.png"],
    "carnet": ["Carnet/src/main/resources/assets/carnet/icon.png"],
    "cerne": ["Cerne/src/main/resources/assets/cerne/icon.png"],
    "mercuriale": ["Mercuriale/src/main/resources/assets/mercuriale/icon.png"],
    "coursier": ["Coursier/src/main/resources/assets/coursier/icon.png"],
    "tieredbars": ["ArmorHUD/src/main/resources/assets/tieredbars/icon.png"],
    "chestradar": ["Lookup/src/main/resources/assets/chestradar/icon.png"],
    "lucarne": ["Lucarne/src/main/resources/assets/lucarne/icon.png"],
    "mapweave": ["MapWeave/src/main/resources/assets/mapweave/icon.png"],
    "parloir": ["Parloir/src/main/resources/assets/parloir/icon.png"],
    "shaderarmor": ["ShaderArmor/src/main/resources/assets/shaderarmor/icon.png"],
    "silhouette": ["Silhouette/src/main/resources/assets/silhouette/icon.png"],
    "standskins": ["StandSkins/src/main/resources/assets/standskins/icon.png"],
    "tallyboard": ["TallyBoard/src/main/resources/assets/tallyboard/icon.png"],
    "vikingbridge": ["VikingBridge/src/main/resources/assets/vikingbridge/icon.png"],
    "vitrine": ["Vitrine/src/main/resources/assets/vitrine/icon.png"],
}

# Grand format, réduit en jeu à la taille exacte (titre et chargement de Vernis)
LARGE = 256
LARGE_TARGETS = {
    "aeternum": ["Vernis/src/main/resources/assets/vernis/mark.png"],
}

FRAME = """<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 128 128">
{tile}
{glyph}
</svg>"""


def glyph(name):
    source = (SVG / f"{name}.svg").read_text(encoding="utf-8")
    body = re.search(r"<svg[^>]*>(.*)</svg>", source, re.S).group(1)
    # Un bloc <metadata> (provenance, éditeur SVG) n'est pas du dessin et ferait échouer resvg
    body = re.sub(r"<metadata>.*?</metadata>", "", body, flags=re.S)
    return re.sub(r"\{(\w+)\}", lambda m: PALETTE[m.group(1)], body)


def render(name, shape, size=SIZE):
    import resvg_py

    tile = SHAPES[shape].format(**PALETTE)
    svg = FRAME.format(size=size, tile=tile, glyph=glyph(name))
    return bytes(resvg_py.svg_to_bytes(svg_string=svg, width=size, height=size))


def export(names):
    for shape in SHAPES:
        out = PNG / shape
        out.mkdir(parents=True, exist_ok=True)
        for name in names:
            (out / f"{name}.png").write_bytes(render(name, shape))
        print(f"png/{shape} : {len(names)} icône(s)")
    large = [n for n in names if n in LARGE_TARGETS]
    if large:
        out = PNG / "grand"
        out.mkdir(parents=True, exist_ok=True)
        for name in large:
            (out / f"{name}.png").write_bytes(render(name, "arrondi", LARGE))
        print(f"png/grand : {len(large)} icône(s)")


def install(names, shape):
    for name in names:
        source = PNG / shape / f"{name}.png"
        for target in TARGETS[name]:
            path = MODS / target
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, path)
        print(f"{name} ({shape}) : {len(TARGETS[name])} fichier(s)")
        for target in LARGE_TARGETS.get(name, []):
            path = MODS / target
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(PNG / "grand" / f"{name}.png", path)
            print(f"{name} (grand) : {target}")


def main(args):
    shape = None
    if "--mods" in args:
        i = args.index("--mods")
        shape = args[i + 1] if i + 1 < len(args) else ""
        if shape not in SHAPES:
            sys.exit("--mods attend une forme : " + " ou ".join(SHAPES))
        args = args[:i] + args[i + 2:]
    names = args or list(TARGETS)
    unknown = [n for n in names if n not in TARGETS]
    if unknown:
        sys.exit("Icône inconnue : " + ", ".join(unknown))
    if shape:
        install(names, shape)
    else:
        export(names)


if __name__ == "__main__":
    main(sys.argv[1:])
