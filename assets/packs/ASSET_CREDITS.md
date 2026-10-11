# Petalbound Asset Sources

Official creator/listing pages and license evidence were checked on 2026-10-11. Complete source archives are retained locally for integrated packs; source art is not overwritten. Runtime palette changes are shader-driven. Mallow, enemies, landmarks, UI, animations, and combat effects are project-authored.

## Used in the game

| Pack | License and source | Local files | Use |
| --- | --- | --- | --- |
| **Mini Meadow — myobln** | [Official itch.io listing](https://myobln.itch.io/game-assets), CC0-1.0. The creator says it is public domain, allows commercial use, and requires no attribution. | `mini_meadow/` (source README, manifest, tile PNGs, sheets, previews) | Ground, dirt/sand/stone paths, four-frame water, and flower, bush, mushroom, rock, log, and stump props in the expanded meadow. |
| **496 Pixel Art Icons for Medieval/Fantasy RPG — credited creator Henrique Lazarini (7Soul1)** | [Official OpenGameArt listing](https://opengameart.org/content/496-pixel-art-icons-for-medievalfantasy-rpg), CC0 as listed. The page says incompatible derivative icons were removed from the public-domain set. | `rpg_inventory_icons/source.zip`; selected 34×34 PNGs under `rpg_inventory_icons/selected/` | Thornblade, Bloomstaff, cloak, Moonheart Charm, and Moontea icons in Mallow's field kit. The full source archive is kept intact. |

## Reviewed, not imported

| Candidate | Finding and decision |
| --- | --- |
| **Free 8-Directional Melee Character — Hormelz** ([source](https://hormelz.itch.io/8-directional-melee-character)) | Creator states CC0-1.0, 38 animations, eight directional sheets. Its 126×132, more detailed style would replace Mallow's established compact white long-eared silhouette. Mallow instead received project-authored blink, movement, dash, attack, and guard animation cues. |
| **Free Pixel Effects Pack — CodeManu** ([source](https://codemanu.itch.io/pixelart-effect-pack)) | Not used: the page's prose says public domain/no credit, while its metadata says CC BY 4.0. Avoided until the conflicting terms are clarified. Current combat sparks, slash arcs, motes, and petal bursts are original code drawings. |
| **PickyPixels — auranym** ([repository](https://github.com/auranym/picky-pixels)) | MIT-licensed, but its early-stage, palette-variant/subviewport workflow is unnecessary here. Project-authored palette and vignette shaders with Godot 2D lights provide the required atmosphere without another plugin. |
