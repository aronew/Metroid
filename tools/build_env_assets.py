"""Lift the painted rooms out of the environment mockups.

The two mansion mockups are the visual specification, and they are paintings,
not layered assets. This script cuts the painted interiors out of them as
"plates": the back wall of a room with its furniture, light and (where the
mockup shows them) the frozen family. Each plate is scaled so the mockup's
figures stand at Cowl's in-game scale, and its edges are feathered so it sits
into the wall behind it. Nothing is repainted.

    python3 tools/build_env_assets.py   ->  assets/plates/*.png, plates.json

Plates are placed by the level's art pass (game/level/level_art.gd) with
their floor line on the room's floor.
"""
import json, os
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "source")
OUT = os.path.join(HERE, "..", "assets", "plates")
WIDE = Image.open(os.path.join(SRC, "mansion_mockup_wide.png")).convert("RGB")
TALL = Image.open(os.path.join(SRC, "mansion_mockup_tall.png")).convert("RGB")
# Scale that brings each mockup's figures to in-game size (Cowl is 124 px).
S_WIDE, S_TALL = 2.1, 2.5

# name: (source, box, feather left/top/right/bottom as fractions, floor inset px)
PLATES = {
    "bedroom": (WIDE, (40, 128, 405, 347), (0.10, 0.22, 0.16, 0.0)),
    "living": (WIDE, (1258, 100, 1742, 353), (0.10, 0.22, 0.10, 0.0)),
    "kitchen": (WIDE, (160, 412, 622, 607), (0.12, 0.20, 0.12, 0.0)),
    "study": (WIDE, (1228, 400, 1742, 605), (0.10, 0.20, 0.10, 0.0)),
    "dining": (TALL, (345, 845, 700, 1046), (0.14, 0.22, 0.14, 0.0)),
    "storage": (TALL, (80, 1110, 400, 1302), (0.14, 0.22, 0.16, 0.0)),
    "flooded": (TALL, (640, 1090, 1050, 1302), (0.30, 0.34, 0.14, 0.0)),
    "bedroom2": (TALL, (790, 296, 990, 398), (0.14, 0.24, 0.14, 0.0)),
    "green_door": (WIDE, (1740, 160, 1852, 353), (0.20, 0.16, 0.20, 0.0)),
}


def ramp(n, frac):
    """0..1 over the first `frac` of n samples, then 1."""
    edge = max(1, int(n * frac))
    r = np.ones(n, np.float32)
    if frac > 0:
        t = np.linspace(0, 1, edge)
        r[:edge] = t * t * (3 - 2 * t)
    return r


meta = {}
for name, (img, box, feather) in PLATES.items():
    s = S_WIDE if img is WIDE else S_TALL
    crop = img.crop(box)
    size = (round(crop.width * s), round(crop.height * s))
    up = crop.resize(size, Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=2.2, percent=55, threshold=2))
    w, h = size
    ax = ramp(w, feather[0]) * ramp(w, feather[2])[::-1]
    ay = ramp(h, feather[1]) * ramp(h, feather[3])[::-1]
    alpha = (np.outer(ay, ax) * 255).astype(np.uint8)
    rgba = np.dstack([np.asarray(up), alpha])
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, name + ".png"))
    # the colour the plate fades into, for the wall behind it
    a = np.asarray(up).astype(np.float32)
    lum = a.sum(axis=2)
    wall = a[lum > np.percentile(lum, 55)].mean(axis=0)
    meta[name] = dict(file=name + ".png", size=[w, h], wall=[round(float(c) / 255, 3) for c in wall])
    print("%-11s %4dx%-4d  %.1f x %.1f tiles" % (name, w, h, w / 64, h / 64))

json.dump(meta, open(os.path.join(OUT, "plates.json"), "w"), indent=1)

# contact sheet
sheet = Image.new("RGB", (2400, 1300), (30, 26, 50))
x = y = 10
rowh = 0
for name in PLATES:
    im = Image.open(os.path.join(OUT, name + ".png"))
    im.thumbnail((760, 420))
    if x + im.width > 2390:
        x, y, rowh = 10, y + rowh + 10, 0
    sheet.paste(im, (x, y), im)
    x += im.width + 10
    rowh = max(rowh, im.height)
sheet.save(os.path.join(HERE, "..", "docs", "plates-sheet.png"))
