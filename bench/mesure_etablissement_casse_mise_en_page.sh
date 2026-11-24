#!/usr/bin/env bash
# P2-290 (mesure) : établissements annotés et masquages à tort, par variante de
# casse et de mise en page, par `Ecluse.redact` (chemin du produit), avant et
# après P2-289. Rien n'est corrigé : les deux fichiers modifiés par P2-289 sont
# remplacés le temps de la mesure « avant » par leur version du commit parent de
# P2-289, puis rétablis (trap), jamais commités. Depuis la racine (graine 42) :
#     bash bench/mesure_etablissement_casse_mise_en_page.sh [DOSSIER_DE_TRAVAIL]
set -Eeuo pipefail
R=$(pwd)
W=${1:-$(mktemp -d)}
mkdir -p "$W/flou"
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
AVANT=584086c^   # parent du commit de P2-289
L=packages/ecluse_redact/lib/src
FICHIERS="$L/heuristics/etablissement_detector.dart $L/coupures_de_nom.dart"
mkdir -p "$W/orig"
for f in $FICHIERS; do cp "$f" "$W/orig/$(basename "$f")"; done
trap 'for f in '"$FICHIERS"'; do cp "$W/orig/$(basename "$f")" "$f"; done' EXIT
python3 bench/generate_corpus_flou.py --n 400 --seed 42 --out-dir "$W/flou" > /dev/null
for c in realiste adversarial temoin; do
  P="$W/flou/corpus_flou_$c.jsonl"
  python3 bench/variantes_casse.py "$P" > /dev/null
  for w in 60 90; do
    python3 bench/generate_corpus_mise_en_page.py "$P" --largeur $w --out "$W/flou/corpus_flou_${c}_l$w.jsonl" > /dev/null
  done
done
run() { (cd "$R/packages/ecluse_redact" && dart run bin/run_redact_bench.dart "$1" "$2" < /dev/null 2>>"$W/stderr.log"); }
VARIANTES="ordinaire:corpus_flou_C.jsonl minuscules:corpus_flou_C_minuscules.jsonl majuscules:corpus_flou_C_majuscules.jsonl phrase:corpus_flou_C_phrase.jsonl mixte:corpus_flou_C_mixte.jsonl l60:corpus_flou_C_l60.jsonl l90:corpus_flou_C_l90.jsonl"
passe() { # $1 = avant|apres
  for c in realiste adversarial temoin; do
    for v in $VARIANTES; do
      n=${v%%:*}; f=${v#*:}; f=${f//C/$c}
      run "$W/flou/$f" "$W/pred_$1_${c}_$n.jsonl"
    done
  done
}
passe apres
for f in $FICHIERS; do git show "$AVANT:$f" > "$f"; done
passe avant
for f in $FICHIERS; do cp "$W/orig/$(basename "$f")" "$f"; done
ARGS=()
for c in realiste adversarial temoin; do
  for v in $VARIANTES; do
    n=${v%%:*}; f=${v#*:}; f=${f//C/$c}
    ARGS+=("$c, $n|$W/flou/$f|$W/pred_avant_${c}_$n.jsonl|$W/pred_apres_${c}_$n.jsonl")
  done
done
python3 bench/analyse_etablissement_casse_mise_en_page.py "${ARGS[@]}"
echo "alertes de restauration non byte-exacte : $(grep -c ALERTE "$W/stderr.log" || true)"
echo "travail : $W"
