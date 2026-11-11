# Cowl interaction assets and room plates — generated source drafts

18 PNGs generated with the built-in image generator, with four targeted correction passes. PNG pixels have not been resized, repacked, recoloured, or otherwise altered after generation. Generation prompts are included.

These are source-art drafts, not a production-certified Godot asset pack. All requested groups are represented, but the generator did not consistently honour exact canvas dimensions, object pixel dimensions, padding, anchors, palette values, silhouette or composition locks. Do not import these as exact tile/collision or animation atlases without cleanup.

## Measured files

| File | Requested pixels | Exported pixels | Mode | Fully transparent pixels present |
| --- | --- | --- | --- | --- |
| W30_Root_Barriers | 2048x2048 | 1254x1254 | RGBA | yes |
| W31_Machines | 2048x2048 | 1254x1254 | RGBA | yes |
| W32_Sealed_Doors | 2048x2048 | 1774x887 | RGBA | yes |
| W33_Secret_Pieces | 2048x2048 | 1774x887 | RGBA | yes |
| W34_Interactables | 2048x2048 | 1774x887 | RGBA | yes |
| W35_Candles_And_Lamps | 2048x2048 | 1254x1254 | RGBA | yes |
| W36_Candle_Flame_Loop | 2048x1024 | 1774x887 | RGBA | yes |
| W37_Hanging_Moss_Clumps | 2048x1024 | 1774x887 | RGBA | yes |
| W38_Moss_Sway_Loop | 2048x1024 | 1774x887 | RGBA | yes |
| W39_Decals | 2048x2048 | 1774x887 | RGBA | yes |
| P_Bedroom | 1532x920 | 1617x972 | RGBA | yes |
| P_Bedroom2 | 1500x766 | 1755x896 | RGBA | yes |
| P_Kitchen | 1940x820 | 1928x815 | RGBA | yes |
| P_Dining | 1776x1004 | 1668x943 | RGBA | yes |
| P_Living | 2032x1062 | 1735x906 | RGBA | yes |
| P_Study | 2048x816 | 1985x792 | RGBA | yes |
| P_Storage | 1600x960 | 1619x972 | RGBA | yes |
| P_Flooded | 2048x1060 | 1742x903 | RGBA | yes |

## Remaining production work

- Repack source pieces at 128 px per tile onto the specified canvas and cell sizes, preserving the intended 64 px or cell-specific spacing. Merely resizing each entire sheet will not establish correct object sizes.
- Re-anchor flame frames at local (256,400), normalise volume and frame spacing, apply durations [6,6,5,5,6,6,5,6] ticks, and test the loop. Flame edges show colour fringe that needs cleanup.
- Re-anchor moss sway frames at a shared fixed ceiling point; durations are eight ticks each. Animation timing and seamlessness have not been tested.
- Check cut-root animation continuity, root barrier cut alignment and remnants. The generated variants are not guaranteed to register to one another.
- Heavy-chain orientation and missing vault socket were corrected. Chain tiling remains unverified; the lift standing lines, machine proportions and orthographic view still need adjustment.
- The secret sheet duplicate small door was removed. Green seams still extend into decorative tracery rather than only door gaps.
- Lighting-sheet haze was removed in a correction pass, but slight coloured fringes remain and the small chandelier still lacks the requested candle arrangement.
- Floor decals exceed the requested 20 px height and need reduction/repainting. The wall crack reads too much like a root.
- Room paintings retain their main object arrangements, but their exact silhouettes, poses, edge feathering, proportions and dimensions are not pixel-matched to the supplied plates. The storage repaint adds/rearranges barrels. Background and water lighting also require palette review.
- Match all colours and line weights to the canonical references at final play scale. Some source assets remain more sculpted and ornate than the target's spare ink-and-wash treatment.

No Godot import, collision setup, slicing, tiling or in-engine test was performed.
