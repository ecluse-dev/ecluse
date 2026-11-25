#!/usr/bin/env bash
# P2-295 (spec, mesure) : « type + mot générique » (« Résidence Autonomie »).
# Rejoue `Ecluse.redact` (chemin du produit, `run_redact_bench.dart`) avec le code
# actuel et deux variantes du détecteur d'établissements, appliquées le temps de la
# mesure par `etablissement_variantes_patch.py` puis rétablies (trap + git
# checkout), jamais commitées. Depuis la racine (graine 42, ≈ 15 min) :
#     bash bench/mesure_type_mot_generique.sh [DOSSIER_DE_TRAVAIL]
# Corpus : documents sans personne (200 000, restreints à ceux où un mot-clé
# d'établissement est suivi d'un mot : aucun autre ne peut produire une entité
# `etablissement`), flou réaliste et adversarial (ordinaire, casses, 60 et 90
# colonnes), corpus principal (v3, 1000), témoin de 480 documents.
set -Eeuo pipefail
R=$(pwd)
W=${1:-$(mktemp -d)}
mkdir -p "$W/flou"
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
F=packages/ecluse_redact/lib/src/heuristics/etablissement_detector.dart
trap 'git -C "$R" checkout -- "$F"' EXIT
python3 bench/generate_corpus_temoin_sans_pii.py --n 200000 --seed 42 --out "$W/sanspii.jsonl" > /dev/null
python3 bench/restreint_sans_personne.py "$W/sanspii.jsonl" "$W/sanspii_filtre.jsonl"
python3 bench/generate_corpus_temoin_sans_pii.py --n 480 --seed 42 --out "$W/temoin480.jsonl" > /dev/null
python3 bench/generate_corpus_flou.py --n 400 --seed 42 --out-dir "$W/flou" > /dev/null
for c in realiste adversarial temoin; do
  P="$W/flou/corpus_flou_$c.jsonl"
  python3 bench/variantes_casse.py "$P" > /dev/null
  for w in 60 90; do
    python3 bench/generate_corpus_mise_en_page.py "$P" --largeur $w --out "$W/flou/corpus_flou_${c}_l$w.jsonl" > /dev/null
  done
done
python3 bench/generate_corpus.py --n 1000 --seed 42 --out "$W/principal.jsonl" > /dev/null
python3 bench/etablissement_variantes_patch.py "$R"
CORPUS="sanspii:$W/sanspii_filtre.jsonl temoin480:$W/temoin480.jsonl principal:$W/principal.jsonl"
for c in realiste adversarial; do
  for v in "" _minuscules _majuscules _phrase _mixte _l60 _l90; do
    CORPUS="$CORPUS ${c}${v}:$W/flou/corpus_flou_${c}${v}.jsonl"
  done
done
run() { # $1 variante, $2 nom:corpus
  n=${2%%:*}; f=${2#*:}
  (cd "$R/packages/ecluse_redact" && ECLUSE_ETAB="$1" dart run bin/run_redact_bench.dart "$f" "$W/pred_${1:-base}_$n.jsonl" < /dev/null > /dev/null 2>&1)
}
for v in "" generiques nomprop; do
  ( for c in $CORPUS; do run "$v" "$c"; done ) &
done
wait
echo "travail : $W"
