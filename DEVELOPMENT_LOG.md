# Development Log

## Current phase: Phase 1 — Mobile feel and character foundation

**Status:** In progress; Phase 1 exit check has not been met. Phone playtesting is still required.

### Completed slice

- Replaced the temporary four-button movement pad with a floating virtual joystick in the lower-left touch zone.
- Joystick motion supplies analog directional strengths to the existing movement actions; keyboard controls remain available.
- Kept the dash action on a large lower-right button and positioned HUD controls relative to the display safe area with an inset fallback.
- Set the camera to a modest 1.15× zoom for closer player framing.
- Added a safe-area-aware PAUSE button and a centered RESUME overlay; Esc/P also toggles pause on desktop, and opening pause clears joystick input.
- Added invisible collision walls around the meadow so Mallow cannot leave the playable world.
- Added original front-, back-, and side-facing code-drawn Mallow poses with a subtle alternating walk step and idle ear flick. This is still prototype drawing, not the planned authored sprite sheet.
- Updated the README to describe the joystick controls.

### Validation

- Godot 4.7.2 headless editor scan: passed without script parse errors.
- Godot 4.7.2 headless project startup (`--quit-after 180`): passed without runtime errors.
- Headless controls smoke test: passed; a simulated joystick drag moved the player, release cleared movement input, and pause/resume correctly toggled the overlay and tree state.
- World-bounds smoke test: passed; simulated movement was stopped at all four edges.
- Character-facing smoke test: passed; down, left, right, and up movement select the corresponding pose state.
- Real-device touch feel, notch/safe-area behavior, and stuck-input behavior: not tested in this environment; test after pulling in Godot Android.

### Next recommended slice

Pull the update and check the controls, camera framing, and pose readability on the target phone. Confirm touch feel and safe-area placement; then build the planned original sprite sheet/animation foundation before any combat work.
