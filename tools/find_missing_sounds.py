#!/usr/bin/env python3
"""Searches Commons more broadly (audio AND video with sound) for animals that still have no sound.
Writes tools/missing_sound_candidates.json: {id: [candidate, ...]} for manual review, best first.
Pick one with:  python3 tools/fetch_media.py download <id>  after setting it as "sound" in the catalog."""
import json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
import fetch_media as f

cat = json.load(open(f.CATALOG))
out_path = os.path.join(f.ROOT, "tools", "missing_sound_candidates.json")
result = json.load(open(out_path)) if os.path.exists(out_path) else {}
rp = os.path.join(f.ROOT, "tools", "sound_reject.json")
reject = json.load(open(rp)) if os.path.exists(rp) else {}

VERBS = {"sound", "sounds", "call", "song", "roar", "howl", "bark", "barking", "meow", "moo", "bleat", "neigh",
         "bray", "crowing", "clucking", "quack", "gobble", "trumpet", "bellow", "clicks", "buzzing", "oink"}
JUNK = re.compile(r"(^File:(LL-Q\d+|[A-Z][a-z]{1,2}(-[a-z]{2,4})?-)|pronunciation|spoken|wikipedia|lecture|interview|"
                  r"speech|song of|music|anthem|hymn|podcast|radio|story|poem|remix|cartoon|sonic|elevator|print)", re.I)

for a in cat["animals"]:
    aid = a["id"]
    if os.path.exists(os.path.join(f.OUT_DIR, aid + ".m4a")) or aid in result:
        continue
    g_s = " ".join(a["sci"].split()[:2])
    nouns = [w for w in re.findall(r"[a-z]+", a["en"].lower()) if w not in VERBS and len(w) > 2]
    noun = " ".join(nouns) or a["en"]
    queries = [f'"{g_s}" filetype:video', f'{noun} sound filetype:audio', f'{noun} filetype:video',
               f'"{a["name"]}" filetype:video']
    titles = []
    for q in queries:
        try:
            titles += f.commons_search(q, limit=15)
        except Exception as e:
            print(aid, "search failed", e)
    titles = [t for t in dict.fromkeys(titles) if not JUNK.search(t) and t not in reject.get(aid, [])]
    infos = f.file_infos(titles) if titles else {}
    keys = [g_s.lower(), a["name"].lower(), noun.lower()] + [x.lower() for x in a.get("say", []) if len(x) > 3]
    cands = []
    for t, c in infos.items():
        text = (t + " " + c.get("description", "")).lower()
        if not any(k in text for k in keys):
            continue
        if not f.license_ok(c["license"]):
            continue
        mime = c["mime"] or ""
        if not (mime.startswith("audio") or mime.startswith("video") or mime == "application/ogg"):
            continue
        L = c.get("length")
        if L is not None and (L < 0.5 or L > 600):
            continue
        s = 0
        if g_s.lower() in text: s += 4
        if noun.lower() in t.lower(): s += 3
        if re.search(r"(call|sound|roar|bray|bleat|crow|vocal|cry|howl|grunt|trumpet|bark|song|singing|ruf|schrei)", text): s += 3
        if mime.startswith("audio"): s += 2
        if L and 3 <= L <= 90: s += 1
        cands.append(dict(c, score=s))
    cands.sort(key=lambda c: -c["score"])
    result[aid] = cands[:4]
    print(f"{aid:16} {len(cands):2} | " + (cands[0]["title"][5:70] if cands else "---"), flush=True)
    json.dump(result, open(out_path, "w"), ensure_ascii=False, indent=2)
print("done")
