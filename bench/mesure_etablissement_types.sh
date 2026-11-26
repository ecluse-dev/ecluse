#!/usr/bin/env bash
# P2-297 (mesure) : par quel type d'entité chaque établissement annoté est
# couvert quand le texte est en capitales, par `Ecluse.redact` (chemin du
# produit : ce que reçoit le LLM), et ce que cela change pour la restauration
# et le rapport de risque. Rien n'est corrigé. Depuis la racine (graine 42) :
#     bash bench/mesure_etablissement_types.sh [DOSSIER_DE_TRAVAIL]
# Ne sort que des nombres. L'ablation `--sans=nom` ou `--sans=etablissement`
# retire du moteur les détecteurs de ce nom, le temps de la mesure.
set -Eeuo pipefail
R=$(pwd)
W=${1:-$(mktemp -d)}
mkdir -p "$W/flou"
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
python3 bench/generate_corpus_flou.py --n 400 --seed 42 --out-dir "$W/flou" > /dev/null
for c in realiste adversarial; do
  python3 bench/variantes_casse.py "$W/flou/corpus_flou_$c.jsonl" > /dev/null
done
cd packages/ecluse_redact
run() { dart run bin/run_etablissement_types.dart "$@" < /dev/null; }
for c in realiste adversarial; do
  F=$W/flou/corpus_flou_$c.jsonl
  run "$c, casse d'origine" "$F"
  run "$c, capitales" "${F%.jsonl}_majuscules.jsonl" "$F"
  for s in etablissement nom; do
    run --sans=$s "$c, casse d'origine" "$F" | sed -n 1,4p
    run --sans=$s "$c, capitales" "${F%.jsonl}_majuscules.jsonl" | sed -n 1,4p
  done
done
echo "travail : $W"
