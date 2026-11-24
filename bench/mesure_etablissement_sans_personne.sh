#!/usr/bin/env bash
# P2-285 (mesure) : établissements masqués dans des documents sans personne, par
# forme, par `Ecluse.redact` (chemin du produit). Rien n'est corrigé : le fichier
# du détecteur est modifié le temps de la variante puis rétabli (trap), jamais
# commité. Depuis la racine du dépôt (graine 42, ≈ 20 min) :
#     bash bench/mesure_etablissement_sans_personne.sh [DOSSIER_DE_TRAVAIL]
set -Eeuo pipefail
R=$(pwd)
W=${1:-$(mktemp -d)}
mkdir -p "$W/flou"
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
F="$R/packages/ecluse_redact/lib/src/heuristics/etablissement_detector.dart"
cp "$F" "$W/etablissement_detector.orig"
trap 'cp "$W/etablissement_detector.orig" "$F"' EXIT
python3 bench/generate_corpus_temoin_sans_pii.py --n 200000 --seed 42 --out "$W/sanspii.jsonl" > /dev/null
python3 bench/generate_corpus_flou.py --n 400 --seed 42 --out-dir "$W/flou" > /dev/null
run() { (cd "$R/packages/ecluse_redact" && dart run bin/run_temoin_nombres_dictes.dart "$1" "$2" < /dev/null); }
CORPUS="sanspii:$W/sanspii.jsonl realiste:$W/flou/corpus_flou_realiste.jsonl adversarial:$W/flou/corpus_flou_adversarial.jsonl"
for c in $CORPUS; do run "${c#*:}" "$W/base_${c%%:*}.jsonl"; done
# Variante : un mot du nom d'établissement ne peut pas commencer par une minuscule
# accentuée (la classe `[A-ZÀ-Ÿ]` couvre aussi U+00E0 à U+00FF, dont « à »).
grep -c 'static const String _word = "\[A-ZÀ-Ÿ\]' "$F" > /dev/null
sed -i 's/static const String _word = "\[A-ZÀ-Ÿ\]/static const String _word = "[A-ZÀ-ÖØ-ÞŒ]/' "$F"
grep -n 'static const String _word' "$F"
for c in $CORPUS; do run "${c#*:}" "$W/variante_${c%%:*}.jsonl"; done
python3 bench/analyse_etablissement_sans_personne.py \
  --sans-pii "$W/sanspii.jsonl" "$W/base_sanspii.jsonl" \
  --variante-sans-pii "$W/variante_sanspii.jsonl" \
  --annotes \
  "flou réaliste:$W/flou/corpus_flou_realiste.jsonl:$W/base_realiste.jsonl:$W/variante_realiste.jsonl" \
  "flou adversarial:$W/flou/corpus_flou_adversarial.jsonl:$W/base_adversarial.jsonl:$W/variante_adversarial.jsonl"
