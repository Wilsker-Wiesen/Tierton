#!/usr/bin/env python3
"""Finds cut-outs with hard straight edges (animal cut off by the original photo frame):
longest run of opaque pixels along the left/right/top border, relative to that border's length."""
import glob, json, os, subprocess, sys, tempfile
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEDIA = os.path.join(ROOT, "Tierton", "Resources", "Media")

def longest_run(vals):
    best = cur = 0
    for v in vals:
        cur = cur + 1 if v else 0
        best = max(best, cur)
    return best

def check(path):
    """Fraction of rows/columns whose outline ends on the same straight line at the left/right/top
    (a cut by the photo frame) – natural outlines are curved and score low."""
    tmp = tempfile.mktemp(suffix=".png")
    subprocess.run(["sips", "-s", "format", "png", path, "--out", tmp], capture_output=True)
    im = Image.open(tmp).convert("RGBA"); os.remove(tmp)
    a = im.split()[3]; w, h = im.size; px = a.load()
    def first(seq):
        for i, v in enumerate(seq):
            if v > 128: return i
        return None
    lefts = [first(px[x, y] for x in range(w)) for y in range(h)]
    rights = [first(px[x, y] for x in range(w - 1, -1, -1)) for y in range(h)]
    tops = [first(px[x, y] for y in range(h)) for x in range(w)]
    def straight(edges, n):
        vals = [e for e in edges if e is not None]
        if not vals: return 0
        m = min(vals)
        return longest_run([e is not None and e <= m + 2 for e in edges]) / n
    return {"L": straight(lefts, h), "R": straight(rights, h), "T": straight(tops, w)}

if __name__ == "__main__":
    cat = json.load(open(os.path.join(ROOT, "Content", "catalog.json")))["animals"]
    ids = sys.argv[1:] or [a["id"] for a in cat if not a.get("hidden") and os.path.exists(os.path.join(MEDIA, a["id"] + ".m4a"))]
    for aid in ids:
        r = check(os.path.join(MEDIA, aid + ".heic"))
        bad = {k: round(v, 2) for k, v in r.items() if v > 0.18}
        if bad: print(f"{aid:16} {bad}")
