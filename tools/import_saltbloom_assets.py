#!/usr/bin/env python3
"""Additively import the Ninja Adventure (CC0) files used by Saltbloom Shoals.

Usage:
    python3 tools/import_saltbloom_assets.py "/path/to/Ninja Adventure - Asset Pack"

Unlike tools/import_ninja_adventure.py this does NOT wipe assets/packs/ninja_adventure
or regenerate props.json: it only copies the coast-region files below and merges
their prop entries (whole-image rects) into assets/data/props.json.
Pack: https://pixel-boy.itch.io/ninja-adventure-asset-pack (CC0 1.0).
"""
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets" / "packs" / "ninja_adventure"
PROPS_JSON = ROOT / "assets" / "data" / "props.json"

COPY = {
    # coast monsters (4x4 sheets of 16px frames, same layout as the existing monsters)
    "Actor/Monster/AxolotBlue/SpriteSheet.png": "monsters/axolotblue.png",
    "Actor/Monster/AxolotBlue/Faceset.png": "monsters/axolotblue_face.png",
    "Actor/Monster/KappaGreen/SpriteSheet.png": "monsters/kappagreen.png",
    "Actor/Monster/KappaGreen/Faceset.png": "monsters/kappagreen_face.png",
    "Actor/Monster/Octopus/SpriteSheet.png": "monsters/octopus.png",
    "Actor/Monster/Octopus/Faceset.png": "monsters/octopus_face.png",
    "Actor/Monster/Mollusc/Mollusc.png": "monsters/mollusc.png",
    "Actor/Monster/Mollusc/Faceset.png": "monsters/mollusc_face.png",
    # side guardian: the Brinehorn (76x79 frames)
    "Actor/Boss/SquidRed/Idle.png": "bosses/squidred/idle.png",
    "Actor/Boss/SquidRed/Walk.png": "bosses/squidred/walk.png",
    "Actor/Boss/SquidRed/Attack.png": "bosses/squidred/attack.png",
    "Actor/Boss/SquidRed/Shoot.png": "bosses/squidred/shoot.png",
    "Actor/Boss/SquidRed/Hit.png": "bosses/squidred/hit.png",
    "Actor/Boss/SquidRed/Faceset.png": "bosses/squidred/faceset.png",
    # Brinewick's netmender
    "Actor/Character/OldMan3/SeparateAnim/Walk.png": "npcs/oldman3/walk.png",
    "Actor/Character/OldMan3/SeparateAnim/Idle.png": "npcs/oldman3/idle.png",
    "Actor/Character/OldMan3/Faceset.png": "npcs/oldman3/faceset.png",
    # harbour props
    "Backgrounds/Vehicles/Boat.png": "tilesets/boat.png",
    "Backgrounds/Vehicles/FishNet.png": "tilesets/fishnet.png",
    "Backgrounds/Vehicles/FishNetFull.png": "tilesets/fishnet_full.png",
    "Backgrounds/Vehicles/Sail.png": "tilesets/sail.png",
    # region music
    "Audio/Musics/18 - Aquatic.ogg": "audio/music/coast.ogg",
}

# prop name -> sheet (whole image is the prop)
PROPS = {"boat": "boat", "fishnet": "fishnet", "fishnet_full": "fishnet_full", "sail": "sail"}


def main():
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/tmp/na_full/Ninja Adventure - Asset Pack")
    for s, d in COPY.items():
        sp = src / s
        if not sp.exists():
            raise SystemExit(f"missing in pack: {s}")
        dp = DEST / d
        dp.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(sp, dp)
    props = json.loads(PROPS_JSON.read_text())
    for name, sheet in PROPS.items():
        bbox = Image.open(DEST / "tilesets" / f"{sheet}.png").convert("RGBA").getchannel("A").getbbox()
        props[name] = {"sheet": sheet, "rect": [bbox[0], bbox[1], bbox[2] - bbox[0], bbox[3] - bbox[1]]}
    PROPS_JSON.write_text(json.dumps(props, separators=(",", ":")))
    print(f"copied {len(COPY)} files, merged {len(PROPS)} props")


if __name__ == "__main__":
    main()
