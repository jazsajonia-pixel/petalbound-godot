# Petalbound Asset Sources

Official creator/listing pages and license evidence were checked on 2026-10-11. Source art is not overwritten; Mallow's rose/plum look and outfit variants are runtime palette swaps in `assets/shaders/sprite_fx.gdshader`. Code, shaders, world generation, and UI layout are project-authored. The hero region masks in `ninja_adventure/hero/masks/` are generated from the CC0 hero sheets by `tools/build_hero_masks.py` (derived data, same CC0 terms). New weapons, armour pieces and materials reuse existing Ninja Adventure icons and hand sprites (with runtime tints).

## Used in the game

| Pack | License and source | Local files | Use |
| --- | --- | --- | --- |
| **Ninja Adventure Asset Pack — Pixel-boy & AAA** | [Official itch.io listing](https://pixel-boy.itch.io/ninja-adventure-asset-pack), **CC0 1.0**. The pack's licence file is kept at `ninja_adventure/LICENSE.txt`. Attribution is not required but is given here. | `ninja_adventure/` (321 selected files copied by `tools/import_ninja_adventure.py`; see `PACK_README.md`) | Hero (NinjaGreen, recoloured as Mallow), villagers and animals, 19 monster types, 4 bosses, tilesets (floor, nature, water, desert, houses, dungeon), weapons/items/gear icons, hearts and UI art, combat and magic FX sprites, and particles. Also all music, jingles and sound effects. |
| **Nunito — The Nunito Project Authors** (github.com/googlefonts/nunito) | [google/fonts: ofl/nunito](https://github.com/google/fonts/tree/main/ofl/nunito), **SIL Open Font License 1.1** (`../fonts/OFL_Nunito.txt`, downloaded 2026-10-13). | `assets/fonts/Nunito.ttf` (variable font, used at weight 750) | All HUD, menu, shop and dialogue text. |
| **Pixelify Sans — The Pixelify Sans Project Authors** (github.com/eifetx/Pixelify-Sans) | [google/fonts: ofl/pixelifysans](https://github.com/google/fonts/tree/main/ofl/pixelifysans), **SIL Open Font License 1.1** (`../fonts/OFL_PixelifySans.txt`, downloaded 2026-10-13). | `assets/fonts/PixelifySans.ttf` | Title logo and floating damage numbers. |
| **Kenney Fonts — Kenney** | [Official page](https://kenney.nl/assets/kenney-fonts), **CC0 1.0** (`kenney_fonts/LICENSE.txt`). | `kenney_fonts/kenney_mini.ttf`, `kenney_pixel.ttf` | Previously all game text; replaced on 2026-10-13 for readability. Kept, unused. |
| **Mini Meadow — myobln** | [Official itch.io listing](https://myobln.itch.io/game-assets), CC0-1.0. The creator says it is public domain, allows commercial use, and requires no attribution. | `mini_meadow/` (source README, manifest, tile PNGs, sheets, previews) | Used by the earlier meadow prototype. It is kept in the repository but no longer rendered by the open-world map. |
| **496 Pixel Art Icons for Medieval/Fantasy RPG — credited creator Henrique Lazarini (7Soul1)** | [Official OpenGameArt listing](https://opengameart.org/content/496-pixel-art-icons-for-medievalfantasy-rpg), CC0 as listed. The page says incompatible derivative icons were removed from the public-domain set. | `rpg_inventory_icons/source.zip`; selected 34×34 PNGs under `rpg_inventory_icons/selected/` | The Plum Wayfarer Cloak icon in the satchel. The full source archive is kept intact. |

## Reviewed, not imported

| Candidate | Finding and decision |
| --- | --- |
| **Free 8-Directional Melee Character — Hormelz** ([source](https://hormelz.itch.io/8-directional-melee-character)) | Creator states CC0-1.0, 38 animations, eight directional sheets. Its 126×132, more detailed style would replace Mallow's established compact white long-eared silhouette. Mallow instead received project-authored blink, movement, dash, attack, and guard animation cues. |
| **Free Pixel Effects Pack — CodeManu** ([source](https://codemanu.itch.io/pixelart-effect-pack)) | Not used: the page's prose says public domain/no credit, while its metadata says CC BY 4.0. Avoided until the conflicting terms are clarified. Current combat sparks, slash arcs, motes, and petal bursts are original code drawings. |
| **PickyPixels — auranym** ([repository](https://github.com/auranym/picky-pixels)) | MIT-licensed, but its early-stage, palette-variant/subviewport workflow is unnecessary here. Project-authored palette and vignette shaders with Godot 2D lights provide the required atmosphere without another plugin. |
