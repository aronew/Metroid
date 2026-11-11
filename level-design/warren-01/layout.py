"""Warren 01: an original blockout in the stacked-corridor grammar.

Rock first. Every space is a rectangle taken out of solid rock, every mass a
rectangle put back. Units are tiles; x runs right, y runs down.
Run build.py to export warren.json, validate it and draw it.
"""

W, H = 228, 118
TONGUE = 2  # rock between two lanes of one stack

spaces, masses, labels = [], [], []
water, crust, cling = [], [], []
doors, rewards = [], []


def carve(x, y, w, h, kind="lane"):
    spaces.append(dict(x=x, y=y, w=w, h=h, kind=kind))


def fill(x, y, w, h, kind="mass"):
    masses.append(dict(x=x, y=y, w=w, h=h, kind=kind))


def stack(top, lanes, gaps):
    """Lanes stacked with a thin tongue of rock between each pair.

    lanes: (x0, x1, height) from the top down.
    gaps:  for each pair, 'L' or 'R'. The opening is 5 wide and sits at that
           END of the LOWER lane, with a block under it against the end wall.
           A lane therefore never carries a block where it runs on: a block
           three tall in a lane four tall would seal it.
    Returns each lane as (x0, x1, y, floor).
    """
    out, y = [], top
    for (x0, x1, h) in lanes:
        carve(x0, y, x1 - x0, h)
        out.append((x0, x1, y, y + h))
        y += h + TONGUE
    for i, side in enumerate(gaps):
        (a0, a1, ay, af), (b0, b1, by, bf) = out[i], out[i + 1]
        g0 = b0 if side == "L" else b1 - 5
        assert a0 <= g0 and a1 >= g0 + 5, ("upper lane must cover the turn", i, lanes[i], lanes[i + 1])
        bh = 3 if bf - af >= 6 else 2
        carve(g0, af, 5, TONGUE, "turn")
        fill(g0 if side == "L" else g0 + 2, bf - bh, 3, bh, "turn-block")
    return out


def turn(x, floor_above, lower_floor, side):
    """One opening and its block, for places a stack() call does not cover."""
    bh = 3 if lower_floor - floor_above >= 6 else 2
    carve(x, floor_above, 5, TONGUE, "turn")
    fill(x if side == "L" else x + 2, lower_floor - bh, 3, bh, "turn-block")


# Each stack is one tall room cut into lanes by thin tongues of rock. The
# tongues reach in from alternate walls, so the walls stay straight and the
# variety comes from tongue lengths, lane heights, pockets and the jogs
# between groups of lanes. Turns strictly alternate sides: two turns on the
# same side make a staircase of blocks.

# --- West stack: an upper tower and a lower tower, offset -------------------
B = stack(12, [(18, 64, 4), (8, 56, 4), (18, 60, 3), (13, 56, 4), (18, 88, 4),
               (12, 62, 4), (26, 62, 3), (26, 62, 4), (26, 94, 4)],
          ["R", "L", "R", "L", "R", "L", "R", "L"])
carve(0, 12, 18, 4, "door")
doors.append(dict(x=0, y=12, h=4, name="west door"))
carve(12, 45, 4, 31, "shaft")                           # neck: pocket down to the twin stacks
rewards += [(62, 14), (10, 20), (15, 31)]
labels.append((30, 9, "west stack"))

# --- The long tunnel east passes through a knuckle --------------------------
carve(68, 30, 12, 5, "chamber")
labels.append((67, 28, "knuckle"))

# --- North shelves under the lamp hall --------------------------------------
C = stack(6, [(100, 150, 9), (100, 174, 4), (92, 150, 4), (100, 158, 4), (88, 150, 4)],
          ["L", "R", "L", "R"])
fill(136, 12, 6, 3, "plinth")                           # the lamp stands here
fill(145, 11, 5, 4, "ledge")                            # lookout over the hall
rewards.append((147, 10))
carve(154, 33, 4, 17, "shaft")                          # neck: shelf 3 down to the cistern
labels.append((112, 3, "lamp hall"))

# --- East stack: lanes wrapped round two thick islands ----------------------
D = stack(17, [(174, 218, 4), (174, 204, 4), (182, 224, 4), (182, 218, 4),
               (182, 222, 3), (190, 218, 4), (198, 228, 4), (166, 218, 4)],
          ["R", "L", "R", "L", "R", "L", "R"])
carve(214, 21, 4, 8, "shaft")                           # east drop past the upper island
carve(174, 27, 4, 31, "shaft")                          # west drop to the bottom lane
carve(166, 50, 8, 4, "tunnel")                          # side passage off the west drop
doors.append(dict(x=227, y=52, h=4, name="east door"))
rewards += [(222, 31), (192, 48)]
labels.append((188, 14, "east stack"))

# --- The cistern: the one large chamber -------------------------------------
carve(94, 50, 72, 22, "chamber")                        # floor 72
carve(120, 44, 26, 6, "chamber")                        # raised roof over the pool
fill(94, 62, 18, 10, "terrace")
fill(115, 60, 5, 12, "pillar")
fill(124, 59, 11, 13, "pier")
fill(139, 60, 5, 12, "pillar")
fill(147, 62, 19, 10, "shelf")
fill(158, 54, 8, 3, "balcony")
carve(147, 67, 13, 4, "pocket")                         # flooded pocket in the shelf
water.append(dict(x=112, y=64, w=35, h=8))
water.append(dict(x=147, y=67, w=13, h=4))
rewards.append((157, 69))
labels.append((124, 47, "the cistern"))

# lone room up the west wall (needs the wall cling)
carve(94, 43, 4, 7, "shaft")
carve(98, 43, 14, 3, "pocket")
cling.append(dict(x=94, y=43, w=4, h=19))
rewards.append((108, 45))
labels.append((99, 41, "lone room"))

# --- Junction, and the stair down into the twin stacks ----------------------
carve(70, 52, 14, 6, "chamber")                         # junction, two levels tall
ER = stack(64, [(52, 84, 4), (58, 90, 4), (10, 84, 4), (58, 208, 4)],
           ["L", "R", "L"])
carve(80, 62, 4, TONGUE, "turn")                        # junction floor down to the stair
fill(81, 65, 3, 3, "turn-block")
labels.append((72, 50, "junction"))
EL = stack(76, [(10, 84, 4), (16, 52, 4), (8, 46, 3), (16, 54, 4), (16, 46, 4)],
           ["L", "R", "L", "R"])
carve(16, 103, 4, 15, "door")                           # drop to the region below
doors.append(dict(x=16, y=112, h=4, name="south drop"))
rewards += [(88, 72), (10, 90), (52, 95)]
labels.append((24, 107, "twin stacks"))

# --- The short snake and the long walk --------------------------------------
F = stack(64, [(172, 216, 4), (172, 208, 4), (172, 220, 4)], ["R", "L"])
turn(172, 62, 68, "L")                                  # east stack's bottom lane into the snake
turn(203, 80, 86, "R")                                  # snake onto the long walk
carve(128, 76, 16, 6, "chamber")                        # low shrine on the long walk
fill(134, 83, 4, 3, "plinth")
rewards += [(214, 66), (218, 78)]
labels.append((178, 90, "the snake"))
labels.append((126, 74, "low shrine"))

# crust pocket under the long walk (opened by the crust-breaking dive)
carve(100, 89, 10, 3, "pocket")
carve(105, 86, 5, 3, "pocket")
fill(107, 89, 3, 3, "turn-block")
crust.append(dict(x=105, y=86, w=5, h=3))
rewards.append((102, 91))

START = (2, 15)
