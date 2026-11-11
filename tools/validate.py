"""Walk the mansion with the real controller and check the design's claims.

    python3 tools/validate.py

Runs tests/explore (Godot, headless) four times: Cowl before the knife and
after it, each with perfect inputs and with a handicapped, cautious player.
Then checks:
  - every room meant to be open at each stage is reached, by the cautious player;
  - every gate holds, even against perfect inputs;
  - nowhere reachable is a place Cowl cannot leave (the pantry before the
    knife is the one intended exception: the knife is in it);
and draws docs/blockouts/mansion-2-walked.png.
"""
import json, os, subprocess, sys, tempfile
import mansion_layout as M

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
DOCS = os.path.join(ROOT, "docs", "blockouts")
L = M.L

BASE_ROOMS = ["Cowl's bedroom", "upstairs hallway", "grand entrance hall", "sister's room",
              "dining room", "kitchen", "living room", "pantry"]
KNIFE_ROOMS = BASE_ROOMS + ["west tower", "conservatory", "library", "parents' bedroom",
                            "east tower", "attic", "storage rooms", "undercroft", "workshop",
                            "boiler room", "laboratory antechamber", "father's study"]
# Places that must stay out of reach until a later ability: (name, x, y, w, h)
LATER = [("west tower high ledge", 8, 6, 4, 8.5), ("east tower high ledge", 242, 5, 4, 6.5),
         ("undercroft high ledge", 140, 44, 8, 4.5)]
ALLOWED_TRAPS = {"base": ["pantry"], "knife": []}


def explore(mode, cautious):
    out = os.path.join(tempfile.gettempdir(), "explore_%s_%d.json" % (mode, cautious))
    cmd = ["godot", "--headless", "--path", ROOT, "res://tests/explore.tscn", "--",
           "--mode=" + mode, "--out=" + out] + (["--cautious"] if cautious else [])
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    return json.load(open(out))


def room_of(x, y):
    best, area = None, 1e9
    for r in L.rooms:
        if r["x"] - 0.5 <= x <= r["x"] + r["w"] + 0.5 and r["y"] <= y <= r["y"] + r["h"] + 0.01:
            a = r["w"] * r["h"]
            if a < area:
                best, area = r["name"], a
    return best


def rooms_reached(nodes):
    seen = {}
    for x, y in nodes:
        n = room_of(x, y)
        if n:
            seen[n] = seen.get(n, 0) + 1
    return seen


def in_rect(p, r):
    return r[1] <= p[0] <= r[1] + r[3] and r[2] <= p[1] <= r[2] + r[4]


def main():
    lines, bad = [], 0
    results = {}
    for mode in ("base", "knife"):
        for cautious in (False, True):
            results[(mode, cautious)] = explore(mode, cautious)

    def check(ok, text):
        nonlocal bad
        lines.append(("  ok    " if ok else "  FAIL  ") + text)
        bad += 0 if ok else 1

    for mode, want in (("base", BASE_ROOMS), ("knife", KNIFE_ROOMS)):
        perfect, careful = results[(mode, False)], results[(mode, True)]
        lines.append("\n%s  (%d standing spots; %d with a cautious player)" % (
            "BEFORE THE KNIFE" if mode == "base" else "WITH THE KNIFE",
            len(perfect["nodes"]), len(careful["nodes"])))
        got_c, got_p = rooms_reached(careful["nodes"]), rooms_reached(perfect["nodes"])
        for name in want:
            check(name in got_c, "reaches %s (cautious player)" % name)
        for r in L.rooms:
            if r["name"] not in want:
                check(r["name"] not in got_p, "%s stays shut, even with perfect inputs" % r["name"])
        for g in LATER:
            leak = [p for p in perfect["nodes"] if in_rect(p, g)]
            check(not leak, "%s is out of reach (kept for a later ability)" % g[0])
        traps = {}
        for p in perfect["traps"]:
            traps.setdefault(room_of(*p), []).append(p)
        for name, pts in traps.items():
            if name in ALLOWED_TRAPS[mode]:
                lines.append("  note  %s cannot be left without the knife, which is in it (%d spots)" % (name, len(pts)))
            else:
                check(False, "TRAP in %s: %d spots reachable but not escapable, e.g. %s" % (name, len(pts), pts[:3]))
        if not [n for n in traps if n not in ALLOWED_TRAPS[mode]]:
            check(True, "no traps: every reachable spot can get back to the bedroom")
        # coverage of floor by room
        cov = []
        for r in L.rooms:
            cells = [(x, y) for (y, a, b) in L.floor_runs() for x in range(a, b)
                     if r["x"] <= x < r["x"] + r["w"] and r["y"] < y <= r["y"] + r["h"]]
            if not cells or r["name"] not in want:
                continue
            reached = {(int(px), round(py)) for px, py in perfect["nodes"]}
            hit = sum(1 for c in cells if c in reached)
            cov.append("%s %d%%" % (r["name"], round(100 * hit / len(cells))))
        lines.append("  floor stood on: " + ", ".join(cov))

    report = "MANSION WALK REPORT (real controller, default preset)\n" + "\n".join(lines) + "\n"
    print(report)
    open(os.path.join(ROOT, "docs", "mansion-walk-report.txt"), "w").write(report)
    base = {tuple(p) for p in results[("base", False)]["nodes"]}
    knife = {tuple(p) for p in results[("knife", False)]["nodes"]}
    draw_walk(base, knife, results)
    return bad


def draw_walk(base, knife, results):
    from PIL import Image, ImageDraw
    S = 12
    path = L.draw(os.path.join(DOCS, "mansion-2-walked.png"), scale=S,
                  title="Walked with the real controller.  Blue: before the knife.  Green: opened by the knife.  Red: cannot leave.")
    img = Image.open(path)
    d = ImageDraw.Draw(img, "RGBA")
    for (x, y) in knife - base:
        d.rectangle([x * S - 2, y * S - 4, x * S + 2, y * S - 1], fill=(40, 200, 90, 255))
    for (x, y) in base:
        d.rectangle([x * S - 2, y * S - 4, x * S + 2, y * S - 1], fill=(30, 130, 255, 255))
    for mode in ("base", "knife"):
        for (x, y) in results[(mode, False)]["traps"]:
            d.rectangle([x * S - 2, y * S - 7, x * S + 2, y * S - 5], fill=(255, 40, 40, 255))
    img.save(path)


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
