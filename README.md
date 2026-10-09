# Petalbound

A tiny landscape 2D pixel-art adventure prototype for Godot 4, inspired by the visual reference: a little white traveler, overgrown ruins, soft teal grass, drifting petals, and a quick dash.

## Play

Open `project.godot` in Godot 4.3 or newer. The project uses the Compatibility renderer and a 960×540 landscape viewport.

- **Move:** WASD / arrow keys, or drag the on-screen virtual joystick
- **Dash:** Space / Shift, or the on-screen DASH button
- **Pause / resume:** on-screen PAUSE button, or Esc / P on a keyboard
- **Joystick tuning:** adjust dead zone and sensitivity from the pause overlay; changes apply immediately
- **Goal:** Gather three moonseeds, then reach the glowing shrine

The on-screen controls are intentionally included for touch play. On a phone, clone or pull this repository into a folder Godot can access (for example, a folder under Documents), then open `project.godot` from Godot's project browser.

## Prototype notes

The game is an original, small first playable slice rather than a recreation of the reference video. The currently rendered world and Mallow are still drawn from GDScript. A separate [Mini Meadow CC0 source pack](assets/packs/mini_meadow/) has been added for a future tileset/style test; it is not yet used by the game scene. The player can explore a small ruin meadow, dash, collect seeds, and reach the shrine.

## Roadmap

See [`GAME_PLAN.md`](GAME_PLAN.md) for the full proposed game vision, systems, world, and development phases. The original MVP is **Phase 0**; development has started **Phase 1**, which is still in progress. Later game systems in the plan remain planned, not implemented.

For recurring, phase-by-phase development runs in Manus Task Scheduler, see [`AUTOMATION_PROMPT.md`](AUTOMATION_PROMPT.md).
