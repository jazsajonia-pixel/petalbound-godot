# Third-Party Game Art Sources

Reviewed 2026-10-15. Since `petalbound-godot` is public, an asset must permit inclusion with a project in a public source repository; “free to use in a game” alone is not enough if redistribution is forbidden.

## Integrated

| Pack | Use | Verified source-page terms |
| --- | --- | --- |
| [Free 16x16 Weapon RPG Icons](https://merchant-shade.itch.io/free-16x16-weapon-rpg-icons) by Shade | 16×16 weapon variants. The listing includes rapier, katana, sword, greatsword, scimitar, knives, axes, hammer, spear, staff, trident, mace, scythe, sickle and nunchucks; 30 designs per family and four material/color sheets. | The official page identifies **CC0 1.0 Universal** and permits commercial/non-commercial game use and modification. |
| [Idylwild’s Armory](https://idylwild.itch.io/idylwilds-armory) by Idylwild | 32×32 armor/accessory icons: helmets, chest pieces, gloves/bracers, pants, boots, cloak, shields, rings and amulets. | The official page identifies **CC0 1.0 Universal** and permits sharing and adaptation for any purpose, including commercially. Attribution is optional. |
| [Coins & Gems & Chests & More](https://greatdocbrown.itch.io/coins-gems-etc) by greatdocbrown | Selected 16×16-style potion and gem icons for consumables and materials. The wider pack also contains coins, keys, chests, hearts, food, bags and orbs. | The official page identifies **CC0 1.0 Universal** and permits copying, modification and distribution, including commercially. |
| [Admurin’s Armory / Pixel Armory](https://admurin.itch.io/pixel-armory) by Admurin | Two 32×32 bow cells from the free weapon sheet, used to keep the two named bow variants visually distinct. | The page permits personal/commercial game-project use and modification, and says the art must be part of a project, not resold or redistributed as a separate game-asset product. The sheet is included as part of the game project; the premium archive is not included. |

Runtime cuts can be reproduced with `tools/slice_itch_asset_sheets.py`. Source sheets and individual asset files are grouped under `assets/packs/itch_cc0/`; the previous custom-generated art has been removed from the project.

## Supplied links reviewed but not included

- [Pixel Creations — 16x16 RPG Items](https://pixelcreations.itch.io/rpg-items-16x16): the official page allows commercial/non-commercial project use and modification, but says not to distribute the assets or edited derivatives. Not included in this public repository.
- [Card RPG Items](https://sagak-art-pururu.itch.io/cardrpg-items): the official page allows commercial/free project use and modification, but prohibits redistribution/resale. Not included in this public repository.
- The Admurin pack was supplied twice; it is included only for the two bow variants under the project-use terms above.

## Other reviewed pack

- [Clockwork Raven — FREE RPG Icon Pack](https://clockworkraven.itch.io/free-rpg-icon-pack-100-weapons-and-po-clockwork-raven-studios): the listing allows project/commercial use and modification but says the pack cannot be distributed as a separate product. It was not needed once the more directly matched CC0 weapon, armor and material sources were selected.

## Character-art candidates reviewed (not integrated)

The current hero replacement is deliberately deferred: a candidate needs to meet the public-repository license, match the fantasy setting, and supply enough directional/action frames for the existing player animations and gear-mask pipeline.

| Pack | Fit and verified terms | Decision |
| --- | --- | --- |
| [CHROME DISTRICT — 20 Cyberpunk Pixel Characters / Top-Down RPG Walk Cycles](https://booliebuilds.itch.io/chrome-district) by booliebuilds | CC0 1.0. 20 characters, 5 camera views, 8 directions × 6 walk frames, 56×84 cells. Good non-16×16-scale/top-down technical baseline, but cyberpunk look and walk-only animation make it a poor direct fantasy-hero swap. | Best repo-safe top-down proportions lead; use only after visual approval and a plan for missing actions/palette masks. |
| [Fantasy Sprites Vol2](https://kepixelart.itch.io/fantasy-sprites-vol2) by KePixelArt | CC0; five detailed fantasy characters as transparent individual PNGs. Page states there are no animations. | On-theme and redistributable, but static art; not a drop-in playable character. |
| [Dark Fantasy Pixel Pack — 54 Characters](https://willyee.itch.io/dark-fantasy-pixel-pack-54-characters-25-monsters-455-weapons) by willYEE | CC0 1.0; 54 characters, 80 px tall, 12 animation types. The page identifies it as a **side-scrolling** action-RPG pack and discloses AI-generated images. | Tall silhouettes, but perspective is incompatible with the current top-down game; not integrated. |
| [The Adventurer — Male](https://sscary.itch.io/the-adventurer-male) by Sscary | The author permits free/commercial game use and modifications, but expressly prohibits redistribution/resale. Free demo has idle/walk/jump/dash/death; additional animations are premium. | Potentially closer to an action-RPG character style, but cannot be included in this public source repository under the listed terms. |
| [Free Pixel Art RPG Animated Character](https://pixel-poem.itch.io/dungeon-hero) by Pixel_Poem | Free/commercial use and modification allowed, but redistribution/resale prohibited. Four-direction idle/run/attack/death. | Not repository-safe; four-direction template and appearance also need evaluation before adoption. |
| [Free Swordsman 1–3 Level Pixel Top-Down Sprite Character](https://craftpix.net/freebies/free-swordsman-1-3-level-pixel-top-down-sprite-character-pack/) by CraftPix | Three four-direction swordsman stages with idle, walk, attack, run, hurt and death animations. Visually taller than a 16×16 Game Boy-like base, though still a compact pixel character. CraftPix's official Freebie license permits game use but forbids distribution of source art files. | Closer in genre and silhouette than the existing base, but **not cleared for inclusion in this public source repository**. |
| [8 Directional Knight Character](https://hormelz.itch.io/8-directional-knight) by Hormelz | Free CC0 Knight-only bundles; pixel-art/HD-2D presentation with 8-direction sprites and a large animation set. The sampled preview reads as a compact, heavily helmeted knight rather than the taller/natural silhouette requested. | Repository-safe in its free Knight-only variant, but not a strong visual/style match; not integrated. |
