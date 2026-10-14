# Integrated weapon and gear art

These individual transparent sprites were cropped from the four-column weapon and gear atlases in `../asset_drafts/` by `tools/slice_generated_equipment.py`.

Weapon and gear inventory icons are 48×48 pixels. Nine small 16×24 held-weapon textures are supplied for the player sprite. `scripts/data/db.gd` resolves item IDs to these assets through `icon_path()` and `hand_path()`, so inventory, rewards, the weapon bar, active relic control and Mallow’s weapon hand share the generated art. The generated gear icons are selected by equipment slot; wearable body regions still use the game’s existing masked palette/look system, while charm, ring and relic remain UI equipment as on the current character rig.
