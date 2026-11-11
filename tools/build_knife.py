"""Cowl's butcher knife, for his hand, from the supplied kit art.

The kit's knife (W34_Interactables, piece "knife") is drawn lying flat, blade
left and edge down. The rig wants it hanging from the fist: grip at the top,
blade down, edge forward (to the right). This turns it a quarter, scales it to
the rig's units and records the grip point. Nothing is redrawn.

    python3 tools/build_knife.py   (after tools/build_kit.py)
"""
import json, os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys_path = os.path.join(HERE)
import sys
sys.path.insert(0, HERE)
from kit_segment import pieces  # noqa: E402
from build_kit import premul_resize, clean  # noqa: E402

SRC = os.path.join(HERE, "..", "assets", "source", "kit", "W34_Interactables.png")
OUT = os.path.join(HERE, "..", "assets", "cowl")
# On screen the knife is about 1.3 tiles long; the rig draws it at 0.82 of a
# rig unit, and a rig unit is 124/369 px.
LENGTH_RIG = 1.3 * 64 / (124.0 / 369.0) / 0.82

sheet = Image.open(SRC).convert("RGBA")
box = pieces(sheet)[3]                       # 0 candle, 1 lit candle, 2 block, 3 knife
knife = clean(sheet.crop((box[0] - 6, box[1] - 6, box[2] + 6, box[3] + 6)))
knife = knife.rotate(90, expand=True, resample=Image.BICUBIC)   # handle up, edge right
knife = premul_resize(knife, LENGTH_RIG / knife.height)
knife.save(os.path.join(OUT, "knife.png"))

# grip: the middle of the dark wooden handle, in the top part
a = np.asarray(knife).astype(int)
top = a[: int(knife.height * 0.42)]
wood = (top[..., 3] > 150) & (top[..., 0] > top[..., 2]) & (top[..., :3].sum(axis=2) < 330)
ys, xs = np.where(wood)
grip = [round(float(xs.mean()), 1), round(float(ys.mean()), 1)] if len(xs) else [knife.width / 2, knife.height * 0.2]

rig_path = os.path.join(OUT, "rig.json")
rig = json.load(open(rig_path))
rig["knife"] = dict(file="knife.png", grip=grip, size=[knife.width, knife.height], source="kit W34 knife")
json.dump(rig, open(rig_path, "w"), indent=1)
print("knife", knife.size, "grip", grip)
