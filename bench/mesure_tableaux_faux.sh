#!/usr/bin/env bash
# P2-296 (mesure) : faux tableaux de noms fabriqués par la mise en page, et coût
# de trois règles plus strictes sur les en-têtes, par `Ecluse.redact` (chemin du
# produit : ce que reçoit le LLM). Rien n'est corrigé : le fichier
# `tableau_csv.dart` est remplacé le temps de chaque règle, puis rétabli (trap),
# jamais commité. Depuis la racine du dépôt (graine 42) :
#     bash bench/mesure_tableaux_faux.sh [DOSSIER_DE_TRAVAIL]
#
# Règles simulées (R0 = main, sans modification) :
#   R1  une cellule d'en-tête ne compte comme colonne de personne que si elle
#       ne contient ni chiffre ni deux-points (une étiquette, pas une phrase
#       qui porte sa valeur : « date de naissance : 16 ») ;
#   R2  un en-tête dont une cellule a plus de trois mots n'est pas un en-tête
#       (le plus long libellé reconnu, « Date de naissance », en a trois) ;
#   R3  une ligne de largeur différente ne lève plus de refus : le tableau
#       s'arrête là (déconseillée a priori : elle envoie les lignes suivantes).
set -Eeuo pipefail
R=$(pwd)
W=${1:-$(mktemp -d)}
mkdir -p "$W/flou" "$W/sonde" "$W/pred"
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
F=packages/ecluse_redact/lib/src/heuristics/tableau_csv.dart
cp "$F" "$W/tableau_csv.orig.dart"
trap 'cp "$W/tableau_csv.orig.dart" "$F"' EXIT

# --- Corpus -----------------------------------------------------------------
python3 bench/generate_corpus_flou.py --n 400 --seed 42 --out-dir "$W/flou" > /dev/null
python3 bench/generate_sonde_tableaux.py --out-dir "$W/sonde" > /dev/null
LARGEURS="40 45 50 55 60 65 70 80 90 100 120"
SERIES=()   # étiquette|fichier
for c in realiste adversarial temoin; do
  SERIES+=("flou $c, ordinaire|$W/flou/corpus_flou_$c.jsonl")
  for w in $LARGEURS; do
    python3 bench/generate_corpus_mise_en_page.py "$W/flou/corpus_flou_$c.jsonl" \
      --largeur "$w" --out "$W/flou/${c}_l$w.jsonl" > /dev/null
    SERIES+=("flou $c, largeur $w|$W/flou/${c}_l$w.jsonl")
  done
done
if [ -f bench/corpus.jsonl ]; then
  SERIES+=("principal, ordinaire|bench/corpus.jsonl")
  for w in 60 90; do
    python3 bench/generate_corpus_mise_en_page.py bench/corpus.jsonl \
      --largeur "$w" --out "$W/principal_l$w.jsonl" > /dev/null
    SERIES+=("principal, largeur $w|$W/principal_l$w.jsonl")
  done
fi
SERIES+=("sonde vrais tableaux|$W/sonde/sonde_tableaux_vrais.jsonl")
SERIES+=("sonde tableaux irréguliers|$W/sonde/sonde_tableaux_irreguliers.jsonl")

# --- Règles -------------------------------------------------------------------
patch() { # $1 = règle ; réécrit $F depuis l'original
  cp "$W/tableau_csv.orig.dart" "$F"
  python3 - "$1" "$F" <<'PY'
import sys
regle, chemin = sys.argv[1], sys.argv[2]
s = open(chemin, encoding="utf-8").read()
def remplace(avant, apres):
    global s
    assert s.count(avant) == 1, "motif introuvable : " + avant[:40]
    s = s.replace(avant, apres)
if regle == "R1":
    remplace("      if (estColonne(_normalise(text.substring(c.start, c.end)))) {",
             "      if (!RegExp(r'[0-9:]').hasMatch(text.substring(c.start, c.end)) &&\n"
             "          estColonne(_normalise(text.substring(c.start, c.end)))) {")
elif regle == "R2":
    remplace("      if (c.end - c.start > 40) courts = false;",
             "      if (c.end - c.start > 40) courts = false;\n"
             "      if (text.substring(c.start, c.end).trim().split(RegExp(r'\\s+')).length > 3) {\n"
             "        courts = false;\n      }")
elif regle == "R3":
    remplace("        throw TableauAmbiguException(\n"
             "          j + 1,\n"
             "          '${cells.length} colonnes au lieu de $nbColonnes',\n"
             "        );",
             "        break;")
elif regle != "R0":
    raise SystemExit("règle inconnue")
open(chemin, "w", encoding="utf-8").write(s)
PY
}

for r in R0 R1 R2 R3; do
  patch "$r"
  (cd packages/ecluse_redact && dart compile exe bin/run_redact_bench.dart -o "$W/bench_$r.exe" > /dev/null)
  i=0
  for s in "${SERIES[@]}"; do
    f=${s#*|}
    [[ "$f" = /* ]] || f="$R/$f"
    "$W/bench_$r.exe" "$f" "$W/pred/${r}_$i.jsonl" < /dev/null > /dev/null 2>> "$W/stderr_$r.log"
    i=$((i + 1))
  done
done
cp "$W/tableau_csv.orig.dart" "$F"

# --- Rapport ------------------------------------------------------------------
for r in R0 R1 R2 R3; do
  echo "## règle $r"
  ARGS=()
  i=0
  for s in "${SERIES[@]}"; do
    f=${s#*|}
    [[ "$f" = /* ]] || f="$R/$f"
    ARGS+=("${s%%|*}|$f|$W/pred/${r}_$i.jsonl")
    i=$((i + 1))
  done
  python3 bench/analyse_tableaux_faux.py "${ARGS[@]}"
done
echo "travail : $W"
