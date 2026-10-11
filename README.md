# Petalbound

An offline, landscape **open-world pixel-art action adventure** for Godot 4 (Android first, keyboard and gamepad supported). Mallow, a rose-haired wanderer in a plum cloak, sets out from the lantern village of Hearthgrove across a 4,096 × 2,816 px valley of six biomes. The goal is to win back four Moonseeds from the region guardians and wake the dimming Moonwell.

![Meadow with touch controls](docs/screenshots/meadow_touch.png)

| | |
| --- | --- |
| ![Hearthgrove at night](docs/screenshots/hearthgrove_night.png) | ![Ember Cyclops boss](docs/screenshots/boss_ember_cyclops.png) |
| ![Sunscar Dunes](docs/screenshots/sunscar_dunes.png) | ![Moonstone Ruins](docs/screenshots/moonstone_ruins.png) |

## Play

Open `project.godot` in Godot 4.3 or newer (validated on 4.7.2). The game uses the **Compatibility renderer**, a 640×360 pixel viewport (aspect expand), and sensor landscape orientation.

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Move | WASD / arrows | Left stick / D-pad | Floating joystick (lower left) |
| Sprint (uses stamina) | Shift | L2 | SPRINT button, or push the stick to its edge |
| Roll (i-frames) | Space | B | Roll button |
| Jump (hop low props, plunge attack) | C / L | Y | Jump button |
| Attack / combo / charge bow | J / K / Enter | A / X | Large weapon button |
| Swap weapon | Q / Tab | R1 | Weapon button |
| Mothlight · Petalguard · Moontea | F · G · R | L1 · R2 · – | Skill buttons |
| Talk / open / rest | E | A | Context button |
| Satchel (equip gear) · World map | I / B · M | Select | BAG · MAP |
| Pause / settings | Esc / P | Start | ❚❚ |

## What's in the world

- **Open world.** A seeded generator (`tools/generate_world.py`) builds six biomes: Petal Meadow, Hollowroot Grove, Sunscar Dunes, Moonstone Ruins, Glasswater Marsh and the southern coast. The world has roads, rivers, lakes, about 2,080 collidable props, about 9,700 decor sprites, 171 monsters in packs, 16 villagers and animals, 13 chests, 5 waystones and 4 boss arenas. Mallow can swim in deep water.
- **Mallow's movement kit.** Mallow can walk, sprint with stamina, dodge-roll with afterimages and invulnerability, and jump over low props with a landing plunge. Mallow also swims, pushes against obstacles, and plays item-get poses. Dust, ripple and footstep effects follow each move.
- **Combat.**
  - Four weapons:
    - Thornblade: 3-hit combo.
    - Bloomstaff: homing bolt.
    - Gale Bow: charge shot.
    - Ironroot Hammer: shockwave.
  - Three skills: Mothlight burst, Petalguard shield, and Moontea heal.
  - Hits have hit-stop, knockback, damage numbers, screen shake and dissolve deaths.
  - 19 monster types use five AI styles (hopper, chaser, flyer, caster, charger), each with wind-up tells.
- **Guardians.** There are four bosses: the Briarback, the Glasswater Toad, the Ember Cyclops and the Quiet Warden. Each mixes charge, leap, spread, ring, spike and teleport patterns, and each enrages at half health. Fights show a boss bar and ground telegraphs.
- **Gear and economy.**
  - Gear: Plum Wayfarer Cloak, Moonheart Charm, Briar Mail, Zephyr Boots and Ember Ring. Equipping armour or boots also changes Mallow's outfit.
  - Heart Blooms raise maximum health. Petalcoins drop from enemies and breakable pots and grass.
  - Pip in Hearthgrove and a desert nomad run shops.
- **World systems.**
  - An 8-minute day/night cycle includes lit lanterns, statues, waystones and Mallow's own lantern at night.
  - Each region has its own tint, fog, light rays and weather (petals, leaves, sand, snow, rain, fireflies).
  - The blight desaturates the world, and colour returns as Moonseeds come home.
  - Each region has its own music, plus ambient loops and a pooled SFX player.
  - Autosave every 45 s, plus saving at waystones.
- **Rendering.** Custom shaders handle the ground blend (biome palette blending, animated water with shoreline foam), foliage wind sway, sprite hit-flash and dissolve, atmosphere (fog, god-rays, vignette) and a post-process pass (soft bloom, colour grade, saturation). A low-FX quality toggle is in Settings.
- **Interface.** The HUD uses the Kenney Mini pixel font and shows:
  - Hearts, stamina, coins and tea, and the current quest.
  - A minimap, a full world map, the day clock and region banners.
  - Typewriter dialogue, the shop, the satchel and pause/settings.
  - Settings cover joystick dead zone and sensitivity, music and SFX volume, FX quality and touch-control visibility.
  - Multi-touch buttons work while the joystick is held.

## Headless checks

```sh
godot --headless --editor --path . --quit          # import + parse
for t in tests/*.gd; do godot --headless --path . -s "$t"; done
```

There are five smoke tests:
- `adventure_slice_smoke`: world, movement, combat, loot, gear, dialogue, guardians, ending, save/load and respawn.
- `player_facing_smoke`
- `virtual_joystick_smoke`
- `touch_buttons_smoke`
- `world_bounds_smoke`

Tests write to a separate `user://petalbound_test_save.json`.

To rebuild the world data, run `python3 tools/generate_world.py && python3 tools/preview_world.py`. This needs numpy, scipy and Pillow. The preview is written to `docs/world_map.png`.

**Not tested on a phone.** Real Android touch feel, notch/safe-area behaviour, thermals and sustained frame rate have not been verified in this environment.

## Credits

The art, animation, sound and music come mainly from **Ninja Adventure** by Pixel-boy & AAA (CC0). The UI font is from **Kenney Fonts** (CC0). The earlier Mini Meadow and RPG icon packs are kept as well. Full details are in [`assets/packs/ASSET_CREDITS.md`](assets/packs/ASSET_CREDITS.md).

## Automation

For phase-by-phase development runs, see [`AUTOMATION_PROMPT.md`](AUTOMATION_PROMPT.md).
