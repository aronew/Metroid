"""The mansion: Cowl's home, sunk into the earth. Collision blockout.

Mass first. The house is one solid block; every room is a rectangle carved out
of it and every piece of furniture the player can stand on is a rectangle put
back. Stairs are single ramps. Placed pieces are few and each has a job.

Floors (walking lines, in tiles, y down):
    attic 16 | upper floor 28 | main floor 41 | basement 54 | lab level 66

Movement envelope this was built for (measured by tests/feel_test, default
preset): full jump rises 3.5 tiles, a 3-tile block is reachable and a 4-tile
block is not; a 6-tile gap is the most a perfect running jump clears and 7 is
a wall. Required jumps here are rise <= 3 and gap <= 4.

Run:  python3 tools/mansion_layout.py
"""
import os
from levelkit import Level

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "levels", "mansion")
DOCS = os.path.join(HERE, "..", "docs", "blockouts")

W, H = 256, 76
ATT, F2, F1, B1, B2 = 16, 28, 41, 54, 66       # floor lines
L = Level("mansion", W, H)


def door(x, floor, h=4, w=2):
    """A doorway through a wall, its sill on the floor line."""
    L.carve(x, floor - h, w, h, "door")
    L.prop("frame", x, floor, w=w, h=h)


def ledge(x, y, w, note=""):
    """A one-way ledge Cowl can jump up through: a shelf, a beam, a canopy.
    Every one is a piece of the house, named for what it is."""
    L.oneway(x, y, w, kind="ledge", note=note)


def note(x, y, text, w=3):
    """Something to read, left where the climb ends: the reward for going up."""
    L.entity("hint", x, y, w=w, h=3, text=text, interact=True, paper="note")


def vine(x, floor, h=4, name=""):
    """Overgrowth across a doorway. The butcher knife cuts it."""
    L.entity("vine", x, floor, w=1, h=h, name=name)


# =========================================================== UPPER FLOOR (28)
# --- West tower: a tall shaft. Climbing it is a later ability. --------------
L.carve(8, 6, 10, F2 - 6)
L.fill(8, 14, 4, 2)                                 # high ledge: seen, not reached
L.carve(9, F2, 4, 3)                                # well down to the conservatory
L.room("west tower", 8, 6, 10, F2 - 6, tint=(90, 120, 200), mood="tower")
L.entity("glint", 10, 14, name="tower ledge")
door(18, F2)
vine(18.5, F2, name="V1 bedroom west door")

# --- Cowl's bedroom: everything slid east when the house tilted. ------------
L.carve(20, 19, 28, 9)
L.fill(33, 26, 5, 2)                                # toppled wardrobe (rise 2)
L.fill(41, 25, 7, 3)                                # the heap against the east wall
L.carve(48, 21, 2, 4, "breach")                     # the way out is over the heap
ledge(21, 25, 4, "the bed's canopy")
ledge(27, 22, 4, "a bookshelf on the wall")
note(28, 22, "Behind the books, a drawing in his own hand: the house, and a circle hanging over it.")
L.room("Cowl's bedroom", 20, 19, 28, 9, mood="bedroom")
L.spawn = (24.3, F2)
L.entity("checkpoint", 24.3, F2, kind="bed", w=5, h=2)
L.entity("hint", 21, F2, w=9, h=5, text="", when="asleep", prompt="Press any key")
L.entity("hint", 28, F2, w=5, h=5, text="", prompt="Jump  [Space]   hold to jump higher")
L.entity("hint", 60, F2, w=5, h=5, text="", prompt="Strike  [J]   press again to string jab, cross and kick")

# --- Upstairs hallway: the floor has fallen into the dining room. -----------
L.carve(50, 19, 36, 9)
L.fill(50, 25, 5, 3)                                # fallen cabinet under the breach
L.carve(66, F2, 4, 3, "hole")                       # the collapse (4 wide: jump it or fall)
ledge(57, 25, 4, "a picture rail, fallen to one nail")
ledge(63, 23, 3, "a door torn off and wedged across")
ledge(68, 25, 4, "joists over the collapse")
ledge(75, 22, 3, "a high shelf")
ledge(80, 24, 3, "a console table on the wall")
L.carve(86, 21, 2, 7, "arch")                       # arch onto the gallery
L.room("upstairs hallway", 50, 19, 36, 9, mood="hall_upper")

# ================================================================ GRAND HALL
L.carve(88, 7, 60, F1 - 7)
L.room("grand entrance hall", 88, 7, 60, F1 - 7, mood="grand_hall")
L.zone(88, 7, 60, F1 - 7 + 1, zoom=0.68, oy=-1.5)
L.fill(88, F2, 14, 2)                               # west gallery
L.stair(102, 28, 105, 29.5, thick=1.5, note="upper flight, top stub")
L.stair(109, 31.5, 114, 34, thick=1.5, note="upper flight, lower remnant")
L.fill(114, 34, 12, 2)                              # the mezzanine
L.stair(126, 34, 140, F1, note="grand flight down to the east floor")
L.stair(136, 28, 129, 31.5, thick=1.5, note="east flight: broken, hangs short of the mezzanine")
L.fill(136, F2, 12, 2)                              # east gallery
# The middle of the upper flight fell and lies as a mound on the west floor:
L.stair(93, F1, 106, 34.5, note="fallen flight, up")
L.stair(106, 34.5, 112.5, F1, note="fallen flight, down")
L.fill(126, ATT, 22, 2)                             # roof truss: the high way east
ledge(104, 25, 3, "a balcony bracket")
ledge(108, 22, 3, "a chandelier, hung low")
note(108.5, 22, "Up here the dust is undisturbed. Below, the hall: years of it, and no footprints but yours.")
L.fill(89, 38, 3, 3)                                # a statue's plinth by the dining-room door
ledge(143, 37, 4, "the porter's shelf by the front door")
door(86, F1)                                        # dining room
door(148, F1)                                       # living room
door(148, F2)                                       # sister's room
L.carve(148, 12, 2, 4, "attic opening")
L.entity("lift", 117, 34, w=5, top=ATT, bottom=34, start="top", kind="chandelier", name="chandelier")
L.entity("lever", 124.5, 34, lift="chandelier", bound=True, name="V8 chandelier winch")
L.entity("checkpoint", 119, F1, kind="rest", w=2, h=2)
L.entity("hint", 90, F2, w=10, h=5, text="", prompt="Dodge  [Shift]")
L.entity("front_door", 141.2, F1, w=6, h=8.5)

# --- East upper floor --------------------------------------------------------
L.carve(150, 19, 26, 9)                             # sister's room
L.fill(159, 25, 6, 3)                               # her bed, on its side
L.fill(170, 22, 6, 6)                               # wardrobe against the east wall
L.carve(171, ATT, 4, 3, "hatch")                    # attic hatch: a way down, not up
ledge(152, 25, 4, "a shelf over the door")
ledge(157, 22, 3, "a hanging mobile, stars and moons")
ledge(165, 22, 4, "the top of her bookcase")
L.room("sister's room", 150, 19, 26, 9, mood="bedroom")
door(176, F2)
vine(176.5, F2, name="V4 sister's room to library gallery")

L.carve(178, 19, 28, F1 - 19)                       # the library, two storeys
L.fill(178, F2, 9, 2)                               # west gallery
L.fill(199, F2, 7, 2)                               # east gallery
# The library stair: one flight from the west gallery down toward the floor.
# It stops three tiles short, over a heap of fallen books, so the floor runs
# on beneath the whole flight and the room stays one room.
L.stair(187, F2, 196, 37, thick=1.5, note="library stair")
L.fill(197, 39, 3, 2)                               # the books that fell from the shelves: a step
ledge(191, 25, 3, "a hanging lamp")                 # the crossing between galleries:
ledge(195.5, 25.5, 3, "a hanging lamp")             # lamps on chains
L.fill(181, 39, 4, 2)                               # reading table
L.room("library", 178, 19, 28, F1 - 19, mood="library")
L.zone(178, 19, 28, F1 - 19 + 1, zoom=0.8)
L.entity("hint", 195.5, 25.5, w=3, h=3, text="A ledger, swollen with damp. Most of it is in a code of his own.\nOne line is not: \"density is a choice the sphere makes for you.\"", interact=True, paper="note")
door(176, F1)
vine(176.5, F1, name="V3 living room to library")
door(206, F1)
door(206, F2)

L.carve(208, 19, 26, 9)                             # parents' bedroom
L.fill(214, 26, 8, 2)                               # the big bed
ledge(215, 23, 6, "the bed's canopy")
ledge(224, 22, 3, "a picture ledge")
ledge(229, 24, 3, "a shelf by the door")
L.room("parents' bedroom", 208, 19, 26, 9, mood="bedroom")
door(234, F2)

L.carve(236, 5, 10, F1 - 5)                         # east tower
L.fill(236, F2, 4, 2)                               # landing from the bedroom
L.fill(242, 11, 4, 2)                               # high ledge: seen, not reached
L.room("east tower", 236, 5, 10, F1 - 5, tint=(90, 120, 200), mood="tower")
L.zone(236, 5, 10, F1 - 5 + 1, zoom=0.8)
L.entity("glint", 244, 11, name="tower ledge")
door(234, F1)

# --- Attic (east): reached by riding the chandelier -------------------------
L.carve(150, 9, 84, 7)
L.fill(186, 13, 6, 3)                               # trunks
L.fill(210, 14, 8, 2)
ledge(166, 13, 4, "a rafter")
ledge(176, 12.5, 3, "a rafter")
ledge(200, 12.5, 4, "a rafter")
L.carve(234, 12, 2, 4, "to tower")
L.fill(236, ATT, 3, 2)                              # sill inside the tower
L.room("attic", 150, 9, 84, 7, mood="attic")
L.entity("drifter", 200, 12)
L.entity("drifter", 224, 12)
L.entity("hint", 160, ATT, w=6, h=4, text="Boxes of winter coats. Four of everything.", interact=True, paper="letter")

# ============================================================ MAIN FLOOR (41)
L.carve(8, 31, 26, 10)                              # conservatory
L.fill(14, 39, 3, 2)                                # planter
L.fill(18, 38, 6, 3)                                # the root that came through the glass
L.fill(26, 39, 4, 2)                                # planter
ledge(19, 35, 4, "a branch of the root")
ledge(25, 34, 3, "a hanging basket")
L.room("conservatory", 8, 31, 26, 10, tint=(60, 160, 90), mood="conservatory")
L.entity("biome_door", 8.4, F1, w=3.6, h=6.3, name="overgrown door")
door(34, F1)
vine(34.5, F1, name="V6 kitchen to conservatory")

L.carve(36, 31, 24, 10)                             # kitchen
L.carve(44, F1, 5, 3, "hole")                       # the floor gave way under the butcher's block
L.carve(52, F1, 4, 3, "lift shaft")
ledge(38, 38, 3, "a shelf of jars")
ledge(43, 35, 5, "the pot rack, over the hole")
L.room("kitchen", 36, 31, 24, 10, mood="kitchen")
L.entity("family", 42.7, F1, who="mother")
L.entity("lift", 52, F1, w=4, top=F1, bottom=B1, start="top", kind="dumbwaiter", name="dumbwaiter")
L.entity("lever", 57, F1, lift="dumbwaiter", bound=True, name="V2 dumbwaiter (kitchen)")
door(60, F1)

L.carve(62, 31, 24, 10)                             # dining room
L.fill(65, 39, 6, 2)                                # fallen ceiling, under the hole
ledge(73, 38.5, 8, "the dining table")
ledge(76, 35.5, 3, "the chandelier")
L.room("dining room", 62, 31, 24, 10, mood="dining")
L.entity("family", 77.3, F1, who="sibling")
L.entity("hint", 81, F1, w=3, h=3, text="A place card: COWL. The chair is pushed in. Dust on the plate, thick as felt.", interact=True)

L.carve(150, 31, 26, 10)                            # living room
L.fill(165, 38, 4, 3)                               # toppled bookshelf
L.fill(170, 35, 6, 2)                               # mantel shelf over the east door
ledge(155, 38, 3, "a sideboard")
ledge(160, 35, 3, "a picture ledge")
L.room("living room", 150, 31, 26, 10, mood="living")
L.entity("hint", 172, 35, w=3, h=3, text="The family portrait. Four figures. Someone has drawn a small circle above the house.", interact=True)

L.carve(208, 31, 26, 10)                            # father's study
L.carve(229, F1, 4, B2 - F1, "lift shaft")
ledge(210, 37, 4, "a library step")
ledge(214, 34, 4, "the top of the shelves")
note(214.5, 34, "Pinned above the shelves: a sketch of a sphere, and in his hand, NOT FOR THE HOUSE.")
L.room("father's study", 208, 31, 26, 10, mood="study")
L.entity("family", 217, F1, who="father")
L.entity("bookcase_door", 228, F1, w=1, h=10, name="study bookcase")
L.entity("lift", 229, B2, w=4, top=F1, bottom=B2, start="bottom", kind="cage", name="study lift")
L.entity("hint", 219, F1, w=6, h=4, text="His notes stop mid-word. The ink has had years to fade.", interact=True, paper="note")

# ============================================================== BASEMENT (54)
L.carve(36, 44, 24, 10)                             # pantry and cold room
L.fill(43, 52, 7, 2)                                # what fell from the kitchen
ledge(37, 50, 3, "a cold shelf")
L.room("pantry", 36, 44, 24, 10, mood="pantry")
L.entity("knife", 39.5, B1)
L.entity("lever", 57.5, B1, lift="dumbwaiter", bound=True, name="V2b dumbwaiter (pantry)")
L.entity("hint", 37, B1, w=6, h=4, text="", when="knife", prompt="The knife  [L]   cuts roots, and hits harder than a fist")
door(60, B1)
vine(60.5, B1, name="V5 pantry to storage")

L.carve(62, 44, 24, 10)                             # storage
L.fill(68, 51, 5, 3)                                # crates
L.fill(77, 48, 6, 6)                                # barrel rack
L.fill(83, 51, 3, 3)                                # a keg on its far side: the way back over
ledge(64, 49, 3, "a shelf of preserves")
ledge(72, 47.5, 3, "a beam over the crates")
L.room("storage rooms", 62, 44, 24, 10, mood="storage")
L.entity("crawler", 65, B1)
L.entity("crawler", 80, 48)
L.carve(86, 48, 2, 6, "arch")

L.carve(88, 44, 60, 10)                             # the undercroft, under the hall
L.fill(98, 51, 5, 3)                                # fallen vault stone
L.carve(116, B1, 4, 2, "trench")                    # stalagmites
ledge(106, 50, 3, "a fallen rib of the vault")
ledge(111, 47.5, 3, "a vault rib")
ledge(117, 49.5, 3, "a beam across the stalagmites")
ledge(123, 50.5, 3, "a broken rib")
L.fill(140, 48, 8, 2)                               # high ledge and its door: a later ability
L.room("undercroft", 88, 44, 60, 10, mood="undercroft")
L.zone(88, 44, 60, 11, zoom=0.85)
L.entity("spikes", 116, B1 + 2, w=4, h=1)
L.entity("crawler", 108, B1)
L.entity("crawler", 130, B1)
L.entity("drifter", 124, 48)
L.entity("biome_door", 144.4, 48, w=2.3, h=3.9, name="door on the high ledge")
door(148, B1)
vine(148.5, B1, name="V7 undercroft to workshop")

L.carve(150, 44, 26, 10)                            # workshop
L.fill(156, 51, 6, 3)                               # workbench
L.fill(166, 49, 5, 5)                               # the engine block
ledge(151, 50, 3, "a tool shelf")
ledge(162, 47.5, 3, "the beam of a chain hoist")
L.room("workshop", 150, 44, 26, 10, mood="workshop")
L.entity("crack", 160, B1, w=4, h=1, name="cracked floor")
L.entity("garage_door", 170, B1, w=5, h=5)
L.entity("checkpoint", 153, B1, kind="rest", w=2, h=2)
L.entity("crawler", 172, B1)
door(176, B1)

L.carve(178, 44, 28, 10)                            # boiler room
L.fill(182, 51, 6, 3)                               # coal bunker
L.oneway(189.5, 48.5, 3.5, kind="pipe")             # the one pipe you need
L.fill(194, 47, 8, 7)                               # the boiler
L.carve(203, B1, 3, 3, "hidden shaft")              # behind the boiler: the way down
L.room("boiler room", 178, 44, 28, 10, mood="boiler")
L.entity("false_wall", 202, B1, w=4, h=10, name="pipes hiding the gap")
L.entity("crawler", 188, B1)

# ============================================================ LAB LEVEL (66)
L.carve(190, 57, 44, 9)
ledge(198, 62, 4, "a gantry")
ledge(205, 60, 4, "a gantry")
ledge(213, 62, 3, "a gantry")
L.room("laboratory antechamber", 190, 57, 44, 9, tint=(60, 200, 220), mood="lab")
L.entity("lab_door", 190, B2, w=3, h=7)
L.entity("lever", 227, B2, lift="study lift", name="study lift call (lab)")
L.entity("checkpoint", 214, B2, kind="rest", w=2, h=2)

# ------------------------------------------------------------------ outputs
if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(DOCS, exist_ok=True)
    L.export(os.path.join(OUT, "mansion.json"))
    L.draw(os.path.join(DOCS, "mansion-1-collision.png"), scale=12, title="The mansion: collision blockout")
    # Play-scale windows: what one screen shows at four moments, Cowl to scale.
    for name, cx, cy in [("bedroom", 34, 24), ("hallway-hole", 68, 25), ("hall-mezzanine", 118, 31), ("boiler", 194, 49)]:
        L.draw_window(os.path.join(DOCS, "mansion-3-screen-%s.png" % name), cx, cy, scale=40)
    for k, v in L.measure().items():
        print("%-32s %s" % (k, v))
