#!/usr/bin/env bash
# P2-270 (mesure) : effet du seuil K (`_kSuite`) et du mot-clé « code » de
# `_motCleFaible` sur le témoin durci et sur les variantes dictées de P2-267,
# par `Ecluse.redact`. Rien n'est corrigé : le fichier de production est modifié
# le temps d'une mesure puis rétabli (trap), jamais commité.
#
# Prérequis (depuis la racine du dépôt, graine 42) :
#   python3 bench/generate_corpus.py --n 1000 --seed 42 --out bench/corpus.jsonl
#   python3 bench/generate_corpus_transcrit.py --corpus bench/corpus.jsonl --seed 42 --out-dir bench/transcrit
#   python3 bench/generate_corpus_mots_nombres.py --n 300 --seed 42 --out bench/transcrit/corpus_temoin_mots_nombres.jsonl
#   python3 bench/generate_corpus_mots_nombres_dur.py --n 90 --seed 42 --out bench/transcrit/corpus_temoin_mots_nombres_dur.jsonl
# Usage : bash bench/mesure_nombres_dictes_k.sh SORTIE_DIR K [code|sans_code]
set -Eeuo pipefail
R=$(pwd)
OUT=${1:?dossier de sortie}
K=${2:?K}
MOT=${3:-code}
F="$R/packages/ecluse_redact/lib/src/nombres_dictes.dart"
mkdir -p "$OUT"
cp "$F" "$OUT/nombres_dictes.orig"
trap 'cp "$OUT/nombres_dictes.orig" "$F"' EXIT
sed -i "s/^const int _kSuite = [0-9]*;/const int _kSuite = $K;/" "$F"
if [ "$MOT" = "sans_code" ]; then
  sed -i "s/portable|code)/portable)/" "$F"
fi
grep -n "^const int _kSuite = \|portable" "$F" | sed -n 1,3p
T=$R/bench/transcrit
cd "$R/packages/ecluse_redact"
dart run bin/run_temoin_nombres_dictes.dart "$T/corpus_temoin_mots_nombres_dur.jsonl" "$OUT/dur.jsonl" < /dev/null
dart run bin/run_temoin_nombres_dictes.dart "$T/corpus_temoin_mots_nombres.jsonl" "$OUT/orig.jsonl" < /dev/null
echo "== témoin durci (630) K=$K mot-clé=$MOT"
python3 "$R/bench/score_temoin_dur.py" --corpus "$T/corpus_temoin_mots_nombres_dur.jsonl" --pred "$OUT/dur.jsonl" --exemples 0
echo "== témoin d'origine (300) : phrases masquées / signalées"
python3 - "$OUT/orig.jsonl" <<'PY'
import json, sys
d = [json.loads(l) for l in open(sys.argv[1])]
print(sum(bool(x["entities"]) for x in d), "/", len(d), "masquées ;", sum(bool(x["signalements"]) for x in d), "signalées")
PY
for v in sans_ponctuation en_lettres double_triple regional zero_o sans_traits_union; do
  dart run bin/run_redact_bench.dart "$T/corpus_transcrit_$v.jsonl" "$OUT/pred_$v.jsonl" < /dev/null > /dev/null
  echo "== dictée $v K=$K mot-clé=$MOT"
  python3 "$R/bench/rappel_structurel.py" --fuite --corpus "$T/corpus_transcrit_$v.jsonl" --pred "$OUT/pred_$v.jsonl" | grep -E "TOTAL"
done
