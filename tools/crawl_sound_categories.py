#!/usr/bin/env python3
"""Lists every audio file below Commons' animal-sound categories -> tools/.cache/commons_animal_audio.json
(category browsing is far less throttled than full-text search)."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import fetch_media as f

ROOTS = ["Category:Animal sounds", "Category:Audio files of animals", "Category:Bioacoustics",
         "Category:Audio files of birds", "Category:Audio files of mammals", "Category:Sounds of mammals",
         "Category:Sounds of birds", "Category:Audio files of amphibians", "Category:Audio files of insects",
         "Category:Whale sounds", "Category:Bird vocalizations"]
seen, files = set(), {}
queue = [(r, 0) for r in ROOTS]
while queue:
    cat, depth = queue.pop(0)
    if cat in seen or depth > 4: continue
    seen.add(cat)
    cont = {}
    while True:
        try:
            r = f.api(f.COMMONS, action="query", list="categorymembers", cmtitle=cat, cmlimit=500,
                      cmtype="file|subcat", **cont)
        except Exception as e:
            print("fail", cat, e); break
        for m in r.get("query", {}).get("categorymembers", []):
            t = m["title"]
            if m["ns"] == 14: queue.append((t, depth + 1))
            elif t.lower().endswith((".ogg", ".oga", ".opus", ".wav", ".mp3", ".flac", ".webm")):
                files.setdefault(t, []).append(cat)
        if "continue" not in r: break
        cont = {"cmcontinue": r["continue"]["cmcontinue"]}
    if len(seen) % 50 == 0: print(len(seen), "cats", len(files), "files", flush=True)
json.dump(files, open(os.path.join(f.CACHE, "commons_animal_audio.json"), "w"), ensure_ascii=False)
print("done", len(seen), "categories,", len(files), "audio files")
