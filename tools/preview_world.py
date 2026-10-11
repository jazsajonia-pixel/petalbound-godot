#!/usr/bin/env python3
"""Render a quick top-down preview of assets/data/world.json (docs/world_map.png)."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets" / "data"
PACK = ROOT / "assets" / "packs" / "ninja_adventure" / "tilesets"
world = json.loads((DATA / "world.json").read_text())
props = json.loads((DATA / "props.json").read_text())
W, H = world["tiles"]
biome = np.array(Image.open(DATA / "world_biome.png"))[:, :, 0]
field = np.array(Image.open(DATA / "world_field.png")).astype(float) / 255
COL = {0: (168, 184, 69), 1: (104, 150, 64), 2: (233, 160, 92), 3: (226, 220, 236), 4: (176, 150, 128), 5: (255, 214, 160)}
img = np.zeros((H * 16, W * 16, 3), dtype=np.uint8)
big = np.kron(biome, np.ones((16, 16), dtype=np.uint8))
for k, c in COL.items():
    img[big == k] = c
f = np.array(Image.fromarray((field[:, :, :3] * 255).astype(np.uint8), "RGB").resize((W * 16, H * 16), Image.BILINEAR)).astype(float) / 255
img[f[:, :, 0] > 0.5] = (190, 120, 80)
wm = f[:, :, 1] > 0.5
img[wm] = (90, 200, 225)
img[wm & (f[:, :, 2] > 0.7)] = (60, 150, 200)
canvas = Image.fromarray(img).convert("RGBA")
sheets = {}
for p in sorted(world["props"], key=lambda p: p["y"]):
    d = props[p["k"]]
    if d["sheet"] not in sheets:
        sheets[d["sheet"]] = Image.open(PACK / f"{d['sheet']}.png").convert("RGBA")
    r = d["rect"]
    spr = sheets[d["sheet"]].crop((r[0], r[1], r[0] + r[2], r[1] + r[3]))
    canvas.alpha_composite(spr, (int(p["x"] - r[2] / 2), int(p["y"] - r[3])))
out = ROOT / "docs"
out.mkdir(exist_ok=True)
canvas.convert("RGB").resize((W * 4, H * 4), Image.LANCZOS).save(out / "world_map.png")
canvas.convert("RGB").crop((900, 1500, 1900, 2150)).save("/tmp/world_crop.png")
print("ok")
