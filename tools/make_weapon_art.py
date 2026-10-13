"""Original 16px-style weapon sprites for Petalbound (created for this project,
released with the repo). Palette matches the Ninja Adventure weapon icons
(outline 141b1b, metal f2eaf1/abc2bc/8d977f, wood ffad5d/a3754e/965340).
Run: python3 tools/make_weapon_art.py"""
from PIL import Image
import os

PAL = {
    "O": (0x14, 0x1b, 0x1b), "l": (0xf2, 0xea, 0xf1), "m": (0xab, 0xc2, 0xbc), "d": (0x8d, 0x97, 0x7f),
    "h": (0xff, 0xad, 0x5d), "w": (0xa3, 0x75, 0x4e), "b": (0x96, 0x53, 0x40),
    "g": (0xff, 0xd2, 0x4a), "G": (0xc9, 0x8a, 0x2a), "r": (0xd0, 0x4a, 0x3c), "R": (0x8f, 0x3e, 0x56),
    "p": (0xf2, 0x9a, 0xc0), "v": (0x6a, 0xb0, 0x4c), "V": (0xc8, 0xf0, 0x8a), "k": (0x3e, 0x6e, 0x3a),
    "u": (0x8a, 0x9c, 0xff), "U": (0x4a, 0x4f, 0x9e), "s": (0xff, 0xe0, 0x8a), "S": (0xff, 0xff, 0xff),
    "c": (0xc9, 0xb8, 0xff), "f": (0x9a, 0x96, 0xab), "F": (0x5f, 0x5a, 0x70),
}

ART = {
    "oakwood_staff": """
.OOO.
OhwbO
ObbbO
.OwO.
.OwO.
.OhO.
.OwO.
.OwO.
.OwO.
.OhO.
.OwO.
.OwO.
.OwO.
.OhO.
.OwO.
.OwO.
.OwO.
ObbbO
OhwbO
.OOO.""",
    "oakwood_staff_hand": """
.OOO.
OhwbO
ObbbO
.OwO.
.OwO.
.OhO.
.OwO.
.OwO.
.OwO.
.OhO.
.OwO.
.OwO.
.OwO.
ObbbO
OhwbO
.OOO.""",
    "cloudstride_staff": """
.OOO.
OgggO
OgGGO
OGGGO
.OrO.
.OrO.
.OgO.
.OrO.
.OrO.
.ORO.
.OrO.
.OrO.
.OgO.
.OrO.
.OrO.
.ORO.
OgggO
OgGGO
OGGGO
.OOO.""",
    "cloudstride_staff_hand": """
.OOO.
OgggO
OgGGO
OGGGO
.OrO.
.OrO.
.OgO.
.OrO.
.OrO.
.ORO.
.OrO.
.OrO.
OgggO
OgGGO
OGGGO
.OOO.""",
    "ironbloom_gauntlet": """
..OOOOOO..
.OlmlmlmO.
.OlmlmlmO.
OOmmmmmmO.
OlOmmmmmdO
OlmOdddddO
.OmmmmmmO.
.OdpppppdO
.OddddddO.
..OOOOOO..""",
    "ironbloom_gauntlet_hand": """
.OOOOO.
OlmlmlO
OmmmmmO
OmdddmO
OpppppO
OdddddO
.OOOOO.""",
    "thornlash_whip": """
...OOOOO....
..OvvVvvO...
.OvOOOOOvO..
OvO.....OvO.
OVO..OO.OvO.
OvO.OvvOOvO.
OvO.OvO.OVO.
.OvOOvO.OvO.
..OvvO..OvO.
...OO..OhwO.
......OhwO..
......OOO...""",
    "thornlash_whip_hand": """
.OO..
OvvO.
OVO..
OvO..
.OvO.
.OkO.
OhwO.
OhwO.
OwbO.
.OO..""",
    "starweave_gloves": """
.OO.OO.OO.
OuuOuuOuuO
OuuOuuOuuO
OuuuuuuuuO
OuusssuuuO
OuusSsuuOO
OuuusuuO..
.OUUUUUO..
.OccccO...
..OOOO....""",
    "starweave_gloves_hand": """
.OOOO.
OuuuuO
OusSuO
OuusuO
OccccO
.OOOO.""",
    "direwolf_claws": """
O...O...O.
lO..lO..lO
mlO.mlO.ml
OmlOOmlOOm
.OmmOOmmOO
..OddddddO
..OfffffO.
..OfFfFfO.
...OOOOO..""",
    "direwolf_claws_hand": """
O.O.O.
lOlOlO
mlmlmO
OmOmOO
OddddO
OfFfFO
.OOOO.""",
}

out = os.path.join(os.path.dirname(__file__), "..", "assets", "art", "weapons")
os.makedirs(out, exist_ok=True)
for name, txt in ART.items():
    rows = [r for r in txt.strip("\n").split("\n")]
    w = max(len(r) for r in rows)
    im = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r.ljust(w, ".")):
            if ch in PAL:
                im.putpixel((x, y), PAL[ch] + (255,))
    im.save(os.path.join(out, name + ".png"))
    print(name, im.size)
