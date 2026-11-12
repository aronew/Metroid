"""Cut Cowl's animation sheets into registered frames, and his effects.

Source: assets/source/cowl_sheets (H0-H23, untouched, with both READMEs).
Output: assets/cowl/frames/*.png, assets/cowl/fx/*.png and
        assets/cowl/cowl_anim.json (clips, frame offsets, ticks, events).

The sheets were not exported at the requested sizes, and scale and placement
drift between sheets (their READMEs say so). So:

  * scale is set per sheet from the beanie, the one shape every frame shows:
    the median of sqrt(beanie area) over the sheet maps to BEANIE_GAME px;
  * each frame is registered on a stable feature, chosen per clip:
      eyes     the eye slits (standing, running, idling)
      rear     the planted rear foot (jab, cross)
      stand    the standing foot (spin back kick)
      mass     the body's centre (airborne frames)
    then the whole clip is shifted once so its median body centre sits on
    the collision body's centre line;
  * grounded frames put their lowest pixel on the floor line; airborne frames
    put their body centre at AIR_CENTRE above Cowl's feet.

Frames are stored at 2x game size and drawn at half scale, so they stay
clean at every camera zoom. Nothing is repainted; stray specks away from the
figure are cleared and alpha under 12 is dropped.

    python3 tools/build_cowl_sprites.py
"""
import json, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "source", "cowl_sheets")
OUT = os.path.join(HERE, "..", "assets", "cowl")
STORE = 2.0                 # frames are written at 2x game size
STANDING_H = 128.0          # Cowl standing, feet to beanie top, game px
AIR_CENTRE = -60.0          # body centre above the feet when airborne, game px
GRID = {(1774, 887): (4, 2), (1254, 1254): (4, 4), (1448, 1086): (4, 3)}

T = json.load(open(os.path.join(SRC, "timings_H0-H12.json")))
T.update(json.load(open(os.path.join(SRC, "timings_H12-H23.json"))))


def ticks_of(sheet):
    t = T.get(sheet)
    if t is None:
        return None
    return t["ticks"] if isinstance(t, dict) else t


# clip: [(sheet, [cell indices]...)], anchor, loop, airborne frame indices (in clip order)
CLIPS = {
    "idle": dict(src=[("H4_Idle", range(16))], anchor="eyes", loop=True),
    "chill": dict(src=[("H5_Chilled_Idle", range(12))], anchor="eyes", loop=True),
    "light": dict(src=[("H6_Lighting_Blunt", range(16))], anchor="eyes"),
    "smoke": dict(src=[("H7_Smoking_Loop", range(12))], anchor="eyes", loop=True),
    "finish": dict(src=[("H8_Finishing_Blunt", range(12))], anchor="eyes"),
    "bong": dict(src=[("H9_Bong_Hit", range(16))], anchor="eyes"),
    "after_bong": dict(src=[("H10_After_Bong", range(16))], anchor="eyes"),
    "snap_blunt": dict(src=[("H11_Snap_Ready", range(0, 6))], anchor="eyes"),
    "snap_bong": dict(src=[("H11_Snap_Ready", range(6, 12))], anchor="eyes"),
    # H12_Run_b is drawn more upright and larger than _a; mixing them makes
    # Cowl bob, so the loop is _a's eight frames.
    "run": dict(src=[("H12_Run_a", range(8))], anchor="eyes", loop=True),
    "start": dict(src=[("H13_Start_Stop_Turn_a", range(0, 4))], anchor="eyes"),
    "stop": dict(src=[("H13_Start_Stop_Turn_a", range(4, 8)), ("H13_Start_Stop_Turn_b", range(0, 2))], anchor="eyes"),
    "turn": dict(src=[("H13_Start_Stop_Turn_b", range(2, 8))], anchor="mass_ground"),
    "jump": dict(src=[("H14_Jump_a", range(8)), ("H14_Jump_b", range(8))], anchor="mass", ground=[0]),
    "fall": dict(src=[("H15_Fall_Land_a", range(0, 4))], anchor="mass", loop=True, air=True),
    "land": dict(src=[("H15_Fall_Land_a", range(4, 8))], anchor="eyes"),
    "land_heavy": dict(src=[("H15_Fall_Land_b", range(8))], anchor="eyes"),
    "jab": dict(src=[("H16_Jab", range(8))], anchor="rear"),
    "cross": dict(src=[("H17_Cross", range(8))], anchor="rear"),
    "kick": dict(src=[("H18_Spin_Back_Kick_a", range(8)), ("H18_Spin_Back_Kick_b", range(4))], anchor="stand"),
    "air_kick": dict(src=[("H19_Air_Kick", range(8))], anchor="mass", air=True),
    "run_to_fight": dict(src=[("H20_Punch_Transitions_a", range(0, 4))], anchor="eyes"),
    "fight_to_run": dict(src=[("H20_Punch_Transitions_a", range(4, 8))], anchor="eyes"),
    "fight_to_idle": dict(src=[("H20_Punch_Transitions_b", range(4))], anchor="eyes"),
}

# effects: sheet, cells, origin in the cell as the brief places it (512 px cell)
FX = {
    "smoke_wisp": dict(src=[("H12_Effects_a", range(0, 4))], origin=(256, 440)),
    "smoke_exhale": dict(src=[("H12_Effects_a", range(4, 8))], origin=(180, 256)),
    "smoke_ring": dict(src=[("H12_Effects_b", range(0, 4))], origin=(256, 256)),
    "smoke_plume": dict(src=[("H12_Effects_b", range(4, 6))], origin=(140, 400)),
    "lighter": dict(src=[("H12_Effects_b", range(6, 8))], origin=(256, 256)),
    "trail_jab": dict(src=[("H21_Strike_Trails_a", range(0, 3))], origin=(256, 400)),
    "trail_cross": dict(src=[("H21_Strike_Trails_a", range(3, 6))], origin=(256, 400)),
    "trail_kick": dict(src=[("H21_Strike_Trails_a", range(6, 8)), ("H21_Strike_Trails_b", range(0, 2))], origin=(256, 400)),
    "trail_air": dict(src=[("H21_Strike_Trails_b", range(2, 4))], origin=(256, 400)),
    "flash_light": dict(src=[("H22_Impact_Flashes_a", range(0, 4))], origin=(256, 256)),
    "flash_heavy": dict(src=[("H22_Impact_Flashes_a", range(4, 8))], origin=(256, 256)),
    "flash_finisher": dict(src=[("H22_Impact_Flashes_b", range(0, 4))], origin=(256, 256)),
    "flare_jab": dict(src=[("H23_Strike_Flares_Soot_a", range(0, 3))], origin=(256, 256)),
    "flare_cross": dict(src=[("H23_Strike_Flares_Soot_a", range(3, 6))], origin=(256, 256)),
    "flare_kick": dict(src=[("H23_Strike_Flares_Soot_a", range(6, 8)), ("H23_Strike_Flares_Soot_b", range(0, 1))], origin=(256, 256)),
    "soot": dict(src=[("H23_Strike_Flares_Soot_b", range(1, 4))], origin=(256, 256)),
}


# ------------------------------------------------------------------ helpers
_sheets = {}


def sheet(name):
    if name not in _sheets:
        _sheets[name] = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
    return _sheets[name]


def cell(name, i):
    im = sheet(name)
    cols, rows = GRID[im.size]
    cw, ch = im.width / cols, im.height / rows
    c, r = i % cols, i // cols
    return im.crop((round(c * cw), round(r * ch), round((c + 1) * cw), round((r + 1) * ch))), cw


def clean(img, keep_frac=0.004, near=40):
    """Drop alpha below 12, and specks that are small and away from the figure."""
    a = np.asarray(img).copy()
    a[..., 3][a[..., 3] < 12] = 0
    mask = a[..., 3] > 40
    lab, n = ndimage.label(ndimage.binary_dilation(mask, iterations=2))
    if n > 1:
        sizes = ndimage.sum(mask, lab, range(1, n + 1))
        big = int(np.argmax(sizes)) + 1
        ys, xs = np.where(lab == big)
        x0, x1, y0, y1 = xs.min() - near, xs.max() + near, ys.min() - near, ys.max() + near
        for i in range(1, n + 1):
            if i == big:
                continue
            if sizes[i - 1] < sizes[big - 1] * keep_frac:
                yy, xx = np.where(lab == i)
                inside = (xx.mean() > x0) and (xx.mean() < x1) and (yy.mean() > y0) and (yy.mean() < y1)
                if not inside or sizes[i - 1] < 20:
                    a[lab == i] = 0
    return Image.fromarray(a, "RGBA")


def premul_resize(img, scale):
    a = np.asarray(img).astype(np.float32) / 255.0
    rgb = a[..., :3] * a[..., 3:4]
    w, h = max(1, round(img.width * scale)), max(1, round(img.height * scale))
    ch = [np.asarray(Image.fromarray(c).resize((w, h), Image.LANCZOS), np.float32) for c in
          [rgb[..., 0], rgb[..., 1], rgb[..., 2], a[..., 3]]]
    al = np.clip(ch[3], 0, 1)
    s = np.maximum(al, 1e-4)
    out = np.dstack([np.clip(ch[0] / s, 0, 1), np.clip(ch[1] / s, 0, 1), np.clip(ch[2] / s, 0, 1), al])
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


def features(img):
    a = np.asarray(img).astype(np.int32)
    al = a[..., 3] > 128
    rgb = a[..., :3]
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    beanie = al & (lum > 150) & (sat < 45)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    eyes = al & (b > 200) & (g > 195) & (b > r + 25)
    ys, xs = np.where(al)
    f = dict(
        beanie_sqrt=float(np.sqrt(beanie.sum())),
        foot_y=float(ys.max()),
        top_y=float(ys.min()),
        mass=(float(xs.mean()), float(ys.mean())),
    )
    if beanie.sum() > 30:
        by, bx = np.where(beanie)
        f["beanie_c"] = (float(bx.mean()), float(by.mean()))
    if eyes.sum() >= 6:
        ey, ex = np.where(eyes)
        f["eyes"] = (float(ex.mean()), float(ey.mean()))
    # ground contact: pixels within 6 px of the lowest row
    gy, gx = np.where(al[int(ys.max()) - 6:int(ys.max()) + 1])
    f["ground_xs"] = (float(gx.min()), float(gx.max()), float(gx.mean())) if len(gx) else (0.0, 0.0, 0.0)
    return f


# -------------------------------------------------------------------- build
def build_clips():
    os.makedirs(os.path.join(OUT, "frames"), exist_ok=True)
    # per-sheet scale from the beanie
    sheet_scale = {}
    idle_h = []
    for i in range(16):
        c, _ = cell("H4_Idle", i)
        f = features(clean(c))
        idle_h.append(f["foot_y"] - f["top_y"])
    ref = []
    for i in range(16):
        ref.append(features(clean(cell("H4_Idle", i)[0]))["beanie_sqrt"])
    beanie_game = np.median(ref) * STANDING_H / np.median(idle_h)

    def scale_for(name):
        if name not in sheet_scale:
            im = sheet(name)
            cols, rows = GRID[im.size]
            vals = []
            for i in range(cols * rows):
                c, _ = cell(name, i)
                if np.asarray(c)[..., 3].max() < 100:
                    continue
                vals.append(features(clean(c))["beanie_sqrt"])
            sheet_scale[name] = beanie_game / float(np.median(vals))
        return sheet_scale[name]

    anim = {"store": STORE, "standing_h": STANDING_H, "clips": {}, "fx": {}}
    for clip, spec in CLIPS.items():
        frames = []
        ticks = []
        for sname, idxs in spec["src"]:
            st = ticks_of(sname)
            for k, i in enumerate(idxs):
                c, _ = cell(sname, i)
                frames.append((sname, i, clean(c)))
                ticks.append(int(st[i]) if st is not None and i < len(st) else 6)
        # features in game px
        recs = []
        for sname, i, img in frames:
            s = scale_for(sname)
            f = features(img)
            recs.append((sname, i, img, s, f))
        mode = spec["anchor"]
        ground = set(spec.get("ground", []))
        air_all = spec.get("air", False)
        # registration x per frame (in that frame's own px), before the clip shift
        reg = []
        for k, (sname, i, img, s, f) in enumerate(recs):
            airborne = air_all or (mode == "mass" and k not in ground)
            if airborne or mode in ("mass", "mass_ground"):
                rx = f["mass"][0]
            elif mode == "eyes":
                if "eyes" in f:
                    rx = f["eyes"][0]
                elif "beanie_c" in f:
                    rx = f["beanie_c"][0] + 0.0
                else:
                    rx = f["mass"][0]
            elif mode == "rear":
                rx = f["ground_xs"][0]
            elif mode == "stand":
                rx = f["ground_xs"][2]
            else:
                rx = f["mass"][0]
            reg.append(rx)
        # eyes missing on some frames: substitute beanie centre + the clip's median offset
        if mode == "eyes":
            deltas = [f["eyes"][0] - f["beanie_c"][0] for (_, _, _, _, f) in recs if "eyes" in f and "beanie_c" in f]
            d = float(np.median(deltas)) if deltas else 0.0
            for k, (_, _, _, _, f) in enumerate(recs):
                if "eyes" not in f and "beanie_c" in f:
                    reg[k] = f["beanie_c"][0] + d
        # clip shift: the median body centre sits on x = 0
        offs = [(f["mass"][0] - reg[k]) * s for k, (_, _, _, s, f) in enumerate(recs)]
        shift = float(np.median(offs))
        out_frames = []
        for k, (sname, i, img, s, f) in enumerate(recs):
            airborne = air_all or (mode == "mass" and k not in ground)
            bb = img.getbbox()
            crop = img.crop(bb)
            big = premul_resize(crop, s * STORE)
            fname = "%s_%02d.png" % (clip, k)
            big.save(os.path.join(OUT, "frames", fname), optimize=True)
            # where the crop's top-left lands relative to Cowl's feet, game px
            ox = (bb[0] - reg[k]) * s - shift
            if airborne:
                oy = (bb[1] - f["mass"][1]) * s + AIR_CENTRE
            else:
                oy = (bb[1] - f["foot_y"]) * s
            # eyes and the frame's forward reach, relative to the feet, game px
            ex = ey = None
            if "eyes" in f:
                ex = round((f["eyes"][0] - reg[k]) * s - shift, 1)
                ey = round((f["eyes"][1] - (f["mass"][1] if airborne else f["foot_y"])) * s + (AIR_CENTRE if airborne else 0.0), 1)
            reach = round(ox + crop.width * s, 1)
            out_frames.append(dict(file=fname, ox=round(ox, 2), oy=round(oy, 2), eyes=[ex, ey] if ex is not None else None,
                                   reach=reach,
                                   w=round(crop.width * s, 2), h=round(crop.height * s, 2),
                                   air=bool(airborne), src="%s#%d" % (sname, i + 1)))
        anim["clips"][clip] = dict(frames=out_frames, ticks=ticks, loop=spec.get("loop", False), anchor=mode)
    anim["sheet_scale"] = {k: round(v, 4) for k, v in sheet_scale.items()}
    anim["beanie_game"] = round(float(beanie_game), 2)
    return anim, beanie_game


def build_fx(anim):
    os.makedirs(os.path.join(OUT, "fx"), exist_ok=True)
    # Effects were drawn for a 256 px Cowl in a 512 px cell; the sheets came
    # out with 443.5 px cells, so one sheet px is (512/443.5) brief px, and a
    # brief px is STANDING_H/256 game px.
    for name, spec in FX.items():
        frames, ticks = [], []
        for sname, idxs in spec["src"]:
            st = ticks_of(sname)
            for i in idxs:
                c, cw = cell(sname, i)
                k = 512.0 / cw
                s = k * STANDING_H / 256.0
                a = np.asarray(c).copy()
                a[..., 3][a[..., 3] < 12] = 0
                img = Image.fromarray(a, "RGBA")
                bb = img.getbbox()
                if bb is None:
                    continue
                crop = img.crop(bb)
                big = premul_resize(crop, s * STORE)
                fname = "%s_%02d.png" % (name, len(frames))
                big.save(os.path.join(OUT, "fx", fname), optimize=True)
                ox = (bb[0] * k - spec["origin"][0]) * STANDING_H / 256.0
                oy = (bb[1] * k - spec["origin"][1]) * STANDING_H / 256.0
                frames.append(dict(file=fname, ox=round(ox, 2), oy=round(oy, 2),
                                   w=round(crop.width * s, 2), h=round(crop.height * s, 2)))
                ticks.append(int(st[i]) if st is not None and i < len(st) else 3)
        anim["fx"][name] = dict(frames=frames, ticks=ticks)


def preview(anim):
    """docs/cowl-clips.png: every clip on a floor line, registered as in game."""
    rows = list(anim["clips"].items())
    S = 1.0
    cw, chh = 150, 210
    maxf = max(len(c["frames"]) for _, c in rows)
    sheet_img = Image.new("RGBA", (120 + maxf * cw, len(rows) * chh), (60, 56, 92, 255))
    d = ImageDraw.Draw(sheet_img)
    for r, (name, clip) in enumerate(rows):
        y0 = r * chh + 170
        d.text((6, y0 - 90), name, fill=(255, 230, 150))
        d.line([(110, y0), (sheet_img.width, y0)], fill=(140, 130, 190), width=1)
        for k, f in enumerate(clip["frames"]):
            cx = 120 + k * cw + cw // 2
            d.line([(cx, y0 - 160), (cx, y0 + 10)], fill=(100, 95, 140), width=1)
            im = Image.open(os.path.join(OUT, "frames", f["file"]))
            im = im.resize((max(1, round(f["w"] * S)), max(1, round(f["h"] * S))), Image.LANCZOS)
            sheet_img.alpha_composite(im, (int(cx + f["ox"] * S), int(y0 + f["oy"] * S)))
            # the collision body
            d.rectangle([cx - 20, y0 - 100, cx + 20, y0], outline=(255, 120, 120, 120))
    sheet_img.convert("RGB").save(os.path.join(HERE, "..", "docs", "cowl-clips.png"))


if __name__ == "__main__":
    anim, bg = build_clips()
    build_fx(anim)
    with open(os.path.join(OUT, "cowl_anim.json"), "w") as f:
        json.dump(anim, f, indent=1)
    preview(anim)
    n = sum(len(c["frames"]) for c in anim["clips"].values())
    m = sum(len(c["frames"]) for c in anim["fx"].values())
    print("%d character frames in %d clips, %d effect frames; beanie %.1f px" % (n, len(anim["clips"]), m, bg))
    print("sheet scales:", anim["sheet_scale"])
