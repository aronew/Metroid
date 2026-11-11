"""Build, measure, walk and draw Warren 01.

  python3 build.py

Writes warren.json (the level as data), report.txt (measured rules and the
walk) and three drawings. The movement numbers below are provisional: the
game has none yet, so every result here holds only for these numbers.
"""
import json, math, os, sys
from collections import deque
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import layout as L

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = L.W, L.H

# ---------------------------------------------------------------- movement
BODY_W, BODY_H = 0.8, 1.8
MODELS = {
    "cautious": dict(rise=3.4, gap=5.0),
    "generous": dict(rise=3.9, gap=6.6),
}
T_APEX = 0.40
SCREEN = (32, 18)


# ---------------------------------------------------------------- the grid
def build_grid(open_crust=False):
    solid = np.ones((H, W), bool)
    for s in L.spaces:
        solid[s["y"]:s["y"] + s["h"], s["x"]:s["x"] + s["w"]] = False
    for m in L.masses:
        solid[m["y"]:m["y"] + m["h"], m["x"]:m["x"] + m["w"]] = True
    # pockets carved after masses (flooded pocket inside the shelf)
    for s in L.spaces:
        if s["kind"] == "pocket":
            solid[s["y"]:s["y"] + s["h"], s["x"]:s["x"] + s["w"]] = False
    for m in L.masses:
        if m["kind"] == "turn-block":
            solid[m["y"]:m["y"] + m["h"], m["x"]:m["x"] + m["w"]] = True
    if not open_crust:
        for c in L.crust:
            solid[c["y"]:c["y"] + c["h"], c["x"]:c["x"] + c["w"]] = True
    return solid


def mask(rects):
    m = np.zeros((H, W), bool)
    for r in rects:
        m[r["y"]:r["y"] + r["h"], r["x"]:r["x"] + r["w"]] = True
    return m


# ---------------------------------------------------------------- the walker
class Walker:
    def __init__(self, solid, wet, cling, model):
        self.s, self.wet, self.cling = solid, wet & ~solid, cling & ~solid
        self.rise, self.gap = model["rise"], model["gap"]
        self.g = 2 * self.rise / T_APEX ** 2
        self.v0 = self.g * T_APEX
        self.vx = self.gap / (2 * T_APEX)

    def is_solid(self, x, y):
        if x < 0 or x >= W or y < 0:
            return True
        if y >= H:
            return False
        return self.s[y, x]

    def stand(self, x, y):
        return (0 <= x < W and 1 <= y < H - 1 and not self.s[y, x]
                and not self.s[y - 1, x] and self.s[y + 1, x])

    def hits(self, px, feet):
        x0, x1 = math.floor(px - BODY_W / 2), math.floor(px + BODY_W / 2 - 1e-6)
        y0, y1 = math.floor(feet - BODY_H), math.floor(feet - 1e-6)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if self.is_solid(x, y):
                    return True
        return False

    def flight(self, x, y, vx, vy, stop_at=None):
        """Fly a body from a standing cell. Returns the landing cell or None."""
        px, feet, dt, t = x + 0.5, y + 1.0, 1 / 60, 0.0
        while t < 6.0:
            t += dt
            if stop_at is not None and t >= stop_at:
                vx = 0.0
            nx = px + vx * dt
            if not self.hits(nx, feet):
                px = nx
            vy = min(vy + self.g * dt, 34.0)
            nf = feet + vy * dt
            if self.hits(px, nf):
                if vy > 0:
                    cy = math.floor(nf) - 1
                    cx = math.floor(px)
                    for c in (cx, math.floor(px - BODY_W / 2), math.floor(px + BODY_W / 2 - 1e-6)):
                        if self.stand(c, cy):
                            return ("stand", c, cy)
                    return None
                vy = 0.0
            else:
                feet = nf
            if feet > H + 1:
                return ("exit", math.floor(px), H)
            cx, cy = math.floor(px), math.floor(feet - 0.9)
            if 0 <= cx < W and 0 <= cy < H and self.wet[cy, cx]:
                return ("wet", cx, cy)
        return None

    def moves(self, node, use_cling):
        kind, x, y = node
        out = set()
        free = self.wet | (self.cling if use_cling else np.zeros_like(self.wet))
        if kind in ("wet", "cling"):
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if (dx or dy) and 0 <= nx < W and 0 <= ny < H and not self.s[ny, nx]:
                        if free[ny, nx]:
                            out.add(("wet" if self.wet[ny, nx] else "cling", nx, ny))
                        elif self.stand(nx, ny):
                            out.add(("stand", nx, ny))
            if kind == "wet" and y > 0 and not self.wet[y - 1, x] and not self.s[y - 1, x]:
                # leave the surface with a short hop
                for d in (-1, 1):
                    for up in (1, 2):
                        if self.stand(x + d, y - up) or self.stand(x + d, y - up + 1):
                            ty = y - up if self.stand(x + d, y - up) else y - up + 1
                            out.add(("stand", x + d, ty))
            return out
        speeds = [self.vx * f for f in (-1, -0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75, 1)]
        for d in (-1, 1):
            if self.stand(x + d, y):
                out.add(("stand", x + d, y))
            elif not self.is_solid(x + d, y) and not self.is_solid(x + d, y - 1):
                for v in (0.15, 0.5, 1.0):                 # walk off the edge
                    r = self.flight(x + d, y, d * self.vx * v, 0.0)
                    if r:
                        out.add(r)
        for v in speeds:
            for stop in (None, T_APEX, 0.2):
                if v == 0 and stop:
                    continue
                r = self.flight(x, y, v, -self.v0, stop)
                if r:
                    out.add(r)
        if free[y, x] or (y > 0 and free[y - 1, x]):
            out.add(("wet" if self.wet[y, x] else "cling", x, y))
        for d in (-1, 1):                                  # step into a pool or onto a cling wall
            for dy in (0, 1):
                nx, ny = x + d, y + dy
                if 0 <= nx < W and ny < H and free[ny, nx]:
                    out.add(("wet" if self.wet[ny, nx] else "cling", nx, ny))
        return out

    def graph(self, use_cling):
        start = ("stand",) + L.START
        edges, seen, q = {}, {start}, deque([start])
        while q:
            n = q.popleft()
            edges[n] = self.moves(n, use_cling)
            for m in edges[n]:
                if m[0] != "exit" and m not in seen:
                    seen.add(m)
                    q.append(m)
        return start, edges, seen


def can_return(start, edges, seen):
    back = {n: set() for n in seen}
    for a, outs in edges.items():
        for b in outs:
            if b in back:
                back[b].add(a)
    ok, q = {start}, deque([start])
    while q:
        n = q.popleft()
        for m in back[n]:
            if m not in ok:
                ok.add(m)
                q.append(m)
    return ok


# ---------------------------------------------------------------- measuring
def floors(solid):
    """Flat floor runs as (y, x0, x1) of standing cells."""
    runs = []
    for y in range(1, H - 1):
        x = 0
        while x < W:
            if not solid[y, x] and not solid[y - 1, x] and solid[y + 1, x]:
                x0 = x
                while x < W and not solid[y, x] and not solid[y - 1, x] and solid[y + 1, x]:
                    x += 1
                runs.append((y, x0, x))
            else:
                x += 1
    return runs


def headroom(solid, x, y):
    n = 0
    while y - n >= 0 and not solid[y - n, x]:
        n += 1
    return n


def measure(solid):
    out = {}
    out["open share of the frame"] = round(float((~solid).mean()), 3)
    runs = floors(solid)
    total = sum(x1 - x0 for _, x0, x1 in runs)
    out["floor tiles"] = total
    out["longest flat floor"] = max(x1 - x0 for _, x0, x1 in runs)
    out["floor in flat runs of 8 or more"] = round(sum(x1 - x0 for _, x0, x1 in runs if x1 - x0 >= 8) / total, 3)
    low = sum(1 for y, x0, x1 in runs for x in range(x0, x1) if headroom(solid, x, y) <= 5)
    out["floor under a ceiling of 5 or less"] = round(low / total, 3)
    feet = [(y, x0, x1) for y, x0, x1 in runs if x1 - x0 <= 8]
    out["footholds (floors 8 long or shorter)"] = len(feet)
    stacked = 0
    for (ya, a0, a1) in feet:
        for (yb, b0, b1) in feet:
            if 2 <= ya - yb <= 6 and min(a1, b1) - max(a0, b0) >= 2:
                if not solid[yb + 1:ya, max(a0, b0):min(a1, b1)].any() is False:
                    col = solid[yb + 2:ya - 1, max(a0, b0):min(a1, b1)]
                    if col.size and not col.any():
                        stacked += 1
    out["stacked footholds"] = stacked
    zig = 0
    for (ya, a0, a1) in feet:
        for (yb, b0, b1) in feet:
            if not (2 <= ya - yb <= 4):
                continue
            for (yc, c0, c1) in feet:
                if 2 <= yb - yc <= 4 and max(a1, b1, c1) - min(a0, b0, c0) <= 14:
                    zig += 1
    out["zig-zag climbs"] = zig
    small = 0
    for (ya, a0, a1) in runs:
        for (yb, b0, b1) in runs:
            if 1 <= ya - yb <= 2 and (b0 == a1 or b1 == a0):
                small += 1
    out["one- or two-tile floor steps"] = small
    out["platforms"] = 0
    out["ladders"] = 0
    return out


# ---------------------------------------------------------------- drawing
def font(size, bold=False):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if bold else ""),):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def draw_blockout(solid, path, S=7):
    img = Image.new("RGB", (W * S, H * S + 60), (10, 12, 18))
    d = ImageDraw.Draw(img)
    d.text((10, 8), "Collision blockout: black is rock, grey is the space carved from it", font=font(18, True), fill=(235, 235, 235))
    d.text((10, 32), "Every edge is a rectangle's edge. Blue is water, amber is breakable crust, green is a wall-cling face.", font=font(13), fill=(150, 155, 165))
    oy = 60
    wet, cr, cl = mask(L.water), mask(L.crust), mask(L.cling)
    for y in range(H):
        for x in range(W):
            c = None
            if cr[y, x]:
                c = (196, 142, 48)
            elif not solid[y, x]:
                c = (86, 128, 178) if wet[y, x] else (198, 202, 212)
            if c:
                d.rectangle([x * S, oy + y * S, x * S + S - 1, oy + y * S + S - 1], fill=c)
    for c in L.cling:
        d.rectangle([c["x"] * S, oy + c["y"] * S, c["x"] * S + 2, oy + (c["y"] + c["h"]) * S], fill=(120, 220, 170))
    for (x, y, t) in L.labels:
        d.text((x * S, oy + y * S - 4), t, font=font(12, True), fill=(240, 240, 240), stroke_width=2, stroke_fill=(10, 12, 18))
    for dr in L.doors:
        d.text((min(dr["x"] * S + 4, W * S - 80), oy + dr["y"] * S - 16), dr["name"], font=font(11), fill=(250, 210, 120))
    img.save(path)


def draw_map(solid, path, S=7, seed=7):
    """The same rectangles under a stand-in skin, in the look of a region map."""
    rng = np.random.default_rng(seed)
    big = np.kron((~solid).astype(np.float32), np.ones((S, S), np.float32))
    hh, ww = big.shape
    def field(cell, blur):
        n = rng.random((hh // cell + 2, ww // cell + 2)).astype(np.float32)
        im = Image.fromarray((n * 255).astype(np.uint8)).resize((ww, hh), Image.BICUBIC)
        return np.asarray(im.filter(ImageFilter.GaussianBlur(blur)), np.float32) / 255 - 0.5
    soft = np.asarray(Image.fromarray((big * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.6)), np.float32) / 255
    skin = (soft + field(9, 2) * 0.55 + field(26, 6) * 0.30) > 0.5
    # colour: deep blue with patches of teal light
    glow = rng.random((hh // 40 + 2, ww // 40 + 2)).astype(np.float32)
    glow = np.asarray(Image.fromarray((glow * 255).astype(np.uint8)).resize((ww, hh), Image.BICUBIC), np.float32) / 255
    glow = np.clip((glow - 0.45) * 2.2, 0, 1)
    grain = np.asarray(Image.fromarray((rng.random((hh // 3 + 1, ww // 3 + 1)) * 255).astype(np.uint8)).resize((ww, hh), Image.BILINEAR), np.float32) / 255
    r = 16 + 14 * grain + 20 * glow
    g = 22 + 18 * grain + 95 * glow
    b = 52 + 34 * grain + 80 * glow
    wetbig = np.kron(mask(L.water).astype(np.float32), np.ones((S, S), np.float32)) > 0
    g = np.where(wetbig, g + 40, g); b = np.where(wetbig, b + 55, b)
    rgb = np.stack([r, g, b], -1) * skin[..., None]
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    m = Image.fromarray((skin * 255).astype(np.uint8))
    edge = np.asarray(m.filter(ImageFilter.MaxFilter(5)), np.int16) - np.asarray(m.filter(ImageFilter.MinFilter(3)), np.int16)
    arr = np.asarray(img).copy()
    arr[edge > 0] = (245, 248, 252)
    Image.fromarray(arr).save(path)


def draw_walk(solid, path, res, S=7):
    img = Image.new("RGB", (W * S, H * S + 60), (10, 12, 18))
    d = ImageDraw.Draw(img)
    d.text((10, 8), "The walk: where the player can stand, by what it takes to get there", font=font(18, True), fill=(235, 235, 235))
    key = [("starting moves, and back", (120, 200, 255)), ("water (swum)", (70, 120, 200)),
           ("wall cling only", (120, 220, 170)), ("crust dive only", (230, 170, 60)),
           ("never reached", (235, 70, 70))]
    x = 10
    for t, c in key:
        d.rectangle([x, 36, x + 12, 48], fill=c); d.text((x + 18, 34), t, font=font(13), fill=(190, 195, 205))
        x += 30 + int(d.textlength(t, font=font(13)))
    oy = 60
    for y in range(H):
        for xx in range(W):
            if not solid[y, xx]:
                d.rectangle([xx * S, oy + y * S, xx * S + S - 1, oy + y * S + S - 1], fill=(38, 42, 54))
    for (y, x0, x1) in res["floors"]:
        for xx in range(x0, x1):
            n = ("stand", xx, y)
            c = (235, 70, 70)
            if n in res["base"]:
                c = (120, 200, 255)
            elif n in res["cling"]:
                c = (120, 220, 170)
            elif n in res["crust"]:
                c = (230, 170, 60)
            d.rectangle([xx * S, oy + y * S + 2, xx * S + S - 1, oy + y * S + S - 1], fill=c)
    wet = mask(L.water)
    for y in range(H):
        for xx in range(W):
            if wet[y, xx] and not solid[y, xx]:
                d.rectangle([xx * S, oy + y * S, xx * S + S - 1, oy + y * S + S - 1], fill=(70, 120, 200))
    for (x, y) in L.rewards:
        d.ellipse([x * S - 4, oy + y * S - 4, x * S + 4, oy + y * S + 4], outline=(255, 235, 150), width=2)
    img.save(path)


def draw_windows(solid, path, spots, S=22):
    sw, sh = SCREEN
    img = Image.new("RGB", (2 * (sw * S + 16) + 16, 2 * (sh * S + 44) + 16), (10, 12, 18))
    d = ImageDraw.Draw(img)
    wet = mask(L.water)
    for i, (name, cx, cy, px, py) in enumerate(spots):
        ox = 16 + (i % 2) * (sw * S + 16); oy = 40 + (i // 2) * (sh * S + 44)
        d.text((ox, oy - 26), name + "  (one screen, %d x %d tiles)" % SCREEN, font=font(15, True), fill=(235, 235, 235))
        x0 = max(0, min(W - sw, cx - sw // 2)); y0 = max(0, min(H - sh, cy - sh // 2))
        for y in range(sh):
            for x in range(sw):
                gx, gy = x0 + x, y0 + y
                c = (10, 12, 18) if solid[gy, gx] else ((60, 104, 160) if wet[gy, gx] else (52, 60, 84))
                d.rectangle([ox + x * S, oy + y * S, ox + x * S + S - 1, oy + y * S + S - 1], fill=c)
        d.rectangle([ox, oy, ox + sw * S, oy + sh * S], outline=(90, 96, 110))
        bx, by = ox + (px - x0) * S, oy + (py - y0 + 1) * S
        d.rectangle([bx + S * 0.1, by - BODY_H * S, bx + S * 0.9, by], fill=(250, 250, 250))
    img.save(path)


# ---------------------------------------------------------------- main
def main():
    solid = build_grid()
    wet, cl = mask(L.water), mask(L.cling)
    rep = ["WARREN 01", "", "Movement numbers (provisional):",
           "  body %.1f x %.1f tiles; cautious jump rises %.1f and clears a %.1f gap; generous %.1f and %.1f; screen %d x %d"
           % (BODY_W, BODY_H, MODELS["cautious"]["rise"], MODELS["cautious"]["gap"],
              MODELS["generous"]["rise"], MODELS["generous"]["gap"], *SCREEN), ""]
    m = measure(solid)
    rep.append("Measured:")
    for k, v in m.items():
        rep.append("  %-40s %s" % (k, v))
    rep.append("  %-40s %d spaces, %d masses" % ("rectangles", len(L.spaces), len(L.masses)))

    fl = floors(solid)
    fl = [(y, x0, x1) for (y, x0, x1) in fl if not wet[y, x0]]
    spots = {("stand", x, y) for (y, x0, x1) in fl for x in range(x0, x1)}
    wk = Walker(solid, wet, cl, MODELS["cautious"])
    start, edges, seen = wk.graph(False)
    home = can_return(start, edges, seen)
    base = {n for n in seen if n in home}
    traps = {n for n in seen if n not in home and n[0] == "stand"}
    exits = sorted({(m[1]) for outs in edges.values() for m in outs if m[0] == "exit"})

    gen = Walker(solid, wet, cl, MODELS["generous"])
    _, _, gseen = gen.graph(False)
    _, cedges, cseen = Walker(solid, wet, cl, MODELS["cautious"]).graph(True)
    chome = can_return(start, cedges, cseen)
    solid2 = build_grid(open_crust=True)
    k2 = Walker(solid2, wet, cl, MODELS["cautious"])
    _, kedges, kseen = k2.graph(False)
    khome = can_return(start, kedges, kseen)

    cling_only = {n for n in cseen if n[0] == "stand" and n not in gseen}
    crust_only = {n for n in kseen if n[0] == "stand" and n not in gseen}
    rep += ["", "Walked from the west door:",
            "  standing tiles                           %d" % len(spots),
            "  reached with starting moves, and back    %d (%.1f%%)" % (len(base & spots), 100 * len(base & spots) / len(spots)),
            "  traps (reached, no way back)             %d" % len(traps),
            "  opened only by the wall cling            %d  (shut to the generous model: %s; way back: %s)"
            % (len(cling_only), "yes" if cling_only else "nothing gated", "yes" if cling_only <= chome else "NO"),
            "  opened only by the crust dive            %d  (shut to the generous model: %s; way back: %s)"
            % (len(crust_only), "yes" if crust_only else "nothing gated", "yes" if crust_only <= khome else "NO"),
            "  one-way exits off the frame at x =       %s" % exits]
    never = spots - seen - cling_only - crust_only
    rep.append("  never reached by any set                 %d" % len(never))
    if traps:
        rep.append("  trap tiles: %s" % sorted((n[1], n[2]) for n in traps)[:20])
    if never:
        rep.append("  unreached tiles: %s" % sorted((n[1], n[2]) for n in never)[:30])
    rep += ["", "Not checked: enemies, hazards, camera, and anything that depends on the final movement numbers."]
    open(os.path.join(HERE, "report.txt"), "w").write("\n".join(rep) + "\n")
    print("\n".join(rep))

    json.dump(dict(width=W, height=H, tongue=L.TONGUE, start=L.START, spaces=L.spaces, masses=L.masses,
                   water=L.water, crust=L.crust, cling=L.cling, doors=L.doors,
                   rewards=L.rewards, labels=L.labels),
              open(os.path.join(HERE, "warren.json"), "w"), indent=1)
    draw_blockout(solid, os.path.join(HERE, "1-collision-blockout.png"))
    draw_map(solid, os.path.join(HERE, "2-map-view.png"))
    draw_walk(solid, os.path.join(HERE, "3-walk.png"),
              dict(floors=fl, base=base, cling=cling_only, crust=crust_only))
    draw_windows(solid, os.path.join(HERE, "4-play-scale.png"),
                 [("West stack, a turn", 46, 20, 40, 21), ("The cistern from the terrace", 116, 58, 106, 61),
                  ("East stack, round the upper island", 204, 26, 200, 20), ("Low shrine on the long walk", 136, 80, 126, 85)])


if __name__ == "__main__":
    main()
