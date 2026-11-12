# The mansion: design notes for the vertical slice

This is the working design behind `tools/mansion_layout.py`. It follows the
blockout-first, progression-first method: abilities before rooms, mass before
platforms, collision before art, and every claim walked by a tool.

**Status: built and validated, awaiting review.** Three things here are
proposals that need the creative lead's decision before anything is built on
them. They are marked **PROPOSED**.

Drawings: `docs/blockouts/mansion-1-collision.png` (the blockout),
`mansion-2-walked.png` (every spot the real controller can stand on, before
and after the knife), `mansion-3-screen-*.png` (play-scale windows).

## 1. Cowl's movement, measured

Numbers come from `tests/feel_test` driving the real controller (default
preset); see `docs/feel-report.txt`. Tile = 64 px. Cowl's body is 0.63 x 1.56
tiles.

| Property | Value | What the level may ask |
| --- | --- | --- |
| Run | 8.6 tiles/s, top speed in 6 frames, stops in 5 | |
| Full jump | rises 3.5 tiles, 0.70 s in the air | required rises are 3 or less |
| Tap jump | rises 1.15 tiles | |
| A 3-tile block | reachable | |
| A 4-tile block | not reachable | 4 and up is a wall |
| Running jump on the flat | clears 6 tiles with a perfect take-off; 7 fails | required gaps are 4 or less; a gap meant as a gate is 9 or more |
| Dodge | 3.6 tiles in 0.24 s, ground only, untouchable for 11 of its 15 frames | |
| Coyote time / jump buffer | 0.10 s / 0.12 s | |

The dodge is ground-only on purpose. It never extends a jump, so an air dash
remains available as a real, later ability.

## 2. Abilities

| Ability | State | Numbers | What it opens | How its lock looks |
| --- | --- | --- | --- | --- |
| **Butcher knife** | in the slice | 3 swings; 132 to 150 px reach | Overgrowth across doorways; roots binding lift levers | Dark roots and blue-green leaf across an opening |
| **A climb** (wall grip) | **PROPOSED** | to be set | The two tower shafts, each 4+ tiles of sheer wall above a landing | A tall smooth shaft with a lit ledge high up |
| **A second jump or air dash** | **PROPOSED** | to be set | The door on the undercroft's high ledge (6 tiles up) | A glowing door seen from below, no way to it |
| **Weight** (the sphere changes density) | **PROPOSED** | to be set | The cracked workshop floor | A floor split by cracks, a hollow sound |
| **The sphere** | story | | The laboratory vault | The round door and its empty socket |

Only the knife exists. The other three are placeholders in the fiction's own
terms (the sphere "changes the density of the objects around it"), written so
the mansion can hold their locks now. Their geometry is deliberately generic:
a sheer shaft, a high ledge, a cracked floor. If the real ability list
differs, these three places are the only ones to revisit.

The knife is not found in the first minutes. Before it the player crosses
up to eight rooms and meets its lock at least three times whichever way they
go (six if they see everything).

## 3. Lock-and-key registry

**Knife locks** (all validated shut without it, even with perfect inputs):

| Lock | Where | Seen before the knife? | Opens |
| --- | --- | --- | --- |
| V1 | bedroom, west door | yes, in the first room | west tower, and its well down to the conservatory |
| V2 | kitchen, the dumbwaiter's lever | yes | the kitchen to pantry lift (a shortcut once freed) |
| V2b | pantry, the dumbwaiter's lever | found with the knife | first cut; frees the lift |
| V3 | living room, east door | yes | library, study |
| V4 | sister's room, east door | yes | library gallery, parents' bedroom, east tower |
| V5 | pantry, east door | found with the knife | storage, and the basement beyond |
| V6 | kitchen, west door | yes | conservatory |
| V7 | undercroft, east door | after the knife | workshop, boiler room |
| V8 | hall mezzanine, the chandelier's winch | yes | the chandelier ride up to the attic |

**Locks kept for later abilities** (validated out of reach with the knife and
perfect inputs): west tower ledge, east tower ledge, the undercroft's high
door, the cracked workshop floor, the green door in the conservatory, the
garage shutter, the buried front door, the laboratory vault.

**The pantry** is the one place Cowl can enter and not leave without the
knife. That is intended: the knife is in it, in plain view, and both ways out
are roots.

## 4. The house

Five floor lines: attic 16, upper floor 28, main floor 41, basement 54,
laboratory level 66. 256 x 76 tiles, about 8 screens wide and 4 tall.

| Room | The idea, in one line | Its job |
| --- | --- | --- |
| Cowl's bedroom | Everything slid east when the house tilted; the way out is over the heap | wake; first jumps; first lock (V1) |
| Upstairs hallway | The floor has fallen into the dining room | first gap; fall or cross, both lead on |
| Grand entrance hall | A stair hall whose upper flight has broken, with its middle lying as a mound on the floor below | the reveal of scale; the hub; five doors at three heights |
| Sister's room | A wardrobe to the ceiling and a hatch above it | lock V4; where the attic's drop lands |
| Library | Two storeys, galleries broken apart in the middle, one hanging lamp between them | vertical hub: four doors, a drop, an upper line over the shelves |
| Parents' bedroom | A quiet room at the end of the upper floor | breath; leads to the tower |
| East / west tower | A sheer shaft with something lit near the top | later-ability locks; one-way drops that close loops |
| Attic | Low, long, under the roof timbers | reached by riding the chandelier; drops into the sister's room and the east tower |
| Conservatory | The glasshouse, taken by what grew through it | the green door: a way out of the house, sealed |
| Kitchen | The floor gave way under the butcher's block | Mum; the hole down; lock V2 |
| Dining room | The table still laid, under the hole in the ceiling | the sibling; where the hallway's fall lands |
| Living room | A toppled bookcase up to the mantel | the portrait; lock V3 |
| Father's study | His desk, and a bookcase that is not one | Dad; the lift arrives behind the bookcase |
| Pantry | What fell from the kitchen | the knife; the first cuts |
| Storage rooms | Crates, and a rack of barrels to get over | first creatures |
| Undercroft | The vaults under the hall, flooded at the far end | a longer room: stone to climb, stalagmites to jump, creatures, a door out of reach |
| Workshop | Dad's benches and an engine block | a rest candle; the cracked floor |
| Boiler room | A boiler with a gap behind it | the hidden way down: up the bunker, the pipe, the boiler, and behind |
| Laboratory antechamber | Plate metal and a round door | the sealed vault; father's lift home |

**Routes.** The spine of the slice:

1. Bedroom, over the heap, into the hallway at height.
2. Hallway, across or through the hole, onto the west gallery.
3. Down the broken flight (a 4-tile gap), the mezzanine, the grand flight.
4. East floor: living room. Back over the mezzanine and down the mound: dining
   room, kitchen. (Or fall through the hallway floor straight to the dining room.)
5. Through the kitchen floor to the pantry. The knife.
6. Cut out: east into storage, or free the dumbwaiter and ride up.
7. Storage, undercroft, workshop, boiler room.
8. Up and over the boiler, down behind it. The vault.
9. Father's lift up; the bookcase opens; study, library, living room, hall.

**Loops and one-way drops:** hallway to dining room; kitchen to pantry; west
tower to conservatory; attic to sister's room; attic and parents' bedroom to
the east tower's foot; boiler room to the laboratory. Every one lands
somewhere with a way home, checked.

**Machines.** Three lifts, each with its lever on the platform and a call
lever at a stop: the dumbwaiter (kitchen and pantry), the chandelier on its
winch (mezzanine and the roof truss), father's lift (laboratory and study).

## 5. Staircases

A staircase in a strict side view divides the floor it stands on: nothing
can pass under its foot. So each flight here is a single smooth ramp placed
where that division is wanted. The grand hall is built around it: the west
floor (from the dining room) and the east floor (from the living room) meet
only over the mezzanine. Upper flights that would have crossed over lower
ones are broken short, which is both the fiction (the house fell) and the
reason nothing snags.

No collision is stepped. Treads are drawn under the walking line.

## 6. What the checks found

`python3 tools/validate.py` walks the level four times with the real
controller: before and after the knife, each with perfect inputs and with a
cautious player (10% less jump, 6% less speed, no coyote time, no corner or
ledge forgiveness). Latest result: `docs/mansion-walk-report.txt`.

- Every room meant to be open at each stage is reached by the cautious player.
- Every knife lock and every later lock holds against perfect inputs.
- No traps, except the pantry before the knife (intended).
- Two real traps were found and fixed this way: the storage barrel rack and
  the library's fallen bookcase each had no way back over from the far side.
  Both got a second mass on that side.

When the environment kit arrived, four masses were adjusted so the art fits
them: the library's reading table (3 tiles high to 2), the conservatory's
root (4 to 3), and the art over the library's book step and the living
room's shelf. The mansion was walked again with no change in what is reached
or held (`docs/kit-integration.md`).

Measured composition: 84 collision rectangles for the whole house, 6 ramps,
2 one-way pieces (under 1% of the standing room), 76% of floor in flat runs
of 8 tiles or more, longest floor 85 tiles.

`tests/slice_test` plays the mechanics end to end in the real scene (waking,
the lock, the knife, cutting, a lift ride, creatures, stalagmites, the
bookcase, dying and returning): `docs/slice-test-report.txt`.

**Not checked by a tool:** how any of this feels in the hands. The tests
measure the controller and prove the routes; they cannot play it. Movement
tuning, camera feel, swing timing and encounter difficulty need a person.

## 7. Open questions for review

1. **The proposed abilities** in section 2. The tower shafts, the high door
   and the cracked floor assume them.
2. **Walls are 2 tiles thick**, thinner than the 3-tile rule for rock,
   because this is a house. Floors between storeys are 3.
3. **The knife is the first key and arrives after eight rooms.** If it should
   come later still, the east wing (sister's room, living room) can grow.
4. **The house's tilt** is carried by composition (the heap, the slid
   furniture, hanging things hanging askew). A slight camera roll was
   considered and left out; it is a one-line change if wanted.
5. **The attic is thin.** It works as a route and holds two creatures; it
   wants a reason of its own.
