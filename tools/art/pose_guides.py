#!/usr/bin/env python3
"""Pose guides for Book 1's key animation cards.

    python3 tools/art/pose_guides.py

Image models draw animation sheets with repeated poses, drifting placement
and swapped left and right limbs. A pose guide fixes the poses before the
painting: one plain mannequin per cell, on the exact grid of the sheet,
with Cowl's proportions (2 tiles tall, the head and beanie half his height),
the near limbs darkest and the far limbs lighter so they never swap.

Poses are written as targets: the pelvis, the torso's lean, the head's tilt,
and where each hand and foot goes; two-bone IK places the elbows and knees.
Everything is drawn facing right (the cell's anchor between the feet is
(256, 400)); `mirror` turns a frame to face left, `rot` spins the whole body
about (256, 300) for the flip.

Writes docs/art-production/attach/guides/G-<card>.png and a preview of each.
"""

import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "docs", "art-production", "attach", "guides")
PREVIEW = os.path.join(ROOT, "docs", "art-production", "attach", "previews", "guides")

SS = 2                      # supersampling
CELL = 512
GROUND = 400
# Measured from the mockup (image A) and scaled to Cowl's 256 px: the head
# and beanie about 48% of his height, the legs about a third, the arms only
# about 14% (shoulder to fist).
TORSO = 50                  # pelvis to neck
UPPER_ARM, FOREARM = 19, 17
THIGH, SHIN = 42, 40
HEAD_RX, HEAD_RY = 60, 54
RAISE = 20                  # the poses below were written for shorter legs; lift the body to stand on these

BG = (242, 242, 246)
GUIDE_LINE = (150, 175, 210)
BODY = (58, 58, 70)
NEAR = (26, 26, 34)
FAR = (150, 150, 166)
BEANIE = (200, 190, 182)
EYE = (60, 200, 225)


def rot2(v, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def ik(root, target, l1, l2, bend):
    """Two-bone IK. bend = +1 puts the joint on the side of a positive
    rotation (knees forward when facing right), -1 the other side."""
    dx, dy = target[0] - root[0], target[1] - root[1]
    d = math.hypot(dx, dy)
    d = max(min(d, l1 + l2 - 0.01), abs(l1 - l2) + 0.01)
    base = math.atan2(dy, dx)
    cos_a = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    a = math.acos(max(-1.0, min(1.0, cos_a)))
    ang = base - bend * a
    joint = (root[0] + l1 * math.cos(ang), root[1] + l1 * math.sin(ang))
    end_ang = math.atan2(target[1] - joint[1], target[0] - joint[0])
    end = (joint[0] + l2 * math.cos(end_ang), joint[1] + l2 * math.sin(end_ang))
    return joint, end


def pose(pelvis, torso, nh, fh, nf, ff, head=0.0, mirror=False, rot=0.0, eyes="right", tuck=False):
    up = lambda q: (q[0], q[1] - RAISE)
    foot = lambda q: q if q[1] >= 392 else up(q)     # planted feet stay on the ground line
    return {"pelvis": up(pelvis), "torso": torso, "head": head, "nh": up(nh), "fh": up(fh),
            "nf": foot(nf), "ff": foot(ff), "mirror": mirror, "rot": rot, "eyes": eyes}


def draw_cell(d, ox, oy, p):
    """Draws one mannequin into the cell whose top-left is (ox, oy)."""
    def T(pt):
        x, y = pt
        if p["rot"]:
            v = rot2((x - 256, y - 300), p["rot"])
            x, y = 256 + v[0], 300 + v[1]
        if p["mirror"]:
            x = CELL - x
        return ((ox + x) * SS, (oy + y) * SS)

    pel = p["pelvis"]
    up = rot2((0, -TORSO), p["torso"])
    neck = add(pel, up)
    shoulder = add(pel, rot2((0, -TORSO + 10), p["torso"]))
    hip = add(pel, rot2((0, -4), p["torso"]))
    head_c = add(neck, rot2((0, -HEAD_RY + 4), p["torso"] + p["head"]))
    head_ang = p["torso"] + p["head"]

    def limb(a, b, c, col, w):
        pts = [T(a), T(b), T(c)]
        d.line(pts, fill=col, width=int(w * SS), joint="curve")
        for q in pts:
            r = w * SS / 2
            d.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=col)

    def arm(target, col):
        j, e = ik(shoulder, target, UPPER_ARM, FOREARM, -1)
        limb(shoulder, j, e, col, 15)
        r = 11 * SS
        q = T(e)
        d.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=col)

    def leg(target, col):
        j, e = ik(hip, target, THIGH, SHIN, +1)
        limb(hip, j, e, col, 17)
        # the foot points forward from the ankle
        toe = add(e, (14, 2))
        d.line([T(e), T(toe)], fill=col, width=int(12 * SS))
        r = 6 * SS
        q = T(toe)
        d.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=col)

    def ellipse_pts(c, rx, ry, ang, a0=0, a1=360, n=40):
        pts = []
        for k in range(n + 1):
            t = math.radians(a0 + (a1 - a0) * k / n)
            v = rot2((rx * math.cos(t), ry * math.sin(t)), ang)
            pts.append(T(add(c, v)))
        return pts

    # far limbs, body, near limbs, head (the near arm last, in front)
    arm(p["fh"], FAR)
    leg(p["ff"], FAR)
    torso_pts = []
    for k in range(13):
        t = math.radians(180 + 15 * k)
        torso_pts.append(add(neck, rot2((22 * math.cos(t), 10 * math.sin(t)), p["torso"])))
    for k in range(13):
        t = math.radians(15 * k)
        torso_pts.append(add(pel, rot2((24 * math.cos(t), 12 * math.sin(t)), p["torso"])))
    d.polygon([T(q) for q in torso_pts], fill=BODY)
    leg(p["nf"], NEAR)
    # head
    d.polygon(ellipse_pts(head_c, HEAD_RX, HEAD_RY, head_ang), fill=BODY)
    # beanie: a cap over the top of the head with the slouch falling back
    cap_c = add(head_c, rot2((0, -14), head_ang))
    d.polygon(ellipse_pts(cap_c, HEAD_RX + 6, HEAD_RY - 4, head_ang, 180, 360), fill=BEANIE)
    slouch_c = add(head_c, rot2((-HEAD_RX + 6, -10), head_ang))
    d.polygon(ellipse_pts(slouch_c, 26, 40, head_ang + 20), fill=BEANIE)
    d.polygon(ellipse_pts(add(head_c, rot2((0, -12), head_ang)), HEAD_RX + 8, 10, head_ang), fill=(176, 166, 158))
    # eyes show which way the head faces
    if p["eyes"] != "none":
        sides = {"right": [(16, 6, 22), (40, 4, 14)], "left": [(-16, 6, 22), (-40, 4, 14)],
                 "front": [(-22, 6, 20), (22, 6, 20)]}[p["eyes"]]
        for x, y, w in sides:
            a = T(add(head_c, rot2((x - w / 2, y), head_ang)))
            b = T(add(head_c, rot2((x + w / 2, y), head_ang)))
            d.line([a, b], fill=EYE, width=int(6 * SS))
    arm(p["nh"], NEAR)


def sheet(poses, cols, rows, name):
    W, H = cols * CELL, rows * CELL
    img = Image.new("RGB", (W * SS, H * SS), BG)
    d = ImageDraw.Draw(img)
    for i, p in enumerate(poses):
        ox, oy = (i % cols) * CELL, (i // cols) * CELL
        d.line([(ox * SS, (oy + GROUND) * SS), ((ox + CELL) * SS, (oy + GROUND) * SS)], fill=GUIDE_LINE, width=2 * SS)
        d.line([((ox + 256) * SS, (oy + 40) * SS), ((ox + 256) * SS, (oy + 470) * SS)], fill=(214, 220, 232), width=SS)
        d.rectangle([ox * SS, oy * SS, (ox + CELL) * SS - 1, (oy + CELL) * SS - 1], outline=(222, 222, 230), width=SS)
        draw_cell(d, ox, oy, p)
    img = img.resize((W, H), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(PREVIEW, exist_ok=True)
    img.save(os.path.join(OUT, name + ".png"), optimize=True)
    pv = img.copy()
    pv.thumbnail((960, 960), Image.LANCZOS)
    pv.save(os.path.join(PREVIEW, name + ".jpg"), quality=85, optimize=True)
    return img


def shoulder_of(pelvis, torso):
    return add(pelvis, rot2((0, -TORSO + 10), torso))


def grounded(pelvis_x, lift, torso, nh, fh, nf, ff, **kw):
    """A pelvis height that puts the lower foot on the ground line."""
    return pose((pelvis_x, 342 - lift), torso, nh, fh, nf, ff, **kw)


# ---------------------------------------------------------------------------
# H12, the ninja run: torso 45 degrees forward, both arms swept straight back.
# ---------------------------------------------------------------------------
def run():
    # near foot positions over the 12 frames (x, y), relative to the cell
    near = [(300, 400), (284, 400), (258, 400), (226, 396), (204, 380), (198, 360),
            (214, 346), (246, 344), (276, 350), (300, 362), (310, 378), (308, 392)]
    pelvis_y = [340, 348, 344, 336, 332, 338]          # contact, down, passing, up, float, reach
    poses = []
    for i in range(12):
        nf = near[i]
        ff = near[(i + 6) % 12]
        py = pelvis_y[i % 6]
        sway = 5 * math.sin(2 * math.pi * i / 12)
        sh = shoulder_of((236, py - RAISE), 45)
        sh = (sh[0], sh[1] + RAISE)
        # both arms swept straight back from the shoulders, nearly level
        nh = (sh[0] - 50, sh[1] + 4 + sway)
        fh = (sh[0] - 48, sh[1] + 8 - sway)
        poses.append(pose((236, py), 45, nh, fh, nf, ff, head=-25))
    return sheet(poses, 4, 3, "G-H12-run")


# ---------------------------------------------------------------------------
# H16, H17, H18: the jab, the cross and the spinning back kick.
# ---------------------------------------------------------------------------
STANCE_NF = (284, 400)       # near (lead) foot forward
STANCE_FF = (228, 400)       # far (rear) foot back
GUARD_NH = (300, 290)        # near (lead) fist in front of the chest, under the chin
GUARD_FH = (286, 296)        # far (rear) fist tucked at the chest


def stance(px=252, py=343, torso=12, fh=GUARD_FH, nh=GUARD_NH, nf=STANCE_NF, ff=STANCE_FF, **kw):
    return pose((px, py), torso, nh, fh, nf, ff, **kw)


def jab():
    """8 drawings: load, fire, smear, contact (held), snap back, guard, settle,
    stance. The near (lead) fist punches at chest height, under the chin."""
    f = [
        stance(255, 343, 15, nh=(302, 292)),
        stance(262, 343, 22, nh=(322, 300), ff=(232, 397), nf=(292, 400)),
        stance(268, 343, 26, nh=(338, 306), ff=(236, 396), nf=(300, 400)),
        stance(272, 343, 28, nh=(348, 310), fh=(298, 296), ff=(240, 395), nf=(304, 400)),
        stance(266, 344, 20, nh=(308, 292), nf=(304, 400), ff=(240, 400)),
        stance(262, 345, 15, nf=(300, 400), ff=(238, 400)),
        stance(260, 344, 12, nf=(296, 400), ff=(236, 400)),
        stance(258, 345, 12, nf=(292, 400), ff=(232, 400)),
    ]
    return sheet(f, 4, 2, "G-H16-jab")


def cross():
    """8 drawings from the jab's settle: pivot, load, smear, contact (held),
    follow-through, return, settle, stance. The far (rear) fist crosses in
    front of the body at chest height as the torso turns."""
    nf = (292, 400)
    f = [
        stance(257, 343, 15, nf=(288, 400), ff=(230, 398)),
        stance(260, 343, 21, fh=(278, 300), nh=(296, 292), nf=nf, ff=(232, 395)),
        stance(270, 343, 30, fh=(330, 304), nh=(302, 290), nf=(298, 400), ff=(240, 393)),
        stance(276, 343, 35, fh=(352, 308), nh=(306, 290), nf=(304, 400), ff=(246, 392)),
        stance(278, 344, 37, fh=(346, 312), nh=(306, 292), nf=(304, 400), ff=(248, 394)),
        stance(272, 344, 26, fh=(312, 300), nh=(306, 290), nf=(304, 400), ff=(246, 398)),
        stance(270, 344, 20, nf=(304, 400), ff=(246, 400)),
        stance(266, 344, 16, nf=(300, 400), ff=(242, 400)),
    ]
    return sheet(f, 4, 2, "G-H17-cross")


def kick():
    """12 drawings from the cross's settle. Drawings 4 to 8 face left (mirror):
    written in the body's own frame, the kicking (near) leg drives straight
    back, which is to the right on screen."""
    chest = lambda px, py, t: add((px, py), rot2((6, -TORSO + 18), t))
    f = [
        stance(262, 344, 18, nf=(292, 400), ff=(236, 400)),
        pose((262, 343), 10, (282, 270), (290, 262), (240, 396), (286, 400), eyes="none"),
        pose((258, 342), 6, (272, 276), (280, 268), (248, 392), (280, 400), eyes="right"),
        pose((254, 338), 22, chest(254, 338, 22), chest(252, 338, 22), (282, 334), (256, 400), mirror=True, eyes="right"),
        pose((260, 334), 52, chest(260, 334, 52), chest(258, 334, 52), (204, 330), (260, 400), mirror=True, eyes="right"),
        pose((262, 332), 62, chest(262, 332, 62), chest(260, 332, 62), (192, 328), (262, 400), mirror=True, eyes="right"),
        pose((262, 332), 60, chest(262, 332, 60), chest(260, 332, 60), (194, 330), (262, 400), mirror=True, eyes="right"),
        pose((258, 336), 34, chest(258, 336, 34), chest(256, 336, 34), (270, 340), (258, 400), mirror=True, eyes="right"),
        pose((256, 340), 14, (276, 268), (238, 268), (270, 372), (256, 400), eyes="front"),
        pose((256, 345), 13, (300, 292), (286, 296), (282, 400), (232, 400)),
        stance(256, 345, 15, nf=(286, 400), ff=(230, 400)),
        stance(254, 343, 12),
    ]
    return sheet(f, 4, 3, "G-H18-kick")


def air_kick():
    """8 drawings in the air: chamber, smear, contact, two holds, retract, open, fall."""
    c = (256, 316)
    f = [
        pose(c, 14, (282, 280), (276, 284), (276, 346), (256, 352)),
        pose(c, -6, (270, 282), (262, 286), (318, 346), (250, 356)),
        pose(c, -14, (266, 286), (258, 290), (322, 350), (252, 352)),
        pose(c, -14, (266, 288), (258, 292), (322, 352), (252, 354)),
        pose((256, 320), -12, (266, 290), (258, 294), (320, 356), (252, 358)),
        pose((256, 320), 6, (280, 288), (270, 292), (282, 352), (254, 360)),
        pose((256, 318), 2, (296, 290), (220, 290), (268, 364), (250, 368)),
        pose((256, 318), 0, (294, 284), (220, 284), (262, 380), (250, 384)),
    ]
    return sheet(f, 4, 2, "G-H20-air-kick")


# ---------------------------------------------------------------------------
# H14, the jump: take-off, a tucked forward flip, the apex, the start of the fall.
# ---------------------------------------------------------------------------
def jump():
    tuck = dict(torso=40, nh=(282, 326), fh=(278, 330), nf=(276, 340), ff=(270, 344))
    f = [
        pose((254, 358), 16, (282, 314), (276, 318), (268, 400), (244, 400)),
        pose((256, 330), 4, (266, 228), (258, 232), (276, 360), (250, 398)),
        pose((256, 316), 2, (268, 236), (254, 240), (270, 350), (250, 382)),
        pose((256, 312), 10, (280, 286), (270, 290), (276, 344), (256, 356)),
    ]
    for k, r in enumerate([45, 90, 135, 180, 225, 270, 315]):
        f.append(pose((256, 314), tuck["torso"], tuck["nh"], tuck["fh"], tuck["nf"], tuck["ff"], rot=r))
    f += [
        pose((256, 312), 8, (300, 300), (214, 300), (268, 366), (248, 362)),
        pose((256, 310), 4, (304, 304), (210, 304), (272, 352), (246, 360)),
        pose((256, 312), 2, (300, 292), (214, 292), (266, 362), (248, 368)),
        pose((256, 314), 0, (296, 286), (218, 286), (264, 374), (250, 378)),
        pose((256, 316), 0, (294, 282), (220, 282), (262, 382), (250, 386)),
    ]
    return sheet(f, 4, 4, "G-H14-jump")


def main():
    for fn in (run, jump, jab, cross, kick, air_kick):
        img = fn()
        print("wrote", fn.__name__, img.size)


if __name__ == "__main__":
    main()
