#!/usr/bin/env python3
"""Generate the Petalbound open-world data offline.

Outputs (all deterministic for a given SEED):
  assets/data/world_biome.png   W x H tiles, R channel = biome id
  assets/data/world_field.png   2W x 2H RGB, R = road, G = water, B = water depth
  assets/data/world.json        props, ground decor, spawns, landmarks, NPCs, chests
  docs/world_map.png            a composited preview of the whole map

Run after tools/import_ninja_adventure.py:
    python3 tools/generate_world.py
"""
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets" / "data"
PACK = ROOT / "assets" / "packs" / "ninja_adventure"
SEED = 20261011
W, H = 256, 176
TILE = 16
FR = 2  # field resolution (texels per tile)

MEADOW, FOREST, DESERT, RUINS, MARSH, BEACH = 0, 1, 2, 3, 4, 5
BIOME_NAMES = ["Petalfield Meadow", "Hollowroot Grove", "Sunscar Dunes", "Moonstone Ruins", "Glasswater Marsh", "Lantern Coast"]

rng = np.random.default_rng(SEED)


# ---------------------------------------------------------------- noise
def value_noise(shape, scale, seed):
    r = np.random.default_rng(seed)
    gh, gw = int(shape[0] / scale) + 3, int(shape[1] / scale) + 3
    grid = r.random((gh, gw))
    ys = np.arange(shape[0]) / scale
    xs = np.arange(shape[1]) / scale
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = grid[y0][:, x0]
    b = grid[y0][:, x0 + 1]
    c = grid[y0 + 1][:, x0]
    d = grid[y0 + 1][:, x0 + 1]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def fbm(shape, scale, seed, octaves=4):
    total = np.zeros(shape)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        total += value_noise(shape, scale / (2 ** o), seed + o * 101) * amp
        norm += amp
        amp *= 0.5
    return total / norm


# ---------------------------------------------------------------- biomes
SEEDS = [
    (MEADOW, 78, 118), (MEADOW, 108, 112), (MEADOW, 118, 84), (MEADOW, 44, 132), (MEADOW, 136, 100), (MEADOW, 96, 140),
    (FOREST, 40, 44), (FOREST, 70, 32), (FOREST, 24, 80), (FOREST, 84, 60), (FOREST, 18, 20),
    (DESERT, 218, 112), (DESERT, 238, 140), (DESERT, 200, 92), (DESERT, 242, 84),
    (RUINS, 204, 40), (RUINS, 230, 26), (RUINS, 172, 30), (RUINS, 128, 24), (RUINS, 150, 16),
    (MARSH, 166, 140), (MARSH, 144, 150), (MARSH, 190, 156), (MARSH, 150, 128),
]

yy, xx = np.mgrid[0:H, 0:W].astype(float)
def nrm(a):
    return (a - a.mean()) / (a.std() + 1e-6)


warp_x = nrm(fbm((H, W), 30, 11)) * 9.0 + nrm(fbm((H, W), 6, 12)) * 2.2
warp_y = nrm(fbm((H, W), 30, 23)) * 9.0 + nrm(fbm((H, W), 6, 24)) * 2.2
best = np.full((H, W), 1e9)
biome = np.zeros((H, W), dtype=np.uint8)
for b, sx, sy in SEEDS:
    d = np.hypot(xx + warp_x - sx, (yy + warp_y - sy) * 1.1)
    m = d < best
    best[m] = d[m]
    biome[m] = b
# majority filter removes tiny single-biome islands that read as blocky patches
from scipy import ndimage
for _ in range(2):
    counts = np.stack([ndimage.uniform_filter((biome == k).astype(float), size=7, mode="nearest") for k in range(6)])
    biome = counts.argmax(0).astype(np.uint8)
coast = 158 + (fbm((H, W), 20, 41) - 0.5) * 10
beach_mask = (yy > coast) & (biome != MARSH)
beach_mask |= (yy > coast + 4)
biome[beach_mask] = BEACH

# ---------------------------------------------------------------- field (roads + water)
FH, FW = H * FR, W * FR
fy, fx = np.mgrid[0:FH, 0:FW].astype(float)
fy = (fy + 0.5) / FR
fx = (fx + 0.5) / FR
road = np.zeros((FH, FW))
water = np.zeros((FH, FW))
glow = np.zeros((FH, FW))
edge_noise = fbm((FH, FW), 10, 77)


def stamp_segment(arr, a, b, width, soft=1.2):
    ax, ay = a
    bx, by = b
    pad = width + soft + 2
    x0, x1 = int(max(0, (min(ax, bx) - pad) * FR)), int(min(FW, (max(ax, bx) + pad) * FR))
    y0, y1 = int(max(0, (min(ay, by) - pad) * FR)), int(min(FH, (max(ay, by) + pad) * FR))
    px = fx[y0:y1, x0:x1]
    py = fy[y0:y1, x0:x1]
    vx, vy = bx - ax, by - ay
    ll = max(1e-6, vx * vx + vy * vy)
    t = np.clip(((px - ax) * vx + (py - ay) * vy) / ll, 0, 1)
    d = np.hypot(px - (ax + vx * t), py - (ay + vy * t))
    v = np.clip(1.0 - (d - width) / soft, 0, 1) * 0.5 + np.clip(1.0 - d / max(width, 0.01), 0, 1) * 0.5
    arr[y0:y1, x0:x1] = np.maximum(arr[y0:y1, x0:x1], v)


def stamp_polyline(arr, pts, width, soft=1.2):
    # Catmull-Rom smoothing for organic roads
    smooth = []
    p = [pts[0]] + pts + [pts[-1]]
    for i in range(1, len(p) - 2):
        for s in range(8):
            t = s / 8
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p[i][0]) + (-p[i - 1][0] + p[i + 1][0]) * t + (2 * p[i - 1][0] - 5 * p[i][0] + 4 * p[i + 1][0] - p[i + 2][0]) * t2 + (-p[i - 1][0] + 3 * p[i][0] - 3 * p[i + 1][0] + p[i + 2][0]) * t3)
            y = 0.5 * ((2 * p[i][1]) + (-p[i - 1][1] + p[i + 1][1]) * t + (2 * p[i - 1][1] - 5 * p[i][1] + 4 * p[i + 1][1] - p[i + 2][1]) * t2 + (-p[i - 1][1] + 3 * p[i][1] - 3 * p[i + 1][1] + p[i + 2][1]) * t3)
            smooth.append((x, y))
    smooth.append(pts[-1])
    for a, b in zip(smooth, smooth[1:]):
        stamp_segment(arr, a, b, width, soft)
    return smooth


def stamp_blob(arr, cx, cy, rx, ry, wobble=0.25, seed=0):
    pad = max(rx, ry) * (1 + wobble) + 3
    x0, x1 = int(max(0, (cx - pad) * FR)), int(min(FW, (cx + pad) * FR))
    y0, y1 = int(max(0, (cy - pad) * FR)), int(min(FH, (cy + pad) * FR))
    px = fx[y0:y1, x0:x1]
    py = fy[y0:y1, x0:x1]
    ang = np.arctan2(py - cy, px - cx)
    r = np.random.default_rng(seed)
    k = np.zeros_like(ang)
    for f in range(2, 6):
        k += np.sin(ang * f + r.random() * 6.28) * (wobble / f) * (1.6 if f == 2 else 1)
    d = np.hypot((px - cx) / rx, (py - cy) / ry) / (1 + k)
    v = np.clip((1.0 - d) * max(rx, ry) / 2.2 + 0.5, 0, 1)
    arr[y0:y1, x0:x1] = np.maximum(arr[y0:y1, x0:x1], v)


LANDMARKS = {
    "hearthgrove": [78, 118], "lake_lumen": [118, 96], "moonwell": [128, 26],
    "briarback_arena": [40, 30], "toad_arena": [178, 150], "cyclops_arena": [230, 124], "warden_arena": [214, 30],
    "oasis": [214, 112], "ruins_pool": [196, 48],
}

ROADS = [
    [(78, 118), (76, 102), (66, 80), (56, 56), (44, 36)],                     # north to Hollowroot
    [(78, 118), (98, 117), (124, 112), (148, 118), (166, 134), (176, 146)],  # east to marsh
    [(124, 112), (150, 102), (182, 106), (208, 110), (228, 122)],            # dunes
    [(150, 102), (160, 74), (184, 52), (212, 32)],                           # ruins
    [(76, 102), (98, 82), (118, 56), (128, 32)],                             # moonwell
    [(160, 74), (142, 50), (130, 32)],                                       # ruins -> moonwell
    [(78, 118), (82, 140), (92, 160)],                                       # coast
    [(56, 56), (88, 46), (118, 56)],                                         # grove ring
]
road_curves = [stamp_polyline(road, r, 0.95, 1.1) for r in ROADS]
# village plaza + arenas
for name, rad in [("hearthgrove", 5.5), ("moonwell", 6.0), ("briarback_arena", 4.0), ("warden_arena", 4.0), ("cyclops_arena", 3.5)]:
    cx, cy = LANDMARKS[name]
    stamp_blob(road, cx, cy, rad, rad * 0.8, 0.12, seed=len(name))

# water bodies
stamp_blob(water, 118, 96, 11, 7, 0.28, 1)
stamp_blob(water, 30, 62, 6, 4, 0.3, 2)
stamp_blob(water, 160, 138, 8, 5, 0.35, 3)
stamp_blob(water, 174, 132, 4, 3, 0.3, 4)
stamp_blob(water, 150, 148, 5, 3.5, 0.3, 5)
stamp_blob(water, 190, 160, 7, 4, 0.3, 6)
stamp_blob(water, 214, 112, 5, 3.5, 0.2, 7)
stamp_blob(water, 196, 48, 7, 3, 0.1, 8)
stamp_blob(water, 128, 25, 3.2, 2.4, 0.05, 9)
river = stamp_polyline(water, [(196, 52), (182, 66), (164, 78), (142, 86), (124, 94)], 1.1, 1.0)
stamp_polyline(water, [(30, 62), (22, 76), (18, 96), (24, 120), (20, 150), (24, 176)], 0.9, 1.0)
# sea along the south
sea = np.clip((fy - (coast[np.clip(fy.astype(int), 0, H - 1), np.clip(fx.astype(int), 0, W - 1)] + 6.5)) * 0.5 + 0.5, 0, 1)
water = np.maximum(water, sea)
# roads ford rivers / don't flood the island
water = np.where(road > 0.55, np.minimum(water, 0.25), water)
stamp_blob_island = np.zeros_like(water)
stamp_blob(stamp_blob_island, 121, 95, 2.6, 1.8, 0.2, 10)
water = np.where(stamp_blob_island > 0.5, 0.0, water)
glow_tmp = np.zeros_like(glow)
stamp_blob(glow_tmp, 128, 25, 3.2, 2.4, 0.05, 9)
glow = glow_tmp

# depth = blurred water
def box_blur(a, r):
    k = 2 * r + 1
    pad = np.pad(a, r, mode="edge")
    c = pad.cumsum(0).cumsum(1)
    c = np.pad(c, ((1, 0), (1, 0)))
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)


wet = (water > 0.5).astype(float)
depth = box_blur(box_blur(wet, 3), 3)

field = np.stack([road, water, depth], axis=-1)
field_img = (np.clip(field, 0, 1) * 255).astype(np.uint8)
DATA.mkdir(parents=True, exist_ok=True)
Image.fromarray(field_img, "RGB").save(DATA / "world_field.png")
Image.fromarray(np.stack([biome, biome, biome], -1).astype(np.uint8), "RGB").save(DATA / "world_biome.png")

# tile-level masks
road_t = road.reshape(H, FR, W, FR).max(axis=(1, 3))
water_t = water.reshape(H, FR, W, FR).max(axis=(1, 3))

# ---------------------------------------------------------------- placement
PROPS = json.loads((DATA / "props.json").read_text())
occupied = np.zeros((H * 2, W * 2), dtype=bool)  # half-tile occupancy grid
props = []
decor = []


def prop_size(kind):
    r = PROPS[kind]["rect"]
    return r[2], r[3]


COLLIDE = {}


def collision_for(kind):
    w, h = prop_size(kind)
    k = kind
    if k.startswith(("tree_", "big_", "small_tree", "palm", "thin")) and not k.startswith("palm_grove"):
        return {"w": 10, "h": 7, "oy": -4, "low": False}
    if k.startswith(("grove_", "palm_grove")):
        return {"w": int(w * 0.78), "h": 12, "oy": -6, "low": False}
    if k.startswith(("house_", "shop", "barn", "dome_", "desert_house", "igloo", "hut_")):
        return {"w": w - 6, "h": int(h * 0.6), "oy": -int(h * 0.3), "low": False}
    if k in ("bush_round", "bush_round2", "log", "stub", "stump", "stump_dark", "pebble_brown", "pebble_gray", "shrub_dry", "haystack"):
        return {"w": max(8, w - 4), "h": max(6, int(h * 0.45)), "oy": -max(3, int(h * 0.22)), "low": True}
    if k in ("torii",):
        return None
    if k in ("arch",):
        return {"w": 10, "h": 8, "oy": -4, "low": False, "split": int(w * 0.36)}
    return {"w": max(6, w - 4), "h": max(6, int(h * 0.5)), "oy": -max(3, int(h * 0.25)), "low": False}


def can_place(tx, ty, rad, allow_road=False, allow_water=False):
    if tx < 1 or ty < 1 or tx >= W - 1 or ty >= H - 1:
        return False
    hx, hy = int(tx * 2), int(ty * 2)
    r2 = int(math.ceil(rad * 2))
    y0, y1 = max(0, hy - r2), min(H * 2, hy + r2 + 1)
    x0, x1 = max(0, hx - r2), min(W * 2, hx + r2 + 1)
    if occupied[y0:y1, x0:x1].any():
        return False
    ix, iy = int(tx), int(ty)
    if not allow_road and road_t[max(0, iy - 1):iy + 2, max(0, ix - 1):ix + 2].max() > 0.08:
        return False
    if not allow_water and water_t[max(0, iy - 1):iy + 2, max(0, ix - 1):ix + 2].max() > 0.35:
        return False
    return True


def mark(tx, ty, rad):
    hx, hy = int(tx * 2), int(ty * 2)
    r2 = int(math.ceil(rad * 2))
    occupied[max(0, hy - r2):hy + r2 + 1, max(0, hx - r2):hx + r2 + 1] = True


def add_prop(kind, tx, ty, extra=None, force=False, rad=None):
    w, h = prop_size(kind)
    if rad is None:
        rad = max(0.6, w / 16 * 0.45)
    if not force and not can_place(tx, ty, rad):
        return False
    mark(tx, ty, rad)
    p = {"k": kind, "x": round(tx * TILE, 1), "y": round(ty * TILE, 1)}
    c = collision_for(kind)
    if c:
        p["c"] = c
    if extra:
        p.update(extra)
    props.append(p)
    return True


def clear_zone(cx, cy, r):
    hx, hy = int(cx * 2), int(cy * 2)
    rr = int(r * 2)
    occupied[max(0, hy - rr):hy + rr, max(0, hx - rr):hx + rr] = True


# ---- hand-authored landmarks
vx, vy = LANDMARKS["hearthgrove"]
village = [
    ("house_orange", vx - 11, vy - 5), ("house_red", vx + 10, vy - 6), ("house_wood", vx - 13, vy + 8),
    ("shop", vx + 12, vy + 7), ("house_round", vx - 3, vy - 10), ("barn", vx + 22, vy + 2),
    ("lion_fountain", vx, vy + 0.6), ("stone_lantern", vx - 5, vy - 3), ("stone_lantern", vx + 5, vy - 3),
    ("stone_lantern", vx - 5, vy + 5), ("stone_lantern", vx + 5, vy + 5), ("torii", vx + 0, vy - 16),
    ("haystack", vx + 18, vy + 6), ("haystack", vx + 19, vy + 7.5), ("barrel", vx + 9, vy + 9.5), ("barrel", vx + 9.8, vy + 9.6),
    ("crate", vx + 15, vy + 9.4), ("pot", vx - 9, vy - 3.5), ("pot_red", vx - 8.3, vy - 3.5), ("bench", vx - 2, vy + 7.8),
    ("sign", vx + 4, vy - 12), ("plant_pot", vx - 14.5, vy - 4), ("plant_pot", vx - 7.5, vy - 4),
    ("mailbox", vx - 10, vy + 9.5), ("big_pink", vx - 20, vy - 2), ("big_pink", vx + 4, vy - 20),
    ("tree_pink", vx - 18, vy + 12), ("tree_pink", vx + 26, vy - 6), ("tree_lime", vx - 24, vy + 6),
    ("statue_monk", vx - 6.5, vy + 13),
]
for kind, tx, ty in village:
    add_prop(kind, tx, ty, force=True)
clear_zone(vx, vy, 4)

mx, my = LANDMARKS["moonwell"]
for kind, tx, ty in [("arch", mx, my - 4.5), ("pillar", mx - 6, my + 1), ("pillar", mx + 6, my + 1), ("pillar", mx - 5, my - 3.5),
                     ("pillar", mx + 5, my - 3.5), ("statue_eye", mx - 9, my + 4), ("statue_eye", mx + 9, my + 4),
                     ("stone_lantern", mx - 3.5, my + 6), ("stone_lantern", mx + 3.5, my + 6), ("big_white", mx - 13, my - 2), ("big_white", mx + 13, my - 2)]:
    add_prop(kind, tx, ty, force=True)
clear_zone(mx, my, 3)

# outposts
ox, oy = LANDMARKS["oasis"]
for kind, tx, ty in [("dome_house", ox - 9, oy - 3), ("dome_tower", ox + 9, oy - 6), ("stall_red", ox - 4, oy + 6), ("palm", ox - 6, oy - 4),
                     ("palm", ox + 6, oy + 4), ("palm", ox + 4, oy - 5), ("pot_desert", ox - 2, oy + 7), ("pot_desert", ox - 1.2, oy + 7.2), ("desert_house", ox + 2, oy + 11)]:
    add_prop(kind, tx, ty, force=True)
ax, ay = LANDMARKS["warden_arena"]
for i in range(8):
    a = i / 8 * math.tau
    add_prop("pillar", ax + math.cos(a) * 8.5, ay + math.sin(a) * 6.5, force=True)
for kind, tx, ty in [("statue_frog", ax - 12, ay + 8), ("statue_monk", ax + 12, ay + 8), ("arch", ax, ay + 10.5)]:
    add_prop(kind, tx, ty, force=True)
clear_zone(ax, ay, 6)
bx, by = LANDMARKS["briarback_arena"]
for i in range(10):
    a = i / 10 * math.tau
    add_prop("bamboo", bx + math.cos(a) * 9, by + math.sin(a) * 7, force=True)
clear_zone(bx, by, 7)
cx_, cy_ = LANDMARKS["cyclops_arena"]
for kind, tx, ty in [("tall_rock", cx_ - 9, cy_ - 5), ("tall_rock", cx_ + 9, cy_ - 4), ("cliff_rock_big", cx_ + 2, cy_ - 10), ("bones", cx_ - 4, cy_ + 5), ("skull_bone", cx_ + 3, cy_ + 6)]:
    add_prop(kind, tx, ty, force=True)
clear_zone(cx_, cy_, 6)
tx_, ty_ = LANDMARKS["toad_arena"]
clear_zone(tx_, ty_, 6)
for kind, tx, ty in [("tree_dead", tx_ - 9, ty_ - 6), ("tree_dead", tx_ + 9, ty_ - 6), ("grave", tx_ + 6, ty_ + 6), ("cross", tx_ - 6, ty_ + 6)]:
    add_prop(kind, tx, ty, force=True)
# ruins scatter
for kind, tx, ty in [("statue_eye", 186, 40), ("statue_frog", 202, 58), ("arch", 178, 26), ("pillar", 182, 30), ("pillar", 175, 30),
                     ("grave", 160, 22), ("grave", 162, 23), ("cross", 164, 21), ("statue_monk", 150, 20), ("arch", 236, 44)]:
    add_prop(kind, tx, ty, force=True)
# lake island tree
add_prop("big_pink", 121, 95.6, force=True)

# shrines (respawn waystones) - one per region
SHRINES = [
    {"id": "hearthgrove", "name": "Hearthgrove Waystone", "x": (vx - 6.5) * TILE, "y": (vy + 13) * TILE},
    {"id": "hollowroot", "name": "Hollowroot Waystone", "x": 60 * TILE, "y": 64 * TILE},
    {"id": "glasswater", "name": "Glasswater Waystone", "x": 152 * TILE, "y": 124 * TILE},
    {"id": "sunscar", "name": "Sunscar Waystone", "x": 196 * TILE, "y": 104 * TILE},
    {"id": "moonstone", "name": "Moonstone Waystone", "x": 176 * TILE, "y": 52 * TILE},
]
for s in SHRINES[1:]:
    add_prop("statue_monk", s["x"] / TILE, s["y"] / TILE, force=True)
    clear_zone(s["x"] / TILE, s["y"] / TILE + 1.5, 1.5)

# ---- procedural scatter per biome
SCATTER = {
    MEADOW: [("tree_pink", 0.020), ("tree_green", 0.010), ("tree_lime", 0.008), ("big_pink", 0.003), ("big_green", 0.002),
             ("grove_pink", 0.0012), ("grove_lime", 0.0008), ("boulder_gray", 0.003), ("bush_round", 0.012), ("bush_round2", 0.006),
             ("stump", 0.002), ("log", 0.0015), ("rock_gray_small", 0.0015)],
    FOREST: [("tree_pine", 0.040), ("tree_green", 0.016), ("tree_jungle", 0.010), ("grove_pine", 0.006), ("grove_green", 0.003),
             ("big_green", 0.004), ("stump_dark", 0.004), ("bush_round2", 0.016), ("boulder_teal", 0.003), ("small_tree", 0.004), ("log", 0.002)],
    DESERT: [("palm", 0.010), ("palm_grove", 0.0015), ("cliff_rock_big", 0.0025), ("tall_rock", 0.003), ("rock_small", 0.006),
             ("boulder_brown", 0.004), ("bones", 0.004), ("skull_bone", 0.0015), ("shrub_dry", 0.009), ("rocks_brown", 0.0012)],
    RUINS: [("tree_white", 0.014), ("big_white", 0.003), ("grove_white", 0.0012), ("rocks_gray", 0.0015), ("cliff_rock_gray", 0.0015),
            ("tall_rock_gray", 0.0025), ("boulder_gray", 0.005), ("grave", 0.0015), ("pillar", 0.002), ("pebble_gray", 0.003)],
    MARSH: [("tree_dead", 0.014), ("grove_dead", 0.002), ("tree_jungle", 0.007), ("bamboo", 0.010), ("stump_dark", 0.004),
            ("bush_round2", 0.012), ("boulder_teal", 0.003), ("tree_lime2", 0.006)],
    BEACH: [("palm", 0.008), ("rock_small", 0.003), ("bones", 0.0015), ("boulder_brown", 0.002), ("shrub_dry", 0.003)],
}
density = fbm((H, W), 18, 99)
DENSITY = {MEADOW: 1.5, FOREST: 2.1, DESERT: 1.2, RUINS: 1.3, MARSH: 1.6, BEACH: 1.0}
order = rng.permutation(W * H)
for idx in order:
    ty, tx = divmod(int(idx), W)
    b = int(biome[ty, tx])
    dens = (0.25 + density[ty, tx] ** 1.6 * 3.2) * DENSITY[b]
    for kind, p in SCATTER[b]:
        if rng.random() < p * dens:
            add_prop(kind, tx + rng.random(), ty + rng.random())
            break

# ---- world border: dense groves so the map edge reads as a natural wall
border_kinds = {MEADOW: "grove_green", FOREST: "grove_pine", DESERT: "rocks_brown", RUINS: "grove_white", MARSH: "grove_dead", BEACH: None}
for t in np.arange(1.5, W - 1, 3.2):
    for ty in (1.6, 4.2):
        b = int(biome[int(ty), int(t)])
        k = border_kinds[b]
        if k:
            add_prop(k, t + rng.random() * 0.6, ty + rng.random() * 0.4, force=True)
for t in np.arange(6, H - 14, 3.0):
    for tx in (1.6, W - 2.2):
        b = int(biome[int(t), int(tx)])
        k = border_kinds[b]
        if k:
            add_prop(k, tx, t + rng.random() * 0.6, force=True)

# ---- ground decor (no collision; drawn in batched chunks)
DECOR = {
    MEADOW: ["fd_flower_yellow", "fd_flower_red", "fd_flower_white", "fd_tuft", "fd_tuft2", "fd_clover", "fd_leafy"],
    FOREST: ["fd_tuft", "fd_tuft2", "fd_leaves", "fd_sticks", "fd_clover", "fd_leafy", "fd_sprout"],
    DESERT: ["fd_pebbles", "fd_bone", "fd_sand_rock", "fd_sticks"],
    RUINS: ["fd_white_tuft", "fd_white_tuft2", "fd_white_flower", "fd_pebbles_gray"],
    MARSH: ["fd_tuft", "fd_leaves", "fd_sticks", "fd_leafy"],
    BEACH: ["fd_shell", "fd_pebbles", "fd_bone"],
}
dnoise = fbm((H, W), 9, 333)
for ty in range(1, H - 1):
    for tx in range(1, W - 1):
        if water_t[ty, tx] > 0.4 or road_t[ty, tx] > 0.3:
            continue
        b = int(biome[ty, tx])
        chance = 0.10 + dnoise[ty, tx] * 0.32
        if rng.random() < chance:
            kinds = DECOR[b]
            k = kinds[int(rng.random() ** 1.4 * len(kinds))]
            decor.append([k, round((tx + rng.random()) * TILE), round((ty + rng.random()) * TILE)])

# ---------------------------------------------------------------- actors
ENEMIES = {
    MEADOW: ["slime", "slime", "mushroom", "butterfly"],
    FOREST: ["bamboo", "owl", "spiderred", "snake2", "mushroom2"],
    DESERT: ["skull", "cyclope", "mole", "flam"],
    RUINS: ["spirit", "spirit2", "bluebat", "eye", "slime3"],
    MARSH: ["slime2", "lizard", "eye", "mole"],
    BEACH: ["slime", "lizard"],
}
safe = [LANDMARKS["hearthgrove"], LANDMARKS["moonwell"]]
enemies = []
tries = 0
while len(enemies) < 170 and tries < 40000:
    tries += 1
    tx, ty = rng.uniform(6, W - 6), rng.uniform(6, H - 10)
    if water_t[int(ty), int(tx)] > 0.3:
        continue
    if any(math.hypot(tx - s[0], ty - s[1]) < 24 for s in safe):
        continue
    if any(math.hypot(tx - s["x"] / TILE, ty - s["y"] / TILE) < 6 for s in SHRINES):
        continue
    if any(math.hypot(tx - e["x"] / TILE, ty - e["y"] / TILE) < 6 for e in enemies):
        continue
    hx, hy = int(tx * 2), int(ty * 2)
    if occupied[hy, hx]:
        continue
    b = int(biome[int(ty), int(tx)])
    pack = 1 + int(rng.random() < 0.55) + int(rng.random() < 0.25)
    species = ENEMIES[b][int(rng.random() * len(ENEMIES[b]))]
    for i in range(pack):
        enemies.append({"s": species, "x": round((tx + rng.uniform(-1.5, 1.5)) * TILE), "y": round((ty + rng.uniform(-1.5, 1.5)) * TILE)})

BOSSES = [
    {"id": "briarback", "kind": "giantbamboo", "name": "The Briarback", "x": LANDMARKS["briarback_arena"][0] * TILE, "y": LANDMARKS["briarback_arena"][1] * TILE, "region": FOREST},
    {"id": "toad", "kind": "giantfrog", "name": "The Glasswater Toad", "x": LANDMARKS["toad_arena"][0] * TILE, "y": LANDMARKS["toad_arena"][1] * TILE, "region": MARSH},
    {"id": "cyclops", "kind": "demoncyclop", "name": "The Ember Cyclops", "x": LANDMARKS["cyclops_arena"][0] * TILE, "y": LANDMARKS["cyclops_arena"][1] * TILE, "region": DESERT},
    {"id": "warden", "kind": "giantspirit", "name": "The Quiet Warden", "x": LANDMARKS["warden_arena"][0] * TILE, "y": LANDMARKS["warden_arena"][1] * TILE, "region": RUINS},
]

NPCS = [
    {"id": "alder", "sprite": "oldman", "name": "Elder Alder", "x": (vx + 2.5) * TILE, "y": (vy - 2.5) * TILE, "wander": 0},
    {"id": "mira", "sprite": "woman", "name": "Mira the Gardener", "x": (vx - 9) * TILE, "y": (vy + 2) * TILE, "wander": 24},
    {"id": "pip", "sprite": "villager2", "name": "Pip the Merchant", "x": (vx + 12) * TILE, "y": (vy + 9.8) * TILE, "wander": 0, "shop": True},
    {"id": "tallow", "sprite": "hunter", "name": "Tallow the Pathfinder", "x": (vx + 1.5) * TILE, "y": (vy - 14) * TILE, "wander": 16},
    {"id": "sora", "sprite": "monk", "name": "Brother Sora", "x": (mx + 2) * TILE, "y": (my + 8) * TILE, "wander": 12},
    {"id": "kit", "sprite": "villager3", "name": "Kit", "x": (vx - 4) * TILE, "y": (vy + 9) * TILE, "wander": 60},
    {"id": "bramble", "sprite": "villager4", "name": "Bramble", "x": (vx + 7) * TILE, "y": (vy + 3) * TILE, "wander": 48},
    {"id": "kaede", "sprite": "samurai", "name": "Kaede of the Watch", "x": (vx + 15) * TILE, "y": (vy - 2) * TILE, "wander": 10},
    {"id": "nomad", "sprite": "villager", "name": "Sela the Nomad", "x": (ox - 3) * TILE, "y": (oy + 8) * TILE, "wander": 20, "shop": True},
    {"id": "hana", "sprite": "princess", "name": "Hana", "x": 104 * TILE, "y": 104 * TILE, "wander": 30},
]
ANIMALS = [
    {"sprite": "cat", "x": (vx - 6) * TILE, "y": (vy + 3) * TILE}, {"sprite": "dog", "x": (vx + 4) * TILE, "y": (vy + 9) * TILE},
    {"sprite": "chicken", "x": (vx + 20) * TILE, "y": (vy + 8) * TILE}, {"sprite": "chicken", "x": (vx + 21) * TILE, "y": (vy + 9) * TILE},
    {"sprite": "chicken", "x": (vx + 19) * TILE, "y": (vy + 10) * TILE}, {"sprite": "cow", "x": (vx + 25) * TILE, "y": (vy + 8) * TILE},
    {"sprite": "frog", "x": 112 * TILE, "y": 106 * TILE}, {"sprite": "frog", "x": 156 * TILE, "y": 130 * TILE},
    {"sprite": "cat", "x": (ox + 2) * TILE, "y": (oy + 5) * TILE},
]

CHESTS = [
    {"id": "c_moonheart", "x": 122 * TILE, "y": 94.4 * TILE, "item": "moonheart_charm", "big": True},
    {"id": "c_bow", "x": 26 * TILE, "y": 52 * TILE, "item": "gale_bow", "big": True},
    {"id": "c_hammer", "x": 238 * TILE, "y": 100 * TILE, "item": "ironroot_hammer", "big": True},
    {"id": "c_boots", "x": 140 * TILE, "y": 160 * TILE, "item": "zephyr_boots", "big": True},
    {"id": "c_armor", "x": 232 * TILE, "y": 18 * TILE, "item": "briar_mail", "big": True},
    {"id": "c_ring", "x": 196 * TILE, "y": 162 * TILE, "item": "ember_ring", "big": True},
    {"id": "c_coins1", "x": 60 * TILE, "y": 90 * TILE, "item": "coins_25"},
    {"id": "c_coins2", "x": 100 * TILE, "y": 60 * TILE, "item": "coins_25"},
    {"id": "c_tea1", "x": 170 * TILE, "y": 100 * TILE, "item": "moontea"},
    {"id": "c_tea2", "x": 44 * TILE, "y": 150 * TILE, "item": "moontea"},
    {"id": "c_coins3", "x": 250 * TILE, "y": 60 * TILE, "item": "coins_50"},
    {"id": "c_heart", "x": 12 * TILE, "y": 110 * TILE, "item": "heart_piece"},
    {"id": "c_heart2", "x": 160 * TILE, "y": 12 * TILE, "item": "heart_piece"},
]
for c in CHESTS:
    clear_zone(c["x"] / TILE, c["y"] / TILE, 1.0)
# little bush rings that must be jumped or cut around some chests
for c in CHESTS[:6]:
    cx0, cy0 = c["x"] / TILE, c["y"] / TILE
    if c["id"] == "c_moonheart":
        continue
    for i in range(9):
        a = i / 9 * math.tau
        add_prop("bush_round", cx0 + math.cos(a) * 2.2, cy0 + 0.3 + math.sin(a) * 1.6, force=True)

world = {
    "seed": SEED, "tiles": [W, H], "tile": TILE, "field_res": FR, "biome_names": BIOME_NAMES,
    "landmarks": {k: [v[0] * TILE, v[1] * TILE] for k, v in LANDMARKS.items()},
    "start": [(vx + 0.5) * TILE, (vy + 4) * TILE],
    "shrines": SHRINES, "bosses": BOSSES, "npcs": NPCS, "animals": ANIMALS, "chests": CHESTS,
    "enemies": enemies, "props": props, "decor": decor,
}
(DATA / "world.json").write_text(json.dumps(world, separators=(",", ":")))
print(f"props {len(props)}  decor {len(decor)}  enemies {len(enemies)}")
