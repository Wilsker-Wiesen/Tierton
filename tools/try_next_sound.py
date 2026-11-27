#!/usr/bin/env python3
"""For animals without a usable sound: try the remaining candidates from
tools/missing_sound_candidates.json one by one. A candidate is accepted when it has an audio
track and Apple's sound classifier finds no speech/music in it; otherwise it goes to the reject list.
Usage: python3 tools/try_next_sound.py <id> [<id> ...]"""
import json, os, subprocess, sys
sys.path.insert(0, os.path.dirname(__file__))
import fetch_media as f

ids = sys.argv[1:]
cands_all = json.load(open(os.path.join(f.ROOT, "tools", "missing_sound_candidates.json")))
rp = os.path.join(f.ROOT, "tools", "sound_reject.json")
reject = json.load(open(rp))
cp = f.CANDIDATES
media_c = json.load(open(cp))

def classify(aid):
    out = subprocess.run(["swift", os.path.join(f.ROOT, "tools", "classify_sounds.swift"), f.OUT_DIR, aid],
                         capture_output=True, text=True).stdout.strip()
    return out

for aid in ids:
    done = False
    for c in cands_all.get(aid, []):
        if c["title"] in reject.get(aid, []):
            continue
        media_c.setdefault(aid, {})["sound"] = c
        json.dump(media_c, open(cp, "w"), ensure_ascii=False, indent=2)
        dst = os.path.join(f.OUT_DIR, aid + ".m4a")
        if os.path.exists(dst): os.remove(dst)
        f.download({aid})
        verdict = classify(aid) if os.path.exists(dst) else f"{aid}\tFAIL\tno file"
        print(verdict, "|", c["title"][5:70], flush=True)
        if "\tok" in verdict:
            done = True
            break
        reject.setdefault(aid, []).append(c["title"])
        json.dump(reject, open(rp, "w"), ensure_ascii=False, indent=2)
        if os.path.exists(dst): os.remove(dst)
    if not done:
        media_c.setdefault(aid, {})["sound"] = None
        json.dump(media_c, open(cp, "w"), ensure_ascii=False, indent=2)
        print(f"{aid}: no usable sound", flush=True)
