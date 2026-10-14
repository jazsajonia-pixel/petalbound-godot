#!/usr/bin/env python3
"""Create small runtime cuts from the project's included itch.io asset sheets.

The source files and rights notes are kept under assets/packs/itch_cc0/.
This script only performs deterministic nearest-neighbor crops; it does not
create new artwork.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets/packs/itch_cc0"
OUT = PACK / "runtime"

# Shade's sheet is 24x20 cells (16px each): 16 groups, 30 designs per group.
# Category order follows the creator's published content list. Each category
# occupies a 3x10 block; the 16 categories fill 8 blocks across and 2 down.
CATEGORIES = [
    "rapier", "katana", "sword", "greatsword", "scimitar", "knife", "butcher_knife", "battle_axe",
    "battle_hammer", "spear", "staff", "trident", "mace", "scythe", "sickle", "nunchucks",
]

# item_id: (category, design index 0..29, material/color sheet)
WEAPON_CUTS = {
    "briarheart_sabre": ("scimitar", 5, "iron"),
    "moonshard_rapier": ("rapier", 17, "steel"),
    "sunforge_greatsword": ("greatsword", 3, "gold"),
    "crimsonfang_sword": ("sword", 22, "steel"),
    "frostthorn_falchion": ("scimitar", 19, "steel"),
    "duskwing_daggers": ("knife", 11, "iron"),
    "sunpetal_twinblades": ("katana", 26, "gold"),
    "aurora_crystal_staff": ("staff", 8, "steel"),
    "emberroot_staff": ("staff", 23, "gold"),
    "ember_cleaver": ("battle_axe", 4, "bronze"),
    "frostcleaver_axe": ("battle_axe", 25, "steel"),
    "starfall_maul": ("battle_hammer", 7, "gold"),
    "rootbreaker_maul": ("mace", 14, "iron"),
    "moonrise_lance": ("spear", 18, "steel"),
}

# Admurin's free 32x32 sheet is permitted for use in a game project. Only two
# bow cells are used; the original sheet is retained as part of this project.
BOW_CELLS = {"windcarved_bow": (0, 3), "moonfeather_bow": (1, 3)}

# These source-atlas crops are 16x16 cells in coins-chests-etc-2-0-noborders.png.
ITEM_CUTS = {
    "gem_sapphire": (32, 368),
    "gem_amethyst": (32, 384),
    "gem_emerald": (32, 400),
    "gem_ruby": (32, 416),
    "potion_empty": (624, 240),
    "potion_red": (640, 240),
    "potion_green": (656, 240),
    "potion_blue": (672, 240),
}


def save_cell(source: Image.Image, box: tuple[int, int, int, int], target: Path) -> None:
    cell = source.crop(box).convert("RGBA")
    if cell.getchannel("A").getbbox() is None:
        raise RuntimeError(f"Empty source cell for {target.name}: {box}")
    target.parent.mkdir(parents=True, exist_ok=True)
    cell.save(target, optimize=True)


def main() -> None:
    weapon_dir = OUT / "weapons"
    hand_dir = OUT / "weapon_hands"
    for name, (category, design, metal) in WEAPON_CUTS.items():
        category_index = CATEGORIES.index(category)
        cell_col = (category_index % 8) * 3 + (design % 3)
        cell_row = (category_index // 8) * 10 + (design // 3)
        source = Image.open(PACK / "shade" / f"{metal}-weapons.png").convert("RGBA")
        if source.size != (384, 320):
            raise RuntimeError(f"Unexpected Shade sheet size: {source.size}")
        box = (cell_col * 16, cell_row * 16, (cell_col + 1) * 16, (cell_row + 1) * 16)
        save_cell(source, box, weapon_dir / f"{name}.png")
        save_cell(source, box, hand_dir / f"{name}_hand.png")

    bow_sheet = Image.open(PACK / "admurin" / "32x32_PixelWeapons_V3.png").convert("RGBA")
    if bow_sheet.size != (448, 448):
        raise RuntimeError(f"Unexpected Admurin sheet size: {bow_sheet.size}")
    for name, (row, col) in BOW_CELLS.items():
        bow = bow_sheet.crop((col * 32, row * 32, (col + 1) * 32, (row + 1) * 32))
        if bow.getchannel("A").getbbox() is None:
            raise RuntimeError(f"Empty Admurin bow cell for {name}")
        weapon_dir.mkdir(parents=True, exist_ok=True)
        bow.save(weapon_dir / f"{name}.png", optimize=True)
        hand_dir.mkdir(parents=True, exist_ok=True)
        bow.resize((16, 16), Image.Resampling.NEAREST).save(hand_dir / f"{name}_hand.png", optimize=True)

    atlas_path = PACK / "greatdocbrown" / "coins-chests-etc-2-0-noborders.png"
    atlas = Image.open(atlas_path).convert("RGBA")
    if atlas.size != (912, 1040):
        raise RuntimeError(f"Unexpected greatdocbrown atlas size: {atlas.size}")
    item_dir = OUT / "items"
    for name, (x, y) in ITEM_CUTS.items():
        save_cell(atlas, (x, y, x + 16, y + 16), item_dir / f"{name}.png")

    print(f"Imported {len(WEAPON_CUTS) + len(BOW_CELLS)} weapon variants and {len(ITEM_CUTS)} item icons into {OUT}")


if __name__ == "__main__":
    main()
