#!/usr/bin/env python3
"""Builds tools/photo-choice-2 (current photo + reviewed candidates per animal) and applies the picks.
Usage: build_multi_choice.py build | apply <picks.json>"""
import json, os, shutil, subprocess, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGE = os.path.join(ROOT, "tools", "photo-choice-2")
MULTI = os.path.join(ROOT, "tools", ".cache", "multi")
MEDIA = os.path.join(ROOT, "Tierton", "Resources", "Media")
KEEP = {  # candidates that passed the manual review
    "walross": [0], "schwein": [3, 2], "biber": [4, 0, 3], "hund": [3, 2, 5, 1],
    "wildhund": [3, 4, 1], "taube": [1, 2, 5, 3], "pottwal": [0, 1],
}

def png(src, dst):
    subprocess.run(["sips", "-s", "format", "png", "-Z", "380", src, "--out", dst], capture_output=True, check=True)
    o = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", dst], capture_output=True, text=True).stdout
    return int(o.split("pixelWidth:")[1].split()[0]), int(o.split("pixelHeight:")[1].split()[0])

def credit(c):
    return f"{(c or {}).get('artist') or 'unbekannt'}"[:60] + f" · {(c or {}).get('license') or ''}"

def build():
    cat = json.load(open(os.path.join(ROOT, "Content", "catalog.json")))
    cats = {c["id"]: c for c in cat["categories"]}
    names = {a["id"]: a for a in cat["animals"]}
    media = json.load(open(os.path.join(ROOT, "Content", "media.json")))
    mc = json.load(open(os.path.join(MULTI, "credits.json")))
    items = []
    for aid, keep in KEEP.items():
        a = names[aid]; c = cats[a["category"]]
        w, h = png(os.path.join(MEDIA, aid + ".heic"), os.path.join(PAGE, "img", f"{aid}_cur.png"))
        opts = [{"key": "cur", "src": f"img/{aid}_cur.png", "w": w, "h": h, "credit": credit(media[aid].get("image")), "now": True}]
        for n in keep:
            w, h = png(os.path.join(MULTI, f"{aid}_{n}.heic"), os.path.join(PAGE, "img", f"{aid}_{n}.png"))
            opts.append({"key": str(n), "src": f"img/{aid}_{n}.png", "w": w, "h": h, "credit": credit(mc[f"{aid}_{n}"])})
        items.append({"id": aid, "name": a["name"], "category": c["name"], "color": c["color"], "options": opts})
    json.dump(items, open(os.path.join(PAGE, "choices.json"), "w"), ensure_ascii=False)
    print(len(items), "animals", sum(len(i["options"]) for i in items), "options")

def apply(path):
    picks = json.load(open(path))
    mp = os.path.join(ROOT, "Content", "media.json")
    media = json.load(open(mp)); mc = json.load(open(os.path.join(MULTI, "credits.json")))
    for aid, k in picks.items():
        if k in ("cur", "none"): continue
        shutil.copy(os.path.join(MULTI, f"{aid}_{k}.heic"), os.path.join(MEDIA, aid + ".heic"))
        media[aid]["image"] = mc[f"{aid}_{k}"]
        print(aid, "->", mc[f"{aid}_{k}"]["title"][5:70])
    json.dump(media, open(mp, "w"), ensure_ascii=False, indent=2)

if __name__ == "__main__":
    build() if sys.argv[1] == "build" else apply(sys.argv[2])
