"""Level kit: author a level as rectangles, export it as data, draw the blockout.

A level starts as solid mass. Spaces are rectangles carved out of it; masses
are rectangles put back. Everything the player collides with is the mass that
is left, merged into the fewest rectangles. Stairs are single smooth ramps,
never stepped collision. Placed pieces (one-way platforms, gates, pickups,
creatures) come last and are few.

Units are tiles (1 tile = 64 px); x runs right, y runs down. A floor "at y"
means the walking line is the top edge of row y.

The exported JSON is what the game loads (game/level/level.gd).
"""
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

TILE = 64


class Level:
    def __init__(self, name, w, h):
        self.name, self.w, self.h = name, w, h
        self.solid = np.ones((h, w), bool)
        self.kind = np.zeros((h, w), np.uint8)   # 0 mass, 1 space
        self.slopes, self.oneways, self.rooms = [], [], []
        self.entities, self.props, self.labels = [], [], []
        self.zones = []
        self.spawn = (2, 2)
        self.ops = []

    # ------------------------------------------------------------ the mass
    def carve(self, x, y, w, h, note=""):
        """Take a rectangular space out of the mass."""
        self.solid[y:y + h, x:x + w] = False
        self.ops.append(("carve", x, y, w, h, note))

    def fill(self, x, y, w, h, note=""):
        """Put a rectangular mass back."""
        self.solid[y:y + h, x:x + w] = True
        self.ops.append(("fill", x, y, w, h, note))

    def stair(self, x0, y0, x1, y1, thick=None, note=""):
        """A staircase as ONE ramp from (x0, y0) to (x1, y1) along its walking
        line. With thick=None it is a solid wedge down to the lower end; with a
        thickness it is a slab with open space beneath (a flying stair)."""
        lo = max(y0, y1)
        if thick is None:
            pts = [(x0, y0), (x1, y1), (x1, lo), (x0, lo)]
            pts = [p for i, p in enumerate(pts) if p not in pts[:i]]
        else:
            pts = [(x0, y0), (x1, y1), (x1, y1 + thick), (x0, y0 + thick)]
        self.slopes.append(dict(pts=[list(p) for p in pts], note=note,
                                line=[x0, y0, x1, y1], thick=thick))

    def oneway(self, x, y, w, kind="ledge", note=""):
        """A thin platform that can be jumped through from below."""
        self.oneways.append(dict(x=x, y=y, w=w, kind=kind, note=note))

    # ------------------------------------------------------- the furniture
    def room(self, name, x, y, w, h, **kw):
        """Name a region. Used for the map, the camera and the art pass."""
        self.rooms.append(dict(name=name, x=x, y=y, w=w, h=h, **kw))

    def zone(self, x, y, w, h, **kw):
        """A camera zone: zoom and framing while Cowl is inside."""
        self.zones.append(dict(x=x, y=y, w=w, h=h, **kw))

    def entity(self, etype, x, y, **kw):
        self.entities.append(dict(type=etype, x=x, y=y, **kw))

    def prop(self, sprite, x, y, **kw):
        """Decoration. Never collides. x, y is the prop's bottom centre."""
        self.props.append(dict(sprite=sprite, x=x, y=y, **kw))

    def label(self, x, y, text):
        self.labels.append((x, y, text))

    # --------------------------------------------------------------- export
    def rects(self):
        """Merge the mass into rectangles: maximal runs along each row, then
        identical runs stacked. Every floor is therefore one unbroken edge."""
        fixed, open_runs = [], {}
        for y in range(self.h + 1):
            runs = set()
            if y < self.h:
                x = 0
                while x < self.w:
                    if self.solid[y, x]:
                        x0 = x
                        while x < self.w and self.solid[y, x]:
                            x += 1
                        runs.add((x0, x))
                    else:
                        x += 1
            for r in list(open_runs):
                if r not in runs:
                    y0 = open_runs.pop(r)
                    fixed.append([r[0], y0, r[1] - r[0], y - y0])
            for r in runs:
                open_runs.setdefault(r, y)
        return fixed

    def to_dict(self):
        return dict(
            name=self.name, tile=TILE, w=self.w, h=self.h,
            spawn=list(self.spawn),
            solids=self.rects(),
            slopes=self.slopes, oneways=self.oneways,
            rooms=self.rooms, zones=self.zones,
            entities=self.entities, props=self.props,
            labels=[list(l) for l in self.labels],
        )

    def export(self, path):
        with open(path, "w") as f:
            json.dump(self.to_dict(), f, indent=1)
        return path

    # ------------------------------------------------------------- measures
    def floor_runs(self):
        """Flat floors as (y, x0, x1): cells with two open rows above mass."""
        runs = []
        s = self.solid
        for y in range(2, self.h):
            x = 0
            while x < self.w:
                ok = s[y, x] and not s[y - 1, x] and not s[y - 2, x]
                if ok:
                    x0 = x
                    while x < self.w and s[y, x] and not s[y - 1, x] and not s[y - 2, x]:
                        x += 1
                    runs.append((y, x0, x))
                else:
                    x += 1
        return runs

    def measure(self):
        runs = self.floor_runs()
        total = sum(b - a for _, a, b in runs) or 1
        long_ = sum(b - a for _, a, b in runs if b - a >= 8)
        plat = sum(o["w"] for o in self.oneways)
        open_ = int((~self.solid).sum())
        return dict(
            rectangles=len(self.rects()),
            ramps=len(self.slopes),
            oneway_platforms=len(self.oneways),
            floor_tiles=total,
            floor_in_runs_of_8_plus=round(long_ / total, 3),
            longest_floor=max((b - a for _, a, b in runs), default=0),
            platform_share_of_standing=round(plat / (total + plat), 3),
            open_share=round(open_ / (self.w * self.h), 3),
            short_floors_under_3=sum(1 for _, a, b in runs if b - a < 3),
        )

    # -------------------------------------------------------------- drawing
    def draw(self, path, scale=12, walked=None, title=None, screen=(30, 17), cowl=(0.62, 1.56)):
        """The collision blockout: black mass, pale space, ramps, platforms,
        gates and markers. `walked` is an optional set/dict of (x, y) standing
        cells from the in-engine explorer."""
        S = scale
        img = Image.new("RGB", (self.w * S, self.h * S), (10, 9, 14))
        d = ImageDraw.Draw(img, "RGBA")
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", max(9, int(S * 1.1)))
            small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", max(8, int(S * 0.8)))
        except Exception:
            font = small = ImageFont.load_default()
        space = (203, 196, 226)
        for y in range(self.h):
            for x in range(self.w):
                if not self.solid[y, x]:
                    d.rectangle([x * S, y * S, x * S + S - 1, y * S + S - 1], fill=space)
        for r in self.rooms:
            tint = r.get("tint")
            if tint:
                d.rectangle([r["x"] * S, r["y"] * S, (r["x"] + r["w"]) * S, (r["y"] + r["h"]) * S],
                            fill=tuple(tint) + (60,))
        for sl in self.slopes:
            d.polygon([(p[0] * S, p[1] * S) for p in sl["pts"]], fill=(10, 9, 14))
        for o in self.oneways:
            d.rectangle([o["x"] * S, o["y"] * S, (o["x"] + o["w"]) * S, o["y"] * S + max(2, S // 4)],
                        fill=(196, 120, 40))
        colors = {
            "vine": (40, 160, 70), "knife": (230, 60, 60), "crawler": (200, 60, 200),
            "drifter": (200, 60, 200), "spikes": (220, 40, 40), "checkpoint": (60, 170, 230),
            "lab_door": (240, 200, 60), "lift": (240, 150, 30), "lever": (240, 150, 30),
            "family": (90, 90, 110), "biome_door": (90, 230, 90), "hint": (120, 120, 120),
            "false_wall": (150, 110, 190), "bookcase_door": (150, 110, 190),
            "dummy": (200, 60, 200), "crack": (170, 140, 110), "note": (120, 120, 120),
        }
        for e in self.entities:
            c = colors.get(e["type"], (255, 255, 255))
            w, h = e.get("w", 1), e.get("h", 1)
            x, y = e["x"], e["y"]
            d.rectangle([x * S, (y - h) * S, (x + w) * S - 1, y * S - 1], fill=c + (200,), outline=c)
        sx, sy = self.spawn
        d.ellipse([(sx - 0.4) * S, (sy - 1.6) * S, (sx + 0.4) * S, sy * S], fill=(255, 255, 255), outline=(230, 60, 60))
        if walked:
            for (x, y) in walked:
                d.rectangle([x * S + S * 0.25, y * S - S * 0.3, x * S + S * 0.75, y * S - 1], fill=(30, 150, 255, 220))
        for r in self.rooms:
            d.text((r["x"] * S + 4, r["y"] * S + 3), r["name"], fill=(60, 40, 110), font=font)
        for (x, y, text) in self.labels:
            d.text((x * S, y * S), text, fill=(90, 60, 30), font=small)
        # scale bar: one screen, one Cowl
        bx, by = S, (self.h - 3) * S
        d.rectangle([bx, by - screen[1] * S // 6, bx + screen[0] * S, by + 2], outline=(255, 210, 90))
        d.text((bx + 4, by - screen[1] * S // 6 - S * 1.4), "one screen wide = %d tiles" % screen[0], fill=(255, 210, 90), font=small)
        if title:
            d.text((S, S // 2), title, fill=(255, 255, 255), font=font)
        img.save(path)
        return path

    def draw_window(self, path, cx, cy, screen=(30, 17), scale=48, walked=None):
        """A play-scale window: what one screen shows, with Cowl to scale."""
        full = self.draw("/tmp/_levelkit_tmp.png", scale=scale, walked=walked)
        img = Image.open(full)
        x0 = int((cx - screen[0] / 2) * scale)
        y0 = int((cy - screen[1] / 2) * scale)
        img.crop((x0, y0, x0 + screen[0] * scale, y0 + int(screen[1] * scale))).save(path)
        return path
