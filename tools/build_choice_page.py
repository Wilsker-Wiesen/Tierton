#!/usr/bin/env python3
"""Builds tools/photo-choice/choices.json + img/*.png: the current photo (A) and the alternative (B)
of every animal that has one in tools/.cache/alt. After the choice, run apply_choices()."""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGE = os.path.join(ROOT, "tools", "photo-choice")
ALT = os.path.join(ROOT, "tools", ".cache", "alt")
MEDIA = os.path.join(ROOT, "Tierton", "Resources", "Media")


def credit(c):
    a = (c or {}).get("artist") or "unbekannt"
    return f"{a[:60]} · {(c or {}).get('license') or ''}"


def png(src, dst):
    subprocess.run(["sips", "-s", "format", "png", "-Z", "380", src, "--out", dst], capture_output=True, check=True)
    out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", dst], capture_output=True, text=True).stdout
    w = int(out.split("pixelWidth:")[1].split()[0]); h = int(out.split("pixelHeight:")[1].split()[0])
    return w, h


def build():
    cat = json.load(open(os.path.join(ROOT, "Content", "catalog.json")))
    media = json.load(open(os.path.join(ROOT, "Content", "media.json")))
    alt = json.load(open(os.path.join(ALT, "credits.json")))
    cats = {c["id"]: c for c in cat["categories"]}
    os.makedirs(os.path.join(PAGE, "img"), exist_ok=True)
    items = []
    for a in cat["animals"]:
        aid = a["id"]
        if aid not in alt or not os.path.exists(os.path.join(ALT, aid + ".heic")):
            continue
        wa, ha = png(os.path.join(MEDIA, aid + ".heic"), os.path.join(PAGE, "img", f"{aid}_a.png"))
        wb, hb = png(os.path.join(ALT, aid + ".heic"), os.path.join(PAGE, "img", f"{aid}_b.png"))
        c = cats[a["category"]]
        items.append({
            "id": aid, "name": a["name"], "category": c["name"], "color": c["color"],
            "a": {"src": f"img/{aid}_a.png", "w": wa, "h": ha, "credit": credit(media.get(aid, {}).get("image"))},
            "b": {"src": f"img/{aid}_b.png", "w": wb, "h": hb, "credit": credit(alt[aid])},
        })
    json.dump(items, open(os.path.join(PAGE, "choices.json"), "w"), ensure_ascii=False)
    print(len(items), "pairs")


def apply_choices(picks_path):
    """picks_path: JSON {id: "A"|"B"|"none"} (read back from the page). B -> replace photo + credit.
    Returns the ids marked "none" (need yet another photo)."""
    import shutil
    picks = json.load(open(picks_path))
    mp = os.path.join(ROOT, "Content", "media.json")
    media = json.load(open(mp))
    alt = json.load(open(os.path.join(ALT, "credits.json")))
    none = []
    for aid, k in picks.items():
        if k == "B" and aid in alt:
            shutil.copy(os.path.join(ALT, aid + ".heic"), os.path.join(MEDIA, aid + ".heic"))
            media.setdefault(aid, {})["image"] = alt[aid]
        elif k == "none":
            none.append(aid)
    json.dump(media, open(mp, "w"), ensure_ascii=False, indent=2)
    print("applied; none:", none)
    return none


if __name__ == "__main__":
    if sys.argv[1:2] == ["apply"]:
        apply_choices(sys.argv[2])
    else:
        build()
