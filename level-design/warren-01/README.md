# Warren 01: a blockout in the stacked-corridor grammar

One region-sized test room, built to answer a single question: can we build
levels with the construction seen in the dense "warren" reference maps?
It is a proof of method for review. It is not a traced copy of any map.

## What was taken from the reference

Measured and read off the reference crop, then rebuilt as an original layout:

- **Mostly rock.** Open space is 29% of the reference frame. Here it is 31%.
- **A stack is one tall room, cut into lanes by thin tongues of rock.** The
  tongues reach in from alternate walls and stop short, leaving the turn.
  Walls stay straight; the tongues are two tiles thick.
- **Lanes are low.** 81% of the floor here sits under a ceiling of five tiles
  or less.
- **Rooms are separate blobs joined by thin necks**: long tunnels, drop
  shafts, and one lane shared between two stacks.
- **A few larger spaces among the lanes**: a hall, a pooled chamber, a shrine,
  two junctions.
- **Pockets of different lengths** beyond the turns, each holding a reward.
- **Irregularity lives in the composition and the skin.** Every collision edge
  is a rectangle's edge. The wavy outline in `2-map-view.png` is drawn over
  the rectangles and collides with nothing.

## What is in it

| Place | What it is |
| --- | --- |
| West stack | Nine lanes in two offset towers; the west door enters at the top |
| Knuckle | A raised bump on the long tunnel east |
| Lamp hall and north shelves | A hall capping four shelves |
| East stack | Eight lanes wrapped round two thick islands, with two drop shafts |
| The cistern | The one large chamber: pillars across a pool, a balcony, a flooded pocket |
| Lone room | Up the cistern's west wall; needs a wall cling |
| Junction, twin stacks | A two-level junction and two stacks sharing one long lane |
| The snake, long walk, low shrine | Three lanes down to an 150-tile walk with a shrine midway |
| Crust pocket | Under the long walk; needs a crust-breaking dive |

## Files

- `layout.py`: the level as rectangles (spaces carved, masses put back).
- `build.py`: builds the grid, measures the rules, walks it, draws it.
- `warren.json`: the same level as engine-neutral data.
- `report.txt`: measured rules and the result of the walk.
- `1-collision-blockout.png`, `2-map-view.png`, `3-walk.png`, `4-play-scale.png`.

Rebuild with `python3 build.py` (needs numpy and Pillow).

## Provisional numbers

The game has no movement numbers yet. Everything here assumes a body 0.8 by
1.8 tiles, a jump that rises 3.4 to 3.9 tiles and clears a 5.0 to 6.6 tile
gap, and a 32 by 18 tile screen. Change them in `build.py` and rebuild; the
walk will say what breaks.

## Known limits

- Every turn is a five-wide opening with a three-wide block under it. A lane
  that runs on past a turn is crossed by dropping onto the block and hopping
  out. The walker passes it both ways, but it has not been played.
- Five of the turn blocks are two tiles tall (under the three-tile lanes).
- The walker is a simplified jump model, not the game's physics.
- Enemies, hazards, camera and art are not designed.
