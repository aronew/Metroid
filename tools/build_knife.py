"""Draw the butcher knife in Cowl's line style: flat fills, one shade band,
a heavy near-black outline. No knife exists in the supplied art, so this is
an extension of the character's design language, sized in rig units.

    python3 tools/build_knife.py     ->  assets/cowl/knife.png

The image is drawn with the grip at the top and the blade hanging down, edge
forward (to the right). The grip's centre is the pivot (see rig.json).
"""
import json, os
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "cowl")
SS = 4                                   # supersample
W, H = 150, 300
LINE = (22, 22, 25, 255)
STEEL = (214, 212, 218, 255)
STEEL_SHADE = (168, 165, 180, 255)
EDGE = (244, 243, 248, 255)
WOOD = (98, 58, 44, 255)
WOOD_SHADE = (72, 42, 36, 255)

im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(im)


def P(pts):
    return [(x * SS, y * SS) for x, y in pts]


# handle (grip centre at 50, 40)
d.rounded_rectangle([36 * SS, 8 * SS, 64 * SS, 84 * SS], 10 * SS, fill=WOOD, outline=LINE, width=5 * SS)
d.rectangle([40 * SS, 14 * SS, 46 * SS, 78 * SS], fill=WOOD_SHADE)
for y in (30, 58):
    d.ellipse([(47) * SS, (y - 4) * SS, 55 * SS, (y + 4) * SS], fill=(190, 186, 196, 255), outline=LINE, width=2 * SS)
# blade: a heavy cleaver, spine on the left, edge on the right, slight belly
blade = [(30, 80), (72, 80), (128, 92), (136, 180), (130, 262), (118, 284), (34, 290), (28, 270)]
d.polygon(P(blade), fill=STEEL, outline=LINE)
d.line(P(blade + [blade[0]]), fill=LINE, width=6 * SS, joint="curve")
# shade band along the spine, bright bevel along the edge
d.polygon(P([(34, 86), (56, 86), (58, 284), (38, 286)]), fill=STEEL_SHADE)
d.polygon(P([(112, 96), (126, 98), (130, 180), (125, 258), (112, 276)]), fill=EDGE)
d.line(P([(112, 96), (112, 276)]), fill=(150, 148, 162, 255), width=2 * SS)
# the hanging hole, and two nicks: it has been used
d.ellipse([86 * SS, 100 * SS, 102 * SS, 116 * SS], fill=(0, 0, 0, 0), outline=LINE, width=4 * SS)
d.polygon(P([(132, 150), (124, 156), (133, 162)]), fill=(0, 0, 0, 0))
d.polygon(P([(130, 222), (123, 227), (129, 233)]), fill=(0, 0, 0, 0))
im = im.resize((W, H), Image.LANCZOS)
im.save(os.path.join(OUT, "knife.png"))

rig_path = os.path.join(OUT, "rig.json")
rig = json.load(open(rig_path))
rig["knife"] = dict(file="knife.png", grip=[50, 40], size=[W, H])
json.dump(rig, open(rig_path, "w"), indent=1)
print("knife ok")
