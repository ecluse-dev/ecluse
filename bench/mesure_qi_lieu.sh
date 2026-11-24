#!/usr/bin/env bash
# P2-287 (mesure) : quasi-identifiants `lieu` du rapport de risque lus sur des mots
# courants, par `Ecluse.redact` avec référence (chemin du produit). Rien n'est
# corrigé. Depuis la racine du dépôt, après `bash bench/etat.sh` (qui génère les
# corpus flous, QI et dossiers, graine 42) :
#     bash bench/mesure_qi_lieu.sh DOSSIER_DE_SORTIE [N_SANS_PII]
set -Eeuo pipefail
R=$(pwd)
OUT=${1:?dossier de sortie}
N=${2:-60000}
mkdir -p "$OUT"
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
python3 bench/generate_corpus_temoin_sans_pii.py --n 200000 --seed 42 --out "$OUT/sanspii.jsonl" > /dev/null
run() { (cd "$R/packages/ecluse_redact" && dart run bin/run_qi_lieu.dart "$1" "$2" ${3:-} < /dev/null); }
run "$OUT/sanspii.jsonl" "$OUT/q_sanspii.jsonl" "$N"
for c in "v3:bench/corpus.jsonl" \
  "flou_realiste:bench/flou/corpus_flou_realiste.jsonl" \
  "flou_adversarial:bench/flou/corpus_flou_adversarial.jsonl" \
  "flou_temoin:bench/flou/corpus_flou_temoin.jsonl" \
  "flou_fauxamis:bench/flou/corpus_flou_fauxamis.jsonl" \
  "courriers:bench/flou/corpus_courriers.jsonl" \
  "qi_realiste:bench/qi/corpus_qi_realiste.jsonl" \
  "qi_adversarial:bench/qi/corpus_qi_adversarial.jsonl" \
  "qi_temoin:bench/qi/corpus_qi_temoin.jsonl" \
  "dossiers_realiste:bench/dossiers/corpus_dossiers_realiste.jsonl" \
  "dossiers_temoin:bench/dossiers/corpus_dossiers_temoin.jsonl"; do
  [ -f "$R/${c#*:}" ] || { echo "ÉCHEC : corpus absent ${c#*:}"; exit 1; }
  run "$R/${c#*:}" "$OUT/q_${c%%:*}.jsonl"
done
python3 bench/generate_sonde_mots_courants.py --out-dir "$OUT"
run "$OUT/sonde_isole.jsonl" "$OUT/q_sonde_isole.jsonl"
run "$OUT/sonde_combine.jsonl" "$OUT/q_sonde_combine.jsonl"
echo "sorties dans $OUT"
