#!/usr/bin/env python3
"""Collects up to 4 clean cut-out candidates per animal (for a manual choice) from several Commons
searches. Output: tools/.cache/multi/<id>_<n>.heic and tools/.cache/multi/credits.json"""
import json, os, re, shutil, sys
sys.path.insert(0, os.path.dirname(__file__))
import fetch_media as f

QUERIES = {
    "schwein_rosa": ["pink pig", "Large White pig", "Landrace pig", '"Sus scrofa domesticus" pig farm'],
    "biber_land": ['"Castor fiber" on land', "beaver on land", "beaver walking", '"Castor canadensis" standing'],
    "pottwal_ganz": ["sperm whale underwater", '"Physeter macrocephalus" swimming', "sperm whale calf"],
    "walross": ['"Odobenus rosmarus"', "walrus"],
    "schwein": ['"Sus domesticus"', "domestic pig", "Hausschwein"],
    "biber": ['"Castor fiber"', "eurasian beaver", '"Castor canadensis"'],
    "hund": ['"Canis lupus familiaris"', "dog standing", "Labrador retriever"],
    "wildhund": ['"Lycaon pictus"', "african wild dog"],
    "taube": ['"Columba livia"', "feral pigeon"],
    "pottwal": ['"Physeter macrocephalus"', "sperm whale"],
}
BAD = re.compile(r"(map|range|distribution|skull|skelet|stamp|coin|drawing|illustration|logo|chart|egg|track|footprint|"
                 r"museum|taxiderm|specimen|plate|print|lithograph|magazine|painting|statue|sculpture|toy|model|render|"
                 r"3d|cartoon|meat|food|dish|\.gif)", re.I)
OUT = os.path.join(f.CACHE, "multi")
os.makedirs(OUT, exist_ok=True)
cp = os.path.join(OUT, "credits.json")
credits = json.load(open(cp)) if os.path.exists(cp) else {}
media = json.load(open(f.MEDIA_JSON))
reject = json.load(open(os.path.join(f.ROOT, "tools", "image_reject.json")))
ids = sys.argv[1:] or list(QUERIES)

for qkey in ids:
    aid = qkey.split("_")[0]
    if any(k.startswith(qkey + "_") for k in credits) and qkey != aid:
        continue
    skip = set(reject.get(aid, [])) | {(media.get(aid, {}).get("image") or {}).get("title")} | {v["title"] for v in credits.values()}
    titles = []
    for q in QUERIES[qkey]:
        titles += f.commons_search(f"{q} filetype:bitmap", limit=20)
    titles = [t for t in dict.fromkeys(titles) if t not in skip and not BAD.search(t)]
    inf = f.file_infos(titles)
    cands = [inf[t] for t in titles if t in inf and f.license_ok(inf[t]["license"])
             and (inf[t]["mime"] or "").startswith("image/") and "svg" not in inf[t]["mime"]]
    shutil.rmtree(f.CUT_IN, ignore_errors=True); shutil.rmtree(f.CUT_OUT, ignore_errors=True)
    os.makedirs(f.CUT_IN); os.makedirs(f.CUT_OUT)
    cands = cands[:16]
    for i, c in enumerate(cands):
        try:
            open(os.path.join(f.CUT_IN, f"{aid}_{i}.jpg"), "wb").write(f.get(c["thumb"] or c["url"], binary=True))
        except Exception as e:
            print(aid, i, e)
    res = f.cutout_batch()
    kept = 0
    for i, c in enumerate(cands):
        edges, cov = res.get(f"{aid}_{i}", ("LRTB", 0))
        if f.clean_cut(edges, cov) and cov >= 0.08 and kept < 8:
            shutil.copy(os.path.join(f.CUT_OUT, f"{aid}_{i}.heic"), os.path.join(OUT, f"{qkey}_{kept}.heic"))
            credits[f"{qkey}_{kept}"] = dict({k: c[k] for k in ("title", "artist", "license", "licenseUrl", "page")}, edited="freigestellt")
            print(f"{qkey}_{kept}: {c['title'][5:80]}", flush=True)
            kept += 1
    json.dump(credits, open(cp, "w"), ensure_ascii=False, indent=2)
    print(f"{aid}: {kept} clean of {len(cands)}", flush=True)
