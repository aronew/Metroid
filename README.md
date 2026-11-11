# Cowl

A 2D Metroidvania. This repository holds the first vertical slice: Cowl as a
playable character, his movement and butcher-knife combat, and the mansion he
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
| Dodge | Shift, K or C | B, RB or RT |
| Swing the knife | J or X (hold Up to swing overhead) | X |
| Look / use | E or Enter | Y |
| Peek up / down | hold W / S while standing | hold stick up / down |

Debug: **F1** movement tuning panel and live read-out, **F2** switch between
the mansion and the lab, **F3** show collision, **F4** fly, **F5** give the knife.

## What is in the slice

- **Cowl**, built from the approved character mockup. The rig is the original
  pixels cut into parts (`tools/build_cowl_parts.py`); nothing was redrawn.
  Idle, walk, run, turn, jump, rise, fall, land, dodge, three knife swings,
  air swing, hurt, death and waking are animated procedurally from the
  controller's state, so the body always follows the physics.
- **The controller** (`game/player/cowl.gd`). Every number lives in one
  resource, `MovementConfig`, with three presets to compare in the lab.
- **The mansion**: 20 named spaces on five levels, from the attic to the sealed
  laboratory door. The opening runs bedroom, hallway, grand hall, the rooms,
  the pantry and the knife, the basement, the hidden way behind the boiler,
  the vault, and father's lift back up into his study.
- **The art pass** (`game/level/level_art.gd`): the painted interiors of the
  two environment mockups, cut out as room plates (`tools/build_env_assets.py`),
  set into ink architecture, parallax arcades, candlelight and dust.

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
assets/source   the supplied mockups, untouched
docs/           design notes, blockout drawings, test reports
```

Levels are authored as rectangles in `tools/mansion_layout.py` (mass first,
rooms carved out, a few masses put back) and exported to JSON. Collision and
decoration are separate: `level.gd` builds only what collides; `level_art.gd`
dresses the same data.

## Checks you can run

```bash
python3 tools/mansion_layout.py     # rebuild the level data and the blockout drawings
python3 tools/validate.py           # walk the mansion with the real controller (about 3 minutes)
godot --headless --path . res://tests/feel_test.tscn    # measure the controller
godot --headless --path . res://tests/slice_test.tscn   # play the mechanics end to end
```

Reports land in `docs/`. See `docs/design/mansion.md` for the design, the
lock-and-key plan and what the checks found.

## What is placeholder

Stated plainly, so nothing here is mistaken for finished art:

- **Creatures** (crawler, drifter) are ink silhouettes with lit eyes. No
  creature art was supplied.
- **The butcher knife** was drawn for this slice in Cowl's line style; there
  was no knife in the supplied art.
- **Architecture outside the painted plates** (walls, windows, shelves,
  columns, railings, the vault door, lifts, candlesticks) is drawn in code in
  the mockups' palette. It is a stand-in skin over approved-for-review
  collision, not final environment art.
- **Sound** is synthesised (`tools/build_sfx.py`). There is no music.
- **Text** in the house is first-draft writing.
