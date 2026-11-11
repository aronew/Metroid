# Art production

Prompt books for **GPT-6 SOL**, the image model that draws the game's art.
Each book is a page of copy-ready prompts with shared rules, timings,
checklists and fixes. It is built from data, the same way as the books in
the MetroidVania repo.

## Book 1: Cowl and the Buried Mansion

| | |
| --- | --- |
| Page (open in any browser) | [cowl-prompt-book.html](cowl-prompt-book.html) |
| Cards (the data) | [`tools/docs/prompt_book_data.py`](../../tools/docs/prompt_book_data.py) |
| Builder | [`tools/docs/build_prompt_book.py`](../../tools/docs/build_prompt_book.py) |
| Images to attach | [`attach/`](attach/): A, Cowl's mockup; B, the mansion cutaway; C, the four-storey mansion; D and E, screenshots of the game to repaint; `plates/`, the room plates the game uses now |
| Review log | [sol-review.md](sol-review.md) |

79 cards in three sets:

- **World (W0 to W47)**, sized to the game as built (`game/level/level_art.gd`, 64-px tiles):
  - two target renders that repaint real screenshots of the game (the bedroom, the grand hall) and a materials sheet;
  - three parallax layers and the flooded vaults;
  - the skin over the collision: earth fill, floor tops, ceilings with hanging moss, wall faces, corners, doorways and floor holes, the grand stair kit (ramps at 1 in 2, a fallen flight at 45°) and iron railings;
  - piers, vault shoulders and ribs, and windows;
  - a back wall for each room mood;
  - every piece of furniture the collision makes solid, at its box size;
  - the root locks, lifts, levers, sealed and secret doors, rest candles, the knife's block and the stalagmites;
  - candelabra, the candle flame, hanging moss and wear;
  - the room plates, repainted at twice their size.
- **Cowl (H0 to H25):**
  - the look: H0 turns the mockup, which is canon, to the game's side view, and H1 to H3 lock the model, eye states and key poses;
  - the sway-and-bob idle, the blunt and bong smoke breaks with a chilled idle and a snap-out;
  - the ninja run, the jump with its flip, and two landings;
  - the jab, cross and spinning back kick, and the flying kick;
  - hurt, death and reforming from soot, the wall grip and the stomp;
  - side-view parts for the game's cut-out rig.
- **Effects (F1 to F5):** strike trails, hit sparks, soot, smoke, and the
  flares on his fist or foot (tinted his eye cyan) with knuckle soot.

The standard is grounded and top-tier: real body mechanics, limbs that keep
their length, no comic gags, everything painted to match the mansion
mockups. The builder refuses cards that ask for rubber stretching or gags.

Start with W0, then W1 and W2, then the parallax and the terrain. For Cowl,
H0 to H3, then the pilots H4 (idle), H12 (run), H14 (jump) and H16 (jab).

### Rebuild after changing a card

```bash
python3 tools/docs/build_prompt_book.py
```

The builder checks every card first and writes nothing if one fails. It
checks that each animation card has one frame per cell, that its stated
timing matches its frames, that everything it attaches exists and comes
earlier in the book, that no copied prompt is too long, and that no card
asks for the cartoon direction the creative lead rejected. To run only the
checks:

```bash
python3 tools/docs/build_prompt_book.py --check
```

After rebuilding, republish the page to the same link, with the `attach/`
images published beside it at the same paths.

## The asset contract

- **World masters** are 128 px per tile. The game's tile is 64 px, so it
  shows them at half size; they stay sharp on large screens and when the
  camera zooms.
- **Collision lines** run 64 px into each tiling piece: floor tops from a
  band's top, ceilings from a band's bottom, walls from a strip's open side.
  Stairs climb 1 tile per 2, plus one fallen flight at 45°. All lines are
  perfectly straight.
- **Furniture** fills its collision box exactly, its top flat and walkable.
- **Character cells** are 512 × 512 px masters, four columns wide, halved to
  256 px in the game.
- **Cowl** is about 256 px tall in a master and about 128 px (2 tiles) in
  the game. The anchor sits between his feet at (256, 400) in each master
  cell.
- **Facing and timing:** everything is drawn facing right, at 60 ticks a
  second.
- **Backgrounds** are transparent, except the parallax, back walls and
  target renders. If SOL cannot do transparency, it uses flat pure magenta
  `#FF00FF`.
- **Files:** masters go in `assets/source/world/`, `assets/source/cowl/` and
  `assets/source/fx/`. Repainted plates replace `assets/plates/`.

## The game, and what is left for it

- **The space** is the other session's layout (`tools/mansion_layout.py`),
  still awaiting review. The tiling pieces fit any shape. The furniture
  pieces are drawn to today's collision boxes.
- **Cowl in the game** is a cut-out rig built from the front-view mockup
  and animated in code (`game/player/cowl_rig.gd`). The sheets can replace it
  move by move; H25 gives the rig side-view parts in the meantime.
- **The bare-handed 1-2 and kick** are not in the controller yet. The game
  has the knife swings and the dodge.
