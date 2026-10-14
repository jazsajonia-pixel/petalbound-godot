# Petalbound equipment art

The item sprites are separate transparent PNGs cut reproducibly from the generated source atlases in `../asset_drafts/` using `tools/slice_generated_equipment.py`.

## Existing base equipment

The base pack contains 9 weapon icons (48×48), 9 held-weapon sprites (16×24), and 9 equipment-slot icons (48×48).

## Named variants

A second pair of 4×4 atlases adds **16 named weapon variants** and **16 gear variants**. Each weapon has its own 48×48 inventory icon and 16×24 held sprite; each gear piece has its own 48×48 icon. The weapon set includes four distinct swords, paired blades, two staffs, two bows, two axes, two hammers, and a long-reach lance. Gear includes unique silhouettes for all nine slots, with additional head, arm, leg, boot, cloak, ring and charm options.

`DB.icon_path()` and `DB.hand_path()` resolve each new item ID to its dedicated image. The equipment database gives items distinct names, rarities and stats; weapon attack patterns and their ranges, cadence and elements are registered in `scripts/data/combat_data.gd`. Held-weapon stat bonuses refresh when the player switches weapons. Wearable body regions continue to use the game's paper-doll palette layers; accessory art is shown in the equipment UI as on the current character rig.
