import re
import sys
from pathlib import Path

import resvg_py

ROOT = Path(__file__).resolve().parent
MODS = ROOT.parent.parent
SIZE = 128

PALETTE = {
    "background": "#17110A",
    "surface": "#241C13",
    "border": "#3B3125",
    "accent": "#F2B441",
    "accent_light": "#FFD57A",
    "accent_dark": "#966A20",
    "secondary": "#5FB8A6",
    "secondary_dark": "#3E8577",
    "text": "#EDE3CF",
    "muted": "#9C8D77",
}

TARGETS = {
    "aeternum": [
        f"{mod}/src/main/resources/assets/aeternum/icon.png"
        for mod in (
            "Arpenteur", "ArmorHUD", "Carnet", "Cerne", "Coursier", "Lisiere", "Lookup", "Lucarne", "MenuRework", "Mercuriale", "Parloir",
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
    "mapweave": ["MapWeave/versions/26.2/src/main/resources/assets/mapweave/icon.png"],
    "astrolabe": ["MenuRework/src/main/resources/assets/astrolabe/icon.png"],
    "parloir": ["Parloir/src/main/resources/assets/parloir/icon.png"],
    "shaderarmor": ["ShaderArmor/src/main/resources/assets/shaderarmor/icon.png"],
    "silhouette": ["Silhouette/src/main/resources/assets/silhouette/icon.png"],
    "standskins": ["StandSkins/src/main/resources/assets/standskins/icon.png"],
    "tallyboard": ["TallyBoard/src/main/resources/assets/tallyboard/icon.png"],
    "vikingbridge": ["VikingBridge/src/main/resources/assets/vikingbridge/icon.png"],
    "vitrine": ["Vitrine/src/main/resources/assets/vitrine/icon.png"],
    "inspectclassic": ["InspectClassic/pack/pack.png"],
}

FRAME = """<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 128 128">
<rect x="2.5" y="2.5" width="123" height="123" rx="18" fill="{background}" stroke="{border}" stroke-width="3"/>
{glyph}
<path d="M22 4 H50" stroke="{accent}" stroke-width="4" stroke-linecap="round"/>
</svg>"""


def glyph(name):
    source = (ROOT / "glyphs" / f"{name}.svg").read_text(encoding="utf-8")
    body = re.search(r"<svg[^>]*>(.*)</svg>", source, re.S).group(1)
    return re.sub(r"\{(\w+)\}", lambda m: PALETTE[m.group(1)], body)


def render(name):
    svg = FRAME.format(size=SIZE, glyph=glyph(name), **PALETTE)
    return bytes(resvg_py.svg_to_bytes(svg_string=svg, width=SIZE, height=SIZE))


def main(args):
    preview = "--preview" in args
    names = [a for a in args if not a.startswith("--")] or list(TARGETS)
    out = ROOT / "preview"
    for name in names:
        png = render(name)
        if preview:
            out.mkdir(exist_ok=True)
            (out / f"{name}.png").write_bytes(png)
            continue
        for target in TARGETS[name]:
            path = MODS / target
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(png)
        print(f"{name}: {len(TARGETS[name])} fichier(s)")


if __name__ == "__main__":
    main(sys.argv[1:])
