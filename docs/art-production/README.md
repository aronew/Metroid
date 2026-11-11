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
| Images to attach | [`attach/`](attach/): A, Cowl's mockup; B, the mansion cutaway; C, the four-storey mansion |
| Review log | [sol-review.md](sol-review.md) |

56 cards in three sets:

- **Cowl (H0 to H25):** the look (H0 turns the mockup, which is canon, to
  the game's side view; H1 to H3 lock the model, eye shapes and key poses), the
  sway-and-bob idle, the blunt and bong smoke breaks with a chilled idle
  and a snap-out, the ninja run, the jump with its flip and hang time, two
  landings, the jab, cross and spinning back kick, the flying kick, hurt,
  death and reforming from soot, the wall, the dive stomp, and rig parts
  for a cut-out rig.
- **Effects (F1 to F5):** strike trails, hit sparks, soot, smoke, and the
  flares on his fist or foot (tinted his eye cyan) with knuckle soot, which
  make his bare charcoal hands read against dark walls.
- **World (W0 to W24):** a target render at play scale, a materials sheet,
  a tiling terrain kit (earth fill, floor, ceiling and wall edges, corners,
  stairs, platforms, breakable floors), architecture, props by room type,
  candle flames, swaying moss, the foreground root frame and parallax
  layers.

Start with H0, then H1 to H3; the pilots are H4 (idle), H12 (run), H14
(jump) and H16 (jab). For the world, W0 first.

### Rebuild after changing a card

```bash
python3 tools/docs/build_prompt_book.py
```

The builder checks every card first and writes nothing if one fails. It
checks that each animation card has one frame per cell, that its stated
timing matches its frames, that everything it attaches exists and comes
earlier in the book, and that no copied prompt is too long. To run only the
checks:

```bash
python3 tools/docs/build_prompt_book.py --check
```

After rebuilding, republish the page to the same link, with the `attach/`
images published beside it at the same paths.

## The asset contract

The game-side numbers are provisional until the space and the camera are
final. The masters do not depend on them, because everything is drawn to
Cowl's scale.

- Character cells are 512 × 512 px masters, four columns wide, halved to
  256 px in the game.
- Cowl is about 240 px tall to the top of the beanie in a master (about
  120 px in the game).
- The anchor sits between his feet at (256, 400) in each master cell. His
  soles rest on that line. Airborne frames keep his centre near (256, 300).
- Everything is drawn facing right, at 60 ticks a second.
- Backgrounds are transparent. If SOL cannot do transparency, it uses flat
  pure magenta `#FF00FF`.
- World pieces are drawn with Cowl at 240 px: 1 tile is 128 px on the
  masters and 64 px in the game (provisional).
- Masters go in `art/source/hero/`, `art/source/fx/` and
  `art/source/world/`, saved under each card's file name.

## The space

The mansion's layout is being blocked out in another session: rooms carved
from solid mass, floors joined by stairs, a tower at each end. The world
cards are a modular kit at Cowl's scale, sorted by the room types in that
draft, so they fit whatever shape the space ends up. Room-by-room dressing
waits until the blockout is final.
