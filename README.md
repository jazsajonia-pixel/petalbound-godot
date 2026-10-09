# Petalbound

A tiny landscape 2D pixel-art adventure prototype for Godot 4, inspired by the visual reference: a little white traveler, overgrown ruins, soft teal grass, drifting petals, and a quick dash.

## Play

Open `project.godot` in Godot 4.3 or newer. The project uses the Compatibility renderer and a 960×540 landscape viewport.

- **Move:** WASD / arrow keys, or drag the on-screen virtual joystick
- **Dash:** Space / Shift, or the on-screen DASH button
- **Pause / resume:** on-screen PAUSE button, or Esc / P on a keyboard
- **Goal:** Gather three moonseeds, then reach the glowing shrine

The on-screen controls are intentionally included for touch play. On a phone, clone or pull this repository into a folder Godot can access (for example, a folder under Documents), then open `project.godot` from Godot's project browser.

## Prototype notes

The game is an original, small first playable slice rather than a recreation of the reference video. It uses hand-drawn pixel shapes in GDScript so the repository is self-contained and has no external art downloads. The player can explore a small ruin meadow, dash, collect seeds, and reach the shrine.

## Roadmap

See [`GAME_PLAN.md`](GAME_PLAN.md) for the full proposed game vision, systems, world, and development phases. The original MVP is **Phase 0**; development has started **Phase 1**, which is still in progress. Later game systems in the plan remain planned, not implemented.

For recurring, phase-by-phase development runs in Manus Task Scheduler, see [`AUTOMATION_PROMPT.md`](AUTOMATION_PROMPT.md).
