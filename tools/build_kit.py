"""Cut the supplied environment kit into the pieces the game uses.

Source: assets/source/kit (W00-W39 and the P_ room plates, untouched).
Output: assets/kit/<group>/<name>.png (or .jpg for opaque textures) and
        assets/kit/kit.json with every piece's size and the measurements the
        game needs to fit it to the collision.

The kit is drawn at 128 px per tile; the game runs at 64. Pieces are halved
here with premultiplied-alpha resampling, so edges keep their ink and pick up
no dark or bright fringe. Opaque textures that the engine scales anyway
(walls, parallax) keep more resolution.

Nothing is repainted. The only pixel changes are:
  - alpha below 12 is cleared (generator haze);
  - W09's opaque slate backing under each ceiling edge is keyed out;
  - grid sheets (root cut, flame loop, moss sway) are re-registered to one
    anchor per sequence, as the kit's README asks.

    python3 tools/build_kit.py
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from kit_segment import pieces  # noqa: E402

SRC = os.path.join(HERE, "..", "assets", "source", "kit")
OUT = os.path.join(HERE, "..", "assets", "kit")
HALF = 0.5

# ------------------------------------------------------------------- spec
N = lambda *names: list(names)  # noqa: E731
PIECES = {
    "W02_Materials": ("materials", N("roots_branch", "masonry_broken", "arch_fragment", "iron_finial_gate",
                                     "panel_floor", "curtain_cushion", "candle_drip", "rubble_mossy"), {}),
    "W08_Floor_Tops": ("edges", N("floor_carved", "floor_flagstone", "floor_gallery", "floor_iron"), {}),
    "W10_Wall_Faces": ("edges", N("face_pilaster_R", "face_pilaster_L", "face_stone_L", "face_stone_R"), {}),
    "W11_Corners": ("edges", N("ledge_end_L", "ledge_end_R", "soffit_end_L", "soffit_end_R",
                               "inner_corner_R", "inner_corner_L", "ledge_roots_L", "ledge_roots_R"), {}),
    "W12_Openings": ("arch", N("door_gothic", "door_round", "door_broken", "header_torn",
                               "door_narrow_roots", "lintel_cloth", "canopy_torn", "door_tall"), dict(amin=60, join=3)),
    "W13_Stairs": ("arch", N("stair_up", "stair_down", "stair_up_newel", "stair_flying_up",
                             "stair_broken_up", "stair_steep_up", "stair_steep_down_rubble", "stair_mound"), dict(amin=60, join=2)),
    "W14_Railings": ("arch", N("rail_section", "rail_newel", "rail_end_scroll", "rail_broken",
                               "rail_stair_up", "rail_stair_down", "rail_fallen", "rail_twisted"), dict(amin=60, join=4)),
    "W15_Piers": ("arch", N("shaft_thin", "pier_cap", "corbel_bat", "corbel_bracket",
                            "pier_block", "plinth", "column", "column_broken"), {}),
    "W16_Vaults": ("arch", N("spandrel_L", "spandrel_R", "spandrel_tall_L", "spandrel_tall_R",
                             "rib_wide", "rib_narrow", "arch_post_L", "arch_post_R"), {}),
    "W17_Windows": ("arch", N("lancet", "lancet_small", "lancet_broken", "lancet_boarded",
                              "rose", "cellar_bars", "dormer", "porthole"), dict(amin=60, join=3)),
    "W26_Bedroom_Wreckage": ("wreck", N("wardrobe_toppled", "heap", "cabinet_tipped", "bed_on_side",
                                        "wardrobe", "canopy_bed", "trunks"), dict(amin=90, join=3)),
    "W27_Shared_Wreckage": ("wreck", N("reading_table", "bookcase_leaning", "book_pile", "urn_planter",
                                       "trough_planter", "root_window", "broken_beams", "bookshelf_toppled",
                                       "long_bench"), {}),
    "W28_Storage_Wreckage": ("wreck", N("table_clutter", "crates", "barrel_rack", "barrel", "vault_stone"), {}),
    "W29_Workshop_Wreckage": ("wreck", N("workbench", "engine", "coal_bunker", "boiler"), {}),
    "W31_Machines": ("machines", N("dumbwaiter", "chandelier_lift", "winch", "cage", "lever_up",
                                   "lever_down", "chain", "lamp_platform", "pipe_platform"), {}),
    "W32_Sealed_Doors": ("doors", N("front_door", "garage_shutter", "lab_vault"), {}),
    "W33_Secret_Pieces": ("doors", N("green_door", "cracked_floor", "green_door_small", "bookcase_door",
                                     "pipe_wall"), {}),
    "W34_Interactables": ("props", N("candle_unlit", "candle_lit", "butcher_block", "knife", "note",
                                     "letter", "stalagmites"), {}),
    "W35_Candles_And_Lamps": ("lights", N("candelabrum_3", "candelabrum_5", "sconce", "candle_stubs",
                                          "candle_table", "father_lamp", "chandelier_small",
                                          "candelabrum_toppled"), {}),
    "W37_Hanging_Moss_Clumps": ("moss", N(*["clump_%d" % i for i in range(8)]), {}),
    "W39_Decals": ("decals", N("wall_crack", "damp_stain", "cobweb_L", "cobweb_R", "ceiling_roots",
                               "rubble", "fallen_books", "broken_glass"), {}),
}
GRIDS = {
    # sheet: (group, cols, rows, names, register)
    "W30_Root_Barriers": ("roots", 4, 2, N("barrier_a", "barrier_b", "barrier_c", "cut_0", "cut_1",
                                           "cut_2", "barrier_wide", "lever_bound"), None),
    "W36_Candle_Flame_Loop": ("flame", 4, 2, N(*["f%d" % i for i in range(8)]), "base"),
    "W38_Moss_Sway_Loop": ("sway", 8, 1, N(*["f%d" % i for i in range(8)]), "top"),
}
WHOLE = {
    # sheet: (group, name, scale, format)
    "W03_Far_Arcades": ("parallax", "far_arcades", 1.0, "jpg"),
    "W04_Middle_Galleries": ("parallax", "middle_galleries", 1.0, "png"),
    "W05_Near_Arcade": ("parallax", "near_arcade", 1.0, "png"),
    "W06_Undercroft": ("parallax", "undercroft", 1.0, "jpg"),
    "W07_Packed_Earth": ("parallax", "packed_earth", 0.5, "png"),
    "W18_Bedroom_Wall": ("walls", "bedroom", 0.75, "jpg"),
    "W19_Common_Wall": ("walls", "common", 0.75, "jpg"),
    "W20_Library_Wall": ("walls", "library", 0.75, "jpg"),
    "W21_Cellar_Wall": ("walls", "cellar", 0.75, "jpg"),
    "W22_Attic_Wall": ("walls", "attic", 0.75, "jpg"),
    "W23_Lab_Wall": ("walls", "lab", 0.75, "jpg"),
    "W24_Conservatory_Wall": ("walls", "conservatory", 0.75, "jpg"),
    "W25_Tower_Wall": ("walls", "tower", 0.75, "jpg"),
}
PLATES = ["P_Bedroom", "P_Bedroom2", "P_Kitchen", "P_Dining", "P_Living", "P_Study", "P_Storage", "P_Flooded"]


# -------------------------------------------------------------- helpers
def premul_resize(img, scale):
    """Resize RGBA without fringes: premultiply, resample, unpremultiply."""
    if scale == 1.0:
        return img
    a = np.asarray(img.convert("RGBA")).astype(np.float32) / 255.0
    rgb = a[..., :3] * a[..., 3:4]
    w, h = max(1, round(img.width * scale)), max(1, round(img.height * scale))
    chans = [Image.fromarray(c).resize((w, h), Image.LANCZOS) for c in
             [rgb[..., 0], rgb[..., 1], rgb[..., 2], a[..., 3]]]
    r, g, b, al = [np.asarray(c, np.float32) for c in chans]
    al = np.clip(al, 0, 1)
    safe = np.maximum(al, 1e-4)
    out = np.dstack([np.clip(r / safe, 0, 1), np.clip(g / safe, 0, 1), np.clip(b / safe, 0, 1), al])
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


def clean(img, floor=12):
    a = np.asarray(img.convert("RGBA")).copy()
    a[..., 3][a[..., 3] < floor] = 0
    return Image.fromarray(a, "RGBA")


def alpha(img):
    return np.asarray(img.convert("RGBA"))[..., 3].astype(np.float32) / 255.0


def top_profile(img, thresh=0.5):
    """Median top-of-silhouette over the central 80% of columns, in px."""
    a = alpha(img) > thresh
    cols = []
    w = a.shape[1]
    for x in range(int(w * 0.1), int(w * 0.9)):
        ys = np.where(a[:, x])[0]
        if len(ys):
            cols.append(ys[0])
    return float(np.median(cols)) if cols else 0.0


def first_row(img, cover):
    a = alpha(img) > 0.5
    frac = a.mean(axis=1)
    rows = np.where(frac >= cover)[0]
    return int(rows[0]) if len(rows) else 0


def deck_row(img):
    """Widest opaque row in the lower 45%: a platform's standing line."""
    a = alpha(img) > 0.5
    h = a.shape[0]
    lo = int(h * 0.55)
    widths = a[lo:].sum(axis=1)
    return int(lo + np.argmax(widths))


def wick_points(img):
    """Lit flames painted on a candle sprite: (x, y) of each flame's base."""
    a = np.asarray(img.convert("RGBA")).astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    # rose flame (#E6A8B2-ish): red well above green AND above blue; lilac
    # wax has blue above red, so it is left out.
    hot = (al > 120) & (r > 190) & (r > g + 40) & (r > b + 12) & (r + g + b > 480)
    lab, n = ndimage.label(ndimage.binary_dilation(hot, iterations=2))
    pts = []
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        if len(xs) < 6 or ys.max() - ys.min() < 5:
            continue
        pts.append([round(float(xs.mean()), 1), round(float(ys.max()), 1), round(float(ys.max() - ys.min()), 1)])
    return sorted(pts)


def corner_anchor(img, name):
    """Where a corner piece meets the collision, in its own pixels.
    walk: the floor line (ledge ends, inner corners)
    soffit: the ceiling line (soffit ends)
    edge: the vertical line - a ledge's tip, a wall's face, a soffit's end."""
    a = alpha(img) > 0.5
    h, w = a.shape
    left = name.endswith("_L")
    meta = {}
    if name.startswith(("ledge", "inner")):
        # floor line: first row that is solid across the side away from the edge
        half = a[:, w // 2:] if (left and name.startswith("ledge")) or (not left and name.startswith("inner")) else a[:, :w // 2]
        if name.startswith("inner"):
            half = a[:, w // 2:] if left else a[:, :w // 2]
        rows = np.where(half.mean(axis=1) > 0.85)[0]
        meta["walk"] = int(rows[0]) if len(rows) else 0
    if name.startswith("ledge"):
        band = a[meta["walk"]:meta["walk"] + 24]
        cols = np.where(band.mean(axis=0) > 0.5)[0]
        meta["edge"] = int(cols.min() if left else cols.max() + 1)
    if name.startswith("inner"):
        band = a[: max(meta["walk"] - 20, 10)]
        cols = np.where(band.mean(axis=0) > 0.85)[0]
        meta["edge"] = int(cols.max() + 1 if left else cols.min())
    if name.startswith("soffit"):
        rows = np.where(a.mean(axis=1) > 0.6)[0]
        meta["soffit"] = int(rows.max() + 1) if len(rows) else 0
        band = a[: max(meta["soffit"] - 2, 4)]
        cols = np.where(band.mean(axis=0) > 0.5)[0]
        meta["edge"] = int(cols.min() if left else cols.max() + 1)
    return meta


def save(img, group, name, fmt="png"):
    d = os.path.join(OUT, group)
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, "%s.%s" % (name, fmt))
    if fmt == "jpg":
        img.convert("RGB").save(path, quality=90, optimize=True)
    else:
        img.save(path, optimize=True)
    return "res://assets/kit/%s/%s.%s" % (group, name, fmt)


def key_backing(img):
    """W09: clear the flat slate backing that fills each ceiling strip below
    its edge. The backing is smooth and mid-toned; the ceiling's stones are
    smooth too, but every one is ringed by ink. So: mark smooth mid-tone
    pixels, keep only the regions that reach the strip's bottom edge."""
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    lum = a[..., :3].mean(axis=2)
    grad = np.hypot(ndimage.sobel(lum, 0), ndimage.sobel(lum, 1))
    bluish = a[..., 2] > a[..., 0] + 25
    cand = (grad < 60) & (lum > 38) & (lum < 120) & bluish & (a[..., 3] > 180)
    lab, _ = ndimage.label(cand)
    bottom = set(np.unique(lab[-4:, :])) - {0}
    mask = np.isin(lab, list(bottom))
    mask = ndimage.binary_closing(mask, iterations=2)
    soft = ndimage.gaussian_filter(mask.astype(np.float32), 1.0)
    out = a.copy()
    out[..., 3] = out[..., 3] * (1.0 - np.clip(soft * 1.5, 0, 1))
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


# ----------------------------------------------------------------- build
def build():
    kit = {}

    def put(key, img, path, **meta):
        kit[key] = dict(path=path, size=[img.width, img.height], **meta)

    for sheet, (group, names, opts) in PIECES.items():
        img = Image.open(os.path.join(SRC, sheet + ".png")).convert("RGBA")
        boxes = pieces(img, alpha_min=opts.get("amin", 40), join=opts.get("join", 10))
        assert len(boxes) == len(names), (sheet, len(boxes), len(names))
        for name, (x0, y0, x1, y1) in zip(names, boxes):
            pad = 4
            crop = clean(img.crop((max(0, x0 - pad), max(0, y0 - pad), min(img.width, x1 + pad), min(img.height, y1 + pad))))
            piece = premul_resize(crop, HALF)
            meta = {}
            if group == "wreck":
                meta["top"] = round(top_profile(piece), 1)
            if sheet == "W08_Floor_Tops":
                meta["walk"] = first_row(piece, 0.85)
            if sheet == "W10_Wall_Faces":
                a = alpha(piece) > 0.5
                cover = a.mean(axis=0)
                open_right = name.endswith("_R")
                cols = np.where(cover >= 0.4)[0]
                meta["face"] = int(cols.max() + 1 if open_right else cols.min())
                meta["open"] = "R" if open_right else "L"
            if sheet == "W11_Corners":
                meta.update(corner_anchor(piece, name))
            if sheet in ("W31_Machines",):
                meta["deck"] = deck_row(piece)
            if sheet == "W31_Machines" and name in ("lamp_platform", "pipe_platform"):
                meta["deck"] = first_row(piece, 0.6)
            if group == "lights" or name in ("candle_lit",):
                meta["wicks"] = wick_points(piece)
            if sheet == "W34_Interactables" and name == "butcher_block":
                # the block without the knife: everything below the block's top face
                a = alpha(piece) > 0.5
                widths = a.sum(axis=1)
                top = int(np.argmax(widths > piece.width * 0.75))
                meta["block_top"] = top
            put("%s/%s" % (group, name), piece, save(piece, group, name), **meta)

    # W09 ceilings: four bands split at the alpha dips, backing keyed out.
    img = Image.open(os.path.join(SRC, "W09_Ceilings.png")).convert("RGBA")
    a = alpha(img)
    prof = a.mean(axis=1)
    cuts = [0]
    y = 1
    while y < img.height - 1:
        if prof[y] < 0.2 and prof[y - 1] >= 0.2:
            cuts.append(y)
        y += 1
    cuts.append(img.height)
    names = ["ceiling_ribs", "ceiling_stone", "ceiling_beams", "ceiling_iron"]
    assert len(cuts) - 1 == 4, cuts
    for name, (y0, y1) in zip(names, zip(cuts[:-1], cuts[1:])):
        band = key_backing(img.crop((0, y0, img.width, y1)))
        # the soft haze above the edge belongs inside the mass: start at the edge
        top = first_row(band, 0.9)
        band = clean(band.crop((0, top, band.width, band.height)))
        bb = band.getbbox()
        band = band.crop((0, 0, band.width, bb[3]))
        piece = premul_resize(band, HALF)
        put("edges/" + name, piece, save(piece, "edges", name))

    # Grids.
    for sheet, (group, cols, rows, names, register) in GRIDS.items():
        img = Image.open(os.path.join(SRC, sheet + ".png")).convert("RGBA")
        cw, ch = img.width / cols, img.height / rows
        cells = []
        for i, name in enumerate(names):
            c, r = i % cols, i // cols
            cell = clean(img.crop((round(c * cw), round(r * ch), round((c + 1) * cw), round((r + 1) * ch))))
            cells.append(cell)
        if register:
            # Move every frame so its anchor lands on the same point.
            anchors = []
            for cell in cells:
                a = alpha(cell) > 0.4
                ys, xs = np.where(a)
                if register == "base":
                    yb = ys.max()
                    xb = xs[ys >= yb - 6].mean()
                    anchors.append((xb, yb))
                else:
                    yt = ys.min()
                    xt = xs[ys <= yt + 10].mean()
                    anchors.append((xt, yt))
            target = (np.mean([p[0] for p in anchors]), np.mean([p[1] for p in anchors]))
            moved = []
            for cell, (ax, ay) in zip(cells, anchors):
                canvas = Image.new("RGBA", cell.size, (0, 0, 0, 0))
                canvas.alpha_composite(cell, (int(round(target[0] - ax)), int(round(target[1] - ay))))
                moved.append(canvas)
            cells = moved
            anchor = [round(target[0] * HALF, 1), round(target[1] * HALF, 1)]
        else:
            anchor = None
        for name, cell in zip(names, cells):
            piece = premul_resize(cell, HALF)
            meta = {"anchor": anchor} if anchor else {}
            if sheet == "W30_Root_Barriers":
                meta["cell"] = [piece.width, piece.height]
            put("%s/%s" % (group, name), piece, save(piece, group, name), **meta)
    # The root-bound lever, cropped to itself (its cell is mostly empty).
    lv = Image.open(os.path.join(OUT, "roots", "lever_bound.png"))
    lv = lv.crop(lv.getbbox())
    put("roots/lever_bound_crop", lv, save(lv, "roots", "lever_bound_crop"))
    # The root barrier's doorway, measured from the clean barrier: its opening
    # is centred in the cell, its floor line where the roots meet the ground.
    a = alpha(Image.open(os.path.join(OUT, "roots", "barrier_a.png"))) > 0.5
    ys = np.where(a.any(axis=1))[0]
    kit["roots/barrier_a"]["floor"] = int(ys.max())

    for sheet, (group, name, scale, fmt) in WHOLE.items():
        img = Image.open(os.path.join(SRC, sheet + ".png")).convert("RGBA")
        piece = premul_resize(img, scale) if scale != 1.0 else img
        put("%s/%s" % (group, name), piece, save(piece, group, name, fmt), source_scale=scale)

    for name in PLATES:
        img = clean(Image.open(os.path.join(SRC, name + ".png")).convert("RGBA"))
        bb = img.getbbox()
        img = img.crop(bb)
        a = alpha(img)
        # floor line: the lowest row that is still opaque across the middle
        mid = a[:, int(img.width * 0.3):int(img.width * 0.7)]
        solid_rows = np.where(mid.mean(axis=1) > 0.9)[0]
        floor = int(solid_rows.max()) if len(solid_rows) else img.height - 1
        # Deepen the plate's own soft margin (sides and top, never the floor),
        # so it settles into the kit's darker walls instead of reading as a box.
        arr = np.asarray(img).astype(np.float32)
        hh, ww = arr.shape[:2]
        def ramp(n, frac):
            r = np.ones(n, np.float32)
            k = max(1, int(n * frac))
            t = np.linspace(0, 1, k)
            r[:k] = t * t * (3 - 2 * t)
            return r
        ax = ramp(ww, 0.09) * ramp(ww, 0.09)[::-1]
        ay = ramp(hh, 0.16)
        ay[floor:] = 1.0
        arr[..., 3] *= np.outer(ay, ax)
        img = Image.fromarray(arr.astype(np.uint8), "RGBA")
        piece = premul_resize(img, HALF)
        key = name[2:].lower()
        put("plates/" + key, piece, save(piece, "plates", key), floor=round(floor * HALF, 1),
            wicks=wick_points(piece))

    with open(os.path.join(OUT, "kit.json"), "w") as f:
        json.dump(kit, f, indent=1, sort_keys=True)
    return kit


def contact_sheet(kit):
    """docs/kit-pieces.png: every piece, labelled, on a mid tone."""
    from PIL import ImageFont
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    keys = [k for k in kit if not k.startswith(("parallax", "walls", "plates", "flame", "sway"))]
    cell = 170
    cols = 12
    rows = (len(keys) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + 18)), (88, 80, 128, 255))
    d = ImageDraw.Draw(sheet)
    for i, k in enumerate(sorted(keys)):
        im = Image.open(os.path.join(OUT, kit[k]["path"].split("assets/kit/")[1]))
        im.thumbnail((cell - 8, cell - 8))
        x, y = (i % cols) * cell, (i // cols) * (cell + 18)
        sheet.alpha_composite(im, (x + (cell - im.width) // 2, y + (cell - im.height) // 2))
        d.text((x + 3, y + cell), k, fill=(255, 240, 160), font=font)
    sheet.convert("RGB").save(os.path.join(HERE, "..", "docs", "kit-pieces.png"))


if __name__ == "__main__":
    kit = build()
    contact_sheet(kit)
    total = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(OUT) for f in fs)
    print("%d pieces, %.1f MB in assets/kit" % (len(kit), total / 1e6))
