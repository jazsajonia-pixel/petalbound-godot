#!/usr/bin/env python3
"""Slice the generated weapon/gear concept atlases into game-sized transparent assets."""
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
DRAFTS = ROOT / "assets/generated/petalbound/asset_drafts"
OUT = ROOT / "assets/generated/petalbound/equipment"

WEAPONS = [
    "katana", "twin_katanas", "spear",
    "hammer", "staff", "bow",
    "axe", "whip", "gauntlet",
]
GEAR = [
    "head", "armor", "cloak",
    "arms", "legs", "boots",
    "charm", "ring", "relic",
]
WEAPON_VARIANTS = [
    "briarheart_sabre", "moonshard_rapier", "sunforge_greatsword", "crimsonfang_sword",
    "frostthorn_falchion", "duskwing_daggers", "sunpetal_twinblades", "aurora_crystal_staff",
    "emberroot_staff", "windcarved_bow", "moonfeather_bow", "ember_cleaver",
    "frostcleaver_axe", "starfall_maul", "rootbreaker_maul", "moonrise_lance",
]
GEAR_VARIANTS = [
    "acornleaf_cap", "fernwarden_cuirass", "rosebriar_bracers", "starweave_wraps",
    "mossrunner_trousers", "cloudstep_leggings", "glasswing_boots", "emberwalker_boots",
    "aurora_petal_cape", "moonstone_charm", "amberloop_ring", "duskglass_ring",
    "wispflame_relic", "emberheart_charm", "moonfall_diadem", "rootguard_mantle",
]


def slice_cells(sheet_name: str, names: list[str], grid: int, output_dir: Path, hand_sprites: bool = False) -> None:
    sheet = Image.open(DRAFTS / sheet_name).convert("RGBA")
    cell_w, cell_h = sheet.width // grid, sheet.height // grid
    output_dir.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(names):
        col, row = index % grid, index // grid
        cell = sheet.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
        alpha = cell.getchannel("A").point(lambda value: 255 if value > 8 else 0)
        bounds = alpha.getbbox()
        if not bounds:
            raise RuntimeError(f"No visible sprite found in {sheet_name}, cell {index}")
        sprite = cell.crop(bounds)
        pad = max(4, round(max(sprite.size) * 0.035))
        padded = Image.new("RGBA", (sprite.width + 2 * pad, sprite.height + 2 * pad), (0, 0, 0, 0))
        padded.alpha_composite(sprite, (pad, pad))
        max_size = (11, 18) if hand_sprites else (44, 44)
        ratio = min(max_size[0] / padded.width, max_size[1] / padded.height)
        size = (max(1, round(padded.width * ratio)), max(1, round(padded.height * ratio)))
        art = padded.resize(size, Image.Resampling.LANCZOS)
        canvas_size = (16, 24) if hand_sprites else (48, 48)
        canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
        canvas.alpha_composite(art, ((canvas.width - art.width) // 2, (canvas.height - art.height) // 2))
        canvas.save(output_dir / f"{name}.png", optimize=True)


slice_cells("weapons_sheet.png", WEAPONS, 3, OUT / "weapons")
slice_cells("weapons_sheet.png", WEAPONS, 3, OUT / "weapon_hands", hand_sprites=True)
slice_cells("gear_sheet.png", GEAR, 3, OUT / "gear")
slice_cells("weapon_variants_sheet.png", WEAPON_VARIANTS, 4, OUT / "weapon_variants")
slice_cells("weapon_variants_sheet.png", WEAPON_VARIANTS, 4, OUT / "weapon_hands_variants", hand_sprites=True)
slice_cells("gear_variants_sheet.png", GEAR_VARIANTS, 4, OUT / "gear_variants")
print(f"Sliced 9 base weapons, {len(WEAPON_VARIANTS)} weapon variants and {len(GEAR_VARIANTS)} gear variants into {OUT}")
