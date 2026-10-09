# Petalbound

A tiny landscape 2D pixel-art adventure prototype for Godot 4, inspired by the visual reference: a little white traveler, overgrown ruins, soft teal grass, drifting petals, and a quick dash.

## Play

Open `project.godot` in Godot 4.3 or newer. The project uses the Compatibility renderer and a 960×540 landscape viewport.

- **Move:** WASD / arrow keys, or the on-screen directional pad
- **Dash:** Space / Shift, or the on-screen DASH button
- **Goal:** Gather three moonseeds, then reach the glowing shrine

The on-screen controls are intentionally included for touch play. On a phone, clone or pull this repository into a folder Godot can access (for example, a folder under Documents), then open `project.godot` from Godot's project browser.

## Prototype notes

The game is an original, small first playable slice rather than a recreation of the reference video. It uses hand-drawn pixel shapes in GDScript so the repository is self-contained and has no external art downloads. The player can explore a small ruin meadow, dash, collect seeds, and reach the shrine.

## Roadmap

See [`GAME_PLAN.md`](GAME_PLAN.md) for the full proposed game vision, systems, world, and development phases. The current prototype is **Phase 0**; later features in the plan are not implemented yet.

For recurring, phase-by-phase development runs in Manus Task Scheduler, see [`AUTOMATION_PROMPT.md`](AUTOMATION_PROMPT.md).
