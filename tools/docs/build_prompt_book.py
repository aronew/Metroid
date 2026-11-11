#!/usr/bin/env python3
"""Builds Book 1, Cowl and the Buried Mansion, from its card data.

    python3 tools/docs/build_prompt_book.py           # check the cards, write the page
    python3 tools/docs/build_prompt_book.py --check   # check the cards only

The cards are in prompt_book_data.py beside this file. It writes
docs/art-production/cowl-prompt-book.html; the page's images are in
docs/art-production/attach/, at the same relative paths the published page
uses, so the repo copy opens in any browser.

Each card's prompt is two parts: the card's own text (shown on the page) and
the shared rules for its kind (added when you press Copy, unless the box at
the top is unticked). The shared rules are written once, here.
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

import prompt_book_data as data  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art-production", "cowl-prompt-book.html")
ATTACH_ROOT = os.path.join(ROOT, "docs", "art-production")
DATE = "11 November 2026"

# ---------------------------------------------------------------------------
# The shared rules, by kind of card.
# ---------------------------------------------------------------------------
PROJECT = ("Project: a 2D side-view Metroidvania set in a gothic mansion buried deep underground, swallowed by black roots, "
           "lit by candles and filled with indigo haze. The hero is Cowl, a small charcoal shadow creature in an off-white beanie and red shorts. "
           "These images become game assets, so the technical rules matter as much as the look.")

NO_TEXT = "- No grid lines, frames, borders, labels, numbers, captions, swatches, logos, signatures or watermarks. No text of any kind."
TRANSPARENT = ("- Background: fully transparent (alpha) PNG. Never paint a checkerboard, paper texture, white or a scene behind the art. "
               "If transparency is impossible, use one flat pure magenta #FF00FF background with no gradient, noise, shadow or glow.")


def rules_hero(card):
    return "\n".join([
        "STYLE AND TECHNICAL RULES (they apply to everything in this request)",
        PROJECT,
        "",
        "Look",
        "- HD 2D cartoon illustration matching attached image A exactly: clean cel shading, crisp ink line work, flat colour with one shadow tone and one small highlight per material, the beanie's ribbed knit always visible. No airbrushed gradients, no 3D-render look, no pixel art.",
        "- Ink outline, one even weight: " + card["outline"] + ".",
        "- Strict orthographic side view, like a 2D platformer: no perspective, no camera tilt, no floor plane (unless a frame says he turns toward the viewer).",
        "- Even, neutral light. No cast shadows, no ground shadows, no rim light, no glow, no bloom, no light rays: the game adds all light.",
        "- Colour rules: Cowl's off-white, red and pale cyan are his alone. Props are muted and never brighter than his beanie.",
        "",
        "Canvas",
        "- Exact canvas: " + card["canvas"] + ".",
        TRANSPARENT,
        NO_TEXT,
        "- No other characters, creatures or scenery unless the request says so.",
    ])


MOTION = "\n".join([
    "THE MOTION STANDARD: TOP-TIER AND EXPRESSIVE (this matters most: stiff sheets are rejected)",
    "- These frames play in order at 60 frames per second. The number in brackets before each frame is how many ticks (sixtieths of a second) it shows for.",
    "- Every frame is a new drawing: no two frames on the sheet are copies, even in a held pose. In a hold something still moves: the breath, the beanie's slouch, the wrap ends, the shorts' hems.",
    "- In-betweens: each frame sits between its neighbours. Apart from a smear frame, no part of him jumps more than about a quarter of his height from one frame to the next.",
    "- Ease in and out: frames bunch up where a motion starts and stops and spread out in its fast middle.",
    "- Smears: the fastest frame of a punch, kick, flip or snatch is one deliberate painted smear of the moving limb (stretched and curved, part of the drawing), not a blur over the whole body.",
    "- Squash and stretch, cartoon-strength: he is soft and rubbery. Squash on landings and impacts, stretch on take-offs and strikes; a striking limb may stretch to about 1.3 times its length at contact and snap back. Keep his volume the same.",
    "- Overlap and follow-through: the beanie's slouch, the wrap ends, the drawstring and the shorts' hems lag one or two frames behind his body and overshoot when he stops. The slouch is what makes him read as fluid at game size.",
    "- Arcs: the head, hands, feet and the tip of the slouch travel on curves, never in straight lines.",
    "- Lines of action and silhouette: every key pose has one clear curve through the body and reads if filled solid black. He never stands straight in a move.",
    "- Acting: his eyes are his whole face. Change their shape as each frame says (neutral, chill, focused, surprised, happy, hurt, watery, blink), and lead each action with a glance.",
    "- Attacks have five phases: a short wind-up (the clearest silhouette), a smear on release, contact at full extension, an overshoot past balance, and a recovery.",
    "- Loops: the last frame leads back into the first without a hitch, as if the sheet went round forever.",
])


def sheet_anim(card):
    cols, rows, cw, ch = shape(card["canvas"])
    return "\n".join([
        "SHEET RULES",
        "- Cells are %d×%d px: %d columns × %d rows. One frame per cell, left to right, top to bottom, in the order listed." % (cw, ch, cols, rows),
        "- One fixed camera, the same scale in every cell. He faces RIGHT in every cell unless a frame says otherwise.",
        "- " + data.PLACE + ". Moves across the room show as poses, not as travel across the cell: the game moves him.",
        "- Nothing crosses a cell edge; keep 16 px clear.",
    ])


SHEET_VIEWS = "\n".join([
    "SHEET RULES",
    "- One view or pose per cell, left to right, top to bottom, in the order listed, all at the same scale.",
    "- In every full-body view his soles rest on the same line, y = 400 in the cell, and his body is centred on x = 256. Close-ups fill their cell.",
    "- Nothing crosses a cell edge; keep 16 px clear.",
])

HERO_LOCK = "\n".join([
    "MATCH HIS DESIGN",
    "- Image A is canon for his shapes and colours. When the approved model sheet H1 is attached it is canon for his proportions and refinements (the longer slouch, the hand wraps, the drawstring ends); where they differ, H1 wins.",
    "- Paint him as a hand-drawn illustration. Do not build him from vector shapes or from repeated copies of one part.",
])


def rules_fx(card):
    return "\n".join([
        "STYLE AND TECHNICAL RULES (they apply to everything in this request)",
        PROJECT,
        "",
        "Canvas",
        "- Exact canvas: " + card["canvas"] + ".",
        TRANSPARENT,
        NO_TEXT,
    ])


def sheet_fx(card):
    cols, rows, cw, ch = shape(card["canvas"])
    return "\n".join([
        "SHEET RULES",
        "- Cells are %d×%d px: %d columns × %d rows. One frame per cell, left to right, top to bottom, in the order listed." % (cw, ch, cols, rows),
        "- The number in brackets before each frame is how many ticks (sixtieths of a second) it shows for, at 60 frames per second. Frames ease in and out, and loops lead back into their first frame without a hitch.",
        "- Nothing crosses a cell edge; keep 24 px clear.",
    ])


FX_LOCK = "\n".join([
    "EFFECTS RULES",
    "- Paint every effect in white and pale grey (#FFFFFF to #C8C8D0) unless the request names a colour: the game tints them (violet-grey for soot, lavender for smoke, rose or cyan for hits).",
    "- Cartoon effect shapes: solid fills with one soft inner shade (#B4B4C0) and clean, hand-drawn edges, matching a high-end hand-drawn 2D cartoon game. Not airbrushed clouds, not photographic smoke, fire or light. No black outline around the effect.",
    "- Only the effect: no character, no props, no background.",
])

WORLD_PALETTE = [
    "- Palette: deep indigo and violet. Darks #0B0E20 and #151834, shadows #25254B, mid stone #373869 and #454076, lit stone #524D88, haze and highlights #6B609E to #8A80BE. Roots and earth near-black violet #07081A. Velvet and curtains plum #5E4182. Candle wax pale lilac.",
    "- Reserved colours: never paint red (Cowl's shorts), pale cyan (#B8EAF8, the shadow folk's eyes) or pure white anywhere in the world. Candle flames are flat pale rose (#E6A8B2) shapes. Arcane green (#BFCD5B) only where a request names it. Water is a muted blue (#566FA5).",
    "- Values: anything behind the playfield stays in the mid violets so Cowl's charcoal body reads in front of it; only the solid earth and the foreground roots go near-black.",
]


def rules_world(card, scene=False):
    lines = [
        "STYLE AND TECHNICAL RULES (they apply to everything in this request)",
        PROJECT,
        "",
        "Look",
        "- Match attached images B and C exactly in style: a gothic mansion buried underground, drawn with clean dark ink line work and flat painted shading, three or four tones per material, soft haze between near and far. Not photoreal, not a 3D render, not pixel art.",
        "- Ink outline: " + card["outline"] + ".",
    ] + WORLD_PALETTE + [
        "- Strict orthographic side view, like a 2D platformer: no perspective, no vanishing points, no camera tilt, no visible floor plane.",
    ]
    if scene:
        lines += ["- Light: candlelight and haze painted softly, as in images B and C."]
    else:
        lines += ["- Even, cool ambient light. No cast shadows, no glow, no light rays: the game lights the room."]
    lines += ["", "Canvas", "- Exact canvas: " + card["canvas"] + "."]
    if scene:
        lines += ["- A full painting edge to edge; no transparency.", NO_TEXT]
    else:
        lines += [TRANSPARENT, NO_TEXT,
                  "- Scale: Cowl stands about 240 px tall on these canvases (2 tiles of 128 px in the game's grid); size every piece to him.",
                  "- No characters or creatures."]
    return "\n".join(lines)


def sheet_world(card):
    cols, rows, cw, ch = shape(card["canvas"])
    if cols * rows > 1:
        return "\n".join([
            "SHEET RULES",
            "- Cells are %d×%d px: %d columns × %d rows. One piece per cell, left to right, top to bottom, in the order listed, all at the same scale." % (cw, ch, cols, rows),
            "- Nothing crosses a cell edge unless the request says it tiles; keep 16 px clear.",
        ])
    return ""


TILE_RULES = "\n".join([
    "TILING RULES",
    "- Seamless where the request says: an edge must continue its opposite edge exactly, with no seam, no change of brightness across it, and no single landmark that would repeat noticeably.",
    "- Collision in the game is made of rectangles; this art is laid along their edges. Keep every surface line exactly where the request puts it, perfectly straight; the art may hang past it (moss, roots, drips) but never fills open space by more than 64 px.",
])

WORLD_MOTION = "\n".join([
    "MOTION",
    "- These frames play in order at 60 frames per second; the number in brackets before each frame is how many ticks (sixtieths of a second) it shows for.",
    "- Every frame is a new drawing; the motion is soft and slow, easing in and out; the last frame leads back into the first without a hitch.",
])


def rules_layer(card):
    return "\n".join([
        "STYLE AND TECHNICAL RULES (they apply to everything in this request)",
        PROJECT,
        "",
        "Look",
        "- Match attached images B and C exactly in style: clean dark ink line work and flat painted shading, soft haze between near and far. Not photoreal, not a 3D render, not pixel art.",
        "- Ink outline: thin and lighter with distance (2 px at most at this size), fading into the haze.",
    ] + WORLD_PALETTE + [
        "- A background layer for parallax scrolling: strict orthographic side view, no perspective floor, nothing in the bottom quarter that looks walkable.",
        "- Seamless left to right: the left edge continues the right edge exactly.",
        "",
        "Canvas",
        "- Exact canvas: " + card["canvas"] + ".",
        "- Opaque unless the request says to leave areas transparent; if transparency is impossible, fill those areas with flat pure magenta #FF00FF.",
        NO_TEXT,
        "- No characters or creatures.",
    ])


WORLD_LOCK = "\n".join([
    "MATCH THE WORLD",
    "- Images B and C are canon for the world's style, palette and light. When the approved target render W0 is attached, it is canon for how the world looks at play scale; when the materials sheet W1 is attached, match its materials.",
    "- Paint by hand, as an illustration. Do not build it from vector shapes or repeated copies of one part.",
])


def shared(card):
    k = card["kind"]
    cowl = "\n".join(data.COWL)
    if k == "model":
        parts = [rules_hero(card), cowl, SHEET_VIEWS, HERO_LOCK]
    elif k == "anim":
        parts = [rules_hero(card), cowl, MOTION, sheet_anim(card), HERO_LOCK]
    elif k == "fx":
        parts = [rules_fx(card), sheet_fx(card), FX_LOCK]
    elif k == "target":
        parts = [rules_world(card, scene=True), cowl, WORLD_LOCK]
    elif k == "world":
        parts = [rules_world(card), sheet_world(card), WORLD_LOCK]
    elif k == "tile":
        parts = [rules_world(card), TILE_RULES, WORLD_LOCK]
    elif k == "world-anim":
        parts = [rules_world(card), WORLD_MOTION, sheet_world(card), TILE_RULES if card["canvas"] == data.ROWS8 else "", WORLD_LOCK]
    elif k == "layer":
        parts = [rules_layer(card), WORLD_LOCK]
    else:
        raise ValueError("unknown kind " + k)
    return "\n\n".join(p for p in parts if p)


# ---------------------------------------------------------------------------
# Sheets and frames.
# ---------------------------------------------------------------------------
LAYOUTS = {
    data.EIGHT: (4, 2, 512, 512),
    data.TWELVE: (4, 3, 512, 512),
    data.SIXTEEN: (4, 4, 512, 512),
    data.TALL8: (4, 2, 512, 1024),
    data.STRIP8: (8, 1, 256, 1024),
    data.ROWS8: (1, 8, 2048, 128),
    data.BANDS4: (1, 4, 2048, 256),
    data.WALLS4: (4, 1, 256, 2048),
    data.SQUARE: (1, 1, 1024, 1024),
    data.WIDE: (1, 1, 2048, 1024),
    data.SCREEN: (1, 1, 2048, 1152),
    data.FRAME4: (1, 1, 2048, 2048),
}


def shape(canvas):
    return LAYOUTS[canvas]


def timed(card):
    return bool(card["rows"]) and isinstance(card["rows"][0], tuple)


def body(card):
    lines = [card["task"]]
    if card["rows"]:
        lines.append("")
        for i, row in enumerate(card["rows"], 1):
            if isinstance(row, tuple):
                lines.append("%d. (%d) %s" % (i, row[0], row[1]))
            elif card["kind"] == "target":
                lines.append("- " + row)
            else:
                lines.append("%d. %s" % (i, row))
    if card["attach"]:
        lines.append("")
        lines.append("ATTACHED: " + "; ".join(data.NAMES[a] for a in card["attach"]) + ".")
    return "\n".join(lines)


def sheet_label(card):
    cols, rows, cw, ch = shape(card["canvas"])
    if card["canvas"] == data.FRAME4:
        return "4 pieces"
    if cols * rows == 1:
        return "1 image"
    if card["canvas"] in (data.BANDS4, data.WALLS4):
        return "4 strips"
    if timed(card):
        return "%d drawings" % (cols * rows)
    return "%d cells" % (cols * rows)


def timing(card):
    if not timed(card):
        return ""
    ticks = sum(t for t, _ in card["rows"])
    return "%d ticks (%.2f s)" % (ticks, ticks / 60.0)


# ---------------------------------------------------------------------------
# Checks: every card is well formed before the page is written.
# ---------------------------------------------------------------------------
def check_cards():
    problems = []
    seen = set()
    groups = {g[0] for g in data.GROUPS}
    for c in data.CARDS:
        cid = c["id"]
        if cid in seen:
            problems.append("%s: duplicate id" % cid)
        seen.add(cid)
        if c["group"] not in groups:
            problems.append("%s: unknown group %s" % (cid, c["group"]))
        if c["canvas"] not in LAYOUTS:
            problems.append("%s: unknown canvas" % cid)
            continue
        cols, rows, _, _ = shape(c["canvas"])
        cells = cols * rows
        n = len(c["rows"])
        if c["kind"] in ("anim", "fx", "world-anim"):
            if not timed(c):
                problems.append("%s: an animation card needs (ticks, words) rows" % cid)
            elif n != cells:
                problems.append("%s: %d frames for %d cells" % (cid, n, cells))
            elif any(t < 1 for t, _ in c["rows"]):
                problems.append("%s: a frame shorter than one tick" % cid)
            else:
                said = re.search(r"(\d+) drawings, (\d+) ticks", c["about"])
                total = sum(t for t, _ in c["rows"])
                if said and (int(said.group(1)) != n or int(said.group(2)) != total):
                    problems.append("%s: its description says %s drawings, %s ticks; the frames make %d drawings, %d ticks"
                                    % (cid, said.group(1), said.group(2), n, total))
        elif c["kind"] in ("model", "world") and cells > 1 and n != cells:
            problems.append("%s: %d views for %d cells" % (cid, n, cells))
        elif c["kind"] == "world" and c["canvas"] == data.FRAME4 and n != 4:
            problems.append("%s: %d pieces for 4" % (cid, n))
        elif c["kind"] == "tile" and c["canvas"] in (data.BANDS4, data.WALLS4) and n != 4:
            problems.append("%s: %d strips for 4" % (cid, n))
        for a in c["attach"]:
            if a not in data.NAMES:
                problems.append("%s: attachment %s has no name" % (cid, a))
            elif re.fullmatch(r"[HWF]\d+", a) and a not in {x["id"] for x in data.CARDS}:
                problems.append("%s: attaches %s, which is not a card" % (cid, a))
        text = shared(c) + "\n\n" + body(c)
        if len(text) > 12000:
            problems.append("%s: the copied prompt is %d characters (keep it under 12000)" % (cid, len(text)))
        if "Naruto" in text:
            problems.append("%s: name the pose, not another franchise" % cid)
    ids = [c["id"] for c in data.CARDS]
    for c in data.CARDS:
        for a in c["attach"]:
            if a in ids and ids.index(a) > ids.index(c["id"]) and c["id"] != "W0":
                problems.append("%s attaches %s, which comes later in the book" % (c["id"], a))
    for p in data.PACK:
        for path in (p[1], p[2]):
            if not os.path.exists(os.path.join(ATTACH_ROOT, path)):
                problems.append("missing image " + path)
    return problems


# ---------------------------------------------------------------------------
# The page.
# ---------------------------------------------------------------------------
def esc(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def js_value(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")


def cards_json(texts):
    """Cards for the page. Many cards share the same rules text, so each
    card points into `texts` instead of carrying its own copy."""
    out = []
    for c in data.CARDS:
        text = shared(c)
        if text not in texts:
            texts.append(text)
        cols, rows, cw, ch = shape(c["canvas"])
        item = {
            "id": c["id"], "group": c["group"], "kind": c["kind"], "title": c["title"],
            "about": c["about"], "file": c["file"], "canvas": c["canvas"], "game": c["game"],
            "attach": c["attach"], "pilot": c["pilot"], "body": body(c), "shared": texts.index(text),
            "sheet": sheet_label(c), "timing": timing(c),
            "layout": {"cols": cols, "rows": rows, "cw": cw, "ch": ch},
        }
        if timed(c):
            item["ticks"] = [t for t, _ in c["rows"]]
        out.append(item)
    return out


SHARED_EXAMPLES = [
    ("Cowl's animation cards", "H12"),
    ("Cowl's reference sheets", "H1"),
    ("Effects", "F1"),
    ("World pieces", "W10"),
    ("Tiling pieces", "W3"),
    ("Background layers", "W21"),
]


def shared_examples(texts):
    by_id = {c["id"]: c for c in data.CARDS}
    return [[label, cid, texts.index(shared(by_id[cid]))] for label, cid in SHARED_EXAMPLES]


def table_html():
    rows = []
    group_titles = {g[0]: g[2] for g in data.GROUPS}
    current = None
    for c in data.CARDS:
        if c["group"] != current:
            current = c["group"]
            rows.append('          <tr class="group-row"><th colspan="4" scope="colgroup">%s</th></tr>' % esc(group_titles[current]))
        size = sheet_label(c)
        t = timing(c)
        rows.append('          <tr><td><a href="#%s"><code>%s</code></a></td><td>%s%s</td><td>%s</td><td class="num">%s</td></tr>' % (
            c["id"], c["id"], esc(c["title"]), ' <span class="pill">make first</span>' if c["pilot"] else "",
            esc(size), esc(t)))
    return "\n".join(rows)


def nav_html():
    parts = ['      <span class="nav-group">Start</span>']
    for anchor, label in START_NAV:
        parts.append('      <a href="#%s">%s</a>' % (anchor, esc(label)))
    parts.append('      <span class="nav-group">Prompts</span>')
    for gid, _, title, _ in data.GROUPS:
        parts.append('      <a href="#%s">%s</a>' % (gid, esc(title)))
    parts.append('      <span class="nav-group">Finish</span>')
    for anchor, label in FINISH_NAV:
        parts.append('      <a href="#%s">%s</a>' % (anchor, esc(label)))
    return "\n".join(parts)


START_NAV = [("direction", "Your direction"), ("cowl", "Cowl's look"), ("world", "The buried mansion"),
             ("cards-table", "The cards"), ("motion", "The motion standard"), ("game", "What the game adds"),
             ("contract", "The asset contract"), ("workflow", "How to use this book"), ("pack", "Images to attach"),
             ("shared", "The shared rules"), ("tester", "Sheet tester")]
FINISH_NAV = [("checks", "Check every result"), ("fixes", "If SOL falls short"), ("after", "What happens next")]


def groups_html():
    parts = []
    for gid, eyebrow, title, about in data.GROUPS:
        parts.append("""    <section id="%s" class="group-section">
      <span class="eyebrow">%s</span>
      <h2>%s</h2>
      <p class="section-lede">%s</p>
      <div class="cards" id="cards-%s"></div>
    </section>""" % (gid, esc(eyebrow), esc(title), esc(about), gid))
    return "\n\n".join(parts)


def swatches(items):
    return "\n".join('          <li><span class="chip" style="background:%s"></span><span><b>%s</b><code>%s</code></span></li>' % (hexv, esc(name), hexv)
                     for name, hexv in items)


HERO_SWATCHES = [("Charcoal", "#2A2A2C"), ("Charcoal shadow", "#1C1C1F"), ("Beanie", "#EBE5E1"), ("Beanie shadow", "#C4BCB6"),
                 ("Wraps", "#E3DAD2"), ("Shorts", "#933731"), ("Shorts shadow", "#6E2622"), ("Eyes", "#B8EAF8")]
WORLD_SWATCHES = [("Earth", "#07081A"), ("Darks", "#151834"), ("Shadow", "#25254B"), ("Mid stone", "#373869"),
                  ("Lit stone", "#524D88"), ("Haze", "#6B609E"), ("Plum velvet", "#5E4182"), ("Candle", "#E6A8B2"),
                  ("Sealed door", "#BFCD5B"), ("Water", "#566FA5")]

CSS = r"""<style>
/* Book 1. A working manual in the mansion's own night: indigo ground,
   the beanie's off-white for text, Cowl's eye cyan for everything you press,
   candle rose for notes. Layout: sticky control bar, a contents rail on wide
   screens, one reading column, prompt cards you copy from. */
:root {
  color-scheme: dark;
  --bg: #0D0F22;
  --panel: #15183A;
  --panel-2: #1C1F47;
  --line: #2F3266;
  --fg: #ECE6E2;
  --muted: #A9A4CB;
  --faint: #7B77A3;
  --eye: #B8EAF8;
  --eye-ink: #0D0F22;
  --rose: #E6A8B2;
  --red: #D2564A;
  --green: #BFCD5B;
  --code-bg: #0A0B1B;
  --font-display: "Grenze Gotisch", "Grenze", Georgia, serif;
  --font-body: "Figtree", "Segoe UI", system-ui, sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, "SFMono-Regular", Menlo, monospace;
  --step--1: 0.84rem;
  --step-0: 1rem;
  --step-1: 1.2rem;
  --step-2: 1.6rem;
  --step-3: 2.3rem;
  --step-4: clamp(2.6rem, 6vw, 4.2rem);
}
* { box-sizing: border-box; }
html { scroll-padding-top: calc(env(safe-area-inset-top, 0px) + 72px); }
body { background: var(--bg); color: var(--fg); font-family: var(--font-body); font-size: var(--step-0); line-height: 1.6; -webkit-font-smoothing: antialiased; }
body::before { content: ""; position: fixed; inset: 0 0 auto; height: env(safe-area-inset-top, 0px); z-index: 10; background: var(--panel); }
a { color: var(--eye); text-underline-offset: 3px; }
a:hover { color: var(--fg); }
:focus-visible { outline: 2px solid var(--eye); outline-offset: 2px; border-radius: 4px; }
code { font-family: var(--font-mono); font-size: 0.86em; background: var(--code-bg); color: var(--fg); padding: 0.1em 0.35em; border-radius: 4px; overflow-wrap: anywhere; }
h1, h2 { font-family: var(--font-display); font-weight: 500; letter-spacing: 0.01em; line-height: 1.1; text-wrap: balance; margin: 0; }
h2 { font-size: var(--step-3); }
h3 { font-size: var(--step-1); line-height: 1.3; margin: 0; font-weight: 600; text-wrap: balance; }
p { margin: 0; }
.eyebrow { display: block; font-size: var(--step--1); text-transform: uppercase; letter-spacing: 0.12em; color: var(--rose); font-weight: 600; }

/* Control bar */
.controls { position: sticky; top: env(safe-area-inset-top, 0px); z-index: 5; background: var(--panel); border-bottom: 1px solid var(--line); padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
.controls .inner { max-width: 1240px; margin: 0 auto; display: flex; flex-wrap: wrap; align-items: center; gap: 8px 20px; padding-block: 10px; }
.controls .title { font-family: var(--font-display); font-size: var(--step-1); margin-right: auto; }
.field { display: inline-flex; align-items: center; gap: 8px; font-size: var(--step--1); color: var(--muted); cursor: pointer; }
.field input { accent-color: var(--eye); width: 16px; height: 16px; }
.progress { font-size: var(--step--1); color: var(--eye); font-variant-numeric: tabular-nums; font-weight: 600; }
@media (max-width: 640px) {
  .controls .title { flex-basis: 100%; }
  .controls .inner { gap: 4px 16px; padding-block: 8px; }
  .wide-only { display: none; }
}

/* Page layout */
.page { max-width: 1240px; margin: 0 auto; display: grid; grid-template-columns: minmax(0, 1fr); gap: 32px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); padding-block: 24px 80px; }
@media (min-width: 1100px) { .page { grid-template-columns: 220px minmax(0, 1fr); } }
.rail nav { display: flex; gap: 6px; overflow-x: auto; padding-bottom: 6px; }
.rail a, .rail .nav-group { white-space: nowrap; }
.rail a { color: var(--muted); text-decoration: none; font-size: var(--step--1); padding: 4px 10px; border: 1px solid var(--line); border-radius: 999px; }
.rail a:hover { color: var(--fg); border-color: var(--eye); }
.rail .nav-group { display: none; }
@media (min-width: 1100px) {
  .rail nav { position: sticky; top: calc(env(safe-area-inset-top, 0px) + 72px); flex-direction: column; gap: 2px; overflow: visible; max-height: calc(100vh - 100px); overflow-y: auto; }
  .rail a { border: 0; border-left: 2px solid var(--line); border-radius: 0; padding: 3px 12px; white-space: normal; }
  .rail a:hover { border-left-color: var(--eye); }
  .rail .nav-group { display: block; margin-top: 14px; padding-left: 12px; font-size: var(--step--1); text-transform: uppercase; letter-spacing: 0.12em; color: var(--rose); font-weight: 600; }
}
main { min-width: 0; display: grid; gap: 56px; }
main > section, main > header { min-width: 0; display: grid; gap: 16px; align-content: start; }
.section-lede, main > section > p { max-width: 68ch; color: var(--muted); }

/* Header */
.hero { gap: 18px; }
.banner { position: relative; border-radius: 14px; overflow: hidden; border: 1px solid var(--line); background: var(--panel); aspect-ratio: 1885 / 834; max-width: 100%; }
.banner img { display: block; width: 100%; height: 100%; object-fit: cover; }
.banner .cowl { position: absolute; right: 2%; bottom: 0; width: 22%; height: auto; filter: drop-shadow(0 6px 18px rgba(0,0,0,0.6)); border-radius: 10px; }
.hero h1 { font-size: var(--step-4); }
.hero .lede { font-size: var(--step-1); max-width: 62ch; color: var(--fg); }
.meta { display: flex; flex-wrap: wrap; gap: 8px; }
.meta span { font-size: var(--step--1); color: var(--muted); border: 1px solid var(--line); border-radius: 999px; padding: 3px 12px; font-variant-numeric: tabular-nums; }

/* Tables */
.table-wrap { overflow-x: auto; border: 1px solid var(--line); border-radius: 10px; }
table { border-collapse: collapse; width: 100%; font-size: 0.94rem; }
th, td { text-align: left; vertical-align: top; padding: 9px 12px; border-bottom: 1px solid var(--line); }
thead th { background: var(--panel); color: var(--muted); font-weight: 600; font-size: var(--step--1); text-transform: uppercase; letter-spacing: 0.08em; }
tbody tr:last-child td { border-bottom: 0; }
td.num { font-variant-numeric: tabular-nums; white-space: nowrap; color: var(--muted); }
tr.group-row th { background: var(--panel-2); color: var(--rose); font-size: var(--step--1); text-transform: uppercase; letter-spacing: 0.1em; }
.direction td:first-child { color: var(--rose); font-style: italic; min-width: 12ch; }
.pill { display: inline-block; font-size: 0.72rem; font-weight: 600; color: var(--eye-ink); background: var(--eye); border-radius: 999px; padding: 0 8px; margin-left: 6px; vertical-align: 1px; white-space: nowrap; }

/* Lists and panels */
.cols { display: grid; gap: 14px; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); }
.kv { background: var(--panel); border: 1px solid var(--line); border-radius: 12px; padding: 16px; display: grid; gap: 10px; align-content: start; min-width: 0; }
.checks { margin: 0; padding-left: 1.1em; display: grid; gap: 6px; color: var(--muted); }
.checks li::marker { color: var(--eye); }
.steps { margin: 0; padding-left: 1.4em; display: grid; gap: 10px; max-width: 72ch; }
.steps li::marker { color: var(--rose); font-weight: 600; }
.note { border-left: 3px solid var(--rose); padding: 4px 0 4px 14px; color: var(--muted); max-width: 72ch; }
.pilot { background: var(--panel-2); border: 1px solid var(--eye); border-radius: 12px; padding: 16px; display: grid; gap: 8px; max-width: 72ch; }
.pilot strong { color: var(--eye); }
.split { display: grid; gap: 20px; grid-template-columns: minmax(0, 1fr); align-items: start; }
@media (min-width: 760px) { .split { grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr); } }
.figure { margin: 0; border: 1px solid var(--line); border-radius: 12px; overflow: hidden; background: var(--panel); }
.figure img { display: block; width: 100%; height: auto; }
.figure figcaption { padding: 8px 12px; font-size: var(--step--1); color: var(--muted); }
.swatches { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); }
.swatches li { display: flex; align-items: center; gap: 10px; font-size: var(--step--1); min-width: 0; }
.swatches li > span:last-child { display: grid; min-width: 0; }
.swatches code { background: none; padding: 0; color: var(--muted); }
.chip { width: 34px; height: 34px; border-radius: 8px; border: 1px solid var(--line); flex: none; }
.lookgrid { display: grid; gap: 10px; }
.lookgrid h3 { color: var(--rose); font-size: var(--step--1); text-transform: uppercase; letter-spacing: 0.1em; }

/* Images to attach */
.pack { display: grid; gap: 14px; grid-template-columns: repeat(auto-fit, minmax(min(100%, 240px), 1fr)); }
.ref { background: var(--panel); border: 1px solid var(--line); border-radius: 12px; overflow: hidden; display: grid; grid-template-rows: auto 1fr; min-width: 0; }
.ref img { width: 100%; aspect-ratio: 4 / 3; object-fit: contain; background: var(--panel-2); display: block; }
.ref div { padding: 12px; display: grid; gap: 4px; font-size: var(--step--1); color: var(--muted); }
.ref strong { color: var(--fg); font-size: var(--step-0); }

/* Shared rules */
details.rules { background: var(--panel); border: 1px solid var(--line); border-radius: 10px; }
details.rules summary { cursor: pointer; padding: 10px 14px; font-weight: 600; }
details.rules summary code { margin-left: 6px; }
details.rules pre { margin: 0; border-top: 1px solid var(--line); }

/* Cards */
.cards { display: grid; gap: 18px; }
.card { background: var(--panel); border: 1px solid var(--line); border-radius: 14px; padding: 18px; display: grid; gap: 12px; min-width: 0; scroll-margin-top: calc(env(safe-area-inset-top, 0px) + 72px); }
.card.is-done { border-color: color-mix(in srgb, var(--eye) 45%, var(--line)); }
.card.is-done .tag { background: var(--eye); color: var(--eye-ink); }
.card-head { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; gap: 12px; align-items: center; }
.tag { font-family: var(--font-mono); font-size: 0.8rem; font-weight: 500; border: 1px solid var(--eye); color: var(--eye); border-radius: 6px; padding: 2px 8px; white-space: nowrap; }
.tag.first { border-color: var(--rose); color: var(--rose); }
.done { display: inline-flex; align-items: center; gap: 6px; font-size: var(--step--1); color: var(--muted); cursor: pointer; }
.done input { accent-color: var(--eye); width: 16px; height: 16px; }
.about { color: var(--muted); max-width: 72ch; }
.spec { display: grid; grid-template-columns: max-content minmax(0, 1fr); gap: 4px 14px; margin: 0; font-size: 0.9rem; }
.spec dt { color: var(--faint); }
.spec dd { margin: 0; min-width: 0; overflow-wrap: anywhere; }
.thumbs { display: flex; flex-wrap: wrap; gap: 8px; }
.thumb { display: inline-flex; align-items: center; gap: 8px; border: 1px solid var(--line); border-radius: 8px; padding: 4px 10px 4px 4px; font-size: var(--step--1); color: var(--muted); text-decoration: none; background: var(--panel-2); }
.thumb img { width: 34px; height: 34px; object-fit: cover; border-radius: 5px; }
.thumb.approved { padding-left: 10px; }
.thumb b { color: var(--fg); }
.prompt { border: 1px solid var(--line); border-radius: 10px; overflow: hidden; background: var(--code-bg); min-width: 0; }
.prompt-bar { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 12px; padding: 8px 10px 8px 14px; background: var(--panel-2); border-bottom: 1px solid var(--line); font-size: var(--step--1); color: var(--muted); }
.prompt-bar strong { color: var(--fg); }
.prompt-bar .spacer { margin-right: auto; }
pre { margin: 0; padding: 14px; font-family: var(--font-mono); font-size: 0.8rem; line-height: 1.55; white-space: pre-wrap; overflow-wrap: anywhere; color: #D9D4E8; max-height: 26rem; overflow: auto; }
.copy, .btn { font: inherit; font-size: var(--step--1); font-weight: 600; cursor: pointer; border-radius: 8px; padding: 6px 14px; border: 1px solid var(--eye); background: var(--eye); color: var(--eye-ink); }
.copy:hover, .btn:hover { background: var(--fg); border-color: var(--fg); }
.copy.copied { background: var(--green); border-color: var(--green); }
.btn.ghost { background: transparent; color: var(--eye); }
.btn.ghost:hover { color: var(--eye-ink); background: var(--eye); }
.btn[aria-pressed="true"] { background: var(--eye); color: var(--eye-ink); }
.btn.ghost[aria-pressed="false"] { background: transparent; color: var(--eye); }

/* Sheet tester */
.tester { background: var(--panel); border: 1px solid var(--line); border-radius: 14px; padding: 16px; display: grid; gap: 16px; grid-template-columns: minmax(0, 1fr); }
@media (min-width: 900px) { .tester { grid-template-columns: minmax(0, 1fr) 300px; } }
.stage { display: grid; gap: 10px; min-width: 0; }
.stage-box { position: relative; border: 1px dashed var(--line); border-radius: 10px; overflow: hidden; display: grid; place-items: center; background: var(--code-bg); }
.stage-box.drag { border-color: var(--eye); }
#tester-canvas { width: 100%; max-width: 520px; height: auto; aspect-ratio: 1 / 1; display: block; image-rendering: auto; }
.transport { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.readout { font-family: var(--font-mono); font-size: 0.8rem; color: var(--muted); font-variant-numeric: tabular-nums; }
.tester-side { display: grid; gap: 12px; align-content: start; min-width: 0; }
.tester-side label { display: grid; gap: 4px; font-size: var(--step--1); color: var(--muted); }
.tester-side select, .tester-side input[type="text"], .tester-side input[type="number"] { font: inherit; font-size: 0.9rem; color: var(--fg); background: var(--code-bg); border: 1px solid var(--line); border-radius: 8px; padding: 7px 9px; width: 100%; min-width: 0; }
.tester-side .row2 { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.tester-side .toggles { display: flex; flex-wrap: wrap; gap: 6px; }
.file-btn { position: relative; }
.file-btn input { position: absolute; inset: 0; opacity: 0; cursor: pointer; }
.warn { color: var(--rose); font-size: var(--step--1); }
.warn:empty { display: none; }

@media (prefers-reduced-motion: reduce) { * { scroll-behavior: auto !important; transition: none !important; } }
</style>"""

BODY = r"""
<div class="controls" role="region" aria-label="Prompt options">
  <div class="inner">
    <span class="title">Cowl's Prompt Book</span>
    <label class="field" for="include-rules"><input type="checkbox" id="include-rules" checked> Copy the shared rules<span class="wide-only"> with each prompt</span></label>
    <span class="progress" id="progress">0 of __N__ done</span>
  </div>
</div>

<div class="page">
  <aside class="rail" aria-label="Contents">
    <nav>
__NAV__
    </nav>
  </aside>

  <main>
    <header class="hero">
      <div class="banner">
        <img src="attach/previews/banner.jpg" alt="The buried gothic mansion: four floors of candlelit rooms cut into black, root-threaded earth, in indigo haze.">
        <img class="cowl" src="attach/previews/A-hero-mockup.jpg" alt="Cowl: a charcoal shadow creature with glowing cyan slit eyes, an oversized off-white beanie and red shorts.">
      </div>
      <span class="eyebrow">Book 1 · art production · GPT-6 SOL</span>
      <h1>Cowl and the Buried Mansion</h1>
      <p class="lede">Every animation and world asset for the first playable, as copy-ready prompts for GPT-6 SOL. Cowl leans into a ninja run, flips at the top of his jump, vibes in his idle until he sneaks a smoke, and fights bare-handed with a stretchy 1-2 and a spinning kick. The mansion comes as a kit that fits whatever shape the space ends up.</p>
      <div class="meta"><span>__N__ prompts</span><span>__NH__ for Cowl · __NF__ effects · __NW__ world</span><span>512-px cells, halved in game</span><span>60 ticks a second</span><span>__DATE__</span></div>
    </header>

    <section id="direction">
      <span class="eyebrow">Start</span>
      <h2>Your direction</h2>
      <div class="table-wrap"><table class="direction">
        <thead><tr><th>You said</th><th>What this book does</th><th>Cards</th></tr></thead>
        <tbody>
          <tr><td>Lean forward when he runs, like that famous ninja run</td><td>Torso about 45° forward and held, his big head leading past his knees, both arms swept straight back, the slouch streaming like a flag. A start, a skid stop where the slouch flops over his eyes, and a turn.</td><td><a href="#H12">H12</a>, <a href="#H13">H13</a></td></tr>
          <tr><td>A jump that looks cool</td><td>A squash-and-launch, a tight forward flip at the top of a full jump, then hang time with his arms out like wings. A short hop skips the flip. Big drops end in a three-point hero landing and a shoulder brush.</td><td><a href="#H14">H14</a>, <a href="#H15">H15</a></td></tr>
          <tr><td>An idle where he sways and bobs</td><td>Sixteen drawings of him nodding to music only he hears: two sways, each a little different, and one slow blink.</td><td><a href="#H4">H4</a></td></tr>
          <tr><td>After chilling, he pulls out a blunt or a bong</td><td>Both, picked at random after about eight seconds. His beanie is the stash: the blunt comes out of the cuff like a pencil behind an ear, and the bong comes out of the slouch, which bulges around it. Afterwards a lazier, half-lidded idle until you move him. Any input snaps him out at once.</td><td><a href="#H6">H6</a>–<a href="#H11">H11</a>, <a href="#H5">H5</a>, <a href="#F4">F4</a></td></tr>
          <tr><td>No weapon at the start: a cool 1-2 punch and a kick</td><td>A snappy jab and a heavy cross whose arms stretch like rubber on contact, chained into a spinning back kick where he spots the target over his shoulder. A flying kick in the air. Hand wraps are proposed so his fists read at game size.</td><td><a href="#H16">H16</a>–<a href="#H20">H20</a>, <a href="#F1">F1</a>, <a href="#F2">F2</a></td></tr>
          <tr><td>Top-tier, AAA animation</td><td>Twelve to sixteen new drawings per move at 60 fps, smears, cartoon squash and stretch, overlap on the slouch, wraps and shorts, five-phase attacks timed so the hit lands 4 to 12 ticks after the press, and a sheet tester to check every result.</td><td><a href="#motion">The standard</a>, <a href="#tester">tester</a></td></tr>
          <tr><td>Expand on the look</td><td>H0 tests each proposed refinement beside your mockup before anything moves. You pick; H1 locks it.</td><td><a href="#H0">H0</a>, <a href="#H1">H1</a></td></tr>
          <tr><td>World assets from the mansion mockups</td><td>A target render at play scale, then a tiling terrain kit, architecture, props for every room type in your draft, living details (flames, swaying moss) and parallax layers. Nothing is tied to the blockout, which is still being built.</td><td><a href="#W0">W0</a>–<a href="#W24">W24</a></td></tr>
        </tbody>
      </table></div>
      <p class="note">The smoke breaks show drug use on screen. Expect a "Use of Drugs" descriptor from the age-rating boards and on store pages, which usually means a teen-or-older rating. If you want a lower rating later, the same animations work with a mug of something in the props' place.</p>
    </section>

    <section id="cowl">
      <span class="eyebrow">Start</span>
      <h2>Cowl's look</h2>
      <div class="split">
        <div class="lookgrid">
          <h3>Kept from your mockup</h3>
          <ul class="checks">
            <li>The soft charcoal body with no mouth, nose or ears.</li>
            <li>Two glowing pale cyan slit eyes, set wide.</li>
            <li>The oversized off-white slouchy beanie, cuff pulled low.</li>
            <li>Baggy red corduroy shorts and bare feet.</li>
            <li>Big-head proportions: the head and beanie are half his height.</li>
          </ul>
          <h3>Proposed, for you to judge on H0</h3>
          <ul class="checks">
            <li><strong>A longer, softer slouch.</strong> It becomes his cape: it lags and streams behind every move and is what reads as fluid at game size.</li>
            <li><strong>Off-white hand wraps.</strong> Charcoal fists vanish against the dark walls. Wraps make every punch read and echo the beanie.</li>
            <li><strong>Drawstring ends</strong> on the shorts, for a small flutter.</li>
            <li><strong>Limbs about 10% longer</strong>, so the punches and the kick have room to read.</li>
            <li><strong>A three-quarter head in side view</strong>, so both eyes always show. They are his whole face.</li>
            <li><strong>Eight eye shapes</strong> (H2) that every card names: neutral, chill, focused, surprised, happy, hurt, watery, blink.</li>
            <li><strong>Soot as his signature effect.</strong> His dust, landings, death and respawn are all made of him.</li>
          </ul>
        </div>
        <figure class="figure"><img src="attach/previews/A-hero-mockup.jpg" alt="Cowl's mockup, front view."><figcaption>Image A, your mockup: canon for his design and colours.</figcaption></figure>
      </div>
      <ul class="swatches" aria-label="Cowl's colours">
__HERO_SWATCHES__
      </ul>
    </section>

    <section id="world">
      <span class="eyebrow">Start</span>
      <h2>The buried mansion</h2>
      <p>Your two paintings set the world: a gothic mansion swallowed by the earth, its rooms cut out of black, root-threaded soil, lit by rose candlelight in indigo haze. The space itself is still being blocked out in your other session (rooms carved from solid mass, floors joined by stairs, a tower at each end). So this book draws a kit that fits any shape, at Cowl's scale, and sorts the props by the room types in your draft.</p>
      <div class="cols">
        <div class="kv"><h3>Three rules for every world card</h3><ul class="checks">
          <li><strong>Values:</strong> the walls behind the playfield stay mid-violet so Cowl's charcoal body reads in front; only the earth and the foreground roots go near-black. Your mockups already do this.</li>
          <li><strong>Reserved colours:</strong> red, pale cyan and pure white belong to Cowl, so the world never uses them. Arcane green appears only on the sealed door.</li>
          <li><strong>Scale:</strong> every piece is drawn with Cowl at 240 px tall, so the kit fits together whatever tile size the game settles on.</li>
        </ul></div>
        <div class="kv"><h3>Room types from your draft</h3><ul class="checks">
          <li>Cowl's bedroom, the parents' and guest rooms</li>
          <li>The grand entrance hall and the western hallway</li>
          <li>The library and the father's study</li>
          <li>The kitchen, dining room and pantry</li>
          <li>The living room and the conservatory</li>
          <li>The attic; the undercroft, storage, workshop and boiler room</li>
          <li>The laboratory antechamber and the two towers</li>
        </ul></div>
      </div>
      <ul class="swatches" aria-label="The world's colours">
__WORLD_SWATCHES__
      </ul>
    </section>

    <section id="cards-table">
      <span class="eyebrow">Start</span>
      <h2>The cards</h2>
      <div class="table-wrap"><table>
        <thead><tr><th>Card</th><th>What</th><th>Sheet</th><th>Timing</th></tr></thead>
        <tbody>
__TABLE__
        </tbody>
      </table></div>
    </section>

    <section id="motion">
      <span class="eyebrow">Start</span>
      <h2>The motion standard</h2>
      <p>Every animation card copies these rules into its prompt. They are what separates a sprite that moves from one that lives.</p>
      <ol class="steps">
        <li><strong>Twelve to sixteen drawings a move, every one new.</strong> Even a held pose changes a little each frame: the breath, the slouch, the wraps.</li>
        <li><strong>In-betweens.</strong> Apart from a smear, nothing moves more than a quarter of his height between frames.</li>
        <li><strong>Ease in and out.</strong> Frames bunch up where motion starts and stops, and spread out in its fast middle.</li>
        <li><strong>Smears.</strong> The fastest frame of a punch, kick, flip or snatch is one painted smear of the limb.</li>
        <li><strong>Cartoon squash and stretch.</strong> He is rubbery: a striking limb stretches to 1.3 times its length at contact and snaps back.</li>
        <li><strong>Overlap.</strong> The slouch, wrap ends, drawstring and shorts lag one or two frames and overshoot.</li>
        <li><strong>Lines of action and acting.</strong> One clear curve through every key pose; his eyes change shape with the beat and lead each action with a glance.</li>
        <li><strong>Responsive timing.</strong> The jump launches on the press, the jab lands 4 ticks after it, the cross 5 and the kick 12, and any input ends an idle break. Feel comes first; the drawings fit inside the game's timing.</li>
      </ol>
    </section>

    <section id="game">
      <span class="eyebrow">Start</span>
      <h2>What the game adds</h2>
      <p>Keep these out of the drawings. Painted glow cannot flicker or change colour; the game's can.</p>
      <div class="cols">
        <div class="kv"><h3>Light</h3><ul class="checks">
          <li>The bloom on Cowl's eyes, the candles' warm pools of light, the ember's glow on the blunt.</li>
          <li>The sealed door's green glow and the lab's liquids.</li>
        </ul></div>
        <div class="kv"><h3>Smoke, soot and sparks</h3><ul class="checks">
          <li>Smoke from F4, emitted on the frames each card names: the exhale, the ash tap, the cough.</li>
          <li>Soot from F3 when he starts, skids and lands; hit sparks from F2 on contact; trails from F1 on the smear and contact frames.</li>
        </ul></div>
        <div class="kv"><h3>Game feel</h3><ul class="checks">
          <li>Hit-stop on contact (3 to 6 ticks), a camera kick on the cross, the kick and the hero landing.</li>
          <li>When the breaks play (after about 8 seconds still) and which (blunt or bong at random). Any input plays the snap-out's first three drawings, then hands over.</li>
        </ul></div>
        <div class="kv"><h3>Movement</h3><ul class="checks">
          <li>The game moves Cowl through the room and flips him to face left; drawings stay in place, facing right.</li>
          <li>It scales the run to his ground speed and skips the flip on a short hop.</li>
        </ul></div>
      </div>
    </section>

    <section id="contract">
      <span class="eyebrow">Start</span>
      <h2>The asset contract</h2>
      <p>The rules every sheet follows so the game can use it without hand-fixing. The game-side numbers are provisional until the space and the camera are final; the master sizes are not, since everything is drawn to Cowl's scale.</p>
      <div class="table-wrap"><table>
        <thead><tr><th>What</th><th>Rule</th></tr></thead>
        <tbody>
          <tr><td>Character cells</td><td>512 × 512 px masters, 4 columns wide; halved to 256 px in the game.</td></tr>
          <tr><td>Cowl's size</td><td>About 240 px tall to the top of the beanie in the master (about 120 px in the game, roughly 1.9 tiles).</td></tr>
          <tr><td>Anchor</td><td>Between his feet at (256, 400) in each master cell, (128, 200) in the game. His soles rest on that line; airborne frames keep his centre near (256, 300).</td></tr>
          <tr><td>Facing</td><td>Everything is drawn facing right; the game flips.</td></tr>
          <tr><td>Timing</td><td>60 ticks a second; each frame's ticks are on its card.</td></tr>
          <tr><td>Background</td><td>Transparent PNG. If SOL cannot, flat pure magenta <code>#FF00FF</code> (nothing in the game uses it).</td></tr>
          <tr><td>World scale</td><td>Drawn with Cowl at 240 px: 1 tile = 128 px on the masters, 64 px in the game (provisional).</td></tr>
          <tr><td>Tiling pieces</td><td>Surface lines exactly where the card puts them (64 px into a band or strip), seamless where it says.</td></tr>
          <tr><td>Files</td><td>Save under the card's file name. Masters go in <code>art/source/hero/</code>, <code>art/source/fx/</code> and <code>art/source/world/</code>; split sheets end in <code>_a</code> and <code>_b</code>.</td></tr>
        </tbody>
      </table></div>
      <p class="note">Two ways to animate Cowl: these frame-by-frame sheets, or the cut-out rig your other session is building, where moves are keyed on body parts. Both can work together. Frames suit the acting beats (the smoke breaks, the kick, the flip); the rig suits moves that need blending or tuning. H25 gives the rig clean side-view parts drawn by SOL.</p>
    </section>

    <section id="workflow">
      <span class="eyebrow">Start</span>
      <h2>How to use this book</h2>
      <div class="pilot">
        <strong>Start with H0, then H1, H2 and H3. Then the pilots: H4, H12, H14 and H16. For the world, W0 first.</strong>
        <p>H0 lets you choose the look; H1 to H3 lock it, and every animation attaches them. The four pilots are the idle, the run, the jump and the jab: they are on screen the most, and if they come back right, the rest follows from them. In the world, the target render decides the look before any kit piece is drawn.</p>
      </div>
      <ol class="steps">
        <li><strong>Attach the images the card lists.</strong> A to C are in <code>docs/art-production/attach/</code>; "approved" sheets are the ones you already made and passed.</li>
        <li><strong>Press Copy and paste the prompt into SOL.</strong> The copy includes the shared rules for its kind (shown below) unless you untick the box at the top.</li>
        <li><strong>Check the result</strong> in the <a href="#tester">sheet tester</a> and against <a href="#checks">the checklist</a>. If it jumps, freezes or drifts, send SOL the fix from <a href="#fixes">If SOL falls short</a>.</li>
        <li><strong>Save it under the card's file name and bring it to me.</strong> I review it, cut it, line it up and get it into the game.</li>
        <li><strong>Tick it done.</strong> Ticks are saved in this browser only.</li>
      </ol>
      <p class="note">Twelve-frame sheets are 2048 × 1536 px and sixteen-frame sheets 2048 × 2048 px. If SOL cannot make a size, each card says how to split it.</p>
    </section>

    <section id="pack">
      <span class="eyebrow">Start</span>
      <h2>Images to attach</h2>
      <p>Your three mockups, renamed by letter. Attach the full-size files from <code>docs/art-production/attach/</code>, not the previews on this page.</p>
      <div class="pack" id="pack-list"></div>
    </section>

    <section id="shared">
      <span class="eyebrow">Start</span>
      <h2>The shared rules</h2>
      <p>What Copy adds in front of each card's prompt, by kind of card. Written once, so every prompt asks for the same thing.</p>
      <div class="cards" id="shared-list"></div>
    </section>

    <section id="tester">
      <span class="eyebrow">Start</span>
      <h2>Sheet tester</h2>
      <p>Drop a sheet from SOL here, pick its card, and it plays at the exact game timing with the ground line, the centre line and the beanie-top line drawn in. Your file stays in this browser. Until you load one, it plays a demo sheet the page draws itself.</p>
      <div class="tester">
        <div class="stage">
          <div class="stage-box" id="stage-box"><canvas id="tester-canvas" width="512" height="512" aria-label="Sheet preview"></canvas></div>
          <div class="transport">
            <button class="btn" type="button" id="t-play" aria-pressed="true">Pause</button>
            <button class="btn ghost" type="button" id="t-prev" aria-label="Previous frame">◀ Frame</button>
            <button class="btn ghost" type="button" id="t-next" aria-label="Next frame">Frame ▶</button>
            <button class="btn ghost" type="button" id="t-speed">Speed 1×</button>
          </div>
          <div class="readout" id="t-readout">Frame 1 of 12</div>
        </div>
        <div class="tester-side">
          <span class="btn file-btn">Load a sheet<input type="file" id="t-file" accept="image/png,image/webp,image/jpeg" aria-label="Load a sheet"></span>
          <label for="t-card">Card<select id="t-card"></select></label>
          <div class="row2">
            <label for="t-cols">Columns<input type="number" id="t-cols" min="1" max="16" value="4"></label>
            <label for="t-rows">Rows<input type="number" id="t-rows" min="1" max="16" value="3"></label>
          </div>
          <label for="t-ticks">Ticks per frame<input type="text" id="t-ticks" value="10"></label>
          <label for="t-bg">Background<select id="t-bg">
            <option value="#373869">Mansion wall (mid violet)</option>
            <option value="#6B609E">Haze (light violet)</option>
            <option value="#07081A">Earth (near black)</option>
            <option value="checker">Checkerboard</option>
            <option value="#ECE6E2">Off-white</option>
          </select></label>
          <div class="toggles">
            <button class="btn" type="button" id="t-guides" aria-pressed="true">Guides</button>
            <button class="btn ghost" type="button" id="t-onion" aria-pressed="false">Onion skin</button>
            <button class="btn ghost" type="button" id="t-flip" aria-pressed="false">Face left</button>
            <button class="btn ghost" type="button" id="t-tile" aria-pressed="false">Tile 2 × 2</button>
          </div>
          <p class="warn" id="t-warn" role="status"></p>
        </div>
      </div>
    </section>

__GROUPS__

    <section id="checks">
      <span class="eyebrow">Finish</span>
      <h2>Check every result</h2>
      <div class="cols">
        <div class="kv"><h3>Flip through it</h3><ul class="checks">
          <li>Play it in the tester at 1× and ¼×. Nothing jumps, pops or freezes.</li>
          <li>As many drawings as the card lists, and no two the same.</li>
          <li>Loops run from the last frame back to the first without a hitch.</li>
          <li>Smears only on the fast frames, as part of the limb.</li>
        </ul></div>
        <div class="kv"><h3>Same Cowl</h3><ul class="checks">
          <li>The same size, colours and details in every cell as H1.</li>
          <li>Soles on the ground line, body on the centre line, the beanie's top near the pink line.</li>
          <li>Both eyes show; the eye shapes match the card.</li>
          <li>The slouch never freezes and always trails.</li>
        </ul></div>
        <div class="kv"><h3>Nothing the game adds</h3><ul class="checks">
          <li>No glow, flame, smoke, soot, sparks or speed lines in his frames.</li>
          <li>The blunt's ember is a flat orange dot; the bong's chamber smoke is the only smoke drawn.</li>
          <li>Effects are pale on transparency, nothing else in the cells.</li>
        </ul></div>
        <div class="kv"><h3>World pieces</h3><ul class="checks">
          <li>Tiling pieces show no seam with "Tile 2 × 2" on.</li>
          <li>Surface lines straight and where the card puts them.</li>
          <li>On the palette: no red, pale cyan or pure white; mid violets behind the playfield.</li>
          <li>Drawn to Cowl's scale (a door about 1.7 times his height).</li>
        </ul></div>
      </div>
    </section>

    <section id="fixes">
      <span class="eyebrow">Finish</span>
      <h2>If SOL falls short</h2>
      <p>Send the fix as a follow-up in the same SOL conversation, with the sheet attached.</p>
      <div class="cards" id="fix-list"></div>
    </section>

    <section id="after">
      <span class="eyebrow">Finish</span>
      <h2>What happens next</h2>
      <ol class="steps">
        <li><strong>I review each sheet</strong> against its card and log it in <code>docs/art-production/sol-review.md</code>: what passes, what to redraw, and the fix to send.</li>
        <li><strong>I prepare it for the game:</strong> cut the cells, remove any magenta, line the feet up on the anchor, halve it, and write the frame timings beside it.</li>
        <li><strong>It goes into the game</strong> once the space and the camera from your other session are in: the idle and run first, then the jump and the string, then the breaks.</li>
        <li><strong>You play it</strong> and we tune the feel: the run's lean against his speed, the flip against the jump height, the hit-stop on each punch.</li>
        <li><strong>Book 2</strong> can cover the shadow folk from your mockups (the cook, the scholar, the one by the orb) and the knife once Cowl finds it.</li>
      </ol>
    </section>
  </main>
</div>
"""

SCRIPT = r"""
(function () {
  "use strict";

  var KEY = "cowl-prompt-book";
  var state = { rules: true, done: {} };
  try {
    var saved = JSON.parse(localStorage.getItem(KEY) || "{}");
    if (typeof saved.rules === "boolean") state.rules = saved.rules;
    if (saved.done && typeof saved.done === "object") state.done = saved.done;
  } catch (e) { /* storage unavailable: defaults */ }
  function save() {
    try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) { /* not saved */ }
  }

  var CARDS = __CARDS__;
  var TEXTS = __TEXTS__;
  var PACK = __PACK__;
  var NAMES = __NAMES__;
  var FIXES = __FIXES__;
  var SHARED = __SHARED__;

  function el(tag, attrs, children) {
    var node = document.createElement(tag);
    if (attrs) for (var k in attrs) {
      if (k === "text") node.textContent = attrs[k];
      else node.setAttribute(k, attrs[k]);
    }
    (children || []).forEach(function (c) { if (c) node.appendChild(typeof c === "string" ? document.createTextNode(c) : c); });
    return node;
  }

  // ---------------------------------------------------------------- copying
  function copyText(text, button) {
    function ok() {
      var label = button.textContent;
      button.textContent = "Copied";
      button.classList.add("copied");
      setTimeout(function () { button.textContent = label; button.classList.remove("copied"); }, 1400);
    }
    function fallback() {
      var area = el("textarea", { readonly: "readonly", "aria-hidden": "true" });
      area.value = text;
      area.style.position = "fixed";
      area.style.opacity = "0";
      document.body.appendChild(area);
      area.select();
      try { if (document.execCommand("copy")) ok(); } catch (e) { /* select by hand */ }
      document.body.removeChild(area);
    }
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(text).then(ok, fallback);
      else fallback();
    } catch (e) { fallback(); }
  }
  function fullPrompt(card) { return state.rules ? TEXTS[card.shared] + "\n\n" + card.body : card.body; }

  function progress() {
    var n = CARDS.filter(function (c) { return state.done[c.id]; }).length;
    document.getElementById("progress").textContent = n + " of " + CARDS.length + " done";
  }

  // ---------------------------------------------------------------- cards
  function thumb(key) {
    var item = PACK.filter(function (p) { return p[0] === key; })[0];
    if (item) {
      return el("a", { class: "thumb", href: "#pack", title: NAMES[key] }, [
        el("img", { src: item[2], alt: "", loading: "lazy" }),
        el("span", {}, [el("b", { text: item[0] + " " }), item[3]])
      ]);
    }
    var target = /^[HWF]\d+$/.test(key) ? "#" + key : "#H0";
    return el("a", { class: "thumb approved", href: target, title: NAMES[key] || key }, [el("span", {}, [el("b", { text: key === "Your H0 pick" ? "H0" : key }), key === "Your H0 pick" ? " your pick" : " approved"])]);
  }

  function renderCard(card) {
    var check = el("input", { type: "checkbox", id: "done-" + card.id });
    check.checked = !!state.done[card.id];
    var node = el("article", { class: "card" + (check.checked ? " is-done" : ""), id: card.id }, [
      el("div", { class: "card-head" }, [
        el("span", { class: "tag" + (card.pilot ? " first" : ""), text: card.id + (card.pilot ? " · make first" : "") }),
        el("h3", { text: card.title }),
        el("label", { class: "done", for: "done-" + card.id }, [check, "Done"])
      ]),
      el("p", { class: "about", text: card.about })
    ]);
    check.addEventListener("change", function () {
      if (check.checked) state.done[card.id] = true; else delete state.done[card.id];
      node.classList.toggle("is-done", check.checked);
      save();
      progress();
    });
    var spec = [el("dt", { text: "Save as" }), el("dd", {}, [el("code", { text: card.file + ".png" })]),
                el("dt", { text: "SOL canvas" }), el("dd", { text: card.canvas }),
                el("dt", { text: "In game" }), el("dd", { text: card.game })];
    if (card.timing) spec.push(el("dt", { text: "Timing" }), el("dd", { text: card.sheet + " · " + card.timing }));
    node.appendChild(el("dl", { class: "spec" }, spec));
    if (card.attach.length) node.appendChild(el("div", { class: "thumbs", "aria-label": "Attach" }, card.attach.map(thumb)));
    var button = el("button", { class: "copy", type: "button", text: "Copy", "aria-label": "Copy the prompt for " + card.id });
    button.addEventListener("click", function () { copyText(fullPrompt(card), button); });
    node.appendChild(el("div", { class: "prompt" }, [
      el("div", { class: "prompt-bar" }, [el("strong", { text: "Prompt" }), el("span", { class: "spacer", text: "plus the shared rules when you copy" }), button]),
      el("pre", { text: card.body })
    ]));
    return node;
  }

  CARDS.forEach(function (card) {
    var box = document.getElementById("cards-" + card.group);
    if (box) box.appendChild(renderCard(card));
  });

  PACK.forEach(function (p) {
    document.getElementById("pack-list").appendChild(el("div", { class: "ref" }, [
      el("a", { href: p[1] }, [el("img", { src: p[2], alt: p[3], loading: "lazy" })]),
      el("div", {}, [el("strong", { text: p[0] + ". " + p[3] }), el("span", { text: p[4] }), el("span", {}, [el("code", { text: "docs/art-production/" + p[1] })])])
    ]));
  });

  SHARED.forEach(function (s) {
    var button = el("button", { class: "copy", type: "button", text: "Copy" });
    button.addEventListener("click", function (ev) { ev.preventDefault(); copyText(TEXTS[s[2]], button); });
    document.getElementById("shared-list").appendChild(el("details", { class: "rules" }, [
      el("summary", {}, [s[0], el("code", { text: "as on " + s[1] })]),
      el("div", { class: "prompt" }, [el("div", { class: "prompt-bar" }, [el("strong", { text: s[0] }), el("span", { class: "spacer" }), button]), el("pre", { text: TEXTS[s[2]] })])
    ]));
  });

  FIXES.forEach(function (f) {
    var button = el("button", { class: "copy", type: "button", text: "Copy" });
    button.addEventListener("click", function () { copyText(f[1], button); });
    document.getElementById("fix-list").appendChild(el("div", { class: "prompt" }, [
      el("div", { class: "prompt-bar" }, [el("strong", { class: "spacer", text: f[0] }), button]),
      el("pre", { text: f[1] })
    ]));
  });

  var rulesBox = document.getElementById("include-rules");
  rulesBox.checked = state.rules;
  rulesBox.addEventListener("change", function () { state.rules = rulesBox.checked; save(); });
  progress();

  // ---------------------------------------------------------------- tester
  var canvas = document.getElementById("tester-canvas");
  var ctx = canvas.getContext("2d");
  var T = { img: null, demo: true, cols: 4, rows: 3, ticks: [10], frame: 0, acc: 0, last: 0, playing: true,
            speed: 1, guides: true, onion: false, flip: false, tile: false, bg: "#373869" };
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduce) T.playing = false;
  var playBtn = document.getElementById("t-play");
  var readout = document.getElementById("t-readout");
  var warn = document.getElementById("t-warn");
  var cardSel = document.getElementById("t-card");
  var colsIn = document.getElementById("t-cols");
  var rowsIn = document.getElementById("t-rows");
  var ticksIn = document.getElementById("t-ticks");

  // The demo: a stand-in Cowl swaying, drawn by the page (not SOL's art).
  function demoSheet() {
    var c = document.createElement("canvas");
    c.width = 2048; c.height = 1536;
    var g = c.getContext("2d");
    for (var i = 0; i < 12; i++) {
      var ox = (i % 4) * 512, oy = Math.floor(i / 4) * 512;
      var t = i / 12 * Math.PI * 2;
      var lean = Math.sin(t) * 10, bob = Math.abs(Math.sin(t)) * 6, lag = Math.sin(t - 0.9) * 16;
      g.save();
      g.translate(ox + 256, oy + 400);
      g.lineWidth = 3; g.strokeStyle = "#111114"; g.lineJoin = "round";
      // legs
      g.fillStyle = "#2A2A2C";
      g.fillRect(-26, -46 + bob * 0.3, 16, 46 - bob * 0.3); g.strokeRect(-26, -46 + bob * 0.3, 16, 46 - bob * 0.3);
      g.fillRect(8, -46 + bob * 0.3, 16, 46 - bob * 0.3); g.strokeRect(8, -46 + bob * 0.3, 16, 46 - bob * 0.3);
      g.rotate(lean * Math.PI / 180);
      // shorts
      g.fillStyle = "#933731";
      g.beginPath(); g.moveTo(-40, -92 + bob); g.lineTo(40, -92 + bob); g.lineTo(48, -48 + bob); g.lineTo(-48, -48 + bob); g.closePath(); g.fill(); g.stroke();
      // torso
      g.fillStyle = "#2A2A2C";
      g.beginPath(); g.ellipse(0, -112 + bob, 36, 28, 0, 0, Math.PI * 2); g.fill(); g.stroke();
      // head
      g.beginPath(); g.ellipse(4, -168 + bob, 58, 50, 0, 0, Math.PI * 2); g.fill(); g.stroke();
      // slouch, lagging
      g.fillStyle = "#EBE5E1";
      g.beginPath(); g.moveTo(-40, -214 + bob); g.quadraticCurveTo(-96 + lag, -190 + bob, -80 + lag, -138 + bob); g.quadraticCurveTo(-52, -160 + bob, -30, -180 + bob); g.closePath(); g.fill(); g.stroke();
      // crown and cuff
      g.beginPath(); g.ellipse(4, -206 + bob, 66, 40, 0, Math.PI, Math.PI * 2); g.fill(); g.stroke();
      g.fillStyle = "#C4BCB6";
      g.fillRect(-62, -208 + bob, 132, 24); g.strokeRect(-62, -208 + bob, 132, 24);
      // eyes
      g.fillStyle = "#B8EAF8";
      var blink = i === 7 ? 2 : 7;
      g.fillRect(14, -172 + bob, 26, blink); g.fillRect(48, -172 + bob, 16, blink);
      g.restore();
    }
    return c;
  }

  function animCards() { return CARDS.filter(function (c) { return c.ticks; }); }
  cardSel.appendChild(el("option", { value: "", text: "Demo: a stand-in sway (12 frames)" }));
  animCards().forEach(function (c) { cardSel.appendChild(el("option", { value: c.id, text: c.id + " · " + c.title })); });
  cardSel.appendChild(el("option", { value: "custom", text: "Custom grid and ticks" }));

  function parseTicks() {
    var list = ticksIn.value.split(/[\s,]+/).map(function (v) { return parseInt(v, 10); }).filter(function (v) { return v > 0; });
    T.ticks = list.length ? list : [10];
  }
  function frameCount() { return Math.max(1, T.cols * T.rows); }
  function ticksOf(i) { return T.ticks.length === 1 ? T.ticks[0] : (T.ticks[i] || T.ticks[T.ticks.length - 1]); }

  function checkSize() {
    warn.textContent = "";
    if (!T.img || T.demo) return;
    var c = CARDS.filter(function (x) { return x.id === cardSel.value; })[0];
    if (!c) return;
    var w = c.layout.cols * c.layout.cw, h = c.layout.rows * c.layout.ch;
    var iw = T.img.naturalWidth || T.img.width, ih = T.img.naturalHeight || T.img.height;
    if (Math.abs(iw / ih - w / h) > 0.02) warn.textContent = "This image is " + iw + " × " + ih + "; " + c.id + " asks for " + w + " × " + h + ". If SOL split it, load each part with its own grid.";
  }

  function applyCard() {
    var c = CARDS.filter(function (x) { return x.id === cardSel.value; })[0];
    if (cardSel.value === "") { T.cols = 4; T.rows = 3; T.ticks = [10]; if (!T.img || T.demo) { T.img = demoSheet(); T.demo = true; } }
    else if (c) { T.cols = c.layout.cols; T.rows = c.layout.rows; T.ticks = c.ticks.slice(); }
    colsIn.value = T.cols; rowsIn.value = T.rows; ticksIn.value = T.ticks.join(", ");
    T.frame = 0; T.acc = 0;
    var ratio = c ? c.layout.cw / c.layout.ch : 1;
    canvas.width = ratio >= 1 ? 512 : Math.round(512 * ratio);
    canvas.height = ratio >= 1 ? Math.round(512 / ratio) : 512;
    canvas.style.aspectRatio = canvas.width + " / " + canvas.height;
    checkSize();
    draw();
  }

  function paintBg(w, h) {
    if (T.bg === "checker") {
      for (var y = 0; y < h; y += 16) for (var x = 0; x < w; x += 16) {
        ctx.fillStyle = ((x + y) / 16) % 2 ? "#3A3A44" : "#2A2A33"; ctx.fillRect(x, y, 16, 16);
      }
    } else { ctx.fillStyle = T.bg; ctx.fillRect(0, 0, w, h); }
  }

  function cell(i, alpha) {
    var img = T.img; if (!img) return;
    var iw = img.naturalWidth || img.width, ih = img.naturalHeight || img.height;
    var cw = iw / T.cols, ch = ih / T.rows;
    var cx = (i % T.cols) * cw, cy = Math.floor(i / T.cols) * ch;
    ctx.save();
    ctx.globalAlpha = alpha;
    if (T.flip) { ctx.translate(canvas.width, 0); ctx.scale(-1, 1); }
    ctx.drawImage(img, cx, cy, cw, ch, 0, 0, canvas.width, canvas.height);
    ctx.restore();
  }

  function draw() {
    var w = canvas.width, h = canvas.height;
    ctx.clearRect(0, 0, w, h);
    paintBg(w, h);
    if (!T.img) return;
    var n = frameCount();
    if (T.tile) {
      var img = T.img, iw = img.naturalWidth || img.width, ih = img.naturalHeight || img.height;
      var s = Math.min(w / (iw * 2), h / (ih * 2));
      var dw = iw * s, dh = ih * s, ox = (w - dw * 2) / 2, oy = (h - dh * 2) / 2;
      for (var r = 0; r < 2; r++) for (var c = 0; c < 2; c++) ctx.drawImage(img, ox + c * dw, oy + r * dh, dw, dh);
      readout.textContent = "Tile check: the whole image repeated 2 × 2";
      return;
    }
    if (T.onion && n > 1) {
      cell((T.frame - 1 + n) % n, 0.28);
      cell((T.frame + 1) % n, 0.12);
    }
    cell(T.frame, 1);
    if (T.guides) {
      ctx.save();
      ctx.lineWidth = 1;
      ctx.setLineDash([6, 5]);
      ctx.strokeStyle = "rgba(184,234,248,0.85)";
      var gy = Math.round(h * 400 / 512) + 0.5, gx = Math.round(w / 2) + 0.5;
      ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(w, gy); ctx.stroke();
      ctx.strokeStyle = "rgba(184,234,248,0.4)";
      ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, h); ctx.stroke();
      ctx.strokeStyle = "rgba(230,168,178,0.75)";
      var hy = Math.round(h * 160 / 512) + 0.5;
      ctx.beginPath(); ctx.moveTo(w * 0.3, hy); ctx.lineTo(w * 0.7, hy); ctx.stroke();
      ctx.restore();
    }
    var total = 0, at = 0;
    for (var i = 0; i < n; i++) { if (i === T.frame) at = total; total += ticksOf(i); }
    readout.textContent = "Frame " + (T.frame + 1) + " of " + n + " · " + ticksOf(T.frame) + " ticks · tick " + (at + 1) + " of " + total + " (" + (total / 60).toFixed(2) + " s)";
  }

  function loop(now) {
    if (!T.last) T.last = now;
    var dt = Math.min(100, now - T.last);
    T.last = now;
    if (T.playing && T.img && !T.tile) {
      T.acc += dt * T.speed;
      var step = ticksOf(T.frame) * 1000 / 60, moved = false;
      while (T.acc >= step) { T.acc -= step; T.frame = (T.frame + 1) % frameCount(); step = ticksOf(T.frame) * 1000 / 60; moved = true; }
      if (moved) draw();
    }
    requestAnimationFrame(loop);
  }

  function toggle(id, key, onLabel, offLabel) {
    var b = document.getElementById(id);
    b.addEventListener("click", function () {
      T[key] = !T[key];
      b.setAttribute("aria-pressed", String(T[key]));
      b.classList.toggle("ghost", !T[key]);
      if (onLabel) b.textContent = T[key] ? onLabel : offLabel;
      draw();
    });
  }
  toggle("t-guides", "guides");
  toggle("t-onion", "onion");
  toggle("t-flip", "flip");
  toggle("t-tile", "tile");
  playBtn.addEventListener("click", function () {
    T.playing = !T.playing;
    playBtn.textContent = T.playing ? "Pause" : "Play";
    playBtn.setAttribute("aria-pressed", String(T.playing));
  });
  if (!T.playing) { playBtn.textContent = "Play"; playBtn.setAttribute("aria-pressed", "false"); }
  document.getElementById("t-prev").addEventListener("click", function () { T.frame = (T.frame - 1 + frameCount()) % frameCount(); T.acc = 0; draw(); });
  document.getElementById("t-next").addEventListener("click", function () { T.frame = (T.frame + 1) % frameCount(); T.acc = 0; draw(); });
  var speeds = [1, 0.5, 0.25], si = 0, speedBtn = document.getElementById("t-speed");
  speedBtn.addEventListener("click", function () { si = (si + 1) % speeds.length; T.speed = speeds[si]; speedBtn.textContent = "Speed " + (T.speed === 1 ? "1" : T.speed === 0.5 ? "½" : "¼") + "×"; });
  document.getElementById("t-bg").addEventListener("change", function (e) { T.bg = e.target.value; draw(); });
  cardSel.addEventListener("change", applyCard);
  colsIn.addEventListener("change", function () { T.cols = Math.max(1, parseInt(colsIn.value, 10) || 1); cardSel.value = "custom"; T.frame = 0; draw(); });
  rowsIn.addEventListener("change", function () { T.rows = Math.max(1, parseInt(rowsIn.value, 10) || 1); cardSel.value = "custom"; T.frame = 0; draw(); });
  ticksIn.addEventListener("change", function () { parseTicks(); draw(); });

  function loadFile(file) {
    if (!file || !/^image\//.test(file.type)) { warn.textContent = "That file is not an image. Load the PNG SOL gave you."; return; }
    var reader = new FileReader();
    reader.onload = function () {
      var img = new Image();
      img.onload = function () {
        T.img = img; T.demo = false; T.frame = 0; T.acc = 0;
        if (cardSel.value === "") { cardSel.value = "custom"; }
        checkSize();
        draw();
      };
      img.onerror = function () { warn.textContent = "That image could not be read. Try saving it as PNG."; };
      img.src = reader.result;
    };
    reader.readAsDataURL(file);
  }
  document.getElementById("t-file").addEventListener("change", function (e) { loadFile(e.target.files[0]); });
  var box = document.getElementById("stage-box");
  box.addEventListener("dragover", function (e) { e.preventDefault(); box.classList.add("drag"); });
  box.addEventListener("dragleave", function () { box.classList.remove("drag"); });
  box.addEventListener("drop", function (e) { e.preventDefault(); box.classList.remove("drag"); loadFile(e.dataTransfer.files[0]); });

  applyCard();
  requestAnimationFrame(loop);
})();
"""


def page():
    n = len(data.CARDS)
    nh = sum(1 for c in data.CARDS if c["id"].startswith("H"))
    nf = sum(1 for c in data.CARDS if c["id"].startswith("F"))
    nw = sum(1 for c in data.CARDS if c["id"].startswith("W"))
    head = """<title>Cowl's Prompt Book</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Figtree:wght@400;500;600;700&family=Grenze+Gotisch:wght@500;700&family=JetBrains+Mono:wght@400;500&display=swap">
"""
    body = (BODY.replace("__NAV__", nav_html())
                .replace("__TABLE__", table_html())
                .replace("__GROUPS__", groups_html())
                .replace("__HERO_SWATCHES__", swatches(HERO_SWATCHES))
                .replace("__WORLD_SWATCHES__", swatches(WORLD_SWATCHES))
                .replace("__NH__", str(nh)).replace("__NF__", str(nf)).replace("__NW__", str(nw))
                .replace("__N__", str(n)).replace("__DATE__", DATE))
    texts = []
    cards = cards_json(texts)
    js = (SCRIPT.replace("__CARDS__", js_value(cards))
                .replace("__TEXTS__", js_value(texts))
                .replace("__PACK__", js_value(data.PACK))
                .replace("__NAMES__", js_value(data.NAMES))
                .replace("__FIXES__", js_value(data.FIXES))
                .replace("__SHARED__", js_value(shared_examples(texts))))
    return head + CSS + "\n" + body + "\n<script>" + js + "</script>\n"


def main(argv):
    problems = check_cards()
    if problems:
        for p in problems:
            print("error:", p)
        return 1
    if "--check" in argv:
        print("%d cards OK" % len(data.CARDS))
        return 0
    html = page()
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(html)
    print("wrote %s (%d cards, %d KB)" % (os.path.relpath(OUT, ROOT), len(data.CARDS), len(html.encode("utf-8")) // 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
