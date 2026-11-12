# Cowl

A 2D Metroidvania. This repository holds the first vertical slice: Cowl as a
playable character, his movement and hand-to-hand combat, and the mansion he
wakes up in. Built in **Godot 4.6** (GL Compatibility renderer).

## Run it

1. Install Godot 4.6 or newer (standard build, no .NET needed).
2. Open `project.godot`, let it import, press **F5**.

Or from a terminal:

```bash
godot --path .
```

To start in the movement laboratory instead of the mansion:

```bash
godot --path . -- --level=lab
```

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | A / D or arrows | left stick (half tilt walks) or d-pad |
| Jump (hold for height) | Space or Z | A |
| Drop through a thin ledge | Down + Jump | Down + A |
| Dodge | Shift, K or C | B or RT |
| Strike (press again: jab, cross, spin back kick; in the air: flying kick) | J or X | X |
| Knife, once found (cuts roots; stand-in frames until its sheets arrive) | L or V | RB |
| Look / use | E or Enter | Y |
| Peek up / down | hold W / S while standing | hold stick up / down |

Debug: **F1** movement tuning panel and live read-out, **F2** switch between
the mansion and the lab, **F3** show collision, **F4** fly, **F5** give the knife,
**F6** black blocks only (hide the edge art).

## What is in the slice

- **Cowl**, from the supplied animation sheets (H4-H20), cut and registered
  by `tools/build_cowl_sprites.py`, drawn frame by frame. Clips: idle, chilled
  idle, start, run, skid stop, turn, jump (with a forward flip on a full
  jump), fall, landing and heavy landing, jab, cross, spin back kick, air
  kick, the stance transitions, and two smoke breaks he takes if left
  standing (blunt or bong, with snap-ready recoveries). Strike trails, impact
  flashes, flares, soot and smoke come from the effect sheets (H12, H21-H23).
  The animator (`game/player/cowl_rig.gd`) reads the controller every physics
  tick, so the contact frame is on screen exactly while the hitbox is live.
- **Combat** is hand to hand: jab, cross and spin back kick as a string, and
  a flying kick. The butcher knife, found in the pantry, goes on its own
  button: a two-swing string and an air swing, and the only thing that cuts
  the roots that block doors and bind levers. Its swings play stand-in
  frames until its own sheets arrive.
- **The controller** (`game/player/cowl.gd`). Every number lives in one
  resource, `MovementConfig`, with three presets to compare in the lab.
- **The mansion**: 20 named spaces on five levels, from the attic to the sealed
  laboratory door. The opening runs bedroom, hallway, grand hall, the rooms,
  the pantry and the knife, the basement, the hidden way behind the boiler,
  the vault, and father's lift back up into his study.
- **The art pass** (`game/level/level_art.gd`) is deliberately plain: the
  collision mass in black, its edges dressed with the kit's floor tops,
  ceilings, wall faces and corners, the staircases, ledges, and the kit's
  parallax arcades behind. **F6** hides the edge dressing to show the black
  blocks alone. Gameplay pieces (roots, lifts, levers, doors, candles, the
  knife's block) keep their kit art. The painted room plates, wreckage, room
  walls, windows and decorations were removed; their cut pieces stay in
  `assets/kit` for later.

## How it is put together

```
game/player     Cowl: controller, rig, movement presets
game/camera     the follow camera
game/level      level loader (collision) and art pass (never collides)
game/world      vines, knife, lifts, levers, doors, candles, fixtures
game/enemies    crawler, drifter, training dummy
game/combat     hurtboxes, contact damage, hit and dust effects
game/ui         HUD and the F1 tuning panel
levels/         level data as JSON (written by the tools, loaded by the game)
tools/          Python: level layouts, validation, art and sound builders
tests/          scripted tests that drive the real controller
assets/source   the supplied mockups and the environment kit, untouched
assets/kit      the kit cut into pieces (tools/build_kit.py)
docs/           design notes, blockout drawings, test reports
```

Levels are authored as rectangles in `tools/mansion_layout.py` (mass first,
rooms carved out, a few masses put back) and exported to JSON. Collision and
decoration are separate: `level.gd` builds only what collides; `level_art.gd`
dresses the same data.

## Checks you can run

```bash
python3 tools/build_kit.py          # cut the environment kit
python3 tools/build_cowl_sprites.py # cut Cowl's frames and effects
python3 tools/mansion_layout.py     # rebuild the level data and the blockout drawings
python3 tools/validate.py           # walk the mansion with the real controller (about 3 minutes)
godot --headless --path . res://tests/feel_test.tscn    # measure the controller
godot --headless --path . res://tests/slice_test.tscn   # play the mechanics end to end
```

Reports land in `docs/`. See `docs/design/mansion.md` for the design, the
lock-and-key plan and what the checks found.

## What is placeholder

Stated plainly, so nothing here is mistaken for finished art:

- **Dodge, hurt and death** have no drawn frames yet; they reuse run, fall
  and heavy-landing frames with code motion. **Waking** reuses idle frames
  laid on the bed.
- **Creatures** (crawler, drifter) are ink silhouettes with lit eyes.
- **Sound** is synthesised (`tools/build_sfx.py`). There is no music.
- **Text** in the house is first-draft writing.

See `docs/character-integration.md` for what each character sheet is used
for, what was changed and what is still needed.
