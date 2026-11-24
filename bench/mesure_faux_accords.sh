#!/usr/bin/env bash
# P2-279 (mesure) : taux de masquages à tort par détecteur, avec intervalle de
# confiance à 95 %, par `Ecluse.redact`. Rien n'est corrigé. Depuis la racine du
# dépôt (graine 42, ≈ 10 min) :
#     bash bench/mesure_faux_accords.sh [DOSSIER_DE_TRAVAIL]
# Chemin mesuré : `Ecluse.redact` (`packages/ecluse_redact/bin/run_faux_accords.dart`).
set -Eeuo pipefail
R=$(pwd)
W=${1:-$(mktemp -d)}
mkdir -p "$W"
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
# 1. témoin durci de P2-268 élargi : 5 familles x 1 000 = 5 000 documents
python3 bench/generate_corpus_ocr.py --n 1 --n-dur 1000 --seed 42 --out "$W/ocr.jsonl" > /dev/null
python3 - "$W" <<'PY'
import json, sys
w = sys.argv[1]
with open(f"{w}/ocr_dur.jsonl", "w", encoding="utf-8") as f:
    for l in open(f"{w}/ocr.jsonl", encoding="utf-8"):
        if json.loads(l)["presentation"] == "temoin_dur":
            f.write(l)
PY
# 2. nombres dictés en lettres, témoin durci de P2-270 élargi : 7 x 800 = 5 600
python3 bench/generate_corpus_mots_nombres_dur.py --n 800 --seed 42 --out "$W/mn_dur.jsonl" > /dev/null
# 3. 200 000 documents du soin et du social sans aucune donnée personnelle
python3 bench/generate_corpus_temoin_sans_pii.py --n 200000 --seed 42 --out "$W/sanspii.jsonl" > /dev/null
(cd packages/ecluse_redact
 for c in ocr_dur mn_dur sanspii; do
   dart run bin/run_faux_accords.dart "$W/$c.jsonl" "$W/fa_$c.jsonl" < /dev/null
 done)
python3 bench/score_faux_accords.py --corpus "$W/ocr_dur.jsonl" --pred "$W/fa_ocr_dur.jsonl" --nom "témoin durci de P2-268, élargi"
python3 bench/score_faux_accords.py --corpus "$W/mn_dur.jsonl" --pred "$W/fa_mn_dur.jsonl" --nom "mots-nombres durci, élargi" --tout-en-dictees
python3 bench/score_faux_accords.py --corpus "$W/sanspii.jsonl" --pred "$W/fa_sanspii.jsonl" --nom "200 000 documents sans donnée personnelle"
