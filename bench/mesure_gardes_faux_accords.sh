#!/usr/bin/env bash
# P2-272 (mesure) : rejoue `Ecluse.redact` avec chaque garde candidate, une à la
# fois, sur les corpus à clé fausse et sur le témoin durci. Aucune correction :
# le patch de `gardes_faux_accords_patch.py` est appliqué le temps de la mesure
# puis rétabli par `git checkout` (jamais commité). Depuis la racine du dépôt :
#     bash bench/mesure_gardes_faux_accords.sh [SORTIE.tsv] [--sans-200k | --sonde]
# Chemin mesuré : `Ecluse.redact` (via run_redact_bench.dart --confiance).
set -Eeuo pipefail
R=$(pwd)
OUT=${1:-/tmp/gardes.tsv}
SANS200K=${2:-}
T=$(mktemp -d)
trap 'git -C "$R" checkout -- packages; rm -rf "$T"' EXIT
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"

python3 bench/generate_corpus_ocr.py --n 40 --seed 42 --out "$T/ocr.jsonl" > /dev/null
python3 bench/generate_corpus.py --n 1000 --seed 42 --out "$T/v3.jsonl" > /dev/null
python3 bench/generate_corpus_libelle_fort.py --n 50 --seed 42 --out "$T/lf.jsonl" > /dev/null
python3 bench/generate_sonde_gardes.py --n 40 --seed 42 --out "$T/sonde.jsonl" > /dev/null
CORPUS="ocr v3 lf sonde"
[ "$SANS200K" = "--sonde" ] && CORPUS="sonde"
if [ "$SANS200K" != "--sans-200k" ] && [ "$SANS200K" != "--sonde" ]; then
  python3 bench/generate_corpus.py --n 200000 --seed 42 --out "$T/c200k.jsonl" > /dev/null
  CORPUS="$CORPUS c200k"
fi
python3 bench/gardes_faux_accords_patch.py "$R"
: > "$OUT"
GARDES=("" iban_g4 iban_cle2 iban_ocr3 iban_motcle "iban_g4,iban_ocr3" nir_sanslettre nir_unelettre nir_suite nir_suitelettre nir_motcle finess_suite finess_suitelettre finess_sanscontexte adr_sanschiffre adr_confusables)
# GARDES_SEULES="a|b,c" : ne rejouer que ces gardes (la base est toujours rejouée).
if [ -n "${GARDES_SEULES:-}" ]; then
  IFS='|' read -r -a AUTRES <<< "$GARDES_SEULES"   # séparées par « | »
  GARDES=("" "${AUTRES[@]}")
fi
for g in "${GARDES[@]}"; do
  for c in $CORPUS; do
    (cd packages/ecluse_redact && ECLUSE_GARDE="$g" dart run bin/run_redact_bench.dart --confiance "$T/$c.jsonl" "$T/p.jsonl" > /dev/null < /dev/null)
    sous=()
    [ "$c" = ocr ] && sous=(--sous-ensemble temoin_dur)
    [ "$c" = sonde ] && sous=(--par famille,ecriture,phrase)
    r=$(python3 bench/score_gardes.py --corpus "$T/$c.jsonl" --pred "$T/p.jsonl" "${sous[@]}")
    printf '%s\t%s\t%s\n' "${g:-base}" "$c" "$r" >> "$OUT"
    if [ "$c" = ocr ]; then   # positifs OCR aussi (sans sous-ensemble)
      r=$(python3 bench/score_gardes.py --corpus "$T/$c.jsonl" --pred "$T/p.jsonl")
      printf '%s\t%s\t%s\n' "${g:-base}" "ocr_tous" "$r" >> "$OUT"
    fi
  done
done
echo "mesure terminée : $OUT"
