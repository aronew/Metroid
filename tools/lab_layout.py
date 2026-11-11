"""The movement laboratory: a plain room of measured tests.

Nothing here is level design. Each station isolates one property of the
controller so two configurations can be compared on the same ground:
a sprint strip, gaps of known width, rises of known height, ramps, a low
ceiling, a corner to bump, one-way ledges, a long drop, and a dummy to hit.
"""
import os
from levelkit import Level

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "levels", "lab")

L = Level("movement_lab", 200, 60)
F = 40                      # the main floor line

# The hall: one long room.
L.carve(4, 14, 192, F - 14)
L.room("movement lab", 4, 14, 192, F - 14)
L.spawn = (10, F)

# 1. Sprint strip with tile marks: acceleration, top speed, stopping, turning.
L.label(8, F + 0.4, "SPRINT STRIP - marks every 5 tiles")
for i in range(0, 30, 5):
    L.entity("note", 8 + i, F, text=str(i), w=0.1, h=0.5)

# 2. Gaps of 3, 4, 5, 6 and 7 tiles (pits four deep, with a way out).
x = 42
for gap in (3, 4, 5, 6, 7):
    L.carve(x, F, gap, 4)
    L.label(x, F + 4.3, "gap %d" % gap)
    x += gap + 7
L.carve(34, F + 3, x - 34 - 7, 3)          # a shared trench under the pits
L.carve(28, F, 6, 6)
L.stair(28, F, 34, F + 6)                   # walk out to the west
L.label(42, F - 2.2, "GAPS")

# 3. Rises of 1, 2, 3, 4 tiles: separate blocks to jump onto.
x = 96
for rise in (1, 2, 3, 4):
    L.fill(x, F - rise, 4, rise)
    L.label(x, F - rise - 1.2, "rise %d" % rise)
    x += 9
L.label(96, F - 7, "RISES")

# 4. Ramps: 1:2 (a grand stair) and 1:1 (a service stair), up and over.
L.stair(134, F, 142, F - 4)
L.fill(142, F - 4, 4, 4)
L.stair(146, F - 4, 150, F)
L.label(134, F - 6.5, "RAMPS 1:2 and 1:1")

# 5. Low ceiling (3 tiles) then a corner to bump from below.
L.fill(154, F - 9, 10, 6)
L.label(154, F - 10.5, "LOW CEILING 3")
L.fill(168, F - 6, 3, 2)
L.label(167, F - 7.5, "CORNER BUMP")

# 6. One-way ledges, and a tall shelf to drop from.
L.oneway(174, F - 3, 5)
L.oneway(181, F - 6, 5)
L.fill(188, F - 14, 8, 14)
L.oneway(184, F - 9, 4)
L.oneway(180, F - 12, 4)
L.label(174, F - 15.5, "ONE-WAY LEDGES / LONG DROP 14")

# 7. The dummy.
L.entity("dummy", 20, F)
L.entity("dummy", 25, F)
L.label(22, F - 4, "DUMMIES")

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    L.export(os.path.join(OUT, "lab.json"))
    L.draw(os.path.join(HERE, "..", "docs", "blockouts", "lab-blockout.png"), scale=10, title="Movement lab")
    print(L.measure())
