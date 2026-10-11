#!/usr/bin/env python3
"""Import the curated Ninja Adventure (CC0) subset used by Petalbound.

Usage:
    python3 tools/import_ninja_adventure.py "/path/to/Ninja Adventure - Asset Pack"

The full pack is available free from https://pixel-boy.itch.io/ninja-adventure-asset-pack
(CC0 1.0). This script copies only the files the game uses into
assets/packs/ninja_adventure/ with clean snake_case paths and regenerates
assets/data/props.json (tight pixel rects for world props cut from the tilesets).
"""
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets" / "packs" / "ninja_adventure"
DATA = ROOT / "assets" / "data"

COPY = {
    # license + docs
    "LICENSE.txt": "LICENSE.txt",
    "README.md": "PACK_README.md",
    # hero
    **{f"Actor/CharacterAnimated/NinjaGreen/Separate/{n}.png": f"hero/{n.lower()}.png"
       for n in ["Idle", "Walk", "Attack", "Roll", "Jump", "Swim", "Hit", "Dead", "Item", "Pickup", "Push"]},
    "Actor/Character/NinjaGreen/Faceset.png": "hero/faceset.png",
    # tilesets
    **{f"Backgrounds/Tilesets/{n}.png": f"tilesets/{n.replace('Tileset', '').lower()}.png"
       for n in ["TilesetFloor", "TilesetWater", "TilesetNature", "TilesetHouse", "TilesetElement", "TilesetDesert"]},
    "Backgrounds/Tilesets/TilesetFloorDetail.png": "tilesets/floor_detail.png",
    "Backgrounds/Animated/Water Ripples/SpriteSheet16x16.png": "tilesets/water_ripples.png",
    "Backgrounds/Animated/Flower/SpriteSheet16x16.png": "tilesets/flower_anim.png",
    # fx sheets
    "FX/Attack/SlashCurved/SpriteSheet.png": "fx/slash_curved.png",
    "FX/Attack/SlashDoubleCurved/SpriteSheet.png": "fx/slash_double.png",
    "FX/Attack/CircularSlash/SpriteSheet.png": "fx/slash_circular.png",
    "FX/Attack/CutX/SpriteSheet.png": "fx/cut_x.png",
    "FX/Attack/Claw/SpriteSheet.png": "fx/claw.png",
    "FX/Elemental/Explosion/SpriteSheet.png": "fx/explosion.png",
    "FX/Elemental/Thunder/SpriteSheet.png": "fx/thunder.png",
    "FX/Elemental/Ice/SpriteSheet.png": "fx/ice.png",
    "FX/Smoke/Smoke/SpriteSheet.png": "fx/smoke.png",
    "FX/Magic/Circle/SpriteSheetWhite.png": "fx/magic_circle.png",
    "FX/Magic/Circle/SpriteSheetSpark2.png": "fx/spark_circle.png",
    "FX/Magic/Spirit/SpriteSheetBlue.png": "fx/spirit_blue.png",
    "FX/Magic/Shield/SpriteSheetYellow.png": "fx/shield.png",
    "FX/Magic/Aura/SpriteSheet.png": "fx/aura.png",
    "FX/Magic/Spark/SpriteSheet.png": "fx/magic_spark.png",
    "FX/Environment/Fog.png": "fx/fog.png",
    "FX/Environment/Raylight.png": "fx/raylight.png",
    "FX/Particle/Leaf.png": "fx/p_leaf.png",
    "FX/Particle/LeafPink.png": "fx/p_leaf_pink.png",
    "FX/Particle/Grass.png": "fx/p_grass.png",
    "FX/Particle/Spark.png": "fx/p_spark.png",
    "FX/Particle/Snow.png": "fx/p_snow.png",
    "FX/Particle/Rain.png": "fx/p_rain.png",
    "FX/Particle/RainOnFloor.png": "fx/p_rain_floor.png",
    "FX/Particle/Rock.png": "fx/p_rock.png",
    "FX/Particle/Wood.png": "fx/p_wood.png",
    "FX/Particle/Fire.png": "fx/p_fire.png",
    "FX/Particle/Clouds.png": "fx/p_clouds.png",
    "FX/Projectile/Arrow.png": "fx/arrow.png",
    "FX/Projectile/EnergyBall.png": "fx/energy_ball.png",
    "FX/Projectile/BigEnergyBall.png": "fx/big_energy_ball.png",
    "FX/Projectile/Fireball.png": "fx/fireball.png",
    "FX/Projectile/IceSpike.png": "fx/ice_spike.png",
    "FX/Projectile/PlantSpike.png": "fx/plant_spike.png",
    "FX/Projectile/SpriteSheetRock.png": "fx/rock_ball.png",
    # ui
    "Ui/Font/NormalFont.ttf": "ui/normal_font.ttf",
    "Ui/Dialog/DialogBoxFaceset.png": "ui/dialog_faceset.png",
    "Ui/Dialog/DialogBox.png": "ui/dialog.png",
    "Ui/Receptacle/Heart.png": "ui/heart.png",
    "Ui/Receptacle/LifeBarMiniProgress.png": "ui/lifebar_mini_progress.png",
    "Ui/Receptacle/LifeBarMiniUnder.png": "ui/lifebar_mini_under.png",
    **{f"Ui/Theme/Theme Wood/{n}.png": f"ui/theme/{n}.png" for n in [
        "nine_path_panel", "nine_path_panel_2", "nine_path_panel_3", "nine_path_bg", "nine_path_bg_2",
        "nine_path_focus", "nine_path_panel_interior", "button_normal", "button_hover", "button_pressed",
        "button_disabled", "inventory_cell", "tab_selected", "tab_unselected"]},
    **{f"Ui/Emote/emote{i}.png": f"ui/emote/emote{i}.png" for i in range(1, 31)},
    **{f"Ui/Skill Icon/Items & Weapon/{n}.png": f"ui/skill/{n.lower()}.png"
       for n in ["Amulet", "Armor", "Boot", "Ring", "Helmet", "Guard", "Scroll", "Money", "Arrow"]},
    **{f"Ui/Skill Icon/Job & Action/{n}.png": f"ui/skill/{n.lower()}.png"
       for n in ["Interact", "Talk", "Potion", "Punch"]},
    # items
    **{f"Items/Weapons/{w}/Sprite.png": f"items/weapons/{w.lower()}.png"
       for w in ["Katana", "BigSword", "Lance", "Hammer", "Bow", "MagicWand", "Axe", "Sai"]},
    **{f"Items/Weapons/{w}/SpriteInHand.png": f"items/weapons/{w.lower()}_hand.png"
       for w in ["Katana", "BigSword", "Lance", "Hammer", "MagicWand", "Axe", "Sai"]},
    "Items/Weapons/Bow/Arrow.png": "items/weapons/bow_arrow.png",
    **{f"Items/Potion/{n}.png": f"items/{n.lower()}.png" for n in ["LifePot", "MilkPot", "WaterPot", "Heart", "Medipack"]},
    **{f"Items/Food/{n}.png": f"items/{n.lower()}.png" for n in ["Onigiri", "Sushi", "Meat", "Fish", "Honey", "TeaLeaf", "SeedLarge", "SeedLargeWhite", "SeedBig1", "Nut"]},
    **{f"Items/Treasure/{n}.png": f"items/{n.lower()}.png" for n in ["Coin2", "GoldCoin", "SilverCoin", "GoldKey", "BigTreasureChest", "LittleTreasureChest", "GoldCup"]},
    **{f"Items/Resource/{n}.png": f"items/{n.lower()}.png" for n in ["GemGreen", "GemPurple", "GemRed", "GemYellow", "Branch", "feather", "Rock", "BarIron", "BarGold"]},
    **{f"Items/Object/{n}.png": f"items/{n.lower()}.png" for n in ["Bag", "Book", "MoneyBag", "Gourd", "Hourglass"]},
    # audio
    **{f"Audio/Sounds/{p}.wav": f"audio/sfx/{p.split('/')[-1].lower()}.wav" for p in [
        "Whoosh & Slash/Slash", "Whoosh & Slash/Slash2", "Whoosh & Slash/Slash3", "Whoosh & Slash/Slash5", "Whoosh & Slash/Launch",
        "Hit & Impact/Hit1", "Hit & Impact/Hit2", "Hit & Impact/Hit5", "Hit & Impact/Impact", "Hit & Impact/Impact3",
        "Jump & Bounce/Jump", "Jump & Bounce/Jump2", "Jump & Bounce/Bounce",
        "Bonus/Coin", "Bonus/Coin2", "Bonus/PowerUp1", "Bonus/Bonus", "Bonus/Gold1",
        "Magic & Skill/Magic1", "Magic & Skill/Magic3", "Magic & Skill/Heal", "Magic & Skill/Spirit", "Magic & Skill/Fx",
        "Elemental/Explosion", "Elemental/Water1", "Elemental/Water5", "Elemental/Grass", "Elemental/Fireball", "Elemental/Bubble",
        "Menu/Accept", "Menu/Accept3", "Menu/Cancel", "Menu/Move1", "Menu/Menu5",
        "Voice/Voice1", "Voice/Voice3", "Voice/Voice5",
        "Ambient/Rain", "Ambient/Wind", "Ambient/River", "Creature/Bird",
        "Alert/Alert2"]},
    **{f"Audio/Jingles/{n}.wav": f"audio/jingles/{n.lower()}.wav" for n in ["LevelUp1", "Success1", "Secret2", "GameOver", "Success3"]},
    "Audio/Musics/1 - Adventure Begin.ogg": "audio/music/title.ogg",
    "Audio/Musics/33 - Calm Village.ogg": "audio/music/village.ogg",
    "Audio/Musics/5 - Peaceful.ogg": "audio/music/meadow.ogg",
    "Audio/Musics/11 - Clearing.ogg": "audio/music/forest.ogg",
    "Audio/Musics/30 - Ruins.ogg": "audio/music/desert.ogg",
    "Audio/Musics/13 - Mystical.ogg": "audio/music/snow.ogg",
    "Audio/Musics/17 - Fight.ogg": "audio/music/boss.ogg",
    "Audio/Musics/9 - Quiet.ogg": "audio/music/night.ogg",
    "Audio/Musics/8 - End Theme.ogg": "audio/music/ending.ogg",
}

MONSTERS = ["Slime", "Slime2", "Mushroom", "Butterfly", "Bamboo", "Owl", "SpiderRed", "Snake2", "Mushroom2",
            "Lizard", "Skull", "Cyclope", "Mole", "Spirit", "Eye", "BlueBat", "Slime3", "Spirit2", "Flam"]
BOSSES = {"GiantFrog": ["Idle40x40", "Jump", "Charge", "Attack", "Hit"],
          "GiantBamboo": ["Idle", "Walk", "Attack", "Charge", "Hit"],
          "DemonCyclop": ["Idle", "Walk", "Hit"],
          "GiantSpirit": ["Idle", "Hit"]}
NPCS = ["Villager", "Villager2", "Villager3", "Villager4", "OldMan", "Woman", "Hunter", "Monk", "Princess", "Samurai"]
ANIMALS = {"Cat": "SpriteSheet", "Dog": "SpriteSheet", "Chicken": "SpriteSheetWhite", "Cow": "SpriteSheetWhite", "Frog": "SpriteSheet"}

# Prop catalogue: tileset -> name -> tile rect (x, y, w, h) in 16px tiles. Tight pixel bounds are computed.
PROPS = {
    "nature": {
        "tree_green": [0, 0, 2, 2], "tree_pine": [2, 0, 2, 2], "tree_dead": [4, 0, 2, 2], "tree_jungle": [6, 0, 2, 2],
        "tree_snowpine": [8, 0, 2, 2], "tree_snowpine2": [10, 0, 2, 2], "tree_white": [12, 0, 2, 2],
        "tree_pink": [14, 0, 2, 2], "tree_lime": [16, 0, 2, 2], "tree_lime2": [18, 0, 2, 2],
        "grove_pine": [0, 2, 4, 3], "grove_green": [4, 2, 4, 3], "grove_white": [8, 2, 4, 3], "grove_pink": [12, 2, 4, 3],
        "grove_lime": [16, 2, 4, 3], "grove_dead": [0, 5, 4, 3], "grove_snow": [4, 5, 4, 3], "grove_snow2": [8, 5, 4, 3],
        "rocks_brown": [12, 5, 4, 3], "rocks_gray": [16, 5, 4, 3],
        "big_pink": [0, 18, 3, 3], "big_green": [3, 18, 3, 3], "big_white": [6, 18, 3, 3], "big_orange": [9, 18, 3, 3],
        "stump_dark": [0, 8, 2, 2], "stump": [2, 8, 2, 2], "small_tree": [6, 8, 2, 2],
        "boulder_brown": [13, 8, 2, 2], "boulder_gray": [16, 8, 2, 2], "boulder_teal": [0, 12, 2, 2], "boulder_snow": [2, 12, 2, 2],
        "pebble_brown": [15, 9, 1, 1], "pebble_gray": [18, 9, 1, 1], "bamboo": [11, 8, 1, 3],
        "bush_round": [10, 8, 1, 1], "bush_round2": [10, 9, 1, 1], "log": [5, 8, 1, 1], "stub": [4, 8, 1, 1],
        "cliff_rock_big": [17, 10, 4, 3], "cliff_rock_gray": [17, 14, 4, 3],
        "tall_rock": [21, 10, 2, 3], "tall_rock_gray": [21, 14, 2, 3], "rock_gray_small": [15, 14, 2, 2], "rock_small": [15, 12, 2, 2],
    },
    "house": {
        "house_orange": [0, 0, 4, 3], "house_tan": [4, 0, 4, 3], "house_orange2": [8, 0, 4, 3], "house_red": [12, 0, 4, 3],
        "shop": [16, 0, 4, 3], "house_round": [23, 0, 3, 3], "house_wood": [26, 0, 3, 3],
        "torii": [0, 4, 2, 3], "hut_straw": [3, 8, 3, 2], "igloo": [0, 11, 4, 3],
        "statue_eye": [1, 15, 2, 3], "statue_monk": [3, 15, 2, 2], "statue_frog": [3, 17, 2, 2],
        "pillar": [0, 15, 1, 3], "arch": [29, 19, 4, 4], "barn": [25, 7, 4, 6],
        "stone_lantern": [29, 13, 2, 2], "oven": [31, 13, 2, 2],
    },
    "element": {
        "barrel": [0, 0, 1, 1], "pot": [1, 0, 1, 1], "pot_red": [3, 0, 1, 1], "crate": [0, 2, 1, 1],
        "chest": [3, 1, 1, 1], "sign": [11, 1, 1, 1], "grave": [5, 2, 1, 1], "cross": [3, 2, 1, 1],
        "haystack": [12, 4, 1, 2], "mailbox": [6, 3, 1, 2], "bench": [11, 1, 3, 1], "plant_pot": [0, 8, 1, 2],
    },
    "desert": {
        "dome_house": [0, 0, 3, 3], "dome_tower": [3, 0, 3, 5], "palm_grove": [10, 4, 4, 3], "palm_grove2": [10, 7, 4, 3],
        "palm": [12, 10, 2, 2], "lion_fountain": [0, 6, 2, 3], "desert_house": [6, 0, 4, 3],
        "bones": [16, 10, 1, 1], "skull_bone": [17, 11, 1, 1], "stall_red": [2, 10, 2, 2], "shrub_dry": [8, 9, 1, 1],
        "pot_desert": [6, 11, 1, 1], "oasis": [17, 7, 3, 3],
    },
}


PIXEL_OVERRIDES = {"torii": [7, 82, 34, 29], "shop": [256, 0, 49, 48]}

LARGEST_ONLY = {"shop", "torii", "igloo", "thin_tree", "cliff_rock", "dome_house", "house_round", "house_wood",
                "statue_monk", "statue_eye", "palm", "stone_lantern", "oven", "tree_jungle"}


def tight_rect(img: Image.Image, rect, largest=False):
    x, y, w, h = rect
    px = np.array(img.crop((x * 16, y * 16, (x + w) * 16, (y + h) * 16)).convert("RGBA"))[:, :, 3] > 0
    if largest:
        from scipy import ndimage
        lab, n = ndimage.label(px, structure=np.ones((3, 3)))
        if n > 1:
            sizes = ndimage.sum(px, lab, range(1, n + 1))
            px = lab == (int(np.argmax(sizes)) + 1)
    ys, xs = np.nonzero(px)
    if len(xs) == 0:
        return [x * 16, y * 16, w * 16, h * 16]
    return [int(x * 16 + xs.min()), int(y * 16 + ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)]


def main():
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/tmp/nf/Ninja Adventure - Asset Pack")
    if DEST.exists():
        shutil.rmtree(DEST)
    copies = dict(COPY)
    for m in MONSTERS:
        sheet = next((p for p in (src / "Actor/Monster" / m).glob("*.png") if "Faceset" not in p.name), None)
        copies[str(sheet.relative_to(src))] = f"monsters/{m.lower()}.png"
        copies[f"Actor/Monster/{m}/Faceset.png"] = f"monsters/{m.lower()}_face.png"
    for b, anims in BOSSES.items():
        for a in anims:
            copies[f"Actor/Boss/{b}/{a}.png"] = f"bosses/{b.lower()}/{a.lower().replace('40x40', '')}.png"
        copies[f"Actor/Boss/{b}/Faceset.png"] = f"bosses/{b.lower()}/faceset.png"
    for n in NPCS:
        for a in ["Walk", "Idle"]:
            copies[f"Actor/Character/{n}/SeparateAnim/{a}.png"] = f"npcs/{n.lower()}/{a.lower()}.png"
        copies[f"Actor/Character/{n}/Faceset.png"] = f"npcs/{n.lower()}/faceset.png"
    for a, s in ANIMALS.items():
        copies[f"Actor/Animal/{a}/{s}.png"] = f"animals/{a.lower()}.png"
    missing = []
    for s, d in copies.items():
        sp = src / s
        if not sp.exists():
            missing.append(s)
            continue
        dp = DEST / d
        dp.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(sp, dp)
    props = {}
    for sheet, items in PROPS.items():
        img = Image.open(DEST / "tilesets" / f"{sheet}.png")
        for name, rect in items.items():
            props[name] = {"sheet": sheet, "rect": PIXEL_OVERRIDES.get(name) or tight_rect(img, rect, name in LARGEST_ONLY)}
    DATA.mkdir(parents=True, exist_ok=True)
    (DATA / "props.json").write_text(json.dumps(props, indent=1))
    print(f"copied {len(copies) - len(missing)} files, {len(props)} props")
    if missing:
        print("missing:", *missing, sep="\n  ")


if __name__ == "__main__":
    main()
