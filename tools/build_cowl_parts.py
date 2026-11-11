"""Cut Cowl's finished artwork into the parts of his rig.

The source is the approved character mockup (assets/source/
cowl_character_mockup.png). Nothing is redrawn: each part is the original
pixels, masked. The only paint added is flat charcoal UNDER parts, where the
mockup hides one part behind another (the neck under the head, the hips under
the shorts), so the rig can move without showing holes.

    python3 tools/build_cowl_parts.py

Writes assets/cowl/*.png and assets/cowl/rig.json (part offsets and pivots).
"""
import json, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "source", "cowl_character_mockup.png")
OUT = os.path.join(HERE, "..", "assets", "cowl")
SCALE = 0.5
CHARCOAL = (53, 53, 57)
LINE = (22, 22, 25)

src = Image.open(SRC).convert("RGB")
W, H = src.size
rgb = np.asarray(src).astype(np.int32)

# ---- silhouette: flood the paper in from the corners; the ink line stops it.
flood = src.copy()
for seed in [(5, 5), (W - 6, 5), (5, H - 6), (W - 6, H - 6), (W // 2, 5), (W // 2, H - 6)]:
    ImageDraw.floodfill(flood, seed, (255, 0, 255), thresh=46)
fl = np.asarray(flood)
paper = (fl[..., 0] == 255) & (fl[..., 1] == 0) & (fl[..., 2] == 255)
# Paper also shows through the small gaps between the arms and the body.
dist = np.abs(rgb - np.array([230, 220, 215])).sum(axis=2)
yy0, xx0 = np.mgrid[0:H, 0:W]
paper |= (dist < 60) & (yy0 > 590)
sil = Image.fromarray((~paper * 255).astype(np.uint8))
sil = sil.filter(ImageFilter.MinFilter(3))                 # pull in off the paper fringe
alpha_full = np.asarray(sil.filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255.0
alpha_full = np.clip((alpha_full - 0.35) / 0.4, 0, 1)
solid = np.asarray(sil) > 0

yy, xx = np.mgrid[0:H, 0:W]
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
red = (r > g + 38) & (r > b + 38) & solid
red_img = Image.fromarray((red * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))
shorts_m = (np.asarray(red_img) > 0) & solid & (yy > 690) & (yy < 835)


def poly_mask(points):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    return np.asarray(m) > 0


head_m = solid & (yy < 578) & ~poly_mask([(690, 560), (768, 590), (846, 560), (900, 600), (640, 600)])
arm_l_m = solid & ~shorts_m & ~head_m & poly_mask(
    [(700, 574), (712, 600), (694, 650), (672, 700), (668, 716), (662, 770), (566, 772), (566, 680), (610, 610), (670, 566)])
arm_r_m = solid & ~shorts_m & ~head_m & poly_mask(
    [(834, 572), (828, 600), (840, 650), (851, 696), (856, 716), (866, 772), (930, 772), (930, 680), (892, 610), (852, 560)])
leg_l_m = solid & ~shorts_m & (yy > 770) & (xx < 768)
leg_r_m = solid & ~shorts_m & (yy > 770) & (xx >= 768)
torso_m = solid & ~head_m & ~arm_l_m & ~arm_r_m & ~shorts_m & ~leg_l_m & ~leg_r_m & (yy < 780)


def soften(mask):
    m = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.9))
    return np.asarray(m).astype(np.float32) / 255.0


def part(name, mask, pivot, under=None, pad=14):
    """Save one part. `under` paints flat charcoal beneath the original pixels."""
    a = np.clip(soften(mask) * (alpha_full > 0.02), 0, 1)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if under is not None:
        under(ImageDraw.Draw(canvas))
        canvas = canvas.filter(ImageFilter.GaussianBlur(0.7))
    top = np.dstack([rgb.astype(np.uint8), (a * 255).astype(np.uint8)])
    canvas = Image.alpha_composite(canvas, Image.fromarray(top, "RGBA"))
    bbox = canvas.getbbox()
    x0, y0, x1, y1 = bbox[0] - pad, bbox[1] - pad, bbox[2] + pad, bbox[3] + pad
    crop = canvas.crop((x0, y0, x1, y1))
    size = (round(crop.width * SCALE), round(crop.height * SCALE))
    crop = crop.resize(size, Image.LANCZOS)
    crop.save(os.path.join(OUT, name + ".png"))
    return dict(file=name + ".png",
                offset=[round((x0 - pivot[0]) * SCALE, 2), round((y0 - pivot[1]) * SCALE, 2)],
                pivot=[round((pivot[0] - ORIGIN[0]) * SCALE, 2), round((pivot[1] - ORIGIN[1]) * SCALE, 2)],
                size=list(size))


def blob(points, width=0):
    def draw(d):
        d.polygon(points, fill=CHARCOAL + (255,), outline=LINE + (255,))
    return draw


def ellipse(box):
    def draw(d):
        d.ellipse(box, fill=CHARCOAL + (255,), outline=LINE + (255,), width=5)
    return draw


def rounded(box, rad):
    def draw(d):
        d.rounded_rectangle(box, rad, fill=CHARCOAL + (255,), outline=LINE + (255,), width=5)
    return draw


def many(*fs):
    def draw(d):
        for f in fs:
            f(d)
    return draw


feet_y = int(np.where(solid.any(axis=1))[0].max())
ORIGIN = (768, feet_y)            # between the feet, on the ground

rig = dict(scale=SCALE, source_height=feet_y - int(np.where(solid.any(axis=1))[0].min()), parts={})
P = rig["parts"]
P["head"] = part("head", head_m, (768, 566), under=ellipse((640, 300, 968, 584)))
P["torso"] = part("torso", torso_m, (768, 712),
                  under=many(rounded((690, 548, 846, 760), 60)))
P["arm_back"] = part("arm_back", arm_l_m, (694, 600), under=ellipse((672, 572, 722, 630)))
P["arm_front"] = part("arm_front", arm_r_m, (842, 600), under=ellipse((816, 572, 866, 630)))
P["shorts"] = part("shorts", shorts_m, (768, 712))
P["leg_back"] = part("leg_back", leg_l_m, (712, 778), under=rounded((684, 740, 742, 816), 22))
P["leg_front"] = part("leg_front", leg_r_m, (822, 778), under=rounded((794, 740, 852, 816), 22))

# ---- eyes: where they are on the head, for the blink and the glow
eye = (b > 215) & (r < 215) & (g > 200) & solid
ex = np.where(eye.any(axis=0))[0]
mid = (ex.min() + ex.max()) // 2
eyes = []
for sel in (eye & (xx < mid - 10), eye & (xx > mid + 10)):
    ys, xs = np.where(sel)
    eyes.append([round((xs.min() - 768) * SCALE, 2), round((ys.min() - 566) * SCALE, 2),
                 round((xs.max() - xs.min()) * SCALE, 2), round((ys.max() - ys.min()) * SCALE, 2)])
rig["eyes_on_head"] = eyes            # x, y, w, h relative to the head pivot
rig["hand_front"] = [round((888 - 842) * SCALE, 2), round((728 - 600) * SCALE, 2)]   # rel. to arm_front pivot
rig["hand_back"] = [round((606 - 694) * SCALE, 2), round((730 - 600) * SCALE, 2)]
rig["height_px"] = round(rig.pop("source_height") * SCALE, 1)

# ---- reference: the whole figure, uncut (for comparison in review)
whole = np.dstack([rgb.astype(np.uint8), (alpha_full * 255).astype(np.uint8)])
wi = Image.fromarray(whole, "RGBA")
bb = wi.getbbox()
wi = wi.crop(bb)
wi.resize((round(wi.width * SCALE), round(wi.height * SCALE)), Image.LANCZOS).save(os.path.join(OUT, "cowl_whole.png"))
rig["whole_offset"] = [round((bb[0] - ORIGIN[0]) * SCALE, 2), round((bb[1] - ORIGIN[1]) * SCALE, 2)]

json.dump(rig, open(os.path.join(OUT, "rig.json"), "w"), indent=1)
print(json.dumps(rig, indent=1))

# contact sheet for review
sheet = Image.new("RGBA", (1500, 460), (120, 110, 150, 255))
x = 10
for n in ["cowl_whole", "head", "torso", "arm_back", "arm_front", "shorts", "leg_back", "leg_front"]:
    im = Image.open(os.path.join(OUT, n + ".png"))
    sheet.alpha_composite(im, (x, 10))
    x += im.width + 12
sheet.save(os.path.join(HERE, "..", "docs", "cowl-parts.png"))
