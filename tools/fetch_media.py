#!/usr/bin/env python3
"""Fetch freely licensed photos, sounds and IUCN status for every animal in Content/catalog.json.

Sources: German Wikipedia -> Wikidata (photo P18, audio P51, IUCN P141, CC0 data)
         Wikimedia Commons (search for audio, license + author metadata).

Usage:
  python3 tools/fetch_media.py resolve    # find candidates -> Content/media_candidates.json
  python3 tools/fetch_media.py download   # download + convert chosen sounds -> Tierton/Resources/Media, Content/media.json
  python3 tools/fetch_media.py images     # pick photos whose automatic cut-out is clean -> Media/<id>.heic
  python3 tools/fetch_media.py all

Overrides: in catalog.json an animal may set "image": "File name.jpg" or "sound": "File name.ogg"
(Commons file names without the "File:" prefix) to force a specific file.
Only licenses CC0 / Public Domain / CC BY / CC BY-SA are accepted.
"""
import json, os, re, ssl, subprocess, sys, time, urllib.parse, urllib.request, html

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "Content", "catalog.json")
CANDIDATES = os.path.join(ROOT, "Content", "media_candidates.json")
MEDIA_JSON = os.path.join(ROOT, "Content", "media.json")
OUT_DIR = os.path.join(ROOT, "Tierton", "Resources", "Media")
CACHE = os.path.join(ROOT, "tools", ".cache")
SSL = ssl.create_default_context(cafile="/etc/ssl/cert.pem") if os.path.exists("/etc/ssl/cert.pem") else None
UA = "TiertonContentBot/0.1 (educational animal-sound app; build script)"

IUCN = {  # Wikidata items for IUCN categories
    "Q211005": "LC", "Q719675": "NT", "Q278113": "VU", "Q11394": "EN", "Q219127": "CR",
    "Q239509": "EW", "Q237350": "EX", "Q3245245": "DD",
}

import hashlib, urllib.error

def get(url, binary=False, retries=8):
    key = None
    if not binary:
        os.makedirs(os.path.join(CACHE, "api"), exist_ok=True)
        key = os.path.join(CACHE, "api", hashlib.sha1(url.encode()).hexdigest() + ".json")
        if os.path.exists(key):
            return json.load(open(key))
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60, context=SSL) as r:
                data = r.read()
            time.sleep(1.2)
            if binary:
                return data
            obj = json.loads(data)
            json.dump(obj, open(key, "w"))
            return obj
        except urllib.error.HTTPError as e:
            if i == retries - 1 or e.code not in (429, 500, 502, 503, 504):
                raise
            wait = int(e.headers.get("Retry-After") or 0) or (20 if binary else 5) * (i + 1)
            print(f"  (HTTP {e.code}, waiting {wait}s)", flush=True)
            time.sleep(min(wait, 150))
        except Exception:
            if i == retries - 1:
                raise
            time.sleep(3 * (i + 1))

def api(base, **params):
    params.setdefault("format", "json")
    return get(base + "?" + urllib.parse.urlencode(params))

COMMONS = "https://commons.wikimedia.org/w/api.php"
DEWIKI = "https://de.wikipedia.org/w/api.php"
WIKIDATA = "https://www.wikidata.org/w/api.php"

def chunks(xs, n):
    for i in range(0, len(xs), n):
        yield xs[i:i + n]

def strip_html(s):
    s = re.sub(r"<[^>]+>", "", s or "")
    return html.unescape(s).strip()

def file_infos(titles):
    """Commons imageinfo for a list of 'File:...' titles -> {title: info}"""
    out = {}
    for batch in chunks(list(dict.fromkeys(titles)), 40):
        r = api(COMMONS, action="query", titles="|".join(batch), prop="imageinfo",
                iiprop="url|size|mime|extmetadata|metadata", iiurlwidth=900, redirects=1)
        q = r.get("query", {})
        redirects = {x["from"]: x["to"] for x in q.get("redirects", [])}
        normalized = {x["from"]: x["to"] for x in q.get("normalized", [])}
        pages = {p["title"]: p for p in q.get("pages", {}).values()}
        for t in batch:
            t2 = normalized.get(t, t)
            t2 = redirects.get(t2, t2)
            p = pages.get(t2)
            if p and "imageinfo" in p:
                ii = p["imageinfo"][0]
                em = ii.get("extmetadata", {})
                length = None
                for m in ii.get("metadata") or []:
                    if m.get("name") in ("length", "playtime_seconds", "duration"):
                        try: length = float(m["value"])
                        except Exception: pass
                out[t] = {
                    "title": t2, "url": ii.get("url"), "thumb": ii.get("thumburl"),
                    "mime": ii.get("mime"), "size": ii.get("size"), "length": length,
                    "license": strip_html(em.get("LicenseShortName", {}).get("value")),
                    "licenseUrl": strip_html(em.get("LicenseUrl", {}).get("value")),
                    "artist": strip_html(em.get("Artist", {}).get("value")),
                    "description": strip_html(em.get("ImageDescription", {}).get("value"))[:300],
                    "page": "https://commons.wikimedia.org/wiki/" + urllib.parse.quote(t2.replace(" ", "_")),
                }
    return out

def license_ok(lic):
    l = (lic or "").lower()
    if any(b in l for b in ("nc", "nd", "fair use", "non-free")):
        return False
    return l.startswith("cc0") or "public domain" in l or l.startswith("pd") or l.startswith("cc by") or l.startswith("cc-by")

PRON = re.compile(r"^File:(LL-Q\d+|[A-Z][a-z]{1,2}(-[a-z]{2,4})?-|Mgm |.*pronunciation)", re.I)
BAD = re.compile(r"(spoken|wikipedia|dance|percussion|anthem|hymn|lecture|interview|speech|poem|lied |song of |radio|podcast|music|instrument|ringtone|remix|voice of|vortrag)", re.I)

def score(c, a, from_p51):
    t = c["title"]
    text = (t + " " + c.get("description", "")).lower()
    s = 0
    if PRON.match(t) or BAD.search(t):
        return -100
    if c["mime"] and not c["mime"].startswith(("audio", "application/ogg", "video/ogg")):
        return -100
    if c["mime"] and c["mime"].startswith("video"):
        return -100
    if not license_ok(c["license"]):
        return -100
    L = c.get("length")
    if L is not None:
        if L < 0.5 or L > 900: return -100
        if 3 <= L <= 90: s += 2
    if "midi" in (c["mime"] or ""):
        return -100
    if from_p51: s += 6
    sci = a["sci"].lower()
    genus_species = " ".join(sci.split()[:2])
    VERBS = {"sound", "sounds", "call", "song", "roar", "howl", "bark", "barking", "meow", "moo", "bleat", "neigh",
             "bray", "crowing", "clucking", "quack", "gobble", "trumpet", "bellow", "clicks", "buzzing", "oink", "duck",
             "whale", "common", "eurasian", "european", "african", "american", "great", "domestic", "red", "grey"}
    nouns = [w for w in re.findall(r"[a-z]+", a["en"].lower()) if w not in VERBS and len(w) > 2]
    tl = t.lower()
    relevant = (from_p51 or genus_species in text or genus_species.replace(" ", "_") in text
                or a["name"].lower() in tl or (nouns and all(w in tl for w in nouns)))
    if not relevant:
        return -100
    if genus_species in text or genus_species.replace(" ", "_") in text: s += 5
    en_words = [w for w in a["en"].lower().split() if len(w) > 2]
    s += 2 * sum(1 for w in en_words if w in t.lower())
    if a["name"].lower() in text: s += 1
    if re.search(r"\b(xc\d+|xeno-canto)", text) and a.get("bird"): s += 2
    if re.search(r"(call|song|roar|sound|vocal|howl|bark|meow|moo|bleat|neigh|bray|crow|quack|chirp|ruf|gesang|laut|grunt|squeak|click|whistle|growl|trumpet)", text): s += 2
    return s

def commons_search(q, limit=15):
    r = api(COMMONS, action="query", list="search", srsearch=q, srnamespace=6, srlimit=limit)
    return [x["title"] for x in r.get("query", {}).get("search", [])]

def resolve():
    cat = json.load(open(CATALOG))
    animals = cat["animals"]
    # 1) dewiki -> QID
    titles = list({a["dewiki"] for a in animals})
    qid = {}
    for batch in chunks(titles, 45):
        r = api(DEWIKI, action="query", titles="|".join(batch), prop="pageprops", ppprop="wikibase_item", redirects=1)
        q = r["query"]
        m = {t: t for t in batch}
        for x in q.get("normalized", []):
            for k, v in m.items():
                if v == x["from"]: m[k] = x["to"]
        for x in q.get("redirects", []):
            for k, v in m.items():
                if v == x["from"]: m[k] = x["to"]
        pages = {p["title"]: p for p in q["pages"].values()}
        for k, v in m.items():
            p = pages.get(v, {})
            qid[k] = p.get("pageprops", {}).get("wikibase_item")
    # 2) Wikidata claims
    ents = {}
    for batch in chunks([q for q in set(qid.values()) if q], 45):
        r = api(WIKIDATA, action="wbgetentities", ids="|".join(batch), props="claims")
        ents.update(r["entities"])
    def claim_vals(e, p):
        return [c["mainsnak"].get("datavalue", {}).get("value") for c in e.get("claims", {}).get(p, []) if c["mainsnak"].get("datavalue")]
    result = {}
    for a in animals:
        q = qid.get(a["dewiki"])
        e = ents.get(q, {}) if q else {}
        imgs = claim_vals(e, "P18")
        auds = claim_vals(e, "P51")
        iucn = [IUCN.get(v["id"]) for v in claim_vals(e, "P141") if isinstance(v, dict)]
        sound_titles = []
        p51 = set()
        if a.get("sound"):
            sound_titles.append("File:" + a["sound"]); p51.add("File:" + a["sound"])
        for f in auds:
            sound_titles.append("File:" + f); p51.add("File:" + f)
        g_s = " ".join(a["sci"].split()[:2])
        # scientific name first; the other searches only if it finds (almost) nothing –
        # Commons throttles anonymous search heavily.
        hits = commons_search(f'"{g_s}" filemime:audio')
        sound_titles += hits
        if len(hits) < 3 and not auds:
            sound_titles += commons_search(f'{a["en"]} filemime:audio')
        result[a["id"]] = {"qid": q, "iucn": next((x for x in iucn if x), None),
                           "image": "File:" + (a.get("image") or (imgs[0] if imgs else "")) if (a.get("image") or imgs) else None,
                           "_sounds": sound_titles, "_p51": list(p51)}
        print(f"{a['id']:16} {q or '-':10} img={'y' if result[a['id']]['image'] else 'n'} p51={len(auds)} cands={len(set(sound_titles))}", flush=True)
    # 3) Commons metadata
    all_titles = []
    for r in result.values():
        all_titles += r["_sounds"]
        if r["image"]: all_titles.append(r["image"])
    infos = file_infos(all_titles)
    by_id = {a["id"]: a for a in animals}
    for aid, r in result.items():
        a = by_id[aid]
        cands = []
        for t in dict.fromkeys(r["_sounds"]):
            c = infos.get(t)
            if not c: continue
            s = score(c, a, t in r["_p51"])
            if a.get("sound") and t == "File:" + a["sound"]: s += 1000
            cands.append(dict(c, score=s))
        cands.sort(key=lambda c: -c["score"])
        r["soundCandidates"] = [c for c in cands if c["score"] > -100][:5]
        r["sound"] = r["soundCandidates"][0] if r["soundCandidates"] and r["soundCandidates"][0]["score"] >= 2 else None
        img = infos.get(r["image"]) if r["image"] else None
        r["image"] = img if img and license_ok(img["license"]) else None
        r["imageRejected"] = img["license"] if img and not r["image"] else None
        del r["_sounds"], r["_p51"]
    json.dump(result, open(CANDIDATES, "w"), ensure_ascii=False, indent=2)
    missing_s = [k for k, v in result.items() if not v["sound"]]
    missing_i = [k for k, v in result.items() if not v["image"]]
    print("no sound:", missing_s)
    print("no image:", missing_i)

# skip leading silence, max 14 s, cut rumble, FFT denoise, loudness-normalise,
# soft noise gate between calls, short fades
SOUND_FILTER = ("silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.1,"
                "atrim=0:14,highpass=f=70,afftdn=nr=24:nf=-35:tn=1,loudnorm=I=-16:TP=-1.5:LRA=11,"
                "agate=threshold=0.03:ratio=3:range=0.06:attack=10:release=250,"
                "afade=t=in:d=0.05,areverse,afade=t=in:d=0.6,areverse")


def reprocess(only=None):
    """Rebuilds every existing Media/<id>.m4a from its cached original with SOUND_FILTER (no downloads)."""
    import glob
    for m4a in sorted(glob.glob(os.path.join(OUT_DIR, "*.m4a"))):
        aid = os.path.basename(m4a)[:-4]
        if only and aid not in only: continue
        raws = sorted(glob.glob(os.path.join(CACHE, "raw", aid + "_snd*")), key=os.path.getmtime, reverse=True)
        raw = next((r for r in raws if subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a", "-show_entries",
                     "stream=codec_type", "-of", "csv=p=0", r], capture_output=True, text=True).stdout.strip()), None)
        if not raw:
            print(f"{aid:16} no cached original, kept"); continue
        tmp = m4a + ".tmp.m4a"
        try:
            run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-vn", "-ac", "1", "-ar", "44100",
                 "-af", SOUND_FILTER, "-c:a", "aac", "-b:a", "80k", tmp])
            dur = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", tmp],
                                 capture_output=True, text=True).stdout.strip()
            if not dur or float(dur) < 0.3:
                run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-vn", "-ac", "1", "-ar", "44100",
                     "-af", SOUND_FILTER.split(",", 1)[1], "-c:a", "aac", "-b:a", "80k", tmp])
            os.replace(tmp, m4a)
            print(f"{aid:16} ok", flush=True)
        except Exception as e:
            print(f"{aid:16} FAILED {str(e)[:100]}")
            if os.path.exists(tmp): os.remove(tmp)


def run(cmd):
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(" ".join(cmd) + "\n" + p.stderr[-800:])

def download(only=None):
    cands = json.load(open(CANDIDATES))
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(os.path.join(CACHE, "raw"), exist_ok=True)
    media = json.load(open(MEDIA_JSON)) if os.path.exists(MEDIA_JSON) else {}
    rp = os.path.join(ROOT, "tools", "sound_reject.json")
    reject = json.load(open(rp)) if os.path.exists(rp) else {}
    valid = {a["id"] for a in json.load(open(CATALOG))["animals"]}
    for aid, r in cands.items():
        if only and aid not in only: continue
        if aid not in valid: continue
        if r.get("sound") and r["sound"]["title"] in reject.get(aid, []):
            r = dict(r, sound=None)
            dst = os.path.join(OUT_DIR, f"{aid}.m4a")
            if os.path.exists(dst): os.remove(dst)
            media.get(aid, {}).pop("sound", None)
        entry = media.get(aid, {})
        entry["iucn"] = r.get("iucn")
        entry["wikidata"] = r.get("qid")
        snd = r.get("sound")
        try:
            fetch_sound(aid, snd, entry)
        except Exception as e:
            print(f"{aid:16} FAILED {str(e)[:120]}", flush=True)
            snd = None
        media[aid] = entry
        json.dump(media, open(MEDIA_JSON, "w"), ensure_ascii=False, indent=2)
        print(f"{aid:16} snd={'y' if snd else '-'}", flush=True)

def fetch_sound(aid, snd, entry):
        if snd:
            dst = os.path.join(OUT_DIR, f"{aid}.m4a")
            if not os.path.exists(dst) or (entry.get("sound") or {}).get("title") != snd["title"]:
                # Prefer Commons' transcoded MP3: originals are rate-limited much harder.
                url = snd["url"]
                try:
                    r2 = api(COMMONS, action="query", titles=snd["title"], prop="videoinfo", viprop="derivatives")
                    for pg in r2["query"]["pages"].values():
                        ders = (pg.get("videoinfo") or [{}])[0].get("derivatives", [])
                        mp3 = [d["src"] for d in ders if d.get("type") == "audio/mpeg" and "/transcoded/" in d["src"]]
                        # videos: smallest transcode is enough, only the audio track is used
                        vids = sorted((d for d in ders if str(d.get("type", "")).startswith("video") and "/transcoded/" in d["src"]),
                                      key=lambda d: int(d.get("height") or 9999))
                        if mp3: url = mp3[0]
                        elif vids: url = vids[0]["src"]
                except Exception:
                    pass
                ext = os.path.splitext(url.split("?")[0])[1]
                raw = os.path.join(CACHE, "raw", f"{aid}_snd{ext}")
                open(raw, "wb").write(get(url, binary=True))
                # small video transcodes on Commons carry no audio track -> fall back to the original file
                probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a", "-show_entries", "stream=codec_type",
                                        "-of", "csv=p=0", raw], capture_output=True, text=True).stdout.strip()
                if not probe and url != snd["url"]:
                    ext = os.path.splitext(snd["url"].split("?")[0])[1]
                    raw = os.path.join(CACHE, "raw", f"{aid}_snd_orig{ext}")
                    open(raw, "wb").write(get(snd["url"], binary=True))
                # skip leading silence, max 14 s, loudness-normalise, short fades, mono AAC
                af = SOUND_FILTER
                run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-vn", "-ac", "1", "-ar", "44100",
                     "-af", af, "-c:a", "aac", "-b:a", "80k", dst])
                dur = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", dst],
                                     capture_output=True, text=True).stdout.strip()
                if not dur or float(dur or 0) < 0.3:
                    run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-vn", "-ac", "1", "-ar", "44100",
                         "-af", af.split(",", 1)[1], "-c:a", "aac", "-b:a", "80k", dst])
            entry["sound"] = {k: snd[k] for k in ("title", "artist", "license", "licenseUrl", "page")}

def sounds_from_crawl(max_check=40):
    """Second source for sounds: all audio files found by tools/crawl_sound_categories.py.
    Matches file titles to animals that have no (or a rejected) sound and re-picks."""
    cat = json.load(open(CATALOG))
    cands = json.load(open(CANDIDATES))
    crawl = json.load(open(os.path.join(CACHE, "commons_animal_audio.json")))
    rp = os.path.join(ROOT, "tools", "sound_reject.json")
    reject = json.load(open(rp)) if os.path.exists(rp) else {}
    titles = list(crawl)
    low = [t.lower() for t in titles]
    for a in cat["animals"]:
        aid = a["id"]
        r = cands.setdefault(aid, {})
        cur = r.get("sound")
        if cur and cur["title"] not in reject.get(aid, []):
            continue
        g_s = " ".join(a["sci"].split()[:2]).lower()
        VERBS = {"sound", "sounds", "call", "song", "roar", "howl", "bark", "barking", "meow", "moo", "bleat", "neigh",
                 "bray", "crowing", "clucking", "quack", "gobble", "trumpet", "bellow", "clicks", "buzzing", "oink"}
        nouns = [w for w in re.findall(r"[a-z]+", a["en"].lower()) if w not in VERBS and len(w) > 2]
        keys = [g_s, a["name"].lower()] + ([" ".join(nouns)] if nouns else []) + [x.lower() for x in a.get("say", []) if len(x) > 3]
        hits = [titles[i] for i, t in enumerate(low) if any(k and k in t for k in keys)][:max_check]
        old = [c["title"] for c in r.get("soundCandidates", [])]
        pool = [t for t in dict.fromkeys(old + hits) if t not in reject.get(aid, [])]
        if not pool:
            r["sound"] = None; continue
        infos = file_infos(pool)
        scored = sorted((dict(c, score=score(c, a, False)) for c in infos.values()), key=lambda c: -c["score"])
        scored = [c for c in scored if c["score"] > -100 and c["title"] not in reject.get(aid, [])]
        r["soundCandidates"] = scored[:5]
        r["sound"] = scored[0] if scored and scored[0]["score"] >= 2 else None
        print(f"{aid:16} {(r['sound']['title'][5:70] if r['sound'] else '---')}", flush=True)
    json.dump(cands, open(CANDIDATES, "w"), ensure_ascii=False, indent=2)

CUT_IN = os.path.join(CACHE, "cut_in")
CUT_OUT = os.path.join(CACHE, "cut_out")

def cutout_batch():
    """Runs tools/cutout.swift on everything in CUT_IN; returns {name: (edges, coverage)}."""
    p = subprocess.run(["swift", os.path.join(ROOT, "tools", "cutout.swift"), CUT_IN, CUT_OUT],
                       capture_output=True, text=True)
    res = {}
    for line in p.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) >= 4:
            res[parts[0]] = (parts[3].split("=")[1], float(parts[2].split("=")[1]))
    return res

def clean_cut(edges, coverage):
    # animal must not be cut off left/right/top; bottom is hidden by the circle anyway
    return not (set(edges) & set("LRT")) and 0.05 <= coverage <= 0.75

def images(only=None, max_rounds=6):
    """Pick for every animal the first photo (Wikidata main image, then Commons search hits)
    whose automatic cut-out is clean, and store it as Media/<id>.heic (transparent)."""
    import shutil
    cat = json.load(open(CATALOG))
    cands = json.load(open(CANDIDATES))
    media = json.load(open(MEDIA_JSON)) if os.path.exists(MEDIA_JSON) else {}
    os.makedirs(OUT_DIR, exist_ok=True)
    todo = [a for a in cat["animals"] if (not only or a["id"] in only)]
    if not only:  # keep animals that already have a cut-out from the same photo
        todo = [a for a in todo if not os.path.exists(os.path.join(OUT_DIR, a["id"] + ".heic"))]
    by_id = {a["id"]: a for a in todo}
    BAD_IMG = re.compile(r"(map|range|distribution|skull|skelet|stamp|coin|drawing|illustration|logo|chart|egg|track|footprint|museum|taxiderm|specimen|\.gif)", re.I)
    def usable(infos, titles):
        return [infos[t] for t in titles if t in infos and license_ok(infos[t]["license"])
                and (infos[t]["mime"] or "").startswith("image/") and "svg" not in infos[t]["mime"]
                and not BAD_IMG.search(infos[t]["title"])]
    # round 0: the Wikidata main photo (or the catalog override); search only for animals that fail
    firsts = {}
    for a in todo:
        if a.get("image"): firsts[a["id"]] = ["File:" + a["image"]]
        elif (cands.get(a["id"]) or {}).get("image"): firsts[a["id"]] = [cands[a["id"]]["image"]["title"]]
        else: firsts[a["id"]] = []
    # tools/image_reject.json: {id: [photo titles that looked wrong in the contact sheet]}
    rp = os.path.join(ROOT, "tools", "image_reject.json")
    reject = json.load(open(rp)) if os.path.exists(rp) else {}
    for aid in firsts:
        if not by_id[aid].get("image"):
            firsts[aid] = [t for t in firsts[aid] if t not in reject.get(aid, [])]
    infos0 = file_infos([t for l in firsts.values() for t in l])
    lists = {aid: usable(infos0, l) for aid, l in firsts.items()}
    searched = set()
    def extend(aid):
        if aid in searched: return
        searched.add(aid)
        a = by_id[aid]
        g_s = " ".join(a["sci"].split()[:2])
        q = a.get("imageQuery") or f'"{g_s}"'
        hits = [t for t in commons_search(f'{q} filetype:bitmap', limit=25)
                if t not in firsts[aid] and t not in reject.get(aid, [])]
        lists[aid] += usable(file_infos(hits), hits)
    for aid in lists:
        if not lists[aid]: extend(aid)
    pending = {aid for aid, l in lists.items() if l}
    for rnd in range(max_rounds):
        if not pending: break
        shutil.rmtree(CUT_IN, ignore_errors=True); shutil.rmtree(CUT_OUT, ignore_errors=True)
        os.makedirs(CUT_IN); os.makedirs(CUT_OUT)
        tried = {}
        for aid in sorted(pending):
            if rnd >= len(lists[aid]): extend(aid)
            if rnd >= len(lists[aid]): continue
            c = lists[aid][rnd]
            try:
                open(os.path.join(CUT_IN, aid + ".jpg"), "wb").write(get(c["thumb"] or c["url"], binary=True))
                tried[aid] = c
            except Exception as e:
                print(f"  {aid}: download failed {e}")
        res = cutout_batch()
        for aid, c in tried.items():
            edges, cov = res.get(aid, ("LRTB", 0))
            # a hand-picked photo from the catalog is always accepted
            ok = clean_cut(edges, cov) or (rnd == 0 and bool(by_id[aid].get("image")))
            print(f"round {rnd} {aid:16} edges={edges or '-':4} cov={cov:.2f} {'OK ' if ok else 'no '} {c['title'][5:60]}", flush=True)
            if ok:
                shutil.copy(os.path.join(CUT_OUT, aid + ".heic"), os.path.join(OUT_DIR, aid + ".heic"))
                media.setdefault(aid, {})["image"] = dict({k: c[k] for k in ("title", "artist", "license", "licenseUrl", "page")}, edited="freigestellt")
                pending.discard(aid)
        json.dump(media, open(MEDIA_JSON, "w"), ensure_ascii=False, indent=2)
    print("no clean photo:", sorted(pending | {aid for aid, l in lists.items() if not l}))

def images_alt(ids, max_rounds=5):
    """Finds a second clean cut-out per animal (current photo excluded) for a side-by-side choice.
    Writes tools/.cache/alt/<id>.heic and tools/.cache/alt/credits.json; media.json stays untouched."""
    import shutil
    cat = json.load(open(CATALOG))
    media = json.load(open(MEDIA_JSON))
    by_id = {a["id"]: a for a in cat["animals"]}
    alt_dir = os.path.join(CACHE, "alt"); os.makedirs(alt_dir, exist_ok=True)
    cp = os.path.join(alt_dir, "credits.json")
    credits = json.load(open(cp)) if os.path.exists(cp) else {}
    rp = os.path.join(ROOT, "tools", "image_reject.json")
    reject = json.load(open(rp)) if os.path.exists(rp) else {}
    BAD_IMG = re.compile(r"(map|range|distribution|skull|skelet|stamp|coin|drawing|illustration|logo|chart|egg|track|footprint|museum|taxiderm|specimen|plate|print|lithograph|birds of|magazine|iconographia|painting|\.gif)", re.I)
    lists = {}
    for aid in ids:
        if aid in credits or aid not in by_id: continue
        a = by_id[aid]
        cur = (media.get(aid, {}).get("image") or {}).get("title")
        g_s = " ".join(a["sci"].split()[:2])
        q = a.get("imageQuery") or f'"{g_s}"'
        hits = [t for t in commons_search(f'{q} filetype:bitmap', limit=25) if t != cur and t not in reject.get(aid, [])]
        inf = file_infos(hits)
        lists[aid] = [inf[t] for t in hits if t in inf and license_ok(inf[t]["license"])
                      and (inf[t]["mime"] or "").startswith("image/") and "svg" not in inf[t]["mime"]
                      and not BAD_IMG.search(inf[t]["title"])]
        print(f"{aid:16} {len(lists[aid])} alternatives", flush=True)
    pending = {k for k, v in lists.items() if v}
    for rnd in range(max_rounds):
        if not pending: break
        shutil.rmtree(CUT_IN, ignore_errors=True); shutil.rmtree(CUT_OUT, ignore_errors=True)
        os.makedirs(CUT_IN); os.makedirs(CUT_OUT)
        tried = {}
        for aid in sorted(pending):
            if rnd >= len(lists[aid]): continue
            c = lists[aid][rnd]
            try:
                open(os.path.join(CUT_IN, aid + ".jpg"), "wb").write(get(c["thumb"] or c["url"], binary=True)); tried[aid] = c
            except Exception as e:
                print(f"  {aid}: {e}")
        res = cutout_batch()
        for aid, c in tried.items():
            edges, cov = res.get(aid, ("LRTB", 0))
            if clean_cut(edges, cov) and cov >= 0.08:
                shutil.copy(os.path.join(CUT_OUT, aid + ".heic"), os.path.join(alt_dir, aid + ".heic"))
                credits[aid] = dict({k: c[k] for k in ("title", "artist", "license", "licenseUrl", "page")}, edited="freigestellt")
                pending.discard(aid)
                print(f"alt {aid:16} {c['title'][5:70]}", flush=True)
        json.dump(credits, open(cp, "w"), ensure_ascii=False, indent=2)
    print("no alternative:", sorted(pending | {k for k, v in lists.items() if not v}))

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "all"
    if cmd in ("resolve", "all"): resolve()
    if cmd in ("download", "all"): download(set(sys.argv[2:]) or None)
    if cmd in ("images", "all"): images(set(sys.argv[2:]) or None)
    if cmd == "crawlsounds": sounds_from_crawl()
    if cmd == "altimages": images_alt(sys.argv[2:])
    if cmd == "reprocess": reprocess(set(sys.argv[2:]) or None)
