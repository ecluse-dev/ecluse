#!/usr/bin/env bash
# P2-318 : documents portant l'avertissement « mot pris pour un nom commun »
# (homonymes écartés, P2-310/P2-315/P2-316/P2-318) sur les témoins du dépôt.
# Chemin mesuré : `Ecluse.redact` (`bin/run_gardes_avertissements.dart`), pas le
# moteur seul. Depuis la racine du dépôt, APRÈS `bash bench/etat.sh` (qui écrit
# les corpus sous bench/{flou,dossiers,transcrit}/) ; graine 42 ; ≈ 15 min :
#     bash bench/mesure_temoins_homonymes.sh [DOSSIER_DE_TRAVAIL] > temoins.txt
# Sortie : « corpus | documents | avertis | part ». Seuil d'arrêt de P2-310 :
# plus de 5 % d'un témoin propre en casse ordinaire. Les corpus de plus de
# 31 200 documents (balayages de CEDEX) et les copies l60/l90 sont écartés.
# Compte seulement des avertissements : aucune valeur du texte n'est lue ni écrite.
set -Eeuo pipefail
R=$(pwd)
W=${1:-$(mktemp -d)}
mkdir -p "$W"
export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
python3 bench/generate_corpus_tournures_sans_nom.py --n 400 --seed 42 --out "$W/tournures_sans_nom.jsonl" > /dev/null
python3 bench/generate_corpus_tournures_personne.py --seed 42 --out "$W/tournures_personne.jsonl" > /dev/null
python3 bench/generate_corpus_prenom_verbe.py --seed 42 --out "$W/prenom_verbe.jsonl" > /dev/null
LISTE=$W/liste.txt
{
  ls bench/corpus.jsonl bench/flou/corpus_*.jsonl bench/dossiers/corpus_*.jsonl \
     bench/transcrit/corpus_*.jsonl "$W"/tournures_sans_nom.jsonl \
     "$W"/tournures_personne.jsonl "$W"/prenom_verbe.jsonl 2>/dev/null
} | grep -v -e 'balayage' -e '_l60' -e '_l90' -e '\.traites' | sort > "$LISTE"
echo "corpus | documents | avertis | part"
while read -r f; do
  [ "$(wc -l < "$f")" -gt 31200 ] && continue
  case "$f" in /*) f_abs=$f ;; *) f_abs=$R/$f ;; esac
  out=$W/pred_$(basename "$f")
  rm -f "$out"
  (cd "$R/packages/ecluse_redact" && dart run bin/run_gardes_avertissements.dart "$f_abs" "$out" < /dev/null) > /dev/null 2>&1 || { echo "ÉCHEC : $f"; continue; }
  python3 - "$f" "$out" <<'PY'
import json, sys
n = a = 0
for l in open(sys.argv[2], encoding="utf-8"):
    if not l.strip():
        continue
    n += 1
    if any("mot pris pour un nom commun" in w for w in json.loads(l).get("warnings", [])):
        a += 1
print(f"{sys.argv[1]} | {n} | {a} | {100 * a / max(n, 1):.2f} %")
PY
done < "$LISTE"
