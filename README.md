# Petalbound

A small, offline landscape adventure prototype for Godot 4: guide Mallow through a flowered meadow of old ruins, restore its Moonseeds, and find a little light for the shrine.

## Play

Open `project.godot` in Godot 4.3 or newer. The project uses the Compatibility renderer and a 960×540 landscape viewport.

- **Move:** WASD / arrow keys or drag the floating lower-left virtual joystick
- **Attack:** J / K or the on-screen ATTACK button
- **Switch weapon:** Q or the top-right weapon button; choose Thornblade or Bloomstaff
- **Dash:** Space / Shift or the on-screen DASH button
- **Mothlight:** F or its touch button; a homing hit against a nearby enemy
- **Petalguard:** G or its touch button; the bloom blocks one incoming hit
- **Moontea:** R or its touch button; restores one heart (three carried)
- **Field kit:** I or BAG; inspect the equipped Plum Wayfarer cloak (+8% walk speed), charm, weapon, tea, and skills
- **Interact:** E or the contextual OPEN CACHE button near the old chest
- **Pause / resume:** PAUSE button or Esc / P; joystick tuning remains in the pause overlay
- **App switching:** held touch controls clear when the application loses focus
- **Goal:** gather three Moonseeds and reach the glowing shrine

The phone-first controls are large and remain usable with a keyboard in development. Pull the repository into a folder Godot can access, then open `project.godot` from Godot's project browser.

## Current prototype

The opening meadow is now built from the included **CC0 Mini Meadow** ground tiles, paths, props, and four-frame animated water. The scene adds a small cabin and bench, lantern-lit vine ruins, drifting petals, a softer teal palette shader, shrine/Moonseed glow, and a restrained vignette. Mallow remains the original white, long-eared traveler: code-drawn idle blink/ear movement, eight-way facing, walk steps, a dash trail, weapon-swing arc, and Petalguard shimmer extend the prototype rather than replacing the character with a mismatched asset.

Explore the first combat slice: six simple Thornling/Puffcap encounters, a three-strike Thornblade finisher and ranged Bloomstaff, Mothlight, Petalguard, the equipped Plum Wayfarer cloak's 8% walking-speed bonus, three Moontea charges, a Moonheart Charm cache, Petalcoin rewards, and start/defeat/retry/victory screens. The selected sword, staff, cloak, charm, and Moontea inventory icons come from a separate CC0 fantasy RPG icon pack; see [`assets/packs/ASSET_CREDITS.md`](assets/packs/ASSET_CREDITS.md) for sources and licensing decisions.

This is still a prototype: there is no persistent save, polished combo animation/hit-pause, full enemy telegraph/boss set, authored Mallow sprite sheet, or finished sound. **Real Android touch feel, notch/safe-area behavior, and sustained phone performance have not been tested in this environment.** Phase 1 remains in progress; see [`GAME_PLAN.md`](GAME_PLAN.md) and [`DEVELOPMENT_LOG.md`](DEVELOPMENT_LOG.md).

## Headless checks

Run the Godot editor import/parse scan, then the smoke tests from the repository root:

```sh
godot --headless --editor --path . --quit
for test in tests/*.gd; do godot --headless --path . -s "$test"; done
```

## Automation

For recurring, phase-by-phase development runs in Manus Task Scheduler, see [`AUTOMATION_PROMPT.md`](AUTOMATION_PROMPT.md).
