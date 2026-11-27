#!/usr/bin/env python3
"""Builds the browser version of Tierton into build/web (deployed to GitHub Pages, branch gh-pages).

It reuses the iOS app's content: Content/catalog.json, facts.json, media.json and the files in
Tierton/Resources/Media (sounds as .m4a, cut-out animals converted from HEIC to WebP with alpha).
Usage: python3 tools/build_web.py
"""
import json, os, shutil, subprocess, tempfile
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "web")
OUT = os.path.join(ROOT, "build", "web")
MEDIA = os.path.join(ROOT, "Tierton", "Resources", "Media")


def main():
    cat = json.load(open(os.path.join(ROOT, "Content", "catalog.json")))
    facts = json.load(open(os.path.join(ROOT, "Content", "facts.json")))
    media = json.load(open(os.path.join(ROOT, "Content", "media.json")))
    if os.path.exists(OUT):
        shutil.rmtree(OUT)
    shutil.copytree(SRC, OUT)
    os.makedirs(os.path.join(OUT, "media"), exist_ok=True)

    animals = []
    tmp = tempfile.mkdtemp()
    for a in cat["animals"]:
        aid = a["id"]
        snd = os.path.join(MEDIA, aid + ".m4a")
        img = os.path.join(MEDIA, aid + ".heic")
        if a.get("hidden") or not os.path.exists(snd) or not os.path.exists(img):
            continue
        shutil.copy(snd, os.path.join(OUT, "media", aid + ".m4a"))
        png = os.path.join(tmp, aid + ".png")
        subprocess.run(["sips", "-s", "format", "png", "-Z", "480", img, "--out", png], capture_output=True, check=True)
        im = Image.open(png)
        im.save(os.path.join(OUT, "media", aid + ".webp"), "WEBP", quality=78, method=6)
        m = media.get(aid, {})
        animals.append({
            "id": aid, "name": a["name"], "category": a["category"], "sci": a["sci"],
            "bird": bool(a.get("bird")), "klang": a.get("klang"), "say": a.get("say", []),
            "w": im.width, "h": im.height,
            "iucn": m.get("iucn"), "facts": facts.get(aid, {}),
            "credits": {k: m[k] for k in ("image", "sound") if m.get(k)},
        })
    shutil.rmtree(tmp)
    used = {a["category"] for a in animals}
    data = {"categories": [c for c in cat["categories"] if c["id"] in used], "animals": animals}
    json.dump(data, open(os.path.join(OUT, "animals.json"), "w"), ensure_ascii=False, separators=(",", ":"))
    # GitHub Pages: serve files as-is (no Jekyll processing)
    open(os.path.join(OUT, ".nojekyll"), "w").close()
    size = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(OUT) for f in fs)
    print(f"{len(animals)} animals, {size / 1e6:.1f} MB -> {OUT}")


if __name__ == "__main__":
    main()
