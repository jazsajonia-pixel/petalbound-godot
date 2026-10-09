# Petalbound — Full Game Plan

**Status:** Proposed design and development roadmap  
**Platform:** Godot 4, Android first, landscape, single-player and playable offline  
**Genre:** Top-down pixel-art action adventure with light exploration, combat, quests, and upgrades  
**Scope target:** A compact, polished adventure that can be built in small playable steps—not an open-world or live-service game.

> **How to read this plan:** Phase 0 describes what is already in the repository. Later phases are the proposed full game. Anything not yet built is a design target, not a current feature.

## 1. The game in one paragraph

You play **Mallow**, a small white, long-eared wanderer in a plum cloak. A quiet blight is draining the **Moonwell**, the source of the meadow's soft light. Travel from a safe village into four overgrown regions, help their inhabitants, recover Moonseeds, and confront the creatures guarding each region. Explore in short sessions, fight with responsive close-range and ranged weapons, use a few readable skills, and restore the Moonwell one region at a time.

The adventure should feel gentle and inviting while still giving combat clear impact. The world is wistful, not grim; danger comes from tangled plants, restless ruins, and creatures whose homes have been disturbed.

## 2. Design pillars

1. **Comfortable on a phone.** Landscape layout, large touch targets, thumb-friendly controls, short encounters, readable HUD, and no tiny precision inputs.
2. **A small world with character.** Each region has a memorable color, landmark, local problem, and boss. Prefer hand-authored spaces to endless procedural maps.
3. **Combat you can read.** Enemies telegraph their attacks; the player has a dependable dodge/dash; hits have clear sound, animation, and particles.
4. **Progress through discovery.** Weapons and skills change how encounters feel. Upgrades are understandable and modest; avoid a grinding loot treadmill.
5. **Warm, handmade presentation.** Limited-palette pixel art, restrained animation, soft weather, and expressive character silhouettes carry the mood.

## 3. Core play loop

1. Start at the **Hearthgrove** village hub; talk to a character or choose an unlocked region.
2. Explore paths, clear small enemy groups, find Moonseeds, caches, shortcuts, and quest objects.
3. Fight the region's guardian and restore its shrine.
4. Return to Hearthgrove with Petalcoins and crafting materials.
5. Upgrade a weapon, craft a small supply, open a new route, or hear how the village changes.
6. Repeat in the next region; after all four shrines are restored, enter the Moonwell finale.

A region should take about **15–25 minutes** on a first run, with optional caches and quests adding replay time. The full main path is planned at roughly **2–3 hours**, adjustable after playtesting.

## 4. Player, controls, and combat

### Mallow

- Small, round, white creature with long ears; dark plum travel cloak and a tiny satchel.
- Silhouette stays readable at phone scale: pale head, dark torso, warm-pink inner ears, two strong eye pixels.
- Personality is communicated through idle ear flicks, cautious looks, happy seed reactions, and a determined combat pose. Dialogue is short and mostly optional.
- Mallow is not voiced in the first release; use small text boxes, expressive portraits, and a few chirps.

### Landscape touch layout

- **Left thumb:** floating/anchored virtual joystick with an inner dead zone and eight-direction movement. The existing Phase 0 directional pad is temporary and is replaced in Phase 1.
- **Right thumb:** large **Attack** button; **Dash** button below or beside it; up to two smaller **Skill** buttons; a **Use Item** button only when a consumable is equipped.
- **Interact** appears contextually near a chest, NPC, shrine, or door. It should not occupy a permanent combat button.
- Buttons stay inside safe margins and can be moved/resized in a simple layout setting. Joystick and action buttons must not block each other.
- Desktop keyboard/gamepad mappings remain for development and accessibility; mobile is the primary design target.

### Combat feel

- **Basic attack:** weapon-specific combo, normally a quick three-hit chain. Movement can be reduced but not fully locked during the first two strikes. The final strike has a little more reach and hit pause.
- **Soft targeting:** attacks gently face the nearest threat in the player's forward half-plane. No mandatory lock-on or tiny aiming stick. Ranged weapons may use an optional right-side aim drag later if tests show it is needed.
- **Dash:** brief invulnerable window near the middle of the dash, then a short cooldown. Clear cooldown feedback; no stamina cost. Dash direction follows the joystick, or the last facing direction if the stick is neutral.
- **Health:** five small heart pips as a starting tuning target. Taking a hit grants brief invulnerability and a knockback response. Balance enemy damage so multiple mistakes are survivable.
- **Skills:** skills use cooldowns or a small Bloom meter earned by landing attacks and successful dodges. No skill-tree spreadsheet or large mana pool.
- **Combat readability:** attack wind-up, danger flash, hit spark, damage reaction, and boss attack warning are distinct. Screen shake is subtle and can be disabled.

### Weapons

Three weapons are the planned launch set. Each has a distinct range and rhythm; do not build a large random weapon drop system.

- **Thornblade — starting weapon:** quick close-range three-hit combo. Reliable and easy to learn. Upgrade path improves reach slightly and adds a petal finisher.
- **Bloomstaff — mid-game unlock:** short-range light bolts with a slower charged bloom burst. Useful against hovering or distant enemies; lower close-range safety.
- **Rootbow — later unlock:** deliberate shots that pierce a line or pin a small enemy briefly. Strong range, slower draw, and limited charge shots rather than an ammunition grind.

### Skills

Mallow can equip **two active skills** at once; a third slot is reserved for the final region only if phone controls remain comfortable.

- **Mothlight:** starter skill. Send a soft homing mote toward the nearest visible enemy; modest damage and a long enough cooldown to feel special.
- **Briar Snare:** root a small target or slow a large one for a short time; unlocked in Hollowroot Grove.
- **Petalguard:** a brief protective bloom that absorbs one hit and nudges nearby enemies back; unlocked from an NPC quest.
- **Moonburst:** late-game area burst that consumes a filled Bloom meter; clears small enemies but should not trivialize bosses.

Skills can receive one or two simple upgrades each (cooldown, radius, or utility). Avoid dozens of passive nodes in the first release.

### Equipment and upgrades

Three equipment slots keep inventory management light:

1. **Weapon** — determines the basic attack and weapon feel.
2. **Cloak** — one defensive or movement modifier (for example, safer healing or a slightly longer dash).
3. **Charm** — one utility modifier (for example, extra Petalcoins from caches or a larger healing effect).

Equipment is earned from exploration, quests, and bosses. It is not randomly rolled. Upgrade a piece through three readable ranks at the village craft table. Show the stat change before spending materials. Cap the number of items so a player can compare them without scrolling through a huge inventory.

## 5. Economy, items, and rewards

### Currency and crafting materials

- **Petalcoins:** common currency from enemy groups, side paths, and chests. Spend them on healing supplies, maps, and modest crafting costs.
- **Moonshards:** rare, named-region materials from bosses and a few optional challenges. Use these for weapon/skill milestones, not ordinary shopping.
- **Region keepsakes:** one unique item per region used to complete local quests or restore its shrine. Do not require farming repeat drops.

Show a reward before an optional challenge and explain what it buys. There are no premium currencies, paid boosts, timers, or daily chores in the proposed core game.

### Consumable items

- **Moontea:** restore one heart; carry up to three initially. Refill at a shrine or buy/craft at Hearthgrove.
- **Feather Tonic:** short movement-speed boost for exploration; optional and not required for combat.
- **Glowseed Lure:** distract or draw small creatures for a few seconds; primarily a puzzle/utility item.
- **Region key items:** story tools such as the Reed Key; do not take a permanent inventory slot after use.

### Reward cadence

An ordinary group yields a little currency or a small chance of a common material. Chests guarantee a known reward. Bosses grant one Moonshard, one story keep-sake, and a visible world change. Repeated enemies should not be the only way to progress.

## 6. Village and NPCs

**Hearthgrove** is a compact hub that grows more colorful as shrines are restored. Keep NPC conversations short, skippable, and revisitable from a journal.

- **Sedge, the smith:** upgrades weapons and cloaks; blunt, encouraging, likes useful old tools.
- **Mira, the gardener:** exchanges region keepsakes for Moontea and cultivates the village garden; teaches the Moonwell lore.
- **Pip, the peddler:** sells maps, Moontea, and a few charms for Petalcoins.
- **Tallow, the pathfinder:** opens region routes after shrine milestones and marks discovered side paths on the map.
- **Nim, the moth-tender:** gives optional rescue quests and unlocks Mothlight/Petalguard improvements.

NPCs do not require full voice acting or branching dialogue trees. Use a small set of portrait poses, a nameplate, short text, and one clear choice where a quest or purchase is involved.

## 7. World and maps

The world is a hub plus four authored regions. Each region should use a small tileset, reusable props, a few enemy combinations, a shortcut, one side quest, and one guardian arena.

1. **Petalfield Meadow — Phase 0 / opening region.** Soft teal grass, white vine-wrapped stones, drifting pink petals, pale footpaths. Phase 0 already sketches this place and its shrine. In the full game it becomes the opening tutorial area, expanded with a safe path, a first enemy encounter, and a short route back to Hearthgrove.
2. **Hearthgrove — hub.** A sheltered village among roots and old lanterns. Shops, crafting, NPC stories, map board, save point, and the visual home for world-restoration progress.
3. **Hollowroot Grove.** Deep green canopy, tangled roots, warm amber spores. Introduces ambush plants and the Briar Snare skill. Boss: **The Briarback**, a shy guardian tangled in thorn growth; attacks with readable root lines and a rolling charge.
4. **Glasswater Marsh.** Blue-green pools, stepping stones, reeds, reflections, and drifting lights. Introduces water-edge navigation and ranged enemy pressure. Boss: **The Mirror Eel**, which dives, sends a visible ripple lane, and briefly creates a decoy reflection.
5. **Moonstone Ruins.** Cool lavender stone, broken arches, wind-borne petals, and star-like markings. Tests dash timing and mixed enemy groups. Boss: **The Quiet Warden**, a former shrine keeper using slow, patterned sweeps and summoned stone echoes.
6. **The Moonwell.** Short finale reached after restoring the four region shrines. A compact sequence and final guardian, **The Hollow Bloom**. Its phases reuse learned tells rather than adding a new control system. The ending restores color and music to the world; a post-game free-explore state remains available.

Each map should have a clear route, one optional loop/shortcut, two or three small encounters, a shrine checkpoint, and the guardian. Avoid sprawling empty maps or mandatory backtracking across the whole world.

## 8. Enemies and bosses

### Common enemies

- **Thornling:** slow melee plant; teaches attack timing and dash-through.
- **Puffcap:** stationary spore creature; telegraphs a small radial puff, encouraging movement.
- **Mothwisp:** floating ranged nuisance; fires a slow visible mote, encouraging approach or dodge.
- **Rootbound:** sturdier shielded creature; vulnerable from the side or after its heavy strike.
- **Marsh Skipper:** quick water-edge attacker; hops to a marked landing spot.

Start with three enemy types in the first combat slice. Add the rest only after attack tells, hit feedback, and mobile performance are solid. A region palette swap alone does not count as a new enemy; each addition needs a distinct behavior.

### Boss pattern rules

- One boss arena, three or four recognizable attacks, clear telegraphs, and a short recovery window.
- A boss fight should take a few minutes, not require precision taps, and allow safe healing windows.
- The player should learn by observing, not by reading a long tutorial. After a loss, retry at the nearby shrine without replaying the whole region.
- Boss rewards are guaranteed and change the hub or open a route.

## 9. Items, quests, and discovery

- **Main quests:** restore the four region shrines and reach the Moonwell.
- **Side quests:** short, local tasks such as returning a lost lantern, finding a garden seed, or escorting a moth wisp across one screen. Each gives a defined reward and an NPC reaction.
- **Secrets:** tucked-away cache, a visible but initially unreachable nook, a small environmental puzzle, and a lore scrap per region.
- **Journal/map:** automatically record region names, NPC requests, discovered shrines, and a simple fog-of-war map. The map shows points of interest but never dictates every route.
- **Save:** autosave on entering Hearthgrove and activating a shrine; save region unlocks, health refill, equipment, currency, quest flags, and collected major rewards. Provide a clear “Continue” and “New Game” choice; do not save every frame.

## 10. Art, animation, audio, and interface

### Visual identity

- **Perspective:** top-down with a slight three-quarter read; consistent ground shadows and object overlap.
- **Resolution:** work on a small logical pixel grid and scale with nearest-neighbor filtering. Keep the game legible on a 16:9 phone without relying on tiny text.
- **Palette:** misty teal and sage for safe meadow; plum for Mallow and UI contrast; pale warm stone for ruins; pink petals and butter-yellow Moonseeds as accents. Give each region its own dominant hue without abandoning the shared palette.
- **Lighting:** soft pools around shrines, Moonseeds, and lanterns. Avoid dark scenes that hide hazards on phone screens.
- **Motion:** Mallow idle breathing and ear flick; short attack anticipation; readable weapon arcs; dash trail; brief hit-flash; petals and grass move slowly. Keep decorative particles low and optional.
- **Environment:** hand-built tile sets with reusable edges, corners, ruins, props, and collision variants. Phase 0's code-drawn placeholder shapes are scaffolding, not final production art.

### Audio

Use a restrained soundtrack: gentle plucked notes and soft pads in the meadow; slightly more rhythmic layers during combat; a clear audio sting on a shrine restoration. Short, distinct cues cover attack, dash, hit, seed pickup, menu focus, and boss telegraph. Add volume sliders and a full mute option. Sound is optional feedback, never the only warning.

### HUD and menus

- Health at top-left; region/objective and Moonseed progress nearby; no always-visible wall of stats.
- Large touch controls at lower left/right with clear pressed/cooldown states.
- Pause menu: resume, controls, sound, text size, button layout, return to title.
- Inventory uses three equipment slots and a compact bag; compare one item at a time.
- Dialogue and item descriptions use large text, short lines, and skip/continue touch targets.
- Boss health bar appears only in the arena. Keep UI inside safe areas and test cutouts/notches.

## 11. Development phases

Phases are milestone gates, not calendar promises. Each ends with a build that can be tried on the phone. Keep the repo's `main` branch runnable; test larger changes on a branch before merging if needed.

### Phase 0 — Current MVP (already in the repository)

- Godot 4 project, landscape viewport/orientation, Compatibility renderer.
- Small meadow with ruins, petals, Moonseeds, and a shrine drawn from GDScript shapes.
- Mallow placeholder, keyboard movement, dash, collisions, mobile directional pad, seed counter, and win message.
- Goal: prove that GitHub → GitSync → Godot Android can load and run a small project.
- **Not included yet:** a virtual joystick, final sprite art, enemies, damage, weapons, NPCs, inventory, or persistent saves.

### Phase 1 — Mobile feel and character foundation

- Replace the four-button pad with a polished, thumb-tested virtual joystick; keep dash as a large touch action.
- Add safe-area handling, pause/settings overlay, touch feedback, joystick dead zone/sensitivity settings, and gamepad/keyboard parity.
- Replace the code-drawn Mallow with a small original sprite sheet: idle, 4/8-direction walk, dash, hurt, and attack placeholders. Keep sprite silhouette and colors from this plan.
- Add camera follow tuning, collision layers, world bounds, shrine checkpoint interactions, and basic save/load skeleton.
- **Exit check:** a 5-minute phone playtest with no stuck input, no cropped controls, and comfortable movement in all directions.

### Phase 2 — First combat slice

- Implement health, damage, brief invulnerability, knockback, hit feedback, healing, and defeat/retry at a shrine.
- Add Thornblade's three-hit combo, facing assist, dash i-frames, cooldown indicator, and one skill button with Mothlight.
- Build Thornling, Puffcap, and one small encounter room; add one elite variant only if the base behaviors are readable.
- Add an encounter reset and a simple tuning/debug page for health, damage, cooldown, and enemy speed.
- **Exit check:** a new player can understand attack, dodge, and healing with short on-screen hints; fights run at a stable frame rate on the target phone.

### Phase 3 — Progression systems

- Add the Hearthgrove hub shell, inventory data model, equipment slots, Petalcoins, Moonshards, Moontea, and persistent player save.
- Add Sedge's upgrade interaction and Pip's shop; display exact cost and stat change before confirmation.
- Add Briar Snare and Petalguard, one cloak, two charms, and one upgrade rank. Avoid filling the inventory with test items.
- Add one local quest and a journal/map entry so quest flags and rewards are exercised.
- **Exit check:** leave the level, save, close/reopen the app, and keep currency, equipment, quest state, and shrine progress correctly.

### Phase 4 — Vertical slice: Petalfield + Hollowroot

- Turn Petalfield into the polished opening level and create Hearthgrove as the hub.
- Build Hollowroot Grove with its own tile set, shortcut, side quest, two enemy combinations, shrine, and Briarback boss.
- Add NPC portraits, short dialogue, sound cues, music transition, cutscene-free boss intro, reward, and region restoration change.
- Create a consistent content checklist so a new region can be built from reusable scenes/data rather than copy-pasted logic.
- **Exit check:** a complete 20–30 minute phone-playable slice from title screen through hub, region, boss, reward, and return.

### Phase 5 — Full adventure content

- Add Glasswater Marsh, Moonstone Ruins, and the Moonwell finale using the approved region template.
- Add the remaining weapons, enemies, bosses, NPC quests, keepsakes, optional caches, lore scraps, and shrine travel.
- Balance prices, drop rates, upgrade costs, enemy HP, boss phases, and level lengths based on playtests.
- Add the post-game free-explore state, full journal, map markers, and ending sequence.
- **Exit check:** the full main quest can be completed on a fresh save without cheats, missing progression, or mandatory grinding.

### Phase 6 — Polish, device testing, and release candidate

- Replace all remaining placeholder art/audio; finish animation, effects, menus, transitions, localization-ready text, and credits.
- Test on at least one lower-powered Android phone and one larger screen; check memory, heat, loading, safe areas, touch latency, orientation, and app pause/resume.
- Add control remapping/layout, text-size option, reduced screen shake/particles, volume settings, and robust save recovery.
- Export and install an Android build, test update/save continuity, prepare screenshots and a short store description, and document the tested Godot version.
- **Exit check:** no known progression blockers or save loss; all controls can be reached one-handed or with two thumbs; a complete release build installs and resumes correctly.

### Optional Phase 7 — After release

Only after the main adventure is stable: add a challenge room, time-trial shrine records stored locally, new cosmetic cloaks, or a new region. Do not add online services, daily rewards, or monetization unless the project direction changes deliberately.

## 12. Scope guardrails and risks

- **Scope:** four regions, one compact hub, three weapons, a small number of authored skills and equipment pieces, and a short main story. No open world, multiplayer, procedural loot, crafting tree, or live-service obligations in the first release.
- **Mobile input risk:** joystick and action buttons can overlap or feel imprecise. Validate Phase 1 early before building lots of combat content.
- **Content risk:** too many bespoke assets can stall implementation. Reuse a small tileset and enemy base behavior while ensuring each enemy still has a distinct readable pattern.
- **Save risk:** test save/load as soon as currency and quests exist, not at the end.
- **Performance risk:** limit overdraw, particle count, large transparent textures, and expensive full-screen effects. Use the Compatibility renderer and test on the actual phone.
- **Reference boundary:** use the clip as an aesthetic/game-feel guide, not as a source for copied characters, maps, or proprietary assets. All final designs and assets should be original.

## 13. What is intentionally decided for now

To let development proceed without needing every story detail up front, this plan chooses a solo offline action-adventure, a gentle fantasy tone, Mallow as the protagonist, a four-region story, one main currency, and short skill loadouts. These are easy to revise before their phase begins. The first meaningful design test is Phase 1's touch controls and Phase 2's combat feel; later content should wait until those work on the phone.
