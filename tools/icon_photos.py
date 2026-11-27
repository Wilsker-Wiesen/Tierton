#!/usr/bin/env python3
"""Finds freely licensed photos of *calling* animals (open mouth/beak) for app-icon ideas and cuts
them out -> tools/.cache/icon/<key>_<n>.heic + credits.json (keeps up to 2 clean cut-outs each)."""
import json, os, re, shutil, sys
sys.path.insert(0, os.path.dirname(__file__))
import fetch_media as f

Q = {
    "ziege": 'goat bleating filetype:bitmap',
    "wolf": 'wolf howling filetype:bitmap',
    "hahn": 'rooster crowing filetype:bitmap',
    "affe": 'howler monkey howling filetype:bitmap',
    "schimpanse": 'chimpanzee screaming open mouth filetype:bitmap',
    "loewe": 'lion roaring filetype:bitmap',
    "tiger": 'tiger roaring filetype:bitmap',
    "nilpferd": 'hippopotamus yawning filetype:bitmap',
    "seeloewe": 'sea lion barking filetype:bitmap',
    "esel": 'donkey braying filetype:bitmap',
    "pferd": 'horse neighing filetype:bitmap',
    "kuh": 'cow mooing filetype:bitmap',
    "hund": 'dog barking filetype:bitmap',
    "katze": 'cat meowing filetype:bitmap',
    "vogel": 'bird singing open beak filetype:bitmap',
    "papagei": 'parrot open beak filetype:bitmap',
    "frosch": 'frog calling vocal sac filetype:bitmap',
    "pavian": 'baboon yawning filetype:bitmap',
}
out = os.path.join(f.CACHE, "icon"); os.makedirs(out, exist_ok=True)
cp = os.path.join(out, "credits.json")
credits = json.load(open(cp)) if os.path.exists(cp) else {}
BAD = re.compile(r"(map|drawing|illustration|logo|stamp|coin|painting|print|plate|museum|statue|sculpture)", re.I)
for key, q in Q.items():
    if any(k.startswith(key + "_") for k in credits): continue
    hits = f.commons_search(q, limit=20)
    inf = f.file_infos(hits)
    cands = [inf[t] for t in hits if t in inf and f.license_ok(inf[t]["license"]) and (inf[t]["mime"] or "").startswith("image/")
             and "svg" not in inf[t]["mime"] and not BAD.search(t)][:8]
    shutil.rmtree(f.CUT_IN, ignore_errors=True); shutil.rmtree(f.CUT_OUT, ignore_errors=True)
    os.makedirs(f.CUT_IN); os.makedirs(f.CUT_OUT)
    for i, c in enumerate(cands):
        try: open(os.path.join(f.CUT_IN, f"{key}_{i}.jpg"), "wb").write(f.get(c["thumb"] or c["url"], binary=True))
        except Exception as e: print(key, i, e)
    res = f.cutout_batch()
    kept = 0
    for i, c in enumerate(cands):
        edges, cov = res.get(f"{key}_{i}", ("LRTB", 0))
        if not (set(edges) & set("LRT")) and 0.06 <= cov <= 0.8 and kept < 3:
            shutil.copy(os.path.join(f.CUT_OUT, f"{key}_{i}.heic"), os.path.join(out, f"{key}_{kept}.heic"))
            credits[f"{key}_{kept}"] = {k: c[k] for k in ("title", "artist", "license", "page")}
            print(f"{key}_{kept}: {c['title'][5:80]}", flush=True)
            kept += 1
    json.dump(credits, open(os.path.join(out, "credits.json"), "w"), ensure_ascii=False, indent=2)
print("done")
