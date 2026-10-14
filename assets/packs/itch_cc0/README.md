# Itch.io Game-Art Packs

These are third-party assets used by Petalbound. Each source is kept separate from the game code; individual runtime cuts are under `runtime/`.

## Sources and terms

- [Shade — Free 16x16 Weapon RPG Icons](https://merchant-shade.itch.io/free-16x16-weapon-rpg-icons): the creator’s itch.io page identifies CC0 1.0 Universal. It contains 16 weapon families, 30 designs per family and four color/material sheets. Selected cells are cropped to `runtime/weapons/` and `runtime/weapon_hands/`.
- [Idylwild — Idylwild’s Armory](https://idylwild.itch.io/idylwilds-armory): the page identifies CC0 1.0 Universal and permits sharing and adaptation, including commercially. The 32×32 individual armor/accessory sprites used by inventory variants are in `idylwild/`.
- [greatdocbrown — Coins & Gems & Chests & More](https://greatdocbrown.itch.io/coins-gems-etc): the page identifies CC0 1.0 Universal. Selected gem and potion cells are cropped to `runtime/items/`.
- [Admurin — Pixel Armory](https://admurin.itch.io/pixel-armory): the free `32x32_PixelWeapons_V3.png` sheet is included as part of this game project, not as a standalone asset pack. The page permits personal/commercial game-project use and modification, and says not to redistribute the asset as a separate game-asset product. Only two 32×32 bow cells feed distinct weapon variant icons; the held versions are scaled to 16×16.

Credit is included here even where optional. See [`docs/asset_sources.md`](../../../docs/asset_sources.md) for the selection rationale and the packs reviewed but not included.

## Rebuild runtime cuts

With Python 3 and Pillow installed, run from the project root:

```sh
python3 tools/slice_itch_asset_sheets.py
```

The tool performs deterministic pixel-aligned crops only; it does not synthesize artwork.
