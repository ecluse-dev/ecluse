import json, sys
from collections import Counter, defaultdict

def load(path):
    out = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                d = json.loads(line)
                out[d["id"]] = d
    return out

corpus = load(sys.argv[1])
preds = load(sys.argv[2])
par_type = defaultdict(Counter)

for doc_id, doc in corpus.items():
    text = doc["text"]
    gold_chars = set()
    for g in doc.get("entities", []):
        gold_chars.update(range(g["start"], g["end"]))
    for e in preds.get(doc_id, {}).get("entities", []):
        if any(i in gold_chars for i in range(e["start"], e["end"])):
            continue
        frag = text[e["start"]:e["end"]].replace("\n", "\\n")
        par_type[e["type"]][frag] += 1

for t in sorted(par_type):
    total = sum(par_type[t].values())
    print(f"\n{'='*70}\n{t} — {total} detections, {len(par_type[t])} fragments distincts\n{'='*70}")
    for frag, n in par_type[t].most_common(30):
        print(f"  {n:5d}  {frag!r}")

if not par_type:
    print("Aucun faux positif.")