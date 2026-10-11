# Development Log

## Open-world update — 2026-10-11

**Status:** A large upgrade to an open-world action adventure, as requested. The headless checks pass. **This build has not been tested on a phone**, so the Phase 1 real-device exit check is still outstanding.

### What changed

- **Scope:** The project moves from a single meadow slice to an open-world valley. `GAME_PLAN.md` is updated to match.
- **Assets:**
  - Imported 321 files from the CC0 **Ninja Adventure** pack (Pixel-boy & AAA): characters, monsters, bosses, tilesets, items, weapons, FX, UI, music and SFX. The import is reproducible with `tools/import_ninja_adventure.py`.
  - Added the CC0 **Kenney Mini/Pixel** fonts.
  - Credits are in `assets/packs/ASSET_CREDITS.md`.
- **Character:** Mallow is now a fully animated four-direction sprite, a NinjaGreen base recoloured rose/plum by shader palette swap. It has walk, attack, jump, item-get and dead poses, and outfit recolours for armour and boots.
- **Movement:**
  - Mallow can walk, sprint (with a stamina bar), dodge-roll (i-frames and afterimages), jump (hopping low props, with a landing plunge attack), swim, and push.
  - Dust, ripples and footstep SFX follow each move.
- **Combat:**
  - Weapons: Thornblade 3-hit combo, Bloomstaff homing bolt, Gale Bow charge shot, and Ironroot Hammer shockwave.
  - Skills: Mothlight, Petalguard and Moontea.
  - Hit feel: hit-stop, knockback, damage numbers, screen shake, flash and dissolve shaders.
  - Enemies: 19 monster types across five AI styles, with wind-up tells.
  - Bosses: four guardians with telegraphed multi-pattern fights, enrage, and a boss bar.
- **World:**
  - A seeded generator builds a 256×176-tile map with six biomes, roads, rivers and lakes.
  - It places about 2,080 collidable props, about 9,700 decor sprites, 171 monsters, villages, 13 chests, 5 waystones, shops and breakables.
  - Props are batched per chunk, and off-screen monsters are deactivated.
- **Rendering:**
  - New ground shader: biome palette blend, animated water, and shoreline foam.
  - Foliage wind shader, sprite FX shader, atmosphere layer (fog, god-rays, vignette), and post-process (soft bloom, grade, saturation).
  - Day/night cycle with 2D lights, plus regional weather.
  - The blight desaturation lifts as Moonseeds return.
  - A low-FX toggle is in Settings.
- **Systems:**
  - NPC dialogue and quests, shops, satchel with tap-to-equip, minimap and world map, and region banners.
  - Region music crossfades and ambient loops.
  - Save/load (`user://petalbound_save.json`, v2), autosave, waystone respawn, and the Moonwell ending.
- **Controls:**
  - Multi-touch buttons, including sprint/jump/roll and the context button.
  - Stick-edge auto-sprint.
  - Full keyboard and gamepad mappings.
  - Orientation changed to sensor landscape (`orientation=4`).
- **Visual QA fixes:**
  - Removed the `source_color` hints that linearised the palette.
  - Fixed double vertex-colour darkening.
  - Switched bloom to a luma threshold.
  - Toned down additive FX and night-light energy.
  - Added a majority filter that removes blocky biome islands.

### Validation

- Godot 4.7.2 headless editor import/parse scan: passed.
- Smoke tests: all five passed (`adventure_slice_smoke`, `player_facing_smoke`, `virtual_joystick_smoke`, `touch_buttons_smoke`, `world_bounds_smoke`).
- A 40-second scripted soak run across every region, using all weapons and skills and saving, produced no script errors.
- Rendered title, regions, night, combat, boss, dialogue, shop, satchel and map screens under Xvfb with the OpenGL3 driver for visual review. Selected screenshots are in `docs/screenshots/`.
- Real Android touch feel, safe areas, thermals and sustained FPS: **not tested**.

### Next recommended slice

Play the build on a landscape Android phone for 5–10 minutes and check:
- Joystick and button reach.
- Text readability at 640×360.
- FPS in dense forest areas and at night with lights.
- Behaviour on app resume.

After that, tune enemy density and boss HP from that playtest, and add side quests for the villagers.

## Current phase: Phase 1 — Mobile feel and character foundation

**Status:** In progress. The Phase 1 exit check still requires a five-minute real-phone playtest; this environment cannot substitute for that.

### Completed slice — 2026-10-11

- Added a title/start menu and defeat/retry/victory screens around the existing compact offline meadow adventure.
- Replaced the flat grassy field with a TileMapLayer using the preserved CC0 Mini Meadow pack: varied ground, readable dirt and stone paths, a four-frame animated pond, and scattered flowers, bushes, rocks, logs, stumps, and mushrooms.
- Added an original hand-drawn cabin, bench, cache, lanterns, and seven mossy ruin landmarks; added collision blockers for the cabin, pond, some props, ruins, and world perimeter.
- Added a sage/teal terrain remap shader, soft screen vignette, and gentle PointLight2D pools around the shrine, Moonseeds, and cabin.
- Expanded Mallow's original code-drawn animation cues with idle blinking and ear motion, directional walk steps, a dash trail, weapon-swing arcs, staff motes, and a Petalguard shimmer. Mallow's identity remains intact; an incompatible full-character pack was reviewed but not imported.
- Added six simple Thornling/Puffcap encounter actors with approach/contact behavior, health, hit flash, and defeat drops. Thornblade has a three-swing chain with a farther, damage-2 finisher; the selectable Bloomstaff gives a short ranged strike. Added Mothlight, a one-hit Petalguard, three-charge Moontea healing, a Moonheart Charm cache that grants a heart, Petalcoin rewards, and a gather-three-seeds/reach-shrine loop.
- Added a field-kit overlay with selected sword, staff, cloak, charm, and tea icons from a verified CC0 RPG item-icon pack. The Plum Wayfarer cloak is equipped from the outset and raises walking speed by 8%; the Moonheart Charm is found in the old cache. Preserved the full source archive and added [asset/license notes](assets/packs/ASSET_CREDITS.md). A candidate VFX pack with conflicting license declarations was deliberately excluded; the current combat sparks and motes are original drawings.
- Added large mobile touch buttons for attack, dash, Mothlight, Petalguard, Moontea, contextual cache interaction, weapon cycling, bag, and pause. The floating joystick, keyboard parity, dead-zone/sensitivity tuning, safe-area layout, and focus-loss cleanup remain.
- Updated the README and roadmap. No phase is marked complete merely because the headless tests pass.

### Validation

- Godot 4.7.2 headless editor import/parse scan: passed.
- Godot 4.7.2 headless project startup (`--quit-after 180`): passed.
- Mobile-controls smoke test: passed; joystick drag/release, settings, pause/resume, and application-focus input cleanup.
- Character-facing smoke test: passed; four cardinal and four diagonal movement states.
- World-bounds smoke test: passed; movement stops at all four boundaries, isolated from intentional scenery blockers.
- Adventure-slice smoke test: passed; title/start, tiled map and animated-water data, imported icons, cloak speed bonus, three-hit finisher, attack/skill/weapon, healing/charm/guard, cache interaction, full defeat/retry state reset, and shrine victory.
- Rendered title, gameplay, and field-kit previews under a virtual display for UI/palette inspection. This is not an Android-device test.
- Actual phone touch feel, safe-area/notch behavior, app pause/resume, and sustained mobile performance: **not tested**.

### Next recommended slice

Pull this build into Godot on the target landscape Android phone and complete the Phase 1 five-minute playtest: verify stick/button separation, safe margins, weapon/field-kit text readability, scene performance, and app background/resume behavior. Then continue replacing the code-drawn Mallow with an original matching sprite sheet/animation set; further combat polish (wind-ups, knockback, cooldown feedback, and enemy tells) remains prototype work, not a completed Phase 2 gate.
