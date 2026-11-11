"""Find the separate pieces on a kit sheet.

A piece is a connected blob of the sheet's alpha after a small dilation (so a
candle and its flame, or a chain's links, stay one piece). Pieces are returned
in reading order: rows by vertical overlap, then left to right.
"""
import numpy as np
from PIL import Image
from scipy import ndimage


def pieces(img, alpha_min=40, join=10, min_frac=0.0015):
    a = np.asarray(img.convert("RGBA"))[..., 3]
    mask = a > alpha_min
    if join:
        mask = ndimage.binary_dilation(mask, iterations=join)
    lab, n = ndimage.label(mask)
    boxes = []
    total = a.size
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if sl is None:
            continue
        ys, xs = sl
        region = (lab[sl] == i + 1) & (a[sl] > alpha_min)
        if region.sum() < total * min_frac:
            continue
        # tight box on the undilated pixels
        yy, xx = np.where(region)
        boxes.append((xs.start + xx.min(), ys.start + yy.min(), xs.start + xx.max() + 1, ys.start + yy.max() + 1))
    return reading_order(boxes)


def reading_order(boxes):
    rows = []
    for b in sorted(boxes, key=lambda b: (b[1] + b[3]) / 2):
        cy = (b[1] + b[3]) / 2
        for r in rows:
            if r["y0"] <= cy <= r["y1"]:
                r["items"].append(b)
                r["y0"] = min(r["y0"], b[1])
                r["y1"] = max(r["y1"], b[3])
                break
        else:
            rows.append({"y0": b[1], "y1": b[3], "items": [b]})
    rows.sort(key=lambda r: r["y0"])
    out = []
    for r in rows:
        out += sorted(r["items"], key=lambda b: b[0])
    return out
