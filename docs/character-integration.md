# Cowl's character sheets in the game

Two archives arrived on 12 November 2026:

| Archive | Sheets |
| --- | --- |
| Character sheets | H0 look development, H1 model, H2 expressions, H3 key poses, H4 idle, H5 chilled idle, H6-H8 the blunt (light, smoke loop, finish), H9-H10 the bong (hit, after), H11 snap-ready, H12 smoke and flame effects |
| Movement, combat, effects | H12 run, H13 start/stop/turn, H14 jump, H15 fall/land, H16 jab, H17 cross, H18 spin back kick, H19 air kick, H20 punch transitions, H21 strike trails, H22 impact flashes, H23 strike flares and soot |

The originals, their READMEs, timings and prompts are kept untouched in
`assets/source/cowl_sheets/`. (Both archives used the name H12 for different
sheets; they are told apart by their full names.)

`tools/build_cowl_sprites.py` cuts them into 216 frames in 24 clips and 52
effect frames (`assets/cowl/`, listed in `assets/cowl/cowl_anim.json`,
drawn registered on a floor line in `docs/cowl-clips.png`).

## What the builder changes

Nothing is repainted. Both READMEs say the sheets weren't exported at the
requested sizes and that scale and placement drift, so:

- **Scale is set per sheet from the beanie,** the one shape every frame shows.
  Standing, Cowl is 128 px tall in game (two tiles).
- **Each frame is registered on a stable feature.** Standing, running and
  idling frames use the eye slits. The jab and cross use the planted rear
  foot. The kick uses the standing foot. Airborne frames use the body's
  centre. Each clip is then shifted once so the body sits on the collision
  body's centre line.
- **Grounded frames stand on the floor line.** Airborne frames centre on the
  body.
- **Stray specks away from the figure are cleared,** and alpha under 12 is
  dropped.
- **Timing comes from the supplied tick lists.** Strike timings in the
  controller are set from them: contact frames are exactly the hitbox's live
  window.

## How each sheet is used

| Sheet | In the game |
| --- | --- |
| H0, H1, H2, H3 | Reference only (model, expressions, key poses) |
| H4 | Idle loop |
| H5 | The chilled idle he settles into after a break |
| H6, H7, H8 | Smoke break 1: light up, smoke (two loops), finish, then chill |
| H9, H10 | Smoke break 2: bong hit and after, then chill |
| H11 | Snap-ready: any input during a break flicks the blunt or bong away. If he moves, only the first beats play, so control is never delayed |
| H12 effects | Smoke wisps, exhales, rings and plume, and the lighter flame, timed to the break frames and placed at his face from each frame's own eye position |
| H12 run | The run loop (frames 1-8; see below), speed-matched to his actual speed |
| H13 | Start from standing, skid stop, and the turn (played when he reverses at speed) |
| H14 | Jump. A full jump flips forward as drawn. A tapped hop skips to the opening and apex frames. Set `FLIP_ON_JUMP` in `cowl_rig.gd` to false to never flip |
| H15 | Fall loop, landing, heavy landing (from long falls) |
| H16, H17, H18 | Jab, then cross, then spin back kick: one button, pressed in rhythm |
| H19 | Flying kick in the air |
| H20 | Run to guard (unused), guard to run, guard to idle |
| H21 | A trail on each strike's smear frame |
| H22 | Impact flashes: light on the jab, heavy on the cross and air kick, the finisher on the kick |
| H23 | A flare at each blow and soot drifting off it (H23_b as supplied, not yet repainted) |

## Combat changed: hand to hand

The sheets fight with fists and feet, so combat now does too. The
butcher knife is still found in the pantry. It is what cuts roots: before
it, strikes only shake them; with it, one strike cuts. The progression is
unchanged. Every gate, room and lock is where it was, and the mechanics
test covers both cases. This is my reading of the new sheets. If the knife
should be a weapon again, it needs its own swing sheets.

| Strike | Startup | Contact | Recovery | Damage | Notes |
| --- | --- | --- | --- | --- | --- |
| Jab | 3 ticks | 3 | 11 | 1 | chains to the cross |
| Cross | 4 | 3 | 11 | 1 | chains to the kick |
| Spin back kick | 10 | 6 | 13 | 2 | finisher: longer hit-stop, heavier knockback |
| Air kick | 2 | 9 | 7 | 1 | |

## The outfit

The new sheets dress Cowl differently from the first mockup:
- a torn cape with a brass clasp;
- a patched beanie;
- plum baggy trousers instead of red shorts.

I've taken the sheets as the current design and replaced the old cut-out
rig, its parts and its knife entirely. Nothing in the game still draws the
first mockup's outfit.

## Not drawn yet

These are clips the game needs, in order of how much they would help:

1. **Dodge.** He uses run frames with after-images. A dedicated low slip
   would be best: 6-8 frames, ground only, ending in a run stance.
2. **Hurt.** A fall frame, tilted and flashed. Wanted: 3-4 frames of recoil.
3. **Death.** The heavy landing's first frame, tipping over and fading.
   Wanted: 6-8 frames of collapse.
4. **Waking from bed.** Idle frames laid on the bed. Wanted: lying asleep
   (eyes shut), eyes opening, sitting up, swinging off the bed, and a
   landing on the floor.
5. **Run, second stride.** H12_Run_b is drawn more upright and larger than
   H12_Run_a, so mixing them made Cowl bob. The loop uses _a's eight frames.
   A redraw of frames 9-12 matching _a would complete the two-stride cycle.
6. **An up strike** (optional). There's no overhead attack now. The old
   knife rig had one.
7. **Interacting** (optional): reaching for a lever, picking the knife up,
   looking at something.

These come from the sheets' own READMEs and are still open:
- the H23_b soot reads as directional flares, not dispersed soot;
- some feet read as footwear;
- a few eye states are brighter than the rules allow.

They're visible only on close inspection at game scale.
