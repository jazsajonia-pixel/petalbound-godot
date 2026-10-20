# Combat VFX polish

Petalbound now adds brief, direction-aware slash accents on top of existing hit/skill effects:

- **Petal Rush:** a fast directional trail.
- **Vine Hook / Tornado Slash:** a rotating ring with short radial streaks.
- **Twin Moon Katanas:** a layered cross-cut on Moonrend Dash.
- **Direwolf Claws:** three separated claw streaks on each barrage hit.

The accents are drawn by a small Godot Node2D script rather than adding large textures or shader dependencies. They self-delete after 0.22 seconds, use the effect's skill/weapon tint, and stay compatible with the game's 640×360 Compatibility-renderer setup. Existing damage, hit detection, cooldowns and input are unchanged.

## Online asset research

These freely usable packs are candidates for a later art pass; **they were researched but are not bundled or used by this change**:

- SpritePilot combat effects (https://spritepilot.com/free-game-assets/combat) — sword/claw slashes and impact effects; page states CC0 1.0.
- OpenGameArt sword slash (https://opengameart.org/content/pixel-art-sword-slash-effect) — 64×47 sprite frames; page states CC0.
- Pixel VFX Free Sample (https://wollnie.itch.io/pixel-vfx-free-sample) — includes Godot 4 scenes and a custom license allowing use in games; review its included license before redistribution.

If sprites are imported later, preserve the original license/attribution file and inspect the actual sheet/frame order visually before slicing. See the Petalbound hand-pose lesson in the knowledge repo.
