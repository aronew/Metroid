# The environment kit in the game

**12 November: the art pass was cut back.** The game now draws only:

- the collision mass in black;
- the floor tops, ceilings, wall faces and corners (W08-W11);
- the stairs (W13);
- ledges (the gallery floor strip);
- the parallax arcades (W03-W05), the nearer two faded so nothing behind the
  play reads as solid.

The room plates, wreckage, room walls, windows, door frames, columns,
railings, candelabra, moss and decals are no longer drawn. Their cut pieces
are still in `assets/kit` if they are wanted again. The tables below record
the first pass.

Three archives arrived on 11 November 2026. Together they hold every file
their manifests list:

| Archive | Files |
| --- | --- |
| Archive 1 | W00-W17: two repaint targets, materials, parallax, floors, ceilings, wall faces, corners, openings, stairs, railings, piers, vaults, windows |
| Archive 2 | W18-W29: eight room walls, four wreckage sheets |
| Archive 3 | W30-W39 and P_*: roots, machines, sealed doors, secret pieces, interactables, candles, flame loop, moss, moss loop, decals, eight repainted room plates |

The originals are kept untouched in `assets/source/kit/`, with both READMEs and
the export manifest. `tools/build_kit.py` cuts them into the 195 pieces the
game loads (`assets/kit/`, listed in `assets/kit/kit.json`, drawn in
`docs/kit-pieces.png`).

## What the builder changes, and why

Nothing is repainted. The changes are the ones the kit's own READMEs ask for:

- **Scale.** The kit is drawn at 128 px a tile, and the game runs at 64.
  Pieces are halved with premultiplied-alpha resampling, so edges pick up no
  fringe.
- **Sizes.** The generator did not hold the requested canvas or object sizes
  (both READMEs say so), so no piece is drawn at a fixed scale. Each one is
  fitted to the collision, to an entity's rectangle, or to a height relative
  to Cowl.
- **W09 ceilings.** Each strip carried an opaque slate backing under its edge.
  It is keyed out: smooth mid-tone regions that reach the strip's bottom are
  cleared; stones are left because ink rings them. Slate enclosed inside an
  arch stays, as vault infill.
- **Grid sheets.** The root cut (W30), flame loop (W36) and moss loop (W38) are
  cut by cell, not by blob, so the cut halves stay registered. The two loops
  are re-anchored to one point per sequence (flame base, moss top).
- **Room plates.** Their soft margins were deepened (sides and top, never the
  floor) so they settle into the darker kit walls.
- **Haze.** Alpha under 12 is cleared everywhere.

## Where each sheet is used

| Sheet | In the game |
| --- | --- |
| W00, W01 | Look targets only. They are repaints of in-game screenshots, not placeable art |
| W03, W04, W05 | The three parallax depths behind the grand hall and other open rooms |
| W06 | The undercroft's wall |
| W07 | Faint texture on the solid mass |
| W08, W09, W10, W11 | Laid along every collision edge: floor tops, ceilings (clipped so nothing hangs lower than 2.5 tiles over a floor), wall faces, ledge lips, inner corners, overhang ends |
| W12 | Frames on every doorway |
| W13 | Every staircase, stretched to its collision ramp; the fallen flight is the mound piece |
| W14 | Railings on real galleries and along every stair (skewed so balusters stay upright) |
| W15 | Columns (three-sliced so capital and base keep their shape), bosses under ceiling bays |
| W16 | Spandrels in room corners |
| W17 | Windows: lancets in the house, barred windows in the cellars, dormers in the attic, portholes in the lab |
| W18-W25 | Room walls by mood |
| W26-W29 | Wreckage fitted over the 25 masses it stands for; see below |
| W30 | Root barriers and their cut sequence; the root-bound levers |
| W31 | The dumbwaiter, chandelier and cage lifts, their chains, levers, the winch, the library lamp, the boiler pipe |
| W32 | Front door, garage shutter, laboratory vault |
| W33 | The two green doors, the study bookcase, the pipes behind the boiler, the cracked workshop floor |
| W34 | Rest candles (unlit and lit), the butcher's block, the knife in Cowl's hand, notes on the floor, the stalagmites |
| W35 | Candelabra and the father's lamps |
| W36 | The flame loop on every candle, painted or placed |
| W37, W38 | Hanging moss in front of the play, and the swaying strands in tall rooms |
| W39 | Damp stains, cracks and floor litter |
| P_* | The eight room plates, at the width the family's interaction points were set for |

## Wreckage against the collision

Each piece is fitted so the median top of its silhouette sits on its mass's
collision top. The art limit is a quarter tile (16 px). Run
`python3 tools/mansion_layout.py` for the current figures. Two pieces exceed
it, both upward:

- the canopy bed (36 px): its posts and drapes rise behind Cowl, above the mattress he stands on;
- the urn planter (35 px): its fronds rise above the rim he stands on.

Neither puts anything under his feet that isn't collision.

To fit the art, four masses changed. The reading table is now 2 tiles high
(was 3). The root through the glass is 3 high (was 4). The library's book step
and the living-room shelf use the toppled-bookshelf piece. The mansion was
walked again afterwards: every room is reached, every gate holds, and nothing
reachable is a trap.

## Not used yet

Some pieces have no place in the slice yet:

- from W02: the material swatches;
- from W12: the torn header, cloth lintel and torn canopy;
- from W14: the broken, fallen and twisted rails;
- from W15: the block pier and plinth;
- from W16: the rib spans and root-bound arch posts;
- from W35: the sconce, candle stubs, small chandelier and toppled candelabrum;
- from W39: the cobwebs and ceiling roots.

They are cut and ready (`docs/kit-pieces.png`).

## What is still needed

In order of how much each would lift the slice:

1. **Cowl, drawn to move.** Supplied on 12 November; see
   `docs/character-integration.md`.
2. **Creatures.** Two exist in play with placeholder ink art: a low
   crawler that patrols, rears and charges, and a floating drifter. Each
   needs these frames:
   - **crawler:** idle, walk, rear (the tell), charge, hurt, death;
   - **drifter:** idle, approach, hurt, burst.
3. **Combat effects.** A slash arc or two, a hit spark, and a small dust
   puff. These are drawn in code now.
4. **Sound and music.** All sound is synthesised placeholder. There is no music.
5. **The laboratory antechamber.** It has walls, portholes, lamps and the
   vault, but nothing of the father's work in it yet: benches, apparatus,
   containment.
6. **UI.** Health pips, a prompt font, and title and pause screens.

These are optional:

- the fourth family member (the portrait shows four);
- a moving water surface for the flooded undercroft;
- the reworks the kit's own README lists (floor decal heights, flame
  fringes).
