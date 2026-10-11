# Development Log

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
