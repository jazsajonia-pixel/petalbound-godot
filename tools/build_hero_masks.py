#!/usr/bin/env python3
"""Build equipment region masks for the Ninja Adventure hero sheets.

Each mask has the same size as its sheet. For every opaque, non-outline pixel:
  R = region * 32  (1 head, 2 chest, 3 arms/hands, 4 legs, 5 feet, 6 face)
  G = shade * 40   (0 light, 1 mid, 2 dark, 3 accent, 4 skin, 5 eye white)
Outline pixels and transparent pixels are left at 0 (shader keeps them).
Regions are assigned per 32x32 frame relative to the frame's top/bottom rows,
so walk bob and jumps keep the same body parts.
"""
from PIL import Image
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
HERO = os.path.join(HERE, "..", "assets", "packs", "ninja_adventure", "hero")
CELL = 32
SHADE = {(0xa8, 0xa1, 0x29): 0, (0x56, 0x86, 0x4c): 1, (0x34, 0x5a, 0x52): 2,
         (0xd1, 0x4b, 0x34): 3, (0xef, 0x91, 0x4f): 4, (0xf2, 0xea, 0xf1): 5}
SHEETS = ["idle", "walk", "attack", "hit", "item", "jump", "pickup", "push", "roll", "swim", "dead"]


def classify(im, ox, oy, out):
    rows = [y for y in range(CELL) if any(im.getpixel((ox + x, oy + y))[3] > 0 for x in range(CELL))]
    if not rows:
        return
    top, bot = rows[0], rows[-1]
    h = bot - top + 1
    # proportions measured on the 15-row standing frame: 10 head, 2 chest, rest legs/feet
    head_end = top + max(3, round(h * 0.66)) - 1
    chest_end = head_end + max(1, round(h * 0.14))
    feet_start = max(chest_end + 1, bot - 1)
    for y in range(CELL):
        for x in range(CELL):
            p = im.getpixel((ox + x, oy + y))
            if p[3] == 0:
                continue
            shade = SHADE.get(p[:3])
            if shade is None:
                continue  # outline / unknown: untouched
            yy = y
            if shade in (4, 5) and yy <= head_end:
                region = 6
            elif yy <= head_end:
                region = 1
            elif shade in (3, 4) and yy < feet_start:
                region = 3
            elif yy <= chest_end:
                region = 2
            elif yy < feet_start:
                region = 4
            else:
                region = 5
            out.putpixel((ox + x, oy + y), (region * 32, shade * 40, 0, 255))


def main():
    for name in SHEETS:
        src = os.path.join(HERO, name + ".png")
        if not os.path.exists(src):
            continue
        im = Image.open(src).convert("RGBA")
        out = Image.new("RGBA", im.size, (0, 0, 0, 0))
        for cy in range(0, im.size[1], CELL):
            for cx in range(0, im.size[0], CELL):
                classify(im, cx, cy, out)
        out.save(os.path.join(HERO, "masks", name + "_mask.png"))
        print("mask", name, im.size)


if __name__ == "__main__":
    main()
